# Analyse de Risques (Méthode STRIDE) - FoodFrenzy

Cette analyse de risques documente les menaces potentielles sur la supply chain logicielle du projet FoodFrenzy et les mesures de sécurité mises en place pour les atténuer.

## 🛡️ Matrice STRIDE & Contre-mesures

| Catégorie STRIDE | Menace Identifiée | Mesure de Sécurisation (Mitigation) |
| :--- | :--- | :--- |
| **S**poofing (Usurpation) | Un attaquant pousse une image malveillante sur Harbor en se faisant passer pour Jenkins. | **Signature Cosign** : Seules les images signées avec la clé privée de Jenkins sont considérées comme valides. |
| **T**ampering (Altération) | Modification silencieuse d'une dépendance (ex. Log4shell) ou du code source. | **Scan SAST (Semgrep)** + **SCA (OWASP)** : Analyse systématique des vulnérabilités dans le code et les librairies tierces. |
| **R**epudiation (Répudiation) | Impossibilité de savoir qui a déployé une version vulnérable en production. | **Logs d'Audit Harbor & Jenkins** : Traçabilité complète des builds et des tags d'images (`IMAGE_TAG` unique). |
| **I**nformation Disclosure | Fuite de clés API ou mots de passe DB dans les logs Jenkins ou le code Git. | **Gitleaks** + **Jenkins Credentials** : Masquage automatique des secrets (`****`) et interdiction de secrets en clair dans le code. |
| **D**enial of Service | Saturation du registre Harbor ou crash de l'appli par injection de code. | **Scan Trivy Container** : Détection des failles OS/Middleware avant déploiement + Healthchecks Docker. |
| **E**levation of Privilege | Un container compromis prend le contrôle de l'hôte Docker (Breakout). | **User Non-Root** : L'application tourne sous l'utilisateur `fooduser` (UID non-privilégié) dans le Dockerfile. |

---

## 🏗️ Sécurisation de la Supply Chain (Software Supply Chain Security)

Le pipeline implémente les principes du **SLSA (Supply-chain Levels for Software Artifacts)** :

1.  **Génération de SBOM (Syft)** : Un inventaire complet des composants est généré pour chaque build. Cela permet une réponse rapide en cas de nouvelle vulnérabilité découverte (ex: nouvelle CVE sur une librairie Java).
2.  **Provenance & Intégrité** : La signature cryptographique avec Cosign garantit que le container déployé est strictement identique à celui qui a été scanné et validé par le pipeline.
3.  **Scan On-Push** : Harbor est configuré pour scanner automatiquement les images dès la réception, doublant ainsi la vérification faite dans Jenkins.

---

## ⚖️ Conformité OWASP

Le projet respecte les recommandations de l'**OWASP Top 10** (notamment A06:2021 – Vulnerable and Outdated Components) grâce à l'intégration de `dependency-check` qui bloque ou alerte sur l'utilisation de librairies obsolètes.
