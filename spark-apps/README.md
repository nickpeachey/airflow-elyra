# Scala Spark Applications

This directory contains Scala Spark applications that can be executed via the Spark Operator in Kubernetes.

## Structure

```
spark-apps/
├── build.sbt                           # SBT build configuration
├── project/
│   └── plugins.sbt                    # SBT plugins
├── src/main/scala/com/example/
│   └── DataProcessing.scala           # Main Scala application
├── data_processing.py                 # Python Spark application
├── data-processing-spark-app.yaml     # Python Spark application manifest
├── scala-spark-apps.yaml              # Scala Spark application manifests
└── README.md                          # This file
```

## Scala Applications

### DataProcessing.scala

A comprehensive data processing application that demonstrates:
- Reading data from S3 (LocalStack)
- Data cleaning and transformation
- Statistical analysis
- Writing results back to S3

**Features:**
- Handles missing values with median imputation
- Processes both numeric and categorical data
- Generates comprehensive statistics
- Includes error handling and logging

### Building the Application

#### Prerequisites
- SBT (Scala Build Tool)
- Java 11+

#### Build Process
```bash
# From the spark-apps directory
sbt clean assembly
```

This creates a fat JAR with all dependencies at:
`target/scala-2.12/data-processing-assembly-1.0.jar`

#### Automated Build and Deployment
```bash
# From the project root
./scripts/build-scala-app.sh
```

This script:
1. Installs SBT if not present (macOS only)
2. Builds the Scala application
3. Uploads the JAR to LocalStack S3
4. Deploys Spark application manifests

## Spark Application Manifests

### scala-data-processing
A production-ready data processing job with:
- S3 integration via LocalStack
- Adaptive query execution
- Proper resource allocation
- Service account configuration
- Monitoring enabled

### scala-spark-pi
A simple Spark Pi calculation example for testing:
- Uses built-in Spark examples JAR
- Minimal resource requirements
- Good for validation

## Running Scala Spark Jobs

### Via Kubectl
```bash
# Apply specific application
kubectl apply -f scala-spark-apps.yaml

# Monitor job
kubectl get sparkapplication -n spark
kubectl describe sparkapplication scala-data-processing -n spark

# View logs
kubectl logs -n spark -l spark-role=driver
kubectl logs -n spark -l spark-role=executor
```

### Via Airflow
The `scala_spark_pipeline.py` DAG demonstrates running Scala Spark jobs through Airflow:
1. Prepares sample data
2. Uploads JAR to S3
3. Submits Spark job via SparkKubernetesOperator
4. Monitors job completion
5. Validates output

### Direct Submission
```bash
# Port forward to access Spark Operator directly
kubectl port-forward -n spark svc/spark-operator-webhook 8080:8080

# Submit job via REST API or kubectl
```

## Configuration

### S3 Configuration (LocalStack)
All applications are configured to work with LocalStack:
- Endpoint: `http://localstack-service.localstack.svc.cluster.local:4566`
- Credentials: `test/test`
- Path style access enabled
- SSL disabled

### Kubernetes Configuration
- Driver service account: `spark-driver`
- Executor service account: `spark-executor`
- Namespace: `spark`
- Image: `apache/spark:3.5.0-scala2.12-java11-python3-ubuntu`

### Resource Allocation
- Driver: 1 core, 1GB memory
- Executor: 1 core, 1GB memory, 2 instances
- Memory overhead: 400MB per container

## Development

### Adding New Applications

1. **Create Scala source file**:
   ```scala
   // src/main/scala/com/example/MyApp.scala
   package com.example
   
   import org.apache.spark.sql.SparkSession
   
   object MyApp {
     def main(args: Array[String]): Unit = {
       val spark = SparkSession.builder()
         .appName("MyApp")
         .getOrCreate()
       
       // Your application logic here
       
       spark.stop()
     }
   }
   ```

2. **Update build.sbt** if needed for additional dependencies

3. **Create Spark application manifest**:
   ```yaml
   apiVersion: sparkoperator.k8s.io/v1beta2
   kind: SparkApplication
   metadata:
     name: my-app
     namespace: spark
   spec:
     type: Scala
     mainClass: "com.example.MyApp"
     # ... rest of configuration
   ```

4. **Build and deploy**:
   ```bash
   sbt assembly
   # Upload JAR to S3
   kubectl apply -f my-app.yaml
   ```

### Testing

#### Unit Testing
Add to `build.sbt`:
```scala
libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.15" % Test
```

Create tests in `src/test/scala/`:
```scala
import org.scalatest.funsuite.AnyFunSuite

class DataProcessingTest extends AnyFunSuite {
  test("data processing logic") {
    // Your tests here
  }
}
```

#### Integration Testing
Use the test pipeline:
```bash
./scripts/test-pipeline.sh
```

### Debugging

#### View Application Status
```bash
kubectl get sparkapplication -n spark -o wide
kubectl describe sparkapplication <app-name> -n spark
```

#### Access Spark UI
```bash
# Port forward to driver pod
kubectl port-forward -n spark <driver-pod-name> 4040:4040
# Open http://localhost:4040
```

#### View Logs
```bash
# Driver logs
kubectl logs -n spark -l spark-role=driver -l spark-app-name=<app-name>

# Executor logs
kubectl logs -n spark -l spark-role=executor -l spark-app-name=<app-name>

# Follow logs
kubectl logs -n spark -l spark-role=driver -f
```

## Performance Tuning

### Memory Optimization
- Adjust `driver.memory` and `executor.memory`
- Configure `memoryOverhead` appropriately
- Use `spark.sql.adaptive.coalescePartitions.enabled`

### CPU Optimization
- Match `executor.cores` to your workload
- Adjust `executor.instances` based on data size
- Consider `spark.sql.adaptive.skewJoin.enabled`

### Storage Optimization
- Use Parquet format for better performance
- Partition data appropriately
- Configure S3A settings for optimal throughput

## Security

### Service Accounts
Applications use dedicated service accounts:
- `spark-driver`: For driver pods
- `spark-executor`: For executor pods

### RBAC
Proper RBAC policies are configured to:
- Allow pod creation and management
- Access to ConfigMaps and Secrets
- Cross-namespace communication

### Network Policies
Consider implementing network policies to:
- Restrict inter-pod communication
- Control egress traffic
- Isolate Spark jobs by tenant

## Monitoring

### Metrics
- Spark metrics exposed via JMX
- Prometheus integration available
- Custom metrics via Spark listeners

### Logging
- Structured logging with JSON format
- Log aggregation via Kubernetes
- Centralized logging with ELK stack (optional)

### Alerting
- Job failure notifications
- Resource usage alerts
- Performance degradation detection
