// ============================================================
// FoodFrenzy — Jenkinsfile DevSecOps
// Java 17 + Spring Boot 3.1.3 + MySQL
// Jenkins local → Harbor local → Deploy local (Compose)
// ============================================================

pipeline {

    agent any

    environment {
        // --- Image ---
        APP_NAME       = "foodfrenzy-app"
        HARBOR_HOST    = "localhost:8081"
        HARBOR_PROJECT = "foodfrenzy"
        IMAGE_NAME     = "${HARBOR_HOST}/${HARBOR_PROJECT}/${APP_NAME}"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        IMAGE_FULL     = "${IMAGE_NAME}:${IMAGE_TAG}"
        IMAGE_LATEST   = "${IMAGE_NAME}:latest"

        // --- Credentials (à créer dans Jenkins > Credentials) ---
        HARBOR_CREDS   = credentials('harbor-credentials')

        // --- Répertoire de déploiement ---
        DEPLOY_DIR     = "/home/khevin/foodfrenzy-deploy"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        // ====================================================
        // STAGE 1 — Checkout
        // ====================================================
        stage('📥 Checkout') {
            steps {
                echo "=== Récupération du code source ==="
                checkout scm
                sh '''
                    echo "Branche  : $(git rev-parse --abbrev-ref HEAD)"
                    echo "Commit   : $(git rev-parse --short HEAD)"
                    echo "Auteur   : $(git log -1 --pretty=%an)"
                    echo "Message  : $(git log -1 --pretty=%s)"
                '''
            }
        }

        // ====================================================
        // STAGE 2 — SAST (en parallèle)
        // ====================================================
        stage('🔬 SAST — Analyse statique') {
            parallel {

                stage('Semgrep') {
                    steps {
                        echo "--- Semgrep : scan du code Java ---"
                        sh '''
                            mkdir -p reports
                            docker run --rm \
                                -v "$(pwd)":/src \
                                --workdir /src \
                                returntocorp/semgrep:latest semgrep \
                                    --config "p/java" \
                                    --config "p/spring-security" \
                                    --json \
                                    --output reports/semgrep-report.json \
                                    src/ \
                                || true
                            echo "Semgrep terminé"
                        '''
                    }
                }

                stage('Gitleaks') {
                    steps {
                        echo "--- Gitleaks : détection de secrets dans le code ---"
                        sh '''
                            mkdir -p reports
                            docker run --rm \
                                -v "$(pwd)":/path \
                                zricethezav/gitleaks:latest detect \
                                    --source /path \
                                    --report-format json \
                                    --report-path /path/reports/gitleaks-report.json \
                                    --exit-code 0
                            echo "Gitleaks terminé"
                        '''
                    }
                }
            }
        }

        // ====================================================
        // STAGE 3 — Build Maven + Tests unitaires
        // ====================================================
        stage('🔨 Build Maven') {
            steps {
                echo "=== Compilation Maven (Java 17) ==="
                sh '''
                    docker run --rm \
                        -v "$(pwd)":/app \
                        -v "$HOME/.m2":/root/.m2 \
                        -w /app \
                        maven:3.9.6-eclipse-temurin-17 \
                        mvn clean package -B --no-transfer-progress
                '''
                echo "JAR généré :"
                sh 'ls -lh target/*.jar'
                archiveArtifacts artifacts: 'target/FoodFrenzy-0.0.1-SNAPSHOT.jar',
                                 fingerprint: true
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/*.xml',
                          allowEmptyResults: true
                }
            }
        }

        // ====================================================
        // STAGE 4 — OWASP Dependency Check
        // ====================================================
        stage('🛡️ OWASP Dependency Check') {
            steps {
                echo "=== Scan des dépendances Maven (CVE) ==="
                sh '''
                    mkdir -p reports
                    docker run --rm \
                        -v "$(pwd)":/src \
                        -v "$(pwd)/reports":/report \
                        owasp/dependency-check:latest \
                            --scan /src \
                            --format JSON \
                            --format HTML \
                            --out /report \
                            --project "FoodFrenzy" \
                            --failOnCVSS 10 \
                        || true
                    echo "OWASP scan terminé"
                '''
                publishHTML([
                    allowMissing:        true,
                    alwaysLinkToLastBuild: true,
                    reportDir:           'reports',
                    reportFiles:         'dependency-check-report.html',
                    reportName:          'OWASP Dependency Check'
                ])
            }
        }

        // ====================================================
        // STAGE 5 — Build Docker Image
        // ====================================================
        stage('🐳 Build Image Docker') {
            steps {
                echo "=== Construction de l'image Docker ==="
                sh """
                    docker build \
                        --no-cache \
                        --label "app=foodfrenzy" \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "build.commit=\$(git rev-parse --short HEAD)" \
                        --label "build.date=\$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        -t ${IMAGE_FULL} \
                        -t ${IMAGE_LATEST} \
                        .

                    echo "Image construite : ${IMAGE_FULL}"
                    docker images | grep foodfrenzy
                """
            }
        }

        // ====================================================
        // STAGE 6 — Scan Trivy
        // ====================================================
        stage('🔍 Scan Trivy') {
            steps {
                echo "=== Scan de vulnérabilités de l'image ==="
                sh """
                    mkdir -p reports

                    # Rapport JSON (archivé)
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v \$(pwd)/reports:/reports \
                        aquasec/trivy:latest image \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format json \
                            --output /reports/trivy-report.json \
                            ${IMAGE_FULL}

                    # Résumé lisible dans les logs Jenkins
                    echo "--- Résumé Trivy ---"
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${IMAGE_FULL}
                """
            }
        }

        // ====================================================
        // STAGE 7 — Signature Cosign
        // ====================================================
        stage('✍️ Signature Cosign') {
            steps {
                echo "=== Signature cryptographique de l'image ==="
                sh """
                    # Générer une paire de clés si elle n'existe pas
                    if [ ! -f cosign.key ]; then
                        docker run --rm \
                            -v \$(pwd):/workspace \
                            -e COSIGN_PASSWORD="" \
                            gcr.io/projectsigstore/cosign:v2.2.0 \
                            generate-key-pair \
                            --output-key-prefix /workspace/cosign
                        echo "Paire de clés Cosign générée"
                    fi

                    # Signer l'image (sans registry push, juste en local)
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v \$(pwd):/workspace \
                        -e COSIGN_PASSWORD="" \
                        gcr.io/projectsigstore/cosign:v2.2.0 \
                        sign \
                            --key /workspace/cosign.key \
                            --yes \
                            ${IMAGE_FULL} \
                        || echo "Signature optionnelle — continuer"
                """
            }
        }

        // ====================================================
        // STAGE 8 — Push vers Harbor
        // ====================================================
        stage('📤 Push Harbor') {
            steps {
                echo "=== Push de l'image vers Harbor (localhost:8081) ==="
                sh """
                    # Login Harbor
                    echo "\${HARBOR_CREDS_PSW}" | docker login ${HARBOR_HOST} \
                        -u "\${HARBOR_CREDS_USR}" \
                        --password-stdin

                    # Push les deux tags
                    docker push ${IMAGE_FULL}
                    docker push ${IMAGE_LATEST}

                    echo "✅ Image pushée : ${IMAGE_FULL}"

                    docker logout ${HARBOR_HOST}
                """
            }
        }

        // ====================================================
        // STAGE 9 — Déploiement Docker Compose
        // ====================================================
        stage('🚀 Déploiement') {
            steps {
                echo "=== Déploiement avec Docker Compose ==="
                sh """
                    # Créer le répertoire de déploiement
                    mkdir -p ${DEPLOY_DIR}

                    # Copier les fichiers de déploiement
                    cp docker-compose.yml ${DEPLOY_DIR}/
                    cp .env.example       ${DEPLOY_DIR}/.env.example

                    cd ${DEPLOY_DIR}

                    # Injecter les variables pour ce build
                    export IMAGE_TAG=${IMAGE_TAG}
                    export HARBOR_HOST=${HARBOR_HOST}

                    # Charger le .env existant (mots de passe)
                    if [ -f .env ]; then
                        export \$(cat .env | grep -v '^#' | xargs)
                    else
                        echo "⚠️  Fichier .env manquant dans ${DEPLOY_DIR}"
                        echo "   Copier .env.example en .env et remplir les valeurs"
                        exit 1
                    fi

                    # Re-login pour Compose (pull depuis Harbor)
                    echo "\${HARBOR_PASSWORD}" | docker login ${HARBOR_HOST} \
                        -u "\${HARBOR_USER}" \
                        --password-stdin

                    # Arrêter l'ancienne version
                    docker compose down --remove-orphans || true

                    # Démarrer la nouvelle version
                    docker compose up -d --pull always

                    docker logout ${HARBOR_HOST}

                    echo "Docker Compose démarré"
                    docker compose ps
                """
            }
        }

        // ====================================================
        // STAGE 10 — Health Check post-déploiement
        // ====================================================
        stage('✅ Vérification') {
            steps {
                echo "=== Vérification que l'application répond ==="
                sh '''
                    echo "Attente du démarrage Spring Boot..."
                    max=15
                    i=0
                    until curl -sf http://localhost:8090/actuator/health > /dev/null 2>&1; do
                        i=$((i+1))
                        if [ $i -ge $max ]; then
                            echo "❌ L'application ne répond pas après $((max*10))s"
                            docker compose -f /home/khevin/foodfrenzy-deploy/docker-compose.yml logs --tail=30
                            exit 1
                        fi
                        echo "  Tentative $i/$max... (attente 10s)"
                        sleep 10
                    done

                    echo ""
                    echo "✅ Application opérationnelle !"
                    echo "--- Health Check ---"
                    curl -s http://localhost:8090/actuator/health | python3 -m json.tool
                    echo ""
                    echo "🌐 Accès : http://localhost:8090"
                '''
            }
        }
    }

    // --------------------------------------------------------
    // Post-pipeline
    // --------------------------------------------------------
    post {

        success {
            echo """
            ╔══════════════════════════════════════╗
            ║   ✅  PIPELINE RÉUSSI                ║
            ╠══════════════════════════════════════╣
            ║  Build    : #${BUILD_NUMBER}
            ║  Image    : ${IMAGE_FULL}
            ║  App      : http://localhost:8090
            ║  Harbor   : http://localhost:8081
            ║  Jenkins  : http://localhost:8080
            ╚══════════════════════════════════════╝
            """
        }

        failure {
            echo "❌ Pipeline échoué — Logs des containers :"
            sh '''
                docker compose \
                    -f /home/khevin/foodfrenzy-deploy/docker-compose.yml \
                    logs --tail=50 \
                    || true
            '''
        }

        always {
            // Archiver tous les rapports de sécurité
            archiveArtifacts artifacts: 'reports/**',
                             allowEmptyArchive: true

            // Nettoyer l'image locale (Harbor garde la copie)
            sh """
                docker rmi ${IMAGE_FULL} || true
                docker image prune -f    || true
            """
        }
    }
}