#!/usr/bin/env bash
# make-ubi.sh - runs inside the container. Turns /in/rootfs.tar into flashable
# UBI images in /out. Geometry values are the ones used by NTC's own
# chip-create-nand-images.sh for the two MLC NAND chips found in the CHIP.
set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
ERASE_SIZE=4194304      # 4 MiB physical erase block
PAGE_SIZE=16384         # 16 KiB page
SUBPAGE_SIZE=16384
# MLC NAND only uses half of each erase block ("dist3" layout), minus headers.
LEB_SIZE=$((ERASE_SIZE / 2 - PAGE_SIZE * 2))
MAX_LEB_COUNT=4096

WORK=/work
mkdir -p "$WORK/rootfs"
echo "==> extracting rootfs"
tar -xpf /in/rootfs.tar -C "$WORK/rootfs" --numeric-owner

echo "==> building UBIFS"
mkfs.ubifs -r "$WORK/rootfs" -m "$PAGE_SIZE" -e "$LEB_SIZE" -c "$MAX_LEB_COUNT" \
    -o "$WORK/rootfs.ubifs"
rm -rf "$WORK/rootfs"

build_variant() {
    local name="$1" vol_size="$2"
    local cfg="$WORK/ubi-$name.cfg" ubi="$WORK/$name.ubi"
    local out="/out/pocketchip-debian10-v${VERSION}-${name}.ubi.sparse"

    cat > "$cfg" <<CFG
[rootfs]
mode=ubi
vol_id=0
vol_size=$vol_size
vol_type=dynamic
vol_name=rootfs
vol_alignment=1
image=$WORK/rootfs.ubifs
CFG
    echo "==> ubinize $name ($vol_size)"
    ubinize -o "$ubi" -p "$ERASE_SIZE" -m "$PAGE_SIZE" -s "$SUBPAGE_SIZE" \
        -M dist3 "$cfg"
    img2simg "$ubi" "$out" "$ERASE_SIZE"
    rm -f "$ubi"
    ls -l "$out"
}

# Toshiba 4 GB MLC (OOB 1280): 3584 MiB volume. Hynix 8 GB MLC (OOB 1664): 7168 MiB.
build_variant toshiba-4g 3584MiB
build_variant hynix-8g 7168MiB

( cd /out && sha256sum ./*.ubi.sparse > "SHA256SUMS-v${VERSION}" )
echo "==> done"
