#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_REF:?IMAGE_REF is required}"
: "${APP_VERSION:?APP_VERSION is required}"
: "${AWS_REGION:?AWS_REGION is required}"

COMPOSE_FILE="/opt/capstone03/compose.yaml"
ECR_REGISTRY="${IMAGE_REF%%/*}"

export DOCKER_CONFIG
DOCKER_CONFIG="$(mktemp -d)"
chmod 700 "$DOCKER_CONFIG"

trap 'rm -rf "$DOCKER_CONFIG"' EXIT

echo "Authenticating to ECR using EC2 IAM role"

aws ecr get-login-password \
  --region "$AWS_REGION" |
docker login \
  --username AWS \
  --password-stdin "$ECR_REGISTRY"

echo "Pulling immutable container image"

docker compose \
  -f "$COMPOSE_FILE" \
  pull

echo "Deploying application"

docker compose \
  -f "$COMPOSE_FILE" \
  up -d \
  --no-build \
  --wait \
  --wait-timeout 180

echo "Checking application HTTP health"

curl --fail --silent --show-error \
  --retry 10 \
  --retry-delay 3 \
  --retry-connrefused \
  http://127.0.0.1:8080/health

echo
echo "Verifying deployed container"

docker compose \
  -f "$COMPOSE_FILE" \
  ps

echo "Capstone 03 deployment successful"
