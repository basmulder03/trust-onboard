#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." 2>/dev/null && pwd || pwd)

APP_NAME=trust-onboard
INSTALL_USER=trust-onboard
INSTALL_GROUP=trust-onboard
INSTALL_BIN=/usr/local/bin/trust-onboard
INSTALL_CONFIG_DIR=/etc/trust-onboard
INSTALL_CONFIG=$INSTALL_CONFIG_DIR/config.yaml
INSTALL_ASSET_DIR=/var/lib/trust-onboard/assets
INSTALL_WORK_DIR=/var/lib/trust-onboard
INSTALL_SERVICE=/etc/systemd/system/trust-onboard.service
RELEASE_REPO=basmulder03/trust-onboard
DEFAULT_RELEASE=latest
TMPDIR=${TMPDIR:-/tmp}
UNATTENDED=${TRUST_ONBOARD_UNATTENDED:-0}

DOWNLOAD_BIN=
CONFIG_TMP=
SERVICE_TMP=
OS_ID=unknown
OS_LIKE=

usage() {
    cat <<'EOF'
Usage: ./scripts/install.sh [--help]

Installs trust-onboard from a published release, writes config and assets,
and optionally enables the systemd service.

Environment variables:
  TRUST_ONBOARD_UNATTENDED=1            Skip prompts and use defaults/env vars
  TRUST_ONBOARD_VERSION                 Release tag to install, default: latest
  TRUST_ONBOARD_ROOT_CERT_PATH          Public root certificate path
  TRUST_ONBOARD_LOGO_PATH               Optional logo path
  TRUST_ONBOARD_SITE_TITLE              Site title
  TRUST_ONBOARD_ORGANIZATION_NAME       Organization or homelab name
  TRUST_ONBOARD_LISTEN_ADDRESS          Listen address, default: :8080
  TRUST_ONBOARD_BASE_URL                Public base URL
  TRUST_ONBOARD_DISPLAYED_CA_NAME       Displayed CA name
  TRUST_ONBOARD_SUPPORT_TEXT            Support text
  TRUST_ONBOARD_SUPPORT_URL             Support URL
  TRUST_ONBOARD_INTERNAL_DOMAINS        Comma-separated internal domains
  TRUST_ONBOARD_EXTERNAL_DOMAINS        Comma-separated external domains
  TRUST_ONBOARD_ANDROID_FORMAT          pem or der
  TRUST_ONBOARD_ADVANCED_ENABLED        true or false
  TRUST_ONBOARD_PAYLOAD_IDENTIFIER      iOS payload identifier
  TRUST_ONBOARD_PAYLOAD_DISPLAY_NAME    iOS payload display name
  TRUST_ONBOARD_PAYLOAD_ORGANIZATION    iOS payload organization
  TRUST_ONBOARD_PAYLOAD_DESCRIPTION     iOS payload description
EOF
}

case ${1:-} in
    -h|--help)
        usage
        exit 0
        ;;
esac

log() {
    printf '[install] %s\n' "$*"
}

warn() {
    printf '[install] warning: %s\n' "$*" >&2
}

die() {
    printf '[install] error: %s\n' "$*" >&2
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

detect_os() {
    if [ -r /etc/os-release ]; then
        OS_ID=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
        OS_LIKE=$(awk -F= '/^ID_LIKE=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    fi
}

prompt_default() {
    prompt_text=$1
    default_value=$2
    if [ "$UNATTENDED" = "1" ]; then
        printf '%s' "$default_value"
        return
    fi
    printf '%s [%s]: ' "$prompt_text" "$default_value" >&2
    IFS= read -r reply || true
    if [ -z "$reply" ]; then
        printf '%s' "$default_value"
    else
        printf '%s' "$reply"
    fi
}

prompt_optional() {
    prompt_text=$1
    default_value=$2
    if [ "$UNATTENDED" = "1" ]; then
        printf '%s' "$default_value"
        return
    fi
    printf '%s [%s]: ' "$prompt_text" "$default_value" >&2
    IFS= read -r reply || true
    if [ -z "$reply" ]; then
        printf '%s' "$default_value"
    else
        printf '%s' "$reply"
    fi
}

prompt_yes_no() {
    prompt_text=$1
    default_value=$2
    if [ "$UNATTENDED" = "1" ]; then
        case $default_value in
            y|Y|yes|YES) return 0 ;;
            *) return 1 ;;
        esac
    fi
    printf '%s [%s]: ' "$prompt_text" "$default_value" >&2
    IFS= read -r reply || true
    case ${reply:-$default_value} in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO) return 1 ;;
        *) return 1 ;;
    esac
}

yaml_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_scalar() {
    key=$1
    value=$2
    printf '%s: "%s"\n' "$key" "$(yaml_escape "$value")"
}

write_list() {
    indent=$1
    key=$2
    csv=$3
    if [ -z "$csv" ]; then
        printf '%s%s: []\n' "$indent" "$key"
        return
    fi
    printf '%s%s:\n' "$indent" "$key"
    OLDIFS=$IFS
    IFS=,
    set -- $csv
    IFS=$OLDIFS
    for item in "$@"; do
        trimmed=$(printf '%s' "$item" | sed 's/^ *//; s/ *$//')
        [ -n "$trimmed" ] || continue
        printf '%s  - "%s"\n' "$indent" "$(yaml_escape "$trimmed")"
    done
}

find_first_file() {
    for candidate in "$@"; do
        if [ -f "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

default_hostname() {
    if command_exists hostname; then
        hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'trust-onboard'
    else
        printf 'trust-onboard'
    fi
}

title_case() {
    printf '%s' "$1" | tr '.-_' '   ' | awk '{for (i = 1; i <= NF; i++) { $i = toupper(substr($i,1,1)) tolower(substr($i,2)) } print}'
}

ensure_download_tools() {
    if command_exists curl || command_exists wget; then
        return 0
    fi

    warn "curl or wget is required to download release assets"
    if ! prompt_yes_no "Install curl automatically if supported?" "y"; then
        die "cannot continue without curl or wget"
    fi

    if command_exists apt-get; then
        run_privileged apt-get update
        run_privileged apt-get install -y curl ca-certificates
    elif command_exists dnf; then
        run_privileged dnf install -y curl ca-certificates
    elif command_exists yum; then
        run_privileged yum install -y curl ca-certificates
    elif command_exists apk; then
        run_privileged apk add curl ca-certificates
    elif command_exists zypper; then
        run_privileged zypper --non-interactive install curl ca-certificates
    else
        die "unsupported package manager for automatic curl installation"
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
        *) die "unsupported OS for installer: $uname_s" ;;
    esac

    case $uname_m in
        x86_64|amd64) arch_part=amd64 ;;
        aarch64|arm64) arch_part=arm64 ;;
        *) die "unsupported architecture for installer: $uname_m" ;;
    esac

    printf '%s-%s-%s' "$APP_NAME" "$os_part" "$arch_part"
}

verify_checksum() {
    checksum_file=$1
    binary_file=$2
    asset_name=$3

    if command_exists sha256sum; then
        expected=$(awk -v name="$asset_name" '$2 == name { print $1 }' "$checksum_file")
        actual=$(sha256sum "$binary_file" | awk '{print $1}')
    elif command_exists shasum; then
        expected=$(awk -v name="$asset_name" '$2 == name { print $1 }' "$checksum_file")
        actual=$(shasum -a 256 "$binary_file" | awk '{print $1}')
    else
        warn "sha256sum/shasum not found; skipping checksum verification"
        return 0
    fi

    [ -n "$expected" ] || die "could not find checksum entry for $asset_name"
    [ "$expected" = "$actual" ] || die "checksum verification failed for $asset_name"
}

prepare_binary() {
    ensure_download_tools

    version=${TRUST_ONBOARD_VERSION:-$DEFAULT_RELEASE}
    asset_name=$(detect_asset_name)
    DOWNLOAD_BIN=$TMPDIR/$asset_name-$$
    checksum_file=$TMPDIR/$APP_NAME-sha256-$$.txt

    if [ "$version" = "latest" ]; then
        binary_url="https://github.com/$RELEASE_REPO/releases/latest/download/$asset_name"
        checksum_url="https://github.com/$RELEASE_REPO/releases/latest/download/sha256sums.txt"
    else
        binary_url="https://github.com/$RELEASE_REPO/releases/download/$version/$asset_name"
        checksum_url="https://github.com/$RELEASE_REPO/releases/download/$version/sha256sums.txt"
    fi

    log "downloading $asset_name from GitHub releases ($version)"
    download_file "$binary_url" "$DOWNLOAD_BIN"
    download_file "$checksum_url" "$checksum_file"
    verify_checksum "$checksum_file" "$DOWNLOAD_BIN" "$asset_name"
    chmod 0755 "$DOWNLOAD_BIN"
    rm -f "$checksum_file"
}

ensure_service_account() {
    if getent group "$INSTALL_GROUP" >/dev/null 2>&1; then
        :
    elif command_exists groupadd; then
        run_privileged groupadd --system "$INSTALL_GROUP"
    elif command_exists addgroup; then
        run_privileged addgroup --system "$INSTALL_GROUP"
    else
        warn "could not create group $INSTALL_GROUP automatically"
    fi

    if id "$INSTALL_USER" >/dev/null 2>&1; then
        :
    elif command_exists useradd; then
        run_privileged useradd --system --gid "$INSTALL_GROUP" --home "$INSTALL_WORK_DIR" --shell /usr/sbin/nologin "$INSTALL_USER"
    elif command_exists adduser; then
        run_privileged adduser --system --ingroup "$INSTALL_GROUP" --home "$INSTALL_WORK_DIR" "$INSTALL_USER"
    else
        warn "could not create user $INSTALL_USER automatically"
    fi
}

write_service_unit() {
    SERVICE_TMP=$TMPDIR/$APP_NAME-service-$$.service
    cat >"$SERVICE_TMP" <<EOF
[Unit]
Description=trust-onboard step-ca trust onboarding portal
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$INSTALL_USER
Group=$INSTALL_GROUP
WorkingDirectory=$INSTALL_WORK_DIR
ExecStart=$INSTALL_BIN serve --config $INSTALL_CONFIG
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
ReadWritePaths=$INSTALL_WORK_DIR
AmbientCapabilities=
CapabilityBoundingSet=
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF
}

install_files() {
    source_cert=$1
    source_logo=$2
    config_tmp=$3

    run_privileged install -d -o root -g root -m 0755 "$INSTALL_CONFIG_DIR"
    run_privileged install -d -m 0755 "$INSTALL_WORK_DIR"
    run_privileged install -d -m 0755 "$INSTALL_ASSET_DIR"

    ensure_service_account

    if id "$INSTALL_USER" >/dev/null 2>&1 && getent group "$INSTALL_GROUP" >/dev/null 2>&1; then
        run_privileged chown "$INSTALL_USER:$INSTALL_GROUP" "$INSTALL_WORK_DIR" "$INSTALL_ASSET_DIR"
    fi

    write_service_unit
    run_privileged install -o root -g root -m 0755 "$DOWNLOAD_BIN" "$INSTALL_BIN"
    run_privileged install -o root -g root -m 0644 "$config_tmp" "$INSTALL_CONFIG"
    run_privileged install -o root -g root -m 0644 "$SERVICE_TMP" "$INSTALL_SERVICE"
    run_privileged install -o root -g root -m 0644 "$source_cert" "$INSTALL_ASSET_DIR/root_ca.crt"

    if [ -n "$source_logo" ] && [ -f "$source_logo" ]; then
        logo_base=$(basename "$source_logo")
        run_privileged install -o root -g root -m 0644 "$source_logo" "$INSTALL_ASSET_DIR/$logo_base"
    fi

    if id "$INSTALL_USER" >/dev/null 2>&1 && getent group "$INSTALL_GROUP" >/dev/null 2>&1; then
        run_privileged chown "$INSTALL_USER:$INSTALL_GROUP" "$INSTALL_ASSET_DIR/root_ca.crt"
        if [ -n "$source_logo" ] && [ -f "$source_logo" ]; then
            logo_base=$(basename "$source_logo")
            run_privileged chown "$INSTALL_USER:$INSTALL_GROUP" "$INSTALL_ASSET_DIR/$logo_base"
        fi
    fi
}

maybe_enable_service() {
    if ! command_exists systemctl; then
        warn "systemctl not found; skipping service enablement"
        return
    fi

    run_privileged systemctl daemon-reload
    if prompt_yes_no "Enable and start trust-onboard.service now?" "y"; then
        run_privileged systemctl enable --now trust-onboard.service
        run_privileged systemctl status --no-pager trust-onboard.service || true
    else
        log "service installed but not started"
    fi
}

cleanup() {
    [ -n "$CONFIG_TMP" ] && rm -f "$CONFIG_TMP"
    [ -n "$SERVICE_TMP" ] && rm -f "$SERVICE_TMP"
    [ -n "$DOWNLOAD_BIN" ] && rm -f "$DOWNLOAD_BIN"
}
trap cleanup EXIT INT TERM

detect_os
log "detected OS: $OS_ID ${OS_LIKE:+($OS_LIKE)}"
if [ "$UNATTENDED" = "1" ]; then
    log "running in unattended mode"
fi

prepare_binary

HOST_FQDN=$(default_hostname)
HOST_SHORT=$(printf '%s' "$HOST_FQDN" | cut -d. -f1)
ORG_DEFAULT=$(title_case "$HOST_SHORT")
SITE_TITLE_DEFAULT="$ORG_DEFAULT Trust Onboarding"
BASE_URL_DEFAULT="https://$HOST_FQDN"
DISPLAYED_CA_DEFAULT="$ORG_DEFAULT Root CA"
PAYLOAD_ID_DEFAULT="local.$(printf '%s' "$HOST_SHORT" | tr '[:upper:]' '[:lower:]').trust-onboard.root"
SUPPORT_TEXT_DEFAULT="If trust still fails, remove older copies of the root certificate and verify the fingerprint with your administrator."

ROOT_CERT_CANDIDATE=$(find_first_file \
    "$REPO_ROOT/assets/root_ca.crt" \
    "$INSTALL_ASSET_DIR/root_ca.crt" \
    "/etc/step-ca/certs/root_ca.crt" \
    "/root/.step/certs/root_ca.crt" \
    "/usr/local/share/ca-certificates/root_ca.crt" \
    "/etc/pki/ca-trust/source/anchors/root_ca.crt" \
    2>/dev/null || true)

LOGO_CANDIDATE=$(find_first_file \
    "$REPO_ROOT/assets/logo.svg" \
    "$REPO_ROOT/assets/logo.png" \
    "$INSTALL_ASSET_DIR/logo.svg" \
    "$INSTALL_ASSET_DIR/logo.png" \
    2>/dev/null || true)

[ -n "${TRUST_ONBOARD_ROOT_CERT_PATH:-}" ] && ROOT_CERT_CANDIDATE=$TRUST_ONBOARD_ROOT_CERT_PATH
[ -n "$ROOT_CERT_CANDIDATE" ] || die "could not find a public root certificate; set TRUST_ONBOARD_ROOT_CERT_PATH or place one in ./assets or a common step-ca path"

SITE_TITLE=$(prompt_default "Site title" "${TRUST_ONBOARD_SITE_TITLE:-$SITE_TITLE_DEFAULT}")
ORGANIZATION_NAME=$(prompt_default "Organization or homelab name" "${TRUST_ONBOARD_ORGANIZATION_NAME:-$ORG_DEFAULT}")
LISTEN_ADDRESS=$(prompt_default "Listen address" "${TRUST_ONBOARD_LISTEN_ADDRESS:-:8080}")
BASE_URL=$(prompt_default "Base URL" "${TRUST_ONBOARD_BASE_URL:-$BASE_URL_DEFAULT}")
DISPLAYED_CA_NAME=$(prompt_default "Displayed CA name" "${TRUST_ONBOARD_DISPLAYED_CA_NAME:-$DISPLAYED_CA_DEFAULT}")
SUPPORT_TEXT=$(prompt_optional "Support text" "${TRUST_ONBOARD_SUPPORT_TEXT:-$SUPPORT_TEXT_DEFAULT}")
SUPPORT_URL=$(prompt_optional "Support URL" "${TRUST_ONBOARD_SUPPORT_URL:-}")
INTERNAL_DOMAINS=$(prompt_optional "Internal domains (comma-separated)" "${TRUST_ONBOARD_INTERNAL_DOMAINS:-}")
EXTERNAL_DOMAINS=$(prompt_optional "External domains (comma-separated)" "${TRUST_ONBOARD_EXTERNAL_DOMAINS:-}")
ANDROID_FORMAT=$(prompt_default "Android cert format (pem or der)" "${TRUST_ONBOARD_ANDROID_FORMAT:-pem}")
ADVANCED_ENABLED=$(prompt_default "Enable advanced section (true or false)" "${TRUST_ONBOARD_ADVANCED_ENABLED:-true}")
PAYLOAD_IDENTIFIER=$(prompt_default "iOS payload identifier" "${TRUST_ONBOARD_PAYLOAD_IDENTIFIER:-$PAYLOAD_ID_DEFAULT}")
PAYLOAD_DISPLAY_NAME=$(prompt_default "iOS payload display name" "${TRUST_ONBOARD_PAYLOAD_DISPLAY_NAME:-$DISPLAYED_CA_NAME}")
PAYLOAD_ORGANIZATION=$(prompt_default "iOS payload organization" "${TRUST_ONBOARD_PAYLOAD_ORGANIZATION:-$ORGANIZATION_NAME}")
PAYLOAD_DESCRIPTION=$(prompt_default "iOS payload description" "${TRUST_ONBOARD_PAYLOAD_DESCRIPTION:-Installs the public root certificate used by internal services.}")

if [ -n "${TRUST_ONBOARD_LOGO_PATH:-}" ]; then
    SELECTED_LOGO=$TRUST_ONBOARD_LOGO_PATH
elif [ -n "$LOGO_CANDIDATE" ] && prompt_yes_no "Use detected logo at $LOGO_CANDIDATE?" "y"; then
    SELECTED_LOGO=$LOGO_CANDIDATE
else
    SELECTED_LOGO=
fi

CONFIG_TMP=$TMPDIR/$APP_NAME-config-$$.yaml
{
    write_scalar site_title "$SITE_TITLE"
    write_scalar organization_name "$ORGANIZATION_NAME"
    write_scalar listen_address "$LISTEN_ADDRESS"
    write_scalar base_url "$BASE_URL"
    write_scalar displayed_ca_name "$DISPLAYED_CA_NAME"
    write_scalar root_ca_cert_path "$INSTALL_ASSET_DIR/root_ca.crt"
    printf '\n'
    printf 'root_ca_locations:\n'
    printf '  source_path: "%s"\n' "$(yaml_escape "$INSTALL_ASSET_DIR/root_ca.crt")"
    printf '  linux_paths:\n'
    printf '    - "/usr/local/share/ca-certificates/root_ca.crt"\n'
    printf '    - "/etc/pki/ca-trust/source/anchors/root_ca.crt"\n'
    printf '  macos_stores:\n'
    printf '    - "System keychain"\n'
    printf '    - "login keychain"\n'
    printf '  windows:\n'
    printf '    - "Local Computer > Trusted Root Certification Authorities"\n'
    printf '    - "Current User > Trusted Root Certification Authorities"\n'
    printf '  android:\n'
    printf '    - "Settings > Security > Encryption & credentials > Install a certificate"\n'
    printf '    - "Managed device certificate payload via MDM"\n'
    printf '  ios:\n'
    printf '    - "Downloaded configuration profile in Settings"\n'
    printf '    - "Managed device trust payload via MDM"\n'
    printf '  manual:\n'
    printf '    - "Distribute the PEM root certificate through your configuration management or MDM tooling"\n'
    printf '\n'
    printf 'android:\n'
    printf '  cert_format: "%s"\n' "$(yaml_escape "$ANDROID_FORMAT")"
    printf '\n'
    printf 'ios:\n'
    printf '  payload_identifier: "%s"\n' "$(yaml_escape "$PAYLOAD_IDENTIFIER")"
    printf '  payload_display_name: "%s"\n' "$(yaml_escape "$PAYLOAD_DISPLAY_NAME")"
    printf '  payload_organization: "%s"\n' "$(yaml_escape "$PAYLOAD_ORGANIZATION")"
    printf '  payload_description: "%s"\n' "$(yaml_escape "$PAYLOAD_DESCRIPTION")"
    printf '\n'
    printf 'fingerprint:\n'
    printf '  auto_calculate: true\n'
    printf '  override: ""\n'
    printf '\n'
    write_scalar support_text "$SUPPORT_TEXT"
    write_scalar support_url "$SUPPORT_URL"
    if [ -n "$SELECTED_LOGO" ]; then
        write_scalar logo_path "$INSTALL_ASSET_DIR/$(basename "$SELECTED_LOGO")"
    else
        write_scalar logo_path ""
    fi
    write_list "" internal_domains "$INTERNAL_DOMAINS"
    write_list "" external_domains "$EXTERNAL_DOMAINS"
    write_scalar footer_text "Public trust onboarding for private infrastructure."
    printf 'advanced_section_enabled: %s\n' "$ADVANCED_ENABLED"
} >"$CONFIG_TMP"

log "installing files"
install_files "$ROOT_CERT_CANDIDATE" "$SELECTED_LOGO" "$CONFIG_TMP"

log "validating installed config"
run_privileged "$INSTALL_BIN" validate --config "$INSTALL_CONFIG"

maybe_enable_service

log "installation complete"
log "binary: $INSTALL_BIN"
log "config: $INSTALL_CONFIG"
log "assets: $INSTALL_ASSET_DIR"
