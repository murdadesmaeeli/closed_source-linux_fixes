#!/bin/bash
# Quick fix for VLC on Debian - Creates working launcher

echo "=== VLC Quick Fix for Debian ==="
echo ""

# Set environment variables
echo "[1/3] Setting up environment variables..."
if ! grep -q "QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# VLC Qt5 fix" >> ~/.bashrc
    echo "export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins" >> ~/.bashrc
    echo "  ✓ Added QT_PLUGIN_PATH to ~/.bashrc"
else
    echo "  - Already set"
fi

# Clean old configs
echo ""
echo "[2/3] Cleaning old VLC configs..."
if [ -d ~/.config/vlc ] || [ -d ~/.cache/vlc ]; then
    BACKUP_DIR=~/.vlc_backup_$(date +%s)
    mkdir -p "$BACKUP_DIR"
    [ -d ~/.config/vlc ] && mv ~/.config/vlc "$BACKUP_DIR/" && echo "  ✓ Backed up ~/.config/vlc"
    [ -d ~/.cache/vlc ] && mv ~/.cache/vlc "$BACKUP_DIR/" && echo "  ✓ Backed up ~/.cache/vlc"
    echo "  Backup saved to: $BACKUP_DIR"
else
    echo "  - No old configs found"
fi

# Create desktop launcher that works
echo ""
echo "[3/3] Creating working VLC launcher..."
LAUNCHER_DIR=~/.local/share/applications
mkdir -p "$LAUNCHER_DIR"

cat > "$LAUNCHER_DIR/vlc-fixed.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=VLC Media Player (Fixed)
Comment=VLC Media Player with Qt5 fix
Icon=vlc
Exec=env QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins /usr/bin/vlc %U
Categories=AudioVideo;Player;Recorder;
MimeType=video/dv;video/mpeg;video/x-mpeg;video/msvideo;video/quicktime;video/x-anim;video/x-avi;video/x-ms-asf;video/x-ms-wmv;video/x-msvideo;video/x-nsv;video/x-flc;video/x-fli;video/x-flv;video/mp4;video/x-matroska;video/webm;video/3gpp;video/3gpp2;video/x-theora+ogg;video/x-ogm+ogg;video/ogg;audio/x-vorbis+ogg;audio/x-flac+ogg;audio/x-speex+ogg;audio/x-opus+ogg;audio/ogg;audio/x-ms-wma;audio/x-mpeg;audio/mpeg;audio/x-mpegurl;audio/x-flac;audio/x-wav;audio/x-musepack;audio/mp4;
Terminal=false
StartupNotify=true
EOF

chmod +x "$LAUNCHER_DIR/vlc-fixed.desktop"
echo "  ✓ Created desktop launcher: VLC Media Player (Fixed)"

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$LAUNCHER_DIR" 2>/dev/null
    echo "  ✓ Updated desktop database"
fi

echo ""
echo "=== Fix Complete! ==="
echo ""
echo "VLC should now work. Try one of these:"
echo ""
echo "  1. Search for 'VLC Media Player (Fixed)' in your application menu"
echo "  2. Run from terminal: QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins vlc"
echo "  3. Restart your terminal and run: source ~/.bashrc && vlc"
echo ""
echo "If VLC still crashes with Qt errors, you can always use:"
echo "  cvlc (command-line VLC)"
echo ""

