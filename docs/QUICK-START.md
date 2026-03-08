# Elgato Camlink 4K - Quick Start Guide

## 🔴 CURRENT STATUS: Camlink NOT Detected

Your Camlink 4K is **not showing up in the USB devices list**. This means it's a hardware connection issue, not OBS configuration.

## ⚡ Quick Fix (Run These Commands)

### Step 1: Apply All Fixes
```bash
cd ~/Documents/public_github/closed_source-linux_fixes
bash/install.sh
```

This will install everything needed and configure your system.

**Note**: The Camlink will be configured as **VIDEO ONLY** - it won't interfere with your existing audio setup (mic/speakers will remain unchanged).

### Step 2: Connect Your Camlink
**IMPORTANT - Must do in this order:**

1. **Turn ON your HDMI source** (camera, console, etc.) ← CRITICAL!
2. **Ensure HDMI source is outputting signal** ← The Camlink won't enumerate without this!
3. **Plug Camlink into USB 3.0 port** (blue port)
4. **Wait 5 seconds**
5. **Check if detected:**
   ```bash
   lsusb | grep -i elgato
   ```

### Step 3: Monitor Connection
```bash
bash/monitor-camlink.sh
```

This will continuously watch for the Camlink and tell you when it's detected.

### Step 4: Use in OBS
Once detected:
1. Open **OBS Studio**
2. Click **+** in Sources
3. Select **Video Capture Device (V4L2)**
4. Choose **Cam Link 4K** from the dropdown
5. Set resolution to match your HDMI source (e.g., 1920x1080@60fps)

## 🚨 Most Common Issue

**The Camlink 4K REQUIRES an active HDMI signal to enumerate as a USB device.**

This means:
- Your camera/console/PC must be **powered ON**
- It must be **actively outputting HDMI**
- Try with a laptop or desktop as HDMI source first to test

## 📋 Files in This Project

**Documentation** (docs/):
- `QUICK-START.md` - This file - fast setup guide
- `README-CAMLINK-4K.md` - Complete troubleshooting documentation
- `OBS-CAMLINK-SETUP.md` - OBS configuration guide

**Scripts** (bash/):
- `install.sh` - Simple one-command installation
- `camlink-4k-fix.sh` - Full diagnostic script
- `apply-camlink-fixes.sh` - Apply all fixes automatically
- `monitor-camlink.sh` - Real-time monitoring
- `quick-diagnose.sh` - "Worked yesterday" diagnostic
- `disable-camlink-audio.sh` - Audio disable script

## 🔧 Manual Commands (if scripts don't work)

### Install packages:
```bash
sudo apt update
sudo apt install v4l-utils obs-studio
```

### Add user to video group:
```bash
sudo usermod -aG video $USER
# Then LOG OUT and LOG BACK IN
```

### Load kernel modules:
```bash
sudo modprobe uvcvideo
sudo modprobe videodev
sudo modprobe videobuf2_v4l2
```

### Create udev rule:
```bash
sudo tee /etc/udev/rules.d/50-elgato-camlink.rules > /dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", MODE="0666", GROUP="video"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Disable USB autosuspend:
```bash
sudo tee /etc/udev/rules.d/50-usb-camlink-power.rules > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", ATTR{power/autosuspend}="-1"
EOF

sudo udevadm control --reload-rules
```

### Configure UVC driver:
```bash
sudo tee /etc/modprobe.d/uvcvideo.conf > /dev/null <<'EOF'
options uvcvideo quirks=0x80
EOF
```

### Load modules at boot:
```bash
sudo tee /etc/modules-load.d/camlink.conf > /dev/null <<'EOF'
uvcvideo
videodev
videobuf2_v4l2
videobuf2_vmalloc
EOF
```

## ✅ Verification

After plugging in Camlink:

```bash
# Should show: Bus XXX Device XXX: ID 0fd9:0066 Elgato Systems GmbH Cam Link 4K
lsusb | grep -i elgato

# Should show Cam Link device
v4l2-ctl --list-devices

# Should show /dev/videoX devices
ls -l /dev/video*

# Check kernel messages
dmesg | tail -n 30
```

## 🆘 Still Not Working?

1. **Try different USB port** (USB 3.0 only, blue ports)
2. **Try different USB cable** (must be data cable, not just power)
3. **Try different HDMI source** (laptop, desktop, known-working device)
4. **Check HDMI cable** (try different cable)
5. **Update Camlink firmware** (requires Windows/Mac unfortunately)
6. **Check USB power**: `lsusb -v | grep -A 5 'Elgato'` (look for power draw)

## 📚 Full Documentation

See `docs/README-CAMLINK-4K.md` for complete troubleshooting guide.

## 🎯 Expected Result

When working correctly:

```bash
$ lsusb | grep -i elgato
Bus 001 Device 007: ID 0fd9:0066 Elgato Systems GmbH Cam Link 4K

$ v4l2-ctl --list-devices
Cam Link 4K: Cam Link 4K (usb-0000:00:14.0-1):
    /dev/video0
    /dev/video1
```

Then in OBS, you'll see "Cam Link 4K" in the device dropdown.

---

**Quick Summary**: 
1. Run `bash/install.sh`
2. Turn ON HDMI source
3. Plug in Camlink to USB 3.0
4. Run `bash/monitor-camlink.sh`
5. Open OBS and add Video Capture Device

