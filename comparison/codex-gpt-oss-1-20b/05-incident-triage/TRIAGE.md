# Payments CrashLoopBackOff triage

## Scope and assumptions

This assessment uses only the frozen files in `starter/`. I would not modify a
cluster or assume unrecorded events, logs, metrics, configuration, node state,
or customer impact. The supplied timestamps place the rollout and restart
onset about 40 minutes before the snapshot.

## Triage sequence

1. **Establish the workload and symptom**

   - **Run/read:** `kubectl get pods -n prod -l app=payments -o wide`; read
     `starter/kubectl-get-pods.yaml`.
   - **Signal sought:** readiness, state, restart trajectory, age, and whether
     another replica is available.
   - **Conclusion/next action:** The displayed `payments` pod is `0/1`, in
     `CrashLoopBackOff`, and has restarted 12 times during its 40-minute life.
     The dump shows only one replica, so it provides no evidence of a healthy
     alternative. Inspect its termination state and events.

2. **Identify the direct failure and rule out basic platform causes**

   - **Run/read:** `kubectl describe pod payments-7f9c4d6b8-xk2nq -n prod`;
     read `starter/kubectl-describe-pod.txt`.
   - **Signal sought:** last state/exit code, events, scheduling and image-pull
     outcomes, probes, and which container failed.
   - **Conclusion/next action:** The `payments` container was `OOMKilled` with
     exit code 137. It was successfully scheduled and pulled, so this is not
     an image-pull or scheduling failure. Events show restart backoff, not
     liveness failure. Read the application logs, especially the last
     terminated instance.

3. **Inspect current and previous container logs**

   - **Run/read:** `kubectl logs -n prod payments-7f9c4d6b8-xk2nq -c payments`
     and `kubectl logs -n prod payments-7f9c4d6b8-xk2nq -c payments --previous`;
     read `starter/kubectl-logs.txt`.
   - **Signal sought:** startup/configuration errors, an orderly exit, memory
     pressure, or probe endpoint failures. `--previous` matters because the
     current container is waiting in a crash loop.
   - **Conclusion/next action:** The supplied output shows successful startup
     and Postgres connection, then `heap approaching limit` at `rss_mb: 61`,
     followed by termination. It corroborates the OOM evidence. The frozen file
     does not identify whether this was current or previous output, so I draw
     no conclusion from missing lines. Compare this with resource limits and
     runtime settings.

4. **Check effective resource limits and runtime memory settings**

   - **Run/read:** `kubectl get pod payments-7f9c4d6b8-xk2nq -n prod -o yaml`
     and `kubectl get deployment payments -n prod -o yaml`; read
     `starter/kubectl-describe-pod.txt` and `starter/deployment.yaml`.
   - **Signal sought:** effective limit versus observed use, request/limit
     changes, and heap settings that can exceed the cgroup limit.
   - **Conclusion/next action:** Both desired Deployment and described pod set
     a 64Mi request and limit. RSS at 61Mi is near that ceiling, while
     `NODE_OPTIONS` permits a 256Mi old-space heap. This is an unsafe mismatch
     and explains the OOM; RSS is not expected to equal heap exactly. Examine
     probes independently before correlating with the rollout.

5. **Assess probes separately from the OOM**

   - **Run/read:** read the probe and Events sections of
     `starter/kubectl-describe-pod.txt` and `starter/deployment.yaml`.
   - **Signal sought:** `Unhealthy`/liveness failure events, endpoint details,
     and whether timing supports a probe-triggered restart.
   - **Conclusion/next action:** Liveness is HTTP `GET :8080/healthz` with a
     displayed 10-second initial delay; readiness is `GET :8080/ready`. There
     is no probe-failure event, and the recorded process lifetime is eight
     seconds. Probes could affect availability but are not the primary failure
     in this evidence. Check recent rollout history and config versus running.

6. **Correlate the rollout and compare desired versus running configuration**

   - **Run/read:** `kubectl rollout history deployment/payments -n prod`,
     `kubectl get deployment payments -n prod -o yaml`, and `kubectl get pod
     payments-7f9c4d6b8-xk2nq -n prod -o yaml`; read the corresponding frozen
     rollout, Deployment, and describe files.
   - **Signal sought:** revision/change cause, timing, and whether the pod is
     actually running the desired template rather than a stale/manual variant.
   - **Conclusion/next action:** Revision 14 explicitly reduced memory to 64Mi
     to save cost; revision 13 used 256Mi. The pod is revision 14 and reports
     the same 64Mi limit as its Deployment. The restart onset coincides with
     that rollout, making it the strongest causal change. Prepare a reversible
     rollback and watch recovery/customer impact.

## Most likely root cause

Revision 14 reduced the `payments` container limit from 256Mi to 64Mi, causing
an OOM kill (`OOMKilled`, exit 137) and therefore kubelet restart backoff. The
application's 61Mi RSS warning and 256Mi Node old-space setting reinforce that
the limit is insufficient. `CrashLoopBackOff` is the outcome, not the root
cause.

## Safe remediation and rollback path

1. Record the active revision and assess customer payment failures and
   error-budget burn through the approved incident process. Do not restart
   nodes or delete pods: neither fixes the resource mismatch.
2. Subject to normal change approval, restore the known prior template:

   ```sh
   kubectl rollout undo deployment/payments -n prod
   kubectl rollout status deployment/payments -n prod --timeout=5m
   ```

   The history indicates this returns to revision 13's 256Mi request/limit.
3. Verify replacement-pod readiness and stopped restarts with `kubectl get
   pods -n prod -l app=payments` and `kubectl describe pod ...`; continuously
   watch approved customer-impact and error-budget indicators. None are in the
   frozen data.
4. If rollout undo is unavailable, make the smallest reviewed Deployment change
   restoring the known 256Mi value, preserve the change record, and wait for
   rollout completion. Do not raise limits blindly beyond cluster capacity.
5. If the rollback causes a distinct regression, use the approved forward/
   rollback procedure to return to revision 14, document it, and pause further
   changes pending investigation.

After stabilization, collect memory data under normal and peak load, select
requests and limits from that evidence, and align the Node heap cap with the
cgroup limit while leaving runtime headroom.

## Edge cases that would change the diagnosis

- A memory leak could make 256Mi a temporary mitigation; growth over time
  rather than this immediate startup pattern would point there.
- A sidecar could be the OOM victim or consume pod-level memory. This dump
  shows only `payments`, but a fuller manifest would need separate review.
- JVM default heap behavior versus a cgroup limit could be decisive for a Java
  workload. This workload shows Node settings, but the runtime/cgroup mismatch
  principle is the same.
- A healthy second replica on another node would change impact assessment and
  could expose node-specific behavior; none appears in this dump.
- A later probe-failure event, configuration-driven allocation spike, or a
  confirmed application exit before the OOM would require reassessing cause.

## What remains unknown

- Actual working-set history, allocation profile, peak traffic, and whether
  256Mi is appropriate long-term.
- Output explicitly obtained with `kubectl logs --previous` beyond the supplied
  excerpt.
- Customer impact, error-budget burn, and service-level indicators.
- Whether revision 13 was healthy at comparable load and its complete template.
- Cluster capacity, quota/LimitRange effects, node pressure, and admission
  constraints on restoring the prior resources.
