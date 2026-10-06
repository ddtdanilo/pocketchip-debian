# Contributing

Thanks for helping keep these little machines alive.

## Good first contributions

- Test the **Toshiba 4 GB** image on a real device and report the result.
- Check the **microphone**, **Bluetooth** and **touch panel** and add the
  results to [`docs/hardware.md`](docs/hardware.md).
- Improve the docs where you got stuck.

## Rules

- Scripts must pass `shellcheck -x` (CI runs it).
- Code, identifiers and comments are in English.
- Never commit passwords, Wi-Fi names, keys or any personal data, and never
  attach them to issues.
- Do not add proprietary binaries. Document where to obtain them instead.
- Keep changes small and say how you tested them, including which NAND chip.

## Commits

Use short, imperative messages (`Fix flash.sh on Linux without sudo`). One topic
per commit. There is no CLA.
