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

### 查看容器日志

```bash
# 查看所有容器日志
docker-compose logs -f

# 查看特定容器日志
docker-compose logs -f node01
```

### 进入容器调试

```bash
# 进入容器
docker exec -it node01 /bin/bash

# 查看应用日志
tail -f /home/admin/manager/logs/manager.log
tail -f /home/admin/node/logs/node.log
```

### ZooKeeper启动失败

#### 权限问题
如果遇到以下权限错误：
```
/home/admin/zookeeper-3.7.0/bin/../logs/zookeeper-admin-server-otter.out: Permission denied
FAILED TO START
```

**解决方案：**
1. **自动修复（推荐）**：重新构建镜像，Dockerfile已包含权限优化
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

2. **手动修复**：使用ZooKeeper权限修复脚本
```bash
# 在容器内执行
docker exec -it otter bash /home/admin/scripts/fix-zookeeper-permissions.sh

# 然后重启容器
docker restart otter
```

3. **临时修复**：手动设置权限
```bash
docker exec -it otter bash -c "
chown -R admin:admin /home/admin/zookeeper-3.7.0/logs
chmod -R 755 /home/admin/zookeeper-3.7.0/logs
chown -R admin:admin /home/admin/zkData
chmod -R 755 /home/admin/zkData
"
docker restart otter
```

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

## 🔗 相关链接

- [Otter 官方文档](https://github.com/alibaba/otter/wiki)
- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
