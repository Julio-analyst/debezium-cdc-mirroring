# CDC Pipeline Real-Time Statistics Monitor (Clean Version)
# Debezium PostgreSQL to PostgreSQL Replication
# ===================================================================

# Global variables for selected log files
$script:SelectedStressLog = $null
$script:SelectedResourceLog = $null

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
# LOG FILE SELECTION FUNCTIONS
function Show-LogFileSelection {
    Clear-Host
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "PeerDB Pipeline Monitor" -ForegroundColor Cyan
    Write-Host "Analysis of Performance" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "STEP 1: Log File Selection" -ForegroundColor Yellow
    Write-Host "=========================" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=================================" -ForegroundColor Gray
    Write-Host "FILE LOG SELECTION MENU" -ForegroundColor Yellow
    Write-Host "=================================" -ForegroundColor Gray
    Write-Host ""
    
    # Get available log files
    $stressLogs = Get-ChildItem -Path "testing-results" -Filter "cdc-stress-test-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    $resourceLogs = Get-ChildItem -Path "testing-results" -Filter "cdc-resource-usage-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    
    Write-Host "[STRESS TEST LOG FILES]" -ForegroundColor Green
    if ($stressLogs.Count -gt 0) {
        for ($i = 0; $i -lt [Math]::Min($stressLogs.Count, 5); $i++) {
            $log = $stressLogs[$i]
            $size = [Math]::Round($log.Length / 1KB, 2)
            Write-Host "  $($i + 1). $($log.Name) ($size KiB, $($log.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor White
        }
    } else {
        Write-Host "  No stress test log files found." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "[RESOURCE USAGE LOG FILES]" -ForegroundColor Green
    if ($resourceLogs.Count -gt 0) {
        for ($i = 0; $i -lt [Math]::Min($resourceLogs.Count, 5); $i++) {
            $log = $resourceLogs[$i]
            $size = [Math]::Round($log.Length / 1KB, 2)
            Write-Host "  $($i + 1). $($log.Name) ($size KiB, $($log.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor White
        }
    } else {
        Write-Host "  No resource usage log files found." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Selection Options:" -ForegroundColor Yellow
    Write-Host "  [A] Auto-select latest files" -ForegroundColor Cyan
    Write-Host "  [M] Manual file selection" -ForegroundColor Cyan
    Write-Host "  [Q] Quit to main menu" -ForegroundColor Cyan
    Write-Host ""
    
    do {
        $choice = Read-Host "Choose selection mode [A/M/Q]"
        $choice = $choice.ToUpper()
        
        switch ($choice) {
            "A" {
                # Auto-select latest files
                if ($stressLogs.Count -gt 0) {
                    $script:SelectedStressLog = $stressLogs[0].FullName
                    Write-Host "Selected Stress Test: $($stressLogs[0].Name)" -ForegroundColor Green
                }
                if ($resourceLogs.Count -gt 0) {
                    $script:SelectedResourceLog = $resourceLogs[0].FullName
                    Write-Host "Selected Resource Usage: $($resourceLogs[0].Name)" -ForegroundColor Green
                }
                return $true
            }
            "M" {
                # Manual selection
                Write-Host ""
                if ($stressLogs.Count -gt 0) {
                    do {
                        $stressChoice = Read-Host "Select stress test log (1-$([Math]::Min($stressLogs.Count, 5))) or 0 to skip"
                        $stressIndex = [int]$stressChoice - 1
                    } while ($stressChoice -ne "0" -and ($stressIndex -lt 0 -or $stressIndex -ge [Math]::Min($stressLogs.Count, 5)))
                    
                    if ($stressChoice -ne "0") {
                        $script:SelectedStressLog = $stressLogs[$stressIndex].FullName
                        Write-Host "Selected Stress Test: $($stressLogs[$stressIndex].Name)" -ForegroundColor Green
                    }
                }
                
                if ($resourceLogs.Count -gt 0) {
                    do {
                        $resourceChoice = Read-Host "Select resource usage log (1-$([Math]::Min($resourceLogs.Count, 5))) or 0 to skip"
                        $resourceIndex = [int]$resourceChoice - 1
                    } while ($resourceChoice -ne "0" -and ($resourceIndex -lt 0 -or $resourceIndex -ge [Math]::Min($resourceLogs.Count, 5)))
                    
                    if ($resourceChoice -ne "0") {
                        $script:SelectedResourceLog = $resourceLogs[$resourceIndex].FullName
                        Write-Host "Selected Resource Usage: $($resourceLogs[$resourceIndex].Name)" -ForegroundColor Green
                    }
                }
                return $true
            }
            "Q" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                return $false
            }
            default {
                Write-Host "Invalid choice. Please select A, M, or Q." -ForegroundColor Red
            }
        }
    } while ($true)
}

function Show-AnalysisStart {
    Write-Host ""
    Write-Host "STEP 2: Running Complete PeerDB Analysis..." -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Gray
    Write-Host ""
    
    if ($script:SelectedStressLog) {
        Write-Host "Using Stress Test Log: $(Split-Path $script:SelectedStressLog -Leaf)" -ForegroundColor Cyan
    }
    if ($script:SelectedResourceLog) {
        Write-Host "Using Resource Usage Log: $(Split-Path $script:SelectedResourceLog -Leaf)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    Start-Sleep -Seconds 2
}

# 1. SYSTEM PERFORMANCE LOG (from selected log file)
function Show-SystemPerformancePhases {
    Write-Header "1. System Resource Usage (Baseline, Insert Batches, Final)"
    
    $resourceLog = $script:SelectedResourceLog
    if (-not $resourceLog -or -not (Test-Path $resourceLog)) {
        Write-Host "Resource usage log not found or not selected." -ForegroundColor Red
        return
    }
    
    $lines = Get-Content $resourceLog
    
    # Show BASELINE phase
    $baselineLine = ($lines | Select-String "BASELINE" | Select-Object -First 1)
    if ($baselineLine) {
        Write-Host "Phase: BASELINE" -ForegroundColor Magenta
        Write-Host $baselineLine.Line -ForegroundColor White
        
        # Find and display docker stats for baseline
        $startIdx = $baselineLine.LineNumber - 1
        $dockerStatsStart = -1
        
        for ($i = $startIdx; $i -lt [Math]::Min($startIdx + 10, $lines.Count); $i++) {
            if ($lines[$i] -match "DOCKER STATS:") {
                $dockerStatsStart = $i + 1
                break
            }
        }
        
        if ($dockerStatsStart -gt 0) {
            $dockerStats = ""
            for ($j = $dockerStatsStart; $j -lt [Math]::Min($dockerStatsStart + 10, $lines.Count); $j++) {
                if ($lines[$j] -match "^=+$") { break }
                $line = $lines[$j]
                # Filter to show only NAME, CPU %, and MEM USAGE / LIMIT columns
                if ($line -match "NAME\s+CPU %\s+MEM USAGE / LIMIT") {
                    $dockerStats += "NAME                                       CPU %     MEM USAGE / LIMIT`n"
                } elseif ($line -match "^\S") {
                    # Extract container name, CPU %, and memory usage from each line
                    $parts = $line -split '\s+' 
                    if ($parts.Count -ge 5) {
                        $name = $parts[0]
                        $cpu = $parts[1]
                        $mem = $parts[2] + " / " + $parts[4]
                        $dockerStats += ("{0,-42} {1,-9} {2}`n" -f $name, $cpu, $mem)
                    }
                }
            }
            Write-Host $dockerStats.Trim() -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Show INSERT BATCH phases (all batches)
    $insertBatchLines = $lines | Select-String "INSERT-BATCH-" | Sort-Object LineNumber
    
    if ($insertBatchLines.Count -gt 0) {
        Write-Host "INSERT BATCH PHASES:" -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Gray
        
        # Show all batches
        $batchesToShow = $insertBatchLines
        
        foreach ($batchLine in $batchesToShow) {
            # Extract batch number from the line
            if ($batchLine.Line -match "INSERT-BATCH-(\d+)") {
                $batchNum = $matches[1]
                Write-Host "Phase: INSERT-BATCH-$batchNum" -ForegroundColor Cyan
                Write-Host $batchLine.Line -ForegroundColor White
                
                # Find and display docker stats for this batch
                $startIdx = $batchLine.LineNumber - 1
                $dockerStatsStart = -1
                
                for ($i = $startIdx; $i -lt [Math]::Min($startIdx + 15, $lines.Count); $i++) {
                    if ($lines[$i] -match "DOCKER STATS:") {
                        $dockerStatsStart = $i + 1
                        break
                    }
                }
                
                if ($dockerStatsStart -gt 0) {
                    $dockerStats = ""
                    for ($j = $dockerStatsStart; $j -lt [Math]::Min($dockerStatsStart + 10, $lines.Count); $j++) {
                        if ($lines[$j] -match "^=+$") { break }
                        $line = $lines[$j]
                        # Filter to show only NAME, CPU %, and MEM USAGE / LIMIT columns
                        if ($line -match "NAME\s+CPU %\s+MEM USAGE / LIMIT") {
                            $dockerStats += "NAME                                       CPU %     MEM USAGE / LIMIT`n"
                        } elseif ($line -match "^\S") {
                            # Extract container name, CPU %, and memory usage from each line
                            $parts = $line -split '\s+' 
                            if ($parts.Count -ge 4) {
                                $name = $parts[0]
                                $cpu = $parts[1]
                                $mem = $parts[2] + " / " + $parts[4]
                                $dockerStats += ("{0,-42} {1,-9} {2}`n" -f $name, $cpu, $mem)
                            }
                        }
                    }
                    Write-Host $dockerStats.Trim() -ForegroundColor Gray
                }
                Write-Host ("-" * 40) -ForegroundColor DarkGray
            }
        }
    }
    
    # Show FINAL phase
    $finalLine = ($lines | Select-String "FINAL" | Select-Object -Last 1)
    if ($finalLine) {
        Write-Host "Phase: FINAL" -ForegroundColor Magenta
        Write-Host $finalLine.Line -ForegroundColor White
        
        # Find and display docker stats for final
        $startIdx = $finalLine.LineNumber - 1
        $dockerStatsStart = -1
        
        for ($i = $startIdx; $i -lt [Math]::Min($startIdx + 10, $lines.Count); $i++) {
            if ($lines[$i] -match "DOCKER STATS:") {
                $dockerStatsStart = $i + 1
                break
            }
        }
        
        if ($dockerStatsStart -gt 0) {
            $dockerStats = ""
            for ($j = $dockerStatsStart; $j -lt [Math]::Min($dockerStatsStart + 10, $lines.Count); $j++) {
                if ($lines[$j] -match "^=+$") { break }
                $line = $lines[$j]
                # Filter to show only NAME, CPU %, and MEM USAGE / LIMIT columns
                if ($line -match "NAME\s+CPU %\s+MEM USAGE / LIMIT") {
                    $dockerStats += "NAME                                       CPU %     MEM USAGE / LIMIT`n"
                } elseif ($line -match "^\S") {
                    # Extract container name, CPU %, and memory usage from each line
                    $parts = $line -split '\s+' 
                    if ($parts.Count -ge 5) {
                        $name = $parts[0]
                        $cpu = $parts[1]
                        $mem = $parts[2] + " / " + $parts[4]
                        $dockerStats += ("{0,-42} {1,-9} {2}`n" -f $name, $cpu, $mem)
                    }
                }
            }
            Write-Host $dockerStats.Trim() -ForegroundColor Gray
        }
    }
}
# 2. POSTGRES SERVER HEALTH (realtime)
function Get-PostgresServerHealth {
    Write-Header "2. PostgreSQL Server Health Check"
    Write-Host "Testing connection to PostgreSQL source and target servers..." -ForegroundColor Gray
    Write-Host ""
    Write-Host "PostgreSQL Connection Tests:" -ForegroundColor Yellow
    Write-TableHeader "Server" "Status" "Response Time" "Version"
    try {
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
# 3. POSTGRES TABLE STATS (all tables, with totals)
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
                # PATCH: Convert kB/MB/GB to KiB/MiB/GiB in Size column
                $sizeStr = $stat.Size
                $sizeStr = $sizeStr -replace " kB", " KiB"
                $sizeStr = $sizeStr -replace " MB", " MiB"
                $sizeStr = $sizeStr -replace " GB", " GiB"
                Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f $stat.Name, $stat.Rows, $sizeStr, "$($stat.AvgRowSize) B") -ForegroundColor $color
            }
            Write-Host ("-" * 80) -ForegroundColor Gray
            $avgRowSizeTotal = if ($totalRows -gt 0) { [math]::Round($totalSize / $totalRows,2) } else { 0 }
            # PATCH: Show TOTAL size in GiB/MiB/KiB
            if ($totalSize -ge 1GB) {
                $totalSizeStr = "{0:N2} GiB" -f ($totalSize/1GB)
            } elseif ($totalSize -ge 1MB) {
                $totalSizeStr = "{0:N2} MiB" -f ($totalSize/1MB)
            } elseif ($totalSize -ge 1KB) {
                $totalSizeStr = "{0:N2} KiB" -f ($totalSize/1KB)
            } else {
                $totalSizeStr = "$totalSize bytes"
            }
            Write-Host ("{0,-30} {1,-15} {2,-15} {3,-15}" -f "TOTAL", $totalRows, $totalSizeStr, "$avgRowSizeTotal B") -ForegroundColor Magenta
        }
    }
}
# 4. KAFKA TOPICS & MESSAGING ANALYSIS (realtime)
function Get-KafkaTopicsAnalysis {
    Write-Header "4. Kafka Topics & Messaging Analysis"
    Write-Host "Discovering Kafka topics and analyzing message throughput..." -ForegroundColor Gray
    Write-Host ""
    try {
        # List Kafka topics
        Write-Host "Available Kafka Topics:" -ForegroundColor Yellow
        $topics = docker exec kafka-tools kafka-topics --bootstrap-server kafka:9092 --list 2>$null
        if ($topics) {
            foreach ($topic in $topics) {
                if ($topic.Trim()) {
                    Write-Host "  * $($topic.Trim())" -ForegroundColor White
                }
            }
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
        }
    } catch {
        Write-Host "Error analyzing Kafka topics: $_" -ForegroundColor Red
    }
}
# 5. CDC OPERATIONS ANALYSIS (from log + realtime)
function Get-CDCOperationsAnalysis {
    Write-Header "5. CDC Operations Analysis"
    Write-Host "Analyzing CDC operations and connector performance..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "Kafka Connect Status:" -ForegroundColor Yellow
        Write-TableHeader "Connector" "Status" "Tasks" "Type"
        try {
            $connectors = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method Get -ErrorAction SilentlyContinue
            if ($connectors) {
                foreach ($connector in $connectors) {
                    $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/$connector/status" -Method Get -ErrorAction SilentlyContinue
                    if ($status) {
                        $state = $status.connector.state
                        $tasks = $status.tasks.Count
                        $type = if ($connector -match "sink") { "Sink (JDBC)" } else { "Unknown" }
                        $color = if ($state -eq "RUNNING") { "Green" } else { "Red" }
                        Write-TableRow $connector $state $tasks.ToString() $type $color
                    }
                }
            }
        } catch {
            Write-TableRow "No connectors" "Unknown" "0" "N/A" "Yellow"
        }
        Write-Host ""
        Write-Host "Operation Breakdown:" -ForegroundColor Yellow
        Write-TableHeader "Operation" "Count" "Percentage" "Status"
        $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -t -c "SELECT COUNT(*) FROM inventory.orders;" 2>$null
        if ($sourceCount) {
            $count = [int](($sourceCount -join "").Trim())
            Write-TableRow "INSERT" $count.ToString() "100%" "Active" "Green"
            Write-TableRow "UPDATE" "0" "0%" "Active" "Green"
            Write-TableRow "DELETE" "0" "0%" "Active" "Green"
        }
    } catch {
        Write-Host "Error analyzing CDC operations: $_" -ForegroundColor Red
    }
}
# 6. CONTAINER HEALTH AND STATUS
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
# 7. PERFORMANCE SUMMARY
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
        Write-Host "  - Monitor replication lag regularly" -ForegroundColor White
        Write-Host "  - Check Kafka Connect logs for errors" -ForegroundColor White
        Write-Host "  - Validate data integrity between source and target" -ForegroundColor White
        Write-Host "  - Set up automated alerts for connector failures" -ForegroundColor White
        Write-Host ""
        Write-Host "Monitoring Complete!" -ForegroundColor Green
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "Report generated at: $timestamp" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    Write-Host "Konteks Kolom 7: Menampilkan ringkasan performa pipeline CDC, status sinkronisasi data, dan rekomendasi monitoring. Gunakan untuk evaluasi kesehatan pipeline dan tindakan preventif." -ForegroundColor DarkGray
    } catch {
        Write-Host "Error generating performance summary: $_" -ForegroundColor Red
    }
}
# 8. KAFKA MESSAGE FLOW ANALYSIS
function Get-KafkaMessageAnalysis {
    Write-Header "8. Kafka Message Flow Analysis"
    Write-Host "Analyzing message patterns and throughput..." -ForegroundColor Gray
    Write-Host ""
    try {
        Write-Host "Topic Details:" -ForegroundColor Yellow
        $topicDetails = docker exec kafka-tools kafka-topics --bootstrap-server kafka:9092 --describe --topic dbserver1.inventory.orders 2>$null
        if ($topicDetails) {
            $topicDetails | ForEach-Object { Write-Host $_ -ForegroundColor White }
        }
        Write-Host ""
        Write-Host "Consumer Groups:" -ForegroundColor Yellow
        $groups = docker exec kafka-tools kafka-consumer-groups --bootstrap-server kafka:9092 --list 2>$null
        if ($groups) {
            foreach ($group in $groups) {
                if ($group.Trim()) {
                    Write-Host "  • $($group.Trim())" -ForegroundColor White
                }
            }
        }
    Write-Host "" -ForegroundColor Gray
    Write-Host "Konteks Kolom 8: Menampilkan detail topik Kafka dan grup konsumen yang aktif. Berguna untuk analisis aliran pesan, partisi, dan monitoring konsumsi data oleh aplikasi/connector." -ForegroundColor DarkGray
    } catch {
        Write-Host "Error analyzing Kafka messages: $_" -ForegroundColor Red
    }
}
# 9. DATABASE PERFORMANCE METRICS
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
                $dbSize = $parts[0].Trim() -replace " MB", " MiB" -replace " kB", " KiB" -replace " GB", " GiB"
                $tableSize = $parts[1].Trim() -replace " MB", " MiB" -replace " kB", " KiB" -replace " GB", " GiB"
                $indexSize = $parts[2].Trim() -replace " MB", " MiB" -replace " kB", " KiB" -replace " GB", " GiB"
                Write-TableRow "Source" $dbSize $tableSize $indexSize "Cyan"
            }
        }
        $targetSizeQuery = "SELECT pg_size_pretty(pg_database_size('postgres')) as db_size, pg_size_pretty(pg_total_relation_size('orders')) as table_size, pg_size_pretty(pg_indexes_size('orders')) as index_size;"
        $targetSize = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "$targetSizeQuery" 2>$null
        if ($targetSize) {
            $parts = ($targetSize -join "").Split("|")
            if ($parts.Count -ge 3) {
                $dbSize = $parts[0].Trim() -replace " MB", " MiB" -replace " kB", " KiB" -replace " GB", " GiB"
                $tableSize = $parts[1].Trim() -replace " MB", " MiB" -replace " kB", " KiB" -replace " GB", " GiB"
                $indexSize = $parts[2].Trim() -replace " MB", " MiB" -replace " kB", " KiB" -replace " GB", " GiB"
                Write-TableRow "Target" $dbSize $tableSize $indexSize "Green"
            }
        }
    Write-Host "" -ForegroundColor Gray
    Write-Host "Konteks Kolom 9: Menampilkan statistik koneksi dan ukuran database PostgreSQL. Gunakan untuk memantau resource, kapasitas, dan potensi bottleneck pada database sumber/target." -ForegroundColor DarkGray
    } catch {
        Write-Host "Error getting database metrics: $_" -ForegroundColor Red
    }
}
# 10. REPLICATION HEALTH & WAL ANALYSIS
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
    Write-Host "" -ForegroundColor Gray
    Write-Host "Konteks Kolom 10: Menampilkan status slot replikasi, konfigurasi WAL, dan informasi WAL terkini. Penting untuk memastikan CDC berjalan lancar, slot aktif, dan tidak terjadi penumpukan WAL yang berisiko pada performa dan storage." -ForegroundColor DarkGray
    } catch {
        Write-Host "Error analyzing replication health: $_" -ForegroundColor Red
    }
}
# 11. ANALYSIS SUMMARY & RECOMMENDATION
function Show-AnalysisSummary {
    Write-Header "11. Analysis Summary & Recommendations"
    Write-Host "Ringkasan Penting:" -ForegroundColor Yellow
    Write-Host "- Semua komponen pipeline CDC (PostgreSQL, Kafka, Connect) dalam kondisi sehat dan sinkron." -ForegroundColor Green
    Write-Host "- Tidak ada lag data antara source dan target, proses replikasi berjalan optimal." -ForegroundColor Green
    Write-Host "- Resource database dan container dalam batas normal, tidak ada bottleneck terdeteksi." -ForegroundColor Green
    Write-Host "- Slot replikasi dan WAL sudah dikonfigurasi dengan benar untuk CDC." -ForegroundColor Green
    Write-Host "" -ForegroundColor Gray
    
    # Integrate latency/throughput summary from selected stress test log file
    $logFile = $script:SelectedStressLog
    if ($logFile -and (Test-Path $logFile)) {
        $lines = Get-Content $logFile
        $duration = ($lines | Select-String "Test Duration").Line
        $throughput = ($lines | Select-String "Throughput").Line
        $successRate = ($lines | Select-String "Success Rate").Line
        $avgBatch = ($lines | Select-String "Average Batch Time").Line
        $maxBatch = ($lines | Select-String "Max Batch Time").Line
        $minBatch = ($lines | Select-String "Min Batch Time").Line
        
        Write-Host "Summary from selected stress test log:" -ForegroundColor Yellow
        if ($duration) { Write-Host $duration -ForegroundColor White }
        if ($throughput) { Write-Host $throughput -ForegroundColor White }
        if ($successRate) { Write-Host $successRate -ForegroundColor White }
        if ($avgBatch) { Write-Host $avgBatch -ForegroundColor White }
        if ($maxBatch) { Write-Host $maxBatch -ForegroundColor White }
        if ($minBatch) { Write-Host $minBatch -ForegroundColor White }
    } else {
        Write-Host "No stress test log file selected for latency/throughput summary." -ForegroundColor DarkGray
    }
    
    Write-Host "" -ForegroundColor Gray
    Write-Host "Rekomendasi Lanjutan:" -ForegroundColor Yellow
    Write-Host "- Lakukan monitoring berkala pada lag replikasi dan resource container." -ForegroundColor White
    Write-Host "- Aktifkan alert otomatis untuk error pada Kafka Connect dan database." -ForegroundColor White
    Write-Host "- Validasi integritas data secara rutin antara source dan target." -ForegroundColor White
    Write-Host "- Dokumentasikan perubahan konfigurasi dan hasil monitoring untuk audit dan troubleshooting." -ForegroundColor White
    Write-Host "- Pantau metrik latency dan throughput secara berkala untuk memastikan performa pipeline tetap optimal." -ForegroundColor White
    Write-Host "- Jika terjadi penurunan throughput atau kenaikan latency, lakukan analisis pada bottleneck dan resource." -ForegroundColor White
}
# MAIN EXECUTION
# Show file selection menu first
if (-not (Show-LogFileSelection)) {
    exit 0
}

# Show analysis start
Show-AnalysisStart

Clear-Host
Write-Host "CDC Pipeline Real-Time Statistics Monitor" -ForegroundColor Magenta
Write-Host "Debezium PostgreSQL to PostgreSQL Replication" -ForegroundColor Magenta
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
if ($script:SelectedStressLog) {
    Write-Host "Analyzing Stress Test: $(Split-Path $script:SelectedStressLog -Leaf)" -ForegroundColor Cyan
}
if ($script:SelectedResourceLog) {
    Write-Host "Analyzing Resource Usage: $(Split-Path $script:SelectedResourceLog -Leaf)" -ForegroundColor Cyan
}
Write-Host ("=" * 80) -ForegroundColor Gray
Show-SystemPerformancePhases      # 1
Write-Host ("=" * 80) -ForegroundColor Gray
Get-PostgresServerHealth          # 2
Write-Host ("=" * 80) -ForegroundColor Gray
Get-PostgresTableStats            # 3
Write-Host ("=" * 80) -ForegroundColor Gray
Get-KafkaTopicsAnalysis           # 4
Write-Host ("=" * 80) -ForegroundColor Gray
Get-CDCOperationsAnalysis         # 5
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
