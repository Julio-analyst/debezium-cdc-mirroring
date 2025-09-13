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

# ...existing monitoring and analysis functions (see original script for full content)...

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
# ...call analysis functions here...
Write-Host "CDC Pipeline Statistics Analysis Completed!" -ForegroundColor Green
Write-Host "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Gray
