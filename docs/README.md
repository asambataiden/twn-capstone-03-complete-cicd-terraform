# Capstone 03 — Engineering Documentation

This folder supplements the [project README](../README.md). All status claims are based on the merged Jenkinsfile, deployment script, Compose file and 1 November 2026 execution evidence.

## Navigation

| Document | Purpose |
|---|---|
| [Architecture overview](architecture/architecture-overview.md) | System boundaries, identities, infrastructure and delivery |
| [Release and rollback flows](architecture/release-and-rollback-flow.md) | Detailed Mermaid flowcharts and failure handling |
| [Deployment runbook](operations/deployment-runbook.md) | Safe CI, authorized rollout, verification and recovery |
| [Evidence register](evidence/verification-register.md) | Verified commands, releases and limitations |
| [Automation review](improvements/automation-opportunities.md) | Manual-to-automated improvements prioritized by risk |
| [Implementation use cases](learning/implemented-use-cases.md) | Step-by-step implemented workflows, learning and follow-ups |

## Evidence rules

**VERIFIED** = supported by passing Jenkins/SSM logs; **MOCK-TESTED** = tested with simulated external commands; **IMPLEMENTED** = present in source but not proven by a live failure-path test; **PROPOSED** = future work.

No credentials, raw registry tokens, Terraform state, or personal administrative access details belong in this folder. Avoid storing unredacted Jenkins logs.

## Important limitation

The verified Jenkinsfile deploys to existing Terraform-provisioned infrastructure. It **does not run Terraform apply**. Its `DEPLOY_TO_EC2` flag defaults to false. The live rollback failure path is not yet verified.
