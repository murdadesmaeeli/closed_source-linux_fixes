#!/bin/bash
#===============================================================================
# set-laptop-audio.sh
# Sets the laptop's built-in speaker and microphone as default audio devices
# - Enables the built-in Intel PCH audio card (if disabled)
# - Sets analog stereo duplex profile (speaker + mic)
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

WIREPLUMBER_CONF_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
DISABLE_BUILTIN_CONF="$WIREPLUMBER_CONF_DIR/50-disable-builtin-mic.conf"
INTEL_CARD="alsa_card.pci-0000_00_1f.3"

echo "=============================================="
echo "  Setting Laptop Audio as Default"
echo "=============================================="
echo

NEEDS_RESTART=false

# Step 1: Enable the built-in audio card if it's disabled in config
if [[ -f "$DISABLE_BUILTIN_CONF" ]]; then
    print_info "Found config that disables built-in audio card"
    print_info "Disabling this config to enable laptop audio..."
    
    mv "$DISABLE_BUILTIN_CONF" "${DISABLE_BUILTIN_CONF}.disabled"
    print_success "Disabled the blocking config file"
    NEEDS_RESTART=true
fi

# Step 2: Restart WirePlumber if config changed
if [[ "$NEEDS_RESTART" == "true" ]]; then
    print_info "Restarting WirePlumber to detect built-in audio..."
    systemctl --user restart wireplumber
    sleep 2
fi

# Step 3: Set the card profile to analog stereo duplex (speaker + mic)
print_info "Setting Intel PCH card profile to Analog Stereo Duplex..."
if pactl list cards short 2>/dev/null | grep -q "$INTEL_CARD"; then
    pactl set-card-profile "$INTEL_CARD" "output:analog-stereo+input:analog-stereo"
    print_success "Activated analog stereo duplex profile (speaker + mic)"
    sleep 1
else
    print_warning "Intel PCH card not found, may need to restart WirePlumber"
fi

# Step 4: Show available devices
echo
echo -e "${CYAN}Available Audio Devices:${NC}"
wpctl status | sed -n '/^Audio/,/^Video/p'
echo

# Step 5: Find and set laptop speaker as default
print_info "Searching for laptop speaker..."

LAPTOP_SINK_ID=""

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]│├└─\*]+([0-9]+)\.[[:space:]]+(.+) ]]; then
        id="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        name=$(echo "$name" | sed 's/\[vol:.*\]//' | xargs)
        
        if echo "$name" | grep -qiE "built.?in.*analog|analog.*built.?in|ALC.*stereo|Intel.*analog"; then
            LAPTOP_SINK_ID="$id"
            print_info "Found laptop speaker: $name (ID: $id)"
            break
        fi
    fi
done < <(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p')

if [[ -n "$LAPTOP_SINK_ID" ]]; then
    wpctl set-default "$LAPTOP_SINK_ID"
    print_success "Set laptop speaker as default output"
    
    # Move all existing audio streams to the new default sink
    print_info "Moving existing audio streams to laptop speaker..."
    pactl list short sink-inputs 2>/dev/null | while read -r index rest; do
        pactl move-sink-input "$index" @DEFAULT_SINK@ 2>/dev/null || true
    done
    print_success "Moved all streams to laptop speaker"
else
    print_warning "Could not find laptop speaker automatically"
    echo "Available sinks:"
    wpctl status | sed -n '/Sinks:/,/Sources:/p'
fi

echo

# Step 6: Find and set laptop microphone as default
print_info "Searching for laptop microphone..."

LAPTOP_SOURCE_ID=""

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]│├└─\*]+([0-9]+)\.[[:space:]]+(.+) ]]; then
        id="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        name=$(echo "$name" | sed 's/\[vol:.*\]//' | xargs)
        
        if echo "$name" | grep -qiE "built.?in.*analog|analog.*built.?in|ALC.*stereo|Intel.*analog"; then
            LAPTOP_SOURCE_ID="$id"
            print_info "Found laptop microphone: $name (ID: $id)"
            break
        fi
    fi
done < <(wpctl status 2>/dev/null | sed -n '/Audio/,/Video/p' | sed -n '/Sources:/,/Filters:/p')

if [[ -n "$LAPTOP_SOURCE_ID" ]]; then
    wpctl set-default "$LAPTOP_SOURCE_ID"
    print_success "Set laptop microphone as default input"
    
    # Move all existing audio input streams to the new default source
    print_info "Moving existing audio input streams to laptop microphone..."
    pactl list short source-outputs 2>/dev/null | while read -r index rest; do
        pactl move-source-output "$index" @DEFAULT_SOURCE@ 2>/dev/null || true
    done
    print_success "Moved all input streams to laptop microphone"
else
    print_warning "Could not find laptop microphone automatically"
    echo "Available sources:"
    wpctl status | sed -n '/Audio/,/Video/p' | sed -n '/Sources:/,/Filters:/p'
fi

echo
echo "=============================================="
echo "  Current Default Audio Devices"
echo "=============================================="
echo

echo -e "${BLUE}Default Sink (Output):${NC}"
wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep '\*' | head -1 || echo "  (none set)"
echo
echo -e "${BLUE}Default Source (Input):${NC}"
wpctl status | sed -n '/Audio/,/Video/p' | sed -n '/Sources:/,/Filters:/p' | grep '\*' | head -1 || echo "  (none set)"

echo
print_success "Laptop audio configuration complete!"
echo
echo -e "${YELLOW}Note:${NC} If Firefox doesn't see the mic, restart Firefox after running this script."
