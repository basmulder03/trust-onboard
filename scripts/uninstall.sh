#!/usr/bin/env sh
set -eu

APP_NAME=trust-onboard
INSTALL_USER=trust-onboard
INSTALL_GROUP=trust-onboard
INSTALL_BIN=/usr/local/bin/trust-onboard
INSTALL_CONFIG_DIR=/etc/trust-onboard
INSTALL_CONFIG=$INSTALL_CONFIG_DIR/config.yaml
INSTALL_ASSET_DIR=/var/lib/trust-onboard/assets
INSTALL_WORK_DIR=/var/lib/trust-onboard
INSTALL_SERVICE=/etc/systemd/system/trust-onboard.service
SERVICE_NAME=trust-onboard.service
UNATTENDED=${TRUST_ONBOARD_UNATTENDED:-0}
REMOVE_CONFIG=${TRUST_ONBOARD_REMOVE_CONFIG:-0}
REMOVE_ASSETS=${TRUST_ONBOARD_REMOVE_ASSETS:-0}
REMOVE_USER=${TRUST_ONBOARD_REMOVE_USER:-0}
REMOVE_GROUP=${TRUST_ONBOARD_REMOVE_GROUP:-0}

usage() {
    cat <<'EOF'
Usage: ./scripts/uninstall.sh [--help]

Removes the installed trust-onboard service and binary. Config, assets, user,
and group are kept unless explicitly removed.

Environment variables:
  TRUST_ONBOARD_UNATTENDED=1   Run without prompts
  TRUST_ONBOARD_REMOVE_CONFIG=1 Remove /etc/trust-onboard/config.yaml
  TRUST_ONBOARD_REMOVE_ASSETS=1 Remove /var/lib/trust-onboard/assets
  TRUST_ONBOARD_REMOVE_USER=1   Remove trust-onboard service user
  TRUST_ONBOARD_REMOVE_GROUP=1  Remove trust-onboard service group
EOF
}

case ${1:-} in
    -h|--help)
        usage
        exit 0
        ;;
esac

log() {
    printf '[uninstall] %s\n' "$*"
}

warn() {
    printf '[uninstall] warning: %s\n' "$*" >&2
}

die() {
    printf '[uninstall] error: %s\n' "$*" >&2
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

remove_if_exists() {
    path=$1
    if [ -e "$path" ] || [ -L "$path" ]; then
        run_privileged rm -rf "$path"
    fi
}

log "this removes the installed $APP_NAME service and files"
if [ "$UNATTENDED" = "1" ]; then
    log "running in unattended mode"
fi

if command_exists systemctl && systemctl list-unit-files "$SERVICE_NAME" >/dev/null 2>&1; then
    log "stopping and disabling $SERVICE_NAME"
    run_privileged systemctl disable --now "$SERVICE_NAME" || true
fi

remove_if_exists "$INSTALL_SERVICE"

if command_exists systemctl; then
    run_privileged systemctl daemon-reload || true
fi

remove_if_exists "$INSTALL_BIN"

if [ "$REMOVE_CONFIG" = "1" ] || prompt_yes_no "Remove config file at $INSTALL_CONFIG?" "n"; then
    remove_if_exists "$INSTALL_CONFIG"
    if [ -d "$INSTALL_CONFIG_DIR" ] && [ -z "$(ls -A "$INSTALL_CONFIG_DIR" 2>/dev/null || true)" ]; then
        remove_if_exists "$INSTALL_CONFIG_DIR"
    fi
fi

if [ "$REMOVE_ASSETS" = "1" ] || prompt_yes_no "Remove asset directory at $INSTALL_ASSET_DIR?" "n"; then
    remove_if_exists "$INSTALL_ASSET_DIR"
    if [ -d "$INSTALL_WORK_DIR" ] && [ -z "$(ls -A "$INSTALL_WORK_DIR" 2>/dev/null || true)" ]; then
        remove_if_exists "$INSTALL_WORK_DIR"
    fi
fi

if id "$INSTALL_USER" >/dev/null 2>&1; then
    if [ "$REMOVE_USER" = "1" ] || prompt_yes_no "Remove service user $INSTALL_USER?" "n"; then
        if command_exists userdel; then
            run_privileged userdel "$INSTALL_USER" || warn "could not remove user $INSTALL_USER"
        elif command_exists deluser; then
            run_privileged deluser "$INSTALL_USER" || warn "could not remove user $INSTALL_USER"
        else
            warn "no supported user removal tool found"
        fi
    fi
fi

if getent group "$INSTALL_GROUP" >/dev/null 2>&1; then
    if [ "$REMOVE_GROUP" = "1" ] || prompt_yes_no "Remove service group $INSTALL_GROUP?" "n"; then
        if command_exists groupdel; then
            run_privileged groupdel "$INSTALL_GROUP" || warn "could not remove group $INSTALL_GROUP"
        elif command_exists delgroup; then
            run_privileged delgroup "$INSTALL_GROUP" || warn "could not remove group $INSTALL_GROUP"
        else
            warn "no supported group removal tool found"
        fi
    fi
fi

log "uninstall complete"
