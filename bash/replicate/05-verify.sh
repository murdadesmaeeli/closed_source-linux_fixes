#!/bin/bash
# Post-configuration verification for the AMD target system.
# Checks GPU, display, packages, and services.
# Run on the TARGET laptop after 04-configure-target.sh and a reboot.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="${SCRIPT_DIR}/export"
PASS=0
WARN=0
FAIL=0

pass() { echo "   [OK] $1"; ((PASS++)) || true; }
warn() { echo "   [!!] $1"; ((WARN++)) || true; }
fail() { echo "   [FAIL] $1"; ((FAIL++)) || true; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  System Verification — AMD Target"
echo "  $(hostname) | $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── 1. GPU Detection ───────────────────────────────────────

echo "=== 1/7  GPU Detection ==="

VGA_INFO=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" || true)
if echo "$VGA_INFO" | grep -qi "amd\|radeon\|navi"; then
    pass "AMD GPU detected"
    echo "        $VGA_INFO" | head -3
else
    fail "AMD GPU not detected in lspci"
    echo "        $VGA_INFO"
fi

if lsmod | grep -q "^amdgpu"; then
    pass "amdgpu kernel module loaded"
else
    fail "amdgpu kernel module NOT loaded"
fi

if lsmod | grep -q "^nvidia"; then
    fail "nvidia kernel module is still loaded!"
else
    pass "nvidia module not loaded (good)"
fi

echo ""

# ─── 2. Vulkan ──────────────────────────────────────────────

echo "=== 2/7  Vulkan ==="

if command -v vulkaninfo &>/dev/null; then
    VULKAN_GPU=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 || true)
    if [ -n "$VULKAN_GPU" ]; then
        pass "Vulkan working"
        echo "        $VULKAN_GPU"
    else
        warn "vulkaninfo ran but no GPU found"
    fi
else
    warn "vulkaninfo not installed (apt install vulkan-tools)"
fi

echo ""

# ─── 3. OpenGL ──────────────────────────────────────────────

echo "=== 3/7  OpenGL ==="

if command -v glxinfo &>/dev/null; then
    GL_RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1 || true)
    if echo "$GL_RENDERER" | grep -qi "amd\|radeon\|navi"; then
        pass "OpenGL using AMD GPU"
        echo "        $GL_RENDERER"
    elif [ -n "$GL_RENDERER" ]; then
        warn "OpenGL renderer found but may not be AMD"
        echo "        $GL_RENDERER"
    else
        warn "Could not query OpenGL renderer (no display?)"
    fi
else
    warn "glxinfo not installed (apt install mesa-utils)"
fi

echo ""

# ─── 4. Display / Desktop ───────────────────────────────────

echo "=== 4/7  Display & Desktop ==="

if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
    pass "Desktop environment: ${XDG_CURRENT_DESKTOP}"
else
    warn "XDG_CURRENT_DESKTOP not set (run from a desktop session)"
fi

if [ -n "${XDG_SESSION_TYPE:-}" ]; then
    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        pass "Session type: Wayland"
    else
        warn "Session type: ${XDG_SESSION_TYPE} (expected wayland)"
    fi
else
    warn "XDG_SESSION_TYPE not set"
fi

if systemctl is-active --quiet sddm; then
    pass "SDDM is running"
else
    warn "SDDM is not active"
fi

echo ""

# ─── 5. Package Count ───────────────────────────────────────

echo "=== 5/7  Packages ==="

CURRENT_COUNT=$(dpkg -l | grep -c "^ii")
echo "   Current installed packages: ${CURRENT_COUNT}"

if [ -f "${EXPORT_DIR}/packages-manual.list" ]; then
    SOURCE_MANUAL=$(wc -l < "${EXPORT_DIR}/packages-manual.list")
    NVIDIA_COUNT=0
    if [ -f "${EXPORT_DIR}/packages-nvidia-cuda.list" ]; then
        NVIDIA_COUNT=$(wc -l < "${EXPORT_DIR}/packages-nvidia-cuda.list")
    fi
    EXPECTED=$((SOURCE_MANUAL - NVIDIA_COUNT))
    CURRENT_MANUAL=$(apt-mark showmanual 2>/dev/null | wc -l)
    echo "   Source manual packages: ${SOURCE_MANUAL}"
    echo "   Minus NVIDIA/CUDA: ${NVIDIA_COUNT}"
    echo "   Expected manual (approx): ${EXPECTED}"
    echo "   Current manual packages: ${CURRENT_MANUAL}"

    DIFF=$((CURRENT_MANUAL - EXPECTED))
    ABS_DIFF=${DIFF#-}
    if [ "$ABS_DIFF" -lt 20 ]; then
        pass "Package count within expected range (delta: ${DIFF})"
    else
        warn "Package count differs by ${DIFF} from expected"
    fi
fi

if [ -f "${EXPORT_DIR}/packages-failed.list" ]; then
    FAILED_COUNT=$(wc -l < "${EXPORT_DIR}/packages-failed.list")
    if [ "$FAILED_COUNT" -gt 0 ]; then
        warn "${FAILED_COUNT} packages failed to install (see export/packages-failed.list)"
    fi
fi

echo ""

# ─── 6. Services ────────────────────────────────────────────

echo "=== 6/7  Key Services ==="

SERVICES_CHECK=(
    "sddm:display manager"
    "NetworkManager:network"
    "bluetooth:bluetooth"
    "power-profiles-daemon:power management"
)

for entry in "${SERVICES_CHECK[@]}"; do
    svc="${entry%%:*}"
    desc="${entry##*:}"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        pass "${desc} (${svc})"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        warn "${desc} (${svc}) — enabled but not active"
    else
        warn "${desc} (${svc}) — not enabled"
    fi
done

# Verify thermald is disabled (Intel-specific)
if systemctl is-enabled --quiet thermald 2>/dev/null; then
    warn "thermald still enabled (should be disabled on AMD)"
else
    pass "thermald disabled (correct for AMD)"
fi

# Verify no nvidia services
if systemctl list-units --all 2>/dev/null | grep -qi nvidia; then
    warn "NVIDIA systemd units still present"
else
    pass "No NVIDIA systemd units found"
fi

echo ""

# ─── 7. ASUS-specific ───────────────────────────────────────

echo "=== 7/7  ASUS-specific ==="

if [ -d /sys/devices/platform/asus-nb-wmi ]; then
    pass "asus-nb-wmi platform driver loaded"
    THERMAL=$(cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy 2>/dev/null || echo "N/A")
    echo "        Thermal policy: ${THERMAL}"
else
    warn "asus-nb-wmi platform not detected"
fi

if lsmod | grep -q "asus_wmi"; then
    pass "asus_wmi module loaded"
else
    warn "asus_wmi module not loaded"
fi

echo ""

# ─── Summary ────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verification Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Passed:   ${PASS}"
echo "  Warnings: ${WARN}"
echo "  Failed:   ${FAIL}"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo "  All checks passed! System is ready."
elif [ "$FAIL" -eq 0 ]; then
    echo "  No critical failures. Review warnings above."
else
    echo "  There are failures that need attention."
    echo "  You can re-run specific steps of 04-configure-target.sh:"
    echo "    sudo ./04-configure-target.sh --step <1-8>"
fi
echo ""
