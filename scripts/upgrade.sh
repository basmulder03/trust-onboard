#!/usr/bin/env sh
set -eu

APP_NAME=trust-onboard
INSTALL_BIN=/usr/local/bin/trust-onboard
INSTALL_CONFIG=/etc/trust-onboard/config.yaml
SERVICE_NAME=trust-onboard.service
RELEASE_REPO=basmulder03/trust-onboard
DEFAULT_RELEASE=latest
TMPDIR=${TMPDIR:-/tmp}

DOWNLOAD_BIN=
CHECKSUM_FILE=

log() {
    printf '[upgrade] %s\n' "$*"
}

warn() {
    printf '[upgrade] warning: %s\n' "$*" >&2
}

die() {
    printf '[upgrade] error: %s\n' "$*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_root() {
    [ "$(id -u)" -eq 0 ]
}

run_privileged() {
    if is_root; then
        "$@"
    elif command_exists sudo; then
        sudo "$@"
    else
        die "this action requires root privileges; rerun as root or install sudo"
    fi
}

download_file() {
    url=$1
    destination=$2
    if command_exists curl; then
        curl -fsSL "$url" -o "$destination"
    elif command_exists wget; then
        wget -qO "$destination" "$url"
    else
        die "curl or wget is required"
    fi
}

detect_asset_name() {
    uname_s=$(uname -s 2>/dev/null || printf '')
    uname_m=$(uname -m 2>/dev/null || printf '')

    case $uname_s in
        Linux) os_part=linux ;;
        *) die "unsupported OS for upgrade: $uname_s" ;;
    esac

    case $uname_m in
        x86_64|amd64) arch_part=amd64 ;;
        aarch64|arm64) arch_part=arm64 ;;
        *) die "unsupported architecture for upgrade: $uname_m" ;;
    esac

    printf '%s-%s-%s' "$APP_NAME" "$os_part" "$arch_part"
}

verify_checksum() {
    asset_name=$1
    if command_exists sha256sum; then
        expected=$(awk -v name="$asset_name" '$2 == name { print $1 }' "$CHECKSUM_FILE")
        actual=$(sha256sum "$DOWNLOAD_BIN" | awk '{print $1}')
    elif command_exists shasum; then
        expected=$(awk -v name="$asset_name" '$2 == name { print $1 }' "$CHECKSUM_FILE")
        actual=$(shasum -a 256 "$DOWNLOAD_BIN" | awk '{print $1}')
    else
        warn "sha256sum/shasum not found; skipping checksum verification"
        return 0
    fi

    [ -n "$expected" ] || die "could not find checksum entry for $asset_name"
    [ "$expected" = "$actual" ] || die "checksum verification failed for $asset_name"
}

cleanup() {
    [ -n "$DOWNLOAD_BIN" ] && rm -f "$DOWNLOAD_BIN"
    [ -n "$CHECKSUM_FILE" ] && rm -f "$CHECKSUM_FILE"
}
trap cleanup EXIT INT TERM

[ -f "$INSTALL_CONFIG" ] || warn "config file not found at $INSTALL_CONFIG"
[ -x "$INSTALL_BIN" ] || warn "existing binary not found at $INSTALL_BIN"

asset_name=$(detect_asset_name)
version=${TRUST_ONBOARD_VERSION:-$DEFAULT_RELEASE}
DOWNLOAD_BIN=$TMPDIR/$asset_name-upgrade-$$
CHECKSUM_FILE=$TMPDIR/$APP_NAME-upgrade-sha256-$$.txt

if [ "$version" = "latest" ]; then
    binary_url="https://github.com/$RELEASE_REPO/releases/latest/download/$asset_name"
    checksum_url="https://github.com/$RELEASE_REPO/releases/latest/download/sha256sums.txt"
else
    binary_url="https://github.com/$RELEASE_REPO/releases/download/$version/$asset_name"
    checksum_url="https://github.com/$RELEASE_REPO/releases/download/$version/sha256sums.txt"
fi

log "downloading $asset_name ($version)"
download_file "$binary_url" "$DOWNLOAD_BIN"
download_file "$checksum_url" "$CHECKSUM_FILE"
verify_checksum "$asset_name"
chmod 0755 "$DOWNLOAD_BIN"

if command_exists systemctl && systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
    log "stopping $SERVICE_NAME"
    run_privileged systemctl stop "$SERVICE_NAME"
fi

log "installing upgraded binary"
run_privileged install -o root -g root -m 0755 "$DOWNLOAD_BIN" "$INSTALL_BIN"

log "validating installed binary"
run_privileged "$INSTALL_BIN" validate --config "$INSTALL_CONFIG"

if command_exists systemctl && systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
    log "starting $SERVICE_NAME"
    run_privileged systemctl start "$SERVICE_NAME"
    run_privileged systemctl status --no-pager "$SERVICE_NAME" || true
fi

log "upgrade complete"
