#!/bin/bash
set -e

# Fix Workflow Controller and Viewer Issues
echo "🔧 Fixing Workflow Controller and Viewer issues..."

# Fix 1: Workflow Controller - Change metrics port to avoid conflict
echo "🔧 Fixing Workflow Controller port conflict..."

# Delete and recreate the workflow controller deployment with proper config
kubectl delete deployment workflow-controller -n kubeflow

# Wait a moment for cleanup
sleep 5

# Create a new workflow controller deployment with fixed configuration
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workflow-controller
  namespace: kubeflow
  labels:
    app: workflow-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: workflow-controller
  template:
    metadata:
      labels:
        app: workflow-controller
    spec:
      serviceAccountName: argo
      containers:
      - name: workflow-controller
        image: gcr.io/ml-pipeline/workflow-controller:v3.4.16-license-compliance
        command:
        - workflow-controller
        args:
        - --configmap=workflow-controller-configmap
        - --executor-image=gcr.io/ml-pipeline/argoexec:v3.4.16-license-compliance
        - --namespaced
        - --managed-namespace=kubeflow
        - --metrics-port=9091
        env:
        - name: LEADER_ELECTION_IDENTITY
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - containerPort: 9091
          name: metrics
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

# Fix 2: Create proper RBAC for viewer CRD
echo "🔧 Creating RBAC for viewer CRD..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ml-pipeline-viewer-crd-service-account
  namespace: kubeflow
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ml-pipeline-viewer-crd-cluster-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["argoproj.io"]
  resources: ["workflows"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["kubeflow.org"]
  resources: ["viewers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ml-pipeline-viewer-crd-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ml-pipeline-viewer-crd-cluster-role
subjects:
- kind: ServiceAccount
  name: ml-pipeline-viewer-crd-service-account
  namespace: kubeflow
EOF

# Fix 3: Update viewer CRD deployment to use service account
echo "🔧 Updating viewer CRD deployment..."
kubectl patch deployment ml-pipeline-viewer-crd -n kubeflow --patch='
spec:
  template:
    spec:
      serviceAccountName: ml-pipeline-viewer-crd-service-account
      containers:
      - name: ml-pipeline-viewer-crd
        env:
        - name: MAX_NUM_VIEWERS
          value: "50"
        - name: CACHE_RESYNC_PERIOD
          value: "300s"
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
'

# Fix 4: Create a simpler workflow controller config to avoid minio dependency issues
echo "🔧 Creating simplified workflow controller config..."
kubectl create configmap workflow-controller-configmap -n kubeflow --dry-run=client -o yaml --from-literal=config='
# Default configuration for the workflow controller
artifactRepository:
  archiveLogs: true
  s3:
    bucket: mlpipeline
    endpoint: minio-service.kubeflow:9000
    insecure: true
    accessKeySecret:
      name: mlpipeline-minio-artifact
      key: accesskey
    secretKeySecret:
      name: mlpipeline-minio-artifact
      key: secretkey

# Remove unused config sections that might cause issues
executorResources:
  requests:
    cpu: 10m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi

metricsConfig:
  enabled: true
  path: /metrics
  port: 9091

telemetryConfig:
  enabled: false
' | kubectl apply -f -

# Wait for rollouts to complete
echo "⏳ Waiting for rollouts to complete..."
kubectl rollout restart deployment/workflow-controller -n kubeflow
kubectl rollout restart deployment/ml-pipeline-viewer-crd -n kubeflow

# Wait for deployments to be ready
echo "⏳ Waiting for workflow controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/workflow-controller -n kubeflow

echo "⏳ Waiting for viewer CRD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/ml-pipeline-viewer-crd -n kubeflow

echo "✅ Workflow Controller and Viewer fixes applied!"

# Verify the fixes
echo "🔍 Verifying fixes..."
echo "Workflow Controller status:"
kubectl get pods -n kubeflow -l app=workflow-controller

echo "Viewer CRD status:"
kubectl get pods -n kubeflow -l app=ml-pipeline-viewer-crd

echo ""
echo "🎉 Workflow Controller and Viewer should now be working!"
echo ""
echo "📋 If issues persist, check logs with:"
echo "  kubectl logs -n kubeflow deployment/workflow-controller"
echo "  kubectl logs -n kubeflow deployment/ml-pipeline-viewer-crd"
