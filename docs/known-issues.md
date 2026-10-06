# Known issues

- **The v0.1.0 image has not been flashed and booted yet.** It was built from a
  verified device, but the round trip (flash, first boot, SSH keys generated,
  USB Ethernet up by itself) and `scripts/flash.sh` are untested. Reports
  welcome.

- **No GPU acceleration.** The Mali userspace libraries are proprietary and are
  not shipped. X uses the software `fbdev` driver. Firefox and anything
  graphical are slow.
- **No PICO-8 and no SunVox.** Proprietary, removed from the image. See
  [`THIRD_PARTY.md`](../THIRD_PARTY.md) for where to get them.
- **`FBIOPUTCMAP: Invalid argument`** is repeated in `/var/log/Xorg.0.log`. It is
  the `fbdev` driver trying to set a color palette the display does not
  support; the screen is not affected.
- **Wrong date after an offline boot.** There is no battery-backed clock.
- **Debian 10 and Linux 4.4 are end-of-life.** See [SECURITY.md](../SECURITY.md).
- **Toshiba 4 GB image is untested.** It is built with the same recipe, but no
  device was available to confirm it boots.
- **VNC passwords are limited to 8 characters** by the protocol.
- **Wi-Fi is slow and can drop under sustained load.** About 0.3 MB/s, and an
  SSH session dropped once during a long transfer. Use the USB cable for large
  transfers ([networking.md](networking.md)).
