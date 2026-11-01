# Verification register — Capstone 03

Evidence date: **1 November 2026**. This is an index of previously observed results, not an assertion of ongoing health.

| Use case | Evidence | Finding |
|---|---|---|
| Jenkins regression gate | Jenkins CI-only build for Git `84a74d8a7966`; five tests passed | VERIFIED |
| CI-only deployment guard | `Deploy to EC2 via SSM` stage skipped in Jenkins CI-only run | VERIFIED |
| ECR artifact | `git-84a74d8a7966` resolved to digest below | VERIFIED |
| Jenkins-driven rollout | SSM command `80c32db2-afb6-41a4-b11f-0bc333591541`, status Success, response 0 | VERIFIED |
| Independent runtime readback | SSM command `bf59b16b-5de3-428f-8120-0c481d91d857`, status Success, response 0 | VERIFIED |
| Deployed version | `84a74d8a7966` returned from localhost app endpoint | VERIFIED |
| Docker runtime | `capstone03-app-1` health `healthy` | VERIFIED |
| Image digest | `sha256:8a28d96d32b94457c37ceaf888f472bc1ac529e1cb5f85236db534d00290064d` | VERIFIED |
| Five rollback scenarios | Python `unittest` with mocked AWS/Docker/HTTP | MOCK-TESTED |
| Live rollback following injected failure | No supporting live SSM log | NOT VERIFIED |
| Terraform apply inside current Jenkinsfile | Stage absent | NOT IMPLEMENTED |
| TWN badge/approval | No reviewer decision documented | NOT VERIFIED |

## Safe reproduction

Run locally from repository root:

```bash
bash -n scripts/deploy-ec2.sh
python3 -m unittest discover -s tests -p 'test_deploy.py' -v
git status --short
```

For future evidence capture: record the Git SHA, Jenkins build URL and number, SSM CommandId, immutable digest, application version, time in UTC, status, and sanitized output. Exclude access keys, session tokens, secret values and personal account details.

**Note:** Jenkins UI screenshots showed a job named `TWN-Capstone-03-SSM-Deployer-Preflight` running the complete pipeline. Job naming and responsibility should be cleaned up separately; do not silently relabel historical evidence.
