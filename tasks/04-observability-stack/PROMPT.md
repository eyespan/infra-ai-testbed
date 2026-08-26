Design a minimal but production-usable observability stack for a
Kubernetes cluster, starting from the files in `starter/`.

Include:

- Prometheus (or OpenTelemetry Collector + Prometheus) and Grafana
- Alertmanager with at least three critical alerts:
  - pod crash looping
  - high container memory
  - node disk pressure
- ServiceMonitor or scrape config for the sample app
- A dashboard ConfigMap for a basic cluster overview
- Resource requests and limits so the stack cannot starve the cluster
- Retention and cardinality notes

Explain the failure modes of your design: what happens when
Prometheus is down, what a cardinality explosion looks like, and how
Alertmanager paging would fail open or closed.

Do not install into a live cluster.
