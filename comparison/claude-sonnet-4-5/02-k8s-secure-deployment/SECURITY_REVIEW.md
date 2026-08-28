# Security Review: Kubernetes Deployment Hardening

## Executive Summary

The original starter manifests contained **15 critical security issues** that would pose significant risks in a production environment. All issues have been addressed in the hardened manifests.

## Critical Issues Fixed

### 1. **Privileged Container Execution** (CRITICAL)
- **Issue**: `privileged: true` in deployment.yaml:28
- **Risk**: Full access to host resources, kernel capabilities, and ability to escape container
- **Fix**: Set `privileged: false` and added explicit capability dropping

### 2. **Hardcoded Secrets in Plain Text** (CRITICAL)
- **Issue**: DB_PASSWORD stored as plain text in:
  - deployment.yaml:24 (environment variable)
  - configmap.yaml:8 (ConfigMap)
- **Risk**: Secrets exposed in version control, kubectl output, and to anyone with ConfigMap read access
- **Fix**: Created Secret resource (secret.yaml) and referenced via `secretKeyRef`

### 3. **Excessive RBAC Permissions** (CRITICAL)
- **Issue**: ClusterRoleBinding to cluster-admin role in rbac.yaml:8
- **Risk**: Full cluster-wide administrative access; pod compromise = cluster compromise
- **Fix**: 
  - Created dedicated ServiceAccount (api-sa)
  - Replaced ClusterRoleBinding with namespace-scoped RoleBinding
  - Implemented least-privilege Role with minimal ConfigMap read-only access

### 4. **Using Default ServiceAccount** (HIGH)
- **Issue**: No serviceAccountName specified, defaults to "default" in rbac.yaml:11-12
- **Risk**: Shared service account across workloads, difficult to audit, token automatically mounted
- **Fix**: Created dedicated ServiceAccount and disabled automatic token mounting

### 5. **Running as Root User** (HIGH)
- **Issue**: No runAsNonRoot or runAsUser specified
- **Risk**: Container processes run as root (UID 0), increasing impact of container escape
- **Fix**: Added `runAsNonRoot: true`, `runAsUser: 10000` at pod and container level

### 6. **Privilege Escalation Allowed** (HIGH)
- **Issue**: No `allowPrivilegeEscalation: false` set
- **Risk**: Processes can gain more privileges than parent process
- **Fix**: Set `allowPrivilegeEscalation: false` in container securityContext

### 7. **No Capability Dropping** (HIGH)
- **Issue**: Container retains default Linux capabilities
- **Risk**: Unnecessary capabilities increase attack surface
- **Fix**: Added `capabilities.drop: [ALL]` to remove all capabilities

### 8. **Writable Root Filesystem** (MEDIUM)
- **Issue**: No `readOnlyRootFilesystem` set
- **Risk**: Malicious code can modify binaries, create backdoors
- **Fix**: Set `readOnlyRootFilesystem: true` with emptyDir volumes for /tmp and /app/.cache

### 9. **Missing Resource Limits** (MEDIUM)
- **Issue**: No resource requests or limits defined
- **Risk**: Pod can consume excessive resources, causing node instability or noisy neighbor problems
- **Fix**: Added appropriate requests (128Mi memory, 100m CPU) and limits (256Mi memory, 500m CPU)

### 10. **No Health Checks** (MEDIUM)
- **Issue**: No readiness or liveness probes
- **Risk**: Traffic routed to unhealthy pods, no automatic restart on failure
- **Fix**: Added HTTP-based readiness probe (/ready) and liveness probe (/health)

### 11. **Image Tag Using 'latest'** (MEDIUM)
- **Issue**: Image tagged as `:latest` in deployment.yaml:19
- **Risk**: Non-deterministic deployments, difficult rollbacks, cache poisoning
- **Fix**: Pinned to specific version with digest (v1.2.3@sha256:...)

### 12. **No Network Segmentation** (MEDIUM)
- **Issue**: No NetworkPolicy defined
- **Risk**: Unrestricted network access from/to all pods
- **Fix**: Created NetworkPolicy allowing only ingress from ingress-nginx namespace and limited egress

### 13. **Missing Namespace** (LOW)
- **Issue**: No namespace defined in any resource
- **Risk**: Resources deployed to default namespace, poor organization, difficult RBAC
- **Fix**: Created dedicated namespace (api-prod) and added to all resources

### 14. **No PodDisruptionBudget** (LOW)
- **Issue**: No PDB defined
- **Risk**: Voluntary disruptions could take down all pods simultaneously
- **Fix**: Added PodDisruptionBudget with minAvailable: 1

### 15. **Missing Security Hardening Features** (LOW)
- **Issue**: No seccomp profile, no fsGroup, automountServiceAccountToken not disabled
- **Risk**: Additional attack surface and privilege vectors
- **Fix**: 
  - Added `seccompProfile: RuntimeDefault`
  - Set `fsGroup: 10000` for volume permissions
  - Set `automountServiceAccountToken: false`

## Additional Improvements

### Service Type Changed
- Changed from `LoadBalancer` to `ClusterIP`
- **Rationale**: Public APIs should be exposed through Ingress controllers, not direct LoadBalancer services

### Structured Labels
- Added consistent labels across all resources
- Includes app, environment metadata for better observability

### Volume Mounts for Read-Only Filesystem
- Added emptyDir volumes for /tmp and /app/.cache
- Allows application to write temporary files while maintaining read-only root filesystem

## Deployment Order

Apply manifests in this order to satisfy dependencies:

1. namespace.yaml
2. serviceaccount.yaml
3. role.yaml
4. rolebinding.yaml
5. secret.yaml
6. configmap.yaml
7. deployment.yaml
8. service.yaml
9. networkpolicy.yaml
10. poddisruptionbudget.yaml

## Verification Commands

```bash
# Verify security context
kubectl get pod -n api-prod -o jsonpath='{.items[0].spec.securityContext}'

# Verify non-root user
kubectl exec -n api-prod <pod-name> -- id

# Verify read-only filesystem
kubectl exec -n api-prod <pod-name> -- touch /test-readonly

# Verify capabilities dropped
kubectl exec -n api-prod <pod-name> -- capsh --print

# Verify network policy
kubectl describe networkpolicy -n api-prod api-network-policy

# Verify RBAC
kubectl auth can-i --as=system:serviceaccount:api-prod:api-sa get pods -n api-prod
```

## Remaining Recommendations

While the manifests are now production-ready, consider these additional security measures:

1. **External Secret Management**: Integrate with Vault, AWS Secrets Manager, or Sealed Secrets
2. **Pod Security Standards**: Enable Pod Security Admission controller with "restricted" policy
3. **Image Scanning**: Implement container image scanning in CI/CD pipeline
4. **Runtime Security**: Deploy Falco or similar runtime security monitoring
5. **mTLS**: Implement service mesh (Istio, Linkerd) for encrypted inter-service communication
6. **Audit Logging**: Enable and monitor Kubernetes audit logs
7. **OPA/Gatekeeper**: Implement admission policies to prevent insecure configurations
8. **SIEM Integration**: Forward security events to centralized logging/SIEM system
