# WSL Ubuntu Docker 安装指南

本指南详细说明如何在 WSL Ubuntu 环境中安装 Docker 并构建 Otter 项目镜像。

## 📋 前置要求

### 系统要求
- Windows 10 版本 2004 及更高版本 (内部版本 19041 及更高版本) 或 Windows 11
- 已启用 WSL 2
- 已安装 Ubuntu WSL 发行版

### 检查 WSL 状态
```powershell
# 检查 WSL 版本和已安装的发行版
wsl --list --verbose

# 确保使用 WSL 2
wsl --set-default-version 2
```

## 🚀 快速开始

### 方法一：使用自动化脚本（推荐）

1. **运行PowerShell脚本**
   ```powershell
   # 在PowerShell中执行
   .\scripts\wsl-docker-install.ps1
   ```

2. **选择完整安装**
   - 在菜单中选择 `1` 进行完整安装
   - 脚本将自动完成所有安装步骤

### 方法二：手动执行脚本

1. **在 WSL Ubuntu 中执行**
   ```bash
   # 进入项目目录
   cd /mnt/d/github/otterwong
   
   # 给脚本执行权限
   chmod +x scripts/wsl-docker-setup.sh
   
   # 执行完整安装
   ./scripts/wsl-docker-setup.sh install
   ```

## 📖 详细安装步骤

### 1. 系统准备

#### 更新系统包
```bash
sudo apt update && sudo apt upgrade -y
```

#### 安装必要依赖
```bash
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    unzip
```

### 2. 安装 Docker

#### 添加 Docker 官方 GPG 密钥
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

#### 添加 Docker 仓库
```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### 安装 Docker Engine
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

#### 配置用户权限
```bash
# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新加载用户组（或重新登录）
newgrp docker
```

### 3. 启动 Docker 服务

```bash
# 启动 Docker 服务
sudo service docker start

# 验证 Docker 安装
docker --version
docker run --rm hello-world
```

### 4. 构建 Otter 镜像

```bash
# 进入项目目录
cd /mnt/d/github/otterwong

# 构建镜像
docker build -t otter:latest .

# 验证镜像构建
docker images | grep otter
```

### 5. 运行 Otter 容器

```bash
# 运行容器
docker run -d \
    --name otter-container \
    -p 8080:8080 \
    -p 9092:9092 \
    -p 2181:2181 \
    otter:latest

# 检查容器状态
docker ps
```

## 🛠️ 管理命令

### 容器管理

```bash
# 查看容器状态
docker ps -a

# 查看容器日志
docker logs otter-container

# 进入容器调试
docker exec -it otter-container /bin/bash

# 停止容器
docker stop otter-container

# 删除容器
docker rm otter-container
```

### 镜像管理

```bash
# 查看镜像
docker images

# 删除镜像
docker rmi otter:latest

# 清理未使用的资源
docker system prune -f
```

### 使用自动化脚本

```bash
# 脚本用法
./scripts/wsl-docker-setup.sh [选项]

# 可用选项：
# install  - 完整安装
# build    - 仅构建镜像
# run      - 运行容器
# status   - 显示状态
# logs     - 显示日志
# enter    - 进入容器
# cleanup  - 清理资源
# help     - 显示帮助
```

## 🌐 访问服务

安装完成后，可以通过以下地址访问服务：

- **Otter Web 管理界面**: http://localhost:8080
- **ZooKeeper**: localhost:2181
- **Kafka**: localhost:9092

## 🔧 故障排除

### Docker 服务问题

#### Docker 服务未启动
```bash
# 检查服务状态
sudo service docker status

# 启动服务
sudo service docker start

# 设置开机自启（可选）
sudo systemctl enable docker
```

#### 权限问题
```bash
# 如果遇到权限错误
sudo usermod -aG docker $USER
newgrp docker

# 或者重新登录 WSL
exit
# 然后重新打开 WSL
```

### 网络问题

#### 端口冲突
```bash
# 检查端口占用
netstat -tulpn | grep :8080

# 使用不同端口运行
docker run -d --name otter-container -p 8081:8080 otter:latest
```

#### 防火墙问题
```bash
# 在 Windows 中检查防火墙设置
# 确保允许 WSL 访问网络
```

### 构建问题

#### 磁盘空间不足
```bash
# 检查磁盘空间
df -h

# 清理 Docker 资源
docker system prune -a
```

#### 网络连接问题
```bash
# 检查网络连接
ping google.com

# 配置 DNS（如果需要）
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### 常见错误解决

#### "Cannot connect to the Docker daemon"
```bash
# 启动 Docker 服务
sudo service docker start

# 检查用户组
groups $USER
```

#### "Permission denied"
```bash
# 修复权限
sudo chown $USER:$USER /var/run/docker.sock
```

#### "Port already in use"
```bash
# 查找占用端口的进程
sudo lsof -i :8080

# 停止冲突的容器
docker stop $(docker ps -q --filter "publish=8080")
```

## 📊 性能优化

### WSL 资源配置

创建 `.wslconfig` 文件在 Windows 用户目录：
```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

### Docker 资源限制

```bash
# 运行容器时限制资源
docker run -d \
    --name otter-container \
    --memory=2g \
    --cpus=1.5 \
    -p 8080:8080 \
    otter:latest
```

## 🔄 开发工作流

### 日常开发流程

1. **启动开发环境**
   ```bash
   ./scripts/wsl-docker-setup.sh run
   ```

2. **查看日志**
   ```bash
   ./scripts/wsl-docker-setup.sh logs
   ```

3. **代码修改后重新构建**
   ```bash
   ./scripts/wsl-docker-setup.sh build
   ./scripts/wsl-docker-setup.sh run
   ```

4. **调试问题**
   ```bash
   ./scripts/wsl-docker-setup.sh enter
   ```

### 自动化脚本集成

可以将脚本集成到 IDE 或编辑器中：

```json
// VS Code tasks.json 示例
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build Otter",
            "type": "shell",
            "command": "wsl",
            "args": ["bash", "/mnt/d/github/otterwong/scripts/wsl-docker-setup.sh", "build"]
        },
        {
            "label": "Run Otter",
            "type": "shell",
            "command": "wsl",
            "args": ["bash", "/mnt/d/github/otterwong/scripts/wsl-docker-setup.sh", "run"]
        }
    ]
}
```

## 📚 参考资源

### 官方文档
- [WSL 官方文档](https://docs.microsoft.com/en-us/windows/wsl/)
- [Docker 官方文档](https://docs.docker.com/)
- [Ubuntu WSL 安装指南](https://ubuntu.com/wsl)

### 有用链接
- [Docker Desktop for Windows](https://docs.docker.com/desktop/windows/)
- [WSL 2 最佳实践](https://docs.microsoft.com/en-us/windows/wsl/compare-versions)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## 🆘 获取帮助

如果遇到问题，可以：

1. **查看脚本帮助**
   ```bash
   ./scripts/wsl-docker-setup.sh help
   ```

2. **检查系统日志**
   ```bash
   sudo journalctl -u docker.service
   ```

3. **查看 Docker 日志**
   ```bash
   docker logs otter-container
   ```

4. **重置环境**
   ```bash
   ./scripts/wsl-docker-setup.sh cleanup
   ./scripts/wsl-docker-setup.sh install
   ```

---

*本指南将根据项目需求和用户反馈持续更新。*