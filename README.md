# 📡 Debezium CDC Mirroring

## 🧠 Overview

This project implements **Change Data Capture (CDC)** mirroring between two PostgreSQL databases using **Debezium**, **Apache Kafka**, and **Kafka Connect**. It captures changes (`INSERT`, `UPDATE`, `DELETE`) in real time from the source database and reflects them into a target database — useful for **backups**, **analytics**, or **synchronizing microservices**.

---

## 🎯 Motivation

Synchronizing data across systems in real-time is a challenge. Traditional ETL tools introduce latency, and direct queries often overload production databases. Debezium offers a **non-intrusive, log-based streaming** mechanism using Kafka.

**Use cases include:**

* Real-time data warehousing
* Backup/mirroring from production DB
* Microservice synchronization

---

## ⚙️ Architecture

```
[Postgres Source] --> [Debezium Source Connector] 
                    → [Kafka Broker] 
                    → [Kafka Connect JDBC Sink Connector] 
                    → [Postgres Target]
```

**Components:**

* 🔹 **Postgres Source**: Database to monitor for changes
* 🔹 **Debezium Connector**: Captures changes using WAL
* 🔹 **Kafka Broker**: Streams the changes
* 🔹 **Kafka JDBC Sink**: Writes into target database
* 🔹 **Postgres Target**: Receives and stores replicated data

---

## 📁 Directory Structure

```
C:\debezium-cdc-mirror
├── docker-compose-postgres.yaml
├── inventory-source.json
├── pg-sink.json
├── jdbc-sink.json
├── README.md
├── plugins
│   ├── debezium-connector-postgres
│   │   └── *.jar (core, connector, jdbc, etc)
│   └── confluentinc-kafka-connect-jdbc
│       ├── lib/
│       ├── doc/, etc/
│       └── manifest
```

---

## 🧰 Tools Used

* **Debezium v2.6** (PostgreSQL connector)
* **Kafka Connect** (Confluent Connect image)
* **Apache Kafka + Zookeeper**
* **PostgreSQL** (Source & Target)
* **Kafdrop** (Kafka UI)

---

## 🪜 Step-by-Step Instructions

### 🔻 1. Clone Repository

```bash
git clone https://github.com/Julio-analyst/debezium-cdc-mirroring.git
cd debezium-cdc-mirroring
```

### 🐳 2. Launch Docker Services

```bash
docker compose -f docker-compose-postgres.yaml up -d
```

### 📦 3. Verify Running Containers

```bash
docker ps
```

### 📝 4. Prepare Source DB

```sql
docker exec -it debezium-cdc-mirror-postgres-1 psql -U postgres -d inventory

-- Drop FKs if needed
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_purchaser_fkey;
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_product_id_fkey;

-- Add new field for metadata (optional)
ALTER TABLE inventory.orders ADD COLUMN keterangan TEXT DEFAULT '';

-- Insert sample data
INSERT INTO inventory.orders(order_date, purchaser, quantity, product_id, keterangan)
VALUES ('2025-07-09', 4321, 5, 9999, 'CDC mirror test OK');
```

### 🔌 5. Register Debezium Source Connector

```bash
curl -X POST -H "Content-Type: application/json" \
     --data "@inventory-source.json" \
     http://localhost:8083/connectors
```

### 🔁 6. Register JDBC Sink Connector

```bash
curl -X POST -H "Content-Type: application/json" \
     --data "@pg-sink.json" \
     http://localhost:8083/connectors
```

### 🧾 7. Validate Replication on Target DB

```bash
docker exec -it debezium-cdc-mirror-target-postgres-1 psql -U postgres -d postgres
SELECT * FROM orders;
```

---

## 🔍 Query Explanation

* `ALTER TABLE` used to disable constraints to allow free inserts without FK validation.
* `inventory-source.json` configures Debezium to read WAL changes.
* `pg-sink.json` includes transformations (unwrap, extract key, add timestamp) to simplify and enrich the message sent to the target DB.
* `insert.mode=upsert` ensures idempotent writes.

---

## ✅ Pros

* ✅ Near real-time replication
* ✅ Decoupled, event-driven architecture
* ✅ Scalable and fault-tolerant
* ✅ Easy to plug into existing Kafka infra

## ⚠️ Cons

* ⚠️ Initial setup complexity
* ⚠️ Kafka learning curve
* ⚠️ Latency possible under high load

---

