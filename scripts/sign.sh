#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1

# Résoudre le vrai chemin hôte du workspace Jenkins
HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Signing image: $IMAGE_FULL"
echo "Host workspace: $HOST_WS"

docker run --rm \
    -v "$HOST_WS:/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign --key cosign.key --tlog-upload=false --yes "$IMAGE_FULL"

echo "Image signed successfully."
