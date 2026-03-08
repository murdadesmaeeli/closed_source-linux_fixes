# NVIDIA Encoder Fix for OBS

## Problem
OBS Studio fails to load NVIDIA encoder with error "failed to load nvidia encoder"

## Root Cause
Driver version mismatch detected:
- **NVIDIA-SMI version**: 575.64.05  
- **Kernel Driver version**: 580.95.05

This mismatch prevents NVENC (NVIDIA Encoder) from working properly.

## Solutions (in order of preference)

### Solution 1: Reload NVIDIA Kernel Modules (Quick Fix)

Run this single command:

```bash
sudo bash -c 'modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia && sleep 2 && modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm'
```

Then test OBS immediately.

### Solution 2: Run the Fix Script

```bash
cd /home/oneking/Documents/public_github/closed_source-linux_fixes/bash
./fix_nvidia_encoder.sh
```

This script will:
1. Check for GPU processes
2. Reload NVIDIA modules (with your permission)
3. Verify driver status
4. Test NVENC availability

### Solution 3: Reboot (Most Reliable)

If the above doesn't work:

```bash
sudo reboot
```

A reboot ensures all kernel modules reload with matching versions.

## Verification

After applying a fix, verify NVENC is available:

```bash
# Check NVIDIA driver is working
nvidia-smi

# Check NVENC encoders are available
ffmpeg -hide_banner -encoders 2>/dev/null | grep nvenc
```

You should see encoders like:
- `h264_nvenc`
- `hevc_nvenc` 
- `av1_nvenc` (if supported)

## OBS Configuration

After fixing:

1. Open OBS Studio
2. Go to **Settings** > **Output**
3. Under **Recording** or **Streaming**:
   - Set **Encoder** to `NVIDIA NVENC H.264` (or HEVC)
4. Click **Apply** and **OK**

## Prevention

To prevent this issue in the future:

1. **Always reboot after NVIDIA driver updates**
2. **Don't kill Xorg/display server** while GPU processes are running
3. **Update drivers properly** using your package manager, not manual installs

## Additional Issues Found

- **DaVinci Resolve** was running hidden (consuming 6.8GB GPU memory)
- This can also interfere with OBS encoder access
- The resolve process has been terminated

## Technical Details

The mismatch occurs when:
- NVIDIA driver was updated but system wasn't rebooted
- Kernel modules are from old driver version
- Userspace tools (nvidia-smi) are from new driver version
- NVENC libraries can't communicate properly with kernel module

This is a common Linux/NVIDIA issue and typically requires either:
- Reloading kernel modules (temporary fix)
- Full system reboot (permanent fix)


