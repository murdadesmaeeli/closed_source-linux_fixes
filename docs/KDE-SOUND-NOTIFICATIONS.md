# Enable Sound Notifications on Debian 13 KDE Plasma

## Quick Overview

This guide shows you how to enable sound notifications in KDE Plasma on Debian 13, with special focus on the **Clocks app timer** and other system notifications.

🔊 **Goal**: Play a sound whenever a desktop notification appears (timers, alerts, messages, etc.)

---

## ⚡ Quick Terminal Fix (Works Immediately)

**If you just want it to work NOW**, run these commands:

```bash
# 1. Install required tools
sudo apt update && sudo apt install libnotify-bin sound-theme-freedesktop libcanberra-pulse gstreamer1.0-pulseaudio -y

# 2. Configure notification sounds
mkdir -p ~/.config
cat > ~/.config/plasmanotifyrc << 'EOF'
[Event/notification]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
EOF

# 3. Configure Clocks/Timer sounds
cat > ~/.config/kclock.notifyrc << 'EOF'
[Event/timerFinished]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
EOF

# 4. Restart notification service
kquitapp5 kded5 && kded5 &

# 5. Test it
notify-send -u critical "Test" "If you hear a sound, it works!"
```

**Did you hear a sound?**
- ✅ **YES**: You're done! Scroll to "Test It" section to verify Clocks timer
- ❌ **NO**: Continue to the GUI method or troubleshooting below

---

## 🔔 Method 1: GUI Configuration (Recommended)

### **Step 1: Open System Settings**

You can get there via:

* **Application Launcher** → **System Settings**
  
  or

* Press **Meta (Windows key)** → type *"Notifications"*

---

### **Step 2: Navigate to Notification Sounds**

1. In System Settings, go to:
   
   **Notifications → Configure Events**

2. On the left sidebar, choose **"Plasma Workspace"** (or search for *notification* in the event list)

---

### **Step 3: Select the Notification Event**

1. Look for the event called:
   - **"Notification"**
   - **"General Notification"**
   - **"Incoming Notification"**
   
   *(Exact names may vary slightly depending on your Plasma version)*

---

### **Step 4: Assign a Sound**

1. ✅ Check **"Play a sound"**

2. Click **"Select Sound…"**

3. Choose a sound file (`.ogg` or `.wav`)
   
   KDE includes sounds by default under:

```bash
/usr/share/sounds/freedesktop/stereo/
```

or

```bash
/usr/share/sounds/KDE-Im-Event-Sounds/
```

**Good sound choices:**
- `message-new-instant.oga` (subtle)
- `complete.oga` (completion sound)
- `dialog-information.oga` (informative)
- `alarm-clock-elapsed.oga` (for timers)

4. Click **Apply**

---

### **Step 5: Adjust Notification Volume (if needed)**

Some themes set a very low event volume.

1. Go to **System Settings → Audio → Applications**

2. Trigger a test notification (see test below)

3. Adjust the **Notification Sounds** or **Event Sounds** channel volume

---

## ⏰ Specific Fix for Clocks App Timer

The KDE Clocks app sometimes doesn't play sounds for timers. Here's how to ensure it works:

### **Option A: Enable Clocks-Specific Notification**

1. Go to **System Settings → Notifications → Configure Events**

2. In the left sidebar, look for **"KClock"** or **"Clocks"**

3. Find the **"Timer Expired"** or **"Alarm"** event

4. ✅ Enable **"Play a sound"**

5. Assign a loud, clear sound like:
   ```
   /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
   ```

### **Option B: Install Additional Sound Packages**

If sounds are missing, install the complete sound theme:

```bash
sudo apt update
sudo apt install sound-theme-freedesktop kde-config-sddm plasma-workspace-wallpapers
```

### **Option C: Test Clocks Notifications**

1. Open **Clocks** app

2. Go to **Timer** tab

3. Set a 10-second timer

4. Wait for it to expire

5. You should hear the notification sound

---

## ✔ Test Your Configuration

### **Test 1: Direct Sound Test (Most Reliable)**

This bypasses notifications and plays sound directly:

```bash
# Test with canberra (most reliable)
/usr/bin/canberra-gtk-play -i message-new-instant

# Or with paplay
paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga

# Or with pw-play (if using PipeWire)
pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
```

**If these don't work**, your audio system is broken - fix that first!

### **Test 2: Desktop Notification (With Sound)**

```bash
# Simple notification
notify-send "Test Alert" "This is a test notification with sound"

# Critical notification (higher priority, should be louder)
notify-send -u critical "Critical Alert" "High priority notification"

# With custom icon
notify-send -i dialog-information "Info" "Information notification"
```

### **Test 3: KDE-Specific Notification**

```bash
# KDE dialog (may or may not have sound depending on config)
kdialog --passivepopup "Test notification sound" 3

# Or use D-Bus directly
qdbus org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.Notify "TestApp" 0 "dialog-information" "Test" "Testing KDE notification sound" [] {} 5000
```

### **Test 4: Clocks Timer (The Real Test)**

1. Open **Clocks** app (or run `kclock` in terminal)
2. Go to **Timer** tab
3. Set a **10-second timer**
4. Click **Start**
5. Wait for it to expire
6. **You should hear**: `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`

If you hear the sound, congratulations - it's working! 🎉

---

## 🔧 Advanced: Configuration File Method

If the GUI method doesn't work, you can edit the configuration directly:

### **Edit Plasma Notification Config**

```bash
nano ~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

Or for system-wide notifications:

```bash
nano ~/.config/plasmanotifyrc
```

Add or modify:

```ini
[Event/notification]
Action=Sound
Sound=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
```

### **Restart Plasma Shell**

After editing config files:

```bash
kquitapp5 plasmashell && kstart5 plasmashell
```

---

## 🛠️ Terminal-Based Fix (If GUI Doesn't Work)

If the GUI configuration isn't working, use this comprehensive terminal method:

### **Step 1: Install Required Packages**

```bash
sudo apt update
sudo apt install libnotify-bin sound-theme-freedesktop pulseaudio-utils
```

### **Step 2: Test Audio System First**

```bash
# Test if audio works at all
paplay /usr/share/sounds/freedesktop/stereo/complete.oga
```

**If no sound:** Your audio system is broken. Fix that first:

```bash
# Check what audio system is running
ps aux | grep -E 'pipewire|pulseaudio'

# If using PipeWire:
systemctl --user restart pipewire pipewire-pulse wireplumber

# If using PulseAudio:
pulseaudio --kill && pulseaudio --start
```

### **Step 3: Configure Notifications via Terminal**

```bash
# Create/edit notification config
mkdir -p ~/.config
cat > ~/.config/plasmanotifyrc << 'EOF'
[Event/notification]
Action=Sound|Popup
Execute=
Logfile=
Popup=true
Sound=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
TTS=

[Event/catastrophe]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/dialog-error.oga

[Event/warning]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/dialog-warning.oga
EOF
```

### **Step 4: Configure KClock Timer Sounds**

```bash
# Create KClock notification config
cat > ~/.config/kclock.notifyrc << 'EOF'
[Event/timerFinished]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga

[Event/alarmTriggered]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
EOF
```

### **Step 5: Reload KDE Configuration**

```bash
# Restart notification daemon
kquitapp5 plasmanotifyrc 2>/dev/null
kquitapp5 kded5 && kded5 &

# Or restart entire plasma shell
kquitapp5 plasmashell && kstart5 plasmashell &
```

### **Step 6: Test with Working Commands**

```bash
# Test 1: Direct sound test (should ALWAYS work if audio is OK)
canberra-gtk-play -f /usr/share/sounds/freedesktop/stereo/message-new-instant.oga

# Test 2: Notification with sound
notify-send -u normal "Test Sound" "Testing notification sound"

# Wait 2 seconds, then:
notify-send -u critical "Critical Test" "This should definitely make noise"

# Test 3: KDE-specific notification
qdbus org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.Notify "Test App" 0 "dialog-information" "Test Notification" "This is a test with sound" [] {} 5000
```

---

## 🐛 Troubleshooting

### **No Sound Playing?**

#### 1. **Check if Sound System is Working**

```bash
# Try multiple methods to test audio
paplay /usr/share/sounds/freedesktop/stereo/complete.oga
aplay /usr/share/sounds/alsa/Front_Center.wav
speaker-test -t wav -c 2 -l 1
```

If NONE of these play, your audio system has issues.

#### 2. **Install Missing Sound Tools**

```bash
# Install canberra for reliable notification sounds
sudo apt install libcanberra-pulse gstreamer1.0-pulseaudio

# Install canberra-gtk3 for testing (canberra-gtk-play tool)
sudo apt install libcanberra-gtk3-module
```

#### 3. **Check PulseAudio/PipeWire**

```bash
# Check what's running
systemctl --user status pipewire pipewire-pulse 2>/dev/null || systemctl --user status pulseaudio

# Check audio outputs
pactl list sinks short

# Check if notification sounds are muted
pactl list sink-inputs
```

Restart audio if needed:

```bash
# For PipeWire:
systemctl --user restart pipewire pipewire-pulse wireplumber

# For PulseAudio:
systemctl --user restart pulseaudio
```

#### 4. **Verify Notification Daemon is Running**

```bash
# Check if notification service is active
ps aux | grep -i notif

# Check D-Bus notification service
qdbus org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.GetCapabilities
```

If you get an error, restart the notification system:

```bash
kquitapp5 kded5 && kded5 &
```

#### 5. **Check Notification Settings Are Enabled**

```bash
# Check if sound is enabled in config
kreadconfig5 --file plasmanotifyrc --group "Event/notification" --key Action

# Should return: Sound|Popup or Sound
# If it returns nothing or "None", notifications sounds are disabled
```

Fix it with:

```bash
kwriteconfig5 --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup"
kwriteconfig5 --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
```

#### 6. **Verify Sound Files Exist**

```bash
# List available sounds
ls -lh /usr/share/sounds/freedesktop/stereo/

# Check if the specific sound exists
ls -lh /usr/share/sounds/freedesktop/stereo/message-new-instant.oga
ls -lh /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
```

If files don't exist:

```bash
sudo apt install sound-theme-freedesktop --reinstall
```

#### 7. **Check Application-Specific Settings**

Some apps override system notification settings. In System Settings:

**Notifications → Application Settings**

Find your app (like Clocks/KClock) and ensure:
- ✅ Show in history
- ✅ Show notification banners
- Volume is not muted

#### 8. **Nuclear Option: Reset All Notification Settings**

If nothing works, reset everything:

```bash
# Backup existing configs
mkdir -p ~/kde-notification-backup
cp ~/.config/plasmanotifyrc ~/kde-notification-backup/ 2>/dev/null
cp ~/.config/kclock.notifyrc ~/kde-notification-backup/ 2>/dev/null

# Remove old configs
rm ~/.config/plasmanotifyrc
rm ~/.config/kclock.notifyrc

# Recreate with working defaults
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
EOF

cat > ~/.config/kclock.notifyrc << 'EOF'
[Event/timerFinished]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga

[Event/alarmTriggered]  
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
EOF

# Restart everything
kquitapp5 plasmashell && kstart5 plasmashell &

# Test again
sleep 3
notify-send -u critical "Reset Complete" "Testing notification sounds"
```

---

### **Still No Sound? Check These:**

```bash
# 1. Verify PulseAudio/PipeWire mixer levels
pavucontrol
# Look for "System Sounds" or "Event Sounds" - make sure not muted

# 2. Check if sound theme is set
kreadconfig5 --file kdeglobals --group Sounds --key Theme

# 3. Enable sound theme if not set
kwriteconfig5 --file kdeglobals --group Sounds --key Theme "freedesktop"

# 4. Check KWin compositor (sometimes blocks sounds)
kreadconfig5 --file kwinrc --group Compositing --key Enabled

# 5. Test notification daemon directly
gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "test" 0 "dialog-information" "Test" "Sound Test" "[]" "{}" 5000
```

---

## 📝 Custom Sound Files

### **Using Your Own Sounds**

1. Copy your sound file (`.ogg` or `.wav` format recommended):

```bash
mkdir -p ~/.local/share/sounds/custom
cp /path/to/your/sound.ogg ~/.local/share/sounds/custom/
```

2. In System Settings → Notifications → Configure Events:
   
   Browse to `~/.local/share/sounds/custom/sound.ogg`

### **Convert MP3 to OGG** (if needed)

```bash
sudo apt install ffmpeg
ffmpeg -i input.mp3 -c:a libvorbis -q:a 4 output.ogg
```

---

## 🎯 Recommended Sound Settings

For the best experience:

| Event Type | Recommended Sound |
|------------|-------------------|
| General Notification | `message-new-instant.oga` |
| Timer/Alarm (Clocks) | `alarm-clock-elapsed.oga` |
| Critical Alerts | `dialog-warning.oga` |
| Completion Events | `complete.oga` |
| Error Messages | `dialog-error.oga` |

---

## ✅ Quick Checklist

- [ ] System Settings → Notifications → Configure Events → Plasma Workspace
- [ ] Enable "Play a sound" for "Notification" event
- [ ] Assign a sound file from `/usr/share/sounds/`
- [ ] Check Audio volume for Event/Notification Sounds
- [ ] Test with `notify-send -u critical "Test" "Sound test"`
- [ ] For Clocks: Enable sound in KClock/Clocks event specifically
- [ ] Verify sound plays when timer expires
- [ ] Test direct sound: `paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga`

---

## 📋 Copy-Paste Solution (Complete Fix)

**For those who just want working commands**, run this entire block:

```bash
#!/bin/bash
# Complete KDE notification sound fix for Debian 13

echo "=== Installing required packages ==="
sudo apt update
sudo apt install -y libnotify-bin sound-theme-freedesktop libcanberra-pulse \
  libcanberra-gtk3-module pulseaudio-utils gstreamer1.0-pulseaudio

echo "=== Configuring notification sounds ==="
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
EOF

# KClock timer sounds
cat > ~/.config/kclock.notifyrc << 'EOF'
[Event/timerFinished]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga

[Event/alarmTriggered]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
EOF

# Set sound theme
kwriteconfig5 --file kdeglobals --group Sounds --key Theme "freedesktop"

echo "=== Restarting notification services ==="
kquitapp5 kded5 2>/dev/null
kded5 &
sleep 2

echo "=== Testing notification sound ==="
notify-send -u critical "✅ Configuration Complete" "If you hear this, notifications are working!"

echo ""
echo "=== Manual Tests ==="
echo "1. Direct sound test:"
echo "   paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
echo ""
echo "2. Notification test:"
echo "   notify-send -u critical 'Test' 'Testing sound'"
echo ""
echo "3. Clocks timer test:"
echo "   Open Clocks app → Timer → Set 10 seconds → Wait"
echo ""
echo "=== Done! ==="
```

Save this as `fix-kde-sounds.sh`, make it executable, and run it:

```bash
chmod +x fix-kde-sounds.sh
./fix-kde-sounds.sh
```

---

## 📚 Additional Resources

- KDE Plasma Notification Documentation: https://docs.kde.org/
- Sound Theme Freedesktop Spec: https://www.freedesktop.org/wiki/Specifications/sound-theme-spec/
- Debian KDE Team: https://wiki.debian.org/KDE

---

**Last Updated**: November 2025  
**Tested On**: Debian 13 (Trixie) with KDE Plasma 5.27+

