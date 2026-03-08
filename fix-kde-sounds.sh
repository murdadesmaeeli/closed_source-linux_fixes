#!/bin/bash
# Complete KDE notification sound fix for Debian 13
# This script enables notification sounds for KDE Plasma, including Clocks timer

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  KDE Notification Sound Configuration"
echo "  Debian 13 (Trixie) - KDE Plasma"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Do NOT run this script as root (sudo)"
    echo "   The script will ask for sudo password when needed."
    exit 1
fi

echo "=== Step 1: Installing required packages ==="
sudo apt update

# Install packages (some may not exist in all Debian versions)
PACKAGES=(
    libnotify-bin
    sound-theme-freedesktop
    libcanberra-pulse
    libcanberra-gtk3-module
    pulseaudio-utils
    gstreamer1.0-pulseaudio
)

for pkg in "${PACKAGES[@]}"; do
    if apt-cache show "$pkg" &>/dev/null; then
        sudo apt install -y "$pkg" 2>/dev/null || echo "   ⚠️  Could not install $pkg (non-critical)"
    else
        echo "   ⚠️  Package $pkg not available (skipping)"
    fi
done

echo ""
echo "=== Step 2: Testing audio system ==="
if paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null; then
    echo "✅ Audio system is working"
else
    echo "⚠️  Audio test failed - attempting to fix..."
    # Try to restart audio
    if systemctl --user is-active --quiet pipewire; then
        systemctl --user restart pipewire pipewire-pulse wireplumber
        echo "   Restarted PipeWire"
    elif systemctl --user is-active --quiet pulseaudio; then
        systemctl --user restart pulseaudio
        echo "   Restarted PulseAudio"
    else
        pulseaudio --kill 2>/dev/null || true
        pulseaudio --start
        echo "   Started PulseAudio"
    fi
    sleep 2
fi

echo ""
echo "=== Step 3: Configuring notification sounds ==="

# Backup existing configs
if [ -f ~/.config/plasmanotifyrc ] || [ -f ~/.config/kclock.notifyrc ]; then
    BACKUP_DIR=~/kde-notification-backup-$(date +%Y%m%d-%H%M%S)
    mkdir -p "$BACKUP_DIR"
    cp ~/.config/plasmanotifyrc "$BACKUP_DIR/" 2>/dev/null || true
    cp ~/.config/kclock.notifyrc "$BACKUP_DIR/" 2>/dev/null || true
    echo "   Backed up existing config to: $BACKUP_DIR"
fi

mkdir -p ~/.config

# Main notification config
cat > ~/.config/plasmanotifyrc << 'EOF'
[Applications][kclock]
Seen=true

[Event/notification]
Action=Sound|Popup
Popup=true
Sound=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga

[Event/warning]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/dialog-warning.oga

[Event/fatalerror]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/dialog-error.oga

[Event/catastrophe]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/dialog-error.oga
EOF

echo "   ✅ Created ~/.config/plasmanotifyrc"

# KClock timer sounds
cat > ~/.config/kclock.notifyrc << 'EOF'
[Event/timerFinished]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga

[Event/alarmTriggered]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
EOF

echo "   ✅ Created ~/.config/kclock.notifyrc"

# Set sound theme
kwriteconfig5 --file kdeglobals --group Sounds --key Theme "freedesktop"
echo "   ✅ Set sound theme to 'freedesktop'"

echo ""
echo "=== Step 4: Restarting notification services ==="
kquitapp5 kded5 2>/dev/null || true
kded5 &
sleep 2
echo "   ✅ Restarted kded5"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Configuration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "=== Running Tests ==="
echo ""

echo "Test 1: Direct sound playback"
echo "   Playing sound file directly..."
if paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga 2>/dev/null; then
    echo "   ✅ Direct sound test PASSED"
else
    echo "   ❌ Direct sound test FAILED - check audio settings"
fi

echo ""
echo "Test 2: Notification with sound"
echo "   Sending test notification..."
notify-send -u critical "✅ Configuration Complete" "If you hear this, notifications are working!"
sleep 2
echo "   📢 Did you hear a notification sound?"
echo ""

echo "Test 3: Alarm/Timer sound"
echo "   Playing timer sound..."
if paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; then
    echo "   ✅ Timer sound test PASSED"
else
    echo "   ❌ Timer sound test FAILED - check audio settings"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Manual Tests You Should Run:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Test notification sound:"
echo "   notify-send -u critical 'Test' 'Testing sound'"
echo ""
echo "2. Test Clocks app timer:"
echo "   - Open Clocks app (or run 'kclock')"
echo "   - Go to Timer tab"
echo "   - Set a 10-second timer"
echo "   - Wait for it to finish"
echo "   - You should hear: alarm-clock-elapsed.oga"
echo ""
echo "3. If you still don't hear sounds, check:"
echo "   - Run 'pavucontrol' and check volume levels"
echo "   - System Settings → Notifications → Configure Events"
echo "   - System Settings → Audio → Applications"
echo ""
echo "For more help, see: docs/KDE-SOUND-NOTIFICATIONS.md"
echo ""
echo "✅ Script completed successfully!"

