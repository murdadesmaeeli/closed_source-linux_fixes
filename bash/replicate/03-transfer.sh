#!/bin/bash
# Transfer system and home data from source to target via rsync over SSH.
# Run on the TARGET (new AMD) laptop after fresh Debian 13 install + network setup.
#
# Usage:
#   sudo ./03-transfer.sh              # full transfer
#   sudo ./03-transfer.sh home-only    # only home directory
#   sudo ./03-transfer.sh system-only  # only system files
#
# Safe to re-run — rsync will only transfer changed/missing files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_USER="oneking"
TARGET_USER="oneking"
MODE="${1:-full}"

# Auto-detect source IP from default gateway (set by the shared NM connection)
SOURCE_IP=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -z "$SOURCE_IP" ]; then
    SOURCE_IP="10.42.0.1"
    echo "   [!!] Could not detect gateway, falling back to ${SOURCE_IP}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  System Transfer — Target Machine"
echo "  Mode: ${MODE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)."
    exit 1
fi

if [[ "$MODE" != "full" && "$MODE" != "home-only" && "$MODE" != "system-only" ]]; then
    echo "Usage: sudo $0 [full|home-only|system-only]"
    exit 1
fi

# ─── Connectivity check ─────────────────────────────────────

echo "=== Checking connectivity to source (${SOURCE_IP}) ==="
if ! ping -c 1 -W 2 "$SOURCE_IP" &>/dev/null; then
    echo "   [!!] Cannot reach ${SOURCE_IP}"
    echo "   Run 02-setup-network.sh on both machines first."
    exit 1
fi
echo "   [OK] Source is reachable"
echo ""

# ─── SSH connectivity check ─────────────────────────────────

echo "=== Checking SSH on source ==="
MAX_SSH_RETRIES=5
SSH_OK=false
for attempt in $(seq 1 $MAX_SSH_RETRIES); do
    if ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
         "${SOURCE_USER}@${SOURCE_IP}" true 2>/dev/null; then
        SSH_OK=true
        break
    fi
    # Distinguish "connection refused" from "auth required"
    ssh_err=$(ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
        "${SOURCE_USER}@${SOURCE_IP}" true 2>&1 || true)
    if echo "$ssh_err" | grep -qi "permission denied"; then
        SSH_OK=true   # server is up, just needs auth — that's fine
        break
    fi
    if [ "$attempt" -lt "$MAX_SSH_RETRIES" ]; then
        echo "   [..] SSH not ready (attempt ${attempt}/${MAX_SSH_RETRIES}), retrying in 3s..."
        sleep 3
    fi
done

if [ "$SSH_OK" = false ]; then
    echo "   [!!] SSH server on ${SOURCE_IP} is not accepting connections."
    echo ""
    echo "   On the SOURCE machine, run:"
    echo "     sudo apt install -y openssh-server"
    echo "     sudo systemctl enable --now ssh"
    echo ""
    echo "   Or re-run:  sudo ./02-setup-network.sh source"
    echo "   (it installs and starts SSH automatically)"
    exit 1
fi
echo "   [OK] SSH is reachable on ${SOURCE_IP}"
echo ""

# ─── SSH key setup hint ─────────────────────────────────────

echo "=== SSH setup ==="
echo "   If you haven't set up SSH keys, you'll be prompted for"
echo "   the password multiple times. To avoid this, run:"
echo "     ssh-copy-id ${SOURCE_USER}@${SOURCE_IP}"
echo ""
read -rp "   Press Enter to continue (or Ctrl+C to set up keys first)... "
echo ""

# ─── Rsync options ───────────────────────────────────────────

RSYNC_OPTS=(
    --archive
    --compress
    --partial
    --progress
    --human-readable
    --info=progress2
    --stats
    --delete-after
    --numeric-ids
)

RSYNC_SSH="ssh -o StrictHostKeyChecking=accept-new"

# ─── Home directory exclusions ───────────────────────────────

HOME_EXCLUDES=(
    --exclude='.local/share/Trash'
    --exclude='.local/share/plasma-vault'
    --exclude='.android'
    --exclude='.docker'
    --exclude='Documents/archive'
    --exclude='Videos'
    --exclude='.cache'
    # Large data/media folders
    --exclude='Documents/public_github/closed_source-content_creation_automation/static'
    --exclude='Documents/private_github/instagram_analyzer/data'
    --exclude='Documents/Personal_Files/dating/dating profile'
    --exclude='Documents/Personal_Files/dating/my pics'
    --exclude='Documents/Personal_Files/Health/mobility'
    # NVIDIA-specific items that won't be needed on AMD
    --exclude='.nv'
    --exclude='.cuda-gdb*'
    # Temp / lock files
    --exclude='.Xauthority'
    --exclude='.xsession-errors*'
    --exclude='*.swp'
    --exclude='*.swo'
    --exclude='.gvfs'
    --exclude='.dbus'
)

# ─── Transfer: export data first ────────────────────────────

echo "=== Syncing export data ==="
EXPORT_SRC="${SOURCE_USER}@${SOURCE_IP}:${SCRIPT_DIR}/export/"
EXPORT_DST="${SCRIPT_DIR}/export/"
mkdir -p "$EXPORT_DST"
rsync "${RSYNC_OPTS[@]}" -e "$RSYNC_SSH" "$EXPORT_SRC" "$EXPORT_DST"
echo "   [OK] Export data synced"
echo ""

# ─── Transfer: system files ─────────────────────────────────

transfer_system() {
    echo "=== Syncing system files ==="
    echo ""

    echo "--- /etc (system configuration) ---"
    rsync "${RSYNC_OPTS[@]}" -e "$RSYNC_SSH" \
        --exclude='machine-id' \
        --exclude='hostname' \
        --exclude='hosts' \
        --exclude='fstab' \
        --exclude='crypttab' \
        --exclude='blkid.tab*' \
        --exclude='lvm/archive' \
        --exclude='lvm/backup' \
        --exclude='adjtime' \
        --exclude='udev/rules.d/70-persistent-*' \
        --exclude='ssh/ssh_host_*' \
        --exclude='modprobe.d/nvidia*' \
        --exclude='modules-load.d/nvidia*' \
        --exclude='X11/xorg.conf.d/*nvidia*' \
        "${SOURCE_USER}@${SOURCE_IP}:/etc/" /etc/
    echo "   [OK] /etc synced"
    echo ""

    echo "--- /opt (third-party software) ---"
    rsync "${RSYNC_OPTS[@]}" -e "$RSYNC_SSH" \
        --exclude='cuda*' \
        --exclude='nvidia*' \
        "${SOURCE_USER}@${SOURCE_IP}:/opt/" /opt/
    echo "   [OK] /opt synced"
    echo ""

    echo "--- /usr/local (local installs) ---"
    rsync "${RSYNC_OPTS[@]}" -e "$RSYNC_SSH" \
        "${SOURCE_USER}@${SOURCE_IP}:/usr/local/" /usr/local/
    echo "   [OK] /usr/local synced"
    echo ""

    echo "--- /var/spool/cron (system crontabs) ---"
    rsync "${RSYNC_OPTS[@]}" -e "$RSYNC_SSH" \
        "${SOURCE_USER}@${SOURCE_IP}:/var/spool/cron/" /var/spool/cron/ 2>/dev/null || true
    echo "   [OK] crontabs synced"
    echo ""
}

# ─── Transfer: home directory ────────────────────────────────

transfer_home() {
    echo "=== Syncing home directory ==="
    echo ""
    echo "   Exclusions:"
    for exc in "${HOME_EXCLUDES[@]}"; do
        echo "     ${exc#--exclude=}"
    done
    echo ""

    TARGET_HOME="/home/${TARGET_USER}"
    mkdir -p "$TARGET_HOME"

    rsync "${RSYNC_OPTS[@]}" -e "$RSYNC_SSH" \
        "${HOME_EXCLUDES[@]}" \
        "${SOURCE_USER}@${SOURCE_IP}:/home/${SOURCE_USER}/" "${TARGET_HOME}/"

    chown -R "$(id -u "$TARGET_USER"):$(id -g "$TARGET_USER")" "$TARGET_HOME"

    echo ""
    echo "   [OK] Home directory synced"
    echo ""
}

# ─── Execute based on mode ───────────────────────────────────

case "$MODE" in
    full)
        transfer_system
        transfer_home
        ;;
    system-only)
        transfer_system
        ;;
    home-only)
        transfer_home
        ;;
esac

# ─── Summary ────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Transfer Complete — ${MODE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Synced from: ${SOURCE_USER}@${SOURCE_IP}"
echo ""
if [[ "$MODE" == "full" || "$MODE" == "system-only" ]]; then
    echo "  System: /etc, /opt, /usr/local, crontabs"
fi
if [[ "$MODE" == "full" || "$MODE" == "home-only" ]]; then
    echo "  Home:   /home/${TARGET_USER}/ (minus exclusions)"
fi
echo ""
echo "  Excluded (home):"
echo "    ~/.local/share/Trash                                          (179GB)"
echo "    ~/.local/share/plasma-vault                                   (134GB)"
echo "    ~/.android                                                    (151GB)"
echo "    ~/.docker                                                      (64GB)"
echo "    ~/Documents/archive                                           (111GB)"
echo "    ~/Videos                                                       (66GB)"
echo "    ~/.cache                                                       (28GB)"
echo "    ~/Documents/.../content_creation_automation/static            (372GB)"
echo "    ~/Documents/.../instagram_analyzer/data                       (178GB)"
echo "    ~/Documents/Personal_Files/dating/dating profile              (3.5GB)"
echo "    ~/Documents/Personal_Files/dating/my pics                     (2.8GB)"
echo "    ~/Documents/Personal_Files/Health/mobility                    (1.9GB)"
echo ""
echo "  Next step: run 04-configure-target.sh on this machine"
echo ""
