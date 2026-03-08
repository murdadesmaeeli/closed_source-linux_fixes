# VLC Not Working on Debian Fix

## Problem
VLC Media Player fails to start on newer Debian versions (Bookworm/Trixie) with error:
```
qt.qpa.plugin: Could not find the Qt platform plugin "xcb" in ""
This application failed to start because no Qt platform plugin could be initialized.
```

OR crashes with:
```
realloc(): invalid pointer
```

## Root Cause
Multiple issues related to Debian's transition:
1. **Qt5 t64 ABI transition**: Debian moved from `libqt5gui5` to `libqt5gui5t64`
2. **Wayland vs X11**: Newer Debian uses Wayland by default
3. **Qt plugin path not set**: VLC can't find Qt5 platform plugins
4. **Old config files**: Configs from older Debian versions cause crashes

## Solutions

### Quick Fix (Recommended)

Run this script:

```bash
/home/oneking/Documents/public_github/closed_source-linux_fixes/bash/fix_vlc_quick.sh
```

This will:
- Set correct Qt plugin path
- Clean old configs
- Create a working desktop launcher

### Manual Fix

#### Option 1: Use Environment Variable

Run VLC with:

```bash
QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins vlc
```

Or add to your `~/.bashrc`:

```bash
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
```

#### Option 2: Clean Old Configs

```bash
rm -rf ~/.config/vlc ~/.cache/vlc
```

Then restart VLC.

#### Option 3: Purge Old Qt5 Residual Configs

```bash
dpkg -l | grep "^rc.*qt"  # List old configs
sudo dpkg --purge libqt5gui5 libqt5core5a  # Remove them
```

### Workaround: Use cvlc (Command-Line VLC)

If the GUI won't work, use:

```bash
cvlc /path/to/video.mp4
```

This works perfectly without the Qt GUI.

## Verification

After applying a fix, test VLC:

```bash
vlc --version
```

Should show:
```
VLC media player 3.0.21 Vetinari
```

## For Previous Debian Versions

If you upgraded from Debian 11 (Bullseye) or earlier:

1. **Purge residual configs**:
   ```bash
   sudo apt remove --purge vlc vlc-plugin-qt
   sudo apt autoremove
   ```

2. **Reinstall clean**:
   ```bash
   sudo apt install vlc
   ```

3. **Apply Qt plugin path fix** (see above)

## Desktop Launcher

The fix script creates a working launcher at:
```
~/.local/share/applications/vlc-fixed.desktop
```

Search for "VLC Media Player (Fixed)" in your application menu.

## Technical Details

### The t64 Transition

Debian Trixie (testing) underwent a 64-bit time_t transition affecting Qt5 and other libraries:
- Old: `libqt5gui5` → New: `libqt5gui5t64`
- Old: `libqt5core5a` → New: `libqt5core5t64`

Residual configuration files from old packages can conflict with new libraries.

### Qt Platform Plugins

VLC's Qt interface requires platform plugins:
- X11: `libqxcb.so`
- Wayland: `libqwayland-egl.so`

These are in `/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms/`

VLC may not find them without `QT_PLUGIN_PATH` set.

### Wayland Support

On Wayland sessions, you may also need:

```bash
export QT_QPA_PLATFORM=wayland
```

However, VLC 3.0.21's Qt5 interface has issues on Wayland, causing the "realloc(): invalid pointer" crash.

## Alternative: Use MPV

If VLC continues to have issues, consider MPV as an alternative:

```bash
sudo apt install mpv
```

MPV has excellent Wayland support and similar functionality.

## Known Issues

1. **Qt5 GUI crashes on Wayland**: This is a known bug in VLC 3.0.x on Wayland
2. **Memory corruption**: Related to Qt5/Wayland interaction
3. **Plugin discovery**: VLC doesn't search system Qt plugin paths by default

## Expected in VLC 4.0

VLC 4.0 (currently in development) will use Qt6 and have better Wayland support, which should resolve these issues.

## References

- [Debian t64 transition](https://wiki.debian.org/ReleaseGoals/64bit-time)
- [VLC Qt issues](https://code.videolan.org/videolan/vlc/-/issues)
- [Qt5 Wayland support](https://doc.qt.io/qt-5/wayland-and-qt.html)

