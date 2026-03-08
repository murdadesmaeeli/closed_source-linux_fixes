---
name: Debian System Replication Script
overview: Create a set of bash scripts in this repo that automate replicating the current Debian 13 / KDE system (Intel+NVIDIA) onto a new ASUS G15 Advantage Edition (AMD CPU+GPU) via direct Ethernet transfer, excluding ~705GB of specified large folders.
todos:
  - id: export-script
    content: Create `bash/replicate/01-export-source.sh` - exports package lists, apt sources, keys, services, system configs to `bash/replicate/export/`
    status: completed
  - id: network-script
    content: Create `bash/replicate/02-setup-network.sh` - sets up direct Ethernet link with static IPs and verifies connectivity
    status: completed
  - id: transfer-script
    content: Create `bash/replicate/03-transfer.sh` - rsync home dir + system files over SSH with exclusion list, supports resume
    status: completed
  - id: configure-script
    content: Create `bash/replicate/04-configure-target.sh` - removes NVIDIA stack, installs AMD drivers, restores packages/snaps/flatpaks, fixes boot/fstab/GRUB/services
    status: completed
  - id: verify-script
    content: Create `bash/replicate/05-verify.sh` - post-config verification of GPU, display, packages, services
    status: completed
  - id: partition-guide
    content: Create `bash/replicate/PARTITION-GUIDE.md` - LVM partition layout instructions for the fresh Debian 13 install on target
    status: completed
  - id: readme
    content: Create `bash/replicate/README.md` - overview and step-by-step usage instructions tying all scripts together
    status: completed
isProject: false
---

# Debian 13 System Replication Script

## Current System Profile

- **OS:** Debian 13 (trixie), KDE Plasma on Wayland, SDDM
- **Hardware:** ASUS G15 2021, Intel CPU, NVIDIA GPU (driver 590.48.01)
- **Storage:** 2x 931.5GB NVMe in LVM -> 1.8TB ext4 root, 1.6TB used
- **Packages:** ~4000 dpkg, 164 NVIDIA/CUDA packages, 6 snaps, 8 flatpaks
- **Home dir:** 1.4TB total

## Target System Profile

- **Hardware:** ASUS G15 2021 Advantage Edition, AMD CPU, AMD GPU (RX 6800M)
- **Storage:** 1TB NVMe + 512GB NVMe, LVM spanning both
- **Method:** Fresh Debian 13 install, then sync packages + configs + home

## Exclusions (~705GB saved)


| Folder                        | Size  |
| ----------------------------- | ----- |
| `~/.local/share/Trash`        | 179GB |
| `~/.local/share/plasma-vault` | 134GB |
| `~/.android`                  | 151GB |
| `~/.docker`                   | 64GB  |
| `~/Documents/archive`         | 111GB |
| `~/Videos`                    | 66GB  |


After exclusions, transfer is ~765GB (695GB home + 70GB system).

## Script Architecture

All scripts live in `bash/replicate/` inside this repo.

### Script 1: `bash/replicate/01-export-source.sh` (run on source/current laptop)

Exports everything needed from the source system:

- **Package lists:**
  - `dpkg --get-selections` -> `packages-dpkg.list`
  - Manually installed packages via `apt-mark showmanual` -> `packages-manual.list`
  - `snap list` -> `packages-snap.list`
  - `flatpak list --app --columns=application` -> `packages-flatpak.list`
  - Global npm/pip packages if present
- **APT sources & keys:**
  - Copy `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`
  - Export apt trusted keys
- **Enabled services:** `systemctl list-unit-files --state=enabled`
- **System configs:** tar of `/etc` (selective, skip machine-specific like `/etc/machine-id`)
- **User crontabs, systemd user units**
- All exported to `bash/replicate/export/`

### Script 2: `bash/replicate/02-setup-network.sh` (run on both laptops)

Sets up direct Ethernet transfer:

- Detect Ethernet interface
- Assign static IPs (source: `10.0.0.1/24`, target: `10.0.0.2/24`)
- Start SSH server on source if not running
- Verify connectivity with ping test
- Print rsync commands for reference

### Script 3: `bash/replicate/03-transfer.sh` (run on target laptop)

Performs the actual data transfer via rsync over SSH:

- **System files:** rsync `/etc`, `/opt`, `/usr/local`, `/var/lib` (selective)
- **Home directory:** rsync `/home/oneking/` with exclusion list:
  - `.local/share/Trash`
  - `.local/share/plasma-vault`
  - `.android`
  - `.docker`
  - `Documents/archive`
  - `Videos`
  - `.cache` (regenerated, not worth transferring 28GB)
- Uses `--archive --compress --partial --progress --human-readable`
- Supports resume if interrupted (`--partial`)
- Estimated transfer time at 1Gbps: ~1.5-2 hours

### Script 4: `bash/replicate/04-configure-target.sh` (run on target laptop)

Post-transfer configuration on the AMD system:

- **Remove NVIDIA packages:** purge all 164 nvidia-* and cuda-* packages
- **Remove NVIDIA apt repos:** `cuda-debian12-x86_64.list`
- **Remove NVIDIA-specific configs:**
  - `/etc/modprobe.d/nvidia*`
  - `/etc/modules-load.d/nvidia*`
  - SDDM NVIDIA overrides
- **Install AMD GPU stack:**
  - `firmware-amd-graphics` (from Debian repos)
  - `mesa-vulkan-drivers`, `libdrm-amdgpu1`
  - `xserver-xorg-video-amdgpu`
  - Update ROCm/amdgpu repos to Debian 13 compatible versions (current repos point to Ubuntu jammy which is wrong)
  - Optionally install ROCm for GPU compute
- **Restore packages:** install from `packages-manual.list` (filtering out nvidia/cuda packages)
- **Restore snaps and flatpaks** from exported lists
- **Fix SDDM:** configure for Wayland (no NVIDIA workarounds needed on AMD)
- **Fix boot:**
  - Update `/etc/fstab` with new UUIDs
  - Update GRUB: remove any `nvidia` kernel params, ensure `amdgpu` module loads
  - `update-grub` and `update-initramfs -u`
- **Fix services:**
  - Disable `thermald` (Intel-specific, not needed on AMD)
  - Ensure `power-profiles-daemon` works with AMD
- **Fix ASUS-specific:**
  - `asus-nb-wmi` module should work on both models
  - The `power-mode.sh` script in this repo may need AMD GPU path adjustments (no `nvidia-smi`)

### Script 5: `bash/replicate/05-verify.sh` (run on target laptop)

Post-configuration verification:

- Check GPU detection (`lspci | grep -i vga`)
- Check Vulkan (`vulkaninfo --summary`)
- Check OpenGL (`glxinfo | grep "OpenGL renderer"`)
- Check KDE/Wayland session loads
- Check package count matches (minus NVIDIA delta)
- Check key services are running
- List any missing packages that failed to install

## Partition Layout Guide (for fresh install)

Documented in `bash/replicate/PARTITION-GUIDE.md`:

- **nvme0n1** (1TB): 512MB EFI (`/boot/efi`), 32GB swap, rest as LVM PV
- **nvme1n1** (512GB): entire disk as LVM PV
- **VG:** `abc` spanning both PVs (~1.4TB usable)
- **LV:** `abc1` using all space, ext4, mounted at `/`

## Key Considerations

- The `.cache` directory (28GB) will be excluded too since it regenerates -- saves transfer time
- The existing `power-mode.sh` script in `bash/` references `nvidia-smi` and NVIDIA-specific paths -- the configure script should note this needs manual adaptation for AMD
- APT sources for `amdgpu.list` and `rocm.list` currently point to Ubuntu jammy repos (wrong for Debian 13) -- these will be updated to proper Debian-compatible repos or removed if not needed
- `envycontrol` (currently installed) is NVIDIA-specific and should be removed on the AMD target

