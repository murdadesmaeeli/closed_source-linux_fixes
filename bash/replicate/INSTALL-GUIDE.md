# Debian 13 (Trixie) Installation Guide — ASUS G15 Advantage Edition

Complete walkthrough: creating a bootable USB, booting the installer, and setting
up LVM across two NVMe drives.

## Part 1: Create the Bootable USB Installer

### Download the ISO

Get the Debian 13 (trixie) netinst ISO with non-free firmware included:

```bash
# From your current machine
wget https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/debian-13.3.0-amd64-netinst.iso
```

If that exact version is gone, find the latest at:
https://www.debian.org/distrib/netinst

### Write to USB

Plug in a spare USB stick (2GB+ is fine — this is just the installer, not the
target drive). **This will erase everything on the USB stick.**

```bash
# Find your USB device
lsblk

# It will show up as something like /dev/sda or /dev/sdb
# Make sure you pick the RIGHT device — not your NVMe drives

# Unmount if auto-mounted
sudo umount /dev/sdX* 2>/dev/null

# Write the ISO (replace sdX with your USB device)
sudo dd if=debian-13.3.0-amd64-netinst.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Sync to make sure all data is flushed
sync
```

**Double-check `lsblk` output before running `dd`.** If you write to the wrong
device you will destroy data.

### Alternative: use `cp` (simpler)

```bash
sudo cp debian-13.3.0-amd64-netinst.iso /dev/sdX
sync
```

### Alternative: use Ventoy

If you already have a Ventoy USB, just copy the ISO file onto it — no `dd` needed.

## Part 2: BIOS/UEFI Setup

### Enter BIOS on the ASUS G15

1. Shut down the laptop completely
2. Hold **F2** and press power to enter BIOS setup
3. Or: hold **Esc** at boot for boot menu, then select UEFI settings

### BIOS Settings to Check

| Setting | Value | Why |
|---------|-------|-----|
| Secure Boot | **Disabled** | Debian installer works better without it; re-enable later if desired |
| Boot Mode | **UEFI** (not Legacy/CSM) | Required for GPT + EFI partition |
| Fast Boot | **Disabled** | Ensures USB is detected |
| Boot Priority | **USB first** | So it boots the installer |

Save and exit (F10).

## Part 3: Boot the Installer

1. Plug in the USB installer stick
2. Power on, press **Esc** or **F8** for boot menu
3. Select the USB device (UEFI mode entry, not Legacy)
4. At the Debian menu, select **"Install"** (text mode — more reliable for LVM setup)
   - "Graphical Install" also works but text mode is shown below

## Part 4: Installer Walkthrough

### Screens 1-5: Language, Location, Keyboard

```
Language:          English
Country:           United States (or your country)
Locale:            en_US.UTF-8
Keyboard:          American English
```

### Screen 6: Network

The installer will try DHCP. If the laptop only has WiFi at this point:

```
Choose network interface: wlan0 (or the wireless adapter)
ESSID:             <your WiFi network name>
WPA passphrase:    <your WiFi password>
```

If you have a USB Ethernet adapter plugged in, it will use that automatically.

### Screen 7: Hostname and Domain

```
Hostname:          device2       (or whatever you want to call this machine)
Domain:            <leave blank>
```

### Screen 8: Root Password and User

```
Root password:     <set one or leave blank to disable root login>
Full name:         oneking
Username:          oneking
Password:          <your password>
```

### Screen 9: Clock

```
Time zone:         Eastern / Central / Pacific (your zone)
```

## Part 5: Partitioning (The Critical Part)

This is where we set up LVM spanning both NVMe drives.

### Select "Manual" Partitioning

```
Partitioning method: Manual
```

You will see both NVMe drives listed:

```
SCSI1 (0,0,0) (sda) - XXXGB ATA ...     <-- ignore if this is the USB
NVMe0 (nvme0n1) - 512.1 GB ...           <-- 512GB drive
NVMe1 (nvme1n1) - 1000.2 GB ...          <-- 1TB drive
```

### Step 1: Create Partition Table on nvme0n1 (512GB)

This smaller drive holds EFI, swap, and the rest goes to LVM.

```
Select: nvme0n1
Create new empty partition table? Yes
Partition table type: gpt
```

### Step 2: Create EFI Partition (nvme0n1p1)

```
Select: FREE SPACE on nvme0n1
Create a new partition
Size:              512 MB
Location:          Beginning
Use as:            EFI System Partition
Done setting up the partition
```

### Step 3: Create Swap Partition (nvme0n1p2)

```
Select: FREE SPACE on nvme0n1
Create a new partition
Size:              32 GB
Location:          Beginning
Use as:            swap area
Done setting up the partition
```

### Step 4: Create LVM PV Partition (nvme0n1p3)

```
Select: FREE SPACE on nvme0n1
Create a new partition
Size:              max (use all remaining ~480GB)
Use as:            physical volume for LVM
Done setting up the partition
```

### Step 5: Create Partition Table on nvme1n1 (1TB)

This larger drive goes entirely to LVM.

```
Select: nvme1n1
Create new empty partition table? Yes
Partition table type: gpt
```

### Step 6: Create LVM PV Partition (nvme1n1p1)

```
Select: FREE SPACE on nvme1n1
Create a new partition
Size:              max (use all ~1TB)
Use as:            physical volume for LVM
Done setting up the partition
```

### Step 7: Configure LVM

```
Select: Configure the Logical Volume Manager
Write changes to disk? Yes

Create volume group
  Volume group name:  abc
  Devices for VG:     /dev/nvme0n1p3, /dev/nvme1n1p1
  (select both with Space, then Continue)

Create logical volume
  Volume group:       abc
  LV name:            abc1
  Size:               max (use all available, should be ~1.4TB)
```

### Step 8: Configure the Logical Volume Filesystem

Back in the partition list, you'll see the new LV:

```
Select: LVM VG abc, LV abc1 - 1.4TB
  Use as:            Ext4 journaling file system
  Mount point:       /
  Done setting up the partition
```

### Step 9: Review and Confirm

The final layout should look like:

```
EFI SP         nvme0n1p1    512 MB    fat32     /boot/efi
swap           nvme0n1p2     32 GB    swap      swap
LVM VG abc     nvme0n1p3   ~480 GB
LVM VG abc     nvme1n1p1     ~1 TB
  abc-abc1                 ~1.4 TB    ext4      /
```

```
Select: Finish partitioning and write changes to disk
Write changes? Yes
```

## Part 6: Base System Installation

### Package Manager / Mirror

```
Scan extra installation media?  No
Debian archive mirror country:  United States (or closest)
Mirror:                         deb.debian.org
HTTP proxy:                     <leave blank>
```

### Popularity Contest

```
Participate in package usage survey? No (or Yes, your choice)
```

### Software Selection

Use **Space** to select/deselect, **Tab** to move to Continue:

```
[*] Debian desktop environment
[*] KDE Plasma
[ ] GNOME                          <-- deselect if checked
[ ] Xfce / LXQT / etc             <-- deselect
[*] SSH server                     <-- select this (needed for transfer)
[*] Standard system utilities
```

### GRUB Boot Loader

```
Install GRUB to your primary drive?  Yes
Device:                              /dev/nvme0n1
```

The installer writes GRUB to the EFI System Partition on nvme0n1.

### Finish

```
Installation complete.
Remove installation media and reboot.
```

## Part 7: First Boot — Verify and Prepare for Transfer

After reboot, log in at the SDDM greeter or switch to a TTY (Ctrl+Alt+F2).

### Verify disk layout

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE
```

Expected output:

```
nvme0n1        476.9G                              disk
├─nvme0n1p1      512M vfat        /boot/efi        part
├─nvme0n1p2       32G swap        [SWAP]           part
└─nvme0n1p3   ~445G   LVM2_member                  part
  └─abc-abc1    1.4T  ext4        /                lvm
nvme1n1        931.5G                              disk
└─nvme1n1p1    931.5G LVM2_member                  part
  └─abc-abc1    1.4T  ext4        /                lvm
```

### Verify LVM

```bash
sudo pvs
sudo vgs
sudo lvs
df -h /
```

### Verify network

```bash
ip addr
ping -c 3 google.com
```

### Install any missing essentials

```bash
sudo apt update
sudo apt install -y openssh-server rsync lvm2 curl wget
```

### Proceed to replication

You're now ready to run the scripts:

```bash
# Get the scripts onto this machine (clone the repo, or scp from source)
git clone https://github.com/<your-username>/closed_source-linux_fixes.git
cd closed_source-linux_fixes/bash/replicate

# Set up Ethernet link
sudo ./02-setup-network.sh target

# Transfer data from source
sudo ./03-transfer.sh

# Configure for AMD hardware
sudo ./04-configure-target.sh

# Reboot and verify
sudo reboot
./05-verify.sh
```

## Troubleshooting

### Installer doesn't detect NVMe drives

The ASUS G15 sometimes needs the NVMe controller mode set correctly in BIOS:
- Enter BIOS (F2)
- Look for **SATA/NVMe Configuration** or **Storage**
- Ensure NVMe mode is **AHCI** (not RAID/RST)

### WiFi doesn't work in installer

The AMD G15's WiFi (MediaTek MT7921) needs firmware. The netinst ISO with
non-free firmware should include it. If not:
- Use a USB Ethernet adapter for the install
- Or download the firmware ISO variant:
  https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/

### GRUB doesn't appear after install

- Enter BIOS → Boot → ensure the Debian entry is first
- If no Debian entry exists, add one manually:
  - Select "Add New Boot Option"
  - Path: `\EFI\debian\grubx64.efi`
  - Name: `debian`

### Screen is blank after GRUB

Try adding kernel parameters at the GRUB menu (press `e` to edit):

```
linux ... quiet amdgpu.dc=1 amdgpu.dpm=1
```

The RX 6800M should work out of the box with the `amdgpu` kernel driver, but
`amdgpu.dc=1` ensures the display core is enabled.
