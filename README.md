# DSH 开机自启与快捷方式配置

本仓库存放 DeepSeek Harness (DSH) 的 Windows 本地配置：开机自动启动、桌面/开始菜单快捷方式及相关脚本。

## 目录结构

```
D:\DSH
├── scripts/                         # 启动与配置脚本
│   ├── dsh-launch.js                # Node.js 启动器（动态路径，跨机器可用）
│   ├── dsh-launch.vbs               # 隐藏窗口包装（wscript 调用，动态路径）
│   ├── deploy.ps1                   # ★ 新电脑一键部署脚本
│   ├── make-shortcuts.ps1           # 生成三个快捷方式的脚本（-RepoRoot 参数）
│   ├── make-icon.ps1                # 生成快捷方式图标的脚本（-RepoRoot 参数）
│   ├── dsh-launch.ps1               # 旧的 PowerShell 启动器（已弃用，保留参考）
│   └── enable-defender-exclusions.ps1  # 管理员运行：添加 Defender 排除项
├── assets/
│   ├── dsh.ico                      # 快捷方式图标
│   └── dsh-icon.png                 # 图标源图（中间产物）
└── logs/                            # 运行日志（不入库）
```

## 开机启动机制（用户登录时）

1. **注册表 Run 键**（`HKCU\...\CurrentVersion\Run` 的 `DSH Server`）：
   `"C:\Windows\System32\wscript.exe" "D:\DSH\scripts\dsh-launch.vbs" server`
   → 登录瞬间后台启动 DSH 服务（`dsh web --no-open`，隐藏窗口）。
2. **开机启动文件夹**快捷方式 `DSH 开机自启.lnk`（open 模式）：
   等服务 HTTP 就绪后自动打开浏览器进入 `http://127.0.0.1:3080`；
   若 12 秒内服务未就绪，会自动回退自行启动服务。
3. **桌面 / 开始菜单**快捷方式（full 模式）：服务未运行则先启动，再打开界面。

## dsh-launch.js 模式

| 模式 | 行为 | 使用者 |
|---|---|---|
| 默认（full） | 确保服务运行 → 打开浏览器 | 桌面/开始菜单快捷方式 |
| `--server-only` | 只确保服务运行，不开浏览器 | Run 键登录自启 |
| `--open-only` | 不启动服务，等就绪后开浏览器（超时回退自启） | 开机启动文件夹 |

日志：`logs/dsh-launch.log`（启动器，毫秒级时间戳）；`logs/dsh-server.out.log`、`logs/dsh-server.err.log`（DSH 服务输出）。

## 部署到新电脑（git clone 一键配置）

所有脚本均使用**动态路径**（从自身位置推导仓库根目录、从 PATH 解析 node、自动发现 dsh 安装位置），因此 clone 到任意目录、任意用户名的机器都能直接工作。

```powershell
# 1. 新电脑安装 Node.js LTS：https://nodejs.org
# 2. 克隆仓库（SSH 或 HTTPS 均可）
git clone git@github.com:Littleyang24/dsh-setup.git
# 3. 一键部署
cd dsh-setup
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
```

`deploy.ps1` 会自动完成：

1. 定位 Node.js，缺失则报错并提示安装；已安装则确保其目录在用户 PATH 中
2. 检测 `@deepseek-ai/dsh` 全局安装，缺失时自动 `npm install -g`（可用 `-InstallDsh` 强制重装）
3. 写入注册表 Run 键 `DSH Server`（登录即后台启动服务）
4. 生成快捷方式图标并创建三个快捷方式（启动文件夹 / 桌面 / 开始菜单）
5. （可选）`-DefenderExclusions`：以管理员身份添加 Defender 排除项，消除冷启动扫描延迟

部署完成后注销/重启一次即可：登录后浏览器自动打开 `http://127.0.0.1:3080`。

## 提速说明

- 启动器用 Node.js 而非 PowerShell（引擎冷启动约 0.1s）。
- 服务就绪判定改为轮询真实 HTTP 响应，不再固定等待 2 秒。
- 已启用 Node 模块编译缓存（`C:\Users\xiaoy\.dsh\node-compile-cache`）。
- 若冷启动仍慢（Defender 扫描 node_modules），以管理员运行：
  `powershell -NoProfile -ExecutionPolicy Bypass -File "D:\DSH\scripts\enable-defender-exclusions.ps1"`

## 常用命令

```powershell
# 手动启动并打开界面（等价于双击桌面快捷方式）
wscript.exe "D:\DSH\scripts\dsh-launch.vbs"

# 只启动服务（不开浏览器）
wscript.exe "D:\DSH\scripts\dsh-launch.vbs" server
```
