# DaVinci Resolve Fixes for Linux (Hybrid Graphics)

## Problem 1: "GPU Memory Full" Error (False Positive)

### Symptoms
- DaVinci Resolve shows "Your GPU memory is full" error
- `nvidia-smi` shows plenty of free GPU memory
- Logs show: `Failed to register OpenGL object for CUDA interop: cudaErrorUnknown`

### Cause
On laptops with hybrid graphics (Intel + NVIDIA), there's a CUDA/OpenGL interop conflict. Resolve tries to use CUDA on NVIDIA but OpenGL defaults to Intel, causing the false "out of memory" error.

### Solution
Force Resolve to use NVIDIA for both OpenGL and CUDA:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia /opt/resolve/bin/resolve
```

---

## Problem 2: Crash After `apt upgrade` (Qt5 Conflict)

### Symptoms
- Resolve crashes immediately on startup
- Log shows crash in `libqsqlite.so` or Qt5 SQL functions
- Started happening after running `apt upgrade`

### Cause
System Qt5 libraries were updated but are incompatible with Resolve's bundled Qt5.

### Solution
Force Resolve to use its own Qt plugins:

```bash
QT_PLUGIN_PATH=/opt/resolve/libs /opt/resolve/bin/resolve
```

---

## Combined Fix: Launcher Script

Create `~/.local/bin/resolve-fixed`:

```bash
#!/bin/bash
# DaVinci Resolve launcher with fixes for:
# 1. Qt5 plugin conflict (after apt upgrades)
# 2. CUDA/OpenGL interop on hybrid graphics

export QT_PLUGIN_PATH=/opt/resolve/libs
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

exec /opt/resolve/bin/resolve "$@"
```

Make it executable:
```bash
chmod +x ~/.local/bin/resolve-fixed
```

---

## Desktop Launcher Fix

Edit `~/.local/share/applications/com.blackmagicdesign.resolve.desktop`:

```ini
Exec=env QT_PLUGIN_PATH=/opt/resolve/libs __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia /opt/resolve/bin/resolve %U
```

---

## Verification

Check GPU is being used correctly:
```bash
nvidia-smi
```

You should see `/opt/resolve/bin/resolve` in the process list with GPU memory allocated.

---

## Environment Variables Explained

| Variable | Purpose |
|----------|---------|
| `QT_PLUGIN_PATH=/opt/resolve/libs` | Use Resolve's bundled Qt plugins |
| `__NV_PRIME_RENDER_OFFLOAD=1` | Force app to render on NVIDIA GPU |
| `__GLX_VENDOR_LIBRARY_NAME=nvidia` | Force NVIDIA for OpenGL |
| `__VK_LAYER_NV_optimus=NVIDIA_only` | Force NVIDIA for Vulkan |
