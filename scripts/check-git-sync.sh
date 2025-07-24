#!/bin/bash

# Check GitHub DAG synchronization status

echo "🔍 Checking GitHub DAG Sync Status..."
echo "Repository: https://github.com/nickpeachey/airflow-elyra"
echo ""

# Get scheduler pod
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler,app=airflow -o jsonpath='{.items[0].metadata.name}')

if [ -z "$SCHEDULER_POD" ]; then
    echo "❌ No Airflow scheduler pod found"
    exit 1
fi

echo "📊 Scheduler Pod: $SCHEDULER_POD"
echo ""

# Check git-sync container logs
echo "📋 Git Sync Logs (last 20 lines):"
kubectl logs -n airflow "$SCHEDULER_POD" -c git-sync --tail=20

echo ""
echo "📁 DAG Files in Git Sync Volume:"
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- find /opt/airflow/dags/repo -name "*.py" -type f

echo ""
echo "📋 Airflow DAGs List:"
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- airflow dags list

echo ""
echo "🔄 Git Sync Container Status:"
kubectl describe pod -n airflow "$SCHEDULER_POD" | grep -A 10 "git-sync:"

echo ""
echo "⏰ Last Sync Time (check git-sync logs above for timestamps)"
echo "   Sync should occur every 60 seconds"
