# OpenClaw ctl

OpenClaw / MoltBot 的管理脚本，把常用操作都包进了一个交互式菜单里，省得每次手打命令。

支持 macOS（Intel / Apple Silicon）和主流 Linux 发行版。

作者：Joey  
YouTube：[@joeyblog](https://youtube.com/@joeyblog)  
Telegram 交流群：https://t.me/+ft-zI76oovgwNmRh  
基于：[kejilion](https://github.com/kejilion) 的原始脚本 + [cliproxyapi-installer](https://github.com/brokechubb/cliproxyapi-installer)

---

## 能做什么

- 一键安装全套（OpenClaw + CLIProxyAPI + OAuth + 自动配置）
- OpenClaw 的启动、停止、更新、卸载
- API 提供商管理，模型同步，模型切换
- CLIProxyAPI 的完整管理（服务控制、账号登录、Key 管理）
- 对接机器人（Telegram、飞书、钉钉等）
- 插件和技能安装
- 备份与还原
- 健康检测

---

## 系统要求

| 系统 | 支持情况 |
|------|---------|
| macOS Apple Silicon | 完整支持，依赖通过 Homebrew 自动安装 |
| macOS Intel | 完整支持，依赖通过 Homebrew 自动安装 |
| Ubuntu / Debian | 完整支持 |
| CentOS / Rocky / RHEL | 完整支持 |
| Alpine | 支持 |
| Arch Linux | 支持 |

---

## 依赖

所有依赖在首次运行时自动安装，无需手动操作：

- macOS：脚本会自动安装 Homebrew（如未安装），然后通过 brew 装其余依赖
- Linux：通过系统包管理器（apt / dnf / yum / apk / pacman）自动安装
- 依赖包括：Node.js、curl、git、nano、jq、python3、gum、fzf

---

## 用法

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/byJoey/openclawctl/main/openclaw.sh)
```

运行一次后，输入 `oc` 即可快速启动（脚本自动创建快捷方式）。

或者下载到本地再运行：

```bash
curl -fsSL https://raw.githubusercontent.com/byJoey/openclawctl/main/openclaw.sh -o openclaw.sh
chmod +x openclaw.sh
./openclaw.sh
```

---

## 小白模式

主菜单第一项，适合第一次安装。按顺序完成：

1. 安装 Node.js 和构建工具
2. `npm install -g openclaw`
3. `openclaw onboard`（交互式向导）
4. 安装 CLIProxyAPI（macOS 用 brew，Linux 用一键脚本）
5. OAuth 登录（支持 Claude / Gemini / OpenAI / Qwen / iFlow）
6. 启动 CLIProxyAPI 服务
7. 注册 CLIProxyAPI 为 API 提供商
8. 从可用模型里选一个作为默认
9. 询问是否跳转到机器人对接

装完即可用，不需要再手动改配置文件。

---

## OAuth 登录说明

### macOS

有本地浏览器，直接运行登录命令，浏览器自动打开，授权后回调自动处理，全程无需手动操作。

### Linux 服务器

服务器没浏览器，登录流程稍微绕一点，但不需要 SSH 端口转发：

1. 脚本在后台启动 `cli-proxy-api --no-browser`，终端里会打印授权 URL
2. 在本地浏览器里打开那个 URL，完成账号授权
3. 授权成功后浏览器会跳转到 `localhost:<port>/oauth2callback?code=...`，页面报连接失败，这是正常的
4. 把地址栏里的完整 URL 复制出来，粘贴到脚本的输入框里
5. 脚本用 curl 把这个回调 URL 发给服务器本地正在监听的进程，完成握手

原理就是 OAuth code 在 URL 里，不需要真的从外部访问服务器的端口。

Qwen 用的是 device flow，只需要在浏览器里输入授权码，两端都一样简单。

---

## CLIProxyAPI 管理

主菜单里有独立的「CLIProxyAPI 管理」子菜单：

| 操作 | 说明 |
|------|------|
| 启动 / 停止 / 重启 | macOS 用 brew services，Linux 优先 systemd，失败了用 nohup |
| 查看日志 | macOS 读 brew 日志，Linux 用 journalctl 或 /tmp/cliproxyapi.log |
| 账号授权登录 | 五个提供商都支持 |
| 生成并添加 API Key | 生成 sk- 格式的 key，自动写入 config.yaml |
| 查看 API Keys | 列出当前配置的 key |
| 编辑配置文件 | 打开 nano |
| 更新 | macOS 用 brew upgrade，Linux 拉最新版本 |
| 卸载 | 停服务，删目录 |

配置文件位置：

- macOS：`~/.cli-proxy-api/config.yaml`
- Linux：`~/cliproxyapi/config.yaml`

---

## 注意事项

**模型切换会重启网关。** 切完之后 OpenClaw gateway 会自动重启，Telegram 机器人有几秒不可用。

**onboard 时随便选的模型不用管。** 安装完成后脚本会让你重新选一个实际可用的模型覆盖掉，不会用 onboard 时选的那个。

**只显示可用模型。** 模型选择界面只列出状态是 `configured` 的，没配好的不会出现。

**macOS 首次运行需要网络。** 会自动安装 Homebrew，需要能访问 GitHub。

---

## 文件说明

```
openclaw.sh              主脚本，直接运行这个
```
