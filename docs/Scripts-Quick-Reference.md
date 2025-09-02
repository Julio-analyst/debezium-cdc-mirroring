# 🚀 Scripts Quick Reference Guide

> Panduan cepat penggunaan script untuk pipeline CDC Debezium PostgreSQL

---

## 📋 Daftar Script Utama

### 1. `insert_debezium.ps1` - Insert Data Test
### 2. `monitoring_debezium.ps1` - Pipeline Monitoring

---

## 🔧 Setup Awal

### Persiapan Environment
```powershell
# Set execution policy (jika diperlukan)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Pastikan Docker running
docker ps

# Pastikan semua container aktif
docker compose -f docker-compose-postgres.yaml ps
```

---

## 📊 1. INSERT DATA TEST

### Basic Usage
```powershell
# Insert default (1000 records, batch 100)
.\scripts\insert_debezium.ps1
```

### Custom Parameters
```powershell
# Insert 5000 records, batch 500
.\scripts\insert_debezium.ps1 -RecordCount 5000 -BatchSize 500

# Insert dengan delay dan progress
.\scripts\insert_debezium.ps1 -RecordCount 2000 -BatchSize 200 -DelayBetweenBatches 2 -ShowProgress

# Stress test besar
.\scripts\insert_debezium.ps1 -RecordCount 10000 -BatchSize 1000 -DelayBetweenBatches 0
```

### Parameter Lengkap
| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `RecordCount` | 1000 | Jumlah total record |
| `BatchSize` | 100 | Record per batch |
| `DelayBetweenBatches` | 1 | Delay antar batch (detik) |
| `ShowProgress` | false | Tampilkan progress bar |

### Rekomendasi Parameter
- **Test Ringan**: `-RecordCount 500 -BatchSize 50`
- **Test Standar**: `-RecordCount 2000 -BatchSize 200`  
- **Stress Test**: `-RecordCount 10000 -BatchSize 1000`
- **Debug Mode**: `-ShowProgress -DelayBetweenBatches 3`

---

## 📈 2. PIPELINE MONITORING

### Basic Monitoring
```powershell
# Monitor pipeline lengkap
.\scripts\monitoring_debezium.ps1
```

### Fitur Monitoring
- ✅ **Container Stats** - CPU, Memory, Network I/O
- ✅ **Database Health** - Connection, size, performance
- ✅ **Kafka Analysis** - Topics, consumer groups, messages
- ✅ **CDC Status** - Connector status, replication lag
- ✅ **WAL Monitoring** - PostgreSQL replication slots
- ✅ **Performance Metrics** - Throughput, latency, success rate

### Timing Recommendations
```powershell
# Monitor setelah insert
.\scripts\insert_debezium.ps1 -RecordCount 1000
.\scripts\monitoring_debezium.ps1

# Monitor berkala (gunakan task scheduler)
# Setiap 15 menit untuk production monitoring
```

---

## 🎯 Skenario Penggunaan

### Skenario 1: Test Ringan
```powershell
# 1. Insert data test kecil
.\scripts\insert_debezium.ps1 -RecordCount 500 -BatchSize 50

# 2. Monitor hasil
.\scripts\monitoring_debezium.ps1
```

### Skenario 2: Test Performa
```powershell
# 1. Insert data sedang dengan monitoring progress
.\scripts\insert_debezium.ps1 -RecordCount 5000 -BatchSize 500 -ShowProgress

# 2. Monitor pipeline
.\scripts\monitoring_debezium.ps1
```

### Skenario 3: Stress Test
```powershell
# 1. Insert besar tanpa delay
.\scripts\insert_debezium.ps1 -RecordCount 10000 -BatchSize 1000 -DelayBetweenBatches 0

# 2. Monitor performa dan resource
.\scripts\monitoring_debezium.ps1
```

---

## 📁 File Output & Log

### Lokasi File
```
testing-results/
├── cdc-stress-test-[timestamp].log          # Log detail insert test
├── cdc-resource-usage-[timestamp].log       # Log resource monitoring
└── [other-logs...]
```

### Format Timestamp
- Format: `YYYY-MM-DD-HH-MM-SS`
- Contoh: `2025-09-02-18-00-51`

### Analisis Log
```powershell
# Lihat log terbaru
Get-ChildItem testing-results\ | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Baca log specific
Get-Content "testing-results\cdc-stress-test-2025-09-02-18-00-51.log"
```

---

## 🔍 Validasi & Verifikasi

### Cek Data Source
```sql
-- Connect ke source database
docker exec -it debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory

-- Cek jumlah data
SELECT COUNT(*) FROM inventory.orders;
```

### Cek Data Target
```sql
-- Connect ke target database  
docker exec -it debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres

-- Cek sinkronisasi
SELECT COUNT(*) FROM public.orders;
```

### Cek Connector Status
```powershell
# Daftar connector
curl http://localhost:8083/connectors

# Status detail
curl http://localhost:8083/connectors/inventory-connector/status
curl http://localhost:8083/connectors/pg-sink-connector/status
```

---

## ⚠️ Troubleshooting Cepat

### Script Tidak Bisa Dijalankan
```powershell
# Set policy sementara
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Set policy permanen
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Container Bermasalah
```powershell
# Cek status container
docker ps -a

# Restart specific container
docker restart debezium-cdc-mirroring-postgres-1

# Restart semua
docker compose -f docker-compose-postgres.yaml restart
```

### Database Connection Error
```powershell
# Test koneksi PostgreSQL
docker exec -it debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory -c "SELECT 1;"

# Restart connector
curl -X POST http://localhost:8083/connectors/inventory-connector/restart
```

### Performance Issues
- Kurangi `BatchSize` jika ada timeout
- Tambah `DelayBetweenBatches` jika overload
- Monitor resource usage di log files

---

## 💡 Tips & Best Practices

### 1. **Monitoring Berkala**
```powershell
# Jalankan monitoring setelah setiap insert
.\scripts\insert_debezium.ps1 -RecordCount 1000
.\scripts\monitoring_debezium.ps1
```

### 2. **Optimasi Parameter**
- **Test kecil**: `RecordCount=500, BatchSize=50`
- **Test normal**: `RecordCount=2000, BatchSize=200` 
- **Stress test**: `RecordCount=10000, BatchSize=1000`
- **Performance optimal**: `BatchSize=500` (sweet spot)

### 3. **Monitoring Strategy**
```powershell
# Pre-test monitoring
.\scripts\monitoring_debezium.ps1

# Execute test  
.\scripts\insert_debezium.ps1 -RecordCount 5000 -BatchSize 500

# Post-test analysis
.\scripts\monitoring_debezium.ps1
```

### 3. **Log Management**
```powershell
# Cleanup log lama (opsional)
Get-ChildItem testing-results\ -Name "*.log" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | Remove-Item
```

### 4. **Health Check Rutin**
- Jalankan monitoring sebelum dan sesudah test
- Cek sinkronisasi data secara berkala
- Monitor resource usage untuk mencegah bottleneck

---

## 🎯 Quick Commands Cheat Sheet

```powershell
# INSERT COMMANDS
.\scripts\insert_debezium.ps1                                    # Basic insert
.\scripts\insert_debezium.ps1 -RecordCount 5000 -BatchSize 500   # Custom insert
.\scripts\insert_debezium.ps1 -ShowProgress                      # With progress

# MONITORING
.\scripts\monitoring_debezium.ps1                                # Full monitoring

# VALIDATION
curl http://localhost:8083/connectors                           # Check connectors
docker ps                                                       # Check containers
docker logs tutorial-connect-1                                  # Check connect logs

# TROUBLESHOOT
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass      # Fix execution policy
docker compose -f docker-compose-postgres.yaml restart          # Restart all
curl -X POST http://localhost:8083/connectors/inventory-connector/restart  # Restart connector
```

---

**🔗 Referensi:**
- [Scripts Documentation](Scripts-Documentation.md) - Dokumentasi detail
- [Latency Guide](Latency-Guide.md) - Panduan analisis latency
- [README.md](../README.md) - Setup dan overview project