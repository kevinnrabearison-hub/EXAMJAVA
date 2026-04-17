#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1
WORKSPACE_DIR="${WORKSPACE:-$(pwd)}"
COSIGN_PUB="$WORKSPACE_DIR/cosign.pub"

echo "Verifying signature for image: $IMAGE_FULL"
echo "Using key: $COSIGN_PUB"

docker run --rm \
    -v "$WORKSPACE_DIR:/work" \
    -w /work \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    verify --key cosign.pub --insecure-ignore-tlog "$IMAGE_FULL"

echo "Signature verified. Image is authentic."
