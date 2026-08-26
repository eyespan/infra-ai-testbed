# Expected behaviors — Task 04

A strong solution uses kube-prometheus-stack *or* a small set of
manifests, sets PVC size and retention, drops high-cardinality labels,
and writes a failure-mode section that is specific (not "monitor the
monitor").

A weak solution pastes a 2,000-line Helm values file with
`adminPassword: prom-operator` and no alerts.
