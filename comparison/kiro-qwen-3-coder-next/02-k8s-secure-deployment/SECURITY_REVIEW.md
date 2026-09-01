# Security Review: api Deployment

## Original Files Issues

This document reviews the original starter manifests and documents all security issues found and fixed.

---

## deployment.yaml

### Issues Found

1. **privileged: true** - The container runs in privileged mode, giving it full access to the host. This is a critical security violation.

2. **Image tag `:latest`** - Using `:latest` tag makes deployments non-reproducible and prevents rollback to known-good versions. Should use a digest or semantic version.

3. **Plaintext DB_PASSWORD in env** - The database password is hardcoded in the deployment spec. This exposes credentials in logs, diffs, and kubectl output.

4. **Missing securityContext** - No `runAsNonRoot`, `runAsUser`, or `allowPrivilegeEscalation` settings.

5. **Missing resource limits/requests** - No CPU or memory limits allow the pod to consume unlimited resources.

6. **Missing probes** - No liveness or readiness probes configured.

7. **Missing ServiceAccount** - Uses the `default` ServiceAccount with default permissions.

8. **Missing namespace** - No namespace specified, defaults to `default`.

9. **Missing terminationGracePeriodSeconds** - Pods may be terminated before graceful shutdown completes.

---

## configmap.yaml

### Issues Found

1. **Secret material in ConfigMap** - `DB_PASSWORD` is stored in a ConfigMap, which is not encrypted and readable by anyone with RBAC access.

---

## service.yaml

### Issues Found

1. **LoadBalancer type** - Using LoadBalancer exposes the service directly to the internet without proper ingress control. For internal services, ClusterIP is appropriate.

2. **Missing namespace** - No namespace specified.

3. **Missing port naming** - Port should be named for clarity.

---

## rbac.yaml

### Issues Found

1. **Using default ServiceAccount** - The `default` ServiceAccount should not be used for applications.

2. **cluster-admin role** - Granting `cluster-admin` is a critical security risk. The principle of least privilege is violated.

3. **Missing namespace scope** - RBAC should be namespace-scoped where possible.

---

## Fixes Applied

### deployment.yaml

| Fix | Details |
|-----|---------|
| Removed privileged mode | Set `allowPrivilegeEscalation: false` |
| Added securityContext | `runAsNonRoot: true`, `runAsUser: 1000`, `fsGroup: 1000`, `seccompProfile: RuntimeDefault` |
| Dropped all capabilities | `capabilities.drop: [ALL]` |
| Made root filesystem read-only | `readOnlyRootFilesystem: true` |
| Pinned image to digest | `image: ghcr.io/example/api@sha256:a1b2c3d4e5f6` |
| Moved DB_PASSWORD to Secret | Referenced via `secretKeyRef` |
| Added resource limits | CPU: 100m-500m, Memory: 128Mi-256Mi |
| Added probes | Liveness at `/healthz`, Readiness at `/ready` |
| Created dedicated ServiceAccount | `api` ServiceAccount |
| Added namespace | `production` |
| Added terminationGracePeriodSeconds | 30 seconds for graceful shutdown |
| Added emptyDir for /tmp | Required for `readOnlyRootFilesystem: true` |

### configmap.yaml

| Fix | Details |
|-----|---------|
| Removed DB_PASSWORD | Secret is now in `secret.yaml` |
| Added namespace | `production` |

### service.yaml

| Fix | Details |
|-----|---------|
| Changed type to ClusterIP | Internal service only |
| Added namespace | `production` |
| Named port | `http` for clarity |

### rbac.yaml

| Fix | Details |
|-----|---------|
| Created dedicated ServiceAccount | `api` in `production` namespace |
| Created namespace-scoped Role | Only `get`, `list` on specific ConfigMap/Secret |
| Removed cluster-admin | Least-privilege RoleBinding instead |

### networkpolicy.yaml (New)

| Fix | Details |
|-----|---------|
| Ingress from ingress-nginx only | Blocks all other external traffic |
| Egress for DNS only | Allow kube-dns (port 53 UDP/TCP) |
| Egress for database only | Allow postgres (port 5432) |

### poddisruptionbudget.yaml (New)

| Fix | Details |
|-----|---------|
| minAvailable: 1 | Ensures at least one pod during disruptions |
| Selector matches deployment | `app: api` |

---

## Additional Recommendations

1. **External Secrets** - For production, use external secret management (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault).

2. **Pod Security Admission** - Enable Pod Security Standard at namespace level.

3. **Network Policy Testing** - Test NetworkPolicy rules with tools like `np-test` or Cilium CLI.

4. **Image Scanning** - Add container image scanning in CI/CD pipeline.

5. **Runtime Security** - Consider Falco or similar runtime security monitoring.

6. **Secrets Rotation** - Implement automatic secret rotation.

7. **Audit Logging** - Enable Kubernetes audit logging for security investigation.