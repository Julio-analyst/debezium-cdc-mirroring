#!/usr/bin/env pwsh
param(
    [switch]$Detailed,
    [switch]$Export,
    [string]$OutputPath = ".\reports\cdc-latency-report.txt"
)

# Color and formatting functions
function Write-Header {
    param([string]$Text)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor White
    Write-Host $('=' * 60) -ForegroundColor Cyan
}

function Write-SubHeader {
    param([string]$Text)
    Write-Host "`n$Text" -ForegroundColor Yellow
    Write-Host $('-' * $Text.Length) -ForegroundColor Yellow
}

function Write-Metric {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Unit = "",
        [string]$Color = "Green"
    )
    $paddedLabel = $Label.PadRight(25)
    Write-Host "$paddedLabel : " -NoNewline -ForegroundColor Gray
    Write-Host "$Value $Unit" -ForegroundColor $Color
}

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

# Main latency monitoring function
function Get-CDCLatencyMetrics {
    Write-Header "CDC Pipeline Latency & Performance Analysis"
    Write-Host "Generated: $(Get-Timestamp)" -ForegroundColor Gray
    Write-Host "Server: localhost:8083" -ForegroundColor Gray

    # 1. Database-level latency metrics
    Write-SubHeader "1. Database Replication Lag"
    
    try {
        # Check if _synced_at column exists and get replication lag
        $lagQuery = "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='_synced_at') THEN EXTRACT(EPOCH FROM (NOW() - MAX(_synced_at)))::INT ELSE NULL END as lag_seconds FROM orders WHERE _synced_at IS NOT NULL;"
        
        $lagResult = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c $lagQuery 2>$null
        
        if ($lagResult -and $lagResult -match '(\d+)') {
            $lagSeconds = [int]$matches[1]
            $lagMinutes = [math]::Round($lagSeconds / 60, 2)
            Write-Metric "Replication Lag" $lagSeconds "seconds" $(if($lagSeconds -gt 60) {"Red"} else {"Green"})
            Write-Metric "Replication Lag" $lagMinutes "minutes" $(if($lagMinutes -gt 1) {"Red"} else {"Green"})
        } else {
            # Alternative: Calculate lag using timestamp comparison
            $sourceQuery = "SELECT EXTRACT(EPOCH FROM MAX(created_at))::INT as latest_source FROM orders;"
            $targetQuery = "SELECT EXTRACT(EPOCH FROM MAX(created_at))::INT as latest_target FROM orders;"
            
            $sourceTime = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d postgres -t -c $sourceQuery 2>$null
            $targetTime = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c $targetQuery 2>$null
            
            if ($sourceTime -match '(\d+)' -and $targetTime -match '(\d+)') {
                $sourceTimes = [int]$matches[1]
                if ($targetTime -match '(\d+)') {
                    $targetTimes = [int]$matches[1]
                    $calculatedLag = $sourceTimes - $targetTimes
                    Write-Metric "Calculated Lag" $calculatedLag "seconds" $(if($calculatedLag -gt 60) {"Red"} else {"Green"})
                    Write-Metric "Calculated Lag" $([math]::Round($calculatedLag / 60, 2)) "minutes" $(if($calculatedLag -gt 60) {"Red"} else {"Green"})
                }
            } else {
                Write-Metric "Replication Lag" "Unable to calculate" "" "Yellow"
            }
        }
    } catch {
        Write-Host "Error calculating replication lag: $_" -ForegroundColor Red
    }

    # 2. Kafka Connect latency metrics
    Write-SubHeader "2. Kafka Connect Performance"
    
    try {
        $connectorStatus = Invoke-RestMethod -Uri "http://localhost:8083/connectors/inventory-connector/status" -Method GET 2>$null
        if ($connectorStatus) {
            Write-Metric "Connector State" $connectorStatus.connector.state "" $(if($connectorStatus.connector.state -eq "RUNNING") {"Green"} else {"Red"})
            
            if ($connectorStatus.tasks -and $connectorStatus.tasks.Count -gt 0) {
                Write-Metric "Task State" $connectorStatus.tasks[0].state "" $(if($connectorStatus.tasks[0].state -eq "RUNNING") {"Green"} else {"Red"})
            }
        }
    } catch {
        Write-Host "Kafka Connect API not accessible" -ForegroundColor Yellow
    }

    # 3. Message processing latency
    Write-SubHeader "3. Message Processing Latency"
    
    try {
        # Get record counts from source and target
        $sourceCount = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        $targetCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        
        if ($sourceCount -match '(\d+)' -and $targetCount -match '(\d+)') {
            $sourceRecords = [int]$matches[1]
            if ($targetCount -match '(\d+)') {
                $targetRecords = [int]$matches[1]
                $pendingRecords = $sourceRecords - $targetRecords
                
                Write-Metric "Source Records" $sourceRecords "" "White"
                Write-Metric "Target Records" $targetRecords "" "White"
                Write-Metric "Pending Replication" $pendingRecords "" $(if($pendingRecords -gt 0) {"Yellow"} else {"Green"})
                
                if ($pendingRecords -eq 0) {
                    Write-Metric "Sync Status" "SYNCHRONIZED" "" "Green"
                } else {
                    Write-Metric "Sync Status" "PENDING" "" "Yellow"
                }
            }
        }
    } catch {
        Write-Host "Error getting record counts: $_" -ForegroundColor Red
    }

    # 4. Real-time throughput measurement
    Write-SubHeader "4. Real-time Throughput Analysis"
    
    try {
        Write-Host "Measuring throughput over 10 seconds..." -ForegroundColor Gray
        
        # Initial count
        $initialCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        $startTime = Get-Date
        
        Start-Sleep -Seconds 10
        
        # Final count
        $finalCount = docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM orders;" 2>$null
        $endTime = Get-Date
        
        if ($initialCount -match '(\d+)' -and $finalCount -match '(\d+)') {
            $initial = [int]$matches[1]
            if ($finalCount -match '(\d+)') {
                $final = [int]$matches[1]
                $recordsProcessed = $final - $initial
                $elapsed = ($endTime - $startTime).TotalSeconds
                $throughput = [math]::Round($recordsProcessed / $elapsed, 2)
                
                Write-Metric "Records Processed" $recordsProcessed "records" "White"
                Write-Metric "Time Elapsed" $([math]::Round($elapsed, 2)) "seconds" "White"
                Write-Metric "Current Throughput" $throughput "records/sec" $(if($throughput -gt 10) {"Green"} else {"Yellow"})
            }
        }
    } catch {
        Write-Host "Error measuring throughput: $_" -ForegroundColor Red
    }

    # 5. Network and connection latency
    Write-SubHeader "5. Network & Connection Latency"
    
    try {
        # Test PostgreSQL connection latency
        $pgLatencyTest = Measure-Command {
            docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d postgres -c "SELECT 1;" 2>$null
        }
        Write-Metric "Source DB Latency" $([math]::Round($pgLatencyTest.TotalMilliseconds, 2)) "ms" "Green"
        
        # Test target PostgreSQL connection latency
        $targetLatencyTest = Measure-Command {
            docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -c "SELECT 1;" 2>$null
        }
        Write-Metric "Target DB Latency" $([math]::Round($targetLatencyTest.TotalMilliseconds, 2)) "ms" "Green"
        
        # Test Kafka Connect API latency
        $kafkaLatencyTest = Measure-Command {
            try {
                Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method GET -TimeoutSec 5 2>$null
            } catch {
                # Ignore errors for latency measurement
            }
        }
        Write-Metric "Kafka Connect API" $([math]::Round($kafkaLatencyTest.TotalMilliseconds, 2)) "ms" "Green"
        
    } catch {
        Write-Host "Error measuring connection latency: $_" -ForegroundColor Red
    }

    # 6. Container resource impact on latency
    Write-SubHeader "6. Resource Impact Analysis"
    
    try {
        $dockerStats = docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>$null
        if ($dockerStats) {
            Write-Host "Container Resource Usage:" -ForegroundColor Gray
            $dockerStats | ForEach-Object {
                if ($_ -and $_ -notmatch "NAME") {
                    Write-Host "  $_" -ForegroundColor White
                }
            }
        }
    } catch {
        Write-Host "Error getting container stats: $_" -ForegroundColor Red
    }

    # 7. Performance recommendations
    Write-SubHeader "7. Latency Optimization Recommendations"
    
    Write-Host "Performance Optimization Tips:" -ForegroundColor Gray
    Write-Host "  • Keep replication lag under 60 seconds" -ForegroundColor Cyan
    Write-Host "  • Monitor connector health regularly" -ForegroundColor Cyan
    Write-Host "  • Ensure adequate memory for Kafka containers" -ForegroundColor Cyan
    Write-Host "  • Use batch processing for high-volume inserts" -ForegroundColor Cyan
    Write-Host "  • Monitor network latency between containers" -ForegroundColor Cyan
}

# Export functionality
function Export-LatencyReport {
    param([string]$FilePath)
    
    $reportDir = Split-Path $FilePath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $exportFile = $FilePath -replace "\.txt$", "_$timestamp.txt"
    
    Write-Host "`nExporting latency report to: $exportFile" -ForegroundColor Yellow
    
    # Capture output and save to file
    Get-CDCLatencyMetrics | Out-File -FilePath $exportFile -Encoding UTF8
    
    Write-Host "Report exported successfully!" -ForegroundColor Green
    return $exportFile
}

# Main execution
Write-Host "CDC Latency Monitor" -ForegroundColor Magenta
Write-Host "==================" -ForegroundColor Magenta

if ($Export) {
    $exportedFile = Export-LatencyReport -FilePath $OutputPath
    Write-Host "`nLatency report saved to: $exportedFile" -ForegroundColor Green
} else {
    Get-CDCLatencyMetrics
}

Write-Host "`nLatency monitoring completed at $(Get-Timestamp)" -ForegroundColor Gray
Write-Host "Use -Export flag to save this report to file" -ForegroundColor Gray
