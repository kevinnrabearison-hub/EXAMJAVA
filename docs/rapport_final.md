# Rapport Final : Sécurisation de la Supply Chain Logicielle
**Projet CI/CD Sécurisé avec Jenkins, Docker et Harbor**

---

## 1. Introduction
Ce projet, réalisé dans le cadre du module DevSecOps sous la direction de M. Bonitah RAMBELOSON, porte sur la sécurisation de bout en bout de la chaîne de livraison logicielle de l'application **FoodFrenzy**. 

L'objectif est de garantir que chaque artefact déployé est exemple de vulnérabilités connues, ne contient aucun secret et n'a pas été altéré durant son cycle de vie.

---

## 2. Architecture Technique
Le pipeline suit une architecture robuste basée sur Jenkins pour l'orchestration, Harbor pour le stockage et la sécurité des conteneurs, et Docker pour le déploiement.

- **Orchestration** : Jenkins (Jenkinsfile déclaratif).
- **Analyse Statique** : Semgrep, Gitleaks.
- **SCA & Scans** : OWASP Dependency Check, Trivy.
- **Registre Privé** : Harbor (avec scan de vulnérabilités embarqué).
- **Signature** : Cosign (Signature OCI).
- **Tunneling** : ngrok (Exposition sécurisée du pipeline).
- **Déploiement** : Docker Compose (Orchestration et isolation).

---

## 3. Détails du Packagaging et de l'Orchestration

### 3.1. Dockerfile Multi-stage (Optimisation & Sécurité)
Le conteneur de l'application utilise un **build multi-stage** pour minimiser la surface d'attaque :
1.  **Stage Builder** : Utilise une image complète Maven pour compiler le code.
2.  **Stage Runtime** : Utilise une image **JRE Alpine** (très légère). Seul le fichier `.jar` final est copié.
3.  **Sécurité Non-Root** : L'application ne tourne pas en mode `root`. Un utilisateur dédié `fooduser` est créé pour limiter les privilèges en cas d'intrusion.
4.  **Healthcheck** : Un contrôle de santé natif est intégré pour s'assurer que Spring Boot a bien démarré avant de router le trafic.

### 3.2. Docker Compose et Isolation Réseau
Le déploiement utilise deux réseaux distincts :
- **app-net** : Pour l'accès public à l'application.
- **db-net (Internal)** : Un réseau strictement interne. La base de données MySQL est isolée ; elle peut parler à l'application mais reste **invisible de l'extérieur**, prévenant ainsi les attaques directes sur les données.
Les secrets (mots de passe DB) sont injectés via un fichier `.env` géré de manière sécurisée par Jenkins.

### 3.3. Exposition via ngrok
Pour permettre la communication entre le monde extérieur (Webhooks GitHub) et notre environnement local, nous utilisons **ngrok**.
- **Utilité** : Créer un tunnel sécurisé vers le port de Jenkins ou de l'application.
- **Sécurité** : Permet de tester le pipeline complet en situation réelle sans exposer tout le réseau local de manière permanente.

---

## 4. Méthodologie de Sécurisation (Théorie vs Réalisation)

### 4.1. SAST (Static Application Security Testing)
- **Théorie** : Analyse le code source sans l'exécuter. Pourquoi ? Pour détecter les erreurs de logique, les injections SQL ou l'utilisation d'API dangereuses le plus tôt possible.
- **Réalisation** : Utilisation de **Semgrep** avec la règle `p/java`. Il scanne les fichiers `.java` et génère un rapport `semgrep.json`.

### 4.2. Scan des Secrets
- **Théorie** : Évite que des clés privées ou des mots de passe ne soient poussés dans Git.
- **Réalisation** : Intégration de **Gitleaks** dans Jenkins. Il scanne l'historique des commits à chaque build.

### 3.3. SCA (Software Composition Analysis)
- **Théorie** : Surveille les vulnérabilités dans les bibliothèques tierces (ex. Spring Boot, Hibernate).
- **Réalisation** : **OWASP Dependency Check** analyse le fichier `pom.xml` et compare les bibliothèques utilisées avec la base de données NVD (National Vulnerability Database).

### 3.4. Scan de Conteneurs
- **Théorie** : Même si le code est sain, l'image de base (OS) peut être vulnérable.
- **Réalisation** : **Trivy** scanne l'image Docker finale (ex. Debian/Alpine) pour détecter les CVE (Common Vulnerabilities and Exposures).

### 3.5. Intégrité et Signature (Provenance)
- **Théorie** : Garantit que le conteneur déployé est bien celui produit par le pipeline.
- **Réalisation** : Utilisation de **Cosign**. Jenkins signe l'image dans Harbor. Lors du déploiement, on vérifie la signature avant de lancer le `docker compose up`.

---

## 4. Résultats et Conformité

### 4.1. Analyse de Risques (STRIDE)
Une matrice STRIDE a été complétée (voir `docs/analyse_risques.md`) pour identifier les menaces d'usurpation, d'altération et de fuite d'information. Chaque menace est mitigée par une étape spécifique du pipeline Jenkins.

### 4.2. Génération de SBOM (Syft)
Pour chaque build, un **SBOM** (Software Bill of Materials) est généré via **Syft**. Cela permet un inventaire complet des composants pour une traçabilité totale (Norme SLSA).

---

## 5. Conclusion
Le pipeline CI/CD mis en place transforme une application vulnérable en un service sécurisé par défaut (**Security by Design**). L'automatisation des contrôles de sécurité réduit drastiquement les risques d'attaques sur la supply chain logicielle tout en maintenant une cadence de déploiement élevée.

---
*Rédigé par Khevin - Projet FoodFrenzy EXAM*
