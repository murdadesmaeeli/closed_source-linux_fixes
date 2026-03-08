#!/bin/bash
# Camlink 4K Installation Script
# Preserves your existing audio setup (one mic, one speaker)
# Run with: ./install.sh

set -e

echo "Installing Camlink 4K support (VIDEO ONLY - Audio preserved)..."
echo ""

# Install packages
echo "Step 1/8: Installing packages..."
sudo apt update
sudo apt install -y v4l-utils obs-studio
echo "✓ Packages installed"
echo ""

# Load kernel modules
echo "Step 2/8: Loading kernel modules..."
sudo modprobe uvcvideo
sudo modprobe videodev
sudo modprobe videobuf2_v4l2
sudo modprobe videobuf2_vmalloc
echo "✓ Modules loaded"
echo ""

# Create udev rules for video
echo "Step 3/8: Creating udev rules..."
sudo tee /etc/udev/rules.d/50-elgato-camlink.rules > /dev/null << 'EOF'
# Elgato Camlink 4K (0fd9:0066) - Video device only
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", MODE="0666", GROUP="video"

# Elgato Camlink Pro (0fd9:006c) - Video device only
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="006c", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE="0666", GROUP="video"

# Prevent Camlink from being used as audio device
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PULSE_IGNORE}="1"
EOF
echo "✓ udev rules created"
echo ""

# Disable USB autosuspend
echo "Step 4/8: Disabling USB autosuspend..."
sudo tee /etc/udev/rules.d/50-usb-camlink-power.rules > /dev/null << 'EOF'
# Disable USB autosuspend for Elgato Camlink (prevents random disconnects)
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", ATTR{power/autosuspend}="-1"
EOF
echo "✓ USB autosuspend disabled"
echo ""

# Block Camlink audio
echo "Step 5/8: Blocking Camlink audio (preserving your mic/speaker setup)..."
sudo tee /etc/udev/rules.d/89-camlink-no-audio.rules > /dev/null << 'EOF'
# Prevent Elgato Camlink from being used as audio device
# This preserves your existing mic/speaker setup

# Camlink 4K
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", ENV{PIPEWIRE_IGNORE}="1"

# Camlink Pro
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PULSE_IGNORE}="1"
SUBSYSTEM=="sound", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", ENV{PIPEWIRE_IGNORE}="1"
EOF
echo "✓ Camlink audio blocked"
echo ""

# Configure UVC quirks
echo "Step 6/8: Configuring UVC driver..."
sudo tee /etc/modprobe.d/uvcvideo.conf > /dev/null << 'EOF'
# Quirks for Elgato Camlink 4K
# 0x80 = UVC_QUIRK_FIX_BANDWIDTH (helps with USB bandwidth issues)
options uvcvideo quirks=0x80
EOF
echo "✓ UVC driver configured"
echo ""

# Load modules at boot
echo "Step 7/8: Configuring boot modules..."
sudo tee /etc/modules-load.d/camlink.conf > /dev/null << 'EOF'
# Load UVC video modules for Elgato Camlink
uvcvideo
videodev
videobuf2_v4l2
videobuf2_vmalloc
EOF
echo "✓ Boot modules configured"
echo ""

# Reload udev
echo "Step 8/8: Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger
echo "✓ udev reloaded"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✓ Installation Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Your audio setup is PRESERVED:"
echo "  • Mic source: unchanged"
echo "  • Speaker source: unchanged"
echo "  • Camlink: VIDEO ONLY"
echo ""
echo "Next steps:"
echo "  1. Turn ON your HDMI source (camera/console)"
echo "  2. Plug Camlink into USB 3.0 port (blue port)"
echo "  3. Run: bash/monitor-camlink.sh"
echo "  4. Open OBS → Add 'Video Capture Device (V4L2)'"
echo "     → Select 'Cam Link 4K'"
echo "     → UNCHECK any audio options"
echo ""
echo "Check detection: lsusb | grep -i elgato"
echo ""

