#!/bin/sh
set -eu

if ! getent group trust-onboard >/dev/null 2>&1; then
    groupadd --system trust-onboard
fi

if ! id trust-onboard >/dev/null 2>&1; then
    useradd --system --gid trust-onboard --home /var/lib/trust-onboard --shell /usr/sbin/nologin trust-onboard
fi

install -d -o trust-onboard -g trust-onboard -m 0750 /var/lib/trust-onboard
install -d -o trust-onboard -g trust-onboard -m 0750 /var/lib/trust-onboard/assets
chown trust-onboard:trust-onboard /var/lib/trust-onboard/assets/root_ca.crt /var/lib/trust-onboard/assets/logo.svg || true

systemctl daemon-reload >/dev/null 2>&1 || true
