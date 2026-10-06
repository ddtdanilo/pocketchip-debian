#!/usr/bin/env bash
# export-rootfs.sh - make a sanitized copy of the running PocketCHIP system.
#
# Run as root ON the PocketCHIP. It copies the root filesystem to $EXPORT,
# removes personal data and proprietary packages, applies ../overlay, and
# verifies that nothing personal is left. It does not touch the running system.
#
# Then stream the result to your computer, e.g. from the Mac/Linux host:
#
#   ssh chip@<pocketchip> 'sudo tar -C /var/tmp/pocketchip-export --numeric-owner -cpf - .' > rootfs.tar
#
# and build the flashable images with scripts/build-image.sh.
set -euo pipefail

EXPORT="${EXPORT:-/var/tmp/pocketchip-export}"
VERSION="${VERSION:-0.1.0}"
OVERLAY="${OVERLAY:-$(dirname "$(readlink -f "$0")")/../overlay}"
BIND=/mnt/pocketchip-rootbind

# Packages that are proprietary (or only useful with proprietary parts) and
# therefore must not be redistributed. See THIRD_PARTY.md.
PURGE_PACKAGES="chip-pico-8 chip-sunvox chip-mali-userspace chip-metapackage"

# Strings that must NOT appear anywhere in the exported tree.
FORBIDDEN_REGEX="${FORBIDDEN_REGEX:-}"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "==> $*"; }

[ "$(id -u)" -eq 0 ] || die "run as root"
[ -d "$OVERLAY" ] || die "overlay directory not found: $OVERLAY"
[ -n "${PRIVATE_USER:-}" ] || die "set PRIVATE_USER to the personal account to remove (e.g. PRIVATE_USER=alice)"
FORBIDDEN_REGEX="${FORBIDDEN_REGEX:-$PRIVATE_USER}"

cleanup() {
    mountpoint -q "$BIND" 2>/dev/null && umount "$BIND" || true
}
trap cleanup EXIT

if [ "${SKIP_COPY:-0}" = "1" ]; then
    # Resume on an existing copy (all the steps below are idempotent).
    [ -d "$EXPORT/etc" ] || die "SKIP_COPY=1 but $EXPORT has no copy to resume from"
    log "reusing the existing copy in $EXPORT"
else
    log "copying the root filesystem to $EXPORT"
    rm -rf "${EXPORT:?}"
    mkdir -p "$EXPORT" "$BIND"
    # A non-recursive bind mount shows what is really stored on the flash, without
    # /proc, /sys, /dev (devtmpfs) or any tmpfs mounted on top.
    mount --bind / "$BIND"
    tar -C "$BIND" --numeric-owner -cpf - \
        --exclude='./var/tmp/pocketchip-*' \
        --exclude='./root/*' --exclude='./root/.[!.]*' \
        --exclude="./home/$PRIVATE_USER" \
        --exclude='./tmp/*' --exclude='./var/tmp/*' \
        --exclude='./var/cache/apt/*.bin' --exclude='./var/cache/apt/archives/*.deb' \
        --exclude='./var/lib/apt/lists/*' \
        --exclude='./var/log/journal/*' \
        . | tar -C "$EXPORT" --numeric-owner -xpf -
    umount "$BIND"
fi

log "removing proprietary packages"
for pkg in $PURGE_PACKAGES; do
    if chroot "$EXPORT" dpkg -s "$pkg" >/dev/null 2>&1; then
        chroot "$EXPORT" dpkg --purge --force-depends "$pkg" >/dev/null 2>&1 \
            || echo "warning: could not purge $pkg" >&2
    fi
done
# The metapackage only pulled dependencies in. Keep what it installed.
# shellcheck disable=SC2016  # ${Package} is a dpkg format string, not a shell variable
KEEP="$(chroot "$EXPORT" dpkg-query -W -f '${Package}\n' 'chip-*' 'pocketchip-*' pocket-home pocket-wm 2>/dev/null | tr '\n' ' ')"
# shellcheck disable=SC2086
chroot "$EXPORT" apt-mark manual $KEEP >/dev/null

rm -rf "$EXPORT/etc/skel/.lexaloffle" "$EXPORT/etc/skel/sunvox_config.ini" \
       "$EXPORT/home/chip/.lexaloffle" "$EXPORT/home/chip/.config/SunVox" \
       "$EXPORT/home/chip/sunvox_config.ini"

log "removing the PICO-8 and SunVox launcher entries"
python3 - "$EXPORT/usr/share/pocket-home/config.json" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path).read()
text = re.sub(r'\{\s*"name":\s*"(Play PICO-8|Make Music)".*?\}\s*,?', '', text,
              flags=re.DOTALL)
open(path, 'w').write(text)
PY

log "removing the personal account '$PRIVATE_USER'"
chroot "$EXPORT" userdel "$PRIVATE_USER" 2>/dev/null || true
rm -rf "${EXPORT:?}/home/${PRIVATE_USER:?}" "${EXPORT:?}/var/mail/${PRIVATE_USER:?}" \
       "${EXPORT:?}/etc/sudoers.d/${PRIVATE_USER:?}"
sed -i "/^${PRIVATE_USER}[:,]/d; s/,${PRIVATE_USER}//g; s/:${PRIVATE_USER}\$/:/" \
    "$EXPORT"/etc/passwd- "$EXPORT"/etc/shadow- "$EXPORT"/etc/group- "$EXPORT"/etc/gshadow- \
    "$EXPORT"/etc/subuid "$EXPORT"/etc/subgid "$EXPORT"/etc/subuid- "$EXPORT"/etc/subgid- 2>/dev/null || true

log "removing Wi-Fi profiles, host keys, machine id, secrets"
find "$EXPORT/etc/NetworkManager/system-connections" -type f ! -name 'usb0_linklocal' -delete
rm -rf "$EXPORT"/var/lib/NetworkManager/* "$EXPORT"/etc/ssh/ssh_host_* \
       "$EXPORT/etc/x11vnc.pass" "$EXPORT/etc/x11vnc.pass.bak"
: > "$EXPORT/etc/machine-id"
ln -sf /etc/machine-id "$EXPORT/var/lib/dbus/machine-id"
rm -f "$EXPORT"/home/chip/.bash_history "$EXPORT"/home/chip/.Xauthority \
      "$EXPORT"/home/chip/.xsession-errors* "$EXPORT"/home/chip/.lesshst \
      "$EXPORT"/home/chip/.viminfo
rm -rf "$EXPORT"/home/chip/.cache/* "$EXPORT"/home/chip/.thumbnails \
       "$EXPORT"/home/chip/.ssh "$EXPORT"/home/chip/.gnupg
find "$EXPORT/var/log" -type f -exec truncate -s 0 {} +
# sudo records "already lectured" per user name, as a file named after the user.
rm -rf "$EXPORT"/var/lib/sudo/lectured/* "$EXPORT"/var/lib/sudo/ts/*

log "applying the overlay"
# Force root ownership: the overlay files may belong to whoever copied them here,
# and that uid must not leak into the image. --no-overwrite-dir keeps the
# metadata of directories that already exist (/etc, /usr, ...).
tar -C "$OVERLAY" --owner=0 --group=0 --numeric-owner -cf - . \
    | tar -C "$EXPORT" --no-overwrite-dir -xpf -
mkdir -p "$EXPORT/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/ssh-keygen-firstboot.service \
    "$EXPORT/etc/systemd/system/multi-user.target.wants/ssh-keygen-firstboot.service"
# FTP and VNC are opt-in (see pocketchip-services).
find "$EXPORT/etc/systemd/system" "$EXPORT"/etc/rc?.d -lname '*vsftpd*' -delete 2>/dev/null || true
find "$EXPORT/etc/systemd/system" "$EXPORT"/etc/rc?.d -lname '*x11vnc*' -delete 2>/dev/null || true
mkdir -p "$EXPORT/tmp" "$EXPORT/var/tmp" "$EXPORT/root"
chmod 1777 "$EXPORT/tmp" "$EXPORT/var/tmp"
chmod 700 "$EXPORT/root"
echo "pocketchip-debian $VERSION (Debian $(cat "$EXPORT/etc/debian_version")), built $(date -u +%Y-%m-%d)" \
    > "$EXPORT/etc/pocketchip-debian-release"

log "checking that no file name contains the personal account"
if find "$EXPORT" -xdev -iname "*${PRIVATE_USER}*" | grep .; then
    die "file names containing '$PRIVATE_USER' remain (listed above)"
fi

log "checking for files owned by users that no longer exist"
orphans="$(chroot "$EXPORT" find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | head -20)"
if [ -n "$orphans" ]; then
    echo "$orphans" >&2
    die "files with an unknown owner remain (listed above)"
fi

log "package manifest"
# Only installed packages; removed ones keep a dpkg entry while their config remains.
# shellcheck disable=SC2016  # dpkg format string
chroot "$EXPORT" dpkg-query -W -f '${db:Status-Abbrev}${Package} ${Version}\n' \
    | sed -n 's/^ii //p' | sort > "${EXPORT}.packages.txt"

log "checking that no personal data is left"
if grep -rIlE "$FORBIDDEN_REGEX" "$EXPORT/etc" "$EXPORT/home" "$EXPORT/root" "$EXPORT/var/lib" 2>/dev/null | head -20 | grep .; then
    die "personal data found in the files above; fix before publishing"
fi

log "done: $EXPORT ($(du -sh "$EXPORT" | cut -f1)); manifest: ${EXPORT}.packages.txt"
