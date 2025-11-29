import math
import builtins
import json
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, BooleanType

# =============================================================================
# 1. CONFIGURATION & INITIALISATION
# =============================================================================

KAFKA_BOOTSTRAP = "172.25.0.21:9092"
THREAT_INTEL_FILE = "/mnt/data/threat_intel_blacklist.json"

spark = SparkSession.builder \
    .appName("AI_Threat_Hunter_Ultimate") \
    .config("spark.sql.streaming.stateStore.providerClass", "org.apache.spark.sql.execution.streaming.state.HDFSBackedStateStoreProvider") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
print(">>> Démarrage du Cerveau IA : Hybride (Signatures Avancées + Threat Intel + Entropie)...")

# --- CHARGEMENT THREAT INTEL (Broadcast) ---
try:
    with open(THREAT_INTEL_FILE, 'r') as f:
        ti_data = json.load(f)
except Exception:
    ti_data = {"ips": [], "user_agents": []}

broadcast_ti = spark.sparkContext.broadcast(ti_data)

# =============================================================================
# 2. FONCTIONS IA & UTILITAIRES
# =============================================================================

def calculate_entropy(text):
    if not text:
        return 0.0
    prob = [float(text.count(c)) / len(text) for c in dict.fromkeys(list(text))]
    entropy = -builtins.sum([p * math.log(p) / math.log(2.0) for p in prob if p > 0])
    return float(entropy)

def calculate_special_ratio(text):
    if not text:
        return 0.0
    special_chars = set("[]{}().,;:'\"!@#$%^&*-_=+|<>?/%\\")
    count = builtins.sum(1 for char in text if char in special_chars)
    return float(count) / len(text)

def check_threat_intel(ip, ua):
    ti = broadcast_ti.value
    is_bad_ip = ip in ti.get("ips", [])
    is_bad_ua = False
    if ua:
        is_bad_ua = any(bad_ua in ua for bad_ua in ti.get("user_agents", []))
    return is_bad_ip or is_bad_ua

entropy_udf = udf(calculate_entropy, DoubleType())
special_ratio_udf = udf(calculate_special_ratio, DoubleType())
ti_check_udf = udf(check_threat_intel, BooleanType())

# =============================================================================
# 3. LECTURE DES FLUX
# =============================================================================
df = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP) \
    .option("subscribe", "syslogs,fraud_alerts") \
    .option("startingOffsets", "latest") \
    .load()

raw_stream = df.select(
    col("timestamp").alias("kafka_ts"),
    col("value").cast("string").alias("payload"),
    col("topic")
)

carding_schema = StructType([
    StructField("transaction_id", StringType()),
    StructField("amount", DoubleType()),
    StructField("currency", StringType()),
    StructField("country", StringType()),
    StructField("city", StringType()),
    StructField("ip", StringType()),
    StructField("user", StringType()),
    StructField("status", StringType()),
    StructField("geoip", StructType([StructField("location", StringType())]))
])
parsed_json = from_json(col("payload"), carding_schema)

# =============================================================================
# 4. FEATURE ENGINEERING
# =============================================================================

ip_regex = r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
raw_extracted_ip = regexp_extract(col("payload"), ip_regex, 1)

analyzed_df = raw_stream \
    .withColumn("log_len", length(col("payload"))) \
    .withColumn("entropy", entropy_udf(col("payload"))) \
    .withColumn("special_ratio", special_ratio_udf(col("payload"))) \
    .withColumn("json_data", when(col("topic") == "fraud_alerts", parsed_json).otherwise(lit(None))) \
    .withColumn("source_ip", coalesce(col("json_data.ip"), when(raw_extracted_ip == "", None).otherwise(raw_extracted_ip))) \
    .withColumn("ua_extract", regexp_extract(col("payload"), r'"(Mozilla|curl|Wget|python-requests)[^" ]*"', 0))

enriched_df = analyzed_df.withColumn("is_known_threat", ti_check_udf(col("source_ip"), col("ua_extract")))

# =============================================================================
# 5. LOGIQUE DE DÉTECTION 
# =============================================================================

# Utilisation de parenthèses pour éviter les erreurs de syntaxe Python et
# échappement des caractères spéciaux pour éviter les erreurs Regex Java.
signatures = (
    when(col("payload").rlike(r"(?i)EventID\s+4625|Audit Failure"), "WINDOWS_BRUTE_FORCE")
    .when(col("payload").rlike(r"(?i)Failed password|invalid user|authentication failure"), "LINUX_BRUTE_FORCE")
    .when(col("payload").rlike(r"(?i)EventID\s+4720"), "USER_ACCOUNT_CREATED")

    # SQL Injection
    .when(col("payload").rlike(r"(?i)UNION\s+SELECT|' OR '1'='1"), "SQLI_UNION")
    .when(col("payload").rlike(r"(?i)information_schema|benchmark\(|sleep\("), "SQLI_ADVANCED")

    # XSS & Web
    .when(col("payload").rlike(r"(?i)<script>|onerror=|onload=|javascript:"), "XSS_ATTACK")
    .when(col("payload").rlike(r"(?i)\.\./|\%2e\%2e|/etc/passwd|/boot.ini"), "LFI_TRAVERSAL")
    .when(col("payload").rlike(r"(?i)curl\s+http|wget\s+http|php://"), "RFI_REMOTE_INCLUDE")

    # RCE & Command Injection
    .when(col("payload").rlike(r"(?i)(system\(|exec\(|shell_exec\(|eval\()"), "RCE_PHP")
    .when(col("payload").rlike(r"(?i)/bin/sh|-e /bin/bash|cmd.exe|powershell.*-enc"), "RCE_OS_COMMAND")
    .when(col("payload").rlike(r"(?i)nc -e|ncat|/dev/tcp/"), "REVERSE_SHELL")

    # CVE Connues & Scans
    .when(col("payload").rlike(r"(?i)jndi:ldap|CVE-2021-44228"), "LOG4J_EXPLOIT")
    
    # CORRECTION ICI : Echappement des parenthèses et accolades -> \(\) \{ :; \};
    .when(col("payload").rlike(r"(?i)\(\) \{ :; \};"), "SHELLSHOCK")
    
    .when(col("payload").rlike(r"(?i)nmap scan|masscan|dirsearch|nikto"), "RECON_SCANNER")

    .otherwise("UNKNOWN")
)

ai_verdict = (
    when((col("entropy") > 4.5) & (col("log_len") > 50), "AI_HIGH_ENTROPY_ANOMALY")
    .when((col("special_ratio") > 0.3) & (col("log_len") > 20), "AI_CODE_INJECTION_ANOMALY")
    .when((col("log_len") > 2000), "AI_DATA_EXFILTRATION")
    .when(col("payload").rlike(r"[A-Za-z0-9+/]{100,}={0,2}"), "AI_BASE64_OBFUSCATION")
    .otherwise(None)
)

# =============================================================================
# 6. DÉCISION FINALE
# =============================================================================

verdict = when(col("topic") == "fraud_alerts", "CARDING_FRAUD") \
         .when(col("is_known_threat") == True, "THREAT_INTEL_BLACKLIST") \
         .when(signatures != "UNKNOWN", signatures) \
         .when(ai_verdict.isNotNull(), ai_verdict) \
         .otherwise("NORMAL_TRAFFIC")

final_df = enriched_df.select(
    coalesce(col("kafka_ts"), current_timestamp()).alias("@timestamp"),
    verdict.alias("attack_type"),
    col("entropy"),
    col("special_ratio"),
    col("log_len"),
    col("source_ip"),
    coalesce(col("json_data.user"), lit("system_watcher")).alias("user"),
    struct(
        col("json_data.geoip.location").alias("location"),
        col("json_data.country").alias("country_name"),
        col("json_data.city").alias("city_name")
    ).alias("geoip"),
    struct(
        col("json_data.amount").alias("amount"),
        col("json_data.currency").alias("currency"),
        col("json_data.transaction_id").alias("id")
    ).alias("transaction"),
    col("payload").alias("raw_message")
)

real_alerts = final_df.filter(
    (col("attack_type") != "NORMAL_TRAFFIC") & 
    (~col("payload").contains("Microsoft-Windows-Security-Auditing"))
)

# =============================================================================
# 7. ECRITURE
# =============================================================================
query = real_alerts \
    .writeStream \
    .outputMode("append") \
    .format("es") \
    .option("es.nodes", "elasticsearch") \
    .option("es.port", "9200") \
    .option("es.resource", "security_events") \
    .option("es.ingest.pipeline", "geoip-enrichment") \
    .option("es.nodes.wan.only", "true") \
    .option("checkpointLocation", "/tmp/checkpoint_ai_entropy_v3_fixed") \
    .start()


query.awaitTermination()
