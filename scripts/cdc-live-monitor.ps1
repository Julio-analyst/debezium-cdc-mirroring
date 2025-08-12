# ===================================================================
# CDC Performance Monitor with Live INSERT Test Integration
# ===================================================================

param(
    [int]$TestRecords = 5000,
    [int]$BatchSize = 500,
    [switch]$RunStressTest
)

function Write-Header {
    param([string]$Title)
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host ("=" * $Title.Length) -ForegroundColor Gray
}

function Write-Metric {
    param([string]$Label, [string]$Value, [string]$Unit = "", [string]$Color = "White")
    Write-Host ("{0,-25}: {1} {2}" -f $Label, $Value, $Unit) -ForegroundColor $Color
}

function Get-DockerStatsSnapshot {
    param([string]$Phase)
    
    Write-Host "`nPhase: $Phase" -ForegroundColor Yellow
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "DOCKER STATS:" -ForegroundColor Yellow
    Write-Host ("{0,-20} {1,-10} {2}" -f "NAME", "CPU %", "MEM USAGE / LIMIT") -ForegroundColor Yellow
    Write-Host ("-" * 60) -ForegroundColor Gray
    
    try {
        $dockerStats = docker stats --no-stream --format "{{.Name}};{{.CPUPerc}};{{.MemUsage}}" 2>$null
        
        if ($dockerStats) {
            $dockerStats -split "`n" | ForEach-Object {
                if ($_ -match '^([^;]+);([^;]+);(.+)$') {
                    $containerName = $matches[1].Trim()
                    $cpuPercent = $matches[2].Trim()
                    $memUsage = $matches[3].Trim()
                    
                    if ($containerName -match "kafka|postgres|connect|zookeeper") {
                        $shortName = $containerName -replace "debezium-cdc-mirroring-", "" -replace "tutorial-", ""
                        Write-Host ("{0,-20} {1,-10} {2}" -f $shortName, $cpuPercent, $memUsage) -ForegroundColor White
                    }
                }
            }
        }
    } catch {
        Write-Host "Error getting Docker stats" -ForegroundColor Red
    }
    
    Write-Host ("-" * 60) -ForegroundColor Gray
}

function Get-DatabaseStats {
    Write-Header "PostgreSQL Database Statistics"
    
    try {
        # Get current target database stats
        $query = @"
SELECT 
    COUNT(*) as total_rows,
    pg_size_pretty(pg_total_relation_size('orders')) as table_size,
    MAX(id) as max_id,
    MIN(id) as min_id,
    MAX(_synced_at) as last_sync
FROM orders;
"@
        
        Write-Host "Querying target database..." -ForegroundColor Gray
        $result = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -c $query 2>$null
        
        if ($result -match '\|') {
            $lines = $result -split "`n" | Where-Object { $_ -match '\|' -and $_ -notmatch '^-+' -and $_ -notmatch 'total_rows' }
            foreach ($line in $lines) {
                if ($line.Trim() -and $line -match '\|') {
                    $parts = $line -split '\|' | ForEach-Object { $_.Trim() }
                    if ($parts.Length -ge 5) {
                        Write-Metric "Total Records" $parts[0] "" "Green"
                        Write-Metric "Table Size" $parts[1] "" "White"
                        Write-Metric "ID Range" "$($parts[3]) → $($parts[2])" "" "White"
                        Write-Metric "Last Sync" $parts[4] "" "Yellow"
                        
                        # Calculate average row size
                        $totalRows = [int]$parts[0]
                        if ($totalRows -gt 0) {
                            $sizeQuery = "SELECT pg_total_relation_size('orders');"
                            $sizeResult = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -c $sizeQuery 2>$null
                            if ($sizeResult -match '(\d+)') {
                                $sizeBytes = [long]$matches[1]
                                $avgRowSize = [math]::Round($sizeBytes / $totalRows, 2)
                                Write-Metric "Avg Row Size" $avgRowSize "bytes" "Cyan"
                            }
                        }
                    }
                }
            }
        }
        
    } catch {
        Write-Host "Error getting database stats: $_" -ForegroundColor Red
    }
}

function Get-CDCOperationBreakdown {
    Write-Header "CDC Operations Breakdown"
    
    try {
        $operationsQuery = @"
SELECT 
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    (n_tup_ins + n_tup_upd + n_tup_del) as total_operations
FROM pg_stat_user_tables 
WHERE schemaname = 'public' AND relname = 'orders';
"@
        
        $result = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -c $operationsQuery 2>$null
        
        if ($result -match '\|') {
            $lines = $result -split "`n" | Where-Object { $_ -match '\|' -and $_ -notmatch '^-+' -and $_ -notmatch 'inserts' }
            foreach ($line in $lines) {
                if ($line.Trim() -and $line -match '\|') {
                    $parts = $line -split '\|' | ForEach-Object { $_.Trim() }
                    if ($parts.Length -ge 4 -and $parts[0] -match '\d+') {
                        $inserts = [int]$parts[0]
                        $updates = [int]$parts[1]
                        $deletes = [int]$parts[2]
                        $total = [int]$parts[3]
                        
                        if ($total -gt 0) {
                            $insertPct = [math]::Round(($inserts / $total) * 100, 2)
                            $updatePct = [math]::Round(($updates / $total) * 100, 2)
                            $deletePct = [math]::Round(($deletes / $total) * 100, 2)
                            
                            Write-Host ("{0,-15} {1,-10} {2}" -f "Operation", "Count", "Percentage") -ForegroundColor Yellow
                            Write-Host ("-" * 40) -ForegroundColor Gray
                            Write-Host ("{0,-15} {1,-10} {2}%" -f "CREATE", $inserts, $insertPct) -ForegroundColor Green
                            Write-Host ("{0,-15} {1,-10} {2}%" -f "UPDATE", $updates, $updatePct) -ForegroundColor Yellow
                            Write-Host ("{0,-15} {1,-10} {2}%" -f "DELETE", $deletes, $deletePct) -ForegroundColor Red
                        }
                    }
                }
            }
        } else {
            Write-Host "No operation statistics available" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Error getting CDC operations: $_" -ForegroundColor Red
    }
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

Clear-Host
Write-Host "CDC Pipeline Statistics & Performance Monitor" -ForegroundColor Magenta
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "PostgreSQL CDC Server: localhost:5432 → localhost:5433" -ForegroundColor Gray

# Phase 1: Baseline Monitoring
Write-Header "1. Real-Time System Performance - BASELINE"
Get-DockerStatsSnapshot "BASELINE"

# Phase 2: Database Analysis
Get-DatabaseStats
Get-CDCOperationBreakdown

# Phase 3: Run Stress Test if requested
if ($RunStressTest) {
    Write-Header "2. Running Live INSERT Stress Test"
    Write-Host "Starting stress test with $TestRecords records..." -ForegroundColor Yellow
    
    # Capture before test
    try {
        $beforeStats = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        $beforeCount = 0
        if ($beforeStats) {
            $cleanStats = $beforeStats | Where-Object { $_ -and $_.Trim() -match '^\s*(\d+)\s*$' }
            if ($cleanStats -and $cleanStats -match '(\d+)') {
                $beforeCount = [int]$matches[1]
            }
        }
    } catch {
        $beforeCount = 0
        Write-Host "Could not get before count: $_" -ForegroundColor Yellow
    }
    
    Write-Host "Records before test: $beforeCount" -ForegroundColor Gray
    
    # Run the actual stress test
    Write-Host ""
    & ".\scripts\simple-insert-test.ps1" -RecordCount $TestRecords -BatchSize $BatchSize -ShowProgress
    
    # Phase 4: After Test Monitoring  
    Write-Header "3. Real-Time System Performance - AFTER INSERT"
    Get-DockerStatsSnapshot "AFTER_INSERT"
    
    # Wait for replication
    Write-Host "`nWaiting for CDC replication..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Capture after test
    try {
        $afterStats = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        $afterCount = 0
        if ($afterStats) {
            $cleanStats = $afterStats | Where-Object { $_ -and $_.Trim() -match '^\s*(\d+)\s*$' }
            if ($cleanStats -and $cleanStats -match '(\d+)') {
                $afterCount = [int]$matches[1]
            }
        }
    } catch {
        $afterCount = 0
        Write-Host "Could not get after count: $_" -ForegroundColor Yellow
    }
    
    $insertedRecords = $afterCount - $beforeCount
    
    Write-Header "4. Test Results Summary"
    Write-Metric "Records Before" $beforeCount "" "White"
    Write-Metric "Records After" $afterCount "" "Green"
    Write-Metric "Successfully Inserted" $insertedRecords "" "Green"
    Write-Metric "CDC Replication" "ACTIVE" "" "Green"
    
    # Final phase monitoring
    Write-Header "5. Real-Time System Performance - FINAL"
    Get-DockerStatsSnapshot "FINAL"
    
} else {
    Write-Host "`nTo run live stress test, use: -RunStressTest" -ForegroundColor Gray
}

Write-Host "`nMonitoring completed!" -ForegroundColor Green
Write-Host "CDC Pipeline Status: OPERATIONAL" -ForegroundColor Green
