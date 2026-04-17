#!/bin/bash
# Script de vérification de signature Cosign
set -euo pipefail

IMAGE_FULL=$1
COSIGN_PUB="cosign.pub"

echo "Verifying signature for image: $IMAGE_FULL"

docker run --rm \
    -v "$(pwd):/work" \
    -w /work \
    bitnami/cosign:2.2.4 \
    verify \
    --key "$COSIGN_PUB" \
    --insecure-ignore-tlog \
    "$IMAGE_FULL"

echo "Signature verified. Image is authentic."
