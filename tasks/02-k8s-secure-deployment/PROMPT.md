Harden and complete the provided Deployment, Service, and ConfigMap
for a public-facing Node.js API.

The starter files contain common real-world mistakes. Produce
production-ready manifests that:

- Run as non-root
- Have resource requests and limits
- Include readiness and liveness probes
- Use a dedicated ServiceAccount with least-privilege RBAC
- Drop all capabilities and set readOnlyRootFilesystem where possible
- Prevent privilege escalation
- Include a NetworkPolicy that only allows ingress from the
  `ingress-nginx` namespace
- Do not store secrets in ConfigMaps
- Add a PodDisruptionBudget with minAvailable=1
- Pin the image to a digest or at least a non-`latest` tag
- Add a namespace

Also produce a short security review of the original starter that
lists every issue you fixed.

Do not apply to a cluster.
