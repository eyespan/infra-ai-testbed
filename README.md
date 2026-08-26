# Infrastructure AI Agent Testbed

A structured evaluation harness for **frontier coding agents** on realistic
infrastructure engineering work: cloud platforms, Kubernetes, CI/CD,
observability, and infrastructure automation.

Use this repository to:

- Give the same task to multiple frontier coding agents
- Review generated implementations with a professional checklist
- Identify bugs, edge cases, reliability issues, and failure modes
- Compare model strengths and weaknesses side by side
- Apply engineering judgment to merge / reject decisions

This is **not** a live cloud lab. Tasks are designed so agents produce
code and written analysis. Automated validators catch syntax and policy
issues; humans score reasoning, security, and production readiness.

## Quick start

1. Pick a task under `tasks/`.
2. Give the agent `PROMPT.md` plus everything in `starter/`.
3. Save the output under `comparison/<model-name>/<task-id>/`.
4. Run the matching script in `scripts/` (optional, if tools are installed).
5. Score with `evaluation/rubric.md` and fill `evaluation/scoring-template.yaml`.
6. Update `evaluation/comparison-matrix.md`.

Do **not** apply generated infrastructure to a real account. Review first.

## Tasks

| ID | Task | Domain | Difficulty |
|----|------|--------|------------|
| 01 | Terraform EKS module | Cloud / IaC | Hard |
| 02 | Secure Kubernetes deployment | Kubernetes | Medium |
| 03 | Jenkins to GitHub Actions | CI/CD | Hard |
| 04 | Observability stack | Observability | Medium |
| 05 | Incident triage | Reliability | Hard |
| 06 | IaC policy guardrails | Automation / policy | Medium |

Each task folder contains:

- `PROMPT.md` — exact prompt to give the agent
- `starter/` — incomplete or intentionally flawed inputs
- `criteria.md` — review checklist (bugs, edge cases, reliability)
- `expected-behaviors.md` — what a strong solution looks like
- `README.md` — how to run this task

## Repository layout

```
infra-ai-testbed/
├── README.md
├── HOW_TO_EVALUATE.md
├── AGENTS.md
├── evaluation/
│   ├── rubric.md
│   ├── scoring-template.yaml
│   └── comparison-matrix.md
├── scripts/
│   ├── validate-terraform.sh
│   ├── validate-k8s.sh
│   ├── validate-gha.sh
│   └── score-run.sh
├── tasks/
│   ├── 01-terraform-eks-module/
│   ├── 02-k8s-secure-deployment/
│   ├── 03-cicd-github-actions/
│   ├── 04-observability-stack/
│   ├── 05-incident-triage/
│   └── 06-iac-policy-guardrails/
├── baselines/          # optional known-good solutions (you add later)
└── comparison/         # drop model outputs here
```

## What you will do

- Use frontier AI coding agents to complete and evaluate complex
  infrastructure engineering tasks.
- Review model-generated implementations involving cloud platforms,
  Kubernetes, CI/CD systems, observability, and infrastructure automation.
- Identify bugs, edge cases, reliability issues, and failure modes.
- Compare outputs from multiple frontier models and assess strengths
  and weaknesses.
- Apply professional engineering judgment to realistic infrastructure
  scenarios.

## Safety

- Never feed real production secrets into an agent.
- Never `terraform apply` or `kubectl apply` generated code against
  production without a human review and a non-prod dry run.
- Treat agent output as untrusted until scored.

## Expanding the suite

Add a new folder under `tasks/` with the same five files. Keep prompts
self-contained. Prefer starter files that encode real failure modes
(hardcoded secrets, missing probes, dropped approval gates) over empty
scaffolds.

See `HOW_TO_EVALUATE.md` for the scoring workflow.
