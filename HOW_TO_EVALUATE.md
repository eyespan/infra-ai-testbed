# How to Evaluate

This document defines the recommended evaluation workflow for the
Infrastructure AI Agent Testbed.

The benchmark is designed to compare coding agents on realistic
infrastructure engineering tasks.

The evaluation process deliberately separates:

1. Agent execution
2. Automated validation
3. Human engineering review
4. Structured scoring
5. Cross-model comparison

The objective is to produce reproducible, evidence-based evaluations rather
than subjective impressions of model output.

---

## 1. Evaluation workflow

The complete workflow is:

```text
Read task
   │
   ▼
Run coding agent
   │
   ▼
Preserve generated output
   │
   ▼
Run automated validation
   │
   ▼
Inspect implementation
   │
   ▼
Review against task criteria
   │
   ▼
Score six engineering dimensions
   │
   ▼
Record evidence in score.yml / score.yaml
   │
   ▼
Repeat for other models
   │
   ▼
Generate comparison matrix
```

Do not skip directly from **agent finished** to **model scored**.

The generated implementation must be inspected.

## 2. Start with the task requirements

Before evaluating a model, read:

```text
tasks/<task-id>/PROMPT.md
tasks/<task-id>/criteria.md
tasks/<task-id>/expected-behaviors.md
tasks/<task-id>/README.md
```

Also inspect the starter material:

```text
tasks/<task-id>/starter/
```

The evaluator must understand what the agent was actually asked to do.

Do not score against requirements that were never part of the task.

## 3. Inspect the generated output

The generated output should be located at:

```text
comparison/<model-name>/<task-id>/
```

For example:

```text
comparison/claude-sonnet-4-5/03-cicd-github-actions/
```

Inspect every relevant generated file.

Useful commands include:

```bash
find comparison/<model>/<task-id> -type f -print | sort
```

and:

```bash
git status --short
```

For small outputs:

```bash
cat comparison/<model>/<task-id>/<file>
```

For larger outputs:

```bash
sed -n '1,240p' comparison/<model>/<task-id>/<file>
```

The purpose is to ensure that the score is based on the actual artifact
rather than the agent's final explanation.

## 4. Run automated validation

Run the validator appropriate to the task.

Examples:

```text
scripts/validate-terraform.sh
scripts/validate-k8s.sh
scripts/validate-gha.sh
scripts/score-run.sh
```

Use the task README to determine the exact command and prerequisites.

Record useful validator evidence.

Examples:

- `terraform validate` passes
- YAML parses successfully
- OPA policy tests pass
- GitHub Actions workflow validation fails

Automated validation should inform the score, but it does not determine the
entire score.

## 5. Mechanical checks

Mechanical checks are objective checks that can normally be represented as:

```text
passed / total
```

Examples:

```text
3/3
2/4
0/1
```

If a task has no applicable mechanical checks:

```text
N/A
```

Mechanical checks should not be confused with the six engineering judgement
dimensions.

A solution can pass all mechanical checks and still receive a low
engineering score.

## 6. Score the six engineering dimensions

Each dimension is scored from `0` to `5`.

The dimensions are:

- Correctness
- Security
- Reliability
- Edges
- Judgment
- Ops

Use `evaluation/rubric.md` for the detailed scoring definitions.

## 7. Correctness

Ask:

- Does the implementation actually satisfy the task?
- Does it preserve required semantics?
- Are configuration relationships correct?
- Are referenced resources actually defined?
- Are commands, paths, and dependencies internally consistent?
- Does the generated code work conceptually as a complete implementation?
- Does it avoid introducing obvious functional regressions?

Examples of correctness failures:

- A workflow references a file that does not exist.
- A Terraform module references an undeclared variable.
- A Kubernetes Service selects labels that do not exist on the Deployment.
- A policy evaluates the wrong resource representation.

## 8. Security

Security should receive particularly careful attention.

Review:

- authentication
- authorization
- IAM permissions
- secrets
- credentials
- encryption
- network exposure
- TLS
- container security
- supply-chain security
- cloud API access
- Kubernetes security contexts
- policy enforcement

Examples of serious findings:

- Plaintext production secret committed to the repository.
- Cloud credentials are stored as long-lived static keys.
- EKS API endpoint is publicly exposed to the entire internet.
- Deployment uses excessive IAM permissions.
- Container image is not pinned to an immutable reference where the task
  requires supply-chain protection.

Security issues should be treated as first-class defects rather than minor
implementation details.

## 9. Critical security failures

A critical security failure can override a high numerical score.

Examples include:

- committed plaintext production credentials
- unrestricted administrative access
- broadly exposed sensitive control-plane interfaces
- intentionally disabled security controls
- a policy implementation that directly defeats a required security control
- other defects that create an immediately unacceptable security posture

When a critical security failure is identified:

```text
critical_security_fail = true
```

The implementation should not pass merely because its numerical average is
above the normal threshold.

Use engineering judgement and document the evidence.

## 10. Reliability

Review:

- failure handling
- rollback
- retries
- deployment strategy
- availability
- resource limits
- health checks
- persistence
- recovery behaviour
- dependency failures
- scaling assumptions
- concurrency
- operational continuity

Ask: **what happens when something goes wrong?**

Do not award high reliability scores merely because a happy-path deployment
is present.

A strong solution should show awareness of failure modes.

## 11. Edge cases

Review both edge cases **identified** and edge cases **missed**.

Typical examples include:

- insufficient availability zones
- unusual region configurations
- zero replicas
- unexpected scaling values
- missing resources
- failed dependencies
- unknown Terraform values
- create/update/delete differences
- forked pull requests
- rollback failures
- partial deployment
- missing monitoring targets
- high-cardinality metrics
- missing configuration
- unsupported versions

A strong implementation should anticipate realistic conditions outside the
happy path.

## 12. Engineering judgment

This dimension evaluates whether the agent made sensible engineering
decisions.

Look for:

- appropriate trade-offs
- realistic assumptions
- avoidance of unnecessary complexity
- explicit limitations
- awareness of deployment context
- production-minded decisions
- recognition of uncertainty
- sensible defaults
- appropriate use of automation

A technically functional solution can still score poorly if the engineering
choices are careless.

## 13. Operations / observability

Review whether the solution can be operated safely after deployment.

Consider:

- logs
- metrics
- alerts
- health checks
- tracing where appropriate
- resource visibility
- failure visibility
- deployment visibility
- rollback visibility
- persistence
- operational runbooks
- alert correctness

Ask: **if this failed at 02:00, would an on-call engineer have enough
information to diagnose and recover it?**

## 14. Evidence

Scores should always be supported by evidence.

Good:

> `deployment.yaml:42-47` uses `secretKeyRef` for `DB_PASSWORD`.

Good:

> Workflow `deploy.yml` does not configure AWS OIDC and instead relies on
> static credentials.

Good:

> `terraform validate` passes, but the module indexes the AZ list three
> times without validating that three AZs are available.

Weak:

> Looks good.

Weak:

> Seems secure.

Weak:

> Production ready.

The goal is to make every important score explainable.

## 15. Do not reward claims that are not demonstrated

Agent-generated documentation can make claims such as "zero-downtime
rollback", "secure by default", or "production ready".

These are claims, not evidence.

Check the implementation.

For example, a rollback script should be examined for:

- correct revision selection
- correct namespace
- correct Deployment
- readiness behaviour
- failure handling
- post-rollback validation

If evidence is absent, record the limitation.

## 16. Do not penalize different valid implementations

The benchmark does not require every model to produce identical code.

Multiple implementations may be valid.

Evaluate: **does this satisfy the requirement safely and reliably?**

rather than: does this look like my preferred implementation?

Engineering preference should not be confused with correctness.

## 17. Score the overall result

The six primary dimensions are averaged:

```text
overall = mean(
    Correct,
    Secure,
    Reliable,
    Edges,
    Judgment,
    Ops
)
```

The default pass bar is `3.5`.

A result therefore passes only when:

```text
overall >= 3.5
AND
critical_security_fail == false
```

Example:

| Dimension | Score |
|-----------|-------|
| Correct   | 4.0   |
| Secure    | 4.5   |
| Reliable  | 4.0   |
| Edges     | 3.5   |
| Judgment  | 4.0   |
| Ops       | 3.5   |

Overall = 3.92 — this would normally pass.

## 18. Record the merge decision

Use one of:

- `yes`
- `yes_with_changes`
- `no`

**`yes`** — the implementation can reasonably be merged as submitted.

**`yes_with_changes`** — the implementation is broadly sound but requires
changes before merge. This is expected to be a common result in
infrastructure work.

**`no`** — the implementation contains unacceptable defects, fails
important requirements, or has a critical security/reliability problem.

## 19. Record the top finding

Each score should identify the most important defect or concern.

Examples:

```text
high: AWS deployment authentication does not use OIDC
critical: plaintext production secret committed
medium: container image is tag-pinned rather than digest-pinned
medium: ConfigMap changes do not trigger a Deployment rollout
```

If there is no significant bug, a note can be recorded:

```text
note: strong evidence-based root-cause analysis
```

The top finding should be short and actionable.

## 20. Record the main strength

Each run should also identify its strongest characteristic.

Examples:

- Strong evidence-based root cause identification
- Comprehensive security hardening
- Faithfully preserves the Jenkins pipeline semantics
- Production-oriented observability configuration

This prevents the benchmark from becoming a list of failures only.

## 21. Score file

Store the score alongside the generated implementation:

```text
comparison/<model>/<task>/score.yaml
```

or:

```text
comparison/<model>/<task>/score.yml
```

The generator supports both extensions.

The score should contain enough information to reproduce the comparison
table and narrative.

Use `evaluation/scoring-template.yaml` as the starting point.

Do not create multiple conflicting score files for the same model/task
unless there is a deliberate reason to preserve separate evaluation runs.

## 22. Inspect the score before generating the matrix

Before running the comparison generator:

```bash
find comparison -name 'score.yml' -o -name 'score.yaml'
```

Then inspect the relevant files.

Useful checks include:

```bash
git status --short
```

and:

```bash
find comparison -type f | sort
```

The comparison generator will report the score files it discovers.

Use that output to detect missing evaluations.

## 23. Generate the comparison matrix

From the repository root:

```bash
scripts/generate-comparison-matrix.py
```

The script reads:

```text
comparison/**/score.yml
comparison/**/score.yaml
```

and uses `evaluation/comparison-matrix.md` as the template.

It generates:

```text
comparison-matrix-<DDMMYYYY>.md
```

in the repository root.

Example:

```text
comparison-matrix-02092026.md
```

## 24. Generated narrative

The comparison generator produces narrative sections when at least two
models have been evaluated for a task.

For example:

```text
Task 03 — CI/CD migration
```

The generated narrative can include:

- model results
- score differences
- strengths
- top findings
- edge cases identified
- edge cases missed

This provides qualitative comparison in addition to the numerical table.

## 25. Cross-cutting patterns

The generated report also looks for recurring themes across the benchmark.

The current categories include:

- IDE-first vs terminal-native
- cloud-specific depth vs portability
- happy-path bias
- secret handling

These should be interpreted as benchmark-level observations.

They are particularly useful when the same class of issue appears
repeatedly across multiple tasks.

## 26. Recommended evaluation sequence

For every model/task pair:

1. Read `PROMPT.md`
2. Read `criteria.md`
3. Read `expected-behaviors.md`
4. Read task `README.md`
5. Inspect starter files
6. Inspect model output
7. Run automated validation
8. Review security
9. Review correctness
10. Review reliability
11. Review edge cases
12. Review engineering judgement
13. Review operations
14. Record evidence
15. Assign six scores
16. Calculate overall
17. Determine critical security status
18. Determine merge decision
19. Record top finding
20. Record main strength
21. Save `score.yml` or `score.yaml`

Only after the model/task runs have been scored should the comparison
matrix be generated.

## 27. Comparing multiple models

When comparing models, keep the task conditions consistent.

Ideally use:

- same `PROMPT.md`
- same `starter/`
- same criteria
- same expected behaviours
- same validation process
- same scoring rubric

Avoid changing the task because one model produced a poor result.

If a task or benchmark changes, record the change.

## 28. Handling incomplete runs

A model may fail to complete a task.

Do not fabricate scores.

Instead record what actually happened and explain the limitation.

Examples:

```text
Mechanical: 0/3
```

or an appropriate incomplete evaluation according to the scoring template.

The comparison matrix should make incomplete or missing evaluations visible
rather than silently treating them as successful runs.

## 29. Common evaluation mistakes

**Mistake 1: Scoring the agent's explanation**

Do not score the final explanation alone. Inspect the generated files.

**Mistake 2: Treating file existence as correctness**

A file called `networkpolicy.yaml` does not prove that the NetworkPolicy is
correct.

**Mistake 3: Giving full security marks for using a secret reference**

Check the entire secret lifecycle. A workload can use `secretKeyRef:` and
still have an insecure Secret committed in plaintext.

**Mistake 4: Assuming an approval gate exists because the workflow says so**

Check how the approval is actually implemented. For GitHub Actions,
distinguish between:

- documented approval
- environment protection
- actual configured reviewers
- executable workflow behaviour

**Mistake 5: Assuming rollback works because `kubectl rollout undo` appears
in the file**

Check:

- revision selection
- namespace
- target workload
- readiness
- failure handling
- validation after rollback

**Mistake 6: Treating a passing parser as production readiness**

Syntax is only the beginning.

**Mistake 7: Ignoring missing edge cases**

A solution that works for the exact starter example may still fail for:

- another region
- another cluster size
- an unexpected Terraform plan state
- a failed dependency
- a forked pull request
- a partial deployment
- an unavailable service

## 30. Safety requirements

Never use real production credentials during evaluation.

Never send:

- AWS access keys
- Kubernetes production credentials
- database passwords
- API keys
- tokens
- certificates/private keys
- other production secrets

to a coding agent.

Do not apply generated infrastructure directly to production.

Use:

```bash
terraform validate
terraform plan
kubectl diff
kubectl apply --dry-run
```

or equivalent controlled validation where appropriate.

Any live testing should use an isolated non-production environment.

## 31. Reproducibility checklist

Before finalizing a benchmark run, record where practical:

- [ ] Model name
- [ ] Model/version
- [ ] Coding agent
- [ ] Task ID
- [ ] Prompt version
- [ ] Starter version
- [ ] Date
- [ ] Validation commands
- [ ] Validation results
- [ ] Score file
- [ ] Merge decision

The more consistent the metadata, the more useful the final comparison.

## 32. Final report workflow

Once all desired model/task pairs have been evaluated:

```bash
cd ~/infra-ai-testbed
```

Check the comparison tree:

```bash
find comparison -type f | sort
```

Check the score files:

```bash
find comparison \( -name 'score.yml' -o -name 'score.yaml' \) | sort
```

Generate the report:

```bash
scripts/generate-comparison-matrix.py
```

The result will be:

```text
comparison-matrix-<DDMMYYYY>.md
```

Open the generated report and review:

- The comparison table
- Missing model/task combinations
- Overall scores
- Merge decisions
- Top findings
- Strengths
- Task narratives
- Cross-cutting patterns

The generated report should be treated as a benchmark snapshot for that
date.

## 33. Final quality check

Before considering an evaluation cycle complete:

- [ ] Every intended model/task pair has output
- [ ] Every intended model/task pair has a score file
- [ ] Score files use `score.yml` or `score.yaml` consistently enough to be
      discovered by the generator
- [ ] Automated validators were run where available
- [ ] Scores are supported by evidence
- [ ] Critical security failures were explicitly considered
- [ ] Merge decisions are recorded
- [ ] Top findings are recorded
- [ ] Strengths are recorded
- [ ] Comparison matrix has been regenerated
- [ ] Generated narrative has been reviewed
- [ ] Cross-cutting patterns have been reviewed

## 34. Interpretation

The benchmark should not be reduced to a single leaderboard number.

A model with the highest overall score may still have a serious weakness in
a particular area.

For example:

> **Model A** — high correctness, high reliability, weak secret handling.

This may be less suitable for a security-sensitive task than a model with a
slightly lower overall score but consistently stronger security behaviour.

Use the matrix to identify:

- strongest overall performer
- strongest performer by task
- strongest security behaviour
- strongest reliability behaviour
- strongest edge-case reasoning
- strongest operational thinking
- recurring failure patterns
- model-specific weaknesses

The purpose is to understand engineering behaviour, not simply rank models.

## 35. Extending the benchmark

When adding a new task, `tasks/<new-task>/` should normally contain:

```text
PROMPT.md
starter/
criteria.md
expected-behaviors.md
README.md
```

Add an appropriate validator if useful.

Add the task to `README.md` and the evaluation material.

Ensure that the scoring template and comparison generator can represent any
new scoring information before running the benchmark.

Prefer realistic infrastructure failure modes over artificial coding
puzzles.

## 36. Benchmark principle

The central principle of this testbed is:

> Evaluate the engineering outcome, not the confidence of the agent's
> explanation.

A strong coding agent should be able to:

- understand the requirements
- inspect existing material
- implement the requested change
- preserve important semantics
- avoid introducing obvious security problems
- anticipate failure modes
- validate its work
- explain limitations honestly
- produce infrastructure that an experienced engineer could review and
  reasonably approve

That is the standard this evaluation process is intended to measure.

---

## Recommended report layout

Keep `evaluation/comparison-matrix.md` as the human-readable **template**
exactly where it is, and treat each generated
`comparison-matrix-<DDMMYYYY>.md` as a dated benchmark snapshot.

That gives a clean separation:

```text
evaluation/
└── comparison-matrix.md          # template

comparison/
├── claude-sonnet-4-5/
├── codex-gpt-oss-1-20b/
└── kiro-qwen-3-coder-next/       # raw outputs + scores

comparison-matrix-02092026.md     # generated benchmark snapshot
```

This structure is stronger for reproducibility and makes it possible to run
the benchmark again later without destroying the previous comparison.