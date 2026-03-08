#!/bin/bash
# Set Audio-Technica AT2020 USB as the ONLY and DEFAULT microphone
# Disables built-in audio card microphone

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Audio-Technica AT2020 USB - Default Microphone Setup"
echo "  Debian 13 - PipeWire/WirePlumber"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Do NOT run this script as root"
    echo "   This script configures user-level audio settings."
    exit 1
fi

echo "=== Step 1: Checking for AT2020 USB ==="
if pactl list sources short | grep -q "audio-technica.*AT2020"; then
    echo "   ✅ AT2020 USB microphone detected"
    AT2020_NAME=$(pactl list sources short | grep "audio-technica.*AT2020" | awk '{print $2}')
    echo "   Device: $AT2020_NAME"
else
    echo "   ❌ AT2020 USB microphone NOT found"
    echo ""
    echo "Available audio sources:"
    pactl list sources short
    echo ""
    echo "Make sure your AT2020 USB is plugged in and recognized."
    exit 1
fi

echo ""
echo "=== Step 2: Creating PipeWire configuration ==="

# Create PipeWire config directory
mkdir -p ~/.config/pipewire/pipewire.conf.d

# Set AT2020 as default source
cat > ~/.config/pipewire/pipewire.conf.d/10-at2020-default.conf << 'EOF'
# Set Audio-Technica AT2020 USB as default microphone
context.properties = {
    default.configured.audio.source = {
        name = "alsa_input.usb-audio-technica____AT2020_USB-00.analog-stereo"
    }
}
EOF
echo "   ✅ Created PipeWire default source config"

echo ""
echo "=== Step 3: Disabling built-in audio card microphone ==="

# Create WirePlumber config directory
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

# Disable built-in audio card
cat > ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf << 'EOF'
# Disable built-in audio card to prevent built-in mic from being used
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "alsa_card.pci-0000_00_1f.3"
      }
    ]
    actions = {
      update-props = {
        device.disabled = true
      }
    }
  }
]
EOF
echo "   ✅ Created WirePlumber rule to disable built-in audio"

echo ""
echo "=== Step 4: Setting current session default ==="

# Disable built-in audio card
if pactl list cards short | grep -q "pci-0000_00_1f.3"; then
    pactl set-card-profile alsa_card.pci-0000_00_1f.3 off 2>/dev/null || true
    echo "   ✅ Disabled built-in audio card"
fi

# Get AT2020 device ID
AT2020_ID=$(wpctl status | grep "Q1U dynamic microphone" | grep -oP '^\s*\K\d+' | head -1)

if [ -n "$AT2020_ID" ]; then
    wpctl set-default "$AT2020_ID"
    echo "   ✅ Set AT2020 as default microphone (ID: $AT2020_ID)"
else
    echo "   ⚠️  Could not find AT2020 in wpctl (will work after restart)"
fi

echo ""
echo "=== Step 5: Restarting audio services ==="
systemctl --user restart wireplumber pipewire pipewire-pulse
sleep 3
echo "   ✅ Restarted PipeWire and WirePlumber"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show current audio sources
echo "Available audio sources:"
wpctl status | grep -A 10 "Sources:"

echo ""
echo "Default configured devices:"
wpctl status | grep -A 5 "Default Configured"

echo ""
echo "Current default microphone volume:"
wpctl get-volume @DEFAULT_AUDIO_SOURCE@

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Configuration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your Audio-Technica AT2020 USB is now:"
echo "  • The ONLY available microphone"
echo "  • Set as the default input device"
echo "  • Will persist across reboots"
echo ""
echo "Built-in audio card microphone is DISABLED."
echo ""
echo "Test your microphone:"
echo "  arecord -f cd -d 5 test.wav && aplay test.wav"
echo ""
echo "Adjust volume:"
echo "  wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 75%"
echo ""
echo "Configuration files created:"
echo "  ~/.config/pipewire/pipewire.conf.d/10-at2020-default.conf"
echo "  ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf"
echo ""














