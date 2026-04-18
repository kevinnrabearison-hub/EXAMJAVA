#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1
# Extraire la base correctement (supprimer seulement le dernier :tag)
IMAGE_BASE=$(echo "$IMAGE_FULL" | sed 's/:[^:]*$//')
IMAGE_LATEST="${IMAGE_BASE}:latest"

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Signing image: $IMAGE_FULL"
echo "Image base: $IMAGE_BASE"
echo "Image latest: $IMAGE_LATEST"
echo "Host workspace: $HOST_WS"

# Utiliser le tag numéroté ou latest
if docker image inspect "$IMAGE_FULL" > /dev/null 2>&1; then
    TARGET="$IMAGE_FULL"
    echo "Using tagged image: $TARGET"
elif docker image inspect "$IMAGE_LATEST" > /dev/null 2>&1; then
    TARGET="$IMAGE_LATEST"
    echo "Tagged image not found, using: $TARGET"
else
    echo "ERROR: No image found for $IMAGE_FULL or $IMAGE_LATEST"
    docker images | grep foodfrenzy || true
    exit 1
fi

# Sauvegarder dans HOST_WS
echo "Saving image to tar..."
docker save "$TARGET" -o "${HOST_WS}/image-to-sign.tar"
echo "Image saved."

# Signer
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
