#!/usr/bin/env sh
set -eu

APP_NAME=trust-onboard
INSTALL_BIN=/usr/local/bin/trust-onboard
INSTALL_CONFIG=/etc/trust-onboard/config.yaml
DEFAULT_BASE_URL=http://127.0.0.1:8080
TMPDIR=${TMPDIR:-/tmp}

TMP_HOME=
TMP_IOS=
TMP_ANDROID=
TMP_ROOT=

usage() {
    cat <<'EOF'
Usage: ./scripts/smoke-test.sh [base-url]

Runs a simple post-install smoke test against a running trust-onboard service.

Arguments:
  base-url                     Optional base URL, default: http://127.0.0.1:8080

Environment variables:
  TRUST_ONBOARD_BASE_URL       Base URL when no argument is provided
EOF
}

case ${1:-} in
    -h|--help)
        usage
        exit 0
        ;;
esac

log() {
    printf '[smoke-test] %s\n' "$*"
}

warn() {
    printf '[smoke-test] warning: %s\n' "$*" >&2
}

die() {
    printf '[smoke-test] error: %s\n' "$*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

fetch_to_file() {
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

cleanup() {
    [ -n "$TMP_HOME" ] && rm -f "$TMP_HOME"
    [ -n "$TMP_IOS" ] && rm -f "$TMP_IOS"
    [ -n "$TMP_ANDROID" ] && rm -f "$TMP_ANDROID"
    [ -n "$TMP_ROOT" ] && rm -f "$TMP_ROOT"
}
trap cleanup EXIT INT TERM

BASE_URL=${1:-${TRUST_ONBOARD_BASE_URL:-$DEFAULT_BASE_URL}}

[ -x "$INSTALL_BIN" ] || die "installed binary not found at $INSTALL_BIN"
[ -f "$INSTALL_CONFIG" ] || die "config file not found at $INSTALL_CONFIG"

TMP_HOME=$TMPDIR/$APP_NAME-home-$$.html
TMP_IOS=$TMPDIR/$APP_NAME-ios-$$.mobileconfig
TMP_ANDROID=$TMPDIR/$APP_NAME-android-$$.cer
TMP_ROOT=$TMPDIR/$APP_NAME-root-$$.crt

EXPECTED_FP=$($INSTALL_BIN print-fingerprint --config "$INSTALL_CONFIG")
[ -n "$EXPECTED_FP" ] || die "could not read expected fingerprint"

log "checking health endpoint"
health_body=$(if command_exists curl; then curl -fsSL "$BASE_URL/healthz"; else wget -qO- "$BASE_URL/healthz"; fi)
[ "$health_body" = "ok" ] || [ "$health_body" = "ok
" ] || die "unexpected /healthz response"

log "fetching landing page"
fetch_to_file "$BASE_URL/" "$TMP_HOME"
grep -F "$EXPECTED_FP" "$TMP_HOME" >/dev/null 2>&1 || die "landing page does not contain expected fingerprint"

log "fetching root certificate"
fetch_to_file "$BASE_URL/download/root.crt" "$TMP_ROOT"
[ -s "$TMP_ROOT" ] || die "root certificate download is empty"

log "fetching iOS profile"
fetch_to_file "$BASE_URL/download/ios.mobileconfig" "$TMP_IOS"
[ -s "$TMP_IOS" ] || die "iOS profile download is empty"
grep -F "PayloadType" "$TMP_IOS" >/dev/null 2>&1 || die "iOS profile does not look valid"

log "fetching Android certificate"
fetch_to_file "$BASE_URL/download/android.cer" "$TMP_ANDROID"
[ -s "$TMP_ANDROID" ] || die "Android certificate download is empty"

log "smoke test passed for $BASE_URL"
