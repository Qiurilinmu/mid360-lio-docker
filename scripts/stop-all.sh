#!/usr/bin/env bash
set -euo pipefail

container="${MID360_CONTAINER:-mid360-lio}"
if ! docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
  echo "$container is not running."
  exit 0
fi

docker exec "$container" bash -lc '
set +e
patterns=(
  "^/root/ws_pointlio/devel/lib/point_lio/pointlio_mapping([[:space:]]|$)"
  "^/root/ws_liosam_mid360/devel/lib/lio_sam/"
  "^/root/ws_livox/devel/lib/livox_ros_driver2/livox_ros_driver2_node([[:space:]]|$)"
  "^/usr/bin/python3 /opt/ros/noetic/bin/roslaunch([[:space:]]|$)"
  "^/usr/bin/python3 /opt/ros/noetic/bin/roscore([[:space:]]|$)"
  "^/usr/bin/python3 /opt/ros/noetic/bin/rosmaster([[:space:]]|$)"
  "^/opt/ros/noetic/lib/rosout/rosout([[:space:]]|$)"
)
for pattern in "${patterns[@]}"; do pkill -TERM -f "$pattern"; done
sleep 2
for pattern in "${patterns[@]}"; do pkill -KILL -f "$pattern"; done
true
'

echo "ROS, MID-360 driver, Point-LIO, and LIO-SAM processes stopped."
