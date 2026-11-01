# CI/CD and rollback flows

## Delivery sequence (implemented)

```mermaid
flowchart TD
  A["SCM checkout + pinned library"] --> B["Python syntax + Bash syntax"]
  B --> C["Five mocked rollback regression tests"]
  C --> D["Build linux/amd64 image"]
  D --> E["Ephemeral container smoke test"]
  E --> F["Validate publisher AWS identity"]
  F --> G{"REUSE_PUBLISHED_IMAGE?"}
  G -->|false| H["Publish new immutable Git tag"]
  G -->|true| I["Resolve previously published tag"]
  H --> J["Resolve ECR image digest"]
  I --> J
  J --> K{"DEPLOY_TO_EC2?"}
  K -->|false| L["End: CI-only success"]
  K -->|true| M["Bind separate SSM credential"]
  M --> N["Send remote deployment command"]
  N --> O["Validate old healthy baseline"]
  O --> P["Pull target image by digest"]
  P --> Q["docker compose up --wait"]
  Q --> R["Verify image + health + version"]
  R --> S{"All match?"}
  S -->|yes| T["Report successful release"]
  S -->|no| U["Attempt previous image + version"]
  U --> V["Verify restored state"]
  V --> W["Return failure to Jenkins"]
```

## Recovery boundary

```mermaid
flowchart TD
  BASE{"Healthy previous version accessible?"}
  BASE -->|no| ABORT["Abort before deployment"]
  BASE -->|yes| PUSH["Deploy requested digest"]
  PUSH --> CHECK{"Compose and verification successful?"}
  CHECK -->|yes| OK["Success"]
  CHECK -->|no| RESTORE["Restore previous image/version"]
  RESTORE --> RCHK{"Previous release healthy?"}
  RCHK -->|yes| RBOK["Rollback succeeded; Jenkins fails requested release"]
  RCHK -->|no| FAIL["Rollback failed; intervention required"]
```

**Verified:** normal deployment and release readback. **Mock-tested:** successful rollout, version mismatch recovery, health failure recovery, rollback failure detection, and unhealthy baseline rejection. **Not verified:** live injected failure and recovery, zero-downtime service, disaster recovery.

## Engineering caution

Image pull and initial ECR authorization occur before the rollback subshell. The implementation aims to avoid changing the running workload when an image is unavailable, but does not claim recovery from every host, Docker, disk, or network failure. Multiple concurrent external deployers must be prevented independently of Jenkins' `disableConcurrentBuilds()`.
