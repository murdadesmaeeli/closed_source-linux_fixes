#!/bin/bash
# Manual installation commands for Camlink 4K fix
# Copy and paste these commands into your terminal

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║  CAMLINK 4K FIX - MANUAL INSTALLATION COMMANDS                   ║
║  Copy and paste these commands into your terminal                ║
╚══════════════════════════════════════════════════════════════════╝

These commands will configure your system for Camlink 4K (VIDEO ONLY).
Your audio setup (mic/speakers) will NOT be changed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 1: Install Required Packages
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo apt update
sudo apt install -y v4l-utils obs-studio

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 2: Load Kernel Modules
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo modprobe uvcvideo
sudo modprobe videodev
sudo modprobe videobuf2_v4l2
sudo modprobe videobuf2_vmalloc

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 3: Create udev Rules (VIDEO ONLY - Audio Disabled)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo tee /etc/udev/rules.d/50-elgato-camlink.rules > /dev/null << 'UDEV_EOF'
# Elgato Camlink 4K (0fd9:0066) - Video device only
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", MODE="0666", GROUP="video"

# Elgato Camlink Pro (0fd9:006c) - Video device only
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="006c", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE="0666", GROUP="video"

# Prevent Camlink from being used as audio device
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PULSE_IGNORE}="1"
UDEV_EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 4: Disable USB Autosuspend for Camlink
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo tee /etc/udev/rules.d/50-usb-camlink-power.rules > /dev/null << 'POWER_EOF'
# Disable USB autosuspend for Elgato Camlink (prevents random disconnects)
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", ATTR{power/autosuspend}="-1"
POWER_EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 5: Block Camlink Audio (PulseAudio/PipeWire)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo tee /etc/udev/rules.d/89-camlink-no-audio.rules > /dev/null << 'AUDIO_EOF'
# Prevent Elgato Camlink from being used as audio device
# This preserves your existing mic/speaker setup

# Camlink 4K
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PIPEWIRE_IGNORE}="1"

# Camlink Pro
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PIPEWIRE_IGNORE}="1"
AUDIO_EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 6: Configure UVC Driver Quirks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo tee /etc/modprobe.d/uvcvideo.conf > /dev/null << 'QUIRKS_EOF'
# Quirks for Elgato Camlink 4K
# 0x80 = UVC_QUIRK_FIX_BANDWIDTH (helps with USB bandwidth issues)
options uvcvideo quirks=0x80
QUIRKS_EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 7: Load Modules at Boot
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo tee /etc/modules-load.d/camlink.conf > /dev/null << 'MODULES_EOF'
# Load UVC video modules for Elgato Camlink
uvcvideo
videodev
videobuf2_v4l2
videobuf2_vmalloc
MODULES_EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STEP 8: Reload udev Rules
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sudo udevadm control --reload-rules
sudo udevadm trigger

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DONE! Now Connect Your Camlink:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Turn ON your HDMI source (camera/console)
2. Plug Camlink into USB 3.0 port (blue port)
3. Wait 5 seconds
4. Check detection:

   lsusb | grep -i elgato

   Should show: "ID 0fd9:0066 Elgato Systems GmbH Cam Link 4K"

5. Monitor for connection:

   cd ~/Documents/public_github/closed_source-linux_fixes
   bash/monitor-camlink.sh

6. Open OBS and add "Video Capture Device (V4L2)"
   Select "Cam Link 4K"
   UNCHECK any audio options

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your mic and speaker sources will remain unchanged! ✓

EOF

