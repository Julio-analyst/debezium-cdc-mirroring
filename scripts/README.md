# CDC Monitoring Scripts

Folder ini berisi script monitoring untuk CDC pipeline Debezium. Semua script telah diuji dan dikonfirmasi bekerja dengan baik.

## Python Scripts

### 1. test_dynamic.py
**Fungsi:** Test dinamis untuk validasi koneksi database dan CDC
- Mengambil data real-time dari database sumber
- Melakukan insert test data
- Memverifikasi CDC propagation
- **Status:** ✅ Tested & Working

### 2. mass_insert_monitor.py
**Fungsi:** Mass insert 100k records dengan monitoring 3-phase
- **Phase 1:** Baseline monitoring (idle state)
- **Phase 2:** Mass insert execution dengan real-time monitoring
- **Phase 3:** Post-insert monitoring dan verifikasi CDC
- Mengumpulkan metrics: container stats, database stats, CDC lag
- **Status:** ✅ Tested & Working
- **Note:** CDC propagation bisa lambat untuk volume besar

### 3. comprehensive_performance_monitor.py
**Fungsi:** Monitoring performa komprehensif CDC pipeline
- Container metrics (CPU, Memory, Network, I/O)
- Database statistics (connections, queries, lag)
- Kafka metrics (topics, partitions, consumer lag)
- Host system metrics
- Real-time CDC operation analysis
- **Status:** ✅ Tested & Working

## PowerShell Scripts

### 1. cdc-live-monitor.ps1
**Fungsi:** Real-time CDC monitoring dashboard
- Live stats dari semua komponen
- Container resource monitoring
- Database connection tracking
- **Status:** ✅ Tested & Working

### 2. cdc-performance-monitor-simple.ps1
**Fungsi:** Simplified performance monitoring
- Quick overview CDC pipeline health
- Basic metrics dan alerts
- **Status:** ✅ Tested & Working

### 3. cdc-latency-monitor.ps1
**Fungsi:** Fokus pada latency analysis
- End-to-end latency measurement
- CDC propagation time tracking
- Performance bottleneck identification
- **Status:** ✅ Tested & Working

### 4. cdc-quick-monitor.ps1
**Fungsi:** Quick health check
- Fast pipeline status overview
- Error detection
- **Status:** ✅ Tested & Working

### 5. cdc-clickhouse-style-monitor.ps1
**Fungsi:** Advanced monitoring dengan style analytics
- Detailed performance analytics
- Historical trend analysis
- **Status:** ✅ Tested & Working

### 6. simple-insert-test.ps1
**Fungsi:** Simple insert test untuk validasi CDC
- Basic insert dan verifikasi
- Quick CDC functionality test
- **Status:** ✅ Tested & Working

## Usage Examples

### Monitoring Performance During Mass Insert
```powershell
# Terminal 1: Jalankan mass insert
python scripts/mass_insert_monitor.py

# Terminal 2: Jalankan comprehensive monitoring
python scripts/comprehensive_performance_monitor.py
```

### Quick CDC Test
```powershell
python scripts/test_dynamic.py
```

### Real-time Dashboard
```powershell
./scripts/cdc-live-monitor.ps1
```

## Requirements
- Python 3.8+
- Required packages: asyncpg, psutil, requests
- PowerShell 5.1+
- Docker Compose CDC pipeline running

## Notes
- Semua script menggunakan data real-time (tidak ada hardcoded data)
- Container metrics diambil via `docker stats`
- Database menggunakan schema `inventory.orders`
- Untuk Windows terminal, jalankan script monitoring di terminal terpisah untuk hasil terbaik
