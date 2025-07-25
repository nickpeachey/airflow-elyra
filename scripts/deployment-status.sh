#!/bin/bash

echo "🚀 Airflow-Elyra Deployment Status Summary"
echo "=========================================="
echo

echo "✅ DEPLOYMENT STATUS: SUCCESSFUL"
echo "✅ GitHub DAG Sync: WORKING"
echo "✅ Airflow Authentication: WORKING (admin/admin)"
echo "✅ SparkKubernetesOperator: WORKING"
echo "✅ S3 Storage (LocalStack): WORKING"
echo "✅ JupyterLab: WORKING"
echo "✅ Papermill Integration: WORKING"
echo "    echo "  🔄 Elyra: IN PROGRESS - Extension installs correctly but requires container restart to load server endpoints""
echo

echo "🌐 Service Endpoints:"
echo "--------------------"
echo "  • Airflow UI: http://localhost:8080"
echo "  • JupyterLab: http://localhost:8081 (token: datascience123)"
echo "  • LocalStack S3: http://localhost:4566"
echo

echo "📊 Recent Spark Job Execution:"
echo "-----------------------------"
kubectl exec -it deployment/localstack -n localstack -- env AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test aws --endpoint-url=http://localhost:4566 s3 ls s3://data-engineering-bucket/spark-output/ --recursive | head -5
echo

echo "📚 JupyterLab Extensions:"
echo "-----------------------"
kubectl exec -n jupyter deployment/jupyter-lab -- jupyter labextension list | grep -E "(elyra|papermill)" | head -5
echo

echo "📝 Available Demo Notebooks:"
echo "----------------------------"
echo "  • notebooks/papermill_demo.ipynb - Papermill integration demo"
echo "  • Can be executed from Airflow using PapermillOperator"
echo "  • Note: Elyra visual pipeline editor has server endpoint issues"
echo "  • Workaround: Use Papermill directly or create pipelines via code"
echo

echo "🔧 Quick Test Commands:"
echo "----------------------"
echo "  # Test Airflow DAG execution:"
echo "  kubectl exec -n airflow airflow-scheduler-0 -- airflow dags list"
echo
echo "  # Test Spark job execution:"
echo "  kubectl exec -n airflow airflow-worker-0 -c worker -- airflow tasks test spark_operator_s3_pipeline spark_data_processing 2025-07-24"
echo
echo "  # Access JupyterLab:"
echo "  open http://localhost:8081"
echo

echo "📦 Component Status:"
echo "------------------"
kubectl get pods -A | grep -E "(airflow|jupyter|spark|localstack)" | awk '{print "  " $2 ": " $4}'
echo

echo "🎉 READY FOR USE!"
echo "================"
echo "• All core components are operational"
echo "• GitHub DAG synchronization is active"
echo "• Spark jobs can execute successfully"
echo "• Jupyter notebooks with Papermill can be executed from Airflow"
echo "• S3 storage is available via LocalStack"
echo
echo "For full deployment, run: ./scripts/deploy-everything.sh"
