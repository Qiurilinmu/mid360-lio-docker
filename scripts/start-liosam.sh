#!/usr/bin/env bash
set -euo pipefail

container="${MID360_CONTAINER:-mid360-lio}"
docker start "$container" >/dev/null

docker exec "$container" bash -lc '
set -e
source /opt/ros/noetic/setup.bash
source /root/ws_livox/devel/setup.bash
source /root/ws_liosam_mid360/devel/setup.bash
mkdir -p /data/logs/liosam

if pgrep -f '^/root/ws_pointlio/devel/lib/point_lio/pointlio_mapping([[:space:]]|$)' >/dev/null; then
  echo "Point-LIO is running. Stop it before starting LIO-SAM." >&2
  exit 1
fi
if pgrep -f '^/root/ws_liosam_mid360/devel/lib/lio_sam/lio_sam_mapOptmization([[:space:]]|$)' >/dev/null; then
  exit 0
fi
if ! pgrep -f '^/usr/bin/python3 /opt/ros/noetic/bin/roscore([[:space:]]|$)' >/dev/null; then
  nohup roscore >/data/logs/liosam/roscore.log 2>&1 </dev/null &
  sleep 3
fi
if ! pgrep -f '^/root/ws_livox/devel/lib/livox_ros_driver2/livox_ros_driver2_node([[:space:]]|$)' >/dev/null; then
  nohup roslaunch livox_ros_driver2 msg_MID360.launch \
    >/data/logs/liosam/livox.log 2>&1 </dev/null &
  sleep 5
fi
nohup roslaunch lio_sam run_mid360_norviz.launch \
  >/data/logs/liosam/liosam.log 2>&1 </dev/null &
'

echo "LIO-SAM startup requested. Run scripts/status.sh to verify it."
