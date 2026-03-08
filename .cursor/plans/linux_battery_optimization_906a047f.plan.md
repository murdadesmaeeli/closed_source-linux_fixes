---
name: Linux Battery Optimization
overview: Reduce power draw from ~40W to ~13W on the ASUS ROG Strix G16 (i9-14900HX + RTX 4060) running Debian 13. Built as a fully reversible toggle -- one command to enter battery mode, one command to restore the original setup exactly.
todos:
  - id: setup-script
    content: "Create bash/power-mode.sh with subcommands: setup, battery, performance, status. Handles snapshot, apply, and full restore."
    status: completed
  - id: snapshot
    content: Snapshot current system state (GRUB, services, sysctl, brightness, GPU mode) to ~/.config/power-mode/snapshot.conf before any changes.
    status: completed
  - id: install-deps
    content: Install envycontrol and reinstall TLP (the only two new packages). Record them in snapshot so uninstall is possible.
    status: pending
  - id: battery-mode
    content: "Implement 'battery' subcommand: switch GPU to integrated, enable TLP, mask PPD, apply GRUB params, sysctl, powertop, brightness."
    status: completed
  - id: performance-mode
    content: "Implement 'performance' subcommand: restore GPU to hybrid, unmask PPD, disable TLP, restore GRUB, remove sysctl, restore brightness."
    status: completed
  - id: status-cmd
    content: "Implement 'status' subcommand: show current mode, GPU state, active power manager, power draw, brightness."
    status: completed
  - id: verify
    content: Test both directions of the toggle. Measure power draw in battery mode, confirm ~13W target. Switch back to performance and confirm original state is restored.
    status: pending
isProject: false
---

# Linux Battery Optimization: Reversible Toggle (2h -> 6h)

## Design Principle: Full Reversibility

Every change is implemented as a **toggle switch**. A single script (`bash/power-mode.sh`) manages two modes:

- `battery` -- all power optimizations ON (target: ~13W, ~6h battery)
- `performance` -- restores the **exact original system state** (current ~40W setup)

Before any changes are made, the script snapshots the current config so it can always be restored.

```
bash/power-mode.sh setup        # one-time: install deps + snapshot current state
bash/power-mode.sh battery      # switch to battery mode (some changes need reboot)
bash/power-mode.sh performance  # restore original setup exactly
bash/power-mode.sh status       # show current mode + power draw
```

## Verified System State

- **Laptop:** ASUS ROG Strix G16 G614JVR
- **CPU:** Intel i9-14900HX, governor: powersave
- **GPU:** Intel UHD (iGPU) + NVIDIA RTX 4060 Max-Q (dGPU) -- dGPU is **active** and drawing power
- **Battery:** 77 Wh usable, currently drawing **~40W** = ~1.9h
- **Session:** Wayland (KDE Plasma)
- **Already installed:** powertop, power-profiles-daemon (active), thermald
- **Previously removed:** TLP (due to conflict with power-profiles-daemon -- we handle this properly now)
- **Deliberately disabled:** audio power save (popping fix) -- will NOT change this
- **NVIDIA config:** DynamicPowerManagement=3, S0ix enabled, modeset=1

---

## Architecture: What Changes and How It Reverses

Each change has a forward (battery) and reverse (performance) operation:


| Change                | Battery Mode (forward)            | Performance Mode (reverse)                         |
| --------------------- | --------------------------------- | -------------------------------------------------- |
| GPU                   | `envycontrol -s integrated`       | `envycontrol -s hybrid --rtd3`                     |
| TLP                   | `apt install tlp`, enable service | stop and disable TLP service                       |
| power-profiles-daemon | `systemctl mask`                  | `systemctl unmask`, start, enable                  |
| GRUB cmdline          | add power params, `update-grub`   | restore original line from snapshot, `update-grub` |
| sysctl                | create `99-powersave.conf`        | delete file, `sysctl -w kernel.nmi_watchdog=1`     |
| powertop service      | create + enable systemd unit      | stop, disable, delete unit                         |
| brightness            | set to 35                         | restore to snapshotted value                       |


**Reboot-required changes:** GPU switch, GRUB params. The script reports this clearly.
**Instant changes:** TLP/PPD swap, sysctl, powertop, brightness.

---

## Step 1: Create the snapshot mechanism

Before any changes, `bash/power-mode.sh setup` captures the current state to `~/.config/power-mode/snapshot.conf`:

```bash
# Snapshot contents (key=value):
ORIGINAL_GRUB_CMDLINE_DEFAULT='quiet'
ORIGINAL_BRIGHTNESS=60
ORIGINAL_NMI_WATCHDOG=1
ORIGINAL_PPD_ENABLED=yes
ORIGINAL_PPD_ACTIVE=yes
ORIGINAL_TLP_INSTALLED=no
ORIGINAL_GPU_MODE=hybrid
SETUP_COMPLETE=yes
```

This file is the **single source of truth** for restoration. The `performance` subcommand reads it and restores every value.

---

## Step 2: Install dependencies (one-time, in `setup`)

Only two packages need installing:

```bash
sudo pip install envycontrol       # GPU switching
sudo apt install tlp tlp-rdw       # power management
```

TLP is installed but NOT enabled yet during setup -- it only activates when you run `battery`.

---

## Step 3: The `battery` subcommand

Applies all optimizations. The script does these in order:

**a) GPU -- switch to integrated (needs reboot)**

```bash
sudo envycontrol -s integrated
```

Powers off the RTX 4060 completely at the ACPI level. Expected savings: **5-10W**.

**b) TLP -- enable and configure**

```bash
sudo systemctl stop power-profiles-daemon
sudo systemctl mask power-profiles-daemon
sudo systemctl enable tlp
sudo systemctl start tlp
```

Creates `/etc/tlp.d/01-rog-strix.conf` with:

- `CPU_BOOST_ON_BAT=0` -- disable turbo on battery
- `CPU_MAX_PERF_ON_BAT=60` -- cap CPU at 60% (plenty for Cursor/browsing)
- `PCIE_ASPM_ON_BAT=powersupersave`
- `USB_AUTOSUSPEND=1` with `USB_EXCLUDE_AUDIO=1` (protects Focusrite/AT2020)
- `RUNTIME_PM_ON_BAT=auto`
- `NMI_WATCHDOG=0`
- `PLATFORM_PROFILE_ON_BAT=low-power`
- No audio power save (keeps existing `power_save=0` to avoid popping)

Expected savings: **5-8W**.

**c) GRUB -- add power params (needs reboot)**

Backs up `/etc/default/grub` to snapshot dir, then changes:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
```

to:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet mem_sleep_default=deep pcie_aspm.policy=powersupersave nmi_watchdog=0"
```

Runs `sudo update-grub`. Expected savings: **1-3W**.

**d) Sysctl**

```bash
echo "kernel.nmi_watchdog=0" | sudo tee /etc/sysctl.d/99-powersave.conf
sudo sysctl -w kernel.nmi_watchdog=0
```

**e) Powertop auto-tune service**

Creates `/etc/systemd/system/powertop-autotune.service`:

```ini
[Unit]
Description=Powertop auto-tune

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
```

Enables and starts it. Expected savings: **1-2W**.

**f) Brightness**

```bash
echo 35 | sudo tee /sys/class/backlight/*/brightness
```

Expected savings: **2-3W**.

**g) Reports what needs reboot**

The script prints a summary:

```
Battery mode applied.
  Instant changes: TLP enabled, PPD masked, sysctl, powertop, brightness=35
  Reboot required for: GPU switched to integrated, GRUB params updated
  Run 'sudo reboot' to complete.
```

---

## Step 4: The `performance` subcommand

Restores everything to the snapshotted state, reading from `~/.config/power-mode/snapshot.conf`:

**a) GPU -- switch back to hybrid (needs reboot)**

```bash
sudo envycontrol -s hybrid --rtd3
```

**b) TLP/PPD -- swap back**

```bash
sudo systemctl stop tlp
sudo systemctl disable tlp
sudo systemctl unmask power-profiles-daemon
sudo systemctl enable power-profiles-daemon
sudo systemctl start power-profiles-daemon
```

**c) GRUB -- restore original**

Restores `GRUB_CMDLINE_LINUX_DEFAULT` to the snapshotted value (`"quiet"`), runs `sudo update-grub`.

**d) Sysctl -- remove and restore**

```bash
sudo rm -f /etc/sysctl.d/99-powersave.conf
sudo sysctl -w kernel.nmi_watchdog=1
```

**e) Powertop service -- remove**

```bash
sudo systemctl stop powertop-autotune
sudo systemctl disable powertop-autotune
sudo rm -f /etc/systemd/system/powertop-autotune.service
sudo systemctl daemon-reload
```

**f) TLP config -- remove**

```bash
sudo rm -f /etc/tlp.d/01-rog-strix.conf
```

**g) Brightness -- restore**

```bash
echo 60 | sudo tee /sys/class/backlight/*/brightness  # value from snapshot
```

**h) Reports what needs reboot**

```
Performance mode restored.
  Instant changes: PPD re-enabled, TLP disabled, sysctl restored, powertop removed, brightness=60
  Reboot required for: GPU switched to hybrid, GRUB params restored
  Run 'sudo reboot' to complete.
```

---

## Step 5: The `status` subcommand

Shows current state at a glance:

```
Power Mode Status
  Mode:        battery (or performance / unknown)
  GPU:         integrated (or hybrid)
  Power mgr:   TLP (or power-profiles-daemon)
  CPU turbo:   off (or on)
  Brightness:  35/100
  Power draw:  14.2W
  Battery:     90%, ~5.4h remaining
  Reboot pending: no
```

---

## What We Are NOT Changing (in either mode)

- `/etc/modprobe.d/audio-power-disable.conf` -- `power_save=0` stays to avoid popping
- USB autosuspend exceptions (Camlink, Focusrite, AT2020 udev rules) -- untouched
- `thermald` -- stays active in both modes
- NVIDIA modprobe options (`nvidia.conf`) -- S0ix and PreserveVideoMemoryAllocations stay as-is

## File Inventory

Files created/modified by the script (all reversible):

- `~/.config/power-mode/snapshot.conf` -- snapshot of original state (created once, never modified)
- `~/.config/power-mode/current_mode` -- tracks which mode is active ("battery" or "performance")
- `/etc/tlp.d/01-rog-strix.conf` -- TLP config (created in battery, deleted in performance)
- `/etc/sysctl.d/99-powersave.conf` -- NMI watchdog (created in battery, deleted in performance)
- `/etc/systemd/system/powertop-autotune.service` -- powertop service (created in battery, deleted in performance)
- `/etc/default/grub` -- GRUB_CMDLINE_LINUX_DEFAULT line modified (restored from snapshot in performance)

## Expected Results (battery mode)

- dGPU off via envycontrol: **5-10W**
- TLP (CPU cap, turbo off, ASPM, runtime PM): **5-8W**
- Kernel boot params: **1-3W**
- powertop auto-tune: **1-2W**
- Brightness 60 -> 35: **2-3W**
- **Total estimated savings: 14-26W** (from ~40W down to ~14-18W)
- **Projected battery life: 4.3-6 hours**

