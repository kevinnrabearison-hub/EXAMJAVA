pipeline {

    agent any

    environment {
        APP_NAME       = "foodfrenzy-app"
        HARBOR_HOST    = "localhost:8081"
        HARBOR_PROJECT = "foodfrenzy"

        IMAGE_NAME     = "localhost:8081/foodfrenzy/foodfrenzy-app"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        IMAGE_FULL     = "localhost:8081/foodfrenzy/foodfrenzy-app:${BUILD_NUMBER}"
        IMAGE_LATEST   = "localhost:8081/foodfrenzy/foodfrenzy-app:latest"

        DEPLOY_DIR     = "/opt/foodfrenzy-deploy"

        // === SECRETS (Masqués dans les logs Jenkins) ===
        HARBOR_CREDS   = credentials('harbor-credentials') // contient HARBOR_CREDS_USR et HARBOR_CREDS_PSW
        DB_ROOT_PWD    = credentials('mysql-root-password')
        DB_APP_USER    = "foodfrenzy_user"
        DB_APP_PWD     = credentials('db-app-password')
        DB_NAME        = "foodfrenzy_db"
        COSIGN_PWD     = credentials('cosign-key-password')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        /* ===================== CHECKOUT ===================== */
        stage('Checkout') {
            steps {
                echo "===CHECKOUT ==="
                checkout scm
            }
        }

        /* ===================== RESOLVE HOST WORKSPACE ===================== */
        stage('Resolve Host Workspace') {
            steps {
                script {
                    // Récupère le vrai chemin du workspace sur l'hôte Docker
                    // en inspectant le volume monté dans le conteneur Jenkins
                    env.HOST_WORKSPACE = sh(
                        script: '''
                            docker inspect jenkins \
                                --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}'
                        ''',
                        returnStdout: true
                    ).trim() + "/workspace/FoodFrenzy-Pipeline"

                    echo "HOST_WORKSPACE resolved: ${env.HOST_WORKSPACE}"
                }
            }
        }

        /* ===================== SAST ===================== */
        stage('SAST') {
            parallel {

                stage('Semgrep') {
                    steps {
                        sh '''
                            mkdir -p reports

                            docker run --rm \
                                -v "$HOST_WORKSPACE:/src" \
                                -w /src \
                                returntocorp/semgrep:latest \
                                semgrep --config p/java \
                                --json --output reports/semgrep.json src/ || true

                            echo "Semgrep OK"
                        '''
                    }
                }

                stage('Gitleaks') {
                    steps {
                        sh '''
                            mkdir -p reports

                            docker run --rm \
                                -v "$HOST_WORKSPACE:/path" \
                                zricethezav/gitleaks:latest detect \
                                --source /path \
                                --report-format json \
                                --report-path /path/reports/gitleaks.json \
                                --exit-code 0 || true

                            echo "Gitleaks OK"
                        '''
                    }
                }
            }
        }

        /* ===================== MAVEN BUILD ===================== */
        stage('Build Maven') {
            steps {
                sh '''
                    echo "=== MAVEN BUILD ==="
                    echo "Mounting HOST_WORKSPACE: $HOST_WORKSPACE"

                    docker run --rm \
                        -v "$HOST_WORKSPACE:/app" \
                        -v "$HOST_WORKSPACE/.m2:/root/.m2" \
                        -w /app \
                        maven:3.9.6-eclipse-temurin-17 \
                        mvn clean package -DskipTests -B

                    ls -lh target/*.jar || true
                '''
            }
        }



        /* ===================== DOCKER BUILD ===================== */
        stage('Build Docker') {
            steps {
                sh '''
                    docker build -t $IMAGE_FULL -t $IMAGE_LATEST .
                    docker images | grep foodfrenzy || true
                '''
            }
        }

        /* ===================== TRIVY ===================== */
        stage('Trivy') {
            steps {
                sh '''
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --format table \
                        $IMAGE_FULL || true

                    echo "Trivy OK"
                '''
            }
        }
                /* ===================== OWASP ===================== */
        stage('OWASP') {
            steps {
                sh '''
                    mkdir -p reports
                    docker run --rm \
                        -v "$HOST_WORKSPACE:/src" \
                        -v "$HOST_WORKSPACE/reports:/report" \
                        owasp/dependency-check:latest \
                        --scan /src \
                        --format HTML --format JSON \
                        --out /report \
                        --project FoodFrenzy || true
                '''
            }
        }

        /* ===================== SBOM (Excellence) ===================== */
        stage('SBOM') {
            steps {
                sh '''
                    echo "=== GENERATING SBOM (Syft) ==="
                    mkdir -p reports
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v "$HOST_WORKSPACE/reports:/out" \
                        anchore/syft:latest \
                        $IMAGE_FULL -o json > reports/sbom.json || true
                '''
            }
        }

        /* ===================== SIGNATURE (Excellence) ===================== */
        stage('Sign Image') {
            steps {
                sh '''
                    echo "=== SIGNING IMAGE (Cosign) ==="
                    chmod +x scripts/sign.sh
                    COSIGN_PASSWORD=$COSIGN_PWD ./scripts/sign.sh $IMAGE_FULL
                '''
            }
        }

        /* ===================== PUSH HARBOR ===================== */
        stage('Push Harbor') {
            steps {
                sh '''
                    set +x
                    echo "$HARBOR_CREDS_PSW" | docker login $HARBOR_HOST \
                        -u "$HARBOR_CREDS_USR" --password-stdin
                    set -x

                    docker push $IMAGE_FULL
                    docker push $IMAGE_LATEST

                    docker logout $HARBOR_HOST
                '''
            }
        }

        /* ===================== VERIFY (Pre-Deploy) ===================== */
        stage('Verify Signature') {
            steps {
                sh '''
                    echo "=== VERIFYING SIGNATURE ==="
                    chmod +x scripts/verify.sh
                    ./scripts/verify.sh $IMAGE_FULL
                '''
            }
        }

        /* ===================== DEPLOY ===================== */
stage('Deploy') {
    steps {
        sh '''
            set -euo pipefail

            DEPLOY_DIR="/opt/foodfrenzy-deploy"

            echo "Deploying to $DEPLOY_DIR"

            # --- CREATE DIR SAFE ---
            mkdir -p "$DEPLOY_DIR"

            # --- COPY COMPOSE FILE ---
            cp docker-compose.yml "$DEPLOY_DIR/"
            cd "$DEPLOY_DIR"

            # --- ENV FILE (SÉCURISÉ : Plus de mots de passe en dur !) ---
            cat > .env <<EOF
MYSQL_ROOT_PASSWORD=${DB_ROOT_PWD}
DB_USER=${DB_APP_USER}
DB_PASSWORD=${DB_APP_PWD}
DB_NAME=${DB_NAME}
HARBOR_HOST=${HARBOR_HOST}
HARBOR_USER=${HARBOR_CREDS_USR}
HARBOR_PASSWORD=${HARBOR_CREDS_PSW}
IMAGE_TAG=${BUILD_NUMBER}
EOF

            echo "Stopping previous stack..."

            # --- SAFE DOCKER COMPOSE HANDLING ---
            if docker compose version >/dev/null 2>&1; then
                echo "Using docker compose v2"

                docker compose down --remove-orphans || true
                docker compose up -d --pull always
                docker compose ps

            elif command -v docker-compose >/dev/null 2>&1; then
                echo "Using docker-compose v1"

                docker-compose down || true
                docker-compose up -d
                docker-compose ps

            else
                echo "ERROR: No Docker Compose available in Jenkins container"
                exit 1
            fi
        '''
    }
}

        /* ===================== HEALTH CHECK ===================== */
        stage('Health Check') {
            steps {
                sh '''
                    echo "Waiting Spring Boot..."

                    for i in $(seq 1 15); do
                        curl -sf http://localhost:8090/actuator/health && exit 0
                        echo "Try $i/15"
                        sleep 10
                    done

                    echo "FAILED HEALTH CHECK"
                    exit 1
                '''
            }
        }
    }

    /* ===================== POST ===================== */
    post {
        success {
            echo "PIPELINE SUCCESS - Build #${BUILD_NUMBER}"
        }

        failure {
            echo "PIPELINE FAILED"
            sh '''
                docker compose -f $DEPLOY_DIR/docker-compose.yml logs --tail=30 || true
            '''
        }

        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
            sh '''
                docker rmi $IMAGE_FULL || true
                docker image prune -f || true
            '''
        }
    }
}