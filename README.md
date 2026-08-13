# cloudflared-armv7

[![build](https://github.com/kmaciej98/cloudflared-armv7/actions/workflows/build.yml/badge.svg)](https://github.com/kmaciej98/cloudflared-armv7/actions/workflows/build.yml)

A minimal container image with [`cloudflared`](https://github.com/cloudflare/cloudflared)
(the Cloudflare Tunnel client) for **32-bit ARM — `linux/arm/v7`, hard-float**.

The official `cloudflare/cloudflared` image is published only for `linux/amd64`
and `linux/arm64`, so 32-bit ARM devices cannot pull it. This repository takes
the official `cloudflared-linux-armhf` release binary published by Cloudflare,
verifies its checksum and packages it into a `scratch` image — the binary, a CA
certificate bundle and the upstream licence, nothing else.

Builds are automated: a scheduled workflow watches the upstream repository and
publishes a new image within a day of every `cloudflared` release.

> Unofficial community build. Not affiliated with, endorsed by or supported by
> Cloudflare, Inc. See [NOTICE](NOTICE).

## Image

```
ghcr.io/kmaciej98/cloudflared-armv7:latest
ghcr.io/kmaciej98/cloudflared-armv7:<cloudflared-version>   # e.g. 2026.7.3
```

| | |
|---|---|
| Platform | `linux/arm/v7` (single-platform manifest, no attestations) |
| Base | `scratch` |
| Size | ≈ 54 MB unpacked (the `cloudflared` binary is almost all of it) |
| Entrypoint | `/usr/local/bin/cloudflared` |
| Default command | `tunnel --no-autoupdate run` |

The image ships a plain single-arch manifest on purpose — provenance/SBOM
attestations are disabled, because some lightweight container runtimes cannot
parse the resulting manifest index.

### Hardware

Any ARMv7-A CPU with hardware floating point (`armhf`) — Cortex-A7, A8, A9,
A15, A17 and similar. That covers Raspberry Pi 2 and older 32-bit Pi OS
installs, many NAS and SBC boards, and MikroTik routers whose CPU is ARMv7
(for example the Cortex-A15 based models) running RouterOS containers.

## How the automation works

| Workflow | Trigger | What it does |
|---|---|---|
| [`build.yml`](.github/workflows/build.yml) | push to `main`, PR, manual | Resolves the release tag and its checksum, checks that the release actually ships a supported 32-bit ARM binary, builds `linux/arm/v7`, verifies the image architecture and that `cloudflared --version` runs under QEMU, then pushes `:<version>` and `:latest` to GHCR |
| [`upstream.yml`](.github/workflows/upstream.yml) | daily cron, manual | Compares the newest upstream release against the tags already in GHCR and calls `build.yml` when something is missing |

Before anything is built, the workflow downloads the release asset and runs
[`scripts/check-binary.sh`](scripts/check-binary.sh) on it, which requires a
32-bit little-endian ARM ELF built with `GOARM=6`/`GOARM=7`. If a future
release drops the 32-bit ARM build, or that asset turns out to hold something
else (an arm64 binary, a soft-float `GOARM=5` build), the run stops with an
explicit *not supported* error and no image is built or published for that
release. The tags already in the registry are untouched, so existing
deployments keep working.

The build then fails rather than publishing anything if the checksum does not
match, if the resulting image is not `arm/v7`, or if the binary does not report
the expected version.

Both workflows run with the built-in `GITHUB_TOKEN`; no extra secrets are
needed. The scheduled workflow only runs from the repository's **default
branch**, so the workflows have to be merged there to activate the automation.

## Licence and attribution

The packaging in this repository is MIT licensed ([LICENSE](LICENSE)).
`cloudflared` itself is Apache-2.0 licensed, copyright Cloudflare, Inc.; it is
redistributed unmodified and its licence is included in the image at
`/usr/local/share/licenses/cloudflared/LICENSE`. See [NOTICE](NOTICE) for
details.
