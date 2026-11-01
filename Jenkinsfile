
pipeline {
    agent {
        label 'twn-ecr-agent-01'
    }

    options {
        timestamps()
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
        skipDefaultCheckout()
    }

    environment {
        IMAGE_NAME = 'capstone03-ci'
        DOCKER_PLATFORM = 'linux/amd64'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Source') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import ast
from pathlib import Path

source = Path("app/main.py")
ast.parse(source.read_text(encoding="utf-8"))

print("PASS: Python source syntax")
PY
'''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_NAME}:${BUILD_NUMBER}"

docker buildx build \
    --platform "$DOCKER_PLATFORM" \
    --provenance=false \
    --load \
    --file app/Dockerfile \
    --tag "$IMAGE_TAG" \
    ./app

ACTUAL_PLATFORM="$(
    docker image inspect "$IMAGE_TAG" \
        --format '{{.Os}}/{{.Architecture}}'
)"

test "$ACTUAL_PLATFORM" = "$DOCKER_PLATFORM"

echo "PASS: Image built for $ACTUAL_PLATFORM"
'''
            }
        }

        stage('Application Smoke Test') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_NAME}:${BUILD_NUMBER}"
CONTAINER_NAME="cap03-ci-${BUILD_NUMBER}"
APP_VERSION="$(git rev-parse --short=12 HEAD)"

cleanup() {
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

docker run \
    --detach \
    --rm \
    --name "$CONTAINER_NAME" \
    --platform "$DOCKER_PLATFORM" \
    --read-only \
    --tmpfs /tmp \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --env "APP_VERSION=$APP_VERSION" \
    "$IMAGE_TAG"

ready=0

for attempt in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" python -c \
        'import urllib.request; urllib.request.urlopen("http://127.0.0.1:8080/health", timeout=2)' \
        >/dev/null 2>&1; then
        ready=1
        break
    fi

    sleep 1
done

if [[ "$ready" != "1" ]]; then
    docker logs "$CONTAINER_NAME" >&2 || true
    echo "FAIL: Application not healthy" >&2
    exit 1
fi

docker exec \
    --env "EXPECTED_VERSION=$APP_VERSION" \
    "$CONTAINER_NAME" \
    python -c '
import json
import os
import urllib.request

base = "http://127.0.0.1:8080"

with urllib.request.urlopen(base + "/health", timeout=3) as response:
    assert response.status == 200
    assert json.load(response)["status"] == "healthy"

with urllib.request.urlopen(base + "/", timeout=3) as response:
    assert response.status == 200
    data = json.load(response)
    assert data["application"] == "twn-capstone-03"
    assert data["status"] == "running"
    assert data["version"] == os.environ["EXPECTED_VERSION"]

print("PASS: Health, application and version verification")
'

echo "PASS: Capstone 03 smoke test"
'''
            }
        }
    }

    post {
        always {
            sh '''#!/usr/bin/env bash
set +e

docker rm -f "cap03-ci-${BUILD_NUMBER}" >/dev/null 2>&1
echo "Temporary container cleanup checked"
'''
        }

        success {
            echo 'Capstone 03 CI validation successful.'
        }

        failure {
            echo 'Capstone 03 CI validation failed.'
        }
    }
}
