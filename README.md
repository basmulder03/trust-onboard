# trust-onboard

`trust-onboard` is a production-oriented single Go binary for distributing public `step-ca` trust material. It serves a small onboarding site, generates install artifacts on demand, and stays intentionally narrow: no CA admin controls, no certificate issuance, no config mutation, no database, and no runtime dependency on GitHub.

## Project purpose

This project helps operators publish the public root certificate of an internal `step-ca` deployment so devices can trust local HTTPS services. It is designed for homelabs and small private infrastructure where you want a simple, auditable onboarding portal that can run directly on bare metal or under `systemd`.

## Architecture summary

- Single statically-buildable Go binary with stdlib-first implementation.
- Embedded HTML and CSS using `embed`; no frontend framework and no Node toolchain.
- Root certificate loaded from disk at startup and validated before serving.
- Dynamic generation of `.mobileconfig`, Android `.cer`, fingerprint, and QR codes.
- HTTP server with graceful shutdown, timeouts, stdout/stderr logging, and `/healthz`.
- No database, no background workers, no runtime shelling out, and no runtime GitHub integration.

## Why single Go binary

- Easier deployment to bare metal, small VMs, and minimal containers.
- Auditable runtime surface with fewer moving parts.
- Straightforward cross-compilation for Linux, macOS, and Windows.
- Simple `systemd` operation with one executable and one config file.

## Why on-demand generation

- The root certificate remains the source of truth on disk.
- Generated assets always match the configured CA metadata and fingerprint.
- Operators can either serve artifacts live or export them with `generate` for manual distribution.

## Why systemd-friendly design

- Foreground process with no daemon mode.
- All logs go to stdout/stderr for journald collection.
- Startup validation fails fast with a non-zero exit code.
- Graceful `SIGINT` and `SIGTERM` handling.
- Suitable for an unprivileged service account with read-only access to public assets.

## Repository layout

- `cmd/trust-onboard/main.go` - CLI entrypoint and command wiring.
- `internal/config/` - config loading, defaults, and validation.
- `internal/cert/` - certificate parsing, fingerprinting, and artifact bundling.
- `internal/mobileconfig/` - iOS mobileconfig generation.
- `internal/qr/` - QR code generation wrapper.
- `internal/templates/` - embedded template and static asset loader.
- `internal/server/` - HTTP handlers.
- `web/` - embedded templates and CSS.
- `assets/` - example asset layout.
- `packaging/trust-onboard.service` - sample `systemd` unit.
- `.github/workflows/release.yml` - tag-driven GitHub release workflow.

## Commands

- `serve` - starts the onboarding HTTP server.
- `generate` - writes generated artifacts to disk.
- `validate` - validates config, files, and generated outputs without serving.
- `print-fingerprint` - prints the effective SHA-256 root fingerprint.

## Config reference

Example: `config.example.yaml`

```yaml
site_title: string
organization_name: string
listen_address: ":8080"
base_url: "https://trust.example.internal"
displayed_ca_name: string
root_ca_cert_path: "assets/root_ca.crt"
root_ca_locations:
  source_path: "assets/root_ca.crt"
  linux_paths: []
  macos_stores: []
  windows: []
  android: []
  ios: []
  manual: []
android:
  cert_format: pem # pem or der
ios:
  payload_identifier: string
  payload_display_name: string
  payload_organization: string
  payload_description: string
fingerprint:
  auto_calculate: true
  override: ""
support_text: string
support_url: "https://help.example.internal"
logo_path: "assets/logo.svg"
internal_domains: []
external_domains: []
footer_text: string
advanced_section_enabled: true
```

Notes:

- `base_url` must be the externally reachable scheme and hostname used by clients and QR codes.
- `root_ca_cert_path` points to the public root certificate only.
- `root_ca_locations.source_path` is the effective source path used by the app and shown in the advanced/manual section.
- `root_ca_locations.*` lets you customize the platform-specific root CA destination hints shown in the onboarding UI.
- `fingerprint.auto_calculate` computes the SHA-256 fingerprint from the certificate DER.
- `fingerprint.override` lets you pin a displayed value if you need to match an external documented fingerprint.
- `android.cert_format` controls whether `/download/android.cer` serves PEM or DER bytes.

## How to place the root cert

Place the public root CA certificate on disk, for example:

- `/var/lib/trust-onboard/assets/root_ca.crt`

The file may be PEM or DER encoded. `trust-onboard` parses either and never needs the private key, ACME material, provisioners, or `step-ca` admin credentials.

If you want the UI to show different destination paths or certificate-store locations for each platform, adjust `root_ca_locations` in your config.

## How fingerprint works

- By default, the app computes the SHA-256 fingerprint of the certificate DER bytes.
- The value is shown on the landing page, returned by `print-fingerprint`, and written by `generate` to `fingerprint.txt`.
- If `fingerprint.override` is set, the override is displayed and printed instead.

## How mobileconfig generation works

- The iOS profile is generated in memory from config metadata and the public root certificate.
- The profile installs a `com.apple.security.root` payload.
- No Apple-specific signing is performed; this is intended for internal onboarding of a public root cert.
- Users may still need to enable full trust in iOS after profile installation depending on platform behavior.

## How Android cert generation works

- Android download is exposed as `/download/android.cer`.
- Set `android.cert_format: pem` for a PEM-wrapped certificate or `der` for raw DER bytes.
- Android certificate import behavior varies by version, OEM, work profile, and whether apps trust the user or managed store.

## HTTP endpoints

- `/` - onboarding landing page.
- `/healthz` - readiness/liveness endpoint.
- `/download/root.crt` - root certificate.
- `/download/ios.mobileconfig` - iOS profile.
- `/download/android.cer` - Android certificate.
- `/qr/home.png` - QR for landing page.
- `/qr/ios.png` - QR for iOS profile URL.
- `/qr/android.png` - QR for Android certificate URL.

## Local run

1. Put a real public root certificate at `assets/root_ca.crt` or change the config path.
2. Optionally place a logo at `assets/logo.svg`.
3. Run validation.
4. Start the server.

```bash
go run ./cmd/trust-onboard validate --config config.example.yaml
go run ./cmd/trust-onboard serve --config config.example.yaml
```

## Build

```bash
go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard ./cmd/trust-onboard
```

Or with the Makefile:

```bash
make build
```

## Cross-compile

Linux amd64:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-linux-amd64 ./cmd/trust-onboard
```

Linux arm64:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-linux-arm64 ./cmd/trust-onboard
```

macOS arm64:

```bash
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-darwin-arm64 ./cmd/trust-onboard
```

Windows amd64:

```bash
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard-windows-amd64.exe ./cmd/trust-onboard
```

## Generate artifacts manually

```bash
go run ./cmd/trust-onboard generate --config config.example.yaml --output-dir ./dist
```

Files written:

- `root_ca.crt`
- `trust-onboard.mobileconfig`
- `android-root.cer`
- `home-qr.png`
- `ios-qr.png`
- `android-qr.png`
- `fingerprint.txt`

## Package as deb or rpm

Using `nfpm`:

```bash
go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest
go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard ./cmd/trust-onboard
VERSION=1.0.0 nfpm package --packager deb --target ./dist/trust-onboard_1.0.0_linux_amd64.deb --config ./packaging/nfpm.yaml
VERSION=1.0.0 nfpm package --packager rpm --target ./dist/trust-onboard-1.0.0-1.x86_64.rpm --config ./packaging/nfpm.yaml
```

Or with the Makefile:

```bash
make package-deb VERSION=1.0.0
make package-rpm VERSION=1.0.0
make package-deb-arm64 VERSION=1.0.0
make package-rpm-arm64 VERSION=1.0.0
```

The package layout targets:

- `/usr/local/bin/trust-onboard`
- `/etc/trust-onboard/config.yaml`
- `/usr/lib/systemd/system/trust-onboard.service`
- `/var/lib/trust-onboard/assets/root_ca.crt`
- `/var/lib/trust-onboard/assets/logo.svg`

The default `VERSION` in the Makefile is derived from `git describe --tags --always --dirty`. To inspect it:

```bash
make release-version
```

## Systemd deployment

Recommended paths:

- Binary: `/usr/local/bin/trust-onboard`
- Config: `/etc/trust-onboard/config.yaml`
- Assets: `/var/lib/trust-onboard/assets/`

Create service account and directories:

```bash
sudo groupadd --system trust-onboard
sudo useradd --system --gid trust-onboard --home /var/lib/trust-onboard --shell /usr/sbin/nologin trust-onboard
sudo install -d -o root -g root -m 0755 /etc/trust-onboard
sudo install -d -o trust-onboard -g trust-onboard -m 0750 /var/lib/trust-onboard
sudo install -d -o trust-onboard -g trust-onboard -m 0750 /var/lib/trust-onboard/assets
```

Install files:

```bash
sudo install -o root -g root -m 0755 ./bin/trust-onboard /usr/local/bin/trust-onboard
sudo install -o root -g root -m 0644 ./config.example.yaml /etc/trust-onboard/config.yaml
sudo install -o trust-onboard -g trust-onboard -m 0644 ./assets/root_ca.crt /var/lib/trust-onboard/assets/root_ca.crt
sudo install -o trust-onboard -g trust-onboard -m 0644 ./assets/logo.svg /var/lib/trust-onboard/assets/logo.svg
sudo install -o root -g root -m 0644 ./packaging/trust-onboard.service /etc/systemd/system/trust-onboard.service
```

Permissions guidance:

- Binary can be world-executable.
- Config should usually be `0644` or `0640` depending on your environment.
- Asset files should be readable by the `trust-onboard` service account.
- Only public certificates and public branding assets belong in the asset directory.

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now trust-onboard.service
sudo systemctl status trust-onboard.service
```

## Reverse proxy examples

### nginx

```nginx
server {
    listen 443 ssl http2;
    server_name trust.example.internal;

    ssl_certificate /etc/letsencrypt/live/trust.example.internal/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/trust.example.internal/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

### Caddy

```caddyfile
trust.example.internal {
    reverse_proxy 127.0.0.1:8080
}
```

### Traefik dynamic config

```yaml
http:
  routers:
    trust-onboard:
      rule: Host(`trust.example.internal`)
      service: trust-onboard
      tls: {}
  services:
    trust-onboard:
      loadBalancer:
        servers:
          - url: http://127.0.0.1:8080
```

## Android caveats

- Some Android versions require manual confirmation for user CA installs.
- Managed devices may need MDM deployment instead of user-driven import.
- Certain applications pin certificates or ignore the user trust store.
- If you need app-specific trust, solve that in the app or device management layer, not in this project.

## Security model

- Public trust distribution only.
- No private keys, provisioners, ACME account keys, or `step-ca` admin operations.
- No issuance endpoints and no editing of `step-ca` configuration.
- Treat the served certificate and logo as public artifacts.
- Run as an unprivileged user behind a reverse proxy or on a high port.
- Prefer HTTPS at the edge so QR codes resolve to a trusted URL.

## One-time GitHub bootstrap with gh

You can initialize a new source repository once and push the project with `gh`. This is not used at runtime.

```bash
git init
git add .
git commit -m "Initial trust-onboard import"
gh repo create trust-onboard --private --source=. --remote=origin --push
```

If you want to namespace it under your account or org explicitly:

```bash
gh repo create your-org-or-user/trust-onboard --private --source=. --remote=origin --push
```

## GitHub releases

The workflow in `.github/workflows/release.yml` builds tagged releases for Linux, macOS, and Windows, creates SHA-256 checksums, and publishes Linux `deb` and `rpm` packages.

Create a release tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Artifacts produced by the workflow:

- `trust-onboard-linux-amd64`
- `trust-onboard-linux-arm64`
- `trust-onboard-darwin-amd64`
- `trust-onboard-darwin-arm64`
- `trust-onboard-windows-amd64.exe`
- `trust-onboard_<version>_linux_amd64.deb`
- `trust-onboard_<version>_linux_arm64.deb`
- `trust-onboard-<version>-1.x86_64.rpm`
- `trust-onboard-<version>-1.aarch64.rpm`
- `sha256sums.txt`

## Config migration note

Older configs can continue using `root_ca_cert_path`. Newer configs should set both `root_ca_cert_path` and `root_ca_locations.source_path` to the same file, or set only `root_ca_locations.source_path` if you are standardizing on the newer field in your own templates.

Behavior:

- `root_ca_locations.source_path` takes precedence as the effective certificate source path.
- `root_ca_cert_path` is still accepted for compatibility and remains documented as the simple top-level path.
- If `root_ca_locations.source_path` is omitted, it defaults to `root_ca_cert_path`.

## Manual operator steps that remain

- Place the real root CA certificate on disk.
- Set `base_url` to the public onboarding URL used by devices.
- Tune support text and domain lists for your environment.
- Put the service behind TLS with nginx, Caddy, Traefik, or another reverse proxy.
- Test iOS and Android imports on the platform versions you actually support.
