# Known issues

- **The v0.1.0 image has not been flashed and booted yet.** It was built from a
  verified device, but the round trip (flash, first boot, SSH keys generated,
  USB Ethernet up by itself) and `scripts/flash.sh` are untested. Reports
  welcome.

- **No GPU acceleration out of the box.** The Mali userspace library is
  proprietary and not shipped; X uses the software `fbdev` driver. OpenGL ES 2.0
  acceleration is one script away, see [gpu.md](gpu.md). Desktop OpenGL and 2D
  drawing stay in software either way.
- **PICO-8 needs its package fixed before it installs** (see [below](#pico-8)).
  Upgrading the stock image to Debian 10 also removes it for this reason.

## PICO-8

NTC's `chip-pico-8` 0.1.9 package declares `Depends: libcurl3`, which Debian 10
does not have, so `dpkg` refuses it and the Debian 10 upgrade removes it. The
binary itself only needs `libcurl.so.4`, which Debian 10's `libcurl4` provides.
With your copy of the package (from the stock image, see
[THIRD_PARTY.md](../THIRD_PARTY.md)):

```sh
dpkg-deb -R chip-pico-8_0.1.9.ntc4_armhf.deb pico8
sed -i 's/libcurl3/libcurl4/; s/^Version: .*/&+deb10/' pico8/DEBIAN/control
dpkg-deb --root-owner-group -b pico8 chip-pico-8-deb10.deb
sudo dpkg -i chip-pico-8-deb10.deb
```

The launcher's "Play PICO-8" icon then works again. Verified on a PocketCHIP
with Debian 10.
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
