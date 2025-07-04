#!/bin/bash

# ZooKeeper 配置修复脚本
# 解决主机名不一致和配置问题

echo "=== ZooKeeper 配置修复脚本 ==="
echo ""

# 检查当前目录
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose-1g.yml" ]; then
    echo "错误: 请在 otterwong 项目根目录下运行此脚本"
    exit 1
fi

# 修复 app.sh 中的 ZooKeeper 配置
function fix_app_sh() {
    echo "1. 修复 app.sh 中的 ZooKeeper 配置..."
    
    # 备份原文件
    cp docker/app.sh docker/app.sh.backup.$(date +%Y%m%d_%H%M%S)
    
    # 修复 ZooKeeper 默认服务器配置
    sed -i 's/ZOO_SERVERS="server.1=localhost:2888:3888"/ZOO_SERVERS="server.1=otter:2888:3888"/' docker/app.sh
    
    # 添加主机名解析检查
    cat > /tmp/zk_fix.txt << 'EOF'

# 检查主机名解析
function check_hostname_resolution() {
    echo "检查主机名解析..."
    if ! getent hosts otter > /dev/null 2>&1; then
        echo "警告: 无法解析主机名 'otter'，添加到 /etc/hosts"
        echo "127.0.0.1 otter" >> /etc/hosts
    fi
}
EOF
    
    # 在 start_zookeeper 函数前插入主机名检查
    sed -i '/^function start_zookeeper() {/i\n# 检查主机名解析\nfunction check_hostname_resolution() {\n    echo "检查主机名解析..."\n    if ! getent hosts otter > /dev/null 2>&1; then\n        echo "警告: 无法解析主机名 '"'"'otter'"'"'，添加到 /etc/hosts"\n        echo "127.0.0.1 otter" >> /etc/hosts\n    fi\n}' docker/app.sh
    
    # 在 start_zookeeper 函数开始时调用主机名检查
    sed -i '/echo "start zookeeper ..."/a\    check_hostname_resolution' docker/app.sh
    
    echo "   ✓ app.sh 配置已修复"
}

# 修复 docker-compose 配置
function fix_docker_compose() {
    echo "2. 检查 docker-compose 配置..."
    
    # 检查是否存在网络配置问题
    if grep -q "extra_hosts" docker-compose-1g.yml; then
        echo "   ✓ extra_hosts 配置已存在"
    else
        echo "   警告: 建议在 docker-compose.yml 中添加 extra_hosts 配置"
    fi
    
    # 检查 ZOO_SERVERS 环境变量
    if grep -q "ZOO_SERVERS" docker-compose-1g.yml; then
        echo "   ✓ ZOO_SERVERS 环境变量已配置"
    else
        echo "   警告: 建议添加 ZOO_SERVERS 环境变量"
    fi
}

# 创建优化的 docker-compose 配置
function create_optimized_compose() {
    echo "3. 创建优化的 docker-compose 配置..."
    
    cat > docker-compose-fixed.yml << 'EOF'
version: "3"
services:
  otter:
    image: registry.cn-hangzhou.aliyuncs.com/redgreat/otter
    restart: unless-stopped
    container_name: otter
    hostname: otter
    networks:
      otter:
        ipv4_address: 10.10.20.11
    ports:
      - 8080:8080 
      - 8018:8018
      - 2181:2181
      - 2088:2088
    volumes:
      - ./config/manager:/home/admin/manager/conf
      - ./config/node:/home/admin/node/conf
      - otter_zk_data:/home/admin/zkData
      - otter_zk_logs:/home/admin/zookeeper-3.7.0/logs
    environment:
      TZ: Asia/Shanghai
      ZOO_CLUSTER: otter:2181
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=otter:2888:3888
      RUN_MODE: ALL
      MANAGER_ADD: 10.10.20.11
      # ZooKeeper 优化配置
      ZOO_TICK_TIME: 2000
      ZOO_INIT_LIMIT: 10
      ZOO_SYNC_LIMIT: 5
      ZOO_MAX_CLIENT_CNXNS: 60
      # JVM 内存配置
      JAVA_OPTS: "-Xms512m -Xmx1024m -XX:+UseG1GC"
    extra_hosts:
      - "otter:10.10.20.11"
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

volumes:
  otter_zk_data:
    driver: local
  otter_zk_logs:
    driver: local

networks:
  otter:
    driver: bridge
    ipam:
      config:
        - subnet: 10.10.0.0/16
          gateway: 10.10.20.1
EOF
    
    echo "   ✓ 已创建 docker-compose-fixed.yml"
}

# 创建启动脚本
function create_startup_script() {
    echo "4. 创建启动脚本..."
    
    cat > start-otter.sh << 'EOF'
#!/bin/bash

# Otter 启动脚本

echo "=== 启动 Otter 服务 ==="

# 检查配置文件
if [ ! -f "config/manager/otter.properties" ]; then
    echo "错误: Manager 配置文件不存在，请先配置数据库连接"
    echo "请编辑 config/manager/otter.properties 文件"
    exit 1
fi

# 检查数据库配置
if grep -q "your-mysql-host" config/manager/otter.properties; then
    echo "警告: 请先配置数据库连接信息"
    echo "编辑 config/manager/otter.properties 文件，修改数据库连接配置"
    read -p "是否继续启动? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 停止现有容器
echo "停止现有容器..."
docker-compose down 2>/dev/null

# 清理旧的数据（可选）
read -p "是否清理 ZooKeeper 数据? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "清理 ZooKeeper 数据..."
    docker volume rm otterwong_otter_zk_data 2>/dev/null || true
    docker volume rm otterwong_otter_zk_logs 2>/dev/null || true
fi

# 启动服务
echo "启动 Otter 服务..."
if [ -f "docker-compose-fixed.yml" ]; then
    docker-compose -f docker-compose-fixed.yml up -d
else
    docker-compose -f docker-compose-1g.yml up -d
fi

# 等待服务启动
echo "等待服务启动..."
sleep 10

# 检查服务状态
echo "检查服务状态..."
docker-compose ps

echo ""
echo "=== 启动完成 ==="
echo "管理界面: http://localhost:8080"
echo "用户名/密码: admin/admin"
echo ""
echo "查看日志: docker-compose logs -f"
echo "诊断问题: bash scripts/diagnose.sh"
EOF
    
    chmod +x start-otter.sh
    echo "   ✓ 已创建 start-otter.sh 启动脚本"
}

# 主函数
function main() {
    echo "开始修复 ZooKeeper 配置问题..."
    echo ""
    
    fix_app_sh
    fix_docker_compose
    create_optimized_compose
    create_startup_script
    
    echo ""
    echo "=== 修复完成 ==="
    echo ""
    echo "修复内容:"
    echo "1. ✓ 修复了 app.sh 中的主机名配置问题"
    echo "2. ✓ 创建了优化的 docker-compose-fixed.yml 配置"
    echo "3. ✓ 创建了 start-otter.sh 启动脚本"
    echo "4. ✓ 添加了主机名解析检查"
    echo ""
    echo "使用方法:"
    echo "1. 配置数据库连接: 编辑 config/manager/otter.properties"
    echo "2. 启动服务: bash start-otter.sh"
    echo "3. 诊断问题: bash scripts/diagnose.sh"
    echo ""
    echo "注意事项:"
    echo "- 确保外部 MySQL 数据库已配置并可访问"
    echo "- 建议分配至少 2GB 内存给容器"
    echo "- 如果仍有问题，请运行诊断脚本获取详细信息"
}

# 运行修复
main