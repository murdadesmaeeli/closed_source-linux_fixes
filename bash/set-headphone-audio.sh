#!/bin/bash
#===============================================================================
# set-headphone-audio.sh
# Sets physical headphone as default output:
#   - Output: Built-in Audio Analog Stereo (headphone jack)
#   - Input: Audio-Technica AT2020 USB microphone
# - Enables built-in audio card (disabled by external audio config)
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
BUILTIN_CARD="alsa_card.pci-0000_00_1f.3"
AT2020_CARD="alsa_card.usb-audio-technica____AT2020_USB-00"

echo "=============================================="
echo "  Setting Headphone Audio as Default"
echo "  - Speaker: Built-in Headphone Jack"
echo "  - Mic: Audio-Technica AT2020"
echo "=============================================="
echo

NEEDS_RESTART=false

# Step 1: Disable the config that disables built-in audio (enable the card)
if [[ -f "$DISABLE_BUILTIN_CONF" ]]; then
    print_info "Enabling built-in audio card..."
    mv "$DISABLE_BUILTIN_CONF" "${DISABLE_BUILTIN_CONF}.disabled"
    NEEDS_RESTART=true
fi

# Step 2: Restart WirePlumber if config changed
if [[ "$NEEDS_RESTART" == "true" ]]; then
    print_info "Restarting WirePlumber..."
    systemctl --user restart wireplumber
    sleep 2
fi

# Step 3: Set built-in card profile for analog stereo output (headphones)
print_info "Setting built-in card profile for headphone output..."
if pactl list cards short 2>/dev/null | grep -q "$BUILTIN_CARD"; then
    pactl set-card-profile "$BUILTIN_CARD" "output:analog-stereo" 2>/dev/null || \
    pactl set-card-profile "$BUILTIN_CARD" "output:analog-stereo+input:analog-stereo" 2>/dev/null || \
    print_warning "Could not set analog stereo profile"
    print_success "Built-in card configured for headphone output"
    sleep 1
else
    print_warning "Built-in card ($BUILTIN_CARD) not found"
fi

# Step 4: Set AT2020 card profile
print_info "Setting AT2020 card profile..."
if pactl list cards short 2>/dev/null | grep -q "$AT2020_CARD"; then
    pactl set-card-profile "$AT2020_CARD" "input:analog-stereo" 2>/dev/null || \
    pactl set-card-profile "$AT2020_CARD" "analog-stereo-input" 2>/dev/null || \
    print_info "AT2020 profile already set or auto-configured"
    print_success "AT2020 card configured"
else
    print_warning "AT2020 card ($AT2020_CARD) not found - is it connected?"
fi

sleep 1

# Step 5: Show available devices
echo
echo -e "${CYAN}Available Audio Devices:${NC}"
wpctl status | sed -n '/^Audio/,/^Video/p'
echo

# Step 6: Find and set headphone speaker as default
print_info "Searching for headphone output..."

HEADPHONE_SINK_ID=""

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]│├└─\*]+([0-9]+)\.[[:space:]]+(.+) ]]; then
        id="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        name=$(echo "$name" | sed 's/\[vol:.*\]//' | xargs)
        
        # Look for Built-in Audio Analog Stereo (headphone output)
        if echo "$name" | grep -qiE "built.?in.*analog|analog.*stereo" && \
           ! echo "$name" | grep -qiE "hdmi|digital|dummy"; then
            HEADPHONE_SINK_ID="$id"
            print_info "Found headphone output: $name (ID: $id)"
            break
        fi
    fi
done < <(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p')

if [[ -n "$HEADPHONE_SINK_ID" ]]; then
    wpctl set-default "$HEADPHONE_SINK_ID"
    print_success "Set headphone as default output"
    
    # Move all existing audio streams to the new default sink
    print_info "Moving existing audio streams to headphone..."
    pactl list short sink-inputs 2>/dev/null | while read -r index rest; do
        pactl move-sink-input "$index" @DEFAULT_SINK@ 2>/dev/null || true
    done
    print_success "Moved all streams to headphone"
else
    print_warning "Could not find headphone output"
    echo "Available sinks:"
    wpctl status | sed -n '/Sinks:/,/Sources:/p'
    echo
    echo -e "${YELLOW}Note:${NC} Make sure headphones are connected to the audio jack"
fi

echo

# Step 7: Find and set AT2020 microphone as default
print_info "Searching for AT2020 microphone..."

AT2020_SOURCE_ID=""

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]│├└─\*]+([0-9]+)\.[[:space:]]+(.+) ]]; then
        id="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        name=$(echo "$name" | sed 's/\[vol:.*\]//' | xargs)
        
        # AT2020 may report as "Q1U dynamic microphone" due to firmware
        if echo "$name" | grep -qiE "(at2020|at-2020|audio.?technica|q1u)"; then
            AT2020_SOURCE_ID="$id"
            print_info "Found AT2020 microphone: $name (ID: $id)"
            break
        fi
    fi
done < <(wpctl status 2>/dev/null | sed -n '/Audio/,/Video/p' | sed -n '/Sources:/,/Filters:/p')

if [[ -n "$AT2020_SOURCE_ID" ]]; then
    wpctl set-default "$AT2020_SOURCE_ID"
    print_success "Set AT2020 microphone as default input"
    
    # Move all existing audio input streams to the new default source
    print_info "Moving existing audio input streams to AT2020 microphone..."
    pactl list short source-outputs 2>/dev/null | while read -r index rest; do
        pactl move-source-output "$index" @DEFAULT_SOURCE@ 2>/dev/null || true
    done
    print_success "Moved all input streams to AT2020 microphone"
else
    print_warning "Could not find AT2020 microphone"
    echo "Available sources:"
    wpctl status | sed -n '/Audio/,/Video/p' | sed -n '/Sources:/,/Filters:/p'
    echo
    echo -e "${YELLOW}Note:${NC} Make sure your AT2020 USB mic is connected"
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
print_success "Headphone audio configuration complete!"
echo
echo -e "${YELLOW}Note:${NC} If apps don't see the devices, restart them after running this script."
