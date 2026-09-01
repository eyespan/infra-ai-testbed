# Observability Stack Deployment Guide

This document provides instructions for deploying the observability stack to a Kubernetes cluster.

## Prerequisites

- Kubernetes cluster with Prometheus Operator CRDs installed
- kubectl configured with cluster admin access

## Deployment Steps

1. Apply the namespace and RBAC:
```bash
kubectl apply -f namespace.yaml
kubectl apply -f prometheus-rbac.yaml
```

2. Apply configuration:
```bash
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-rules.yaml
kubectl apply -f alertmanager-config.yaml
kubectl apply -f grafana-datasource.yaml
kubectl apply -f grafana-dashboards.yaml
```

3. Deploy components:
```bash
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f prometheus-service.yaml
kubectl apply -f alertmanager-deployment.yaml
kubectl apply -f alertmanager-service.yaml
kubectl apply -f grafana-deployment.yaml
kubectl apply -f grafana-service.yaml
```

4. Create Grafana admin secret:
```bash
kubectl create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 16) \
  -n monitoring
```

## Resource Requirements

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Prometheus (2x) | 500m | 1000m | 1Gi | 2Gi |
| Alertmanager (2x) | 100m | 200m | 128Mi | 256Mi |
| Grafana | 100m | 500m | 256Mi | 1Gi |

Total estimated: ~3.5 CPU cores, ~6GB RAM

## Post-Deployment

1. Verify pods are running:
```bash
kubectl get pods -n monitoring
```

2. Access Grafana:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

3. Access Prometheus:
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

4. Access Alertmanager:
```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

## Monitoring Configuration

Update the ServiceMonitor in `servicemonitor.yaml` with your application's labels and port configuration.
