# Elgato Camlink 4K - Linux Fix Guide (Debian 13 / KDE)

## Problem
Elgato Camlink 4K not showing up in OBS Studio on Linux.

## Current Status
**The Camlink 4K is NOT detected by your system** - this is a hardware/connection issue, not a software issue.

## Critical Requirements for Camlink 4K

### 1. **ACTIVE HDMI Signal Required**
⚠️ **Most Important**: The Camlink 4K **will NOT enumerate as a USB device** unless it receives an **active HDMI signal**.

- Your HDMI source (camera, console, PC) must be **powered ON**
- HDMI source must be **outputting a signal**
- Try with a known-working HDMI source first (like a laptop)

### 2. **USB 3.0 Port Required**
- Must use USB 3.0 port (blue port on most systems)
- Preferably direct motherboard connection (not through USB hub)
- Some USB hubs don't provide enough power

### 3. **USB Cable Quality**
- Use the cable that came with Camlink, or a high-quality USB 3.0 cable
- Cable must support data transfer (not just power)

## Quick Diagnosis

### Check if Camlink is detected:
```bash
# Look for Elgato device (vendor ID: 0fd9)
lsusb | grep -i '0fd9\|elgato'
```

If you see output like:
```
Bus 001 Device 007: ID 0fd9:0066 Elgato Systems GmbH Cam Link 4K
```
Then it's connected! Proceed to "OBS Configuration" below.

If you see nothing, continue troubleshooting.

### Monitor USB detection in real-time:
```bash
# In one terminal, watch USB devices:
watch -n 1 'lsusb | grep -i elgato'

# In another terminal, watch kernel messages:
sudo dmesg -w
```

Then unplug and replug the Camlink. You should see messages.

## Automated Fix Scripts

### Quick Install (Recommended):
```bash
cd ~/Documents/public_github/closed_source-linux_fixes
bash/install.sh
```

### Full Diagnostic:
```bash
bash/camlink-4k-fix.sh
```

These scripts will:
- ✓ Check if Camlink is detected
- ✓ Install v4l-utils (if needed)
- ✓ Verify user permissions (video group)
- ✓ Load required kernel modules
- ✓ Create udev rules
- ✓ Check OBS installation
- ✓ Provide specific troubleshooting steps

**Audio Configuration**: The Camlink is configured as **VIDEO ONLY** - it will not interfere with your existing audio setup. Your default microphone and speakers will remain unchanged.

## Manual Fix Steps

### 1. Install Required Packages
```bash
sudo apt update
sudo apt install v4l-utils obs-studio
```

### 2. Add User to Video Group
```bash
sudo usermod -aG video $USER
# Then LOG OUT and LOG BACK IN (required!)
```

### 3. Load Required Kernel Modules
```bash
sudo modprobe uvcvideo
sudo modprobe videodev
sudo modprobe videobuf2_v4l2
```

### 4. Create udev Rule
Create `/etc/udev/rules.d/50-elgato-camlink.rules`:
```bash
sudo nano /etc/udev/rules.d/50-elgato-camlink.rules
```

Add these lines:
```
# Elgato Camlink 4K
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", MODE="0666", GROUP="video"
```

Reload udev:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 5. List Video Devices
```bash
v4l2-ctl --list-devices
ls -l /dev/video*
```

You should see something like:
```
Cam Link 4K: Cam Link 4K (usb-0000:00:14.0-1):
    /dev/video0
    /dev/video1
```

## OBS Configuration

### 1. Add Video Source
1. Open OBS Studio
2. Click **+** in Sources panel
3. Select **Video Capture Device (V4L2)**
4. Give it a name (e.g., "Camlink 4K")

### 2. Configure Device
- **Device**: Select `Cam Link 4K` or try each `/dev/video*`
- **Resolution/FPS**: Match your HDMI source
  - Common: 1920x1080 @ 30fps or 60fps
  - 4K: 3840x2160 @ 30fps (if source supports it)
- **Video Format**: YUYV 4:2:2 (most compatible)

### 3. If Multiple Video Devices
Try each `/dev/video0`, `/dev/video1`, etc. until you see your HDMI source.

## Testing Camera Outside OBS

### Using ffplay (from ffmpeg):
```bash
ffplay /dev/video0
```

### Using mpv:
```bash
mpv av://v4l2:/dev/video0
```

### Using GNOME Cheese:
```bash
sudo apt install cheese
cheese
```

### Check device capabilities:
```bash
v4l2-ctl -d /dev/video0 --all
v4l2-ctl -d /dev/video0 --list-formats-ext
```

## Common Issues & Solutions

### Issue 1: "No HDMI signal" in OBS
**Solution**: 
- Check HDMI source is ON and outputting
- Try different HDMI cable
- Check HDMI source resolution (some weird resolutions not supported)
- Try 1080p source first

### Issue 2: Camlink detected but no video in OBS
**Solution**:
- Make sure you selected the correct `/dev/video*` device
- Try different video format (YUYV, MJPEG)
- Restart OBS
- Check `dmesg | tail -n 50` for errors

### Issue 3: "Permission denied" errors
**Solution**:
```bash
# Check you're in video group:
groups | grep video

# If not, add yourself:
sudo usermod -aG video $USER
# Then LOG OUT and back in!

# Check device permissions:
ls -l /dev/video*
# Should show: crw-rw---- 1 root video
```

### Issue 4: Device appears then disappears
**Solution**:
- USB power issue - try different port
- HDMI signal dropping - check source
- USB cable issue - try different cable
- Check `dmesg` for USB errors

### Issue 5: Kernel driver issues
**Solution**:
```bash
# Check if uvcvideo module loaded:
lsmod | grep uvcvideo

# Force reload:
sudo modprobe -r uvcvideo
sudo modprobe uvcvideo

# Check kernel messages:
dmesg | grep -i uvc
```

## Monitoring Script

Monitor Camlink connection:
```bash
./monitor-camlink.sh
```

This will continuously watch for Camlink and show when it connects/disconnects.

## Firmware Updates

Elgato occasionally releases firmware updates that improve Linux compatibility:
1. Visit: https://www.elgato.com/en/downloads
2. Download "Cam Link 4K" software
3. Firmware updates require Windows/macOS (unfortunately)
4. After update, device should work better on Linux

## Known Working Configurations

- ✓ Debian 13 + Kernel 6.12 + OBS 30.2.3 + USB 3.0
- ✓ Ubuntu 24.04 + OBS Flatpak + USB 3.0
- ✓ Fedora 40 + OBS native + USB 3.0

## Alternative: Use HDMI Capture Card with Better Linux Support

If Camlink continues to be problematic, consider these alternatives with better Linux support:
- **Elgato HD60 S+** (better Linux drivers)
- **AVerMedia Live Gamer Portable 2 Plus**
- **Magewell USB Capture HDMI Gen 2** (best Linux support, expensive)

## Debug Information Collection

If still not working, collect this info for troubleshooting:
```bash
# Run and save output:
./camlink-4k-fix.sh > camlink-debug.txt 2>&1

# Also collect:
lsusb -v > lsusb-verbose.txt
dmesg > dmesg-full.txt
udevadm info --export-db > udev-db.txt
```

## Support Resources

- **Elgato Support**: https://help.elgato.com/
- **OBS Forums**: https://obsproject.com/forum/
- **Linux UVC Driver**: https://www.ideasonboard.org/uvc/

## Your Current System Info

- **OS**: Debian 13 (Trixie)
- **Kernel**: 6.12.48+deb13-amd64
- **Desktop**: KDE Plasma
- **OBS**: 30.2.3+dfsg-3 (from apt)
- **User Groups**: video ✓, cdrom ✓, audio ✓, plugdev ✓

## Next Steps

1. **Ensure HDMI source is ON and outputting signal** ← Most important!
2. **Plug Camlink into USB 3.0 port** (blue port)
3. **Run diagnostic**: `./camlink-4k-fix.sh`
4. **Check detection**: `lsusb | grep -i elgato`
5. **Open OBS** and add Video Capture Device
6. **Select Cam Link 4K** from device list

---

**Last Updated**: 2025-11-22  
**Script Version**: 1.0

