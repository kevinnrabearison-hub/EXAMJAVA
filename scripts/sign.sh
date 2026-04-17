#!/bin/bash
set -euo pipefail
IMAGE_FULL=$1
COSIGN_KEY="cosign.key"
echo "Signing image: $IMAGE_FULL"
docker run --rm \
    -v "$(pwd):/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign --key "$COSIGN_KEY" --tlog-upload=false --yes "$IMAGE_FULL"
echo "Image signed successfully."
