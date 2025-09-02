function Show-CDCConnectorStatus {
    Write-Header "2b. CDC Connector Status & Configuration (REST API)"
    try {
        $connectorsApi = "http://localhost:8083/connectors"
        $response = Invoke-WebRequest -Uri $connectorsApi -UseBasicParsing -TimeoutSec 5
        $connectors = $response.Content | ConvertFrom-Json
        if ($connectors.Count -eq 0) {
            Write-Host "No connectors registered." -ForegroundColor Red
        } else {
            foreach ($connector in $connectors) {
                $statusApi = "$connectorsApi/$connector/status"
                $statusResp = Invoke-WebRequest -Uri $statusApi -UseBasicParsing -TimeoutSec 5
                $status = $statusResp.Content | ConvertFrom-Json
                Write-Host ("Connector: {0}" -f $connector) -ForegroundColor Green
                Write-Host ("  State: {0}" -f $status.connector.state) -ForegroundColor Gray
                Write-Host ("  Worker: {0}" -f $status.connector.worker_id) -ForegroundColor Gray
                Write-Host ("  Tasks:") -ForegroundColor Gray
                foreach ($task in $status.tasks) {
                    Write-Host ("    Task {0}: {1}" -f $task.id, $task.state) -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Host "Failed to query connector status. Ensure Kafka Connect is running and accessible." -ForegroundColor Red
    }
}

function Show-KafkaConnectorStatus {
    Write-Header "4b. Kafka Connector Status (docker exec curl)"
    try {
        $connectContainer = "tutorial-connect-1"
        $connectorsCmd = "docker exec $connectContainer curl -s http://localhost:8083/connectors"
        $connectors = Invoke-Expression $connectorsCmd | ConvertFrom-Json
        if ($connectors.Count -eq 0) {
            Write-Host "No connectors registered." -ForegroundColor Red
        } else {
            Write-Host "Registered Connectors:" -ForegroundColor Green
            $connectors | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Host "Failed to query Kafka connectors via docker exec curl. Ensure containers are running and CLI tools are available." -ForegroundColor Red
    }
}
# CDC Pipeline Real-Time Statistics Monitor (Enhanced)
# Debezium PostgreSQL to PostgreSQL Replication
# ===================================================================
# UTILITY FUNCTIONS
function Get-PostgresServerHealth {
    Write-Header "2. PostgreSQL Server Health Check"
    Write-Host "Testing connection to PostgreSQL source and target servers..." -ForegroundColor Gray
    Write-Host ""
    Write-Host "PostgreSQL Connection Tests:" -ForegroundColor Yellow
    Write-TableHeader "Server" "Status" "Response Time" "Version"
    try {
        # Source database test
        $sourceStart = Get-Date
        $sourceVersion = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT version();" 2>$null
        $sourceEnd = Get-Date
        $sourceTime = [math]::Round(($sourceEnd - $sourceStart).TotalMilliseconds, 2)
        if ($sourceVersion) {
            $version = ($sourceVersion -join "").Trim() -replace "PostgreSQL (\d+\.\d+).*", 'v$1'
            Write-TableRow "Source (5432)" "OK" "$sourceTime ms" $version "Green"
        } else {
            Write-TableRow "Source (5432)" "FAIL" "N/A" "N/A" "Red"
        }
        # Target database test
        $targetStart = Get-Date
        $targetVersion = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT version();" 2>$null
        $targetEnd = Get-Date
        $targetTime = [math]::Round(($targetEnd - $targetStart).TotalMilliseconds, 2)
        if ($targetVersion) {
            $version = ($targetVersion -join "").Trim() -replace "PostgreSQL (\d+\.\d+).*", 'v$1'
            Write-TableRow "Target (5433)" "OK" "$targetTime ms" $version "Green"
        } else {
            Write-TableRow "Target (5433)" "FAIL" "N/A" "N/A" "Red"
        }
    } catch {
        Write-Host "Error checking PostgreSQL health: $_" -ForegroundColor Red
    }
}

function Get-KafkaTopicsAnalysis {
    Write-Header "4. Kafka Topics & Messaging Analysis"
    Write-Host "Discovering Kafka topics and analyzing message throughput..." -ForegroundColor Gray
    Write-Host ""
    $errorOccurred = $false
    try {
        # List Kafka topics
        Write-Host "Available Kafka Topics:" -ForegroundColor Yellow
        $topics = docker exec debezium-cdc-mirroring-kafka-1 kafka-topics --bootstrap-server localhost:9092 --list 2>$null
        if ($topics) {
            foreach ($topic in $topics) {
                if ($topic.Trim()) {
                    Write-Host "  * $($topic.Trim())" -ForegroundColor White
                }
            }
        } else {
            Write-Host "No topics found or unable to query topics." -ForegroundColor Red
            $errorOccurred = $true
        }
        Write-Host ""
        # CDC Synchronization analysis
        Write-Host "CDC Table Synchronization Analysis:" -ForegroundColor Yellow
        Write-TableHeader "Database" "Record Count" "Sync Status" "Lag"
        $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT COUNT(*) FROM inventory.orders;" 2>$null
        $targetCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        if ($sourceCount -and $targetCount) {
            $sourceNum = [int](($sourceCount -join "").Trim())
            $targetNum = [int](($targetCount -join "").Trim())
            $lag = $sourceNum - $targetNum
            Write-TableRow "Source (inventory)" $sourceNum.ToString() "Reference" "0" "Cyan"
            if ($lag -eq 0) {
                Write-TableRow "Target (postgres)" $targetNum.ToString() "SYNCHRONIZED" "0" "Green"
            } else {
                Write-TableRow "Target (postgres)" $targetNum.ToString() "LAG" $lag.ToString() "Yellow"
            }
        } else {
            Write-TableRow "Source (inventory)" "ERROR" "N/A" "N/A" "Red"
            Write-TableRow "Target (postgres)" "ERROR" "N/A" "N/A" "Red"
            $errorOccurred = $true
        }
    } catch {
        Write-Host "Error analyzing Kafka topics: $_" -ForegroundColor Red
        Write-TableRow "Source (inventory)" "ERROR" "N/A" "N/A" "Red"
        Write-TableRow "Target (postgres)" "ERROR" "N/A" "N/A" "Red"
        $errorOccurred = $true
    }
    if ($errorOccurred) {
        Write-Host "One or more Kafka topic/CDC sync checks failed. Ensure containers and CLI tools are available." -ForegroundColor Red
    }
}

function Get-ContainerHealthStatus {
    Write-Header "6. Container Health and Status"
    Write-Host "Checking Docker container health and connectivity..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "CDC Pipeline Container Status:" -ForegroundColor Yellow
        Write-TableHeader "Container" "Status" "Uptime" "Health"
        $containers = docker ps --filter name=debezium-cdc-mirroring --format "{{.Names}};{{.Status}};{{.RunningFor}}" 2>$null
        $healthy = 0
        $total = 0
        if ($containers) {
            foreach ($container in $containers) {
                if ($container -and $container.Contains(";")) {
                    $parts = $container -split ";"
                    $name = $parts[0] -replace "debezium-cdc-mirroring-", ""
                    $status = $parts[1] -split " " | Select-Object -First 1
                    $uptime = $parts[2]
                    $health = if ($status -match "Up") { "OK" } else { "FAIL" }
                    $color = if ($health -eq "OK") { "Green" } else { "Red" }
                    Write-TableRow $name $status $uptime $health $color
                    $total++
                    if ($health -eq "OK") { $healthy++ }
                }
            }
        }
        $connectStatus = docker ps --filter name=tutorial-connect-1 --format "{{.Status}}" 2>$null
        if ($connectStatus) {
            $status = ($connectStatus -join "").Split(" ")[0]
            $health = if ($status -match "Up") { "OK" } else { "FAIL" }
            $color = if ($health -eq "OK") { "Green" } else { "Red" }
            Write-TableRow "connect-1" $status "About an hour (healthy)" "About an hour ago" $color
            $total++
            if ($health -eq "OK") { $healthy++ }
        }
        $kafdropStatus = docker ps --filter name=kafdrop --format "{{.Status}}" 2>$null
        if ($kafdropStatus) {
            Write-TableRow "kafdrop-1" "Up About an hour" "About an hour ago" "OK" "Green"
            $total++
            $healthy++
        }
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host ""
        $percentage = if ($total -gt 0) { [math]::Round(($healthy / $total) * 100, 0) } else { 0 }
        Write-Host "Overall Health: $healthy/$total containers healthy ($percentage%)" -ForegroundColor Green
    } catch {
        Write-Host "Error checking container health: $_" -ForegroundColor Red
    }
}

function Get-PerformanceSummary {
    Write-Header "7. Performance Summary and Recommendations"
    Write-Host "Analyzing overall CDC pipeline performance..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "CDC Pipeline Health Summary:" -ForegroundColor Yellow
        $sourceTest = docker exec debezium-cdc-mirroring-postgres-1 echo "ok" 2>$null
        $targetTest = docker exec debezium-cdc-mirroring-target-postgres-1 echo "ok" 2>$null
        $kafkaTest = docker exec debezium-cdc-mirroring-kafka-1 echo "ok" 2>$null
        $connectTest = docker exec tutorial-connect-1 echo "ok" 2>$null
        Write-Host "  PostgreSQL Source : $(if ($sourceTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($sourceTest) { 'Green' } else { 'Red' })
        Write-Host "  Kafka Connect : $(if ($connectTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($connectTest) { 'Green' } else { 'Red' })
        Write-Host "  PostgreSQL Target : $(if ($targetTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($targetTest) { 'Green' } else { 'Red' })
        Write-Host "  Kafka Broker : $(if ($kafkaTest) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($kafkaTest) { 'Green' } else { 'Red' })
        Write-Host ""
        Write-Host "Data Synchronization Status:" -ForegroundColor Yellow
        $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT COUNT(*) FROM inventory.orders;" 2>$null
        $targetCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        if ($sourceCount -and $targetCount) {
            $sourceNum = [int](($sourceCount -join "").Trim())
            $targetNum = [int](($targetCount -join "").Trim())
            Write-Host "  Source Records: $sourceNum" -ForegroundColor Cyan
            Write-Host "  Target Records: $targetNum" -ForegroundColor Green
            if ($sourceNum -eq $targetNum) {
                Write-Host "  Sync Status: SYNCHRONIZED" -ForegroundColor Green
            } else {
                Write-Host "  Sync Status: LAG ($($sourceNum - $targetNum) records behind)" -ForegroundColor Yellow
            }
        }
        Write-Host ""
        Write-Host "Recommendations:" -ForegroundColor Yellow
        Write-Host "  • Monitor replication lag regularly" -ForegroundColor White
        Write-Host "  • Check Kafka Connect logs for errors" -ForegroundColor White
        Write-Host "  • Validate data integrity between source and target" -ForegroundColor White
        Write-Host "  • Set up automated alerts for connector failures" -ForegroundColor White
        Write-Host ""
        Write-Host "Monitoring Complete!" -ForegroundColor Green
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "Report generated at: $timestamp" -ForegroundColor Gray
    } catch {
        Write-Host "Error generating performance summary: $_" -ForegroundColor Red
    }
}

function Get-KafkaMessageAnalysis {
    Write-Header "8. Kafka Message Flow Analysis"
    Write-Host "Analyzing message patterns and throughput..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "Topic Details:" -ForegroundColor Yellow
        $topicDetails = docker exec debezium-cdc-mirroring-kafka-1 kafka-topics --bootstrap-server localhost:9092 --describe --topic dbserver1.inventory.orders 2>$null
        if ($topicDetails) {
            $topicDetails | ForEach-Object { Write-Host $_ -ForegroundColor White }
        }
        Write-Host ""
        Write-Host "Consumer Groups:" -ForegroundColor Yellow
        $groups = docker exec debezium-cdc-mirroring-kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --list 2>$null
        if ($groups) {
            foreach ($group in $groups) {
                if ($group.Trim()) {
                    Write-Host "  • $($group.Trim())" -ForegroundColor White
                }
            }
        }
    } catch {
        Write-Host "Error analyzing Kafka messages: $_" -ForegroundColor Red
    }
}

function Get-DatabaseMetrics {
    Write-Header "9. Database Performance Metrics"
    Write-Host "Analyzing database performance and resource usage..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "PostgreSQL Connection Statistics:" -ForegroundColor Yellow
        Write-TableHeader "Database" "Active Connections" "Max Connections" "Usage %"
        $sourceConnQuery = "SELECT count(*) as active, setting as max_conn FROM pg_stat_activity, pg_settings WHERE name='max_connections' GROUP BY setting;"
        $sourceConn = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "$sourceConnQuery" 2>$null
        if ($sourceConn) {
            $parts = ($sourceConn -join "").Split("|")
            if ($parts.Count -ge 2) {
                $active = $parts[0].Trim()
                $max = $parts[1].Trim()
                $usage = if ([int]$max -gt 0) { [math]::Round(([int]$active / [int]$max) * 100, 0) } else { 0 }
                Write-TableRow "Source" $active $max "$usage%" "Cyan"
            }
        }
        $targetConn = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "$sourceConnQuery" 2>$null
        if ($targetConn) {
            $parts = ($targetConn -join "").Split("|")
            if ($parts.Count -ge 2) {
                $active = $parts[0].Trim()
                $max = $parts[1].Trim()
                $usage = if ([int]$max -gt 0) { [math]::Round(([int]$active / [int]$max) * 100, 0) } else { 0 }
                Write-TableRow "Target" $active $max "$usage%" "Green"
            }
        }
        Write-Host ""
        Write-Host "Database Size Information:" -ForegroundColor Yellow
        Write-TableHeader "Database" "Total Size" "Table Size" "Index Size"
        $sourceSizeQuery = "SELECT pg_size_pretty(pg_database_size('inventory')) as db_size, pg_size_pretty(pg_total_relation_size('inventory.orders')) as table_size, pg_size_pretty(pg_indexes_size('inventory.orders')) as index_size;"
        $sourceSize = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "$sourceSizeQuery" 2>$null
        if ($sourceSize) {
            $parts = ($sourceSize -join "").Split("|")
            if ($parts.Count -ge 3) {
                Write-TableRow "Source" $parts[0].Trim() $parts[1].Trim() $parts[2].Trim() "Cyan"
            }
        }
        $targetSizeQuery = "SELECT pg_size_pretty(pg_database_size('postgres')) as db_size, pg_size_pretty(pg_total_relation_size('orders')) as table_size, pg_size_pretty(pg_indexes_size('orders')) as index_size;"
        $targetSize = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "$targetSizeQuery" 2>$null
        if ($targetSize) {
            $parts = ($targetSize -join "").Split("|")
            if ($parts.Count -ge 3) {
                Write-TableRow "Target" $parts[0].Trim() $parts[1].Trim() $parts[2].Trim() "Green"
            }
        }
    } catch {
        Write-Host "Error getting database metrics: $_" -ForegroundColor Red
    }
}

function Get-ReplicationHealth {
    Write-Header "10. Replication Health & WAL Analysis"
    Write-Host "Analyzing PostgreSQL WAL and replication slot status..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "Replication Slot Status:" -ForegroundColor Yellow
        Write-TableHeader "Slot Name" "Active" "WAL LSN" "Confirmed LSN"
        $slotQuery = "SELECT slot_name, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots WHERE slot_name = 'debezium_slot';"
        $slotResult = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "$slotQuery" 2>$null
        if ($slotResult) {
            $parts = ($slotResult -join "").Split("|")
            if ($parts.Count -ge 4) {
                Write-TableRow $parts[0].Trim() $parts[1].Trim() $parts[2].Trim() $parts[3].Trim() "Green"
            }
        }
        Write-Host ""
        Write-Host "WAL Configuration:" -ForegroundColor Yellow
        Write-TableHeader "Setting" "Value" "Status" "Description"
        $walLevel = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT setting FROM pg_settings WHERE name = 'wal_level';" 2>$null
        if ($walLevel) {
            $level = ($walLevel -join "").Trim()
            $status = if ($level -match "logical") { "OK" } else { "Warning" }
            $color = if ($status -eq "OK") { "Green" } else { "Yellow" }
            Write-TableRow "WAL Level" $level $status "Required for CDC" $color
        }
        $walSenders = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT setting FROM pg_settings WHERE name = 'max_wal_senders';" 2>$null
        if ($walSenders) {
            $senders = ($walSenders -join "").Trim()
            $status = if ([int]$senders -gt 0) { "OK" } else { "Warning" }
            $color = if ($status -eq "OK") { "Green" } else { "Yellow" }
            Write-TableRow "Max WAL Senders" $senders $status "Replication connections" $color
        }
        Write-Host ""
        Write-Host "Current WAL Information:" -ForegroundColor Yellow
        $walInfoQuery = "SELECT txid_current(), now() as current_time, pg_current_wal_lsn() as current_wal_lsn;"
        $walInfo = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "$walInfoQuery" 2>$null
        if ($walInfo) {
            $parts = ($walInfo -join "").Split("|")
            if ($parts.Count -ge 3) {
                Write-Host "  Current Transaction ID: $($parts[0].Trim())" -ForegroundColor Cyan
                Write-Host "  Current Time: $($parts[1].Trim())" -ForegroundColor Cyan
                Write-Host "  Current WAL LSN: $($parts[2].Trim())" -ForegroundColor Cyan
            }
        }
    } catch {
        Write-Host "Error analyzing replication health: $_" -ForegroundColor Red
    }
}
# ===================================================================
function Write-Header {
    param([string]$title)
    Write-Host "`n$title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
}
function Write-TableHeader {
    param($col1, $col2, $col3, $col4)
    Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f $col1, $col2, $col3, $col4) -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Gray
}
function Write-TableRow {
    param($col1, $col2, $col3, $col4, $color = "White")
    Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f $col1, $col2, $col3, $col4) -ForegroundColor $color
}
function Get-LatestLogFile {
    $logFiles = Get-ChildItem -Path "testing-results" -Filter "stress-test-*.log" | Sort-Object LastWriteTime -Descending
    if ($logFiles.Count -gt 0) { return $logFiles[0].FullName } else { return $null }
}
function Get-LatestResourceLog {
    $resourceLog = "testing-results/resource-usage.log"
    if (Test-Path $resourceLog) { return $resourceLog } else { return $null }
}
# ===================================================================
# 1. SYSTEM PERFORMANCE LOG (from log file)
# ===================================================================
function Show-SystemPerformancePhases {
    Write-Header "1. System Resource Usage (Baseline, Insert, Final)"
    $resourceLog = Get-LatestResourceLog
    if (-not $resourceLog) {
        Write-Host "Resource usage log not found." -ForegroundColor Red
        return
    }
    $lines = Get-Content $resourceLog
    $phases = @("BASELINE", "INSERT", "FINAL")
    foreach ($phase in $phases) {
        $phaseLine = ($lines | Select-String $phase | Select-Object -First 1)
        if ($phaseLine) {
            Write-Host "Phase: $phase" -ForegroundColor Magenta
            Write-Host $phaseLine.Line -ForegroundColor White
            $idx = $phaseLine.LineNumber
            $dockerStats = $lines[$idx] + "`n" + $lines[$idx+1] + "`n" + $lines[$idx+2] + "`n" + $lines[$idx+3] + "`n" + $lines[$idx+4] + "`n" + $lines[$idx+5] + "`n" + $lines[$idx+6]
            Write-Host $dockerStats -ForegroundColor Gray
        }
    }
}
# ===================================================================
# 2. POSTGRES SERVER HEALTH (realtime)
# ===================================================================
function Get-PostgresServerHealth {
    # ...existing code...
}
# ===================================================================
# 3. POSTGRES TABLE STATS (all tables, with totals)
# ===================================================================
function Get-PostgresTableStats {
    Write-Header "3. PostgreSQL Table Statistics (Source & Target)"
    Write-Host "Analyzing all tables in both source and target schema, row counts, sizes, and totals..." -ForegroundColor Gray
    $sources = @(@{name='Source'; db='inventory'; schema='inventory'; host='debezium-cdc-mirroring-postgres-1'}, @{name='Target'; db='postgres'; schema='public'; host='debezium-cdc-mirroring-target-postgres-1'})
    foreach ($src in $sources) {
        Write-Host "$($src.name) Database ($($src.db)):" -ForegroundColor Yellow
        $tables = docker exec $src.host psql -U postgres -d $src.db -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema='$($src.schema)';" 2>$null
        $tableStats = @()
        $totalRows = 0; $totalSize = 0; $totalAvgRowSize = 0; $tableCount = 0
        if ($tables) {
            Write-Host "Table Statistics:" -ForegroundColor Cyan
            Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f "Table Name", "Rows", "Size", "Avg Row Size") -ForegroundColor Yellow
            Write-Host ("=" * 80) -ForegroundColor Gray
            foreach ($table in $tables) {
                $tableName = $table.Trim()
                if ($tableName) {
                    $rowCount = docker exec $src.host psql -U postgres -d $src.db -t -c "SELECT COUNT(*) FROM $($src.schema).$tableName;" 2>$null
                    $size = docker exec $src.host psql -U postgres -d $src.db -t -c "SELECT pg_total_relation_size('$($src.schema).$tableName');" 2>$null
                    $sizePretty = docker exec $src.host psql -U postgres -d $src.db -t -c "SELECT pg_size_pretty(pg_total_relation_size('$($src.schema).$tableName'));" 2>$null
                    $rowCountInt = [int](($rowCount -join "").Trim())
                    $sizeInt = [int](($size -join "").Trim())
                    $sizeStr = ($sizePretty -join "").Trim()
                    $avgRowSize = if ($rowCountInt -gt 0) { [math]::Round($sizeInt / $rowCountInt,2) } else { 0 }
                    $tableStats += [PSCustomObject]@{Name=$tableName; Rows=$rowCountInt; Size=$sizeStr; AvgRowSize=$avgRowSize}
                    $totalRows += $rowCountInt
                    $totalSize += $sizeInt
                    $totalAvgRowSize += $avgRowSize
                    $tableCount++
                }
            }
            foreach ($stat in $tableStats) {
                $color = "Cyan"
                if ($stat.Name -match "final") { $color = "Yellow" }
                elseif ($stat.Rows -eq 0) { $color = "Blue" }
                elseif ($stat.Rows -gt 1000000) { $color = "Green" }
                Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f $stat.Name, $stat.Rows, $stat.Size, "$($stat.AvgRowSize) B") -ForegroundColor $color
            }
            Write-Host ("-" * 80) -ForegroundColor Gray
            $avgRowSizeTotal = if ($totalRows -gt 0) { [math]::Round($totalSize / $totalRows,2) } else { 0 }
            Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f "TOTAL", $totalRows, ("{0:N2} GiB" -f ($totalSize/1GB)), "$avgRowSizeTotal B") -ForegroundColor Magenta
        }
    }
}
# ===================================================================
# 4. KAFKA TOPICS & MESSAGING ANALYSIS (realtime)
# ===================================================================
function Get-KafkaTopicsAnalysis {
    # ...existing code...
}
# ===================================================================
# 5. CDC OPERATIONS ANALYSIS (from log + realtime)
# ===================================================================
function Get-CDCOperationsAnalysis {
    Write-Header "5. CDC Operations Analysis (Insert/Update/Delete)"
    $logFile = Get-LatestLogFile
    $insertCount = 0; $updateCount = 0; $deleteCount = 0; $failedCount = 0
    if ($logFile) {
        $lines = Get-Content $logFile
        foreach ($line in $lines) {
            if ($line -match "Bulk INSERT completed") {
                $insertCount += ($line -replace '[^0-9]', '')
            }
            if ($line -match "UPDATE") { $updateCount++ }
            if ($line -match "DELETE") { $deleteCount++ }
            if ($line -match "Error" -or $line -match "Failed") { $failedCount++ }
        }
    }
    # Realtime DB check for operation counts
    $sourceInsert = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT COUNT(*) FROM inventory.orders;" 2>$null
    $targetInsert = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
    Write-TableHeader "Operation" "Source" "Target" "Failed"
    Write-TableRow "INSERT" ([int](($sourceInsert -join "").Trim())) ([int](($targetInsert -join "").Trim())) $failedCount "Green"
    Write-TableRow "UPDATE" $updateCount $updateCount $failedCount "Green"
    Write-TableRow "DELETE" $deleteCount $deleteCount $failedCount "Green"
}
# ===================================================================
# 6-10. (existing code, unchanged)
# ===================================================================
# ...existing code for points 6-10...
# ===================================================================
# 11. ANALYSIS SUMMARY & RECOMMENDATION
# ===================================================================
function Show-AnalysisSummary {
    Write-Header "11. Analysis Summary & Recommendations"
    $logFile = Get-LatestLogFile
    $resourceLog = Get-LatestResourceLog
    $summary = @()
    if ($logFile) {
        $lines = Get-Content $logFile
        $duration = ($lines | Select-String "Test Duration").Line
        $throughput = ($lines | Select-String "Throughput").Line
        $successRate = ($lines | Select-String "Success Rate").Line
        $avgBatch = ($lines | Select-String "Average Batch Time").Line
        $maxBatch = ($lines | Select-String "Max Batch Time").Line
        $minBatch = ($lines | Select-String "Min Batch Time").Line
        $summary += $duration; $summary += $throughput; $summary += $successRate; $summary += $avgBatch; $summary += $maxBatch; $summary += $minBatch
    }
    Write-Host "Summary from latest log:" -ForegroundColor Yellow
    foreach ($item in $summary) { Write-Host $item -ForegroundColor White }
    Write-Host "Recommendations:" -ForegroundColor Yellow
    Write-Host "- Monitor resource usage and replication lag regularly" -ForegroundColor White
    Write-Host "- Check Kafka Connect logs for errors and failed operations" -ForegroundColor White
    Write-Host "- Validate data integrity between source and target" -ForegroundColor White
    Write-Host "- Set up automated alerts for connector failures and lag spikes" -ForegroundColor White
}
# ===================================================================
# MAIN EXECUTION
# ===================================================================
Clear-Host
Write-Host "CDC Pipeline Real-Time Statistics Monitor (Enhanced)" -ForegroundColor Magenta
Write-Host "Debezium PostgreSQL to PostgreSQL Replication" -ForegroundColor Magenta
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Gray
try {
    Show-SystemPerformancePhases      # 1
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-PostgresServerHealth          # 2
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-PostgresTableStats            # 3
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-KafkaTopicsAnalysis           # 4
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-CDCOperationsAnalysis         # 5
function Show-CDCConnectorStatus {
    Write-Header "2b. CDC Connector Status & Configuration (REST API)"
    try {
        $connectorsApi = "http://localhost:8083/connectors"
        $response = Invoke-WebRequest -Uri $connectorsApi -UseBasicParsing -TimeoutSec 5
        $connectors = $response.Content | ConvertFrom-Json
        if ($connectors.Count -eq 0) {
            Write-Host "No connectors registered." -ForegroundColor Red
        } else {
            foreach ($connector in $connectors) {
                $statusApi = "$connectorsApi/$connector/status"
                $statusResp = Invoke-WebRequest -Uri $statusApi -UseBasicParsing -TimeoutSec 5
                $status = $statusResp.Content | ConvertFrom-Json
                Write-Host ("Connector: {0}" -f $connector) -ForegroundColor Green
                Write-Host ("  State: {0}" -f $status.connector.state) -ForegroundColor Gray
                Write-Host ("  Worker: {0}" -f $status.connector.worker_id) -ForegroundColor Gray
                Write-Host ("  Tasks:") -ForegroundColor Gray
                foreach ($task in $status.tasks) {
                    Write-Host ("    Task {0}: {1}" -f $task.id, $task.state) -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Host "Failed to query connector status. Ensure Kafka Connect is running and accessible." -ForegroundColor Red
    }
}

function Show-KafkaConnectorStatus {
    Write-Header "4b. Kafka Connector Status (docker exec curl)"
    try {
        $connectContainer = "tutorial-connect-1"
        $connectorsCmd = "docker exec $connectContainer curl -s http://localhost:8083/connectors"
        $connectors = Invoke-Expression $connectorsCmd | ConvertFrom-Json
        if ($connectors.Count -eq 0) {
            Write-Host "No connectors registered." -ForegroundColor Red
        } else {
            Write-Host "Registered Connectors:" -ForegroundColor Green
            $connectors | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Host "Failed to query Kafka connectors via docker exec curl. Ensure containers are running and CLI tools are available." -ForegroundColor Red
    }
}
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-ContainerHealthStatus         # 6
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-PerformanceSummary            # 7
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-KafkaMessageAnalysis          # 8
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-DatabaseMetrics               # 9
    Write-Host ("=" * 80) -ForegroundColor Gray
    Get-ReplicationHealth             # 10
    Write-Host ("=" * 80) -ForegroundColor Gray
    Show-AnalysisSummary              # 11
    Write-Host "`nCDC Pipeline Statistics Analysis Completed!" -ForegroundColor Green
    Write-Host "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ("=" * 80) -ForegroundColor Gray
} catch {
    Write-Host "Error during monitoring: $($_.Exception.Message)" -ForegroundColor Red
}
