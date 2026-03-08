#!/bin/bash
# Emergency Camlink troubleshooter when camera is ON but Camlink not detected

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║     CAMLINK NOT DETECTED - Camera ON, HDMI Connected             ║
╚══════════════════════════════════════════════════════════════════╝

Your Camlink 4K is NOT showing up in USB even though camera is ON.

This usually means one of these issues:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 ISSUE #1: Camlink Not Plugged Into Computer
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHECK:
  □ Is the Camlink's USB cable plugged into your computer?
  □ Is the USB cable fully inserted (heard a click)?
  □ Does the Camlink have an LED that lights up? Is it ON?

FIX:
  1. Plug Camlink's USB cable into USB 3.0 port (blue port)
  2. Make sure it's fully inserted
  3. Check for LED indicator on Camlink device

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 ISSUE #2: Camera Not Actually Outputting HDMI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Some cameras need special settings to output HDMI while recording:

CHECK:
  □ Is camera in "clean HDMI output" mode?
  □ Is camera set to output video (not just power save mode)?
  □ Does camera have "HDMI output while recording" enabled?
  □ Try connecting camera HDMI to a TV/monitor - does it show?

COMMON CAMERA SETTINGS:
  • Sony: Menu → Setup → HDMI Settings → HDMI Info Display = Off
  • Canon: Menu → HDMI Output → Enable
  • Panasonic: Setup Menu → HDMI Rec Output → On
  • Nikon: Setup Menu → HDMI → Output Resolution

TEST HDMI OUTPUT:
  1. Unplug HDMI from Camlink
  2. Plug camera directly into TV/monitor
  3. Verify you see camera output on TV
  4. Plug back into Camlink

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 ISSUE #3: Wrong USB Port Type
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Camlink 4K REQUIRES USB 3.0 (won't work with USB 2.0)

CHECK:
  □ Are you using a BLUE USB port? (USB 3.0)
  □ Black USB ports are usually USB 2.0 (won't work!)

FIX:
  1. Find USB 3.0 port (usually blue, or has "SS" symbol)
  2. Try ports on BACK of computer (more reliable)
  3. Avoid USB hubs if possible

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 ISSUE #4: Bad USB Cable
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHECK:
  □ Is USB cable fully inserted on both ends?
  □ Is this a USB 3.0 capable cable?
  □ Is cable damaged/frayed?

FIX:
  1. Try the original cable that came with Camlink
  2. Make sure both ends are firmly connected
  3. Try a different USB 3.0 cable if available

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 ISSUE #5: HDMI Cable Not Fully Connected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHECK:
  □ Is HDMI cable fully inserted into camera?
  □ Is HDMI cable fully inserted into Camlink?
  □ Did you hear a "click" when inserting HDMI?

FIX:
  1. Unplug HDMI cable from both ends
  2. Plug firmly into camera (should click/lock)
  3. Plug firmly into Camlink (should click/lock)
  4. Wiggle gently - should not come loose

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔄 POWER CYCLE SEQUENCE (Do This First!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Do these steps IN EXACT ORDER:

  1. Turn OFF camera
  2. Unplug Camlink USB from computer
  3. Unplug HDMI cable from camera and Camlink
  4. Wait 10 seconds
  5. Plug HDMI into camera (make sure it clicks)
  6. Plug HDMI into Camlink (make sure it clicks)
  7. Turn ON camera and wait for it to fully boot
  8. Make sure camera is displaying something (lens cap off!)
  9. Plug Camlink USB into USB 3.0 port (blue port)
  10. Wait 5 seconds
  11. Run: lsusb | grep -i elgato

Expected output:
  Bus XXX Device XXX: ID 0fd9:0066 Elgato Systems GmbH Cam Link 4K

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 CURRENT STATUS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your USB devices right now:

EOF

lsusb | sed 's/^/  /'

cat << 'EOF'

Looking for: ID 0fd9:0066 Elgato Systems GmbH Cam Link 4K
Status: NOT FOUND ✗

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 CHECKLIST - Do ALL of these:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

□ Camera is ON and booted up (not just powered on but in live view)
□ Camera lens cap is OFF
□ Camera is actively displaying/recording (not in standby)
□ HDMI cable is firmly connected to camera (clicked in)
□ HDMI cable is firmly connected to Camlink (clicked in)
□ Camlink USB cable is plugged into COMPUTER (blue USB 3.0 port)
□ Camlink USB cable is firmly inserted (both ends)
□ Using USB 3.0 port (BLUE port, not black)
□ Not using a USB hub (try direct motherboard connection)
□ Camera HDMI output settings enabled (check camera menu)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 AFTER CHECKING ALL ABOVE, TEST:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  watch -n 1 'lsusb | grep -i elgato'

Then unplug/replug Camlink USB and watch for it to appear.

If it STILL doesn't appear:
  → Hardware issue (bad Camlink, bad cable, or defective USB port)
  → Try Camlink on different computer to verify it works

EOF
















