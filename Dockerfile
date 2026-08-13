# syntax=docker/dockerfile:1
# check=skip=FromPlatformFlagConstDisallowed
# (the final stage pins --platform to a constant on purpose — see below)

# Minimal 32-bit ARM (armv7 / hard-float) container image for cloudflared.
#
# The official cloudflare/cloudflared image only publishes linux/amd64 and
# linux/arm64, so 32-bit ARM devices cannot pull it. This image repackages the
# official `cloudflared-linux-armhf` release binary published by Cloudflare
# (Apache-2.0) into a scratch image containing nothing but the binary, a CA
# bundle and the upstream licence.

ARG ALPINE_VERSION=3.22

# ---------------------------------------------------------------------------
# Fetch stage — always runs on the native build platform (no QEMU needed,
# because nothing is executed for the target architecture).
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS fetch

# Release tag from https://github.com/cloudflare/cloudflared/releases
# (e.g. "2026.7.3"), or "latest".
ARG CLOUDFLARED_VERSION=latest
# Expected SHA-256 of cloudflared-linux-armhf. Optional, but strongly
# recommended — the release checksums are published in the release notes.
ARG CLOUDFLARED_SHA256=""

RUN apk add --no-cache ca-certificates curl

WORKDIR /out
RUN set -eu; \
    if [ "${CLOUDFLARED_VERSION}" = "latest" ]; then \
        binary_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-armhf"; \
        license_ref="master"; \
    else \
        binary_url="https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-armhf"; \
        license_ref="${CLOUDFLARED_VERSION}"; \
    fi; \
    echo "Downloading ${binary_url}"; \
    curl -fsSL --retry 5 --retry-delay 2 -o cloudflared "${binary_url}"; \
    if [ -n "${CLOUDFLARED_SHA256}" ]; then \
        echo "${CLOUDFLARED_SHA256}  cloudflared" | sha256sum -c -; \
    else \
        echo "WARNING: CLOUDFLARED_SHA256 not set, skipping checksum verification"; \
        sha256sum cloudflared; \
    fi; \
    curl -fsSL --retry 5 --retry-delay 2 \
        -o LICENSE "https://raw.githubusercontent.com/cloudflare/cloudflared/${license_ref}/LICENSE"; \
    chmod 0755 cloudflared

# ---------------------------------------------------------------------------
# Final image — pinned to armv7 because the payload is a hard-float ARM binary,
# so the image metadata stays correct even for a plain `docker build` without
# an explicit --platform.
# ---------------------------------------------------------------------------
FROM --platform=linux/arm/v7 scratch

ARG CLOUDFLARED_VERSION=latest
ARG BUILD_DATE
ARG SOURCE_URL="https://github.com/kmaciej98/cloudflared-armv7"

LABEL org.opencontainers.image.title="cloudflared-armv7" \
      org.opencontainers.image.description="Cloudflare Tunnel client (cloudflared) for 32-bit ARM (armv7, hard-float)" \
      org.opencontainers.image.version="${CLOUDFLARED_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.url="${SOURCE_URL}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="Unofficial community build (not affiliated with Cloudflare)"

COPY --from=fetch /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=fetch /out/LICENSE /usr/local/share/licenses/cloudflared/LICENSE
COPY --from=fetch /out/cloudflared /usr/local/bin/cloudflared

# In-place self-update cannot work in a scratch image, so disable it by
# default (equivalent to passing --no-autoupdate).
ENV NO_AUTOUPDATE=true

ENTRYPOINT ["/usr/local/bin/cloudflared"]
CMD ["tunnel", "--no-autoupdate", "run"]
