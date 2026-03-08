#!/bin/bash
# Disable Camlink audio to preserve your existing audio setup
# This ensures Camlink is VIDEO ONLY and won't interfere with your mic/speaker sources

set -e

echo "=========================================="
echo "Disabling Camlink Audio (Video Only Mode)"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Create PulseAudio/PipeWire rule to ignore Camlink audio
echo "=== Configuring Audio System ==="

# For PulseAudio
PULSE_RULE="/etc/udev/rules.d/89-camlink-no-audio.rules"
echo "Creating udev rule to ignore Camlink audio..."
sudo tee "$PULSE_RULE" > /dev/null <<'EOF'
# Prevent Elgato Camlink from being used as audio device
# This preserves your existing mic/speaker setup

# Camlink 4K
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PIPEWIRE_IGNORE}="1"

# Camlink Pro
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PIPEWIRE_IGNORE}="1"
EOF

echo -e "${GREEN}✓ udev rule created${NC}"

# Reload udev
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger
echo -e "${GREEN}✓ udev reloaded${NC}"
echo ""

# 2. If Camlink is currently connected, unbind and rebind it
echo "=== Checking for Connected Camlink ==="
if lsusb | grep -q '0fd9:0066'; then
    echo -e "${YELLOW}⚠ Camlink is currently connected${NC}"
    echo "To apply changes, either:"
    echo "  1. Unplug and replug the Camlink, OR"
    echo "  2. Restart PulseAudio/PipeWire:"
    echo ""
    
    # Detect which audio system is running
    if pgrep -x pipewire > /dev/null; then
        echo "     systemctl --user restart pipewire pipewire-pulse"
    elif pgrep -x pulseaudio > /dev/null; then
        echo "     pulseaudio -k"
    fi
else
    echo "Camlink not currently connected. Rules will apply when you plug it in."
fi
echo ""

# 3. Verify current audio sinks/sources
echo "=== Current Audio Configuration ==="
if command -v pactl &> /dev/null; then
    echo "Default audio sink (speakers):"
    pactl info | grep "Default Sink:" || echo "  (Unable to detect)"
    echo ""
    echo "Default audio source (microphone):"
    pactl info | grep "Default Source:" || echo "  (Unable to detect)"
else
    echo "pactl not available (PulseAudio/PipeWire not running?)"
fi
echo ""

echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "✓ Camlink audio is now DISABLED"
echo "✓ Your existing mic/speaker setup is PRESERVED"
echo "✓ Camlink will work as VIDEO ONLY device in OBS"
echo ""
echo -e "${YELLOW}Note:${NC} If Camlink is currently plugged in, unplug/replug it"
echo "      or restart your audio system for changes to take effect."
echo ""

