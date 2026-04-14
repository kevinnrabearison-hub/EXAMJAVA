# FoodFrenzy — Pipeline CI/CD DevSecOps

> Spring Boot 3.1.3 · Java 17 · MySQL 8 · Jenkins · Harbor · Docker Compose

---

## Architecture des containers

```
┌─────────────────────────────────────────────────────────┐
│                   Votre PC local                        │
│                                                         │
│  ┌─────────────────┐      ┌──────────────────────────┐ │
│  │    Jenkins      │      │   Harbor Registry        │ │
│  │  :8080 / :50000 │      │   (8 containers)         │ │
│  │                 │      │   :8081                  │ │
│  └────────┬────────┘      └────────────┬─────────────┘ │
│           │  build + push              │ pull           │
│           ▼                            ▼                │
│  ┌─────────────────────────────────────────────────┐    │
│  │         Docker Compose (déploiement)            │    │
│  │                                                 │    │
│  │  ┌──────────────────┐   ┌─────────────────────┐ │    │
│  │  │  foodfrenzy-app  │   │   foodfrenzy-db     │ │    │
│  │  │  Spring Boot     │◄──│   MySQL 8.0         │ │    │
│  │  │  :8090           │   │   (interne)         │ │    │
│  │  └──────────────────┘   └─────────────────────┘ │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Pré-requis (déjà en place sur votre PC)

| Service | Port | Statut |
|---|---|---|
| Jenkins | http://localhost:8080 | ✅ Running |
| Harbor  | http://localhost:8081 | ✅ Running |
| Docker  | — | ✅ Installé |

---

## Mise en place étape par étape

### Étape 1 — Copier les fichiers dans votre projet

```bash
cd ~/Documents/LECON\ L3/JAVA\ LECON/FoodFrenzyEXAM

# Fichiers racine
cp /chemin/vers/fichiers/Dockerfile .
cp /chemin/vers/fichiers/Jenkinsfile .
cp /chemin/vers/fichiers/docker-compose.yml .
cp /chemin/vers/fichiers/.env.example .
cp /chemin/vers/fichiers/.gitignore .
cp /chemin/vers/fichiers/pom.xml .   # ← Actuator ajouté

# Profil Docker Spring Boot
cp /chemin/vers/fichiers/application-docker.properties \
   src/main/resources/
```

### Étape 2 — Créer le fichier .env

```bash
cp .env.example .env
nano .env   # remplir vos vrais mots de passe
```

Contenu minimal du `.env` :
```
MYSQL_ROOT_PASSWORD=VotreMotDePasseRoot
DB_USER=foodfrenzy_user
DB_PASSWORD=VotreMotDePasseApp
HARBOR_HOST=localhost:8081
HARBOR_USER=admin
HARBOR_PASSWORD=Harbor12345
IMAGE_TAG=latest
```

### Étape 3 — Créer le projet dans Harbor

1. Aller sur http://localhost:8081
2. Se connecter (admin / Harbor12345)
3. **Projects → New Project**
   - Name : `foodfrenzy`
   - Access level : **Private**
   - ✅ cocher "Scan on push"
4. Valider

### Étape 4 — Configurer Jenkins

#### 4a. Installer les plugins nécessaires

Jenkins → Manage Jenkins → Plugins → Available :
- `Docker Pipeline`
- `HTML Publisher` (pour les rapports OWASP)
- `JUnit` (déjà installé en général)

#### 4b. Ajouter les credentials Harbor

Jenkins → Manage Jenkins → Credentials → Global → Add Credentials :

| Champ | Valeur |
|---|---|
| Kind | Username with password |
| Username | admin |
| Password | Harbor12345 (votre mdp Harbor) |
| ID | `harbor-credentials` |
| Description | Harbor Registry Local |

#### 4c. Créer le pipeline

Jenkins → **New Item** :
- Nom : `FoodFrenzy-Pipeline`
- Type : **Pipeline**
- OK

Dans la configuration :
- Section **Pipeline** → Definition : `Pipeline script from SCM`
- SCM : `Git`
- Repository URL : chemin local ou dépôt Git
- Script Path : `Jenkinsfile`

### Étape 5 — Créer le répertoire de déploiement

```bash
mkdir -p ~/foodfrenzy-deploy
cp .env ~/foodfrenzy-deploy/.env   # copier le .env ici aussi
```

### Étape 6 — Lancer le pipeline

Jenkins → FoodFrenzy-Pipeline → **Build Now**

---

## Stages du pipeline

| # | Stage | Outil | Ce que ça fait |
|---|---|---|---|
| 1 | Checkout | Git | Récupère le code + infos commit |
| 2 | SAST | Semgrep + Gitleaks | Analyse code Java, détecte secrets |
| 3 | Build | Maven 3.9 / Java 17 | Compile, teste, génère le JAR |
| 4 | OWASP | Dependency-Check | Scanne les CVE dans pom.xml |
| 5 | Docker Build | Docker | Construit l'image multi-stage |
| 6 | Trivy | Trivy | Scanne les CVE dans l'image |
| 7 | Cosign | Cosign v2 | Signe l'image cryptographiquement |
| 8 | Push | Harbor | Upload l'image dans le registry |
| 9 | Deploy | Docker Compose | Démarre app + MySQL |
| 10 | Verify | curl/healthcheck | Vérifie que l'app répond |

---

## Accès après déploiement

| URL | Description |
|---|---|
| http://localhost:8090 | Application FoodFrenzy |
| http://localhost:8090/actuator/health | Health check |
| http://localhost:8081 | Harbor Registry |
| http://localhost:8080 | Jenkins |

---

## Commandes utiles

```bash
# Voir les containers de l'app
docker compose -f ~/foodfrenzy-deploy/docker-compose.yml ps

# Voir les logs de l'app
docker compose -f ~/foodfrenzy-deploy/docker-compose.yml logs -f foodfrenzy-app

# Arrêter tout
docker compose -f ~/foodfrenzy-deploy/docker-compose.yml down

# Reconstruire manuellement l'image
docker build -t localhost:8081/foodfrenzy/foodfrenzy-app:test .
```

---

## Sécurité — points clés

- **MySQL** non exposé à l'extérieur (`internal: true`)
- **User non-root** dans le container Spring Boot
- **Secrets** via `.env` (jamais dans le code)
- **Image signée** avec Cosign avant chaque push
- **Scan CVE** Trivy à chaque build
- **SAST** Semgrep sur les règles Java + Spring Security