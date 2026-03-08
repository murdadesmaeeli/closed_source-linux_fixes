#!/bin/bash
# Export source system state for replication to a new machine.
# Run on the SOURCE (current) laptop. No root required for most exports,
# but sudo is used for /etc tarball and apt key export.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="${SCRIPT_DIR}/export"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  System Export — Source Machine"
echo "  $(hostname) | $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

mkdir -p "${EXPORT_DIR}"

# ─── Package Lists ───────────────────────────────────────────

echo "=== 1/8  Package lists ==="

dpkg --get-selections > "${EXPORT_DIR}/packages-dpkg.list"
echo "   [OK] dpkg selections  ($(wc -l < "${EXPORT_DIR}/packages-dpkg.list") packages)"

apt-mark showmanual | sort > "${EXPORT_DIR}/packages-manual.list"
echo "   [OK] manually installed  ($(wc -l < "${EXPORT_DIR}/packages-manual.list") packages)"

dpkg-query -Wf '${Package}\t${Version}\n' | sort > "${EXPORT_DIR}/packages-versions.list"
echo "   [OK] package versions"

echo ""

# ─── Snap & Flatpak ─────────────────────────────────────────

echo "=== 2/8  Snap & Flatpak ==="

if command -v snap &>/dev/null; then
    snap list 2>/dev/null | tail -n +2 | awk '{print $1}' > "${EXPORT_DIR}/packages-snap.list"
    echo "   [OK] snap list  ($(wc -l < "${EXPORT_DIR}/packages-snap.list") snaps)"
else
    touch "${EXPORT_DIR}/packages-snap.list"
    echo "   [--] snap not installed"
fi

if command -v flatpak &>/dev/null; then
    flatpak list --app --columns=application 2>/dev/null > "${EXPORT_DIR}/packages-flatpak.list"
    echo "   [OK] flatpak list  ($(wc -l < "${EXPORT_DIR}/packages-flatpak.list") apps)"
else
    touch "${EXPORT_DIR}/packages-flatpak.list"
    echo "   [--] flatpak not installed"
fi

echo ""

# ─── pip / npm globals ───────────────────────────────────────

echo "=== 3/8  pip & npm globals ==="

if command -v pip3 &>/dev/null; then
    pip3 list --format=freeze 2>/dev/null > "${EXPORT_DIR}/packages-pip.list" || true
    echo "   [OK] pip3 packages  ($(wc -l < "${EXPORT_DIR}/packages-pip.list") packages)"
else
    touch "${EXPORT_DIR}/packages-pip.list"
    echo "   [--] pip3 not found"
fi

if command -v npm &>/dev/null; then
    npm list -g --depth=0 --json 2>/dev/null > "${EXPORT_DIR}/packages-npm-global.json" || true
    echo "   [OK] npm global packages"
else
    echo "   [--] npm not found"
fi

echo ""

# ─── APT sources & keys ─────────────────────────────────────

echo "=== 4/8  APT sources & keys ==="

mkdir -p "${EXPORT_DIR}/apt"
cp /etc/apt/sources.list "${EXPORT_DIR}/apt/" 2>/dev/null || true
cp -r /etc/apt/sources.list.d/ "${EXPORT_DIR}/apt/" 2>/dev/null || true
echo "   [OK] sources.list + sources.list.d/"

mkdir -p "${EXPORT_DIR}/apt/trusted-keys"
if [ -d /etc/apt/trusted.gpg.d ]; then
    cp /etc/apt/trusted.gpg.d/* "${EXPORT_DIR}/apt/trusted-keys/" 2>/dev/null || true
    echo "   [OK] trusted.gpg.d keys"
fi
if [ -d /usr/share/keyrings ]; then
    mkdir -p "${EXPORT_DIR}/apt/keyrings"
    for src in "${EXPORT_DIR}"/apt/sources.list.d/*; do
        [ -f "$src" ] || continue
        grep -oP 'signed-by=\K[^\]\s]+' "$src" 2>/dev/null | while read -r keypath; do
            if [ -f "$keypath" ]; then
                cp "$keypath" "${EXPORT_DIR}/apt/keyrings/" 2>/dev/null || true
            fi
        done
    done
    echo "   [OK] referenced signing keys"
fi

echo ""

# ─── Enabled services ───────────────────────────────────────

echo "=== 5/8  Enabled services ==="

systemctl list-unit-files --state=enabled --type=service --no-pager \
    | grep enabled | awk '{print $1}' | sort > "${EXPORT_DIR}/services-enabled.list"
echo "   [OK] system services  ($(wc -l < "${EXPORT_DIR}/services-enabled.list"))"

systemctl --user list-unit-files --state=enabled --type=service --no-pager 2>/dev/null \
    | grep enabled | awk '{print $1}' | sort > "${EXPORT_DIR}/services-user-enabled.list" || true
echo "   [OK] user services  ($(wc -l < "${EXPORT_DIR}/services-user-enabled.list"))"

echo ""

# ─── System configs (/etc) ───────────────────────────────────

echo "=== 6/8  System configs ==="

sudo tar czf "${EXPORT_DIR}/etc-backup.tar.gz" \
    --exclude='/etc/machine-id' \
    --exclude='/etc/hostname' \
    --exclude='/etc/hosts' \
    --exclude='/etc/fstab' \
    --exclude='/etc/crypttab' \
    --exclude='/etc/blkid.tab*' \
    --exclude='/etc/lvm/archive' \
    --exclude='/etc/lvm/backup' \
    --exclude='/etc/adjtime' \
    --exclude='/etc/udev/rules.d/70-persistent-*' \
    --exclude='/etc/ssh/ssh_host_*' \
    /etc 2>/dev/null || true
echo "   [OK] /etc tarball  ($(du -sh "${EXPORT_DIR}/etc-backup.tar.gz" | awk '{print $1}'))"

echo ""

# ─── User crontabs & systemd user units ─────────────────────

echo "=== 7/8  Crontabs & user units ==="

crontab -l > "${EXPORT_DIR}/crontab-user.txt" 2>/dev/null || echo "# no crontab" > "${EXPORT_DIR}/crontab-user.txt"
echo "   [OK] user crontab"

if [ -d "${HOME}/.config/systemd/user" ]; then
    tar czf "${EXPORT_DIR}/systemd-user-units.tar.gz" -C "${HOME}/.config/systemd" user/ 2>/dev/null || true
    echo "   [OK] systemd user units"
else
    echo "   [--] no user units found"
fi

echo ""

# ─── NVIDIA package list (for exclusion on target) ──────────

echo "=== 8/8  NVIDIA/CUDA package list (for target exclusion) ==="

dpkg -l | grep -iE "^ii.*(nvidia|cuda)" | awk '{print $2}' | sort > "${EXPORT_DIR}/packages-nvidia-cuda.list"
echo "   [OK] nvidia/cuda packages to exclude  ($(wc -l < "${EXPORT_DIR}/packages-nvidia-cuda.list"))"

echo ""

# ─── Summary ────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Export Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Output directory: ${EXPORT_DIR}/"
echo ""
echo "  Files created:"
ls -lh "${EXPORT_DIR}/" | tail -n +2 | awk '{print "    " $NF " (" $5 ")"}'
echo ""
echo "  Next step: run 02-setup-network.sh on both machines"
echo ""
