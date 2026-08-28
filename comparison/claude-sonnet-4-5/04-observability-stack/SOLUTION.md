# Observability Stack Solution

## Overview

Complete production-ready observability stack for Kubernetes with Prometheus, Alertmanager, and Grafana. All requirements met with proper resource limits, retention policies, and failure mode documentation.

## Deliverables

### Core Components

1. **namespace.yaml** - Monitoring namespace
2. **rbac.yaml** - ServiceAccount and ClusterRole for Prometheus
3. **prometheus-config.yaml** - Prometheus scrape configuration
4. **prometheus-rules.yaml** - Alert rules (3 critical + additional)
5. **prometheus-deployment.yaml** - Prometheus deployment with PVC, resources, health checks
6. **alertmanager-config.yaml** - Alertmanager routing and notification configuration
7. **alertmanager-deployment.yaml** - Alertmanager deployment with PVC
8. **grafana-config.yaml** - Grafana datasources, dashboard providers, and cluster overview dashboard
9. **grafana-deployment.yaml** - Grafana deployment with PVC
10. **sample-app-servicemonitor.yaml** - ServiceMonitor for sample application

### Documentation

11. **OPERATIONAL_NOTES.md** - Comprehensive failure mode analysis, cardinality management, retention notes
12. **DEPLOYMENT_GUIDE.md** - Step-by-step deployment and troubleshooting guide

## Requirements Checklist

### ✅ Prometheus Setup
- [x] Prometheus deployment with proper configuration
- [x] Kubernetes service discovery (pods, nodes, services, API server, cAdvisor)
- [x] Resource requests (500m CPU, 2Gi memory) and limits (2 CPU, 4Gi memory)
- [x] Persistent storage (50Gi PVC)
- [x] Retention configuration (15 days / 45GB)
- [x] Pinned image version (v2.48.0, not :latest)
- [x] Security context (non-root user)
- [x] Health probes (liveness and readiness)

### ✅ Alertmanager
- [x] Alertmanager deployment with configuration
- [x] PagerDuty integration (configured)
- [x] Slack integration (configured)
- [x] Email integration (configured)
- [x] Alert grouping, inhibition, and routing
- [x] Resource limits (100m CPU, 128Mi memory)
- [x] Persistent storage for silences (10Gi PVC)

### ✅ Three Critical Alerts
1. **PodCrashLooping** - Detects pods in CrashLoopBackOff
   - Expression: `rate(kube_pod_container_status_restarts_total[15m]) > 0`
   - Threshold: Firing for 5 minutes
   - Severity: Critical

2. **ContainerHighMemory** - Detects containers using >90% of memory limit
   - Expression: `(container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.90`
   - Threshold: Firing for 5 minutes
   - Severity: Critical

3. **NodeDiskPressure** - Detects nodes under disk pressure
   - Expression: `kube_node_status_condition{condition="DiskPressure",status="true"} == 1`
   - Threshold: Firing for 2 minutes
   - Severity: Critical

### ✅ Grafana
- [x] Grafana deployment with Prometheus datasource
- [x] Basic cluster overview dashboard (ConfigMap)
- [x] Panels for: nodes, pods, restarts, CPU, memory, network I/O, disk I/O, pod status
- [x] Resource limits (250m CPU, 512Mi memory)
- [x] Persistent storage (10Gi PVC)
- [x] Admin credentials in Secret

### ✅ ServiceMonitor for Sample App
- [x] Complete ServiceMonitor with selector, endpoints, relabeling
- [x] Metric relabeling to reduce cardinality
- [x] Alternative annotation-based scraping documented

### ✅ Resource Management
- [x] All components have resource requests and limits
- [x] Total stack footprint: 850m CPU request, 3.5 CPU limit, 2.64Gi memory request, 5.5Gi memory limit
- [x] Stack uses <10% of typical cluster resources
- [x] Prevents observability stack from starving cluster

### ✅ Retention and Cardinality Documentation
- [x] Retention policy: 15 days or 45GB
- [x] Cardinality management strategies documented
- [x] Metric relabeling to drop high-cardinality metrics
- [x] Calculation examples for storage sizing
- [x] Cardinality explosion detection and mitigation

### ✅ Failure Mode Analysis
- [x] **Prometheus down:** Fail open (blind, no metrics collected)
- [x] **Alertmanager down:** Fail closed (silent failure, no notifications)
- [x] **Cardinality explosion:** Memory exhaustion, query slowdown, OOM kill
- [x] **Disk full:** Silent data loss, queries return stale data
- [x] **Network partition:** Partial blindness
- [x] **PagerDuty API down:** Fail closed (no pages)
- [x] Detection and mitigation strategies for each failure mode

## Architecture

```
┌─────────────────────────────────────────────────────┐
│             Kubernetes Cluster                       │
│                                                      │
│  ┌──────┐  ┌──────┐  ┌──────┐                      │
│  │ Pods │  │Nodes │  │ APIs │                      │
│  └───┬──┘  └───┬──┘  └───┬──┘                      │
│      │         │          │                          │
│      └─────────┼──────────┘                          │
│                ▼                                     │
│        ┌──────────────┐                             │
│        │  Prometheus  │  50Gi PVC                   │
│        │              │  500m CPU, 2Gi RAM          │
│        └──────┬───────┘                             │
│               │                                      │
│      ┌────────┼────────┐                            │
│      ▼                 ▼                             │
│  ┌──────────┐   ┌──────────┐                       │
│  │Alertmgr  │   │ Grafana  │                       │
│  │10Gi PVC  │   │10Gi PVC  │                       │
│  │100m,128M │   │250m,512M │                       │
│  └────┬─────┘   └──────────┘                       │
│       │                                              │
│       ▼                                              │
│  [PagerDuty]                                        │
│  [Slack]                                            │
│  [Email]                                            │
└─────────────────────────────────────────────────────┘
```

## Key Features

### Resource Allocation
- **Prometheus:** 500m-2 CPU, 2-4Gi memory, 50Gi storage
- **Alertmanager:** 100m-500m CPU, 128-512Mi memory, 10Gi storage
- **Grafana:** 250m-1 CPU, 512Mi-1Gi memory, 10Gi storage
- **Total:** 850m-3.5 CPU, 2.64-5.5Gi memory, 70Gi storage

### Retention Policy
- **Time-based:** 15 days
- **Size-based:** 45GB (90% of PVC)
- **Calculation:** ~50k samples/sec × 15 days ×1.5 bytes × 0.25 (compression) ≈ 24GB

### Cardinality Management
- Drop high-cardinality container network metrics
- Drop Docker internal metrics
- Drop histogram buckets where appropriate
- Label drop for user_id and similar unbounded labels
- Alert when cardinality exceeds 800k (80% of 1M budget)

### Alert Configuration
- **3 Critical Alerts:** Pod crash looping, high memory, disk pressure
- **Additional Alerts:** Node not ready, pending pods, high CPU, Prometheus self-monitoring
- **Routing:** Critical → PagerDuty + Slack, Warning → Slack only
- **Inhibition:** Suppress warnings when critical fires, suppress pod alerts when node down
- **Grouping:** By alertname, cluster, namespace, pod (reduce noise)

### Dashboard
- Cluster-level metrics: Total nodes, total pods, restarts, nodes not ready
- Resource usage: CPU and memory by node
- Network I/O by namespace
- Disk I/O by node
- Pod status table by namespace

## Deployment

### Prerequisites
- Kubernetes 1.20+
- Storage class supporting 70Gi total
- kubectl access

### Quick Deploy
```bash
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-rules.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f alertmanager-config.yaml
kubectl apply -f alertmanager-deployment.yaml
kubectl apply -f grafana-config.yaml
kubectl apply -f grafana-deployment.yaml
kubectl apply -f sample-app-servicemonitor.yaml
```

### Configuration Required
1. **alertmanager-config.yaml:**
   - Set PagerDuty service key
   - Set Slack webhook URL
   - Set SMTP password

2. **grafana-deployment.yaml:**
   - Change default admin password

3. **ServiceMonitor:**
   - Requires Prometheus Operator, or use annotation-based scraping

### Access Services
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Grafana (admin / changeme123)
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## Operational Highlights

### Monitoring the Monitors
- Deploy second Prometheus to watch first
- Implement DeadMansSwitch (always-firing alert)
- External monitoring for observability stack health
- PagerDuty heartbeat integration

### Failure Recovery
- Prometheus: Auto-restart via Deployment, loads from PVC
- Alertmanager: Auto-restart, silences preserved in PVC
- Grafana: Auto-restart, dashboards from ConfigMaps
- Data loss only occurs if PVC lost or disk full

### Cardinality Explosion Response
1. Alert fires: `PrometheusHighMemory`
2. Query top metrics: Check cardinality by metric name
3. Add metric_relabel_configs to drop offenders
4. Reload Prometheus config
5. Consider increasing memory limits or reducing retention

### Storage Management
1. Alert fires: `PrometheusStorageLow` at 85% full
2. Options:
   - Expand PVC (if storage class supports)
   - Reduce retention time
   - Delete old data via API
   - Export to long-term storage

## Testing

### Verify Scraping
```bash
# Check targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'
```

### Verify Alerts
```bash
# Check rules loaded
curl http://localhost:9090/api/v1/rules | jq

# Trigger test alert
kubectl run test-crash --image=busybox --restart=Never -- exit 1
# Wait 5 minutes, check PodCrashLooping alert fires
```

### Verify Alertmanager
```bash
# Check config
curl http://localhost:9093/api/v1/status | jq

# Send test alert
curl -X POST http://localhost:9093/api/v1/alerts -d '[{
  "labels": {"alertname": "TestAlert", "severity": "critical"},
  "annotations": {"summary": "This is a test"}
}]'
```

### Verify Grafana
```bash
# Check datasource
curl -u admin:changeme123 http://localhost:3000/api/datasources | jq

# Check dashboards
curl -u admin:changeme123 http://localhost:3000/api/search | jq
```

## Troubleshooting

See **DEPLOYMENT_GUIDE.md** for comprehensive troubleshooting:
- Prometheus not scraping targets
- Alerts not firing
- Alerts firing but no notifications
- High memory usage
- Storage issues
- Cardinality explosions

## Scaling

### When to Scale Up
- Cardinality > 800k time series
- Query latency > 5s
- Memory usage near limit
- Scrape duration > 30s

### When to Scale Out
- Single Prometheus insufficient
- Need high availability
- Multi-region monitoring

### Scaling Options
- Federation (hierarchical Prometheus)
- Thanos (HA + long-term storage)
- Cortex (multi-tenant)
- M3DB (distributed TSDB)

## Security Considerations

- ✅ All components run as non-root users
- ✅ Security contexts configured
- ✅ RBAC with least-privilege
- ✅ Secrets for credentials (not ConfigMaps)
- ⚠️ No authentication on Prometheus/Alertmanager (use Ingress + OAuth proxy)
- ⚠️ No TLS (use Ingress with cert-manager)
- 📝 NetworkPolicy example provided in DEPLOYMENT_GUIDE.md

## Production Readiness

This stack is production-ready with:
- ✅ Persistent storage (no data loss on restart)
- ✅ Resource limits (won't starve cluster)
- ✅ Health probes (auto-restart on failure)
- ✅ Retention management (won't fill disk)
- ✅ Cardinality controls (won't OOM)
- ✅ Critical alerts (detect common issues)
- ✅ Failure mode documentation (ops team knows what to expect)
- ✅ Operational runbooks (how to respond)
- ✅ Monitoring self-monitoring (observability for observability)

## Next Steps

1. **Deploy:** Follow DEPLOYMENT_GUIDE.md
2. **Configure:** Update secrets and webhooks
3. **Test:** Verify all components working
4. **Monitor:** Watch for alerts, check dashboards
5. **Tune:** Adjust retention, cardinality, resources as needed
6. **Document:** Add runbook URLs for your environment
7. **Train:** Ensure team understands failure modes
8. **Iterate:** Add custom alerts and dashboards for your workloads

## References

- **OPERATIONAL_NOTES.md** - Failure modes, cardinality, retention details
- **DEPLOYMENT_GUIDE.md** - Deployment steps, troubleshooting, configuration
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Grafana Documentation](https://grafana.com/docs/)
