"""
PySpark DAG with SparkOperator and S3 Integration
===============================================

This DAG demonstrates:
1. Using SparkOperator for PySpark job execution
2. Processing data with Spark on Kubernetes
3. Saving results to LocalStack S3 bucket
4. Logging to S3 via Airflow configuration
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
import tempfile


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
    'spark_operator_s3_pipeline',
    default_args=default_args,
    description='PySpark data processing using SparkOperator with S3 storage',
    schedule_interval=timedelta(hours=6),
    catchup=False,
    tags=['spark', 'spark-operator', 's3', 'data-processing'],
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
            'product_id': f'PROD_{(i % 50):03d}',
            'quantity': (i % 10) + 1,
            'unit_price': 10.0 + (i * 0.5) % 100,
            'transaction_date': context['ds'],
            'region': ['North', 'South', 'East', 'West'][i % 4],
            'product_category': ['Electronics', 'Clothing', 'Books', 'Home', 'Sports'][i % 5]
        }
        record['total_amount'] = round(record['quantity'] * record['unit_price'], 2)
        data.append(record)
    
    # Convert to JSON lines format for Spark
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
        Key=f'spark-input/sales/sales_{context["ds"]}.json',
        Body=json_lines
    )
    
    print(f"✅ Uploaded {len(data)} sales records to S3")
    return f"s3://data-engineering-bucket/spark-input/sales/sales_{context['ds']}.json"


def validate_spark_outputs(**context):
    """Validate that Spark job outputs were created in S3"""
    import boto3
    
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    
    processed_date = context['ds']
    expected_paths = [
        f'spark-input/sales/sales_{processed_date}.json',
        f'spark-output/aggregations/region_summary/',
        f'spark-output/aggregations/category_summary/',
        f'spark-output/metrics/daily_summary/'
    ]
    
    validation_results = {}
    
    for path in expected_paths:
        try:
            if path.endswith('/'):
                # Directory check
                response = s3_client.list_objects_v2(Bucket='data-engineering-bucket', Prefix=path)
                if 'Contents' in response:
                    file_count = len(response['Contents'])
                    total_size = sum(obj['Size'] for obj in response['Contents'])
                    validation_results[path] = {
                        'exists': True,
                        'files': file_count,
                        'total_size': total_size
                    }
                    print(f"✅ Found: {path} ({file_count} files, {total_size} bytes)")
                else:
                    validation_results[path] = {'exists': False}
                    print(f"❌ Missing: {path}")
            else:
                # File check
                response = s3_client.head_object(Bucket='data-engineering-bucket', Key=path)
                validation_results[path] = {
                    'exists': True,
                    'size': response['ContentLength'],
                    'last_modified': response['LastModified'].isoformat()
                }
                print(f"✅ Found: {path} ({response['ContentLength']} bytes)")
        except Exception as e:
            validation_results[path] = {'exists': False, 'error': str(e)}
            print(f"❌ Missing: {path} - {str(e)}")
    
    # List all objects in bucket for overview
    try:
        response = s3_client.list_objects_v2(Bucket='data-engineering-bucket')
        if 'Contents' in response:
            print(f"📊 Total objects in bucket: {len(response['Contents'])}")
        else:
            print("📊 No objects found in bucket")
    except Exception as e:
        print(f"⚠️ Could not list bucket objects: {str(e)}")
    
    return validation_results


# Create sample data task
create_data_task = PythonOperator(
    task_id='create_spark_input_data',
    python_callable=create_sample_data,
    dag=dag,
)

# Fallback function for when SparkKubernetesOperator is not available
def submit_spark_application(**context):
    """Fallback: Submit SparkApplication using kubectl"""
    import subprocess
    import tempfile
    import os
    
    spark_app_yaml = f"""
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: sales-data-processor-{context['ds_nodash']}
  namespace: default
spec:
  type: Python
  pythonVersion: "3"
  mode: cluster
  image: "bitnami/spark:3.4.1"
  imagePullPolicy: Always
  mainApplicationFile: local:///opt/spark/work-dir/spark_s3_job.py
  sparkVersion: "3.4.1"
  restartPolicy:
    type: Never
  deps:
    jars:
      - "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar"
      - "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar"
  volumes:
    - name: spark-job-volume
      configMap:
        name: spark-job-code
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "1g"
    labels:
      version: 3.4.1
    serviceAccount: spark-operator-spark
    env:
      - name: AWS_ACCESS_KEY_ID
        value: test
      - name: AWS_SECRET_ACCESS_KEY
        value: test
      - name: AWS_ENDPOINT_URL
        value: http://localstack-service.localstack.svc.cluster.local:4566
      - name: AWS_DEFAULT_REGION
        value: us-east-1
    volumeMounts:
      - name: spark-job-volume
        mountPath: /opt/spark/work-dir
  executor:
    cores: 1
    instances: 2
    memory: "1g"
    labels:
      version: 3.4.1
    env:
      - name: AWS_ACCESS_KEY_ID
        value: test
      - name: AWS_SECRET_ACCESS_KEY
        value: test
      - name: AWS_ENDPOINT_URL
        value: http://localstack-service.localstack.svc.cluster.local:4566
      - name: AWS_DEFAULT_REGION
        value: us-east-1
    volumeMounts:
      - name: spark-job-volume
        mountPath: /opt/spark/work-dir
  sparkConf:
    "spark.hadoop.fs.s3a.endpoint": "http://localstack-service.localstack.svc.cluster.local:4566"
    "spark.hadoop.fs.s3a.access.key": "test"
    "spark.hadoop.fs.s3a.secret.key": "test"
    "spark.hadoop.fs.s3a.path.style.access": "true"
    "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem"
    "spark.hadoop.fs.s3a.connection.ssl.enabled": "false"
    "spark.sql.adaptive.enabled": "true"
    "spark.sql.adaptive.coalescePartitions.enabled": "true"
"""
    
    # Write YAML to temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        f.write(spark_app_yaml)
        yaml_file = f.name
    
    try:
        # Apply the SparkApplication
        result = subprocess.run(
            ['kubectl', 'apply', '-f', yaml_file],
            capture_output=True,
            text=True,
            check=True
        )
        print(f"✅ SparkApplication created: {result.stdout}")
        return f"sales-data-processor-{context['ds_nodash']}"
        
    finally:
        # Clean up temp file
        os.unlink(yaml_file)

# Spark job for data processing using SparkKubernetesOperator
spark_processing_task = SparkKubernetesOperator(
    task_id='spark_data_processing',
    namespace='default',
    application_file='spark_application.yaml',
    kubernetes_conn_id='kubernetes_default',
    do_xcom_push=False,  # Disable XCom to avoid sidecar container issues
    dag=dag,
)

# Validate outputs task
validate_task = PythonOperator(
    task_id='validate_spark_outputs',
    python_callable=validate_spark_outputs,
    dag=dag,
)

# Set task dependencies - SparkKubernetesOperator waits for completion internally
create_data_task >> spark_processing_task >> validate_task
