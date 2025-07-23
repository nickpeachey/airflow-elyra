#!/bin/bash

# Deploy DAGs and Notebooks Script
# This script copies DAGs to Airflow pods and notebooks to Jupyter pods

set -e

echo "📋 Deploying DAGs and Notebooks..."

# Wait for Airflow pods to be ready
echo "⏳ Waiting for Airflow pods to be ready..."
kubectl wait --for=condition=ready pod -l component=scheduler -n airflow --timeout=300s
kubectl wait --for=condition=ready pod -l component=webserver -n airflow --timeout=300s

# Wait for Jupyter pod to be ready
echo "⏳ Waiting for Jupyter pod to be ready..."
kubectl wait --for=condition=ready pod -l app=jupyter-lab -n jupyter --timeout=300s

# Get pod names
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')
WEBSERVER_POD=$(kubectl get pods -n airflow -l component=webserver -o jsonpath='{.items[0].metadata.name}')
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter-lab -o jsonpath='{.items[0].metadata.name}')

echo "📋 Found pods:"
echo "  Scheduler: $SCHEDULER_POD"
echo "  Webserver: $WEBSERVER_POD"
echo "  Jupyter: $JUPYTER_POD"

# Copy DAGs to Airflow scheduler
echo "📄 Copying DAGs to Airflow scheduler..."
for dag_file in dags/*_fixed.py dags/simple_test_dag.py dags/spark_operator_s3.py; do
    if [ -f "$dag_file" ]; then
        echo "  Copying $(basename $dag_file)..."
        kubectl cp "$dag_file" airflow/"$SCHEDULER_POD":/opt/airflow/dags/$(basename $dag_file) -c scheduler
    fi
done

# Copy SparkApplication template
if [ -f "dags/spark_application.yaml" ]; then
    echo "  Copying spark_application.yaml..."
    kubectl cp "dags/spark_application.yaml" airflow/"$SCHEDULER_POD":/opt/airflow/dags/spark_application.yaml -c scheduler
fi

# Copy DAGs to Airflow webserver (needed for some DAG operations)
echo "📄 Copying DAGs to Airflow webserver..."
for dag_file in dags/*_fixed.py dags/simple_test_dag.py dags/spark_operator_s3.py; do
    if [ -f "$dag_file" ]; then
        echo "  Copying $(basename $dag_file)..."
        kubectl cp "$dag_file" airflow/"$WEBSERVER_POD":/opt/airflow/dags/$(basename $dag_file)
    fi
done

# Copy notebooks to Jupyter
echo "📓 Copying notebooks to Jupyter..."
for notebook_file in notebooks/*_fixed.ipynb; do
    if [ -f "$notebook_file" ]; then
        echo "  Copying $(basename $notebook_file)..."
        kubectl cp "$notebook_file" jupyter/"$JUPYTER_POD":/home/jovyan/work/$(basename $notebook_file)
    fi
done

# Refresh DAGs in Airflow
echo "🔄 Refreshing DAGs in Airflow..."
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- airflow dags reserialize

# List DAGs to verify
echo "📋 Verifying DAGs are loaded..."
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- airflow dags list

echo "✅ DAGs and notebooks deployed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "  • Airflow UI: http://localhost:8080 (admin/admin)"
echo "  • Jupyter Lab: http://localhost:8888"
echo ""
echo "📋 Available DAGs:"
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- airflow dags list | tail -n +3 | head -10
