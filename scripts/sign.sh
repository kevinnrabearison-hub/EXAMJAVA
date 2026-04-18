#!/bin/bash
set -euo pipefail

IMAGE_FULL=$1
IMAGE_BASE=$(echo "$IMAGE_FULL" | sed 's/:[^:]*$//')
IMAGE_LATEST="${IMAGE_BASE}:latest"

HOST_WS=$(docker inspect jenkins \
    --format '{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{.Source}}{{end}}{{end}}')
HOST_WS="${HOST_WS}/workspace/FoodFrenzy-Pipeline"

echo "Signing image: $IMAGE_FULL"
echo "Host workspace: $HOST_WS"

# Utiliser le tag numéroté ou latest
if docker image inspect "$IMAGE_FULL" > /dev/null 2>&1; then
    TARGET="$IMAGE_FULL"
else
    TARGET="$IMAGE_LATEST"
    echo "Using latest: $TARGET"
fi

# Sauvegarder via conteneur intermédiaire dans le workspace Jenkins
echo "Saving image to tar..."
docker run --rm \
    -v "$HOST_WS:/workspace" \
    --entrypoint="" \
    alpine:latest \
    sh -c "echo 'workspace mounted'" || true

docker save "$TARGET" | \
    docker run --rm -i \
    -v "$HOST_WS:/workspace" \
    alpine:latest \
    sh -c "cat > /workspace/image-to-sign.tar"

echo "Image saved."

# Signer
docker run --rm \
    --network host \
    -v "$HOST_WS:/work" \
    -w /work \
    -e COSIGN_PASSWORD="$COSIGN_PASSWORD" \
    gcr.io/projectsigstore/cosign:v2.2.3 \
    sign-blob \
    --key cosign.key \
    --tlog-upload=false \
    --yes \
    --output-signature image.sig \
    image-to-sign.tar

echo "Image signed successfully."
