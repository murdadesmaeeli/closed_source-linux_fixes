#!/bin/bash
# Quick diagnostic for "worked yesterday, broken today" issues

echo "═══════════════════════════════════════════════════════════"
echo "Camlink Quick Diagnostic - Worked Yesterday, Broken Today"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Most Common Causes When It Worked Yesterday:${NC}"
echo ""
echo "1. HDMI source is OFF or not outputting"
echo "2. USB cable came loose"
echo "3. Camlink plugged into different port"
echo "4. System update changed something"
echo "5. USB port lost power"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check 1: Is Camlink physically detected?
echo -e "${YELLOW}[1/6] Checking USB Detection...${NC}"
if lsusb | grep -q '0fd9:0066'; then
    echo -e "${GREEN}✓ Camlink 4K DETECTED in USB${NC}"
    CAMLINK_FOUND=true
elif lsusb | grep -qi 'elgato'; then
    echo -e "${GREEN}✓ Elgato device detected${NC}"
    lsusb | grep -i elgato
    CAMLINK_FOUND=true
else
    echo -e "${RED}✗ Camlink NOT detected in USB${NC}"
    CAMLINK_FOUND=false
fi
echo ""

if [ "$CAMLINK_FOUND" = false ]; then
    echo -e "${RED}PROBLEM: Camlink is not detected at all!${NC}"
    echo ""
    echo -e "${YELLOW}Quick Fixes to Try (IN THIS ORDER):${NC}"
    echo ""
    echo "1. Check HDMI Source:"
    echo "   → Is your camera/console/PC turned ON?"
    echo "   → Is it outputting HDMI? (check with another display)"
    echo "   → Camlink won't enumerate without active HDMI signal!"
    echo ""
    echo "2. Check USB Connection:"
    echo "   → Unplug Camlink from USB port"
    echo "   → Wait 5 seconds"
    echo "   → Plug back into SAME USB 3.0 port as yesterday"
    echo "   → Watch for LED on Camlink"
    echo ""
    echo "3. Try Different USB Port:"
    echo "   → Use USB 3.0 port (blue)"
    echo "   → Try port directly on motherboard (not hub)"
    echo ""
    echo "4. Check USB Cable:"
    echo "   → Make sure cable is fully inserted"
    echo "   → Try different USB cable if possible"
    echo ""
    echo "5. Power Cycle Everything:"
    echo "   → Turn off HDMI source"
    echo "   → Unplug Camlink"
    echo "   → Wait 10 seconds"
    echo "   → Turn on HDMI source (wait for it to boot)"
    echo "   → Plug in Camlink"
    echo ""
    echo -e "${BLUE}Monitor in real-time:${NC}"
    echo "   watch -n 1 'lsusb | grep -i elgato'"
    echo ""
    exit 1
fi

# Check 2: Kernel modules
echo -e "${YELLOW}[2/6] Checking Kernel Modules...${NC}"
if lsmod | grep -q uvcvideo; then
    echo -e "${GREEN}✓ uvcvideo module loaded${NC}"
else
    echo -e "${RED}✗ uvcvideo module NOT loaded${NC}"
    echo "  Loading module..."
    sudo modprobe uvcvideo
fi
echo ""

# Check 3: Video devices
echo -e "${YELLOW}[3/6] Checking Video Devices...${NC}"
if command -v v4l2-ctl &> /dev/null; then
    v4l2-ctl --list-devices | grep -A 3 -i 'cam.*link' && echo -e "${GREEN}✓ Camlink video device found${NC}" || echo -e "${YELLOW}⚠ Camlink not showing as video device${NC}"
else
    echo "v4l-utils not installed"
fi
echo ""

# Check 4: Permissions
echo -e "${YELLOW}[4/6] Checking Permissions...${NC}"
if groups | grep -q '\bvideo\b'; then
    echo -e "${GREEN}✓ User in 'video' group${NC}"
else
    echo -e "${RED}✗ User NOT in 'video' group${NC}"
    echo "  Run: sudo usermod -aG video $USER"
    echo "  Then LOG OUT and back in"
fi
echo ""

# Check 5: Recent system updates
echo -e "${YELLOW}[5/6] Checking Recent Updates...${NC}"
if [ -f /var/log/apt/history.log ]; then
    RECENT_UPDATES=$(grep -A 5 "Start-Date: $(date +%Y-%m-%d)" /var/log/apt/history.log 2>/dev/null || \
                     grep -A 5 "Start-Date: $(date -d yesterday +%Y-%m-%d)" /var/log/apt/history.log 2>/dev/null)
    if [ -n "$RECENT_UPDATES" ]; then
        echo -e "${YELLOW}⚠ Recent package updates found:${NC}"
        echo "$RECENT_UPDATES" | head -10
        echo ""
        echo "If kernel was updated, you may need to reboot."
    else
        echo "No recent updates detected"
    fi
else
    echo "Update log not accessible"
fi
echo ""

# Check 6: OBS process
echo -e "${YELLOW}[6/6] Checking OBS...${NC}"
if pgrep -x obs > /dev/null; then
    echo -e "${GREEN}✓ OBS is running${NC}"
    echo -e "${YELLOW}  → Try closing and reopening OBS${NC}"
else
    echo "OBS is not running"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo -e "${BLUE}Summary:${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "If Camlink is detected but not working in OBS:"
echo "  1. Close OBS completely"
echo "  2. Unplug/replug Camlink (with HDMI active!)"
echo "  3. Reopen OBS"
echo "  4. Re-add Video Capture Device source"
echo ""
echo "If Camlink is still not detected:"
echo "  1. Ensure HDMI source is ON and outputting"
echo "  2. Try different USB 3.0 port"
echo "  3. Reboot system"
echo ""

