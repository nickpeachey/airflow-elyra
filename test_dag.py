from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator

def test_function():
    print("Hello from test DAG!")
    return "success"

dag = DAG(
    'test_dag',
    default_args={
        'owner': 'admin',
        'depends_on_past': False,
        'start_date': datetime(2024, 1, 1),
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 1,
        'retry_delay': timedelta(minutes=5),
    },
    description='Simple test DAG',
    schedule='@once',
    catchup=False,
    tags=['test'],
)

test_task = PythonOperator(
    task_id='test_task',
    python_callable=test_function,
    dag=dag,
)
