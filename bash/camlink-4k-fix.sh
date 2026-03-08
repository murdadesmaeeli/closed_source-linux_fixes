#!/bin/bash
# Elgato Camlink 4K Fix Script for Debian/Linux
# This script diagnoses and fixes common Camlink 4K issues

set -e

echo "========================================"
echo "Elgato Camlink 4K Diagnostic & Fix"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root (some commands need it)
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Warning: Running as root. Some checks will be skipped.${NC}"
    echo ""
fi

# 1. Check if Camlink is physically connected
echo "=== Step 1: Checking USB Connection ==="
echo "Looking for Elgato Camlink 4K (Vendor ID: 0fd9)..."
CAMLINK_USB=$(lsusb | grep -i '0fd9\|elgato' || true)

if [ -z "$CAMLINK_USB" ]; then
    echo -e "${RED}✗ Camlink 4K NOT detected via USB${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Ensure Camlink 4K is plugged into a USB 3.0 port (blue port)"
    echo "  2. Try a different USB port (preferably directly on motherboard)"
    echo "  3. Try a different USB cable"
    echo "  4. Check if Camlink power LED is on"
    echo "  5. Ensure HDMI source is connected and active"
    echo ""
    echo "All detected USB devices:"
    lsusb
    echo ""
    echo "After checking the above, unplug and replug the Camlink and run:"
    echo "  watch -n 1 'lsusb | grep -i elgato'"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ Camlink 4K detected:${NC}"
    echo "  $CAMLINK_USB"
fi
echo ""

# 2. Check kernel messages
echo "=== Step 2: Checking Kernel Messages ==="
echo "Recent dmesg output (checking for errors)..."
DMESG_OUT=$(dmesg 2>&1 | tail -n 100 | grep -i -E 'video|uvc|usb.*0fd9|cam.*link' || true)
if [ -n "$DMESG_OUT" ]; then
    echo "$DMESG_OUT"
else
    echo "No recent video/UVC related kernel messages (this might be OK if dmesg requires sudo)"
fi
echo ""

# 3. Check if v4l-utils is installed
echo "=== Step 3: Checking Video4Linux Tools ==="
if ! command -v v4l2-ctl &> /dev/null; then
    echo -e "${YELLOW}✗ v4l-utils not installed${NC}"
    echo "Installing v4l-utils..."
    sudo apt update
    sudo apt install -y v4l-utils
    echo -e "${GREEN}✓ v4l-utils installed${NC}"
else
    echo -e "${GREEN}✓ v4l-utils already installed${NC}"
fi
echo ""

# 4. List all video devices
echo "=== Step 4: Listing Video Devices ==="
if command -v v4l2-ctl &> /dev/null; then
    echo "Video devices detected by v4l2:"
    v4l2-ctl --list-devices || echo "Could not list devices"
    echo ""
    
    echo "Video device files:"
    ls -l /dev/video* 2>/dev/null || echo "No /dev/video* devices found"
    echo ""
    
    echo "Video device names:"
    for dev in /sys/class/video4linux/video*/name; do
        if [ -f "$dev" ]; then
            echo "  $(basename $(dirname $dev)): $(cat $dev)"
        fi
    done
fi
echo ""

# 5. Check user permissions
echo "=== Step 5: Checking Permissions ==="
CURRENT_USER=$(whoami)
if groups | grep -q '\bvideo\b'; then
    echo -e "${GREEN}✓ User '$CURRENT_USER' is in 'video' group${NC}"
else
    echo -e "${RED}✗ User '$CURRENT_USER' is NOT in 'video' group${NC}"
    echo "Adding user to video group..."
    sudo usermod -aG video "$CURRENT_USER"
    echo -e "${YELLOW}⚠ You must LOG OUT and LOG BACK IN for this to take effect${NC}"
fi
echo ""

# 6. Check kernel modules
echo "=== Step 6: Checking Kernel Modules ==="
REQUIRED_MODULES=("uvcvideo" "videodev" "videobuf2_core" "videobuf2_v4l2" "videobuf2_vmalloc")
for mod in "${REQUIRED_MODULES[@]}"; do
    if lsmod | grep -q "^$mod"; then
        echo -e "${GREEN}✓ $mod loaded${NC}"
    else
        echo -e "${YELLOW}⚠ $mod not loaded, attempting to load...${NC}"
        sudo modprobe "$mod" 2>/dev/null || echo -e "${RED}  Could not load $mod${NC}"
    fi
done
echo ""

# 7. Check if OBS is installed
echo "=== Step 7: Checking OBS Installation ==="
if command -v obs &> /dev/null; then
    OBS_VERSION=$(obs --version 2>&1 | head -n1 || echo "unknown")
    echo -e "${GREEN}✓ OBS installed: $OBS_VERSION${NC}"
    
    # Check if it's flatpak/snap
    if flatpak list 2>/dev/null | grep -q obs; then
        echo -e "${YELLOW}⚠ OBS is installed via Flatpak${NC}"
        echo "  Running: flatpak override com.obsproject.Studio --device=all --filesystem=/dev"
        flatpak override com.obsproject.Studio --device=all --filesystem=/dev
    elif snap list 2>/dev/null | grep -q obs; then
        echo -e "${YELLOW}⚠ OBS is installed via Snap${NC}"
        echo "  Running: sudo snap connect obs-studio:camera"
        sudo snap connect obs-studio:camera
    else
        echo "  OBS appears to be installed via package manager (good!)"
    fi
else
    echo -e "${RED}✗ OBS not found${NC}"
    echo "Install OBS Studio:"
    echo "  sudo apt update && sudo apt install obs-studio"
fi
echo ""

# 8. Create udev rule for Camlink
echo "=== Step 8: Creating udev Rule for Camlink 4K ==="
UDEV_RULE_FILE="/etc/udev/rules.d/50-elgato-camlink.rules"
if [ -f "$UDEV_RULE_FILE" ]; then
    echo -e "${GREEN}✓ udev rule already exists${NC}"
else
    echo "Creating udev rule..."
    sudo tee "$UDEV_RULE_FILE" > /dev/null <<'EOF'
# Elgato Camlink 4K
SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0066", MODE="0666", GROUP="video"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0066", MODE="0666", GROUP="video"
EOF
    echo -e "${GREEN}✓ udev rule created${NC}"
    echo "Reloading udev rules..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
fi
echo ""

# 9. Test camera with simple capture
echo "=== Step 9: Testing Camera Capture ==="
CAMLINK_DEV=""
for dev in /dev/video*; do
    if [ -c "$dev" ]; then
        DEV_INFO=$(udevadm info --query=all --name=$dev 2>/dev/null | grep 'ID_MODEL=' || true)
        if echo "$DEV_INFO" | grep -qi 'cam.*link\|elgato'; then
            CAMLINK_DEV="$dev"
            break
        fi
    fi
done

if [ -n "$CAMLINK_DEV" ]; then
    echo -e "${GREEN}✓ Camlink found at: $CAMLINK_DEV${NC}"
    echo "Testing with v4l2-ctl..."
    v4l2-ctl -d "$CAMLINK_DEV" --all 2>&1 | head -n 30
else
    echo -e "${YELLOW}⚠ Could not identify Camlink video device${NC}"
    echo "Available video devices:"
    for dev in /dev/video*; do
        if [ -c "$dev" ]; then
            echo "  $dev"
        fi
    done
fi
echo ""

# 10. Final summary
echo "========================================"
echo "Summary & Next Steps"
echo "========================================"
echo ""
echo "1. If Camlink is detected but not showing in OBS:"
echo "   - Open OBS Studio"
echo "   - Add Source → Video Capture Device (V4L2)"
echo "   - Select 'Cam Link 4K' or try each /dev/video device"
echo "   - Set resolution to match your HDMI source (e.g., 1920x1080)"
echo ""
echo "2. If Camlink is still not detected:"
echo "   - Ensure HDMI source is ON and outputting signal"
echo "   - Try different USB 3.0 port"
echo "   - Unplug/replug Camlink and run: dmesg | tail -n 50"
echo "   - Check Elgato firmware: https://www.elgato.com/en/downloads"
echo ""
echo "3. Common issues:"
echo "   - Camlink 4K REQUIRES an active HDMI signal to enumerate"
echo "   - Must use USB 3.0 port (blue port)"
echo "   - Some USB hubs don't provide enough power"
echo ""
echo "4. To test camera outside OBS:"
echo "   - ffplay /dev/videoX (where X is your Camlink device)"
echo "   - mpv av://v4l2:/dev/videoX"
echo "   - cheese (GNOME camera app)"
echo ""

