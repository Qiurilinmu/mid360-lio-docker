#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: sudo $0 <interface> <host-ip/cidr> <mid360-ip>" >&2
  echo "Example: sudo $0 enp2s0 192.168.1.5/24 192.168.1.3" >&2
  exit 2
fi

interface="$1"
host_cidr="$2"
lidar_ip="$3"
host_ip="${host_cidr%/*}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$repo_dir/config/MID360_config.json"
connection="MID360-${interface}"

command -v nmcli >/dev/null || {
  echo "NetworkManager/nmcli is required." >&2
  exit 1
}
command -v python3 >/dev/null || {
  echo "python3 is required to update the JSON configuration." >&2
  exit 1
}
ip link show "$interface" >/dev/null

if nmcli -t -f NAME connection show | grep -Fxq "$connection"; then
  nmcli connection modify "$connection" \
    connection.interface-name "$interface" \
    ipv4.method manual ipv4.addresses "$host_cidr" \
    ipv4.gateway "" ipv4.dns "" ipv6.method disabled
else
  nmcli connection add type ethernet ifname "$interface" con-name "$connection" \
    ipv4.method manual ipv4.addresses "$host_cidr" ipv6.method disabled
fi
nmcli connection up "$connection"

python3 - "$config" "$host_ip" "$lidar_ip" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
host_ip = sys.argv[2]
lidar_ip = sys.argv[3]
data = json.loads(path.read_text())
host = data["MID360"]["host_net_info"]
for key in ("cmd_data_ip", "push_msg_ip", "point_data_ip", "imu_data_ip"):
    host[key] = host_ip
data["lidar_configs"][0]["ip"] = lidar_ip
path.write_text(json.dumps(data, indent=2) + "\n")
PY

cat > "$repo_dir/.env" <<EOF
HOST_LIDAR_IP=$host_ip
MID360_IP=$lidar_ip
MID360_INTERFACE=$interface
IMAGE_TAG=ghcr.io/qiurilinmu/mid360-lio-docker:noetic-amd64
EOF

echo "Configured $interface as $host_cidr and MID-360 as $lidar_ip."
ping -c 2 -W 1 "$lidar_ip" || {
  echo "MID-360 did not answer ping. Check power, cable, interface, and its actual IP." >&2
  exit 1
}

