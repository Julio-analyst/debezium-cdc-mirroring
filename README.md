# 📡 Debezium CDC Mirroring: Real-time PostgreSQL Replication

> Log-based data replication pipeline using Debezium, Kafka, Kafka Connect, and PostgreSQL.

---

## 📌 Overview

This project demonstrates a **real-time data replication** architecture using **Debezium** and **Apache Kafka** to capture changes (CDC) from a PostgreSQL source database and mirror them into a PostgreSQL target database.

---

## 💡 Why CDC & Streaming?

Synchronizing data across systems in real time is a challenge.
Traditional ETL tools introduce latency, and direct queries often overload production databases.

**Debezium** offers a **non-intrusive, log-based mechanism** to stream changes efficiently using Kafka — making it ideal for:
- Real-time backups
- Microservice synchronization
- Streaming data to analytics pipelines

---

## 🔗 Data Flow Architecture
- Event-driven architectures
- Streaming analytics pipelines
- Backup/mirroring from production DB
- Synchronizing services or downstream systems

---

## 🔗 Data Flow Architecture

```
[Postgres Source] → [Debezium Source Connector] → [Kafka Broker] → [JDBC Sink Connector] → [Postgres Target]
```

**Components:**
- **Postgres Source**: Origin DB using WAL (Write-Ahead Log)
- **Debezium**: Captures changes in real time
- **Kafka Broker + Zookeeper**: Streams changes across connectors
- **Kafka Connect (JDBC Sink)**: Pushes data to target
- **Postgres Target**: Receives updates

---

## 📁 Project Structure

```
👠 debezium-cdc-mirroring/
├─ docker-compose-postgres.yaml        # Main deployment file
├─ inventory-source.json             # Debezium connector config
├─ pg-sink.json                     # JDBC sink config
├─ jdbc-sink.json (optional)
├─ plugins/
│   ├─ debezium-connector-postgres/
│   └─ confluentinc-kafka-connect-jdbc/
└─ README.md
```

---

## 🚀 Quick Start Guide

### 1. Clone & Start
```bash
git clone https://github.com/Julio-analyst/debezium-cdc-mirroring.git
cd debezium-cdc-mirroring
docker compose -f docker-compose-postgres.yaml up -d
```

### 2. Prepare Source Database
```sql
-- Enter DB container
docker exec -it debezium-cdc-mirror-postgres-1 psql -U postgres -d inventory

-- Optional: Drop constraints for demo
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_product_id_fkey;
ALTER TABLE inventory.orders ADD COLUMN keterangan TEXT DEFAULT '';

-- Insert sample data
INSERT INTO inventory.orders(order_date, purchaser, quantity, product_id, keterangan)
VALUES ('2025-07-09', 4321, 5, 9999, 'CDC mirror test OK');
```

### 3. Register Connectors
```bash
# Debezium source connector
curl -X POST -H "Content-Type: application/json" \
     --data "@inventory-source.json" \
     http://localhost:8083/connectors

# JDBC sink connector
curl -X POST -H "Content-Type: application/json" \
     --data "@pg-sink.json" \
     http://localhost:8083/connectors
```

### 4. Verify Replication
```bash
docker exec -it debezium-cdc-mirror-target-postgres-1 psql -U postgres -d postgres
SELECT * FROM orders;
```

---

## 🪨 Key Concepts & Notes

- `inventory-source.json`: Debezium config (WAL-based)
- `pg-sink.json`: JDBC sink config w/ `transformations`, `insert.mode=upsert`
- `Kafdrop`: Web UI to monitor Kafka topics (if enabled)
- `keterangan` field: added for metadata validation in mirrored data

---

## 🥇 Features & Benefits

| ✅ Advantages                        | ⚠️ Limitations                    |
|-------------------------------------|-------------------------------------|
| Near real-time streaming            | Initial setup complexity             |
| Decoupled microservice-friendly     | Kafka & connector learning curve     |
| Highly extensible (sink any target) | Potential latency under heavy load   |
| Supports insert/update/delete       | Connector tuning may be required     |

---

## 🛠️ Tech Stack

- Debezium 2.6
- Apache Kafka & Kafka Connect (Confluent)
- PostgreSQL
- Docker Compose
- Kafdrop (UI)

---

## 📖 References

- [Debezium Docs](https://debezium.io/documentation/)
- [Kafka Connect JDBC Sink](https://docs.confluent.io/kafka-connect-jdbc/current/index.html)
- [Docker Compose](https://docs.docker.com/compose/)

---

## 📄 License

MIT License  
© 2025 Julio-analyst

---

## 📬 Contact

- 🌐 [LinkedIn](https://www.linkedin.com/in/farrel-julio-427143288)  
- 📂 [Portfolio (Notion)](https://linktr.ee/Julio-analyst)  
- ✉️ farelrel12345@gmail.com
