#!/bin/bash
# Apply all patches for ath9k_htc 10 MHz ham radio support
# Requires: kernel source at /usr/src/linux-$(uname -r) or specify KERNEL_SRC=
set -e

KERNEL_SRC="${KERNEL_SRC:-/usr/src/linux-$(uname -r | sed 's/-[^-]*$//')}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$KERNEL_SRC/net/mac80211" ]; then
    echo "ERROR: Kernel source not found at $KERNEL_SRC"
    echo "Set KERNEL_SRC=/path/to/kernel/source and retry."
    exit 1
fi

echo "Applying kernel patches to $KERNEL_SRC ..."
cd "$KERNEL_SRC"

for p in "$SCRIPT_DIR/kernel-patches/"*.patch; do
    echo "  $(basename $p)"
    patch -p1 --forward --reject-file=- < "$p" || echo "    (already applied or failed)"
done

echo ""
echo "Building modules..."
make M=net/mac80211 -j$(nproc)
make M=drivers/net/wireless/ath/ath9k -j$(nproc)

echo ""
echo "Installing modules..."
sudo cp net/mac80211/mac80211.ko /lib/modules/$(uname -r)/kernel/net/mac80211/
sudo cp drivers/net/wireless/ath/ath9k/ath9k_htc.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ath9k/
sudo cp drivers/net/wireless/ath/ath9k/ath9k_common.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ath9k/
sudo cp drivers/net/wireless/ath/ath9k/ath9k_hw.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ath9k/
sudo cp drivers/net/wireless/ath/ath.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ 2>/dev/null || true
sudo cp net/wireless/cfg80211.ko /lib/modules/$(uname -r)/kernel/net/wireless/ 2>/dev/null || true

echo ""
echo "=== Kernel patches applied and modules installed. ==="
echo ""
echo "Next steps:"
echo "  1. Patch and rebuild wpa_supplicant (see wpa_supplicant-patches/)"
echo "  2. Reload modules: sudo rmmod ath9k_htc; sudo modprobe ath9k_htc"
echo "     (or reboot, or use the reload-wifi.sh script)"
echo "  3. Configure your AP (see README.md)"
