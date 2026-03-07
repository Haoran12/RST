# RST v0.2

RST 是一个面向本地部署的角色扮演/长对话辅助工具，核心目标是提升长对话场景下的上下文一致性与设定稳定性。  
项目采用前后端分离架构，支持开发模式与发布模式（无命令行窗口启动）。

## 主要功能

1. 会话与消息管理
- 支持会话创建、切换、重命名、删除。
- 支持消息编辑、删除、可见性控制，用于提示词组装与调度。

2. Preset 与 Prompt 组装
- 提供可配置的 Prompt 条目与顺序管理。
- 支持系统条目与用户条目协同组装，便于不同玩法快速切换。

3. RST Lore（设定与状态）
- 支持结构化设定管理与按上下文检索注入。
- 适合长对话中的世界观、角色状态、关系变化追踪。

4. 双 API 配置
- 区分主对话 API 与调度器 API。
- 支持模型参数配置与模型列表获取，可手动填写模型名。

5. 请求日志与排障
- 记录请求与响应的关键信息，便于排查模型调用问题。

6. 本地安全存储
- API Key 采用本地加密存储，不以明文落盘。
- 提供发布前安全检查脚本，降低敏感信息误提交风险。

## 技术栈

- 后端：FastAPI + uv
- 前端：Vue 3 + Vite + pnpm
- 本地存储：项目本地数据 + SQLite（新建会话的 Lore/运行时数据默认使用 SQLite）

## 安装（Windows）

### 环境要求

- Windows 10/11
- Python 3.12+
- Node.js 18+

> `scripts\setup.bat` 会优先检查环境，缺少 Python/Node 时会尝试自动安装，并完成依赖安装。

### 安装步骤

1. 克隆项目并进入目录
```bat
git clone https://github.com/Haoran12/RST.git
cd RST
```

2. 一键安装依赖
```bat
scripts\setup.bat
```

3. 首次会自动生成 `.env`（来自 `.env.example`）。

## 启动方式

### 方式一：开发模式（用于开发调试）

```bat
scripts\dev.bat
```

- 前端地址：`http://localhost:15173`
- 后端健康检查：`http://127.0.0.1:18080/health`

### 方式二：发布模式（无命令行窗口）

1. 发布前安全检查
```bat
scripts\release_check.bat
```

2. 构建前端
```bat
scripts\release_build.bat
```

3. 双击启动（后台运行，不弹命令行）
- `scripts\release_start.vbs`

4. 打开应用
- `http://127.0.0.1:18080/`

5. 双击停止
- `scripts\release_stop.vbs`

### 分发包（可直接发给他人的 zip）

执行：

```bat
scripts\release_package.bat
```

会生成：
- 目录：`release\RST-v0.2-quickstart\`
- 压缩包：`release\RST-v0.2-quickstart.zip`

在打包后的目录中：
- 首次运行：`scripts\release_quick_start.bat`
- 或仅安装运行时：`scripts\setup_release.bat`

### 发布到 GitHub Release

如果你要把本地打好的 zip 同步到 GitHub Release：

```powershell
$env:GITHUB_TOKEN = "<github-token>"
scripts\release_publish.ps1 -Tag v0.2 -Title "RST v0.2" -NotesFile docs\release-notes-v0.2.md -AssetPath release\RST-v0.2-quickstart.zip
```

说明：
- `GITHUB_TOKEN` 需要具备创建或更新 Release 的权限。
- 如果同标签的 Release 已存在，脚本会更新说明并替换同名资产。
- 省略 `-AssetPath` 时，默认使用 `release\RST-v0.2-quickstart.zip`。

## 首次使用建议

1. 打开应用后先配置 API（Provider、Base URL、API Key、Model）。
2. 创建或选择会话。
3. 根据需求切换 Preset 与 RST 模式配置。

## 常用脚本

- `scripts\setup.bat`：安装或更新依赖
- `scripts\dev.bat`：开发模式启动
- `scripts\test.bat`：运行测试
- `scripts\lint.bat`：代码检查
- `scripts\release_check.bat`：发布前安全检查
- `scripts\release_build.bat`：构建发布前端资源
- `scripts\release_package.bat`：生成可分发的 quickstart 目录与 zip
- `scripts\release_publish.ps1`：更新 GitHub Release 并上传 zip 资产
- `scripts\release_start.vbs`：发布模式后台启动（无窗口）
- `scripts\release_stop.vbs`：发布模式停止

## 安全说明

- 不要提交 `.env` 或 `.env.*`，仅保留 `.env.example`。
- 不要提交运行时数据目录：`data/`、`_tmp_llm_import_data/`、`release/`。
- 打包或发布前建议执行一次：
```bat
scripts\release_check.bat
```

## 关键环境变量

基于 `.env.example` 调整：

- `RST_BACKEND_PORT`：后端端口，默认 `18080`
- `RST_BACKEND_RELOAD`：是否热重载，开发建议 `1`，发布建议 `0`
- `RST_SERVE_FRONTEND`：后端是否托管前端静态资源，发布模式建议 `1`
- `RST_FRONTEND_DIST`：前端构建目录，默认 `./frontend/dist`
