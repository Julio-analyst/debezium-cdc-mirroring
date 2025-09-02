# Simple Insert & Docker Stats Capture (PowerShell)
# Author: GitHub Copilot
# Date: August 2025

$null = Import-Module powershell-yaml
# --- CONFIGURATION ---

# --- CONFIGURATION ---
$configPath = "config.yaml"
if (Test-Path $configPath) {
    $config = (Get-Content $configPath | Out-String | ConvertFrom-Yaml)
} else {
    $config = @{ database = @{ host = 'localhost'; port = 5432; user = 'postgres'; password = 'postgres'; database = 'inventory' } }
}

$recordCount = 100000
$batchSize = 1000
$delayBetweenBatches = 1
$containerNames = @(
    'debezium-cdc-mirroring-postgres-1',
    'debezium-cdc-mirroring-kafka-1',
    'debezium-cdc-mirroring-zookeeper-1',
    'debezium-cdc-mirroring-target-postgres-1',
    'tutorial-connect-1'
)

$results = @{}


function Get-DockerStats {
    param([string[]]$Names)
    $stats = @{}
    foreach ($name in $Names) {
        $result = docker stats --no-stream --format '{{.Name}};{{.CPUPerc}};{{.MemUsage}};{{.MemPerc}}' $name
        if ($result) {
            $parts = $result -split ';'
            $stats[$name] = @{ 'cpu' = $parts[1]; 'mem' = $parts[2]; 'mem%' = $parts[3]; 'timestamp' = (Get-Date).ToString('o') }
        } else {
            $stats[$name] = @{ 'error' = 'not found'; 'timestamp' = (Get-Date).ToString('o') }
        }
    }
    return $stats
}

function Get-DockerLogs {
    param([string[]]$Names, [int]$Lines = 20)
    $logs = @{}
    foreach ($name in $Names) {
        $result = docker logs --tail $Lines $name 2>&1
        $logs[$name] = $result
    }
    return $logs
}

function Save-Results {
    param($data)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $dir = "testing-results"
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $file = "$dir/simple-insert-docker-monitor_$timestamp.json"
    $json = $data | ConvertTo-Json -Depth 6
    Set-Content -Path $file -Value $json
    Write-Host "Results saved to $file"
}


# --- PHASE 1: BASELINE ---
Write-Host "[PHASE 1] BASELINE"
$phase1 = @{}
$phase1['phase'] = 'baseline'
$phase1['timestamp'] = (Get-Date).ToString('o')
$phase1['docker_stats'] = Get-DockerStats -Names $containerNames
$phase1['docker_logs'] = Get-DockerLogs -Names $containerNames
$results['baseline'] = $phase1

# --- PHASE 2: INSERT ---
Write-Host "[PHASE 2] INSERT"
$phase2 = @{}
$phase2['phase'] = 'insert'
$phase2['timestamp'] = (Get-Date).ToString('o')
$phase2['docker_stats_before'] = Get-DockerStats -Names $containerNames
$phase2['docker_logs_before'] = Get-DockerLogs -Names $containerNames

# --- INSERT OPERATION ---
$insertResults = @()
$psqlCmd = "psql -h $($config.database.host) -p $($config.database.port) -U $($config.database.user) -d $($config.database.database) -c"
$env:PGPASSWORD = $config.database.password
for ($i = 1; $i -le $recordCount; $i += $batchSize) {
    $batchEnd = [Math]::Min($i + $batchSize - 1, $recordCount)
    $currentBatchSize = $batchEnd - $i + 1
    $batchStartTime = Get-Date
    # Contoh insert: (ganti dengan query insert sesuai skema Anda)
    $query = "INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) SELECT CURRENT_DATE, 1001, 1, 101 FROM generate_series(1, $currentBatchSize);"
    $output = & $psqlCmd $query
    $batchEndTime = Get-Date
    $duration = ($batchEndTime - $batchStartTime).TotalSeconds
    $insertResults += @{ batch = ($i / $batchSize); start = $batchStartTime.ToString('o'); end = $batchEndTime.ToString('o'); duration = $duration; output = $output }
    # Capture docker stats/logs di tengah insert
    $phase2["docker_stats_batch_$i"] = Get-DockerStats -Names $containerNames
    $phase2["docker_logs_batch_$i"] = Get-DockerLogs -Names $containerNames
    Start-Sleep -Seconds $delayBetweenBatches
}
$phase2['insert_results'] = $insertResults
$results['insert'] = $phase2

# --- PHASE 3: FINAL ---
Write-Host "[PHASE 3] FINAL"
$phase3 = @{}
$phase3['phase'] = 'final'
$phase3['timestamp'] = (Get-Date).ToString('o')
$phase3['docker_stats'] = Get-DockerStats -Names $containerNames
$phase3['docker_logs'] = Get-DockerLogs -Names $containerNames
$results['final'] = $phase3

Save-Results $results
Write-Host "Test completed."
