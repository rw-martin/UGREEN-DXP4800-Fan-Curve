# `temps.sh` — Drive Temperature Monitor

## Overview

`temps.sh` is a lightweight Bash script for polling SMART temperature data from all four drives in the UGREEN DXP4800+ and presenting it as a formatted, colour-coded thermal report. It was used throughout the fan curve tuning process to capture per-bay temperature readings and validate results across test iterations.

The script queries each drive via `smartctl`, maps it to a bay identifier via `/dev/disk/by-path/`, applies a heat state classification, sorts output hottest-first, and prints a summary with max, min, average, and delta values.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| `smartmontools` | Provides `smartctl`. Install via `apt install smartmontools` or via TrueNAS SCALE shell. |
| `lsblk` | Standard on most Linux distributions, included in TrueNAS SCALE. |
| Root / sudo access | Required for `smartctl` to read drive SMART data. |
| Bash 4.0+ | Uses arrays and `sort` with process substitution. |

On TrueNAS SCALE, `smartctl` is available by default. If running on a separate Linux host connected to the NAS, ensure `smartmontools` is installed.

---

## Usage

```bash
# Make executable (first run only)
chmod +x temps.sh

# Run directly
sudo ./temps.sh

# Or via bash explicitly
sudo bash temps.sh
```

> **Note:** `sudo` is required because `smartctl` needs elevated privileges to read SMART attributes from drives.

---

## Sample Output

```
System Thermal Report - 2025-10-14 21:43:07
================================================================================
BAY  DEV    MODEL              SERIAL         TEMP   STATE
--------------------------------------------------------------------------------
2    /dev/sdb  ST18000NM003D   WCT1XXXX       52°C   WARM
3    /dev/sdc  ST18000NM003D   WCT2XXXX       46°C   OK
4    /dev/sdd  ST18000NM003D   WCT3XXXX       46°C   OK
1    /dev/sda  ST18000NM003D   WCT4XXXX       43°C   OK
--------------------------------------------------------------------------------
Summary:
  Max Disk Temp : 52°C
  Min Disk Temp : 43°C
  Avg Disk Temp : 46.8°C
  Delta         : 9°C
================================================================================
```

Output is sorted hottest-first so the drive requiring the most attention is always at the top.

---

## Colour Coding

| Colour | Threshold | State Label |
|---|---|---|
| 🟢 Green | < 50°C | `OK` |
| 🟡 Yellow | 50–54°C | `WARM` |
| 🔴 Red | ≥ 55°C | `HOT` |

These thresholds align with the target temperature ranges documented in the main README.

---

## How It Works

1. **Drive discovery** — Iterates over `sda`–`sdd`, checking each exists as a block device via `-b /dev/$disk`.
2. **Model and serial** — Retrieved via `lsblk -dn -o MODEL/SERIAL` and trimmed with `xargs`.
3. **Bay mapping** — Parses `/dev/disk/by-path/` symlinks to extract the ATA port number, which corresponds to physical bay position. Falls back to `?` if the path cannot be resolved.
4. **Temperature** — Queries via `smartctl -A`, first attempting to match `Temperature_Celsius` (standard SMART attribute 194), then falling back to a `Temperature:` match for drives that report differently.
5. **Sorting** — Results are sorted numerically by temperature descending before display, regardless of discovery order.
6. **Summary** — Calculates max, min, average (to one decimal place), and delta across all detected drives.

---

## Limitations

- **Fixed to `sda`–`sdd`** — The script assumes a 4-bay system and iterates only those four device nodes. If your drive assignments differ (e.g. drives appear as `sde`+), edit the `for disk in sda sdb sdc sdd` line accordingly.
- **Bay detection is best-effort** — The ATA port extraction from `/dev/disk/by-path/` works reliably on the DXP4800+ with TrueNAS SCALE but may not map correctly on other configurations or after drive reseating.
- **No logging** — Output is printed to stdout only. To retain readings over time, redirect output to a file or pipe through `tee`:

```bash
sudo ./temps.sh | tee -a ~/thermal-log.txt
```

- **No continuous monitoring** — The script is a one-shot snapshot. For periodic polling, wrap it in `watch` or a cron job:

```bash
# Run every 5 minutes, append to log
*/5 * * * * /path/to/temps.sh >> /var/log/nas-temps.log 2>&1
```

---

