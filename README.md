# Linux Hardware Fixes Collection

Collection of fixes and workarounds for hardware issues on Linux.

## Elgato Camlink 4K - OBS Not Detecting

### Problem
Elgato Camlink 4K not recognized in OBS Studio on Debian 13 / Linux.

### Quick Reference

```bash
# Show all commands and documentation
./camlink-help.sh
```

### Quick Fix

```bash
# Apply all fixes
bash/install.sh

# Monitor for Camlink connection
bash/monitor-camlink.sh
```

### Important Notes

⚠️ **The Camlink 4K requires an ACTIVE HDMI signal to enumerate as a USB device**
- Your HDMI source must be ON and outputting
- Must use USB 3.0 port (blue port)
- See docs/QUICK-START.md for step-by-step instructions

### Documentation

- **docs/QUICK-START.md** - Fast setup guide (start here!)
- **docs/README-CAMLINK-4K.md** - Complete troubleshooting documentation
- **docs/OBS-CAMLINK-SETUP.md** - OBS configuration guide

### Scripts

| Script | Purpose |
|--------|---------|
| `bash/install.sh` | Simple one-command installation |
| `bash/camlink-4k-fix.sh` | Full diagnostic - checks connection, permissions, drivers |
| `bash/apply-camlink-fixes.sh` | Applies all system fixes automatically |
| `bash/monitor-camlink.sh` | Monitors USB for Camlink connection in real-time |
| `bash/quick-diagnose.sh` | Quick diagnostic for "worked yesterday" issues |
| `bash/disable-camlink-audio.sh` | Disable Camlink audio (preserves your mic/speaker) |

### System Requirements

- Linux kernel 4.x+ (tested on 6.12)
- USB 3.0 port
- Active HDMI signal source
- v4l-utils package
- OBS Studio

### What Gets Fixed

✓ Installs v4l-utils and OBS Studio  
✓ Adds user to `video` group  
✓ Loads UVC video kernel modules  
✓ Creates udev rules for Camlink  
✓ Disables USB autosuspend  
✓ Configures UVC driver quirks  
✓ Sets modules to load at boot  

### Current Status

**Your Camlink is NOT detected** - This is a hardware connection issue.

See **docs/QUICK-START.md** for what to do next.

---

## Audio-Technica AT2020 USB - Set as Default Microphone

### Problem
Multiple microphones available (built-in, USB, etc.) causing confusion. Need AT2020 USB to be the ONLY and DEFAULT microphone.

### Quick Fix

```bash
# Run the automated configuration script
./set-at2020-default-mic.sh
```

### Manual Configuration

```bash
# Set AT2020 as default and disable built-in mic
wpctl set-default $(wpctl status | grep "Q1U dynamic microphone" | grep -oP '^\s*\K\d+' | head -1)
pactl set-card-profile alsa_card.pci-0000_00_1f.3 off
```

### Documentation

- **docs/AT2020-DEFAULT-MIC.md** - Complete setup and troubleshooting guide

### What Gets Fixed

✓ Sets AT2020 USB as the default microphone  
✓ Disables built-in audio card microphone  
✓ Creates persistent configuration  
✓ Ensures no other mics interfere  
✓ Works across reboots  

### Verification

```bash
# Check only AT2020 is available
wpctl status | grep -A 5 "Sources:"

# Should show ONLY: Q1U dynamic microphone
```

---

## KDE Plasma - Sound Notifications Not Working

### Problem
KDE Plasma notifications appear visually but don't play sounds. Clocks app timer expires silently.

### Quick Fix

```bash
# Run the automated fix script
./fix-kde-sounds.sh
```

Or configure manually:

```bash
# Install required packages
sudo apt install libnotify-bin sound-theme-freedesktop libcanberra-pulse

# Configure and restart
kwriteconfig5 --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup"
kwriteconfig5 --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
kquitapp5 kded5 && kded5 &

# Test
notify-send -u critical "Test" "If you hear this, it works!"
```

### Documentation

- **docs/KDE-SOUND-NOTIFICATIONS.md** - Complete guide with troubleshooting

### What Gets Fixed

✓ Installs notification sound packages  
✓ Configures Plasma notification sounds  
✓ Enables Clocks/KClock timer sounds  
✓ Sets system sound theme  
✓ Tests and verifies configuration  

---

## Slack Desktop - Not Opening (snapd Masked)

### Problem
Slack installed via Snap won't open because `snapd.service` is masked on Debian 13. Error: `cannot communicate with server: dial unix /run/snapd-snap.socket: connect: no such file or directory`.

### Quick Fix

```bash
# Unmask snapd, connect interfaces, update and launch Slack
./fix-slack-app.sh
```

### What Gets Fixed

✓ Unmasks and starts `snapd.service`  
✓ Connects required snap interfaces (desktop, audio, network, etc.)  
✓ Installs gnome content snap if missing  
✓ Updates Slack to the latest version  
✓ Launches Slack  

---

**Tested on**: Debian 13 (Trixie), Kernel 6.12.48, KDE Plasma  
**Created**: 2025-11-22  
**Updated**: 2026-03-05
