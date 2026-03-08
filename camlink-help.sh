#!/bin/bash
# Camlink 4K Helper - Shows correct paths and usage

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║           ELGATO CAMLINK 4K - QUICK REFERENCE                    ║
╚══════════════════════════════════════════════════════════════════╝

📁 Repository Structure:
  docs/                    - All documentation
  bash/                    - All scripts
  README.md                - Main overview

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 QUICK START:

1. Install and configure:
   bash/install.sh

2. Monitor for Camlink connection:
   bash/monitor-camlink.sh

3. Diagnose issues:
   bash/camlink-4k-fix.sh

4. "Worked yesterday" diagnostic:
   bash/quick-diagnose.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 DOCUMENTATION:

• Start here:        docs/QUICK-START.md
• Full guide:        docs/README-CAMLINK-4K.md
• OBS setup:         docs/OBS-CAMLINK-SETUP.md
• Main README:       README.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 ALL SCRIPTS:

bash/install.sh                  - Simple one-command installation
bash/apply-camlink-fixes.sh      - Full automatic fix application
bash/camlink-4k-fix.sh           - Complete diagnostic tool
bash/monitor-camlink.sh          - Real-time USB monitoring
bash/quick-diagnose.sh           - "Worked yesterday" troubleshooter
bash/disable-camlink-audio.sh    - Disable Camlink audio
bash/INSTALL-COMMANDS.sh         - Manual installation commands

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ MOST COMMON ISSUE:

Your Camlink is NOT detected?
→ HDMI source must be ON and actively outputting!
→ The Camlink won't enumerate without active HDMI signal

Quick fix:
  1. Turn ON your HDMI source (camera/console)
  2. Unplug Camlink from USB
  3. Wait 5 seconds
  4. Plug back into USB 3.0 port (blue port)
  5. Run: bash/monitor-camlink.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📖 Read docs/QUICK-START.md for step-by-step instructions

EOF
















