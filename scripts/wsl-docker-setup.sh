#!/bin/bash
# WSL Ubuntu Docker安装和Otter镜像构建脚本
# 用于在WSL Ubuntu环境中安装Docker并构建Otter项目镜像

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在WSL环境中运行
check_wsl_environment() {
    log_info "检查WSL环境..."
    
    if ! grep -q "microsoft" /proc/version 2>/dev/null; then
        log_error "此脚本需要在WSL环境中运行"
        exit 1
    fi
    
    log_success "WSL环境检查通过"
}

# 更新系统包
update_system() {
    log_info "更新系统包..."
    
    # 更新包列表
    if ! sudo apt update; then
        log_error "包列表更新失败"
        return 1
    fi
    
    # 在WSL环境中，某些系统包升级可能会失败，我们需要更谨慎的处理
    log_info "升级系统包（跳过可能有问题的包）..."
    
    # 先尝试升级，如果失败则跳过有问题的包
    if ! sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y; then
        log_warning "系统包升级遇到问题，尝试跳过有问题的包..."
        
        # 标记保持有问题的包，然后升级其他包
        sudo apt-mark hold libc6 libc6-dev libc-bin 2>/dev/null || true
        
        if sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y; then
            log_success "系统包升级完成（跳过了一些有问题的包）"
            log_warning "某些系统包被保持在当前版本以避免WSL兼容性问题"
        else
            log_warning "系统包升级失败，但这不会影响Docker安装"
        fi
        
        # 取消保持标记
        sudo apt-mark unhold libc6 libc6-dev libc-bin 2>/dev/null || true
    else
        log_success "系统包更新完成"
    fi
}

# 等待apt锁释放
wait_for_apt_lock() {
    local max_wait=300  # 最多等待5分钟
    local wait_time=0
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        if [ $wait_time -ge $max_wait ]; then
            log_error "等待apt锁释放超时"
            return 1
        fi
        
        log_info "等待apt锁释放... ($wait_time/$max_wait 秒)"
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    return 0
}

# 安装必要的依赖
install_dependencies() {
    log_info "安装必要的依赖包..."
    
    # 等待apt锁释放
    if ! wait_for_apt_lock; then
        log_error "无法获取apt锁，请稍后重试"
        return 1
    fi
    
    # 安装依赖包
    if sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
        unzip; then
        log_success "依赖包安装完成"
    else
        log_error "依赖包安装失败"
        return 1
    fi
}

# 安装Docker
install_docker() {
    log_info "安装Docker..."
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        log_warning "Docker已安装，跳过安装步骤"
        return 0
    fi
    
    # 添加Docker官方GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 添加Docker仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包索引
    sudo apt update
    
    # 安装Docker Engine
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # 将当前用户添加到docker组
    sudo usermod -aG docker $USER
    
    log_success "Docker安装完成"
    log_warning "请重新登录或运行 'newgrp docker' 以使用户组更改生效"
}

# 启动Docker服务
start_docker_service() {
    log_info "启动Docker服务..."
    
    # 在WSL中，通常需要手动启动Docker
    if ! sudo service docker status &> /dev/null; then
        sudo service docker start
    fi
    
    # 等待Docker服务启动
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker info &> /dev/null; then
            log_success "Docker服务已启动"
            return 0
        fi
        
        log_info "等待Docker服务启动... (尝试 $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Docker服务启动失败"
    return 1
}

# 验证Docker安装
verify_docker_installation() {
    log_info "验证Docker安装..."
    
    # 检查Docker版本
    docker --version
    docker compose version
    
    # 运行测试容器
    if docker run --rm hello-world &> /dev/null; then
        log_success "Docker安装验证成功"
    else
        log_error "Docker安装验证失败"
        return 1
    fi
}

# 设置项目目录
setup_project_directory() {
    log_info "设置项目目录..."
    
    # 检查项目目录是否存在
    local project_dir="/mnt/d/github/otterwong"
    
    if [ ! -d "$project_dir" ]; then
        log_error "项目目录不存在: $project_dir"
        log_info "请确保项目已克隆到 D:\\github\\otterwong"
        return 1
    fi
    
    cd "$project_dir"
    log_success "已切换到项目目录: $(pwd)"
}

# 构建Otter Docker镜像
build_otter_image() {
    log_info "构建Otter Docker镜像..."
    
    # 检查Dockerfile是否存在
    if [ ! -f "Dockerfile" ]; then
        log_error "Dockerfile不存在"
        return 1
    fi
    
    # 构建镜像
    log_info "开始构建镜像，这可能需要几分钟..."
    
    if docker build -t otter:latest .; then
        log_success "Otter镜像构建成功"
    else
        log_error "Otter镜像构建失败"
        return 1
    fi
}

# 验证镜像构建
verify_image_build() {
    log_info "验证镜像构建..."
    
    # 检查镜像是否存在
    if docker images | grep -q "otter"; then
        log_success "Otter镜像验证成功"
        docker images | grep otter
    else
        log_error "Otter镜像验证失败"
        return 1
    fi
}

# 运行Otter容器
run_otter_container() {
    log_info "运行Otter容器..."
    
    # 停止现有容器（如果存在）
    if docker ps -a | grep -q "otter-container"; then
        log_info "停止现有容器..."
        docker stop otter-container 2>/dev/null || true
        docker rm otter-container 2>/dev/null || true
    fi
    
    # 运行新容器
    docker run -d \
        --name otter-container \
        -p 8080:8080 \
        -p 9092:9092 \
        -p 2181:2181 \
        otter:latest
    
    log_success "Otter容器已启动"
    log_info "容器名称: otter-container"
    log_info "Web界面: http://localhost:8080"
    log_info "ZooKeeper: localhost:2181"
}

# 显示容器状态
show_container_status() {
    log_info "容器状态:"
    docker ps -a | grep otter || log_warning "未找到Otter容器"
    
    log_info "\n镜像列表:"
    docker images | grep otter || log_warning "未找到Otter镜像"
}

# 显示日志
show_container_logs() {
    log_info "显示容器日志..."
    
    if docker ps | grep -q "otter-container"; then
        docker logs --tail 50 otter-container
    else
        log_warning "Otter容器未运行"
    fi
}

# 进入容器调试
enter_container() {
    log_info "进入容器调试模式..."
    
    if docker ps | grep -q "otter-container"; then
        docker exec -it otter-container /bin/bash
    else
        log_warning "Otter容器未运行"
    fi
}

# 清理资源
cleanup_resources() {
    log_info "清理Docker资源..."
    
    # 停止并删除容器
    docker stop otter-container 2>/dev/null || true
    docker rm otter-container 2>/dev/null || true
    
    # 删除镜像
    docker rmi otter:latest 2>/dev/null || true
    
    # 清理未使用的资源
    docker system prune -f
    
    log_success "资源清理完成"
}

# 显示帮助信息
show_help() {
    echo "Otter WSL Docker 安装和管理脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  install     - 完整安装Docker并构建Otter镜像"
    echo "  build       - 仅构建Otter镜像"
    echo "  run         - 运行Otter容器"
    echo "  status      - 显示容器状态"
    echo "  logs        - 显示容器日志"
    echo "  enter       - 进入容器调试"
    echo "  cleanup     - 清理所有资源"
    echo "  help        - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 install   # 完整安装"
    echo "  $0 build     # 仅构建镜像"
    echo "  $0 run       # 运行容器"
}

# 完整安装流程
full_install() {
    log_info "开始完整安装流程..."
    
    # 检查WSL环境
    if ! check_wsl_environment; then
        log_error "WSL环境检查失败，安装终止"
        exit 1
    fi
    
    # 更新系统（允许失败，不影响后续安装）
    if ! update_system; then
        log_warning "系统更新失败，但继续安装过程"
    fi
    
    # 安装依赖
    if ! install_dependencies; then
        log_error "依赖安装失败，安装终止"
        exit 1
    fi
    
    # 安装Docker
    if ! install_docker; then
        log_error "Docker安装失败，安装终止"
        exit 1
    fi
    
    # 启动Docker服务
    if ! start_docker_service; then
        log_error "Docker服务启动失败，安装终止"
        exit 1
    fi
    
    # 验证Docker安装
    if ! verify_docker_installation; then
        log_error "Docker验证失败，安装终止"
        exit 1
    fi
    
    # 设置项目目录
    if ! setup_project_directory; then
        log_error "项目目录设置失败，安装终止"
        exit 1
    fi
    
    # 构建镜像
    if ! build_otter_image; then
        log_error "镜像构建失败，安装终止"
        exit 1
    fi
    
    # 验证镜像
    if ! verify_image_build; then
        log_error "镜像验证失败，安装终止"
        exit 1
    fi
    
    # 运行容器
    if ! run_otter_container; then
        log_error "容器启动失败，但Docker和镜像已安装成功"
        log_info "您可以稍后使用 '$0 run' 命令启动容器"
    else
        show_container_status
        
        log_success "完整安装流程完成！"
        log_info "\n访问地址:"
        log_info "  Web界面: http://localhost:8080"
        log_info "  ZooKeeper: localhost:2181"
    fi
    
    log_info "\n常用命令:"
    log_info "  查看状态: $0 status"
    log_info "  查看日志: $0 logs"
    log_info "  进入容器: $0 enter"
    log_info "  重新运行: $0 run"
}

# 主函数
main() {
    case "${1:-install}" in
        "install")
            full_install
            ;;
        "build")
            check_wsl_environment
            start_docker_service
            setup_project_directory
            build_otter_image
            verify_image_build
            ;;
        "run")
            check_wsl_environment
            start_docker_service
            setup_project_directory
            run_otter_container
            show_container_status
            ;;
        "status")
            show_container_status
            ;;
        "logs")
            show_container_logs
            ;;
        "enter")
            enter_container
            ;;
        "cleanup")
            cleanup_resources
            ;;
        "help")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"