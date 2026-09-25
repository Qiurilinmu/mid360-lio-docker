#!/usr/bin/env bash
set -euo pipefail

pointlio_dir="${1:?Point-LIO source directory required}"
liosam_dir="${2:?LIO-SAM source directory required}"

grep -RIl 'livox_ros_driver' \
  "$pointlio_dir/CMakeLists.txt" \
  "$pointlio_dir/package.xml" \
  "$pointlio_dir/src/laserMapping.cpp" \
  "$pointlio_dir/src/preprocess.cpp" \
  "$pointlio_dir/src/preprocess.h" \
  | xargs sed -i 's/livox_ros_driver/livox_ros_driver2/g'

sed -i 's/-std=c++11/-std=c++14/' "$liosam_dir/CMakeLists.txt"
if ! grep -q 'add_definitions(-DUSE_UNORDERED_MAP=0)' "$liosam_dir/CMakeLists.txt"; then
  sed -i '/set(CMAKE_CXX_FLAGS_RELEASE/a add_definitions(-DUSE_UNORDERED_MAP=0)' \
    "$liosam_dir/CMakeLists.txt"
fi
sed -i 's#<opencv/cv.h>#<opencv2/opencv.hpp>#' "$liosam_dir/include/utility.h"
if ! grep -q '^#define USE_UNORDERED_MAP 0$' "$liosam_dir/include/utility.h"; then
  sed -i '/#include <pcl\/point_cloud.h>/i #ifdef USE_UNORDERED_MAP\n#undef USE_UNORDERED_MAP\n#endif\n#define USE_UNORDERED_MAP 0' \
    "$liosam_dir/include/utility.h"
fi
sed -i 's/savePCD: true/savePCD: false/' "$liosam_dir/config/paramsLivoxIMU.yaml"

grep -q 'livox_ros_driver2/CustomMsg.h' "$pointlio_dir/src/preprocess.h"
grep -q -- '-std=c++14' "$liosam_dir/CMakeLists.txt"
grep -q 'savePCD: false' "$liosam_dir/config/paramsLivoxIMU.yaml"

