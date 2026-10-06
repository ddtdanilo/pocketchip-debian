# Security policy

## Read this before putting the device on a network

- **Debian 10 and the 4.4 kernel are end-of-life.** There are no more security
  updates. Treat the device as untrusted: keep it on a home LAN behind a router,
  never expose it to the internet, and do not use it for anything sensitive.
- **The default login is `chip` / `chip`.** Change it on first boot (`passwd`).
- **FTP and VNC are off by default** because both send credentials in clear
  text. Turn them on only on a network you trust (`sudo pocketchip-services`).
  Prefer SFTP (port 22) over FTP.
- SSH host keys are generated on the first boot of each device, so no two
  devices share keys.

## Reporting a problem in this repository

For anything in the scripts, configuration or release assets of this project,
open a GitHub issue. If it should not be public (for example, a leaked secret
in a release asset), use GitHub's private vulnerability reporting on this
repository.

Vulnerabilities in Debian, the Linux kernel or U-Boot themselves should be
reported to those projects; there is nothing this repository can patch there.
