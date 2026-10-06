# Flashing the image

This replaces everything on the device's internal flash (NAND). If you have
anything on it you want to keep, copy it off first.

> [!NOTE]
> `flash.sh` follows NTC's own flashing sequence, but in v0.1.0 it has not been
> run end to end yet. The same tools (`sunxi-fel` + current `fastboot`) were
> used by hand to flash the stock image on the real device. Please report how
> it went.

You need:

- A PocketCHIP (or a bare C.H.I.P.) and its **battery connected**.
- A micro-USB **data** cable. Charge-only cables are the most common reason
  nothing shows up.
- A paper clip or jumper wire.
- A Mac or Linux computer. Windows is not covered.

## 1. Know your NAND

The C.H.I.P. shipped with one of two NAND chips. `flash.sh` detects it for you
and refuses to flash the wrong image.

| NAND | Image to download |
|---|---|
| Hynix 8 GB MLC | `pocketchip-debian10-v0.1.0-hynix-8g.ubi.sparse` |
| Toshiba 4 GB MLC | `pocketchip-debian10-v0.1.0-toshiba-4g.ubi.sparse` (not tested on hardware) |

If you do not know which one you have, download the Hynix one: if the device
turns out to be Toshiba, the script stops before erasing anything and tells you
which file to use.

Download the image, `SHA256SUMS-v0.1.0` and `pocketchip-bootloader-ntc-b126.tar.gz`
from the [latest release](https://github.com/ddtdanilo/pocketchip-debian/releases/latest).
Check the hashes:

```sh
shasum -a 256 -c SHA256SUMS-v0.1.0 --ignore-missing   # macOS
sha256sum -c SHA256SUMS-v0.1.0 --ignore-missing        # Linux
```

Unpack the bootloader files next to the image:

```sh
mkdir bootloader && tar -xzf pocketchip-bootloader-ntc-b126.tar.gz -C bootloader
```

## 2. Install the host tools

You need `sunxi-fel`, `fastboot` and `mkimage`.

### macOS

`sunxi-tools` is not in Homebrew core, so build it:

```sh
brew install libusb pkg-config dtc zlib u-boot-tools android-platform-tools
git clone --depth 1 https://github.com/linux-sunxi/sunxi-tools.git
cd sunxi-tools
make sunxi-fel \
  CFLAGS="-std=c99 -Wall -Wno-unused-result -D_POSIX_C_SOURCE=200112L -D_DEFAULT_SOURCE -I/opt/homebrew/include -Iinclude/" \
  LDFLAGS="-L/opt/homebrew/lib"
sudo install -m 0755 sunxi-fel /usr/local/bin/
```

On an Intel Mac replace `/opt/homebrew` with `/usr/local`. This was done on an
Apple-silicon Mac with `sunxi-tools` at its latest commit.

### Debian / Ubuntu

```sh
sudo apt install sunxi-tools u-boot-tools fastboot
```

Allow your user to talk to the device without root:

```sh
sudo tee /etc/udev/rules.d/99-allwinner.rules <<'RULES'
SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="efe8", MODE="0660", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="1010", MODE="0660", GROUP="plugdev"
RULES
sudo udevadm control --reload-rules
sudo usermod -aG plugdev "$USER"   # log out and back in
```

## 3. Put the device in FEL mode

1. Switch the PocketCHIP off and unplug it.
2. Open the back. On the C.H.I.P. board find the **FEL** pin and any **GND**
   pin on the header (FEL is on the right edge, USB port pointing up).
3. Bridge FEL and GND with the paper clip.
4. While keeping the bridge, connect the micro-USB cable to the computer.

Check that the computer sees it:

```sh
sunxi-fel ver        # expected: AWUSBFEX soc=00001625(A13) ...
```

On a Mac, `ioreg -p IOUSB -l | grep 7994` also shows it (vendor `0x1f3a`,
product `0xefe8`).

## 4. Flash

```sh
scripts/flash.sh --ubi pocketchip-debian10-v0.1.0-hynix-8g.ubi.sparse \
                 --bootloader-dir bootloader
```

The script detects the NAND, erases it, writes the bootloader and the system
image (about 5 minutes for the image itself) and tells you when it is done.
Keep the FEL jumper on until it finishes.

Then remove the jumper, unplug the cable and power the device on. The first
boot takes a couple of minutes (SSH host keys are generated, the file system
is checked). Continue with [first boot](first-boot.md).

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `waiting for FEL` never succeeds | Charge-only cable, FEL not bridged to GND when plugging in, or a USB hub. Use a short data cable straight into the computer. |
| `usb_bulk_send() ERROR -7: Operation timed out` | The USB port gives too little power. Feed 5 V to the `CHG-IN` pin, try another cable, or try `sunxi-tools` v1.4.1. |
| `fastboot: invalid option -- 'i'` | You are running NTC's original scripts with a modern `fastboot`. Use `scripts/flash.sh`. |
| `permission denied` on Linux | Missing udev rule (step 2), or run the script with `sudo`. |
| Black screen after flashing | Remove the FEL jumper and power-cycle. Wait 2 minutes on the first boot. |
| The script says the NAND does not match the image | You downloaded the wrong variant. Use the file it names. |

## Getting the stock image

NTC's servers are gone, but its images are preserved on the Internet Archive:
<https://archive.org/details/C.h.i.p.FlashCollection>. The stock PocketCHIP image
is `stable-pocketchip-b126.zip` (about 1 GB). It contains the proprietary
packages this project leaves out (PICO-8, SunVox, Mali userspace).

NTC's own flashing scripts are in `CHIP-tools.zip` in the same collection; the
community-maintained [Flash-CHIP](https://github.com/Thore-Krug/Flash-CHIP) wraps
them but depends on a download server that no longer exists.
