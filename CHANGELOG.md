# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-06

Pre-release: the image is built from a verified device but has not been
flashed back and booted yet.

### Added
- Flashable Debian 10 (buster) image for the PocketCHIP (Hynix 8 GB MLC NAND).
- Image for Toshiba 4 GB MLC NAND units (built the same way, not hardware-tested).
- `scripts/flash.sh`: FEL + fastboot flasher for macOS and Linux, compatible
  with current `fastboot`.
- `scripts/export-rootfs.sh` and `scripts/build-image.sh`: reproducible image
  build from a running device.
- `pocketchip-services` helper to opt in to FTP and VNC.
- Documentation: flashing, first boot, building, upgrading from the stock image.

### Changed
- Display: X uses the `fbdev` driver; `armsoc` no longer exists in Debian 9+.
- `awesome` configuration ported to the awesome 4.3 API so the PocketCHIP
  launcher starts.
- NetworkManager no longer randomizes the MAC during Wi-Fi scans (the CHIP's
  driver cannot do it and looped forever).
- SSH host keys are no longer regenerated at every boot.

### Fixed
- USB Ethernet (`usb0`) is managed by NetworkManager again; Debian 10's
  `85-nm-unmanaged.rules` had marked every USB gadget interface unmanaged.
- `pocketchip-warn05` / `pocketchip-warn15` no longer fail while charging.

### Removed
- PICO-8, SunVox and the Mali userspace libraries (proprietary; see
  `THIRD_PARTY.md`).
