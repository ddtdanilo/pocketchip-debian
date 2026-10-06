# Hardware notes

What was checked on a PocketCHIP with Hynix 8 GB NAND, the device the v0.1.0
image was exported from. "Verified" means it was run on that device; "not
verified" means it is expected but untested. The image itself has not yet been
flashed back and booted.

| Part | Status |
|---|---|
| SoC | Allwinner R8 (reports as A13), 1 GHz ARM Cortex-A8, 512 MB RAM. Verified. |
| Display | 480x272 panel, shows the launcher. Verified (screenshots in the README). |
| Keyboard | Built-in keyboard. Not verified in this release. |
| Wi-Fi | Realtek RTL8723BS (`8723bs`), 2.4 GHz only. Connects and comes back after reboot. Verified. Slow and fragile under sustained load, see [networking.md](networking.md). |
| Battery | Voltage and charge current read correctly through the AXP209. Verified. |
| Audio input | The codec exposes capture channels (Mic1/Mic2) and records samples. Not verified that a physical microphone is connected. |
| GPU | The Mali-400 kernel driver loads (`/dev/mali`). The userspace libraries are proprietary and not included, and X runs on `fbdev`, so there is no 3D acceleration. Not verified beyond the driver loading. |
| Bluetooth | Not verified. |
| Touch panel | Not verified in this release. |
| USB Ethernet | `usb0` gadget interface, link-local `169.254.x.x`. Verified with the address set by hand; the udev rule that lets NetworkManager bring it up by itself ships in the image but is not verified on a freshly flashed device. See [networking.md](networking.md). |
| NAND | Hynix 8 GB MLC verified. Toshiba 4 GB MLC image built identically, not hardware-tested. |

The kernel is NTC's `4.4.13-ntc-mlc` and is the same as the stock image.
