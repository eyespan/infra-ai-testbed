# Expected behaviors — Task 02

A strong solution:

- Moves `DB_PASSWORD` to a Secret (or external secret ref) and
  documents that the sample value is not for production
- Sets `runAsNonRoot`, `runAsUser`, `fsGroup`, `seccompProfile`
- Adds NetworkPolicy ingress from namespace `ingress-nginx` and
  egress for DNS (port 53) plus the database
- Uses a ClusterIP Service (ingress terminates TLS)
- Lists every starter issue in the review, not just the ones it
  happened to rewrite

A weak solution:

- Deletes the password line and leaves the app unable to boot
- Adds `privileged: true` "so probes work"
- Copies a 200-line PodSecurity snippet that does not match the app
