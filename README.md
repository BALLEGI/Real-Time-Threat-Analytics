
# Système Unifié de Détection de Menaces (Spark Streaming)

> Détection en temps réel des attaques Web, tentatives de brute-force et fraude par **carding** à l'aide d'**Apache Spark Structured Streaming**, **Kafka**, **Elasticsearch** et **Kibana**.

---

##  Table des matières
- [Présentation](#présentation)
- [Architecture](#architecture)
- [Fonctionnalités clés](#fonctionnalités-clés)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Lancement du Job Spark](#lancement-du-job-spark)
- [Simulation d'attaques](#simulation-dattaques)
- [Logique de détection](#logique-de-détection)
- [Schéma des données](#schéma-des-données)
- [Tableaux de bord & Visualisation](#tableaux-de-bord--visualisation)
- [Paramétrage & Personnalisation](#paramétrage--personnalisation)
- [Dépannage](#dépannage)
- [Sécurité & Bonnes pratiques](#sécurité--bonnes-pratiques)
- [Roadmap](#roadmap)
- [Licence](#licence)

---

## Présentation
Ce projet implémente une **solution de détection unifiée** des menaces en temps réel. Il utilise une approche **hybride** combinant :
- **Signatures** (regex pour Web/XSS/SQLi/LFI/RFI/RCE/Brute-Force),
- **Threat Intelligence (TI)** (IP/UA blacklists diffusées en broadcast),
- **Heuristiques d'anomalie** (Entropie & Ratio de caractères spéciaux) pour repérer obfuscation et exfiltration.

Le pipeline lit des messages **Kafka** (`syslogs`, `fraud_alerts`), enrichit les événements, applique les règles, et **indexe** les alertes pertinentes dans **Elasticsearch** pour visualisation via **Kibana**.

---

## Architecture
L'infrastructure est orchestrée via **Docker Compose**.

```
+------------------+       +------------------+       +---------------------+       +------------------+
|  Syslog-ng/Apps  |  -->  |  Kafka+Zookeeper |  -->  |  Spark (Streaming)  |  -->  |  Elasticsearch   |
| (Logs & Events)  |       |  Ingestion Bus   |       |  Détection & Enrich |       |  Index & Search  |
+------------------+       +------------------+       +---------------------+       +------------------+
                                                                    |                         |
                                                                    +-------------------------+
                                                                    |     Kibana (Dashboards) |
                                                                    +-------------------------+
```

**Composants**
- **Ingestion** : Kafka, Zookeeper, Syslog-ng
- **Traitement** : Spark Master/Workers (PySpark)
- **Stockage/Indexation** : Elasticsearch
- **Visualisation** : Kibana

---

## Fonctionnalités clés
- Lecture **en continu** depuis Kafka.
- **Feature Engineering** : entropie, ratio de caractères spéciaux, extraction IP/UA.
- **Règles de signatures** pour les attaques Web, brute-force, reverse shell, CVE (Log4Shell), etc.
- **Détection IA heuristique** : obfuscation (Base64), exfiltration, injection de code.
- **Enrichissement GeoIP** via pipeline d'ingestion Elasticsearch.
- **Alerting** : index `security_events` alimenté en temps réel.

---

## Prérequis
- **Docker** & **Docker Compose** installés.
- Environnement de travail : Windows, Linux, ou macOS.
- Accès réseau local pour les conteneurs (bridge `fraud-net`).

---

## Démarrage rapide
1. **Cloner le dépôt** ou copier les fichiers dans un répertoire.
2. **Démarrer l'infrastructure** :
   ```bash
   docker-compose up -d
   ```
3. **Vérifier les services** :
   - Kafka/Zookeeper démarrés,
   - Elasticsearch & Kibana accessibles,
   - Spark Master/Workers en ligne.

**Accès UI**
- Kibana : http://localhost:5601
- Spark UI : http://localhost:8080

---
##  Installation et Mise en Place

###  Prérequis
- Docker Desktop
- Git
- Windows PowerShell

###  Étapes
#### 1) Cloner le projet
```bash
git clone https://github.com/BALLEGI/Real-Time-Threat-Analytics
cd Real-Time-Threat-Analytics
```

#### 2) Démarrer l'infrastructure
```bash
docker-compose up -d
```
 Attendre ~60s pour l'initialisation complète.

#### 3) Configurer Elasticsearch
Accédez à Kibana : [http://localhost:5601](http://localhost:5601)

Allez dans **Dev Tools** et exécutez :

**Pipeline GeoIP**
```json
PUT /_ingest/pipeline/geoip-enrichment
{
  "description": "GeoIP enrichment for SIEM",
  "processors": [
    {
      "geoip": {
        "field": "source_ip",
        "target_field": "geoip",
        "ignore_failure": true
      }
    }
  ]
}
```

**Template d'Index**
```json
PUT _index_template/security_template
{
  "index_patterns": ["security_events*"],
  "template": {
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "geoip": { "properties": { "location": { "type": "geo_point" } } },
        "source_ip": { "type": "ip" },
        "attack_type": { "type": "keyword" },
        "transaction": { "properties": { "amount": { "type": "double" } } }
      }
    }
  }
}
```

#### 4) Créer les Topics Kafka (Optionnel)
```bash
docker exec kafka kafka-topics --create --topic syslogs --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
docker exec kafka kafka-topics --create --topic fraud_alerts --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
```

#### 5) Importer le Dashboard Kibana
- Allez dans **Kibana → Stack Management → Saved Objects → Import**.
- Importez le fichier `dashboard.ndjson` fourni.

---

##  Utilisation

###  Lancer le moteur de détection
```powershell
start-detection.bat
```
 Attendez le message : `Pipeline Unifié Actif. Écriture vers 'security_events'...`

###  Simuler des attaques
- **Fenêtre 1 : Fraude bancaire**
```powershell
.\generate-carding-attack.ps1
```
- **Fenêtre 2 : Attaques Web**
```powershell
.\generate-web-attacks.ps1
```
- **Fenêtre 3 : Brute Force SSH**
```powershell
.\generate-attack.ps1
```

###  Observer en temps réel
- Kibana → Dashboard **Unified Security Center**.
- Période : `Today` ou `Last 1 hour`.
## Lancement du Job Spark
Le script de détection **`spark_fraud_detection.py`** doit être soumis au cluster Spark.

> Les packages nécessaires (connecteurs) sont résolus via Ivy au premier lancement.

### Windows
Utilisez le script fourni :
```bat
start-detection.bat
```

### Linux/macOS
Exécutez les commandes suivantes :
```bash
# 1) Copier le script dans le conteneur spark-master
docker cp spark_fraud_detection.py spark-master:/opt/spark/spark_fraud_detection.py

# 2) Préparer les permissions Ivy (cache JAR)
docker exec -u 0 spark-master bash -c "mkdir -p /home/spark/.ivy2/cache /home/spark/.ivy2/jars && chown -R spark:spark /home/spark/.ivy2"

# 3) Lancer le job Spark (mode client)
docker exec -it --user spark spark-master /opt/spark/bin/spark-submit \
  --master spark://172.25.0.10:7077 \
  --deploy-mode client \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.4.3,org.elasticsearch:elasticsearch-spark-30_2.12:8.15.2 \
  /opt/spark/spark_fraud_detection.py
```

> **Note** : Adaptez les versions des packages au runtime Spark/Scala et à la version d'Elasticsearch du projet.

---

## Simulation d'attaques
Des scripts **PowerShell (`.ps1`)** permettent d'injecter des événements de test dans Kafka pour valider la détection :
- `generate-attack.ps1` : brute-force SSH (Linux/Windows).
- `generate-web-attacks.ps1` : SQLi (`UNION SELECT`, `' OR '1'='1'`), XSS (`<script>`), LFI (`../`).
- `generate-carding-attack.ps1` : transactions de **carding** géo-dispersées.

> Les alertes apparaissent en temps réel dans **Kibana** une fois le job Spark actif.

---

## Logique de détection
Le fichier **`spark_fraud_detection.py`** implémente :

### 1) Ingestion
- Lecture streaming des topics Kafka : `syslogs` et `fraud_alerts`.

### 2) Feature Engineering
- **Entropie** : repère obfuscation/payloads compressés (seuil typique > 4.5).
- **Ratio de caractères spéciaux** : détecte injections/commandes (seuil typique > 0.3).
- **Threat Intel** : IP/UA blacklistés via fichier JSON diffusé en **broadcast**.
- **Extraction IP & UA** : depuis payload ou JSON (selon `topic`).

### 3) Règles de signatures
- **Brute-Force** : `EventID 4625` (Windows), `Failed password` (Linux/SSH).
- **Attaques Web** : `UNION SELECT`, `' OR '1'='1'` (SQLi), `<script>` (XSS), `../`, `%2e%2e`, `/etc/passwd` (LFI/Traversal), `php://` (RFI).
- **RCE & Reverse Shell** : `system(`, `exec(`, `shell_exec(`, `eval(`), `/bin/sh`, `cmd.exe`, `powershell -enc`, `nc -e`, `ncat`, `/dev/tcp/`.
- **CVE connues** : Log4Shell (`jndi:ldap`, `CVE-2021-44228`), **Shellshock** (regex correctement échappée : `\(\) \{ :; \};`).
- **Scanners** : `nmap`, `masscan`, `dirsearch`, `nikto`.

### 4) Heuristiques IA
- `AI_HIGH_ENTROPY_ANOMALY` : entropie élevée & taille de payload.
- `AI_CODE_INJECTION_ANOMALY` : ratio de spéciaux élevé & longueur.
- `AI_DATA_EXFILTRATION` : longueur > 2000.
- `AI_BASE64_OBFUSCATION` : motifs Base64 longs.

### 5) Décision finale
Priorité:
1. `CARDING_FRAUD` si `topic == fraud_alerts`.
2. `THREAT_INTEL_BLACKLIST` si IP/UA correspond à la blacklist.
3. Signature connue (regex).
4. Verdict IA.
5. Sinon `NORMAL_TRAFFIC`.

### 6) Sortie & Filtrage
- Écriture des alertes (non `NORMAL_TRAFFIC`) vers l'index **`security_events`** d'Elasticsearch.
- Filtre anti-bruit pour certains logs Windows (Auditing).

---

## Schéma des données
### `fraud_alerts` (JSON attendu)
```json
{
  "transaction_id": "abc-123",
  "amount": 199.99,
  "currency": "EUR",
  "country": "FR",
  "city": "Paris",
  "ip": "198.51.100.23",
  "user": "john.doe",
  "status": "pending",
  "geoip": { "location": "48.8566,2.3522" }
}
```

### Sortie (index `security_events`)
```json
{
  "@timestamp": "2025-11-04T12:34:56Z",
  "attack_type": "SQLI_UNION",
  "entropy": 5.12,
  "special_ratio": 0.41,
  "log_len": 854,
  "source_ip": "203.0.113.45",
  "user": "system_watcher",
  "geoip": { "location": "...", "country_name": "...", "city_name": "..." },
  "transaction": { "amount": 0, "currency": "", "id": "" },
  "raw_message": "..."
}
```

---

## Tableaux de bord & Visualisation
- Créez un **index pattern** `security_events*` dans Kibana.
- Dashboards recommandés :
  - Répartition des `attack_type` dans le temps,
  - Top `source_ip` par type d'attaque,
  - Cartographie GeoIP,
  - Heatmap entropie/ratio.

---

## Paramétrage & Personnalisation
- **Fichier TI** : `/mnt/data/threat_intel_blacklist.json`
  ```json
  { "ips": ["198.51.100.23"], "user_agents": ["sqlmap", "masscan", "curl/7.", "python-requests"] }
  ```
- **Seuils** : ajuster (entropie, ratio, longueur) selon vos données.
- **Règles** : ajouter/modifier des regex pour votre contexte applicatif.
- **Connecteurs** : adapter versions des packages `spark-sql-kafka` et `elasticsearch-spark`.

---

## Dépannage
- **Le job ne démarre pas** : vérifier Spark Master (`http://localhost:8080`), packages résolus (cache Ivy).
- **Pas d'événements** : confirmer que Kafka reçoit des messages (`syslogs`, `fraud_alerts`).
- **Pas d'indexation** : valider la santé d'Elasticsearch (`/_cluster/health`) et droits réseau.
- **Regex trop agressives** : réduire la portée pour limiter les faux positifs.
- **Mémoire** : ajuster ressources Docker (RAM/CPU) pour Spark & ES.

---

## Sécurité & Bonnes pratiques
- Isoler les **réseaux Docker** et limiter l'exposition des ports.
- Mettre à jour régulièrement les **blacklists** (TI) et les dépendances.
- Journaliser et tracer les décisions (inférence IA vs signature/menace connue).
- Ajouter des **alertes** (Watchers/Alerts Kibana) pour les types critiques (RCE, exfiltration).

---

## Roadmap
- Paramètres via variables d'environnement (seuils, topics, index).
- Rechargement dynamique du fichier TI.
- Intégration **Prometheus/Grafana** pour métriques Spark.
- Ajout de **tests unitaires** des UDF.
- Support de **schema registry** et formats Avro/Protobuf.

---

## Licence
Ce projet est publié sous licence **MIT** (à adapter selon vos besoins).

