You are the on-call engineer. A Deployment named `payments` in
namespace `prod` is in CrashLoopBackOff.

Starting information:

- `kubectl get pods` shows 0/1 Ready, restart count climbing
- Last deployment was 40 minutes ago
- No recent cluster upgrades

Frozen command output is in `starter/`. Treat that as the only
cluster you can see. Do not invent logs, events, or metrics that
are not in those files.

Perform a coherent triage sequence. For each step state:

1. What you would run (or which starter file you read)
2. What signal you are looking for
3. What you conclude and the next action

Finally:

- Name the most likely root cause given the evidence
- Propose a safe remediation including a rollback path
- List edge cases that would change the diagnosis
- List what you still do not know

Write the answer as `TRIAGE.md`.
