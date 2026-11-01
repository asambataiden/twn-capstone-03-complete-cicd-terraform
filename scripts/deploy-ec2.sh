#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_REF:?IMAGE_REF is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${AWS_REGION:?AWS_REGION is required}"

COMPOSE_FILE="/opt/capstone03/compose.yaml"
CONTAINER_NAME="capstone03-app-1"
HEALTH_URL="http://127.0.0.1:8080"
ECR_REGISTRY="${IMAGE_REF%%/*}"

[[ "$IMAGE_REF" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9._/-]+@sha256:[a-f0-9]{64}$ ]] || {
  echo "ERROR: IMAGE_REF must be an immutable ECR digest" >&2
  exit 1
}
[[ "$APP_VERSION" =~ ^[a-f0-9]{7,40}$ ]] || {
  echo "ERROR: APP_VERSION must be a Git revision" >&2
  exit 1
}

export DOCKER_CONFIG
DOCKER_CONFIG="$(mktemp -d)"
chmod 700 "$DOCKER_CONFIG"
trap 'rm -rf "$DOCKER_CONFIG"' EXIT

# Capture the last known good state before any container mutation.
OLD_IMAGE="$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}')"
OLD_VERSION="$(curl -fsS "$HEALTH_URL/" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
OLD_HEALTH="$(docker inspect "$CONTAINER_NAME" --format '{{.State.Health.Status}}')"
[[ "$OLD_IMAGE" =~ @sha256:[a-f0-9]{64}$ && "$OLD_VERSION" =~ ^[a-f0-9]{7,40}$ && "$OLD_HEALTH" == healthy ]] || {
  echo "ERROR: No verified healthy rollback baseline" >&2
  exit 1
}

verify_release() {
  local expected_image="$1" expected_version="$2"
  local actual_image actual_health actual_version
  actual_image="$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}')" || return 1
  actual_health="$(docker inspect "$CONTAINER_NAME" --format '{{.State.Health.Status}}')" || return 1
  actual_version="$(curl -fsS "$HEALTH_URL/" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')" || return 1
  [[ "$actual_image" == "$expected_image" && "$actual_health" == healthy && "$actual_version" == "$expected_version" ]]
}

echo "Previous healthy release: $OLD_IMAGE (version $OLD_VERSION)"
echo "Target release: $IMAGE_REF (version $APP_VERSION)"

echo "Authenticating with ECR using EC2 instance IAM role"
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Pulling target image before changing the running service"
docker pull --platform linux/amd64 "$IMAGE_REF"
docker image inspect "$IMAGE_REF" >/dev/null

# A subshell keeps errexit effective and avoids trapping the rollback itself.
if (
  set -euo pipefail
  export IMAGE_REF APP_VERSION
  docker compose -f "$COMPOSE_FILE" config -q
  docker compose -f "$COMPOSE_FILE" up -d --no-build --wait --wait-timeout 180
  verify_release "$IMAGE_REF" "$APP_VERSION"
); then
  echo "PASS: target image, application version and healthy status verified"
  exit 0
fi

echo "ERROR: Deployment failed; attempting previous healthy release" >&2
export IMAGE_REF="$OLD_IMAGE" APP_VERSION="$OLD_VERSION"

if (
  set -euo pipefail
  docker image inspect "$IMAGE_REF" >/dev/null
  docker compose -f "$COMPOSE_FILE" up -d --no-build --wait --wait-timeout 180
  verify_release "$IMAGE_REF" "$APP_VERSION"
); then
  echo "ROLLBACK SUCCESS: previous release restored and verified" >&2
else
  echo "ROLLBACK FAILED: manual recovery required; do not retry blindly" >&2
fi

# Always fail the Jenkins/SSM job when the requested deployment failed,
# even if rollback succeeded.
exit 1
