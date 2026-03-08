#!/bin/bash
#
# One-time fix: restore nvidia.conf and power-profiles-daemon after
# the first power-mode.sh run damaged them.
# Run this once, then delete this script.
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo $0"
    exit 1
fi

echo "=== Restoring original /etc/modprobe.d/nvidia.conf ==="
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
# You need to run "update-initramfs -u" after editing this file.

# Nouveau must be blacklisted here as well beside from the initrd to avoid a
# delayed loading (for example on Optimus laptops where the Nvidia card is not
# driving the main display).

blacklist nouveau

# Enable complete power management. From:
# file:///usr/share/doc/nvidia-driver/html/powermanagement.html

options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_EnableS0ixPowerManagement=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
echo "  OK: nvidia.conf restored"

echo ""
echo "=== Reinstalling power-profiles-daemon ==="
apt-get install -y power-profiles-daemon 2>&1 | tail -5
systemctl enable power-profiles-daemon
systemctl start power-profiles-daemon
echo "  OK: power-profiles-daemon reinstalled and started"

echo ""
echo "=== Rebuilding initramfs ==="
update-initramfs -u 2>&1 | tail -2
echo "  OK: initramfs rebuilt"

echo ""
echo "=== Cleaning up stale config ==="
rm -rf ~/.config/power-mode /root/.config/power-mode
echo "  OK: old snapshot removed"

echo ""
echo "=== Verifying ==="
echo "  nvidia.conf:"
head -3 /etc/modprobe.d/nvidia.conf
echo "  PPD: $(systemctl is-active power-profiles-daemon)"
echo ""
echo "System restored. You can now re-run:"
echo "  sudo bash/power-mode.sh setup"
echo "  sudo bash/power-mode.sh battery"
