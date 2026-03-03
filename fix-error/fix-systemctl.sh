#!/usr/bin/env bash
# fix-systemctl.sh
# Script to repair systemctl/systemd and optionally protect the binaries.
# Run as root.

set -euo pipefail

echo "=== Step 1: Remove immutable attrs (if any) from systemd unit files ==="
find /lib/systemd/system/ -maxdepth 1 -type f -exec chattr -i {} \;
find /etc/systemd/system/ -maxdepth 1 -type f -exec chattr -i {} \;

echo "=== Step 2: Try to fix any pending dpkg configurations ==="
dpkg --configure -a || true

echo "=== Step 3: Force unpack systemd package ==="
dpkg --force-overwrite --force-overwrite-dir --unpack /var/cache/apt/archives/systemd_*.deb

echo "=== Step 4: Configure systemd ==="
dpkg --configure systemd

echo "=== Step 5: Fix broken dependencies and upgrade packages ==="
apt --fix-broken install -y
apt update -y
apt upgrade -y

echo "=== Step 6: Verify systemctl availability ==="
if command -v systemctl >/dev/null 2>&1; then
    echo "systemctl found"
    systemctl --version
else
    echo "systemctl still not found — check logs"
    exit 1
fi

echo "=== Step 7: Status of nginx (if installed) ==="
systemctl status nginx || echo "nginx not installed or not active"

echo "=== Step 8: Optionally protect systemctl/systemd binaries ==="
# Set immutable flag on systemd binary and systemctl binary
# NOTE: this will block further package upgrades unless attrs are removed.
read -p "Protect systemctl & systemd binaries from modification? (y/N): " protect
if [[ "$protect" =~ ^[Yy]$ ]]; then
    echo "Protecting /usr/bin/systemctl and related binaries..."
    chattr +i /usr/bin/systemctl || echo "Could not protect systemctl"
    chattr +i /usr/lib/systemd/systemd || echo "Could not protect systemd"
    echo "Immutable attributes set. To allow changes later, use 'chattr -i'."
else
    echo "Skipping protection step."
fi

echo "=== Script completed ==="