# Hybrid Android ROM Flasher (Fastboot & Custom Recovery)

**Flasher by `git@zuri1503`** is a unified ROM installation package designed to work seamlessly across **Windows, Linux, and macOS via Fastboot** as well as directly on-device via **64-bit Custom Recovery (TWRP / OrangeFox)**.

It pairs cross-platform Fastboot scripts (`INSTALL.bat` / `INSTALL.sh`) with a lightweight, statically linked 64-bit (`arm64-v8a`) recovery `update-binary` capable of streaming large (`>4 GB`) raw and Android sparse images directly from a single ZIP/ZIP64 archive.

---

## Package Structure

A complete release archive combines both Fastboot and Recovery components in one ZIP file:

```text
ROM_Package.zip
├── INSTALL.bat                          # Windows Fastboot installer
├── INSTALL.sh                           # Linux / macOS Fastboot installer
├── META-INF/
│   ├── fastboot.exe                     # Bundled Windows Fastboot binary
│   └── com/
│       └── google/
│           └── android/
│               ├── update-binary        # Custom 64-bit Recovery binary
│               └── updater-script       # Minimal Edify recovery script
└── images/
    ├── boot.img                         # Kernel / ramdisk image (raw)
    ├── super.img                        # Dynamic partitions image (sparse or raw)
    ├── cust.img                         # (Optional) Regional/cust partition
    └── preloader_raw.img                # (Optional) MediaTek preloader (Fastboot only)
```

---

## Key Features

### 1. Cross-Platform Fastboot Flasher (`INSTALL.bat` & `INSTALL.sh`)
- **Direct `super.img` Flashing:** Flashes `images/super.img` directly via `fastboot flash super` without requiring `img2simg` pre-conversion or temporary disk space.
- **Device Codename Verification:** Queries `fastboot getvar product` and blocks installation if the connected device does not match the configured codenames (`DEVICE1` / `DEVICE2`).
- **Interactive Data Wipe Prompt:** Prompts the user before flashing (`Type 1 to FORMAT data or 0 to KEEP data`) and erases `userdata`, `metadata`, and `frp` when `1` is selected.
- **Conditional Firmware Handling:** Automatically detects and flashes `images/preloader_raw.img` (`preloader_a`, `preloader_b`, `preloader1`, `preloader2`) and `images/cust.img` (`cust`) if present in the `images/` directory.
- **A/B Slot Management:** Sets active slot to `a` (`--set-active=a`), flashes both `boot_a` and `boot_b`, and automatically reboots into the system upon completion.
- **Zero-Dependency Windows & Guided Unix Setup:** Uses bundled `META-INF\fastboot.exe` on Windows, and checks system `fastboot` on Linux/macOS with exact package-manager install commands (`apt`, `dnf`, `pacman`, `brew`) if missing.

### 2. Custom Recovery Engine (`update-binary` & `updater-script`)
- **Streaming Raw & Sparse Extraction (`>4 GB` ZIP64 Ready):** Streams data directly from ZIP/ZIP64 packages to block devices using a fixed `4 MiB` page-aligned buffer, avoiding out-of-memory (OOM) crashes in recovery `tmpfs` RAM when flashing `7 GB+` `super.img` files.
- **Auto A/B Slot Detection & Single-Pass Dual-Slot Flashing:** Given a base path such as `/dev/block/bootdevice/by-name/boot`, the binary automatically detects whether the device uses single-slot or `_a`/`_b` partitions and writes both `boot_a` and `boot_b` simultaneously in a single decompression pass.
- **Automatic Per-File Progress Bar (`0%`–`100%`):** Drives the TWRP/OrangeFox progress bar from `0%` to `100%` for each `extract_raw` and `extract_sparse` call based on actual bytes written to storage.
- **eMMC & UFS I/O Optimization:** Combines `posix_fadvise` (`SEQUENTIAL` / `DONTNEED`) with periodic `sync_file_range` (`32 MiB` writeback windows) for consistent write throughput without stalls at the end of large partitions.
- **Integrity & Partition Safety:**
  - Verifies streaming `CRC32` checksums and uncompressed byte counts against the ZIP Central Directory.
  - Validates sparse headers, chunk counts, and block counts.
  - Checks target block device capacity (`BLKGETSIZE64`) before writing and prevents accidental file creation under `/dev/` if a partition is missing.
  - Automatically falls back between `/dev/block/bootdevice/by-name/` and `/dev/block/by-name/`.
- **Automatic Active Slot Switching:** Automatically runs `bootctl set-active-boot-slot 0` after the script completes on A/B devices (`ro.build.ab_update=true`).

---

## End-User Installation Guide

### Method A: Custom Recovery (TWRP / OrangeFox)
1. Copy `ROM_Package.zip` to internal storage or an SD card / USB OTG drive.
2. Boot the device into **TWRP** or **OrangeFox** (64-bit).
3. *(Recommended for clean install)* Go to **Wipe → Format Data**, type `yes`, and confirm.
4. Go to **Install**, select `ROM_Package.zip`, and swipe to flash.
5. Reboot to System.

### Method B: Fastboot (PC)
1. Extract the entire `ROM_Package.zip` archive to a folder on your PC.
2. Boot the phone into **Fastboot Mode** and connect it via USB.
3. Run the installer for your operating system:
   - **Windows:** Double-click `INSTALL.bat`.
   - **Linux / macOS:** Open a terminal in the extracted folder and run:
     ```bash
     chmod +x INSTALL.sh && ./INSTALL.sh
     ```
     *(If `fastboot` is not installed on Linux/macOS, install `android-tools` / `fastboot` as prompted by the script.)*
4. Enter `1` to format data (clean flash) or `0` to keep existing data (dirty flash), then wait for the device to reboot automatically.

---

## Maintainer Guide: Customizing the Scripts

When adapting this template for a new ROM build, keep all three scripts (`INSTALL.bat`, `INSTALL.sh`, and `updater-script`) synchronized.

### 1. Setting Target Device Codenames
Replace `DEVICE1` and `DEVICE2` with your target device codenames (e.g., `fuxi`, `nuwa`) across all three files:

- **`INSTALL.bat`:**
  ```bat
  set device1=DEVICE1
  set device2=DEVICE2
  ```
- **`INSTALL.sh`:**
  ```bash
  device1="DEVICE1"
  device2="DEVICE2"
  ```
- **`META-INF/com/google/android/updater-script`:**
  ```edify
  getprop("ro.product.device") == "DEVICE1" || getprop("ro.product.device") == "DEVICE2" || abort("Compatible devices: DEVICE1, DEVICE2");
  ```
  *(To support a 3rd codename, add `set device3=...` and an extra `if` condition in `INSTALL.bat`/`INSTALL.sh`, and append `|| getprop("ro.product.device") == "DEVICE3"` before `|| abort(...)` in `updater-script`.)*

### 2. Adding Extra Firmware Partitions
To include additional firmware images (such as `dtbo.img` or `vendor_boot.img`) inside `images/`:

- **`INSTALL.bat` (insert before `%fastboot% reboot`):**
  ```bat
  %fastboot% flash dtbo_a images\dtbo.img
  %fastboot% flash dtbo_b images\dtbo.img
  ```
- **`INSTALL.sh` (insert before `"$fastboot" reboot`):**
  ```bash
  "$fastboot" flash dtbo_a images/dtbo.img
  "$fastboot" flash dtbo_b images/dtbo.img
  ```
- **`updater-script` (insert under `Flashing firmware partitions...` — omit `_a`/`_b`):**
  ```edify
  extract_raw("images/dtbo.img", "/dev/block/bootdevice/by-name/dtbo") || abort("Failed to flash dtbo!");
  ```
  *(Note: Do **not** add `preloader_raw.img` to `updater-script`; preloader flashing is handled exclusively in `INSTALL.bat` and `INSTALL.sh`.)*

### 3. `updater-script` Syntax & Function Reference

The custom recovery binary implements a minimal Edify interpreter with **5 built-in functions**. Every statement must end with a semicolon (`;`).

| Function | Arguments | Return Value | Description |
| :--- | :--- | :--- | :--- |
| `ui_print(msg, ...)` | 1 or more strings | Concatenated string | Prints a message to the recovery log. |
| `extract_raw(zip_path, dest_path)` | 2 strings | `"t"` on success, `""` on failure | Streams a raw image from the ZIP to a block device (auto-detects single slot or `_a`/`_b`). |
| `extract_sparse(zip_path, dest_path)` | 2 strings | `"t"` on success, `""` on failure | Streams and unsparses an Android sparse image directly to a block device. |
| `getprop(prop_name)` | 1 string | Property string or `""` | Reads an Android system/recovery property. |
| `abort([msg, ...])` | 0 or more strings | Exits (`code 1`) | Prints an optional message and immediately halts installation. |

**Supported Operators:** `+` (string concatenation), `==`, `!=`, `||`, `&&`, `!`, `( ... )` grouping, and `#` line comments.

**Important Rules for `updater-script`:**
- **Do not use** `package_extract_file`, `show_progress`, `set_progress`, `ifelse`, or `run_program`—they are intentionally excluded from the custom binary.
- **Always chain `|| abort("...")`** after `extract_raw` and `extract_sparse` so installation stops immediately if any partition fails to flash.

### 4. ZIP Packaging Requirements
- **Compression Methods:** Only **Store (`0`)** and **Deflate (`8`)** are supported by `update-binary`. Never compress entries with `Zstd`, `LZMA`, or `BZip2`.
- **ZIP64:** Enable ZIP64 when packing archives larger than `4 GB`.
- **Performance Tip:** Store `images/super.img` using **Store (`-0`, uncompressed)** mode inside the ZIP. Because sparse images are already compact, bypassing Deflate decompression maximizes UFS/eMMC write speeds during recovery flashing.
