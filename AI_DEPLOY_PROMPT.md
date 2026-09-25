# 给新机器上 AI 的部署提示词

把下面整段内容发给能够操作新机器终端的 AI。只需按实际情况补充管理员密码或
明确哪一个网口连接 MID-360。

```text
请在这台机器上完整部署下面的公开项目：
https://github.com/Qiurilinmu/mid360-lio-docker

目标：使用一台 Livox MID-360，在 Docker 中运行 ROS1 Noetic、官方
livox_ros_driver2、Point-LIO 和 MID-360 适配版 LIO-SAM。优先拉取项目发布的
GHCR 镜像；只有镜像不可用时才从 Dockerfile 构建。

请自主完成部署、验证和故障排查，不要只给我命令。具体要求：

1. 先读取仓库 README.md、docker-compose.yml 和 scripts/，以仓库文档为准。
2. 检查系统架构。该镜像要求 Ubuntu/Linux amd64；如果是 ARM/Jetson，停止并
   明确告诉我镜像不兼容，不要强行运行。
3. 检查 Docker Engine 和 Docker Compose v2；缺失时按 Docker 官方 Ubuntu
   文档安装。不要使用来历不明的一键安装脚本。
4. 克隆仓库到合适目录。保留仓库中的 config、scripts 和 data 目录结构。
5. 用 `ip -br link`、`nmcli device status`、carrier 状态和必要的插拔观察识别
   连接 MID-360 的专用有线网口。如果只有一个明显的有线接口可直接使用；如有
   多个候选且无法判断，向我询问，不要修改 Wi-Fi 或互联网默认路由。
6. 默认网络参数是：主机雷达网口 192.168.1.5/24，MID-360 为 192.168.1.3。
   使用仓库的 `scripts/configure-mid360-network.sh` 创建持久化 NetworkManager
   连接。该连接不要设置默认网关和 DNS。若发现雷达实际 IP 不同，先报告证据，
   再用实际地址更新配置。
7. 检查 `config/MID360_config.json`：四个 host IP 必须等于主机雷达网口地址，
   `lidar_configs[0].ip` 必须等于雷达地址。
8. 执行 `scripts/deploy.sh`。优先拉取
   `ghcr.io/qiurilinmu/mid360-lio-docker:noetic-amd64`。如果公共镜像不存在或
   拉取失败，再执行 `docker compose build`，并完整记录构建错误。
9. 先只启动 Point-LIO，执行 `scripts/start-pointlio.sh`。不要同时启动 LIO-SAM。
10. 验证容器、ROS 节点和话题：
    - `/livox/lidar` 应约 10 Hz；
    - `/livox/imu` 应约 200 Hz；
    - `/aft_mapped_to_init` 应持续输出有效 `nav_msgs/Odometry`；
    - 位姿中不能出现 NaN/Inf。
11. 停止 Point-LIO，确认相关节点退出；再启动 LIO-SAM，并验证：
    - `/lio_sam/mapping/odometry` 应持续输出，静止测试通常约 5 Hz；
    - `/lio_sam/mapping/path` 和 `/lio_sam/mapping/cloud_registered` 存在；
    - 位姿中不能出现 NaN/Inf。
12. 测试完成后只保留我指定的算法运行；如果我没有指定，停止全部算法，但保留
    容器。不要让 Point-LIO 和 LIO-SAM 同时运行。
13. 检查 CPU、内存、磁盘和容器资源占用。默认保持自动 PCD 保存关闭，避免磁盘
    被点云占满。
14. 最后向我报告：主机系统与架构、选用网口、主机 IP、雷达 IP、镜像版本、
    容器状态、两个算法各自的验证结果、话题频率、资源占用和仍需注意的问题。

安全边界：不要删除现有容器、镜像、网络连接或用户数据；不要覆盖其他 ROS
工作空间；不要修改与 MID-360 无关的网口；任何无法确定的网络接口选择都先问我。
```

