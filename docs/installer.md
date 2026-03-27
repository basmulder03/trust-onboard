# Installer

This project includes an interactive Linux installer:

- `scripts/install.sh`

It is intended for Debian, Ubuntu, and common Proxmox container setups.

## What the installer does

- Detects whether it is running as root or needs `sudo`
- Can install `curl` when a supported package manager is available
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

Run from a local checkout:

```bash
./scripts/install.sh
```

The script fills in defaults from the current machine and prompts for the rest.

By default it installs the latest public release. To pin a specific release:

```bash
TRUST_ONBOARD_VERSION=v0.1.0 ./scripts/install.sh
```

## Auto-detection behavior

Defaults include:

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

If `sudo` is not installed, run the script as root.

## Environments without systemd

If `systemctl` is not available, the script installs files and config but skips service enablement.

## Release download requirements

The installer downloads the platform binary and `sha256sums.txt`, then verifies the binary when `sha256sum` or `shasum` is available.
