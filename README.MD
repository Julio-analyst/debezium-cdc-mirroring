Debezium CDC Mirroring

📘 Overview

This project implements Change Data Capture (CDC) mirroring between two PostgreSQL databases using Debezium, Apache Kafka, and Kafka Connect. It captures changes (INSERT, UPDATE, DELETE) in real time from the source database and reflects them into a target database for purposes such as backup, analytics, or synchronization between microservices.

🧠 Motivation

Synchronizing data across systems in real-time is often a challenge in modern architectures. Traditional ETL tools introduce latency, while direct queries can overload source systems. Debezium enables a non-intrusive, log-based streaming approach to stream changes efficiently using Kafka.

Use cases include:

Real-time data warehousing

Backup/mirroring from production DB

Microservice synchronization

⚙️ Architecture

   [Postgres Source]  --->  [Debezium Source Connector]
                                 |
                                 v
                           [Kafka Broker]
                                 |
                                 v
                    [Kafka Connect JDBC Sink Connector]
                                 |
                                 v
                           [Postgres Target]

Components:

Postgres Source: Application database to watch for changes

Debezium Connector: Captures changes using WAL logs

Kafka Broker: Message streaming layer

Kafka Connect JDBC Sink: Writes messages into target DB

Postgres Target: Replica database receiving changes

📁 Directory Structure

C:\debezium-cdc-mirror
├── docker-compose-postgres.yaml
├── inventory-source.json
├── pg-sink.json
├── README.md
├── plugins
│   ├── debezium-connector-postgres
│   │   ├── *.jar (debezium-core, connector, postgresql JDBC, etc.)
│   └── confluentinc-kafka-connect-jdbc
│       ├── lib/
│       ├── doc/, etc/
│       └── manifest

🛠️ Prerequisites

Docker & Docker Compose

Git

curl

🚀 Setup Instructions

1. Clone the Repository

git clone https://github.com/Julio-analyst/debezium-cdc-mirroring.git
cd debezium-cdc-mirroring

2. Start All Services with Docker Compose

docker compose -f docker-compose-postgres.yaml up -d

3. Deploy Source Connector

curl -X POST -H "Content-Type: application/json" --data "@inventory-source.json" http://localhost:8083/connectors

4. Deploy Sink Connector

curl -X POST -H "Content-Type: application/json" --data "@pg-sink.json" http://localhost:8083/connectors

5. Insert Data into Source

docker exec -it debezium-cdc-mirror-postgres-1 psql -U postgres -d inventory

-- Drop foreign key constraints if needed
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_purchaser_fkey;
ALTER TABLE inventory.orders DROP CONSTRAINT IF EXISTS orders_product_id_fkey;

-- Add a new column
ALTER TABLE inventory.orders ADD COLUMN keterangan TEXT DEFAULT '';

-- Insert sample record
INSERT INTO inventory.orders(order_date, purchaser, quantity, product_id, keterangan)
VALUES ('2025-07-09', 4321, 5, 9999, 'CDC mirror test OK');

6. Check Replication in Target

docker exec -it debezium-cdc-mirror-target-postgres-1 psql -U postgres -d postgres
SELECT * FROM orders;

⚖️ Pros and Cons

✅ Advantages

Real-time replication with low latency

Scalable and fault-tolerant

Works without modifying application logic

Supports schema evolution

Excellent ecosystem integration (UI, metrics, etc.)

❌ Limitations

Requires Kafka infrastructure (complex for small teams)

Transformation logic is limited unless Kafka Streams or ksqlDB is added

Schema drift needs manual handling in some cases

📌 Notes

The inventory-source.json defines the Debezium source connector for PostgreSQL.

The pg-sink.json defines the JDBC sink connector to the target PostgreSQL.

The plugins/ folder includes the required JARs for Debezium and JDBC connectors.