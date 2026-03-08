---
name: Reach 13W Power Draw
overview: Reduce system power from 28W to ~13W by eliminating unnecessary CPU load (VSCode, Firefox, Java daemon, excess CPU cores) and adding aggressive hardware power savings (CPU offline, iGPU frequency cap, ASPM fix, display resolution).
todos:
  - id: clean-cursor-flags
    content: Revert Cursor wrapper/desktop to minimal --ozone-platform=wayland only (remove GPU flags, in-process-gpu, EGL overrides)
    status: completed
  - id: cpu-offline
    content: Add CPU thread offlining (keep 8 of 32) to do_battery, restore in do_performance
    status: completed
  - id: cpu-max-perf
    content: Lower CPU_MAX_PERF_ON_BAT from 60 to 40 in TLP config
    status: completed
  - id: igpu-cap
    content: Add Intel iGPU frequency cap (450MHz) to do_battery, restore in do_performance
    status: completed
  - id: resolution
    content: Add display resolution change (1920x1200) to do_battery, restore 2560x1600 in do_performance
    status: completed
  - id: java-ext
    content: Disable Java/Gradle extensions in Cursor settings during battery mode
    status: completed
  - id: aspm-nvme-wifi
    content: Force ASPM powersupersave at runtime, NVMe APST, WiFi power save in do_battery
    status: completed
  - id: verify
    content: Test the combined changes and measure power draw
    status: completed
isProject: false
---

# Reach 13W Power Draw on ASUS ROG Strix G16

## Current State: ~28W

```
CPU active load:     ~15W  (108% CPU across all apps)
Hardware baseline:   ~13W  (display, iGPU, WiFi, NVMe, 64GB RAM, chipset)
```

## Problem: 15W of CPU Load Is Being Wasted

Right now, **three apps are running that don't need to be**:

- **VSCode**: 12.5% CPU (~2W) -- a separate VSCode instance is running alongside Cursor
- **Firefox**: 4.7% CPU (~1W) -- browser with active tabs
- **Java/Gradle daemon**: 1.1% CPU (~0.5W) -- from Cursor's Java extension
- **Cursor renderer zygote**: 42-54% CPU (~5-8W) -- software compositing at 2560x1600

The target 13W is essentially the **hardware baseline** -- meaning CPU active load must drop to near zero (~2-3W for Cursor idle).

## Plan: Two-Phase Attack

### Phase 1: Eliminate Unnecessary CPU Load (~10W savings)

These go into `power-mode.sh` `do_battery`:

1. **Close competing apps guidance** -- add a warning that VSCode and Firefox should be closed. Optionally, the script could detect and warn about running Electron/browser apps.
2. **Disable Cursor's Java/Gradle extension in battery mode** -- the Red Hat Java extension spawns a 2.3% CPU Java daemon and Gradle daemon. Disable it via Cursor settings:
  ```json
   "java.autobuild.enabled": false,
   "java.import.gradle.enabled": false
  ```
   Or better: add Java extension to disabled list in battery mode.
3. **Offline 24 of 32 CPU threads** -- the i9-14900HX has 8 P-cores (16 threads) + 16 E-cores (16 threads). Cursor needs ~2 active cores. Offlining 24 threads (keep 8) reduces package idle power by ~3-5W because fewer cores need to maintain C-state residency and the package can enter deeper sleep states:
  ```bash
   for cpu in $(seq 8 31); do
       echo 0 > /sys/devices/system/cpu/cpu${cpu}/online
   done
  ```
   Restore in `do_performance` by echoing 1 back.
4. **Lower CPU max frequency to 40%** (currently 60%) -- drop `CPU_MAX_PERF_ON_BAT` from 60 to 40. Cursor is not CPU-bound for coding; it's I/O and rendering bound. This reduces active power proportionally.
5. **Kill the Cursor GPU in-process overhead** -- revert to plain `--ozone-platform=wayland` without `--in-process-gpu` or GPU flags. We proved GPU accel doesn't reduce power on this setup. Remove `__EGL_VENDOR_LIBRARY_FILENAMES` and `MESA_LOADER_DRIVER_OVERRIDE` too. Keep it clean.

### Phase 2: Reduce Hardware Baseline (~3-5W savings)

1. **Cap Intel iGPU frequency** -- currently running at 700MHz, max 1650MHz. Cap to 450MHz for code editing:
  ```bash
   echo 450 > /sys/class/drm/card0/gt_max_freq_mhz
  ```
   This reduces iGPU power from ~2-3W to ~1W.
2. **Fix ASPM** -- kernel cmdline says `pcie_aspm.policy=powersupersave` but sysfs shows `[default]`. The kernel param is set but may need runtime enforcement. TLP should handle this via `PCIE_ASPM_ON_BAT=powersupersave`, but verify and force it:
  ```bash
   echo powersupersave > /sys/module/pcie_aspm/parameters/policy
  ```
3. **Lower display resolution to 1920x1200** in battery mode -- 2560x1600 is 4.1M pixels. 1920x1200 is 2.3M pixels (44% less). This reduces:
  - iGPU compositing work (fewer pixels to push)
  - Cursor renderer CPU (fewer pixels to paint)
  - Display panel power (fewer pixels driven)
   Use `kscreen-doctor` or `wlr-randr` to set:
4. **Set NVMe power state** -- the NVMe is showing `active` runtime status. Force APST (Autonomous Power State Transition):
  ```bash
   echo 5000 > /sys/class/nvme/nvme0/device/power/autosuspend_delay_ms
  ```
5. **Ensure WiFi power save is on** -- `iw dev wlo1 set power_save on`

## Expected Results


| Component                   | Before   | After    | Savings  |
| --------------------------- | -------- | -------- | -------- |
| VSCode/Firefox/Java         | ~4W      | 0W       | 4W       |
| Cursor renderer (lower res) | ~8W      | ~4W      | 4W       |
| CPU package (8 cores, 40%)  | ~5W      | ~2W      | 3W       |
| iGPU (capped 450MHz)        | ~2W      | ~1W      | 1W       |
| ASPM/NVMe/WiFi fixes        | ~2W      | ~1W      | 1W       |
| Display (5% brightness)     | ~2W      | ~2W      | 0W       |
| RAM/chipset (fixed)         | ~3W      | ~3W      | 0W       |
| **Total**                   | **~28W** | **~13W** | **~15W** |


## Files to Modify

- `[bash/power-mode.sh](bash/power-mode.sh)`: Add CPU offline, iGPU cap, resolution change, Java extension disable, ASPM enforcement, NVMe APST, WiFi power save to `do_battery`. Add full reversal to `do_performance`. Clean up Cursor flags to minimal Wayland-only.

## Risks

- **CPU offline**: fully reversible, but if Cursor needs a burst (e.g., AI request), 8 threads might cause brief lag
- **Lower resolution**: text may be slightly less sharp, but 1920x1200 on a 16" screen is still good
- **iGPU cap**: might cause slight frame drops during fast scrolling, reversible

