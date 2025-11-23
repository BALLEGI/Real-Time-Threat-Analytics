CLS
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   SIMULATION D'ATTAQUE BRUTE-FORCE (DIRECT KAFKA)" -ForegroundColor Cyan
Write-Host "========================================================"
Write-Host ""

# --- CONFIGURATION ---
$ContainerName = "kafka"
$TopicName = "syslogs"
$AttackerIP = "185.220.101.42"  # IP Tor Exit Node
$TargetUser = "root"
$Count = 20  # Nombre de tentatives (suffisant pour déclencher le seuil > 6)

Write-Host "[*] Cible      : Container '$ContainerName' -> Topic '$TopicName'"
Write-Host "[*] Scénario   : L'IP $AttackerIP tente de forcer l'utilisateur '$TargetUser'"
Write-Host "[*] Action     : Envoi de $Count logs en rafale..."
Write-Host ""

# --- BOUCLE D'ATTAQUE ---
for ($i = 1; $i -le $Count; $i++) {
    # 1. Création du faux log SSH (Format standard Syslog)
    $Date = Get-Date -Format "MMM dd HH:mm:ss"
    $Port = Get-Random -Min 1000 -Max 60000
    $Pid_ssh = Get-Random -Min 1000 -Max 9999
    
    # Le format doit matcher votre Regex Spark : "Failed password" ... "for" ... "from"
    $LogMessage = "$Date server-prod sshd[$Pid_ssh]: Failed password for invalid user $TargetUser from $AttackerIP port $Port ssh2"

    # 2. Affichage visuel
    Write-Host " [$i/$Count] Envoi : $LogMessage" -ForegroundColor Yellow

    # 3. Injection directe dans Kafka (via Docker)
    # On utilise kafka-console-producer qui est déjà installé dans le conteneur
    $DockerCommand = "echo $LogMessage | kafka-console-producer --broker-list localhost:9092 --topic $TopicName > /dev/null 2>&1"
    
    # Exécution de la commande dans le conteneur
    Invoke-Expression "docker exec $ContainerName bash -c '$DockerCommand'"

    # Petite pause pour simuler une attaque humaine ou bot rapide (mais pas instantanée)
    Start-Sleep -Milliseconds 200
}

# --- CONCLUSION ---
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "   ATTAQUE TERMINEE ! VERIFICATIONS :" -ForegroundColor Green
Write-Host "========================================================"
Write-Host "1. Regardez votre fenêtre Spark : Vous devriez voir des Batchs traiter des données."
Write-Host "2. Allez sur Kibana : http://localhost:5601"
Write-Host "3. Discover > Sélectionnez la vue 'fraud_alerts'"
Write-Host "   (Si pas encore créée : Stack Management > Data Views > Create > 'fraud_alerts')"
Write-Host ""
Pause