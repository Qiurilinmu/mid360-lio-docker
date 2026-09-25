#!/usr/bin/env bash
set -euo pipefail

container="${MID360_CONTAINER:-mid360-lio}"
docker start "$container" >/dev/null

docker exec -d "$container" bash -lc '
set -e
source /opt/ros/noetic/setup.bash
source /root/ws_livox/devel/setup.bash
source /root/ws_pointlio/devel/setup.bash
mkdir -p /data/logs/pointlio

if pgrep -f "/lio_sam_" >/dev/null; then
  echo "LIO-SAM is running. Stop it before starting Point-LIO." >&2
  exit 1
fi
if pgrep -f "/pointlio_mapping([[:space:]]|$)" >/dev/null; then
  exit 0
fi
if ! pgrep -f "/roscore([[:space:]]|$)" >/dev/null; then
  nohup roscore >/data/logs/pointlio/roscore.log 2>&1 </dev/null &
  sleep 3
fi
if ! pgrep -f "/livox_ros_driver2_node([[:space:]]|$)" >/dev/null; then
  nohup roslaunch livox_ros_driver2 msg_MID360.launch \
    >/data/logs/pointlio/livox.log 2>&1 </dev/null &
  sleep 5
fi
nohup roslaunch point_lio mapping_mid360.launch rviz:=false \
  >/data/logs/pointlio/pointlio.log 2>&1 </dev/null &
'

echo "Point-LIO startup requested. Run scripts/status.sh to verify it."

