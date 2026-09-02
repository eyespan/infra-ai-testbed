# Infrastructure AI Agent Testbed

> **Engineering Portfolio Project**
>
> A structured evaluation harness for **frontier coding agents** on realistic
infrastructure engineering work: cloud platforms, Kubernetes, CI/CD,
observability, reliability, and infrastructure automation.

> The purpose of this repository is to evaluate whether AI coding agents can
produce infrastructure work that is not merely syntactically correct, but
also secure, reliable, operationally sound, and appropriate for production
use.

```mermaid
flowchart TB

    A["📋 TASK DEFINITION<br/><br/>PROMPT.md<br/>Starter files<br/>Criteria<br/>Expected behaviours"]

    A --> B

    B["🤖 FRONTIER CODING AGENT<br/><br/>Claude<br/>Codex<br/>Kiro<br/>Other agents"]

    B --> C["🛠️ IMPLEMENTATION<br/><br/>Infrastructure code<br/>Configuration<br/>Documentation<br/>Analysis"]

    C --> D["📦 MODEL OUTPUT<br/><br/>comparison/<br/>model/task/"]

    D --> E["⚙️ AUTOMATED VALIDATION<br/><br/>Syntax<br/>Terraform<br/>Kubernetes<br/>GitHub Actions<br/>Policy checks"]

    E --> F["👨‍💻 HUMAN REVIEW<br/><br/>Correctness<br/>Security<br/>Reliability<br/>Edge cases<br/>Engineering judgment<br/>Operations"]

    F --> G["📝 EVIDENCE & SCORE<br/><br/>score.yaml<br/>Findings<br/>Top bug<br/>Strength<br/>Merge decision"]

    G --> H["📊 COMPARISON MATRIX<br/><br/>Model × Task<br/>Mechanical checks<br/>Six evaluation dimensions<br/>Overall score"]

    H --> I["🧠 BENCHMARK INSIGHTS<br/><br/>Strengths<br/>Weaknesses<br/>Failure modes<br/>Cross-cutting patterns"]

    I --> J["✅ ENGINEERING DECISION<br/><br/>MERGE<br/>MERGE WITH CHANGES<br/>REJECT"]

    K["⚠️ SAFETY BOUNDARY<br/><br/>Generated infrastructure is untrusted<br/>Do not apply to production<br/>Human review required"]

    D -.-> K
    K -.-> F

    style A fill:#e3f2fd,stroke:#1565c0,stroke-width:3px
    style B fill:#f3e5f5,stroke:#6a1b9a,stroke-width:3px
    style C fill:#fff3e0,stroke:#e65100,stroke-width:3px
    style D fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    style E fill:#fce4ec,stroke:#ad1457,stroke-width:3px
    style F fill:#fff8e1,stroke:#f57f17,stroke-width:4px
    style G fill:#e0f7fa,stroke:#00695c,stroke-width:3px
    style H fill:#ede7f6,stroke:#4527a0,stroke-width:3px
    style I fill:#f1f8e9,stroke:#558b2f,stroke-width:3px
    style J fill:#ffebee,stroke:#c62828,stroke-width:4px
    style K fill:#ffecb3,stroke:#ff8f00,stroke-width:3px,stroke-dasharray: 6 4
  ```

**Repository:** https://github.com/eyespan/infra-ai-testbed/

Use this repository to:

- Give the same task to multiple coding agents
- Provide each agent with the same task requirements and starter material
- Preserve each agent's generated implementation independently
- Run automated validators where available
- Review generated implementations with a professional engineering rubric
- Identify bugs, edge cases, security issues, reliability problems, and
  operational weaknesses
- Record evidence and scores consistently
- Compare model strengths and weaknesses side by side
- Apply engineering judgment to merge / reject decisions
- Generate a reproducible comparison matrix across models and tasks

This is **not** a live cloud lab.

Tasks are designed so agents produce code, configuration, infrastructure
definitions, and/or written analysis. Automated validators catch syntax,
structural, and policy issues where practical. Human evaluation is still
required for reasoning quality, security, edge cases, reliability, judgment,
and production readiness.

---

## Quick start

### 1. Choose a task

Pick a task under:

```text
tasks/
```

Each task contains the requirements, starter material, review criteria, and
expected behaviours.

For example:

```text
tasks/03-cicd-github-actions/
```

### 2. Give the task to the coding agent

Provide the agent with:

```text
tasks/<task-id>/PROMPT.md
tasks/<task-id>/starter/
```

The agent should work in the existing repository and inspect the task
requirements and starter files before making changes.

A good agent prompt should explicitly require the agent to:

- Read the task requirements first
- Inspect all relevant starter files
- Implement the task rather than merely describe a solution
- Create all required deliverables
- Place the generated implementation in the designated comparison directory
- Verify the generated files before finishing
- Avoid modifying unrelated benchmark material

### 3. Save the agent output

Each model/run should have its own directory:

```text
comparison/<model-name>/<task-id>/
```

For example:

```text
comparison/
├── claude-sonnet-4-5/
│   ├── 01-terraform-eks-module/
│   ├── 02-k8s-secure-deployment/
│   ├── 03-cicd-github-actions/
│   ├── 04-observability-stack/
│   ├── 05-incident-triage/
│   └── 06-iac-policy-guardrails/
│
├── codex-gpt-oss-1-20b/
│   ├── 01-terraform-eks-module/
│   ├── 02-k8s-secure-deployment/
│   └── ...
│
└── kiro-qwen-3-coder-next/
    ├── 01-terraform-eks-module/
    ├── 02-k8s-secure-deployment/
    └── ...
```

Do not overwrite another model's output.

The comparison directory is intended to preserve the evidence produced by
each model independently.

### 4. Run automated validation

Where a task provides a validator, run the matching script in:

```text
scripts/
```

Examples:

```text
scripts/validate-terraform.sh
scripts/validate-k8s.sh
scripts/validate-gha.sh
scripts/score-run.sh
```

The exact commands and prerequisites are documented by the individual task
and evaluation material.

Automated validation is evidence, not a replacement for human review.

A configuration can pass syntax validation and still contain serious:

- security problems
- reliability problems
- incorrect assumptions
- missing edge-case handling
- operational weaknesses
- production-readiness issues

### 5. Score the run

Use:

```text
evaluation/rubric.md
evaluation/scoring-template.yaml
```

Each evaluated model/task should have a score file inside its comparison
directory.

Both of the following extensions are supported:

- `score.yml`
- `score.yaml`

The benchmark therefore accepts:

```text
comparison/<model>/<task>/score.yml
```

or:

```text
comparison/<model>/<task>/score.yaml
```

The score file is the authoritative record of the evaluation.

It should contain the scores, evidence, merge decision, top finding, and
strength for that model/task run.

---

## Scoring model

The benchmark evaluates six primary engineering dimensions:

- Correctness
- Security
- Reliability
- Edge cases
- Engineering judgment
- Operations / observability

Each dimension is scored from `0` to `5`.

Tasks may also have **Mechanical checks**.

Mechanical checks are reported separately because they are normally objective
pass/fail checks rather than a judgement score.

For example:

```text
Mechanical: 3/3
```

or:

```text
Mechanical: N/A
```

### Overall score

The overall score is the mean of the applicable scored dimensions.

Conceptually:

```text
overall = mean(
    correctness,
    security,
    reliability,
    edges,
    judgment,
    operations
)
```

The default pass bar is:

```text
overall >= 3.5
```

However, a run must also avoid a critical security failure.

Therefore:

```text
PASS =
    overall >= 3.5
    AND
    critical_security_fail == false
```

A high numerical score must not hide a critical security defect.

### Merge decisions

The evaluation should distinguish between:

- `yes`
- `yes_with_changes`
- `no`

Use:

- `yes` when the implementation is suitable to merge as submitted
- `yes_with_changes` when the implementation is broadly sound but requires
  material fixes before merging
- `no` when the implementation contains unacceptable defects or does not
  satisfy the task sufficiently

A merge decision is an engineering judgement and should be supported by the
recorded evidence.

### Evidence-based scoring

Scores should be based on observable evidence.

Prefer evidence such as:

```text
modules/eks/main.tf:299-322 creates a managed node group
```

over vague statements such as:

```text
The solution looks production ready.
```

Useful evidence can include:

- file paths
- line ranges
- validator output
- test results
- policy results
- configuration values
- explicit omissions
- incorrect assumptions
- documented limitations
- implementation behaviour

The objective is to make another engineer able to understand why the score
was awarded.

---

## Tasks

| ID | Task | Domain | Difficulty |
|----|------|--------|------------|
| 01 | Terraform EKS module | Cloud / IaC | Hard |
| 02 | Secure Kubernetes deployment | Kubernetes | Medium |
| 03 | Jenkins to GitHub Actions | CI/CD | Hard |
| 04 | Observability stack | Observability | Medium |
| 05 | Incident triage | Reliability | Hard |
| 06 | IaC policy guardrails | Automation / policy | Medium |

Each task folder normally contains:

```text
PROMPT.md
starter/
criteria.md
expected-behaviors.md
README.md
```

**`PROMPT.md`**
The exact task prompt intended for the coding agent.

**`starter/`**
Incomplete, intentionally flawed, or constrained material supplied to the
agent.

Starter files should represent realistic infrastructure situations rather
than empty coding exercises.

**`criteria.md`**
Task-specific review criteria covering issues such as:

- correctness
- security
- reliability
- edge cases
- operational behaviour

**`expected-behaviors.md`**
Characteristics expected from a strong solution.

This should describe the desired engineering behaviour without requiring the
agent to reproduce a single fixed implementation.

**`README.md`**
Task-specific execution and validation instructions.

---

## Repository layout

```text
infra-ai-testbed/
├── README.md
├── HOW_TO_EVALUATE.md
├── AGENTS.md
│
├── evaluation/
│   ├── rubric.md
│   ├── scoring-template.yaml
│   └── comparison-matrix.md
│
├── scripts/
│   ├── validate-terraform.sh
│   ├── validate-k8s.sh
│   ├── validate-gha.sh
│   ├── score-run.sh
│   └── generate-comparison-matrix.py
│
├── tasks/
│   ├── 01-terraform-eks-module/
│   ├── 02-k8s-secure-deployment/
│   ├── 03-cicd-github-actions/
│   ├── 04-observability-stack/
│   ├── 05-incident-triage/
│   └── 06-iac-policy-guardrails/
│
├── baselines/
│   └── # optional known-good solutions
│
├── comparison/
│   ├── <model-1>/
│   ├── <model-2>/
│   └── <model-3>/
│
└── comparison-matrix-<DDMMYYYY>.md
```

---

## Comparison matrix generation

The benchmark includes an automated comparison-matrix generator:

```text
scripts/generate-comparison-matrix.py
```

The generator reads:

```text
comparison/**/score.yml
comparison/**/score.yaml
```

and uses:

```text
evaluation/comparison-matrix.md
```

as the template.

It writes the generated report into the repository root as:

```text
comparison-matrix-<DDMMYYYY>.md
```

For example:

```text
comparison-matrix-02092026.md
```

Run it from the repository root:

```bash
scripts/generate-comparison-matrix.py
```

or:

```bash
python3 scripts/generate-comparison-matrix.py
```

The generator automatically:

- discovers model/task score files
- supports both `.yml` and `.yaml`
- extracts mechanical results
- extracts dimension scores
- calculates/uses the recorded overall score
- records merge decisions
- records the top finding
- records the main strength
- orders results by task and model
- generates task-level narratives when multiple models have been evaluated
- generates cross-cutting patterns
- writes a dated report into the repository root

The template in `evaluation/comparison-matrix.md` is therefore the input
template, not the final report.

Do not manually edit the generated dated report unless it is being used for
a specific publication or snapshot.

### Comparison report structure

The generated report contains two major parts.

**Comparison table**

One row is generated for each `(model, task)` pair.

The table includes:

- Model
- Task
- Mechanical
- Correct
- Secure
- Reliable
- Edges
- Judgment
- Ops
- Overall
- Merge
- Top bug
- Strength

This makes it possible to compare models both within a task and across the
entire benchmark.

**Task narratives**

When two or more models have been scored for the same task, the generator
creates a narrative section such as:

```text
Task 03 — CI/CD migration
```

The narrative summarizes:

- each model's result
- score differences
- important strengths
- top findings
- edge cases identified
- edge cases missed

This is intended to answer a more useful question than "which model has the
highest score?" It should also reveal why the models differed, and what
engineering behaviours caused the difference.

**Cross-cutting patterns**

The generated report also looks across tasks for recurring patterns such as:

- IDE-first vs terminal-native
- cloud-specific depth vs portability
- happy-path bias
- secret handling

These patterns are useful for identifying systematic model behaviour rather
than isolated mistakes.

For example, repeated findings around:

- public cloud endpoints
- plaintext secrets
- missing OIDC
- unpinned container images
- incomplete rollback evidence
- weak edge-case handling

may indicate a broader model tendency.

---

## Evaluation philosophy

This benchmark is designed to distinguish between "the agent produced
something that looks right" and "the agent produced infrastructure that an
experienced engineer could reasonably approve."

A strong result should therefore demonstrate more than implementation speed.
It should demonstrate:

- accurate interpretation of requirements
- preservation of existing semantics
- security awareness
- failure-mode awareness
- production reasoning
- operational thinking
- appropriate validation
- explicit handling of uncertainty
- sensible trade-offs
- evidence-based conclusions

### What you will do

Use frontier AI coding agents to:

- complete infrastructure engineering tasks
- inspect existing infrastructure code
- modify Terraform
- create Kubernetes manifests
- migrate CI/CD pipelines
- design observability configurations
- perform incident analysis
- create infrastructure policy guardrails

Then:

- preserve the generated output
- run appropriate validators
- inspect the actual generated files
- score the implementation
- record evidence
- compare models
- make a merge/reject decision
- generate the comparison report

---

## Important evaluation principles

**Do not score filenames**

The existence of a file such as `networkpolicy.yaml`, `secret.yaml`, or
`serviceaccount.yaml` does not prove that the implementation is secure.
Inspect the contents.

**Do not score intent as implementation**

A model may write "OIDC authentication is enabled" while the actual workflow
uses long-lived credentials. Score the implementation, not the explanation.

**Do not confuse syntax validation with correctness**

A file can pass `terraform validate` and still contain:

- unsafe networking
- invalid production assumptions
- poor failure handling
- missing encryption
- inadequate validation
- unsupported versions

Likewise, valid Kubernetes YAML can still be operationally unsafe.

**Treat missing evidence as missing evidence**

If an agent claims "rollback provides zero downtime" but no evidence
supports that claim, do not automatically award the reliability points.
The benchmark rewards evidence-based engineering judgement.

**Separate "identified" from "missed"**

When scoring edge cases, distinguish between edge cases *identified* and
edge cases *missed*. A strong agent should not merely solve the happy path.
It should recognize conditions that can cause the implementation to fail in
real environments.

---

## Safety

This repository contains infrastructure examples and intentionally flawed
configurations.

Do not apply generated infrastructure directly to production.

Never run `terraform apply` or `kubectl apply` against a production account
or cluster without appropriate review and controlled non-production
validation.

Additional rules:

- Never feed real production secrets to an AI coding agent.
- Do not commit real credentials.
- Treat generated credentials and tokens as sensitive.
- Treat agent-generated infrastructure as untrusted until reviewed.
- Use isolated/non-production environments for live testing.
- Prefer dry runs and static validation where possible.
- Review IAM, networking, authentication, encryption, and secret handling
  before any deployment.

---

## Reproducibility

For meaningful model comparisons, keep the evaluation conditions as
consistent as possible.

Record where practical:

- model name
- model/version
- coding agent
- date
- task
- prompt version
- starter version
- validator results
- score file
- merge decision

Do not silently change the task prompt or starter material between model
runs.

If the benchmark itself changes, consider recording a benchmark/version
identifier in the evaluation material.

---

## Adding another model

To evaluate another coding agent:

1. Create a model directory under `comparison/`. For example:
   `comparison/new-model/`
2. Run each task using the same task requirements.
3. Store each result under `comparison/new-model/<task-id>/`.
4. Validate the generated output.
5. Create `score.yaml` or `score.yml`.
6. Score using `evaluation/rubric.md`.
7. Regenerate the comparison matrix:
   `scripts/generate-comparison-matrix.py`

---

## Expanding the suite

Add a new folder under `tasks/` using the established task structure.

Prefer tasks that represent realistic infrastructure engineering problems.

Good starter material should encode real failure modes such as:

- hardcoded secrets
- excessive IAM permissions
- public network exposure
- missing readiness/liveness probes
- missing resource limits
- unsafe deployment strategies
- dropped approval gates
- long-lived cloud credentials
- unpinned dependencies
- incorrect rollback logic
- weak policy validation
- missing observability
- incomplete failure handling

Avoid empty scaffolds that only test whether an agent can generate
boilerplate.

A good benchmark task should require engineering judgement.

---

## Baselines

Known-good reference implementations may be added under `baselines/`.

Baselines are optional.

They should be used as engineering references rather than as an answer key
that forces every model to reproduce exactly the same implementation.

Multiple technically valid solutions may exist.

---

## Final workflow

The intended end-to-end workflow is:

```text
Task
  │
  ▼
PROMPT.md + starter/
  │
  ▼
Coding agent
  │
  ▼
comparison/<model>/<task>/
  │
  ├── generated implementation
  ├── generated documentation
  └── validation evidence
  │
  ▼
Automated validation
  │
  ▼
Human review
  │
  ▼
score.yml / score.yaml
  │
  ▼
scripts/generate-comparison-matrix.py
  │
  ▼
comparison-matrix-<DDMMYYYY>.md
```

The goal is not simply to determine which model writes the most code.

The goal is to determine which coding agent demonstrates the strongest
overall infrastructure engineering judgement under consistent evaluation.


---

## Licence

Copyright © 2026 Eyespan Limited

Unless otherwise stated, the original source code, documentation, evaluation
materials, task definitions, prompts, and supporting material in this
repository are made available under the **MIT License**.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files, to use, copy, modify,
merge, publish, distribute, and/or sell copies of the software, subject to
the conditions of the MIT License.

The software is provided **"as is"**, without warranty of any kind, express
or implied.

See the [`LICENSE`](LICENSE) file for the complete licence text.

### Third-Party Licences

The MIT License applies only to original project material covered by this
repository's licence.

Third-party libraries, frameworks, models, datasets, images, documentation,
services, and other external materials remain subject to their respective
licences and terms.

In particular, outputs generated by external AI coding agents and any
third-party models or services used to produce those outputs may be subject
to additional terms and conditions.

Users of this project are responsible for reviewing and complying with the
applicable licences and terms.

---

## Disclaimer

This project is provided for educational, demonstration, research, evaluation,
and engineering portfolio purposes.

This repository is an evaluation testbed and is **not a production
infrastructure deployment platform or live cloud laboratory**.

No guarantee is made regarding:

- production suitability
- security or compliance
- availability
- performance
- scalability
- AWS or other cloud costs
- third-party service availability
- AI model behaviour
- accuracy or completeness of generated code
- accuracy or completeness of evaluation results
- suitability of generated infrastructure for a particular environment

Generated infrastructure, configuration, policies, workflows, and other
agent-produced artefacts should be treated as **untrusted until reviewed**.

Always review and adapt implementations to the requirements, security
controls, compliance obligations, and operational characteristics of your own
environment before deploying them.

Never apply generated infrastructure directly to a production environment
without appropriate human review, validation, and non-production testing.

---

## Why This Project Exists

The Infrastructure AI Agent Testbed was created to evaluate the engineering
capabilities of modern AI coding agents when working on realistic
infrastructure engineering problems.

The project focuses on more than whether an agent can produce code that
appears to work. It evaluates the engineering qualities required to produce
infrastructure that could be responsibly reviewed for real-world use:

**Correctness → Security → Reliability → Edge Cases → Engineering Judgment → Operations**

The testbed deliberately combines:

- cloud and infrastructure-as-code tasks
- Kubernetes configuration and security
- CI/CD migration and deployment automation
- observability and operational readiness
- incident investigation and root-cause analysis
- infrastructure policy and guardrails

Each task provides the same starting conditions and requirements to the
agents being evaluated. Generated implementations are then reviewed using a
common rubric, automated validation where appropriate, and human engineering
judgment.

The resulting comparison matrix provides a structured view of how different
coding agents perform across the same infrastructure challenges, including
where they succeed, where they fail, and which failure modes require human
intervention.

The broader objective is to understand where AI coding agents can
**accelerate infrastructure engineering** and where experienced engineers
must remain firmly in the review, validation, security, and operational
control loop.