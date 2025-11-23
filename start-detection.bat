@echo off
CLS
echo ========================================================
echo   DEMARRAGE DU JOB SPARK STREAMING (FRAUD DETECTION)
echo ========================================================

:: 1. Copie du script Python dans le conteneur Master
echo.
echo [1/4] Copie du script spark_fraud_detection.py vers le container...
docker cp spark_fraud_detection.py spark-master:/opt/spark/spark_fraud_detection.py
if %ERRORLEVEL% NEQ 0 (
    echo ERREUR: Impossible de copier le fichier. Verifiez qu'il est dans ce dossier.
    pause
    exit /b
)

:: 2. Configuration des droits et dossiers pour les JARs (Ivy)
echo.
echo [2/4] Configuration des permissions Ivy (cache JARs)...
docker exec -u 0 spark-master bash -c "mkdir -p /home/spark/.ivy2/cache /home/spark/.ivy2/jars && chown -R spark:spark /home/spark/.ivy2"

:: 3. Lancement du Job Spark (COMMANDE CRITIQUE)
echo.
echo [3/4] Lancement du Job Spark...
echo       (Ne fermez pas cette fenetre tant que le traitement tourne)
echo.

docker exec -it --user spark spark-master /opt/spark/bin/spark-submit ^
  --master spark://172.25.0.10:7077 ^
  --deploy-mode client ^
  --conf spark.app.name="UnifiedThreatDefense" ^
  --conf spark.driver.host=172.25.0.10 ^
  --conf spark.driver.bindAddress=0.0.0.0 ^
  --conf spark.driver.port=40303 ^
  --conf spark.ui.port=4040 ^
  --conf spark.jars.ivy=/home/spark/.ivy2 ^
  --conf spark.sql.streaming.metrics.enabled=true ^
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.4.3,org.elasticsearch:elasticsearch-spark-30_2.12:8.15.2 ^
  /opt/spark/spark_fraud_detection.py

:: 4. Nettoyage et fin
echo.
echo [4/4] Nettoyage du script dans le conteneur...
docker exec spark-master rm -f /opt/spark/spark_fraud_detection.py

echo.
echo ========================================================
echo   JOB TERMINE OU ARRETE
echo ========================================================
pause