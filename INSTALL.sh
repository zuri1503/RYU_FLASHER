#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

device="invalid"
device1="DEVICE1"
device2="DEVICE2"

OS_TYPE="$(uname -s)"

if ! command -v fastboot > /dev/null 2>&1; then
    echo "[ERROR] Missing required system tool: fastboot"
    echo ""
    case "$OS_TYPE" in
        Linux*)
            echo "Please install it using the command for your Linux distribution:"
            echo "  - Ubuntu / Debian / Mint : sudo apt update && sudo apt install -y fastboot"
            echo "  - Fedora / RHEL          : sudo dnf install -y android-tools"
            echo "  - Arch / Manjaro         : sudo pacman -S --needed android-tools"
            ;;
        Darwin*)
            echo "Please install it via Homebrew on macOS:"
            echo "  - Command: brew install android-tools"
            ;;
        *)
            echo "[ERROR] Unsupported OS: $OS_TYPE"
            ;;
    esac
    echo ""
    read -rp "Press Enter to exit..."
    exit 1
fi

fastboot="fastboot"

echo ""
echo "======================="
echo "Flasher by git@zuri1503"
echo "======================="
echo ""
echo "Waiting your device..."
echo ""

product_out=$("$fastboot" getvar product 2>&1 | grep -i "^product:" | awk '{print $2}' | tr -d '\r\n')
if [ -n "$product_out" ]; then
    device="$product_out"
fi

if [ "$device" != "$device1" ] && [ "$device" != "$device2" ]; then
    echo "[ERROR] ROM: $device1 - $device2"
    echo "[ERROR] Your device: $device"
    read -rp "Press Enter to exit..."
    exit 1
fi

data="0"
read -rp "Type 1 to FORMAT data or 0 to KEEP data: " data
if [ "$data" = "1" ]; then
    echo ""
    echo "[FORMAT] userdata ..."
    echo ""
    "$fastboot" erase userdata
    "$fastboot" erase metadata
    "$fastboot" erase frp
fi

echo ""
echo "[FLASH] firmware ..."
echo ""
if [ -f "images/preloader_raw.img" ]; then
    "$fastboot" flash preloader_a images/preloader_raw.img
    "$fastboot" flash preloader_b images/preloader_raw.img
    "$fastboot" flash preloader1 images/preloader_raw.img
    "$fastboot" flash preloader2 images/preloader_raw.img
fi
if [ -f "images/cust.img" ]; then
    "$fastboot" flash cust images/cust.img
fi
"$fastboot" --set-active=a
"$fastboot" flash boot_a images/boot.img
"$fastboot" flash boot_b images/boot.img

echo ""
echo "[FLASH] super.img ..."
echo ""
"$fastboot" flash super images/super.img

echo ""
echo "[REBOOT] system ..."
echo ""
"$fastboot" reboot

echo ""
echo "=========================="
echo "Completed to install ROM !"
echo "=========================="
echo ""
read -rp "Press Enter to exit..."
