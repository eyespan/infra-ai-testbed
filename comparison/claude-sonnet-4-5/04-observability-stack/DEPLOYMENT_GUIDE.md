# Observability Stack Deployment Guide

## Overview

Complete production-ready observability stack for Kubernetes including Prometheus, Alertmanager, and Grafana.

## Components

### Core Monitoring
- **Prometheus** - Metrics collection and storage
- **Alertmanager** - Alert routing and notification
- **Grafana** - Metrics visualization and dashboards

### Configuration
- **Alert Rules** - 3 critical alerts (pod crash looping, high memory, disk pressure)
- **Scrape Configs** - Kubernetes service discovery
- **Dashboard** - Cluster overview dashboard
- **ServiceMonitor** - Sample app metrics collection

## Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured
- Storage class for PersistentVolumes (50Gi + 10Gi + 10Gi = 70Gi total)
- **Optional:** Prometheus Operator (for ServiceMonitor support)

## Quick Start

### 1. Create Namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Deploy RBAC

```bash
kubectl apply -f rbac.yaml
```

### 3. Deploy Prometheus

```bash
# Apply configuration
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-rules.yaml

# Deploy Prometheus
kubectl apply -f prometheus-deployment.yaml

# Verify
kubectl get pods -n monitoring -l app=prometheus
kubectl logs -n monitoring -l app=prometheus --tail=50
```

### 4. Deploy Alertmanager

**Important:** Edit `alertmanager-config.yaml` first:
- Replace `YOUR_PAGERDUTY_SERVICE_KEY`
- Replace `YOUR/SLACK/WEBHOOK`
- Replace `YOUR_SMTP_PASSWORD`

```bash
kubectl apply -f alertmanager-config.yaml
kubectl apply -f alertmanager-deployment.yaml

# Verify
kubectl get pods -n monitoring -l app=alertmanager
```

### 5. Deploy Grafana

**Important:** Change default password in `grafana-deployment.yaml`:
```yaml
stringData:
  password: "CHANGE_THIS_PASSWORD"
```

```bash
kubectl apply -f grafana-config.yaml
kubectl apply -f grafana-deployment.yaml

# Verify
kubectl get pods -n monitoring -l app=grafana
```

### 6. Deploy Sample App ServiceMonitor (Optional)

```bash
kubectl apply -f sample-app-servicemonitor.yaml
```

## Access Services

### Port Forward Method (Development)

```bash
# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090

# Access Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open http://localhost:9093

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000
# Login: admin / (password from secret)
```

### Ingress Method (Production)

Create Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - prometheus.example.com
        - alertmanager.example.com
        - grafana.example.com
      secretName: monitoring-tls
  rules:
    - host: prometheus.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus
                port:
                  number: 9090
    - host: alertmanager.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: alertmanager
                port:
                  number: 9093
    - host: grafana.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
```

## Verification

### Check Prometheus Targets

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Visit http://localhost:9090/targets
# All targets should show "UP"
```

### Check Alert Rules

```bash
# Visit http://localhost:9090/alerts
# Should see alert rules loaded
```

### Check Alertmanager Status

```bash
# Port forward Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Visit http://localhost:9093/#/status
# Should show configuration loaded
```

### Check Grafana Dashboard

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Visit http://localhost:3000
# Login with admin credentials
# Navigate to Dashboards → Cluster Overview
# Should see metrics displayed
```

## Configuration

### Customize Retention

Edit `prometheus-deployment.yaml`:

```yaml
args:
  - '--storage.tsdb.retention.time=30d'  # Change from 15d to 30d
  - '--storage.tsdb.retention.size=90GB' # Adjust size accordingly
```

Then increase PVC size in same file.

### Add Custom Alerts

Edit `prometheus-rules.yaml` and add to `groups`:

```yaml
- name: my_custom_alerts
  interval: 30s
  rules:
    - alert: MyCustomAlert
      expr: my_metric > 100
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Custom alert description"
```

Reload configuration:
```bash
kubectl exec -n monitoring deployment/prometheus -- curl -X POST http://localhost:9090/-/reload
```

### Add Notification Channels

Edit `alertmanager-config.yaml` and add receivers:

```yaml
receivers:
  - name: 'my-team'
    slack_configs:
      - channel: '#my-team-alerts'
        webhook_url: 'https://hooks.slack.com/...'
```

Apply and restart:
```bash
kubectl apply -f alertmanager-config.yaml
kubectl rollout restart -n monitoring deployment/alertmanager
```

### Add Grafana Dashboards

Create ConfigMap with dashboard JSON:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-my-dashboard
  namespace: monitoring
data:
  my-dashboard.json: |
    {
      "dashboard": {
        "title": "My Dashboard",
        ...
      }
    }
```

Mount in Grafana deployment:
```yaml
volumeMounts:
  - name: my-dashboard
    mountPath: /var/lib/grafana/dashboards/my-dashboard.json
    subPath: my-dashboard.json
volumes:
  - name: my-dashboard
    configMap:
      name: grafana-dashboard-my-dashboard
```

## Troubleshooting

### Prometheus Not Scraping Targets

**Check service discovery:**
```bash
kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/targets | jq
```

**Check RBAC permissions:**
```bash
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:prometheus -n prod
```

**Check logs:**
```bash
kubectl logs -n monitoring -l app=prometheus --tail=100 | grep -i error
```

### Alerts Not Firing

**Check alert rules loaded:**
```bash
kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/rules | jq
```

**Check alert evaluation:**
```bash
# Visit http://localhost:9090/alerts
# Check "State" column - should transition from "Inactive" → "Pending" → "Firing"
```

**Check Alertmanager connectivity:**
```bash
kubectl logs -n monitoring -l app=prometheus | grep alertmanager
```

### Alerts Firing But No Notifications

**Check Alertmanager logs:**
```bash
kubectl logs -n monitoring -l app=alertmanager --tail=100
```

**Check webhook configuration:**
```bash
# Test Slack webhook
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_SLACK_WEBHOOK_URL
```

**Check silence status:**
```bash
# Visit http://localhost:9093/#/silences
# Ensure no active silences blocking your alerts
```

### High Memory Usage

**Check cardinality:**
```bash
# Connect to Prometheus
kubectl exec -n monitoring deployment/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series' | jq

# Check top metric names by cardinality
kubectl exec -n monitoring deployment/prometheus -- wget -qO- 'http://localhost:9090/api/v1/label/__name__/values' | jq
```

**If cardinality is too high:**
1. Add metric_relabel_configs to drop high-cardinality metrics
2. Reduce scrape_interval
3. Increase memory limits
4. Reduce retention time

### Storage Issues

**Check disk usage:**
```bash
kubectl exec -n monitoring deployment/prometheus -- df -h /prometheus
```

**Check PVC status:**
```bash
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring prometheus-storage
```

**Expand PVC (if storage class supports):**
```bash
kubectl patch pvc prometheus-storage -n monitoring -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

## Monitoring the Monitors

### Deploy DeadMansSwitch

Add to `prometheus-rules.yaml`:

```yaml
- alert: DeadMansSwitch
  expr: vector(1)
  labels:
    severity: none
  annotations:
    summary: "Alerting pipeline is healthy"
```

Configure Alertmanager to send to PagerDuty heartbeat or similar external service.

### Monitor Prometheus from Outside

Deploy a second monitoring system (Pingdom, Datadog, etc.) to monitor:
- Prometheus `/metrics` endpoint availability
- Alertmanager `/metrics` endpoint availability
- Grafana `/api/health` endpoint availability

## Backup and Recovery

### Backup Prometheus Data

```bash
# Create snapshot
kubectl exec -n monitoring deployment/prometheus -- \
  curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Copy snapshot from pod
SNAPSHOT_NAME=$(kubectl exec -n monitoring deployment/prometheus -- \
  ls /prometheus/snapshots | tail -1)

kubectl cp monitoring/$(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}'):/prometheus/snapshots/$SNAPSHOT_NAME \
  ./prometheus-backup-$(date +%Y%m%d)
```

### Restore Prometheus Data

```bash
# Scale down Prometheus
kubectl scale -n monitoring deployment/prometheus --replicas=0

# Copy backup to PVC (requires a helper pod)
kubectl run -n monitoring restore-helper --image=busybox --command -- sleep infinity
kubectl cp ./prometheus-backup-20240827 monitoring/restore-helper:/backup
kubectl exec -n monitoring restore-helper -- cp -r /backup/* /prometheus/

# Scale up Prometheus
kubectl scale -n monitoring deployment/prometheus --replicas=1
```

### Backup Grafana Dashboards

```bash
# Export all dashboards
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/search | jq -r '.[].uid' | \
  while read uid; do
    curl -H "Authorization: Bearer YOUR_API_KEY" \
      http://localhost:3000/api/dashboards/uid/$uid > dashboard-$uid.json
  done
```

## Performance Tuning

### Reduce Scrape Load

```yaml
# In prometheus-config.yaml
global:
  scrape_interval: 60s  # Increase from 30s
  scrape_timeout: 20s
```

### Optimize Query Performance

```yaml
# In prometheus-deployment.yaml
args:
  - '--query.timeout=30s'
  - '--query.max-concurrency=20'
  - '--query.max-samples=50000000'
```

### Enable Remote Write (for long-term storage)

```yaml
# In prometheus-config.yaml
remote_write:
  - url: http://thanos-receive:19291/api/v1/receive
    queue_config:
      capacity: 10000
      max_shards: 50
      min_shards: 1
      max_samples_per_send: 5000
      batch_send_deadline: 5s
```

## Security Hardening

### Enable Authentication (Prometheus)

Not natively supported - use OAuth2 Proxy or similar:

```yaml
# Deploy oauth2-proxy sidecar
containers:
  - name: oauth2-proxy
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    args:
      - --provider=github
      - --upstream=http://localhost:9090
```

### Enable TLS

Use Ingress with cert-manager for TLS termination (recommended).

Alternatively, configure native TLS in each component (complex).

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: grafana
        - podSelector:
            matchLabels:
              app: alertmanager
      ports:
        - protocol: TCP
          port: 9090
  egress:
    - to:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 9093  # Alertmanager
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443  # Kubernetes API
    - to:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 80  # Scrape targets
```

## Upgrading

### Upgrade Prometheus

```bash
# Edit prometheus-deployment.yaml, change image version
# Example: prom/prometheus:v2.48.0 → prom/prometheus:v2.49.0

kubectl apply -f prometheus-deployment.yaml
kubectl rollout status -n monitoring deployment/prometheus
```

### Upgrade Alertmanager

```bash
# Edit alertmanager-deployment.yaml
kubectl apply -f alertmanager-deployment.yaml
kubectl rollout status -n monitoring deployment/alertmanager
```

### Upgrade Grafana

```bash
# Edit grafana-deployment.yaml
kubectl apply -f grafana-deployment.yaml
kubectl rollout status -n monitoring deployment/grafana
```

## Cleanup

```bash
# Delete all monitoring resources
kubectl delete namespace monitoring

# This will delete:
# - All pods
# - All services
# - All PVCs (and data!)
# - All ConfigMaps
# - All Secrets
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [OPERATIONAL_NOTES.md](./OPERATIONAL_NOTES.md) - Failure modes and operational considerations
