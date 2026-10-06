# First boot

Log in on the PocketCHIP's own screen: the launcher starts automatically.

## Accounts

| User | Password | Notes |
|---|---|---|
| `chip` | `chip` | Has `sudo`. The launcher session runs as this user. |

**Change the password immediately.** Open Terminal in the launcher and run:

```sh
passwd
```

Optionally add your own administrator account and keep `chip` for the launcher:

```sh
sudo adduser alice
sudo usermod -aG sudo,video,audio,dialout,plugdev,netdev,input alice
```

## Wi-Fi

From the launcher: Wi-Fi icon (top right). From a terminal:

```sh
nmcli dev wifi list
sudo nmcli dev wifi connect "<ssid>" password "<password>"
```

The connection is saved and comes back on every boot. You can also use the USB
cable: the device shows up as a serial port (`/dev/ttyACM0` on Linux,
`/dev/cu.usbmodem*` on macOS), `screen /dev/cu.usbmodem* 115200` to log in.

## Remote access

SSH is on from the first boot:

```sh
ssh chip@chip.local        # or use the IP address
```

The device announces itself as `chip.local` (Avahi/mDNS). Host keys are created
on first boot, so your SSH client will ask you to trust a new key once.

FTP and VNC are installed but **off**, because they send credentials in clear
text. Turn them on if you want them:

```sh
sudo pocketchip-services status
sudo pocketchip-services enable-vnc    # asks for a VNC password (first 8 characters count)
sudo pocketchip-services enable-ftp
```

- **VNC** mirrors the PocketCHIP's own screen (the same X session), port 5900.
  macOS: Finder -> Go -> Connect to Server -> `vnc://chip.local`.
- **FTP** is plain vsftpd for local users on port 21. Prefer SFTP (the same
  login over SSH, port 22) for anything that matters.

Turn them off again with `disable-vnc` / `disable-ftp`.

## Installing software

The Debian 10 repositories moved to the archive, and the image already points
there. Refresh the package lists once, then install as usual:

```sh
sudo apt update
sudo apt install htop git python3-pip
```

`apt` verifies signatures with Debian's keyring. Expect no new versions: buster
is frozen. Firefox ESR 115 is installed but a 512 MB, single-core device is slow
with modern web pages.

## Clock

The C.H.I.P. has no battery-backed clock. After a boot without network the date
can be wrong (it starts at 1970 until NTP syncs), which can make HTTPS and
`apt` complain. Connecting to Wi-Fi fixes it.

## Where things live

| Thing | Path |
|---|---|
| Launcher entries | `/usr/share/pocket-home/config.json` |
| Window manager config (awesome) | `~chip/.config/awesome/rc.lua` |
| X server config | `/etc/X11/xorg.conf` |
| Image version | `/etc/pocketchip-debian-release` |
