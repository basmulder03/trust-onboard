# Packaging notes

This directory provides Linux packaging inputs for `deb` and `rpm` builds.

- `trust-onboard.service` installs to `/usr/lib/systemd/system/`
- `nfpm.yaml` maps the binary, config, unit, and public assets into the target filesystem
- `postinstall.sh` creates the service account and asset directories on first install
- `preremove.sh` stops and disables the service during package removal

Example packaging commands:

```bash
go build -trimpath -ldflags="-s -w" -o ./bin/trust-onboard ./cmd/trust-onboard
VERSION=1.0.0 nfpm package --packager deb --target ./dist/trust-onboard_1.0.0_linux_amd64.deb --config ./packaging/nfpm.yaml
VERSION=1.0.0 nfpm package --packager rpm --target ./dist/trust-onboard-1.0.0-1.x86_64.rpm --config ./packaging/nfpm.yaml
```
