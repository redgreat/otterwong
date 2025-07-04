# OtterWong - Docker版Otter数据同步中间件

基于阿里巴巴开源的 Otter 数据同步中间件的 Docker 化部署方案。

## 🚀 特性

- **容器化部署**：完全基于 Docker 和 Docker Compose
- **外部数据库支持**：支持连接外部 MySQL 数据库
- **配置文件映射**：配置文件映射到本地，便于修改和管理
- **集群支持**：支持 ZooKeeper 集群和多节点部署
- **灵活运行模式**：支持 ALL、MANAGER、NODE 三种运行模式

## 📋 系统要求

- Docker 20.10+
- Docker Compose 2.0+
- 外部 MySQL 5.7+ 数据库

## 🛠️ 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/your-username/otterwong.git
cd otterwong
```

### 2. 准备外部 MySQL 数据库

在你的 MySQL 数据库中执行以下 SQL：

```sql
-- 创建数据库
CREATE DATABASE otter DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户并授权
CREATE USER 'otter'@'%' IDENTIFIED BY 'otter_password';
GRANT ALL PRIVILEGES ON otter.* TO 'otter'@'%';
FLUSH PRIVILEGES;
```

### 3. 初始化数据库表结构

`docker/otter-manager-schema.sql`

### 4. 配置数据库连接

修改 `config/manager/otter.properties` 文件中的数据库连接配置：

```properties
# 修改为你的 MySQL 数据库地址
otter.database.driver.url = jdbc:mysql://your-mysql-host:3306/otter?useUnicode=true&characterEncoding=UTF-8&useSSL=false
otter.database.driver.username = otter
otter.database.driver.password = otter_password
```

### 5. 启动服务

```bash
# 使用外部 MySQL 数据库
docker-compose -f docker-compose-external-mysql.yml up -d

# 或者使用默认配置（需要先配置好外部数据库）
docker-compose up -d
```

### 6. 访问管理界面

打开浏览器访问：http://localhost:8080

默认用户名/密码：`admin/admin`

### ⚠️ 启动问题快速修复

如果遇到启动问题，请按以下顺序尝试：

1. **运行诊断脚本**
   ```bash
   ./scripts/diagnose-startup-issues.sh
   ```

2. **ZooKeeper启动失败修复**
   ```bash
   # 快速修复权限和JVM问题
   ./scripts/quick-fix-zookeeper.sh
   ```

3. **完全重建（解决JVM参数问题）**
   ```bash
   # 重新构建镜像并应用所有修复
   ./rebuild-with-jvm-fix.sh
   ```

4. **查看详细日志**
   ```bash
   docker-compose logs otter | grep -E "(ERROR|WARN|Exception|Permission denied|Aborted)"
   ```

## 📁 项目结构

```
otterwong/
├── Dockerfile                              # Docker 镜像构建文件
├── docker-compose.yml                      # 默认 Docker Compose 配置
├── docker-compose-external-mysql.yml       # 外部 MySQL 配置示例
├── config/                                  # 配置文件目录
│   ├── README.md                           # 配置说明文档
│   ├── manager/                            # Manager 配置文件
│   │   ├── otter.properties               # Manager 主配置
│   │   ├── jetty.xml                      # Jetty 配置
│   │   └── logback.xml                    # 日志配置
│   └── node/                              # Node 配置文件
│       ├── otter.properties               # Node 主配置
│       └── logback.xml                    # 日志配置
└── docker/                                # Docker 相关文件
    ├── app.sh                             # 容器启动脚本
    ├── manager.deployer-4.2.19-SNAPSHOT.tar.gz
    ├── node.deployer-4.2.19-SNAPSHOT.tar.gz
    ├── otter-manager-schema.sql
    └── apache-zookeeper-3.7.0-bin.tar.gz
```

## 🔧 运行模式

通过环境变量 `RUN_MODE` 可以控制容器的运行模式：

- **ALL**：同时运行 Manager 和 Node（默认）
- **MANAGER**：仅运行 Manager
- **NODE**：仅运行 Node

## 🌐 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 8080 | Manager Web | 管理界面 |
| 8018 | ZooKeeper Admin | ZooKeeper 管理端口 |
| 2181 | ZooKeeper | ZooKeeper 客户端端口 |
| 2088 | Node | Node 服务端口 |
| 2089 | Node | Node 下载端口 |
| 2090 | Node | Node MBean 端口 |

## 📝 注意事项

1. **数据库连接**：确保外部 MySQL 数据库网络可达
2. **防火墙设置**：检查防火墙设置，确保相关端口开放
3. **用户权限**：建议使用专用的数据库用户，避免使用 root 用户
4. **数据备份**：定期备份 Otter 数据库
5. **密码安全**：生产环境建议修改默认密码
6. **资源限制**：根据实际需求调整容器资源限制

## 🔍 故障排查

### 快速诊断工具
```bash
# 运行综合诊断脚本（推荐）
./scripts/diagnose-startup-issues.sh

# 该脚本会自动检查：
# - Docker服务状态和资源使用
# - Java环境配置
# - ZooKeeper/Manager/Node进程状态
# - 端口监听情况
# - 日志文件内容
# - 常见问题（JVM参数、权限、内存、进程异常）
# - 目录权限设置
```

### 手动检查步骤

**1. 检查服务状态**
```bash
# 查看容器状态
docker-compose ps

# 查看服务日志
docker-compose logs otter

# 查看特定错误日志
docker-compose logs otter | grep -E "(ERROR|WARN|Exception|Permission denied|Aborted)"
```

**2. 检查JVM参数修复效果**
```bash
# 检查Manager启动脚本
docker-compose exec otter cat /home/admin/manager/bin/startup.sh | grep JAVA_OPTS

# 检查Manager日志中的JVM警告
docker-compose exec otter tail -100 /home/admin/manager/logs/manager.log | grep -E "(PermSize|MaxPermSize|UseCMSCompactAtFullCollection)"

# 检查内存分配错误
docker-compose exec otter tail -100 /home/admin/manager/logs/manager.log | grep -E "(out of memory|unable to allocate)"
```

**3. 检查ZooKeeper状态**
```bash
# 检查ZooKeeper进程
docker-compose exec otter ps aux | grep zookeeper

# 检查ZooKeeper端口
docker-compose exec otter netstat -tlnp | grep 2181

# 检查ZooKeeper服务状态
docker-compose exec otter gosu admin /home/admin/zookeeper-3.7.0/bin/zkServer.sh status

# 检查ZooKeeper日志
docker-compose exec otter tail -50 /home/admin/zkData/zookeeper.log
```

**4. 检查权限问题**
```bash
# 检查ZooKeeper目录权限
docker-compose exec otter ls -la /home/admin/zookeeper-3.7.0/logs/

# 检查数据目录权限
docker-compose exec otter ls -la /home/admin/zkData/

# 检查日志文件是否存在
docker-compose exec otter ls -la /home/admin/zookeeper-3.7.0/logs/zookeeper-admin-server-otter.out
```

**5. 检查Java环境**
```bash
# 检查Java版本
docker-compose exec otter java -version

# 检查JAVA_HOME
docker-compose exec otter echo $JAVA_HOME

# 检查Java进程
docker-compose exec otter ps aux | grep java
```

### 进入容器调试

```bash
# 进入容器
docker exec -it otter /bin/bash

# 查看应用日志
tail -f /home/admin/manager/logs/manager.log
tail -f /home/admin/node/logs/node.log
```

### ZooKeeper启动问题

#### 权限问题

如果ZooKeeper启动时遇到`Permission denied`错误：

```
Starting zookeeper ... /home/admin/zookeeper-3.7.0/bin/zkServer.sh: line 164: /home/admin/zookeeper-3.7.0/bin/../logs/zookeeper-admin-server-otter.out: Permission denied
FAILED TO START
```

#### JVM兼容性问题

如果ZooKeeper启动时遇到Java进程异常终止：

```
Starting zookeeper ... /home/admin/zookeeper-3.7.0/bin/zkServer.sh: line 155: 52 Aborted (core dumped) nohup "$JAVA" ...
FAILED TO START
```

这通常是由于ZooKeeper的JVM参数与Java 8不兼容导致的。

#### 快速诊断

```bash
# 运行诊断脚本
./scripts/diagnose-startup-issues.sh
```

#### 解决方案

**推荐方案（完全重建）：**
使用重建脚本，确保所有修复都生效：

```bash
# 运行完整重建脚本
./rebuild-with-jvm-fix.sh
```

**手动重建方案：**
重新构建镜像，Dockerfile已包含所有修复：

```bash
docker-compose down --remove-orphans
docker rmi otterwong_otter:latest || true
docker builder prune -a -f
docker-compose build --no-cache --pull otter
docker-compose up -d
```

**专用修复脚本：**
运行ZooKeeper专用修复脚本：

```bash
# 在容器内执行
docker exec -it otter bash /home/admin/scripts/fix-zookeeper-startup.sh

# 或在宿主机执行
bash scripts/fix-zookeeper-startup.sh
```

**临时修复方案：**
手动设置权限和JVM参数：

```bash
# 进入容器
docker exec -it otter bash

# 修复权限
mkdir -p /home/admin/zookeeper-3.7.0/logs
touch /home/admin/zookeeper-3.7.0/logs/zookeeper-admin-server-otter.out
chown -R admin:admin /home/admin/zookeeper-3.7.0
chmod -R 777 /home/admin/zookeeper-3.7.0/logs
chmod +x /home/admin/zookeeper-3.7.0/bin/*.sh

# 修复JVM参数
sed -i 's/-XX:PermSize=[0-9]*[mMgG]//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh
sed -i 's/-XX:MaxPermSize=[0-9]*[mMgG]//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh
sed -i 's/-XX:+UseCMSCompactAtFullCollection//g' /home/admin/zookeeper-3.7.0/bin/zkServer.sh

# 设置环境变量并重启
export JVMFLAGS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
gosu admin env JVMFLAGS="$JVMFLAGS" /home/admin/zookeeper-3.7.0/bin/zkServer.sh restart
```

#### 修复内容

- **权限修复**：确保ZooKeeper目录和日志文件的正确权限，预创建日志文件
- **JVM参数优化**：移除Java 8不支持的参数（PermSize、MaxPermSize等）
- **垃圾收集器更新**：从CMS切换到G1GC，减少内存碎片
- **内存配置优化**：设置合适的堆内存大小和GC参数
- **环境变量设置**：确保JAVA_HOME和PATH正确配置
- **启动脚本优化**：改进ZooKeeper启动流程，增加状态检查

### JVM参数警告问题
#### JVM参数优化问题

在使用Java 8运行Otter时，可能会遇到以下JVM参数警告和内存错误：

```
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option PermSize=96m; support was removed in 8.0
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=256m; support was removed in 8.0
Java HotSpot(TM) 64-Bit Server VM warning: UseCMSCompactAtFullCollection is deprecated and will likely be removed in a future release.
library initialization failed - unable to allocate file descriptor table - out of memory
```

#### 解决方案

**推荐方案（完全重建）：**
使用专用脚本重新构建Docker镜像，确保JVM参数修复生效：

```bash
# 运行完整重建脚本
./rebuild-with-jvm-fix.sh
```

**手动重建方案：**
如果需要手动重建，请按以下步骤操作：

```bash
# 1. 停止并删除容器
docker-compose down --remove-orphans
docker container prune -f

# 2. 删除旧镜像
docker rmi otterwong_otter:latest || true
docker images | grep otter | awk '{print $3}' | xargs -r docker rmi || true

# 3. 清理构建缓存
docker builder prune -a -f
docker system prune -f

# 4. 重新构建镜像（无缓存）
docker-compose build --no-cache --pull otter

# 5. 启动服务
docker-compose up -d
```

**临时修复方案：**
如果只需要临时修复现有容器，可以运行：

```bash
# 运行JVM参数修复脚本
./fix-jvm-params.sh
```

#### 优化内容

- **移除废弃参数**：`PermSize`、`MaxPermSize`、`UseCMSCompactAtFullCollection`等
- **替换垃圾收集器**：从CMS切换到G1GC，提供更好的性能和内存管理
- **优化内存配置**：调整堆内存大小和新生代比例，避免内存分配错误
- **添加GC暂停时间控制**：设置`MaxGCPauseMillis=200`提升响应性
- **分离sed命令**：避免复杂正则表达式导致的sed执行失败

#### 故障排查

如果重建后仍有问题，请检查：

1. **验证容器内文件**：
   ```bash
   docker-compose exec otter cat /home/admin/manager/bin/startup.sh | grep JAVA_OPTS
   ```

2. **检查日志**：
   ```bash
   docker-compose logs otter
   docker-compose exec otter tail -100 /home/admin/manager/logs/manager.log
   ```

3. **确认镜像版本**：
   ```bash
   docker images | grep otter
   ```

#### 其他问题
- 检查端口是否被占用：`netstat -tulpn | grep 2181`
- 查看ZooKeeper日志：`docker exec -it otter tail -f /home/admin/zkData/zookeeper.log`
- 确保有足够的内存和磁盘空间

### Manager连接失败
- 检查数据库连接配置是否正确
- 确认外部MySQL数据库可访问
- 查看Manager日志：`docker exec -it otter tail -f /home/admin/manager/logs/manager.log`

### Node连接失败
- 检查Manager地址配置
- 确认ZooKeeper服务正常运行
- 查看Node日志：`docker exec -it otter tail -f /home/admin/node/logs/node.log`

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于 MIT 许可证开源。

## ❓ 常见问题

### Q: ZooKeeper启动失败 - Permission denied
**问题**: `Permission denied` 无法创建 `zookeeper-admin-server-otter.out` 文件

**解决方案**:
```bash
# 方法1: 使用重建脚本（推荐）
./rebuild-with-jvm-fix.sh

# 方法2: 手动修复权限
docker-compose exec otter bash
mkdir -p /home/admin/zookeeper-3.7.0/logs
touch /home/admin/zookeeper-3.7.0/logs/zookeeper-admin-server-otter.out
chmod 777 /home/admin/zookeeper-3.7.0/logs
chown -R admin:admin /home/admin/zookeeper-3.7.0
```

### Q: Java进程异常终止 - Aborted (core dumped)
**问题**: ZooKeeper启动时Java进程异常终止

**原因**: JVM参数与Java 8不兼容（如PermSize、UseCMSCompactAtFullCollection等废弃参数）

**解决方案**:
```bash
# 使用修复脚本
./scripts/fix-zookeeper-startup.sh

# 或手动设置JVM参数
export JVMFLAGS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

### Q: Manager启动时JVM参数警告
**问题**: 日志中出现 `PermSize`、`MaxPermSize` 等废弃参数警告

**解决方案**:
```bash
# 重新构建镜像应用修复
./rebuild-with-jvm-fix.sh
```

### Q: 内存分配错误
**问题**: `unable to allocate file descriptor table - out of memory`

**解决方案**:
1. 检查Docker容器内存限制
2. 优化JVM堆内存设置
3. 使用G1GC减少内存碎片

### Q: 容器启动失败
**解决方案**: 
- 检查端口是否被占用
- 确保Docker服务正常运行
- 运行诊断脚本: `./scripts/diagnose-startup-issues.sh`

### Q: 数据库连接失败
**解决方案**: 
- 检查数据库配置
- 确保数据库服务已启动
- 检查网络连接

### Q: 同步任务不工作
**解决方案**: 
- 检查ZooKeeper连接状态
- 确保Manager和Node都正常运行
- 查看同步任务配置和日志

## 🔗 相关链接

- [Otter 官方文档](https://github.com/alibaba/otter/wiki)
- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
