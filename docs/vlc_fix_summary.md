# VLC Fix Summary

## The Problem

VLC 3.0.21 on Debian Trixie/Bookworm crashes immediately with:
- "Could not find the Qt platform plugin xcb"
- "realloc(): invalid pointer"

## Root Causes

1. **Qt5 t64 ABI transition** - Debian moved to new time64 libraries
2. **Residual old Qt5 configs** from previous Debian versions
3. **Qt plugin path not set** - VLC can't find platform plugins
4. **Qt5/Wayland incompatibility** - VLC 3.0.x Qt GUI has memory corruption on Wayland

## What We Did

### Diagnosis

1. ✓ Verified VLC installed (version 3.0.21)
2. ✓ Identified missing Qt platform plugin error
3. ✓ Detected Wayland session (vs old X11)
4. ✓ Found residual old Qt5 packages (`libqt5gui5`, `libqt5core5a`)
5. ✓ Discovered memory corruption in Qt GUI even after fixes

### Fixes Applied

1. **Purged old Qt5 residual configs**:
   ```bash
   sudo dpkg --purge libqt5gui5 libqt5core5a libreoffice-qt5
   ```

2. **Set Qt plugin path in ~/.bashrc**:
   ```bash
   export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
   ```

3. **Cleaned VLC configs**:
   ```bash
   rm -rf ~/.config/vlc ~/.cache/vlc
   ```

4. **Reinstalled VLC**:
   ```bash
   sudo apt reinstall vlc-plugin-qt
   ```

### Result

**The Qt5 GUI still crashes** due to a known VLC 3.0.x bug on Wayland.

## Working Solutions

### Solution 1: Use cvlc (Command-Line VLC) ✓ WORKS

```bash
cvlc /path/to/video.mp4
```

This works perfectly - no crashes, full functionality.

### Solution 2: Use the vlc-cli wrapper

```bash
/home/oneking/Documents/public_github/closed_source-linux_fixes/bash/vlc-cli
```

### Solution 3: Create alias

Add to `~/.bashrc`:
```bash
alias vlc='cvlc'
```

### Solution 4: Desktop Launcher

The fix script created a desktop launcher:
```
~/.local/share/applications/vlc-fixed.desktop
```

Search for "VLC Media Player (Fixed)" in your app menu.

## What Doesn't Work

❌ **VLC Qt GUI on Wayland** - Known bug in VLC 3.0.x
- Setting `QT_PLUGIN_PATH` - helps find plugins but still crashes
- Setting `QT_QPA_PLATFORM=wayland` - still crashes
- Using `LIBGL_ALWAYS_SOFTWARE=1` - still crashes  
- Fresh config files - still crashes
- Reinstalling VLC - still crashes

The issue is in VLC's Qt5/Wayland integration itself.

## Long-Term Solution

**Wait for VLC 4.0** which will use Qt6 and have proper Wayland support.

OR

**Switch to X11 session** instead of Wayland (if you need the GUI).

OR

**Use MPV** as alternative:
```bash
sudo apt install mpv
mpv /path/to/video.mp4
```

## Files Created

- `bash/fix_vlc_quick.sh` - Applies environment fixes
- `bash/fix_vlc.sh` - Interactive fix script
- `bash/vlc_wrapper.sh` - Wrapper script
- `bash/vlc-cli` - Command-line launcher
- `docs/vlc_fix.md` - Detailed documentation

## Summary

**cvlc works perfectly** - this is the recommended solution until VLC 4.0 is released.

The Qt GUI crash is a known upstream bug, not fixable at the configuration level.

