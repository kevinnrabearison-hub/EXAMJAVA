#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Verifying signature from Harbor Registry: $IMAGE_FULL"

docker run --rm \
    --network host \
    -v "$HOST_WS:/work" \
    -w /work \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    verify \
    --key cosign.pub \
    --insecure-ignore-tlog \
    --allow-insecure-registry \
    --registry-username="$HARBOR_USER" \
    --registry-password="$HARBOR_PASSWORD" \
    "$IMAGE_FULL"

echo "Signature verified. Image is authentic."
