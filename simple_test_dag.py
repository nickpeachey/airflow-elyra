from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator

def simple_test():
    """Simple test function that doesn't require external DAG files"""
    print("=" * 50)
    print("🎉 SUCCESS: KubernetesExecutor is working!")
    print("📅 Current time:", datetime.now())
    print("🐳 Running in Kubernetes pod")
    print("=" * 50)
    return "test_completed"

dag = DAG(
    'simple_test_dag',
    default_args={
        'owner': 'admin',
        'depends_on_past': False,
        'start_date': datetime(2024, 1, 1),
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 0,  # No retries for testing
    },
    description='Simple test DAG for KubernetesExecutor',
    schedule=None,  # Manual trigger only
    catchup=False,
    tags=['test', 'kubernetes'],
)

simple_task = PythonOperator(
    task_id='simple_test_task',
    python_callable=simple_test,
    dag=dag,
)
