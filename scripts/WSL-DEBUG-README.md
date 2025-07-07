# WSL Docker调试工具使用指南

本工具集提供了在WSL Ubuntu环境中调试Otter Docker容器的完整解决方案。

## 📁 文件说明

### 核心脚本
- **`wsl-debug-run.sh`** - WSL中的主要调试脚本
- **`wsl-debug-launcher.ps1`** - Windows PowerShell启动器
- **`quick-debug.bat`** - 快速启动批处理文件（推荐）

### 辅助脚本
- **`fix-zookeeper-permissions.sh`** - ZooKeeper权限修复脚本
- **`rebuild-with-permissions.ps1`** - 容器重建脚本
- **`quality-check.ps1`** - 代码质量检查脚本

## 🚀 快速开始

### 方法一：双击运行（最简单）
1. 双击 `quick-debug.bat`
2. 选择操作选项
3. 等待执行完成

### 方法二：PowerShell命令行
```powershell
# 完整重建并运行
.\wsl-debug-launcher.ps1 rebuild

# 查看日志
.\wsl-debug-launcher.ps1 logs

# 进入容器调试
.\wsl-debug-launcher.ps1 enter
```

### 方法三：直接在WSL中运行
```bash
# 在WSL Ubuntu中执行
cd /mnt/d/github/otterwong/scripts
chmod +x wsl-debug-run.sh
./wsl-debug-run.sh rebuild
```

## 🛠️ 功能说明

### 主要操作

| 操作 | 说明 | 推荐场景 |
|------|------|----------|
| `rebuild` | 清理并重新构建运行 | 首次运行或代码更新后 |
| `build` | 仅构建Docker镜像 | 只需要重新构建镜像 |
| `run` | 仅运行容器 | 镜像已存在，只需启动 |
| `status` | 显示容器状态 | 检查容器是否正常运行 |
| `logs` | 显示容器日志 | 调试问题时查看日志 |
| `enter` | 进入容器调试 | 需要在容器内执行命令 |
| `monitor` | 监控服务健康状态 | 持续监控服务状态 |
| `stop` | 停止容器 | 停止运行的容器 |
| `cleanup` | 清理容器和镜像 | 完全清理，释放空间 |

### 端口映射

| 服务 | 端口 | 访问地址 | 说明 |
|------|------|----------|------|
| Manager Web UI | 8080 | http://localhost:8080 | Otter管理界面 |
| ZooKeeper | 2181 | localhost:2181 | ZooKeeper服务 |
| ZooKeeper Admin | 8018 | http://localhost:8018 | ZooKeeper管理界面 |
| Node | 2088 | localhost:2088 | Otter节点服务 |

## 🔧 环境要求

### 必需组件
1. **Windows 11** 或 Windows 10 (版本1903或更高)
2. **WSL 2** 已安装并启用
3. **Ubuntu** 或其他Linux发行版在WSL中 (如果安装了多个WSL发行版，脚本会提示选择Ubuntu)
4. **Docker Desktop** 已安装并启用WSL集成

### 检查环境
```powershell
# 检查WSL版本
wsl --version

# 列出WSL发行版

wsl -l -v

# 检查Docker在WSL中是否可用
wsl docker --version
```

## 🐛 故障排除

### WSL相关问题
```bash
# 检查WSL状态和已安装的发行版
wsl --list --verbose

# 重启WSL
wsl --shutdown

# 设置默认WSL版本
wsl --set-default-version 2

# 如果有多个Ubuntu发行版，可以查看具体名称
wsl --list
```

#### 多WSL发行版选择
- 脚本会自动检测已安装的WSL发行版
- 如果检测到多个包含"Ubuntu"的发行版，会提示您选择
- 选择后的发行版将用于所有Docker操作
- 确保选择的发行版已安装Docker并配置正确

### 常见问题

#### 1. WSL不可用
**症状**: 提示"WSL不可用或未安装"

**解决方案**:
```powershell
# 启用WSL功能
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# 重启后设置WSL 2为默认版本
wsl --set-default-version 2

# 安装Ubuntu
wsl --install -d Ubuntu
```

#### 2. Docker不可用
**症状**: 提示"Docker在WSL中不可用"

**解决方案**:
1. 确保Docker Desktop已启动
2. 在Docker Desktop设置中启用WSL集成
3. 选择要集成的WSL发行版
4. 重启Docker Desktop

#### 3. 权限问题
**症状**: 容器启动失败，权限被拒绝

**解决方案**:
```bash
# 在WSL中手动修复权限
sudo chown -R $USER:$USER /mnt/d/github/otterwong
chmod +x /mnt/d/github/otterwong/scripts/*.sh
```

#### 4. 端口冲突
**症状**: 端口已被占用

**解决方案**:
```powershell
# 查看端口占用
netstat -ano | findstr :8080

# 停止占用端口的进程
taskkill /PID <进程ID> /F
```

### 日志分析

#### 查看容器日志
```bash
# 查看所有日志
docker logs otter-debug

# 实时跟踪日志
docker logs -f otter-debug

# 查看最近50行日志
docker logs --tail 50 otter-debug
```

#### 进入容器检查
```bash
# 进入容器
docker exec -it otter-debug /bin/bash

# 检查服务状态
ps aux | grep java

# 检查端口监听
netstat -tlnp

# 检查文件权限
ls -la /home/admin/
```

## 📊 监控和调试

### 服务健康检查
```bash
# ZooKeeper状态
echo stat | nc localhost 2181

# Manager状态
curl -s http://localhost:8080/health || echo "Manager不可用"

# Node状态
telnet localhost 2088
```

### 性能监控
```bash
# 容器资源使用
docker stats otter-debug

# 系统资源
top
htop
iostat
```

## 🔄 开发工作流

### 典型开发流程
1. **修改代码**
2. **重新构建**: `rebuild`
3. **查看日志**: `logs`
4. **测试功能**: 访问Web界面
5. **调试问题**: `enter` 进入容器
6. **重复流程**

### 快速调试
```bash
# 一键重建并监控
./quick-debug.bat
# 选择 1 (完整重建)
# 然后选择 7 (监控状态)
```

## 📝 最佳实践

### 开发建议
1. **使用rebuild**: 代码更改后总是使用rebuild确保更新生效
2. **监控日志**: 启动后立即查看日志确认服务正常
3. **定期清理**: 使用cleanup清理旧的容器和镜像
4. **备份数据**: 重要数据要及时备份

### 性能优化
1. **资源分配**: 确保Docker Desktop有足够的内存和CPU
2. **磁盘空间**: 定期清理Docker镜像和容器
3. **网络配置**: 检查防火墙和网络设置

## 🆘 获取帮助

### 命令帮助
```powershell
# PowerShell帮助
.\wsl-debug-launcher.ps1 help

# WSL脚本帮助
./wsl-debug-run.sh help
```

### 调试信息收集
```bash
# 收集系统信息
uname -a
docker version
docker info
df -h
free -h

# 收集容器信息
docker ps -a
docker images
docker logs otter-debug
```

---

## 📞 技术支持

如果遇到问题，请提供以下信息：
1. 操作系统版本
2. WSL版本和发行版
3. Docker Desktop版本
4. 错误日志
5. 执行的具体命令

**祝您调试愉快！** 🎉