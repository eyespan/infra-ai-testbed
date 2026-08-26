# Review criteria — Task 02

## Mechanical

- [ ] YAML parses
- [ ] No plaintext DB password in env value
- [ ] Dedicated ServiceAccount (not `default`)

## Bugs / misses

- Still using `image: ...:latest`
- Missing `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true` without an emptyDir for `/tmp`
- NetworkPolicy that also blocks DNS (no egress to kube-dns)
- RBAC still `cluster-admin`
- Probes hitting the wrong port or `/` on an API that only has `/healthz`
- PDB `minAvailable` greater than replica count
- Service type LoadBalancer plus NetworkPolicy that denies the LB

## Edge cases

- Rolling update with 2 replicas and PDB minAvailable=1
- Ingress controller not in `ingress-nginx`
- Windows vs Linux securityContext fields mixed
- ConfigMap change not triggering a rollout (missing checksum annotation)

## Reliability

- No `terminationGracePeriodSeconds`
- No topology spread
- Memory limit without request (scheduler vs OOM mismatch)
