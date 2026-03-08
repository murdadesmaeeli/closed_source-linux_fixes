# Set Audio-Technica AT2020 USB as Default Microphone

## Overview

This guide shows you how to set your **Audio-Technica AT2020 USB** microphone as the **ONLY** and **DEFAULT** microphone on Debian 13 with KDE Plasma 6 and PipeWire.

## Quick Fix

Run the automated script:

```bash
./set-at2020-default-mic.sh
```

This will:
- ✅ Set AT2020 USB as the default microphone
- ✅ Disable the built-in audio card microphone
- ✅ Make the configuration persistent across reboots

---

## What Was Configured

### Current Setup

| Device | Type | Status |
|--------|------|--------|
| **Audio-Technica AT2020 USB** | Microphone | ✅ ONLY & DEFAULT |
| Built-in Audio (PCH) | Audio Card | ❌ DISABLED |
| Elgato Cam Link 4K | Video Capture | 🔇 Audio Disabled |
| NVIDIA HDMI Audio | Output Only | ✅ Active |

### Configuration Files Created

1. **`~/.config/pipewire/pipewire.conf.d/10-at2020-default.conf`**
   - Sets AT2020 USB as the default audio source
   - Persists across reboots

2. **`~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf`**
   - Disables the built-in audio card
   - Prevents built-in microphone from interfering

---

## Manual Configuration

If you prefer to configure manually:

### Step 1: Identify Your AT2020 USB

```bash
pactl list sources short | grep audio-technica
```

You should see:
```
85  alsa_input.usb-audio-technica____AT2020_USB-00.analog-stereo
```

### Step 2: Create PipeWire Configuration

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d

cat > ~/.config/pipewire/pipewire.conf.d/10-at2020-default.conf << 'EOF'
# Set Audio-Technica AT2020 USB as default microphone
context.properties = {
    default.configured.audio.source = {
        name = "alsa_input.usb-audio-technica____AT2020_USB-00.analog-stereo"
    }
}
EOF
```

### Step 3: Disable Built-in Microphone

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

cat > ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf << 'EOF'
# Disable built-in audio card
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "alsa_card.pci-0000_00_1f.3"
      }
    ]
    actions = {
      update-props = {
        device.disabled = true
      }
    }
  }
]
EOF
```

### Step 4: Disable Built-in Card Now

```bash
# Disable the built-in audio card immediately
pactl set-card-profile alsa_card.pci-0000_00_1f.3 off
```

### Step 5: Set AT2020 as Default

```bash
# Get the device ID
wpctl status | grep "Q1U dynamic microphone"

# Set as default (replace XX with the ID number)
wpctl set-default XX
```

### Step 6: Restart Audio Services

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```

---

## Verification

### Check Current Default

```bash
wpctl status | grep -A 10 "Sources:"
```

Should show **ONLY**:
```
├─ Sources:
│      66. Q1U dynamic microphone Analog Stereo [vol: 0.66]
```

### Check Default Configuration

```bash
wpctl status | grep -A 3 "Default Configured"
```

Should include:
```
1. Audio/Source  alsa_input.usb-audio-technica____AT2020_USB-00.analog-stereo
```

### Test Recording

```bash
# Record 5 seconds of audio
arecord -f cd -d 5 test.wav

# Play it back
aplay test.wav

# Clean up
rm test.wav
```

---

## Adjust Microphone Settings

### Volume Control

```bash
# Set to 75%
wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 75%

# Set to 100%
wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 100%

# Get current volume
wpctl get-volume @DEFAULT_AUDIO_SOURCE@
```

### Mute/Unmute

```bash
# Mute
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1

# Unmute
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
```

### GUI Volume Control

```bash
# Open PulseAudio Volume Control
pavucontrol
```

Go to **Input Devices** tab → Adjust "Q1U dynamic microphone"

---

## Troubleshooting

### AT2020 Not Detected

**Check if the microphone is connected:**

```bash
lsusb | grep -i audio
```

Should show:
```
Bus 001 Device XXX: ID 17a0:0002 Samson Technologies Corp. Q1U dynamic microphone
```

**Check PipeWire sees it:**

```bash
wpctl status | grep -i technica
```

**Restart audio if needed:**

```bash
systemctl --user restart wireplumber pipewire
```

### Built-in Mic Still Showing

**Check if built-in card is disabled:**

```bash
pactl list cards short
```

If you see `alsa_card.pci-0000_00_1f.3`, disable it:

```bash
pactl set-card-profile alsa_card.pci-0000_00_1f.3 off
```

**Make it permanent:**

Edit `~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf` and ensure it has:

```conf
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "alsa_card.pci-0000_00_1f.3"
      }
    ]
    actions = {
      update-props = {
        device.disabled = true
      }
    }
  }
]
```

Then restart:

```bash
systemctl --user restart wireplumber
```

### Wrong Device Selected in Apps

Some applications (Discord, Zoom, etc.) have their own audio device selection.

**Firefox/Chrome:**
- Go to site settings → Microphone → Select "Q1U dynamic microphone"

**Discord:**
- Settings → Voice & Video → Input Device → Select "Q1U dynamic microphone"

**OBS Studio:**
- Settings → Audio → Mic/Auxiliary Audio → Select "Q1U dynamic microphone"

### No Sound / Low Volume

**Check volume level:**

```bash
wpctl get-volume @DEFAULT_AUDIO_SOURCE@
```

**Increase volume:**

```bash
wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 85%
```

**Test with audacity or other recording software**

---

## Reverting Changes

If you want to re-enable the built-in microphone:

```bash
# Remove configuration files
rm ~/.config/pipewire/pipewire.conf.d/10-at2020-default.conf
rm ~/.config/wireplumber/wireplumber.conf.d/50-disable-builtin-mic.conf

# Re-enable built-in audio card
pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:analog-stereo+input:analog-stereo

# Restart audio
systemctl --user restart wireplumber pipewire
```

---

## Technical Details

### AT2020 USB Specifications

- **Device Name:** `alsa_input.usb-audio-technica____AT2020_USB-00.analog-stereo`
- **Description:** Q1U dynamic microphone Analog Stereo
- **Driver:** PipeWire
- **Sample Rate:** 48000 Hz (48 kHz)
- **Bit Depth:** 16-bit (s16le)
- **Channels:** 2 (Stereo)
- **USB ID:** `17a0:0002` (Samson Technologies Corp.)
- **Card Name:** AT2020 USB

### How PipeWire Default Selection Works

1. **System Default:** Set in `pipewire.conf.d/` files
2. **User Preference:** Can be overridden in applications
3. **Priority:** Devices with higher `priority.session` values are preferred
4. **Persistence:** Configurations in `~/.config/` persist across reboots

### Why Disable Built-in Audio?

When multiple audio cards exist:
- Applications may auto-select the built-in mic
- The system might switch defaults unpredictably
- Some apps use the first enumerated device

By disabling the built-in audio card:
- ✅ AT2020 USB becomes the ONLY choice
- ✅ No accidental switching
- ✅ Consistent behavior across all apps

---

## Related Documentation

- **Cam Link 4K Audio Disabled:** See `docs/OBS-CAMLINK-SETUP.md`
- **GNOME Clocks Sound Fix:** See `docs/GNOME-CLOCKS-FIX.md`
- **KDE Notifications:** See `docs/KDE-SOUND-NOTIFICATIONS.md`

---

**Last Updated:** December 2025  
**Tested On:** Debian 13 (Trixie), KDE Plasma 6, PipeWire 1.2+














