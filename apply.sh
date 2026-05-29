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

# Check for required config option
if ! grep -q "CONFIG_ATH_REG_DYNAMIC_USER_CERT_TESTING=y" "$KERNEL_SRC/.config" 2>/dev/null; then
    echo "WARNING: CONFIG_ATH_REG_DYNAMIC_USER_CERT_TESTING=y not found in .config"
    echo "Patch 004 (no strict reg) will have no effect without it."
    echo "Add it to your .config and run 'make olddefconfig' before building."
    echo ""
fi

echo "Applying kernel patches to $KERNEL_SRC ..."
cd "$KERNEL_SRC"

for p in "$SCRIPT_DIR/kernel-patches/"*.patch; do
    echo "  $(basename $p)"
    patch -p1 --forward --reject-file=- < "$p" || echo "    (already applied or failed)"
done

echo ""
echo "Building modules..."
make M=net/wireless -j$(nproc)
make M=net/mac80211 -j$(nproc)
make M=drivers/net/wireless/ath -j$(nproc)
make M=drivers/net/wireless/ath/ath9k -j$(nproc)

echo ""
echo "Installing modules..."
sudo cp net/wireless/cfg80211.ko /lib/modules/$(uname -r)/kernel/net/wireless/
sudo cp net/mac80211/mac80211.ko /lib/modules/$(uname -r)/kernel/net/mac80211/
sudo cp drivers/net/wireless/ath/ath.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/
sudo cp drivers/net/wireless/ath/ath9k/ath9k_htc.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ath9k/
sudo cp drivers/net/wireless/ath/ath9k/ath9k_common.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ath9k/
sudo cp drivers/net/wireless/ath/ath9k/ath9k_hw.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/ath/ath9k/

echo ""
echo "=== Kernel patches applied and modules installed. ==="
echo ""
echo "Next steps:"
echo "  1. Patch and rebuild wpa_supplicant (see wpa_supplicant-patches/)"
echo "  2. Reload modules (will briefly disconnect all WiFi):"
echo "       sudo rmmod ath9k_htc ath9k_common ath9k_hw ath mac80211 cfg80211"
echo "       sudo modprobe ath9k_htc"
echo "     Or reboot."
echo "  3. Configure your AP (see README.md)"
