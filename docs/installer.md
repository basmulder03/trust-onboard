# Installer

This project includes an interactive Linux installer:

- `scripts/install.sh`
- `scripts/upgrade.sh`
- `scripts/smoke-test.sh`
- `scripts/uninstall.sh`

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
./scripts/upgrade.sh
./scripts/smoke-test.sh
./scripts/uninstall.sh
./scripts/install.sh --help
./scripts/upgrade.sh --help
./scripts/smoke-test.sh --help
./scripts/uninstall.sh --help
```

The script fills in defaults from the current machine and prompts for the rest.

By default it installs the latest public release. To pin a specific release:

```bash
TRUST_ONBOARD_VERSION=v0.1.0 ./scripts/install.sh
TRUST_ONBOARD_VERSION=v0.1.0 ./scripts/upgrade.sh
```

## Unattended install

Set `TRUST_ONBOARD_UNATTENDED=1` to skip prompts and use detected values or environment variables.

Example:

```bash
TRUST_ONBOARD_UNATTENDED=1 \
TRUST_ONBOARD_ROOT_CERT_PATH=/etc/step-ca/certs/root_ca.crt \
TRUST_ONBOARD_SITE_TITLE="Homelab Trust Onboarding" \
TRUST_ONBOARD_ORGANIZATION_NAME="Mulder Homelab" \
TRUST_ONBOARD_BASE_URL="https://trust.example.internal" \
./scripts/install.sh
```

Useful variables:

- `TRUST_ONBOARD_UNATTENDED=1`
- `TRUST_ONBOARD_VERSION`
- `TRUST_ONBOARD_ROOT_CERT_PATH`
- `TRUST_ONBOARD_LOGO_PATH`
- `TRUST_ONBOARD_SITE_TITLE`
- `TRUST_ONBOARD_ORGANIZATION_NAME`
- `TRUST_ONBOARD_LISTEN_ADDRESS`
- `TRUST_ONBOARD_BASE_URL`
- `TRUST_ONBOARD_DISPLAYED_CA_NAME`
- `TRUST_ONBOARD_SUPPORT_TEXT`
- `TRUST_ONBOARD_SUPPORT_URL`
- `TRUST_ONBOARD_INTERNAL_DOMAINS`
- `TRUST_ONBOARD_EXTERNAL_DOMAINS`
- `TRUST_ONBOARD_ANDROID_FORMAT`
- `TRUST_ONBOARD_ADVANCED_ENABLED`
- `TRUST_ONBOARD_PAYLOAD_IDENTIFIER`
- `TRUST_ONBOARD_PAYLOAD_DISPLAY_NAME`
- `TRUST_ONBOARD_PAYLOAD_ORGANIZATION`
- `TRUST_ONBOARD_PAYLOAD_DESCRIPTION`

For upgrades, unattended mode uses the same `TRUST_ONBOARD_UNATTENDED=1` flag plus `TRUST_ONBOARD_VERSION` when you want to pin a release.

For uninstalls, unattended mode keeps config, assets, user, and group by default. To remove them as well, set one or more of:

- `TRUST_ONBOARD_REMOVE_CONFIG=1`
- `TRUST_ONBOARD_REMOVE_ASSETS=1`
- `TRUST_ONBOARD_REMOVE_USER=1`
- `TRUST_ONBOARD_REMOVE_GROUP=1`

Examples:

```bash
TRUST_ONBOARD_UNATTENDED=1 TRUST_ONBOARD_VERSION=v0.1.0 ./scripts/upgrade.sh

TRUST_ONBOARD_UNATTENDED=1 \
TRUST_ONBOARD_REMOVE_CONFIG=1 \
TRUST_ONBOARD_REMOVE_ASSETS=1 \
./scripts/uninstall.sh
```

## Upgrade behavior

The upgrade script:

- downloads the requested release binary
- verifies checksums
- stops the service when `systemd` is available
- replaces the installed binary
- validates the existing config
- starts the service again

## Smoke test behavior

The smoke-test script:

- checks `/healthz`
- fetches the landing page
- confirms the expected fingerprint is present
- downloads the root certificate, iOS profile, and Android certificate

By default it tests `http://127.0.0.1:8080`. To target a different URL:

```bash
./scripts/smoke-test.sh https://trust.example.internal
TRUST_ONBOARD_BASE_URL=https://trust.example.internal ./scripts/smoke-test.sh
```

## Uninstall behavior

The uninstall script:

- stops and disables the service when present
- removes the systemd unit and installed binary
- optionally removes config, assets, service user, and service group

It defaults to keeping config and assets unless you explicitly confirm removal.

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
