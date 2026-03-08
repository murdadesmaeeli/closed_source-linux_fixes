# Fix GNOME Clocks Timer Sound on KDE Plasma 6

## The Issue

You're using **GNOME Clocks** (not KClock) on **KDE Plasma 6**. GNOME Clocks uses a different sound system than KDE applications.

### Why It's Different

- **KDE apps** use KDE's notification system with `.notifyrc` files
- **GNOME Clocks** uses **libcanberra** to play sounds directly
- **libcanberra** reads GNOME settings (`gsettings`) not KDE settings

## Quick Fix (Run This Script)

```bash
./fix-gnome-clocks-timer.sh
```

## Manual Fix (Step by Step)

If you prefer to do it manually:

### 1. Install Required Packages

```bash
sudo apt install -y libcanberra-pulse libcanberra-gtk3-0 \
  gstreamer1.0-plugins-good gstreamer1.0-pulseaudio \
  sound-theme-freedesktop
```

### 2. Enable GNOME Sound Events

```bash
gsettings set org.gnome.desktop.sound event-sounds true
gsettings set org.gnome.desktop.sound theme-name 'freedesktop'
```

### 3. Configure KDE Notifications for GNOME Clocks

```bash
kwriteconfig6 --file plasmanotifyrc --group "Applications" --group "org.gnome.clocks" --key Seen "true"
kwriteconfig6 --file plasmanotifyrc --group "Applications" --group "org.gnome.clocks" --key ShowPopups "true"
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup"
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
kwriteconfig6 --file kdeglobals --group Sounds --key Theme "freedesktop"
```

### 4. Restart Services

```bash
killall gnome-clocks 2>/dev/null || true
kquitapp6 kded6 && sleep 2 && kded6 &
```

### 5. Test It!

Open GNOME Clocks, go to Timer tab, set a 10-second timer, and wait for it to finish.

## Troubleshooting

### Timer Still Silent?

#### Check GNOME Sound Settings

```bash
gsettings get org.gnome.desktop.sound event-sounds
```

Should return `true`. If not:

```bash
gsettings set org.gnome.desktop.sound event-sounds true
```

#### Check Sound Theme

```bash
gsettings get org.gnome.desktop.sound theme-name
```

Should return `'freedesktop'`. If not:

```bash
gsettings set org.gnome.desktop.sound theme-name 'freedesktop'
```

#### Test Sound Directly

```bash
paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
```

If this doesn't play, your audio system is broken.

#### Check Audio Mixer During Timer

While a timer is going off, run:

```bash
pavucontrol
```

Go to **Playback** tab - you should see "GNOME Clocks" or "System Sounds". Make sure it's not muted.

#### Check PulseAudio/PipeWire

```bash
# Check if audio server is running
systemctl --user status pipewire pipewire-pulse
# or
systemctl --user status pulseaudio

# Restart if needed
systemctl --user restart pipewire pipewire-pulse wireplumber
# or
systemctl --user restart pulseaudio
```

#### Verify Sound File Exists

```bash
ls -lh /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
```

If missing:

```bash
sudo apt install --reinstall sound-theme-freedesktop
```

### Check if libcanberra is Working

If you have `canberra-gtk-play` installed:

```bash
canberra-gtk-play -i alarm-clock-elapsed -d "Timer test"
```

This should play the alarm sound immediately.

### Use KClock Instead?

If GNOME Clocks continues to be problematic, you can use KDE's native clock app:

```bash
sudo apt install kclock
```

Then use KClock for timers instead. It integrates better with KDE Plasma.

## Key Differences: GNOME vs KDE Apps

| Feature | GNOME Clocks | KClock |
|---------|--------------|--------|
| Sound System | libcanberra + GSound | KDE Notifications |
| Config File | gsettings | `.notifyrc` files |
| Sound Theme | GNOME theme | KDE theme |
| Desktop Integration | GTK/GNOME | Qt/KDE |

## Why Does This Happen?

When you run GNOME apps on KDE:
- The app uses GNOME libraries (GTK, libcanberra)
- KDE has its own notification system
- The two systems don't automatically communicate
- You need to configure **both** systems

## Complete One-Liner Fix

```bash
gsettings set org.gnome.desktop.sound event-sounds true && \
gsettings set org.gnome.desktop.sound theme-name 'freedesktop' && \
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup" && \
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga" && \
kwriteconfig6 --file kdeglobals --group Sounds --key Theme "freedesktop" && \
killall gnome-clocks 2>/dev/null; kquitapp6 kded6 && kded6 &
```

## Verification

After running the fix:

1. ✅ Sound file exists: `ls /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`
2. ✅ GNOME sounds enabled: `gsettings get org.gnome.desktop.sound event-sounds` = `true`
3. ✅ Sound theme set: `gsettings get org.gnome.desktop.sound theme-name` = `'freedesktop'`
4. ✅ Audio works: `paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`
5. ✅ Timer rings when it expires!

---

**Last Resort:** If nothing works, GNOME Clocks might have a bug on your system. Use KClock instead:

```bash
sudo apt install kclock
kclock
```

KClock is the native KDE clock app and will work perfectly with KDE Plasma 6's notification system.















