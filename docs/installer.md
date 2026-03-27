# Installer

The repo includes an interactive Linux installer:

- `scripts/install.sh`

It is intended for common self-hosted environments such as:

- Debian
- Ubuntu
- Proxmox VE containers
- Proxmox LXC guests where you are already root and `sudo` is not installed

## What the installer does

- Detects whether it is running as root or needs `sudo`
- Detects Debian/Ubuntu-style package managers and can install `curl` if needed
- Downloads the correct published release binary
- Verifies the downloaded binary against `sha256sums.txt`
- Searches common locations for a public root CA certificate
- Searches common locations for a logo file
- Prompts for missing config values with sensible defaults
- Installs the binary, config, assets, and systemd unit in standard locations
- Creates a `trust-onboard` service user when possible
- Enables and starts the service when `systemd` is available

## Standard install paths

- Binary: `/usr/local/bin/trust-onboard`
- Config: `/etc/trust-onboard/config.yaml`
- Assets: `/var/lib/trust-onboard/assets/`
- Unit: `/etc/systemd/system/trust-onboard.service`

## Usage

Run from the repo checkout:

```bash
./scripts/install.sh
```

The script is interactive. It tries to fill in defaults from the current machine and asks for the rest.

By default it installs the latest public release. To pin a specific release:

```bash
TRUST_ONBOARD_VERSION=v0.1.0 ./scripts/install.sh
```

## Auto-detection behavior

The installer tries these kinds of defaults before prompting:

- Hostname-based site title and organization name
- A `base_url` derived from the current hostname
- Root cert from common locations such as:
  - `./assets/root_ca.crt`
  - `/etc/step-ca/certs/root_ca.crt`
  - `/root/.step/certs/root_ca.crt`
  - `/var/lib/trust-onboard/assets/root_ca.crt`
- Logo from common locations such as:
  - `./assets/logo.svg`
  - `./assets/logo.png`
  - `/var/lib/trust-onboard/assets/logo.svg`

## Environments without sudo

If the machine does not have `sudo`, the script still works when run as root.

That is common in Proxmox LXC containers, and the installer handles it directly.

## Environments without systemd

If `systemctl` is not available, the script still installs the files and generated config, but it skips service enablement.

## Release download requirements

The installer expects published releases to be reachable without interactive authentication.

It downloads:

- the platform-specific binary
- `sha256sums.txt`

from the release download endpoint and verifies the binary when `sha256sum` or `shasum` is available.
