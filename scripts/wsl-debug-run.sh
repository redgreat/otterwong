#!/bin/bash
# WSL Ubuntu环境下的Docker调试运行脚本
# 用于在WSL中构建、运行和调试Otter容器

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="otter"
IMAGE_NAME="otter:latest"
CONTAINER_NAME="otter-debug"
PROJECT_DIR="/mnt/d/github/otterwong"

# 函数：打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 函数：检查Docker是否运行
check_docker() {
    print_info "检查Docker服务状态..."
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker未运行或无法访问"
        print_info "请确保Docker Desktop已启动并在WSL中可用"
        exit 1
    fi
    print_success "Docker服务正常"
}

# 函数：检查项目目录
check_project_dir() {
    print_info "检查项目目录..."
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
        print_error "Dockerfile不存在: $PROJECT_DIR/Dockerfile"
        exit 1
    fi
    
    print_success "项目目录检查通过"
}

# 函数：清理现有容器和镜像
cleanup() {
    print_info "清理现有容器和镜像..."
    
    # 停止并删除现有容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_info "停止现有容器: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # 删除现有镜像
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
        print_info "删除现有镜像: $IMAGE_NAME"
        docker rmi "$IMAGE_NAME" >/dev/null 2>&1 || true
    fi
    
    # 清理构建缓存
    print_info "清理Docker构建缓存..."
    docker builder prune -f >/dev/null 2>&1 || true
    
    print_success "清理完成"
}

# 函数：构建Docker镜像
build_image() {
    print_info "开始构建Docker镜像..."
    
    cd "$PROJECT_DIR"
    
    # 显示构建信息
    print_info "构建配置:"
    echo "  - 项目目录: $PROJECT_DIR"
    echo "  - 镜像名称: $IMAGE_NAME"
    echo "  - 容器名称: $CONTAINER_NAME"
    
    # 构建镜像
    if docker build -t "$IMAGE_NAME" . --no-cache; then
        print_success "镜像构建成功"
    else
        print_error "镜像构建失败"
        exit 1
    fi
}

# 函数：运行容器
run_container() {
    print_info "启动调试容器..."
    
    # 运行容器（交互模式，用于调试）
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p 8080:8080 \
        -p 2181:2181 \
        -p 8018:8018 \
        -p 2088:2088 \
        -e RUN_MODE=ALL \
        -e MYSQL_USER=root \
        -e MYSQL_USER_PASSWORD=123456 \
        -e OTTER_MANAGER_MYSQL=127.0.0.1:3306 \
        -e MANAGER_ADD=127.0.0.1 \
        -e ZOO_CLUSTER=127.0.0.1:2181 \
        "$IMAGE_NAME"
    
    if [ $? -eq 0 ]; then
        print_success "容器启动成功"
        print_info "容器名称: $CONTAINER_NAME"
        print_info "端口映射:"
        echo "  - Manager Web UI: http://localhost:8080"
        echo "  - ZooKeeper: localhost:2181"
        echo "  - ZooKeeper Admin: http://localhost:8018"
        echo "  - Node: localhost:2088"
    else
        print_error "容器启动失败"
        exit 1
    fi
}

# 函数：显示容器状态
show_status() {
    print_info "容器状态信息:"
    
    # 显示容器状态
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME"; then
        print_success "容器正在运行"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
    else
        print_warning "容器未运行"
        if docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "$CONTAINER_NAME"; then
            print_info "容器存在但已停止:"
            docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep "$CONTAINER_NAME"
        fi
    fi
}

# 函数：显示容器日志
show_logs() {
    print_info "显示容器日志 (最近50行):"
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker logs --tail 50 "$CONTAINER_NAME"
    else
        print_warning "容器未运行，无法显示日志"
    fi
}

# 函数：进入容器调试
enter_container() {
    print_info "进入容器进行调试..."
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_info "使用以下命令进入容器:"
        echo "docker exec -it $CONTAINER_NAME /bin/bash"
        print_info "或者直接执行:"
        docker exec -it "$CONTAINER_NAME" /bin/bash
    else
        print_warning "容器未运行，无法进入"
        print_info "请先启动容器"
    fi
}

# 函数：监控容器健康状态
monitor_health() {
    print_info "监控容器健康状态..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            print_info "检查服务状态 (尝试 $attempt/$max_attempts)..."
            
            # 检查ZooKeeper
            if nc -z localhost 2181 2>/dev/null; then
                print_success "ZooKeeper (2181) - 正常"
            else
                print_warning "ZooKeeper (2181) - 未就绪"
            fi
            
            # 检查Manager Web UI
            if nc -z localhost 8080 2>/dev/null; then
                print_success "Manager Web UI (8080) - 正常"
            else
                print_warning "Manager Web UI (8080) - 未就绪"
            fi
            
            # 检查Node
            if nc -z localhost 2088 2>/dev/null; then
                print_success "Node (2088) - 正常"
            else
                print_warning "Node (2088) - 未就绪"
            fi
            
            # 检查ZooKeeper Admin
            if nc -z localhost 8018 2>/dev/null; then
                print_success "ZooKeeper Admin (8018) - 正常"
            else
                print_warning "ZooKeeper Admin (8018) - 未就绪"
            fi
            
            echo "---"
            sleep 5
            attempt=$((attempt + 1))
        else
            print_error "容器已停止运行"
            break
        fi
    done
}

# 函数：显示帮助信息
show_help() {
    echo "WSL Ubuntu Docker调试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  build     - 构建Docker镜像"
    echo "  run       - 运行容器"
    echo "  rebuild   - 清理并重新构建运行"
    echo "  status    - 显示容器状态"
    echo "  logs      - 显示容器日志"
    echo "  enter     - 进入容器调试"
    echo "  monitor   - 监控容器健康状态"
    echo "  stop      - 停止容器"
    echo "  cleanup   - 清理容器和镜像"
    echo "  help      - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 rebuild    # 完整重建并运行"
    echo "  $0 logs       # 查看日志"
    echo "  $0 enter      # 进入容器调试"
}

# 函数：停止容器
stop_container() {
    print_info "停止容器..."
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "$CONTAINER_NAME"
        print_success "容器已停止"
    else
        print_warning "容器未运行"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        "build")
            check_docker
            check_project_dir
            build_image
            ;;
        "run")
            check_docker
            run_container
            show_status
            ;;
        "rebuild")
            check_docker
            check_project_dir
            cleanup
            build_image
            run_container
            show_status
            print_info "等待服务启动..."
            sleep 10
            monitor_health
            ;;
        "status")
            check_docker
            show_status
            ;;
        "logs")
            check_docker
            show_logs
            ;;
        "enter")
            check_docker
            enter_container
            ;;
        "monitor")
            check_docker
            monitor_health
            ;;
        "stop")
            check_docker
            stop_container
            ;;
        "cleanup")
            check_docker
            cleanup
            ;;
        "help")
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 检查是否在WSL环境中
if ! grep -q microsoft /proc/version 2>/dev/null; then
    print_warning "此脚本设计用于WSL环境"
fi

# 执行主函数
main "$@"