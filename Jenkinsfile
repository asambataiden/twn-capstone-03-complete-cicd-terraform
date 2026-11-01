
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

    parameters {
        booleanParam(name: 'DEPLOY_TO_EC2', defaultValue: false,
                     description: 'Explicitly authorize SSM deployment to Capstone 03 EC2')
        booleanParam(name: 'REUSE_PUBLISHED_IMAGE', defaultValue: false,
                     description: 'Resolve existing immutable ECR tag instead of pushing again')
    }

    environment {
        DOCKER_PLATFORM = 'linux/amd64'
    }

    stages {
        stage('Validate Shared Library') {
            steps {
                script {
                    library 'twn-devops-bootcamp-jenkins-shared-library@c514371'

                    echo 'PASS: Jenkins Shared Library loaded successfully'
                    echo 'PASS: Pinned to revision c514371'
                    echo 'No ECR publishing or SSM deployment executed'
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm

                sh '''#!/usr/bin/env bash
set -euo pipefail

echo "=== Git revision ==="
git rev-parse HEAD
git log -1 --format='%s'
'''
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

ast.parse(
    source.read_text(encoding="utf-8")
)

print("PASS: Python source syntax")
PY
'''
            }
        }


stage('Deployment Regression Tests') {
    steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail

echo "=== Validate deployment script syntax ==="
bash -n scripts/deploy-ec2.sh

echo "=== Run rollback regression tests ==="
python3 -m unittest discover \
    -s tests \
    -p 'test_deploy.py' \
    -v

echo "PASS: Deployment regression tests"
'''
    }
}


        stage('Build Docker Image') {
            steps {
                script {
                    String gitSha = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim()

                    String imageRef = ecrBuild(
                        accountId: '591132357918',
                        region: 'eu-north-1',
                        repository: 'twn-capstone-03-app',
                        tag: "git-${gitSha}".toString(),
                        dockerfile: 'app/Dockerfile',
                        context: 'app',
                        platform: 'linux/amd64'
                    )

                    // Publish image reference to later stages.
                    env.IMAGE_REF = imageRef

                    echo 'PASS: Shared Library ecrBuild completed'
                    echo "Local image: ${imageRef}"
                    echo 'Build complete; publishing follows successful validation'
                }
            }
        }

        stage('Application Smoke Test') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

# IMAGE_REF comes from the preceding Jenkins Groovy stage.
IMAGE_TAG="${IMAGE_REF:?IMAGE_REF is not set}"
CONTAINER_NAME="cap03-ci-${BUILD_NUMBER}"
APP_VERSION="$(git rev-parse --short=12 HEAD)"

echo "=== Verify locally built image ==="

docker image inspect "$IMAGE_TAG" >/dev/null || {
    echo "ERROR: Docker image not found: $IMAGE_TAG" >&2
    exit 1
}

ACTUAL_PLATFORM="$(
    docker image inspect "$IMAGE_TAG" \
        --format '{{.Os}}/{{.Architecture}}'
)"

if [[ "$ACTUAL_PLATFORM" != "$DOCKER_PLATFORM" ]]; then
    echo "ERROR: Architecture mismatch: $ACTUAL_PLATFORM" >&2
    exit 1
fi

echo "PASS: Using locally built image: $IMAGE_TAG"
echo "PASS: Image platform: $ACTUAL_PLATFORM"

cleanup() {
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "=== Start application container ==="

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

echo "=== Wait for application readiness ==="

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
    echo "FAIL: Application did not become healthy" >&2
    docker logs "$CONTAINER_NAME" >&2 || true
    exit 1
fi

echo "=== Verify application endpoints ==="

docker exec \
    --env "EXPECTED_VERSION=$APP_VERSION" \
    "$CONTAINER_NAME" \
    python -c '
import json
import os
import urllib.request

base = "http://127.0.0.1:8080"

with urllib.request.urlopen(
    base + "/health", timeout=3
) as response:
    assert response.status == 200
    health = json.load(response)
    assert health["status"] == "healthy"

with urllib.request.urlopen(
    base + "/", timeout=3
) as response:
    assert response.status == 200
    application = json.load(response)

    assert application["application"] == "twn-capstone-03"
    assert application["status"] == "running"
    assert application["version"] == os.environ["EXPECTED_VERSION"]

print("PASS: Health endpoint")
print("PASS: Application endpoint")
print("PASS: Application Git version")
'

echo "PASS: Capstone 03 application smoke test"
'''
            }
        }

        stage('AWS Identity Preflight') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'twn-capstone03-ecr-publisher',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    withEnv([
                        'AWS_DEFAULT_REGION=eu-north-1',
                        'AWS_REGION=eu-north-1',
                        'AWS_PAGER='
                    ]) {
                        sh '''#!/usr/bin/env bash
        set -euo pipefail

        EXPECTED_ACCOUNT="591132357918"
        EXPECTED_ARN="arn:aws:iam::591132357918:user/twn-capstone03-ecr-publisher"

        # Prevent an inherited profile or credential-file setting
        # from changing the intended authentication source.
        unset AWS_PROFILE AWS_SESSION_TOKEN
        unset AWS_CONFIG_FILE AWS_SHARED_CREDENTIALS_FILE

        ACTUAL_ACCOUNT="$(
            aws sts get-caller-identity \
                --query Account \
                --output text
        )"

        ACTUAL_ARN="$(
            aws sts get-caller-identity \
                --query Arn \
                --output text
        )"

        if [[ "$ACTUAL_ACCOUNT" != "$EXPECTED_ACCOUNT" ]]; then
            echo "FAIL: AWS account mismatch" >&2
            exit 1
        fi

        if [[ "$ACTUAL_ARN" != "$EXPECTED_ARN" ]]; then
            echo "FAIL: AWS principal mismatch" >&2
            exit 1
        fi

        echo "PASS: Correct AWS account"
        echo "PASS: Dedicated Capstone 03 publisher identity"
        echo "PASS: AWS authentication successful"
        echo "No ECR push or EC2 deployment performed"
        '''
                    }
                }
            }
        }

        stage('Publish Image to ECR') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'twn-capstone03-ecr-publisher',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]
                ]) {
                    withEnv([
                        'AWS_DEFAULT_REGION=eu-north-1',
                        'AWS_REGION=eu-north-1',
                        'AWS_PAGER='
                    ]) {
                        script {
                            String gitSha = sh(
                                script: 'git rev-parse --short=12 HEAD',
                                returnStdout: true
                            ).trim()
                            String imageTag = "git-${gitSha}".toString()

                            if (!params.REUSE_PUBLISHED_IMAGE) {
                                // ECR tags are immutable. A second push of the same tag is rejected.
                                String publishedRef = ecrPush(
                                    accountId: '591132357918',
                                    region: 'eu-north-1',
                                    repository: 'twn-capstone-03-app',
                                    tag: imageTag
                                )
                                if (publishedRef != env.IMAGE_REF) {
                                    error('Published image reference differs from tested image')
                                }
                                echo "PASS: Published image: ${publishedRef}"
                            } else {
                                echo "Reusing immutable ECR tag: ${imageTag}"
                            }

                            String digestRef = ecrImageDigest(
                                accountId: '591132357918',
                                region: 'eu-north-1',
                                repository: 'twn-capstone-03-app',
                                tag: imageTag
                            )
                            env.IMAGE_DIGEST_REF = digestRef
                            echo "PASS: Resolved immutable image digest: ${digestRef}"
                            echo 'SSM deployment is a separate opt-in stage'
                        }
                    }
                }
            }
        }

        stage('Deploy to EC2 via SSM') {
            when {
                expression { params.DEPLOY_TO_EC2 == true }
            }
            steps {
                // Provision this dedicated credential before enabling deployment.
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'twn-capstone03-ssm-deployer',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    withEnv([
                        'AWS_DEFAULT_REGION=eu-north-1',
                        'AWS_REGION=eu-north-1',
                        'AWS_PAGER='
                    ]) {
                        script {
                            if (env.BRANCH_NAME &&
                                env.BRANCH_NAME != 'feat/capstone03-jenkins-ci-pipeline') {
                                error('Deployment blocked: unexpected branch')
                            }

                            String sha = sh(
                                script: 'git rev-parse --short=12 HEAD',
                                returnStdout: true
                            ).trim()

                            if (!env.IMAGE_DIGEST_REF?.trim()) {
                                error('Deployment blocked: missing immutable image digest')
                            }

                            String commandId = ssmDeploy(
                                accountId: '591132357918',
                                region: 'eu-north-1',
                                instanceId: 'i-058aa03bdbb014833',
                                imageRef: env.IMAGE_DIGEST_REF,
                                appVersion: sha,
                                composeFile: 'deploy/compose.ec2.yaml',
                                deployScript: 'scripts/deploy-ec2.sh'
                            )

                            echo "PASS: SSM deployment completed: ${commandId}"
                            echo "Deployed image: ${env.IMAGE_DIGEST_REF}"
                            echo "Application version: ${sha}"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            sh '''#!/usr/bin/env bash
set +e

docker rm -f "cap03-ci-${BUILD_NUMBER}" \
    >/dev/null 2>&1

echo "Temporary container cleanup checked"
'''
        }

        success {
            echo 'SUCCESS: Capstone 03 CI validation completed.'
            echo 'Check Deploy to EC2 stage for deployment status.'
        }

        failure {
            echo 'FAILURE: Capstone 03 CI validation failed.'
            echo 'Review the failed stage in Jenkins Console Output.'
        }
    }
}
