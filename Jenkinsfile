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

        stage('Checkout') {
            steps {
                echo "=== Checkout ==="
                checkout scm
                sh 'git log --oneline -3'
            }
        }

        stage('SAST') {
            parallel {

                stage('Semgrep') {
                    steps {
                        sh '''
                            mkdir -p reports
                            docker run --rm \
                                -v "$(pwd)":/src \
                                --workdir /src \
                                returntocorp/semgrep:latest semgrep \
                                    --config "p/java" \
                                    --json \
                                    --output reports/semgrep-report.json \
                                    src/ || true
                            echo "Semgrep termine"
                        '''
                    }
                }

                stage('Gitleaks') {
                    steps {
                        sh '''
                            mkdir -p reports
                            touch reports/gitleaks-report.json
                            docker run --rm \
                                -v "$(pwd)":/path \
                                zricethezav/gitleaks:latest detect \
                                    --source /path \
                                    --report-format json \
                                    --report-path /path/reports/gitleaks-report.json \
                                    --exit-code 0 || true
                            echo "Gitleaks termine"
                        '''
                    }
                }
            }
        }

        stage('Build Maven') {
            steps {
                sh '''
                    echo "=== Build Maven ==="
                    ls -la
                    test -f pom.xml || (echo "pom.xml introuvable" && exit 1)
                    docker run --rm \
                        -v "$(pwd)":/app \
                        -v "$HOME/.m2":/root/.m2 \
                        -w /app \
                        maven:3.9.6-eclipse-temurin-17 \
                        mvn clean package -DskipTests -B --no-transfer-progress
                    ls -lh target/*.jar
                '''
            }
        }

        stage('OWASP') {
            steps {
                sh '''
                    mkdir -p reports
                    docker run --rm \
                        -v "$(pwd)":/src \
                        -v "$(pwd)/reports":/report \
                        owasp/dependency-check:latest \
                            --scan /src \
                            --format HTML \
                            --out /report \
                            --project "FoodFrenzy" || true
                    echo "OWASP termine"
                '''
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'reports',
                    reportFiles: 'dependency-check-report.html',
                    reportName: 'OWASP'
                ])
            }
        }

        stage('Build Docker') {
            steps {
                sh """
                    docker build \
                        --no-cache \
                        -t ${IMAGE_FULL} \
                        -t ${IMAGE_LATEST} \
                        .
                    echo "Image construite"
                    docker images | grep foodfrenzy
                """
            }
        }

        stage('Trivy') {
            steps {
                sh """
                    mkdir -p reports
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v \$(pwd)/reports:/reports \
                        aquasec/trivy:latest image \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${IMAGE_FULL} || true
                    echo "Trivy termine"
                """
            }
        }

        stage('Push Harbor') {
            steps {
                sh """
                    echo \${HARBOR_CREDS_PSW} | docker login ${HARBOR_HOST} \
                        -u \${HARBOR_CREDS_USR} \
                        --password-stdin
                    docker push ${IMAGE_FULL}
                    docker push ${IMAGE_LATEST}
                    docker logout ${HARBOR_HOST}
                    echo "Push Harbor OK"
                """
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    mkdir -p ${DEPLOY_DIR}
                    cp docker-compose.yml ${DEPLOY_DIR}/
                    cd ${DEPLOY_DIR}
                    if [ ! -f .env ]; then
                        echo "MYSQL_ROOT_PASSWORD=RootP@ssw0rd!" > .env
                        echo "DB_USER=foodfrenzy_user" >> .env
                        echo "DB_PASSWORD=FoodP@ssw0rd!" >> .env
                        echo "HARBOR_HOST=localhost:8081" >> .env
                        echo "HARBOR_USER=admin" >> .env
                        echo "HARBOR_PASSWORD=Harbor12345" >> .env
                        echo "IMAGE_TAG=${IMAGE_TAG}" >> .env
                    else
                        sed -i 's/IMAGE_TAG=.*/IMAGE_TAG=${IMAGE_TAG}/' .env
                    fi
                    export IMAGE_TAG=${IMAGE_TAG}
                    echo \${HARBOR_CREDS_PSW} | docker login ${HARBOR_HOST} \
                        -u \${HARBOR_CREDS_USR} --password-stdin
                    docker compose down --remove-orphans || true
                    docker compose up -d --pull always
                    docker logout ${HARBOR_HOST}
                    docker compose ps
                """
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    echo "Attente Spring Boot..."
                    max=15
                    i=0
                    until curl -sf http://localhost:8090/actuator/health > /dev/null 2>&1; do
                        i=$((i+1))
                        if [ $i -ge $max ]; then
                            echo "Application ne repond pas"
                            exit 1
                        fi
                        echo "Tentative $i/$max..."
                        sleep 10
                    done
                    echo "Application OK !"
                    curl -s http://localhost:8090/actuator/health
                '''
            }
        }
    }

    post {
        success {
            echo "PIPELINE REUSSI - Build #${BUILD_NUMBER} - http://localhost:8090"
        }
        failure {
            echo "PIPELINE ECHOUE"
            sh 'docker compose -f /home/khevin/foodfrenzy-deploy/docker-compose.yml logs --tail=30 || true'
        }
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
            sh """
                docker rmi ${IMAGE_FULL} || true
                docker image prune -f || true
            """
        }
    }
}
