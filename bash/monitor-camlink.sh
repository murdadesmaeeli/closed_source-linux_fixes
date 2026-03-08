#!/bin/bash
# Real-time Camlink 4K monitoring script
# This will continuously check if the Camlink is connected

echo "=========================================="
echo "Monitoring for Elgato Camlink 4K..."
echo "=========================================="
echo ""
echo "Vendor ID: 0fd9 (Elgato Systems)"
echo "Product ID: 0066 (Cam Link 4K)"
echo ""
echo "Instructions:"
echo "  1. Make sure HDMI source is ON"
echo "  2. Plug in Camlink 4K to USB 3.0 port"
echo "  3. Watch for detection below"
echo "  4. Press Ctrl+C to stop monitoring"
echo ""
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DETECTED=false
COUNTER=0

while true; do
    COUNTER=$((COUNTER + 1))
    CURRENT_TIME=$(date '+%H:%M:%S')
    
    # Check if Camlink is present
    CAMLINK=$(lsusb | grep '0fd9:0066' || lsusb | grep -i 'Elgato.*Cam.*Link')
    
    # Clear previous line
    echo -ne "\r\033[K"
    
    if [ -n "$CAMLINK" ]; then
        if [ "$DETECTED" = false ]; then
            # Just connected
            echo ""
            echo -e "${GREEN}[$CURRENT_TIME] ✓ CAMLINK 4K DETECTED!${NC}"
            echo "  $CAMLINK"
            echo ""
            
            # Show video devices
            echo "Checking video devices..."
            sleep 2  # Give system time to create video devices
            
            if command -v v4l2-ctl &> /dev/null; then
                v4l2-ctl --list-devices 2>/dev/null | grep -A 2 -i 'cam.*link' || echo "  (v4l2 devices not yet ready)"
            fi
            
            echo ""
            echo "Video device files:"
            ls -l /dev/video* 2>/dev/null
            echo ""
            
            echo -e "${YELLOW}Next steps:${NC}"
            echo "  1. Open OBS Studio"
            echo "  2. Add 'Video Capture Device (V4L2)' source"
            echo "  3. Select 'Cam Link 4K' from device dropdown"
            echo ""
            echo "Continuing to monitor..."
            echo ""
            DETECTED=true
        fi
        echo -ne "[$CURRENT_TIME] ${GREEN}● Connected${NC} - Scan #$COUNTER"
    else
        if [ "$DETECTED" = true ]; then
            # Just disconnected
            echo ""
            echo -e "${RED}[$CURRENT_TIME] ✗ CAMLINK 4K DISCONNECTED${NC}"
            echo ""
            DETECTED=false
        fi
        echo -ne "[$CURRENT_TIME] ${RED}○ Not detected${NC} - Scan #$COUNTER (waiting...)"
    fi
    
    sleep 1
done

