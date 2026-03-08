#!/bin/bash
# VLC wrapper to fix Qt5/Wayland issues on Debian
# Uses alternative interface to avoid Qt crashes

# Export required environment variables
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=wayland

# Try to run VLC with Qt interface first
# If it crashes, fall back to other interfaces
echo "Attempting to start VLC..."

# Method 1: Try with fresh config
if [ ! -d ~/.config/vlc ]; then
    /usr/bin/vlc "$@"
    exit $?
fi

# Method 2: Try disabling Qt and using GTK-style ncurses
echo "Using alternative interface mode..."
/usr/bin/cvlc --extraintf=http "$@" &
VLC_PID=$!

# Open browser to VLC's web interface if no files specified
if [ $# -eq 0 ]; then
    sleep 2
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:8080" 2>/dev/null
    fi
fi

# Keep script alive while VLC runs
wait $VLC_PID

