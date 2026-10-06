#!/usr/bin/env bash
# flash.sh - flash a PocketCHIP/CHIP NAND over USB (FEL + fastboot).
#
# Works on macOS and Linux. It replaces NTC's CHIP-tools for this one job and
# is adapted to modern fastboot. THIS ERASES THE WHOLE NAND OF THE DEVICE.
#
# Requirements: sunxi-fel (sunxi-tools), fastboot, mkimage (u-boot-tools).
#
# Usage:
#   scripts/flash.sh --ubi <image.ubi.sparse> --bootloader-dir <dir> [--yes]
#
# The bootloader directory must contain the NTC bootloader files:
#   sunxi-spl.bin  u-boot-dtb.bin  uboot-400000.bin  spl-400000-4000-680.bin
#   spl-400000-4000-500.bin   (see docs/flashing.md)
set -euo pipefail

UBI=""
BOOTDIR=""
ASSUME_YES=0
FEL="${FEL:-sunxi-fel}"
FASTBOOT="${FASTBOOT:-fastboot}"
MKIMAGE="${MKIMAGE:-mkimage}"

SPL_ADDR=0x43000000
UBOOT_ADDR=0x4a000000
SCRIPT_ADDR=0x43100000

die() { echo "error: $*" >&2; exit 1; }
log() { echo "==> $*"; }

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ubi) UBI="${2:?--ubi needs a file}"; shift 2 ;;
        --bootloader-dir) BOOTDIR="${2:?--bootloader-dir needs a directory}"; shift 2 ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        -h|--help) usage 0 ;;
        *) usage 1 ;;
    esac
done

[ -f "$UBI" ] || die "--ubi <file> is required and must exist"
[ -d "$BOOTDIR" ] || die "--bootloader-dir <dir> is required and must exist"
for tool in "$FEL" "$FASTBOOT" "$MKIMAGE"; do
    command -v "$tool" >/dev/null || die "$tool not found (see docs/flashing.md)"
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pocketchip-flash.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

wait_for_fel() {
    printf 'waiting for FEL'
    for _ in $(seq 1 60); do
        if "$FEL" ver >/dev/null 2>&1; then
            echo " OK"
            return 0
        fi
        printf '.'
        sleep 1
    done
    echo " TIMEOUT"
    die "no device in FEL mode. Jumper FEL to GND, then connect the micro-USB data cable."
}

wait_for_fastboot() {
    printf 'waiting for fastboot'
    for _ in $(seq 1 120); do
        if [ -n "$("$FASTBOOT" devices 2>/dev/null)" ]; then
            echo " OK"
            return 0
        fi
        printf '.'
        sleep 1
    done
    echo " TIMEOUT"
    die "the device did not come up in fastboot mode"
}

if [ "$ASSUME_YES" -ne 1 ]; then
    echo "This will ERASE the entire NAND of the connected device."
    read -r -p "Type 'erase' to continue: " answer
    [ "$answer" = "erase" ] || die "aborted"
fi

# 1. Detect the NAND chip: run U-Boot from RAM and read its 'nand info'.
log "detecting NAND"
cat > "$TMP/detect.cmds" <<'EOF'
nand info
env export -t -s 0x100 0x7c00 nand_erasesize nand_writesize nand_oobsize
reset
EOF
"$MKIMAGE" -A arm -T script -C none -n "detect NAND" -d "$TMP/detect.cmds" "$TMP/detect.scr" >/dev/null
wait_for_fel
"$FEL" spl "$BOOTDIR/sunxi-spl.bin"
sleep 1
"$FEL" write "$UBOOT_ADDR" "$BOOTDIR/u-boot-dtb.bin"
"$FEL" write "$SCRIPT_ADDR" "$TMP/detect.scr"
"$FEL" exe "$UBOOT_ADDR"
wait_for_fel
"$FEL" read 0x7c00 0x100 "$TMP/nand-info"
tr -d '\000' < "$TMP/nand-info" > "$TMP/nand-info.txt"
cat "$TMP/nand-info.txt"

nand_erasesize="$(sed -n 's/^nand_erasesize=//p' "$TMP/nand-info.txt")"
nand_writesize="$(sed -n 's/^nand_writesize=//p' "$TMP/nand-info.txt")"
nand_oobsize="$(sed -n 's/^nand_oobsize=//p' "$TMP/nand-info.txt")"
if [ -z "$nand_erasesize" ] || [ -z "$nand_writesize" ] || [ -z "$nand_oobsize" ]; then
    die "could not read the NAND geometry"
fi

case "$nand_oobsize" in
    680) variant="hynix-8g" ;;
    500) variant="toshiba-4g" ;;
    *) die "unsupported NAND (oob=$nand_oobsize). Only the MLC chips (Hynix 8 GB, Toshiba 4 GB) are supported." ;;
esac
case "$(basename "$UBI")" in
    *"$variant"*) ;;
    *) die "this device has a $variant NAND but the image is '$(basename "$UBI")'. Use the matching image." ;;
esac

SPL_BIN="$BOOTDIR/spl-$nand_erasesize-$nand_writesize-$nand_oobsize.bin"
UBOOT_BIN="$BOOTDIR/uboot-$nand_erasesize.bin"
[ -f "$SPL_BIN" ] || die "missing $SPL_BIN"
[ -f "$UBOOT_BIN" ] || die "missing $UBOOT_BIN"

# 2. Build the U-Boot script that erases the NAND, writes the bootloader and
#    stores the PocketCHIP boot environment, then enters fastboot.
if stat -f%z "$UBOOT_BIN" >/dev/null 2>&1; then
    uboot_size="$(stat -f%z "$UBOOT_BIN")"      # BSD/macOS
else
    uboot_size="$(stat -c%s "$UBOOT_BIN")"      # GNU
fi
uboot_size_hex="$(printf '0x%08x' "$uboot_size")"
pages_per_eb="$(printf '%x' $((0x$nand_erasesize / 0x$nand_writesize)))"

cat > "$TMP/flash.cmds" <<EOF
nand erase.chip
nand write.raw.noverify $SPL_ADDR 0x0 $pages_per_eb
nand write.raw.noverify $SPL_ADDR 0x400000 $pages_per_eb
nand write $UBOOT_ADDR 0x800000 $uboot_size_hex
setenv mtdparts mtdparts=sunxi-nand.0:4m(spl),4m(spl-backup),4m(uboot),4m(env),-(UBI)
setenv stdout serial
setenv stderr serial
setenv splashpos m,m
EOF
# Boot environment: single-quoted so ${...} and \$ reach U-Boot untouched.
cat >> "$TMP/flash.cmds" <<'EOF'
setenv clear_fastboot 'i2c mw 0x34 0x4 0x00 4;'
setenv write_fastboot 'i2c mw 0x34 0x4 66 1; i2c mw 0x34 0x5 62 1; i2c mw 0x34 0x6 30 1; i2c mw 0x34 0x7 00 1'
setenv test_fastboot 'i2c read 0x34 0x4 4 0x80200000; if itest.s *0x80200000 -eq fb0; then echo (Fastboot); i2c mw 0x34 0x4 0x00 4; fastboot 0; fi'
setenv bootargs root=ubi0:rootfs rootfstype=ubifs rw ubi.mtd=4 quiet lpj=501248 loglevel=3 splash plymouth.ignore-serial-consoles
setenv bootpaths 'initrd noinitrd'
setenv bootcmd 'run test_fastboot; if test -n ${fel_booted} && test -n ${scriptaddr}; then echo (FEL boot); source ${scriptaddr}; fi; for path in ${bootpaths}; do run boot_$path; done'
setenv boot_initrd 'mtdparts; ubi part UBI; ubifsmount ubi0:rootfs; ubifsload $fdt_addr_r /boot/sun5i-r8-chip.dtb; ubifsload 0x44000000 /boot/initrd.uimage; ubifsload $kernel_addr_r /boot/zImage; bootz $kernel_addr_r 0x44000000 $fdt_addr_r'
setenv boot_noinitrd 'mtdparts; ubi part UBI; ubifsmount ubi0:rootfs; ubifsload $fdt_addr_r /boot/sun5i-r8-chip.dtb; ubifsload $kernel_addr_r /boot/zImage; bootz $kernel_addr_r - $fdt_addr_r'
setenv video-mode
setenv dip_addr_r 0x43400000
setenv dip_overlay_dir /lib/firmware/nextthingco/chip/early
setenv dip_overlay_cmd 'if test -n "${dip_overlay_name}"; then ubifsload $dip_addr_r $dip_overlay_dir/$dip_overlay_name; fi'
setenv fel_booted 0
setenv bootdelay 1
saveenv
echo going to fastboot mode
fastboot 0
while true; do; sleep 10; done;
EOF
"$MKIMAGE" -A arm -T script -C none -n "flash pocketchip" -d "$TMP/flash.cmds" "$TMP/flash.scr" >/dev/null

# 3. Run it from RAM: this erases the NAND and leaves the device in fastboot.
log "erasing NAND and writing the bootloader"
wait_for_fel
"$FEL" spl "$BOOTDIR/sunxi-spl.bin"
sleep 1
"$FEL" write "$UBOOT_ADDR" "$UBOOT_BIN"
"$FEL" write "$SPL_ADDR" "$SPL_BIN"
"$FEL" write "$SCRIPT_ADDR" "$TMP/flash.scr"
"$FEL" exe "$UBOOT_ADDR"

# 4. Write the root filesystem image (a few minutes).
log "writing the system image"
wait_for_fastboot
"$FASTBOOT" flash UBI "$UBI"
"$FASTBOOT" continue >/dev/null

cat <<'EOF'

Done. Remove the FEL jumper (if still in place) and power-cycle the device.
The first boot takes a couple of minutes.
EOF
