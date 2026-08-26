# Task 01 — Terraform EKS module

Give the agent `PROMPT.md` and the files under `starter/`.

The starter is an incomplete module: a VPC sketch, hardcoded region,
missing IRSA, missing logging, and a node group that cannot actually
join the cluster.

Validate with:

```
scripts/validate-terraform.sh comparison/<model>/01-terraform-eks-module
```
