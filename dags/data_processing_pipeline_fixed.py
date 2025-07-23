"""
Simplified Data Processing Pipeline DAG
Uses PythonOperator instead of Kubernetes operators
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
import logging

# Default arguments
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
    'data_processing_pipeline',
    default_args=default_args,
    description='Data processing pipeline with ingestion, processing, and validation',
    schedule_interval='@daily',
    catchup=False,
    tags=['data-pipeline', 'etl', 'papermill'],
)

def setup_environment(**context):
    """Setup environment and S3 credentials"""
    import os
    
    # Configure AWS credentials for LocalStack
    os.environ['AWS_ACCESS_KEY_ID'] = 'test'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'test'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
    
    execution_date = context['ds']
    logging.info(f"Setting up environment for: {execution_date}")
    
    return {"status": "environment_ready", "execution_date": execution_date}

def run_data_ingestion(**context):
    """Simulate data ingestion notebook execution"""
    execution_date = context['ds']
    logging.info(f"Running data ingestion for: {execution_date}")
    
    # In a real setup, this would use papermill to execute the notebook
    # papermill data_ingestion.ipynb output.ipynb -p execution_date {execution_date}
    
    logging.info("📥 Data ingestion simulation:")
    logging.info(f"  - Generated sample transaction data")
    logging.info(f"  - Uploaded to S3: s3://data-lake/raw-data/{execution_date}/")
    logging.info(f"  - Created metadata file")
    
    return {
        "status": "completed",
        "records_processed": 10000,
        "s3_path": f"s3://data-lake/raw-data/{execution_date}/"
    }

def run_spark_processing(**context):
    """Simulate Spark data processing"""
    execution_date = context['ds']
    logging.info(f"Running Spark processing for: {execution_date}")
    
    # In a real setup, this would submit a Spark job to the cluster
    logging.info("⚡ Spark processing simulation:")
    logging.info(f"  - Processing data from: s3://data-lake/raw-data/{execution_date}/")
    logging.info(f"  - Applying transformations and aggregations")
    logging.info(f"  - Output to: s3://data-lake/processed-data/{execution_date}/")
    
    return {
        "status": "completed", 
        "input_records": 10000,
        "output_records": 8500,
        "processing_time": "2.5 minutes"
    }

def run_data_validation(**context):
    """Simulate data validation notebook execution"""
    execution_date = context['ds']
    logging.info(f"Running data validation for: {execution_date}")
    
    # In a real setup, this would use papermill to execute validation
    logging.info("✅ Data validation simulation:")
    logging.info(f"  - Checking data quality for: {execution_date}")
    logging.info(f"  - Validating schema compliance")
    logging.info(f"  - Generating quality report")
    
    return {
        "status": "passed",
        "validation_checks": {
            "schema_compliance": "passed",
            "data_quality": "passed",
            "completeness": "passed"
        }
    }

def generate_report(**context):
    """Generate processing summary report"""
    execution_date = context['ds']
    logging.info(f"Generating report for: {execution_date}")
    
    # Pull results from previous tasks
    task_instance = context['task_instance']
    
    logging.info("📊 Pipeline Execution Summary:")
    logging.info(f"  - Execution Date: {execution_date}")
    logging.info(f"  - Data Ingestion: ✅ Completed")
    logging.info(f"  - Spark Processing: ✅ Completed")
    logging.info(f"  - Data Validation: ✅ Passed")
    logging.info(f"  - Pipeline Status: SUCCESS")
    
    return {"pipeline_status": "SUCCESS", "execution_date": execution_date}

# Define tasks
setup_task = PythonOperator(
    task_id='setup_environment',
    python_callable=setup_environment,
    dag=dag,
)

ingest_task = PythonOperator(
    task_id='data_ingestion',
    python_callable=run_data_ingestion,
    dag=dag,
)

process_task = PythonOperator(
    task_id='spark_processing',
    python_callable=run_spark_processing,
    dag=dag,
)

validate_task = PythonOperator(
    task_id='data_validation',
    python_callable=run_data_validation,
    dag=dag,
)

report_task = PythonOperator(
    task_id='generate_report',
    python_callable=generate_report,
    dag=dag,
)

# Define task dependencies
setup_task >> ingest_task >> process_task >> validate_task >> report_task
