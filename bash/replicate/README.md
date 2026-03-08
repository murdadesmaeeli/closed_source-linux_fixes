# System Replication: Debian 13 — Intel/NVIDIA to AMD

Replicate a Debian 13 (trixie) KDE Plasma system from an ASUS G15 2021
(Intel CPU + NVIDIA GPU) to an ASUS G15 2021 Advantage Edition (AMD CPU + AMD GPU)
via direct Ethernet transfer.

## Overview

| | Source (current) | Target (new) |
|---|---|---|
| **Model** | ASUS G15 2021 | ASUS G15 2021 Advantage Edition |
| **CPU** | Intel | AMD |
| **GPU** | NVIDIA (590.48.01) | AMD (RX 6800M) |
| **Storage** | 2x 931GB NVMe (1.8TB LVM) | 512GB (nvme0n1) + 1TB (nvme1n1) NVMe (1.4TB LVM) |
| **Transfer** | ~765GB after exclusions | |

## Excluded Folders (~705GB saved)

| Folder | Size | Reason |
|---|---|---|
| `~/.local/share/Trash` | 179GB | Trash |
| `~/.local/share/plasma-vault` | 134GB | Encrypted vault (recreate) |
| `~/.android` | 151GB | Android emulator images |
| `~/.docker` | 64GB | Docker images (repull) |
| `~/Documents/archive` | 111GB | Archive data |
| `~/Videos` | 66GB | Video files |
| `~/.cache` | 28GB | Regenerated automatically |

## Prerequisites

- Ethernet cable (to connect both laptops directly)
- Debian 13 netinst USB installer
- Both laptops have Ethernet ports (or USB-C Ethernet adapters)

## Step-by-Step

### Phase 1: Prepare the Source Machine

Run on the current (Intel/NVIDIA) laptop:

```bash
cd bash/replicate
./01-export-source.sh
```

This creates `bash/replicate/export/` with package lists, apt sources, keys,
service lists, and system config backups.

### Phase 2: Install Debian 13 on Target

Follow [PARTITION-GUIDE.md](PARTITION-GUIDE.md) to install a fresh Debian 13
on the AMD laptop with LVM spanning both NVMe drives.

During install, select:
- KDE Plasma desktop
- Standard system utilities
- SSH server

### Phase 3: Connect Both Laptops

Connect an Ethernet cable between both laptops, then run:

```bash
# On source (current) laptop:
sudo ./02-setup-network.sh source

# On target (new) laptop:
sudo ./02-setup-network.sh target
```

This assigns static IPs (`10.0.0.1` source, `10.0.0.2` target) and starts SSH.

### Phase 4: Transfer Data

Run on the target laptop:

```bash
# Set up SSH keys first (optional, avoids repeated password prompts):
ssh-copy-id oneking@10.0.0.1

# Full transfer (~765GB, ~1.5-2 hours at 1Gbps):
sudo ./03-transfer.sh

# Or transfer only specific parts:
sudo ./03-transfer.sh home-only
sudo ./03-transfer.sh system-only
```

Safe to re-run if interrupted — rsync only transfers changed/missing files.

### Phase 5: Configure for AMD

Run on the target laptop:

```bash
sudo ./04-configure-target.sh
```

This will:
1. Purge all NVIDIA/CUDA packages (~164 packages)
2. Remove NVIDIA config files and apt repos
3. Install AMD GPU drivers (firmware, mesa, vulkan, amdgpu)
4. Restore packages from exported list (filtering out NVIDIA)
5. Restore snaps and flatpaks
6. Configure SDDM for Wayland (native AMD support)
7. Fix GRUB and initramfs (remove nvidia params, add amdgpu)
8. Fix services (disable thermald, ensure PPD works)

To run individual steps: `sudo ./04-configure-target.sh --step 3`

### Phase 6: Verify and Reboot

```bash
# Reboot first
sudo reboot

# After reboot, verify everything:
./05-verify.sh
```

## After Replication

### Manual Steps

- **power-mode.sh**: The script in `bash/power-mode.sh` references `nvidia-smi`
  and NVIDIA-specific sysfs paths. It needs manual adaptation for AMD GPU control
  (use `amdgpu` sysfs or `rocm-smi` instead).

- **ROCm**: If you need GPU compute (ML/AI workloads), install ROCm separately:
  https://rocm.docs.amd.com/en/latest/deploy/linux/install.html

- **Docker**: Docker data was excluded. After install, repull needed images.

- **Android SDK**: Android emulator images were excluded. Reinstall via
  Android Studio if needed.

## Script Reference

| Script | Run on | Requires root | Purpose |
|---|---|---|---|
| `01-export-source.sh` | Source | Partial (sudo for /etc) | Export system state |
| `02-setup-network.sh` | Both | Yes | Set up Ethernet link |
| `03-transfer.sh` | Target | Yes | rsync data from source |
| `04-configure-target.sh` | Target | Yes | NVIDIA→AMD swap + package restore |
| `05-verify.sh` | Target | No | Verify system health |
