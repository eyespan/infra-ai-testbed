# Scoring rubric

Score each dimension 0–5. Use half points only if you must. Record
evidence (file + line or quote) for any score below 4.

## Dimensions

### 1. Correctness

| Score | Meaning |
|------:|---------|
| 0 | Does not parse, or fundamentally wrong resource types |
| 1 | Parses but cannot plan / apply conceptually |
| 2 | Partial: core resource exists, dependencies broken |
| 3 | Works with minor manual fixes |
| 4 | Validators pass; small omissions |
| 5 | Complete, internally consistent, would plan cleanly |

### 2. Security

| Score | Meaning |
|------:|---------|
| 0 | Secrets in source, world-open admin ports, privileged by default |
| 2 | Several CIS-class misses |
| 3 | Mostly secure, 1–2 real gaps |
| 4 | Least privilege with a documented residual risk |
| 5 | Encryption, IAM, network, secrets, and privilege all addressed |

**Automatic fail:** plaintext production secrets committed; SSH/RDP
open to `0.0.0.0/0`; cluster-admin bound to a workload SA without
justification.

### 3. Reliability

| Score | Meaning |
|------:|---------|
| 0 | Happy path only; no probes, no PDBs, no retries, no rollback |
| 3 | Common failures handled |
| 5 | Explicit failure modes, budgets, rollback, and blast-radius notes |

### 4. Edge cases

Does the solution mention or handle AZ count, version skew, empty
desired capacity, image tag mutability, missing attributes in a plan,
cardinality explosion, flaky tests, etc.?

### 5. Engineering judgment

Trade-offs written down. Alternatives considered. Known limitations
honest. Not cargo-cult copy-paste.

### 6. Observability / operations

Metrics, logs, alerts, runbooks, or a coherent triage sequence —
whichever the task requires.

## Overall

```
overall = mean(six dimensions)
pass    = overall >= 3.5 AND no critical security fail
```

## Merge decision

- **Yes** — would merge after a normal PR review
- **Yes with changes** — mergeable after listed fixes
- **No** — unsafe or too incomplete
