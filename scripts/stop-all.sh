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
  pointlio_mapping lio_sam_mapOptmization lio_sam_featureExtraction
  lio_sam_imageProjection lio_sam_imuPreintegration
  livox_ros_driver2_node roslaunch roscore rosout
)
for pattern in "${patterns[@]}"; do pkill -TERM -f "/${pattern}([[:space:]]|$)"; done
sleep 2
for pattern in "${patterns[@]}"; do pkill -KILL -f "/${pattern}([[:space:]]|$)"; done
true
'

echo "ROS, MID-360 driver, Point-LIO, and LIO-SAM processes stopped."

