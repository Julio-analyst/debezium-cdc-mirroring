# ===================================================================
# CDC Pipeline Statistics and Performance Monitor  
# ===================================================================

param(
    [int]$RecordCount = 5000,
    [int]$BatchSize = 500,
    [switch]$DetailedAnalysis,
    [switch]$Export
)

function Write-Header {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n$Title" -ForegroundColor $Color
    Write-Host "Analyzing table sizes, row counts, and data distribution..." -ForegroundColor Gray
    Write-Host ""
}

function Write-TableHeader {
    param([string]$Header1, [string]$Header2, [string]$Header3, [string]$Header4 = "")
    if ($Header4) {
        Write-Host ("{0,-25} {1,-15} {2,-15} {3}" -f $Header1, $Header2, $Header3, $Header4) -ForegroundColor Yellow
    } else {
        Write-Host ("{0,-25} {1,-15} {2}" -f $Header1, $Header2, $Header3) -ForegroundColor Yellow
    }
    Write-Host ("=" * 80) -ForegroundColor Gray
}

function Write-TableRow {
    param([string]$Col1, [string]$Col2, [string]$Col3, [string]$Col4 = "", [string]$Color = "White")
    if ($Col4) {
        Write-Host ("{0,-25} {1,-15} {2,-15} {3}" -f $Col1, $Col2, $Col3, $Col4) -ForegroundColor $Color
    } else {
        Write-Host ("{0,-25} {1,-15} {2}" -f $Col1, $Col2, $Col3) -ForegroundColor $Color
    }
}

function Get-SystemPerformance {
    Write-Header "1. Real-Time System Performance"
    Write-Host "Current system resource utilization..." -ForegroundColor Gray
    Write-Host "Resource Usage by Workload Phase (latest per phase)" -ForegroundColor Gray
    Write-Host ("=" * 80) -ForegroundColor Gray

    # Capture performance in different phases
    $phases = @("BASELINE", "INSERT", "FINAL")
    
    foreach ($phase in $phases) {
        Write-Host "`nPhase: $phase" -ForegroundColor Cyan
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "$timestamp    $phase    N/A% CPU    N/A MB Used" -ForegroundColor Gray
        
        Write-Host "DOCKER STATS:" -ForegroundColor Yellow
        Write-TableHeader "NAME" "CPU %" "MEM USAGE / LIMIT"
        
        # Get real docker stats
        try {
            $dockerStats = docker stats --no-stream --format "{{.Name}};{{.CPUPerc}};{{.MemUsage}}" 2>$null
            
            if ($dockerStats) {
                $dockerStats -split "`n" | ForEach-Object {
                    if ($_ -match '^([^;]+);([^;]+);(.+)$') {
                        $containerName = $matches[1].Trim()
                        $cpuPercent = $matches[2].Trim()
                        $memUsage = $matches[3].Trim()
                        
                        # Show relevant containers
                        if ($containerName -match "kafka|postgres|connect|zookeeper|kafdrop") {
                            $shortName = $containerName -replace "debezium-cdc-mirroring-", "" -replace "tutorial-", ""
                            Write-TableRow $shortName $cpuPercent $memUsage "White"
                        }
                    }
                }
            } else {
                Write-Host "No docker containers found or docker not accessible" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error getting docker stats: $_" -ForegroundColor Red
        }
        
        Write-Host ("-" * 80) -ForegroundColor Gray
        if ($phase -ne "FINAL") { Start-Sleep -Seconds 2 }
    }
}

function Get-PostgresServerHealth {
    Write-Header "2. PostgreSQL Server Health Check" 
    Write-Host "Testing connection to PostgreSQL source and target servers..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        Write-Host "Source PostgreSQL Server Health:" -ForegroundColor Yellow
        
        # Test PostgreSQL source connection
        $sourceCheck = docker exec debezium-cdc-mirroring-postgres-1 echo "container_ok" 2>$null
        
        if ($sourceCheck -match "container_ok") {
            Write-Host "[OK] Source server responding to ping" -ForegroundColor Green
            
            # Get version info
            $versionResult = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT version();" 2>$null
            if ($versionResult -and $versionResult -match "PostgreSQL\s+([\d.]+)") {
                $version = $matches[1]
                Write-Host "[OK] Source version: PostgreSQL $version" -ForegroundColor Green
            }
            
            # Test query response time
            $startTime = Get-Date
            $dbTest = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT 1;" 2>$null
            $endTime = Get-Date
            
            if ($dbTest -and $dbTest.Trim() -eq "1") {
                $responseTime = ($endTime - $startTime).TotalMilliseconds
                Write-Host "[OK] Source query response time: $([math]::Round($responseTime, 2))ms" -ForegroundColor Green
            }
        } else {
            Write-Host "[FAIL] Source server not accessible" -ForegroundColor Red
        }
        
        Write-Host "`nTarget PostgreSQL Server Health:" -ForegroundColor Yellow
        
        # Test PostgreSQL target connection
        $targetCheck = docker exec debezium-cdc-mirroring-target-postgres-1 echo "container_ok" 2>$null
        
        if ($targetCheck -match "container_ok") {
            Write-Host "[OK] Target server responding to ping" -ForegroundColor Green
            
            # Get target version info
            $targetVersionResult = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT version();" 2>$null
            if ($targetVersionResult -and $targetVersionResult -match "PostgreSQL\s+([\d.]+)") {
                $targetVersion = $matches[1]
                Write-Host "[OK] Target version: PostgreSQL $targetVersion" -ForegroundColor Green
            }
            
            # Test target query response time
            $startTime = Get-Date
            $targetTest = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT 1;" 2>$null
            $endTime = Get-Date
            
            if ($targetTest -and $targetTest.Trim() -eq "1") {
                $responseTime = ($endTime - $startTime).TotalMilliseconds
                Write-Host "[OK] Target query response time: $([math]::Round($responseTime, 2))ms" -ForegroundColor Green
            }
        } else {
            Write-Host "[FAIL] Target server not accessible" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error checking PostgreSQL server health: $_" -ForegroundColor Red
        Write-Host "[FAIL] Connection failed" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Get-PostgresTableStats {
    Write-Header "3. PostgreSQL Table Statistics"
    Write-Host "Analyzing table sizes, row counts, and data distribution..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        Write-Host "Source Database Table Statistics:" -ForegroundColor Yellow
        Write-TableHeader "Table Name" "Rows" "Size" "Avg Row Size"
        
        # Get source database stats from PostgreSQL with explicit schema
        $sourceTables = @("customers", "products", "orders")
        
        foreach ($table in $sourceTables) {
            try {
                $sourceQuery = "SELECT COUNT(*) as total_rows, pg_size_pretty(pg_total_relation_size('$table')) as table_size, CASE WHEN COUNT(*) > 0 THEN ROUND(pg_total_relation_size('$table')::numeric / COUNT(*), 2) ELSE 0 END as avg_row_size_bytes FROM $table;"
                $result = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c $sourceQuery 2>$null
                
                if ($result -and $result.Trim() -and $result -match '\|') {
                    $parts = $result -split '\|' | ForEach-Object { $_.Trim() }
                    if ($parts.Length -ge 3 -and $parts[0] -match '^\d+$') {
                        $rows = $parts[0]
                        $size = $parts[1]
                        $avgSize = [math]::Round([double]$parts[2], 2)
                        
                        $color = switch ($table) {
                            "customers" { "Cyan" }
                            "products" { "Green" } 
                            "orders" { "Yellow" }
                            default { "White" }
                        }
                        
                        Write-TableRow $table $rows $size "${avgSize} B" $color
                    }
                } else {
                    Write-Host "  Could not retrieve stats for table: $table" -ForegroundColor Red
                }
                
            } catch {
                Write-Host "Error getting stats for source table $table : $_" -ForegroundColor Red
            }
        }
        
        Write-Host "`nTarget Database Table Statistics:" -ForegroundColor Yellow
        Write-TableHeader "Table Name" "Rows" "Size" "Avg Row Size"
        
        # Get target database stats
        try {
            $targetQuery = "SELECT COUNT(*) as total_rows, pg_size_pretty(pg_total_relation_size('orders')) as table_size, CASE WHEN COUNT(*) > 0 THEN ROUND(pg_total_relation_size('orders')::numeric / COUNT(*), 2) ELSE 0 END as avg_row_size_bytes FROM orders;"
            $targetResult = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -t -c $targetQuery 2>$null
            
            if ($targetResult -and $targetResult.Trim() -and $targetResult -match '\|') {
                $parts = $targetResult -split '\|' | ForEach-Object { $_.Trim() }
                if ($parts.Length -ge 3 -and $parts[0] -match '^\d+$') {
                    $rows = $parts[0]
                    $size = $parts[1] 
                    $avgSize = [math]::Round([double]$parts[2], 2)
                    Write-TableRow "orders_final" $rows $size "${avgSize} B" "Green"
                }
            } else {
                Write-Host "  Could not retrieve target table statistics" -ForegroundColor Red
            }
            
        } catch {
            Write-Host "Error getting target table statistics: $_" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error getting table statistics: $_" -ForegroundColor Red
    }
}

function Get-KafkaTopicsAnalysis {
    Write-Header "4. Kafka Topics and Messaging Analysis"
    Write-Host "Discovering Kafka topics and analyzing message throughput..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Get Kafka topics dengan multiple methods
        Write-Host "Available Kafka Topics:" -ForegroundColor Yellow
        
        # Method 1: Using kafka-topics.sh with proper path
        $topicsList = docker exec debezium-cdc-mirroring-kafka-1 bash -c "cd /opt/kafka && bin/kafka-topics.sh --bootstrap-server localhost:9092 --list" 2>$null
        
        if (-not $topicsList -or $topicsList -match "Timed out") {
            # Method 2: Try alternative kafka tools path
            $topicsList = docker exec debezium-cdc-mirroring-kafka-1 /usr/bin/kafka-topics --bootstrap-server localhost:9092 --list 2>$null
        }
        
        if (-not $topicsList -or $topicsList -match "Timed out") {
            # Method 3: Try with shorter timeout
            $topicsList = docker exec debezium-cdc-mirroring-kafka-1 timeout 5s /kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>$null
        }
        
        if ($topicsList -and $topicsList -notmatch "Timed out" -and $topicsList -notmatch "Error") {
            $topics = $topicsList -split "`n" | Where-Object { $_ -and $_ -notmatch "^__" -and $_.Trim() }
            if ($topics -and $topics.Count -gt 0) {
                foreach ($topic in $topics) {
                    if ($topic.Trim()) {
                        Write-Host "  - $($topic.Trim())" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "  No user topics found (only internal topics exist)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Could not retrieve Kafka topics - checking Kafka connectivity..." -ForegroundColor Yellow
            
            # Check if Kafka is actually running
            $kafkaStatus = docker exec debezium-cdc-mirroring-kafka-1 ps aux | grep kafka 2>$null
            if ($kafkaStatus) {
                Write-Host "  Kafka process is running but topics may not be initialized yet" -ForegroundColor Yellow
            } else {
                Write-Host "  Kafka service may not be fully started" -ForegroundColor Red
            }
        }
        
        Write-Host "`nCDC Table Analysis:" -ForegroundColor Yellow
        Write-TableHeader "Table" "Total Records" "Latest Activity"
        
        # Get actual record counts from both source and target
        try {
            # Source count with proper error handling
            $sourceCountCmd = "SELECT COUNT(*) FROM orders;"
            $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c $sourceCountCmd 2>$null
            $sourceCountNum = if ($sourceCount -and $sourceCount.Trim() -match '^\d+$') { $sourceCount.Trim() } else { "Error" }
            
            # Target count
            $targetCountCmd = "SELECT COUNT(*) FROM orders;"
            $targetCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -t -c $targetCountCmd 2>$null
            $targetCountNum = if ($targetCount -and $targetCount.Trim() -match '^\d+$') { $targetCount.Trim() } else { "Error" }
            
            $latestActivity = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Color coding based on count comparison
            $sourceColor = if ($sourceCountNum -match '^\d+$') { "Cyan" } else { "Red" }
            $targetColor = if ($targetCountNum -match '^\d+$') { "Green" } else { "Red" }
            
            Write-TableRow "orders_source" $sourceCountNum $latestActivity $sourceColor
            Write-TableRow "orders_target" $targetCountNum $latestActivity $targetColor
            
            # Show sync status
            if ($sourceCountNum -match '^\d+$' -and $targetCountNum -match '^\d+$') {
                $lag = [int]$sourceCountNum - [int]$targetCountNum
                if ($lag -eq 0) {
                    Write-Host "`n  Sync Status: SYNCHRONIZED" -ForegroundColor Green
                } elseif ($lag -gt 0) {
                    Write-Host "`n  Sync Status: TARGET LAG ($lag records behind)" -ForegroundColor Yellow
                } else {
                    Write-Host "`n  Sync Status: INCONSISTENT (target ahead by $([math]::Abs($lag)) records)" -ForegroundColor Red
                }
            }
            
        } catch {
            Write-Host "Error getting record counts: $_" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error getting Kafka analysis: $_" -ForegroundColor Red
    }
}

function Get-CDCOperationsBreakdown {
    Write-Host "`nOperation Breakdown for orders_final:" -ForegroundColor Yellow
    Write-TableHeader "Operation" "Count" "Percentage"
    
    try {
        # Get REAL operation stats from PostgreSQL target
        $statsQuery = "SELECT n_tup_ins as inserts, n_tup_upd as updates, n_tup_del as deletes, (n_tup_ins + n_tup_upd + n_tup_del) as total FROM pg_stat_user_tables WHERE schemaname = 'public' AND relname = 'orders';"
        
        $statsResult = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -t -c $statsQuery 2>$null
        
        if ($statsResult -and $statsResult -match '\|') {
            $parts = $statsResult -split '\|' | ForEach-Object { $_.Trim() }
            if ($parts.Length -ge 4) {
                $inserts = [int]$parts[0]
                $updates = [int]$parts[1]
                $deletes = [int]$parts[2]
                $total = [int]$parts[3]
                
                if ($total -gt 0) {
                    $insertPercent = [math]::Round(($inserts / $total) * 100, 2)
                    $updatePercent = [math]::Round(($updates / $total) * 100, 2)
                    $deletePercent = [math]::Round(($deletes / $total) * 100, 2)
                    
                    Write-TableRow "CREATE" $inserts "$insertPercent%" "Green"
                    Write-TableRow "UPDATE" $updates "$updatePercent%" "Yellow"
                    Write-TableRow "DELETE" $deletes "$deletePercent%" "Red"
                } else {
                    Write-Host "No operations recorded yet in pg_stat_user_tables" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "Could not retrieve operation statistics from target database" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Error getting operation breakdown: $_" -ForegroundColor Red
    }
    
    # Get recent activity from test logs  
    Write-Host "`nRecent Activity (From Test Logs):" -ForegroundColor Yellow
    
    $recentLogs = Get-ChildItem "testing-results" -Filter "*insert*" | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($recentLogs) {
        foreach ($log in $recentLogs) {
            $logContent = Get-Content $log.FullName -ErrorAction SilentlyContinue
            $records = "Unknown"
            $duration = "Unknown"
            
            foreach ($line in $logContent) {
                if ($line -match "Total Records Attempted:\s*(\d+)") {
                    $records = $matches[1]
                }
                if ($line -match "Test Duration:\s*(.+)") {
                    $duration = $matches[1]
                }
            }
            
            Write-Host "  CREATE - $records operations ($duration)" -ForegroundColor Green
        }
    } else {
        Write-Host "  No recent test logs found in testing-results directory" -ForegroundColor Gray
    }
}

function Get-CDCOperationsAnalysis {
    Write-Header "5. CDC Operations Analysis"
    Write-Host "Analyzing CDC operations and sync performance..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        Write-Host "CDC Connector Status:" -ForegroundColor Yellow
        
        # Check multiple possible Kafka Connect containers
        $connectContainers = @("debezium-cdc-mirroring-connect-1", "tutorial-connect-1", "connect-1")
        $connectFound = $false
        
        foreach ($container in $connectContainers) {
            $containerExists = docker ps --filter "name=$container" --format "{{.Names}}" 2>$null
            if ($containerExists) {
                Write-Host "Found Kafka Connect container: $container" -ForegroundColor Green
                
                # Test Connect API
                $connectStatus = docker exec $container curl -s --connect-timeout 5 http://localhost:8083/connectors 2>$null
                
                if ($connectStatus -and $connectStatus -notmatch "Connection refused" -and $connectStatus -notmatch "curl:") {
                    try {
                        $connectors = $connectStatus | ConvertFrom-Json -ErrorAction SilentlyContinue
                        if ($connectors -and $connectors.Count -gt 0) {
                            Write-Host "Active Connectors:" -ForegroundColor Green
                            foreach ($connector in $connectors) {
                                Write-Host "  - $connector" -ForegroundColor Green
                            }
                        } else {
                            Write-Host "No active connectors found" -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host "Could not parse connector list" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Kafka Connect API not responding on port 8083" -ForegroundColor Red
                }
                
                $connectFound = $true
                break
            }
        }
        
        if (-not $connectFound) {
            Write-Host "No Kafka Connect container found" -ForegroundColor Red
        }
        
        Write-Host "`nReplication Lag Analysis:" -ForegroundColor Yellow
        Write-TableHeader "Database" "Record Count" "Lag Status"
        
        # Compare source vs target record counts with better error handling
        try {
            $sourceCountCmd = "SELECT COUNT(*) FROM orders;"
            $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c $sourceCountCmd 2>$null
            $sourceNum = if ($sourceCount -and $sourceCount.Trim() -match '^\d+$') { [int]$sourceCount.Trim() } else { $null }
            
            $targetCountCmd = "SELECT COUNT(*) FROM orders;"
            $targetCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -t -c $targetCountCmd 2>$null
            $targetNum = if ($targetCount -and $targetCount.Trim() -match '^\d+$') { [int]$targetCount.Trim() } else { $null }
            
            if ($sourceNum -ne $null -and $targetNum -ne $null) {
                $lag = $sourceNum - $targetNum
                
                Write-TableRow "Source" $sourceNum.ToString() "Reference" "Cyan"
                
                $lagStatus = if ($lag -eq 0) { "SYNCHRONIZED" }
                            elseif ($lag -gt 0 -and $lag -lt 10) { "MINOR LAG ($lag)" }
                            elseif ($lag -gt 0) { "SIGNIFICANT LAG ($lag)" }
                            else { "AHEAD BY $([math]::Abs($lag))" }
                
                $lagColor = if ($lag -eq 0) { "Green" }
                           elseif ($lag -gt 0 -and $lag -lt 10) { "Yellow" }
                           elseif ($lag -gt 0) { "Red" }
                           else { "Red" }
                
                Write-TableRow "Target" $targetNum.ToString() $lagStatus $lagColor
                
                # Overall replication status
                Write-Host "`nOverall Replication Status:" -ForegroundColor Yellow
                if ($lag -eq 0) {
                    Write-Host "  ✓ Databases are synchronized" -ForegroundColor Green
                } elseif ($lag -gt 0 -and $lag -lt 10) {
                    Write-Host "  ⚠ Minor replication lag detected" -ForegroundColor Yellow
                } elseif ($lag -gt 0) {
                    Write-Host "  ✗ Significant replication lag - investigate CDC pipeline" -ForegroundColor Red
                } else {
                    Write-Host "  ✗ Data inconsistency - target has more records than source" -ForegroundColor Red
                }
                
            } else {
                Write-TableRow "Source" "Connection Error" "N/A" "Red"
                Write-TableRow "Target" "Connection Error" "N/A" "Red"
                Write-Host "`n  Error: Could not connect to one or both databases" -ForegroundColor Red
            }
            
        } catch {
            Write-Host "Error analyzing replication lag: $_" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error analyzing CDC operations: $_" -ForegroundColor Red
    }
}

function Get-ContainerHealthStatus {
    Write-Header "6. Container Health and Status"
    Write-Host "Checking Docker container health and connectivity..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        Write-Host "Container Health Status:" -ForegroundColor Yellow
        Write-TableHeader "Container" "Status" "Ports" "Health"
        
        # Get all containers related to our stack
        $allContainers = docker ps -a --format "table {{.Names}};{{.Status}};{{.Ports}}" --filter name=debezium-cdc-mirroring 2>$null
        
        $totalContainers = 0
        $healthyContainers = 0
        
        if ($allContainers) {
            $allContainers -split "`n" | ForEach-Object {
                if ($_ -match '^([^;]+);([^;]+);(.*)$') {
                    $containerName = $matches[1].Trim()
                    $status = $matches[2].Trim()
                    $ports = $matches[3].Trim()
                    
                    if ($containerName -match "debezium-cdc-mirroring") {
                        $totalContainers++
                        $shortName = $containerName -replace "debezium-cdc-mirroring-", ""
                        $healthStatus = if ($status -match "Up") { 
                            $healthyContainers++
                            "[OK]" 
                        } else { 
                            "[FAIL]" 
                        }
                        $healthColor = if ($status -match "Up") { "Green" } else { "Red" }
                        
                        Write-TableRow $shortName $status $ports $healthStatus $healthColor
                    }
                }
            }
        }
        
        # Also check tutorial containers (if any)
        $tutorialContainers = docker ps -a --format "table {{.Names}};{{.Status}};{{.Ports}}" --filter name=tutorial 2>$null
        
        if ($tutorialContainers) {
            $tutorialContainers -split "`n" | ForEach-Object {
                if ($_ -match '^([^;]+);([^;]+);(.*)$') {
                    $containerName = $matches[1].Trim()
                    $status = $matches[2].Trim()
                    $ports = $matches[3].Trim()
                    
                    $totalContainers++
                    $shortName = $containerName -replace "tutorial-", ""
                    $healthStatus = if ($status -match "Up") { 
                        $healthyContainers++
                        "[OK]" 
                    } else { 
                        "[FAIL]" 
                    }
                    $healthColor = if ($status -match "Up") { "Green" } else { "Red" }
                    
                    Write-TableRow $shortName $status $ports $healthStatus $healthColor
                }
            }
        }
        
        Write-Host ("=" * 80) -ForegroundColor Gray
        
        # Overall health summary
        if ($totalContainers -gt 0) {
            $healthPercentage = [math]::Round(($healthyContainers / $totalContainers) * 100, 0)
            $healthColor = if ($healthPercentage -eq 100) { "Green" } elseif ($healthPercentage -ge 80) { "Yellow" } else { "Red" }
            Write-Host "`nOverall Health: $healthyContainers/$totalContainers containers healthy ($healthPercentage percent)" -ForegroundColor $healthColor
        } else {
            Write-Host "`nNo containers found in the current stack" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error checking container health: $_" -ForegroundColor Red
    }
}

function Get-PerformanceSummary {
    Write-Header "7. Performance Summary and Recommendations"
    Write-Host "Analyzing overall system performance and providing recommendations..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        Write-Host "Performance Summary:" -ForegroundColor Yellow
        Write-Host "System Health Checks:" -ForegroundColor Yellow
        
        # Check PostgreSQL health
        $sourceHealth = docker exec debezium-cdc-mirroring-postgres-1 echo "ok" 2>$null
        $targetHealth = docker exec debezium-cdc-mirroring-target-postgres-1 echo "ok" 2>$null
        $sourceStatus = if ($sourceHealth -match "ok") { "OK" } else { "FAIL" }
        $targetStatus = if ($targetHealth -match "ok") { "OK" } else { "FAIL" }
        
        Write-Host "  [$sourceStatus] PostgreSQL Source: $sourceStatus" -ForegroundColor $(if($sourceStatus -eq "OK"){"Green"}else{"Red"})
        Write-Host "  [$targetStatus] PostgreSQL Target: $targetStatus" -ForegroundColor $(if($targetStatus -eq "OK"){"Green"}else{"Red"})
        
        # Check Kafka health
        $kafkaHealth = docker exec debezium-cdc-mirroring-kafka-1 echo "ok" 2>$null
        $kafkaStatus = if ($kafkaHealth -match "ok") { "OK" } else { "FAIL" }
        Write-Host "  [$kafkaStatus] Kafka: $kafkaStatus" -ForegroundColor $(if($kafkaStatus -eq "OK"){"Green"}else{"Red"})
        
        # Check Connect health
        $connectHealth = docker exec debezium-cdc-mirroring-connect-1 echo "ok" 2>$null
        $connectStatus = if ($connectHealth -match "ok") { "OK" } else { "FAIL" }
        Write-Host "  [$connectStatus] Kafka Connect: $connectStatus" -ForegroundColor $(if($connectStatus -eq "OK"){"Green"}else{"Red"})
        
        Write-Host "`nRecommendations:" -ForegroundColor Yellow
        
        # Data consistency check
        $sourceCountQuery = "SELECT COUNT(*) FROM orders;"
        $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c $sourceCountQuery 2>$null
        $targetCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -t -c $sourceCountQuery 2>$null
        
        if ($sourceCount -and $targetCount) {
            $sourceNum = [int]$sourceCount.Trim()
            $targetNum = [int]$targetCount.Trim()
            $lag = $sourceNum - $targetNum
            
            if ($lag -eq 0) {
                Write-Host "  OK - Data is synchronized between source and target" -ForegroundColor Green
            } elseif ($lag -gt 0) {
                Write-Host "  WARN - Target is behind source by $lag records - check CDC connector" -ForegroundColor Yellow
            } else {
                Write-Host "  ERROR - Target has more records than source - data integrity issue" -ForegroundColor Red
            }
        }
        
        # Container health recommendations
        $runningContainers = docker ps --filter name=debezium-cdc-mirroring --format "{{.Names}}" 2>$null
        if ($runningContainers) {
            $containerCount = ($runningContainers -split "`n" | Where-Object { $_ }).Count
            if ($containerCount -lt 6) {
                Write-Host "  WARN - Some containers may be missing - run 'docker-compose up -d' to ensure all services are running" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nPerformance Monitoring Complete!" -ForegroundColor Green
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
        Write-Host "PostgreSQL Source: localhost:5432" -ForegroundColor Gray
        Write-Host "PostgreSQL Target: localhost:5433" -ForegroundColor Gray
        Write-Host "Use -DetailedAnalysis flag for extended metrics" -ForegroundColor Gray
        Write-Host "Use -Export flag to save report to file" -ForegroundColor Gray
        
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "Export performance report: .\scripts\cdc-fixed-monitor.ps1 -Export" -ForegroundColor Gray
        
    } catch {
        Write-Host "Error generating performance summary: $_" -ForegroundColor Red
    }
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

Clear-Host
Write-Host "CDC Pipeline Statistics and Performance Monitor" -ForegroundColor Magenta
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "PostgreSQL Source: localhost:5432" -ForegroundColor Gray
Write-Host "PostgreSQL Target: localhost:5433" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Gray

# Execute all monitoring functions
Get-SystemPerformance
Get-PostgresServerHealth 
Get-PostgresTableStats
Get-KafkaTopicsAnalysis
Get-CDCOperationsBreakdown
Get-CDCOperationsAnalysis
Get-ContainerHealthStatus
Get-PerformanceSummary

Write-Host "`nStatistics analysis completed!" -ForegroundColor Green
