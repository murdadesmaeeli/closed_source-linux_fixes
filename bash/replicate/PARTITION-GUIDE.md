# Partition Layout Guide — Debian 13 on ASUS G15 Advantage Edition

Target hardware: 1TB NVMe + 512GB NVMe, LVM spanning both drives.

## Drive Layout

```
nvme0n1 (512GB)                  nvme1n1 (1TB)
┌────────────────────────┐       ┌────────────────────────┐
│ p1: 512MB  EFI (FAT32) │       │ p1: entire disk        │
│ p2: 32GB   swap         │       │     LVM PV             │
│ p3: ~480GB LVM PV       │       │                        │
└────────────────────────┘       └────────────────────────┘
         │                                  │
         └──────────┬───────────────────────┘
                    │
              VG: abc (~1.4TB)
                    │
              LV: abc1 (ext4, mounted at /)
```

## Step-by-Step During Debian Installer

### 1. Boot the Debian 13 installer

Use a USB stick with the Debian 13 (trixie) netinst ISO. Boot in UEFI mode.

### 2. Partitioning — choose "Manual"

At the partitioning step, select **Manual** to set up the layout below.

### 3. Partition nvme0n1 (512GB drive)

| Partition | Size   | Type         | Mount        |
|-----------|--------|--------------|--------------|
| nvme0n1p1 | 512 MB | EFI System   | /boot/efi    |
| nvme0n1p2 | 32 GB  | Linux swap   | swap         |
| nvme0n1p3 | ~480GB | LVM PV       | (none)       |

Steps:
1. Select `nvme0n1` and create a new empty partition table (GPT)
2. Create partition 1: 512 MB, type "EFI System Partition", mount at `/boot/efi`
3. Create partition 2: 32 GB, type "Linux swap"
4. Create partition 3: use remaining space, type "physical volume for LVM"

### 4. Partition nvme1n1 (1TB drive)

| Partition | Size       | Type   | Mount  |
|-----------|------------|--------|--------|
| nvme1n1p1 | entire disk | LVM PV | (none) |

Steps:
1. Select `nvme1n1` and create a new empty partition table (GPT)
2. Create partition 1: use all space, type "physical volume for LVM"

### 5. Configure LVM

1. In the partitioning screen, select **"Configure the Logical Volume Manager"**
2. Create volume group: name it `abc`
3. Add both PVs to the VG:
   - `/dev/nvme0n1p3`
   - `/dev/nvme1n1p1`
4. Create logical volume: name it `abc1`, use all available space in VG
5. Back in the partition list, select the new LV (`abc-abc1`)
6. Format as **ext4**, mount at **/**

### 6. Finish partitioning

Review the layout:
- `/dev/nvme0n1p1` → `/boot/efi` (FAT32)
- `/dev/nvme0n1p2` → swap
- `/dev/mapper/abc-abc1` → `/` (ext4)

Select "Finish partitioning and write changes to disk".

### 7. Continue installation

- Select a mirror (deb.debian.org)
- Install the standard system utilities + KDE Plasma desktop
- Install GRUB to the EFI partition

## Post-Install Checklist

After the base install completes and you've rebooted:

1. Verify the layout:
   ```
   lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE
   df -h /
   ```

2. Verify LVM:
   ```
   pvs
   vgs
   lvs
   ```

3. Expected output should show `abc-abc1` as ~1.4TB ext4 mounted at `/`.

4. Install SSH server (needed for transfer):
   ```
   sudo apt install openssh-server
   ```

5. Proceed to `02-setup-network.sh target` to set up the Ethernet link.

## Swap Size Note

32 GB swap is chosen because the G15 Advantage Edition has 16-32 GB RAM. Adjust if
your model has different RAM. Rule of thumb: match RAM size for hibernate support,
or use half for non-hibernate setups.

## Why LVM?

Spanning both NVMe drives into a single volume group gives you one large filesystem
instead of having to decide what goes on which drive. This matches the source system's
layout and simplifies the rsync transfer.
