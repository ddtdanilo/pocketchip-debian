#!/usr/bin/env bash
# build-image.sh - build flashable UBI images from an exported rootfs tarball.
#
# Runs on any host with Docker (macOS or Linux). Input is the tarball produced
# by scripts/export-rootfs.sh; output goes to ./dist.
#
# Usage: scripts/build-image.sh <rootfs.tar> [version]
set -euo pipefail

ROOTFS="${1:?usage: build-image.sh <rootfs.tar> [version]}"
VERSION="${2:-0.1.0}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/dist"

[ -f "$ROOTFS" ] || { echo "error: $ROOTFS not found" >&2; exit 1; }
command -v docker >/dev/null || { echo "error: docker is required" >&2; exit 1; }

mkdir -p "$OUT"
docker build -t pocketchip-ubi-builder "$HERE/docker"
docker run --rm \
    -e VERSION="$VERSION" \
    -v "$(cd "$(dirname "$ROOTFS")" && pwd)/$(basename "$ROOTFS"):/in/rootfs.tar:ro" \
    -v "$OUT:/out" \
    pocketchip-ubi-builder
echo "Images written to $OUT"
