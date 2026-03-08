# 2026-03-03: Cursor GPU Acceleration on Linux (Electron 39 / Chromium 134)

## The Problem

Cursor was using 90-150% CPU at idle because its GPU process was crashing on launch, forcing all UI rendering onto the CPU (software rendering). This caused ~15W of unnecessary power draw on battery.

## Root Causes Found

### 1. `--use-gl=egl` crashes the GPU process

Electron 39 ships Chromium 134 which uses **ANGLE** (Almost Native Graphics Layer Engine) exclusively. The old `--use-gl=egl` flag maps to `gl=egl-gles2,angle=none` which is no longer in the allowed implementations list:

```
Requested GL implementation (gl=egl-gles2,angle=none) not found in allowed implementations:
  [(gl=egl-angle,angle=opengl),(gl=egl-angle,angle=opengles),
   (gl=egl-angle,angle=vulkan),(gl=egl-angle,angle=swiftshader)]
Exiting GPU process due to errors during initialization
```

Every GPU process launch attempt failed immediately, Chromium retried a few times, then gave up and fell back to software rendering. This is invisible to the user -- no error dialog, no warning, just silently high CPU.

**Fix:** Remove `--use-gl=egl` entirely. Let ANGLE auto-detect the backend (it picks OpenGL ES on Intel Mesa, which works).

### 2. `ELECTRON_EXTRA_LAUNCH_ARGS` does not exist

This env var is commonly recommended online but is **not a real Electron/Chromium environment variable**. Setting it has zero effect -- the flags inside it are silently ignored. Flags must be passed as direct command-line arguments.

### 3. `cursor-flags.conf` is NOT read by Cursor AppImage (proven)

The Electron flags file (`~/.config/cursor-flags.conf`) is **completely ignored** by the Cursor AppImage. Sandbox test: launched AppImage with 5 flags in cursor-flags.conf and zero cmdline flags -- none of the cursor-flags.conf entries appeared in `/proc/PID/cmdline`. Direct command-line args are the only way to pass Chromium flags.

### 4. GPU works by default without any GPU flags

Sandbox test: launched Cursor AppImage with NO GPU flags at all (no `--ignore-gpu-blocklist`, no `--enable-gpu-rasterization`, etc.) -- GPU process initialized successfully, DRI fd was open, 0 errors. The GPU flags are nice-to-have optimizations, but the critical fix is simply **not passing `--use-gl=egl`** which was the only thing crashing the GPU process.

### 5. KDE truncates complex `.desktop` Exec lines

An `Exec=` line with `env` setting multiple environment variables plus multiple flags gets partially parsed by KDE's desktop file handler. Only the first env var and first few args survived. The rest were silently dropped.

**Fix:** `.desktop` file should call a wrapper script that handles env vars and flags internally:

```ini
Exec=/home/user/.local/bin/cursor %F
```

## What Works (Verified via Sandbox Testing)

Sandbox methodology: launch a separate Cursor AppImage instance with `--user-data-dir=/tmp/test`, check for GPU errors in stderr, verify DRI file descriptors, and inspect `/proc/PID/cmdline` and `/proc/PID/environ`. No need to restart the real Cursor repeatedly.

### Correct wrapper script (`~/.local/bin/cursor`)

```bash
#!/bin/bash
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export MESA_LOADER_DRIVER_OVERRIDE=iris
exec ~/Applications/Cursor.AppImage \
    --ozone-platform=wayland \
    --enable-wayland-ime \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    "$@"
```

### What each flag/env var does

| Flag/Env | Purpose |
|---|---|
| `ELECTRON_OZONE_PLATFORM_HINT=wayland` | Tells Electron to prefer Wayland (fallback hint) |
| `__EGL_VENDOR_LIBRARY_FILENAMES=.../50_mesa.json` | Forces Mesa's EGL (Intel iGPU), not NVIDIA's |
| `MESA_LOADER_DRIVER_OVERRIDE=iris` | Forces Intel Iris driver specifically |
| `--ozone-platform=wayland` | Native Wayland rendering (no XWayland overhead) |
| `--enable-wayland-ime` | Input method support on Wayland |
| `--ignore-gpu-blocklist` | Override Chromium's GPU driver blocklist |
| `--enable-gpu-rasterization` | GPU-accelerated page rasterization |
| `--enable-zero-copy` | Avoid CPU-side buffer copies for GPU textures |

### What NOT to use

| Bad Flag | Why |
|---|---|
| `--use-gl=egl` | Crashes GPU process on Chromium 134+ (ANGLE-only) |
| `--use-gl=angle --use-angle=opengl` | Parsed as `gl=none,angle=none` by Electron -- crashes |
| `ELECTRON_EXTRA_LAUNCH_ARGS="..."` | Not a real env var, silently ignored |
| `--disable-gpu` | Forces software rendering (people add this to "fix" crashes, making things worse) |
| `disable-hardware-acceleration: true` in `argv.json` or `settings.json` | Same effect as --disable-gpu |

## How to Verify GPU Acceleration is Working

```bash
# 1. Check for a gpu-process
pgrep -af "mount_Cursor" | grep "gpu-process"

# 2. Check DRI file descriptors (should show /dev/dri/renderD128 = Intel)
for pid in $(pgrep -f "mount_Cursor"); do
    ls -la /proc/$pid/fd 2>/dev/null | grep dri
done

# 3. Check total CPU (should be <20% idle, not 90-150%)
ps aux | grep -i "[c]ursor" | awk '{sum+=$3} END {printf "%.1f%%\n", sum}'

# 4. Check for GPU init errors
# Launch with --enable-logging and check stderr for "Exiting GPU process"
```

## Sandbox Testing Results

| Test | cursor-flags.conf | Cmdline flags | GPU errors | DRI fd | CPU |
|---|---|---|---|---|---|
| flags-conf-only | 5 flags in file | none | 0 | YES | 30% |
| cmdline-only | file removed | all 5 flags | 0 | YES | 30% |
| both | 5 flags + cmdline | all 5 flags | 0 | YES | 31% |
| chromium comparison | n/a | all flags | 0 | YES | - |

All tests used separate `--user-data-dir` and `--enable-logging` to capture stderr. CPU numbers are during startup (settles to ~5-10% idle). All 4 configurations produce identical GPU results.

## Sandbox Testing Method

To test GPU flags without restarting Cursor:

```bash
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export MESA_LOADER_DRIVER_OVERRIDE=iris

~/Applications/Cursor.AppImage \
    --ozone-platform=wayland \
    --enable-wayland-ime \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --enable-logging \
    --user-data-dir=/tmp/cursor-gpu-test \
    2>/tmp/cursor-gpu-test.log &

sleep 8

# Check results
grep "Exiting GPU" /tmp/cursor-gpu-test.log    # should return nothing
grep "gl_factory" /tmp/cursor-gpu-test.log      # should return nothing

# Check process has DRI fds
for pid in $(pgrep -f "cursor-gpu-test"); do
    ls -la /proc/$pid/fd 2>/dev/null | grep dri
done

# Cleanup
pkill -f "cursor-gpu-test"
rm -rf /tmp/cursor-gpu-test /tmp/cursor-gpu-test.log
```

## KDE Desktop File Notes

KDE launches apps via `systemd --user` transient services. To verify what KDE actually executes:

```bash
systemctl --user show app-cursor@*.service | grep ExecStart
```

After editing `.desktop` files, rebuild the KDE cache:

```bash
kbuildsycoca6 --noincremental
```

## System Info

- Laptop: ASUS ROG Strix G16 (G614JVR)
- GPUs: Intel Raptor Lake UHD (iGPU) + NVIDIA RTX 4060 Max-Q (dGPU)
- Compositor: KDE Plasma 6 / kwin_wayland
- Cursor version: 2.4.28 (Electron 39.2.7 / Chromium ~134)
- OS: Debian 13 (trixie)
- Display server: Wayland
