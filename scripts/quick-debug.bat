@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM WSL Docker调试快速启动脚本
REM 双击即可运行，提供交互式菜单

title WSL Docker调试工具

REM 颜色代码
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "CYAN=[96m"
set "WHITE=[97m"
set "RESET=[0m"

echo.
echo %CYAN%=== WSL Docker调试工具 ===%RESET%
echo.

:MENU
echo %BLUE%请选择操作:%RESET%
echo.
echo %WHITE%1.%RESET% 完整重建并运行 (推荐)
echo %WHITE%2.%RESET% 仅构建镜像
echo %WHITE%3.%RESET% 仅运行容器
echo %WHITE%4.%RESET% 查看容器状态
echo %WHITE%5.%RESET% 查看容器日志
echo %WHITE%6.%RESET% 进入容器调试
echo %WHITE%7.%RESET% 监控服务健康状态
echo %WHITE%8.%RESET% 停止容器
echo %WHITE%9.%RESET% 清理容器和镜像
echo %WHITE%0.%RESET% 退出
echo.
echo %YELLOW%注意: 如果安装了多个WSL发行版，脚本会提示您选择Ubuntu发行版%RESET%
echo.
set /p choice=%YELLOW%请输入选项 (0-9): %RESET%

if "%choice%"=="1" goto REBUILD
if "%choice%"=="2" goto BUILD
if "%choice%"=="3" goto RUN
if "%choice%"=="4" goto STATUS
if "%choice%"=="5" goto LOGS
if "%choice%"=="6" goto ENTER
if "%choice%"=="7" goto MONITOR
if "%choice%"=="8" goto STOP
if "%choice%"=="9" goto CLEANUP
if "%choice%"=="0" goto EXIT

echo %RED%无效选项，请重新选择%RESET%
echo.
goto MENU

:REBUILD
echo.
echo %GREEN%开始完整重建并运行...%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" rebuild -KeepOpen
goto MENU

:BUILD
echo.
echo %GREEN%开始构建镜像...%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" build -KeepOpen
goto MENU

:RUN
echo.
echo %GREEN%开始运行容器...%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" run -KeepOpen
goto MENU

:STATUS
echo.
echo %GREEN%查看容器状态...%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" status -KeepOpen
goto MENU

:LOGS
echo.
echo %GREEN%查看容器日志...%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" logs -KeepOpen
goto MENU

:ENTER
echo.
echo %GREEN%进入容器调试...%RESET%
echo %YELLOW%注意: 这将打开一个新的交互式会话%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" enter -Interactive -KeepOpen
goto MENU

:MONITOR
echo.
echo %GREEN%监控服务健康状态...%RESET%
echo %YELLOW%注意: 这将持续监控，按Ctrl+C停止%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" monitor -KeepOpen
goto MENU

:STOP
echo.
echo %GREEN%停止容器...%RESET%
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" stop -KeepOpen
goto MENU

:CLEANUP
echo.
echo %YELLOW%警告: 这将删除所有相关的容器和镜像%RESET%
set /p confirm=%RED%确认清理? (y/N): %RESET%
if /i "%confirm%"=="y" (
    echo.
    echo %GREEN%开始清理...%RESET%
    echo.
    powershell -ExecutionPolicy Bypass -File "%~dp0wsl-debug-launcher.ps1" cleanup -KeepOpen
) else (
    echo %YELLOW%已取消清理操作%RESET%
)
goto MENU

:EXIT
echo.
echo %GREEN%感谢使用WSL Docker调试工具！%RESET%
echo.
pause
exit /b 0

:ERROR
echo.
echo %RED%发生错误，请检查系统环境%RESET%
echo.
echo %YELLOW%请确保:%RESET%
echo - WSL已安装并可用
echo - Docker Desktop已启动
echo - 项目文件完整
echo.
pause
exit /b 1