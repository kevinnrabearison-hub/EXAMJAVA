# Cahier des Charges - FoodFrenzy DevSecOps

## 1. Contexte du Projet
FoodFrenzy est une application Java/Spring Boot critique nécessitant un haut niveau de sécurité dans sa chaîne de déploiement. Ce projet vise à implémenter un pipeline CI/CD sécurisé respectant les principes du DevSecOps.

## 2. Objectifs Techniques
- **Automatisation** : Pipeline complet de la validation du code au déploiement.
- **Sécurité Statique (SAST)** : Détection proactive des failles de code et des secrets.
- **Sécurité des Dépendances (SCA)** : Surveillance des vulnérabilités dans les librairies tierces.
- **Intégrité des Artefacts** : Signature cryptographique des images Docker.
- **Visibilité** : Génération de SBOM et rapports de scan archivés.

## 3. Stack Technique
- **Application** : Java 17, Spring Boot 3.1.
- **CI/CD** : Jenkins.
- **Registre** : Harbor.
- **Sécurité** : Semgrep, Gitleaks, Trivy, Cosign, Syft.
- **Déploiement** : Docker Compose.

## 4. Spécifications du Pipeline
Le pipeline doit comporter les étapes suivantes :
1.  **Checkout** : Récupération du code source.
2.  **Analyse Statique** : Scan de code (Semgrep) et détection de secrets (Gitleaks).
3.  **Build** : Compilation Maven et packaging JAR.
4.  **Scans de Sécurité** : Scan de dépendances (OWASP) et scan d'image (Trivy).
5.  **Génération de SBOM** : Inventaire des composants via Syft.
6.  **Signature** : Signature de l'image via Cosign avant le push vers Harbor.
7.  **Déploiement** : Mise à jour automatique de l'environnement via Docker Compose.

## 5. Critères d'Acceptation
- Aucun secret ne doit apparaître dans les logs Jenkins.
- L'image dans Harbor doit porter le tag de signature.
- L'application doit être accessible et saine après déploiement (Healthcheck).
