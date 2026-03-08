# Fix KClock Timer Sound - Debian 13 KDE Plasma 6

## The Problem

You're running **KDE Plasma 6**, but the previous script used Plasma 5 commands. This is why the Clocks timer doesn't ring.

## Quick Fix (Copy-Paste This)

Run these commands in your terminal:

```bash
# Configure KClock timer notifications (Plasma 6)
kwriteconfig6 --file kclock.notifyrc --group "Event/timerFinished" --key Action "Sound|Popup"
kwriteconfig6 --file kclock.notifyrc --group "Event/timerFinished" --key Sound "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
kwriteconfig6 --file kclock.notifyrc --group "Event/alarmTriggered" --key Action "Sound|Popup"
kwriteconfig6 --file kclock.notifyrc --group "Event/alarmTriggered" --key Sound "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

# Configure general notifications
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Action "Sound|Popup"
kwriteconfig6 --file plasmanotifyrc --group "Event/notification" --key Sound "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"

# Set sound theme
kwriteconfig6 --file kdeglobals --group Sounds --key Theme "freedesktop"

# Restart notification daemon
kquitapp6 kded6 && sleep 2 && kded6 &

# Kill kclockd so it picks up new config
killall kclockd 2>/dev/null || true

echo "✅ Configuration complete! Now test the timer in Clocks app."
```

## Test It

1. **Open Clocks app:**
   ```bash
   kclock
   ```

2. **Go to Timer tab**

3. **Set a 10-second timer**

4. **Wait for it to finish** - you should hear the alarm sound!

## Alternative Test

Test if the notification works without opening the app:

```bash
notify-send -a "KClock" -u critical "Timer Finished" "This is a test timer notification"
```

You should hear the sound immediately.

## Still Not Working?

### Check Notification Settings

1. Open **System Settings**
2. Go to **Notifications → Application Settings**
3. Find **KClock** in the list
4. Make sure:
   - ✅ "Show in history" is enabled
   - ✅ "Show notification banners" is enabled
   - ✅ Sound is NOT muted

### Check Audio Mixer

While a timer is going off, run:

```bash
pavucontrol
```

Go to the **Playback** tab and see if "System Sounds" or "Event Sounds" appears. Make sure it's not muted.

### Manual GUI Configuration

1. **System Settings → Notifications → Configure Events**
2. In the left sidebar, find **KClock** or **Clocks**
3. Look for:
   - **Timer Finished**
   - **Alarm Triggered**
4. For each event:
   - ✅ Enable "Play a sound"
   - Click "Select Sound" and choose: `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`
   - Click **Apply**

### Verify Configuration File

Check if the config was created correctly:

```bash
cat ~/.config/kclock.notifyrc
```

Should show:

```ini
[Event/alarmTriggered]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga

[Event/timerFinished]
Action=Sound|Popup
Sound=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
```

## Why Did This Happen?

- **Your system**: KDE Plasma 6
- **Original script**: Used Plasma 5 commands (`kwriteconfig5`, `kquitapp5`, `kded5`)
- **Fix**: Use Plasma 6 commands (`kwriteconfig6`, `kquitapp6`, `kded6`)

The daemon `kclockd` needs to be restarted after configuration changes, which is why killing it helps.

---

**Quick One-Liner to Fix Everything:**

```bash
kwriteconfig6 --file kclock.notifyrc --group "Event/timerFinished" --key Action "Sound|Popup" && kwriteconfig6 --file kclock.notifyrc --group "Event/timerFinished" --key Sound "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" && kwriteconfig6 --file kclock.notifyrc --group "Event/alarmTriggered" --key Action "Sound|Popup" && kwriteconfig6 --file kclock.notifyrc --group "Event/alarmTriggered" --key Sound "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" && kquitapp6 kded6 && kded6 &> /dev/null & killall kclockd 2>/dev/null || true
```

Then test with a 10-second timer in the Clocks app!















