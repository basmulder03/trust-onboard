# trust-onboard

> [!WARNING]
> This project was vibe coded. Treat it as a starting point, review the code, and test it in your own environment before production use.

`trust-onboard` is a single-binary Go service for publishing public `step-ca` trust material.

It serves a small onboarding site, generates iOS and Android trust artifacts on demand, prints the CA fingerprint, and stays intentionally narrow: no issuance, no CA admin actions, no database, and no secret material.

## Quick links

- Docs index: `docs/README.md`
- Configuration: `docs/configuration.md`
- Installation: `docs/installer.md`
- Deployment and `systemd`: `docs/deployment.md`
- Packaging: `docs/packaging.md`
- Development: `docs/development.md`

## Quick start

Validate a config:

```bash
go run ./cmd/trust-onboard validate --config config.example.yaml
```

Run the server:

```bash
go run ./cmd/trust-onboard serve --config config.example.yaml
```

Generate artifacts:

```bash
go run ./cmd/trust-onboard generate --config config.example.yaml --output-dir ./dist
```

## What it does

- Serves an onboarding UI
- Publishes the public root CA certificate
- Generates iOS `.mobileconfig`
- Serves Android `.cer` in PEM or DER
- Displays the SHA-256 fingerprint
- Generates QR codes for onboarding URLs

## What it does not do

- No certificate issuance
- No `step-ca` admin features
- No `step-ca` config editing
- No private keys, provisioners, or CA secrets
- No runtime external platform integration

## Install helper

This project includes an interactive installer for Linux machines and containers:

```bash
./scripts/install.sh
```

It downloads the correct published binary, verifies checksums, and is designed to work on Debian, Ubuntu, and common Proxmox LXC setups, including root-only environments where `sudo` is not installed.
