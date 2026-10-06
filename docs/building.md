# Building the image yourself

The release image is produced from a running PocketCHIP in two steps, so you
can reproduce it or make your own variant.

```
running PocketCHIP --export-rootfs.sh--> rootfs.tar --build-image.sh (Docker)--> .ubi.sparse
```

## 1. Prepare a device

Start from a PocketCHIP that has the system you want to capture. To reproduce
this project, flash the stock image and upgrade it to Debian 10 following
[upgrade-from-stock.md](upgrade-from-stock.md), or simply flash the release
image and customize it.

You need about 4 GB of free space on the device for the temporary copy.

## 2. Export a sanitized copy (on the device)

Copy `scripts/` and `overlay/` to the device and run, as root:

```sh
sudo PRIVATE_USER=<your personal account> \
     FORBIDDEN_REGEX='<account>|<wifi ssid>|<any password>' \
     bash scripts/export-rootfs.sh
```

`export-rootfs.sh` never changes the running system. It copies the root file
system to `/var/tmp/pocketchip-export` and then:

- removes the proprietary packages (PICO-8, SunVox, Mali userspace) and their
  launcher entries;
- deletes your personal account, Wi-Fi profiles, SSH host keys, VNC password,
  shell history, caches and logs;
- empties `/etc/machine-id` so each device gets its own;
- applies everything in `overlay/` (first-boot SSH key generation, the
  `pocketchip-services` helper, the login message) and turns FTP and VNC off;
- **fails** if any of these checks does not pass:
  - a string matching `FORBIDDEN_REGEX` is still found under `/etc`, `/home`,
    `/root` or `/var/lib`;
  - a file or directory **name** contains the personal account (sudo, for
    example, keeps `/var/lib/sudo/lectured/<user>`);
  - a file is owned by a user or group that does not exist in the image (an
    orphaned uid could later be handed to a different account).

The package list is written next to it as `pocketchip-export.packages.txt`.
If a check fails, fix the cause and run again with `SKIP_COPY=1` to reuse the
copy instead of waiting for a new one (the steps are idempotent).

> Lesson learned while building this: run the script from files you do not own
> by an account you are about to delete. The overlay is extracted with root
> ownership on purpose; copying it with the original owner leaked uid 1001 into
> `/etc`, `/usr` and the files themselves in an earlier draft.

Stream the result to your computer (it is a plain tar, about 1.6 GB). **Use the
USB cable, not Wi-Fi**: it is about ten times faster (see
[networking.md](networking.md)). With `nc` listening on the computer:

```sh
# computer
nc -l 9999 > rootfs.tar
# device
sudo tar -C /var/tmp/pocketchip-export --numeric-owner -cpf - . > /dev/tcp/<computer-ip>/9999
```

If you prefer SSH, `ssh chip@<device> 'sudo tar -C /var/tmp/pocketchip-export
--numeric-owner -cpf - .' > rootfs.tar` works too, at Wi-Fi speed (hours).

## 3. Build the images (on your computer)

You need Docker. Nothing else is installed on the host.

```sh
scripts/build-image.sh rootfs.tar 0.1.0
```

This builds a container with NTC's fork of `mtd-utils` and writes to `dist/`:

- `pocketchip-debian10-v0.1.0-hynix-8g.ubi.sparse`
- `pocketchip-debian10-v0.1.0-toshiba-4g.ubi.sparse`
- `SHA256SUMS-v0.1.0`

### Why the odd tooling

The C.H.I.P.'s MLC NAND is used in a special "dist3" layout that only NTC's
`ubinize` can write (`-M dist3`). Upstream `mtd-utils` has no such option, and
an image built with it does not boot. The geometry constants (4 MiB erase block,
16 KiB page, half-size LEBs, 3584/7168 MiB volumes) come from NTC's own
`chip-create-nand-images.sh`.

The bootloader files (`sunxi-spl.bin`, `u-boot-dtb.bin`, `uboot-*.bin`,
`spl-*.bin`) are not rebuilt here; they come unchanged from NTC's stable
PocketCHIP image b126.

## 4. Test

Flash it ([flashing.md](flashing.md)) on a spare device before publishing, and
check at least: the launcher appears, Wi-Fi connects, SSH works, `apt update`
works, and a second boot comes up on its own.
