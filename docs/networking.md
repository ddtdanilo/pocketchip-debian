# Networking: Wi-Fi, USB Ethernet and the serial console

The PocketCHIP has three ways to talk to a computer. They are very different in
speed and reliability, and the choice matters when you move big files.

| Link | How you reach it | Measured throughput | Use it for |
|---|---|---|---|
| Wi-Fi (`wlan0`, Realtek RTL8723BS) | `chip.local` or its IP | about 0.3 MB/s sustained | Shells, light copies, `apt` |
| USB Ethernet (`usb0`) | the micro-USB cable, link-local `169.254.x.x` | about 2.8 MB/s (limited by the NAND, not by USB) | Images, backups, anything big |
| USB serial console | `/dev/cu.usbmodem*` (macOS), `/dev/ttyACM0` (Linux) | 115200 baud | Recovery, first setup, debugging boot |

The numbers come from single runs on one device (Hynix 8 GB NAND, Apple-silicon
Mac, 2.4 GHz Wi-Fi). Treat them as orders of magnitude, not benchmarks.

## What was measured

Moving a 1.6 GB root file system off the device:

- **Wi-Fi, over SSH:** about 280 to 300 KB/s. Switching to plain TCP
  (`tar ... > /dev/tcp/<host>/<port>`) gave the same speed, so the SSH cipher
  (the CPU is a single 1 GHz core) is **not** the bottleneck; the Wi-Fi link is.
  Under that sustained load an SSH session dropped once with `Operation timed
  out`.
- **NAND read:** `tar` of a 60 MB directory took 17.8 s, about 3.4 MB/s. Reading
  the flash is the ceiling for anything that streams the file system.
- **USB Ethernet:** about 2.8 MB/s for the same `tar` stream, roughly ten times
  the Wi-Fi rate, and stable for the whole transfer.
- **`apt`** over Wi-Fi ran at about 250 kB/s during the Debian upgrades, which
  is why they take hours.

Rule of thumb: use Wi-Fi to log in, use the cable to move data.

## USB Ethernet

When you plug the device into a computer it shows up as a composite USB gadget
(vendor `0x0525`, "CDC Composite Gadget"): a serial port **and** a network
interface (`usb0` on the device, driver `g_ether`).

The device uses IPv4 link-local addressing (`169.254.0.0/16`), configured by
the `usb0_linklocal` NetworkManager profile. A Mac or Linux computer also
self-assigns a `169.254.x.x` address on that interface after a few seconds
(observed on macOS; most Linux desktops do the same through NetworkManager), so
no router or DHCP server is needed:

```sh
ssh chip@chip.local          # mDNS should resolve over the cable too (not tested)
ssh chip@169.254.10.55       # if you set a fixed address, see below
```

### Why it did not work after upgrading Debian (and how it is fixed)

On the stock Debian 8 image the USB network came up by itself. After upgrading
to Debian 10, `nmcli dev` showed `usb0 ethernet unmanaged` and the link never
got an address. The cause is a rule that ships with Debian 10's NetworkManager,
`/lib/udev/rules.d/85-nm-unmanaged.rules`:

```
ENV{DEVTYPE}=="gadget", ENV{NM_UNMANAGED}="1"
```

It marks every USB gadget interface as unmanaged, and `usb0` is one. The image
overrides it with a later rule, `/etc/udev/rules.d/86-pocketchip-usb0-managed.rules`
(see [`overlay/`](../overlay/etc/udev/rules.d/86-pocketchip-usb0-managed.rules)):

```
SUBSYSTEM=="net", KERNEL=="usb0", ENV{NM_UNMANAGED}="0"
```

If you upgraded a stock image yourself, add that file and reboot. To bring the
link up by hand on a device that does not have the rule:

```sh
sudo ip link set usb0 up
sudo ip addr add 169.254.10.55/16 dev usb0
```

On the Mac, the interface is listed as "CDC Composite Gadget" in
`networksetup -listallhardwareports`. If its status stays `inactive`, the
device side is not up yet.

## Moving large files

Over the USB cable, stream a tar through a raw TCP connection. On the computer:

```sh
nc -l 9999 > rootfs.tar
```

On the device (`<computer-ip>` is the computer's `169.254.x.x` or LAN address):

```sh
sudo tar -C /some/dir --numeric-owner -cpf - . > /dev/tcp/<computer-ip>/9999
```

This sends the data unencrypted, so use it only over the direct cable or a
network you trust, and only for data that is not secret (the exported image is
sanitized, see [building.md](building.md)). For anything sensitive, use
`ssh ... 'tar ...' > file` and accept the lower speed.

## Wi-Fi notes

- The CHIP's Wi-Fi driver is `8723bs`. It cannot change the MAC address while
  scanning. NetworkManager 1.14 tries to randomize it by default and then loops
  on `set-hw-addr ... not successfully set (scanning)`, so the device never
  connects. The image ships `wifi.scan-rand-mac-address=no` in
  `/etc/NetworkManager/NetworkManager.conf`.
- `wlan1` exists but is kept unmanaged by the same file.
- Only 2.4 GHz networks work.
- The clock has no battery. If the date is wrong after an offline boot, connect
  to Wi-Fi and wait for NTP before judging TLS or `apt` errors.

## Serial console

The same cable gives you a login prompt with no network at all, which is the
way to recover a device whose Wi-Fi is broken:

```sh
screen /dev/cu.usbmodem* 115200      # macOS
screen /dev/ttyACM0 115200           # Linux
```

Log in as `chip`. Press Return once if the screen is blank. Press `Ctrl-A` then
`K` to leave `screen`.
