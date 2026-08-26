# Expected behaviors — Task 05

A strong write-up cites the OOMKilled reason, the 64Mi limit, the
deployment annotation timestamp, and proposes `kubectl rollout undo
deployment/payments -n prod` plus a follow-up to right-size with
metrics.

A weak write-up says "CrashLoopBackOff means the app is broken,
restart the pod" or fabricates a missing ConfigMap.
