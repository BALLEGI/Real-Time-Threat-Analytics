CLS
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "    SIMULATION D'ATTAQUES WEB (SQLi, XSS, TRAVERSAL)" -ForegroundColor Cyan
Write-Host "========================================================"

$ContainerName = "kafka"
$TopicName = "syslogs"

# Liste de faux logs web malveillants (Format Apache/Nginx simulé)
$Attacks = @(
    @{Type="SQL Injection"; Msg='192.168.1.50 - - [21/Nov/2025:10:00:01 +0000] "GET /products.php?id=1 UNION SELECT 1,username,password FROM users" 200 452'},
    @{Type="SQL Injection"; Msg='10.0.0.14 - - [21/Nov/2025:10:05:00 +0000] "POST /login" "user=admin&pass=' + "' OR '1'='1" + '" 500 124'},
    @{Type="XSS Attack";    Msg='45.33.22.11 - - [21/Nov/2025:11:20:00 +0000] "GET /search?q=<script>alert(1)</script>" 200 1500'},
    @{Type="Path Traversal";Msg='185.200.10.5 - - [21/Nov/2025:12:00:00 +0000] "GET /download?file=../../../../etc/passwd" 403 0'},
    @{Type="Scanner Tool";  Msg='192.168.1.99 - - [21/Nov/2025:12:01:00 +0000] "HEAD /admin.php" 404 0 "Nmap Scripting Engine"'}
)

Write-Host "[*] Injection des attaques dans Kafka..."

foreach ($Attack in $Attacks) {
    $Log = $Attack.Msg
    $Type = $Attack.Type
    
    Write-Host " [!] Envoi ($Type) : $Log" -ForegroundColor Yellow
    
    # 1. Définir la commande BASH interne. On utilise 'printf' pour imprimer la log.
    # On échappe les guillemets doubles dans le log pour qu'ils soient traités correctement par printf.
    $LogForBash = $Log.Replace('"', '\"')
    $InternalCommand = "printf %s `"$LogForBash`" | kafka-console-producer --broker-list localhost:9092 --topic $TopicName > /dev/null 2>&1"
    
    # 2. Encoder la commande BASH en Base64.
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($InternalCommand)
    $Base64Command = [System.Convert]::ToBase64String($Bytes)
    
    # 3. Construire la commande finale Docker : elle décodera et exécutera le script BASH.
    # Cette structure est très stable car elle ne contient aucun caractère spécial de shell.
    $FinalDockerCommand = "docker exec $ContainerName sh -c ""echo $Base64Command | base64 -d | sh"""
    
    # 4. Exécuter la commande simple
    Invoke-Expression $FinalDockerCommand
    
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "Terminé. Vérifiez Kibana index 'security_events' !" -ForegroundColor Green