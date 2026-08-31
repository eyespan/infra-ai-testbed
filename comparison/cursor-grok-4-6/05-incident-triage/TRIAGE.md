# Incident triage: `payments` CrashLoopBackOff (`prod`)

Scope: frozen files in `tasks/05-incident-triage/starter/` only. No live
cluster access. Nothing below invents logs, events, metrics, or objects
that are not in those files.

Assumption: the snapshot is complete for this pod; other namespaces,
nodes, and replicas are unknown unless shown.

---

## Triage sequence

### 1. Confirm the failing unit

**Would run / file read:** `kubectl get pods -n prod` (and typically
`-o wide` / `-l app=payments`). Read `starter/kubectl-get-pods.yaml`.

**Signal:** Ready count, STATUS (CrashLoop vs ImagePull vs Pending),
RESTARTS trend, AGE vs the reported 40-minute deploy.

**Conclusion:** One listed pod, `payments-7f9c4d6b8-xk2nq`, is `0/1`
`CrashLoopBackOff`, 12 restarts, age 40m. This is a running-then-dying
container, not a pull or schedule failure. Next: describe that pod for
last exit reason and events.

### 2. Last termination reason and kubelet events

**Would run / file read:**
`kubectl describe pod payments-7f9c4d6b8-xk2nq -n prod`.
Read `starter/kubectl-describe-pod.txt`.

**Signal:** `Last State` Reason/exit code, image pull events, probe
Unhealthy events, OOM vs Error vs Completed, node assignment, restart
count, resource limits on the live object.

**Conclusion:**

- Last state: `Terminated` / `OOMKilled` / exit `137`.
- Image pull succeeded (`Successfully pulled image`); not ImagePullBackOff.
- Scheduled onto `ip-10-0-3-22.ec2.internal`.
- Live limits: memory `64Mi`, CPU `500m`. Requests: memory `64Mi`.
- Revision annotation `14`. Restart count 12. Events: Created/Started
  ×12 over 40m, Back-off restarting failed container. No Unhealthy probe
  events in this dump.
- Last observed run lasted about 8 seconds (`12:38:01` → `12:38:09`).

Primary failure mode is cgroup OOM, not a failed HTTP probe and not a
missing image. Next: application logs around the kill.

### 3. Current logs (and previous container)

**Would run / file read:**
`kubectl logs -n prod payments-7f9c4d6b8-xk2nq -c payments` and
`kubectl logs ... --previous`. Read `starter/kubectl-logs.txt`.

**Signal:** Did the process start, connect to dependencies, then die
near the memory ceiling? Config/auth errors vs heap pressure. Whether
`--previous` matches the current snippet.

**Conclusion:** Starter logs show listen on 8080, Postgres connect,
then `heap approaching limit` with `rss_mb: 61`, then
`<no further lines — process killed>`. RSS ~61 MiB against a 64Mi
limit is consistent with OOMKilled. There is **no separate previous-log
file**; `--previous` is not evidenced here. Treat the snippet as the
killed instance (or equivalent). Next: compare declared resources and
runtime heap settings.

### 4. Resource limits vs process heap

**Would run / file read:** live pod resources (already in describe) plus
`kubectl get deploy payments -n prod -o yaml`. Read
`starter/deployment.yaml`.

**Signal:** request vs limit, whether the app’s heap target can fit
inside the cgroup, request=limit (no burst).

**Conclusion:** Deployment and running pod both set memory
request/limit to **64Mi**. `NODE_OPTIONS=--max-old-space-size=256`
tells Node the old-space heap may grow toward **256 MB**, which cannot
fit in a 64Mi cgroup. Request equals limit, so there is no burst above
64Mi. This is a heap-vs-cgroup mismatch, analogous to a JVM `-Xmx`
larger than the container limit. Next: probes (rule out as primary).

### 5. Probes

**Would run / file read:** describe (probes + events) and deployment
probe spec.

**Signal:** `Killing` / `Unhealthy` on `/healthz` or `/ready` vs
OOMKilled. Would a probe fire before the process can listen?

**Conclusion:** Liveness `GET /healthz:8080` (delay 10s, timeout 1s,
period 10s); readiness `GET /ready` (delay 5s). Last run was ~8s, so
liveness delay 10s likely did not even fire. Events do not show probe
failures. Probes are not the primary cause.

### 6. Recent rollout

**Would run / file read:**
`kubectl rollout history deployment/payments -n prod`.
Read `starter/kubectl-rollout-history.txt`. Also change-cause on the
Deployment.

**Signal:** revision that matches the 40-minute window; what changed.

**Conclusion:** Revision **13** change-cause: `bump memory request/limit
to 256Mi`. Revision **14**: `reduce memory limit to 64Mi to save cost`.
Pod age 40m, start time, and “last deployment was 40 minutes ago” align
with revision 14. Image remains `ghcr.io/example/payments-api:a1b2c3d4e5f6`.
The incident tracks a memory-limit cut, not an image bump in this dump.

### 7. Spec vs running object

**Would run / file read:** deployment YAML vs describe.

**Signal:** drift (wrong image, extra env, different limits).

**Conclusion:** Running pod matches spec: same image, `NODE_OPTIONS`,
64Mi memory, revision 14. `NODE_ENV=production` appears on the pod but
not in the Deployment YAML fragment; that env is not needed to explain
OOM. Config and running state agree on the lethal settings.

---

## Most likely root cause

**Revision 14 cut the container memory limit (and request) from 256Mi
to 64Mi while Node is still configured for a 256 MB old-space heap.**
The process starts, connects to Postgres, RSS climbs to ~61 MiB, then
the kubelet OOM-kills it (exit 137). CrashLoopBackOff is the restart
backoff around that kill loop. Cost-driven limit reduction is the
change that coincides with the outage window.

Not primary (on this evidence): ImagePullBackOff, bad probes, node
upgrade (prompt: none), missing ConfigMap, or a generic “app bug”
without the limit change.

---

## Safe remediation (with rollback)

**Immediate (restore last known-good memory envelope):**

```bash
kubectl rollout undo deployment/payments -n prod
```

That should return the ReplicaSet for revision 13 (256Mi
request/limit per rollout history). Do **not** delete the node, do
**not** set `privileged: true`, do **not** `kubectl delete pod` as the
fix (it will just OOM again under the same spec).

If undo is blocked or revision 13 is unavailable, patch memory back to
the previous values (256Mi request and limit) and leave
`NODE_OPTIONS` unchanged until you have data:

```bash
kubectl set resources deployment/payments -n prod \
  --containers=payments --requests=memory=256Mi --limits=memory=256Mi
```

Prefer the Deployment object (rollout/undo) over editing a live Pod.

**Verify (after undo):**

- `kubectl rollout status deployment/payments -n prod`
- Ready 1/1, no new OOMKilled
- Logs show sustained `listening` without kill
- Watch payment-path error rate / SLO / error budget; this is a
  single-replica Deployment (`replicas: 1` in the starter), so the
  service was fully down for ~40m of restarts.

**Follow-up (not during the fire):**

- Right-size from actual RSS/heap under load; do not keep 64Mi if
  working set is ~61 MiB plus headroom.
- Align `--max-old-space-size` with the cgroup limit (heap target must
  be **below** the limit, with room for non-heap RSS).
- Change-control: memory “cost saving” that contradicts the previous
  256Mi bump needs review before prod.

**Rollback of the remediation:** if undo itself is bad (unexpected
revision 13 behavior), `kubectl rollout undo` again (or
`rollout undo --to-revision=14`) returns to 14 — only do that if 14
is somehow required; it is the failing spec.

---

## Edge cases that would change the diagnosis

- **Memory leak vs chronic under-limit:** if RSS grew without bound
  over hours at 256Mi, a leak remains possible. Here the process dies
  in seconds at ~61 MiB after a 256Mi→64Mi cut, which favors
  under-limit, not a slow leak. A leak would still need a larger
  limit as a *mitigation*, not as proof it is the only bug.
- **Sidecar vs main container:** this Pod spec has a single container
  `payments`. A sidecar OOM is not in the dump.
- **Heap vs cgroup (Node/V8 or JVM):** `--max-old-space-size=256` vs
  64Mi limit is exactly this class of failure. If `NODE_OPTIONS` were
  absent or heap ≪ 64Mi, the story would shift toward a leak, a
  spike, or a different killer.
- **Healthy replica on another node:** dump shows one pod and
  `replicas: 1`. A second Ready replica would change blast radius, not
  the OOM reason on this pod.
- **Probe-induced restart:** would need Unhealthy/Killing events and
  a non-OOM last state. Not present.
- **Image or config regression:** image ID is pulled successfully and
  history cites memory, not a tag change. A broken image would more
  likely exit non-137 without `OOMKilled`.
- **Node-level memory pressure:** possible in general, but last state
  is container OOMKilled with RSS at the **container** limit; no node
  events are in the starter.

---

## What is still unknown

- `--previous` logs for earlier of the 12 restarts (same pattern or
  not).
- Actual metrics (RSS/working set under the old 256Mi limit; CPU).
  None are in the starter; none are inferred from Prometheus.
- Whether 256Mi is enough at peak traffic or only at this idle-ish
  startup path.
- Who merged revision 14, whether it was intended to keep heap at 256,
  and whether other env (e.g. `NODE_ENV`) is set via a patch not in
  the Deployment fragment.
- Downstream impact: error rate, queue depth, customer-facing
  checkout failures. Not in the dump; treat as full outage given 0/1
  Ready and one replica until proven otherwise.
- Postgres: connect succeeded; no DB error is shown. DB health is
  unknown beyond that one log line.
- Cluster-wide memory pressure, eviction, or other pods on
  `ip-10-0-3-22` — not in the files.
- Whether a later revision exists beyond 14.

---

## Commands I would **not** run as the fix

- `kubectl delete node ...`
- Privileged containers or hostPID/hostNetwork “to debug prod”
- Blind `kubectl delete pod` without changing the 64Mi spec
- Invented Prometheus queries or alerts not present in starter
