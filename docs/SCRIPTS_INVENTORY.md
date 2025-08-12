# 📋 CDC Monitoring Scripts Inventory

## ✅ WORKING SCRIPTS

### PowerShell Scripts (Confirmed Working - 6 scripts)
1. **`cdc-live-monitor.ps1`** - Real-time CDC performance monitoring
   - Multi-phase monitoring (idle, processing, final)
   - Live Docker stats integration
   - Database metrics collection

2. **`cdc-performance-monitor-simple.ps1`** - Simplified performance monitoring
   - Essential metrics only
   - Quick health checks
   - Resource usage tracking

3. **`cdc-quick-monitor.ps1`** - Quick status check
   - Fast overview of system state
   - Basic connectivity tests
   - Error detection

4. **`simple-insert-test.ps1`** - Basic data insertion testing
   - Inserts test records
   - Verifies CDC propagation
   - Simple validation

5. **`cdc-clickhouse-style-monitor.ps1`** - Advanced analytics monitoring
   - ClickHouse-style metrics
   - Detailed performance analytics
   - Trend analysis

6. **`cdc-latency-monitor.ps1`** - Latency-focused monitoring
   - End-to-end latency measurement
   - Batch processing time analysis
   - Performance bottleneck detection

### Python Scripts (Confirmed Working - 4 scripts)
1. **`cdc_stress_test_dynamic.py`** - Dynamic stress testing
   - Configurable via `config.yaml`
   - Batch insert operations
   - Real-time performance metrics

2. **`test_dynamic.py`** - Database connectivity testing
   - Connection validation
   - Basic CRUD operations
   - Schema verification

3. **`mass_insert_monitor.py`** - 100k+ Mass insert with 3-phase monitoring
   - Insert large volumes of data (default 100k records)
   - 3-phase Docker monitoring (idle, processing, final)
   - Real-time batch performance tracking
   - Comprehensive Docker stats collection
   - Usage: `python mass_insert_monitor.py [record_count] [batch_size]`

4. **`comprehensive_performance_monitor.py`** - Complete pipeline performance analysis
   - 3-phase monitoring with load simulation
   - Docker container usage tracking
   - Kafka topics and consumer groups analysis
   - Database performance metrics
   - End-to-end latency measurements
   - Error log analysis
   - Complete health scoring
   - Usage: `python comprehensive_performance_monitor.py [duration_minutes]`

### Configuration Files
1. **`config.yaml`** - Main configuration file
   - Database connections (source/target)
   - Test parameters
   - Performance thresholds
   - Docker container settings

## 🗑️ REMOVED SCRIPTS
The following scripts were removed due to database/schema compatibility issues:
- Various Python scripts with hardcoded schemas
- Scripts referencing non-existent tables
- Outdated monitoring scripts

## 🎯 USAGE GUIDELINES

### For Real-time Monitoring:
```powershell
# Full monitoring cycle
.\cdc-live-monitor.ps1

# Quick health check
.\cdc-quick-monitor.ps1

# Latency analysis
.\cdc-latency-monitor.ps1
```

### For Mass Data Testing:
```bash
# Mass insert with 3-phase monitoring (100k records)
python mass_insert_monitor.py 100000 5000

# Quick mass insert test (1k records)
python mass_insert_monitor.py 1000 100

# Database connectivity test
python test_dynamic.py

# Stress testing
python cdc_stress_test_dynamic.py
```

### For Comprehensive Performance Analysis:
```bash
# Full performance monitoring with 3-phase analysis
python comprehensive_performance_monitor.py 5

# Quick performance check (1 minute)
python comprehensive_performance_monitor.py 1
```

### For Performance Analysis:
```powershell
# Advanced analytics
.\cdc-clickhouse-style-monitor.ps1

# Simple metrics
.\cdc-performance-monitor-simple.ps1
```

## 🔧 CONFIGURATION
All scripts use the correct database configuration:
- **Source Database**: `inventory`
- **Source Schema**: `inventory` 
- **Source Table**: `orders`
- **Target Database**: `postgres`
- **Target Schema**: `inventory`

## 📊 OUTPUT
All scripts generate:
- Real-time metrics (no hardcoded data)
- JSON reports in `testing-results/`
- Live performance statistics
- Latency measurements

## ⚠️ REQUIREMENTS
- PowerShell 5.1+
- Python 3.7+ with packages: `asyncpg`, `PyYAML`, `psutil`, `requests`
- Docker containers running
- PostgreSQL accessible on ports 5432/5433

## 🎯 TOTAL WORKING SCRIPTS: 10
- **PowerShell**: 6 scripts  
- **Python**: 4 scripts
- **All tested and verified working with real data**
