#!/bin/bash
# One-command fix for NVIDIA encoder issue
# Run with: sudo ./fix_now.sh

if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo:"
    echo "  sudo $0"
    exit 1
fi

echo "=== Fixing NVIDIA Encoder ==="
echo ""

# Kill DaVinci Resolve if running
echo "[1/4] Killing DaVinci Resolve processes..."
pkill -9 resolve 2>/dev/null && echo "  ✓ Killed DaVinci Resolve" || echo "  - No DaVinci Resolve running"

# Wait a moment
sleep 1

# Unload NVIDIA modules
echo ""
echo "[2/4] Unloading NVIDIA kernel modules..."
modprobe -r nvidia_uvm 2>/dev/null
modprobe -r nvidia_drm 2>/dev/null
modprobe -r nvidia_modeset 2>/dev/null
modprobe -r nvidia 2>/dev/null
echo "  ✓ Modules unloaded"

# Wait for unload
sleep 2

# Reload NVIDIA modules
echo ""
echo "[3/4] Reloading NVIDIA kernel modules..."
modprobe nvidia
modprobe nvidia_modeset
modprobe nvidia_drm
modprobe nvidia_uvm
echo "  ✓ Modules reloaded"

# Verify
echo ""
echo "[4/4] Verifying NVIDIA driver..."
sleep 1
if nvidia-smi > /dev/null 2>&1; then
    echo "  ✓ NVIDIA driver is working!"
    echo ""
    nvidia-smi --query-gpu=driver_version,name --format=csv,noheader
else
    echo "  ✗ Driver not responding - you may need to reboot"
    exit 1
fi

echo ""
echo "=== Fix Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Open OBS Studio"
echo "  2. Go to Settings > Output"
echo "  3. Select 'NVIDIA NVENC H.264' as encoder"
echo "  4. Test recording/streaming"
echo ""
echo "If OBS still can't find the encoder, run: sudo reboot"
echo ""


