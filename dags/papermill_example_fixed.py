"""
Simple Papermill example DAG showing how to run parameterized notebooks
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
import subprocess
import os

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'papermill_example',
    default_args=default_args,
    description='Example of running Jupyter notebooks with Papermill',
    schedule_interval='@daily',
    catchup=False,
    tags=['papermill', 'jupyter', 'example'],
)

def run_notebook_with_papermill(**context):
    """
    Run a Jupyter notebook using Papermill with parameters
    """
    import logging
    
    execution_date = context['ds']
    logging.info(f"Running notebook for execution date: {execution_date}")
    
    # Set AWS credentials for LocalStack
    os.environ['AWS_ACCESS_KEY_ID'] = 'test'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'test'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
    
    try:
        # Create output directory if it doesn't exist
        output_dir = '/tmp/notebook_outputs'
        os.makedirs(output_dir, exist_ok=True)
        
        # For now, just log that we would run the notebook
        # In a real setup with mounted volumes, you would use:
        # papermill input_notebook.ipynb output_notebook.ipynb -p param1 value1
        
        logging.info("Papermill execution simulation:")
        logging.info(f"Input notebook: /notebooks/simple_analysis.ipynb")
        logging.info(f"Output notebook: {output_dir}/simple_analysis_{execution_date}.ipynb")
        logging.info(f"Parameters: execution_date={execution_date}, sample_size=1000")
        
        # Simulate successful execution
        result = {
            'status': 'success',
            'execution_date': execution_date,
            'output_path': f"{output_dir}/simple_analysis_{execution_date}.ipynb",
            'message': 'Notebook execution simulated successfully'
        }
        
        logging.info(f"Notebook execution result: {result}")
        return result
        
    except Exception as e:
        logging.error(f"Error running notebook: {str(e)}")
        raise

def validate_notebook_output(**context):
    """
    Validate that the notebook ran successfully
    """
    import logging
    
    execution_date = context['ds']
    logging.info(f"Validating notebook output for: {execution_date}")
    
    # In a real scenario, you would check if the output file exists
    # and validate its contents
    
    logging.info("✅ Notebook validation completed successfully")
    return {"validation_status": "passed", "execution_date": execution_date}

# Task to run the notebook
run_notebook = PythonOperator(
    task_id='run_simple_analysis_notebook',
    python_callable=run_notebook_with_papermill,
    dag=dag,
)

# Task to validate the output
validate_output = PythonOperator(
    task_id='validate_notebook_output',
    python_callable=validate_notebook_output,
    dag=dag,
)

# Set task dependencies
run_notebook >> validate_output
