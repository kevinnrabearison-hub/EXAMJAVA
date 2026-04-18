#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Signing image: $IMAGE_FULL"

# Récupérer le digest local de l'image
IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_FULL" 2>/dev/null || \
               docker inspect --format='{{.Id}}' "$IMAGE_FULL")

echo "Image digest: $IMAGE_DIGEST"

# Sauvegarder l'image en tar
echo "Saving image to tar..."
docker save "$IMAGE_FULL" -o /tmp/image-to-sign.tar

# Signer le tar avec cosign
docker run --rm \
    --network host \
    -v "$HOST_WS:/work" \
    -v "/tmp:/tmp" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign-blob \
    --key cosign.key \
    --tlog-upload=false \
    --yes \
    --output-signature /tmp/image.sig \
    /tmp/image-to-sign.tar

echo "Signature saved to /tmp/image.sig"
echo "Image signed successfully."
