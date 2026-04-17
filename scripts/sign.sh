#!/bin/bash
# Script de signature d'image Docker avec Cosign
set -euo pipefail

IMAGE_FULL=$1
COSIGN_KEY="cosign.key"

echo "Signing image: $IMAGE_FULL"

docker run --rm \
    -v "$(pwd):/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    bitnami/cosign:2.2.4 \
    sign \
    --key "$COSIGN_KEY" \
    --tlog-upload=false \
    --yes \
    "$IMAGE_FULL"

echo "Image signed successfully."
