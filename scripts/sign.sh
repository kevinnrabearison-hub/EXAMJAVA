#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1
WORKSPACE_DIR="${WORKSPACE:-$(pwd)}"
COSIGN_KEY="$WORKSPACE_DIR/cosign.key"

echo "Signing image: $IMAGE_FULL"
echo "Using key: $COSIGN_KEY"
echo "Workspace: $WORKSPACE_DIR"

docker run --rm \
    -v "$WORKSPACE_DIR:/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign --key cosign.key --tlog-upload=false --yes "$IMAGE_FULL"

echo "Image signed successfully."
