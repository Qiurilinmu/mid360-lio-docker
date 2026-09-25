# MID-360 LIO Docker

面向 Livox MID-360 的可复现 ROS1 Noetic 环境，包含官方
`livox_ros_driver2`、Point-LIO 和 MID-360 适配版 LIO-SAM。项目目标是在新的
Ubuntu 工控机上尽量少操作即可恢复当前已验证的环境。

> 当前只包含 Point-LIO 和 LIO-SAM，不包含 FAST-LIO、HDL Localization 或 NDT。

## 已验证组合

| 组件 | 版本 |
| --- | --- |
| 宿主机 | Ubuntu 22.04 amd64 |
| 容器 | Ubuntu 20.04 + ROS Noetic |
| 雷达 | Livox MID-360 |
| 主机雷达网口 | `192.168.1.5/24` |
| MID-360 地址 | `192.168.1.3` |
| `Livox-SDK2` | `c0796f0` |
| `livox_ros_driver2` | `2144554` |
| Point-LIO | `1510c3b` |
| LIO-SAM-MID360 | `21ef7bb`，`Livox-ros-driver2` 分支 |

镜像只构建 `linux/amd64`。ARM/Jetson 设备不能直接使用该镜像。

## 最快部署

### 1. 安装 Docker

在 Ubuntu 22.04 上按照 Docker 官方文档安装 Docker Engine 和 Compose v2：

<https://docs.docker.com/engine/install/ubuntu/>

确认：

```bash
docker --version
docker compose version
```

如果当前用户不在 `docker` 组，命令前加 `sudo`，或按 Docker 官方文档配置
非 root 使用方式。

### 2. 下载仓库

```bash
git clone https://github.com/Qiurilinmu/mid360-lio-docker.git
cd mid360-lio-docker
```

### 3. 配置 MID-360 专用网口

先查看接口：

```bash
ip -br link
nmcli device status
```

假设连接 MID-360 的网口是 `enp2s0`：

```bash
sudo ./scripts/configure-mid360-network.sh enp2s0 192.168.1.5/24 192.168.1.3
```

脚本会：

- 创建持久化 NetworkManager 连接；
- 不配置默认网关，不影响 Wi-Fi/互联网默认路由；
- 更新 `.env`；
- 更新 `config/MID360_config.json` 中的主机和雷达地址；
- 用 `ping` 做基础连通检查。

不要猜测网口。如果机器上有多个有线接口，应先通过插拔网线或
`ethtool <接口>` 确认连接 MID-360 的接口。

### 4. 拉取并创建容器

```bash
./scripts/deploy.sh
```

等价的手动命令：

```bash
cp .env.example .env
mkdir -p data
docker compose pull
docker compose up -d
```

公开 GHCR 镜像地址：

```text
ghcr.io/qiurilinmu/mid360-lio-docker:noetic-amd64
```

### 5. 启动算法

Point-LIO：

```bash
./scripts/start-pointlio.sh
```

LIO-SAM：

```bash
./scripts/start-liosam.sh
```

停止所有 ROS、驱动和算法进程：

```bash
./scripts/stop-all.sh
```

查看状态：

```bash
./scripts/status.sh
```

**不要同时启动 Point-LIO 和 LIO-SAM。** 两者订阅同一套数据，但会发布可能
冲突的 TF 和全局状态。本项目的启动脚本会检测另一算法是否正在运行。

## 验证数据

进入容器：

```bash
docker exec -it mid360-lio bash
source /opt/ros/noetic/setup.bash
source /root/ws_livox/devel/setup.bash
source /root/ws_pointlio/devel/setup.bash
source /root/ws_liosam_mid360/devel/setup.bash
```

检查 MID-360：

```bash
rostopic hz /livox/lidar
rostopic hz /livox/imu
```

正常情况下：

- `/livox/lidar` 约 10 Hz；
- `/livox/imu` 约 200 Hz。

检查 Point-LIO：

```bash
rostopic hz /aft_mapped_to_init
rostopic echo -n 1 /aft_mapped_to_init
```

检查 LIO-SAM：

```bash
rostopic hz /lio_sam/mapping/odometry
rostopic echo -n 1 /lio_sam/mapping/odometry
```

## 日志和数据

宿主机仓库的 `data/` 挂载为容器中的 `/data`：

```text
data/logs/pointlio/
data/logs/liosam/
data/maps/pointlio/
data/maps/liosam/
```

默认关闭自动 PCD 保存，避免长期运行占满磁盘。确实需要建图文件时：

- Point-LIO：把容器内 `config/mid360.yaml` 的 `pcd_save_en` 改为 `true`，
  停止算法时地图写入 `/data/maps/pointlio`；
- LIO-SAM：把 `config/paramsLivoxIMU.yaml` 的 `savePCD` 改为 `true`，或调用
  `lio_sam/save_map` 服务，目标目录使用 `/data/maps/liosam`。

开启保存前先检查：

```bash
df -h
du -sh data
```

## 从源码构建镜像

如果 GHCR 镜像暂时无法拉取，可以在仓库根目录重建：

```bash
docker compose build --no-cache
docker compose up -d
```

构建会下载固定提交的四个上游仓库、安装 GTSAM/PCL 等依赖并编译三个 catkin
工作空间。首次构建耗时较长，并建议至少预留 25 GB 可用磁盘和 8 GB 内存。

构建完成后可给本地镜像命名：

```bash
docker tag mid360-lio-docker-mid360-lio \
  ghcr.io/qiurilinmu/mid360-lio-docker:local
```

## 更换 IP

例如新主机使用 `192.168.2.5/24`、雷达使用 `192.168.2.3`：

```bash
sudo ./scripts/configure-mid360-network.sh enp2s0 192.168.2.5/24 192.168.2.3
docker compose up -d --force-recreate
```

主机地址必须与 JSON 中的 `cmd_data_ip`、`push_msg_ip`、`point_data_ip`、
`imu_data_ip` 一致。雷达地址必须与 `lidar_configs[0].ip` 一致。

## 常见问题

### 有话题名但没有点云

依次检查：

```bash
ip -br addr
ping -c 3 192.168.1.3
docker logs mid360-lio
tail -n 100 data/logs/pointlio/livox.log
```

重点确认网线、雷达供电、主机静态地址和 JSON 中地址一致。

### `Cannot load message class for livox_ros_driver2/CustomMsg`

当前终端没有加载驱动工作空间：

```bash
source /opt/ros/noetic/setup.bash
source /root/ws_livox/devel/setup.bash
```

### 拉取 GHCR 报权限错误

公共镜像正常不需要登录。如果包刚发布仍为 private，需要在 GitHub Package
设置中把 `mid360-lio-docker` 的 visibility 改为 Public，然后重新拉取。

### 算法位置缓慢漂移

这是 LIO 的累计误差，不是容器故障。长期绝对定位需要已有地图重定位、NDT、
GNSS、UWB、轮速或视觉约束之一。

## 自动构建与发布

`.github/workflows/publish-image.yml` 支持手动运行，或在推送 `v*` 标签时构建并
发布 `noetic-amd64` 镜像。工作流通过仓库的 `GITHUB_TOKEN` 写入 GHCR，不需要
把个人令牌提交到仓库。

## 第三方项目

本仓库只维护容器构建、适配配置和部署脚本。算法和驱动版权归各上游项目所有：

- <https://github.com/Livox-SDK/Livox-SDK2>
- <https://github.com/Livox-SDK/livox_ros_driver2>
- <https://github.com/hku-mars/Point-LIO>
- <https://github.com/nkymzsy/LIO-SAM-MID360>

使用、再分发或商用前请分别检查各上游项目许可证。

## 给 AI 的部署提示词

完整提示词见 [AI_DEPLOY_PROMPT.md](AI_DEPLOY_PROMPT.md)。新机器准备好后，将仓库
链接和该提示词一起交给 AI 即可。

