# Security review of the original starter

This lists every issue found in `tasks/02-k8s-secure-deployment/starter/`.
Manifests in this directory were not applied to a cluster.

## Assumptions

- Workload namespace is `api` (starter used implicit `default`).
- Health endpoint is HTTP `/healthz` on container port 3000 (starter had
  no probes; path is the usual one for this task’s API).
- PostgreSQL is in namespace `prod` on TCP 5432, matching
  `postgres.prod.svc.cluster.local`. Pod labels for that database are
  unknown, so egress is namespace-scoped on that port only.
- Ingress controller pods run in namespace `ingress-nginx`.
- Image `myregistry/api:1.0.0` is a stand-in for a real version; pin a
  registry digest before production.
- UID 1000 is a typical non-root Node.js user. Confirm against the
  actual image USER. If the image is root-only, rebuild it; do not set
  `runAsUser: 0`.
- The API does not call the Kubernetes API, so it gets a dedicated
  ServiceAccount with **no** Role/ClusterRoleBinding and with token
  automount disabled.
- `REPLACE_ME_VIA_SECRET_STORE` is not a real password. Inject via a
  secret manager. Do not commit live credentials.

## `starter/deployment.yaml`

1. **Privileged container** (`securityContext.privileged: true`) — full
   host access; removed. `privileged: false` plus dropped capabilities.
2. **Runs as root / no non-root constraint** — no `runAsNonRoot`,
   `runAsUser`, `runAsGroup`, `fsGroup`, or `seccompProfile`.
3. **Privilege escalation allowed** (default) — set
   `allowPrivilegeEscalation: false`.
4. **Writable root filesystem** — `readOnlyRootFilesystem: true` plus
   `emptyDir` on `/tmp` so the process can still use temp files.
5. **Linux capabilities retained** — `capabilities.drop: [ALL]`. No
   `add`.
6. **Image `:latest`** — mutable, hard to audit/roll back. Pinned to
   tag `1.0.0` (digest still required for prod).
7. **No `imagePullPolicy`** — `:latest` would imply Always; now
   `IfNotPresent` with a version tag.
8. **Plaintext secret in env** (`DB_PASSWORD: "supersecret"`) — moved
   to `secretKeyRef`.
9. **No resource requests or limits** — scheduler vs OOM mismatch;
   both request and limit set for CPU and memory.
10. **No liveness or readiness probes** — added HTTP GET `/healthz` on
    the named port `http` (3000), not `/` and not the Service port
    alone.
11. **No dedicated ServiceAccount** — would use `default`. Now `api`.
12. **ServiceAccount token automounted** (default) — disabled on pod
    and SA.
13. **No namespace** on the object — placed in `api`.
14. **No Pod security/seccomp** at pod level.
15. **No termination grace period** — `terminationGracePeriodSeconds: 30`.
16. **No topology spread** — zone spread with `ScheduleAnyway` so a
    single-zone cluster still schedules.
17. **ConfigMap/Secret changes would not roll pods** — checksum
    annotations on the pod template.
18. **No rolling-update bounds** — `maxUnavailable: 1` / `maxSurge: 1`
    so PDB `minAvailable: 1` and 2 replicas can coexist.
19. **Container port unnamed** — named `http` for probes and Service
    `targetPort`.

## `starter/service.yaml`

20. **`type: LoadBalancer`** on a “public-facing” API while the
    NetworkPolicy only allows `ingress-nginx` — the LB path would not
    match that ingress-only policy (and often skips ingress TLS).
    Changed to **ClusterIP**; TLS at ingress.
21. **No namespace**.
22. **Port unnamed** — named `http`.
23. **No labels** for consistent selection.

## `starter/configmap.yaml`

24. **Secret in ConfigMap** (`DB_PASSWORD: supersecret`) — ConfigMaps
    are not encryption-at-rest in the same way as Secrets in many
    clusters, are easily `get`’d, and get copied into env. Removed
    from ConfigMap; only `DB_HOST`, `NODE_ENV`, `DB_PORT` remain.
25. **No namespace**.

## `starter/rbac.yaml`

26. **`ClusterRoleBinding` to `cluster-admin`** — cluster-wide
    superuser.
27. **Subject is ServiceAccount `default` in `default`** — every pod
    using the default SA in that namespace inherits admin if bound
    this way; even without that, default SA is shared.
28. **No least-privilege Role** — the workload does not need API
    access, so the binding is deleted entirely rather than replaced
    with a wide Role.

## Missing from starter (required by the prompt)

29. **No Namespace object.**
30. **No NetworkPolicy** — unrestricted pod ingress/egress. Added
    ingress **only** from namespace `ingress-nginx` on 3000, egress
    DNS (kube-dns in `kube-system`, UDP/TCP 53) and Postgres (`prod`
    TCP 5432). Default-deny for other egress (no 443-to-world unless
    the app needs it; unknown from starter).
31. **No PodDisruptionBudget** — added `minAvailable: 1` (not greater
    than replica count 2).

## What we did not do (on purpose)

- Did not apply manifests to a cluster.
- Did not keep `privileged: true` “so probes work”.
- Did not drop `DB_PASSWORD` without a Secret (app would fail to boot).
- Did not mix Windows `securityContext` fields.
- Did not invent a cloud account, registry digest, or postgres pod
  label. DNS/CoreDNS label `k8s-app: kube-dns` is the common in-cluster
  DNS label; if the cluster uses other labels, the DNS egress rule
  must be updated or the app will fail name resolution.
