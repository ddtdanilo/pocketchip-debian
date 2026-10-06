# Upgrading the stock image to Debian 10

This is the reference procedure that produced the release image: a stock NTC
PocketCHIP image (Debian 8 "jessie") taken to Debian 10 "buster". It was run
step by step on a real device. You do not need it if you flash the release
image; it is here so the result is reproducible and so you can adapt it.

Plan on 3 to 4 hours, mostly waiting: the CPU is a single 1 GHz core and the
Debian archive downloads at about 250 kB/s over Wi-Fi.

> Do not power the device off while `dpkg` is working. Everything below can be
> done over the USB serial console if the network is not available.

## 0. Flash the stock image

Follow [flashing.md](flashing.md) with NTC's stock image
`stable-pocketchip-b126` (see [getting the stock image](flashing.md#getting-the-stock-image)).
Log in as `chip` / `chip`.

## 1. Point apt at the archive

NTC's repository and the Debian mirrors for old releases are gone. Use
`archive.debian.org`. Jessie's keys are expired, so for the first hops tell apt
to ignore the expiry and trust the archive:

```sh
echo 'Acquire::Check-Valid-Until "false";' | sudo tee /etc/apt/apt.conf.d/99archive
```

Create `/etc/apt/sources.list` for the release you are going to:

```
deb [trusted=yes] http://archive.debian.org/debian stretch main contrib non-free
deb [trusted=yes] http://archive.debian.org/debian-security stretch/updates main contrib non-free
```

Remove everything in `/etc/apt/sources.list.d/`.

## 2. Jessie -> Stretch

```sh
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes \
     -o Dpkg::Options::=--force-confold upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes \
     -o Dpkg::Options::=--force-confold dist-upgrade
```

Run it inside `screen` or with `nohup`: it takes about 1.5 hours. Then, before
rebooting:

1. **X driver.** `armsoc` is gone in Stretch. Use `modesetting`: take
   [`configs/xorg.conf`](../configs/xorg.conf) and change the driver to
   `modesetting`.
2. **Wi-Fi.** Use [`configs/NetworkManager.conf`](../configs/NetworkManager.conf).
   Without `wifi.scan-rand-mac-address=no`, NetworkManager loops forever on
   `set-hw-addr ... not successfully set (scanning)` and never connects.
3. **Window manager.** Apply [`patches/awesome-rc.lua.patch`](../patches/awesome-rc.lua.patch)
   (awesome 3 -> 4 API) or the launcher never starts.
4. **First-boot script.** Replace `/etc/rc.local` with a script that only runs
   `exit 0`. The stock one regenerates all SSH host keys on every boot because
   it waits for an SSHv1 key that modern OpenSSH never creates.

Reboot and check the launcher shows on the screen.

## 3. Stretch -> Buster

Same as step 2 with `stretch` replaced by `buster` in `sources.list` (about
1.5 hours, ~1.6 GB used afterwards). Then:

1. **X driver**: `Driver "fbdev"` in `/etc/X11/xorg.conf`
   ([`configs/xorg.conf`](../configs/xorg.conf)).
2. **awesome 4.3** dropped more deprecated calls. The patch already covers
   them (`awful.spawn`, `awful.spawn.with_shell`, `gears.table.join`).
3. **Battery warnings.** Apply
   [`patches/pocketchip-battery-warnings.patch`](../patches/pocketchip-battery-warnings.patch)
   so `pocketchip-warn05/15` stop failing while charging.

Finally remove `[trusted=yes]` from `sources.list` and run `apt-get update`:
Buster's own keyring verifies the archive without it.

Reboot. Expected result: `cat /etc/debian_version` prints `10.13`, `uname -r`
still prints `4.4.13-ntc-mlc` (the kernel is not part of the upgrade), and the
launcher is on the screen.

## Notes

- Do not skip Stretch. Jumping straight from 8 to 10 is not supported by Debian.
- Do not go beyond Buster on this kernel without testing: newer Debian releases
  need newer system components than the 4.4 kernel was built for.
- The kernel stays at NTC's 4.4.13, which is what drives the screen, the touch
  panel and the Wi-Fi chip.
