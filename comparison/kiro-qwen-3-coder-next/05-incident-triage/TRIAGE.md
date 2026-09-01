# Incident Triage: payments Deployment (prod namespace)

## Initial Alert

**Observation**: `kubectl get pods` shows `payments-7f9c4d6b8-xk2nq` at `0/1 Ready` in `CrashLoopBackOff` with 12 restarts over 40 minutes.

**Signal**: The restart count is climbing, indicating repeated container failures.

**Conclusion**: The container is failing repeatedly. Need to determine the root cause of the failures.

---

## Step 1: Pod Status and Events

**Command**: `kubectl describe pod payments-7f9c4d6b8-xk2nq -n prod`

**Signal**: Last State shows `Terminated` with `Reason: OOMKilled` and `Exit Code: 137`.

**Conclusion**: The container was terminated by the kernel OOM killer. Exit code 137 is the standard signal for OOM (128 + 9 = SIGKILL). This is not a crash in the application code—it's an infrastructure-level termination.

---

## Step 2: Container Logs

**Command**: `kubectl logs payments-7f9c4d6b8-xk2nq -n prod`

**Signal**: The last log lines show:
```
{"level":"info","msg":"listening","port":8080}
{"level":"info","msg":"connected to postgres"}
{"level":"warn","msg":"heap approaching limit","rss_mb":61}
<no further lines — process killed>
```

**Conclusion**: The application was functioning correctly (listening, connected to postgres) but was killed while reporting that the heap was approaching its limit at 61MB. The process was killed abruptly, consistent with OOM termination.

---

## Step 3: Resource Limits

**Source**: `kubectl describe pod` output shows:
```
Limits:
  cpu:     500m
  memory:  64Mi
Requests:
  cpu:     100m
  memory:  64Mi
```

**Signal**: The memory limit is 64Mi, but the logs show the process was using 61MB of RSS heap alone. Additionally, `deployment.yaml` contains:
```yaml
env:
  - name: NODE_OPTIONS
    value: --max-old-space-size=256
```

**Conclusion**: The memory limit (64Mi) is insufficient for the application's configured heap size (256MB). The Node.js process is configured to use up to 256MB of old space, but the container's memory limit is only 64Mi. When the heap approaches 61MB (already near the 64Mi limit), the kernel OOM killer terminates the process.

---

## Step 4: Recent Deployment Changes

**Command**: `kubectl rollout history deployment/payments -n prod`

**Signal**: Revision 14 (40 minutes ago) has change-cause: "reduce memory limit to 64Mi to save cost"

**Conclusion**: The memory limit was recently reduced from 256Mi (Revision 13) to 64Mi. This change introduced the OOM condition. The timing aligns with the pod starting to fail (40 minutes ago).

---

## Root Cause

**Most likely root cause**: The deployment was updated 40 minutes ago to reduce the memory limit from 256Mi to 64Mi. The application is configured with `--max-old-space-size=256` (256MB), and its heap is growing beyond the 64Mi container limit. The kernel OOM killer terminates the process, causing CrashLoopBackOff.

**Why not other common causes?**

- **Image pull failure**: `kubectl describe pod` shows "Successfully pulled image"—no ImagePullBackOff.
- **Liveness probe failure**: The liveness probe is HTTP on `/healthz` and would show probe failures in events. The actual termination reason is OOMKilled.
- **ConfigMap/Secret missing**: No such events in the pod description.
- **Node issues**: Only this pod is affected; no indication of node-wide problems.

---

## Safe Remediation

### Immediate Fix: Rollback to Previous Revision

```bash
kubectl rollout undo deployment/payments -n prod
```

This will revert to Revision 13, which had a 256Mi memory limit.

### Alternative: Restore Memory Limit Without Full Rollback

If you want to keep the current revision but fix the memory limit:

```bash
kubectl set resources deployment/payments -n prod \
  --limits=memory=256Mi \
  --requests=memory=256Mi
```

### Rollback Path

The rollout history shows Revision 13 was the last known good revision. Rolling back to it is safe because:
1. It was working for some period before Revision 14
2. Kubernetes maintains rollback history
3. The change is reversible (we can revisit the 64Mi decision with proper metrics)

---

## Edge Cases That Would Change Diagnosis

1. **Memory leak vs genuine under-limit**: If rolling back doesn't resolve the issue, the application may have a memory leak that only became apparent after the limit reduction.

2. **Sidecar vs main container OOM**: The current pod only has the `payments` container. If sidecars were added (e.g.,istio proxy), they could contribute to memory pressure.

3. **JVM default heap vs cgroup limit**: The application is Node.js, not JVM. For JVM apps, the default heap is often 1/4 of container memory, which could cause OOM even below the limit.

4. **A second healthy replica**: This is the only replica shown. If there were additional replicas on other nodes that are healthy, it would suggest node-specific resource pressure rather than a deployment-wide issue.

5. **Memory overcommitment**: Some clusters allow memory overcommitment where containers can exceed limits briefly before OOM. The clean OOMKilled exit suggests strict enforcement.

---

## What We Still Do Not Know

1. **Memory usage trend**: We don't have historical metrics to see if memory usage was gradually increasing or if there was a recent spike.

2. **Application traffic patterns**: We don't know if memory usage correlates with request volume or specific endpoints.

3. **GC behavior**: Node.js garbage collection patterns affect heap growth. We don't have GC logs.

4. **Other containers in the pod**: If there were sidecars (not visible in the current `deployment.yaml`), their memory usage could contribute to the 64Mi limit.

5. **Error budget impact**: We don't know the service's SLO/error budget status or customer impact level.

6. **Future traffic growth**: We don't know if 256Mi was historically sufficient or if traffic growth necessitated a different approach.

---

## Post-Incident Actions

1. **Right-size with metrics**: Add memory metrics to Grafana/Datadog to establish baseline usage.

2. **Implement autoscaling**: Consider Horizontal Pod Autoscaler (HPA) based on memory utilization.

3. **Add alerts**: Configure alerts for memory utilization > 80% of limit.

4. **Review deployment process**: Implement resource limit validation in CI/CD (e.g., with OPA/Gatekeeper or Kyverno policies).

5. **Document cost-quality tradeoff**: Establish a process for evaluating cost savings vs. reliability when reducing resource limits.