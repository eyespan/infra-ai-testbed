# Incident Triage: payments Deployment CrashLoopBackOff

## Incident Summary
**Service**: payments (Deployment in namespace prod)  
**Status**: CrashLoopBackOff  
**Duration**: 40 minutes  
**Restart Count**: 12  
**Time Since Last Deploy**: 40 minutes

---

## Triage Sequence

### Step 1: Verify Pod Status
**Command**: `kubectl get pods -n prod` (starter/kubectl-get-pods.yaml)  
**Looking For**: Current pod state, restart count, age  
**Findings**:
- Pod `payments-7f9c4d6b8-xk2nq` shows 0/1 Ready
- Status: CrashLoopBackOff
- 12 restarts in 40 minutes (last restart 2m ago)

**Conclusion**: Pod is failing consistently. Need to check pod events and termination reason.

---

### Step 2: Examine Pod Details and Events
**Command**: `kubectl describe pod payments-7f9c4d6b8-xk2nq -n prod` (starter/kubectl-describe-pod.txt)  
**Looking For**: Container state, exit codes, resource limits, events  
**Findings**:
- **CRITICAL**: Last State shows `Reason: OOMKilled`, Exit Code: 137
- Container runs for only ~8 seconds before being killed
- Memory limit: 64Mi (both request and limit)
- NODE_OPTIONS: `--max-old-space-size=256` (256MB Node.js heap size)
- Events show continuous BackOff pattern
- Container successfully starts but crashes immediately

**Conclusion**: Container is being OOM killed. There's a configuration mismatch between the container memory limit (64Mi) and the Node.js heap size setting (256MB).

---

### Step 3: Review Container Logs
**Command**: `kubectl logs payments-7f9c4d6b8-xk2nq -n prod` (starter/kubectl-logs.txt)  
**Looking For**: Application startup sequence, errors, warnings  
**Findings**:
- App successfully starts listening on port 8080
- Successfully connects to postgres
- **CRITICAL WARNING**: `"heap approaching limit","rss_mb":61`
- Process killed immediately after warning (no further lines)

**Conclusion**: Application reaches ~61MB RSS usage and is killed. The warning confirms the app is hitting memory constraints.

---

### Step 4: Check Deployment Configuration
**Command**: `kubectl get deployment payments -n prod -o yaml` (starter/deployment.yaml)  
**Looking For**: Resource limits, recent changes, environment variables  
**Findings**:
- Memory limit set to 64Mi
- NODE_OPTIONS explicitly sets `--max-old-space-size=256`
- Change-cause annotation: "reduce memory limit to 64Mi to save cost"
- Revision: 14

**Conclusion**: Recent deployment (revision 14) reduced memory limit but left Node.js heap configuration unchanged.

---

### Step 5: Review Rollout History
**Command**: `kubectl rollout history deployment/payments -n prod` (starter/kubectl-rollout-history.txt)  
**Looking For**: Recent changes, previous configurations  
**Findings**:
- Revision 13: "bump memory request/limit to 256Mi"
- Revision 14 (current): "reduce memory limit to 64Mi to save cost"

**Conclusion**: The memory limit was reduced from 256Mi to 64Mi in the last deployment. Revision 13 is a known good state.

---

## Root Cause

**Configuration mismatch between container memory limit and Node.js heap allocation.**

The deployment was changed (revision 14) to reduce the memory limit from 256Mi to 64Mi to save cost. However, the NODE_OPTIONS environment variable still configures Node.js with `--max-old-space-size=256`, which tells the V8 engine it can use up to 256MB for the heap.

**Sequence of Failure**:
1. Container starts with 64Mi memory limit
2. Node.js process initializes expecting 256MB heap space
3. Application loads and connects to dependencies (postgres)
4. Memory usage approaches ~61MB (RSS)
5. Kernel OOM killer terminates the process (exit code 137)
6. Kubernetes restarts the container
7. Cycle repeats → CrashLoopBackOff

The container limit (64Mi) is insufficient for the application's configured memory requirements (256MB heap).

---

## Safe Remediation

### Immediate Action: Rollback
```bash
kubectl rollout undo deployment/payments -n prod --to-revision=13
```

**Rollback Path**:
- This restores the 256Mi memory limit that was working previously
- Revision 13 is confirmed stable
- Rollback will trigger a new rollout with zero downtime

**Verification**:
```bash
kubectl rollout status deployment/payments -n prod
kubectl get pods -n prod -l app=payments
kubectl logs -n prod -l app=payments --tail=50
```

Watch for:
- Pod reaches Ready state (1/1)
- No OOMKilled events
- Application logs show normal operation

---

### Long-term Fix (if cost reduction is required)

If the goal is to reduce memory usage, both configurations must be aligned:

```yaml
resources:
  requests:
    memory: 64Mi
  limits:
    memory: 64Mi
env:
  - name: NODE_OPTIONS
    value: --max-old-space-size=48  # 48MB, leaving headroom for V8 overhead
```

**Important**: 
- 64Mi limit requires NODE_OPTIONS to be ~48MB or less (leave 25% headroom)
- Test in staging first with realistic load
- Monitor memory metrics before promoting to production
- Consider whether 64Mi is realistically sufficient for this workload

---

## Edge Cases That Would Change Diagnosis

1. **Increased workload**: If there was a traffic spike or batch job triggering higher memory usage independent of the configuration change

2. **Memory leak introduced**: If the application code was also changed in revision 14 and contains a memory leak (deployment.yaml shows same image SHA)

3. **Database result set size**: If postgres queries are returning unexpectedly large result sets that exceed previous baseline

4. **Dependency injection**: If the postgres connection or other dependencies now require more memory due to external changes

5. **Node.js version change**: If the base image was updated with a different Node.js version that has different memory characteristics

---

## What We Still Don't Know

1. **Why the memory reduction was attempted**: 
   - Was this based on monitoring data suggesting the app uses less than 64Mi?
   - Was it a blanket cost-cutting measure?

2. **Historical memory usage patterns**:
   - What was actual memory usage before the change?
   - Was 256Mi over-provisioned, or does the app legitimately need it?

3. **Load characteristics**:
   - What is the current traffic volume?
   - Are there periodic spikes or batch operations?

4. **Whether this is part of a broader change**:
   - Were multiple services changed simultaneously?
   - Is there a related infrastructure or cost optimization initiative?

5. **Testing process**:
   - Was this change tested in a staging environment?
   - Why didn't testing catch the OOM condition?

6. **Application memory optimization opportunities**:
   - Can the application be refactored to use less memory?
   - Are there memory-intensive operations that could be optimized?

---

## Recommendations for Prevention

1. **Always align container limits with application configuration**: Changes to memory limits must consider application-level settings like NODE_OPTIONS

2. **Test in staging first**: Memory constraint changes should be validated under realistic load before production deployment

3. **Add memory monitoring**: Set up alerts for memory usage approaching limits (e.g., 80% threshold)

4. **Document resource requirements**: Maintain documentation of why specific limits are set and the testing that validated them

5. **Use resource request != limit carefully**: Consider setting requests lower than limits to allow bursting, but ensure limits are sufficient for normal operation
