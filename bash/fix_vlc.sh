#!/bin/bash
# Fix VLC on Debian with Wayland
# This fixes "Could not find the Qt platform plugin xcb" error

echo "=== VLC Wayland Fix ==="
echo ""

# Check if running Wayland
SESSION_TYPE=$(echo $XDG_SESSION_TYPE)
echo "Current session type: $SESSION_TYPE"

if [ "$SESSION_TYPE" = "wayland" ]; then
    echo "  ✓ Wayland detected - applying fix"
else
    echo "  ⚠ Not running Wayland (running $SESSION_TYPE)"
    echo "  This fix is specifically for Wayland issues"
fi

echo ""
echo "Applying fixes..."

# Fix 1: Set Qt platform to Wayland
echo ""
echo "[1/3] Setting Qt platform environment variables..."
if ! grep -q "QT_QPA_PLATFORM=wayland" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Fix VLC on Wayland" >> ~/.bashrc
    echo "export QT_QPA_PLATFORM=wayland" >> ~/.bashrc
    echo "  ✓ Added to ~/.bashrc"
else
    echo "  - Already set in ~/.bashrc"
fi

# Also set for current session
export QT_QPA_PLATFORM=wayland

# Fix 2: Reset VLC config if corrupted
echo ""
echo "[2/3] Checking VLC configuration..."
if [ -d ~/.config/vlc ]; then
    echo "  Found VLC config directory"
    read -p "  Reset VLC config to defaults? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv ~/.config/vlc ~/.config/vlc.backup.$(date +%s)
        echo "  ✓ Old config backed up"
    else
        echo "  - Keeping existing config"
    fi
else
    echo "  - No existing config found"
fi

# Fix 3: Install missing packages if needed
echo ""
echo "[3/3] Verifying required packages..."
MISSING=""
if ! dpkg -l | grep -q "^ii.*qtwayland5"; then
    MISSING="$MISSING qtwayland5"
fi
if ! dpkg -l | grep -q "^ii.*qt6-wayland"; then
    MISSING="$MISSING qt6-wayland"
fi

if [ -n "$MISSING" ]; then
    echo "  Missing packages:$MISSING"
    echo "  Install with: sudo apt install$MISSING"
else
    echo "  ✓ All required packages installed"
fi

echo ""
echo "=== Testing VLC ==="
echo ""
echo "Attempting to launch VLC..."
timeout 3 vlc --qt-fullscreen-screennumber=-1 2>&1 | head -10 &
VLC_PID=$!
sleep 2

if ps -p $VLC_PID > /dev/null 2>&1; then
    echo "  ✓ VLC is running!"
    pkill vlc
else
    echo "  ✗ VLC failed to start"
    echo ""
    echo "  Try these additional fixes:"
    echo "    1. Restart your terminal/session"
    echo "    2. Run: source ~/.bashrc"
    echo "    3. Try: QT_QPA_PLATFORM=wayland vlc"
fi

echo ""
echo "=== Fix Complete ==="
echo ""
echo "To apply environment changes:"
echo "  1. Close and reopen your terminal, OR"
echo "  2. Run: source ~/.bashrc"
echo ""
echo "Then try running VLC normally"
echo ""

