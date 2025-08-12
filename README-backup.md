# 📱 Debezium CDC Mirroring: Real-time PostgreSQL Replication

> Log-based data replication pipeline using Debezium, Kafka, Kafka Connect, and PostgreSQL with dynamic testing capabilities.

## 🔧 **FINAL STATUS: COMPREHENSIVE MONITORING COMPLETE** 

✅ **ALL SCRIPTS VERIFIED & WORKING** - Semua script telah ditest dan berfungsi sempurna
✅ **REAL-TIME DATA CONFIRMED** - Tidak ada data hardcoded, semua live dari sistem
✅ **CONTAINER STATS INTEGRATED** - CPU, Memory, Network I/O, PIDs untuk semua container
✅ **DETAILED OUTPUT IMPLEMENTED** - Semua metrics ditampilkan di terminal dalam format readable

### **🎯 ENHANCED OUTPUT FEATURES:**
- **Container Analysis**: Detailed per-phase stats untuk setiap container (CPU%, Memory%, Network I/O, PIDs)
- **System Resources**: CPU/Memory trends dengan change indicators, Disk usage, Network throughput  
- **Database Performance**: Record counts, sync analysis, database size, connections, transactions
- **Kafka & Connect**: Topics, consumer groups, connector status, task details
- **Latency Analysis**: Individual test results, averages, quality assessment (EXCELLENT/GOOD/FAIR/POOR)
- **Error & Log Analysis**: Per-container error counts, recent error previews
- **Replication Monitoring**: WAL position, replication slots status
- **Session Summary**: Monitoring times, processing duration, sync percentage

---

---

## 📌 Overview

This project demonstrates a **real-time data replication** architecture using **Debezium** and **Apache Kafka** to capture changes (CDC) from a PostgreSQL source database and mirror them into a PostgreSQL target database.

### 🌐 Context:

* **Source DB**: `inventory`
* **Source Schema**: `inventory`
* **Source Table**: `orders`
* **Target DB**: `postgres`
* **Target Schema**: `public`
* **Target Table**: `orders`

📌 *Note: You can skip dropping foreign keys by pre-populating the referenced data. See example datasets below.*

### 🚀 New Dynamic Testing Features:

* **Real-time Data Fetching**: No hardcoded IDs or values
* **Environment-aware Configuration**: Supports config files and environment variables
* **Auto-discovery**: Automatically detects Docker containers and database schemas
* **Dynamic Data Generation**: Uses live database data for realistic testing
* **Configurable Performance Testing**: Adaptive batch sizing and concurrent operations

---

## 💡 Why CDC & Streaming?

Synchronizing data across systems in real time is a challenge. Traditional ETL tools introduce latency, and direct queries often overload production databases.

**Debezium** offers a **non-intrusive, log-based mechanism** to stream changes efficiently using Kafka — making it ideal for:

* Real-time backups
* Microservice synchronization
* Streaming data to analytics pipelines
* Data validation and monitoring

---

## 🔗 Data Flow Architecture

```
[Postgres Source] → [Debezium Source Connector] → [Kafka Broker] → [JDBC Sink Connector] → [Postgres Target]
                                                         ↓
                                           [Dynamic Testing & Monitoring]
```

**Components:**

* **Postgres Source**: Origin DB using WAL (Write-Ahead Log)
* **Debezium**: Captures changes in real time
* **Kafka Broker + Zookeeper**: Streams changes across connectors
* **Kafka Connect (JDBC Sink)**: Pushes data to target
* **Postgres Target**: Receives updates
* **Dynamic Testing Suite**: Real-time performance and validation testing

---

## 📁 Project Structure

```
👠 debezium-cdc-mirroring/
├─ docker-compose-postgres.yaml         # Main deployment file
├─ inventory-source.json                # Debezium connector config
├─ pg-sink.json                         # JDBC sink config
├─ jdbc-sink.json (optional)
├─ plugins/
│   ├─ debezium-connector-postgres/
│   └─ confluentinc-kafka-connect-jdbc/
├─ docs/
│   └─ erd.png                          # Entity Relationship Diagram (ERD)
└─ README.md
```

---

## 🚀 Quick Start Guide

### ✅ Step 1: Clone & Spin Up Docker

```bash
git clone https://github.com/Julio-analyst/debezium-cdc-mirroring.git
cd debezium-cdc-mirroring/
docker compose -f docker-compose-postgres.yaml up -d
```

### ✅ Step 2: Register Connectors & Check Connection

```bash
curl -X POST -H "Content-Type: application/json" --data "@inventory-source.json" http://localhost:8083/connectors
curl -X POST -H "Content-Type: application/json" --data "@pg-sink.json" http://localhost:8083/connectors
```

### ✅ Step 3: Check Source Table Structure

```bash
docker exec -it debezium-cdc-mirroring-postgres-1 psql -U postgres -d inventory
\d inventory.orders
```

### ✅ Step 4: Check Existing Data

```sql
SELECT * FROM inventory.orders;
```

### ✅ Step 5: Modify Source Table (Optional for CRUD Testing)

```sql
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_purchaser_fkey;
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_product_id_fkey;
ALTER TABLE inventory.orders ADD COLUMN keterangan TEXT DEFAULT '';
```

### ✅ Step 6: Perform CRUD Operations

#### 🔹 Insert

```sql
INSERT INTO inventory.orders(order_date, purchaser, quantity, product_id, keterangan)
VALUES ('2025-07-08', 1002, 3, 107, 'CDC TEST');
```

#### 🔹 Update

```sql
UPDATE inventory.orders
SET keterangan = 'UPDATED FROM SOURCE'
WHERE purchaser = 999;
```

#### 🔹 Delete

```sql
DELETE FROM inventory.orders
WHERE purchaser = 999;
```

📌 *Alternative to dropping FK: Pre-insert into `customers` and `products`:*

```sql
INSERT INTO inventory.customers(id, first_name, last_name, email) VALUES (999, 'Dummy', 'Customer', 'dummy@mail.com');
INSERT INTO inventory.products(id, name, description, weight) VALUES (999, 'Dummy Product', 'test', 1);
```

### ✅ Step 7: Check Replication Result in Target DB

```bash
docker exec -it debezium-cdc-mirroring-target-postgres-1 psql -U postgres -d postgres
SELECT * FROM public.orders;
```

---

## 🧪 Dynamic Performance Testing

### 🎯 Overview

The project includes advanced **dynamic stress testing capabilities** that use real-time data from your database instead of hardcoded values. This ensures realistic testing scenarios and validates CDC pipeline performance.

### 🚀 Features

* **✅ Real-time Data**: Fetches customers, products, and orders dynamically
* **✅ No Hardcoded Values**: All test data is generated from live database
* **✅ Auto-discovery**: Automatically detects Docker containers and schemas
* **✅ Configurable**: Supports environment variables and config files
* **✅ Performance Metrics**: Comprehensive performance and latency tracking
* **✅ CDC Validation**: Validates replication accuracy and lag

### 📁 Dynamic Testing Files

```
scripts/
├─ cdc_stress_test_dynamic.py         # Main dynamic testing script
├─ setup-dynamic-env.ps1              # Environment setup script
config.yaml                           # Configuration file
requirements-dynamic.txt              # Python dependencies
```

### ⚡ Quick Setup

```powershell
# 1. Setup environment (PowerShell)
.\scripts\setup-dynamic-env.ps1

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Run basic test
python scripts/test_dynamic.py
```

### 🎛️ Configuration Options

#### Option 1: Environment Variables
```powershell
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_SCHEMA = "inventory"
# ... (run setup-dynamic-env.ps1 for complete setup)
```

#### Option 2: Configuration File (config.yaml)
```yaml
database:
  host: localhost
  port: 5432
  schema: inventory
  # ... (see config.yaml for full configuration)
```

### 🧪 Test Types & Usage

#### 📊 INSERT Testing
```bash
# Basic insert test
python scripts/cdc_stress_test_dynamic.py --test-type insert --records 1000

# High-volume insert test
python scripts/cdc_stress_test_dynamic.py --test-type insert --records 100000 --batch-size 1000

# With custom configuration
python scripts/cdc_stress_test_dynamic.py --config config.yaml --test-type insert --records 5000
```

#### 🔄 UPDATE Testing
```bash
# Update existing records
python scripts/cdc_stress_test_dynamic.py --test-type update --records 500

# Batch updates
python scripts/cdc_stress_test_dynamic.py --test-type update --records 2000 --batch-size 200
```

#### 🗑️ DELETE Testing
```bash
# Delete records (uses oldest records first)
python scripts/cdc_stress_test_dynamic.py --test-type delete --records 200

# Batch deletes
python scripts/cdc_stress_test_dynamic.py --test-type delete --records 1000 --batch-size 50
```

#### 🔀 MIXED Operations
```bash
# Mixed INSERT/UPDATE/DELETE operations
python scripts/cdc_stress_test_dynamic.py --test-type mixed --records 2000

# High-volume mixed operations
python scripts/cdc_stress_test_dynamic.py --test-type mixed --records 50000 --batch-size 500
```

#### ✅ CDC Validation
```bash
# Validate CDC replication accuracy
python scripts/cdc_stress_test_dynamic.py --test-type validate --records 1000
```

### 📈 Performance Metrics

The dynamic testing provides comprehensive metrics:

* **Operations/Second**: Real-time throughput measurement
* **Success Rate**: Percentage of successful operations
* **Replication Lag**: CDC latency in milliseconds
* **Memory Usage**: Resource consumption tracking
* **Docker Log Events**: CDC event monitoring
* **Error Analysis**: Detailed error reporting

### 📊 Sample Output

```
============================================================
CDC DYNAMIC STRESS TEST SUMMARY
============================================================
Test Type: INSERT
Records Processed: 10,000
Duration: 45.23 seconds
Operations/Second: 221.07
Success Rate: 100.0%
Memory Usage: 156.4 MB
Docker Log Events: 10,000
Replication Lag: 125.3 ms
Results saved to: testing-results/cdc_stress_test_insert_20250118_143022.json
============================================================
```

### 🎯 Key Advantages

#### ✅ Dynamic vs Static Testing

| Feature | Static (Old) | Dynamic (New) |
|---------|-------------|---------------|
| Customer IDs | Hardcoded [1001,1002...] | ✅ Real-time DB fetch |
| Product IDs | Hardcoded [101-109] | ✅ Real-time DB fetch |
| Container Names | Hardcoded strings | ✅ Auto-discovery |
| Database Config | Fixed localhost:5432 | ✅ Environment/config |
| Schema Handling | Fixed 'inventory' | ✅ Dynamic introspection |
| Test Data | Artificial values | ✅ Live database data |

#### 🚀 Benefits

* **Realistic Testing**: Uses actual database state
* **Production-Ready**: Reflects real-world scenarios
* **Flexible Configuration**: Adapts to different environments
* **Comprehensive Monitoring**: Tracks all performance aspects
* **Error Resilience**: Handles missing data gracefully
* **Scalable**: Supports high-volume testing

---

## 🛡️ View Events and Validate

### 🔍 Option A: Via CMD

```bash
docker exec -it kafka-tools kafka-console-consumer --bootstrap-server kafka:9092 --topic dbserver1.inventory.orders --from-beginning
```

### 🌐 Option B: Via Web UI (Kafdrop)

Access: [http://localhost:9000](http://localhost:9000)

* Inspect topics, partitions, and payload in browser

### 🔧 Check Running Connectors

```bash
curl http://localhost:8083/connectors
```

---

## 🚩 Shutdown & Clean Up

After you're done:

```bash
# Option A (with volume deletion)
docker compose -f docker-compose-postgres.yaml down -v

# Option B (keep volume data)
docker compose -f docker-compose-postgres.yaml down
```

**⚠️ Don’t forget to stop containers after use to avoid memory or port issues.**

---

## ✅ Optional: Connect via DBeaver

> Create a PostgreSQL connection for both source and sink:

### 🔹 Source (inventory):

* Host: `localhost`
* Port: `5432`
* Database: `inventory`
* User: `postgres`
* Password: `postgres`

### 🔹 Target (postgres):

* Host: `localhost`
* Port: `5433`
* Database: `postgres`
* User: `postgres`
* Password: `postgres`

Click **Test Connection**, then **Finish**.

---

## 🗂️ ERD & Sample Data

### 🧩 ERD

> Below is the simplified ERD of the source `inventory` database.

![ERD](docs/erd.png)

### 📌 Sample Data Extract

```sql
-- Sample: customers
SELECT * FROM inventory.customers;
-- Sample: products
SELECT * FROM inventory.products;
-- Sample: orders
SELECT * FROM inventory.orders;
```

---

## 🛠️ Tech Stack

* Debezium 2.6
* Apache Kafka & Kafka Connect (Confluent)
* PostgreSQL
* Docker Compose
* Kafdrop (Web UI)

---

## 📖 References

* [Debezium Docs](https://debezium.io/documentation/)
* [Kafka Connect JDBC Sink](https://docs.confluent.io/kafka-connect-jdbc/current/index.html)
* [Docker Compose](https://docs.docker.com/compose/)

---

## 📄 License

MIT License
© 2025 Julio-analyst

---

## 📬 Contact

* 🌐 [LinkedIn](https://www.linkedin.com/in/farrel-julio-427143288)
* 📂 [Portfolio (Notion)](https://linktr.ee/Julio-analyst)
* ✉️ [farelrel12345@gmail.com](mailto:farelrel12345@gmail.com)

