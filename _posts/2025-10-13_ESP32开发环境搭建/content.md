---
title: 智能小车——esp32开发环境搭建
tags: [工作分享, 智能小车, esp32]
comments: true
toc: true
---

## 一、配置 WSL2 挂载ESP32

### 1.1 安装 usbipd-win 工具

`usbipd-win` 是 Windows11 上的 USB/IP 服务器，用于共享 USB 设备给 WSL2：

打开 PowerShell（管理员模式），执行以下命令安装（需联网）：

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

安装完成后，重启电脑（确保服务生效）。

### 1.2 查找 ESP32 的 USB 设备 ID

将 ESP32 通过 USB 连接到电脑，在 PowerShell 中执行以下命令，列出所有 USB 设备：

```powershell
usbipd list
```

输出示例（需找到 ESP32 对应的设备，通常带有COM3等字样）：

```plaintext
BUSID  VID:PID    DEVICE                                                        STATE
1-3    10c4:ea60  Silicon Labs CP210x USB to UART Bridge (COM3)                 Not shared
```

记录 `BUSID`（如 `1-3`）和设备名称，后续用于转发。

### 1.3 将 USB 设备附加到 WSL2

在 PowerShell 中执行以下命令，将 ESP32 转发到 WSL2（替换 `BUSID` 为实际值，`Ubuntu-22.04` 为你的 WSL 发行版名称）：

```powershell
# 在管理员 PowerShell 中

# 1. 绑定设备以供共享
usbipd bind --busid 1-3

# 2. 将已绑定的设备附加到 WSL
usbipd attach --wsl --busid 1-3
```

### 1.4 验证 WSL2 已识别 USB 设备

打开 WSL2 终端（如 Ubuntu），执行以下命令验证设备是否被识别：

```bash
ls /dev/ttyUSB*  
# 或者
ls /dev/ttyACM*  
```

## 二、创建PlatformIO编译环境

### 2.1 配置Docker环境

#### Dockerfile

这个文件告诉 Docker 如何构建镜像。它会从一个基础 Python 镜像开始，然后安装 PlatformIO Core 和一些必要的工具。

```dockerfile
# 使用本地已有的 Alpine 镜像
FROM alpine:3.22

# 设置环境变量
ENV PLATFORMIO_CORE_DIR=/root/.platformio

# 安装 Python3、pip 和其他必要软件，包括glibc兼容性支持
RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    gcc \
    g++ \
    musl-dev \
    linux-headers \
    eudev-dev \
    gcompat \
    libstdc++ \
    libgcc \
    bash \
    && ln -sf python3 /usr/bin/python

# 升级 pip 并安装 PlatformIO
RUN python3 -m pip install --upgrade pip --break-system-packages && \
    python3 -m pip install platformio --break-system-packages

# 创建 udev 规则目录和 PlatformIO udev 规则文件
RUN mkdir -p /etc/udev/rules.d && \
    echo '# PlatformIO udev rules' > /etc/udev/rules.d/99-platformio-udev.rules && \
    echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="0666", GROUP="dialout"' >> /etc/udev/rules.d/99-platformio-udev.rules && \
    echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", GROUP="dialout"' >> /etc/udev/rules.d/99-platformio-udev.rules && \
    echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="0666", GROUP="dialout"' >> /etc/udev/rules.d/99-platformio-udev.rules && \
    echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1002", MODE="0666", GROUP="dialout"' >> /etc/udev/rules.d/99-platformio-udev.rules

# 设置工作目录
WORKDIR /root

# 保持容器运行
CMD [ "sleep", "infinity" ]
```

#### docker-compose.yml

这个文件可以让我们更方便地管理容器的配置和启动。

```yaml
services:
  platformio-dev:
    # 使用当前目录下的 Dockerfile 进行构建
    build: .
    # 容器的名字，方便识别
    container_name: platformio-dev
    # 保持容器持续运行
    command: sleep infinity
    # 将当前目录下的 project 文件夹挂载到容器的工作区
    # 这样你在 Windows 中修改的代码会实时同步到容器里
    volumes:
      - ./project:/root/project
    # 关键！给予容器访问主机 USB 设备的特权
    privileged: true
```

### 2.2 常用命令

#### 初始化项目

```bash
# 替换 "esp32-3s-devkitc-1" 为你具体的开发板型号
pio project init --board esp32-3s-devkitc-1
# 初始化后项目结构
project/
├── .pio/           # PlatformIO构建输出
├── include/         # 头文件
├── lib/           # 库文件
├── src/
│  ├── main.cpp       # 主程序文件（Blink示例）
│  └── serial_test.cpp.bak # 串口测试程序（备用）
├── test/           # 测试文件
└── platformio.ini      # PlatformIO配置文件
```

#### 编译项目

```bash
docker exec -it platformio-dev sh -c "cd ./project && pio run"
```

#### 上传固件

```bash
# 串口编号
let port = "/dev/ttyACM0"
docker exec -it platformio-dev sh -c "cd ./project && pio run -t upload --upload-port $port"
```

#### 监视串口

```bash
# 注意波特率一定要正确否则监视输出会乱码
docker exec -it platformio-dev sh -c "cd ./project && pio device monitor --port $port --baud 115200"
```

### 2.3 其他脚本

#### 自检脚本

```bash
#!/bin/bash
# ESP32串口诊断脚本
# 用于诊断串口连接和权限问题

echo "=== ESP32串口诊断工具 ==="
echo

# 检查系统串口设备
echo "1. 系统串口设备列表:"
ls -la /dev/tty* | grep -E "(USB|ACM)"
echo

# 检查容器内的串口设备
echo "2. 容器内串口设备列表:"
docker exec -it pio-dev-container sh -c "ls -la /dev/tty* | grep -E '(USB|ACM)'"
echo

# 检查USB设备
echo "3. USB设备列表:"
docker exec -it pio-dev-container sh -c "lsusb"
echo

# 检查PlatformIO设备列表
echo "4. PlatformIO检测到的设备:"
docker exec -it pio-dev-container sh -c "pio device list"
echo

# 检查udev规则
echo "5. udev规则状态:"
docker exec -it pio-dev-container sh -c "ls -la /etc/udev/rules.d/"
echo

echo "=== 诊断完成 ==="
echo
echo "常见问题解决方案:"
echo "1. 如果设备未显示，请检查:"
echo "   - ESP32是否正确连接到USB端口"
echo "   - USB线缆是否支持数据传输"
echo "   - 容器是否以特权模式运行"
echo
echo "2. 如果权限被拒绝，请检查:"
echo "   - 用户是否在dialout组中"
echo "   - udev规则是否正确加载"
echo
echo "3. 如果串口乱码，请检查:"
echo "   - 波特率是否匹配 (115200)"
echo "   - 串口参数设置是否正确"
```

#### 部署脚本

```bash
#!/bin/bash
# ESP32统一管理平台
# 集成编译、上传、监视功能于一体

# 显示帮助信息
show_help() {
    echo "ESP32统一管理平台"
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  build              编译ESP32项目"
    echo "  upload [串口]      上传固件到ESP32（默认串口: /dev/ttyACM0）"
    echo "  monitor [串口]     监视串口输出（默认串口: /dev/ttyACM0）"
    echo "  all [串口]         编译、上传、监视一条龙（默认串口: /dev/ttyACM0）"
    echo "  help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build                    # 仅编译"
    echo "  $0 upload                   # 上传到默认串口"
    echo "  $0 upload /dev/ttyUSB0      # 上传到指定串口"
    echo "  $0 monitor                  # 监视默认串口"
    echo "  $0 all                      # 编译、上传、监视默认串口"
    echo "  $0 all /dev/ttyUSB0         # 编译、上传、监视指定串口"
}

# 获取串口参数，如果没有提供则使用默认值
get_port() {
    if [ -z "$1" ]; then
        echo "/dev/ttyACM0"
    else
        echo "$1"
    fi
}

# 编译项目
build_project() {
    echo "=========================================="
    echo "开始编译ESP32项目..."
    echo "=========================================="
    
    docker exec -it platformio-dev sh -c "cd ./project && pio run"
    
    if [ $? -eq 0 ]; then
        echo "=========================================="
        echo "✅ 编译完成！"
        echo "=========================================="
        return 0
    else
        echo "=========================================="
        echo "❌ 编译失败！"
        echo "=========================================="
        return 1
    fi
}

# 上传固件
upload_firmware() {
    local port=$(get_port "$1")
    echo "=========================================="
    echo "准备上传固件到ESP32..."
    echo "使用串口: $port"
    echo "=========================================="
    
    docker exec -it platformio-dev sh -c "cd ./project && pio run -t upload --upload-port $port"
    
    if [ $? -eq 0 ]; then
        echo "=========================================="
        echo "✅ 上传完成！"
        echo "=========================================="
        return 0
    else
        echo "=========================================="
        echo "❌ 上传失败！请检查ESP32连接和串口设置"
        echo "=========================================="
        return 1
    fi
}

# 监视串口
monitor_serial() {
    local port=$(get_port "$1")
    echo "=========================================="
    echo "开始监视串口输出..."
    echo "使用串口: $port"
    echo "波特率: 115200"
    echo "按 Ctrl+C 退出监视"
    echo "=========================================="
    
    # 在容器内执行监视命令，工作目录已经是 /root/workspace/github/esp32-docker-project
    docker exec -it platformio-dev sh -c "cd ./project && pio device monitor --port $port --baud 115200"
}

# 一条龙操作：编译、上传、监视
all_in_one() {
    local port=$(get_port "$1")
    
    echo "🚀 启动ESP32开发一条龙模式！"
    echo "目标串口: $port"
    echo ""
    
    # 第一步：编译
    if ! build_project; then
        echo "编译失败，停止后续操作"
        exit 1
    fi
    
    echo ""
    echo "等待2秒后继续..."
    sleep 2
    
    # 第二步：上传
    if ! upload_firmware "$port"; then
        echo "上传失败，停止后续操作"
        exit 1
    fi
    
    echo ""
    echo "等待3秒后开始监视..."
    sleep 3
    
    # 第三步：监视
    monitor_serial "$port"
}

# 主程序
main() {
    # 检查是否提供了命令
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        "build")
            build_project
            ;;
        "upload")
            upload_firmware "$2"
            ;;
        "monitor")
            monitor_serial "$2"
            ;;
        "all")
            all_in_one "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "❌ 未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"
```