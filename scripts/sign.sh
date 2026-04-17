#!/bin/bash
# Script de signature d'image Docker avec Cosign
set -euo pipefail

IMAGE_FULL=$1
COSIGN_KEY="cosign.key"

echo "Signing image: $IMAGE_FULL"

# On utilise Docker pour exécuter cosign
docker run --rm \
    -v "$(pwd):/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    bitnami/cosign:latest sign --key "$COSIGN_KEY" --tlog-upload=false "$IMAGE_FULL"

echo "Image signed successfully."
