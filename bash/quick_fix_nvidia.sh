#!/bin/bash
# Quick non-interactive NVIDIA encoder fix
# Reloads NVIDIA kernel modules to fix encoder issues

echo "=== Quick NVIDIA Encoder Fix ==="

# Kill GPU-heavy processes first
echo "Checking for DaVinci Resolve or other GPU processes..."
pkill -9 resolve 2>/dev/null && echo "Killed DaVinci Resolve"

# Try to unload and reload modules
echo "Attempting to reload NVIDIA modules..."

# First, try without sudo (will fail but worth trying)
# Then show the sudo commands needed
echo ""
echo "The following commands need to be run with sudo:"
echo ""
echo "sudo modprobe -r nvidia_uvm"
echo "sudo modprobe -r nvidia_drm"  
echo "sudo modprobe -r nvidia_modeset"
echo "sudo modprobe -r nvidia"
echo "sleep 2"
echo "sudo modprobe nvidia"
echo "sudo modprobe nvidia_modeset"
echo "sudo modprobe nvidia_drm"
echo "sudo modprobe nvidia_uvm"
echo ""
echo "Or simply run:"
echo "  sudo bash -c 'modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia && sleep 2 && modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm'"
echo ""


