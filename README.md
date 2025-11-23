# Système Unifié de Détection de Menaces (Spark Streaming)



---

## ⚙️ Configurer Elasticsearch

### 1) Accéder à Kibana
Ouvrez votre navigateur : [http://localhost:5601](http://localhost:5601)

### 2) Créer le Pipeline GeoIP
Dans **Dev Tools**, exécutez :
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

### 3) Créer le Template d'Index
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

### 4) Créer les Topics Kafka (Optionnel)
```bash
docker exec kafka kafka-topics --create --topic syslogs --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
docker exec kafka kafka-topics --create --topic fraud_alerts --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
```

### 5) Importer le Dashboard Kibana
- Allez dans **Kibana → Stack Management → Saved Objects → Import**.
- Importez le fichier `dashboard.ndjson` fourni.


---

## 🚀 Installation et Mise en Place

### ✅ Prérequis
- Docker Desktop
- Git
- Windows PowerShell

### 🛠️ Étapes
#### 1) Cloner le projet
```bash
git clone https://github.com/BALLEGI/realtime-fraud-detection1
cd realtime-fraud-detection1
```

#### 2) Démarrer l'infrastructure
```bash
docker-compose up -d
```
⏳ Attendre ~60s pour l'initialisation complète.

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

## 🎮 Utilisation

### ▶️ Lancer le moteur de détection
```powershell
start-detection.bat
```
✅ Attendez le message : `Pipeline Unifié Actif. Écriture vers 'security_events'...`

### 🧪 Simuler des attaques
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

### 🔍 Observer en temps réel
- Kibana → Dashboard **Unified Security Center**.
- Période : `Today` ou `Last 1 hour`.
