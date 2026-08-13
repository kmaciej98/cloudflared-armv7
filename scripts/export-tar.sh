#!/usr/bin/env bash
# Export the image to a .tar archive, for hosts that import container images
# from a file instead of pulling from a registry (for example RouterOS).
#
# Usage:
#   scripts/export-tar.sh [image] [output.tar]
#
# Examples:
#   scripts/export-tar.sh                                  # pull :latest from GHCR
#   scripts/export-tar.sh ghcr.io/kmaciej98/cloudflared-armv7:2026.7.3
#   scripts/export-tar.sh cloudflared-armv7:latest out.tar # a locally built image
#
# An image that is already present locally is exported as-is; run
# `docker rmi <image>` first if you want a fresh pull from the registry.

set -euo pipefail

IMAGE="${1:-ghcr.io/kmaciej98/cloudflared-armv7:latest}"
OUTPUT="${2:-cloudflared-armv7.tar}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Pulling $IMAGE (linux/arm/v7)"
    docker pull --platform linux/arm/v7 "$IMAGE"
fi

arch="$(docker image inspect "$IMAGE" --format '{{.Architecture}}/{{.Variant}}')"
if [ "$arch" != "arm/v7" ]; then
    echo "ERROR: $IMAGE has architecture $arch, expected arm/v7" >&2
    exit 1
fi

docker save "$IMAGE" -o "$OUTPUT"
echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1 | tr -d ' '))"
