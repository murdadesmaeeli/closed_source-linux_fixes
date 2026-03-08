#!/bin/bash
# Apply all Camlink 4K fixes for Linux
# Run this AFTER plugging in the Camlink

set -e

echo "=========================================="
echo "Applying Camlink 4K Fixes for Linux"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running with sudo privileges available
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}This script requires sudo privileges.${NC}"
    echo "You may be prompted for your password."
    echo ""
fi

# 1. Install v4l-utils if not present
echo "=== Installing Required Packages ==="
if ! command -v v4l2-ctl &> /dev/null; then
    echo "Installing v4l-utils..."
    sudo apt update
    sudo apt install -y v4l-utils
    echo -e "${GREEN}✓ v4l-utils installed${NC}"
else
    echo -e "${GREEN}✓ v4l-utils already installed${NC}"
fi

if ! command -v obs &> /dev/null; then
    echo "OBS Studio not found. Installing..."
    sudo apt install -y obs-studio
    echo -e "${GREEN}✓ OBS Studio installed${NC}"
else
    echo -e "${GREEN}✓ OBS Studio already installed${NC}"
fi
echo ""

# 2. Add user to video group
echo "=== Configuring User Permissions ==="
CURRENT_USER=$(whoami)
if groups | grep -q '\bvideo\b'; then
    echo -e "${GREEN}✓ User '$CURRENT_USER' already in 'video' group${NC}"
else
    echo "Adding user '$CURRENT_USER' to 'video' group..."
    sudo usermod -aG video "$CURRENT_USER"
    echo -e "${YELLOW}⚠ You must LOG OUT and LOG BACK IN for this to take effect!${NC}"
fi
echo ""

# 3. Load kernel modules
echo "=== Loading Kernel Modules ==="
MODULES=("uvcvideo" "videodev" "videobuf2_v4l2" "videobuf2_vmalloc" "videobuf2_memops")
for mod in "${MODULES[@]}"; do
    if lsmod | grep -q "^$mod"; then
        echo -e "${GREEN}✓ $mod already loaded${NC}"
    else
        echo "Loading $mod..."
        sudo modprobe "$mod" 2>/dev/null && echo -e "${GREEN}✓ $mod loaded${NC}" || echo -e "${RED}✗ Failed to load $mod${NC}"
    fi
done
echo ""

# 4. Create udev rule
echo "=== Creating udev Rules ==="
UDEV_RULE="/etc/udev/rules.d/50-elgato-camlink.rules"
if [ -f "$UDEV_RULE" ]; then
    echo -e "${GREEN}✓ udev rule already exists${NC}"
else
    echo "Creating udev rule for Camlink 4K (video only, no audio changes)..."
    sudo tee "$UDEV_RULE" > /dev/null <<'EOF'
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
    echo -e "${GREEN}✓ udev rule created (video only, audio ignored)${NC}"
fi

echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger
echo -e "${GREEN}✓ udev rules reloaded${NC}"
echo ""

# 5. Make modules load at boot
echo "=== Configuring Modules to Load at Boot ==="
MODULES_CONF="/etc/modules-load.d/camlink.conf"
if [ -f "$MODULES_CONF" ]; then
    echo -e "${GREEN}✓ Module loading configuration already exists${NC}"
else
    echo "Creating module loading configuration..."
    sudo tee "$MODULES_CONF" > /dev/null <<'EOF'
# Load UVC video modules for Elgato Camlink
uvcvideo
videodev
videobuf2_v4l2
videobuf2_vmalloc
EOF
    echo -e "${GREEN}✓ Modules will load automatically at boot${NC}"
fi
echo ""

# 6. Fix USB power management (can cause disconnects)
echo "=== Disabling USB Autosuspend for Camlink ==="
USB_PM_RULES="/etc/udev/rules.d/50-usb-camlink-power.rules"
if [ -f "$USB_PM_RULES" ]; then
    echo -e "${GREEN}✓ USB power management rule already exists${NC}"
else
    echo "Creating USB power management rule..."
    sudo tee "$USB_PM_RULES" > /dev/null <<'EOF'
# Disable USB autosuspend for Elgato Camlink (prevents random disconnects)
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", ATTR{power/autosuspend}="-1"
EOF
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo -e "${GREEN}✓ USB autosuspend disabled for Camlink${NC}"
fi
echo ""

# 7. Increase uvcvideo quirks (some Camlinks need this)
echo "=== Configuring UVC Video Driver Quirks ==="
MODPROBE_CONF="/etc/modprobe.d/uvcvideo.conf"
if [ -f "$MODPROBE_CONF" ]; then
    echo -e "${GREEN}✓ UVC configuration already exists${NC}"
else
    echo "Creating UVC driver configuration..."
    sudo tee "$MODPROBE_CONF" > /dev/null <<'EOF'
# Quirks for Elgato Camlink 4K
# 0x80 = UVC_QUIRK_FIX_BANDWIDTH (helps with USB bandwidth issues)
options uvcvideo quirks=0x80
EOF
    echo -e "${YELLOW}⚠ UVC driver configuration created${NC}"
    echo -e "${YELLOW}  You may need to reboot for this to take effect${NC}"
fi
echo ""

# 8. Check if Camlink is currently connected
echo "=== Checking Current Connection ==="
CAMLINK=$(lsusb | grep '0fd9:0066' || lsusb | grep -i 'Elgato.*Cam.*Link' || true)
if [ -n "$CAMLINK" ]; then
    echo -e "${GREEN}✓ Camlink 4K detected:${NC}"
    echo "  $CAMLINK"
    echo ""
    
    # List video devices
    echo "Video devices:"
    if command -v v4l2-ctl &> /dev/null; then
        v4l2-ctl --list-devices || echo "  Unable to list devices"
    fi
    echo ""
    
    ls -l /dev/video* 2>/dev/null || echo "No /dev/video* devices found"
    echo ""
else
    echo -e "${RED}✗ Camlink 4K NOT currently detected${NC}"
    echo ""
    echo "Make sure:"
    echo "  1. Camlink is plugged into USB 3.0 port (blue)"
    echo "  2. HDMI source is ON and outputting signal"
    echo "  3. Using good quality USB cable"
    echo ""
    echo "Then run: bash/monitor-camlink.sh"
    echo ""
fi

# 9. Final summary
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "What was done:"
echo "  ✓ Installed v4l-utils and OBS Studio"
echo "  ✓ Added user to 'video' group"
echo "  ✓ Loaded required kernel modules"
echo "  ✓ Created udev rules for Camlink"
echo "  ✓ Configured modules to load at boot"
echo "  ✓ Disabled USB autosuspend for Camlink"
echo "  ✓ Applied UVC driver quirks"
echo ""
echo "Next steps:"
echo ""
echo "1. If you added user to video group for first time:"
echo "   ${YELLOW}LOG OUT and LOG BACK IN${NC} (or reboot)"
echo ""
echo "2. Plug in your Camlink 4K:"
echo "   - Use USB 3.0 port (blue)"
echo "   - Ensure HDMI source is ON"
echo "   - Run: bash/monitor-camlink.sh"
echo ""
echo "3. In OBS Studio:"
echo "   - Add Source → Video Capture Device (V4L2)"
echo "   - Select 'Cam Link 4K' from dropdown"
echo "   - Set resolution to match your HDMI source"
echo ""
echo "4. If still having issues:"
echo "   - Read: README-CAMLINK-4K.md"
echo "   - Run: bash/camlink-4k-fix.sh"
echo "   - Check dmesg: sudo dmesg | tail -n 50"
echo ""
echo "=========================================="

