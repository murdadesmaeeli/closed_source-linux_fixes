#!/bin/bash
# Replace VLC menu entry with working version

echo "=== Replacing VLC KDE Menu Entry ==="
echo ""

# Kill any running VLC processes
echo "[1/3] Stopping all VLC processes..."
pkill -9 vlc 2>/dev/null
pkill -9 cvlc 2>/dev/null
sleep 1
if ps aux | grep -q "[v]lc"; then
    echo "  ⚠ Some VLC processes still running"
else
    echo "  ✓ All VLC processes stopped"
fi

# Copy system VLC desktop file and modify it
echo ""
echo "[2/3] Replacing VLC menu entry..."
if [ -f /usr/share/applications/vlc.desktop ]; then
    cp /usr/share/applications/vlc.desktop ~/.local/share/applications/vlc.desktop
    
    # Replace Exec line to use cvlc
    sed -i 's|^Exec=/usr/bin/vlc.*|Exec=env QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins /usr/bin/cvlc %U|' ~/.local/share/applications/vlc.desktop
    sed -i 's|^TryExec=/usr/bin/vlc|TryExec=/usr/bin/cvlc|' ~/.local/share/applications/vlc.desktop
    
    echo "  ✓ VLC menu entry updated to use cvlc"
else
    echo "  ✗ System VLC desktop file not found"
    exit 1
fi

# Remove old "fixed" version if it exists
[ -f ~/.local/share/applications/vlc-fixed.desktop ] && rm ~/.local/share/applications/vlc-fixed.desktop

# Update desktop database
echo ""
echo "[3/3] Updating desktop database..."
update-desktop-database ~/.local/share/applications/ 2>/dev/null && echo "  ✓ Standard database updated"

# Update KDE cache
if command -v kbuildsycoca6 &> /dev/null; then
    kbuildsycoca6 2>/dev/null && echo "  ✓ KDE6 cache updated"
elif command -v kbuildsycoca5 &> /dev/null; then
    kbuildsycoca5 2>/dev/null && echo "  ✓ KDE5 cache updated"
fi

echo ""
echo "=== Complete! ==="
echo ""
echo "The VLC menu entry now uses cvlc (the working version)."
echo "The original name 'VLC media player' is preserved."
echo ""
echo "You can now launch VLC from your application menu as normal!"
echo ""

