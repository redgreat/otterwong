#!/bin/bash

# Otter Docker 诊断脚本
# 用于排查 ZooKeeper、Manager 和 Node 启动问题

echo "=== Otter Docker 诊断脚本 ==="
echo "开始诊断..."
echo ""

# 检查容器状态
function check_container_status() {
    echo "1. 检查容器状态:"
    docker-compose ps
    echo ""
}

# 检查网络连接
function check_network() {
    echo "2. 检查网络配置:"
    docker network ls | grep otter
    echo ""
    
    echo "检查容器网络详情:"
    docker network inspect otterwong_otter 2>/dev/null || echo "网络 otterwong_otter 不存在"
    echo ""
}

# 检查 ZooKeeper 配置和日志
function check_zookeeper() {
    echo "3. 检查 ZooKeeper 配置和状态:"
    
    # 检查容器内的 ZooKeeper 配置
    echo "ZooKeeper 配置文件:"
    docker exec -it otter cat /home/admin/zookeeper-3.7.0/conf/zoo.cfg 2>/dev/null || echo "无法读取 zoo.cfg"
    echo ""
    
    echo "ZooKeeper myid:"
    docker exec -it otter cat /home/admin/zkData/myid 2>/dev/null || echo "无法读取 myid"
    echo ""
    
    echo "ZooKeeper 启动日志:"
    docker exec -it otter tail -20 /home/admin/zkData/zookeeper.log 2>/dev/null || echo "无法读取 ZooKeeper 日志"
    echo ""
    
    echo "ZooKeeper 进程状态:"
    docker exec -it otter ps aux | grep zookeeper | grep -v grep 2>/dev/null || echo "ZooKeeper 进程未运行"
    echo ""
    
    echo "ZooKeeper 端口监听:"
    docker exec -it otter netstat -tlnp | grep 2181 2>/dev/null || echo "端口 2181 未监听"
    echo ""
}

# 检查 Manager 状态
function check_manager() {
    echo "4. 检查 Manager 状态:"
    
    echo "Manager 启动日志:"
    docker exec -it otter tail -20 /tmp/start_manager.log 2>/dev/null || echo "无法读取 Manager 启动日志"
    echo ""
    
    echo "Manager 应用日志:"
    docker exec -it otter tail -20 /home/admin/manager/logs/manager.log 2>/dev/null || echo "无法读取 Manager 应用日志"
    echo ""
    
    echo "Manager 进程状态:"
    docker exec -it otter ps aux | grep manager | grep -v grep 2>/dev/null || echo "Manager 进程未运行"
    echo ""
    
    echo "Manager 端口监听:"
    docker exec -it otter netstat -tlnp | grep 8080 2>/dev/null || echo "端口 8080 未监听"
    echo ""
}

# 检查 Node 状态
function check_node() {
    echo "5. 检查 Node 状态:"
    
    echo "Node 启动日志:"
    docker exec -it otter tail -20 /tmp/start_node.log 2>/dev/null || echo "无法读取 Node 启动日志"
    echo ""
    
    echo "Node 应用日志:"
    docker exec -it otter tail -20 /home/admin/node/logs/node.log 2>/dev/null || echo "无法读取 Node 应用日志"
    echo ""
    
    echo "Node 进程状态:"
    docker exec -it otter ps aux | grep node | grep -v grep 2>/dev/null || echo "Node 进程未运行"
    echo ""
    
    echo "Node 端口监听:"
    docker exec -it otter netstat -tlnp | grep 2088 2>/dev/null || echo "端口 2088 未监听"
    echo ""
}

# 检查配置文件
function check_config() {
    echo "6. 检查配置文件:"
    
    echo "Manager 配置文件:"
    if [ -f "./config/manager/otter.properties" ]; then
        echo "数据库配置:"
        grep "otter.database" ./config/manager/otter.properties
        echo "ZooKeeper 配置:"
        grep "otter.zookeeper" ./config/manager/otter.properties
    else
        echo "Manager 配置文件不存在"
    fi
    echo ""
    
    echo "Node 配置文件:"
    if [ -f "./config/node/otter.properties" ]; then
        echo "ZooKeeper 配置:"
        grep "otter.zookeeper" ./config/node/otter.properties
        echo "Manager 配置:"
        grep "otter.manager" ./config/node/otter.properties
    else
        echo "Node 配置文件不存在"
    fi
    echo ""
}

# 检查环境变量
function check_environment() {
    echo "7. 检查环境变量:"
    docker exec -it otter env | grep -E "(ZOO_|RUN_MODE|MANAGER_)" 2>/dev/null || echo "无法读取环境变量"
    echo ""
}

# 提供解决建议
function provide_suggestions() {
    echo "=== 常见问题解决建议 ==="
    echo ""
    echo "1. ZooKeeper 启动失败:"
    echo "   - 检查容器内存是否足够（建议至少 1GB）"
    echo "   - 检查 ZOO_SERVERS 配置是否正确"
    echo "   - 检查主机名解析是否正常"
    echo ""
    echo "2. Manager 启动失败:"
    echo "   - 检查数据库连接配置是否正确"
    echo "   - 确保外部 MySQL 数据库可访问"
    echo "   - 检查数据库表是否已初始化"
    echo ""
    echo "3. Node 启动失败:"
    echo "   - 检查 ZooKeeper 是否正常运行"
    echo "   - 检查 Manager 地址配置是否正确"
    echo "   - 检查网络连接是否正常"
    echo ""
    echo "4. 网络问题:"
    echo "   - 检查 Docker 网络配置"
    echo "   - 确保容器间可以正常通信"
    echo "   - 检查防火墙设置"
    echo ""
}

# 主函数
function main() {
    check_container_status
    check_network
    check_zookeeper
    check_manager
    check_node
    check_config
    check_environment
    provide_suggestions
    
    echo "=== 诊断完成 ==="
    echo "如果问题仍未解决，请将以上输出信息提供给技术支持。"
}

# 检查是否在正确的目录
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose-1g.yml" ]; then
    echo "错误: 请在 otterwong 项目根目录下运行此脚本"
    exit 1
fi

# 运行诊断
main