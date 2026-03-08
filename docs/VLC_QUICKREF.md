# Quick Reference - VLC Fix

## TL;DR - What Works

```bash
cvlc /path/to/video.mp4
```

or create an alias:

```bash
echo "alias vlc='cvlc'" >> ~/.bashrc
source ~/.bashrc
```

## The Problem

VLC GUI crashes on Debian Bookworm/Trixie with:
- Qt platform plugin errors
- Memory corruption (realloc(): invalid pointer)

## Why?

VLC 3.0.x Qt5 GUI is incompatible with Wayland (Debian's new default).

## Quick Fixes

### Option 1: Use cvlc (Recommended)
```bash
cvlc video.mp4
```
Works perfectly, same functionality, no GUI needed for playback.

### Option 2: Replace KDE menu entry (Recommended for GUI users)
```bash
/home/oneking/Documents/public_github/closed_source-linux_fixes/bash/replace_vlc_menu.sh
```
This makes the regular VLC menu entry use cvlc automatically.

### Option 3: Run fix script
```bash
/home/oneking/Documents/public_github/closed_source-linux_fixes/bash/fix_vlc_quick.sh
```

### Option 4: Set environment variable
```bash
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
```
(Note: May not fully fix GUI on Wayland)

### Option 5: Use alternative player
```bash
sudo apt install mpv
mpv video.mp4
```

## Full Documentation

See: `docs/vlc_fix.md` and `docs/vlc_fix_summary.md`

