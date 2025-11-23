CLS
Write-Host "===================================================================" -ForegroundColor Red
Write-Host "   SIMULATION D'ATTAQUE CARDING MONDIALE (DATA GEO-DISPERSÉE)" -ForegroundColor Yellow
Write-Host "==================================================================="
Write-Host ""

# --- CONFIGURATION ---
$ContainerName = "kafka"
$TopicName = "fraud_alerts"  # Assurez-vous que votre Spark lit ce topic ou écrivez dans 'syslogs' si c'est le même pipeline
$Count = 500

# Dictionnaire des pays avec Coordonnées Centrales (Lat, Lon) et Villes principales
$Targets = @{
    "Nigeria"      = @{ lat=9.0820;  lon=8.6753;   cities=@("Lagos","Abuja","Kano") }
    "Brazil"       = @{ lat=-14.2350; lon=-51.9253; cities=@("São Paulo","Rio de Janeiro","Brasília") }
    "Colombia"     = @{ lat=4.5709;  lon=-74.2973; cities=@("Bogotá","Medellín","Cali") }
    "Peru"         = @{ lat=-9.1900; lon=-75.0152; cities=@("Lima","Cusco","Arequipa") }
    "South Africa" = @{ lat=-30.5595; lon=22.9375;  cities=@("Johannesburg","Cape Town","Durban") }
    "Morocco"      = @{ lat=31.7911; lon=-7.0926;  cities=@("Casablanca","Rabat","Marrakech") }
    "Indonesia"    = @{ lat=-0.7893; lon=113.9213; cities=@("Jakarta","Surabaya","Bali") }
    "Philippines"  = @{ lat=12.8797; lon=121.7740; cities=@("Manila","Cebu City","Davao") }
    "Russia"       = @{ lat=61.5240; lon=105.3188; cities=@("Moscow","Saint Petersburg","Novosibirsk") }
    "China"        = @{ lat=35.8617; lon=104.1954; cities=@("Beijing","Shanghai","Shenzhen") }
}

Write-Host "[*] Injection de $Count transactions frauduleuses dans Kafka..."
Write-Host "[*] Cible : Topic '$TopicName' via Container '$ContainerName'"
Write-Host ""

1..$Count | ForEach-Object {
    # 1. Sélection aléatoire d'un pays cible
    $CountryName = $Targets.Keys | Get-Random
    $TargetData = $Targets[$CountryName]
    
    # 2. "Jitter" Géographique (Dispersion)
    # On ajoute une variation aléatoire entre -2.0 et +2.0 degrés pour créer des "taches" sur la carte
    $RandomLat = $TargetData.lat + ((Get-Random -Minimum -200 -Maximum 200) / 100.0)
    $RandomLon = $TargetData.lon + ((Get-Random -Minimum -200 -Maximum 200) / 100.0)
    $City = $TargetData.cities | Get-Random

    # 3. Construction du Log JSON
    # Note: J'ai adapté le format pour qu'il soit compatible avec un parsing JSON standard
    $LogData = @{
        "@timestamp"     = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        transaction_id   = "txn_" + (Get-Random -Minimum 1000000 -Maximum 9999999)
        amount           = Get-Random -Minimum 50 -Maximum 5000
        currency         = "USD"
        country          = $CountryName
        city             = $City
        ip               = "$((Get-Random -Min 1 -Max 255)).$((Get-Random -Min 1 -Max 255)).$((Get-Random -Min 1 -Max 255)).$((Get-Random -Min 1 -Max 255))"
        user             = "fraud_bot_$(Get-Random -Min 1 -Max 99)"
        attempts         = Get-Random -Minimum 5 -Maximum 25
        card_type        = "Visa Platinum"
        status           = "DECLINED"
        fraud_score      = 0.99
        geoip            = @{
            location = "$RandomLat,$RandomLon"  # Format requis par Elasticsearch geo_point
        }
    } | ConvertTo-Json -Compress

    # 4. Envoi Robuste via Docker (kafka-console-producer)
    # On échappe les guillemets pour la ligne de commande
    $LogPayload = $LogData.Replace('"', '\"')
    
    $Command = "echo $LogPayload | kafka-console-producer --broker-list localhost:9092 --topic $TopicName > /dev/null 2>&1"
    Invoke-Expression "docker exec $ContainerName bash -c '$Command'"

    # 5. Feedback Visuel
    $AmountStr = "$($LogData | ConvertFrom-Json | Select -ExpandProperty amount)$"
    Write-Host " [$($_)/$Count] ALERTE $CountryName ($City) :: $AmountStr :: Geo[$RandomLat, $RandomLon]" -ForegroundColor Red

    # Pause variable pour simuler un trafic "humain/bot" rapide
    Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 100)
}

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host "   ATTAQUE TERMINÉE - VÉRIFIEZ LA CARTE KIBANA !" -ForegroundColor Green
Write-Host "==================================================================="