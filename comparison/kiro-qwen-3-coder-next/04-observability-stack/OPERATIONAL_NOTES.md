# Observability Stack Operational Notes

## Failure Modes

### Prometheus Down

**Impact**: 
- Dashboards in Grafana will be empty (no data)
- Alerts will not fire (no evaluation)
- System becomes blind to failures

**Failure Mode**: Fail-closed. Without Prometheus evaluating alerts, no notifications will be sent.

**Recovery**:
1. Check pod status: `kubectl get pods -n monitoring`
2. Check Prometheus PVC for data corruption
3. If replica is down, the second replica should continue serving
4. Check WAL: `kubectl exec -n monitoring <pod> -- ls /prometheus/wal`
5. If WAL is corrupted, data may be lost; restore from backup if available

### Alertmanager Down

**Impact**:
- Notifications are queued in Prometheus but will eventually be dropped
- No alert routing to receivers (Slack, email, etc.)
- Alerts will show as "pending" but never "firing"

**Failure Mode**: Fail-open. Alertmanager has in-memory queue; without HA, alerts may be lost during restart.

**Recovery**:
1. Check pod status: `kubectl get pods -n monitoring`
2. Verify Alertmanager config: `kubectl get configmap alertmanager-config -n monitoring -o yaml`
3. Check queue depth: `curl http://alertmanager:9093/api/v2/status`

### Disk Full on Prometheus PVC

**Impact**:
- WAL corruption
- Data loss
- Prometheus may crash

**Mitigation**:
- PVC size: 50GB (configurable via `storage.volumeClaimTemplate`)
- Retention: 15 days (configurable via `--storage.tsdb.retention.time`)
- Size-based cleanup: `--storage.tsdb.retention.size=50GB`

**Recovery**:
1. Immediately increase PVC size if possible
2. Delete old WAL segments: `kubectl exec -n monitoring <pod> -- rm -rf /prometheus/wal/*`
3. Restart Prometheus pod
4. Consider reducing retention time

### Cardinality Explosion

**Impact**:
- Prometheus memory usage spikes
- Query performance degrades
- Storage fills rapidly

**Common Causes**:
- High-scrape-interval jobs (e.g., 5s on kube-state-metrics)
- Labels with high-cardinality values (e.g., user IDs, session IDs)
- Missing relabel_configs in scrape_configs

**Mitigation**:
- Scrape interval: 30s (reduced from 5s in starter)
- Drop high-cardinality labels in relabel_configs
- Use `metric_relabel_configs` to drop expensive metrics
- Set `__name__` filters to limit metric types

**Recovery**:
1. Identify high-cardinality metrics: `curl http://prometheus:9090/api/v1/labels`
2. Update scrape config to drop labels
3. Restart Prometheus to apply config

## Alert Tuning

### Pod Crash Looping
- Current threshold: `rate(container_restart_count_total[5m]) > 0`
- Consider adjusting for legitimate short-lived jobs

### High Container Memory
- Current threshold: >90% of limit for >10m
- Consider adding 50% warning threshold

### Node Disk Pressure
- Current threshold: <10% available
- Consider adding 20% warning threshold

## Maintenance

### Backup
Prometheus data should be backed up regularly:
```bash
# Export snapshots
curl -X POST http://prometheus:9090/api/v1/admin/tsdb/snapshot
```

### Configuration Updates
1. Update ConfigMap
2. Trigger reload: `kubectl rollout restart deployment/prometheus -n monitoring`

## Scaling

### Horizontal Scaling
- Prometheus: 2 replicas with anti-affinity
- Alertmanager: 2 replicas with mesh clustering

### Vertical Scaling
- Increase resource requests/limits if Prometheus OOMs
- Add more replicas if query load is high

## Troubleshooting Commands

```bash
# Check Prometheus status
kubectl exec -n monitoring <pod> -- curl localhost:9090/-/healthy

# Check Alertmanager status
kubectl exec -n monitoring <pod> -- curl localhost:9093/-/healthy

# View Prometheus metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
open http://localhost:9090/metrics

# View Grafana logs
kubectl logs -n monitoring deployment/grafana -f
```
