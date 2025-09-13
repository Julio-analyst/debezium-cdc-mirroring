# ===================================================================
# CDC Pipeline INSERT Stress Test FINAL - Resource & Performance Logging
# ===================================================================
# Purpose: Test CDC pipeline dengan INSERT dan log resource docker tiap batch
# Author: CDC Pipeline Team  
# Version: 2.0
# Last Updated: 2025-08-21
# ===================================================================

param(
    [int]$RecordCount = 1000,
    [int]$BatchSize = 100,
    [int]$DelayBetweenBatches = 1,
    [switch]$ShowProgress
)

# ===================================================================
# CONFIGURATION and VARIABLES
# ===================================================================

$script:METRICS = @{
    StartTime = $null
    EndTime = $null
    TotalRecords = 0
    SuccessfulOperations = 0
    FailedOperations = 0
    BatchTimes = @()
    Errors = @()
    CustomerIds = @()
    ProductIds = @()
}

$Colors = @{
    Info = "Cyan"
    Success = "Green" 
    Warning = "Yellow"
    Error = "Red"
    Progress = "Blue"
}

# Generate unique test ID dengan timestamp
$script:TestId = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$LogPath = "testing-results/cdc-stress-test-$($script:TestId).log"
$ResourceLogPath = "testing-results/cdc-resource-usage-$($script:TestId).log"

# ===================================================================
# UTILITY FUNCTIONS
function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "Info"
    # Check PostgreSQL container
    $pgStatus = docker ps --filter "name=debezium-cdc-mirroring-postgres-1" --format "{{.Status}}" 2>$null
    if (-not $pgStatus -or $pgStatus -notmatch "Up") {
        Write-Log "PostgreSQL container is not running" "Error"
        return $false
    }
    # Test PostgreSQL connection
    try {
        $testResult = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c "SELECT 1;" 2>$null
        if ($testResult -match "1") {
            Write-Log "PostgreSQL: Connected" "Success"
        } else {
            Write-Log "PostgreSQL connection failed" "Error"
            return $false
        }
    } catch {
        Write-Log "Cannot connect to PostgreSQL: $($_.Exception.Message)" "Error"
        return $false
    }
    Write-Log "All prerequisites met!" "Success"
    return $true
}

function Get-ExistingCustomers {
    try {
        Write-Log "Fetching existing customers..." "Info"
        $result = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c "SELECT id FROM inventory.customers;" 2>$null
        $customerIds = @()
        $result -split "`n" | ForEach-Object {
            if ($_ -match '^\s*(\d+)\s*$') {
                $customerIds += [int]$matches[1]
            }
        }
        if ($customerIds.Count -eq 0) {
            throw "No customers found"
        }
        Write-Log "Found $($customerIds.Count) customers: $($customerIds -join ', ')" "Success"
        return $customerIds
    } catch {
        throw "Failed to fetch customers: $($_.Exception.Message)"
    }
}

function Get-ExistingProducts {
    try {
        Write-Log "Fetching existing products..." "Info"
        $result = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c "SELECT id FROM inventory.products;" 2>$null
        $productIds = @()
        $result -split "`n" | ForEach-Object {
            if ($_ -match '^\s*(\d+)\s*$') {
                $productIds += [int]$matches[1]
            }
        }
        if ($productIds.Count -eq 0) {
            throw "No products found"
        }
        Write-Log "Found $($productIds.Count) products: $($productIds -join ', ')" "Success"
        return $productIds
    } catch {
        throw "Failed to fetch products: $($_.Exception.Message)"
    }
}

function Get-CurrentOrderCount {
    try {
        $result = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c "SELECT COUNT(*) FROM inventory.orders;" 2>$null
        $count = $result -split "`n" | Where-Object { $_ -match '^\s*(\d+)\s*$' } | ForEach-Object { [int]$matches[1] } | Select-Object -First 1
        return $count
    } catch {
        return 0
    }
}
# ===================================================================

function Write-Log {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = $Colors[$Type]
    $fullMessage = "[$timestamp] $Message"
    Write-Host $fullMessage -ForegroundColor $color
    Add-Content -Path $LogPath -Value $fullMessage
}

function Write-ResourceUsage {
    param([string]$Phase)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp`t$Phase"
    
    # Log header dengan informasi test
    if ($Phase -eq "BASELINE") {
        $testInfo = @"
========================================
CDC INSERT Stress Test Resource Log
Test ID: $($script:TestId)
Test Start: $timestamp
Record Count: $RecordCount
Batch Size: $BatchSize
========================================

"@
        Add-Content -Path $ResourceLogPath -Value $testInfo
    }
    
    try {
        # Get all running containers first to identify which ones exist
        $runningContainers = docker ps --format "{{.Names}}"
        
        if ($runningContainers) {
            # Filter for CDC-related containers
            $cdcContainers = @($runningContainers | Where-Object { 
                $_ -like "*debezium*" -or 
                $_ -like "*kafka*" -or 
                $_ -like "*zookeeper*" -or 
                $_ -like "*connect*" -or
                $_ -like "*postgres*" -or
                $_ -like "*kafdrop*"
            })
            
            $allStats = ""
            
            # Get CDC container stats
            if ($cdcContainers.Count -gt 0) {
                $statsCmd = "docker stats --no-stream --format ""table {{.Name}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.NetIO}}`t{{.BlockIO}}"" " + ($cdcContainers -join " ")
                $allStats = Invoke-Expression $statsCmd 2>$null | Out-String
            } else {
                $allStats = "(No CDC containers found running)"
            }
        } else {
            $allStats = "(No containers found running)"
        }
    } catch { 
        $allStats = "(docker stats unavailable: $($_.Exception.Message))" 
    }
    
    Add-Content -Path $ResourceLogPath -Value "$logLine"
    Add-Content -Path $ResourceLogPath -Value ("DOCKER STATS:" + [Environment]::NewLine + $allStats)
    Add-Content -Path $ResourceLogPath -Value ("=" * 100)
    
    # Log to main log file juga untuk tracking
    Write-Log "Resource usage logged for phase: $Phase" "Info"
}

# ...existing functions: Test-Prerequisites, Get-ExistingCustomers, Get-ExistingProducts, Get-CurrentOrderCount...

function Invoke-BulkInsertTest {
    param([int]$TotalRecords, [int]$BatchSize, [array]$CustomerIds, [array]$ProductIds)
    Write-Log "Starting bulk INSERT test: $TotalRecords records in batches of $BatchSize" "Info"
    $successCount = 0
    $batchNumber = 0
    $totalBatches = [math]::Ceiling($TotalRecords / $BatchSize)
    for ($startRecord = 0; $startRecord -lt $TotalRecords; $startRecord += $BatchSize) {
        $batchNumber++
        $endRecord = [math]::Min($startRecord + $BatchSize, $TotalRecords)
        $currentBatchSize = $endRecord - $startRecord
        if ($ShowProgress) {
            Write-Log "Processing batch $batchNumber/$totalBatches (records $($startRecord + 1)-$endRecord)" "Progress"
        }
        $batchStart = Get-Date
        $insertValues = @()
        for ($i = 0; $i -lt $currentBatchSize; $i++) {
            $customerId = $CustomerIds | Get-Random
            $productId = $ProductIds | Get-Random
            $quantity = Get-Random -Minimum 1 -Maximum 100
            $orderDate = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 30)).ToString("yyyy-MM-dd")
            $insertValues += "('$orderDate', $customerId, $quantity, $productId)"
        }
        $insertQuery = @"
INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id)
VALUES $($insertValues -join ', ');
"@
        try {
            $result = docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c $insertQuery 2>$null
            if ($result -match "INSERT 0 $currentBatchSize") {
                $successCount += $currentBatchSize
                $script:METRICS.SuccessfulOperations += $currentBatchSize
            } else {
                $script:METRICS.FailedOperations += $currentBatchSize
                $script:METRICS.Errors += "Batch $batchNumber failed: $result"
                Write-Log "Batch $batchNumber failed: $result" "Error"
            }
        } catch {
            $script:METRICS.FailedOperations += $currentBatchSize
            $script:METRICS.Errors += "Batch $batchNumber exception: $($_.Exception.Message)"
            Write-Log "Batch $batchNumber exception: $($_.Exception.Message)" "Error"
        }
        $batchEnd = Get-Date
        $batchDuration = ($batchEnd - $batchStart).TotalMilliseconds
        $script:METRICS.BatchTimes += $batchDuration
        # Log resource usage per batch
    Write-ResourceUsage -Phase "INSERT-BATCH-$batchNumber"
    # Log batch summary
    $failedOps = $script:METRICS.FailedOperations
    $batchLog = "Batch " + $batchNumber + ": " + $currentBatchSize + " records, " + $batchDuration + " ms, Success: " + $successCount + ", Failed: " + $failedOps
    Add-Content -Path $LogPath -Value $batchLog
        # Progress update every 10 batches
        if ($batchNumber % 10 -eq 0) {
            $progress = [math]::Round(($endRecord / $TotalRecords) * 100, 1)
            $avgBatchTime = if ($script:METRICS.BatchTimes.Count -gt 0) {
                [math]::Round(($script:METRICS.BatchTimes | Measure-Object -Average).Average, 2)
            } else { 0 }
            Write-Log "Progress: $progress% | Success: $successCount/$endRecord | Avg Batch: ${avgBatchTime}ms" "Progress"
        }
        if ($DelayBetweenBatches -gt 0 -and $batchNumber -lt $totalBatches) {
            Start-Sleep -Seconds $DelayBetweenBatches
        }
    }
    Write-Log "Bulk INSERT completed: $successCount/$TotalRecords records inserted successfully" "Success"
    return $successCount
}

function Show-Results {
    $script:METRICS.EndTime = Get-Date
    $totalDuration = $script:METRICS.EndTime - $script:METRICS.StartTime
    Write-Log "" "Info"
    Write-Log "PERFORMANCE RESULTS" "Success"
    Write-Log "===================" "Success"
    Write-Log "Test Duration: $($totalDuration.ToString('hh\:mm\:ss'))" "Info"
    Write-Log "Total Records Attempted: $($script:METRICS.TotalRecords)" "Info"
    Write-Log "Successful Operations: $($script:METRICS.SuccessfulOperations)" "Success"
    Write-Log "Failed Operations: $($script:METRICS.FailedOperations)" "Error"
    $successRate = if ($script:METRICS.TotalRecords -gt 0) {
        [math]::Round(($script:METRICS.SuccessfulOperations / $script:METRICS.TotalRecords) * 100, 2)
    } else { 0 }
    Write-Log "Success Rate: $successRate%" "Info"
    $throughput = if ($totalDuration.TotalSeconds -gt 0) {
        [math]::Round($script:METRICS.SuccessfulOperations / $totalDuration.TotalSeconds, 2)
    } else { 0 }
    Write-Log "Throughput: $throughput operations/second" "Success"
    if ($script:METRICS.BatchTimes.Count -gt 0) {
        $avgBatchTime = [math]::Round(($script:METRICS.BatchTimes | Measure-Object -Average).Average, 2)
        $maxBatchTime = [math]::Round(($script:METRICS.BatchTimes | Measure-Object -Maximum).Maximum, 2)
        $minBatchTime = [math]::Round(($script:METRICS.BatchTimes | Measure-Object -Minimum).Minimum, 2)
        Write-Log "Average Batch Time: ${avgBatchTime}ms" "Info"
        Write-Log "Max Batch Time: ${maxBatchTime}ms" "Warning"
        Write-Log "Min Batch Time: ${minBatchTime}ms" "Success"
    }
    if ($script:METRICS.Errors.Count -gt 0) {
        Write-Log "Errors encountered: $($script:METRICS.Errors.Count)" "Error"
        $script:METRICS.Errors | Select-Object -First 3 | ForEach-Object {
            Write-Log "  $_" "Error"
        }
    }
    Write-Log "===================" "Success"
}

function Main {
    try {
        $script:METRICS.StartTime = Get-Date
        $script:METRICS.TotalRecords = $RecordCount
        Write-Log "CDC Pipeline INSERT Stress Test FINAL" "Info"
        Write-Log "=====================================" "Info"
        Write-Log "Test ID: $($script:TestId)" "Info"
        Write-Log "Target Records: $RecordCount" "Info"
        Write-Log "Batch Size: $BatchSize" "Info"
        Write-Log "Delay Between Batches: ${DelayBetweenBatches}s" "Info"
        Write-Log "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Info"
        Write-Log "Stress Test Log: $LogPath" "Info"
        Write-Log "Resource Usage Log: $ResourceLogPath" "Info"
        Write-Log "" "Info"
        if (-not (Test-Prerequisites)) {
            throw "Prerequisites check failed"
        }
        $customerIds = Get-ExistingCustomers
        $productIds = Get-ExistingProducts
        $script:METRICS.CustomerIds = $customerIds
        $script:METRICS.ProductIds = $productIds
        $initialOrderCount = Get-CurrentOrderCount
        Write-Log "Initial order count: $initialOrderCount" "Info"
    Write-ResourceUsage -Phase "BASELINE"
        Write-Log "Starting INSERT stress test..." "Success"
        $successCount = Invoke-BulkInsertTest -TotalRecords $RecordCount -BatchSize $BatchSize -CustomerIds $customerIds -ProductIds $productIds
        Start-Sleep -Seconds 5
        $finalOrderCount = Get-CurrentOrderCount
        $actualInserted = $finalOrderCount - $initialOrderCount
        Write-Log "Final order count: $finalOrderCount (inserted: $actualInserted)" "Success"
        Show-Results
        Write-ResourceUsage -Phase "FINAL"
        
        # Add test completion summary to resource log
        $completionSummary = @"

========================================
Test Completion Summary
Test ID: $($script:TestId)
Test End: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Duration: $((Get-Date) - $script:METRICS.StartTime)
Records Processed: $successCount/$RecordCount
Success Rate: $(if ($RecordCount -gt 0) { [math]::Round(($successCount / $RecordCount) * 100, 2) } else { 0 })%
========================================
"@
        Add-Content -Path $ResourceLogPath -Value $completionSummary
        
        Write-Log "" "Info"
        Write-Log "Stress test completed!" "Success"
        Write-Log "Unique log files generated with Test ID: $($script:TestId)" "Success"
        Write-Log "Check log file: $LogPath" "Info"
        Write-Log "Check resource log file: $ResourceLogPath" "Info"
    } catch {
        Write-Log "Stress test failed: $($_.Exception.Message)" "Error"
        if ($script:METRICS.StartTime) {
            Show-Results
        }
        throw
    }
}

if (-not (Test-Path "testing-results")) {
    New-Item -ItemType Directory -Path "testing-results" -Force | Out-Null
}
try {
    Main
    exit 0
} catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" "Error"
    exit 1
}
# ===================================================================
# END OF SCRIPT
# ===================================================================

