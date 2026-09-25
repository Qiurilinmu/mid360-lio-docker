FROM fishros2/ros:noetic-desktop-full

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG LIVOX_SDK2_COMMIT=c0796f04c143143899c87a773d9f6b7136453c0b
ARG LIVOX_DRIVER2_COMMIT=21445540f0d100dc86a7e6df312dd70bbdb4afdf
ARG POINTLIO_COMMIT=1510c3bbf1743f254d83d0b22fbabb5b2d729f6b
ARG LIOSAM_MID360_COMMIT=21ef7bb108fe3c7218c102bf7cb3a06582a2fed9

COPY scripts/apply-source-patches.sh /tmp/apply-source-patches.sh
COPY config/pointlio-mid360.yaml /tmp/mid360.yaml
COPY config/mapping_mid360.launch /tmp/mapping_mid360.launch
COPY config/run_mid360_norviz.launch /tmp/run_mid360_norviz.launch
COPY config/MID360_config.json /tmp/MID360_config.json

# Replace the expired ROS apt source bundled in the historical base image.
RUN rm -f /etc/apt/sources.list.d/ros-fish.list \
    && curl -fL --retry 3 -o /tmp/ros-apt-source.deb \
      https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros-apt-source_1.3.0.focal_all.deb \
    && echo "33a491f72e4e25491f8511c173526bb20ce84ff9faf596158f178f4900da5df1  /tmp/ros-apt-source.deb" | sha256sum -c - \
    && dpkg -i /tmp/ros-apt-source.deb \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates curl \
      libapr1-dev libaprutil1-dev libboost-all-dev libeigen3-dev libpcl-dev \
      ros-noetic-eigen-conversions ros-noetic-gtsam ros-noetic-navigation \
      ros-noetic-pcl-conversions ros-noetic-pcl-ros \
      ros-noetic-robot-localization ros-noetic-xacro \
    && rm -rf /var/lib/apt/lists/* /tmp/ros-apt-source.deb

RUN git clone https://github.com/Livox-SDK/Livox-SDK2.git /tmp/Livox-SDK2 \
    && git -C /tmp/Livox-SDK2 checkout "$LIVOX_SDK2_COMMIT" \
    && cmake -S /tmp/Livox-SDK2 -B /tmp/Livox-SDK2/build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/Livox-SDK2/build --parallel "$(nproc)" \
    && cmake --install /tmp/Livox-SDK2/build \
    && ldconfig \
    && rm -rf /tmp/Livox-SDK2

RUN mkdir -p /root/ws_livox/src \
    && git clone https://github.com/Livox-SDK/livox_ros_driver2.git \
      /root/ws_livox/src/livox_ros_driver2 \
    && git -C /root/ws_livox/src/livox_ros_driver2 checkout "$LIVOX_DRIVER2_COMMIT" \
    && cp /tmp/MID360_config.json /root/ws_livox/src/livox_ros_driver2/config/MID360_config.json \
    && cd /root/ws_livox/src/livox_ros_driver2 \
    && source /opt/ros/noetic/setup.bash \
    && ./build.sh ROS1

RUN mkdir -p /root/ws_pointlio/src /root/ws_liosam_mid360/src \
    && git clone https://github.com/hku-mars/Point-LIO.git /root/ws_pointlio/src/Point-LIO \
    && git -C /root/ws_pointlio/src/Point-LIO checkout "$POINTLIO_COMMIT" \
    && git -C /root/ws_pointlio/src/Point-LIO submodule update --init --recursive \
    && git clone --branch Livox-ros-driver2 --single-branch \
      https://github.com/nkymzsy/LIO-SAM-MID360.git \
      /root/ws_liosam_mid360/src/LIO-SAM-MID360 \
    && git -C /root/ws_liosam_mid360/src/LIO-SAM-MID360 checkout "$LIOSAM_MID360_COMMIT" \
    && chmod +x /tmp/apply-source-patches.sh \
    && /tmp/apply-source-patches.sh \
      /root/ws_pointlio/src/Point-LIO \
      /root/ws_liosam_mid360/src/LIO-SAM-MID360 \
    && cp /tmp/mid360.yaml /root/ws_pointlio/src/Point-LIO/config/mid360.yaml \
    && cp /tmp/mapping_mid360.launch /root/ws_pointlio/src/Point-LIO/launch/mapping_mid360.launch \
    && cp /tmp/run_mid360_norviz.launch \
      /root/ws_liosam_mid360/src/LIO-SAM-MID360/launch/run_mid360_norviz.launch

RUN source /opt/ros/noetic/setup.bash \
    && source /root/ws_livox/devel/setup.bash \
    && cd /root/ws_pointlio \
    && catkin_make -DCMAKE_BUILD_TYPE=Release \
    && source /root/ws_pointlio/devel/setup.bash \
    && cd /root/ws_liosam_mid360 \
    && catkin_make -DCMAKE_BUILD_TYPE=Release \
    && rm -rf /root/ws_livox/build /root/ws_pointlio/build /root/ws_liosam_mid360/build \
      /tmp/apply-source-patches.sh /tmp/mid360.yaml /tmp/mapping_mid360.launch \
      /tmp/run_mid360_norviz.launch /tmp/MID360_config.json

RUN mkdir -p /data/logs /data/maps/pointlio /data/maps/liosam \
    && rm -rf /root/ws_pointlio/src/Point-LIO/PCD \
    && ln -s /data/maps/pointlio /root/ws_pointlio/src/Point-LIO/PCD \
    && mkdir -p /root/Downloads \
    && ln -s /data/maps/liosam /root/Downloads/LOAM

WORKDIR /root
CMD ["bash", "-lc", "trap : TERM INT; sleep infinity & wait"]
