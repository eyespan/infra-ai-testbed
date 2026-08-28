# Security review of the starter manifests

## Fixed issues

1. `deployment.yaml` used `myregistry/api:latest`, which is mutable and makes
   provenance and rollback unreliable. The Deployment now uses a non-`latest`,
   versioned tag. **Assumption:** the approved image-promotion process replaces
   it with an immutable digest before production deployment.
2. The pod did not select a namespace or dedicated ServiceAccount, so it would
   run in the default namespace with the `default` ServiceAccount. A dedicated
   `api` account in `api-prod` is now selected and token mounting is disabled.
3. `rbac.yaml` bound the default account to cluster-admin cluster-wide. That
   binding is removed. No Kubernetes API access is evidenced, so the workload
   receives zero RBAC permissions; the included empty Role documents this
   intentional least-privilege baseline.
4. The container set `privileged: true`. Privileged mode is removed; privilege
   escalation is disabled and all Linux capabilities are dropped.
5. Neither pod nor container required a non-root identity, group, or seccomp
   profile. The workload now uses a non-root UID/GID, `fsGroup`, and
   `RuntimeDefault` seccomp.
6. The root filesystem was writable. It is read-only now, with a bounded
   `emptyDir` mounted at `/tmp` for the writable location the runtime may need.
7. There were no CPU or memory requests/limits. Both are supplied, avoiding an
   unbounded workload and the scheduler/limit mismatch of a limit-only setup.
8. There were no startup, liveness, or readiness probes. All three now use the
   named HTTP port and `/healthz`; this is the only health endpoint stated by
   the task, so a richer readiness endpoint remains an application contract to
   confirm.
9. The Service was a public `LoadBalancer`. It is now `ClusterIP`, with the
   ingress controller responsible for external TLS/traffic termination.
10. No NetworkPolicy existed. Policy now permits ingress only from the
    `ingress-nginx` namespace, permits DNS over TCP/UDP 53, and permits the
    PostgreSQL connection inferred from `DB_HOST`. **Assumptions:** the
    controller namespace is named `ingress-nginx`, CoreDNS has label
    `k8s-app: kube-dns`, and PostgreSQL listens on TCP 5432 in namespace `prod`.
    These selectors must be verified before use; otherwise valid traffic could
    be blocked.
11. `DB_PASSWORD` was plaintext in the Deployment and ConfigMap. It is removed
    from both; the workload refers to `api-db-credentials/DB_PASSWORD`, which
    must be supplied by the approved external secret manager. No sample secret
    is committed because Kubernetes Secret encoding is not secret protection.
12. There was no PodDisruptionBudget. With two replicas, `minAvailable: 1`
    permits one voluntary disruption while retaining one available replica.
13. The starter had no graceful termination period, rollout controls, or
    topology spread. The Deployment now uses a 30-second grace period, bounded
    rolling update, and zone spread preference. `ScheduleAnyway` avoids making
    the two-replica service unschedulable in a single-zone or constrained
    cluster.
14. ConfigMap-backed environment values would not update existing Pods. The
    Pod-template checksum annotation is CI-managed and must change whenever
    `api-config` changes, triggering a controlled rollout.

## Remaining deployment prerequisites

Before applying these manifests through the approved delivery process, verify
the image digest, the secret-manager output, the ingress-controller/DNS labels,
the database selector and port, and the resource values against observed load.
No live cluster was queried or changed.
