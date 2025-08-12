#!/usr/bin/env python3
"""
CDC Mass Insert Test with 3-Phase Docker Monitoring
==================================================

Script untuk melakukan insert 100k data dengan monitoring Docker stats
pada 3 phase: idle, processing, dan final.

Author: Debezium CDC Pipeline Team
Date: August 2025
"""

import asyncio
import asyncpg
import json
import time
import yaml
import subprocess
import os
import sys
from datetime import datetime
from typing import Dict, List, Any
import random

class CDCMassInsertMonitor:
    def __init__(self, config_path: str = "config.yaml"):
        """Initialize the CDC Mass Insert Monitor"""
        self.config = self._load_config(config_path)
        self.results = {}
        self.phase_data = {}
        self.container_names = [
            "debezium-cdc-mirroring-postgres-1",
            "debezium-cdc-mirroring-kafka-1", 
            "debezium-cdc-mirroring-zookeeper-1",
            "debezium-cdc-mirroring-target-postgres-1",
            "tutorial-connect-1"
        ]
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            print(f"⚠️  Config file {config_path} not found, using defaults")
            return {
                'database': {
                    'host': 'localhost',
                    'port': 5432,
                    'user': 'postgres', 
                    'password': 'postgres',
                    'database': 'inventory',
                    'schema': 'inventory'
                },
                'target_database': {
                    'host': 'localhost',
                    'port': 5433,
                    'user': 'postgres',
                    'password': 'postgres', 
                    'database': 'postgres',
                    'schema': 'inventory'
                }
            }

    def get_docker_stats(self) -> Dict[str, Any]:
        """Get current Docker container statistics"""
        stats = {}
        try:
            # Get container stats
            for container in self.container_names:
                try:
                    result = subprocess.run(
                        ['docker', 'stats', '--no-stream', '--format', 
                         '{{.CPUPerc}};{{.MemUsage}};{{.MemPerc}};{{.NetIO}};{{.BlockIO}}', 
                         container],
                        capture_output=True, text=True, timeout=10
                    )
                    if result.returncode == 0 and result.stdout.strip():
                        parts = result.stdout.strip().split(';')
                        if len(parts) >= 5:
                            stats[container] = {
                                'cpu_percent': parts[0],
                                'memory_usage': parts[1], 
                                'memory_percent': parts[2],
                                'network_io': parts[3],
                                'block_io': parts[4],
                                'timestamp': datetime.now().isoformat()
                            }
                except subprocess.TimeoutExpired:
                    stats[container] = {'error': 'timeout'}
                except Exception as e:
                    stats[container] = {'error': str(e)}
                    
        except Exception as e:
            print(f"❌ Error getting Docker stats: {e}")
            
        return stats

    def get_docker_logs_summary(self, container: str, lines: int = 20) -> Dict[str, Any]:
        """Get recent Docker logs from container"""
        try:
            result = subprocess.run(
                ['docker', 'logs', '--tail', str(lines), container],
                capture_output=True, text=True, timeout=10
            )
            return {
                'stdout': result.stdout,
                'stderr': result.stderr,
                'lines_count': len(result.stdout.split('\n')) if result.stdout else 0
            }
        except Exception as e:
            return {'error': str(e)}

    def get_kafka_topics_info(self) -> Dict[str, Any]:
        """Get Kafka topics information"""
        try:
            # List topics
            result = subprocess.run(
                ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1', 
                 'kafka-topics', '--bootstrap-server', 'localhost:9092', '--list'],
                capture_output=True, text=True, timeout=15
            )
            
            topics = result.stdout.strip().split('\n') if result.returncode == 0 else []
            
            # Get topic details for our main topic
            topic_details = {}
            main_topic = "dbserver1.inventory.orders"
            
            if main_topic in topics:
                detail_result = subprocess.run(
                    ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1',
                     'kafka-log-dirs', '--bootstrap-server', 'localhost:9092', 
                     '--topic-list', main_topic, '--describe'],
                    capture_output=True, text=True, timeout=15
                )
                topic_details[main_topic] = {
                    'exists': True,
                    'detail_output': detail_result.stdout if detail_result.returncode == 0 else None
                }
            
            return {
                'topics': topics,
                'topic_count': len(topics),
                'main_topic_details': topic_details
            }
        except Exception as e:
            return {'error': str(e)}

    async def get_database_stats(self, db_config: Dict[str, Any], db_name: str) -> Dict[str, Any]:
        """Get database statistics"""
        try:
            conn = await asyncpg.connect(
                host=db_config['host'],
                port=db_config['port'],
                user=db_config['user'],
                password=db_config['password'],
                database=db_config['database']
            )
            
            # Get table count for orders
            if db_name == "source":
                count_query = "SELECT COUNT(*) FROM inventory.orders"
            else:
                count_query = "SELECT COUNT(*) FROM orders"
                
            count = await conn.fetchval(count_query)
            
            # Get database size
            size_query = "SELECT pg_size_pretty(pg_database_size(current_database()))"
            db_size = await conn.fetchval(size_query)
            
            # Get connection count
            conn_query = "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'"
            active_connections = await conn.fetchval(conn_query)
            
            await conn.close()
            
            return {
                'orders_count': count,
                'database_size': db_size,
                'active_connections': active_connections,
                'status': 'connected'
            }
            
        except Exception as e:
            return {'error': str(e), 'status': 'error'}

    async def capture_phase_data(self, phase_name: str) -> Dict[str, Any]:
        """Capture comprehensive data for a specific phase"""
        print(f"\n🔍 Capturing {phase_name} phase data...")
        
        phase_data = {
            'phase': phase_name,
            'timestamp': datetime.now().isoformat(),
            'docker_stats': self.get_docker_stats(),
            'kafka_info': self.get_kafka_topics_info()
        }
        
        # Get database stats
        source_stats = await self.get_database_stats(
            self.config['database'], 'source'
        )
        target_stats = await self.get_database_stats(
            self.config['target_database'], 'target'
        )
        
        phase_data['source_db'] = source_stats
        phase_data['target_db'] = target_stats
        
        # Get Docker logs for key containers
        phase_data['docker_logs'] = {}
        for container in ['tutorial-connect-1', 'debezium-cdc-mirroring-kafka-1']:
            phase_data['docker_logs'][container] = self.get_docker_logs_summary(container)
        
        return phase_data

    async def mass_insert_orders(self, count: int = 100000, batch_size: int = 5000) -> Dict[str, Any]:
        """Perform mass insert of orders"""
        print(f"\n🚀 Starting mass insert of {count:,} orders in batches of {batch_size:,}")
        
        try:
            conn = await asyncpg.connect(
                host=self.config['database']['host'],
                port=self.config['database']['port'], 
                user=self.config['database']['user'],
                password=self.config['database']['password'],
                database=self.config['database']['database']
            )
            
            # Get existing customers and products
            customers = await conn.fetch("SELECT id FROM inventory.customers LIMIT 100")
            products = await conn.fetch("SELECT id FROM inventory.products LIMIT 100")
            
            if not customers or not products:
                raise Exception("No customers or products found for generating orders")
            
            customer_ids = [row['id'] for row in customers]
            product_ids = [row['id'] for row in products]
            
            start_time = time.time()
            total_inserted = 0
            batch_times = []
            
            # Process in batches
            for batch_start in range(0, count, batch_size):
                batch_end = min(batch_start + batch_size, count)
                current_batch_size = batch_end - batch_start
                
                batch_start_time = time.time()
                
                # Generate batch data
                orders_data = []
                for i in range(current_batch_size):
                    purchaser = random.choice(customer_ids)
                    product_id = random.choice(product_ids)
                    quantity = random.randint(1, 10)
                    
                    orders_data.append((
                        datetime.now().date(),
                        purchaser,
                        quantity,
                        product_id
                    ))
                
                # Batch insert
                await conn.executemany(
                    """INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) 
                       VALUES ($1, $2, $3, $4)""",
                    orders_data
                )
                
                batch_time = time.time() - batch_start_time
                batch_times.append(batch_time)
                total_inserted += current_batch_size
                
                # Progress update
                progress = (total_inserted / count) * 100
                ops_per_sec = current_batch_size / batch_time if batch_time > 0 else 0
                
                print(f"  📊 Batch {len(batch_times):,}: {current_batch_size:,} orders in {batch_time:.2f}s "
                      f"({ops_per_sec:.0f} ops/sec) - Progress: {progress:.1f}%")
                
                # Small delay to allow CDC to process
                await asyncio.sleep(0.1)
            
            await conn.close()
            
            total_time = time.time() - start_time
            avg_ops_per_sec = total_inserted / total_time if total_time > 0 else 0
            
            return {
                'total_inserted': total_inserted,
                'total_time_seconds': total_time,
                'avg_ops_per_second': avg_ops_per_sec,
                'batch_count': len(batch_times),
                'avg_batch_time': sum(batch_times) / len(batch_times) if batch_times else 0,
                'fastest_batch': min(batch_times) if batch_times else 0,
                'slowest_batch': max(batch_times) if batch_times else 0
            }
            
        except Exception as e:
            print(f"❌ Error in mass insert: {e}")
            return {'error': str(e)}

    async def run_test(self, record_count: int = 100000, batch_size: int = 5000):
        """Run the complete 3-phase mass insert test"""
        print("🎯 CDC Mass Insert Test with 3-Phase Monitoring")
        print("=" * 55)
        print(f"📈 Target: {record_count:,} records in batches of {batch_size:,}")
        print(f"⏰ Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Phase 1: IDLE (before insert)
        print(f"\n📸 PHASE 1: IDLE STATE")
        self.phase_data['idle'] = await self.capture_phase_data('idle')
        
        # Wait a moment
        await asyncio.sleep(2)
        
        # Phase 2: PROCESSING (during insert)
        print(f"\n📸 PHASE 2: PROCESSING STATE")
        processing_start = time.time()
        
        # Start background monitoring during insert
        async def monitor_during_insert():
            await asyncio.sleep(5)  # Let insert start
            return await self.capture_phase_data('processing')
        
        # Start both tasks
        monitor_task = asyncio.create_task(monitor_during_insert())
        insert_task = asyncio.create_task(self.mass_insert_orders(record_count, batch_size))
        
        # Wait for both to complete
        insert_results, processing_data = await asyncio.gather(insert_task, monitor_task)
        
        self.phase_data['processing'] = processing_data
        processing_time = time.time() - processing_start
        
        # Phase 3: FINAL (after insert, let CDC catch up)
        print(f"\n⏳ Waiting 10 seconds for CDC to catch up...")
        await asyncio.sleep(10)
        
        print(f"\n📸 PHASE 3: FINAL STATE")
        self.phase_data['final'] = await self.capture_phase_data('final')
        
        # Compile final results
        self.results = {
            'test_info': {
                'record_count': record_count,
                'batch_size': batch_size,
                'start_time': datetime.now().isoformat(),
                'processing_time_seconds': processing_time
            },
            'insert_results': insert_results,
            'phase_data': self.phase_data,
            'summary': {
                'total_phases': 3,
                'success': 'error' not in insert_results,
                'completion_time': datetime.now().isoformat()
            }
        }
        
        # Save results
        await self.save_results()
        
        # Print summary
        self.print_summary()

    async def save_results(self):
        """Save test results to JSON file"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"mass_insert_test_{timestamp}.json"
        
        # Create testing-results directory if it doesn't exist
        os.makedirs("testing-results", exist_ok=True)
        filepath = os.path.join("testing-results", filename)
        
        try:
            with open(filepath, 'w') as f:
                json.dump(self.results, f, indent=2, default=str)
            print(f"\n💾 Results saved to: {filepath}")
        except Exception as e:
            print(f"❌ Error saving results: {e}")

    def print_summary(self):
        """Print test summary"""
        print(f"\n🎯 MASS INSERT TEST SUMMARY")
        print("=" * 40)
        
        if 'insert_results' in self.results:
            insert_data = self.results['insert_results']
            if 'error' not in insert_data:
                print(f"✅ Insert Status: SUCCESS")
                print(f"📊 Records Inserted: {insert_data.get('total_inserted', 0):,}")
                print(f"⏱️  Total Time: {insert_data.get('total_time_seconds', 0):.2f} seconds")
                print(f"🚀 Avg Ops/Second: {insert_data.get('avg_ops_per_second', 0):.0f}")
                print(f"📦 Batches: {insert_data.get('batch_count', 0)}")
            else:
                print(f"❌ Insert Status: FAILED - {insert_data['error']}")
        
        # Database counts summary
        print(f"\n📊 DATABASE COUNTS BY PHASE:")
        for phase_name, phase_data in self.phase_data.items():
            source_count = phase_data.get('source_db', {}).get('orders_count', 'N/A')
            target_count = phase_data.get('target_db', {}).get('orders_count', 'N/A')
            print(f"  {phase_name.upper():>10}: Source={source_count:>8} | Target={target_count:>8}")
        
        print(f"\n🔍 Full details saved in testing-results/")

async def main():
    """Main function"""
    if len(sys.argv) > 1:
        try:
            record_count = int(sys.argv[1])
        except ValueError:
            record_count = 100000
    else:
        record_count = 100000
    
    if len(sys.argv) > 2:
        try:
            batch_size = int(sys.argv[2])
        except ValueError:
            batch_size = 5000
    else:
        batch_size = 5000
    
    monitor = CDCMassInsertMonitor()
    await monitor.run_test(record_count, batch_size)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⚠️  Test interrupted by user")
    except Exception as e:
        print(f"❌ Test failed: {e}")
