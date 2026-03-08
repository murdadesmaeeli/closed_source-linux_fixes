#!/bin/bash
# KDE Plasma 6 notification sound fix for Debian 13
# Specifically fixes KClock timer sounds

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  KDE Plasma 6 Notification Sound Configuration"
echo "  Debian 13 (Trixie) - Specifically for KClock Timer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Do NOT run this script as root (sudo)"
    echo "   The script will ask for sudo password when needed."
    exit 1
fi

# Detect Plasma version
if command -v kwriteconfig6 &>/dev/null; then
    PLASMA_VER=6
    KWRITE="kwriteconfig6"
    KQUIT="kquitapp6"
    KDED="kded6"
    echo "✅ Detected: KDE Plasma 6"
elif command -v kwriteconfig5 &>/dev/null; then
    PLASMA_VER=5
    KWRITE="kwriteconfig5"
    KQUIT="kquitapp5"
    KDED="kded5"
    echo "✅ Detected: KDE Plasma 5"
else
    echo "❌ ERROR: Cannot detect KDE Plasma version"
    echo "   Neither kwriteconfig5 nor kwriteconfig6 found"
    exit 1
fi

echo ""
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
echo "=== Step 3: Configuring KClock timer sounds ==="

# Configure KClock notifications
$KWRITE --file kclock.notifyrc --group "Event/timerFinished" --key Action "Sound|Popup"
$KWRITE --file kclock.notifyrc --group "Event/timerFinished" --key Sound "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
$KWRITE --file kclock.notifyrc --group "Event/alarmTriggered" --key Action "Sound|Popup"
$KWRITE --file kclock.notifyrc --group "Event/alarmTriggered" --key Sound "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
echo "   ✅ Configured KClock timer sounds"

# Configure general notifications
$KWRITE --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup"
$KWRITE --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
echo "   ✅ Configured general notification sounds"

# Set sound theme
$KWRITE --file kdeglobals --group Sounds --key Theme "freedesktop"
echo "   ✅ Set sound theme to 'freedesktop'"

echo ""
echo "=== Step 4: Restarting services ==="

# Kill kclockd if running
if pgrep -x kclockd > /dev/null; then
    killall kclockd 2>/dev/null || true
    sleep 1
    echo "   ✅ Restarted kclockd (will auto-start when needed)"
fi

# Restart notification daemon
$KQUIT $KDED 2>/dev/null || true
sleep 2
$KDED &>/dev/null &
sleep 2
echo "   ✅ Restarted $KDED"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Configuration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "=== Running Tests ==="
echo ""

echo "Test 1: Direct alarm sound"
echo "   Playing alarm sound file..."
if paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; then
    echo "   ✅ Alarm sound test PASSED"
else
    echo "   ❌ Alarm sound test FAILED"
fi

echo ""
echo "Test 2: Notification with sound"
echo "   Sending test notification..."
notify-send -u critical "✅ KClock Configuration Complete" "Notification sounds are now enabled"
sleep 1

echo ""
echo "Test 3: KClock-specific notification"
echo "   Simulating KClock timer notification..."
notify-send -a "KClock" -u critical "Timer Finished" "This is what a timer notification looks like"
sleep 1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔔 IMPORTANT: Test the Clocks App Timer Now"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open the Clocks app:"
echo "   kclock"
echo ""
echo "2. Go to the Timer tab"
echo ""
echo "3. Set a 10-second timer and start it"
echo ""
echo "4. Wait for it to finish - you should hear:"
echo "   /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
echo ""
echo "5. If you DON'T hear a sound:"
echo "   - Check System Settings → Notifications → Applications"
echo "   - Find 'KClock' and ensure sounds are enabled"
echo "   - Check 'pavucontrol' → Playback tab while timer goes off"
echo "   - Run: notify-send -a 'KClock' -u critical 'Test' 'Timer test'"
echo ""
echo "Configuration saved to:"
echo "   ~/.config/kclock.notifyrc"
echo "   ~/.config/plasmanotifyrc"
echo ""
echo "✅ Script completed successfully!"















