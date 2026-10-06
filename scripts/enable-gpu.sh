#!/usr/bin/env bash
# Turn on Mali-400 GPU acceleration (OpenGL ES 2.0 through EGL on X11).
#
# Run on the PocketCHIP as root:
#   sudo scripts/enable-gpu.sh --accept-arm-eula   # enable
#   sudo scripts/enable-gpu.sh --revert            # back to the fbdev driver
#
# What it does:
#   1. builds NTC's xf86-video-armsoc X driver (MIT) against the installed X server;
#   2. installs ARM's Mali userspace library, downloaded from NTC's own
#      repository (proprietary, ARM EULA; never shipped by this project);
#   3. switches /etc/X11/xorg.conf from fbdev to armsoc with DRI2.
# The Mali kernel module is already part of the image.
# Restart X afterwards: sudo systemctl restart lightdm
set -euo pipefail

ARMSOC_COMMIT=77872d1ed350360428fe89548638413fc64dcd70
MALI_COMMIT=a9d2b5060103baa3f5d6e98011e28f2d4fae2fa6
ARMSOC_URL="https://github.com/nextthingco/xf86-video-armsoc/archive/${ARMSOC_COMMIT}.tar.gz"
MALI_URL="https://github.com/NextThingCo/chip-mali-userspace/archive/${MALI_COMMIT}.tar.gz"
EULA_URL="https://github.com/NextThingCo/chip-mali-userspace/blob/${MALI_COMMIT}/debian/copyright"
BUILD_DEPS="build-essential autoconf automake libtool pkg-config xutils-dev
            xserver-xorg-dev libdrm-dev libudev-dev"
XORG_CONF=/etc/X11/xorg.conf
XORG_BACKUP=/etc/X11/xorg.conf.fbdev
DRIVER=/usr/lib/xorg/modules/drivers/armsoc_drv.so
LIBDIR=/usr/lib/arm-linux-gnueabihf

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
installed() { dpkg-query -W -f '${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii'; }

usage() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

revert() {
    [ -f "$XORG_BACKUP" ] || die "no $XORG_BACKUP; nothing to revert"
    cp "$XORG_BACKUP" "$XORG_CONF"
    rm -f "$DRIVER"
    log "X is back on fbdev. Restart it: sudo systemctl restart lightdm"
    log "The Mali library stays installed (harmless). Remove it with: sudo apt-get purge chip-mali-userspace"
}

build_armsoc() {
    local work="$1" missing=() dep
    # shellcheck disable=SC2086  # word splitting of the list is intended
    for dep in $BUILD_DEPS; do
        installed "$dep" || missing+=("$dep")
    done
    log "installing build dependencies"
    apt-get update -qq
    # mesa-common-dev and NTC's Mali package both ship KHR/khrplatform.h.
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
        -o Dpkg::Options::=--force-overwrite $BUILD_DEPS

    log "building xf86-video-armsoc ${ARMSOC_COMMIT:0:7}"
    curl -fsSL "$ARMSOC_URL" | tar -xz -C "$work"
    (
        cd "$work/xf86-video-armsoc-$ARMSOC_COMMIT"
        ./autogen.sh --prefix=/usr >"$work/armsoc-configure.log" 2>&1 \
            || { tail -20 "$work/armsoc-configure.log"; exit 1; }
        make -j1 >"$work/armsoc-make.log" 2>&1 || { tail -20 "$work/armsoc-make.log"; exit 1; }
        install -D -m 0644 src/.libs/armsoc_drv.so "$DRIVER"
    )

    if [ "${#missing[@]}" -gt 0 ]; then
        log "removing the build dependencies this script installed"
        DEBIAN_FRONTEND=noninteractive apt-get purge -y -q --auto-remove "${missing[@]}" >/dev/null
    fi
}

install_mali() {
    local work="$1" src pkg
    if installed chip-mali-userspace; then
        log "chip-mali-userspace is already installed"
        return
    fi
    log "downloading the Mali userspace library from NTC (ARM EULA)"
    curl -fsSL "$MALI_URL" | tar -xz -C "$work"
    src="$work/chip-mali-userspace-$MALI_COMMIT"
    pkg="$work/pkg"

    # Same files, links and package relations as NTC's package, built without
    # debhelper. KHR/khrplatform.h is left to mesa-common-dev to avoid a conflict.
    mkdir -p "$pkg/DEBIAN" "$pkg$LIBDIR"
    cp -a "$src/etc" "$pkg/"
    cp -a "$src/usr" "$pkg/"
    rm -rf "$pkg/usr/include/KHR"
    while read -r target link; do
        [ -n "$target" ] || continue
        ln -sf "$(basename "/$target")" "$pkg/$link"
    done < "$src/debian/chip-mali-userspace.links"
    sed -n '/^Package:/,$p' "$src/debian/control" \
        | sed 's/^Package: .*/Package: chip-mali-userspace/' \
        | grep -E '^(Package|Architecture|Provides|Conflicts|Replaces|Multi-Arch|Description):' \
        > "$pkg/DEBIAN/control.tmp"
    {
        echo "Version: 0.1"
        echo "Maintainer: Next Thing Co. <software@nextthing.co>"
        echo "Section: libs"
        echo "Priority: optional"
        cat "$pkg/DEBIAN/control.tmp"
    } > "$pkg/DEBIAN/control"
    rm "$pkg/DEBIAN/control.tmp"
    chmod -R u=rwX,go=rX "$pkg"
    dpkg-deb --root-owner-group --build "$pkg" "$work/chip-mali-userspace.deb" >/dev/null
    dpkg -i "$work/chip-mali-userspace.deb"
    ldconfig
}

switch_xorg() {
    if grep -qE '^\s*Driver\s+"armsoc"' "$XORG_CONF"; then
        log "$XORG_CONF already uses armsoc"
        return
    fi
    grep -qE '^\s*Driver\s+"fbdev"' "$XORG_CONF" || die "$XORG_CONF has no fbdev Device; edit it by hand"
    [ -f "$XORG_BACKUP" ] || cp "$XORG_CONF" "$XORG_BACKUP"
    sed -i -E 's/^(\s*Driver\s+)"fbdev"/\1"armsoc"\n\tOption\t\t"DRI2"\t"true"/' "$XORG_CONF"
    log "X switched to armsoc (backup: $XORG_BACKUP)"
}

case "${1:-}" in
    --accept-arm-eula) ;;
    --revert) [ "$(id -u)" -eq 0 ] || die "run as root"; revert; exit 0 ;;
    -h|--help) usage 0 ;;
    *) printf 'The Mali library is proprietary and licensed by ARM:\n  %s\n' "$EULA_URL" >&2
       printf 'Read it, then run again with --accept-arm-eula.\n\n' >&2
       usage 1 ;;
esac

[ "$(id -u)" -eq 0 ] || die "run as root"
modprobe mali 2>/dev/null || true
[ -c /dev/mali ] || die "/dev/mali is missing: the Mali kernel module for $(uname -r) is not loaded"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

build_armsoc "$WORK"
install_mali "$WORK"
switch_xorg
log "done. Restart X: sudo systemctl restart lightdm"
log "Members of the 'video' group can use the GPU (the default 'chip' user is one)."
