#!/usr/bin/env bash
# CR-10S Upgrade - Configure Dual Wi-Fi (Home + School) on MainsailOS SD Card
set -euo pipefail

ROOTFS="/media/dorten/rootfs1"
BOOTFS="/media/dorten/bootfs"

if [ ! -d "${ROOTFS}/etc/NetworkManager/system-connections" ]; then
    echo "[ERROR] SD card rootfs not found at ${ROOTFS}."
    echo "Please plug the SD card into this PC first."
    exit 1
fi

echo "=========================================================="
echo "    CONFIGURING DUAL WI-FI PROFILES ON MAINSAILOS SD     "
echo "=========================================================="

# Generate valid RFC 4122 UUIDs
UUID_HOME="$(uuidgen 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')"
UUID_SCHOOL="$(uuidgen 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')"

echo "[1/5] Preserving School Wi-Fi profile (SSID: sensors)..."
cat << EOF > "${ROOTFS}/etc/NetworkManager/system-connections/school-sensors.nmconnection"
[connection]
id=school-sensors
uuid=${UUID_SCHOOL}
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=sensors
hidden=false

[wifi-security]
key-mgmt=wpa-psk
psk=sKPMBWsg

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF
echo "  [OK] Saved school-sensors.nmconnection"

echo "[2/5] Creating Home Wi-Fi profile (SSID: WELOVEYOU)..."
cat << EOF > "${ROOTFS}/etc/NetworkManager/system-connections/home-weloveyou.nmconnection"
[connection]
id=home-weloveyou
uuid=${UUID_HOME}
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=WELOVEYOU
hidden=false

[wifi-security]
key-mgmt=wpa-psk
psk=electrohead.8

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF
echo "  [OK] Saved home-weloveyou.nmconnection"

echo "[3/5] Setting strict NetworkManager permissions (0600 root:root)..."
chmod 600 "${ROOTFS}"/etc/NetworkManager/system-connections/*.nmconnection
chown root:root "${ROOTFS}"/etc/NetworkManager/system-connections/*.nmconnection
echo "  [OK] Permissions verified."

echo "[4/5] Adding official MainsailOS headless_nm.txt to bootfs..."
cat << 'EOF' > "${BOOTFS}/headless_nm.txt"
SSID="WELOVEYOU"
PASSWORD="electrohead.8"
HIDDEN="false"
REGDOMAIN="CZ"
EOF
echo "  [OK] Written ${BOOTFS}/headless_nm.txt"

echo "[5/5] Updating /boot/wpa_supplicant.conf fallback..."
cat << 'EOF' > "${BOOTFS}/wpa_supplicant.conf"
country=CZ
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="WELOVEYOU"
    psk="electrohead.8"
    priority=2
}

network={
    ssid="sensors"
    psk="sKPMBWsg"
    priority=1
}
EOF
echo "  [OK] Updated fallback wpa_supplicant.conf."

sync
echo ""
echo "=========================================================="
echo " SUCCESS! Wi-Fi configuration complete:"
echo "   - Home Wi-Fi   : WELOVEYOU"
echo "   - School Wi-Fi : sensors"
echo "=========================================================="
echo "You can now safely eject the SD card and insert it into the Pi."
