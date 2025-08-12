#!/usr/bin/env python3
"""
Quick test for dynamic data fetching
"""

import asyncio
import asyncpg
from random import choice

async def test_dynamic_data():
    """Test fetching dynamic data from database"""
    
    # Database configuration
    conn = await asyncpg.connect(
        host='localhost',
        port=5432,
        user='postgres',
        password='postgres',
        database='inventory'
    )
    
    try:
        # Fetch customers
        customers = await conn.fetch("SELECT id, first_name, last_name FROM inventory.customers")
        print(f"Found {len(customers)} customers:")
        for customer in customers:
            print(f"  - ID: {customer['id']}, Name: {customer['first_name']} {customer['last_name']}")
        
        # Fetch products
        products = await conn.fetch("SELECT id, name FROM inventory.products")
        print(f"\nFound {len(products)} products:")
        for product in products:
            print(f"  - ID: {product['id']}, Name: {product['name']}")
        
        # Test random selection
        print(f"\nTesting random selection:")
        if customers:
            random_customer = choice(customers)
            print(f"  Random customer: {random_customer['id']} - {random_customer['first_name']}")
        
        if products:
            random_product = choice(products)
            print(f"  Random product: {random_product['id']} - {random_product['name']}")
        
        # Test insert with dynamic data
        if customers and products:
            customer_id = choice(customers)['id']
            product_id = choice(products)['id']
            
            print(f"\nTesting insert with:")
            print(f"  Customer ID: {customer_id}")
            print(f"  Product ID: {product_id}")
            
            # Insert test record
            result = await conn.fetchrow("""
                INSERT INTO inventory.orders (order_date, purchaser, quantity, product_id) 
                VALUES (NOW(), $1, $2, $3) 
                RETURNING id
            """, customer_id, 5, product_id)
            
            print(f"  Inserted order ID: {result['id']}")
            
            # Count total orders
            count = await conn.fetchval("SELECT COUNT(*) FROM inventory.orders")
            print(f"  Total orders now: {count}")
        
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(test_dynamic_data())
