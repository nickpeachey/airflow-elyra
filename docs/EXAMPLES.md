# Data Engineering Examples

This directory contains example notebooks, DAGs, and Spark applications demonstrating various data engineering patterns and best practices.

## Notebooks

### Data Ingestion (`data_ingestion.ipynb`)
- Demonstrates data generation and loading into S3 (LocalStack)
- Shows parameterization with Papermill
- Includes data quality metadata generation
- Compatible with Airflow KubernetesPodOperator

### Data Validation (`data_validation.ipynb`)
- Comprehensive data quality validation framework
- Tests for completeness, uniqueness, validity, and consistency
- Generates detailed validation reports
- Can be used as a validation step in pipelines

### Simple Analysis (`simple_analysis.ipynb`)
- Basic example of parameterized notebook execution
- Demonstrates data visualization and summary statistics
- Good starting point for custom analysis notebooks

## Airflow DAGs

### Data Processing Pipeline (`data_processing_pipeline.py`)
- Complete end-to-end pipeline example
- Integrates Jupyter notebooks, Spark jobs, and validation
- Uses LocalStack for storage
- Demonstrates task dependencies and error handling

### Papermill Example (`papermill_example.py`)
- Simple example of running notebooks with Papermill
- Shows parameter injection and output handling
- Good starting point for notebook-based workflows

## Spark Applications

### Data Processing Job (`data_processing.py`)
- PySpark application for data transformation
- Reads from and writes to S3 (LocalStack)
- Includes data cleaning and analysis functions
- Can be deployed via Spark Operator

### Spark Application Definition (`data-processing-spark-app.yaml`)
- Kubernetes SparkApplication resource
- Configured for LocalStack S3 integration
- Includes monitoring and resource management
- Ready for deployment with `kubectl apply`

## Best Practices

### Notebook Development
1. Always tag parameter cells with `parameters`
2. Include comprehensive error handling
3. Generate metadata for downstream processes
4. Use meaningful output file names with timestamps
5. Document notebook purpose and usage

### DAG Development
1. Use meaningful task IDs and descriptions
2. Set appropriate retries and timeouts
3. Include monitoring and alerting
4. Use XCom for task communication
5. Tag DAGs for organization

### Spark Development
1. Configure appropriate resource limits
2. Use S3A for S3 integration
3. Enable adaptive query execution
4. Include comprehensive logging
5. Handle schema evolution gracefully

## Running Examples

### 1. Run Individual Notebook
```bash
# Port forward to Jupyter
kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888

# Open http://localhost:8888 and run notebooks
```

### 2. Run Papermill from Command Line
```bash
# Execute notebook with parameters
papermill notebooks/simple_analysis.ipynb \
  notebooks/output/analysis_$(date +%Y%m%d).ipynb \
  -p execution_date "$(date +%Y-%m-%d)" \
  -p sample_size 5000
```

### 3. Deploy Spark Job
```bash
# Apply Spark application
kubectl apply -f spark-apps/data-processing-spark-app.yaml

# Monitor job
kubectl get sparkapplication -n spark
kubectl logs -n spark -l spark-role=driver
```

### 4. Trigger Airflow DAG
```bash
# Access Airflow UI at http://localhost:8080
# Enable and trigger DAGs from the web interface
```

## Customization

### Creating New Notebooks
1. Copy an existing notebook as a template
2. Update parameter cell with required variables
3. Modify analysis code for your use case
4. Test with Papermill before integration

### Creating New DAGs
1. Use existing DAGs as templates
2. Update task definitions and dependencies
3. Test in Airflow UI before scheduling
4. Add appropriate monitoring and alerts

### Creating New Spark Jobs
1. Start with the provided PySpark template
2. Update data sources and transformations
3. Test locally before Kubernetes deployment
4. Configure appropriate resources

## Monitoring and Debugging

### Notebook Execution
- Check Jupyter logs for execution errors
- Review notebook outputs for parameter injection
- Monitor resource usage during execution

### DAG Execution
- Use Airflow UI for task monitoring
- Check task logs for detailed error information
- Monitor resource usage in Kubernetes

### Spark Jobs
- Use Spark UI for job monitoring
- Check driver and executor logs
- Monitor resource allocation and usage

## Performance Optimization

### Notebooks
- Use efficient pandas operations
- Minimize data loading and copying
- Leverage vectorized operations
- Consider using Dask for large datasets

### Spark Jobs
- Optimize partitioning strategy
- Use appropriate caching
- Tune memory and CPU resources
- Consider broadcast joins for small datasets

### Overall Pipeline
- Parallelize independent tasks
- Use appropriate data formats (Parquet)
- Implement incremental processing
- Monitor and optimize bottlenecks
