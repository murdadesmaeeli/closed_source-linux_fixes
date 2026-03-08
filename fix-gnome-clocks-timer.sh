#!/bin/bash
# Fix GNOME Clocks timer sound on KDE Plasma 6 / Debian 13

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GNOME Clocks Timer Sound Fix"
echo "  For KDE Plasma 6 on Debian 13"
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
sudo apt install -y \
    libnotify-bin \
    sound-theme-freedesktop \
    libcanberra-pulse \
    libcanberra-gtk3-0 \
    libcanberra-gtk3-module \
    gstreamer1.0-plugins-good \
    gstreamer1.0-pulseaudio \
    pulseaudio-utils

echo ""
echo "=== Step 2: Enable GNOME sound events ==="
gsettings set org.gnome.desktop.sound event-sounds true
gsettings set org.gnome.desktop.sound theme-name 'freedesktop'
echo "   ✅ GNOME event sounds enabled"

echo ""
echo "=== Step 3: Configure KDE Plasma notifications for GNOME Clocks ==="

# Configure Plasma to show notifications from GNOME Clocks
kwriteconfig6 --file plasmanotifyrc --group "Applications" --group "org.gnome.clocks" --key Seen "true"
kwriteconfig6 --file plasmanotifyrc --group "Applications" --group "org.gnome.clocks" --key ShowPopups "true"
kwriteconfig6 --file plasmanotifyrc --group "Applications" --group "org.gnome.clocks" --key ShowPopupsInDoNotDisturbMode "true"
kwriteconfig6 --file plasmanotifyrc --group "Applications" --group "org.gnome.clocks" --key ShowInTaskManager "true"
echo "   ✅ GNOME Clocks notifications enabled in Plasma"

# Configure general notification sounds
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup"
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
echo "   ✅ Notification sounds configured"

# Set KDE sound theme
kwriteconfig6 --file kdeglobals --group Sounds --key Theme "freedesktop"
echo "   ✅ KDE sound theme set"

echo ""
echo "=== Step 4: Create custom notification config for GNOME Clocks ==="
cat > ~/.config/org.gnome.clocks.notifyrc << 'EOF'
[Event/alarm]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga

[Event/timer]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
EOF
echo "   ✅ Created ~/.config/org.gnome.clocks.notifyrc"

echo ""
echo "=== Step 5: Restart services ==="

# Restart GNOME Clocks
if pgrep -x gnome-clocks > /dev/null; then
    killall gnome-clocks 2>/dev/null || true
    sleep 1
    echo "   ✅ Restarted GNOME Clocks (will auto-start when needed)"
fi

# Restart KDE notification daemon
kquitapp6 kded6 2>/dev/null || true
sleep 2
kded6 &>/dev/null &
sleep 1
echo "   ✅ Restarted kded6"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Testing Sound System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Test 1: Direct alarm sound (paplay)"
if paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null; then
    echo "   ✅ PASSED - paplay works"
else
    echo "   ❌ FAILED - paplay doesn't work"
fi

echo ""
echo "Test 2: GNOME Clocks notification simulation"
notify-send -a "org.gnome.clocks" -u critical "Timer" "Time's up!"
sleep 1
echo "   📢 Did you see the notification?"

echo ""
echo "Test 3: General notification with sound"
notify-send -u critical "Test Notification" "Testing notification sound"
sleep 1
echo "   📢 Did you hear a notification sound?"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⏲️  CRITICAL: Test with Real Timer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "GNOME Clocks plays sounds using libcanberra, which works"
echo "INDEPENDENTLY of the KDE notification system."
echo ""
echo "The timer sound should work now. Test it:"
echo ""
echo "1. Open GNOME Clocks"
echo "2. Go to Timer tab"
echo "3. Set a 10-second timer"
echo "4. Wait for it to finish"
echo "5. You should hear the alarm sound!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "If it STILL doesn't work:"
echo ""
echo "1. Check audio mixer while timer is going off:"
echo "   pavucontrol"
echo ""
echo "2. Verify GNOME sound settings:"
echo "   gsettings get org.gnome.desktop.sound event-sounds"
echo "   (should show 'true')"
echo ""
echo "3. Check PulseAudio is running:"
echo "   systemctl --user status pulseaudio"
echo "   systemctl --user status pipewire pipewire-pulse"
echo ""
echo "4. Test libcanberra directly (if tools exist):"
echo "   canberra-gtk-play -i alarm-clock-elapsed"
echo ""
echo "5. Check if sound file exists:"
echo "   ls -lh /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
echo ""
echo "✅ Configuration complete!"















