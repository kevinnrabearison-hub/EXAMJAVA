#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Signing image in Harbor Registry (OCI): $IMAGE_FULL"

docker run --rm \
    --network host \
    -v "$HOST_WS:/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign \
    --key cosign.key \
    --tlog-upload=false \
    --allow-insecure-registry \
    --registry-username="$HARBOR_USER" \
    --registry-password="$HARBOR_PASSWORD" \
    --yes \
    "$IMAGE_FULL"

echo "Image signed successfully in Harbor."
