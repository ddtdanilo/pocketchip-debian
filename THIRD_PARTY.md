# Third-party components

This repository's own files (scripts, configuration, documentation) are MIT
licensed. The system image it produces is an aggregate of many other projects,
each under its own license.

## What is in the image

| Component | Source | License |
|---|---|---|
| Debian 10 "buster" packages | `archive.debian.org` | Per package, see `/usr/share/doc/<package>/copyright` in the image |
| Linux 4.4.13-ntc-mlc kernel and modules | Next Thing Co. (NTC) | GPL-2.0 |
| U-Boot and SPL (bootloader release asset) | NTC build of U-Boot | GPL-2.0-or-later |
| `pocket-home`, `pocket-wm`, `pocketchip-*`, `chip-*` packages | NTC, mirrored by the community | As published by NTC; see each package's `copyright` file |

The full package list with versions is in
[`docs/packages.txt`](docs/packages.txt).

NTC went out of business in 2018 and its servers are gone. The software above
is redistributed on the understanding that NTC published it as open source. If
you hold rights to any of it and want something removed, open an issue.

## What is deliberately NOT in the image

These are proprietary and are not redistributed here:

- **PICO-8** (`chip-pico-8`) - Lexaloffle Games. Buy it from <https://www.lexaloffle.com/pico-8.php>.
- **SunVox** (`chip-sunvox`) - Alexander Zolotov. Available from <https://warmplace.ru/soft/sunvox/>.
- **Mali userspace libraries** (`chip-mali-userspace`: `libMali.so`, EGL, GLES) - ARM proprietary.

The two launcher icons that started PICO-8 and SunVox are removed. The kernel
Mali module (`chip-mali-modules`, GPL) is kept. The Mali userspace library is
downloaded from NTC's repository by [`scripts/enable-gpu.sh`](scripts/enable-gpu.sh)
on your device, only after you accept ARM's licence; see [`docs/gpu.md`](docs/gpu.md).
For SunVox and PICO-8, take the `.deb` from NTC's original image (see
[`docs/flashing.md`](docs/flashing.md#getting-the-stock-image)). PICO-8's
package needs a one-line dependency fix first, see
[`docs/known-issues.md`](docs/known-issues.md#pico-8).

## Fetched on the device by optional scripts (not distributed)

- NTC's `xf86-video-armsoc` X driver (MIT), built from source at a pinned commit
  by `scripts/enable-gpu.sh`: <https://github.com/nextthingco/xf86-video-armsoc>.
- ARM's Mali userspace driver r6p0 (`libMali.so`, proprietary ARM EULA), from
  <https://github.com/NextThingCo/chip-mali-userspace>.

## Build-time tools (not distributed)

- NTC's fork of `mtd-utils` (`ubinize -M dist3`), GPL-2.0, mirrored at
  <https://github.com/ntc-chip-revived/CHIP-mtd-utils>, pinned by commit in
  [`docker/Dockerfile`](docker/Dockerfile).
- `sunxi-tools` (GPL-2.0), <https://github.com/linux-sunxi/sunxi-tools>.
