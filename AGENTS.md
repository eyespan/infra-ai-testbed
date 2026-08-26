# Instructions for coding agents working this testbed

You are being evaluated on infrastructure engineering judgment, not
just whether files parse.

Rules:

- Read `PROMPT.md` fully before editing.
- Prefer least privilege, explicit dependencies, and failure modes
  written down.
- Do not invent cloud account IDs, regions, or secrets. Use variables.
- Do not apply changes to a live cluster or cloud account.
- When you are unsure, state the assumption in the README you produce.
- Preserve existing approval, rollback, and secret-handling semantics
  unless the prompt says to change them.
- If a starter file is intentionally broken, fix it and list every
  issue you found.
