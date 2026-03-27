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

## GitHub release workflow

The workflow in `.github/workflows/release.yml` builds:

- Linux amd64 and arm64 binaries
- macOS amd64 and arm64 binaries
- Windows amd64 binary
- Linux amd64 and arm64 `deb` packages
- Linux amd64 and arm64 `rpm` packages
- `sha256sums.txt`

Trigger a release by pushing a tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Public releases also allow `scripts/install.sh` to install directly from GitHub without requiring a local build toolchain on the target machine.

## One-time GitHub bootstrap

To create the repository with `gh`:

```bash
git init
git add .
git commit -m "Initial trust-onboard import"
gh repo create basmulder03/trust-onboard --public --source=. --remote=origin --push
```
