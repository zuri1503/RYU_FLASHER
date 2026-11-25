# Hybrid Android ROM Flasher (Fastboot & Custom Recovery)

**Flasher by `git@zuri1503`** is an all-in-one ROM installer supporting **PC Fastboot** (Windows, Linux, macOS) and **64-bit Custom Recovery** (TWRP / OrangeFox) from a single ZIP/ZIP64 package.

---

## Package Structure

```text
ROM_Package.zip
├── INSTALL.bat                          # Windows Fastboot script
├── INSTALL.sh                           # Linux / macOS Fastboot script
├── META-INF/
│   ├── fastboot.exe                     # Windows Fastboot executable
│   ├── AdbWinApi.dll                    # Fastboot Windows library
│   ├── AdbWinUsbApi.dll                 # Fastboot USB driver library
│   └── com/google/android/
│       ├── update-binary                # Custom 64-bit Recovery binary
│       └── updater-script               # Minimal Edify recovery script
└── images/
    ├── boot.img                         # Raw boot image
    ├── super.img                        # Sparse or raw super image
    ├── cust.img                         # (Optional) Cust image
    └── preloader_raw.img                # (Optional) Preloader image
```

---

## Key Features

- **Fastboot (`INSTALL.bat` / `INSTALL.sh`):**
  - Verifies device codename (`DEVICE1` / `DEVICE2`) before flashing.
  - Interactive data prompt (`1` to format `userdata`/`metadata`/`frp`, `0` to keep data).
  - Flashes `super.img` directly without `img2simg` conversion, auto-flashes `preloader_raw.img` and `cust.img` if present, sets active slot to `a`, and reboots.
- **Custom Recovery (`update-binary`):**
  - **Streaming Engine (`>4 GB` ZIP64 Ready):** Streams raw and sparse images directly to partitions using a fixed `4 MiB` buffer (low RAM usage, no OOM crashes).
  - **Auto A/B Detection:** Automatically detects single-slot or `_a`/`_b` partitions and writes both slots in a single pass.
  - **Auto Progress (`0%`–`100%`):** Updates the recovery progress bar per file based on actual bytes written.
  - **Safety & Slot Switching:** Verifies `CRC32` checksums, checks partition sizes, optimizes eMMC/UFS writeback, and automatically sets active slot to `A` (`slot 0`) on A/B devices upon completion.

---

## How to Install

### Option 1: Custom Recovery (TWRP / OrangeFox)
1. Copy `ROM_Package.zip` to your device or SD card/OTG.
2. Boot into 64-bit **TWRP** or **OrangeFox**.
3. *(Optional for clean flash)* Go to **Wipe → Format Data**, type `yes`, and confirm.
4. Select **Install** → choose `ROM_Package.zip` → swipe to flash, then reboot.

### Option 2: Fastboot (PC)
1. Extract `ROM_Package.zip` to a folder on your PC.
2. Boot the phone into **Fastboot Mode** and connect via USB.
3. Run the installer:
   - **Windows:** Double-click `INSTALL.bat`.
   - **Linux / macOS:** Run `chmod +x INSTALL.sh && ./INSTALL.sh` *(install `fastboot` / `android-tools` if prompted)*.
4. Type `1` (format data) or `0` (keep data) and wait for the phone to reboot.

---

## Customization Guide

### 1. Change Supported Devices
Replace `DEVICE1` and `DEVICE2` in all three files:
- **`INSTALL.bat`:** `set device1=...` and `set device2=...`
- **`INSTALL.sh`:** `device1="..."` and `device2="..."`
- **`updater-script`:** `getprop("ro.product.device") == "DEVICE1" || getprop("ro.product.device") == "DEVICE2" || abort("...");`

### 2. Add Extra Firmware Partitions
- **`INSTALL.bat` / `INSTALL.sh`:** Add `fastboot flash <part>_a` and `<part>_b` before `reboot`.
- **`updater-script`:** Add a single line (omit `_a`/`_b`):
  ```edify
  extract_raw("images/<part>.img", "/dev/block/bootdevice/by-name/<part>") || abort("Failed to flash <part>!");
  ```

### 3. Supported `updater-script` Functions
Every statement must end with `;` and extraction calls should chain `|| abort("...")`:

| Function | Purpose |
| :--- | :--- |
| `ui_print(msg, ...)` | Print text to the recovery screen. |
| `extract_raw(zip_path, dest_path)` | Stream raw image to partition (auto-resolves `_a`/`_b`). |
| `extract_sparse(zip_path, dest_path)` | Stream and unsparse sparse image (e.g., `super.img`). |
| `getprop(prop)` | Read Android system property. |
| `abort([msg])` | Print error message and stop flashing. |

### 4. ZIP Packing Rules
- Use **Store (`0`)** or **Deflate (`8`)** compression only (do not use `Zstd` or `LZMA`).
- Enable **ZIP64** for packages larger than `4 GB`.
- Packing `images/super.img` in **Store (`-0`)** mode is recommended for maximum flashing speed.
