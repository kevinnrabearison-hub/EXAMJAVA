# ============================================================
# FoodFrenzy — Dockerfile multi-stage
# Stage 1 : Build avec Maven
# Stage 2 : Runtime léger (JRE Alpine)
# ============================================================

# ------- STAGE 1 : BUILD -------
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /build

# Copier pom.xml SEUL d'abord → cache Maven des dépendances
# Si le code change mais pas pom.xml, Maven ne re-télécharge rien
COPY pom.xml .
RUN mvn dependency:go-offline -B --no-transfer-progress

# Copier le source et compiler
COPY src ./src
RUN mvn clean package -DskipTests -B --no-transfer-progress

# ------- STAGE 2 : RUNTIME -------
FROM eclipse-temurin:17-jre-alpine

# Sécurité : ne jamais tourner en root
RUN addgroup -S foodgroup && adduser -S fooduser -G foodgroup

WORKDIR /app

# Récupérer uniquement le JAR depuis le stage builder
COPY --from=builder /build/target/FoodFrenzy-0.0.1-SNAPSHOT.jar app.jar

# Changer le propriétaire
RUN chown fooduser:foodgroup app.jar

USER fooduser

EXPOSE 8080

# Healthcheck Docker natif (utilisé par Compose + Jenkins)
HEALTHCHECK \
  --interval=30s \
  --timeout=10s \
  --start-period=90s \
  --retries=5 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

# Profil docker activé au démarrage
ENTRYPOINT ["java", \
  "-Dspring.profiles.active=docker", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]