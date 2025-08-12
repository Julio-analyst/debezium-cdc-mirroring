#!/usr/bin/env python3
"""
Comprehensive CDC Pipeline Performance Monitor
==============================================

Script lengkap untuk monitoring performance CDC pipeline:
- Docker stats (CPU, Memory, Network, Disk)
- Kafka topics dan message counts
- Database source & target metrics
- Connector status dan throughput
- Latency measurements
- Error tracking
- Real-time analytics

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
import psutil
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import threading
from collections import defaultdict, deque

class CDCPerformanceMonitor:
    def __init__(self, config_path: str = "config.yaml"):
        """Initialize the comprehensive performance monitor"""
        self.config = self._load_config(config_path)
        self.monitoring_active = False
        self.metrics_history = defaultdict(deque)
        self.container_names = [
            "debezium-cdc-mirroring-postgres-1",
            "debezium-cdc-mirroring-kafka-1", 
            "debezium-cdc-mirroring-zookeeper-1",
            "debezium-cdc-mirroring-target-postgres-1",
            "tutorial-connect-1"
        ]
        self.kafka_connect_url = "http://localhost:8083"
        self.results = {}
        
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

    def get_system_metrics(self) -> Dict[str, Any]:
        """Get host system metrics"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            network = psutil.net_io_counters()
            
            return {
                'timestamp': datetime.now().isoformat(),
                'cpu': {
                    'percent': cpu_percent,
                    'count': psutil.cpu_count(),
                    'load_avg': os.getloadavg() if hasattr(os, 'getloadavg') else None
                },
                'memory': {
                    'total_gb': round(memory.total / (1024**3), 2),
                    'available_gb': round(memory.available / (1024**3), 2),
                    'used_gb': round(memory.used / (1024**3), 2),
                    'percent': memory.percent
                },
                'disk': {
                    'total_gb': round(disk.total / (1024**3), 2),
                    'free_gb': round(disk.free / (1024**3), 2),
                    'used_gb': round(disk.used / (1024**3), 2),
                    'percent': round((disk.used / disk.total) * 100, 2)
                },
                'network': {
                    'bytes_sent': network.bytes_sent,
                    'bytes_recv': network.bytes_recv,
                    'packets_sent': network.packets_sent,
                    'packets_recv': network.packets_recv
                }
            }
        except Exception as e:
            return {'error': str(e)}

    def get_detailed_docker_stats(self) -> Dict[str, Any]:
        """Get comprehensive Docker container statistics"""
        stats = {}
        
        try:
            # Get detailed stats for all containers
            result = subprocess.run(
                ['docker', 'stats', '--no-stream', '--format', 
                 '{{.Name}};{{.CPUPerc}};{{.MemUsage}};{{.MemPerc}};{{.NetIO}};{{.BlockIO}};{{.PIDs}}'],
                capture_output=True, text=True, timeout=15
            )
            
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line and ';' in line:
                        parts = line.split(';')
                        if len(parts) >= 7:
                            container_name = parts[0]
                            if any(name in container_name for name in self.container_names):
                                stats[container_name] = {
                                    'cpu_percent': parts[1],
                                    'memory_usage': parts[2],
                                    'memory_percent': parts[3],
                                    'network_io': parts[4],
                                    'block_io': parts[5],
                                    'pids': parts[6],
                                    'timestamp': datetime.now().isoformat()
                                }
            
            # Get additional container info
            for container in self.container_names:
                if container in stats:
                    try:
                        # Get container inspect info
                        inspect_result = subprocess.run(
                            ['docker', 'inspect', container],
                            capture_output=True, text=True, timeout=10
                        )
                        if inspect_result.returncode == 0:
                            inspect_data = json.loads(inspect_result.stdout)[0]
                            stats[container]['info'] = {
                                'status': inspect_data.get('State', {}).get('Status'),
                                'started_at': inspect_data.get('State', {}).get('StartedAt'),
                                'restart_count': inspect_data.get('RestartCount', 0)
                            }
                    except Exception as e:
                        stats[container]['info_error'] = str(e)
                        
        except Exception as e:
            print(f"❌ Error getting Docker stats: {e}")
            
        return stats

    def get_kafka_comprehensive_metrics(self) -> Dict[str, Any]:
        """Get comprehensive Kafka metrics"""
        try:
            kafka_metrics = {
                'topics': {},
                'consumer_groups': {},
                'broker_info': {},
                'error': None
            }
            
            # List all topics
            topics_result = subprocess.run(
                ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1', 
                 'kafka-topics', '--bootstrap-server', 'localhost:9092', '--list'],
                capture_output=True, text=True, timeout=15
            )
            
            if topics_result.returncode == 0:
                topics = topics_result.stdout.strip().split('\n')
                kafka_metrics['topics']['list'] = topics
                kafka_metrics['topics']['count'] = len(topics)
                
                # Get detailed info for main topic
                main_topic = "dbserver1.inventory.orders"
                if main_topic in topics:
                    # Get topic description
                    desc_result = subprocess.run(
                        ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1',
                         'kafka-topics', '--bootstrap-server', 'localhost:9092',
                         '--describe', '--topic', main_topic],
                        capture_output=True, text=True, timeout=15
                    )
                    
                    # Get consumer group info
                    groups_result = subprocess.run(
                        ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1',
                         'kafka-consumer-groups', '--bootstrap-server', 'localhost:9092', '--list'],
                        capture_output=True, text=True, timeout=15
                    )
                    
                    kafka_metrics['topics'][main_topic] = {
                        'description': desc_result.stdout if desc_result.returncode == 0 else None,
                        'exists': True
                    }
                    
                    if groups_result.returncode == 0:
                        groups = groups_result.stdout.strip().split('\n')
                        kafka_metrics['consumer_groups']['list'] = groups
                        kafka_metrics['consumer_groups']['count'] = len(groups)
                        
                        # Get group details for connect groups
                        for group in groups:
                            if 'connect' in group.lower():
                                group_detail = subprocess.run(
                                    ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1',
                                     'kafka-consumer-groups', '--bootstrap-server', 'localhost:9092',
                                     '--describe', '--group', group],
                                    capture_output=True, text=True, timeout=15
                                )
                                if group_detail.returncode == 0:
                                    kafka_metrics['consumer_groups'][group] = group_detail.stdout
            
            # Get broker info
            broker_result = subprocess.run(
                ['docker', 'exec', 'debezium-cdc-mirroring-kafka-1',
                 'kafka-broker-api-versions', '--bootstrap-server', 'localhost:9092'],
                capture_output=True, text=True, timeout=10
            )
            
            kafka_metrics['broker_info'] = {
                'accessible': broker_result.returncode == 0,
                'version_info': broker_result.stdout if broker_result.returncode == 0 else None
            }
            
            return kafka_metrics
            
        except Exception as e:
            return {'error': str(e)}

    def get_kafka_connect_status(self) -> Dict[str, Any]:
        """Get Kafka Connect cluster and connector status"""
        try:
            connect_status = {
                'cluster': {},
                'connectors': {},
                'error': None
            }
            
            # Get cluster info
            try:
                cluster_response = requests.get(f"{self.kafka_connect_url}/", timeout=10)
                if cluster_response.status_code == 200:
                    connect_status['cluster'] = cluster_response.json()
                    connect_status['cluster']['accessible'] = True
                else:
                    connect_status['cluster']['accessible'] = False
                    connect_status['cluster']['status_code'] = cluster_response.status_code
            except requests.exceptions.RequestException as e:
                connect_status['cluster']['accessible'] = False
                connect_status['cluster']['error'] = str(e)
            
            # Get connectors list
            try:
                connectors_response = requests.get(f"{self.kafka_connect_url}/connectors", timeout=10)
                if connectors_response.status_code == 200:
                    connectors_list = connectors_response.json()
                    connect_status['connectors']['list'] = connectors_list
                    connect_status['connectors']['count'] = len(connectors_list)
                    
                    # Get detailed status for each connector
                    for connector_name in connectors_list:
                        try:
                            status_response = requests.get(
                                f"{self.kafka_connect_url}/connectors/{connector_name}/status", 
                                timeout=10
                            )
                            if status_response.status_code == 200:
                                connect_status['connectors'][connector_name] = status_response.json()
                        except Exception as e:
                            connect_status['connectors'][connector_name] = {'error': str(e)}
            except Exception as e:
                connect_status['connectors']['error'] = str(e)
            
            return connect_status
            
        except Exception as e:
            return {'error': str(e)}

    async def get_database_comprehensive_metrics(self, db_config: Dict[str, Any], db_name: str) -> Dict[str, Any]:
        """Get comprehensive database metrics"""
        try:
            conn = await asyncpg.connect(
                host=db_config['host'],
                port=db_config['port'],
                user=db_config['user'],
                password=db_config['password'],
                database=db_config['database']
            )
            
            metrics = {
                'connection': {'status': 'connected'},
                'tables': {},
                'performance': {},
                'replication': {},
                'error': None
            }
            
            # Table metrics
            if db_name == "source":
                # Source database queries
                orders_count = await conn.fetchval("SELECT COUNT(*) FROM inventory.orders")
                customers_count = await conn.fetchval("SELECT COUNT(*) FROM inventory.customers")
                products_count = await conn.fetchval("SELECT COUNT(*) FROM inventory.products")
                
                metrics['tables'] = {
                    'orders': orders_count,
                    'customers': customers_count,
                    'products': products_count
                }
                
                # Replication slot info
                try:
                    replication_slots = await conn.fetch("""
                        SELECT slot_name, plugin, slot_type, database, active, 
                               restart_lsn, confirmed_flush_lsn 
                        FROM pg_replication_slots
                    """)
                    metrics['replication']['slots'] = [dict(row) for row in replication_slots]
                except Exception as e:
                    metrics['replication']['slots_error'] = str(e)
                
                # WAL status
                try:
                    wal_status = await conn.fetchrow("""
                        SELECT pg_current_wal_lsn() as current_lsn,
                               pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') as wal_bytes
                    """)
                    metrics['replication']['wal'] = dict(wal_status) if wal_status else {}
                except Exception as e:
                    metrics['replication']['wal_error'] = str(e)
                    
            else:
                # Target database queries  
                try:
                    orders_count = await conn.fetchval("SELECT COUNT(*) FROM orders")
                    metrics['tables']['orders'] = orders_count
                except Exception as e:
                    # Try with schema prefix if table not found
                    try:
                        orders_count = await conn.fetchval("SELECT COUNT(*) FROM public.orders")
                        metrics['tables']['orders'] = orders_count
                    except Exception as e2:
                        metrics['tables']['orders_error'] = f"{str(e)} | {str(e2)}"
            
            # Performance metrics
            try:
                db_stats = await conn.fetchrow("""
                    SELECT datname, numbackends, xact_commit, xact_rollback,
                           blks_read, blks_hit, tup_returned, tup_fetched,
                           tup_inserted, tup_updated, tup_deleted
                    FROM pg_stat_database 
                    WHERE datname = current_database()
                """)
                
                if db_stats:
                    metrics['performance']['database_stats'] = dict(db_stats)
                    
                    # Calculate cache hit ratio
                    total_reads = db_stats['blks_read'] + db_stats['blks_hit']
                    if total_reads > 0:
                        cache_hit_ratio = (db_stats['blks_hit'] / total_reads) * 100
                        metrics['performance']['cache_hit_ratio'] = round(cache_hit_ratio, 2)
                        
            except Exception as e:
                metrics['performance']['stats_error'] = str(e)
            
            # Connection info
            try:
                connections = await conn.fetch("""
                    SELECT state, count(*) as count 
                    FROM pg_stat_activity 
                    WHERE datname = current_database()
                    GROUP BY state
                """)
                metrics['performance']['connections'] = {row['state']: row['count'] for row in connections}
            except Exception as e:
                metrics['performance']['connections_error'] = str(e)
            
            # Database size
            try:
                db_size = await conn.fetchval("SELECT pg_size_pretty(pg_database_size(current_database()))")
                metrics['performance']['database_size'] = db_size
            except Exception as e:
                metrics['performance']['size_error'] = str(e)
                
            await conn.close()
            return metrics
            
        except Exception as e:
            print(f"❌ Database connection error ({db_name}): {e}")
            return {'error': str(e), 'connection': {'status': 'failed'}}

    async def measure_end_to_end_latency(self) -> Dict[str, Any]:
        """Measure end-to-end CDC latency"""
        try:
            latency_results = {
                'test_start': datetime.now().isoformat(),
                'measurements': []
            }
            
            # Get initial counts
            source_conn = await asyncpg.connect(
                host=self.config['database']['host'],
                port=self.config['database']['port'],
                user=self.config['database']['user'],
                password=self.config['database']['password'],
                database=self.config['database']['database']
            )
            
            target_conn = await asyncpg.connect(
                host=self.config['target_database']['host'],
                port=self.config['target_database']['port'],
                user=self.config['target_database']['user'],
                password=self.config['target_database']['password'],
                database=self.config['target_database']['database']
            )
            
            initial_source = await source_conn.fetchval("SELECT COUNT(*) FROM inventory.orders")
            initial_target = await target_conn.fetchval("SELECT COUNT(*) FROM orders")
            
            # Perform test inserts and measure latency
            for i in range(5):
                insert_start = time.time()
                
                # Insert a test record
                customers = await source_conn.fetch("SELECT id FROM inventory.customers LIMIT 10")
                products = await source_conn.fetch("SELECT id FROM inventory.products LIMIT 10")
                
                if customers and products:
                    customer_id = customers[0]['id']
                    product_id = products[0]['id']
                    
                    await source_conn.execute("""
                        INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id)
                        VALUES ($1, $2, $3, $4)
                    """, datetime.now().date(), customer_id, 1, product_id)
                    
                    insert_time = time.time()
                    
                    # Wait for CDC to propagate (max 30 seconds)
                    propagated = False
                    timeout = 30
                    start_wait = time.time()
                    
                    while time.time() - start_wait < timeout:
                        current_target = await target_conn.fetchval("SELECT COUNT(*) FROM orders")
                        if current_target > initial_target + i:
                            propagated = True
                            propagation_time = time.time()
                            break
                        await asyncio.sleep(0.5)
                    
                    if propagated:
                        total_latency = propagation_time - insert_start
                        cdc_latency = propagation_time - insert_time
                        
                        latency_results['measurements'].append({
                            'test_number': i + 1,
                            'insert_timestamp': datetime.fromtimestamp(insert_start).isoformat(),
                            'propagation_timestamp': datetime.fromtimestamp(propagation_time).isoformat(),
                            'total_latency_ms': round(total_latency * 1000, 2),
                            'cdc_latency_ms': round(cdc_latency * 1000, 2),
                            'status': 'success'
                        })
                    else:
                        latency_results['measurements'].append({
                            'test_number': i + 1,
                            'insert_timestamp': datetime.fromtimestamp(insert_start).isoformat(),
                            'status': 'timeout',
                            'timeout_seconds': timeout
                        })
                
                # Wait between tests
                await asyncio.sleep(2)
            
            await source_conn.close()
            await target_conn.close()
            
            # Calculate statistics
            successful_measurements = [m for m in latency_results['measurements'] if m['status'] == 'success']
            if successful_measurements:
                latencies = [m['total_latency_ms'] for m in successful_measurements]
                cdc_latencies = [m['cdc_latency_ms'] for m in successful_measurements]
                
                latency_results['statistics'] = {
                    'successful_tests': len(successful_measurements),
                    'failed_tests': len(latency_results['measurements']) - len(successful_measurements),
                    'avg_total_latency_ms': round(sum(latencies) / len(latencies), 2),
                    'min_total_latency_ms': round(min(latencies), 2),
                    'max_total_latency_ms': round(max(latencies), 2),
                    'avg_cdc_latency_ms': round(sum(cdc_latencies) / len(cdc_latencies), 2),
                    'min_cdc_latency_ms': round(min(cdc_latencies), 2),
                    'max_cdc_latency_ms': round(max(cdc_latencies), 2)
                }
            
            return latency_results
            
        except Exception as e:
            return {'error': str(e)}

    def get_docker_logs_analysis(self) -> Dict[str, Any]:
        """Analyze Docker logs for errors and patterns"""
        logs_analysis = {
            'containers': {},
            'error_summary': {},
            'timestamp': datetime.now().isoformat()
        }
        
        for container in self.container_names:
            try:
                # Get recent logs
                result = subprocess.run(
                    ['docker', 'logs', '--tail', '100', '--since', '10m', container],
                    capture_output=True, text=True, timeout=15
                )
                
                if result.returncode == 0:
                    logs = result.stdout + result.stderr
                    lines = logs.split('\n')
                    
                    # Analyze logs
                    error_count = sum(1 for line in lines if 'ERROR' in line.upper())
                    warn_count = sum(1 for line in lines if 'WARN' in line.upper())
                    info_count = sum(1 for line in lines if 'INFO' in line.upper())
                    
                    logs_analysis['containers'][container] = {
                        'total_lines': len(lines),
                        'error_count': error_count,
                        'warning_count': warn_count,
                        'info_count': info_count,
                        'recent_errors': [line for line in lines if 'ERROR' in line.upper()][-5:],
                        'recent_warnings': [line for line in lines if 'WARN' in line.upper()][-5:]
                    }
                else:
                    logs_analysis['containers'][container] = {'error': 'Could not retrieve logs'}
                    
            except Exception as e:
                logs_analysis['containers'][container] = {'error': str(e)}
        
        # Summary
        total_errors = sum(
            container.get('error_count', 0) 
            for container in logs_analysis['containers'].values() 
            if isinstance(container, dict) and 'error_count' in container
        )
        total_warnings = sum(
            container.get('warning_count', 0) 
            for container in logs_analysis['containers'].values() 
            if isinstance(container, dict) and 'warning_count' in container
        )
        
        logs_analysis['error_summary'] = {
            'total_errors': total_errors,
            'total_warnings': total_warnings,
            'containers_with_errors': len([
                k for k, v in logs_analysis['containers'].items() 
                if isinstance(v, dict) and v.get('error_count', 0) > 0
            ])
        }
        
        return logs_analysis

    async def run_comprehensive_monitoring(self, duration_minutes: int = 5):
        """Run comprehensive performance monitoring with 3-phase data collection"""
        print(f"🎯 CDC Comprehensive Performance Monitoring")
        print("=" * 50)
        print(f"⏱️  Duration: {duration_minutes} minutes")
        print(f"🚀 Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        start_time = time.time()
        
        # Phase 1: IDLE - Collect baseline metrics
        print(f"\n📸 PHASE 1: IDLE STATE - Baseline Metrics")
        idle_phase = await self.collect_phase_metrics("idle")
        
        # Wait between phases
        await asyncio.sleep(2)
        
        # Phase 2: PROCESSING - Collect metrics during load (simulate activity)
        print(f"\n📸 PHASE 2: PROCESSING STATE - Under Load")
        
        # Start background activity simulation
        processing_start = time.time()
        
        async def simulate_load_and_monitor():
            # Do some database activity to create load
            try:
                source_conn = await asyncpg.connect(
                    host=self.config['database']['host'],
                    port=self.config['database']['port'],
                    user=self.config['database']['user'],
                    password=self.config['database']['password'],
                    database=self.config['database']['database']
                )
                
                # Generate some load with queries
                for i in range(10):
                    await source_conn.fetchval("SELECT COUNT(*) FROM inventory.orders")
                    await source_conn.fetchval("SELECT COUNT(*) FROM inventory.customers") 
                    await source_conn.fetchval("SELECT COUNT(*) FROM inventory.products")
                    await asyncio.sleep(0.1)
                    
                await source_conn.close()
            except Exception as e:
                print(f"  ⚠️  Load simulation error: {e}")
            
            # Collect metrics during processing
            await asyncio.sleep(2)  # Let load settle
            return await self.collect_phase_metrics("processing")
        
        processing_phase = await simulate_load_and_monitor()
        processing_time = time.time() - processing_start
        
        # Wait for system to settle
        print(f"\n⏳ Waiting 5 seconds for system to settle...")
        await asyncio.sleep(5)
        
        # Phase 3: FINAL - Collect final state metrics
        print(f"\n� PHASE 3: FINAL STATE - Post-Load")
        final_phase = await self.collect_phase_metrics("final")
        
        # Compile comprehensive results
        monitoring_time = time.time() - start_time
        
        self.results = {
            'monitoring_info': {
                'start_time': datetime.now().isoformat(),
                'duration_minutes': duration_minutes,
                'total_monitoring_time_seconds': round(monitoring_time, 2),
                'processing_time_seconds': round(processing_time, 2)
            },
            'phase_data': {
                'idle': idle_phase,
                'processing': processing_phase,
                'final': final_phase
            },
            'comparison': self.compare_phases(idle_phase, processing_phase, final_phase)
        }
        
        # Generate summary after results are set
        self.results['summary'] = await self.generate_summary()
        
        # Save results
        await self.save_results()
        
        # Print summary
        self.print_comprehensive_summary()

    async def collect_phase_metrics(self, phase_name: str) -> Dict[str, Any]:
        """Collect comprehensive metrics for a specific phase"""
        print(f"  🔍 Collecting {phase_name} phase metrics...")
        
        phase_data = {
            'phase': phase_name,
            'timestamp': datetime.now().isoformat()
        }
        
        # System metrics
        print(f"    🖥️  System metrics...")
        phase_data['system_metrics'] = self.get_system_metrics()
        
        # Docker metrics
        print(f"    🐳 Docker metrics...")
        phase_data['docker_metrics'] = self.get_detailed_docker_stats()
        
        # Kafka metrics
        print(f"    📨 Kafka metrics...")
        phase_data['kafka_metrics'] = self.get_kafka_comprehensive_metrics()
        
        # Kafka Connect status
        print(f"    🔗 Kafka Connect status...")
        phase_data['connect_status'] = self.get_kafka_connect_status()
        
        # Database metrics
        print(f"    🗄️  Database metrics...")
        try:
            phase_data['source_database'] = await self.get_database_comprehensive_metrics(
                self.config['database'], 'source'
            )
        except Exception as e:
            print(f"      ❌ Source DB error: {e}")
            phase_data['source_database'] = {'error': str(e)}
            
        try:
            phase_data['target_database'] = await self.get_database_comprehensive_metrics(
                self.config['target_database'], 'target'
            )
        except Exception as e:
            print(f"      ❌ Target DB error: {e}")
            phase_data['target_database'] = {'error': str(e)}
        
        # Log analysis
        print(f"    📋 Log analysis...")
        phase_data['logs_analysis'] = self.get_docker_logs_analysis()
        
        # Only do latency measurement in processing phase
        if phase_name == "processing":
            print(f"    ⏱️  Latency measurements...")
            phase_data['latency_analysis'] = await self.measure_end_to_end_latency()
        
        return phase_data

    def compare_phases(self, idle: Dict[str, Any], processing: Dict[str, Any], final: Dict[str, Any]) -> Dict[str, Any]:
        """Compare metrics across phases"""
        comparison = {
            'timestamp': datetime.now().isoformat(),
            'container_usage': {},
            'database_changes': {},
            'system_changes': {}
        }
        
        # Compare Docker container usage across phases
        for container_name in self.container_names:
            comparison['container_usage'][container_name] = {
                'idle': self.extract_container_stats(idle.get('docker_metrics', {}), container_name),
                'processing': self.extract_container_stats(processing.get('docker_metrics', {}), container_name),
                'final': self.extract_container_stats(final.get('docker_metrics', {}), container_name)
            }
        
        # Compare database counts
        comparison['database_changes'] = {
            'source_orders': {
                'idle': idle.get('source_database', {}).get('tables', {}).get('orders', 0),
                'processing': processing.get('source_database', {}).get('tables', {}).get('orders', 0),
                'final': final.get('source_database', {}).get('tables', {}).get('orders', 0)
            },
            'target_orders': {
                'idle': idle.get('target_database', {}).get('tables', {}).get('orders', 0),
                'processing': processing.get('target_database', {}).get('tables', {}).get('orders', 0),
                'final': final.get('target_database', {}).get('tables', {}).get('orders', 0)
            }
        }
        
        # Compare system metrics
        comparison['system_changes'] = {
            'cpu_usage': {
                'idle': idle.get('system_metrics', {}).get('cpu', {}).get('percent', 0),
                'processing': processing.get('system_metrics', {}).get('cpu', {}).get('percent', 0),
                'final': final.get('system_metrics', {}).get('cpu', {}).get('percent', 0)
            },
            'memory_usage': {
                'idle': idle.get('system_metrics', {}).get('memory', {}).get('percent', 0),
                'processing': processing.get('system_metrics', {}).get('memory', {}).get('percent', 0),
                'final': final.get('system_metrics', {}).get('memory', {}).get('percent', 0)
            }
        }
        
        return comparison

    def extract_container_stats(self, docker_metrics: Dict[str, Any], container_name: str) -> Dict[str, Any]:
        """Extract key stats from container metrics"""
        container_data = docker_metrics.get(container_name, {})
        if not container_data or 'error' in container_data:
            return {'error': 'No data'}
            
        return {
            'cpu_percent': container_data.get('cpu_percent', 'N/A'),
            'memory_usage': container_data.get('memory_usage', 'N/A'),
            'memory_percent': container_data.get('memory_percent', 'N/A'),
            'timestamp': container_data.get('timestamp', 'N/A')
        }

    async def generate_summary(self) -> Dict[str, Any]:
        """Generate monitoring summary"""
        summary = {
            'timestamp': datetime.now().isoformat(),
            'pipeline_health': 'unknown',
            'key_metrics': {},
            'alerts': []
        }
        
        # Use final phase data for summary (most recent)
        final_phase = self.results.get('phase_data', {}).get('final', {})
        
        # Determine pipeline health
        alerts = []
        health_score = 100
        
        # Check database connectivity
        source_db_ok = final_phase.get('source_database', {}).get('connection', {}).get('status') == 'connected'
        target_db_ok = final_phase.get('target_database', {}).get('connection', {}).get('status') == 'connected'
        
        if not source_db_ok:
            alerts.append("❌ Source database connection failed")
            health_score -= 30
        if not target_db_ok:
            alerts.append("❌ Target database connection failed")
            health_score -= 30
            
        # Check Kafka Connect
        connect_accessible = final_phase.get('connect_status', {}).get('cluster', {}).get('accessible', False)
        if not connect_accessible:
            alerts.append("⚠️  Kafka Connect not accessible")
            health_score -= 20
            
        # Check connector status
        connectors = final_phase.get('connect_status', {}).get('connectors', {})
        for conn_name, conn_data in connectors.items():
            if isinstance(conn_data, dict) and 'connector' in conn_data:
                conn_state = conn_data.get('connector', {}).get('state')
                if conn_state != 'RUNNING':
                    alerts.append(f"⚠️  Connector {conn_name} is {conn_state}")
                    health_score -= 15
        
        # Check latency (from processing phase)
        processing_phase = self.results.get('phase_data', {}).get('processing', {})
        latency_stats = processing_phase.get('latency_analysis', {}).get('statistics', {})
        if latency_stats:
            avg_latency = latency_stats.get('avg_total_latency_ms', 0)
            if avg_latency > 5000:  # 5 seconds
                alerts.append(f"⚠️  High latency: {avg_latency:.0f}ms")
                health_score -= 10
                
        # Check errors in logs
        logs_summary = final_phase.get('logs_analysis', {}).get('error_summary', {})
        total_errors = logs_summary.get('total_errors', 0)
        if total_errors > 5:
            alerts.append(f"⚠️  {total_errors} errors found in logs")
            health_score -= 10
        
        # Determine health
        if health_score >= 90:
            summary['pipeline_health'] = 'excellent'
        elif health_score >= 70:
            summary['pipeline_health'] = 'good'
        elif health_score >= 50:
            summary['pipeline_health'] = 'fair'
        else:
            summary['pipeline_health'] = 'poor'
            
        summary['health_score'] = health_score
        summary['alerts'] = alerts
        
        # Key metrics
        summary['key_metrics'] = {
            'source_orders_count': final_phase.get('source_database', {}).get('tables', {}).get('orders', 0),
            'target_orders_count': final_phase.get('target_database', {}).get('tables', {}).get('orders', 0),
            'avg_latency_ms': latency_stats.get('avg_total_latency_ms', 0),
            'total_errors': total_errors,
            'connectors_running': len([
                conn for conn, data in connectors.items() 
                if isinstance(data, dict) and data.get('connector', {}).get('state') == 'RUNNING'
            ])
        }
        
        return summary

    async def save_results(self):
        """Save monitoring results to JSON file"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"comprehensive_performance_report_{timestamp}.json"
        
        # Create testing-results directory if it doesn't exist
        os.makedirs("testing-results", exist_ok=True)
        filepath = os.path.join("testing-results", filename)
        
        try:
            with open(filepath, 'w') as f:
                json.dump(self.results, f, indent=2, default=str)
            print(f"\n💾 Comprehensive report saved to: {filepath}")
        except Exception as e:
            print(f"❌ Error saving report: {e}")

    def print_comprehensive_summary(self):
        """Print comprehensive monitoring summary"""
        print(f"\n🎯 COMPREHENSIVE PERFORMANCE SUMMARY")
        print("=" * 70)
        
        summary = self.results.get('summary', {})
        
        # Health status
        health = summary.get('pipeline_health', 'unknown')
        health_score = summary.get('health_score', 0)
        health_color = {
            'excellent': '🟢',
            'good': '🟡', 
            'fair': '🟠',
            'poor': '🔴'
        }.get(health, '⚪')
        
        print(f"{health_color} Pipeline Health: {health.upper()} ({health_score}/100)")
        
        # Key metrics
        key_metrics = summary.get('key_metrics', {})
        print(f"\n📊 KEY METRICS:")
        print(f"  📋 Source Orders: {key_metrics.get('source_orders_count', 'N/A'):,}")
        print(f"  📋 Target Orders: {key_metrics.get('target_orders_count', 'N/A'):,}")
        print(f"  ⏱️  Avg Latency: {key_metrics.get('avg_latency_ms', 0):.1f}ms")
        print(f"  🔗 Running Connectors: {key_metrics.get('connectors_running', 0)}")
        print(f"  ❌ Total Errors: {key_metrics.get('total_errors', 0)}")
        
        # Detailed 3-Phase Container Usage Analysis
        print(f"\n🐳 DETAILED CONTAINER ANALYSIS BY PHASE:")
        print("=" * 70)
        comparison = self.results.get('comparison', {})
        container_usage = comparison.get('container_usage', {})
        
        if container_usage:
            for container_name, phases in container_usage.items():
                short_name = container_name.replace("debezium-cdc-mirroring-", "").replace("tutorial-", "")
                print(f"\n📦 {short_name.upper()}")
                print("-" * 50)
                
                # Header
                print(f"{'Phase':<12} {'CPU %':<8} {'Memory %':<10} {'Memory Usage':<20} {'Network I/O':<15} {'PIDs':<6}")
                print("-" * 75)
                
                for phase_name, stats in phases.items():
                    if isinstance(stats, dict) and 'cpu_percent' in stats:
                        cpu = stats.get('cpu_percent', 'N/A')
                        mem_pct = stats.get('memory_percent', 'N/A')
                        mem_usage = stats.get('memory_usage', 'N/A')
                        
                        # Get additional details from phase data
                        phase_data = self.results.get('phase_data', {}).get(phase_name, {})
                        docker_metrics = phase_data.get('docker_metrics', {})
                        container_detail = docker_metrics.get(container_name, {})
                        
                        network_io = container_detail.get('network_io', 'N/A')
                        pids = container_detail.get('pids', 'N/A')
                        
                        print(f"{phase_name:<12} {cpu:<8} {mem_pct:<10} {mem_usage:<20} {network_io:<15} {pids:<6}")
                    else:
                        print(f"{phase_name:<12} {'ERROR':<8} {'N/A':<10} {'N/A':<20} {'N/A':<15} {'N/A':<6}")
        
        # System resources detailed analysis by phase
        system_changes = comparison.get('system_changes', {})
        if system_changes:
            print(f"\n🖥️  DETAILED SYSTEM RESOURCES BY PHASE:")
            print("=" * 70)
            
            # Get detailed system metrics from each phase
            phase_data = self.results.get('phase_data', {})
            
            print(f"{'Metric':<20} {'Idle':<15} {'Processing':<15} {'Final':<15} {'Change':<10}")
            print("-" * 70)
            
            # CPU Analysis
            cpu_data = system_changes.get('cpu_usage', {})
            cpu_idle = cpu_data.get('idle', 0)
            cpu_proc = cpu_data.get('processing', 0)
            cpu_final = cpu_data.get('final', 0)
            cpu_change = cpu_proc - cpu_idle
            change_indicator = "📈" if cpu_change > 0 else "📉" if cpu_change < 0 else "➡️"
            print(f"{'CPU Usage %':<20} {cpu_idle:<15.1f} {cpu_proc:<15.1f} {cpu_final:<15.1f} {change_indicator}{cpu_change:+.1f}")
            
            # Memory Analysis
            memory_data = system_changes.get('memory_usage', {})
            mem_idle = memory_data.get('idle', 0)
            mem_proc = memory_data.get('processing', 0)
            mem_final = memory_data.get('final', 0)
            mem_change = mem_proc - mem_idle
            change_indicator = "�" if mem_change > 0 else "📉" if mem_change < 0 else "➡️"
            print(f"{'Memory Usage %':<20} {mem_idle:<15.1f} {mem_proc:<15.1f} {mem_final:<15.1f} {change_indicator}{mem_change:+.1f}")
            
            # Additional system details
            if 'idle' in phase_data:
                idle_sys = phase_data['idle'].get('system_metrics', {})
                proc_sys = phase_data.get('processing', {}).get('system_metrics', {})
                final_sys = phase_data.get('final', {}).get('system_metrics', {})
                
                print(f"\n💾 DETAILED SYSTEM METRICS:")
                print("-" * 50)
                
                # Memory details
                if 'memory' in idle_sys:
                    print(f"Memory Total: {idle_sys['memory'].get('total_gb', 0):.1f} GB")
                    print(f"Memory Available: Idle={idle_sys['memory'].get('available_gb', 0):.1f}GB | "
                          f"Proc={proc_sys.get('memory', {}).get('available_gb', 0):.1f}GB | "
                          f"Final={final_sys.get('memory', {}).get('available_gb', 0):.1f}GB")
                
                # CPU details
                if 'cpu' in idle_sys:
                    print(f"CPU Cores: {idle_sys['cpu'].get('count', 'N/A')}")
                
                # Disk details
                if 'disk' in idle_sys:
                    print(f"Disk Usage: {idle_sys['disk'].get('percent', 0):.1f}% ({idle_sys['disk'].get('used_gb', 0):.1f}GB / {idle_sys['disk'].get('total_gb', 0):.1f}GB)")
                
                # Network details
                if 'network' in idle_sys:
                    network = idle_sys['network']
                    print(f"Network I/O: Sent={network.get('bytes_sent', 0)/1024/1024:.1f}MB, Recv={network.get('bytes_recv', 0)/1024/1024:.1f}MB")
        
        # Database changes by phase
        db_changes = comparison.get('database_changes', {})
        if db_changes:
            print(f"\n� DATABASE COUNTS BY PHASE:")
            source_orders = db_changes.get('source_orders', {})
            target_orders = db_changes.get('target_orders', {})
            
            print(f"  Source Orders:")
            print(f"    Idle: {source_orders.get('idle', 0):,} | Processing: {source_orders.get('processing', 0):,} | Final: {source_orders.get('final', 0):,}")
            print(f"  Target Orders:")
            print(f"    Idle: {target_orders.get('idle', 0):,} | Processing: {target_orders.get('processing', 0):,} | Final: {target_orders.get('final', 0):,}")
        
        # Kafka and Connect Analysis
        phase_data = self.results.get('phase_data', {})
        if 'final' in phase_data:
            final_phase = phase_data['final']
            kafka_metrics = final_phase.get('kafka_metrics', {})
            connect_status = final_phase.get('connect_status', {})
            
            print(f"\n📨 KAFKA & CONNECT ANALYSIS:")
            print("=" * 70)
            
            # Kafka topics
            topics = kafka_metrics.get('topics', {})
            if topics:
                topic_list = topics.get('list', [])
                print(f"Kafka Topics: {len(topic_list)} total")
                for topic in topic_list:
                    if 'dbserver1' in topic:
                        print(f"  📋 Main Topic: {topic}")
            
            # Consumer groups
            consumer_groups = kafka_metrics.get('consumer_groups', {})
            if consumer_groups:
                groups = consumer_groups.get('list', [])
                print(f"Consumer Groups: {len(groups)} active")
                for group in groups:
                    if 'connect' in group.lower():
                        print(f"  🔗 Connect Group: {group}")
            
            # Connector status details
            connectors = connect_status.get('connectors', {})
            if connectors:
                connector_list = connectors.get('list', [])
                print(f"\nConnectors: {len(connector_list)} configured")
                
                for conn_name in connector_list:
                    if conn_name in connectors:
                        conn_data = connectors[conn_name]
                        conn_state = conn_data.get('connector', {}).get('state', 'UNKNOWN')
                        conn_type = conn_data.get('type', 'unknown')
                        
                        state_icon = "✅" if conn_state == "RUNNING" else "❌"
                        print(f"  {state_icon} {conn_name} ({conn_type}): {conn_state}")
                        
                        # Task details
                        tasks = conn_data.get('tasks', [])
                        if tasks:
                            for task in tasks:
                                task_state = task.get('state', 'UNKNOWN')
                                task_id = task.get('id', 'N/A')
                                task_icon = "✅" if task_state == "RUNNING" else "❌"
                                print(f"    {task_icon} Task {task_id}: {task_state}")
        
        # Latency Analysis
        processing_phase = self.results.get('phase_data', {}).get('processing', {})
        latency_analysis = processing_phase.get('latency_analysis', {})
        if latency_analysis:
            print(f"\n⏱️  LATENCY ANALYSIS:")
            print("=" * 70)
            
            measurements = latency_analysis.get('measurements', [])
            statistics = latency_analysis.get('statistics', {})
            
            if statistics:
                print(f"Latency Tests: {statistics.get('successful_tests', 0)}/{len(measurements)} successful")
                print(f"Average Total Latency: {statistics.get('avg_total_latency_ms', 0):.1f}ms")
                print(f"Average CDC Latency: {statistics.get('avg_cdc_latency_ms', 0):.1f}ms")
                print(f"Latency Range: {statistics.get('min_total_latency_ms', 0):.1f}ms - {statistics.get('max_total_latency_ms', 0):.1f}ms")
                
                # Latency quality assessment
                avg_latency = statistics.get('avg_total_latency_ms', 0)
                if avg_latency < 500:
                    latency_status = "🟢 EXCELLENT"
                elif avg_latency < 1000:
                    latency_status = "🟡 GOOD"
                elif avg_latency < 5000:
                    latency_status = "🟠 FAIR"
                else:
                    latency_status = "🔴 POOR"
                
                print(f"Latency Quality: {latency_status}")
                
                # Individual test results
                if measurements:
                    print(f"\nIndividual Test Results:")
                    print(f"{'Test':<6} {'Status':<10} {'Total Latency':<15} {'CDC Latency':<12}")
                    print("-" * 50)
                    for i, measurement in enumerate(measurements[:5]):  # Show first 5 tests
                        test_num = measurement.get('test_number', i+1)
                        status = measurement.get('status', 'unknown')
                        total_lat = measurement.get('total_latency_ms', 0)
                        cdc_lat = measurement.get('cdc_latency_ms', 0)
                        
                        status_icon = "✅" if status == "success" else "❌"
                        print(f"#{test_num:<5} {status_icon}{status:<9} {total_lat:<15.1f} {cdc_lat:<12.1f}")
        
        # Error Analysis
        if 'final' in phase_data:
            logs_analysis = phase_data['final'].get('logs_analysis', {})
            error_summary = logs_analysis.get('error_summary', {})
            
            if error_summary:
                print(f"\n🚨 ERROR & LOG ANALYSIS:")
                print("=" * 70)
                
                total_errors = error_summary.get('total_errors', 0)
                total_warnings = error_summary.get('total_warnings', 0)
                containers_with_errors = error_summary.get('containers_with_errors', 0)
                
                print(f"Total Errors: {total_errors}")
                print(f"Total Warnings: {total_warnings}")
                print(f"Containers with Errors: {containers_with_errors}")
                
                # Container-specific errors
                containers = logs_analysis.get('containers', {})
                for container_name, log_data in containers.items():
                    if isinstance(log_data, dict):
                        short_name = container_name.replace("debezium-cdc-mirroring-", "").replace("tutorial-", "")
                        error_count = log_data.get('error_count', 0)
                        warning_count = log_data.get('warning_count', 0)
                        total_lines = log_data.get('total_lines', 0)
                        
                        status_icon = "🔴" if error_count > 0 else "🟡" if warning_count > 0 else "🟢"
                        print(f"\n  {status_icon} {short_name}: {error_count} errors, {warning_count} warnings ({total_lines} log lines)")
                        
                        if error_count > 0:
                            recent_errors = log_data.get('recent_errors', [])
                            if recent_errors:
                                print(f"    Recent errors:")
                                for error in recent_errors[:2]:  # Show top 2 errors
                                    error_preview = error[:60] + "..." if len(error) > 60 else error
                                    print(f"      • {error_preview}")
        
        # Replication Analysis (if available)
        if 'final' in phase_data:
            final_source = phase_data['final'].get('source_database', {})
            replication = final_source.get('replication', {})
            
            if replication:
                print(f"\n🔄 REPLICATION ANALYSIS:")
                print("=" * 70)
                
                slots = replication.get('slots', [])
                if slots:
                    for slot in slots:
                        slot_name = slot.get('slot_name', 'N/A')
                        plugin = slot.get('plugin', 'N/A')
                        active = slot.get('active', False)
                        
                        status_icon = "✅" if active else "❌"
                        print(f"  {status_icon} Slot: {slot_name} ({plugin}) - {'Active' if active else 'Inactive'}")
                
                wal = replication.get('wal', {})
                if wal:
                    wal_bytes = wal.get('wal_bytes', 0)
                    print(f"  WAL Position: {wal_bytes:,} bytes")

        # Alerts
        alerts = summary.get('alerts', [])
        if alerts:
            print(f"\n🚨 ACTIVE ALERTS:")
            print("=" * 70)
            for alert in alerts:
                print(f"  {alert}")
        else:
            print(f"\n✅ NO ALERTS - ALL SYSTEMS NOMINAL")
        
        # Monitoring summary
        monitoring_info = self.results.get('monitoring_info', {})
        print(f"\n📋 MONITORING SESSION SUMMARY:")
        print("=" * 70)
        print(f"Total Monitoring Time: {monitoring_info.get('total_monitoring_time_seconds', 0):.1f} seconds")
        print(f"Processing Time: {monitoring_info.get('processing_time_seconds', 0):.1f} seconds")
        print(f"Duration Setting: {monitoring_info.get('duration_minutes', 0)} minutes")
        print(f"Report Generated: {monitoring_info.get('start_time', 'N/A')}")
        
        # Database sync status
        source_count = key_metrics.get('source_orders_count', 0)
        target_count = key_metrics.get('target_orders_count', 0)
        if source_count and target_count:
            sync_diff = abs(source_count - target_count)
            sync_pct = (min(source_count, target_count) / max(source_count, target_count)) * 100 if max(source_count, target_count) > 0 else 100
            print(f"\n🔄 FINAL SYNC STATUS:")
            print(f"  📊 Sync Percentage: {sync_pct:.1f}%")
            print(f"  📊 Record Difference: {sync_diff:,}")
        
        print(f"\n🔍 Full JSON details saved in testing-results/")
        print("=" * 70)

async def main():
    """Main function"""
    duration = 5  # default 5 minutes
    if len(sys.argv) > 1:
        try:
            duration = int(sys.argv[1])
        except ValueError:
            print("Invalid duration, using default 5 minutes")
    
    monitor = CDCPerformanceMonitor()
    await monitor.run_comprehensive_monitoring(duration)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⚠️  Monitoring interrupted by user")
    except Exception as e:
        print(f"❌ Monitoring failed: {e}")
