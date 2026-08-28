# Kubernetes Secure Deployment Solution

## Overview

This solution provides production-ready, hardened Kubernetes manifests for a public-facing Node.js API. All 15 security issues from the original starter files have been addressed.

## Deliverables

### Hardened Manifests

1. **namespace.yaml** - Dedicated namespace (api-prod)
2. **serviceaccount.yaml** - Dedicated ServiceAccount with token mounting disabled
3. **role.yaml** - Least-privilege Role with minimal ConfigMap access
4. **rolebinding.yaml** - Namespace-scoped RoleBinding
5. **secret.yaml** - Proper Secret resource for sensitive data
6. **configmap.yaml** - ConfigMap without secrets
7. **deployment.yaml** - Fully hardened Deployment with:
   - Non-root user execution
   - Resource requests and limits
   - Readiness and liveness probes
   - Read-only root filesystem
   - All capabilities dropped
   - Privilege escalation prevented
   - Pinned image with digest
   - Proper volume mounts
8. **service.yaml** - ClusterIP Service with namespace
9. **networkpolicy.yaml** - NetworkPolicy restricting ingress to ingress-nginx namespace
10. **poddisruptionbudget.yaml** - PDB ensuring minAvailable=1

### Documentation

- **SECURITY_REVIEW.md** - Comprehensive security review listing all 15 issues fixed

## Key Security Features

✅ Runs as non-root user (UID 10000)  
✅ Resource requests and limits defined  
✅ Readiness and liveness probes configured  
✅ Dedicated ServiceAccount with least-privilege RBAC  
✅ All capabilities dropped  
✅ Read-only root filesystem  
✅ Privilege escalation prevented  
✅ NetworkPolicy restricting traffic to ingress-nginx  
✅ Secrets stored in Secret resource, not ConfigMap  
✅ PodDisruptionBudget with minAvailable=1  
✅ Image pinned to digest  
✅ Namespace isolation  

## Deployment

### Prerequisites

- Kubernetes cluster with NetworkPolicy support
- ingress-nginx namespace (or adjust NetworkPolicy accordingly)
- Proper image digest (replace placeholder in deployment.yaml)

### Apply Order

```bash
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f role.yaml
kubectl apply -f rolebinding.yaml
kubectl apply -f secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f networkpolicy.yaml
kubectl apply -f poddisruptionbudget.yaml
```

Or apply all at once:

```bash
kubectl apply -f namespace.yaml,serviceaccount.yaml,role.yaml,rolebinding.yaml,secret.yaml,configmap.yaml,deployment.yaml,service.yaml,networkpolicy.yaml,poddisruptionbudget.yaml
```

### Verification

```bash
# Check deployment status
kubectl get deployment -n api-prod

# Check pod security context
kubectl get pod -n api-prod -o yaml | grep -A 10 securityContext

# Verify pods are running as non-root
kubectl get pod -n api-prod
kubectl exec -n api-prod <pod-name> -- id

# Check network policy
kubectl describe networkpolicy -n api-prod
```

## Notes

- The image digest in deployment.yaml is a placeholder and must be replaced with your actual image digest
- The Secret resource uses stringData for clarity; in production, integrate with external secret management
- The NetworkPolicy assumes ingress-nginx namespace; adjust selectors for your ingress controller
- Health probe endpoints (/health and /ready) must be implemented in the Node.js application
