#
# ╔══════════════════════════════════════════════════════════════════╗
# ║           OpenClaw CTL / MoltBot Windows 管理脚本               ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  作者     GitHub  : byJoey                                      ║
# ║           YouTube : @joeyblog                                   ║
# ║           Telegram: https://t.me/+ft-zI76oovgwNmRh             ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  致谢 / 引用                                                    ║
# ║  · 原始脚本基础来自 kejilion（@kejilion）                       ║
# ║  · CLIProxyAPI 安装器来自 cliproxyapi-installer                 ║
# ║    github.com/brokechubb/cliproxyapi-installer                  ║
# ╚══════════════════════════════════════════════════════════════════╝
#
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:OpenClawHome = Join-Path $env:USERPROFILE '.openclaw'
$script:OpenClawJson = Join-Path $script:OpenClawHome 'openclaw.json'
$script:CLIProxyDir  = Join-Path $env:USERPROFILE '.cli-proxy-api'
$script:CLIProxyConf = Join-Path $script:CLIProxyDir 'config.yaml'
$script:CLIProxyBin  = Join-Path $script:CLIProxyDir 'cli-proxy-api.exe'


function Write-Colored {
    param([string]$Text, [ConsoleColor]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
}

function UI-Header {
    param([string]$Title)
    $line = '─' * 50
    Write-Host ""
    Write-Colored "  $line" DarkCyan
    Write-Colored "    $Title" Cyan
    Write-Colored "  $line" DarkCyan
    Write-Host ""
}

function UI-OK    { param([string]$Msg) Write-Colored "  [OK] $Msg" Green }
function UI-Err   { param([string]$Msg) Write-Colored "  [ERR] $Msg" Red }
function UI-Warn  { param([string]$Msg) Write-Colored "  [WARN] $Msg" Yellow }
function UI-Info  { param([string]$Msg) Write-Colored "  [i] $Msg" DarkCyan }
function UI-Step  { param([string]$Msg) Write-Colored "  >> $Msg" Magenta }

function Show-Menu {
    param(
        [string]$Header,
        [string[]]$Options
    )

    $sel = 0
    $savedVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    try {
        $w = [Console]::WindowWidth
        $headerLines = 0
        if ($Header) { $headerLines = 3 }
        $totalLines = $headerLines + $Options.Count

        $top = [Console]::CursorTop
        $bufferHeight = [Console]::BufferHeight

        if ($top + $totalLines + 1 -gt $bufferHeight) {
            $needed = $top + $totalLines + 1 - $bufferHeight
            for ($i = 0; $i -le $needed; $i++) {
                [Console]::WriteLine()
            }
            $top = [Console]::CursorTop
        }

        $anchorY = $top

        while ($true) {
            $bufferHeight = [Console]::BufferHeight
            if ($bufferHeight -le 1) { $bufferHeight = 2 }

            if ($anchorY -lt 0 -or $anchorY + $totalLines + 1 -gt $bufferHeight) {
                $anchorY = [Math]::Max(0, $bufferHeight - $totalLines - 1)
            }

            $row = $anchorY

            if ($Header) {
                if ($row -ge $bufferHeight) { continue }
                [Console]::SetCursorPosition(0, $row)
                $line = ("  $Header").PadRight($w - 1)
                Write-Host $line -ForegroundColor DarkCyan
                $row++

                if ($row -ge $bufferHeight) { continue }
                [Console]::SetCursorPosition(0, $row)
                $hint = "  ↑↓ 移动 · Enter 确认 · q 退出".PadRight($w - 1)
                Write-Host $hint -ForegroundColor DarkGray
                $row++

                if ($row -ge $bufferHeight) { continue }
                [Console]::SetCursorPosition(0, $row)
                Write-Host ("".PadRight($w - 1))
                $row++
            }

            for ($i = 0; $i -lt $Options.Count; $i++) {
                if ($row -ge $bufferHeight) { break }
                [Console]::SetCursorPosition(0, $row)
                $prefix = if ($i -eq $sel) { "  > " } else { "    " }
                $txt = ($prefix + $Options[$i])
                if ($txt.Length -ge $w) { $txt = $txt.Substring(0, $w - 1) } else { $txt = $txt.PadRight($w - 1) }
                $color = if ($i -eq $sel) { 'Cyan' } else { 'Gray' }
                Write-Host $txt -ForegroundColor $color
                $row++
            }

            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { if ($sel -gt 0) { $sel-- } else { $sel = $Options.Count - 1 } }
                'DownArrow' { if ($sel -lt $Options.Count - 1) { $sel++ } else { $sel = 0 } }
                'Enter'     { return $Options[$sel] }
                'Q'         { return $null }
                'Escape'    { return $null }
            }
        }
    } finally {
        [Console]::CursorVisible = $savedVisible
    }
}

function Press-Enter {
    Write-Host ""
    Write-Colored "  ──────────────────────────────" DarkGray
    Read-Host "  按回车继续"
    Clear-Host
}



function Ensure-Node {
    if (Get-Command node -ErrorAction SilentlyContinue) { return }
    UI-Info "正在安装 Node.js..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                     [System.Environment]::GetEnvironmentVariable('Path', 'User')
    } else {
        UI-Err "未检测到 winget，请手动安装 Node.js: https://nodejs.org/"
        return
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        UI-Err "Node.js 安装后未生效，请关闭终端重新打开"
        return
    }
    UI-OK "Node.js $(node --version) 已安装"
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return }
    UI-Info "正在安装 Git..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                     [System.Environment]::GetEnvironmentVariable('Path', 'User')
    } else {
        UI-Err "未检测到 winget，请手动安装 Git: https://git-scm.com/"
    }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                 [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

function Ensure-Fzf {
    if (Get-Command fzf -ErrorAction SilentlyContinue) { return }
    UI-Info "正在安装 fzf（用于列表选择）..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id junegunn.fzf -e --accept-source-agreements --accept-package-agreements --silent | Out-Null
        Refresh-Path
    } else {
        UI-Warn "未检测到 winget，跳过 fzf 安装，将使用内置菜单"
    }
}



function Install-OpenClaw {
    UI-Info "正在通过官方脚本安装 OpenClaw..."
    Write-Host ""
    try {
        $script = (New-Object Net.WebClient).DownloadString('https://openclaw.ai/install.ps1')
        Invoke-Expression $script
    } catch {
        UI-Err "官方安装脚本执行失败: $_"
        return
    }

    Refresh-Path

    if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
        UI-Err "openclaw 安装后不可用，请关闭终端重新打开"
        return
    }
    UI-OK "OpenClaw $(openclaw --version 2>$null) 已安装"

    if (Test-Path $script:OpenClawJson) {
        $json = Get-Content $script:OpenClawJson -Raw
        $json = $json -replace '"profile":\s*"messaging"', '"profile": "full"'
        Set-Content $script:OpenClawJson $json -NoNewline
    }

    Start-Gateway
}

function Start-Gateway {
    UI-Info "正在启动网关..."
    try { cmd /c openclaw gateway stop 2>$null } catch {}
    Start-Process cmd.exe -ArgumentList '/c','openclaw','gateway','start' -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Stop-Gateway {
    UI-Info "正在停止网关..."
    try { cmd /c openclaw gateway stop 2>$null } catch {}
    Get-Process | Where-Object { $_.ProcessName -match 'openclaw|node' -and $_.MainWindowTitle -eq '' } | Stop-Process -Force -ErrorAction SilentlyContinue
    UI-OK "网关已停止"
}



function Get-CLIProxyLatest {
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest' -UseBasicParsing
    $arch = if ([System.Environment]::Is64BitOperatingSystem) {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    } else { 'amd64' }
    $asset = $release.assets | Where-Object { $_.name -like "*windows_${arch}.zip" } | Select-Object -First 1
    return @{
        Version = $release.tag_name
        Url     = $asset.browser_download_url
        Name    = $asset.name
    }
}

function Install-CLIProxy {
    if (Test-Path $script:CLIProxyBin) {
        UI-Info "CLIProxyAPI 已安装: $($script:CLIProxyBin)"
        return
    }

    UI-Info "正在下载 CLIProxyAPI..."
    $info = Get-CLIProxyLatest
    if (-not $info.Url) {
        UI-Err "无法获取 CLIProxyAPI 下载地址"
        return
    }

    if (-not (Test-Path $script:CLIProxyDir)) {
        New-Item -ItemType Directory -Path $script:CLIProxyDir -Force | Out-Null
    }

    $zipPath = Join-Path $env:TEMP $info.Name
    Invoke-WebRequest -Uri $info.Url -OutFile $zipPath -UseBasicParsing

    $extractDir = Join-Path $env:TEMP 'cliproxy_extract'
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $exe = Get-ChildItem -Path $extractDir -Filter 'cli-proxy-api.exe' -Recurse | Select-Object -First 1
    if (-not $exe) {
        $exe = Get-ChildItem -Path $extractDir -Filter '*.exe' -Recurse | Select-Object -First 1
    }
    if ($exe) {
        Copy-Item $exe.FullName $script:CLIProxyBin -Force
    } else {
        UI-Err "解压后未找到可执行文件"
        return
    }

    if (-not (Test-Path $script:CLIProxyConf)) {
        $exampleConf = Get-ChildItem -Path $extractDir -Filter 'config*yaml' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exampleConf) {
            Copy-Item $exampleConf.FullName $script:CLIProxyConf -Force
        } else {
            $authDir = $script:CLIProxyDir -replace '\\', '/'
            @"
port: 8317
auth-dir: "$authDir"
api-keys:
  - "sk-placeholder"
"@ | Set-Content $script:CLIProxyConf -Encoding UTF8
        }
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

    UI-OK "CLIProxyAPI $($info.Version) 已安装"
}

function Ensure-CLIProxyAuthDir {
    if (-not (Test-Path $script:CLIProxyConf)) { return }
    $content = Get-Content $script:CLIProxyConf -Raw
    if ($content -notmatch 'auth-dir:') {
        $authDir = $script:CLIProxyDir -replace '\\', '/'
        $content = "auth-dir: `"$authDir`"`n$content"
        Set-Content $script:CLIProxyConf $content -NoNewline -Encoding UTF8
    }
}

function Start-CLIProxy {
    if (-not (Test-Path $script:CLIProxyBin)) {
        UI-Err "CLIProxyAPI 未安装"
        return $false
    }
    $running = Get-Process -Name 'cli-proxy-api' -ErrorAction SilentlyContinue
    if ($running) {
        UI-Info "CLIProxyAPI 已在运行 (PID: $($running.Id))"
        return $true
    }

    Ensure-CLIProxyAuthDir

    UI-Info "正在启动 CLIProxyAPI..."
    Start-Process -FilePath $script:CLIProxyBin -WorkingDirectory $script:CLIProxyDir -WindowStyle Hidden -ErrorAction SilentlyContinue

    for ($i = 1; $i -le 10; $i++) {
        Start-Sleep -Seconds 1
        $check = Get-Process -Name 'cli-proxy-api' -ErrorAction SilentlyContinue
        if ($check) {
            UI-OK "CLIProxyAPI 已启动 (PID: $($check.Id))"
            return $true
        }
        Write-Host "  等待启动... ($i/10)" -ForegroundColor DarkGray
    }
    UI-Err "CLIProxyAPI 启动失败，尝试前台诊断："
    Push-Location $script:CLIProxyDir
    & $script:CLIProxyBin 2>&1 | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Pop-Location
    return $false
}

function Stop-CLIProxy {
    $proc = Get-Process -Name 'cli-proxy-api' -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        UI-OK "CLIProxyAPI 已停止"
    } else {
        UI-Info "CLIProxyAPI 未在运行"
    }
}

function CLIProxy-OAuthLogin {
    if (-not (Test-Path $script:CLIProxyBin)) {
        UI-Err "CLIProxyAPI 未安装"
        return
    }

    $providers = @(
        'Claude (Anthropic)'
        'Gemini (Google)'
        'OpenAI / Codex'
        'Qwen (通义千问)'
        'iFlow'
    )
    $choice = Show-Menu -Header '选择要登录的 AI 提供商' -Options $providers
    if (-not $choice) { return }

    $loginCmd = switch ($choice) {
        'Claude (Anthropic)' { '--claude-login' }
        'Gemini (Google)'    { '--login' }
        'OpenAI / Codex'     { '--codex-login' }
        'Qwen (通义千问)'     { '--qwen-login' }
        'iFlow'              { '--iflow-login' }
    }

    if (-not (Test-Path $script:CLIProxyConf)) {
        UI-Err "配置文件不存在，正在创建默认配置..."
        if (-not (Test-Path $script:CLIProxyDir)) {
            New-Item -ItemType Directory -Path $script:CLIProxyDir -Force | Out-Null
        }
        $authDir = $script:CLIProxyDir -replace '\\', '/'
        @"
port: 8317
auth-dir: "$authDir"
api-keys:
  - "sk-placeholder"
"@ | Set-Content $script:CLIProxyConf -Encoding UTF8
    }

    UI-Info "浏览器将自动打开，完成授权后按提示操作即可..."
    Write-Host ""

    Push-Location $script:CLIProxyDir
    try {
        if ($loginCmd -eq '--login') {
            $geminiChoice = "2" + [Environment]::NewLine
            $geminiChoice | & $script:CLIProxyBin $loginCmd 2>&1 | ForEach-Object { Write-Host $_ }
        } else {
            & $script:CLIProxyBin $loginCmd 2>&1 | ForEach-Object { Write-Host $_ }
        }
    } finally {
        Pop-Location
    }

    Write-Host ""
    UI-OK "登录流程结束"
}

function Generate-APIKey {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 48
    $rng.GetBytes($bytes)
    $key = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    return "sk-$key"
}

function Inject-CLIProxyKey {
    param([string]$Key)
    if (-not (Test-Path $script:CLIProxyConf)) { return }
    $lines = Get-Content $script:CLIProxyConf
    $newLines = @()
    $inKeys = $false
    $injected = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*api-keys:\s*$') {
            $inKeys = $true
            $newLines += $line
            $newLines += "  - `"$Key`""
            $injected = $true
            continue
        }
        if ($inKeys -and $line -match '^\s*-\s*"sk-placeholder"') { continue }
        if ($inKeys -and $line -match '^\S') { $inKeys = $false }
        $newLines += $line
    }
    if (-not $injected) {
        $newLines += 'api-keys:'
        $newLines += "  - `"$Key`""
    }
    Set-Content $script:CLIProxyConf ($newLines -join "`n") -NoNewline -Encoding UTF8
}

function Get-CLIProxyKey {
    if (-not (Test-Path $script:CLIProxyConf)) { return $null }
    $content = Get-Content $script:CLIProxyConf -Raw
    if ($content -match '"(sk-[^"]+)"') { return $Matches[1] }
    return $null
}

function Get-CLIProxyPort {
    if (-not (Test-Path $script:CLIProxyConf)) { return 8317 }
    $content = Get-Content $script:CLIProxyConf
    foreach ($line in $content) {
        if ($line -match '^\s*port:\s*(\d+)') { return $Matches[1] }
    }
    return 8317
}



$script:TaskNameOC  = 'OpenClawGateway'
$script:TaskNameCP  = 'CLIProxyAPI'

function Get-AutostartStatus {
    param([string]$TaskName)
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            if ($task.State -ne 'Disabled') { return '已开启' }
            else { return '已关闭' }
        }
    } catch {}
    return '未安装'
}

function Enable-Autostart-OC {
    $openclaw = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
    if (-not $openclaw) { UI-Err "openclaw 未安装"; return }
    $action  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$openclaw`" gateway start"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $script:TaskNameOC -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    UI-OK "OpenClaw 网关开机自启动已开启"
}

function Disable-Autostart-OC {
    Unregister-ScheduledTask -TaskName $script:TaskNameOC -Confirm:$false -ErrorAction SilentlyContinue
    UI-OK "OpenClaw 网关开机自启动已关闭"
}

function Enable-Autostart-CP {
    if (-not (Test-Path $script:CLIProxyBin)) { UI-Err "CLIProxyAPI 未安装"; return }
    $action  = New-ScheduledTaskAction -Execute $script:CLIProxyBin -WorkingDirectory $script:CLIProxyDir
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $script:TaskNameCP -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    UI-OK "CLIProxyAPI 开机自启动已开启"
}

function Disable-Autostart-CP {
    Unregister-ScheduledTask -TaskName $script:TaskNameCP -Confirm:$false -ErrorAction SilentlyContinue
    UI-OK "CLIProxyAPI 开机自启动已关闭"
}

function Toggle-Autostart {
    $ocStatus = Get-AutostartStatus $script:TaskNameOC
    $cpStatus = Get-AutostartStatus $script:TaskNameCP

    Clear-Host
    UI-Header "开机自启动管理"
    Write-Host "  OpenClaw 网关  : " -NoNewline; Write-Colored $ocStatus $(if ($ocStatus -eq '已开启') { 'Green' } else { 'Red' })
    Write-Host "  CLIProxyAPI    : " -NoNewline; Write-Colored $cpStatus $(if ($cpStatus -eq '已开启') { 'Green' } else { 'Red' })
    Write-Host ""

    $opts = @()
    if ($ocStatus -ne '已开启') { $opts += '开启 OpenClaw 网关自启动' }
    if ($ocStatus -eq '已开启') { $opts += '关闭 OpenClaw 网关自启动' }
    if ($cpStatus -ne '已开启') { $opts += '开启 CLIProxyAPI 自启动' }
    if ($cpStatus -eq '已开启') { $opts += '关闭 CLIProxyAPI 自启动' }
    $opts += '返回'

    $action = Show-Menu -Header '选择操作' -Options $opts
    switch ($action) {
        '开启 OpenClaw 网关自启动' { Enable-Autostart-OC }
        '关闭 OpenClaw 网关自启动' { Disable-Autostart-OC }
        '开启 CLIProxyAPI 自启动'  { Enable-Autostart-CP }
        '关闭 CLIProxyAPI 自启动'  { Disable-Autostart-CP }
    }
}



function Beginner-Install {
    Clear-Host
    UI-Header "小白模式安装"
    Write-Host ""
    Write-Colored "  [ OpenClaw -> CLIProxyAPI -> AI Auth -> Auto Config ]" Magenta
    Write-Host ""

    UI-Step "第 1 步：安装 OpenClaw"
    Install-OpenClaw

    UI-Step "第 2 步：安装 CLIProxyAPI"
    Install-CLIProxy

    if (-not (Test-Path $script:CLIProxyConf)) {
        UI-Err "CLIProxyAPI 配置文件不存在: $($script:CLIProxyConf)"
        Press-Enter; return
    }
    UI-OK "CLIProxyAPI 安装完成"

    UI-Step "第 3 步：登录 AI 账号"
    UI-Info "通过 OAuth 授权即可免费使用，无需付费 API Key"
    Write-Host ""
    CLIProxy-OAuthLogin

    UI-Step "第 4 步：生成 API Key 并启动服务"
    $newKey = Generate-APIKey
    Inject-CLIProxyKey $newKey
    UI-OK "API Key 已写入: $($newKey.Substring(0, 12))****"

    $started = Start-CLIProxy
    if (-not $started) {
        UI-Err "CLIProxyAPI 无法启动，请检查配置文件后手动启动"
        Press-Enter; return
    }

    Enable-Autostart-CP

    UI-Step "第 5 步：配置 OpenClaw API"
    $port = Get-CLIProxyPort
    $apiKey = Get-CLIProxyKey
    $baseUrl = "http://localhost:${port}/v1"

    if (-not $apiKey) {
        UI-Err "无法读取 API Key，请在 CLIProxyAPI 管理中手动添加"
        Press-Enter; return
    }

    UI-Info "地址：$baseUrl"
    UI-Info "Key：$($apiKey.Substring(0, 12))****"

    $ok = Add-ModelsFromProvider 'cliproxy' $baseUrl $apiKey

    if ($ok) {
        Start-Gateway
        Enable-Autostart-OC

        UI-Step "第 6 步：选择默认模型"
        UI-Info "请从可用模型中选择一个作为默认"
        Write-Host ""
        Change-Model

        Write-Host ""
        Write-Colored "  ╔══════════════════════════════════════════╗" Green
        Write-Colored "  ║      INSTALL COMPLETE                    ║" Green
        Write-Colored "  ║  OpenClaw 已自动接入 CLIProxyAPI         ║" Green
        Write-Colored "  ╚══════════════════════════════════════════╝" Green

        Write-Host ""
        $goBot = Show-Menu -Header '现在去对接机器人？' -Options @('是，立即对接', '否，稍后再说')
        if ($goBot -eq '是，立即对接') {
            Connect-Bot
            return
        }
    } else {
        UI-Err "模型获取失败，CLIProxyAPI 可能尚未就绪"
        UI-Info "请稍后在主菜单中使用「API 管理 -> 添加 API」手动配置"
        Start-Gateway
        Enable-Autostart-OC
    }

    Press-Enter
}



function Connect-Bot {
    while ($true) {
        Clear-Host
        UI-Header "机器人连接对接"

        $platforms = @(
            'Telegram 机器人对接'
            '飞书 (Lark) 机器人对接'
            'WhatsApp 机器人对接'
            'Discord 机器人对接'
            'Slack 机器人对接'
            '返回'
        )
        $choice = Show-Menu -Header '选择要对接的平台' -Options $platforms
        if (-not $choice -or $choice -eq '返回') { return }

        $platformMap = @{
            'Telegram 机器人对接'      = 'telegram'
            '飞书 (Lark) 机器人对接'    = 'feishu'
            'WhatsApp 机器人对接'       = 'whatsapp'
            'Discord 机器人对接'        = 'discord'
            'Slack 机器人对接'          = 'slack'
        }
        $platform = $platformMap[$choice]
        if (-not $platform) { continue }

        $code = Read-Host "  输入 $($choice -replace ' 机器人对接','') 连接码 (如 NYA99R2F)"
        if ([string]::IsNullOrWhiteSpace($code)) { continue }

        cmd /c openclaw pairing approve $platform $code 2>$null
        Press-Enter
    }
}



function Fetch-ModelList {
    param([string]$BaseUrl, [string]$ApiKey, [int]$Retries = 5)

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            $headers = @{ 'Authorization' = "Bearer $ApiKey" }
            $resp = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers $headers -TimeoutSec 10
            $models = if ($resp.data) { $resp.data } else { $resp }
            if ($models -and $models.Count -gt 0) { return $models }
        } catch {}
        if ($attempt -lt $Retries) {
            Write-Host "  获取模型列表失败，${attempt}/${Retries} 重试中..." -ForegroundColor DarkGray
            Start-Sleep -Seconds 3
        }
    }
    return $null
}

function Get-ModelCost {
    param([string]$ModelId)
    $input = 0.15; $output = 0.60
    if ($ModelId -match 'opus|pro|preview|thinking|sonnet') { $input = 2.00; $output = 12.00 }
    elseif ($ModelId -match 'gpt-5|codex') { $input = 1.25; $output = 10.00 }
    elseif ($ModelId -match 'flash|lite|haiku|mini|nano') { $input = 0.10; $output = 0.40 }
    return @{ input = $input; output = $output; cacheRead = 0; cacheWrite = 0 }
}

function Get-ModelMetadata {
    param([string]$ModelId)
    $meta = @{
        contextWindow = 1048576
        input         = @('text', 'image')
        cost          = Get-ModelCost $ModelId
    }
    switch -Regex ($ModelId) {
        '^MiniMax-M3$' {
            $meta.contextWindow = 1000000
            $meta.input = @('text', 'image', 'video')
            $meta.cost = @{ input = 0.6; output = 2.4; cacheRead = 0.12; cacheWrite = $null }
        }
        '^MiniMax-M2\.7$' {
            $meta.contextWindow = 204800
            $meta.input = @('text')
            $meta.cost = @{ input = 0.3; output = 1.2; cacheRead = 0.06; cacheWrite = 0.375 }
        }
    }
    return $meta
}

function Add-ModelsFromProvider {
    param([string]$Name, [string]$BaseUrl, [string]$ApiKey)

    if (-not (Test-Path $script:OpenClawJson)) {
        UI-Err "未找到 openclaw.json"
        return $false
    }

    UI-Info "正在获取 $Name 的模型列表..."
    $models = Fetch-ModelList $BaseUrl $ApiKey
    if (-not $models) {
        UI-Err "获取模型列表失败"
        return $false
    }

    $modelArray = @()
    foreach ($m in $models) {
        if (-not $m.id) { continue }
        $meta = Get-ModelMetadata $m.id
        $modelArray += @{
            id            = $m.id
            name          = "$Name / $($m.id)"
            input         = $meta.input
            contextWindow = $meta.contextWindow
            maxTokens     = 128000
            cost          = $meta.cost
        }
    }

    if ($modelArray.Count -eq 0) {
        UI-Err "无可用模型"
        return $false
    }

    UI-Info "发现 $($modelArray.Count) 个模型"

    Copy-Item $script:OpenClawJson "$($script:OpenClawJson).bak" -Force -ErrorAction SilentlyContinue
    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json

    if (-not $json.models) { $json | Add-Member -NotePropertyName 'models' -NotePropertyValue ([PSCustomObject]@{}) -Force }
    if (-not $json.models.mode) { $json.models | Add-Member -NotePropertyName 'mode' -NotePropertyValue 'merge' -Force }
    if (-not $json.models.providers) { $json.models | Add-Member -NotePropertyName 'providers' -NotePropertyValue ([PSCustomObject]@{}) -Force }

    $provider = [PSCustomObject]@{
        baseUrl = $BaseUrl
        apiKey  = $ApiKey
        api     = 'openai-completions'
        models  = $modelArray
    }
    $json.models.providers | Add-Member -NotePropertyName $Name -NotePropertyValue $provider -Force

    if (-not $json.agents) { $json | Add-Member -NotePropertyName 'agents' -NotePropertyValue ([PSCustomObject]@{}) -Force }
    if (-not $json.agents.defaults) { $json.agents | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([PSCustomObject]@{}) -Force }

    $existingModels = $json.agents.defaults.models
    if (-not $existingModels -or $existingModels -isnot [PSCustomObject]) {
        $existingModels = [PSCustomObject]@{}
    }
    foreach ($m in $modelArray) {
        $ref = "$Name/$($m.id)"
        if (-not $existingModels.PSObject.Properties[$ref]) {
            $existingModels | Add-Member -NotePropertyName $ref -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
    }
    $json.agents.defaults | Add-Member -NotePropertyName 'models' -NotePropertyValue $existingModels -Force

    $json | ConvertTo-Json -Depth 20 | Set-Content $script:OpenClawJson -Encoding UTF8
    UI-OK "$Name 已添加 $($modelArray.Count) 个模型（引用格式: $Name/<model-id>）"
    return $true
}

function Change-Model {
    if (-not (Test-Path $script:OpenClawJson)) {
        UI-Err "未找到 openclaw.json"
        Press-Enter; return
    }

    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json
    $providers = $json.models.providers
    if (-not $providers) { UI-Err "未配置任何 API provider"; Press-Enter; return }

    $modelNames = @()
    foreach ($prop in $providers.PSObject.Properties) {
        $pname = $prop.Name
        $pval = $prop.Value
        if ($pval.models) {
            foreach ($m in $pval.models) {
                if ($m.id) { $modelNames += "$pname/$($m.id)" }
            }
        }
    }

    if ($modelNames.Count -eq 0) { UI-Err "无可用模型"; Press-Enter; return }

    Ensure-Fzf
    $selected = $null
    $fzfCmd = Get-Command fzf -ErrorAction SilentlyContinue
    if ($fzfCmd) {
        UI-Info "使用 fzf 选择模型（支持模糊搜索）"
        $selected = $modelNames | & $fzfCmd.Source
    } else {
        $selected = Show-Menu -Header '选择默认模型' -Options $modelNames
    }
    if (-not $selected) { return }

    $selected = ($selected -split '\s+')[0]

    cmd /c openclaw models set "$selected" 2>$null
    Start-Gateway
    UI-OK "已切换至：$selected"
    Press-Enter
}



function Test-APILatency {
    param([string]$BaseUrl, [string]$ApiKey)
    try {
        $uri = $BaseUrl.TrimEnd('/') + '/models'
        $headers = @{ 'Authorization' = "Bearer $ApiKey"; 'User-Agent' = 'Mozilla/5.0' }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 12 -ErrorAction Stop | Out-Null
        $sw.Stop()
        return [int]$sw.ElapsedMilliseconds
    } catch {
        return -1
    }
}

function Show-APIListWithLatency {
    if (-not (Test-Path $script:OpenClawJson)) { return }
    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json
    $providers = $json.models.providers
    if (-not $providers) { return }

    Write-Colored "  --- 已配置 API 列表 ---" DarkCyan
    $idx = 1
    foreach ($prop in $providers.PSObject.Properties) {
        $pname = $prop.Name
        $pval = $prop.Value
        $url = if ($pval.baseUrl) { $pval.baseUrl } else { '-' }
        $count = if ($pval.models) { $pval.models.Count } else { 0 }
        $api = if ($pval.api) { $pval.api } else { '' }
        $supportedApis = @('openai-completions', 'openai-responses', 'openai-chat-completions')

        $latencyText = '未检测'
        $latencyColor = 'Gray'
        if ($supportedApis -contains $api -and $url -ne '-' -and $pval.apiKey) {
            $ms = Test-APILatency $url $pval.apiKey
            if ($ms -ge 0) {
                $latencyText = "${ms}ms"
                if ($ms -le 800) { $latencyColor = 'Green' }
                elseif ($ms -le 2000) { $latencyColor = 'Yellow' }
                else { $latencyColor = 'Red' }
            } else {
                $latencyText = '不可用'
                $latencyColor = 'Red'
            }
        }

        Write-Host "  [$idx] $pname | $url | " -NoNewline
        Write-Host "模型: " -NoNewline
        Write-Host "$count" -NoNewline -ForegroundColor Yellow
        Write-Host " | 延迟: " -NoNewline
        Write-Host "$latencyText" -ForegroundColor $latencyColor
        $idx++
    }
    Write-Host ""
}

function Remove-ProviderWithCleanup {
    param([string]$ProviderName)
    if (-not (Test-Path $script:OpenClawJson)) { return }
    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json

    $providers = $json.models.providers
    if (-not $providers -or -not $providers.PSObject.Properties[$ProviderName]) {
        UI-Err "provider 不存在: $ProviderName"
        return
    }

    $otherRefs = @()
    foreach ($prop in $providers.PSObject.Properties) {
        if ($prop.Name -eq $ProviderName) { continue }
        if ($prop.Value.models) {
            foreach ($m in $prop.Value.models) {
                if ($m.id) { $otherRefs += "$($prop.Name)/$($m.id)" }
            }
        }
    }
    $replacement = if ($otherRefs.Count -gt 0) { $otherRefs[0] } else { $null }

    $defaults = $json.agents.defaults
    if ($defaults) {
        $model = $defaults.model
        $primary = $null
        if ($model -is [string]) { $primary = $model }
        elseif ($model.primary) { $primary = $model.primary }

        if ($primary -and $primary.StartsWith("$ProviderName/")) {
            if (-not $replacement) {
                UI-Err "默认主模型指向该 provider，且无可用替代模型，已中止删除"
                return
            }
            if ($model -is [string]) { $defaults.model = $replacement }
            else { $defaults.model.primary = $replacement }
            UI-Info "默认主模型切换: $primary -> $replacement"
        }

        foreach ($fk in @('modelFallback', 'imageModelFallback')) {
            $val = $defaults.$fk
            if ($val -and $val -is [string] -and $val.StartsWith("$ProviderName/")) {
                if (-not $replacement) {
                    UI-Err "${fk} 指向该 provider，且无可用替代模型，已中止删除"
                    return
                }
                $defaults | Add-Member -NotePropertyName $fk -NotePropertyValue $replacement -Force
                UI-Info "${fk} 切换: $val -> $replacement"
            }
        }

        if ($defaults.models) {
            $toRemove = @()
            foreach ($mp in $defaults.models.PSObject.Properties) {
                if ($mp.Name.StartsWith("$ProviderName/")) { $toRemove += $mp.Name }
            }
            foreach ($r in $toRemove) { $defaults.models.PSObject.Properties.Remove($r) }
            if ($toRemove.Count -gt 0) {
                UI-Info "已清理 defaults.models 中 $($toRemove.Count) 个关联模型引用"
            }
        }
    }

    $providers.PSObject.Properties.Remove($ProviderName)
    $json | ConvertTo-Json -Depth 20 | Set-Content $script:OpenClawJson -Encoding UTF8
    UI-OK "$ProviderName 已删除"
    Start-Gateway
}

function API-Manage-Menu {
    while ($true) {
        Clear-Host
        UI-Header "API 管理"
        Show-APIListWithLatency

        $opts = @('添加 API', '同步 API 供应商模型列表', '删除 API', '返回')
        $choice = Show-Menu -Header '选择操作' -Options $opts
        switch ($choice) {
            '添加 API' {
                $name = Read-Host '  API 名称 (provider)'
                if (-not $name) { continue }
                $url = Read-Host '  Base URL (如 http://localhost:8317/v1)'
                $key = Read-Host '  API Key'
                if ($url -and $key) {
                    $ok = Add-ModelsFromProvider $name $url $key
                    if ($ok) {
                        Start-Gateway
                        $pickModel = Show-Menu -Header '是否选择默认模型？' -Options @('是', '否')
                        if ($pickModel -eq '是') { Change-Model }
                    }
                }
                Press-Enter
            }
            '同步 API 供应商模型列表' {
                if (Test-Path $script:OpenClawJson) {
                    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json
                    $providers = $json.models.providers
                    if ($providers) {
                        $names = @()
                        foreach ($p in $providers.PSObject.Properties) { $names += $p.Name }
                        $sel = Show-Menu -Header '选择要同步的 provider' -Options $names
                        if ($sel) {
                            $prov = $providers.$sel
                            Add-ModelsFromProvider $sel $prov.baseUrl $prov.apiKey
                            Start-Gateway
                        }
                    }
                }
                Press-Enter
            }
            '删除 API' {
                if (Test-Path $script:OpenClawJson) {
                    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json
                    if ($json.models.providers) {
                        $names = @()
                        foreach ($p in $json.models.providers.PSObject.Properties) { $names += $p.Name }
                        $sel = Show-Menu -Header '选择要删除的 provider' -Options $names
                        if ($sel) {
                            $confirmDel = Show-Menu -Header "确认删除 $sel？" -Options @('是，删除', '取消')
                            if ($confirmDel -eq '是，删除') {
                                Remove-ProviderWithCleanup $sel
                            }
                        }
                    }
                }
                Press-Enter
            }
            default { break }
        }
        if ($choice -eq '返回' -or -not $choice) { break }
    }
}



function Get-AllCLIProxyKeys {
    if (-not (Test-Path $script:CLIProxyConf)) { return @() }
    $keys = @()
    $inKeys = $false
    foreach ($line in (Get-Content $script:CLIProxyConf)) {
        if ($line -match '^\s*api-keys:\s*$') { $inKeys = $true; continue }
        if ($inKeys -and $line -match '^\S') { break }
        if ($inKeys -and $line -match '"(sk-[^"]+)"') { $keys += $Matches[1] }
    }
    return $keys
}

function Get-CLIProxyVersion {
    if (-not (Test-Path $script:CLIProxyBin)) { return '' }
    try {
        $out = & $script:CLIProxyBin --version 2>&1 | Select-Object -First 1
        if ($out -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
    } catch {}
    return ''
}

function CLIProxy-ManageMenu {
    while ($true) {
        Clear-Host
        UI-Header "CLIProxyAPI 管理"

        $installed = Test-Path $script:CLIProxyBin
        $running = $null -ne (Get-Process -Name 'cli-proxy-api' -ErrorAction SilentlyContinue)
        $port = Get-CLIProxyPort
        $version = Get-CLIProxyVersion
        $allKeys = Get-AllCLIProxyKeys

        Write-Host "  安装状态: " -NoNewline
        if ($installed) {
            $vLabel = if ($version) { "已安装 v$version" } else { "已安装" }
            Write-Colored $vLabel Green
        } else { Write-Colored "未安装" Red }
        Write-Host "  运行状态: " -NoNewline
        if ($running) { Write-Colored "运行中" Green } else { Write-Colored "未运行" Red }
        Write-Host "  端口: $port    API Keys: $($allKeys.Count)"
        Write-Host ""

        $opts = @(
            '启动', '停止', '重启',
            '查看日志',
            '账号授权登录',
            '生成并添加 API Key', '查看 API Keys',
            '编辑配置文件', '更新', '卸载', '返回'
        )
        $choice = Show-Menu -Header '─── CLIProxyAPI ───' -Options $opts

        switch ($choice) {
            '启动' { Start-CLIProxy; Press-Enter }
            '停止' { Stop-CLIProxy; Press-Enter }
            '重启' { Stop-CLIProxy; Start-Sleep 1; Start-CLIProxy; Press-Enter }
            '查看日志' {
                Write-Host ""
                $logPath = Join-Path $script:CLIProxyDir 'logs'
                $logFiles = @()
                if (Test-Path $logPath) {
                    $logFiles = Get-ChildItem $logPath -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                }
                $singleLog = Join-Path $script:CLIProxyDir 'cli-proxy-api.log'
                if ($logFiles.Count -gt 0) {
                    Get-Content $logFiles[0].FullName -Tail 80
                } elseif (Test-Path $singleLog) {
                    Get-Content $singleLog -Tail 80
                } else {
                    UI-Warn "未找到日志文件（服务尚未运行过）"
                }
                Press-Enter
            }
            '账号授权登录' { CLIProxy-OAuthLogin; Press-Enter }
            '生成并添加 API Key' {
                $nk = Generate-APIKey
                Write-Host ""
                Write-Colored "  已生成新 API Key：" Green
                Write-Colored "  $nk" Cyan
                Write-Host ""
                $confirmKey = Show-Menu -Header '将此 Key 写入 config.yaml？' -Options @('是', '否')
                if ($confirmKey -eq '是') {
                    Inject-CLIProxyKey $nk
                    UI-OK "API Key 已写入配置"
                    UI-Info "需要重启 CLIProxyAPI 生效"
                }
                Press-Enter
            }
            '查看 API Keys' {
                Write-Host ""
                if ($allKeys.Count -gt 0) {
                    Write-Colored "  config.yaml 中的 API Keys：" DarkCyan
                    Write-Host ""
                    foreach ($k in $allKeys) {
                        Write-Host "    - `"$k`""
                    }
                } else {
                    UI-Warn "未配置任何 API Key"
                }
                Write-Host ""
                Press-Enter
            }
            '编辑配置文件' {
                if (Test-Path $script:CLIProxyConf) {
                    Start-Process notepad $script:CLIProxyConf -Wait
                } else { UI-Err "配置文件不存在" }
                Press-Enter
            }
            '更新' {
                $confirmUp = Show-Menu -Header '确认更新 CLIProxyAPI？' -Options @('是', '否')
                if ($confirmUp -eq '是') {
                    Stop-CLIProxy
                    if (Test-Path $script:CLIProxyBin) { Remove-Item $script:CLIProxyBin -Force }
                    Install-CLIProxy
                    Start-CLIProxy
                }
                Press-Enter
            }
            '卸载' {
                $confirmDel = Show-Menu -Header '确认卸载 CLIProxyAPI？' -Options @('是，卸载', '取消')
                if ($confirmDel -eq '是，卸载') {
                    Stop-CLIProxy
                    Disable-Autostart-CP
                    Remove-Item $script:CLIProxyDir -Recurse -Force -ErrorAction SilentlyContinue
                    UI-OK "CLIProxyAPI 已卸载"
                }
                Press-Enter
            }
            default { break }
        }
        if ($choice -eq '返回' -or -not $choice) { break }
    }
}



function Install-Plugin {
    Clear-Host
    UI-Header "插件管理"
    try { openclaw plugins list 2>$null } catch {}
    Write-Host ""

    $plugins = @(
        'feishu          飞书/Lark 集成'
        'telegram        Telegram 机器人'
        'slack           Slack 企业通讯'
        'msteams         Microsoft Teams'
        'discord         Discord 社区管理'
        'whatsapp        WhatsApp 自动化'
        'memory-core     基础记忆 (文件检索)'
        'memory-lancedb  增强记忆 (向量数据库)'
        'copilot-proxy   Copilot 接口转发'
        'lobster         审批流 (带人工确认)'
        'voice-call      语音通话能力'
        'nostr           加密隐私聊天'
        '手动输入插件 ID'
    )
    $sel = Show-Menu -Header '选择要安装的插件' -Options $plugins
    if (-not $sel) { return }

    $pluginId = if ($sel -eq '手动输入插件 ID') {
        Read-Host '  插件 ID'
    } else {
        ($sel -split '\s+')[0]
    }
    if (-not $pluginId) { return }

    UI-Info "正在安装 $pluginId..."
    openclaw plugins install $pluginId 2>$null
    openclaw plugins enable $pluginId 2>$null
    Start-Gateway
    UI-OK "插件 $pluginId 安装完成"
    Press-Enter
}

function Install-Skill {
    Clear-Host
    UI-Header "技能管理"
    try { openclaw skills list 2>$null } catch {}
    Write-Host ""

    $skills = @(
        'github           管理 GitHub Issues/PR/CI'
        'notion           操作 Notion 页面与数据库'
        '1password        自动化读取 1Password 密钥'
        'gog              Google Workspace 全能助手'
        'himalaya         终端邮件管理 (IMAP/SMTP)'
        'summarize        网页/播客/YouTube 内容总结'
        'openai-whisper   本地音频转文字'
        'coding-agent     运行 Claude Code/Codex 等编程助手'
        '手动输入技能名称'
    )
    $sel = Show-Menu -Header '选择要安装的技能' -Options $skills
    if (-not $sel) { return }

    $skillName = if ($sel -eq '手动输入技能名称') {
        Read-Host '  技能名称'
    } else {
        ($sel -split '\s+')[0]
    }
    if (-not $skillName) { return }

    UI-Info "正在安装 $skillName..."
    npx clawhub install $skillName 2>$null
    Start-Gateway
    UI-OK "技能 $skillName 安装完成"
    Press-Enter
}



function Sync-OpenClawAPIModels {
    if (-not (Test-Path $script:OpenClawJson)) { return $true }
    $json = Get-Content $script:OpenClawJson -Raw | ConvertFrom-Json
    $providers = $json.models.providers
    if (-not $providers) { UI-Info "未检测到 API providers，跳过模型同步"; return $true }

    $supportedApis = @('openai-completions', 'openai-responses', 'openai-chat-completions')
    $changed = $false

    foreach ($prop in @($providers.PSObject.Properties)) {
        $pname = $prop.Name
        $pval = $prop.Value
        if (-not $pval -or -not $pval.baseUrl -or -not $pval.apiKey) { continue }
        $api = if ($pval.api) { $pval.api } else { '' }
        if ($supportedApis -notcontains $api) { continue }
        if (-not $pval.models -or $pval.models.Count -eq 0) { continue }

        $uri = $pval.baseUrl.TrimEnd('/') + '/models'
        $remoteIds = @()
        try {
            $headers = @{ 'Authorization' = "Bearer $($pval.apiKey)"; 'User-Agent' = 'Mozilla/5.0' }
            $resp = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 12 -ErrorAction Stop
            if ($resp.data) {
                foreach ($item in $resp.data) {
                    if ($item.id) { $remoteIds += [string]$item.id }
                }
            }
        } catch {
            UI-Warn "${pname}: /models 探测失败 ($_)"
            continue
        }

        if ($remoteIds.Count -eq 0) {
            UI-Warn "${pname}: 上游 /models 为空"
            continue
        }

        $remoteSet = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($rid in $remoteIds) { $remoteSet.Add($rid) | Out-Null }

        $localModels = @($pval.models | Where-Object { $_.id })
        $localIds = $localModels | ForEach-Object { [string]$_.id }

        $template = if ($localModels.Count -gt 0) { $localModels[0] } else { $null }
        if (-not $template) { continue }

        $keptModels = @($localModels | Where-Object { $remoteSet.Contains([string]$_.id) })
        $keptIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($m in $keptModels) { $keptIds.Add([string]$m.id) | Out-Null }

        $newModels = [System.Collections.ArrayList]::new()
        foreach ($m in $keptModels) { $newModels.Add($m) | Out-Null }
        $addedCount = 0
        foreach ($rid in $remoteIds) {
            if (-not $keptIds.Contains($rid)) {
                $nm = $template.PSObject.Copy()
                $nm.id = $rid
                if ($nm.name) { $nm.name = "$pname / $rid" }
                $newModels.Add($nm) | Out-Null
                $addedCount++
            }
        }

        $removedCount = ($localIds | Where-Object { -not $remoteSet.Contains($_) }).Count
        if ($removedCount -gt 0 -or $addedCount -gt 0) {
            $pval.models = @($newModels)
            $changed = $true

            $newRefs = $newModels | ForEach-Object { "$pname/$($_.id)" }
            if ($json.agents.defaults.models) {
                foreach ($mp in @($json.agents.defaults.models.PSObject.Properties)) {
                    if ($mp.Name.StartsWith("$pname/") -and $newRefs -notcontains $mp.Name) {
                        $json.agents.defaults.models.PSObject.Properties.Remove($mp.Name)
                    }
                }
                foreach ($ref in $newRefs) {
                    if (-not $json.agents.defaults.models.PSObject.Properties[$ref]) {
                        $json.agents.defaults.models | Add-Member -NotePropertyName $ref -NotePropertyValue ([PSCustomObject]@{}) -Force
                    }
                }
            }

            UI-Info "${pname}: 删除 $removedCount 个，新增 $addedCount 个，当前 $($newModels.Count) 个"
        }
    }

    if ($changed) {
        $json | ConvertTo-Json -Depth 20 | Set-Content $script:OpenClawJson -Encoding UTF8
        UI-OK "API 模型同步完成"
    } else {
        UI-Info "无需同步：配置已与上游保持一致"
    }
    return $true
}

function Doctor-Fix {
    UI-Info "正在执行健康检测..."
    try { cmd /c openclaw doctor --fix 2>&1 | ForEach-Object { Write-Host "  $_" } } catch { UI-Warn "doctor 执行失败" }
    Write-Host ""
    $ok = Sync-OpenClawAPIModels
    if ($ok) {
        Start-Gateway
    } else {
        UI-Err "API 模型同步失败，已中止重启网关"
    }
    Press-Enter
}



function Get-WebUIToken {
    try {
        $out = cmd /c openclaw dashboard 2>&1 | Out-String
        if ($out -match ':18789/#token=([a-f0-9]+)') { return $Matches[1] }
    } catch {}
    return ''
}

function Show-WebUIAddr {
    $token = Get-WebUIToken
    $addr = "http://127.0.0.1:18789"
    if ($token) { $addr += "/#token=$token" }

    Write-Host ""
    Write-Colored "  ┌─────────────────────────────────────────┐" DarkCyan
    Write-Colored "  │  OpenClaw WebUI 访问地址                 │" DarkCyan
    Write-Colored "  └─────────────────────────────────────────┘" DarkCyan
    Write-Host "  本机: " -NoNewline
    Write-Colored $addr Green
    Write-Host ""
}

function WebUI-DevicePairing {
    Show-WebUIAddr
    UI-Info "先在浏览器中访问上方地址以触发设备 ID"
    Press-Enter

    UI-Info "正在加载设备列表..."
    try { cmd /c openclaw devices list 2>&1 | ForEach-Object { Write-Host "  $_" } } catch {}
    Write-Host ""

    $requestKey = Read-Host '  请输入 Request Key'
    if (-not $requestKey) { UI-Err "Request Key 不能为空"; return }
    try { cmd /c openclaw devices approve "$requestKey" 2>&1 | ForEach-Object { Write-Host "  $_" } } catch { UI-Err "配对失败" }
}

function WebUI-Menu {
    while ($true) {
        Clear-Host
        UI-Header "WebUI 访问与设置"
        Show-WebUIAddr

        $opts = @('设备配对', '退出')
        $choice = Show-Menu -Header '选择操作' -Options $opts
        switch ($choice) {
            '设备配对' { WebUI-DevicePairing; Press-Enter }
            default { break }
        }
        if ($choice -eq '退出' -or -not $choice) { break }
    }
}



function Get-BackupRoot {
    $root = Join-Path $script:OpenClawHome 'backups'
    if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Show-BackupFileList {
    $root = Get-BackupRoot
    $files = Get-ChildItem $root -Filter '*.tar.gz' -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($files.Count -eq 0) {
        Write-Colored "  (无备份文件)" DarkGray
        return @()
    }

    Write-Colored "  --- 备份文件列表 ---" DarkCyan
    $memCount = 0; $projCount = 0
    foreach ($f in $files) {
        $type = '其他'
        if ($f.Name -match '^openclaw-memory-full') { $type = '记忆备份'; $memCount++ }
        elseif ($f.Name -match '^openclaw-project') { $type = '项目备份'; $projCount++ }
        $size = '{0:N1} KB' -f ($f.Length / 1024)
        Write-Host "  [$type] $($f.Name)  ($size)"
    }
    Write-Host "  记忆备份: $memCount    项目备份: $projCount"
    Write-Host ""
    return $files
}

function Backup-Memory {
    $workspace = Join-Path $script:OpenClawHome 'workspace'
    if (-not (Test-Path $workspace)) { UI-Err "未找到 workspace 目录"; Press-Enter; return }

    $root = Get-BackupRoot
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $tmpDir = Join-Path $env:TEMP "oc-backup-mem-$ts"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    $memoryMd = Join-Path $workspace 'MEMORY.md'
    $memoryDir = Join-Path $workspace 'memory'
    if (Test-Path $memoryMd) { Copy-Item $memoryMd $tmpDir }
    if (Test-Path $memoryDir) { Copy-Item $memoryDir $tmpDir -Recurse }

    $includeExtra = Show-Menu -Header '是否附带 AGENTS/USER/SOUL/TOOLS 文件？' -Options @('是', '否')
    if ($includeExtra -eq '是') {
        foreach ($fn in @('AGENTS.md', 'USER.md', 'SOUL.md', 'TOOLS.md')) {
            $fp = Join-Path $workspace $fn
            if (Test-Path $fp) { Copy-Item $fp $tmpDir }
        }
    }

    $items = Get-ChildItem $tmpDir -Recurse
    if ($items.Count -eq 0) { UI-Err "未找到可备份的记忆文件"; Remove-Item $tmpDir -Recurse -Force; Press-Enter; return }

    $outFile = Join-Path $root "openclaw-memory-full-$ts.tar.gz"
    UI-Info "正在打包备份..."
    try {
        tar -czf $outFile -C $tmpDir .
        UI-OK "记忆全量备份完成: $outFile"
    } catch { UI-Err "备份失败: $_" }
    Remove-Item $tmpDir -Recurse -Force
    Press-Enter
}

function Restore-Memory {
    $workspace = Join-Path $script:OpenClawHome 'workspace'
    if (-not (Test-Path $workspace)) { New-Item -ItemType Directory -Path $workspace -Force | Out-Null }

    $root = Get-BackupRoot
    $files = Get-ChildItem $root -Filter 'openclaw-memory-full-*.tar.gz' -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($files.Count -eq 0) { UI-Warn "无记忆备份文件"; Press-Enter; return }

    $names = $files | ForEach-Object { $_.Name }
    $sel = Show-Menu -Header '选择要还原的记忆备份' -Options $names
    if (-not $sel) { return }

    $archivePath = Join-Path $root $sel
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $tmpDir = Join-Path $env:TEMP "oc-restore-mem-$ts"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    UI-Info "正在解包还原..."
    try {
        tar -xzf $archivePath -C $tmpDir
        Copy-Item "$tmpDir\*" $workspace -Recurse -Force
        UI-OK "记忆全量还原完成"
    } catch { UI-Err "还原失败: $_" }
    Remove-Item $tmpDir -Recurse -Force
    Press-Enter
}

function Backup-Project {
    $ocRoot = $script:OpenClawHome
    if (-not (Test-Path $ocRoot)) { UI-Err "未找到 OpenClaw 根目录"; Press-Enter; return }

    $modes = @('安全模式（推荐）：workspace + openclaw.json + extensions/skills/prompts/tools',
               '完整模式（含更多状态，敏感风险更高）')
    $modeSel = Show-Menu -Header '选择备份模式' -Options $modes
    if (-not $modeSel) { return }

    $root = Get-BackupRoot
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $tmpDir = Join-Path $env:TEMP "oc-backup-proj-$ts"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    $modeLabel = 'safe'
    if ($modeSel -like '完整*') {
        $modeLabel = 'full'
        foreach ($d in @('workspace', 'extensions', 'skills', 'prompts', 'tools',
                         'telegram', 'feishu', 'whatsapp', 'discord', 'slack', 'qqbot', 'logs')) {
            $src = Join-Path $ocRoot $d
            if (Test-Path $src) { Copy-Item $src $tmpDir -Recurse }
        }
        $jsonSrc = Join-Path $ocRoot 'openclaw.json'
        if (Test-Path $jsonSrc) { Copy-Item $jsonSrc $tmpDir }
    } else {
        foreach ($d in @('workspace', 'extensions', 'skills', 'prompts', 'tools')) {
            $src = Join-Path $ocRoot $d
            if (Test-Path $src) { Copy-Item $src $tmpDir -Recurse }
        }
        $jsonSrc = Join-Path $ocRoot 'openclaw.json'
        if (Test-Path $jsonSrc) { Copy-Item $jsonSrc $tmpDir }
    }

    $items = Get-ChildItem $tmpDir -Recurse
    if ($items.Count -eq 0) { UI-Err "未找到可备份的项目内容"; Remove-Item $tmpDir -Recurse -Force; Press-Enter; return }

    $outFile = Join-Path $root "openclaw-project-$modeLabel-$ts.tar.gz"
    UI-Info "正在打包备份..."
    try {
        tar -czf $outFile -C $tmpDir .
        UI-OK "项目备份完成 ($modeLabel): $outFile"
    } catch { UI-Err "备份失败: $_" }
    Remove-Item $tmpDir -Recurse -Force
    Press-Enter
}

function Restore-Project {
    $ocRoot = $script:OpenClawHome
    if (-not (Test-Path $ocRoot)) { New-Item -ItemType Directory -Path $ocRoot -Force | Out-Null }

    $confirmRisk = Show-Menu -Header '高风险操作：项目还原会覆盖配置与工作区，确认继续？' -Options @('确认继续', '取消')
    if ($confirmRisk -ne '确认继续') { return }

    $root = Get-BackupRoot
    $files = Get-ChildItem $root -Filter 'openclaw-project-*.tar.gz' -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($files.Count -eq 0) { UI-Warn "无项目备份文件"; Press-Enter; return }

    $names = $files | ForEach-Object { $_.Name }
    $sel = Show-Menu -Header '选择要还原的项目备份' -Options $names
    if (-not $sel) { return }

    $archivePath = Join-Path $root $sel
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $tmpDir = Join-Path $env:TEMP "oc-restore-proj-$ts"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    Stop-Gateway
    UI-Info "正在解包还原..."
    try {
        tar -xzf $archivePath -C $tmpDir
        Copy-Item "$tmpDir\*" $ocRoot -Recurse -Force
        UI-OK "项目还原完成"
    } catch { UI-Err "还原失败: $_" }
    Remove-Item $tmpDir -Recurse -Force
    Start-Gateway
    Press-Enter
}

function Delete-BackupFile {
    $root = Get-BackupRoot
    $files = Get-ChildItem $root -Filter '*.tar.gz' -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($files.Count -eq 0) { UI-Warn "无备份文件"; Press-Enter; return }

    $names = $files | ForEach-Object { $_.Name }
    $sel = Show-Menu -Header '选择要删除的备份' -Options $names
    if (-not $sel) { return }

    $confirmDel = Show-Menu -Header "确认删除 $sel？删除后不可恢复" -Options @('确认删除', '取消')
    if ($confirmDel -ne '确认删除') { return }

    $targetPath = Join-Path $root $sel
    try { Remove-Item $targetPath -Force; UI-OK "删除成功: $sel" } catch { UI-Err "删除失败: $_" }
    Press-Enter
}

function Backup-RestoreMenu {
    while ($true) {
        Clear-Host
        UI-Header "备份与还原"
        Show-BackupFileList | Out-Null

        $opts = @('备份记忆全量', '还原记忆全量',
                  '备份 OpenClaw 项目', '还原 OpenClaw 项目（高风险）',
                  '删除备份文件', '返回')
        $choice = Show-Menu -Header '选择操作' -Options $opts
        switch ($choice) {
            '备份记忆全量'                   { Backup-Memory }
            '还原记忆全量'                   { Restore-Memory }
            '备份 OpenClaw 项目'             { Backup-Project }
            '还原 OpenClaw 项目（高风险）'   { Restore-Project }
            '删除备份文件'                   { Delete-BackupFile }
            default { break }
        }
        if ($choice -eq '返回' -or -not $choice) { break }
    }
}



function Update-OpenClaw {
    UI-Info "正在通过官方脚本更新 OpenClaw..."
    try {
        $script = (New-Object Net.WebClient).DownloadString('https://openclaw.ai/install.ps1')
        Invoke-Expression $script
    } catch {
        UI-Err "更新失败: $_"
        Press-Enter; return
    }
    Refresh-Path
    Start-Gateway
    UI-OK "更新完成"
    Press-Enter
}

function Uninstall-OpenClaw {
    $confirm = Read-Host '  确认卸载 OpenClaw？此操作不可逆 (y/N)'
    if ($confirm -ne 'y') { return }

    Stop-Gateway
    Disable-Autostart-OC

    try { openclaw uninstall 2>$null } catch {}
    npm uninstall -g openclaw 2>$null

    if (Test-Path $script:OpenClawHome) {
        Remove-Item $script:OpenClawHome -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Colored "  卸载完成，脚本已退出。" Green
    exit 0
}



function Main-Menu {
    while ($true) {
        Clear-Host

        $installed = if (Get-Command openclaw -ErrorAction SilentlyContinue) { '已安装' } else { '未安装' }
        $running = '未运行'
        if ($installed -eq '已安装') {
            try {
                $gwOut = cmd /c openclaw gateway status 2>&1 | Out-String
                if ($gwOut -match 'running|active|listening') { $running = '运行中' }
            } catch {}
            if ($running -eq '未运行') {
                $portCheck = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
                if ($portCheck) { $running = '运行中' }
            }
        }

        Write-Host ""
        Write-Colored "  ╔══════════════════════════════════════════╗" Cyan
        Write-Colored "  ║         O P E N C L A W                 ║" Cyan
        Write-Colored "  ║    [ AI Agent Gateway Manager ]         ║" Cyan
        Write-Colored "  ╚══════════════════════════════════════════╝" Cyan
        Write-Host "  输入 " -NoNewline
        Write-Host "oc" -NoNewline -ForegroundColor Yellow
        Write-Host " 可快速启动本脚本" -ForegroundColor DarkGray
        Write-Host "  状态: " -NoNewline
        Write-Host "$installed" -NoNewline -ForegroundColor $(if ($installed -eq '已安装') { 'Green' } else { 'Red' })
        Write-Host "  |  " -NoNewline
        Write-Host "$running" -ForegroundColor $(if ($running -eq '运行中') { 'Green' } else { 'Red' })
        Write-Host ""
        Write-Colored "  ╔══════════════════════════════════════════╗" Magenta
        Write-Colored "  ║  by Joey     GitHub: byJoey              ║" Magenta
        Write-Colored "  ║  YouTube: @joeyblog                      ║" Magenta
        Write-Colored "  ║  Telegram: t.me/+ft-zI76oovgwNmRh       ║" Magenta
        Write-Colored "  ║  基于：kejilion · cliproxyapi-installer  ║" Magenta
        Write-Colored "  ╚══════════════════════════════════════════╝" Magenta
        Write-Host ""

        $ocAutostart = Get-AutostartStatus $script:TaskNameOC
        $cpAutostart = Get-AutostartStatus $script:TaskNameCP
        $autostartLabel = "开机自启动 [OC:$ocAutostart | CP:$cpAutostart]"

        $menuItems = @(
            '小白模式安装（推荐）'
            '安装 OpenClaw'
            '启动'
            '停止'
            '状态日志查看'
            $autostartLabel
            '换模型'
            'API 管理'
            'CLIProxyAPI 管理'
            '机器人连接对接'
            '安装插件'
            '安装技能'
            '健康检测与修复'
            'WebUI访问与设置'
            'TUI 命令行对话'
            '备份与还原'
            '编辑主配置文件'
            '配置向导'
            '更新'
            '卸载'
            '退出'
        )

        $choice = Show-Menu -Header '─── CONTROL CENTER ───' -Options $menuItems

        switch ($choice) {
            '小白模式安装（推荐）' { Beginner-Install }
            '安装 OpenClaw'         { Install-OpenClaw; Press-Enter }
            '启动'                 { Start-Gateway; Press-Enter }
            '停止'                 { Stop-Gateway; Press-Enter }
            '状态日志查看' {
                try { openclaw status 2>$null } catch { UI-Warn "openclaw 未安装" }
                try { openclaw gateway status 2>$null } catch {}
                try { openclaw logs 2>$null } catch {}
                Press-Enter
            }
            { $_ -like '开机自启动*' } { Toggle-Autostart; Press-Enter }
            '换模型'               { Change-Model }
            'API 管理'             { API-Manage-Menu }
            'CLIProxyAPI 管理'     { CLIProxy-ManageMenu }
            '机器人连接对接'       { Connect-Bot }
            '安装插件'             { Install-Plugin }
            '安装技能'             { Install-Skill }
            '健康检测与修复'       { Doctor-Fix }
            'WebUI访问与设置'      { WebUI-Menu }
            '备份与还原'           { Backup-RestoreMenu }
            '编辑主配置文件' {
                if (Test-Path $script:OpenClawJson) {
                    Start-Process notepad $script:OpenClawJson -Wait
                    Start-Gateway
                } else { UI-Err "openclaw.json 不存在" }
                Press-Enter
            }
            '配置向导' {
                try { openclaw onboard --install-daemon 2>$null } catch { UI-Err "openclaw 未安装" }
                Press-Enter
            }
            'TUI 命令行对话' {
                try { openclaw tui } catch { UI-Err "openclaw 未安装" }
                Press-Enter
            }
            '更新'   { Update-OpenClaw }
            '卸载'   { Uninstall-OpenClaw }
            '退出'   { return }
            default  { return }
        }
    }
}



function Install-Shortcut {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

    $markerV2 = '# openclawctl-oc-v2'
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if (-not $profileContent -or $profileContent -notmatch [regex]::Escape($markerV2)) {
        $block = @"

$markerV2
function oc { irm https://raw.githubusercontent.com/byJoey/openclawctl/main/openclaw.ps1 | iex }
"@
        Add-Content -Path $profilePath -Value $block -Encoding UTF8
    }
}

Install-Shortcut



Main-Menu
