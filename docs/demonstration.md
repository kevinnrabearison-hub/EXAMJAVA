# Guide de Démonstration Technique - Soutenance
**Projet CI/CD Sécurisé FoodFrenzy**

Ce guide vous décrit les étapes à suivre lors de votre démonstration orale pour prouver la robustesse de votre pipeline.

---

## Étape 1 : Le Déclenchement (Le Commit)
**Action** : Modifiez un fichier mineur (ex: `README.md` ou un commentaire dans `AdminController.java`) et faites un `git push`.
**Parole** : *"Je lance un nouveau cycle de vie. Le développeur pousse son code, et Jenkins détecte automatiquement le changement pour démarrer le pipeline sécurisé."*

## Étape 2 : L'Analyse Statique (SAST & Secrets)
**Action** : Montrez l'étape **SAST** dans Jenkins. Cliquez sur les logs.
**Parole** : *"Avant même de compiler, nous vérifions l'intégrité du code. Semgrep cherche des vulnérabilités logiques et Gitleaks s'assure qu'aucun secret n'a été introduit par erreur."*

## Étape 3 : Scans des Dépendances & Image
**Action** : Montrez les étapes **OWASP** et **Trivy**.
**Parole** : *"Nous analysons ensuite les bibliothèques tierces avec OWASP Dependency Check. Une fois l'image Docker construite, nous utilisons Trivy pour scanner le système d'exploitation du conteneur. Si une faille critique est trouvée, le pipeline s'arrête ici."*

## Étape 4 : Stockage & Signature dans Harbor
**Action** : Ouvrez votre interface **Harbor**. Montrez l'image `foodfrenzy-app`.
**Points à montrer** :
1.  Le tag de l'image (ex: build #45).
2.  Le statut du scan Harbor.
3.  **Crucial** : Montrez que l'image est **signée** (icône de signature dans Harbor).
**Parole** : *"L'image est stockée dans notre registre privé Harbor. Elle est signée via Cosign. Cette signature est la 'preuve d'authenticité' que notre serveur utilisera pour accepter le déploiement."*

## Étape 5 : Déploiement et Vérification
**Action** : Montrez l'étape finale du déploiement dans Jenkins. Puis montrez l'application qui tourne (en local ou sur le serveur).
**Parole** : *"Enfin, Docker Compose déploie l'image validée. Le pipeline termine par un Health Check automatique pour garantir que le service est disponible pour les utilisateurs."*

---

## Scénario "Excelence" (Optionnel)
Pour impressionner le jury, vous pouvez simuler une faille :
1. Ajoutez un mot de passe en clair dans le code (`String pass = "123456";`).
2. Faites un push.
3. Montrez que Jenkins **échoue** à cause de Gitleaks ou Semgrep.
4. **Parole** : *"Le pipeline a bloqué la branche. La vulnérabilité n'a jamais atteint le serveur de production. La Supply Chain est protégée."*
