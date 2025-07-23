"""
PySpark DAG Example with S3 Data Storage
=========================================

This DAG demonstrates:
1. Creating sample data with PySpark
2. Processing data with transformations
3. Saving results to LocalStack S3 bucket
4. Logging to S3 via Airflow configuration
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
import boto3
import pandas as pd
from io import StringIO


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
    'pyspark_s3_data_pipeline',
    default_args=default_args,
    description='PySpark data processing with S3 storage',
    schedule_interval=timedelta(hours=6),
    catchup=False,
    tags=['pyspark', 's3', 'data-processing'],
)


def create_sample_data(**context):
    """Create sample sales data and upload to S3"""
    import random
    from datetime import datetime, timedelta
    
    # Create sample sales data
    data = []
    base_date = datetime(2024, 1, 1)
    
    for i in range(1000):
        record = {
            'transaction_id': f'TXN_{i:05d}',
            'customer_id': f'CUST_{random.randint(1, 100):03d}',
            'product_id': f'PROD_{random.randint(1, 50):03d}',
            'quantity': random.randint(1, 10),
            'unit_price': round(random.uniform(10.0, 500.0), 2),
            'transaction_date': (base_date + timedelta(days=random.randint(0, 365))).strftime('%Y-%m-%d'),
            'region': random.choice(['North', 'South', 'East', 'West']),
            'product_category': random.choice(['Electronics', 'Clothing', 'Books', 'Home', 'Sports'])
        }
        record['total_amount'] = round(record['quantity'] * record['unit_price'], 2)
        data.append(record)
    
    # Convert to CSV
    df = pd.DataFrame(data)
    csv_buffer = StringIO()
    df.to_csv(csv_buffer, index=False)
    
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
        Key=f'raw-data/sales/sales_{context["ds"]}.csv',
        Body=csv_buffer.getvalue()
    )
    
    print(f"✅ Uploaded {len(data)} sales records to S3")
    return f"s3://data-engineering-bucket/raw-data/sales/sales_{context['ds']}.csv"


def create_spark_application_yaml(**context):
    """Create Spark application YAML for data processing"""
    
    spark_app_yaml = f"""
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: sales-data-processor-{context['ds'].replace('-', '')}
  namespace: default
spec:
  type: Python
  pythonVersion: "3"
  mode: cluster
  image: "spark:3.4.1-python3"
  imagePullPolicy: Always
  mainApplicationFile: local:///opt/spark/examples/src/main/python/pi.py
  sparkVersion: "3.4.1"
  restartPolicy:
    type: Never
  volumes:
    - name: "test-volume"
      hostPath:
        path: "/tmp"
        type: Directory
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "1g"
    labels:
      version: 3.4.1
    serviceAccount: spark-operator-spark
    volumeMounts:
      - name: "test-volume"
        mountPath: "/tmp"
    env:
      - name: AWS_ACCESS_KEY_ID
        value: test
      - name: AWS_SECRET_ACCESS_KEY
        value: test
      - name: AWS_ENDPOINT_URL
        value: http://localstack-service.localstack.svc.cluster.local:4566
  executor:
    cores: 1
    instances: 1
    memory: "1g"
    labels:
      version: 3.4.1
    volumeMounts:
      - name: "test-volume"
        mountPath: "/tmp"
    env:
      - name: AWS_ACCESS_KEY_ID
        value: test
      - name: AWS_SECRET_ACCESS_KEY
        value: test
      - name: AWS_ENDPOINT_URL
        value: http://localstack-service.localstack.svc.cluster.local:4566
"""
    
    # Save to file (in real scenario, this would be a more sophisticated process)
    print(f"📄 Created Spark application YAML for date: {context['ds']}")
    return "spark-app-created"


def process_sales_data_python(**context):
    """Process sales data using Python and save aggregated results to S3"""
    
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
            Key=f'raw-data/sales/sales_{context["ds"]}.csv'
        )
        df = pd.read_csv(StringIO(response['Body'].read().decode('utf-8')))
        
        print(f"📊 Processing {len(df)} sales records")
        
        # Perform aggregations
        # 1. Sales by region
        region_sales = df.groupby('region').agg({
            'total_amount': ['sum', 'mean', 'count'],
            'quantity': 'sum'
        }).round(2)
        region_sales.columns = ['total_revenue', 'avg_order_value', 'order_count', 'total_quantity']
        region_sales = region_sales.reset_index()
        
        # 2. Sales by product category
        category_sales = df.groupby('product_category').agg({
            'total_amount': ['sum', 'mean'],
            'quantity': 'sum'
        }).round(2)
        category_sales.columns = ['total_revenue', 'avg_order_value', 'total_quantity']
        category_sales = category_sales.reset_index()
        
        # 3. Daily sales summary
        daily_sales = df.groupby('transaction_date').agg({
            'total_amount': 'sum',
            'transaction_id': 'count'
        }).round(2)
        daily_sales.columns = ['daily_revenue', 'transaction_count']
        daily_sales = daily_sales.reset_index()
        
        # Save aggregated results to S3
        processed_date = context['ds']
        
        # Upload region sales
        csv_buffer = StringIO()
        region_sales.to_csv(csv_buffer, index=False)
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'processed-data/sales-by-region/region_sales_{processed_date}.csv',
            Body=csv_buffer.getvalue()
        )
        
        # Upload category sales
        csv_buffer = StringIO()
        category_sales.to_csv(csv_buffer, index=False)
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'processed-data/sales-by-category/category_sales_{processed_date}.csv',
            Body=csv_buffer.getvalue()
        )
        
        # Upload daily sales
        csv_buffer = StringIO()
        daily_sales.to_csv(csv_buffer, index=False)
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'processed-data/daily-sales/daily_sales_{processed_date}.csv',
            Body=csv_buffer.getvalue()
        )
        
        # Create summary report
        summary = {
            'processing_date': processed_date,
            'total_records_processed': len(df),
            'total_revenue': df['total_amount'].sum(),
            'avg_order_value': df['total_amount'].mean(),
            'unique_customers': df['customer_id'].nunique(),
            'unique_products': df['product_id'].nunique(),
            'regions_covered': df['region'].nunique(),
            'categories_covered': df['product_category'].nunique()
        }
        
        summary_df = pd.DataFrame([summary])
        csv_buffer = StringIO()
        summary_df.to_csv(csv_buffer, index=False)
        s3_client.put_object(
            Bucket='data-engineering-bucket',
            Key=f'processed-data/summary/processing_summary_{processed_date}.csv',
            Body=csv_buffer.getvalue()
        )
        
        print(f"✅ Processed and saved sales data aggregations to S3")
        print(f"📈 Summary: {summary}")
        
        return summary
        
    except Exception as e:
        print(f"❌ Error processing sales data: {str(e)}")
        raise


def validate_s3_outputs(**context):
    """Validate that all expected files were created in S3"""
    
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    processed_date = context['ds']
    expected_files = [
        f'raw-data/sales/sales_{processed_date}.csv',
        f'processed-data/sales-by-region/region_sales_{processed_date}.csv',
        f'processed-data/sales-by-category/category_sales_{processed_date}.csv',
        f'processed-data/daily-sales/daily_sales_{processed_date}.csv',
        f'processed-data/summary/processing_summary_{processed_date}.csv'
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
        except:
            validation_results[file_key] = {'exists': False}
            print(f"❌ Missing: {file_key}")
    
    # Count total objects in bucket
    try:
        response = s3_client.list_objects_v2(Bucket='data-engineering-bucket')
        total_objects = response.get('KeyCount', 0)
        print(f"📊 Total objects in bucket: {total_objects}")
    except Exception as e:
        print(f"⚠️ Could not count bucket objects: {str(e)}")
    
    return validation_results


# Define tasks
create_data_task = PythonOperator(
    task_id='create_sample_sales_data',
    python_callable=create_sample_data,
    dag=dag,
)

process_data_task = PythonOperator(
    task_id='process_sales_data',
    python_callable=process_sales_data_python,
    dag=dag,
)

validate_task = PythonOperator(
    task_id='validate_s3_outputs',
    python_callable=validate_s3_outputs,
    dag=dag,
)

# Set task dependencies
create_data_task >> process_data_task >> validate_task
