#!/bin/bash
# Fix NVIDIA encoder for OBS
# This script resolves issues with NVIDIA NVENC encoder not loading

echo "=== NVIDIA Encoder Fix Script ==="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please run this script WITHOUT sudo (it will prompt when needed)"
    exit 1
fi

# Step 1: Kill any processes using the GPU heavily
echo "Step 1: Checking for GPU-intensive processes..."
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | while IFS=',' read pid name mem; do
    if [ ! -z "$pid" ]; then
        echo "  Found: $name (PID: $pid, Memory: $mem)"
    fi
done

# Step 2: Unload and reload NVIDIA modules
echo ""
echo "Step 2: Reloading NVIDIA kernel modules..."
echo "  This will temporarily disable your GPU (screen may flicker)"
read -p "  Continue? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia
    sleep 2
    sudo modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm
    echo "  ✓ Modules reloaded"
else
    echo "  Skipped module reload"
fi

# Step 3: Verify driver status
echo ""
echo "Step 3: Verifying NVIDIA driver status..."
if nvidia-smi > /dev/null 2>&1; then
    echo "  ✓ NVIDIA driver is working"
    nvidia-smi --query-gpu=driver_version,name --format=csv,noheader
else
    echo "  ✗ NVIDIA driver is NOT responding properly"
    echo "  You may need to reboot your system"
fi

# Step 4: Check for driver/module mismatch
echo ""
echo "Step 4: Checking for version mismatches..."
SMI_VERSION=$(nvidia-smi | grep "Driver Version:" | awk '{print $6}')
MODULE_VERSION=$(cat /proc/driver/nvidia/version 2>/dev/null | grep "Kernel Module" | awk '{print $8}')
echo "  NVIDIA-SMI version: $SMI_VERSION"
echo "  Kernel module version: $MODULE_VERSION"

if [ "$SMI_VERSION" != "$MODULE_VERSION" ]; then
    echo "  ⚠ WARNING: Version mismatch detected!"
    echo "  This is likely why OBS can't load the encoder"
    echo "  Recommended: Reboot your system to reload matching kernel modules"
fi

# Step 5: Test NVENC availability
echo ""
echo "Step 5: Testing NVENC encoder availability..."
if command -v ffmpeg &> /dev/null; then
    if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q nvenc; then
        echo "  ✓ NVENC encoders are available to ffmpeg"
        ffmpeg -hide_banner -encoders 2>/dev/null | grep nvenc
    else
        echo "  ✗ NVENC encoders NOT found"
    fi
else
    echo "  (ffmpeg not installed, skipping test)"
fi

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Next steps:"
echo "  1. If version mismatch was detected: REBOOT YOUR SYSTEM"
echo "  2. After reboot (or if no mismatch): Start OBS and test"
echo "  3. In OBS: Settings > Output > Recording > Encoder should show NVIDIA NVENC options"
echo ""


