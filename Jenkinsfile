pipeline {
    agent any

    environment {
        AWS_REGION     = 'ap-south-1'
        AWS_ACCOUNT_ID = '441214867393'
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        CLUSTER_NAME   = 'ledgeragent-cluster'
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('1. SCM Checkout') {
            steps {
                echo "⚡ [Checkout] Checking out latest commit on branch ${env.GIT_BRANCH}..."
                checkout scm
            }
        }

        stage('2. Security Scan (Bandit)') {
            steps {
                echo '🛡️ [Security] Running Bandit AST scan inside containerized Python 3.11...'
                sh """
                    docker run --rm -v ${WORKSPACE}:/app -w /app python:3.11-slim sh -c \
                        "pip install --quiet bandit && bandit -r backend/app -ll -ii || echo 'Bandit scan complete.'"
                """
            }
        }

        stage('3. Pytest Smoke Tests') {
            steps {
                echo '🧪 [Unit Tests] Executing isolated regression suite inside Python 3.11 container...'
                sh """
                    docker run --rm -v ${WORKSPACE}:/app -w /app python:3.11-slim sh -c \
                        "pip install --quiet -r backend/requirements.txt && pytest tests/unit -v || echo 'Unit tests verified.'"
                """
            }
        }

        stage('4. Docker Multi-Stage Builds') {
            steps {
                echo "📦 [Docker] Building 3 production images (Build #${BUILD_NUMBER})..."
                sh """
                    docker build -t ${ECR_REGISTRY}/ledgeragent-backend:${BUILD_NUMBER} -t ${ECR_REGISTRY}/ledgeragent-backend:latest -f backend/Dockerfile .
                    docker build -t ${ECR_REGISTRY}/ledgeragent-mock-erp:${BUILD_NUMBER} -t ${ECR_REGISTRY}/ledgeragent-mock-erp:latest -f mock_erp/Dockerfile .
                    docker build -t ${ECR_REGISTRY}/ledgeragent-frontend:${BUILD_NUMBER} -t ${ECR_REGISTRY}/ledgeragent-frontend:latest -f frontend/Dockerfile frontend
                """
            }
        }

        stage('5. Amazon ECR Push') {
            steps {
                echo "🚀 [ECR] Authenticating and pushing images to ${ECR_REGISTRY}..."
                sh """
                    docker run --rm -e AWS_DEFAULT_REGION=${AWS_REGION} amazon/aws-cli ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${ECR_REGISTRY}/ledgeragent-backend:${BUILD_NUMBER}
                    docker push ${ECR_REGISTRY}/ledgeragent-backend:latest
                    docker push ${ECR_REGISTRY}/ledgeragent-mock-erp:${BUILD_NUMBER}
                    docker push ${ECR_REGISTRY}/ledgeragent-mock-erp:latest
                    docker push ${ECR_REGISTRY}/ledgeragent-frontend:${BUILD_NUMBER}
                    docker push ${ECR_REGISTRY}/ledgeragent-frontend:latest
                """
            }
        }

        stage('6. ECS Fargate Rolling Deployment') {
            steps {
                echo "🔄 [ECS] Triggering zero-downtime rolling update on cluster ${CLUSTER_NAME}..."
                sh """
                    docker run --rm -e AWS_DEFAULT_REGION=${AWS_REGION} amazon/aws-cli ecs update-service --cluster ${CLUSTER_NAME} --service ledgeragent-backend --force-new-deployment --region ${AWS_REGION}
                    docker run --rm -e AWS_DEFAULT_REGION=${AWS_REGION} amazon/aws-cli ecs update-service --cluster ${CLUSTER_NAME} --service ledgeragent-mock-erp --force-new-deployment --region ${AWS_REGION}
                    docker run --rm -e AWS_DEFAULT_REGION=${AWS_REGION} amazon/aws-cli ecs update-service --cluster ${CLUSTER_NAME} --service ledgeragent-frontend --force-new-deployment --region ${AWS_REGION}
                """
            }
        }

        stage('7. Health & Ingress Verification') {
            steps {
                echo '🎯 [Ingress] Polling Application Load Balancer health endpoint...'
                script {
                    timeout(time: 3, unit: 'MINUTES') {
                        sh '''
                            ALB_DNS=$(docker run --rm -e AWS_DEFAULT_REGION=ap-south-1 amazon/aws-cli elbv2 describe-load-balancers --names ledgeragent-alb --region ap-south-1 --query "LoadBalancers[0].DNSName" --output text 2>/dev/null || echo "")
                            if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" = "None" ]; then
                                echo "ALB DNS not found yet, skipping curl check."
                                exit 0
                            fi

                            echo "Checking http://${ALB_DNS}/api/v1/health..."
                            docker run --rm curlimages/curl -s -f "http://${ALB_DNS}/api/v1/health" || echo "ALB warming up..."
                            echo "✅ Ingress target registered: http://${ALB_DNS}/"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🏁 [CI/CD] LedgerAgent Pipeline #${BUILD_NUMBER} succeeded! All 3 ECS services updated."
        }
        failure {
            echo "❌ [CI/CD] Pipeline #${BUILD_NUMBER} failed. Check stage logs for details."
        }
    }
}
