# Manual vs automated — improvement backlog

This analysis separates **current implementation** from **recommended future automation**. Proposed work must not be described as completed.

| Priority | Current workflow | Manual gap / risk | Recommended change | Acceptance criteria |
|---|---|---|---|---|
| P0 | Jenkins reachable via public HTTP in screenshots | Credentials/session exposure | HTTPS via reverse proxy, limit public network, review authentication and permissions | TLS validated; access restricted; no public unauthenticated Jenkins |
| P0 | Existing ECR tag can be reused | Local smoke-tested image not independently matched against remote digest | Compare trusted locally built image manifest or provenance to selected ECR artifact; fail closed | Reuse mismatch prevents deployment |
| P0 | Branch-specific Jenkins deploy guard | Current condition recognizes feature branch only when `BRANCH_NAME` exists | Refactor to explicit protected-branch approval strategy, test with main | CI-only main builds pass; CD requires deliberate authorization |
| P1 | Post-deploy independent SSM check run manually | Hard to guarantee every release checked | Build digest/version/health readback into Jenkins with saved report | Every deployment publishes a machine-readable verification artifact |
| P1 | Mocked rollback tests in CI | No realistic failure recovery test | Isolated disposable test EC2 or Docker environment; failure injection | Demonstrated failed release and verified restoration without harming live workload |
| P1 | Manual pull requests and mixed Jenkins jobs | No consistently reported PR status | PR-triggered CI, GitHub status checks, branch rules | Review cannot merge while required validation fails |
| P1 | Manual AWS/IAM and Jenkins job configuration | Configuration drift | Terraform IAM/infra + Jenkins Configuration as Code/Job DSL | Clean environment recreated reproducibly from versioned config |
| P1 | Jenkins deploy credentials are stored AWS keys | Rotation and leakage risk | Role federation / short-lived credentials where supported | No long-lived static deploy keys |
| P2 | SSM commands and screenshots collected ad hoc | Evidence can be lost | Archive sanitized Jenkins + SSM command metadata, structured release manifest | Traceable release record per build |
| P2 | Health endpoint only | Limited availability/performance insight | Prometheus/Grafana metrics, alerts, structured logs | Alert fires on injected unhealthy condition |
| P2 | Handwritten architecture and steps | Documentation drift | Mermaid as code, PR docs checks and generated inventory reports | Docs reviewed and validated on change |

## Suggested delivery order

1. Protect Jenkins ingress and fix main-branch release policy.
2. Add image provenance and post-deployment verification checks.
3. Add required PR validation and auditable release artifacts.
4. Verify rollback in an isolated lab and move config to IaC/JCasC.
5. Expand observability and automate documentation validation.

## Automation versus judgment

Automate deterministic checks, build, test, publish, release readback and evidence collection. Keep **human approval** for production-impacting deployment, Terraform apply, privilege expansion, merge decisions, and disaster recovery unless a reviewed policy authorizes otherwise.

## Technical debt to preserve explicitly

- ECR SHA digests may remain identical across multiple Git commits when the image build context is unchanged.
- The current Jenkins job's deployment guard is feature-branch-specific and does not independently enforce branch trust for a plain Pipeline-from-SCM job with no `BRANCH_NAME`.
- `disableConcurrentBuilds()` prevents overlap in one job, not every deployer targeting the EC2 instance.
- Rollback code needs a healthy prior baseline and locally retained prior image.
