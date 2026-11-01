# Capstone 03 — Implemented use cases and engineering learning

## 1. Bootstrap and identity verification

**Problem:** Jenkins and EC2 need different AWS permissions.  
**Implemented:** Dedicated ECR publishing identity, SSM deployer identity, EC2 role with ECR pull permissions, identity and SSM preflight tests.  
**Verified:** Jenkins AWS identity checks, SSM target online and send-command preflight.  
**Better:** Temporary credentials with federation; policy as code and automated access checks.

## 2. Python application and image validation

**Problem:** An image may build but not run or report expected behavior.  
**Implemented:** Python syntax check, amd64 Docker build, ephemeral hardened container, app /health and version checks.  
**Verified:** Jenkins CI pipeline success.  
**Better:** Add unit/integration tests and image vulnerability scan; pin base image by digest and dependency versions.

## 3. Publishing and selecting release artifacts

**Problem:** A mutable image tag can drift from the tested artifact.  
**Implemented:** Git-tagged ECR publication and immutable digest resolution.  
**Verified:** ECR publish and resolve logs.  
**Better:** Local/remote image provenance cross-check on reused tags; SBOM and signed attestations.

## 4. Remote rollout without SSH

**Problem:** A Jenkins agent should not need an open SSH ingress path to deploy to EC2.  
**Implemented:** Shared Library `ssmDeploy` via SendCommand, polling and remote Docker Compose deploy script.  
**Verified:** Jenkins-triggered deployment command completed successfully.  
**Better:** Formal deployment approval, log archival and post-deployment verification stage in Jenkins.

## 5. Failure recovery

**Problem:** A broken image could replace a healthy service.  
**Implemented:** Capture healthy previous image/version, verify new release, attempt rollback on failure, retain failed Jenkins outcome.  
**Verified:** Five mocked regression tests; successful healthy rollout.  
**Not verified:** Real failure-induced EC2 recovery.  
**Better:** Disposable failure-injection environment and a documented incident recovery runbook.

## 6. Independent release evidence

**Problem:** Jenkins stage success is not enough to prove runtime state.  
**Implemented:** Manual read-only SSM verification of image digest, version and Docker health.  
**Verified:** Command `bf59b16b-5de3-428f-8120-0c481d91d857` returned Success/0, healthy, correct version and digest.  
**Better:** Make verification an automated mandatory pipeline gate and archive a structured report.

## 7. Change management and portfolio

**Problem:** Working infrastructure without reproducible records is hard to review.  
**Implemented:** Git feature branch, passing regression tests, PR #1 reviewed/merged, README with Q&A and What I Learned.  
**Verified:** Merge commit `de06a6b` on `main`.  
**Better:** GitHub required CI checks, PR templates, ADRs, sanitized evidence and periodic doc drift checks.

## Takeaway

The project demonstrates a functioning release delivery system with safety guards, not an unattended production platform. Operational maturity comes from controlling permissions, evidence, failure modes and human approvals—not merely adding more infrastructure components.
