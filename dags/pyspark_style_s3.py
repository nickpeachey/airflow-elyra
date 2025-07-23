"""
Simple PySpark-style DAG with S3 Integration
===========================================

This DAG demonstrates:
1. Creating sample data
2. Processing data with Python (simulating PySpark)
3. Saving results to LocalStack S3 bucket
4. Using S3 for Airflow logging
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator


# Default arguments for all tasks
default_args = {
    'owner': 'data-engineering-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# DAG definition
dag = DAG(
    'pyspark_style_s3_pipeline',
    default_args=default_args,
    description='PySpark-style data processing with S3 storage (no SparkOperator)',
    schedule_interval=timedelta(hours=6),
    catchup=False,
    tags=['pyspark-style', 's3', 'data-processing', 'localstack'],
)


def create_sales_data(**context):
    """Create sample sales data and upload to S3"""
    import json
    import boto3
    import random
    from datetime import datetime as dt, timedelta as td
    
    print("🏭 Creating sample sales data...")
    
    # Create sample sales data (larger dataset)
    data = []
    base_date = dt.strptime(context['ds'], '%Y-%m-%d')
    
    for i in range(5000):  # Larger dataset
        record = {
            'transaction_id': f'TXN_{i:06d}',
            'customer_id': f'CUST_{random.randint(1, 500):04d}',
            'product_id': f'PROD_{random.randint(1, 200):04d}',
            'quantity': random.randint(1, 15),
            'unit_price': round(random.uniform(5.0, 1000.0), 2),
            'transaction_date': context['ds'],
            'transaction_time': (base_date + td(seconds=random.randint(0, 86400))).strftime('%H:%M:%S'),
            'region': random.choice(['North America', 'Europe', 'Asia Pacific', 'Latin America', 'Africa']),
            'product_category': random.choice(['Electronics', 'Clothing', 'Books', 'Home & Garden', 'Sports', 'Automotive', 'Health', 'Beauty']),
            'customer_segment': random.choice(['Premium', 'Standard', 'Economy']),
            'sales_channel': random.choice(['Online', 'Retail Store', 'Mobile App', 'Phone'])
        }
        record['total_amount'] = round(record['quantity'] * record['unit_price'], 2)
        data.append(record)
    
    # Convert to JSON lines format (like what Spark would process)
    json_lines = '\n'.join([json.dumps(record) for record in data])
    
    # Upload to S3
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    # Ensure bucket exists
    try:
        s3_client.create_bucket(Bucket='data-engineering-bucket')
    except:
        pass  # Bucket may already exist
    
    # Upload raw data
    s3_client.put_object(
        Bucket='data-engineering-bucket',
        Key=f'pyspark-input/sales/sales_{context["ds"]}.json',
        Body=json_lines
    )
    
    print(f"✅ Uploaded {len(data)} sales records to S3")
    print(f"📊 Total revenue: ${sum(record['total_amount'] for record in data):,.2f}")
    return {
        'input_file': f's3://data-engineering-bucket/pyspark-input/sales/sales_{context["ds"]}.json',
        'record_count': len(data),
        'total_revenue': sum(record['total_amount'] for record in data)
    }


def process_sales_data(**context):
    """Process sales data using PySpark-style operations"""
    import json
    import boto3
    from collections import defaultdict
    
    print("⚙️ Starting PySpark-style data processing...")
    
    # Initialize S3 client
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    # Read the raw data from S3
    try:
        response = s3_client.get_object(
            Bucket='data-engineering-bucket',
            Key=f'pyspark-input/sales/sales_{context["ds"]}.json'
        )
        raw_data = response['Body'].read().decode('utf-8')
        
        # Parse JSON lines (like Spark DataFrame)
        records = []
        for line in raw_data.strip().split('\n'):
            records.append(json.loads(line))
        
        print(f"📊 Processing {len(records)} sales records...")
        
        # Simulate Spark DataFrame operations
        # 1. Aggregate by region (like df.groupBy("region").agg(...))
        region_aggregates = defaultdict(lambda: {
            'total_revenue': 0,
            'total_quantity': 0,
            'transaction_count': 0,
            'avg_order_value': 0
        })
        
        for record in records:
            region = record['region']
            region_aggregates[region]['total_revenue'] += record['total_amount']
            region_aggregates[region]['total_quantity'] += record['quantity']
            region_aggregates[region]['transaction_count'] += 1
        
        # Calculate averages
        for region, metrics in region_aggregates.items():
            metrics['avg_order_value'] = round(metrics['total_revenue'] / metrics['transaction_count'], 2)
            metrics['total_revenue'] = round(metrics['total_revenue'], 2)
        
        # 2. Aggregate by product category
        category_aggregates = defaultdict(lambda: {
            'total_revenue': 0,
            'total_quantity': 0,
            'transaction_count': 0,
            'avg_order_value': 0
        })
        
        for record in records:
            category = record['product_category']
            category_aggregates[category]['total_revenue'] += record['total_amount']
            category_aggregates[category]['total_quantity'] += record['quantity']
            category_aggregates[category]['transaction_count'] += 1
        
        # Calculate averages
        for category, metrics in category_aggregates.items():
            metrics['avg_order_value'] = round(metrics['total_revenue'] / metrics['transaction_count'], 2)
            metrics['total_revenue'] = round(metrics['total_revenue'], 2)
        
        # 3. Customer segment analysis
        segment_aggregates = defaultdict(lambda: {
            'total_revenue': 0,
            'customer_count': 0,
            'avg_customer_value': 0
        })
        
        customer_segments = defaultdict(lambda: defaultdict(float))
        for record in records:
            customer_segments[record['customer_segment']][record['customer_id']] += record['total_amount']
        
        for segment, customers in customer_segments.items():
            segment_aggregates[segment]['total_revenue'] = round(sum(customers.values()), 2)
            segment_aggregates[segment]['customer_count'] = len(customers)
            segment_aggregates[segment]['avg_customer_value'] = round(
                segment_aggregates[segment]['total_revenue'] / segment_aggregates[segment]['customer_count'], 2
            )
        
        # 4. Sales channel performance
        channel_aggregates = defaultdict(lambda: {
            'total_revenue': 0,
            'transaction_count': 0,
            'avg_transaction_value': 0
        })
        
        for record in records:
            channel = record['sales_channel']
            channel_aggregates[channel]['total_revenue'] += record['total_amount']
            channel_aggregates[channel]['transaction_count'] += 1
        
        # Calculate averages
        for channel, metrics in channel_aggregates.items():
            metrics['avg_transaction_value'] = round(metrics['total_revenue'] / metrics['transaction_count'], 2)
            metrics['total_revenue'] = round(metrics['total_revenue'], 2)
        
        # Save aggregated results to S3 (like Spark DataFrame.write.parquet())
        processed_date = context['ds']
        
        # Save region analysis
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'pyspark-output/region-analysis/region_analysis_{processed_date}.json',
            Body=json.dumps(dict(region_aggregates), indent=2)
        )
        
        # Save category analysis
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'pyspark-output/category-analysis/category_analysis_{processed_date}.json',
            Body=json.dumps(dict(category_aggregates), indent=2)
        )
        
        # Save customer segment analysis
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'pyspark-output/segment-analysis/segment_analysis_{processed_date}.json',
            Body=json.dumps(dict(segment_aggregates), indent=2)
        )
        
        # Save channel analysis
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'pyspark-output/channel-analysis/channel_analysis_{processed_date}.json',
            Body=json.dumps(dict(channel_aggregates), indent=2)
        )
        
        # Create executive summary
        total_revenue = sum(record['total_amount'] for record in records)
        total_transactions = len(records)
        unique_customers = len(set(record['customer_id'] for record in records))
        unique_products = len(set(record['product_id'] for record in records))
        
        summary = {
            'processing_date': processed_date,
            'total_records_processed': total_transactions,
            'total_revenue': round(total_revenue, 2),
            'avg_transaction_value': round(total_revenue / total_transactions, 2),
            'unique_customers': unique_customers,
            'unique_products': unique_products,
            'regions_covered': len(region_aggregates),
            'categories_covered': len(category_aggregates),
            'top_region': max(region_aggregates.items(), key=lambda x: x[1]['total_revenue'])[0],
            'top_category': max(category_aggregates.items(), key=lambda x: x[1]['total_revenue'])[0],
            'top_segment': max(segment_aggregates.items(), key=lambda x: x[1]['total_revenue'])[0],
            'top_channel': max(channel_aggregates.items(), key=lambda x: x[1]['total_revenue'])[0]
        }
        
        # Save executive summary
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'pyspark-output/executive-summary/summary_{processed_date}.json',
            Body=json.dumps(summary, indent=2)
        )
        
        print("✅ PySpark-style processing completed successfully!")
        print(f"📈 Executive Summary:")
        for key, value in summary.items():
            print(f"   • {key}: {value}")
        
        return summary
        
    except Exception as e:
        print(f"❌ Error in PySpark-style processing: {str(e)}")
        raise


def validate_results(**context):
    """Validate that all processing outputs were created in S3"""
    import boto3
    
    print("🔍 Validating PySpark processing results...")
    
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    processed_date = context['ds']
    expected_files = [
        f'pyspark-input/sales/sales_{processed_date}.json',
        f'pyspark-output/region-analysis/region_analysis_{processed_date}.json',
        f'pyspark-output/category-analysis/category_analysis_{processed_date}.json',
        f'pyspark-output/segment-analysis/segment_analysis_{processed_date}.json',
        f'pyspark-output/channel-analysis/channel_analysis_{processed_date}.json',
        f'pyspark-output/executive-summary/summary_{processed_date}.json'
    ]
    
    validation_results = {}
    all_files_exist = True
    
    for file_key in expected_files:
        try:
            response = s3_client.head_object(Bucket='data-engineering-bucket', Key=file_key)
            validation_results[file_key] = {
                'exists': True,
                'size': response['ContentLength'],
                'last_modified': response['LastModified'].isoformat()
            }
            print(f"✅ Found: {file_key} ({response['ContentLength']} bytes)")
        except Exception as e:
            validation_results[file_key] = {'exists': False, 'error': str(e)}
            print(f"❌ Missing: {file_key} - {str(e)}")
            all_files_exist = False
    
    # Count total objects in bucket
    try:
        response = s3_client.list_objects_v2(Bucket='data-engineering-bucket')
        if 'Contents' in response:
            total_objects = len(response['Contents'])
            total_size = sum(obj['Size'] for obj in response['Contents'])
            print(f"📊 Total objects in bucket: {total_objects} ({total_size:,} bytes)")
            
            # Show recent files
            print("\n📄 Recent files in bucket:")
            for obj in sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)[:10]:
                print(f"   • {obj['Key']} ({obj['Size']} bytes)")
        else:
            print("📊 No objects found in bucket")
    except Exception as e:
        print(f"⚠️ Could not list bucket objects: {str(e)}")
    
    if all_files_exist:
        print("\n🎉 All validation checks passed!")
    else:
        print("\n⚠️ Some files are missing - check processing logs")
    
    return validation_results


# Define tasks
create_data_task = PythonOperator(
    task_id='create_sales_data',
    python_callable=create_sales_data,
    dag=dag,
)

process_data_task = PythonOperator(
    task_id='process_sales_data_pyspark_style',
    python_callable=process_sales_data,
    dag=dag,
)

validate_task = PythonOperator(
    task_id='validate_processing_results',
    python_callable=validate_results,
    dag=dag,
)

# Set task dependencies
create_data_task >> process_data_task >> validate_task
