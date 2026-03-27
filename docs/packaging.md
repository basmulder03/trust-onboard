# Packaging And Releases

## deb and rpm packages

`nfpm` packaging is included.

Install `nfpm`:

```bash
go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest
```

Build packages:

```bash
make package-deb VERSION=1.0.0
make package-rpm VERSION=1.0.0
make package-deb-arm64 VERSION=1.0.0
make package-rpm-arm64 VERSION=1.0.0
```

Check the derived release version:

```bash
make release-version
```

## Release artifacts

The automated release pipeline builds:

- Linux amd64 and arm64 binaries
- macOS amd64 and arm64 binaries
- Windows amd64 binary
- Linux amd64 and arm64 `deb` packages
- Linux amd64 and arm64 `rpm` packages
- `sha256sums.txt`

Published release artifacts allow `scripts/install.sh` to install directly without requiring a local build toolchain on the target machine.
