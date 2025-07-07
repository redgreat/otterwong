# Otter项目持续质量监控脚本
# 用于自动化监控代码质量、性能和安全性指标

param(
    [string]$ReportPath = "./quality-reports",
    [string]$ConfigFile = "./scripts/quality-config.json",
    [switch]$Continuous,
    [int]$IntervalMinutes = 30,
    [switch]$EmailReport,
    [string]$EmailTo = "",
    [switch]$Verbose
)

# 颜色定义
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
}

# 日志函数
function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = $Colors[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    # 写入日志文件
    $logFile = Join-Path $ReportPath "quality-monitor.log"
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $logFile -Append
}

# 创建报告目录
function Initialize-ReportDirectory {
    if (-not (Test-Path $ReportPath)) {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
        Write-Log "创建报告目录: $ReportPath" "Info"
    }
}

# 加载配置文件
function Get-QualityConfig {
    $defaultConfig = @{
        thresholds = @{
            codeComplexity = 10
            duplicateLines = 5
            testCoverage = 80
            buildTime = 300
            imageSize = 500
        }
        checks = @{
            security = $true
            performance = $true
            documentation = $true
            dependencies = $true
        }
        notifications = @{
            email = $false
            webhook = ""
        }
    }
    
    if (Test-Path $ConfigFile) {
        try {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            Write-Log "加载配置文件: $ConfigFile" "Info"
            return $config
        }
        catch {
            Write-Log "配置文件格式错误，使用默认配置" "Warning"
        }
    }
    
    # 创建默认配置文件
    $defaultConfig | ConvertTo-Json -Depth 3 | Out-File $ConfigFile
    Write-Log "创建默认配置文件: $ConfigFile" "Info"
    
    return $defaultConfig
}

# 代码复杂度检查
function Test-CodeComplexity {
    param($Config)
    
    Write-Log "检查代码复杂度..." "Info"
    
    $complexityReport = @{
        timestamp = Get-Date
        files = @()
        averageComplexity = 0
        maxComplexity = 0
        violations = 0
    }
    
    # 检查Java文件
    $javaFiles = Get-ChildItem -Path "." -Filter "*.java" -Recurse
    
    foreach ($file in $javaFiles) {
        $content = Get-Content $file.FullName
        $complexity = 1 # 基础复杂度
        
        # 简单的复杂度计算（基于控制流语句）
        $controlStatements = @('if', 'else', 'while', 'for', 'switch', 'case', 'catch', 'finally')
        foreach ($line in $content) {
            foreach ($statement in $controlStatements) {
                if ($line -match "\b$statement\b") {
                    $complexity++
                }
            }
        }
        
        $fileInfo = @{
            path = $file.FullName
            complexity = $complexity
            lines = $content.Count
        }
        
        $complexityReport.files += $fileInfo
        
        if ($complexity -gt $Config.thresholds.codeComplexity) {
            $complexityReport.violations++
            Write-Log "高复杂度文件: $($file.Name) (复杂度: $complexity)" "Warning"
        }
    }
    
    if ($complexityReport.files.Count -gt 0) {
        $complexityReport.averageComplexity = ($complexityReport.files | Measure-Object -Property complexity -Average).Average
        $complexityReport.maxComplexity = ($complexityReport.files | Measure-Object -Property complexity -Maximum).Maximum
    }
    
    return $complexityReport
}

# 重复代码检查
function Test-CodeDuplication {
    param($Config)
    
    Write-Log "检查代码重复..." "Info"
    
    $duplicationReport = @{
        timestamp = Get-Date
        duplicates = @()
        totalDuplicateLines = 0
        violations = 0
    }
    
    # 简单的重复代码检测
    $allFiles = Get-ChildItem -Path "." -Include "*.java", "*.js", "*.py" -Recurse
    $lineHashes = @{}
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName
        for ($i = 0; $i -lt $content.Count; $i++) {
            $line = $content[$i].Trim()
            if ($line.Length -gt 10 -and $line -notmatch "^\s*//" -and $line -notmatch "^\s*\*") {
                $hash = $line.GetHashCode()
                if ($lineHashes.ContainsKey($hash)) {
                    $lineHashes[$hash] += @(@{
                        file = $file.FullName
                        lineNumber = $i + 1
                        content = $line
                    })
                } else {
                    $lineHashes[$hash] = @(@{
                        file = $file.FullName
                        lineNumber = $i + 1
                        content = $line
                    })
                }
            }
        }
    }
    
    # 查找重复行
    foreach ($hash in $lineHashes.Keys) {
        if ($lineHashes[$hash].Count -gt 1) {
            $duplicationReport.duplicates += @{
                content = $lineHashes[$hash][0].content
                occurrences = $lineHashes[$hash]
                count = $lineHashes[$hash].Count
            }
            $duplicationReport.totalDuplicateLines += $lineHashes[$hash].Count
        }
    }
    
    if ($duplicationReport.totalDuplicateLines -gt $Config.thresholds.duplicateLines) {
        $duplicationReport.violations = 1
        Write-Log "发现 $($duplicationReport.totalDuplicateLines) 行重复代码" "Warning"
    }
    
    return $duplicationReport
}

# Docker镜像大小检查
function Test-DockerImageSize {
    param($Config)
    
    Write-Log "检查Docker镜像大小..." "Info"
    
    $imageSizeReport = @{
        timestamp = Get-Date
        images = @()
        violations = 0
    }
    
    try {
        # 检查本地Docker镜像
        $images = docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | Select-Object -Skip 1
        
        foreach ($imageInfo in $images) {
            if ($imageInfo -match "otter") {
                $parts = $imageInfo -split "\s+"
                $imageName = $parts[0]
                $sizeStr = $parts[1]
                
                # 解析大小（简化处理）
                $sizeValue = 0
                if ($sizeStr -match "(\d+(?:\.\d+)?)([KMGT]?B)") {
                    $number = [float]$matches[1]
                    $unit = $matches[2]
                    
                    switch ($unit) {
                        "KB" { $sizeValue = $number / 1024 }
                        "MB" { $sizeValue = $number }
                        "GB" { $sizeValue = $number * 1024 }
                        "TB" { $sizeValue = $number * 1024 * 1024 }
                        default { $sizeValue = $number / (1024 * 1024) }
                    }
                }
                
                $imageReport = @{
                    name = $imageName
                    size = $sizeStr
                    sizeMB = $sizeValue
                }
                
                $imageSizeReport.images += $imageReport
                
                if ($sizeValue -gt $Config.thresholds.imageSize) {
                    $imageSizeReport.violations++
                    Write-Log "镜像过大: $imageName ($sizeStr)" "Warning"
                }
            }
        }
    }
    catch {
        Write-Log "无法检查Docker镜像大小: $($_.Exception.Message)" "Warning"
    }
    
    return $imageSizeReport
}

# 安全漏洞检查
function Test-SecurityVulnerabilities {
    param($Config)
    
    Write-Log "检查安全漏洞..." "Info"
    
    $securityReport = @{
        timestamp = Get-Date
        vulnerabilities = @()
        riskLevel = "Low"
        violations = 0
    }
    
    # 检查常见的安全问题
    $securityPatterns = @{
        "硬编码密码" = @("password\s*=\s*['\"]\w+['\"]")
        "SQL注入风险" = @("\+.*\+.*sql", "String.*sql.*\+")
        "XSS风险" = @("innerHTML\s*=", "document\.write")
        "不安全的随机数" = @("Math\.random\(\)", "Random\(\)")
    }
    
    $allFiles = Get-ChildItem -Path "." -Include "*.java", "*.js", "*.py", "*.php" -Recurse
    
    foreach ($file in $allFiles) {
        $content = Get-Content $file.FullName -Raw
        
        foreach ($riskType in $securityPatterns.Keys) {
            foreach ($pattern in $securityPatterns[$riskType]) {
                if ($content -match $pattern) {
                    $vulnerability = @{
                        file = $file.FullName
                        type = $riskType
                        pattern = $pattern
                        severity = "Medium"
                    }
                    
                    $securityReport.vulnerabilities += $vulnerability
                    $securityReport.violations++
                    Write-Log "安全风险: $riskType 在文件 $($file.Name)" "Warning"
                }
            }
        }
    }
    
    if ($securityReport.violations -gt 0) {
        $securityReport.riskLevel = "Medium"
    }
    if ($securityReport.violations -gt 5) {
        $securityReport.riskLevel = "High"
    }
    
    return $securityReport
}

# 依赖项检查
function Test-Dependencies {
    param($Config)
    
    Write-Log "检查依赖项..." "Info"
    
    $dependencyReport = @{
        timestamp = Get-Date
        outdated = @()
        vulnerable = @()
        violations = 0
    }
    
    # 检查Maven依赖（如果存在pom.xml）
    if (Test-Path "pom.xml") {
        try {
            # 这里可以集成Maven依赖检查工具
            Write-Log "检测到Maven项目，建议运行: mvn dependency:analyze" "Info"
        }
        catch {
            Write-Log "Maven依赖检查失败" "Warning"
        }
    }
    
    # 检查package.json（如果存在）
    if (Test-Path "package.json") {
        try {
            # 这里可以集成npm audit
            Write-Log "检测到Node.js项目，建议运行: npm audit" "Info"
        }
        catch {
            Write-Log "npm依赖检查失败" "Warning"
        }
    }
    
    return $dependencyReport
}

# 性能指标检查
function Test-PerformanceMetrics {
    param($Config)
    
    Write-Log "检查性能指标..." "Info"
    
    $performanceReport = @{
        timestamp = Get-Date
        buildTime = 0
        testTime = 0
        violations = 0
    }
    
    # 模拟构建时间检查
    $buildStart = Get-Date
    
    try {
        # 这里可以集成实际的构建时间测量
        Start-Sleep -Seconds 1 # 模拟构建
        $buildEnd = Get-Date
        $performanceReport.buildTime = ($buildEnd - $buildStart).TotalSeconds
        
        if ($performanceReport.buildTime -gt $Config.thresholds.buildTime) {
            $performanceReport.violations++
            Write-Log "构建时间过长: $($performanceReport.buildTime) 秒" "Warning"
        }
    }
    catch {
        Write-Log "性能指标检查失败" "Warning"
    }
    
    return $performanceReport
}

# 生成质量报告
function New-QualityReport {
    param($Reports, $Config)
    
    $reportData = @{
        timestamp = Get-Date
        summary = @{
            totalViolations = 0
            riskLevel = "Low"
            score = 100
        }
        reports = $Reports
        recommendations = @()
    }
    
    # 计算总违规数
    foreach ($report in $Reports.Values) {
        if ($report.violations) {
            $reportData.summary.totalViolations += $report.violations
        }
    }
    
    # 计算质量分数
    $score = 100
    $score -= $reportData.summary.totalViolations * 5
    $score = [Math]::Max(0, $score)
    $reportData.summary.score = $score
    
    # 确定风险等级
    if ($reportData.summary.totalViolations -gt 10) {
        $reportData.summary.riskLevel = "High"
    } elseif ($reportData.summary.totalViolations -gt 5) {
        $reportData.summary.riskLevel = "Medium"
    }
    
    # 生成建议
    if ($Reports.complexity.violations -gt 0) {
        $reportData.recommendations += "建议重构高复杂度的代码文件"
    }
    if ($Reports.duplication.violations -gt 0) {
        $reportData.recommendations += "建议提取重复代码到公共方法"
    }
    if ($Reports.security.violations -gt 0) {
        $reportData.recommendations += "建议修复安全漏洞"
    }
    if ($Reports.imageSize.violations -gt 0) {
        $reportData.recommendations += "建议优化Docker镜像大小"
    }
    
    return $reportData
}

# 保存报告
function Save-QualityReport {
    param($ReportData)
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # 保存JSON格式报告
    $jsonFile = Join-Path $ReportPath "quality-report-$timestamp.json"
    $ReportData | ConvertTo-Json -Depth 5 | Out-File $jsonFile
    
    # 生成HTML报告
    $htmlFile = Join-Path $ReportPath "quality-report-$timestamp.html"
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Otter项目质量报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { background: #e8f5e8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .warning { background: #fff3cd; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .error { background: #f8d7da; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f8f9fa; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Otter项目质量报告</h1>
        <p>生成时间: $($ReportData.timestamp)</p>
    </div>
    
    <div class="summary">
        <h2>质量概览</h2>
        <div class="metric">质量分数: $($ReportData.summary.score)/100</div>
        <div class="metric">风险等级: $($ReportData.summary.riskLevel)</div>
        <div class="metric">总违规数: $($ReportData.summary.totalViolations)</div>
    </div>
    
    <h2>检查结果</h2>
"@
    
    # 添加各项检查结果
    foreach ($reportType in $ReportData.reports.Keys) {
        $report = $ReportData.reports[$reportType]
        $htmlContent += "<h3>$reportType 检查</h3>"
        $htmlContent += "<p>违规数: $($report.violations)</p>"
    }
    
    # 添加建议
    if ($ReportData.recommendations.Count -gt 0) {
        $htmlContent += "<h2>改进建议</h2><ul>"
        foreach ($recommendation in $ReportData.recommendations) {
            $htmlContent += "<li>$recommendation</li>"
        }
        $htmlContent += "</ul>"
    }
    
    $htmlContent += "</body></html>"
    $htmlContent | Out-File $htmlFile
    
    Write-Log "报告已保存: $jsonFile" "Success"
    Write-Log "HTML报告: $htmlFile" "Success"
    
    return @{
        jsonFile = $jsonFile
        htmlFile = $htmlFile
    }
}

# 发送邮件报告
function Send-EmailReport {
    param($ReportFiles, $ReportData)
    
    if (-not $EmailReport -or -not $EmailTo) {
        return
    }
    
    try {
        $subject = "Otter项目质量报告 - $($ReportData.summary.riskLevel) 风险"
        $body = @"
质量分数: $($ReportData.summary.score)/100
风险等级: $($ReportData.summary.riskLevel)
总违规数: $($ReportData.summary.totalViolations)

详细报告请查看附件。
"@
        
        # 这里需要配置SMTP设置
        Write-Log "邮件报告功能需要配置SMTP设置" "Info"
    }
    catch {
        Write-Log "发送邮件失败: $($_.Exception.Message)" "Error"
    }
}

# 主监控函数
function Start-QualityMonitoring {
    Write-Log "开始质量监控..." "Info"
    
    do {
        try {
            $config = Get-QualityConfig
            
            # 执行各项检查
            $reports = @{
                complexity = Test-CodeComplexity -Config $config
                duplication = Test-CodeDuplication -Config $config
                imageSize = Test-DockerImageSize -Config $config
                security = Test-SecurityVulnerabilities -Config $config
                dependencies = Test-Dependencies -Config $config
                performance = Test-PerformanceMetrics -Config $config
            }
            
            # 生成报告
            $reportData = New-QualityReport -Reports $reports -Config $config
            $reportFiles = Save-QualityReport -ReportData $reportData
            
            # 发送邮件（如果配置）
            Send-EmailReport -ReportFiles $reportFiles -ReportData $reportData
            
            # 显示摘要
            Write-Log "质量检查完成" "Success"
            Write-Log "质量分数: $($reportData.summary.score)/100" "Info"
            Write-Log "风险等级: $($reportData.summary.riskLevel)" "Info"
            Write-Log "总违规数: $($reportData.summary.totalViolations)" "Info"
            
            if ($Continuous) {
                Write-Log "等待 $IntervalMinutes 分钟后进行下次检查..." "Info"
                Start-Sleep -Seconds ($IntervalMinutes * 60)
            }
        }
        catch {
            Write-Log "监控过程中发生错误: $($_.Exception.Message)" "Error"
            if ($Continuous) {
                Start-Sleep -Seconds 60 # 错误后等待1分钟
            }
        }
    } while ($Continuous)
}

# 主程序入口
function Main {
    Write-Host "Otter项目持续质量监控" -ForegroundColor $Colors.Header
    Write-Host "=" * 50 -ForegroundColor $Colors.Header
    
    Initialize-ReportDirectory
    
    if ($Continuous) {
        Write-Log "启动持续监控模式，间隔: $IntervalMinutes 分钟" "Info"
    } else {
        Write-Log "执行单次质量检查" "Info"
    }
    
    Start-QualityMonitoring
    
    Write-Log "质量监控完成" "Success"
}

# 执行主程序
if ($MyInvocation.InvocationName -ne '.') {
    Main
}