#!/usr/bin/env bash
set -euo pipefail

container="${MID360_CONTAINER:-mid360-lio}"
docker ps --filter "name=^/${container}$"
docker exec "$container" bash -lc '
source /opt/ros/noetic/setup.bash
source /root/ws_livox/devel/setup.bash
source /root/ws_pointlio/devel/setup.bash
source /root/ws_liosam_mid360/devel/setup.bash
echo "--- processes ---"
pgrep -af "roscore|livox_ros_driver2_node|pointlio_mapping|lio_sam_" || true
echo "--- important topics ---"
rostopic list 2>/dev/null | grep -E "^/livox/|^/aft_mapped_to_init$|^/lio_sam/mapping/(odometry|path|cloud_registered)$" || true
'

