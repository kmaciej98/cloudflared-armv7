#!/usr/bin/env bash
# Build the armv7 image locally.
#
# Usage:
#   scripts/build.sh [cloudflared_version] [image_tag]
#
# Examples:
#   scripts/build.sh                       # latest upstream release
#   scripts/build.sh 2026.7.3              # a specific release
#   scripts/build.sh latest my-cloudflared # custom local tag
#
# No QEMU is required: the target stage is `scratch` and nothing is executed
# for the target architecture during the build.

set -euo pipefail

VERSION="${1:-latest}"
IMAGE="${2:-cloudflared-armv7:${VERSION}}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sha=""
if command -v curl >/dev/null 2>&1; then
    if [ "$VERSION" = "latest" ]; then
        api="https://api.github.com/repos/cloudflare/cloudflared/releases/latest"
    else
        api="https://api.github.com/repos/cloudflare/cloudflared/releases/tags/${VERSION}"
    fi
    sha="$(curl -fsSL "$api" \
        | grep -oE 'cloudflared-linux-armhf: *[0-9a-f]{64}' \
        | grep -oE '[0-9a-f]{64}' \
        | head -n1 || true)"
fi

if [ -n "$sha" ]; then
    echo "Expected sha256 of cloudflared-linux-armhf: $sha"
else
    echo "WARNING: could not fetch the upstream checksum; building without verification" >&2
fi

docker buildx build \
    --platform linux/arm/v7 \
    --build-arg "CLOUDFLARED_VERSION=${VERSION}" \
    --build-arg "CLOUDFLARED_SHA256=${sha}" \
    --build-arg "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --provenance=false \
    --sbom=false \
    --tag "$IMAGE" \
    --load \
    "$ROOT"

echo
echo "Built $IMAGE"
docker image inspect "$IMAGE" --format 'architecture: {{.Architecture}}/{{.Variant}}'
