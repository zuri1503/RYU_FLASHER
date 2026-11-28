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
    └── preloader_raw.img                # (Optional) Preloader image (auto-skipped in Recovery)
```

---

## Key Features

- **Fastboot (`INSTALL.bat` / `INSTALL.sh`):**
  - Verifies device codename (`DEVICE1` / `DEVICE2`) before flashing.
  - Interactive data prompt (`1` to format `userdata`/`metadata`/`frp`, `0` to keep data).
  - Flashes `super.img` directly without `img2simg` conversion, auto-flashes `preloader_raw.img` and `cust.img` if present, sets active slot to `a`, and reboots.
- **Custom Recovery (`update-binary`):**
  - Standalone ARM64 static binary built for Android 13+ TWRP / OrangeFox (supports both `4 KB` and `16 KB` kernel page sizes) with runtime ARMv8 hardware CRC32 acceleration.
  - Hash-indexed ZIP / ZIP64 reader supporting `STORE` and `DEFLATE` entries with a zero-copy async ring pipeline (`4 × 2 MiB`) for fast eMMC/UFS throughput.
  - **Single-pass dual-slot flashing:** Automatically resolves `_a`/`_b` or unslotted block devices and writes both slots simultaneously in one decompression pass, updating the recovery progress bar in real time.
  - **Smart `extract_partitions`:** Automatically detects raw vs. sparse images, skips `.img` files that have no matching partition on the device, and flashes in a safe order: `A–Z` firmware → `A–Z` `*boot*` → `cust` → `super`.
  - **Dynamic Partitions (`super`) lifecycle:** Unmounts and unmaps `super`-backed `dm-*` devices before flashing, then remaps updated logical partitions (`dm-linear` and `/dev/block/mapper/<name>`) afterward.
  - **Built-in status & error handling:** Prints `Flashed <part> partition!` for every flashed partition and automatically aborts with `Failed to flash <part> partition!` on error.
  - **Automatic Slot A activation:** Runs `bootctl set-active-boot-slot 0` after a successful flash on A/B devices (`ro.build.ab_update=true`).

---

## How to Install

### Option 1: Custom Recovery (TWRP / OrangeFox)
1. Copy `ROM_Package.zip` to your device, SD card, or USB OTG.
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

### 1. Default `updater-script`

```edify
ui_print("Flasher by git@zuri1503");
ui_print("Your device: " + getprop("ro.product.device"));
getprop("ro.product.device") == "DEVICE1" || getprop("ro.product.device") == "DEVICE2" || abort("Compatible devices: DEVICE1, DEVICE2");
ui_print("Started flashing ROM...");
extract_partitions("images");
ui_print("Successfully flashed ROM!");
```

### 2. Change Supported Devices
Replace `DEVICE1` and `DEVICE2` in all three files:
- **`INSTALL.bat`:** `set device1=...` and `set device2=...`
- **`INSTALL.sh`:** `device1="..."` and `device2="..."`
- **`updater-script`:** `getprop("ro.product.device") == "DEVICE1" || getprop("ro.product.device") == "DEVICE2" || abort("...");`

### 3. Add or Remove Partition Images
- **Custom Recovery (`updater-script`):** No script edits are needed when using `extract_partitions("images")`. Any `<part>.img` placed inside `images/` is automatically matched to `/dev/block/bootdevice/by-name/<part>` (or `_a`/`_b`), and images without a matching device partition (such as `preloader_raw.img`) are skipped automatically.
- **Fastboot (`INSTALL.bat` / `INSTALL.sh`):** Add or remove `fastboot flash <part>_a` and `<part>_b` lines before `reboot`.

### 4. Supported `updater-script` Functions

Separate statements with `;`. The binary validates script syntax, function names, and argument counts in a pre-pass before touching any partition. Flash functions automatically print `Flashed <part> partition!` on success and abort with `Failed to flash <part> partition!` on failure—chaining `|| abort(...)` is not required.

#### `ui_print(message, ...)`
Joins zero or more arguments without inserting spaces, prints the resulting text to the recovery UI, and writes it to `/tmp/recovery.log`.

```edify
ui_print("Your device: " + getprop("ro.product.device"));
```

#### `extract_partitions(folder)`
1. Scans all `*.img` files directly inside `folder` inside the ZIP.
2. Runs a fast preflight check: skips images whose target partition does not exist on the device, verifies image headers, and checks capacity on all target block devices.
3. Sorts matched images into four stages (alphabetical `A–Z` within each stage):
   1. Regular firmware partitions (`abl`, `dtbo`, `modem`, `vbmeta`, etc.)
   2. Any partition containing `boot` (`boot`, `init_boot`, `vendor_boot`, etc.)
   3. `cust`
   4. `super`
4. Flashes all matched images in a single pass with weighted progress (`0% → 100%`).

```edify
extract_partitions("images");
```

#### `extract_image(zip_path, dest_path)`
Inspects the 28-byte image header to automatically detect Android sparse (`0xED26FF3A`) or raw images, then flashes the target partition(s) in a single pass.

```edify
extract_image("images/super.img", "/dev/block/bootdevice/by-name/super");
```

#### `extract_raw(zip_path, dest_path)`
Flashes a raw partition image (or extracts a regular file outside `/dev/`) in a single pass, verifying ZIP uncompressed size and CRC32.

```edify
extract_raw("images/boot.img", "/dev/block/bootdevice/by-name/boot");
```

#### `extract_sparse(zip_path, dest_path)`
Flashes an Android sparse image in a single pass, validating sparse file/chunk headers, block counts, `CHUNK_TYPE_CRC32` checksums, and ZIP CRC32.

```edify
extract_sparse("images/super.img", "/dev/block/bootdevice/by-name/super");
```

#### Target Partition Resolution
All extract functions resolve block devices using the rules below (checking both `/dev/block/bootdevice/by-name/` and `/dev/block/by-name/`):

| Destination requested | Block devices written |
| --- | --- |
| Base name with `_a` and `_b` present | `part_a` and `part_b` simultaneously in a single pass (aliases with the same device node are deduplicated). |
| Base name with only one slot present | The available `part_a` or `part_b`. |
| Base name with neither slot present | The unslotted `part` (e.g., `super`, `cust`, or non-A/B partitions). |
| Name ending in `_a` or `_b` | The explicitly requested slot only. |

#### `getprop(key)`
Reads an Android system property in the recovery environment and returns its value (or `""` if unset).

```edify
getprop("ro.boot.hwc") == "CN" && extract_image("images/modem_cn.img", "/dev/block/bootdevice/by-name/modem");
```

#### `run_program(program, ...)`
Executes a binary or script with the given arguments and returns its exit code as a string (`"0"` on success, `"127"` if exec fails, `"-1"` on signal/fork error). Automatically resolves `/sbin/*` fallbacks (`/system/bin/sh`, `toybox`, `bootctl`) on Android 13+ recoveries without `/sbin`.

```edify
run_program("/sbin/sh", "-c", "echo Done") == "0" || abort("Post-flash command failed!");
```

#### `abort(message, ...)`
Prints the joined message as an error and immediately halts installation with a non-zero exit code.

### 5. ZIP Packing Rules
- Use **Store (`0`)** or **Deflate (`8`)** compression only (do not use `Zstd` or `LZMA`).
- Enable **ZIP64** for packages larger than `4 GB`.
- Packing `images/super.img` in **Store (`-0`)** mode is recommended for maximum flashing speed.
