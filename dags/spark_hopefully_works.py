"""
PySpark DAG with SparkKubernetesOperator and S3 Integration
=========================================================

This DAG demonstrates:
1. Using SparkKubernetesOperator for PySpark job execution
2. Processing data with Spark on Kubernetes
3. Saving results to LocalStack S3 bucket
4. Proper Kubernetes-native Spark execution
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

# Try to import SparkKubernetesOperator
try:
    from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
    SPARK_OPERATOR_AVAILABLE = True
except ImportError:
    SPARK_OPERATOR_AVAILABLE = False
    print("SparkKubernetesOperator not available - using alternative approach")


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
    'spark_operator_s3_fixed_pipeline_hopefull',
    default_args=default_args,
    description='PySpark data processing using SparkKubernetesOperator with S3 storage',
    schedule_interval=timedelta(hours=6),
    catchup=False,
    tags=['spark', 'spark-operator', 's3', 'data-processing', 'fixed'],
)


def create_sample_data(**context):
    """Create sample sales data and upload to S3"""
    import json
    import boto3
    
    # Create sample sales data
    data = []
    for i in range(1000):
        record = {
            'transaction_id': f'TXN_{i:05d}',
            'customer_id': f'CUST_{(i % 100):03d}',
            'amount': 10.0 + (i * 2.5),
            'date': context['ds'],
            'region': ['North', 'South', 'East', 'West'][i % 4],
            'category': ['Electronics', 'Clothing', 'Food', 'Books'][i % 4]
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
        Key=f'input/sales/sales_{context["ds"]}.json',
        Body=json_lines
    )
    
    print(f"✅ Uploaded {len(data)} sales records to S3")
    return f"s3a://data-engineering-bucket/input/sales/sales_{context['ds']}.json"


def verify_results(**context):
    """Verify that Spark processing completed successfully"""
    import boto3
    
    # Initialize S3 client
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    # Check for output files
    expected_outputs = [
        f'output/regional-summary/{context["ds"]}/part-00000',
        f'output/category-summary/{context["ds"]}/part-00000',
        f'output/customer-summary/{context["ds"]}/part-00000'
    ]
    
    results = {}
    for output_path in expected_outputs:
        try:
            response = s3_client.list_objects_v2(
                Bucket='data-engineering-bucket',
                Prefix=output_path
            )
            if 'Contents' in response:
                results[output_path] = "✅ Found"
            else:
                results[output_path] = "❌ Missing"
        except Exception as e:
            results[output_path] = f"❌ Error: {e}"
    
    print("📊 Processing Results:")
    for path, status in results.items():
        print(f"   {path}: {status}")
    
    return results


# Task 1: Create sample data
create_data_task = PythonOperator(
    task_id='create_sample_data',
    python_callable=create_sample_data,
    dag=dag,
)

# Task 2: Spark data processing
if SPARK_OPERATOR_AVAILABLE:
    # Use proper SparkKubernetesOperator
    spark_task = SparkKubernetesOperator(
        task_id='spark_data_processing_spark',
        namespace='default',
        application_file='spark_application.yaml',  # Reference to YAML file
        dag=dag,
    )
else:
    # Alternative approach using Python processing
    def process_data_python(**context):
        """Process data using Python (fallback when SparkOperator not available)"""
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
        
        # Read the raw data
        try:
            response = s3_client.get_object(
                Bucket='data-engineering-bucket',
                Key=f'input/sales/sales_{context["ds"]}.json'
            )
            raw_data = response['Body'].read().decode('utf-8')
            
            # Parse JSON lines
            records = [json.loads(line) for line in raw_data.strip().split('\n')]
            
            # Process data
            regional_summary = defaultdict(lambda: {'total_amount': 0, 'count': 0})
            category_summary = defaultdict(lambda: {'total_amount': 0, 'count': 0})
            customer_summary = defaultdict(lambda: {'total_amount': 0, 'count': 0})
            
            for record in records:
                amount = record['amount']
                
                # Regional aggregation
                regional_summary[record['region']]['total_amount'] += amount
                regional_summary[record['region']]['count'] += 1
                
                # Category aggregation
                category_summary[record['category']]['total_amount'] += amount
                category_summary[record['category']]['count'] += 1
                
                # Customer aggregation
                customer_summary[record['customer_id']]['total_amount'] += amount
                customer_summary[record['customer_id']]['count'] += 1
            
            # Save results back to S3
            for summary_name, summary_data in [
                ('regional-summary', regional_summary),
                ('category-summary', category_summary),
                ('customer-summary', customer_summary)
            ]:
                # Convert to JSON lines
                json_output = '\n'.join([
                    json.dumps({
                        'key': key,
                        'total_amount': data['total_amount'],
                        'count': data['count'],
                        'average_amount': data['total_amount'] / data['count']
                    })
                    for key, data in summary_data.items()
                ])
                
                # Upload to S3
                s3_client.put_object(
                    Bucket='data-engineering-bucket',
                    Key=f'output/{summary_name}/{context["ds"]}/part-00000',
                    Body=json_output
                )
            
            print(f"✅ Processed {len(records)} records")
            print(f"   Regional summaries: {len(regional_summary)}")
            print(f"   Category summaries: {len(category_summary)}")
            print(f"   Customer summaries: {len(customer_summary)}")
            
        except Exception as e:
            print(f"❌ Error processing data: {e}")
            raise
    
    spark_task = PythonOperator(
        task_id='spark_data_processing',
        python_callable=process_data_python,
        dag=dag,
    )

# Task 3: Verify results
verify_task = PythonOperator(
    task_id='verify_results',
    python_callable=verify_results,
    dag=dag,
)

# Set task dependencies
create_data_task >> spark_task >> verify_task
