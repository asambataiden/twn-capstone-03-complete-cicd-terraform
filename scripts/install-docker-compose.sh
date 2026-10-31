#!/usr/bin/env bash
set -euo pipefail

COMPOSE_VERSION="v5.6.1"
ARCH="$(uname -m)"
PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"

if [[ "$ARCH" != "x86_64" ]]; then
  echo "Unsupported architecture: $ARCH" >&2
  exit 1
fi

BASE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}"
ASSET="docker-compose-linux-${ARCH}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl --fail --location --retry 3 \
  "${BASE_URL}/${ASSET}" \
  --output "${TMP_DIR}/${ASSET}"

curl --fail --location --retry 3 \
  "${BASE_URL}/${ASSET}.sha256" \
  --output "${TMP_DIR}/${ASSET}.sha256"

(
  cd "$TMP_DIR"
  sha256sum --check "${ASSET}.sha256"
)

install -d -m 0755 "$PLUGIN_DIR"
install -m 0755 \
  "${TMP_DIR}/${ASSET}" \
  "${PLUGIN_DIR}/docker-compose"

docker compose version
