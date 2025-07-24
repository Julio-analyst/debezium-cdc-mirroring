# 📱 Debezium CDC Mirroring: Real-time PostgreSQL Replication

> Log-based data replication pipeline using Debezium, Kafka, Kafka Connect, and PostgreSQL.

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

---

## 🔗 Data Flow Architecture

```
[Postgres Source] → [Debezium Source Connector] → [Kafka Broker] → [JDBC Sink Connector] → [Postgres Target]
```

**Components:**

* **Postgres Source**: Origin DB using WAL (Write-Ahead Log)
* **Debezium**: Captures changes in real time
* **Kafka Broker + Zookeeper**: Streams changes across connectors
* **Kafka Connect (JDBC Sink)**: Pushes data to target
* **Postgres Target**: Receives updates

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

## 🗂️ Sample Data

### 📌 Sample Data Extract

```sql
-- Sample: customers
SELECT * FROM inventory.customers;
-- Sample: products
SELECT * FROM inventory.products;
-- Sample: orders
SELECT * FROM inventory.orders;
```
