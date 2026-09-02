# Comparison matrix

Generated automatically from `comparison/**/score.yaml` and `comparison/**/score.yml`.

Generated: 2026-09-02 10:34:05

Fill one row per (model, task). Keep evidence short.

| Model | Task | Mechanical | Correct | Secure | Reliable | Edges | Judgment | Ops | Overall | Merge | Top bug | Strength |
|-------|------|------------|---------|--------|----------|-------|----------|-----|---------|-------|---------|---------|
| Claude Sonnet 4.5 | 01 |  |  |  |  |  |  |  | 3.33 | Yes with changes | The module hard-codes three AZ-dependent resources while only dynamically discovering the AZ list, making the advertised multi-AZ design unsafe for regions with fewer than three... | Strong baseline EKS architecture: worker nodes are isolated in private subnets, NAT gateways provide egress, managed node groups have explicit IAM dependencies, cluster logging... |
| codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock) | 01 |  |  |  |  |  |  |  | 4.7 | yes_with_changes |  | Replaces the starter design with a reusable EKS/VPC module |
| kiro (Qwen3 Coder Next) | 01 |  |  |  |  |  |  |  | 2 |  | critical security failure | Creates a complete multi-AZ VPC layout with public and private subnets. |
| claude-code (Claude Sonnet 4.5) | 02 |  |  |  |  |  |  |  | 3.75 | yes_with_changes |  | Correctly moved DB_PASSWORD from the Deployment environment value to secretKeyRef |
| codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock) | 02 |  |  |  |  |  |  |  | 4.58 | yes_with_changes |  | Comprehensive security hardening rather than deleting insecure configuration |
| kiro (Qwen3 Coder Next) | 02 |  |  |  |  |  |  |  | 3.4167 | no | critical security failure | Creates the complete requested 10-file output set. |
| claude-code (Claude Sonnet 4.5) | 03 |  |  |  |  |  |  |  | 3.25 | yes_with_changes |  | Correctly restricts deployment to pushes on main |
| codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock) | 03 |  |  |  |  |  |  |  | 4.42 | yes_with_changes |  | Faithfully maps the Jenkins unit, integration, scan, build, staging, production, rollback, concurrency, and notification behavior |
| kiro (Qwen3 Coder Next) | 03 |  |  |  |  |  |  |  | 3.08 | yes with changes |  | Creates the required deploy.yml workflow. |
| claude-code (Claude Sonnet 4.5) | 04 |  |  |  |  |  |  |  | 4.25 | yes_with_changes |  | Comprehensive Prometheus configuration covering Kubernetes service discovery, persistence, retention, resources, security context, and health probes. |
| codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock) | 04 |  |  |  |  |  |  |  | 4.62 | yes_with_changes |  | Production-oriented observability stack without an unnecessarily large Helm values file |
| kiro (Qwen3 Coder Next) | 04 |  |  |  |  |  |  |  | 2.92 | no |  | Creates a complete-looking observability stack covering Prometheus, Alertmanager and Grafana. |
| claude-code (Claude Sonnet 4.5) | 05 |  |  |  |  |  |  |  | 4.25 | yes_with_changes |  | Strong evidence-based root cause identification |
| codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock) | 05 |  |  |  |  |  |  |  | 5 | yes |  | Follows the required triage sequence: pods → describe/events → logs → previous logs → resource limits → probes → rollout → desired versus running configuration. |
| kiro (Qwen3 Coder Next) | 05 |  |  |  |  |  |  |  | 4.75 | yes |  | Correctly identifies OOMKilled with exit code 137 as the immediate failure mechanism. |
| claude-code (Claude Sonnet 4.5) | 06 |  |  |  |  |  |  |  | 3.5 | yes_with_changes |  | Four required policy areas are implemented. |
| codex | 06 |  |  |  |  |  | 4.8 |  | 4.73 | yes_with_changes |  | Policies evaluate Terraform plan JSON rather than HCL |
| kiro (Qwen3 Coder Next) | 06 |  |  |  |  |  |  |  | 1.5 |  | critical security failure | Provides separate S3, security-group, EKS, and tagging policies. |

## Narrative (after two or more models on the same task)

### Task 01 — Terraform EKS

- **codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock)**; overall 4.7; strength: Replaces the starter design with a reusable EKS/VPC module.

- **Claude Sonnet 4.5**; overall 3.33; strength: Strong baseline EKS architecture: worker nodes are isolated in private subnets, NAT gateways provide egress, managed node groups have explicit IAM dependencies, cluster logging...; top finding: The module hard-codes three AZ-dependent resources while only dynamically discovering the AZ list, making the advertised multi-AZ design unsafe for regions with fewer than three....

- **kiro (Qwen3 Coder Next)**; overall 2; strength: Creates a complete multi-AZ VPC layout with public and private subnets.; top finding: critical security failure.

### Task 02 — Secure Kubernetes

- **codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock)**; overall 4.58; strength: Comprehensive security hardening rather than deleting insecure configuration.

- **claude-code (Claude Sonnet 4.5)**; overall 3.75; strength: Correctly moved DB_PASSWORD from the Deployment environment value to secretKeyRef.

- **kiro (Qwen3 Coder Next)**; overall 3.4167; strength: Creates the complete requested 10-file output set.; top finding: critical security failure.

### Task 03 — CI/CD migration

- **codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock)**; overall 4.42; strength: Faithfully maps the Jenkins unit, integration, scan, build, staging, production, rollback, concurrency, and notification behavior.

- **claude-code (Claude Sonnet 4.5)**; overall 3.25; strength: Correctly restricts deployment to pushes on main.

- **kiro (Qwen3 Coder Next)**; overall 3.08; strength: Creates the required deploy.yml workflow..

### Task 04 — Observability

- **codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock)**; overall 4.62; strength: Production-oriented observability stack without an unnecessarily large Helm values file.

- **claude-code (Claude Sonnet 4.5)**; overall 4.25; strength: Comprehensive Prometheus configuration covering Kubernetes service discovery, persistence, retention, resources, security context, and health probes..

- **kiro (Qwen3 Coder Next)**; overall 2.92; strength: Creates a complete-looking observability stack covering Prometheus, Alertmanager and Grafana..

### Task 05 — Incident triage

- **codex (0.150.1 / OpenAI gpt-oss-20b via Amazon Bedrock)**; overall 5; strength: Follows the required triage sequence: pods → describe/events → logs → previous logs → resource limits → probes → rollout → desired versus running configuration..

- **kiro (Qwen3 Coder Next)**; overall 4.75; strength: Correctly identifies OOMKilled with exit code 137 as the immediate failure mechanism..

- **claude-code (Claude Sonnet 4.5)**; overall 4.25; strength: Strong evidence-based root cause identification.

### Task 06 — Policy guardrails

- **codex**; overall 4.73; strength: Policies evaluate Terraform plan JSON rather than HCL.

- **claude-code (Claude Sonnet 4.5)**; overall 3.5; strength: Four required policy areas are implemented..

- **kiro (Qwen3 Coder Next)**; overall 1.5; strength: Provides separate S3, security-group, EKS, and tagging policies.; top finding: critical security failure.

## Cross-cutting patterns

- **IDE-first vs terminal-native:** The module hard-codes three AZ-dependent resources while only dynamically discovering the AZ list, making the advertised multi-AZ design unsafe for regions with fewer than three...; critical security failure

- **Cloud-specific depth vs portability:** The module hard-codes three AZ-dependent resources while only dynamically discovering the AZ list, making the advertised multi-AZ design unsafe for regions with fewer than three...; critical security failure

- **Happy-path bias:** No consistent pattern identified from the recorded evidence.

- **Secret handling:** No recurring secret-handling finding identified.
