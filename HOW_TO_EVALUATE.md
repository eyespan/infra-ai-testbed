# How to evaluate an agent run

## Protocol

1. **Freeze the prompt.** Copy `tasks/<id>/PROMPT.md` verbatim. Do not
   coach the model unless you are testing a follow-up turn (then record it).
2. **Give starter files.** Attach or paste everything under `starter/`.
3. **One model, one worktree.** Isolate each run so files do not leak
   between models.
4. **Capture everything.** Save generated files, the full transcript,
   tool calls, and wall-clock time under `comparison/<model>/<task-id>/`.
5. **Validate mechanically** with `scripts/` where tools exist.
6. **Score with the rubric.** Six dimensions, 0–5 each. A critical
   security miss is an automatic fail regardless of average.
7. **Write a merge decision.** Yes / Yes with changes / No, plus why.

## Fair comparison rules

- Same prompt, same starter, same tool access if possible.
- Record model name, date, and whether the agent could run shell tools.
- If one agent iterates on `terraform validate` errors and another
  cannot, note that in the comparison matrix — it is a capability, not
  a scoring error.
- Do not "fix up" output before scoring. Score the artifact as produced.

## Pass bar

A task **passes** when:

- Average score ≥ 3.5
- No critical security finding (secrets in git, open SSH to the world,
  privileged containers without justification, dropped prod approval)
- Mechanical validators that apply to the task succeed, or failures are
  documented as known limitations in the agent's README

## Suggested first comparison set

Run tasks 02, 05, and 03 first. They cover Kubernetes hardening,
incident reasoning, and CI/CD semantics — the three places agents
usually fail differently.
