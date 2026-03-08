---
name: Fix Linux Power Draw
overview: Reduce power draw from 25W to ~10-12W by fixing two critical Cursor misconfigurations (XWayland + disabled GPU acceleration = all rendering on CPU), stopping 11 unnecessary background services, and adding these to the battery mode toggle script.
todos:
  - id: cursor-settings
    content: Update do_battery to set Cursor settings (enableWayland=true, hardware-acceleration=on) with backup/restore in do_performance
    status: completed
  - id: stop-services
    content: Update do_battery to stop 11 unnecessary services (docker, containerd, libvirtd, snapd, ModemManager, cups, cups-browsed, exim4, smartmontools, avahi-daemon, pcscd) with restore in do_performance
    status: completed
  - id: setup-snapshot
    content: Update do_setup to snapshot active services list and Cursor settings
    status: completed
  - id: status-display
    content: Update do_status to show Cursor rendering mode and background service count
    status: completed
isProject: false
---

# Fix Linux Power Draw to Beat Mac

## Current State: 24.5W (1.9h battery)

The GPU fix worked -- NVIDIA is suspended in D3. The remaining 24.5W is almost entirely CPU, and most of it is avoidable.

## Root Causes Found

### 1. Cursor is burning 90% CPU due to two misconfigurations (biggest win, ~15W savings)

In `~/.config/Cursor/User/settings.json`:

```json
"window.enableWayland": false,
"disable-hardware-acceleration": true,
```

These two settings together are catastrophic for power:

- `**window.enableWayland: false**` -- Forces Cursor to run through XWayland (an X11-to-Wayland translation layer) instead of native Wayland. This means every frame goes: Cursor -> XWayland -> kwin compositor -> display. The XWayland bridge adds overhead and prevents efficient buffer sharing.
- `**disable-hardware-acceleration: true**` -- Forces ALL UI rendering (text, scrolling, animations, webviews) onto the CPU instead of the Intel iGPU. The iGPU is designed to do this at a fraction of the power cost. With this on, the CPU does all pixel work in software.

Combined effect: Cursor is software-rendering through an X11 compatibility layer. This explains the 90% CPU / 6GB RAM usage and the 5.3% CPU on kwin (compositing XWayland surfaces is more expensive than native Wayland).

**Fix**: Set `window.enableWayland: true` and remove `disable-hardware-acceleration` (or set it to `false`). This alone should drop Cursor from ~90% CPU to ~5-10% CPU idle, saving roughly 12-15W.

### 2. Eleven unnecessary background services running (~2-3W savings)

These are all active but doing nothing useful during coding/browsing:


| Service             | Why unnecessary                             |
| ------------------- | ------------------------------------------- |
| docker + containerd | 0 containers running, 19 threads idle       |
| libvirtd            | VM daemon, not using VMs                    |
| snapd               | Snap package manager (only Slack installed) |
| ModemManager        | No cellular modem in laptop                 |
| cups + cups-browsed | Printer services, not printing              |
| exim4               | Mail transfer agent, no mail server needed  |
| smartmontools       | Disk health monitoring (NVMe has its own)   |
| avahi-daemon        | mDNS service discovery                      |
| pcscd               | Smart card daemon                           |


Each service keeps threads alive, prevents deep CPU C-states, and triggers periodic wakeups. Collectively they add ~2-3W.

### 3. Kernel IRQ burning 2.3% CPU

`irq/27-i2c_designware.1` -- this is an i2c bus interrupt handler firing constantly. Likely the touchpad or keyboard controller polling too aggressively. Can be mitigated by adjusting the i2c device power management.

## Implementation Plan

### Changes to [bash/power-mode.sh](bash/power-mode.sh)

`**do_battery**` -- Add two new sections:

- **Section: Cursor Wayland + GPU acceleration** -- Create/update `~/.config/Cursor/User/settings.json` to set `window.enableWayland: true` and `disable-hardware-acceleration: false`. Back up original values first.
- **Section: Stop unnecessary services** -- Stop and disable the 11 services listed above. Record which ones were running in the snapshot so `performance` mode can restore them.

`**do_performance**` -- Restore original Cursor settings and re-enable the services that were previously running.

`**do_setup**` -- Snapshot which services are currently active/enabled and snapshot the current Cursor settings.

`**do_status**` -- Show Cursor rendering mode (Wayland/XWayland) and count of background services.

### Expected Power Budget After All Fixes

- Cursor (native Wayland + GPU accel): ~3-5W (down from ~18W)
- kwin_wayland: ~1W (down from ~2W, less XWayland overhead)
- Screen at brightness 35: ~2W
- WiFi + system baseline: ~3-4W
- NVMe + RAM: ~2W
- **Total: ~11-13W -> approximately 5-6 hours battery**

