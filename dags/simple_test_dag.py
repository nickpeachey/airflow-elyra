from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    'owner': 'admin',
    'depends_on_past': False,
    'start_date': datetime(2025, 7, 23),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'simple_test_dag',
    default_args=default_args,
    description='A simple test DAG to verify LocalExecutor works',
    schedule=None,  # Manual trigger only
    catchup=False,
    tags=['test'],
)

def test_function():
    print("Hello from LocalExecutor!")
    print("Task executed successfully!")
    return "success"

test_task = PythonOperator(
    task_id='test_task',
    python_callable=test_function,
    dag=dag,
)
