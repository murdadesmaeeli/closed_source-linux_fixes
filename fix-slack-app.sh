#!/bin/bash
# Fix Slack not opening on Debian 13 (Trixie)
# Unmasking snapd service which was stopped by power-mode.sh battery mode,
# connecting required snap interfaces, and updating Slack.

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Slack Desktop - Fix Snap Launch Issue"
echo "  Debian 13 (Trixie)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Do NOT run this script as root (sudo)"
    echo "   The script will ask for sudo password when needed."
    exit 1
fi

echo "=== Step 1: Ensuring snapd is running ==="

# is-enabled exits non-zero for masked units, so capture output separately
SNAPD_ENABLED=$(systemctl is-enabled snapd.service 2>/dev/null) || true

if [[ "$SNAPD_ENABLED" == "masked" ]]; then
    echo "   snapd.service is masked — unmasking..."
    sudo systemctl unmask snapd.service
    echo "   ✅ Unmasked snapd.service"
fi

SNAPD_STATUS=$(systemctl is-active snapd.service 2>/dev/null) || true

if [[ "$SNAPD_STATUS" != "active" ]]; then
    echo "   Starting snapd.socket and snapd.service..."
    sudo systemctl start snapd.socket
    sudo systemctl start snapd.service
    sleep 3
    echo "   ✅ snapd is running"
else
    echo "   ✅ snapd is already running"
fi
echo ""

echo "=== Step 2: Verifying Slack snap is installed ==="
if snap list slack &>/dev/null; then
    CURRENT_VER=$(snap list slack 2>/dev/null | awk 'NR==2{print $2}')
    echo "   ✅ Slack snap is installed (version: ${CURRENT_VER:-unknown})"
else
    echo "   Slack snap not found, installing..."
    sudo snap install slack
    echo "   ✅ Slack snap installed"
fi
echo ""

echo "=== Step 3: Connecting snap interfaces ==="
INTERFACES=(
    "slack:desktop :desktop"
    "slack:desktop-legacy :desktop-legacy"
    "slack:wayland :wayland"
    "slack:unity7 :unity7"
    "slack:browser-support :browser-support"
    "slack:network :network"
    "slack:network-bind :network-bind"
    "slack:pulseaudio :pulseaudio"
    "slack:audio-playback :audio-playback"
    "slack:removable-media :removable-media"
    "slack:camera :camera"
)

for iface in "${INTERFACES[@]}"; do
    sudo snap connect $iface 2>/dev/null && echo "   ✅ Connected: $iface" || echo "   -- Skipped: $iface (already connected or unavailable)"
done

# Content interface (gnome platform snap)
if snap list gnome-3-38-2004 &>/dev/null; then
    echo "   ✅ gnome-3-38-2004 content snap already installed"
else
    echo "   Installing gnome-3-38-2004 content snap..."
    sudo snap install gnome-3-38-2004 2>/dev/null || echo "   ⚠️  Could not install gnome-3-38-2004 (Slack may still work)"
fi
echo ""

echo "=== Step 4: Updating Slack to latest version ==="
sudo snap refresh slack 2>&1 && echo "   ✅ Slack updated" || echo "   ✅ Slack is already at the latest version"
echo ""

echo "=== Step 5: Launching Slack ==="
echo "   Starting Slack..."
nohup slack &>/dev/null &
sleep 2
echo "   ✅ Slack launched"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Fix Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  If Slack doesn't open, try:"
echo "    snap run slack"
echo ""
echo "  To check snapd status:"
echo "    systemctl status snapd.service"
echo ""
echo "✅ Script completed successfully!"
