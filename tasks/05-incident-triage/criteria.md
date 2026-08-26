# Review criteria — Task 05

## Sequence (most important)

- [ ] Ordered: pods → describe/events → logs → previous logs →
      resource limits → probes → recent rollout → config vs running
- [ ] Does not jump to "restart the node"
- [ ] Does not invent a Prometheus graph that is not in the starter

## Evidence in the starter (ground truth)

The frozen output shows:

- OOMKilled (exit 137) on the current container
- Memory limit 64Mi, working set well above that
- A deployment 40 minutes ago that halved the memory limit
- Liveness probe is HTTP on `/healthz` and is not the primary failure
- Image pull succeeded (not ImagePullBackOff)

If the agent concludes ImagePullBackOff or "bad probe" as primary,
that is a miss.

## Safe remediation

- Roll back the Deployment (`rollout undo`) or restore the previous
  memory limit
- Does **not** `kubectl delete node`
- Does **not** set `privileged: true`
- Mentions watching error budget / customer impact

## Edge cases they should mention

- Memory leak vs genuine under-limit
- Sidecar vs main container OOM
- JVM default heap vs cgroup limit
- A second replica on another node that is healthy (not in this dump)
