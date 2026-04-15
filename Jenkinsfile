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

        DEPLOY_DIR     = "/home/khevin/foodfrenzy-deploy"

        HARBOR_CREDS   = credentials('harbor-credentials')
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
                echo "=== CLEAN + CHECKOUT ==="
                deleteDir()
                checkout scm

                sh '''
                    echo "WORKSPACE: $WORKSPACE"
                    ls -la
                    test -f pom.xml || (echo "ERROR: pom.xml missing" && exit 1)
                '''
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
                                -v "$WORKSPACE:/src" \
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
                                -v "$WORKSPACE:/path" \
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

        /* ===================== MAVEN BUILD (FIXED) ===================== */
        stage('Build Maven') {
            steps {
                sh '''
                    echo "=== MAVEN BUILD ==="

                    docker run --rm \
                        -v "$WORKSPACE:/app" \
                        -v "$HOME/.m2:/root/.m2" \
                        -w /app \
                        maven:3.9.6-eclipse-temurin-17 \
                        mvn clean package -DskipTests -B

                    ls -lh target/*.jar || true
                '''
            }
        }

        /* ===================== OWASP ===================== */
        stage('OWASP') {
            steps {
                sh '''
                    mkdir -p reports

                    docker run --rm \
                        -v "$WORKSPACE:/src" \
                        -v "$WORKSPACE/reports:/report" \
                        owasp/dependency-check:latest \
                        --scan /src \
                        --format HTML \
                        --out /report \
                        --project FoodFrenzy || true

                    echo "OWASP OK"
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

        /* ===================== PUSH HARBOR ===================== */
        stage('Push Harbor') {
            steps {
                sh '''
                    echo "$HARBOR_CREDS_PSW" | docker login $HARBOR_HOST \
                        -u "$HARBOR_CREDS_USR" --password-stdin

                    docker push $IMAGE_FULL
                    docker push $IMAGE_LATEST

                    docker logout $HARBOR_HOST
                '''
            }
        }

        /* ===================== DEPLOY ===================== */
        stage('Deploy') {
            steps {
                sh '''
                    mkdir -p $DEPLOY_DIR
                    cp docker-compose.yml $DEPLOY_DIR/

                    cd $DEPLOY_DIR

                    if [ ! -f .env ]; then
                        cat > .env <<EOF
MYSQL_ROOT_PASSWORD=RootP@ssw0rd!
DB_USER=foodfrenzy_user
DB_PASSWORD=FoodP@ssw0rd!
HARBOR_HOST=localhost:8081
HARBOR_USER=admin
HARBOR_PASSWORD=Harbor12345
IMAGE_TAG=$BUILD_NUMBER
EOF
                    else
                        sed -i "s/IMAGE_TAG=.*/IMAGE_TAG=$BUILD_NUMBER/" .env
                    fi

                    docker compose down || true
                    docker compose up -d --pull always
                    docker compose ps
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