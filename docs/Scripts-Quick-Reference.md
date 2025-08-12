# CDC Scripts Quick Reference

**Last Updated:** August 12, 2025

## 🔥 Quick Commands

### Health Check
```powershell
.\scripts\cdc-quick-monitor.ps1
```

### Full Performance Analysis
```powershell
.\scripts\cdc-performance-monitor-simple.ps1 -Export
```

### Stress Test (10K records)
```powershell
.\scripts\simple-insert-test.ps1 -RecordCount 10000
```

### Live Monitoring with Test
```powershell
.\scripts\cdc-live-monitor.ps1 -TestRecords 5000
```

### Dashboard View
```powershell
.\scripts\cdc-clickhouse-style-monitor.ps1 -DetailedAnalysis
```

### Latency Analysis
```powershell
.\scripts\cdc-latency-monitor.ps1 -Detailed
```

---

## 📊 Script Functions Summary

| Script | Main Function | Key Features |
|--------|---------------|--------------|
| `cdc-quick-monitor.ps1` | Health check | Container status, DB counts |
| `cdc-performance-monitor-simple.ps1` | Analytics | Table stats, CDC ops, export |
| `cdc-live-monitor.ps1` | Multi-phase | Docker stats, 3-phase monitoring |
| `simple-insert-test.ps1` | Stress test | Bulk inserts, performance tracking |
| `cdc-clickhouse-style-monitor.ps1` | Dashboard | Visual stats, resource analysis |
| `cdc-latency-monitor.ps1` | Latency analysis | Network performance, response times |

---

## ⚡ Common Parameters

```powershell
# Record counts
-RecordCount 10000
-TestRecords 5000

# Batch processing
-BatchSize 500
-BatchSize 1000

# Export options
-Export
-ExportPath "custom\path.txt"

# Analysis modes
-DetailedAnalysis
-ShowProgress
-RunStressTest
```

---

## 🎯 Typical Workflow

1. **Health Check** → `cdc-quick-monitor.ps1`
2. **Baseline Stats** → `cdc-performance-monitor-simple.ps1`
3. **Stress Test** → `simple-insert-test.ps1`
4. **Live Monitor** → `cdc-live-monitor.ps1`
5. **Final Analysis** → `cdc-clickhouse-style-monitor.ps1`

---

## 🔍 What Each Script Shows

### `cdc-quick-monitor.ps1`
- ✅ Container health status
- 📊 Basic table counts
- 🔗 Connector status

### `cdc-performance-monitor-simple.ps1`
- 📈 PostgreSQL statistics
- 🔄 CDC operation breakdown
- 📋 Performance recommendations
- 💾 Export capability

### `cdc-live-monitor.ps1`
- 🐳 Live Docker stats (CPU, memory)
- 📊 3-phase comparison
- 🔄 CDC operation details
- ⚡ Integrated stress testing

### `simple-insert-test.ps1`
- 📥 Bulk data insertion
- ⏱️ Performance timing
- 📊 Throughput metrics
- 🎯 Batch processing

### `cdc-clickhouse-style-monitor.ps1`
- 📊 Dashboard-style output
- 📈 Table size analysis
- 🔍 Data distribution
- 💻 Resource utilization

### `cdc-latency-monitor.ps1`
- 📊 Comprehensive latency analysis
- 🔗 Database connection response times
- 📈 Real-time throughput measurement
- 🔍 Network performance breakdown
- 💻 API response time monitoring

---

## 🛠️ Troubleshooting Quick Fixes

**Container not running:**
```powershell
docker-compose up -d
```

**Database connection issues:**
```powershell
docker ps | grep postgres
```

**API connection problems:**
```powershell
curl http://localhost:8083/connectors
```

**Reset environment:**
```powershell
docker-compose down -v
docker-compose up -d
```
