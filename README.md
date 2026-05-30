# ath9k-ham-13cm: 10 MHz WiFi on 2397 MHz for Amateur Radio

## ⚠️ LEGAL WARNING

**Operating on frequencies outside the unlicensed ISM bands requires a valid
radio license.** In the United States, this means an FCC Part 97 Amateur Radio
license (Technician class or higher). Similar regulations apply in other
countries.

**Do not use this software unless you are legally authorized to transmit on
the frequencies involved.** Unauthorized transmission on these frequencies is
illegal and may result in fines, equipment seizure, or criminal penalties.

By using this software you accept full responsibility for compliance with all
applicable laws and regulations in your jurisdiction.

---

## What This Does

Enables an Atheros AR9271 USB WiFi adapter (ath9k_htc driver) to operate as a
station (client) at **10 MHz bandwidth on 2397 MHz** — within the US Amateur
Radio 13cm band allocation (2390–2450 MHz), below consumer WiFi channel 1
(2412 MHz). The occupied spectrum (2392–2402 MHz) overlaps the Part 15 ISM
band (2400–2483.5 MHz) by only 2 MHz, avoiding interference with standard
WiFi devices.

This avoids interference with consumer WiFi devices while providing a dedicated
ham radio data link.

### Channel -2 (AREDN/HSMM convention)

- Center frequency: 2397 MHz
- Bandwidth: 10 MHz
- Occupied spectrum: 2392–2402 MHz
- Within Part 97 allocation, below consumer WiFi channel 1 (2412 MHz)
- Upper 2 MHz overlaps Part 15 ISM band; Part 97 is primary allocation

## Requirements

- **Hardware**: Atheros AR9271 USB adapter (any device using ath9k_htc)
- **Kernel source**: Matching your running kernel
- **AP**: An access point also configured for 2397 MHz @ 10 MHz with the
  DS Parameter Set IE removed from beacons (see AP Setup below)
- **License**: Valid Amateur Radio license (US: Technician or higher)

## Tested Versions

- **Linux kernel**: 6.17.13
- **wpa_supplicant**: 2.11
- **iw**: 6.9

Patches target these versions. Offsets may vary on other kernel versions but
the same code paths exist in 5.15+ kernels.

## Secure Boot

These patches modify the kernel's wireless regulatory enforcement. On systems
with UEFI Secure Boot enabled, unsigned kernel modules will be rejected.

You must either:
- **Disable Secure Boot** in BIOS/UEFI settings, or
- **Enroll a Machine Owner Key (MOK)** and sign your rebuilt kernel/modules
  with that key using `mokutil` and `sbsign`

See: https://wiki.ubuntu.com/UEFI/SecureBoot/DKMS

## Quick Start

```bash
# Ensure your kernel config has this option enabled:
#   CONFIG_ATH_REG_DYNAMIC_USER_CERT_TESTING=y
# Without it, the regulatory domain patches will have no effect.
# Add it to /usr/src/linux-*/.config and run: make olddefconfig

# Clone this repo
git clone https://github.com/barberd/ath9k-ham-13cm.git
cd ath9k-ham-13cm

# Apply kernel patches and build modules
# Set KERNEL_SRC if your source isn't at /usr/src/linux-*
chmod +x apply.sh
./apply.sh

# Patch wpa_supplicant
apt-get source wpasupplicant
cd wpa-*/
patch -p1 < ../wpa_supplicant-patches/001-support-sub-2412-frequencies.patch
dpkg-buildpackage -us -uc -b -j$(nproc)
sudo dpkg -i ../wpasupplicant_*.deb

# Reload wireless modules (will briefly disconnect all WiFi)
sudo rmmod ath9k_htc ath9k_common ath9k_hw ath mac80211 cfg80211
sudo modprobe ath9k_htc

# Connect
sudo iw dev wlx* scan freq 2397 ssid "YOUR-AP-SSID"
sudo iw dev wlx* connect YOUR-AP-SSID 2397 auth open
```

## Kernel Patches

All patches are in `kernel-patches/` and applied by `apply.sh`:

| Patch | File | Purpose |
|-------|------|---------|
| 001 | ath/regd.c | Widen ath regulatory rules to 2312–2732 MHz |
| 002 | ath9k/htc_drv_init.c | Suppress ath9k_htc regulatory_hint (prevents EEPROM regdomain override) |
| 003 | ath9k/init.c | Suppress ath9k regulatory_hint |
| 004 | ath/regd.c | Remove REGULATORY_STRICT_REG (allows custom regdomain to take effect) |
| 005 | net/wireless/reg.c | cfg80211: allow all channels in world regdomain |
| 006 | ath9k/htc_drv_init.c | Add WIPHY_FLAG_SUPPORTS_5_10_MHZ to ath9k_htc |
| 007 | net/mac80211/scan.c | Scan at 10 MHz for sub-2412 MHz channels |
| 008 | net/mac80211/mlme.c | Connect at 10 MHz for sub-2412 MHz channels |

### Why patches 007 and 008 are needed

The 802.11 standard does not define 10 MHz operation for infrastructure
(AP/STA) mode — only for IBSS (ad-hoc) and OCB (802.11p). There is no
Information Element for an AP to advertise 10 MHz bandwidth in beacons.

Without patch 007, mac80211 scans at 20 MHz and cannot decode 10 MHz beacons.
Without patch 008, mac80211 attempts to connect at 20 MHz and gets rejected.

## wpa_supplicant Patch

The patch in `wpa_supplicant-patches/` adds support for frequencies below
2412 MHz to `ieee80211_freq_to_channel_ext()`. Without it, wpa_supplicant
logs "No channel number found for frequency XXXX MHz" and cannot manage
connections on extended channels.

## AP Setup

The access point must:

1. **Operate on 2397 MHz at 10 MHz bandwidth**
2. **NOT include the DS Parameter Set IE in beacons**

The DS Parameter Set IE normally contains the channel number as a `u8`. For
channel -2, this wraps to 254, which causes cfg80211 on the client to discard
the beacon entirely (it can't map channel 254 to a valid frequency for the
2.4 GHz band).

### OpenWrt AP (ath5k)

For an OpenWrt AP using ath5k (e.g., La Fonera FON2100A with AR2315), you need:

- hostapd patched to support negative channels (`conf->channel` as `int`)
- hostapd patched to omit DS Parameter Set IE when `channel < 1`
- Channel set to -2: `uci set wireless.radio0.channel='-2'`
- Bandwidth set to 10 MHz: `uci set wireless.radio0.chanbw='10'`
- No encryption (Part 97 requirement): `uci set wireless.@wifi-iface[0].encryption='none'`

See the [openwrt-fon2100-ham](https://github.com/barberd/openwrt-fon2100-ham) repo for a
complete OpenWrt Attitude Adjustment build for the La Fonera FON2100A with all
necessary patches for the AP side.

## Station Identification

Part 97 requires station identification. The convention for HSMM/AREDN
networks is to encode your callsign as ASCII in the MAC address:

```bash
# Example: W1AW-0 = 57:31:41:57:2D:30
python3 -c "print('W1AW-0'.encode('ascii').hex(':'))"

# Set via NetworkManager:
nmcli connection modify "YOUR-CONNECTION" wifi.cloned-mac-address 57:31:41:57:2D:30
```

## Tested Configuration

- **Client**: AR9271 USB (ath9k_htc), Linux 6.17, Ubuntu
- **AP**: AR2315 (ath5k), OpenWrt Attitude Adjustment, La Fonera FON2100A
- **Frequency**: 2397 MHz (channel -2)
- **Bandwidth**: 10 MHz
- **Throughput**: ~27 Mbps effective (54 Mbps OFDM at half-rate)
- **Packet loss**: 0% at 30 feet

## Limitations

- 10 MHz in AP/STA mode is non-standard (Atheros proprietary extension)
- Both sides must be patched — standard WiFi clients cannot connect
- Only OFDM rates work at 10 MHz (CCK/DSSS does not support half-rate)
- No HT/VHT/HE — legacy 802.11a/g rates only

## License

These patches are provided under the same licenses as the original projects
they modify (GPLv2 for Linux kernel, BSD for wpa_supplicant).
