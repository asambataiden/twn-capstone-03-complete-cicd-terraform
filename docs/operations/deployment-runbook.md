# Deployment and recovery runbook

**Scope:** Existing Capstone 03 EC2 instance and application, not first-install Terraform provisioning. **Do not use the production-like instance to inject failures.**

## Prerequisites

- Approved and reviewed Jenkinsfile, deployment scripts and immutable ECR artifact.
- Jenkins Shared Library pinned to `c514371`.
- Separate credentials `twn-capstone03-ecr-publisher` and `twn-capstone03-ssm-deployer`.
- EC2 target is online in SSM, existing release is healthy, EC2 role can pull from ECR.
- No concurrent release outside the Jenkins job.

## 1. CI-only release quality gate

Use `DEPLOY_TO_EC2=false` (default). Choose `REUSE_PUBLISHED_IMAGE=false` for a **new** Git tag; true for an **already published** tag only after verifying its provenance. Jenkins must pass source checks, five mocked rollback tests, image build, smoke test, AWS identity and ECR steps. Deployment stage must be skipped.

## 2. Explicit deployment

After reviewing target instance, digest and release window, use `DEPLOY_TO_EC2=true` and `REUSE_PUBLISHED_IMAGE=true` for an already published commit. Confirm the job's SCM branch and deployment policy: the merged Jenkinsfile still contains a feature-branch-specific `BRANCH_NAME` guard, which must be deliberately refactored before enabling production-like automatic deployment from `main`. Do not bypass safety by manipulating environment variables.

Jenkins invokes `ssmDeploy`; the remote script checks the old healthy release, pulls the digest, performs Compose rollout, and verifies digest, health and application version.

## 3. Verification

Confirm **all**: SSM `Status=Success`, `ResponseCode=0`, running Docker `Config.Image` points to requested digest, `State.Health.Status=healthy`, `GET /` JSON `version` equals the requested commit. A previous independent verification used SSM command `bf59b16b-5de3-428f-8120-0c481d91d857`.

Do not interpret the existence of a submitted SSM command, or a green Jenkins stage alone, as complete runtime verification.

## 4. On unsuccessful deployment

1. Inspect Jenkins stage logs, SSM command invocation details and remote error output.
2. Check whether the script logged `ROLLBACK SUCCESS` or `ROLLBACK FAILED`.
3. If rollback succeeded, keep the release marked failed and investigate root cause before retrying.
4. If rollback failed, stop automated retries and recover the workload manually using the last known-good immutable digest, verified config, and approved incident procedure.
5. Record incident times, failed/current digests, command IDs, health checks, remediation and lessons learned.

## 5. Controlled local validation

```bash
bash -n scripts/deploy-ec2.sh
python3 -m unittest discover -s tests -p 'test_deploy.py' -v
```

These use mocked dependencies. They do not simulate the entire SSM/EC2 network or host failure environment.

## 6. Risk and cost controls

Keep Terraform infrastructure changes in a reviewed, separate workflow; limit IAM permissions, monitor resource costs, store registry credentials only in ephemeral Docker config, and avoid exposing Jenkins over HTTP on an unrestricted public endpoint.
