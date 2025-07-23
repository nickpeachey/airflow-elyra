"""
Simple PySpark DAG with S3 Integration
=====================================

This DAG demonstrates basic data processing and S3 storage
without complex dependencies.
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
    'simple_pyspark_s3_pipeline',
    default_args=default_args,
    description='Simple PySpark data processing with S3 storage',
    schedule_interval=timedelta(hours=6),
    catchup=False,
    tags=['pyspark', 's3', 'data-processing', 'simple'],
)


def create_sample_data(**context):
    """Create sample sales data and upload to S3"""
    import json
    import boto3
    from io import StringIO
    
    # Create sample sales data
    data = []
    for i in range(100):
        record = {
            'transaction_id': f'TXN_{i:05d}',
            'customer_id': f'CUST_{(i % 50):03d}',
            'amount': 10.0 + (i * 5.5),
            'date': context['ds'],
            'region': ['North', 'South', 'East', 'West'][i % 4]
        }
        data.append(record)
    
    # Convert to JSON lines format
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
        Key=f'raw-data/simple-sales/sales_{context["ds"]}.json',
        Body=json_lines
    )
    
    print(f"✅ Uploaded {len(data)} sales records to S3")
    return f"s3://data-engineering-bucket/raw-data/simple-sales/sales_{context['ds']}.json"


def process_simple_data(**context):
    """Process sales data using simple Python and save results to S3"""
    import json
    import boto3
    from collections import defaultdict
    
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
            Key=f'raw-data/simple-sales/sales_{context["ds"]}.json'
        )
        raw_data = response['Body'].read().decode('utf-8')
        
        # Parse JSON lines
        records = []
        for line in raw_data.strip().split('\n'):
            records.append(json.loads(line))
        
        print(f"📊 Processing {len(records)} sales records")
        
        # Perform simple aggregations
        region_totals = defaultdict(float)
        customer_totals = defaultdict(float)
        total_amount = 0
        
        for record in records:
            region_totals[record['region']] += record['amount']
            customer_totals[record['customer_id']] += record['amount']
            total_amount += record['amount']
        
        # Create summary report
        summary = {
            'processing_date': context['ds'],
            'total_records_processed': len(records),
            'total_revenue': round(total_amount, 2),
            'avg_transaction_value': round(total_amount / len(records), 2),
            'unique_customers': len(customer_totals),
            'region_breakdown': dict(region_totals),
            'top_customers': dict(sorted(customer_totals.items(), key=lambda x: x[1], reverse=True)[:5])
        }
        
        # Save summary to S3
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'processed-data/simple-summary/summary_{context["ds"]}.json',
            Body=json.dumps(summary, indent=2)
        )
        
        print(f"✅ Processed and saved sales data summary to S3")
        print(f"📈 Summary: {summary}")
        
        return summary
        
    except Exception as e:
        print(f"❌ Error processing sales data: {str(e)}")
        raise


def validate_simple_outputs(**context):
    """Validate that all expected files were created in S3"""
    import boto3
    
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    processed_date = context['ds']
    expected_files = [
        f'raw-data/simple-sales/sales_{processed_date}.json',
        f'processed-data/simple-summary/summary_{processed_date}.json'
    ]
    
    validation_results = {}
    
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
    
    # List all objects in bucket
    try:
        response = s3_client.list_objects_v2(Bucket='data-engineering-bucket')
        if 'Contents' in response:
            print(f"📊 Total objects in bucket: {len(response['Contents'])}")
            for obj in response['Contents']:
                print(f"  📄 {obj['Key']} ({obj['Size']} bytes)")
        else:
            print("📊 No objects found in bucket")
    except Exception as e:
        print(f"⚠️ Could not list bucket objects: {str(e)}")
    
    return validation_results


# Define tasks
create_data_task = PythonOperator(
    task_id='create_simple_sales_data',
    python_callable=create_sample_data,
    dag=dag,
)

process_data_task = PythonOperator(
    task_id='process_simple_sales_data',
    python_callable=process_simple_data,
    dag=dag,
)

validate_task = PythonOperator(
    task_id='validate_simple_outputs',
    python_callable=validate_simple_outputs,
    dag=dag,
)

# Set task dependencies
create_data_task >> process_data_task >> validate_task
