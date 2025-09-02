# Simple CDC Monitor Test
Write-Host "CDC Monitor Test Starting..." -ForegroundColor Green

# Test basic function
function Test-BasicFunction {
    Write-Host "Testing basic functionality..." -ForegroundColor Yellow
    
    try {
        # Test Docker containers
        $containers = docker ps --format "{{.Names}}"
        Write-Host "Found containers:" -ForegroundColor Cyan
        foreach ($container in $containers) {
            if ($container -match "debezium") {
                Write-Host "  - $container" -ForegroundColor Green
            }
        }
        
        # Test PostgreSQL connection
        $sourceTest = & docker exec debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c "SELECT 1;" 2>$null
        if ($sourceTest) {
            Write-Host "Source PostgreSQL: Connected" -ForegroundColor Green
        } else {
            Write-Host "Source PostgreSQL: Failed" -ForegroundColor Red
        }
        
        $targetTest = & docker exec debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres -c "SELECT 1;" 2>$null
        if ($targetTest) {
            Write-Host "Target PostgreSQL: Connected" -ForegroundColor Green
        } else {
            Write-Host "Target PostgreSQL: Failed" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

# Execute test
Test-BasicFunction
Write-Host "Test completed!" -ForegroundColor Green
