# Telegram installation on Linux

**Chat ID:** `c61d20c5-b736-40fa-9f78-962d384d7db9`

**Last updated:** 2026-02-01 05:35

---

## User

<user_query>
isntall telegram on this linux comptuer

flatpak install flathub org.telegram.desktop
</user_query>

assistant:
[Thinking] The user wants to install Telegram on their Linux computer using Flatpak. They've provided the command they want to run. Let me execute this for them.
I'll install Telegram using Flatpak for you.
[Tool call] Shell
  command: flatpak install flathub org.telegram.desktop -y
  description: Install Telegram via Flatpak
  timeout: 300000

[Tool result] Shell

assistant:
[Thinking] Telegram has been successfully installed via Flatpak. The installation completed successfully with exit code 0. It also installed/updated the necessary runtime dependencies like GNOME Platform 49 and various GL drivers.
Telegram has been successfully installed. The installation completed with all necessary dependencies including the GNOME Platform runtime.

You can now launch Telegram by:
- Searching for "Telegram" in your application menu
- Or running: `flatpak run org.telegram.desktop`


## User

<user_query>
@bash/set-external-audio.sh use this just make speaker outptu bet physical headphone connnected
</user_query>

assistant:
[Thinking] The user wants me to look at a bash script called `set-external-audio.sh` and modify it so that the speaker output is the physical headphone connected. Let me first read the file to understand what it does.
[Tool call] Read
  path: /home/oneking/Documents/public_github/closed_source-linux_fixes/bash/set-external-audio.sh

[Tool result] Read

assistant:
[Thinking] The user wants me to modify this script so that instead of using the BenQ HDMI monitor speaker, it uses the physical headphone output. Let me first check what audio devices are available on this system to understand what the headphone device might be called.
Let me check what audio devices are available to find the physical headphone output.
[Tool call] Shell
  command: wpctl status
  description: List available audio devices
[Tool call] Shell
  command: pactl list cards short
  description: List audio cards

[Tool result] Shell

[Tool result] Shell

assistant:
[Thinking] I can see the current audio setup:
- Only the NVIDIA HDMI card (AD107) and the AT2020 USB mic are showing
- The built-in audio card (which would have the headphone jack) is disabled by the WirePlumber config

The script disables the built-in audio card via the WirePlumber config. I need to:
1. Look for the built-in audio card config
2. Modify the script to use the built-in card's headphone output instead of HDMI

Let me check what the built-in card is called and what the disable config looks like.
I see the built-in audio card is disabled. Let me check the WirePlumber config and find the built-in card name.
[Tool call] Shell
  command: cat ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf 2>/dev/null || cat ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf.disabled 2>/dev/null || echo "Config not found"
  description: Check WirePlumber disable config
[Tool call] Shell
  command: pactl list cards 2>/dev/null | grep -E "(Name:|alsa.card_name|device.description)" | head -20
  description: List all card names and descriptions

[Tool result] Shell

[Tool result] Shell

assistant:
[Thinking] Now I understand the setup:

1. The built-in audio card is `alsa_card.pci-0000_00_1f.3` - this is disabled by the WirePlumber config
2. This built-in card has the physical headphone jack

I need to create a new script that:
1. Enables the built-in audio card (by disabling/renaming the WirePlumber disable config)
2. Sets the headphone output from the built-in card as the default output
3. Keeps the AT2020 microphone as the input

Let me create a new script for setting headphone output. I'll modify the existing script to set the physical headphone as the output instead of HDMI.

Actually, the user said "use this just make speaker output be physical headphone connected" - so they want me to modify the script to use headphones instead of HDMI. Let me create a modified version or a new script.

Let me first enable the built-in card and see what output it provides.
I see the built-in audio card (`alsa_card.pci-0000_00_1f.3`) with the headphone jack is disabled. I'll create a script to set the physical headphone as the output. Let me first enable the built-in card to see the available outputs.
[Tool call] Shell
  command: mv ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf.disabled 2>/dev/null && systemctl --user restart wireplumber && sleep 2 && pactl list cards | grep -A 50 "pci-0000_00_1f.3" | head -60
  description: Enable built-in card and list profiles
  timeout: 15000

[Tool result] Shell

assistant:
[Thinking] I can see the built-in card is now enabled and has `output:analog-stereo` profile available - that's the headphone output. Now let me set it as the default and then create a proper script.
The built-in card has `output:analog-stereo` for the headphone output. Let me set it as default now and then create a script for this.
[Tool call] Shell
  command: pactl set-card-profile alsa_card.pci-0000_00_1f.3 "output:analog-stereo" && sleep 1 && wpctl status | sed -n '/Sinks:/,/Sources:/p'
  description: Set analog stereo profile and list sinks

[Tool result] Shell

assistant:
[Thinking] Now I can see the "Built-in Audio Analog Stereo" sink is available with ID 62. Let me set it as default and move all audio streams to it.
Now I'll set the headphone output as default and move all streams to it.
[Tool call] Shell
  command: wpctl set-default 62 && pactl list short sink-inputs | while read -r index rest; do pactl move-sink-input "$index" @DEFAULT_SINK@ 2>/dev/null || true; done && echo "Done!" && wpctl status | sed -n '/Sinks:/,/Sources:/p' | head -5
  description: Set headphone as default output

[Tool result] Shell

assistant:
[Thinking] The headphone output is now set as default (indicated by the asterisk *). Now let me create a script for this so the user can easily switch to headphones in the future.
The physical headphone is now set as the default output (marked with `*`). Now I'll create a script to easily switch to headphones in the future.
[Tool call] Write
  path: /home/oneking/Documents/public_github/closed_source-linux_fixes/bash/set-headphone-audio.sh
  contents: #!/bin/bash
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


[Tool result] Write

assistant:
[Thinking] Now let me make the script executable.
[Tool call] Shell
  command: chmod +x /home/oneking/Documents/public_github/closed_source-linux_fixes/bash/set-headphone-audio.sh
  description: Make script executable

[Tool result] Shell

assistant:
[Thinking] The script is created and executable. The headphone output is already set as default. Let me summarize what was done.
Done. The physical headphone is now set as your default audio output.

**What I did:**
1. Enabled the built-in audio card (was disabled by the external audio config)
2. Set `output:analog-stereo` profile for the headphone jack
3. Set the headphone output as the default sink
4. Moved all existing audio streams to the headphone output

**Created script:** `bash/set-headphone-audio.sh` - you can run this anytime to switch back to headphones.

**To switch between audio outputs:**
- Headphones: `./bash/set-headphone-audio.sh`
- HDMI monitor: `./bash/set-external-audio.sh`

