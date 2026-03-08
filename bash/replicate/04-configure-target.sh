#!/bin/bash
# Post-transfer configuration for the AMD target system.
# Removes NVIDIA stack, installs AMD GPU drivers, restores packages,
# and fixes boot/GRUB/services for the new hardware.
#
# Run on the TARGET laptop after 03-transfer.sh completes.
# Requires root.
#
# Usage:
#   sudo ./04-configure-target.sh           # run all steps
#   sudo ./04-configure-target.sh --step N  # run only step N (1-8)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="${SCRIPT_DIR}/export"
TARGET_USER="oneking"
STEP_ONLY="${2:-}"

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)."
    exit 1
fi

if [ ! -d "$EXPORT_DIR" ]; then
    echo "Error: export directory not found at ${EXPORT_DIR}"
    echo "Run 03-transfer.sh first to pull export data from source."
    exit 1
fi

should_run() {
    local step="$1"
    [[ -z "$STEP_ONLY" ]] && return 0
    [[ "$1" == "$STEP_ONLY" ]] && return 0
    return 1
}

# Parse --step flag
if [[ "${1:-}" == "--step" ]]; then
    STEP_ONLY="${2:-}"
    if [[ -z "$STEP_ONLY" ]]; then
        echo "Usage: sudo $0 --step <1-8>"
        exit 1
    fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Target Configuration — AMD System"
echo "  $(hostname) | $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ═══════════════════════════════════════════════════════════════
# Step 1: Remove NVIDIA packages
# ═══════════════════════════════════════════════════════════════

if should_run 1; then
    echo "=== Step 1/8: Remove NVIDIA & CUDA packages ==="
    echo ""

    NVIDIA_PKGS=()
    while IFS= read -r pkg; do
        if dpkg -l "$pkg" &>/dev/null 2>&1; then
            NVIDIA_PKGS+=("$pkg")
        fi
    done < <(dpkg -l | grep -iE "^ii.*(nvidia|cuda|nvcuvid|nvenc|nsight|envycontrol)" | awk '{print $2}')

    if [ ${#NVIDIA_PKGS[@]} -gt 0 ]; then
        echo "   Purging ${#NVIDIA_PKGS[@]} NVIDIA/CUDA packages..."
        apt-get purge -y "${NVIDIA_PKGS[@]}" 2>&1 | tail -5
        apt-get autoremove -y --purge 2>&1 | tail -3
        echo "   [OK] NVIDIA packages purged"
    else
        echo "   [--] No NVIDIA packages found"
    fi

    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 2: Remove NVIDIA configs and repos
# ═══════════════════════════════════════════════════════════════

if should_run 2; then
    echo "=== Step 2/8: Remove NVIDIA configs & repos ==="
    echo ""

    # Modprobe / module configs
    for f in /etc/modprobe.d/nvidia* /etc/modprobe.d/*nvidia* \
             /etc/modules-load.d/nvidia* /etc/modules-load.d/*nvidia*; do
        if [ -f "$f" ]; then
            rm -v "$f"
        fi
    done

    # X11 nvidia configs
    for f in /etc/X11/xorg.conf.d/*nvidia*; do
        if [ -f "$f" ]; then
            rm -v "$f"
        fi
    done

    # SDDM nvidia overrides
    if [ -f /etc/sddm.conf.d/nvidia.conf ]; then
        rm -v /etc/sddm.conf.d/nvidia.conf
    fi

    # NVIDIA apt repo
    for f in /etc/apt/sources.list.d/cuda*.list; do
        if [ -f "$f" ]; then
            rm -v "$f"
        fi
    done

    # NVIDIA ld.so.conf entries
    for f in /etc/ld.so.conf.d/*nvidia* /etc/ld.so.conf.d/*cuda*; do
        if [ -f "$f" ]; then
            rm -v "$f"
        fi
    done
    ldconfig 2>/dev/null || true

    # Remove leftover nvidia kernel modules if any
    if [ -d /lib/modules ]; then
        find /lib/modules -name "nvidia*" -type f -delete 2>/dev/null || true
    fi

    echo "   [OK] NVIDIA configs cleaned"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 3: Install AMD GPU stack
# ═══════════════════════════════════════════════════════════════

if should_run 3; then
    echo "=== Step 3/8: Install AMD GPU drivers ==="
    echo ""

    # Remove stale AMD repos that point to Ubuntu jammy
    for f in /etc/apt/sources.list.d/amdgpu.list \
             /etc/apt/sources.list.d/amdgpu-proprietary.list \
             /etc/apt/sources.list.d/rocm.list; do
        if [ -f "$f" ] && grep -q "ubuntu" "$f" 2>/dev/null; then
            echo "   Removing stale repo: $f (points to Ubuntu)"
            rm -v "$f"
        fi
    done

    apt-get update -qq

    AMD_PACKAGES=(
        firmware-amd-graphics
        libdrm-amdgpu1
        mesa-vulkan-drivers
        mesa-va-drivers
        mesa-vdpau-drivers
        xserver-xorg-video-amdgpu
        libgl1-mesa-dri
        libglx-mesa0
        libegl-mesa0
        vulkan-tools
    )

    echo "   Installing AMD GPU packages..."
    apt-get install -y "${AMD_PACKAGES[@]}" 2>&1 | tail -5
    echo "   [OK] AMD GPU stack installed"

    # Ensure amdgpu module loads at boot
    if ! grep -q "^amdgpu" /etc/modules 2>/dev/null; then
        echo "amdgpu" >> /etc/modules
        echo "   [OK] amdgpu added to /etc/modules"
    fi

    echo ""
    echo "   Note: For ROCm GPU compute support, install separately:"
    echo "     See https://rocm.docs.amd.com/en/latest/deploy/linux/install.html"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 4: Restore apt sources and install packages
# ═══════════════════════════════════════════════════════════════

if should_run 4; then
    echo "=== Step 4/8: Restore APT sources & install packages ==="
    echo ""

    # Restore apt sources (the transfer script already synced /etc, but
    # we need to selectively restore keys and non-NVIDIA sources)
    if [ -d "${EXPORT_DIR}/apt/keyrings" ]; then
        cp "${EXPORT_DIR}"/apt/keyrings/* /usr/share/keyrings/ 2>/dev/null || true
        echo "   [OK] Signing keys restored"
    fi
    if [ -d "${EXPORT_DIR}/apt/trusted-keys" ]; then
        cp "${EXPORT_DIR}"/apt/trusted-keys/* /etc/apt/trusted.gpg.d/ 2>/dev/null || true
        echo "   [OK] Trusted keys restored"
    fi

    apt-get update -qq 2>&1 | tail -3
    echo "   [OK] Package index updated"
    echo ""

    # Build filtered package list: exclude nvidia/cuda and kernel-specific packages
    if [ -f "${EXPORT_DIR}/packages-manual.list" ]; then
        echo "   Filtering package list (removing NVIDIA/CUDA/kernel-specific)..."

        grep -ivE '(nvidia|cuda|nsight|nvcuvid|nvenc|envycontrol|linux-image-|linux-headers-|linux-kbuild-)' \
            "${EXPORT_DIR}/packages-manual.list" \
            > /tmp/packages-to-install.list

        TOTAL=$(wc -l < /tmp/packages-to-install.list)
        echo "   Installing ${TOTAL} packages (this will take a while)..."
        echo ""

        # Install in batches to handle unavailable packages gracefully
        FAILED_PKGS=()
        BATCH_SIZE=50
        INSTALLED=0

        while IFS= read -r pkg; do
            BATCH+=("$pkg")
            if [ ${#BATCH[@]} -ge $BATCH_SIZE ]; then
                if ! apt-get install -y --no-install-recommends "${BATCH[@]}" 2>/dev/null; then
                    for p in "${BATCH[@]}"; do
                        if ! apt-get install -y --no-install-recommends "$p" 2>/dev/null; then
                            FAILED_PKGS+=("$p")
                        else
                            ((INSTALLED++)) || true
                        fi
                    done
                else
                    INSTALLED=$((INSTALLED + ${#BATCH[@]}))
                fi
                BATCH=()
                printf "   Progress: %d / %d installed\r" "$INSTALLED" "$TOTAL"
            fi
        done < /tmp/packages-to-install.list

        # Handle remaining batch
        if [ ${#BATCH[@]} -gt 0 ]; then
            if ! apt-get install -y --no-install-recommends "${BATCH[@]}" 2>/dev/null; then
                for p in "${BATCH[@]}"; do
                    if ! apt-get install -y --no-install-recommends "$p" 2>/dev/null; then
                        FAILED_PKGS+=("$p")
                    else
                        ((INSTALLED++)) || true
                    fi
                done
            else
                INSTALLED=$((INSTALLED + ${#BATCH[@]}))
            fi
        fi

        echo ""
        echo "   [OK] ${INSTALLED} packages installed"

        if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
            echo "   [!!] ${#FAILED_PKGS[@]} packages failed to install:"
            printf '         %s\n' "${FAILED_PKGS[@]}" | tee "${EXPORT_DIR}/packages-failed.list"
        fi
    else
        echo "   [!!] packages-manual.list not found in export dir"
    fi

    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 5: Restore snaps and flatpaks
# ═══════════════════════════════════════════════════════════════

if should_run 5; then
    echo "=== Step 5/8: Restore snaps & flatpaks ==="
    echo ""

    # Snaps
    if [ -f "${EXPORT_DIR}/packages-snap.list" ]; then
        # Skip base/core/snapd snaps
        while IFS= read -r snap_name; do
            [[ "$snap_name" =~ ^(bare|core[0-9]*|gnome-.*|gtk-common-themes|snapd)$ ]] && continue
            if ! snap list "$snap_name" &>/dev/null; then
                echo "   Installing snap: ${snap_name}..."
                snap install "$snap_name" 2>/dev/null || echo "   [!!] Failed: ${snap_name}"
            else
                echo "   [--] snap already installed: ${snap_name}"
            fi
        done < "${EXPORT_DIR}/packages-snap.list"
        echo "   [OK] Snaps processed"
    fi
    echo ""

    # Flatpaks
    if [ -f "${EXPORT_DIR}/packages-flatpak.list" ]; then
        if command -v flatpak &>/dev/null; then
            # Ensure flathub remote exists
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

            while IFS= read -r app_id; do
                [ -z "$app_id" ] && continue
                if ! flatpak list --app --columns=application 2>/dev/null | grep -qx "$app_id"; then
                    echo "   Installing flatpak: ${app_id}..."
                    flatpak install -y flathub "$app_id" 2>/dev/null || echo "   [!!] Failed: ${app_id}"
                else
                    echo "   [--] flatpak already installed: ${app_id}"
                fi
            done < "${EXPORT_DIR}/packages-flatpak.list"
            echo "   [OK] Flatpaks processed"
        else
            echo "   [!!] flatpak not installed, skipping"
        fi
    fi

    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 6: Fix SDDM and Wayland config
# ═══════════════════════════════════════════════════════════════

if should_run 6; then
    echo "=== Step 6/8: Fix SDDM & Wayland ==="
    echo ""

    # On AMD, SDDM works natively with Wayland — no nvidia workarounds needed
    SDDM_CONF="/etc/sddm.conf.d"
    mkdir -p "$SDDM_CONF"

    # Remove any nvidia-specific SDDM overrides that may have been synced
    rm -f "${SDDM_CONF}/nvidia.conf" 2>/dev/null
    rm -f "${SDDM_CONF}/10-nvidia.conf" 2>/dev/null

    # Ensure Wayland greeter is configured (AMD supports this natively)
    cat > "${SDDM_CONF}/10-wayland.conf" <<'SDDM_EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
SDDM_EOF
    echo "   [OK] SDDM configured for Wayland (AMD native)"

    # Remove envycontrol config if present (nvidia-specific)
    rm -f /etc/envycontrol 2>/dev/null
    rm -f /usr/bin/envycontrol 2>/dev/null

    # Remove chromium/vscode nvidia-specific flags that reference nvidia
    for flagfile in /home/${TARGET_USER}/.config/chromium-flags.conf \
                    /home/${TARGET_USER}/.config/code-flags.conf; do
        if [ -f "$flagfile" ]; then
            sed -i '/--disable-gpu/d' "$flagfile" 2>/dev/null || true
        fi
    done

    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 7: Fix boot (GRUB, fstab, initramfs)
# ═══════════════════════════════════════════════════════════════

if should_run 7; then
    echo "=== Step 7/8: Fix boot configuration ==="
    echo ""

    # The fresh Debian install should have created a valid fstab.
    # We verify it still references the correct UUIDs.
    echo "   Current /etc/fstab:"
    cat /etc/fstab | grep -v "^#" | grep -v "^$" | while read -r line; do
        echo "     $line"
    done
    echo ""

    # GRUB: remove nvidia-specific kernel params, add amdgpu
    GRUB_DEFAULT="/etc/default/grub"
    if [ -f "$GRUB_DEFAULT" ]; then
        # Remove nvidia-specific params
        sed -i 's/nvidia-drm\.modeset=[0-9]//g' "$GRUB_DEFAULT"
        sed -i 's/nvidia\.NVreg_PreserveVideoMemoryAllocations=[0-9]//g' "$GRUB_DEFAULT"
        sed -i 's/nvidia\.NVreg_TemporaryFilePath=[^ "]*//g' "$GRUB_DEFAULT"

        # Clean up double/triple spaces from removals
        sed -i 's/  \+/ /g' "$GRUB_DEFAULT"
        sed -i 's/" /"/g; s/ "/"/g' "$GRUB_DEFAULT"

        # Ensure amdgpu module is loaded early
        if ! grep -q "amdgpu" "$GRUB_DEFAULT" 2>/dev/null; then
            sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 amdgpu.dc=1/' "$GRUB_DEFAULT"
        fi

        echo "   [OK] GRUB params cleaned (nvidia removed, amdgpu.dc=1 added)"
        echo ""
        echo "   Updated GRUB_CMDLINE_LINUX_DEFAULT:"
        grep "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_DEFAULT" | head -1 | sed 's/^/     /'
    fi
    echo ""

    # Update GRUB
    update-grub 2>&1 | tail -3
    echo "   [OK] GRUB updated"

    # Rebuild initramfs (include amdgpu, exclude nvidia)
    # Remove nvidia from initramfs modules if present
    if [ -f /etc/initramfs-tools/modules ]; then
        sed -i '/^nvidia/d' /etc/initramfs-tools/modules
        if ! grep -q "^amdgpu" /etc/initramfs-tools/modules; then
            echo "amdgpu" >> /etc/initramfs-tools/modules
        fi
    fi

    update-initramfs -u -k all 2>&1 | tail -3
    echo "   [OK] initramfs rebuilt"

    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Step 8: Fix services
# ═══════════════════════════════════════════════════════════════

if should_run 8; then
    echo "=== Step 8/8: Fix services ==="
    echo ""

    # thermald is Intel-specific, not needed on AMD
    if systemctl is-enabled thermald &>/dev/null 2>&1; then
        systemctl disable thermald
        systemctl stop thermald 2>/dev/null || true
        echo "   [OK] thermald disabled (Intel-specific)"
    fi

    # Ensure power-profiles-daemon is available
    if ! systemctl is-enabled power-profiles-daemon &>/dev/null 2>&1; then
        apt-get install -y power-profiles-daemon 2>/dev/null
        systemctl enable power-profiles-daemon
        echo "   [OK] power-profiles-daemon enabled"
    else
        echo "   [--] power-profiles-daemon already enabled"
    fi

    # nvidia-persistenced won't exist, but clean up just in case
    systemctl disable nvidia-persistenced 2>/dev/null || true

    # Ensure bluetooth and NetworkManager are enabled
    systemctl enable bluetooth 2>/dev/null || true
    systemctl enable NetworkManager 2>/dev/null || true
    systemctl enable sddm 2>/dev/null || true

    # Restore user services
    if [ -f "${EXPORT_DIR}/systemd-user-units.tar.gz" ]; then
        USER_HOME="/home/${TARGET_USER}"
        mkdir -p "${USER_HOME}/.config/systemd"
        tar xzf "${EXPORT_DIR}/systemd-user-units.tar.gz" -C "${USER_HOME}/.config/systemd/" 2>/dev/null || true
        chown -R "$(id -u "${TARGET_USER}"):$(id -g "${TARGET_USER}")" "${USER_HOME}/.config/systemd/"
        echo "   [OK] User systemd units restored"
    fi

    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Configuration Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Completed steps:"
should_run 1 && echo "    1. NVIDIA/CUDA packages purged"
should_run 2 && echo "    2. NVIDIA configs and repos removed"
should_run 3 && echo "    3. AMD GPU stack installed"
should_run 4 && echo "    4. APT sources restored, packages installed"
should_run 5 && echo "    5. Snaps and flatpaks restored"
should_run 6 && echo "    6. SDDM/Wayland configured for AMD"
should_run 7 && echo "    7. GRUB/initramfs rebuilt for AMD"
should_run 8 && echo "    8. Services fixed"
echo ""
echo "  IMPORTANT — manual steps remaining:"
echo "    - Review /etc/fstab matches your partition layout"
echo "    - The power-mode.sh script references nvidia-smi and"
echo "      NVIDIA paths — it needs manual adaptation for AMD"
echo "    - If you need ROCm for GPU compute, install it separately"
echo ""
echo "  Next step: run 05-verify.sh, then reboot"
echo ""
