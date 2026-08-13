#!/bin/sh
# Decide whether an upstream cloudflared release asset is something this image
# can actually ship: a 32-bit little-endian ARM ELF built for hard-float ARM.
#
# Usage:
#   scripts/check-binary.sh <path-to-cloudflared-binary>
#
# Exit status:
#   0  supported — safe to build an armv7 image from it
#   1  not supported — the release should be skipped, not published
#   2  usage error
#
# Checked, in order:
#   * ELF magic                     (it is a binary at all)
#   * EI_CLASS == 32-bit            (rules out arm64/amd64 assets)
#   * e_machine == 0x28, ARM, LE    (rules out a renamed non-ARM asset)
#   * Go build setting GOARM        (6/7 = hard-float; 5 is the soft-float
#                                    "cloudflared-linux-arm" build)

set -eu

BIN="${1:-}"
if [ -z "$BIN" ]; then
    echo "usage: $0 <path-to-cloudflared-binary>" >&2
    exit 2
fi
if [ ! -f "$BIN" ]; then
    echo "error: $BIN does not exist" >&2
    exit 2
fi

hdr="$(od -An -v -tx1 -N20 "$BIN" | tr -d ' \n')"
magic="$(echo "$hdr" | cut -c1-8)"
class="$(echo "$hdr" | cut -c9-10)"
machine="$(echo "$hdr" | cut -c37-40)"

if [ "$magic" != "7f454c46" ]; then
    echo "not supported: $BIN is not an ELF binary (magic ${magic})"
    exit 1
fi
if [ "$class" != "01" ]; then
    echo "not supported: $BIN is not 32-bit (ELF class ${class}, expected 01)"
    exit 1
fi
if [ "$machine" != "2800" ]; then
    echo "not supported: $BIN is not little-endian ARM (e_machine ${machine}, expected 2800)"
    exit 1
fi

goarm="$(strings -a "$BIN" | grep -aoE 'GOARM=[0-9]' | head -n1 | cut -d= -f2 || true)"
case "$goarm" in
    6|7)
        echo "supported: 32-bit little-endian ARM ELF, GOARM=${goarm}"
        ;;
    "")
        echo "supported: 32-bit little-endian ARM ELF (no GOARM build setting found)"
        ;;
    *)
        echo "not supported: built with GOARM=${goarm}, expected a hard-float build (6 or 7)"
        exit 1
        ;;
esac
