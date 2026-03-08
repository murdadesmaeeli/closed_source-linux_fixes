#!/bin/bash
#===============================================================================
# set-external-audio.sh
# Sets external audio devices as default:
#   - Output: BenQ HDMI monitor speaker (via NVIDIA card)
#   - Input: Audio-Technica AT2020 USB microphone
# - Disables built-in audio card for cleaner routing
# - Disables Cam Link 4K audio input (capture card, not a real mic)
# - Boosts AT2020 WirePlumber priority to prevent Cam Link from stealing default
# - Clears stale WirePlumber default-nodes state on config changes
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
WIREPLUMBER_STATE_DIR="$HOME/.local/state/wireplumber"
DISABLE_BUILTIN_CONF="$WIREPLUMBER_CONF_DIR/50-disable-builtin-mic.conf"
AT2020_PRIORITY_CONF="$WIREPLUMBER_CONF_DIR/51-at2020-default-source.conf"
NVIDIA_CARD="alsa_card.pci-0000_01_00.1"
AT2020_CARD="alsa_card.usb-audio-technica____AT2020_USB-00"

echo "=============================================="
echo "  Setting External Audio as Default"
echo "  - Speaker: BenQ HDMI Monitor"
echo "  - Mic: Audio-Technica AT2020"
echo "=============================================="
echo

NEEDS_RESTART=false

# Step 1: Re-enable the disable config for built-in audio (cleaner external routing)
if [[ -f "${DISABLE_BUILTIN_CONF}.disabled" ]] && [[ ! -f "$DISABLE_BUILTIN_CONF" ]]; then
    print_info "Re-enabling config to disable built-in audio..."
    mv "${DISABLE_BUILTIN_CONF}.disabled" "$DISABLE_BUILTIN_CONF"
    NEEDS_RESTART=true
fi

# Step 1b: Ensure AT2020 priority & Cam Link audio disable config exists
# The Cam Link 4K is a capture card — its audio input is not a real mic and
# should be disabled so it never steals default source from the AT2020.
mkdir -p "$WIREPLUMBER_CONF_DIR"
AT2020_CONF_CONTENT='monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_input.*AT2020.*" }
    ]
    actions = {
      update-props = {
        priority.driver  = 3000
        priority.session = 3000
      }
    }
  }
  {
    matches = [
      { node.name = "~alsa_input.*Cam_Link_4K*" }
    ]
    actions = {
      update-props = {
        node.disabled = true
      }
    }
  }
]'

if [[ ! -f "$AT2020_PRIORITY_CONF" ]] || ! diff -q <(echo "$AT2020_CONF_CONTENT") "$AT2020_PRIORITY_CONF" &>/dev/null; then
    print_info "Writing AT2020 priority + Cam Link disable config..."
    echo "$AT2020_CONF_CONTENT" > "$AT2020_PRIORITY_CONF"
    NEEDS_RESTART=true
fi

# Step 2: Restart WirePlumber if config changed (clear stale state first)
if [[ "$NEEDS_RESTART" == "true" ]]; then
    print_info "Clearing stale WirePlumber default-nodes state..."
    rm -f "$WIREPLUMBER_STATE_DIR/default-nodes"
    print_info "Restarting WirePlumber..."
    systemctl --user restart wireplumber
    sleep 2
fi

# Step 3: Set NVIDIA card profile for HDMI output (BenQ monitor)
print_info "Setting NVIDIA card profile for HDMI output..."
if pactl list cards short 2>/dev/null | grep -q "$NVIDIA_CARD"; then
    # Try to find an available HDMI profile (format: "output:hdmi-stereo: Description... available: yes")
    HDMI_PROFILE=$(pactl list cards 2>/dev/null | grep -A 100 "$NVIDIA_CARD" | grep -E "^\s+output:hdmi.*available: yes" | head -1 | awk -F: '{print $1":"$2}' | xargs)
    
    if [[ -n "$HDMI_PROFILE" ]]; then
        print_info "Found available HDMI profile: $HDMI_PROFILE"
        pactl set-card-profile "$NVIDIA_CARD" "$HDMI_PROFILE"
        print_success "Activated HDMI profile"
    else
        print_warning "No HDMI port shows as available - monitor may not be connected"
        print_info "Trying default HDMI stereo profile anyway..."
        if pactl set-card-profile "$NVIDIA_CARD" "output:hdmi-stereo" 2>/dev/null; then
            print_success "Set output:hdmi-stereo profile"
        elif pactl set-card-profile "$NVIDIA_CARD" "output:hdmi-stereo-extra1" 2>/dev/null; then
            print_success "Set output:hdmi-stereo-extra1 profile"
        elif pactl set-card-profile "$NVIDIA_CARD" "output:hdmi-stereo-extra2" 2>/dev/null; then
            print_success "Set output:hdmi-stereo-extra2 profile"
        else
            print_warning "Could not set any HDMI profile"
        fi
    fi
    sleep 1
else
    print_warning "NVIDIA card ($NVIDIA_CARD) not found"
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

# Step 6: Find and set HDMI speaker as default
print_info "Searching for HDMI speaker..."

HDMI_SINK_ID=""

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]│├└─\*]+([0-9]+)\.[[:space:]]+(.+) ]]; then
        id="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        name=$(echo "$name" | sed 's/\[vol:.*\]//' | xargs)
        
        # Look for BenQ or HDMI/NVIDIA output (not Dummy)
        if echo "$name" | grep -qiE "benq"; then
            HDMI_SINK_ID="$id"
            print_info "Found BenQ speaker: $name (ID: $id)"
            break
        elif echo "$name" | grep -qiE "(hdmi|displayport|nvidia.*stereo|AD107)" && \
             ! echo "$name" | grep -qiE "dummy"; then
            HDMI_SINK_ID="$id"
            print_info "Found HDMI speaker: $name (ID: $id)"
        fi
    fi
done < <(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p')

if [[ -n "$HDMI_SINK_ID" ]]; then
    wpctl set-default "$HDMI_SINK_ID"
    print_success "Set HDMI speaker as default output"
    
    # Move all existing audio streams to the new default sink
    print_info "Moving existing audio streams to HDMI speaker..."
    pactl list short sink-inputs 2>/dev/null | while read -r index rest; do
        pactl move-sink-input "$index" @DEFAULT_SINK@ 2>/dev/null || true
    done
    print_success "Moved all streams to HDMI speaker"
else
    print_warning "Could not find HDMI speaker"
    echo "Available sinks:"
    wpctl status | sed -n '/Sinks:/,/Sources:/p'
    echo
    echo -e "${YELLOW}Note:${NC} Make sure your BenQ monitor is connected via HDMI and turned on"
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
print_success "External audio configuration complete!"
echo
echo -e "${YELLOW}Note:${NC} If apps don't see the devices, restart them after running this script."
