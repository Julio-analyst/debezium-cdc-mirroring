# CDC Pipeline Scripts Documentation

**Last Updated:** August 12, 2025  
**Version:** 1.0  
**Status:** All scripts tested and verified ✅

---

## 📋 Overview

This document provides comprehensive documentation for the CDC (Change Data Capture) pipeline monitoring and testing scripts. All scripts have been tested and verified to use **real-time data** with no hardcoded values.

## 🎯 Core Scripts (Tested & Verified)

### 1. `cdc-live-monitor.ps1` - Multi-phase Monitoring with Stress Test

**Purpose:** Real-time multi-phase monitoring of CDC pipeline performance with integrated stress testing.

**Location:** `scripts/cdc-live-monitor.ps1`

**Parameters:**
- `TestRecords` (int): Number of test records to insert (default: 5000)
- `BatchSize` (int): Records per batch (default: 500)
- `RunStressTest` (switch): Run integrated stress test

**Key Features:**
- **Multi-phase monitoring**: Baseline → Insert Test → Final Comparison
- **Live Docker stats**: CPU, memory, network I/O from `docker stats`
- **CDC operation breakdown**: Creates, updates, deletes, snapshots
- **Database metrics**: Real-time table counts via PostgreSQL queries
- **Integration**: Combines monitoring with actual insert operations

**Data Sources:**
- Docker stats API (real-time)
- Kafka Connect REST API
- PostgreSQL database queries
- Container status from `docker ps`

**Usage Examples:**
```powershell
# Standard monitoring with 5K records
.\scripts\cdc-live-monitor.ps1

# Custom test size
.\scripts\cdc-live-monitor.ps1 -TestRecords 10000 -BatchSize 1000

# With stress test
.\scripts\cdc-live-monitor.ps1 -RunStressTest
```

**Output Phases:**
1. **Baseline**: Initial system state
2. **INSERT Test**: Performance during data insertion
3. **Final**: Post-test comparison and metrics

---

### 2. `cdc-performance-monitor-simple.ps1` - Performance Analytics

**Purpose:** Comprehensive CDC pipeline performance analysis with ClickHouse-style statistics.

**Location:** `scripts/cdc-performance-monitor-simple.ps1`

**Parameters:**
- `Export` (switch): Export results to file
- `ExportPath` (string): Custom export file path

**Key Features:**
- **PostgreSQL statistics**: Table sizes, row counts, data distribution
- **Kafka analysis**: Topics and messaging metrics
- **CDC operations**: CREATE/UPDATE/DELETE breakdown
- **Container health**: Service status monitoring
- **Performance summary**: Recommendations and insights

**Data Sources:**
- PostgreSQL system catalogs (`pg_stat_user_tables`, `pg_size_pretty`)
- Kafka Connect REST API (`/connectors`, `/status`)
- Docker container status
- Database table statistics (real-time queries)

**Functions:**
- `Write-ColoredOutput`: Formatted console output
- `Get-PostgreSQLStats`: Live database statistics
- `Get-KafkaTopicStats`: Topic analysis
- `Get-CDCOperationStats`: Change operation breakdown
- `Get-ContainerHealth`: Service monitoring

**Usage Examples:**
```powershell
# Full monitoring report
.\scripts\cdc-performance-monitor-simple.ps1

# Export to file
.\scripts\cdc-performance-monitor-simple.ps1 -Export

# Custom export path
.\scripts\cdc-performance-monitor-simple.ps1 -Export -ExportPath "reports\performance.txt"
```

---

### 3. `cdc-quick-monitor.ps1` - Quick Status Check

**Purpose:** Fast CDC pipeline health check and status overview.

**Location:** `scripts/cdc-quick-monitor.ps1`

**Parameters:**
- `Export` (switch): Export results to file

**Key Features:**
- **Container health**: Quick status of all CDC services
- **Database statistics**: Live table counts
- **CDC connector status**: Active connector health
- **Fast execution**: Optimized for quick checks

**Data Sources:**
- `docker ps` for container status
- PostgreSQL queries for table counts
- Kafka Connect API for connector status

**Functions:**
- `Write-Header`: Section formatting
- `Write-Metric`: Metric display
- Quick health checks without detailed analysis

**Usage Examples:**
```powershell
# Quick health check
.\scripts\cdc-quick-monitor.ps1

# Export quick report
.\scripts\cdc-quick-monitor.ps1 -Export
```

---

### 4. `simple-insert-test.ps1` - Bulk Insert Stress Test

**Purpose:** CDC pipeline stress testing with bulk INSERT operations.

**Location:** `scripts/simple-insert-test.ps1`

**Parameters:**
- `RecordCount` (int): Number of test records (default: 100,000)
- `BatchSize` (int): Records per batch (default: 1,000)
- `DelayBetweenBatches` (int): Seconds between batches (default: 1)
- `ShowProgress` (switch): Show detailed progress

**Key Features:**
- **Bulk data generation**: Realistic test data creation
- **Batch processing**: Controlled insertion rates
- **Performance tracking**: Timing and throughput metrics
- **Error handling**: Failed operation tracking
- **Progress monitoring**: Real-time batch progress

**Test Data:**
- Customer records with realistic names, emails, addresses
- Product records with categories, prices, descriptions
- Order records linking customers and products
- Random data generation for realistic testing

**Metrics Tracked:**
- Total execution time
- Records per second throughput
- Successful vs. failed operations
- Batch processing times
- Database connection performance

**Usage Examples:**
```powershell
# Default 100K records
.\scripts\simple-insert-test.ps1

# Custom test size
.\scripts\simple-insert-test.ps1 -RecordCount 50000

# Smaller batches with progress
.\scripts\simple-insert-test.ps1 -RecordCount 10000 -BatchSize 500 -ShowProgress

# Fast test with minimal delay
.\scripts\simple-insert-test.ps1 -RecordCount 5000 -DelayBetweenBatches 0
```

---

### 5. `cdc-clickhouse-style-monitor.ps1` - Dashboard-style Monitoring

**Purpose:** ClickHouse-inspired analytics dashboard for CDC pipeline performance.

**Location:** `scripts/cdc-clickhouse-style-monitor.ps1`

**Parameters:**
- `RecordCount` (int): Test record count (default: 5,000)
- `BatchSize` (int): Batch size for tests (default: 500)
- `DetailedAnalysis` (switch): Enable detailed analytics

**Key Features:**
- **Table statistics**: Row counts, sizes, average row sizes
- **Data distribution**: Analysis of data spread across tables
- **Performance metrics**: Query execution times
- **Resource utilization**: Memory and CPU analysis
- **Dashboard format**: Clean, organized output similar to ClickHouse

**Data Sources:**
- PostgreSQL system views (`pg_stat_user_tables`, `pg_total_relation_size`)
- Real-time table counts and sizes
- Docker resource statistics
- Kafka topic metrics

**Functions:**
- `Write-Header`: Section headers with analysis descriptions
- `Write-TableHeader`: Formatted table headers
- `Write-TableRow`: Consistent table row formatting
- `Get-DatabaseTableStats`: Live database statistics

**Usage Examples:**
```powershell
# Standard dashboard
.\scripts\cdc-clickhouse-style-monitor.ps1

# Detailed analysis
.\scripts\cdc-clickhouse-style-monitor.ps1 -DetailedAnalysis

# Custom test parameters
.\scripts\cdc-clickhouse-style-monitor.ps1 -RecordCount 10000 -BatchSize 1000
```

---

### 6. `cdc-latency-monitor.ps1` - Comprehensive Latency Analysis

**Purpose:** Comprehensive CDC pipeline latency monitoring and network performance analysis.

**Location:** `scripts/cdc-latency-monitor.ps1`

**Parameters:**
- `Detailed` (switch): Enable detailed analysis mode
- `Export` (switch): Export results to file
- `OutputPath` (string): Custom export file path (default: `.\reports\cdc-latency-report.txt`)

**Key Features:**
- **Database replication lag**: Time-based lag analysis in seconds/minutes
- **Connection latency**: Database and API response times in milliseconds
- **Real-time throughput**: Records processed per second measurement
- **Network analysis**: Component-wise latency breakdown
- **Resource impact**: Container performance correlation with latency
- **Optimization recommendations**: Performance improvement suggestions

**Data Sources:**
- PostgreSQL timestamp-based lag queries
- Docker container connection tests (`Measure-Command`)
- Kafka Connect REST API response times
- Real-time throughput measurement over time intervals
- Container resource statistics correlation

**Functions:**
- `Get-CDCLatencyMetrics`: Main latency analysis function
- `Write-Header`: Formatted section headers
- `Write-SubHeader`: Subsection formatting
- `Write-Metric`: Standardized metric display with color coding
- `Get-Timestamp`: Consistent timestamp formatting

**Latency Metrics:**
- **Database Replication Lag**: Time difference between source and target
- **Connection Latency**: Response time for database queries
- **API Latency**: Kafka Connect REST API response time
- **Throughput Analysis**: Records/second during monitoring period

**Usage Examples:**
```powershell
# Standard latency analysis
.\scripts\cdc-latency-monitor.ps1

# Detailed analysis with export
.\scripts\cdc-latency-monitor.ps1 -Detailed -Export

# Custom export path
.\scripts\cdc-latency-monitor.ps1 -Export -OutputPath "reports\latency-$(Get-Date -Format 'yyyy-MM-dd').txt"
```

**Interpretation Guide:**
- **< 100ms DB latency**: Excellent performance
- **100-500ms DB latency**: Moderate, acceptable for most use cases
- **> 500ms DB latency**: High, needs optimization
- **< 10ms API latency**: Excellent responsiveness
- **Replication lag < 60 seconds**: Good synchronization

---

## 🔧 Technical Implementation

### Real-time Data Sources

**All scripts use live data from:**

1. **Docker Stats API:**
   ```powershell
   docker stats --no-stream --format "{{.Name}};{{.CPUPerc}};{{.MemUsage}}"
   ```

2. **PostgreSQL Queries:**
   ```sql
   SELECT COUNT(*) FROM inventory.customers;
   SELECT COUNT(*) FROM inventory.products;
   SELECT COUNT(*) FROM inventory.orders;
   ```

3. **Kafka Connect REST API:**
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method GET
   ```

4. **Container Status:**
   ```powershell
   docker ps --format "{{.Names}};{{.Status}}"
   ```

### Error Handling

All scripts include:
- Try-catch blocks for external API calls
- Graceful degradation when services are unavailable
- Clear error messages for troubleshooting
- Fallback values for failed queries

### Performance Considerations

- **Optimized queries**: Use efficient PostgreSQL queries
- **Minimal API calls**: Reduce external service dependencies
- **Caching**: Store frequently used values during execution
- **Batch processing**: Handle large datasets efficiently

---

## 📊 Data Verification

### Proof of Real-time Data

**All hardcoded data has been removed and replaced with:**

1. **Live Docker statistics** from container runtime
2. **Real database queries** to PostgreSQL
3. **Active API calls** to Kafka Connect
4. **Dynamic timestamps** and calculations

### Testing Results

All scripts have been tested and verified:
- ✅ **No hardcoded values** in output
- ✅ **Real-time data sources** confirmed
- ✅ **Multi-phase monitoring** working
- ✅ **Integration** between scripts verified
- ✅ **Error handling** tested

---

## 🚀 Usage Workflow

### Recommended Execution Order

1. **Start with health check:**
   ```powershell
   .\scripts\cdc-quick-monitor.ps1
   ```

2. **Run performance analysis:**
   ```powershell
   .\scripts\cdc-performance-monitor-simple.ps1
   ```

3. **Execute stress test:**
   ```powershell
   .\scripts\simple-insert-test.ps1 -RecordCount 10000
   ```

4. **Monitor during test:**
   ```powershell
   .\scripts\cdc-live-monitor.ps1 -TestRecords 5000
   ```

5. **Dashboard analysis:**
   ```powershell
   .\scripts\cdc-clickhouse-style-monitor.ps1 -DetailedAnalysis
   ```

### Integration Scenarios

**Combined monitoring and testing:**
```powershell
# Run live monitor with integrated stress test
.\scripts\cdc-live-monitor.ps1 -TestRecords 20000 -RunStressTest

# Follow up with detailed analysis
.\scripts\cdc-performance-monitor-simple.ps1 -Export
```

---

## 🔍 Troubleshooting

### Common Issues

1. **Container not running:**
   - Check `docker ps` output
   - Verify Docker Compose services are up

2. **Database connection failed:**
   - Verify PostgreSQL container is healthy
   - Check connection parameters

3. **API calls failing:**
   - Ensure Kafka Connect is running on port 8083
   - Check network connectivity

4. **Permission errors:**
   - Run PowerShell as Administrator if needed
   - Check Docker permissions

### Log Files

Scripts generate logs in:
- `testing-results/` directory
- Console output with timestamps
- Error logs with detailed messages

---

## 📝 Script Comparison

| Script | Purpose | Speed | Detail Level | Use Case |
|--------|---------|-------|--------------|----------|
| `cdc-quick-monitor.ps1` | Health Check | Fast | Basic | Quick status |
| `cdc-performance-monitor-simple.ps1` | Analytics | Medium | High | Detailed analysis |
| `cdc-live-monitor.ps1` | Multi-phase | Medium | High | Stress testing |
| `simple-insert-test.ps1` | Stress Test | Variable | Medium | Load testing |
| `cdc-clickhouse-style-monitor.ps1` | Dashboard | Medium | High | Visual monitoring |
| `cdc-latency-monitor.ps1` | Latency Analysis | Medium | High | Network performance |

---

## 🎯 Best Practices

1. **Run health check first** before stress testing
2. **Monitor during tests** to catch issues early
3. **Use appropriate record counts** for your environment
4. **Export important results** for later analysis
5. **Check container resources** before large tests

---

## 📚 Dependencies

**Required Services:**
- Docker Desktop
- PostgreSQL containers (source and target)
- Apache Kafka
- Kafka Connect with Debezium
- PowerShell 5.1+

**External Tools:**
- `docker` CLI
- `psql` client (if available)
- Network access to containers

---

*This documentation covers the 5 core scripts that have been tested and verified for the CDC pipeline monitoring and testing workflow.*
