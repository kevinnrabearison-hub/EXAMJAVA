#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Verifying signature for image: $IMAGE_FULL"

docker run --rm \
    --network host \
    -v "$HOST_WS:/work" \
    -w /work \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    verify --key cosign.pub --insecure-ignore-tlog "$IMAGE_FULL"

echo "Signature verified. Image is authentic."
