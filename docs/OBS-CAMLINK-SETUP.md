# OBS Setup for Camlink 4K (Preserving Your Audio Configuration)

## Important: Audio Configuration

🔒 **Your audio setup will NOT be changed**

- Your existing **microphone source** stays as default
- Your existing **speaker/output** stays as default  
- Camlink will be **VIDEO ONLY** in OBS
- Camlink's embedded audio (if any) is **disabled** at the system level

## OBS Configuration Steps

### 1. Add Video Source (No Audio)

1. Open **OBS Studio**
2. In the **Sources** panel, click **+** (Add)
3. Select **Video Capture Device (V4L2)**
4. Name it: `Camlink 4K` (or whatever you want)
5. Click **OK**

### 2. Configure Device Settings

In the properties window:

**Device**:
- Select: `Cam Link 4K` or `/dev/video0` (whichever shows your HDMI source)

**Resolution/FPS Type**: 
- Select: `Custom`

**Resolution**:
- Set to match your HDMI source
- Common options:
  - `1920x1080` (1080p)
  - `3840x2160` (4K - if your source supports it)
  - `1280x720` (720p)

**FPS**:
- Match your HDMI source framerate
  - `30` (most cameras)
  - `60` (gaming, some cameras)

**Video Format**:
- Try: `YUYV 4:2:2` (most compatible)
- If choppy, try: `MJPEG`

**Important - Audio Settings**:
- ❌ **UNCHECK** "Use Device Audio" (or similar option)
- This ensures Camlink audio is completely ignored
- Your existing mic source continues to work

### 3. Position & Scale

- The video preview should now show your HDMI source
- Resize/position as needed in the OBS canvas
- Right-click → Transform → Fit to Screen (if needed)

### 4. Verify Audio Sources

Check that your audio hasn't changed:

1. Go to **Settings** → **Audio**
2. Verify your **Mic/Auxiliary Audio** is still your preferred microphone
3. Verify **Desktop Audio** is still your preferred output
4. Camlink should **NOT appear** in any audio device list

If Camlink appears in audio:
```bash
cd ~/Documents/public_github/closed_source-linux_fixes
./disable-camlink-audio.sh
```

Then restart OBS.

## Troubleshooting

### No Video Preview

**Check:**
1. Is HDMI source ON and outputting?
2. Try different `/dev/video*` device in OBS
3. Check video format (try MJPEG if YUYV doesn't work)
4. Verify Camlink is detected: `lsusb | grep -i elgato`

### Choppy Video

**Fix:**
1. Change **Video Format** to `MJPEG`
2. Lower resolution (try 720p instead of 1080p)
3. Check USB cable quality
4. Try different USB 3.0 port

### Black Screen in OBS

**Fix:**
1. Ensure HDMI source is **actively outputting**
2. Try unplugging/replugging HDMI cable
3. Check HDMI source resolution (some weird resolutions not supported)
4. Try 1080p@30fps first (most compatible)

### Wrong Video Device

If you have multiple webcams:

```bash
v4l2-ctl --list-devices
```

Find which `/dev/video*` is the Camlink, then select that specific device in OBS.

### Camlink Appears in Audio Settings

This means the audio blocking didn't work. Run:

```bash
./disable-camlink-audio.sh
```

Then:
- Unplug/replug Camlink, OR
- Restart audio: `systemctl --user restart pipewire pipewire-pulse`
- Restart OBS

## Example OBS Scene Setup

```
Scene: "Gameplay with Facecam"
├── Source 1: Camlink 4K (gameplay from console) - VIDEO ONLY
├── Source 2: Webcam (your face) - VIDEO ONLY  
└── Source 3: Your existing Mic - AUDIO

Audio Mixer shows:
✓ Your Mic (existing)
✓ Desktop Audio (existing)
✗ NO Camlink audio
```

## Multiple Camera Setup

You can add multiple video sources:

1. **Camlink 4K** → HDMI camera/console (video only)
2. **Built-in Webcam** → Your face (video only)
3. **Your Mic** → Audio (unchanged from before)

Each video source is independent and won't affect your audio configuration.

## Performance Tips

### For 4K Capture:
- Use MJPEG format (more efficient)
- Ensure USB 3.0 connection
- May need powerful CPU for encoding

### For 1080p60:
- YUYV works fine
- Less CPU intensive
- Recommended for most setups

### For 1080p30:
- Most compatible
- Lowest CPU usage
- Use if you have performance issues

## Verify Everything Works

✅ **Checklist**:
- [ ] Video from Camlink appears in OBS preview
- [ ] Your existing microphone is still the audio source
- [ ] Speaker/desktop audio output is unchanged
- [ ] No Camlink audio device in Audio Mixer
- [ ] Video is smooth (not choppy)
- [ ] Correct resolution and framerate

## Audio Mixing (Your Setup)

Since you want **one mic source** and **one speaker source**:

In OBS Audio Mixer (bottom panel):
- ✓ **Your Mic** (Mic/Aux) - volume slider
- ✓ **Desktop Audio** - volume slider
- ❌ **NO** Camlink audio

Your HDMI source audio (if any) is handled separately outside OBS, or you're using a dedicated audio mixer. The Camlink video is just video - audio comes from your existing setup.

Perfect! 🎯

---

**TL;DR**: 
- Add Camlink as "Video Capture Device (V4L2)"
- Select Cam Link 4K
- **UNCHECK** any audio options
- Your mic/speaker setup stays exactly the same

