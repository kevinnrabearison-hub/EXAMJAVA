#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Signing image: $IMAGE_FULL"
echo "Host workspace: $HOST_WS"

# Sauvegarder l'image dans le workspace (accessible par cosign)
JENKINS_WS="/var/jenkins_home/workspace/FoodFrenzy-Pipeline"
docker save "$IMAGE_FULL" -o "$JENKINS_WS/image-to-sign.tar"
echo "Image saved to tar"

# Signer le tar (monté via HOST_WS)
docker run --rm \
    --network host \
    -v "$HOST_WS:/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign-blob \
    --key cosign.key \
    --tlog-upload=false \
    --yes \
    --output-signature image.sig \
    image-to-sign.tar

echo "Image signed successfully."
