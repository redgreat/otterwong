#!/bin/bash

# Otter 启动脚本
# 用于正确启动 Otter 服务并进行必要的检查

set -e

echo "=== Otter 启动脚本 ==="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查当前目录
function check_directory() {
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose-1g.yml" ]; then
        echo -e "${RED}错误: 请在 otterwong 项目根目录下运行此脚本${NC}"
        exit 1
    fi
}

# 检查配置文件
function check_config() {
    echo "1. 检查配置文件..."
    
    if [ ! -f "config/manager/otter.properties" ]; then
        echo -e "${RED}错误: Manager 配置文件不存在${NC}"
        echo "请先运行: tar -xzf docker/manager.deployer-4.2.19-SNAPSHOT.tar.gz -C config/manager --strip-components=2 manager/conf/"
        exit 1
    fi
    
    if [ ! -f "config/node/otter.properties" ]; then
        echo -e "${RED}错误: Node 配置文件不存在${NC}"
        echo "请先运行: tar -xzf docker/node.deployer-4.2.19-SNAPSHOT.tar.gz -C config/node --strip-components=2 node/conf/"
        exit 1
    fi
    
    # 检查数据库配置
    if grep -q "your-mysql-host" config/manager/otter.properties; then
        echo -e "${YELLOW}警告: 数据库连接配置使用默认占位符${NC}"
        echo "请编辑 config/manager/otter.properties 文件，配置正确的数据库连接信息"
        echo ""
        echo "需要修改的配置项:"
        echo "  otter.database.driver.url = jdbc:mysql://your-mysql-host:3306/otter"
        echo "  otter.database.driver.username = otter"
        echo "  otter.database.driver.password = otter_password"
        echo ""
        read -p "是否继续启动? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo -e "${GREEN}   ✓ 配置文件检查完成${NC}"
}

# 检查 Docker 环境
function check_docker() {
    echo "2. 检查 Docker 环境..."
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker 未安装或未在 PATH 中${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}错误: Docker Compose 未安装或未在 PATH 中${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}错误: Docker 服务未运行${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}   ✓ Docker 环境检查完成${NC}"
}

# 选择配置文件
function select_compose_file() {
    echo "3. 选择 Docker Compose 配置文件..."
    
    if [ -f "docker-compose-optimized.yml" ]; then
        COMPOSE_FILE="docker-compose-optimized.yml"
        echo -e "${GREEN}   使用优化配置: docker-compose-optimized.yml${NC}"
        echo "   - 包含网络优化配置"
        echo "   - 使用Docker默认桥接网络"
        echo "   - JVM内存优化"
    elif [ -f "docker-compose-1g.yml" ]; then
        COMPOSE_FILE="docker-compose-1g.yml"
        echo -e "${YELLOW}   使用 1GB 配置: docker-compose-1g.yml${NC}"
    else
        COMPOSE_FILE="docker-compose.yml"
        echo -e "${YELLOW}   使用默认配置: docker-compose.yml${NC}"
    fi
}

# 停止现有容器
function stop_existing() {
    echo "4. 停止现有容器..."
    
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # 清理孤立容器
    docker container prune -f 2>/dev/null || true
    
    echo -e "${GREEN}   ✓ 现有容器已停止${NC}"
}

# 清理数据（可选）
function cleanup_data() {
    echo "5. 数据清理选项..."
    
    read -p "是否清理 ZooKeeper 数据? 这将重置所有 ZooKeeper 状态 (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "清理 ZooKeeper 数据..."
        docker volume rm otterwong_otter_zk_data 2>/dev/null || true
        docker volume rm otterwong_otter_zk_logs 2>/dev/null || true
        echo -e "${GREEN}   ✓ ZooKeeper 数据已清理${NC}"
    fi
    
    read -p "是否清理应用日志? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "清理应用日志..."
        docker volume rm otterwong_otter_manager_logs 2>/dev/null || true
        docker volume rm otterwong_otter_node_logs 2>/dev/null || true
        echo -e "${GREEN}   ✓ 应用日志已清理${NC}"
    fi
}

# 启动服务
function start_services() {
    echo "6. 启动 Otter 服务..."
    
    echo "使用配置文件: $COMPOSE_FILE"
    docker-compose -f "$COMPOSE_FILE" up -d
    
    echo -e "${GREEN}   ✓ 服务启动命令已执行${NC}"
}

# 等待服务启动
function wait_for_services() {
    echo "7. 等待服务启动..."
    
    echo "等待 ZooKeeper 启动..."
    for i in {1..30}; do
        if docker exec otter nc -z localhost 2181 2>/dev/null; then
            echo -e "${GREEN}   ✓ ZooKeeper 已启动${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${YELLOW}   ⚠ ZooKeeper 启动超时，请检查日志${NC}"
        fi
        sleep 2
    done
    
    echo "等待 Manager 启动..."
    for i in {1..60}; do
        if docker exec otter nc -z localhost 8080 2>/dev/null; then
            echo -e "${GREEN}   ✓ Manager 已启动${NC}"
            break
        fi
        if [ $i -eq 60 ]; then
            echo -e "${YELLOW}   ⚠ Manager 启动超时，请检查日志${NC}"
        fi
        sleep 2
    done
    
    echo "等待 Node 启动..."
    for i in {1..30}; do
        if docker exec otter nc -z localhost 2088 2>/dev/null; then
            echo -e "${GREEN}   ✓ Node 已启动${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${YELLOW}   ⚠ Node 启动超时，请检查日志${NC}"
        fi
        sleep 2
    done
}

# 显示服务状态
function show_status() {
    echo "8. 服务状态检查..."
    
    echo ""
    echo "容器状态:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "端口监听状态:"
    docker exec otter netstat -tlnp 2>/dev/null | grep -E ":(2181|8080|2088)" || echo "部分端口未监听"
}

# 显示访问信息
function show_access_info() {
    echo ""
    echo "=== 启动完成 ==="
    echo ""
    echo -e "${GREEN}📋 服务访问信息:${NC}"
echo "   Manager Web界面: http://localhost:8080"
echo "   ZooKeeper Admin: http://localhost:8018"
echo "   Node监控端口: http://localhost:2088"
echo "   容器主机名: otter"
echo ""
echo -e "${GREEN}管理界面登录信息:${NC}"
echo "  用户名: admin"
echo "  密码: admin"
    echo ""
    echo -e "${GREEN}常用命令:${NC}"
    echo "  查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "  查看特定服务日志: docker-compose -f $COMPOSE_FILE logs -f otter"
    echo "  进入容器: docker exec -it otter /bin/bash"
    echo "  停止服务: docker-compose -f $COMPOSE_FILE down"
    echo "  诊断问题: bash scripts/diagnose.sh"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo "  - 如果服务启动失败，请运行诊断脚本获取详细信息"
    echo "  - 确保外部 MySQL 数据库已正确配置并可访问"
    echo "  - 首次启动可能需要较长时间，请耐心等待"
}

# 主函数
function main() {
    check_directory
    check_config
    check_docker
    select_compose_file
    stop_existing
    cleanup_data
    start_services
    wait_for_services
    show_status
    show_access_info
}

# 错误处理
trap 'echo -e "${RED}启动过程中发生错误，请检查上述输出信息${NC}"' ERR

# 运行主函数
main