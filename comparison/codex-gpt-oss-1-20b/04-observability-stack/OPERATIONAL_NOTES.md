# Operational notes and failure modes

## Scope and assumptions

This is a minimal, single-replica stack for a small cluster, not an HA control
plane. The `payments` Service is assumed to be in `prod`, labelled
`app: payments`, and to expose a named `metrics` port. The ServiceMonitor is
for a Prometheus Operator installation; this standalone Prometheus instead
uses the equivalent restricted endpoint scrape in `prometheus-config.yaml`.
Secrets `grafana-admin` (`admin`) and `alertmanager-pagerduty`
(`pagerduty-routing-key`) must be provisioned outside this repository.

## Capacity, retention, and cardinality

Prometheus retains 15 days or 45 GB on a 50 Gi PVC, whichever limit is reached
first. The 2–4 Gi Prometheus allocation is a starting point for roughly a
three-node cluster; it is not a 500-node sizing claim. At 500 nodes, shard or
federate Prometheus, increase storage/retention based on measured ingest, and
load-test API-proxy/kubelet scraping before rollout.

The app scrape is every 30 seconds and only targets the selected payments
Service. Do not add user IDs, request IDs, pod UIDs, container IDs, image
digests, unbounded URLs, or raw error text as metric labels. A cardinality
explosion appears as rapidly increasing head-series count, memory, compaction
and query latency, then WAL/disk pressure and missed scrapes. Histogram bucket
counts multiply every label combination; use a small, reviewed bucket set.
The recording rule exists so the overview dashboard does not repeatedly run a
cluster-wide container-memory aggregation.

## Failure modes and response

- **Prometheus unavailable:** Grafana has stale or empty panels and Prometheus
  rules do not evaluate, so new alerts are silent (fail closed). Alertmanager
  cannot create missing alerts. Alert on Prometheus availability from an
  independent platform monitor and retain a runbook/data-source fallback.
- **Prometheus PVC full or corrupt:** WAL writes/compaction can fail, recent
  data may be lost, and restart recovery can be slow or fail. The size cap
  leaves headroom below PVC capacity; page on volume use and restore from a
  tested snapshot rather than deleting WAL files ad hoc.
- **Alertmanager unavailable:** Prometheus continues evaluating rules but
  notifications queue only while it is reachable; active paging is delayed or
  absent. This one-replica design has no Alertmanager HA mesh and uses
  `emptyDir`, so silences and notification log are lost on reschedule. A
  production HA upgrade uses a StatefulSet, persistent volumes, a headless
  service, and two or more mesh peers.
- **Pager receiver/secret failure:** Alertmanager cannot deliver critical pages
  (fail closed), which is safer than claiming notification succeeded. Monitor
  Alertmanager delivery failures and use an independently configured secondary
  receiver for high-severity incidents.
- **Kubernetes API proxy or RBAC failure:** kubelet cAdvisor scrapes fail, so
  memory alerts have missing data. Prometheus target-health alerts and periodic
  permission checks should detect this; do not weaken RBAC or use unauthenticated
  kubelet endpoints as a workaround.

No manifests were installed or connected to a live cluster.
