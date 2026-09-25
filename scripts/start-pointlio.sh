#!/usr/bin/env bash
set -euo pipefail

container="${MID360_CONTAINER:-mid360-lio}"
docker start "$container" >/dev/null

docker exec "$container" bash -lc '
set -e
source /opt/ros/noetic/setup.bash
source /root/ws_livox/devel/setup.bash
source /root/ws_pointlio/devel/setup.bash
mkdir -p /data/logs/pointlio

if pgrep -f "^/root/ws_liosam_mid360/devel/lib/lio_sam/" >/dev/null; then
  echo "LIO-SAM is running. Stop it before starting Point-LIO." >&2
  exit 1
fi
if pgrep -f "^/root/ws_pointlio/devel/lib/point_lio/pointlio_mapping([[:space:]]|$)" >/dev/null; then
  exit 0
fi
if ! pgrep -f "^/usr/bin/python3 /opt/ros/noetic/bin/roscore([[:space:]]|$)" >/dev/null; then
  nohup roscore >/data/logs/pointlio/roscore.log 2>&1 </dev/null &
  sleep 3
fi
if ! pgrep -f "^/root/ws_livox/devel/lib/livox_ros_driver2/livox_ros_driver2_node([[:space:]]|$)" >/dev/null; then
  nohup roslaunch livox_ros_driver2 msg_MID360.launch \
    >/data/logs/pointlio/livox.log 2>&1 </dev/null &
  sleep 5
fi
nohup roslaunch point_lio mapping_mid360.launch rviz:=false \
  >/data/logs/pointlio/pointlio.log 2>&1 </dev/null &
'

echo "Point-LIO startup requested. Run scripts/status.sh to verify it."
