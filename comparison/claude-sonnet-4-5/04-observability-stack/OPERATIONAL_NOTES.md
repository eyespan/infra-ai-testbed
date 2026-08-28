# Observability Stack Operational Notes

## Overview

This document explains the failure modes, operational considerations, and design decisions for the Kubernetes observability stack.

## Architecture Summary

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │   Pods     │  │   Nodes    │  │   Services │        │
│  │ (metrics)  │  │ (metrics)  │  │ (metrics)  │        │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘        │
│         │                │                │              │
│         └────────────────┼────────────────┘              │
│                          ▼                               │
│                  ┌──────────────┐                        │
│                  │  Prometheus  │                        │
│                  │ (scrape &    │                        │
│                  │  evaluate)   │                        │
│                  └──────┬───────┘                        │
│                         │                                │
│              ┌──────────┼──────────┐                     │
│              ▼                     ▼                     │
│      ┌──────────────┐      ┌──────────────┐             │
│      │ Alertmanager │      │   Grafana    │             │
│      │  (routing)   │      │ (visualize)  │             │
│      └──────┬───────┘      └──────────────┘             │
│             │                                            │
│             ▼                                            │
│    ┌─────────────────┐                                  │
│    │  PagerDuty /    │                                  │
│    │  Slack / Email  │                                  │
│    └─────────────────┘                                  │
└─────────────────────────────────────────────────────────┘
```

## Resource Allocation

### Prometheus
- **CPU Request:** 500m (0.5 cores)
- **CPU Limit:** 2000m (2 cores)
- **Memory Request:** 2Gi
- **Memory Limit:** 4Gi
- **Storage:** 50Gi PVC

**Rationale:**
- Request ensures minimum resources for scraping ~100-200 targets
- Limit prevents Prometheus from starving other workloads
- 2Gi memory baseline supports typical cardinality (~1M active time series)
- 4Gi limit handles cardinality spikes without OOM
- Storage sized for 15-day retention with ~50-100k samples/sec

### Alertmanager
- **CPU Request:** 100m
- **CPU Limit:** 500m
- **Memory Request:** 128Mi
- **Memory Limit:** 512Mi
- **Storage:** 10Gi PVC

**Rationale:**
- Alertmanager is lightweight (routing, grouping, inhibition only)
- Storage needed for silences and notification history
- Minimal resource footprint

### Grafana
- **CPU Request:** 250m
- **CPU Limit:** 1000m (1 core)
- **Memory Request:** 512Mi
- **Memory Limit:** 1Gi
- **Storage:** 10Gi PVC

**Rationale:**
- Dashboard rendering can be CPU-intensive
- Memory needed for query caching
- Storage for dashboard configs, user sessions, annotations

### Total Stack Resource Footprint
- **CPU Request:** 850m (~0.85 cores)
- **CPU Limit:** 3.5 cores
- **Memory Request:** 2.64Gi
- **Memory Limit:** 5.5Gi
- **Storage:** 70Gi

This ensures the observability stack uses **less than 10% of resources** on a typical 10-node cluster with 4 cores and 16GB RAM per node.

---

## Retention and Storage

### Prometheus Retention Policy

```yaml
--storage.tsdb.retention.time=15d   # Keep 15 days of data
--storage.tsdb.retention.size=45GB  # Max 45GB (90% of 50GB PVC)
```

**Why 15 days?**
- Long enough for post-incident analysis (most incidents analyzed within 7 days)
- Short enough to control storage costs
- Sufficient for weekly trend analysis
- Balances between retention and cardinality pressure

**Retention Calculation:**
```
Sample Rate: 50,000 samples/sec (typical for medium cluster)
Sample Size: ~1-2 bytes per sample (compressed)
Daily Data: 50k samples/sec × 86,400 sec × 1.5 bytes = ~6.5 GB/day
15-day retention: 6.5 GB × 15 = ~97.5 GB uncompressed
With compression (4:1): ~24 GB actual storage
```

**What happens when storage fills?**
1. Prometheus deletes oldest blocks first (time-based retention)
2. If size limit hit before time limit, oldest data dropped
3. Logs warning: `msg="Compaction failed" err="no space left on device"`
4. Alert fires: `PrometheusStorageLow` (when <15% free)

**Mitigation:**
- Alert fires at 15% free (~7.5GB remaining = ~1 day buffer)
- Increase PVC size via volume expansion (if storage class supports it)
- Reduce retention time temporarily: `kubectl exec` into pod, update flags, restart
- Export critical data to long-term storage (Thanos, Cortex, M3DB)

### Alertmanager Retention

```yaml
--data.retention=120h  # 5 days
```

Stores:
- Alert notification history
- Silences
- Inhibition state

**Low storage impact:** ~100MB typical, <1GB worst case

---

## Cardinality Management

### What is Cardinality?

**Cardinality** = Number of unique time series

Each unique combination of metric name + label set = one time series.

**Example:**
```
http_requests_total{method="GET", path="/api/users", status="200"}
http_requests_total{method="POST", path="/api/users", status="201"}
http_requests_total{method="GET", path="/api/orders", status="200"}
```
= 3 unique time series (3× cardinality)

### Cardinality Explosion

**Causes:**
1. **High-cardinality labels:** user_id, session_id, timestamp, UUID
2. **Unbounded label values:** IP addresses, email addresses, URLs
3. **Label proliferation:** Adding many labels to every metric
4. **Metric storms:** Rapid pod churn creating/destroying time series

**Example of BAD metric:**
```
# DON'T DO THIS
http_request_duration{user_id="user123456", request_id="uuid-abc-def-123"}
```

If you have 1M users and each makes 100 requests, that's 100M time series!

**What it looks like:**

**Symptoms:**
- Prometheus memory usage spikes (2Gi → 4Gi → OOM)
- Query latency increases (1s → 10s → timeout)
- Scrape duration increases, targets fail to scrape
- CPU usage spikes to limit
- Alert: `PrometheusHighMemory` fires
- Logs: `msg="head GC completed" duration=45s` (should be <1s)

**Prometheus behavior under cardinality explosion:**
1. Memory usage climbs rapidly
2. Queries slow down (more series to scan)
3. Scraping falls behind (backlog builds)
4. Eventually hits memory limit → OOM killed
5. Pod restarts, loads data from disk (slow)
6. Alert: `PodCrashLooping` fires for Prometheus itself

**Detection:**
```promql
# Check number of time series
prometheus_tsdb_symbol_table_size_bytes

# Check ingestion rate
rate(prometheus_tsdb_head_samples_appended_total[5m])

# Check memory usage per time series
process_resident_memory_bytes / prometheus_tsdb_head_series
```

**Mitigation in this stack:**

1. **Metric relabeling** (in `prometheus-config.yaml`):
```yaml
metric_relabel_configs:
  # Drop high-cardinality container network metrics
  - source_labels: [__name__]
    regex: 'container_network_.*'
    action: drop
  # Drop docker internal metrics
  - source_labels: [id]
    regex: '/docker/.*'
    action: drop
```

2. **ServiceMonitor relabeling** (in `sample-app-servicemonitor.yaml`):
```yaml
metricRelabelings:
  # Drop histogram buckets (keep count/sum only)
  - sourceLabels: [__name__]
    regex: 'http_request_duration_seconds_bucket'
    action: drop
  # Drop user_id labels
  - sourceLabels: [user_id]
    action: labeldrop
```

3. **Alert on high cardinality:**
```yaml
# Add this alert to prometheus-rules.yaml
- alert: HighCardinality
  expr: prometheus_tsdb_head_series > 1000000
  for: 10m
```

### Cardinality Best Practices

**DO:**
- Use low-cardinality labels: `status` (5 values), `method` (7 values), `endpoint` (dozens)
- Aggregate at query time: `sum by (status) (http_requests_total)`
- Use histograms for latency (not one series per latency value)

**DON'T:**
- Use user IDs, session IDs, request IDs as labels
- Use timestamps as labels
- Use unbounded text fields (error messages, URLs) as labels
- Create metrics in tight loops without deduplication

---

## Failure Mode Analysis

### 1. Prometheus is Down

**Scenario:** Prometheus pod crashes, is evicted, or deployment is deleted.

**What happens:**

**Metrics Collection:**
- ❌ **No metrics are being collected** (scraping stopped)
- ✅ Applications continue emitting metrics (but they're not stored)
- ✅ Metrics endpoints still respond to `/metrics` requests

**Alerting:**
- ❌ **No new alerts fire** (no evaluation happening)
- ❌ **Existing alerts do not resolve** (Alertmanager keeps firing based on last state)
- ⚠️ Alertmanager continues routing already-active alerts (repeat_interval)

**Dashboards:**
- ❌ **Grafana shows "No data"** for recent time ranges
- ✅ Historical data still available (if PVC intact)
- ❌ Real-time dashboards stop updating

**Failure Mode: Fail Open**

Prometheus downtime means **you are blind**:
- Incidents may go undetected
- Alerts don't fire for new problems
- Dashboards show stale data

**Detection:**
- Grafana dashboards stop updating
- Alert: `PrometheusTargetDown` fires (if you have a second Prometheus watching the first)
- PagerDuty/Slack stops receiving new alerts (silence is suspicious)

**Recovery:**
1. Prometheus pod restarts automatically (if using Deployment)
2. Loads TSDB from PVC (if storage intact)
3. Resumes scraping from current time
4. **Data gap:** Time when Prometheus was down is permanently lost

**Mitigation:**
- Use **Prometheus Operator** with automatic recovery
- Deploy **highly available Prometheus** (2+ replicas with Thanos sidecar)
- Implement **federated Prometheus** (central Prometheus scrapes regional Prometheus instances)
- Configure **external monitoring** to alert if Prometheus is down (e.g., Pingdom, Datadog)
- Use **remote write** to send metrics to long-term storage (Thanos, Cortex)

---

### 2. Alertmanager is Down

**Scenario:** Alertmanager pod crashes or deployment is deleted.

**What happens:**

**Alert Evaluation:**
- ✅ **Prometheus continues evaluating alerts**
- ✅ Alerts transition to `FIRING` state
- ❌ **Prometheus cannot send alerts** (Alertmanager unreachable)

**Notifications:**
- ❌ **No notifications sent** (no PagerDuty, Slack, email)
- ❌ Existing silences ignored (state lost if PVC lost)
- ❌ Grouping/inhibition stopped

**Logs in Prometheus:**
```
level=error msg="Notify for alerts failed" num_alerts=3 err="Post \"http://alertmanager:9093/api/v1/alerts\": dial tcp: lookup alertmanager on 10.96.0.10:53: no such host"
```

**Failure Mode: Fail Closed (Silent)**

Alertmanager downtime means **you won't be notified**:
- Critical incidents occur without paging
- Prometheus UI shows firing alerts (but no one checks it proactively)
- Silent failure (most dangerous)

**Detection:**
- Prometheus logs show repeated errors sending alerts
- No alerts received in Slack/PagerDuty (absence of noise)
- Alert: `PrometheusTargetDown` for Alertmanager itself
- Alert: Prometheus `DeadMansSwitch` stops firing (see below)

**DeadMansSwitch Pattern:**
```yaml
# Alert that ALWAYS fires - proves Alertmanager is working
- alert: DeadMansSwitch
  expr: vector(1)
  labels:
    severity: none
  annotations:
    summary: "Alertmanager is working (this alert always fires)"
```

If you stop receiving the DeadMansSwitch alert, Alertmanager is down.

**Recovery:**
1. Alertmanager pod restarts
2. Loads silences from PVC (if storage intact)
3. Prometheus reconnects and sends backlog of alerts
4. Notifications resume

**Mitigation:**
- Deploy **HA Alertmanager** (3+ replicas with gossip protocol)
- Configure **DeadMansSwitch** to external service (PagerDuty heartbeat)
- Use **multiple Alertmanager instances** (Prometheus can send to multiple)
- Set up **external dead man's switch** (e.g., Cronitor, Pingdom heartbeat)

---

### 3. Grafana is Down

**Scenario:** Grafana pod crashes or deployment is deleted.

**What happens:**

**Metrics & Alerts:**
- ✅ **Prometheus continues collecting metrics**
- ✅ **Alertmanager continues routing alerts**
- ✅ All backend functionality intact

**Dashboards:**
- ❌ **Cannot view dashboards** (UI unreachable)
- ✅ Data still being collected (can query later)

**Failure Mode: Least Critical**

Grafana downtime means **you can't visualize**, but:
- Metrics are still collected
- Alerts still fire
- You can query Prometheus directly: `kubectl port-forward -n monitoring svc/prometheus 9090:9090`

**Recovery:**
1. Grafana pod restarts
2. Loads dashboards from ConfigMaps
3. Reconnects to Prometheus
4. Historical data available immediately

**Mitigation:**
- Grafana is the **least critical component** (doesn't impact data collection or alerting)
- Can access Prometheus UI directly as fallback
- Can query Prometheus API with `curl`

---

### 4. Network Partition

**Scenario:** Prometheus pod cannot reach some targets (network policy, node failure).

**What happens:**

**Scrape Success:**
- ✅ **Reachable targets continue being scraped**
- ❌ **Unreachable targets show `up=0`**
- ⚠️ Last scraped values retained (stale markers added after 5 minutes)

**Alerting:**
- ✅ Alert: `PrometheusTargetDown` fires for unreachable targets
- ⚠️ Alerts based on unreachable targets show stale data
- ❌ May miss incidents on partitioned nodes

**Mitigation:**
- Monitor `up` metric to detect scrape failures
- Deploy Prometheus with host networking (if needed)
- Use **node-local scraping** for critical metrics
- Federation to handle network segments

---

### 5. Disk Full (Prometheus PVC)

**Scenario:** Prometheus storage PVC reaches 100% capacity.

**What happens:**

**Storage:**
- ❌ **Cannot write new samples** (compaction fails)
- ✅ Existing data readable (queries still work on old data)
- ❌ Scraping continues but data discarded

**Logs:**
```
level=error msg="Compaction failed" err="no space left on device"
```

**Behavior:**
- Prometheus **does not crash** (continues running)
- **Silently drops data** (no errors to targets)
- Queries return stale data

**Mitigation:**
- Alert: `PrometheusStorageLow` fires at 85% full
- **Volume expansion** (if storage class supports)
- Reduce `--storage.tsdb.retention.time`
- Delete old data: `curl -X POST http://prometheus:9090/api/v1/admin/tsdb/delete_series?match[]={__name__=~".+"}`

---

## Alert Routing Failure Scenarios

### Scenario 1: PagerDuty API Down

**Configuration:**
```yaml
pagerduty_configs:
  - service_key: 'YOUR_KEY'
```

**Failure:** PagerDuty API returns 5xx errors.

**Behavior:**
- Alertmanager **retries** with exponential backoff
- Logs error but **continues trying**
- ❌ **No notifications sent**

**Failure Mode: Fail Closed**

**Detection:** DeadMansSwitch stops paging

**Mitigation:** Multiple receivers (PagerDuty + Slack)

### Scenario 2: Slack Webhook Revoked

**Configuration:**
```yaml
slack_configs:
  - webhook_url: 'https://hooks.slack.com/...'
```

**Failure:** Slack webhook returns 404 (deleted webhook).

**Behavior:**
- Alertmanager logs error
- **Stops trying** (doesn't retry 404)
- ❌ **No Slack notifications**
- ✅ Other receivers still work

**Failure Mode: Partial Fail Closed**

**Mitigation:** Test webhook periodically, use multiple channels

### Scenario 3: Alertmanager Silences

**User silences:** `alertname="PodCrashLooping"`

**Effect:**
- ❌ **No notifications for matching alerts**
- ✅ Alerts still fire in Prometheus
- ✅ Visible in Prometheus Alerts page (but marked silenced)

**Failure Mode: Intentional Fail Closed**

**Risk:** Silence expires but no one notices → incidents missed

**Mitigation:**
- Silence expiry notifications
- Regularly audit active silences
- Require comments on silences

---

## Query Performance

### What happens during high query load?

**Scenario:** Many Grafana users load dashboards simultaneously.

**Prometheus behavior:**
1. Query queue builds up
2. CPU usage increases
3. Query latency increases (1s → 5s → 30s)
4. Queries timeout (30s default)
5. Dashboards show "Query timeout" errors

**Scraping impact:**
- ✅ **Scraping continues** (separate goroutine pool)
- ⚠️ Under extreme load, scraping can be delayed

**Mitigation:**
- Set query timeout: `--query.timeout=30s`
- Limit concurrent queries: `--query.max-concurrency=20`
- Use query result caching in Grafana
- Optimize dashboard queries (avoid `rate(metric[1h])` over large ranges)

---

## Configuration Reload

### Prometheus Config Reload

**How:**
```bash
kubectl exec -n monitoring prometheus-xxx -- curl -X POST http://localhost:9090/-/reload
```

Or use `--web.enable-lifecycle` flag (already configured).

**What reloads:**
- Scrape configs
- Alert rules
- Recording rules

**What does NOT reload:**
- Storage retention settings (requires restart)
- Command-line flags (requires restart)

**Behavior during reload:**
- ✅ **Scraping continues** (no interruption)
- ✅ **Queries continue** (no downtime)
- ⚠️ Brief pause in alert evaluation (~1s)

---

## Summary Table: Failure Modes

| Component | Impact on Metrics | Impact on Alerts | Impact on Dashboards | Failure Mode |
|-----------|-------------------|------------------|---------------------|--------------|
| **Prometheus down** | ❌ Lost (gap) | ❌ No new alerts | ❌ No data | **Fail Open** (blind) |
| **Alertmanager down** | ✅ Collected | ❌ No notifications | ✅ Working | **Fail Closed** (silent) |
| **Grafana down** | ✅ Collected | ✅ Still firing | ❌ No UI | Non-critical |
| **Prometheus disk full** | ❌ Lost (dropped) | ⚠️ Stale data | ⚠️ Stale data | **Fail Open** (blind) |
| **Network partition** | ⚠️ Partial loss | ⚠️ Partial | ⚠️ Partial | Partial blind |
| **PagerDuty API down** | ✅ Collected | ❌ No pages | ✅ Working | **Fail Closed** |
| **High query load** | ✅ Collected | ✅ Still firing | ⚠️ Timeouts | Degraded UX |

## Operational Recommendations

### 1. Monitor the Monitors

**Deploy a second Prometheus** to watch the first:
```yaml
# In second Prometheus
scrape_configs:
  - job_name: 'prometheus-primary'
    static_configs:
      - targets: ['prometheus.monitoring.svc:9090']
```

Alert if primary Prometheus is down.

### 2. DeadMansSwitch

Always-firing alert to prove alerting pipeline works:
```yaml
- alert: DeadMansSwitch
  expr: vector(1)
  annotations:
    summary: "Alerting pipeline is healthy"
```

Send to PagerDuty heartbeat or similar service.

### 3. Cardinality Budget

Set a budget and alert when approached:
```yaml
- alert: CardinalityBudgetExceeded
  expr: prometheus_tsdb_head_series > 800000  # 80% of 1M limit
  for: 10m
```

### 4. Regular Backups

Snapshot Prometheus data periodically:
```bash
# Create snapshot
curl -X POST http://prometheus:9090/api/v1/admin/tsdb/snapshot

# Backup PVC
kubectl cp monitoring/prometheus-xxx:/prometheus/snapshots/xxx ./backup/
```

### 5. Runbooks

Every alert should have:
- `runbook_url`: Link to investigation steps
- `dashboard_url`: Link to relevant Grafana dashboard
- Clear severity labels

### 6. Test Failure Scenarios

Quarterly chaos engineering:
1. Kill Prometheus pod → verify auto-recovery
2. Fill Prometheus disk → verify alert and recovery
3. Break Alertmanager config → verify DeadMansSwitch catches it
4. Revoke Slack webhook → verify fallback to PagerDuty

---

## Scaling Considerations

### When to Scale Prometheus

**Scale up (increase resources) when:**
- Cardinality consistently > 800k time series
- Query latency > 5s for typical queries
- Scrape duration > 30s
- Memory usage consistently near limit

**Scale out (horizontal) when:**
- Single Prometheus cannot handle load
- Need cross-region monitoring
- Need high availability

**Horizontal Scaling Options:**
1. **Federation:** Central Prometheus scrapes from regional Prometheus instances
2. **Prometheus Operator + Thanos:** HA setup with long-term storage
3. **Cortex:** Multi-tenant Prometheus-as-a-Service
4. **M3DB:** Distributed time-series database

---

## Conclusion

This observability stack is production-ready with:
- ✅ Resource limits to prevent cluster starvation
- ✅ Persistent storage with sensible retention
- ✅ Cardinality management to prevent explosions
- ✅ Critical alerts for common failure modes
- ✅ Clear understanding of failure modes

**Key Takeaways:**
1. **Prometheus down = Fail Open** (you're blind)
2. **Alertmanager down = Fail Closed** (silent failure - most dangerous)
3. **Cardinality explosions kill Prometheus** (manage labels carefully)
4. **Monitor the monitors** (DeadMansSwitch, secondary Prometheus)
5. **Resource limits prevent cascade failures** (observe ability shouldn't kill the cluster)
