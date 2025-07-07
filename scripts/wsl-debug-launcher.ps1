# WSL Docker调试启动器
# 用于在Windows环境下启动WSL并执行Docker调试脚本

param(
    [Parameter(Position=0)]
    [ValidateSet('build', 'run', 'rebuild', 'status', 'logs', 'enter', 'monitor', 'stop', 'cleanup', 'help')]
    [string]$Action = 'help',
    
    [switch]$Interactive,
    [switch]$KeepOpen
)

# 全局变量：选定的WSL发行版
$script:SelectedDistro = $null

# 颜色定义
$Colors = @{
    Red = 'Red'
    Green = 'Green'
    Yellow = 'Yellow'
    Blue = 'Blue'
    Cyan = 'Cyan'
    White = 'White'
}

# 函数：打印带颜色的消息
function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [string]$Prefix = ''
    )
    
    if ($Prefix) {
        Write-Host "[$Prefix] " -ForegroundColor $Color -NoNewline
    }
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info { param([string]$Message) Write-ColorMessage $Message 'Blue' 'INFO' }
function Write-Success { param([string]$Message) Write-ColorMessage $Message 'Green' 'SUCCESS' }
function Write-Warning { param([string]$Message) Write-ColorMessage $Message 'Yellow' 'WARNING' }
function Write-Error { param([string]$Message) Write-ColorMessage $Message 'Red' 'ERROR' }

# 函数：检查WSL是否可用并选择Ubuntu发行版
function Test-WSLAvailable {
    Write-Info "检查WSL可用性..."
    
    try {
        $wslVersion = wsl --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL已安装并可用"
        }
    }
    catch {
        # 忽略错误，继续检查
    }
    
    # 列出所有WSL发行版
    try {
        $distributions = wsl -l -q 2>$null | Where-Object { $_ -and $_.Trim() }
        if ($LASTEXITCODE -eq 0 -and $distributions) {
            Write-Success "WSL发行版可用"
            Write-Info "检测到的发行版:"
            $distributions | ForEach-Object { Write-Host "  - $_" }
            
            # 过滤Ubuntu发行版，排除docker相关的发行版
            $ubuntuDistros = $distributions | Where-Object { 
                $_ -match "ubuntu" -and 
                $_ -notmatch "docker" -and 
                $_ -ne "" -and 
                $_ -ne $null 
            }
            
            if ($ubuntuDistros.Count -eq 0) {
                Write-Error "未找到Ubuntu发行版，请先安装Ubuntu WSL"
                return $false
            } elseif ($ubuntuDistros.Count -eq 1) {
                $script:SelectedDistro = $ubuntuDistros[0]
                Write-Success "自动选择Ubuntu发行版: $script:SelectedDistro"
            } else {
                Write-Info "检测到多个Ubuntu发行版:"
                for ($i = 0; $i -lt $ubuntuDistros.Count; $i++) {
                    Write-Host "  $($i + 1). $($ubuntuDistros[$i])"
                }
                
                do {
                    $choice = Read-Host "请选择Ubuntu发行版 (1-$($ubuntuDistros.Count))"
                    $choiceNum = [int]$choice - 1
                } while ($choiceNum -lt 0 -or $choiceNum -ge $ubuntuDistros.Count)
                
                $script:SelectedDistro = $ubuntuDistros[$choiceNum]
                Write-Success "已选择Ubuntu发行版: $script:SelectedDistro"
            }
            
            return $true
        }
    }
    catch {
        # 忽略错误
    }
    
    Write-Error "WSL不可用或未安装"
    Write-Info "请确保:"
    Write-Host "  1. 已启用WSL功能"
    Write-Host "  2. 已安装Ubuntu或其他Linux发行版"
    Write-Host "  3. WSL版本为2.0或更高"
    return $false
}

# 函数：检查Docker Desktop是否运行
function Test-DockerDesktop {
    Write-Info "检查Docker Desktop状态..."
    
    # 检查Docker Desktop进程
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    if (-not $dockerProcess) {
        Write-Warning "Docker Desktop进程未运行"
        Write-Info "尝试启动Docker Desktop..."
        
        # 尝试启动Docker Desktop
        $dockerPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath
            Write-Info "已启动Docker Desktop，等待初始化..."
            Start-Sleep -Seconds 10
        } else {
            Write-Error "未找到Docker Desktop，请手动安装并启动"
            return $false
        }
    } else {
        Write-Success "Docker Desktop正在运行"
    }
    
    # 在选定的WSL发行版中检查Docker是否可用
    Write-Info "检查WSL中的Docker可用性..."
    $dockerCheck = wsl -d $script:SelectedDistro bash -c "docker info >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'"
    
    if ($dockerCheck -eq "OK") {
        Write-Success "WSL中Docker可用"
        return $true
    } else {
        Write-Warning "WSL中Docker不可用，等待Docker Desktop完全启动..."
        
        # 等待Docker在WSL中可用
        $maxAttempts = 12
        $attempt = 1
        
        while ($attempt -le $maxAttempts) {
            Write-Info "等待Docker启动 (尝试 $attempt/$maxAttempts)..."
            Start-Sleep -Seconds 5
            
            $dockerCheck = wsl -d $script:SelectedDistro bash -c "docker info >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'"
            if ($dockerCheck -eq "OK") {
                Write-Success "Docker在WSL中已可用"
                return $true
            }
            
            $attempt++
        }
        
        Write-Error "Docker在WSL中仍不可用"
        Write-Info "请检查:"
        Write-Host "  1. Docker Desktop是否完全启动"
        Write-Host "  2. WSL集成是否已启用"
        Write-Host "  3. 在Docker Desktop设置中启用WSL集成"
        return $false
    }
}

# 函数：检查项目文件
function Test-ProjectFiles {
    Write-Info "检查项目文件..."
    
    $projectPath = "D:\github\otterwong"
    $scriptPath = "$projectPath\scripts\wsl-debug-run.sh"
    
    if (-not (Test-Path $projectPath)) {
        Write-Error "项目目录不存在: $projectPath"
        return $false
    }
    
    if (-not (Test-Path "$projectPath\Dockerfile")) {
        Write-Error "Dockerfile不存在"
        return $false
    }
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "WSL调试脚本不存在: $scriptPath"
        return $false
    }
    
    Write-Success "项目文件检查通过"
    return $true
}

# 函数：执行WSL调试脚本
function Invoke-WSLDebugScript {
    param([string]$Action)
    
    Write-Info "在WSL发行版 '$script:SelectedDistro' 中执行调试脚本..."
    
    # 转换Windows路径为WSL路径
    $wslScriptPath = "/mnt/d/github/otterwong/scripts/wsl-debug-run.sh"
    
    # 确保脚本有执行权限
    wsl -d $script:SelectedDistro chmod +x $wslScriptPath
    
    if ($Interactive) {
        Write-Info "以交互模式运行..."
        wsl -d $script:SelectedDistro bash $wslScriptPath $Action
    } else {
        Write-Info "执行操作: $Action"
        wsl -d $script:SelectedDistro bash $wslScriptPath $Action
    }
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Success "操作完成"
    } else {
        Write-Error "操作失败 (退出码: $exitCode)"
    }
    
    return $exitCode
}

# 函数：显示帮助信息
function Show-Help {
    Write-Host ""
    Write-ColorMessage "WSL Docker调试启动器" 'Cyan'
    Write-Host ""
    Write-Host "用法: .\wsl-debug-launcher.ps1 [操作] [选项]"
    Write-Host ""
    Write-Host "操作:"
    Write-Host "  build     - 构建Docker镜像"
    Write-Host "  run       - 运行容器"
    Write-Host "  rebuild   - 清理并重新构建运行"
    Write-Host "  status    - 显示容器状态"
    Write-Host "  logs      - 显示容器日志"
    Write-Host "  enter     - 进入容器调试"
    Write-Host "  monitor   - 监控容器健康状态"
    Write-Host "  stop      - 停止容器"
    Write-Host "  cleanup   - 清理容器和镜像"
    Write-Host "  help      - 显示此帮助信息"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Interactive  - 交互模式运行"
    Write-Host "  -KeepOpen    - 执行完成后保持窗口打开"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\wsl-debug-launcher.ps1 rebuild"
    Write-Host "  .\wsl-debug-launcher.ps1 logs -KeepOpen"
    Write-Host "  .\wsl-debug-launcher.ps1 enter -Interactive"
    Write-Host ""
    Write-Host "快速访问:"
    Write-Host "  Manager Web UI: http://localhost:8080"
    Write-Host "  ZooKeeper Admin: http://localhost:8018"
    Write-Host ""
}

# 函数：显示系统信息
function Show-SystemInfo {
    Write-Info "系统环境信息:"
    
    # Windows版本
    $windowsVersion = (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
    Write-Host "  Windows: $windowsVersion"
    
    # WSL版本和选定的发行版
    try {
        $wslVersion = wsl --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  WSL: 已安装"
            if ($script:SelectedDistro) {
                Write-Host "  选定的发行版: $script:SelectedDistro"
            }
        }
    }
    catch {
        Write-Host "  WSL: 未安装或不可用"
    }
    
    # Docker Desktop状态
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    if ($dockerProcess) {
        Write-Host "  Docker Desktop: 运行中"
    } else {
        Write-Host "  Docker Desktop: 未运行"
    }
    
    Write-Host ""
}

# 主函数
function Main {
    Write-Host ""
    Write-ColorMessage "=== WSL Docker调试启动器 ===" 'Cyan'
    Write-Host ""
    
    if ($Action -eq 'help') {
        Show-Help
        return
    }
    
    # 首先选择WSL发行版
    if (-not (Test-WSLAvailable)) {
        Write-Error "WSL检查失败"
        return 1
    }
    
    # 显示系统信息
    Show-SystemInfo
    
    if (-not (Test-DockerDesktop)) {
        Write-Error "Docker检查失败"
        return 1
    }
    
    if (-not (Test-ProjectFiles)) {
        Write-Error "项目文件检查失败"
        return 1
    }
    
    # 执行调试脚本
    $exitCode = Invoke-WSLDebugScript $Action
    
    if ($Action -eq 'rebuild' -or $Action -eq 'run') {
        Write-Host ""
        Write-Success "容器已启动，可以通过以下方式访问:"
        Write-Host "  Manager Web UI: " -NoNewline
        Write-ColorMessage "http://localhost:8080" 'Cyan'
        Write-Host "  ZooKeeper Admin: " -NoNewline  
        Write-ColorMessage "http://localhost:8018" 'Cyan'
        Write-Host ""
        Write-Info "使用以下命令查看日志:"
        Write-Host "  .\wsl-debug-launcher.ps1 logs"
        Write-Host ""
        Write-Info "使用以下命令进入容器调试:"
        Write-Host "  .\wsl-debug-launcher.ps1 enter"
    }
    
    return $exitCode
}

# 执行主函数
try {
    $exitCode = Main
    
    if ($KeepOpen) {
        Write-Host ""
        Write-Info "按任意键退出..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    exit $exitCode
}
catch {
    Write-Error "执行过程中发生错误: $($_.Exception.Message)"
    
    if ($KeepOpen) {
        Write-Host ""
        Write-Info "按任意键退出..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    exit 1
}