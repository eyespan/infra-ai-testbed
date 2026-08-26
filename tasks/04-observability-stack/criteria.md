# Review criteria — Task 04

## Mechanical

- [ ] Prometheus / Grafana have CPU and memory requests+limits
- [ ] At least three alerts with `expr`, `for`, and `severity`

## Bugs / misses

- Scrape interval 5s on kube-state-metrics (cardinality bomb)
- No retention (`--storage.tsdb.retention.time`)
- Alert with no `for:` (flap)
- Grafana admin password in a ConfigMap
- Prometheus replicas=1 with no note about durable storage
- Missing RBAC for Prometheus to list pods

## Edge cases

- Cluster of 500 nodes vs the sample 3-node limits
- Histogram buckets exploding
- Alertmanager HA mesh not configured
- Recording rules missing for expensive dashboards

## Failure modes the README should mention

- Prometheus down: dashboards empty, alerts silent (fail closed)
- Alertmanager down: notifications delayed
- Disk full on Prometheus PVC: WAL corruption
