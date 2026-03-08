#!/bin/bash
#
# Power Mode Toggle for ASUS ROG Strix G16 (G614JVR)
# Switches between battery-optimized and performance modes with full reversibility.
#
# Battery mode: SDDM Wayland greeter (NVIDIA idles at ~1-2W), TLP, powertop,
#               CPU capped at 60%, turbo off, 8 of 32 CPU threads online,
#               iGPU capped, resolution lowered, brightness 35.
# Performance mode: SDDM X11 greeter, all CPU/GPU maximized, ASUS turbo thermal
#               profile (fans ramp for cooling), NVIDIA persistence + clock unlock,
#               performance governor, turbo boost on, 100% CPU uncapped.
#
# Usage:
#   sudo bash/power-mode.sh setup        # one-time: snapshot current state + install TLP
#   sudo bash/power-mode.sh battery      # switch to battery mode (~6h battery life)
#   sudo bash/power-mode.sh performance  # restore original setup exactly
#   bash/power-mode.sh status            # show current mode + power draw
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
CONFIG_DIR="${REAL_HOME}/.config/power-mode"
SNAPSHOT_FILE="$CONFIG_DIR/snapshot.conf"
MODE_FILE="$CONFIG_DIR/current_mode"
MODPROBE_BACKUP_DIR="$CONFIG_DIR/modprobe-backup"
GRUB_FILE="/etc/default/grub"
TLP_CONF="/etc/tlp.d/01-rog-strix.conf"
SYSCTL_CONF="/etc/sysctl.d/99-powersave.conf"
POWERTOP_SERVICE="/etc/systemd/system/powertop-autotune.service"

# In battery mode, SDDM is switched from its X11 greeter (which holds
# the NVIDIA GPU at ~15W in P3) to a Wayland greeter using kwin_wayland
# on the Intel iGPU. This lets the NVIDIA GPU drop to D3cold (~1-2W).
# Performance mode restores the X11 greeter and NVIDIA override.
SDDM_WAYLAND_CONF="/etc/sddm.conf.d/wayland.conf"
SDDM_OVERRIDE="/etc/systemd/system/sddm.service.d/override.conf"
SDDM_OVERRIDE_DISABLED="${SDDM_OVERRIDE}.power-mode-disabled"
NVIDIA_MODULES_LOAD="/etc/modules-load.d/nvidia.conf"
NVIDIA_MODULES_LOAD_DISABLED="${NVIDIA_MODULES_LOAD}.power-mode-disabled"
NVIDIA_MODPROBE="/etc/modprobe.d/nvidia.conf"
NVIDIA_MODPROBE_BATTERY="/etc/modprobe.d/zz-power-mode-nvidia.conf"

CURSOR_SETTINGS="${REAL_HOME}/.config/Cursor/User/settings.json"
CURSOR_SETTINGS_BACKUP="$CONFIG_DIR/cursor-settings.json.bak"
CURSOR_ARGV="${REAL_HOME}/.cursor/argv.json"
CURSOR_ARGV_BACKUP="$CONFIG_DIR/cursor-argv.json.bak"
CURSOR_FLAGS="${REAL_HOME}/.config/cursor-flags.conf"
CURSOR_FLAGS_BACKUP="$CONFIG_DIR/cursor-flags.conf.bak"
CURSOR_DESKTOP="${REAL_HOME}/.local/share/applications/cursor.desktop"
CURSOR_DESKTOP_BACKUP="$CONFIG_DIR/cursor.desktop.bak"
CURSOR_BIN="${REAL_HOME}/.local/bin/cursor"
CURSOR_BIN_BACKUP="$CONFIG_DIR/cursor-bin.bak"

CHROMIUM_FLAGS="${REAL_HOME}/.config/chromium-flags.conf"
CHROMIUM_FLAGS_BACKUP="$CONFIG_DIR/chromium-flags.conf.bak"
VSCODE_FLAGS="${REAL_HOME}/.config/code-flags.conf"
VSCODE_FLAGS_BACKUP="$CONFIG_DIR/code-flags.conf.bak"
SLACK_DESKTOP_USER="${REAL_HOME}/.local/share/applications/slack_slack.desktop"
SLACK_DESKTOP_BACKUP="$CONFIG_DIR/slack_slack.desktop.bak"
KWIN_RC="${REAL_HOME}/.config/kwinrc"
KWIN_RC_BACKUP="$CONFIG_DIR/kwinrc-compositing.bak"

BATTERY_SERVICES_FILE="$CONFIG_DIR/stopped-services.list"
BATTERY_MODE_SERVICES=(
    docker
    containerd
    libvirtd
    ModemManager
    cups
    cups-browsed
    exim4
    smartmontools
    avahi-daemon
    pcscd
)

NVIDIA_MODPROBE_FILES=(
    /etc/modprobe.d/nvidia.conf
    /etc/modprobe.d/nvidia-modeset.conf
)

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}─── $1 ───${NC}"
}

info()  { echo -e "  ${GREEN}[OK]${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}[!!]${NC}  $1"; }
err()   { echo -e "  ${RED}[ERR]${NC} $1"; }
skip()  { echo -e "  ${BLUE}[--]${NC}  $1"; }

require_root_for() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This command requires root. Run with sudo:${NC}"
        echo "  sudo $0 $1"
        exit 1
    fi
}

own_to_user() {
    chown "$REAL_USER:$REAL_USER" "$@" 2>/dev/null || true
}

get_current_brightness() {
    local bl_dir
    bl_dir=$(ls -d /sys/class/backlight/*/ 2>/dev/null | head -1)
    if [[ -n "$bl_dir" ]]; then
        cat "${bl_dir}brightness" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

get_max_brightness() {
    local bl_dir
    bl_dir=$(ls -d /sys/class/backlight/*/ 2>/dev/null | head -1)
    if [[ -n "$bl_dir" ]]; then
        cat "${bl_dir}max_brightness" 2>/dev/null || echo "100"
    else
        echo "100"
    fi
}

set_brightness() {
    local val="$1"
    for bl in /sys/class/backlight/*/brightness; do
        echo "$val" > "$bl" 2>/dev/null || true
    done
}

get_power_draw_watts() {
    local power_now
    power_now=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo "0")
    echo "scale=1; $power_now / 1000000" | bc 2>/dev/null || echo "unknown"
}

get_battery_percent() {
    cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "unknown"
}

get_battery_status() {
    cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "unknown"
}

get_gpu_mode() {
    local power_draw
    power_draw=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
    if [[ -n "$power_draw" ]]; then
        echo "hybrid (nvidia loaded, ${power_draw}W)"
    else
        echo "integrated (nvidia not loaded)"
    fi
}

is_service_active() {
    local result
    result=$(systemctl is-active "$1" 2>/dev/null) || true
    echo "${result:-inactive}"
}

is_service_enabled() {
    local result
    result=$(systemctl is-enabled "$1" 2>/dev/null) || true
    echo "${result:-disabled}"
}

is_pkg_installed() {
    dpkg -s "$1" &>/dev/null && dpkg -s "$1" 2>/dev/null | grep -q '^Status: install ok installed'
}

get_current_mode() {
    if [[ -f "$MODE_FILE" ]]; then
        cat "$MODE_FILE"
    else
        echo "unknown"
    fi
}

run_as_user_wayland() {
    local uid
    uid=$(id -u "$REAL_USER")
    sudo -u "$REAL_USER" \
        DISPLAY=:0 \
        WAYLAND_DISPLAY=wayland-0 \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        "$@"
}

backup_nvidia_modprobe() {
    mkdir -p "$MODPROBE_BACKUP_DIR"
    for f in "${NVIDIA_MODPROBE_FILES[@]}"; do
        if [[ -f "$f" ]]; then
            cp "$f" "$MODPROBE_BACKUP_DIR/$(basename "$f")"
            info "Backed up $(basename "$f")"
        fi
    done
    own_to_user "$MODPROBE_BACKUP_DIR" "$MODPROBE_BACKUP_DIR"/*
}

restore_nvidia_modprobe() {
    if [[ ! -d "$MODPROBE_BACKUP_DIR" ]]; then
        warn "No modprobe backup found"
        return 1
    fi
    for f in "${NVIDIA_MODPROBE_FILES[@]}"; do
        local backup="$MODPROBE_BACKUP_DIR/$(basename "$f")"
        if [[ -f "$backup" ]]; then
            cp "$backup" "$f"
            info "Restored $(basename "$f") from backup"
        fi
    done
}

set_cursor_json_value() {
    local file="$1" key="$2" value="$3"
    if [[ ! -f "$file" ]]; then
        echo "{}" > "$file"
        own_to_user "$file"
    fi
    local tmpfile="${file}.tmp"
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
with open('$file') as f:
    d = json.load(f)
d['$key'] = $value
with open('$tmpfile', 'w') as f:
    json.dump(d, f, indent=4)
" 2>/dev/null && mv "$tmpfile" "$file" && own_to_user "$file" && return 0
    fi
    return 1
}

get_cursor_json_value() {
    local file="$1" key="$2"
    if [[ -f "$file" ]] && command -v python3 &>/dev/null; then
        python3 -c "
import json
with open('$file') as f:
    d = json.load(f)
v = d.get('$key')
if v is None:
    print('unset')
elif isinstance(v, bool):
    print(str(v).lower())
else:
    print(v)
" 2>/dev/null
    else
        echo "unset"
    fi
}

# ─────────────────────────────────────────────────────────────
# SETUP: one-time snapshot + install TLP
# ─────────────────────────────────────────────────────────────
do_setup() {
    require_root_for "setup"
    print_header "Power Mode Setup"

    mkdir -p "$CONFIG_DIR"
    own_to_user "$CONFIG_DIR"

    if [[ -f "$SNAPSHOT_FILE" ]]; then
        warn "Snapshot already exists at $SNAPSHOT_FILE"
        echo -e "    To re-run setup, delete it first: rm -rf $CONFIG_DIR"
        echo -e "    Then run: sudo $0 setup"
        exit 1
    fi

    # ── Snapshot current state ──
    print_section "Snapshotting current system state"

    local grub_cmdline_default
    grub_cmdline_default=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" 2>/dev/null | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT=//' | tr -d '"')

    local brightness
    brightness=$(get_current_brightness)

    local nmi_watchdog
    nmi_watchdog=$(cat /proc/sys/kernel/nmi_watchdog 2>/dev/null || echo "1")

    local ppd_installed="no"
    is_pkg_installed power-profiles-daemon && ppd_installed="yes"
    local ppd_enabled ppd_active
    ppd_enabled=$(is_service_enabled power-profiles-daemon)
    ppd_active=$(is_service_active power-profiles-daemon)

    local tlp_installed="no"
    is_pkg_installed tlp && tlp_installed="yes"

    local gpu_mode
    if nvidia-smi &>/dev/null; then
        gpu_mode="hybrid"
    else
        gpu_mode="integrated"
    fi

    cat > "$SNAPSHOT_FILE" <<SNAP
# Power Mode snapshot - captured $(date '+%Y-%m-%d %H:%M:%S')
ORIGINAL_GRUB_CMDLINE_DEFAULT='${grub_cmdline_default}'
ORIGINAL_BRIGHTNESS=${brightness}
ORIGINAL_NMI_WATCHDOG=${nmi_watchdog}
ORIGINAL_PPD_INSTALLED=${ppd_installed}
ORIGINAL_PPD_ENABLED=${ppd_enabled}
ORIGINAL_PPD_ACTIVE=${ppd_active}
ORIGINAL_TLP_INSTALLED=${tlp_installed}
ORIGINAL_GPU_MODE=${gpu_mode}
SETUP_COMPLETE=yes
SNAP

    cp "$GRUB_FILE" "$CONFIG_DIR/grub.bak"
    own_to_user "$SNAPSHOT_FILE" "$CONFIG_DIR/grub.bak"

    info "Snapshot saved to $SNAPSHOT_FILE"
    info "GRUB backup saved to $CONFIG_DIR/grub.bak"

    # ── Backup nvidia modprobe configs ──
    print_section "Backing up NVIDIA modprobe configs"
    backup_nvidia_modprobe

    # ── Backup SDDM NVIDIA override ──
    print_section "Backing up SDDM NVIDIA override"
    if [[ -f "$SDDM_OVERRIDE" ]]; then
        cp "$SDDM_OVERRIDE" "$CONFIG_DIR/sddm-override.bak"
        own_to_user "$CONFIG_DIR/sddm-override.bak"
        info "SDDM override backed up to $CONFIG_DIR/sddm-override.bak"
    else
        skip "No SDDM NVIDIA override found at $SDDM_OVERRIDE"
    fi

    echo ""
    echo "  Captured values:"
    echo "    GRUB cmdline default: $grub_cmdline_default"
    echo "    Brightness:           $brightness / $(get_max_brightness)"
    echo "    NMI watchdog:         $nmi_watchdog"
    echo "    PPD installed:        $ppd_installed (enabled=$ppd_enabled, active=$ppd_active)"
    echo "    TLP installed:        $tlp_installed"
    echo "    GPU mode:             $gpu_mode"
    echo "    SDDM override:       $(test -f "$SDDM_OVERRIDE" && echo "present" || echo "absent")"

    # ── Snapshot active background services ──
    print_section "Snapshotting background services"
    local active_count=0
    for svc in "${BATTERY_MODE_SERVICES[@]}"; do
        if [[ "$(is_service_active "$svc")" == "active" ]]; then
            ((active_count++)) || true
        fi
    done
    info "$active_count of ${#BATTERY_MODE_SERVICES[@]} optional services currently active"

    # ── Snapshot Cursor settings ──
    print_section "Snapshotting Cursor settings"
    if [[ -f "$CURSOR_SETTINGS" ]]; then
        cp "$CURSOR_SETTINGS" "$CURSOR_SETTINGS_BACKUP"
        own_to_user "$CURSOR_SETTINGS_BACKUP"
        local cur_wayland cur_hwaccel
        cur_wayland=$(get_cursor_json_value "$CURSOR_SETTINGS" "window.enableWayland")
        cur_hwaccel=$(get_cursor_json_value "$CURSOR_SETTINGS" "disable-hardware-acceleration")
        info "Cursor settings backed up (wayland=$cur_wayland, hw-accel-disabled=$cur_hwaccel)"
    else
        skip "Cursor settings file not found"
    fi
    if [[ -f "$CURSOR_ARGV" ]]; then
        cp "$CURSOR_ARGV" "$CURSOR_ARGV_BACKUP"
        own_to_user "$CURSOR_ARGV_BACKUP"
        info "Cursor argv.json backed up"
    else
        skip "No Cursor argv.json found (will be created in battery mode)"
    fi
    if [[ -f "$CURSOR_FLAGS" ]]; then
        cp "$CURSOR_FLAGS" "$CURSOR_FLAGS_BACKUP"
        own_to_user "$CURSOR_FLAGS_BACKUP"
        info "Cursor flags conf backed up"
    else
        skip "No cursor-flags.conf found (will be created in battery mode)"
    fi

    # ── Snapshot GPU acceleration configs ──
    print_section "Snapshotting app GPU acceleration configs"

    for pair in \
        "$CHROMIUM_FLAGS:$CHROMIUM_FLAGS_BACKUP" \
        "$VSCODE_FLAGS:$VSCODE_FLAGS_BACKUP" \
        "$SLACK_DESKTOP_USER:$SLACK_DESKTOP_BACKUP"; do
        src="${pair%%:*}"
        dst="${pair##*:}"
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            own_to_user "$dst"
            info "Backed up $(basename "$src")"
        else
            skip "$(basename "$src") not found (no flags set)"
        fi
    done

    if [[ -f "$KWIN_RC" ]]; then
        python3 -c "
import sys, re
with open(sys.argv[1]) as f:
    text = f.read()
m = re.search(r'(\[Compositing\][^\[]*)', text, re.DOTALL)
with open(sys.argv[2], 'w') as f:
    f.write(m.group(1) if m else '')
" "$KWIN_RC" "$KWIN_RC_BACKUP"
        own_to_user "$KWIN_RC_BACKUP"
        info "Backed up kwinrc [Compositing] section"
    fi

    # ── Install TLP (only new dep -- no envycontrol needed) ──
    print_section "Installing dependencies"

    # NOTE: apt install tlp removes power-profiles-daemon as a conflict.
    # This is expected. The 'performance' command reinstalls PPD when needed.
    if ! is_pkg_installed tlp; then
        echo "  Installing tlp and tlp-rdw..."
        echo "  (This will remove power-profiles-daemon -- expected, restored in 'performance' mode)"
        apt-get install -y tlp tlp-rdw 2>&1 | tail -5
        systemctl disable tlp 2>/dev/null || true
        systemctl stop tlp 2>/dev/null || true
        info "TLP installed (not enabled yet -- run 'battery' to activate)"
    else
        skip "TLP already installed"
    fi

    echo "performance" > "$MODE_FILE"
    own_to_user "$MODE_FILE"

    print_section "Setup complete"
    echo ""
    echo -e "  ${GREEN}Ready to use:${NC}"
    echo "    sudo $0 battery      # switch to battery mode"
    echo "    sudo $0 performance  # restore original setup"
    echo "    $0 status             # check current state"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# BATTERY MODE: apply all power optimizations
# ─────────────────────────────────────────────────────────────
do_battery() {
    require_root_for "battery"
    print_header "Switching to Battery Mode"

    if [[ ! -f "$SNAPSHOT_FILE" ]]; then
        err "No snapshot found. Run setup first: sudo $0 setup"
        exit 1
    fi

    local needs_reboot=()

    # ── a) SDDM: switch to Wayland greeter so NVIDIA GPU can idle ──
    print_section "SDDM: switching to Wayland greeter"

    if [[ -f "$SDDM_WAYLAND_CONF" ]] && [[ ! -f "$SDDM_OVERRIDE" ]]; then
        skip "SDDM already configured for Wayland greeter"
    else
        mkdir -p /etc/sddm.conf.d
        cat > "$SDDM_WAYLAND_CONF" <<'SDDM'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --no-global-shortcuts --inputmethod maliit-keyboard --locale1
SDDM
        info "Created $SDDM_WAYLAND_CONF (Wayland greeter via kwin_wayland)"

        if [[ -f "$SDDM_OVERRIDE" ]]; then
            mv "$SDDM_OVERRIDE" "$SDDM_OVERRIDE_DISABLED"
            info "Disabled SDDM NVIDIA override (renamed to .power-mode-disabled)"
        fi

        needs_reboot+=("SDDM switched to Wayland greeter")
    fi

    # ── a2) Prevent NVIDIA modules from loading at boot ──
    print_section "GPU: disabling NVIDIA module autoload + PreserveVideoMemory"

    if [[ -f "$NVIDIA_MODULES_LOAD" ]]; then
        mv "$NVIDIA_MODULES_LOAD" "$NVIDIA_MODULES_LOAD_DISABLED"
        info "Disabled $NVIDIA_MODULES_LOAD (renamed to .power-mode-disabled)"
        needs_reboot+=("NVIDIA module autoload disabled")
    elif [[ -f "$NVIDIA_MODULES_LOAD_DISABLED" ]]; then
        skip "NVIDIA modules-load already disabled"
    else
        skip "No $NVIDIA_MODULES_LOAD found"
    fi

    cat > "$NVIDIA_MODPROBE_BATTERY" <<'NVBAT'
# Managed by power-mode.sh -- do not edit manually
# Override PreserveVideoMemoryAllocations to let the GPU enter D3cold.
options nvidia NVreg_PreserveVideoMemoryAllocations=0
options nvidia NVreg_DynamicPowerManagement=0x02
NVBAT
    info "Created $NVIDIA_MODPROBE_BATTERY (disable VRAM preserve, enable RTD3)"
    update-initramfs -u 2>&1 | tail -1
    needs_reboot+=("NVIDIA modprobe overrides applied")

    # ── b) TLP: enable + configure ──
    print_section "Power management: enabling TLP"

    cat > "$TLP_CONF" <<'TLP'
# ROG Strix G16 battery optimization
# Managed by power-mode.sh -- do not edit manually

CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_BAT=0
CPU_MAX_PERF_ON_BAT=60

PCIE_ASPM_ON_BAT=powersupersave

WIFI_PWR_ON_BAT=on

NMI_WATCHDOG=0

USB_AUTOSUSPEND=1
USB_EXCLUDE_AUDIO=1

RUNTIME_PM_ON_BAT=auto

DISK_APM_LEVEL_ON_BAT="128"
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# ASUS ROG uses "quiet" instead of "low-power"
PLATFORM_PROFILE_ON_BAT=quiet
TLP
    info "TLP config written to $TLP_CONF"

    # Reset governors to powersave so TLP can manage EPP without "device busy" errors
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > "$gov" 2>/dev/null || true
    done

    systemctl enable tlp 2>/dev/null || true
    systemctl start tlp 2>/dev/null || true
    info "TLP enabled and started"

    # ── c) GRUB: add power params ──
    print_section "GRUB: adding power-saving kernel parameters"

    local current_grub
    current_grub=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT=//' | tr -d '"')

    if echo "$current_grub" | grep -q "pcie_aspm.policy=powersupersave"; then
        skip "GRUB already has power-saving params"
    else
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet mem_sleep_default=deep pcie_aspm.policy=powersupersave nmi_watchdog=0"/' "$GRUB_FILE"
        update-grub 2>&1 | tail -2
        info "GRUB updated with power-saving params"
        needs_reboot+=("GRUB params updated")
    fi

    # ── d) Sysctl: NMI watchdog ──
    print_section "Sysctl: disabling NMI watchdog"

    echo "kernel.nmi_watchdog=0" > "$SYSCTL_CONF"
    sysctl -w kernel.nmi_watchdog=0 >/dev/null 2>&1
    info "NMI watchdog disabled (immediate + persistent)"

    # ── e) Powertop auto-tune service ──
    print_section "Powertop: creating auto-tune service"

    cat > "$POWERTOP_SERVICE" <<'PTOP'
[Unit]
Description=Powertop auto-tune for battery optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
PTOP
    systemctl daemon-reload
    systemctl enable powertop-autotune 2>/dev/null || true
    systemctl start powertop-autotune 2>/dev/null || true
    info "Powertop auto-tune service enabled and started"

    # ── f) Brightness ──
    print_section "Brightness: reducing to 35"

    set_brightness 35
    info "Brightness set to 35 / $(get_max_brightness)"

    # ── g) Cursor: enable native Wayland (minimal flags, no GPU overhead) ──
    print_section "Cursor: enabling native Wayland + power-saving settings"

    if [[ -f "$CURSOR_SETTINGS" ]]; then
        if [[ ! -f "$CURSOR_SETTINGS_BACKUP" ]]; then
            cp "$CURSOR_SETTINGS" "$CURSOR_SETTINGS_BACKUP"
            own_to_user "$CURSOR_SETTINGS_BACKUP"
            info "Backed up Cursor settings"
        fi

        python3 -c "
import json
with open('$CURSOR_SETTINGS') as f:
    d = json.load(f)
d['window.enableWayland'] = True
d.pop('disable-hardware-acceleration', None)
d['editor.smoothScrolling'] = False
d['editor.cursorBlinking'] = 'solid'
d['editor.cursorSmoothCaretAnimation'] = 'off'
d['workbench.list.smoothScrolling'] = False
d['editor.minimap.enabled'] = False
d['editor.bracketPairColorization.enabled'] = False
d['editor.renderWhitespace'] = 'none'
d['editor.guides.indentation'] = False
d['editor.occurrencesHighlight'] = 'off'
d['editor.hover.delay'] = 500
d['editor.suggest.preview'] = False
d['editor.parameterHints.enabled'] = False
d['terminal.integrated.gpuAcceleration'] = 'off'
d['extensions.autoUpdate'] = False
d['java.autobuild.enabled'] = False
d['java.import.gradle.enabled'] = False
d['java.server.launchMode'] = 'LightWeight'
with open('$CURSOR_SETTINGS', 'w') as f:
    json.dump(d, f, indent=4)
" 2>/dev/null
        own_to_user "$CURSOR_SETTINGS"
        info "Set Wayland + power-saving editor settings + disabled Java/Gradle extension"
    else
        skip "Cursor settings file not found at $CURSOR_SETTINGS"
    fi

    if [[ -f "$CURSOR_ARGV" ]]; then
        if [[ ! -f "$CURSOR_ARGV_BACKUP" ]]; then
            cp "$CURSOR_ARGV" "$CURSOR_ARGV_BACKUP"
            own_to_user "$CURSOR_ARGV_BACKUP"
        fi
    fi
    local crash_id
    crash_id=$(get_cursor_json_value "$CURSOR_ARGV_BACKUP" "crash-reporter-id" 2>/dev/null || echo "")
    python3 -c "
import json, sys
d = {'enable-crash-reporter': True, 'disable-hardware-acceleration': False}
cid = sys.argv[1]
if cid:
    d['crash-reporter-id'] = cid
with open(sys.argv[2], 'w') as f:
    json.dump(d, f, indent='\t')
    f.write('\n')
" "$crash_id" "$CURSOR_ARGV"
    own_to_user "$CURSOR_ARGV"
    info "Set argv.json (disable-hardware-acceleration=false, Chromium flags go via cursor-flags.conf)"

    if [[ -f "$CURSOR_FLAGS" ]]; then
        if [[ ! -f "$CURSOR_FLAGS_BACKUP" ]]; then
            cp "$CURSOR_FLAGS" "$CURSOR_FLAGS_BACKUP"
            own_to_user "$CURSOR_FLAGS_BACKUP"
        fi
    fi
    cat > "$CURSOR_FLAGS" <<'CFLAGS'
--ozone-platform=wayland
--enable-wayland-ime
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy
CFLAGS
    own_to_user "$CURSOR_FLAGS"
    info "Created $CURSOR_FLAGS (Wayland + GPU accel flags)"

    if [[ -f "$CURSOR_DESKTOP" ]]; then
        if [[ ! -f "$CURSOR_DESKTOP_BACKUP" ]]; then
            cp "$CURSOR_DESKTOP" "$CURSOR_DESKTOP_BACKUP"
            own_to_user "$CURSOR_DESKTOP_BACKUP"
        fi
    fi
    local cursor_appimage_real="${REAL_HOME}/Applications/Cursor.AppImage.real"
    local cursor_appimage="${REAL_HOME}/Applications/Cursor.AppImage"
    if [[ -f "$cursor_appimage" && ! -f "$cursor_appimage_real" ]]; then
        mv "$cursor_appimage" "$cursor_appimage_real"
        own_to_user "$cursor_appimage_real"
        info "Renamed AppImage to Cursor.AppImage.real"
    fi

    cat > "$cursor_appimage" <<'APPWRAP'
#!/bin/bash
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export MESA_LOADER_DRIVER_OVERRIDE=iris
exec "$(dirname "$(readlink -f "$0")")/Cursor.AppImage.real" \
    --ozone-platform=wayland \
    --enable-wayland-ime \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    "$@"
APPWRAP
    chmod +x "$cursor_appimage"
    own_to_user "$cursor_appimage"
    info "Created AppImage wrapper (intercepts ALL launch methods)"

    cat > "$CURSOR_DESKTOP" <<DESK
[Desktop Entry]
Type=Application
Name=Cursor
Comment=AI-powered code editor
Exec=${CURSOR_BIN} %F
Terminal=false
Categories=Development;IDE;Utility;
Icon=cursor
StartupWMClass=Cursor
DESK
    own_to_user "$CURSOR_DESKTOP"
    info "Updated cursor.desktop"

    if [[ -f "$CURSOR_BIN" ]]; then
        if [[ -L "$CURSOR_BIN" ]] || ! grep -q "ELECTRON_OZONE" "$CURSOR_BIN" 2>/dev/null; then
            cp -a "$CURSOR_BIN" "$CURSOR_BIN_BACKUP" 2>/dev/null || true
            own_to_user "$CURSOR_BIN_BACKUP"
        fi
    fi
    rm -f "$CURSOR_BIN"
    cat > "$CURSOR_BIN" <<WRAP
#!/bin/bash
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export MESA_LOADER_DRIVER_OVERRIDE=iris
exec ${cursor_appimage_real} \\
    --ozone-platform=wayland \\
    --enable-wayland-ime \\
    --ignore-gpu-blocklist \\
    --enable-gpu-rasterization \\
    --enable-zero-copy \\
    "\$@"
WRAP
    chmod +x "$CURSOR_BIN"
    own_to_user "$CURSOR_BIN"
    info "Created ~/.local/bin/cursor wrapper"
    warn "Restart Cursor for changes to take effect"

    # ── h) GPU acceleration: reverting app flags (save power) ──
    print_section "GPU acceleration: reverting app flags to save power"

    for pair in \
        "$CHROMIUM_FLAGS:$CHROMIUM_FLAGS_BACKUP" \
        "$VSCODE_FLAGS:$VSCODE_FLAGS_BACKUP" \
        "$SLACK_DESKTOP_USER:$SLACK_DESKTOP_BACKUP"; do
        dst="${pair%%:*}"
        bak="${pair##*:}"
        if [[ -f "$bak" ]]; then
            cp "$bak" "$dst"
            own_to_user "$dst"
            info "Restored $(basename "$dst") from backup"
        elif [[ -f "$dst" ]]; then
            rm -f "$dst"
            info "Removed $(basename "$dst")"
        else
            skip "$(basename "$dst") not present"
        fi
    done

    # KDE compositor: revert GLCore to original
    if [[ -f "$KWIN_RC" ]]; then
        python3 -c "
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out = [l for l in lines if not l.strip().startswith('GLCore=')]
with open(path, 'w') as f:
    f.writelines(out)
" "$KWIN_RC"
        own_to_user "$KWIN_RC"
        info "KDE compositor: reverted GLCore (removed)"
    fi

    # ── i) Stop unnecessary background services ──
    print_section "Services: stopping unnecessary daemons"

    local stopped_services=()
    for svc in "${BATTERY_MODE_SERVICES[@]}"; do
        if [[ "$(is_service_active "$svc")" == "active" ]]; then
            systemctl stop "$svc" 2>/dev/null || true
            systemctl mask "$svc" 2>/dev/null || true
            stopped_services+=("$svc")
            info "Stopped and masked $svc"
        else
            skip "$svc already inactive"
        fi
    done

    printf '%s\n' "${stopped_services[@]}" > "$BATTERY_SERVICES_FILE"
    own_to_user "$BATTERY_SERVICES_FILE"
    info "Recorded ${#stopped_services[@]} stopped services to $BATTERY_SERVICES_FILE"

    # ── j) CPU thread offlining: keep 8 of 32 threads ──
    print_section "CPU: offlining threads (keeping 8 of 32)"

    local cpus_offlined=0
    for cpu in $(seq 8 31); do
        local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
        if [[ -f "$online_file" ]]; then
            echo 0 > "$online_file" 2>/dev/null || true
            ((cpus_offlined++)) || true
        fi
    done
    info "Offlined $cpus_offlined CPU threads (cpu8-cpu31)"

    # ── k) Intel iGPU frequency cap ──
    print_section "iGPU: capping max frequency to 450MHz"

    local igpu_max_freq="/sys/class/drm/card0/gt_max_freq_mhz"
    local igpu_max_freq_alt="/sys/class/drm/card1/gt_max_freq_mhz"
    if [[ -f "$igpu_max_freq" ]]; then
        local orig_igpu_freq
        orig_igpu_freq=$(cat "$igpu_max_freq" 2>/dev/null || echo "")
        if [[ -n "$orig_igpu_freq" ]]; then
            echo "$orig_igpu_freq" > "$CONFIG_DIR/igpu_orig_freq"
            own_to_user "$CONFIG_DIR/igpu_orig_freq"
            echo 450 > "$igpu_max_freq" 2>/dev/null || true
            info "iGPU max freq capped: ${orig_igpu_freq}MHz -> 450MHz (card0)"
        fi
    elif [[ -f "$igpu_max_freq_alt" ]]; then
        local orig_igpu_freq
        orig_igpu_freq=$(cat "$igpu_max_freq_alt" 2>/dev/null || echo "")
        if [[ -n "$orig_igpu_freq" ]]; then
            echo "$orig_igpu_freq" > "$CONFIG_DIR/igpu_orig_freq"
            own_to_user "$CONFIG_DIR/igpu_orig_freq"
            echo 450 > "$igpu_max_freq_alt" 2>/dev/null || true
            info "iGPU max freq capped: ${orig_igpu_freq}MHz -> 450MHz (card1)"
        fi
    else
        warn "iGPU sysfs not found at card0 or card1"
    fi

    # ── l) Display resolution: lower to 1920x1200 ──
    print_section "Display: lowering resolution to 1920x1200"

    local kscreen_out
    kscreen_out=$(run_as_user_wayland kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    local current_mode_info
    current_mode_info=$(echo "$kscreen_out" | grep -oP '\d+:\S+\*' | head -1 || echo "")
    local current_res
    current_res=$(echo "$current_mode_info" | grep -oP '\d+x\d+' || echo "")
    local current_mode_id
    current_mode_id=$(echo "$current_mode_info" | grep -oP '^\d+' || echo "")
    local output_name
    output_name=$(echo "$kscreen_out" | grep -oP '^Output: \d+ \K\S+' | head -1 || echo "")

    if [[ -n "$current_res" && "$current_res" != "1920x1200" && -n "$output_name" ]]; then
        echo "$current_res" > "$CONFIG_DIR/orig_resolution"
        own_to_user "$CONFIG_DIR/orig_resolution"
        if [[ -n "$current_mode_id" ]]; then
            echo "$current_mode_id" > "$CONFIG_DIR/orig_mode_id"
            own_to_user "$CONFIG_DIR/orig_mode_id"
        fi
        run_as_user_wayland kscreen-doctor output."$output_name".mode.1920x1200@60 2>/dev/null || \
            warn "Could not set 1920x1200 via kscreen-doctor"
        info "Display resolution: ${current_res} -> 1920x1200 on $output_name"
    elif [[ "$current_res" == "1920x1200" ]]; then
        skip "Display already at 1920x1200"
    else
        warn "Could not detect current resolution or output"
    fi

    # ── m) ASPM, NVMe APST, WiFi power save ──
    print_section "Hardware: enforcing ASPM, NVMe APST, WiFi power save"

    local aspm_policy="/sys/module/pcie_aspm/parameters/policy"
    if [[ -f "$aspm_policy" ]]; then
        echo powersupersave > "$aspm_policy" 2>/dev/null || \
            warn "Could not write to $aspm_policy (may need kernel support)"
        local current_aspm
        current_aspm=$(cat "$aspm_policy" 2>/dev/null || echo "unknown")
        info "PCIe ASPM policy: $current_aspm"
    else
        skip "ASPM sysfs not available"
    fi

    for nvme_dev in /sys/class/nvme/nvme*/device/power/autosuspend_delay_ms; do
        if [[ -f "$nvme_dev" ]]; then
            echo 5000 > "$nvme_dev" 2>/dev/null || true
            info "NVMe APST: autosuspend delay set to 5000ms ($(dirname "$(dirname "$nvme_dev")" | xargs basename))"
        fi
    done

    local wifi_dev
    wifi_dev=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1 || echo "")
    if [[ -n "$wifi_dev" ]]; then
        iw dev "$wifi_dev" set power_save on 2>/dev/null || true
        info "WiFi power save enabled on $wifi_dev"
    else
        skip "No WiFi interface found"
    fi

    echo "battery" > "$MODE_FILE"
    own_to_user "$MODE_FILE"

    print_header "Battery Mode Applied"
    echo ""
    echo -e "  ${GREEN}Instant changes applied:${NC}"
    echo "    - TLP enabled (CPU max 60%, turbo off)"
    echo "    - NMI watchdog disabled"
    echo "    - Powertop auto-tune running"
    echo "    - Brightness set to 35"
    echo "    - CPU threads: 8 online, 24 offlined"
    echo "    - iGPU capped at 450MHz"
    echo "    - Display resolution lowered to 1920x1200"
    echo "    - PCIe ASPM, NVMe APST, WiFi power save enforced"
    echo "    - Cursor set to native Wayland (restart Cursor)"
    echo "    - Java/Gradle extensions disabled in Cursor"
    echo "    - GPU accel flags removed for Chromium, VS Code, Slack"
    echo "    - KDE compositor GLCore reverted"
    echo "    - ${#stopped_services[@]} unnecessary services stopped"
    echo "    - SDDM set to Wayland greeter (NVIDIA GPU will idle after reboot)"
    echo ""
    echo -e "  ${YELLOW}Tip: Close VSCode and Firefox for best power savings.${NC}"
    echo ""

    if [[ ${#needs_reboot[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Reboot required for:${NC}"
        for item in "${needs_reboot[@]}"; do
            echo "    - $item"
        done
        echo ""
        echo -e "  Run: ${BOLD}sudo reboot${NC}"
    else
        echo -e "  ${GREEN}No reboot needed -- all changes are active.${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────
# PERFORMANCE MODE: restore original system state from snapshot
# ─────────────────────────────────────────────────────────────
do_performance() {
    require_root_for "performance"
    print_header "Restoring Performance Mode (original state)"

    if [[ ! -f "$SNAPSHOT_FILE" ]]; then
        err "No snapshot found. Cannot restore without a snapshot."
        err "If you haven't run setup, the system is already in its original state."
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$SNAPSHOT_FILE"

    local needs_reboot=()

    # ── a) SDDM: restore X11 greeter and NVIDIA override ──
    print_section "SDDM: restoring X11 greeter"

    if [[ -f "$SDDM_WAYLAND_CONF" ]]; then
        rm -f "$SDDM_WAYLAND_CONF"
        info "Removed $SDDM_WAYLAND_CONF"
    else
        skip "Wayland greeter config not present"
    fi

    if [[ -f "$SDDM_OVERRIDE_DISABLED" ]]; then
        mv "$SDDM_OVERRIDE_DISABLED" "$SDDM_OVERRIDE"
        info "Restored SDDM NVIDIA override"
        needs_reboot+=("SDDM restored to X11 greeter")
    elif [[ -f "$CONFIG_DIR/sddm-override.bak" ]] && [[ ! -f "$SDDM_OVERRIDE" ]]; then
        mkdir -p "$(dirname "$SDDM_OVERRIDE")"
        cp "$CONFIG_DIR/sddm-override.bak" "$SDDM_OVERRIDE"
        info "Restored SDDM NVIDIA override from backup"
        needs_reboot+=("SDDM restored to X11 greeter")
    else
        skip "SDDM NVIDIA override already in place"
    fi

    # ── a2) Restore NVIDIA module autoload + remove battery modprobe override ──
    print_section "GPU: restoring NVIDIA module autoload"

    if [[ -f "$NVIDIA_MODULES_LOAD_DISABLED" ]]; then
        mv "$NVIDIA_MODULES_LOAD_DISABLED" "$NVIDIA_MODULES_LOAD"
        info "Restored $NVIDIA_MODULES_LOAD"
        needs_reboot+=("NVIDIA module autoload restored")
    elif [[ -f "$NVIDIA_MODULES_LOAD" ]]; then
        skip "NVIDIA modules-load already in place"
    else
        skip "No NVIDIA modules-load file to restore"
    fi

    if [[ -f "$NVIDIA_MODPROBE_BATTERY" ]]; then
        rm -f "$NVIDIA_MODPROBE_BATTERY"
        info "Removed $NVIDIA_MODPROBE_BATTERY"
        update-initramfs -u 2>&1 | tail -1
    fi

    # ── b) TLP off, reinstall PPD ──
    print_section "Power management: restoring power-profiles-daemon"

    systemctl stop tlp 2>/dev/null || true
    systemctl disable tlp 2>/dev/null || true
    info "TLP stopped and disabled"
    rm -f "$TLP_CONF"

    if is_pkg_installed tlp; then
        echo "  Removing TLP (conflicts with power-profiles-daemon)..."
        apt-get remove -y tlp tlp-rdw 2>&1 | tail -3
        info "TLP packages removed"
    else
        info "TLP already removed"
    fi

    # Always ensure a power manager is active in performance mode.
    # The snapshot may incorrectly show PPD as "not installed" if setup ran
    # after TLP had already removed it, so we install unconditionally.
    if ! is_pkg_installed power-profiles-daemon; then
        echo "  Installing power-profiles-daemon..."
        apt-get install -y power-profiles-daemon 2>&1 | tail -3
        info "power-profiles-daemon installed"
    else
        info "power-profiles-daemon already installed"
    fi
    # Reset governors to powersave so PPD can manage EPP without "device busy" errors
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > "$gov" 2>/dev/null || true
    done

    systemctl enable power-profiles-daemon 2>/dev/null || true
    systemctl start power-profiles-daemon 2>/dev/null || true
    powerprofilesctl set performance 2>/dev/null || true
    info "power-profiles-daemon enabled, started, set to performance profile"

    # ── c) GRUB: restore original ──
    print_section "GRUB: restoring original kernel parameters"

    local current_grub
    current_grub=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT=//' | tr -d '"')

    if [[ "$current_grub" == "${ORIGINAL_GRUB_CMDLINE_DEFAULT}" ]]; then
        skip "GRUB already matches original"
    else
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${ORIGINAL_GRUB_CMDLINE_DEFAULT}\"/" "$GRUB_FILE"
        update-grub 2>&1 | tail -2
        info "GRUB restored to: GRUB_CMDLINE_LINUX_DEFAULT=\"${ORIGINAL_GRUB_CMDLINE_DEFAULT}\""
        needs_reboot+=("GRUB params restored")
    fi

    # ── d) Sysctl: remove and restore ──
    print_section "Sysctl: restoring NMI watchdog"

    rm -f "$SYSCTL_CONF"
    sysctl -w "kernel.nmi_watchdog=${ORIGINAL_NMI_WATCHDOG}" >/dev/null 2>&1
    info "NMI watchdog restored to ${ORIGINAL_NMI_WATCHDOG}"

    # ── e) Powertop service: remove ──
    print_section "Powertop: removing auto-tune service"

    if [[ -f "$POWERTOP_SERVICE" ]]; then
        systemctl stop powertop-autotune 2>/dev/null || true
        systemctl disable powertop-autotune 2>/dev/null || true
        rm -f "$POWERTOP_SERVICE"
        systemctl daemon-reload
        info "Powertop auto-tune service removed"
    else
        skip "Powertop service not present"
    fi

    # ── f) Brightness: restore ──
    print_section "Brightness: restoring to ${ORIGINAL_BRIGHTNESS}"

    if [[ "${ORIGINAL_BRIGHTNESS}" != "unknown" ]]; then
        set_brightness "${ORIGINAL_BRIGHTNESS}"
        info "Brightness restored to ${ORIGINAL_BRIGHTNESS} / $(get_max_brightness)"
    else
        skip "Original brightness unknown, not changing"
    fi

    # ── g) Cursor: restore original settings ──
    print_section "Cursor: restoring original settings"

    if [[ -f "$CURSOR_SETTINGS_BACKUP" ]]; then
        cp "$CURSOR_SETTINGS_BACKUP" "$CURSOR_SETTINGS"
        own_to_user "$CURSOR_SETTINGS"
        info "Cursor settings.json restored from backup"
    else
        skip "No Cursor settings backup found"
    fi

    if [[ -f "$CURSOR_ARGV_BACKUP" ]]; then
        cp "$CURSOR_ARGV_BACKUP" "$CURSOR_ARGV"
        own_to_user "$CURSOR_ARGV"
        info "Cursor argv.json restored from backup"
    elif [[ -f "$CURSOR_ARGV" ]]; then
        rm -f "$CURSOR_ARGV"
        info "Removed Cursor argv.json (was not present originally)"
    fi

    if [[ -f "$CURSOR_FLAGS_BACKUP" ]]; then
        cp "$CURSOR_FLAGS_BACKUP" "$CURSOR_FLAGS"
        own_to_user "$CURSOR_FLAGS"
        info "Cursor flags restored from backup"
    elif [[ -f "$CURSOR_FLAGS" ]]; then
        rm -f "$CURSOR_FLAGS"
        info "Removed cursor-flags.conf (was not present originally)"
    fi

    if [[ -f "$CURSOR_DESKTOP_BACKUP" ]]; then
        cp "$CURSOR_DESKTOP_BACKUP" "$CURSOR_DESKTOP"
        own_to_user "$CURSOR_DESKTOP"
        info "Cursor desktop file restored from backup"
    fi

    local cursor_appimage_real="${REAL_HOME}/Applications/Cursor.AppImage.real"
    local cursor_appimage="${REAL_HOME}/Applications/Cursor.AppImage"
    if [[ -f "$cursor_appimage_real" ]]; then
        rm -f "$cursor_appimage"
        mv "$cursor_appimage_real" "$cursor_appimage"
        own_to_user "$cursor_appimage"
        info "Restored original Cursor.AppImage (removed wrapper)"
    fi

    if [[ -f "$CURSOR_BIN_BACKUP" ]]; then
        rm -f "$CURSOR_BIN"
        cp -a "$CURSOR_BIN_BACKUP" "$CURSOR_BIN"
        own_to_user "$CURSOR_BIN"
        info "Cursor bin wrapper restored from backup"
    fi
    warn "Restart Cursor for changes to take effect"

    # ── h) GPU acceleration: enable for Chromium, VS Code, Slack, KDE ──
    print_section "GPU acceleration: enabling for desktop apps"

    cat > "$CHROMIUM_FLAGS" <<'GPUFLAGS'
--ozone-platform-hint=auto
--enable-gpu-rasterization
--enable-zero-copy
--ignore-gpu-blocklist
--enable-features=UseOzonePlatform,WaylandWindowDecorations,VaapiVideoDecoder,VaapiVideoEncoder
--enable-wayland-ime
GPUFLAGS
    own_to_user "$CHROMIUM_FLAGS"
    info "Created chromium-flags.conf (Wayland + GPU raster + VA-API decode)"

    cat > "$VSCODE_FLAGS" <<'GPUFLAGS'
--ozone-platform-hint=auto
--enable-gpu-rasterization
--enable-zero-copy
--ignore-gpu-blocklist
--enable-wayland-ime
GPUFLAGS
    own_to_user "$VSCODE_FLAGS"
    info "Created code-flags.conf (Wayland + GPU raster)"

    if command -v snap &>/dev/null && snap list slack &>/dev/null 2>&1; then
        mkdir -p "$(dirname "$SLACK_DESKTOP_USER")"
        cat > "$SLACK_DESKTOP_USER" <<'SLACKDESK'
[Desktop Entry]
X-SnapInstanceName=slack
Name=Slack
StartupWMClass=Slack
Comment=Slack Desktop
GenericName=Slack Client for Linux
X-SnapAppName=slack
Exec=env ELECTRON_OZONE_PLATFORM_HINT=wayland /snap/bin/slack --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --ozone-platform-hint=auto %U
Icon=/snap/slack/current/usr/share/pixmaps/slack.png
Type=Application
StartupNotify=true
Categories=GNOME;GTK;Network;InstantMessaging;
MimeType=x-scheme-handler/slack;
SLACKDESK
        own_to_user "$SLACK_DESKTOP_USER"
        info "Updated Slack desktop file (Wayland + GPU raster + PipeWire)"
    else
        skip "Slack snap not installed, skipping"
    fi

    # KDE Plasma compositor: enable OpenGL core profile for efficient GPU rendering
    if [[ -f "$KWIN_RC" ]]; then
        python3 -c "
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
in_section = False
glcore_found = False
for i, line in enumerate(lines):
    s = line.strip()
    if s.startswith('['):
        if in_section and not glcore_found:
            lines.insert(i, 'GLCore=true\n')
            glcore_found = True
            break
        in_section = (s == '[Compositing]')
    elif in_section and s.startswith('GLCore='):
        lines[i] = 'GLCore=true\n'
        glcore_found = True
        break
if in_section and not glcore_found:
    lines.append('GLCore=true\n')
    glcore_found = True
if not glcore_found:
    lines.append('\n[Compositing]\nGLCore=true\n')
with open(path, 'w') as f:
    f.writelines(lines)
" "$KWIN_RC"
        own_to_user "$KWIN_RC"
        info "KDE compositor: enabled OpenGL core profile (GLCore=true)"
    fi

    warn "Restart Chromium, VS Code, and Slack for GPU acceleration"

    # ── i) Services: unmask and restart previously stopped services ──
    print_section "Services: restoring background daemons"

    if [[ -f "$BATTERY_SERVICES_FILE" ]]; then
        local restored_count=0
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            systemctl unmask "$svc" 2>/dev/null || true
            systemctl start "$svc" 2>/dev/null || true
            info "Unmasked and started $svc"
            ((restored_count++)) || true
        done < "$BATTERY_SERVICES_FILE"
        rm -f "$BATTERY_SERVICES_FILE"
        info "Restored $restored_count services"
    else
        skip "No stopped-services list found"
    fi

    # ── j) CPU threads: bring all back online ──
    print_section "CPU: restoring all threads online"

    local cpus_onlined=0
    for cpu in $(seq 8 31); do
        local online_file="/sys/devices/system/cpu/cpu${cpu}/online"
        if [[ -f "$online_file" ]]; then
            local cur_state
            cur_state=$(cat "$online_file" 2>/dev/null || echo "1")
            if [[ "$cur_state" == "0" ]]; then
                echo 1 > "$online_file" 2>/dev/null || true
                ((cpus_onlined++)) || true
            fi
        fi
    done
    info "Brought $cpus_onlined CPU threads back online"

    # ── k) iGPU: restore original max frequency ──
    print_section "iGPU: restoring max frequency"

    if [[ -f "$CONFIG_DIR/igpu_orig_freq" ]]; then
        local orig_freq
        orig_freq=$(cat "$CONFIG_DIR/igpu_orig_freq")
        local igpu_max_freq="/sys/class/drm/card0/gt_max_freq_mhz"
        local igpu_max_freq_alt="/sys/class/drm/card1/gt_max_freq_mhz"
        if [[ -f "$igpu_max_freq" ]]; then
            echo "$orig_freq" > "$igpu_max_freq" 2>/dev/null || true
            info "iGPU max freq restored to ${orig_freq}MHz (card0)"
        elif [[ -f "$igpu_max_freq_alt" ]]; then
            echo "$orig_freq" > "$igpu_max_freq_alt" 2>/dev/null || true
            info "iGPU max freq restored to ${orig_freq}MHz (card1)"
        fi
        rm -f "$CONFIG_DIR/igpu_orig_freq"
    else
        skip "No saved iGPU frequency to restore"
    fi

    # ── l) CPU frequency: unlock and let PPD manage governor ──
    print_section "CPU: unlocking frequency limits and enabling turbo"

    if [[ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]]; then
        echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || true
        info "CPU max_perf_pct set to 100%"
    fi
    if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        info "Turbo boost enabled"
    fi

    # ── m) ASUS thermal policy: turbo mode (fans + PL1/PL2) ──
    print_section "ASUS: setting turbo thermal profile (fans will ramp up)"

    local asus_thermal="/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy"
    if [[ -f "$asus_thermal" ]]; then
        local prev_thermal
        prev_thermal=$(cat "$asus_thermal" 2>/dev/null || echo "?")
        echo 1 > "$asus_thermal" 2>/dev/null || true
        local new_thermal
        new_thermal=$(cat "$asus_thermal" 2>/dev/null || echo "?")
        info "Thermal policy: $prev_thermal -> $new_thermal (0=balanced, 1=turbo, 2=silent)"
    else
        skip "ASUS thermal policy sysfs not available"
    fi

    local ppt_pl1="/sys/devices/platform/asus-nb-wmi/ppt_pl1_spl"
    local ppt_pl2="/sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt"
    if [[ -f "$ppt_pl1" ]]; then
        local new_pl1
        new_pl1=$(cat "$ppt_pl1" 2>/dev/null || echo "?")
        local new_pl2
        new_pl2=$(cat "$ppt_pl2" 2>/dev/null || echo "?")
        info "CPU power limits after turbo profile: PL1=${new_pl1}W, PL2=${new_pl2}W"
    fi

    # ── n) NVIDIA GPU: persistence mode and clock unlock ──
    print_section "NVIDIA GPU: enabling persistence mode and unlocking clocks"

    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi -pm 1 2>/dev/null && \
            info "NVIDIA persistence mode enabled" || \
            warn "Could not enable NVIDIA persistence mode"

        local max_gpu_clock
        max_gpu_clock=$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
        if [[ -n "$max_gpu_clock" && "$max_gpu_clock" =~ ^[0-9]+$ ]]; then
            nvidia-smi -lgc 300,"$max_gpu_clock" 2>/dev/null && \
                info "GPU clock range unlocked: 300-${max_gpu_clock} MHz" || \
                warn "Could not set GPU clock range"
        else
            skip "Could not query max GPU clock"
        fi

        local nv_boost="/sys/devices/platform/asus-nb-wmi/nv_dynamic_boost"
        if [[ -f "$nv_boost" ]]; then
            local cur_boost
            cur_boost=$(cat "$nv_boost" 2>/dev/null || echo "?")
            info "NVIDIA dynamic boost: ${cur_boost}W (set by thermal profile)"
        fi
    else
        skip "nvidia-smi not found, skipping GPU performance tuning"
    fi

    # ── o) Display resolution: restore original ──
    print_section "Display: restoring original resolution"

    if [[ -f "$CONFIG_DIR/orig_resolution" ]]; then
        local orig_res
        orig_res=$(cat "$CONFIG_DIR/orig_resolution")
        local kscreen_out
        kscreen_out=$(run_as_user_wayland kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
        local output_name
        output_name=$(echo "$kscreen_out" | grep -oP '^Output: \d+ \K\S+' | head -1 || echo "")

        if [[ -n "$output_name" ]]; then
            local restore_arg="${orig_res}@60"
            if [[ -f "$CONFIG_DIR/orig_mode_id" ]]; then
                restore_arg=$(cat "$CONFIG_DIR/orig_mode_id")
            fi
            run_as_user_wayland kscreen-doctor output."$output_name".mode."$restore_arg" 2>/dev/null || \
                warn "Could not restore resolution to $orig_res"
            info "Display resolution restored to $orig_res"
        else
            warn "Could not detect output name for resolution restore"
        fi
        rm -f "$CONFIG_DIR/orig_resolution" "$CONFIG_DIR/orig_mode_id"
    else
        skip "No saved resolution to restore"
    fi

    echo "performance" > "$MODE_FILE"
    own_to_user "$MODE_FILE"

    print_header "Performance Mode Restored"
    echo ""
    echo -e "  ${GREEN}Performance changes applied:${NC}"
    echo "    - SDDM restored to X11 greeter with NVIDIA override"
    echo "    - power-profiles-daemon: performance profile active"
    echo "    - TLP disabled, config removed"
    echo "    - ASUS thermal policy: turbo (fans will ramp for max cooling)"
    echo "    - CPU: turbo boost on, 100% uncapped (PPD manages governor)"
    echo "    - All 32 CPU threads online"
    echo "    - NVIDIA GPU: persistence mode, clocks unlocked"
    echo "    - iGPU max frequency restored"
    echo "    - Display resolution restored, brightness restored"
    echo "    - GPU accel enabled: Chromium, VS Code, Slack (restart apps)"
    echo "    - KDE compositor: OpenGL core profile enabled"
    echo "    - Background services restored"
    echo ""

    if [[ ${#needs_reboot[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Reboot required for:${NC}"
        for item in "${needs_reboot[@]}"; do
            echo "    - $item"
        done
        echo ""
        echo -e "  Run: ${BOLD}sudo reboot${NC}"
    else
        echo -e "  ${GREEN}No reboot needed -- all changes are active.${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────
# STATUS: show current state
# ─────────────────────────────────────────────────────────────
do_status() {
    print_header "Power Mode Status"

    local mode gpu_mode power_mgr cpu_turbo brightness max_brightness
    local power_draw battery_pct battery_status

    mode=$(get_current_mode)
    gpu_mode=$(get_gpu_mode)

    if [[ "$(is_service_active tlp)" == "active" ]]; then
        power_mgr="TLP"
    elif [[ "$(is_service_active power-profiles-daemon)" == "active" ]]; then
        local profile
        profile=$(powerprofilesctl get 2>/dev/null || echo "unknown")
        power_mgr="power-profiles-daemon ($profile)"
    else
        power_mgr="none"
    fi

    local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"
    if [[ -f "$turbo_file" ]]; then
        local no_turbo
        no_turbo=$(cat "$turbo_file")
        if [[ "$no_turbo" == "1" ]]; then
            cpu_turbo="off"
        else
            cpu_turbo="on"
        fi
    else
        cpu_turbo="unknown"
    fi

    brightness=$(get_current_brightness)
    max_brightness=$(get_max_brightness)
    power_draw=$(get_power_draw_watts)
    battery_pct=$(get_battery_percent)
    battery_status=$(get_battery_status)

    local est_hours="--"
    if [[ "$battery_status" == "Discharging" && "$power_draw" != "unknown" && "$power_draw" != "0" ]]; then
        local energy_now
        energy_now=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo "0")
        if [[ "$energy_now" -gt 0 ]]; then
            local power_now_raw
            power_now_raw=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo "0")
            if [[ "$power_now_raw" -gt 0 ]]; then
                est_hours=$(echo "scale=1; $energy_now / $power_now_raw" | bc 2>/dev/null || echo "--")
            fi
        fi
    fi

    local nmi
    nmi=$(cat /proc/sys/kernel/nmi_watchdog 2>/dev/null || echo "unknown")

    local cpus_online=0
    for cpu in /sys/devices/system/cpu/cpu[0-9]*/online; do
        if [[ -f "$cpu" ]]; then
            local state
            state=$(cat "$cpu" 2>/dev/null || echo "1")
            [[ "$state" == "1" ]] && ((cpus_online++)) || true
        fi
    done
    ((cpus_online++)) || true  # cpu0 has no online file, always online

    local igpu_freq="unknown"
    if [[ -f /sys/class/drm/card0/gt_max_freq_mhz ]]; then
        igpu_freq="$(cat /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null)MHz"
    elif [[ -f /sys/class/drm/card1/gt_max_freq_mhz ]]; then
        igpu_freq="$(cat /sys/class/drm/card1/gt_max_freq_mhz 2>/dev/null)MHz"
    fi

    local sddm_greeter
    if [[ -f "$SDDM_WAYLAND_CONF" ]]; then
        sddm_greeter="wayland (kwin_wayland)"
    else
        sddm_greeter="x11 (default)"
    fi

    local cursor_rendering
    local cur_wayland cur_hwaccel cur_hwaccel_argv
    cur_wayland=$(get_cursor_json_value "$CURSOR_SETTINGS" "window.enableWayland")
    cur_hwaccel=$(get_cursor_json_value "$CURSOR_SETTINGS" "disable-hardware-acceleration")
    cur_hwaccel_argv=$(get_cursor_json_value "$CURSOR_ARGV" "disable-hardware-acceleration")
    local hw_disabled="false"
    [[ "$cur_hwaccel" == "true" || "$cur_hwaccel_argv" == "true" ]] && hw_disabled="true"
    if [[ "$cur_wayland" == "true" && "$hw_disabled" != "true" ]]; then
        cursor_rendering="native Wayland + GPU accel"
    elif [[ "$cur_wayland" == "true" ]]; then
        cursor_rendering="native Wayland, SW rendering (high CPU!)"
    elif [[ "$hw_disabled" != "true" ]]; then
        cursor_rendering="XWayland + GPU accel"
    else
        cursor_rendering="XWayland + SW rendering (high CPU!)"
    fi

    local bg_services_active=0
    for svc in "${BATTERY_MODE_SERVICES[@]}"; do
        [[ "$(is_service_active "$svc")" == "active" ]] && ((bg_services_active++)) || true
    done

    local aspm_status="unknown"
    if [[ -f /sys/module/pcie_aspm/parameters/policy ]]; then
        aspm_status=$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo "unknown")
    fi

    local chromium_gpu="no flags"
    [[ -f "$CHROMIUM_FLAGS" ]] && chromium_gpu="GPU accel + Wayland"
    local vscode_gpu="no flags"
    [[ -f "$VSCODE_FLAGS" ]] && vscode_gpu="GPU accel + Wayland"
    local slack_gpu="default"
    [[ -f "$SLACK_DESKTOP_USER" ]] && grep -q "enable-gpu-rasterization" "$SLACK_DESKTOP_USER" 2>/dev/null && slack_gpu="GPU accel + Wayland"
    local kde_glcore="off"
    grep -q "^GLCore=true" "$KWIN_RC" 2>/dev/null && kde_glcore="on"

    echo ""
    echo -e "  Mode:            ${BOLD}${mode}${NC}"
    echo -e "  GPU:             ${gpu_mode}"
    echo -e "  SDDM greeter:    ${sddm_greeter}"
    echo -e "  Cursor:          ${cursor_rendering}"
    echo -e "  Chromium:        ${chromium_gpu}"
    echo -e "  VS Code:         ${vscode_gpu}"
    echo -e "  Slack:           ${slack_gpu}"
    echo -e "  KDE GLCore:      ${kde_glcore}"
    echo -e "  Bg services:     ${bg_services_active}/${#BATTERY_MODE_SERVICES[@]} active"
    echo -e "  Power manager:   ${power_mgr}"
    echo -e "  CPU turbo:       ${cpu_turbo}"
    echo -e "  CPU threads:     ${cpus_online}/32 online"
    echo -e "  iGPU max freq:   ${igpu_freq}"
    echo -e "  PCIe ASPM:       ${aspm_status}"
    echo -e "  NMI watchdog:    ${nmi}"
    echo -e "  Brightness:      ${brightness} / ${max_brightness}"
    echo -e "  Power draw:      ${power_draw}W"
    echo -e "  Battery:         ${battery_pct}%, ${battery_status}"
    echo -e "  Est. remaining:  ${est_hours}h"

    if [[ -f "$SNAPSHOT_FILE" ]]; then
        echo ""
        echo -e "  ${BLUE}Snapshot:${NC}  $SNAPSHOT_FILE"
    else
        echo ""
        echo -e "  ${YELLOW}No snapshot found. Run:${NC} sudo $0 setup"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────
case "${1:-}" in
    setup)
        do_setup
        ;;
    battery)
        do_battery
        ;;
    performance)
        do_performance
        ;;
    status)
        do_status
        ;;
    *)
        echo "Usage: $0 {setup|battery|performance|status}"
        echo ""
        echo "  setup        One-time: snapshot current state + install TLP"
        echo "  battery      Switch to battery mode (~6h battery life)"
        echo "  performance  Restore original setup exactly"
        echo "  status       Show current mode and power draw"
        exit 1
        ;;
esac
