

# RST（Reg's SmartTavern）开发计划书

## 0. 文档说明

本计划书基于《RST 总体架构与技术选型》编制，将系统拆分为 6 个里程碑（Milestone），每个里程碑包含明确的交付物、验收标准与预估工期。开发采用单人或小团队节奏，按周迭代。

---

## 1. 总体阶段划分

| 里程碑 | 名称 | 核心目标 | 预估工期 |
|---|---|---|---|
| M0 | 工程脚手架 | 前后端项目初始化、目录规范、CI 基础 |
| M1 | 基础对话闭环 | Session + API + Preset 最小可用，能完成一轮对话 |
| M2 | 配置管理面板 | 统一侧边 Panel 完成 5 类配置的 CRUD |
| M3 | RST Lore 存储与编辑 | Lore 数据模型、文件读写、前端编辑器 |
| M4 | Lore 调度器 | 上下文扫描 → 元数据检索 → LLM 筛选 → 注入 |
| M5 | 打磨与兼容 | ST/RST 模式切换、Appearance、安全加固、测试 |

---

## 2. M0 — 工程脚手架（第 1 周）

### 目标
搭建前后端项目骨架，统一开发规范，确保本地一键启动。

### 任务清单

| # | 任务 | 说明 |
|---|---|---|
| 0.1 | 初始化后端项目 | ≥Python 3.12, FastAPI, uvicorn, pyproject.toml, ruff/mypy 配置 |
| 0.2 | 初始化前端项目 | Vite + Vue 3 + TypeScript + Pinia + Vue Router, ESLint/Prettier |
| 0.3 | 确定目录结构 | 后端按 `routers/ services/ models/ storage/` 分层；前端按 `views/ components/ stores/ api/ types/` 分层 |
| 0.4 | 数据目录初始化 | 启动时自动创建 `data/sessions/`, `data/presets/`, `data/api_configs/`, `data/appearance/` |
| 0.5 | 开发脚本 | Makefile 或 scripts/：`dev`（前后端并行启动）、`lint`、`test` |
| 0.6 | 基础 CORS 与代理 | Vite dev proxy → FastAPI；FastAPI CORS 中间件 |

### 交付物
- 前后端可同时启动，浏览器访问到空白 Shell 页面
- 后端 `/health` 接口返回 200

### 建议目录结构

```
rst/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI 入口
│   │   ├── routers/             # 路由层
│   │   ├── services/            # 业务逻辑层
│   │   ├── models/              # Pydantic 数据模型
│   │   ├── storage/             # 文件读写、原子写入、锁
│   │   └── providers/           # LLM API 适配器
│   ├── tests/
│   └── pyproject.toml
├── frontend/
│   ├── src/
│   │   ├── views/               # 页面级组件
│   │   ├── components/          # 通用 & 业务组件
│   │   ├── stores/              # Pinia stores
│   │   ├── api/                 # 后端请求封装
│   │   ├── types/               # TypeScript 类型
│   │   └── styles/              # SCSS + CSS Variables
│   ├── index.html
│   └── vite.config.ts
└── data/                        # 运行时数据（gitignore）├── sessions/
    ├── presets/
    ├── api_configs/
    └── appearance/
```

---

## 3. M1 — 基础对话闭环（第 2–4 周）

### 目标
实现最小可用的对话系统：创建会话 → 输入消息 → 组装 Prompt → 调用 LLM → 流式返回 → 保存消息。

### 第 2 周：数据模型 + 存储层 + API 配置

| # | 任务 | 说明 |
|---|---|---|
| 1.1 | 定义核心 Pydantic 模型 | `SessionMeta`, `Message`, `ApiConfig`, `PresetEntry`, `Preset` |
| 1.2 | 实现 `storage/` 基础工具 | `atomic_write()`, `read_json()`, `write_json()`, 文件锁（`threading.Lock` per path） |
| 1.3 | API 配置 CRUD | `POST/GET/PUT/DELETE /api/api-configs/{id}` |
| 1.4 | API Key 加密存储 | 使用 `cryptography.fernet` 对称加密，密钥从环境变量或本地 keyfile 读取 |
| 1.5 | 模型列表获取 | `GET /api/api-configs/{id}/models` → 根据 provider 类型调用对应 list-models 接口 |

核心数据模型定义：

```python
# backend/app/models/api_config.py
from pydantic import BaseModel
from enum import Enum
from typing import Optional

class ProviderType(str, Enum):
    OPENAI = "openai"
    GEMINI = "gemini"
    DEEPSEEK = "deepseek"
    ANTHROPIC = "anthropic"
    OPENAI_COMPAT = "openai_compat"

class ApiConfig(BaseModel):
    id: str
    name: str
    provider: ProviderType
    base_url: str
    encrypted_key: str          # 加密后的 key
    model: str = ""
    temperature: float = 0.7
    max_tokens: int = 4096
    stream: bool = True
    version: int = 1
```

```python
# backend/app/models/session.py
from pydantic import BaseModel
from typing import Literal, Optional
from datetime import datetime

class SessionMeta(BaseModel):
    name: str
    mode: Literal["ST", "RST"] = "RST"
    user_description: str = ""
    scan_depth: int = 4
    mem_length: int = 40
    created_at: datetime
    updated_at: datetime
    main_api_config_id: str
    scheduler_api_config_id: Optional[str] = None
    preset_id: str
    version: int = 1

class Message(BaseModel):
    id: str                     # uuid
    role: Literal["system", "user", "assistant"]
    content: str
    timestamp: datetime
    visible: bool = True
```

```python
# backend/app/models/preset.py
from pydantic import BaseModel
from typing import Literal, Optional

class PresetEntry(BaseModel):
    name: str
    role: Literal["system", "user", "assistant"] = "system"
    content: str = ""
    disabled: bool = False
    comment: str = ""

# 系统保留条目名称
SYSTEM_ENTRIES = [
    "Main_Prompt", "lores", "user_description",
    "chat_history", "scene", "user_input"
]

class Preset(BaseModel):
    id: str
    name: str
    entries: list[PresetEntry]
    version: int = 1
```

### 第 3 周：Session + Preset + Prompt 组装

| # | 任务 | 说明 |
|---|---|---|
| 1.6 | Session CRUD | 创建/列表/读取/删除/重命名会话，自动创建 `rst_data/` 子目录 |
| 1.7 | 消息 CRUD | 追加/编辑/删除/切换可见性，写入 `messages.json` |
| 1.8 | Preset CRUD | 新建时自动填充 6 个系统条目；保存时校验系统条目完整性并自动补齐 |
| 1.9 | Prompt 组装器 | `PromptAssembler.build(session, preset, lores_block, user_input) -> list[dict]`，按 Preset 条目顺序拼装，系统条目从对应数据源填充 |

Prompt 组装器核心逻辑：

```python
# backend/app/services/prompt_assembler.py
class PromptAssembler:
    def build(
        self,
        session: SessionMeta,
        preset: Preset,
        messages: list[Message],
        lores_block: str,       # 由调度器生成，M1 阶段为空串
        user_input: str,
    ) -> list[dict]:
        """按 Preset 条目顺序组装 messages 数组"""
        result = []
        for entry in preset.entries:
            if entry.disabled:
                continue
            content = self._resolve_content(
                entry, session, messages, lores_block, user_input
            )
            if content:
                result.append({"role": entry.role, "content": content})
        return result

    def _resolve_content(self, entry, session, messages, lores_block, user_input):
        match entry.name:
            case "chat_history":
                return None  # 特殊处理：展开为多条 message
            case "lores":
                return lores_block or None
            case "user_description":
                return session.user_description or None
            case "user_input":
                return user_input
            case "scene":
                return ""    # M4 阶段由调度器填充
            case _:
                return entry.content or None
```

> 注：`chat_history` 需要特殊处理——不是插入单条 message，而是将最近 `mem_length` 条可见消息展开插入到该位置。组装器在遇到 `chat_history` 条目时，将消息列表按原始 role 逐条插入 result。

### 第 4 周：Provider 适配 + 流式对话 + 前端对话界面

| # | 任务 | 说明 |
|---|---|---|
| 1.10 | Provider 适配器 | 抽象 `BaseProvider`，实现 `OpenAIProvider`（兼容 Deepseek/OpenAI_Compat）、`AnthropicProvider`、`GeminiProvider` |
| 1.11 | 流式对话接口 | `POST /api/sessions/{name}/chat` → SSE 流式返回 |
| 1.12 | 前端对话页面 | 消息列表 + 输入框 + 流式渲染 + 消息编辑/删除/可见性切换 |
| 1.13 | 前端 API 配置页 | 简易表单，选择 Provider 自动填充 Base URL，测试连接 + 拉取模型列表 |

Provider 适配器接口：

```python
# backend/app/providers/base.py
from abc import ABC, abstractmethod
from typing import AsyncIterator

class BaseProvider(ABC):
    @abstractmethod
    async def chat_stream(
        self, messages: list[dict], **kwargs
    ) -> AsyncIterator[str]:
        """流式返回文本 chunk"""
        ...

    @abstractmethod
    async def chat(
        self, messages: list[dict], **kwargs
    ) -> str:
        """非流式返回完整文本"""
        ...

    @abstractmethod
    async def list_models(self) -> list[str]:
        ...
```

### M1 验收标准
- 能创建会话、选择 API 配置和 Preset
- 输入消息后流式收到 LLM 回复
- 消息持久化到 `messages.json`，刷新后恢复
- 可编辑/删除/隐藏消息

---

## 4. M2 — 配置管理面板（第 5–6 周）

### 目标
实现统一的侧边折叠 Panel，管理 5 类配置（Session, API, Preset, Lore, Appearance）的 CRUD。

### 第 5 周：统一 Panel 框架 + Session/API/Preset 管理

| # | 任务 | 说明 |
|---|---|---|
| 2.1 | 侧边 Panel 框架 | 左侧图标栏（5 个图标），点击展开对应 Panel，再次点击或点击其他图标折叠 |
| 2.2 | Panel 通用组件 | `ConfigPanel` 组件：列表视图（新建/删除/重命名）+ 详情编辑视图，支持 slot 自定义 |
| 2.3 | Session Panel | 会话列表 + 会话设置（mode, scan_depth, mem_length, 关联的 API/Preset 选择） |
| 2.4 | API Config Panel | 配置列表 + 编辑表单（Provider 选择 → 自动填充 URL → Key 输入 → 测试 → 模型选择） |
| 2.5 | Preset Panel | Preset 列表 + 条目拖拽排序 + 条目编辑（系统条目 content 只读灰显）+ 新增/删除自定义条目 |

Panel 组件结构：

```
components/
├── panels/
│   ├── PanelShell.vue          # 侧边栏容器，管理展开/折叠状态
│   ├── ConfigPanel.vue         # 通用 CRUD 列表 + 详情框架
│   ├── SessionPanel.vue
│   ├── ApiConfigPanel.vue
│   ├── PresetPanel.vue
│   ├── LorePanel.vue           # M3 实现
│   └── AppearancePanel.vue     # M5 实现
```

### 第 6 周：交互打磨 + 状态同步

| # | 任务 | 说明 |
|---|---|---|
| 2.6 | Pinia Store 设计 | `useSessionStore`, `useApiConfigStore`, `usePresetStore`，统一 CRUD action 模式 |
| 2.7 | 实时保存 | 编辑后失焦后自动保存，保存失败指示 |
| 2.8 | 删除确认与保护 | 删除配置时二次确认；正在使用的配置不可删除 |
| 2.9 | 键盘与无障碍 | Panel 支持 Esc 关闭、Tab 导航、aria 标签 |

### M2 验收标准
- 左侧图标栏可展开/折叠各 Panel
- 每类配置可新建、重命名、删除、编辑
- Preset 条目可拖拽排序，系统条目不可删除/改名
- 编辑自动保存，刷新后状态一致
- 批量删除条目与复制条目功能
---

## 5. M3 — RST Lore 存储与编辑（第 7–8 周）

### 目标
实现 Lore 数据模型、文件存储、前端编辑器，为 M4 调度器提供数据基础。

### 第 7 周：Lore 数据模型 + 后端 CRUD

| # | 任务 | 说明 |
|---|---|---|
| 3.1 | Lore 条目模型 | `LoreEntry`: name, category, content, disabled, constant, tags[] |
| 3.2 | Lore 文件模型 | Character 文件包含多个 section（基础设定 + 动态状态）；其他范畴文件包含多个条目 |
| 3.3 | Lore 存储服务 | 按 session 读写 `rst_data/` 下的文件，支持单条目级别的增删改查 |
| 3.4 | Lore REST API | `GET/POST/PUT/DELETE /api/sessions/{name}/lores/{category}/{entry_id}` |
| 3.5 | 元数据索引 | 启动或会话加载时扫描 Lore 文件，建立 `{tag -> entry_id[]}` 和 `{name -> entry_id}` 的内存索引 |

Lore 数据模型：

```python
# backend/app/models/lore.py
from pydantic import BaseModel
from typing import Literal, Optional

LoreCategory = Literal[
    "world_base", "society", "place",
    "faction", "character", "skills", "others"
]

class LoreEntry(BaseModel):
    id: str                     # uuid
    name: str
    category: LoreCategory
    content: str
    disabled: bool = False
    constant: bool = False      # constant 条目始终注入
    tags: list[str] = []

class LoreFile(BaseModel):
    """非 character 范畴的文件结构"""
    category: LoreCategory
    entries: list[LoreEntry]
    version: int = 1

class CharacterFile(BaseModel):
    """character 范畴：一个角色一个文件"""
    character_id: str
    name: str
    entries: list[LoreEntry]    # 基础设定 + 动态状态分条目
    version: int = 1
```

文件存储映射：

```
sessions/{session_name}/rst_data/
├── world_base.json             # LoreFile
├── society.json                # LoreFile
├── place.json                  # LoreFile
├── faction.json                # LoreFile
├── skills.json                 # LoreFile
├── others.json                 # LoreFile
├── characters/
│   ├── {character_id}.json     # CharacterFile
│   └── ...
└── .index/                     # 索引缓存（可重建）
    └── metadata.json
```

### 第 8 周：前端 Lore 编辑器

| # | 任务 | 说明 |
|---|---|---|
| 3.6 | Lore Panel | 左侧树形导航：按 category 分组，character 下按角色分组 |
| 3.7 | 条目编辑器 | 表单：name, category(只读), tags(标签输入), content(文本域), disabled/constant 开关 |
| 3.8 | Character 编辑器 | 角色概览 + 条目列表，支持新增/删除条目 |
| 3.9 | 批量操作 | 支持批量启用/禁用条目 |
| 3.10 | 搜索与过滤 | 按 name/tag/category 搜索条目 |

### M3 验收标准
- 可在 Lore Panel 中按范畴浏览、新增、编辑、删除条目
- Character 文件独立存储，支持多条目
- 条目修改实时保存到 JSON 文件
- 元数据索引可用于按 tag/name 快速查找

---

## 6. M4 — Lore 调度器（第 9–11 周）

### 目标
实现核心差异化功能：根据最近对话上下文，智能检索并注入相关 Lore 条目。

### 第 9 周：检索管线

| # | 任务 | 说明 |
|---|---|---|
| 4.1 | 上下文提取 | 取最近 `scan_depth` 条可见消息，提取关键词、实体名、地点名 |
| 4.2 | 元数据匹配 | 用 tags/name 与提取的关键词做交集匹配，返回候选条目集 |
| 4.3 | Constant 条目 | `constant=True` 的条目始终加入候选集 |
| 4.4 | 候选排序 | 按匹配度（tag 命中数 + name 精确匹配权重）排序，取 Top-K |

### 第 10 周：LLM 二次筛选 + 注入块生成

| # | 任务 | 说明 |
|---|---|---|
| 4.5 | 筛选 Prompt 设计 | 将候选条目摘要 + 最近消息发送给调度器 LLM，要求其判断每条的相关性并输出精简摘要 |
| 4.6 | 调度器 LLM 调用 | 使用 `scheduler_api_config_id` 对应的 API 配置，非流式调用 |
| 4.7 | 注入块格式化 | 将 LLM 筛选结果格式化为结构化文本块，填入 Preset 的 `lores` 位置 |
| 4.8 | Scene 生成 | 从调度器结果中提取当前时间/地点/场景信息，填入 `scene` 条目 |

调度器核心流程：

```python
# backend/app/services/lore_scheduler.py
class LoreScheduler:
    async def schedule(
        self,
        session: SessionMeta,
        messages: list[Message],
        lore_index: LoreIndex,
    ) -> ScheduleResult:
        # 1. 取最近 scan_depth 条可见消息
        recent = [m for m in messages if m.visible][-session.scan_depth:]

        # 2. 提取关键词/实体
        keywords = self._extract_keywords(recent)

        # 3. 元数据匹配 + constant 条目
        candidates = lore_index.match(keywords)
        candidates += lore_index.get_constants()

        # 4. 排序取 Top-K
        candidates = self._rank_and_truncate(candidates, max_k=30)

        # 5. LLM 二次筛选
        filtered = await self._llm_filter(recent, candidates)

        # 6. 格式化输出
        return ScheduleResult(
            lores_block=self._format_lores(filtered),
            scene_block=self._format_scene(filtered),
        )
```

### 第 11 周：Lore 动态更新 + 集成测试

| # | 任务 | 说明 |
|---|---|---|
| 4.9 | 状态变化抽取 | 对话完成后，异步调用 LLM 分析最新消息中的状态变化（人物位置、关系、事件等） |
| 4.10 | 条目更新写入 | 将变化归类到对应条目，更新 content 或新增条目，写回文件 |
| 4.11 | 更新确认机制 | 可选：更新前弹出 diff 预览，用户确认后写入（降低设定漂移风险） |
| 4.12 | 索引刷新 | 条目变更后增量更新内存索引 |
| 4.13 | 端到端集成测试 | 完整对话流程：输入 → 调度 → 组装 → 调用 → 回复 → 更新，验证 Lore 注入正确性 |

### M4 验收标准
- 对话时自动触发 Lore 调度，相关条目被注入 Prompt
- Constant 条目始终注入
- 对话后异步更新动态状态，变更可在 Lore Panel 中查看
- 可选的人工确认更新机制可用

---

## 7. M5 — 打磨与兼容（第 12–13 周）

### 第 12 周：ST/RST 模式 + Appearance

| # | 任务 | 说明 |
|---|---|---|
| 5.1 | ST/RST 模式切换 | Session 设置中切换 mode；ST 模式下隐藏 Lore Panel、禁用调度器、Preset 仅保留 ST 兼容条目 |
| 5.2 | Appearance 数据模型 | 主题 JSON：primary_color, bg_color, font_family, font_size, chat_bubble_style 等 |
| 5.3 | Appearance Panel | 主题列表 + 可视化编辑器（颜色选择器、字体选择、预览） |
| 5.4 | CSS Variables 热更新 | 切换主题时动态更新 `:root` CSS Variables，无需刷新 |

### 第 13 周：安全加固 + 测试 + 文档

| # | 任务 | 说明 |
|---|---|---|
| 5.5 | API Key 安全审计 | 确认 Key 不出现在日志、前端响应、错误信息中；前端显示时脱敏 |
| 5.6 | 文件写入健壮性 | 原子写入 + .bak 备份全面覆盖；异常恢复测试 |
| 5.7 | 后端单元测试 | 覆盖 storage、prompt_assembler、lore_scheduler 核心逻辑，目标覆盖率 ≥ 80% |
| 5.8 | 前端组件测试 | 关键交互组件（Panel、Preset 编辑器、消息列表）的 Vitest + Vue Test Utils 测试 |
| 5.9 | 用户文档 | README：安装、配置、使用指南；开发者文档：架构说明、API 文档（FastAPI 自动生成） |
| 5.10 | 打包与部署 | Docker Compose 一键部署；或 `pip install` + `npm run build` 的纯本地部署方式 |

### M5 验收标准
- ST 模式下行为与 SillyTavern 兼容（无 Lore 调度、简化 Preset）
- 主题切换即时生效
- API Key 全链路脱敏
- 核心模块测试覆盖 ≥ 80%
- Docker Compose 一键启动可用

---

## 8. 风险管理

| 风险 | 影响 | 概率 | 对策 | 负责阶段 |
|---|---|---|---|---|
| Lore 动态更新导致设定漂移 | 高 | 中 | 人工确认 + diff 预览 + 回滚机制 | M4 |
| 调度器召回不准（漏注入/噪声注入） | 高 | 中 | 多级检索（tag + 关键词 + LLM 筛选）；后续可引入向量检索 | M4 |
| JSON 并发读写冲突 | 中 | 低 | 后端 per-file 锁 + 原子写入 | M0/M1 |
| LLM 调用延迟影响体验 | 中 | 高 | 主对话流式返回；调度器/更新异步执行不阻塞 UI | M1/M4 |
| Provider API 差异导致适配问题 | 低 | 中 | 抽象 BaseProvider + 充分的集成测试 | M1 |

---

## 9. 技术债务与后续演进

以下内容不在本期计划范围内，但需在开发中预留扩展点：

1. 向量检索：`.index/` 目录已预留，后续可引入 FAISS 或 sqlite-vss 增强语义召回
2. 插件系统：Provider 适配器模式天然支持扩展，后续可开放自定义 Provider 注册
3. 数据迁移：所有 JSON 文件包含 `version` 字段，后续 schema 变更时编写迁移脚本
4. 多语言 UI：前端文案抽取为 i18n key，当前仅实现中文
5. 战斗/数值系统：可作为独立 service 模块接入 Lore 体系

---

## 10. 里程碑总览时间线

```
Week  1        2        3        4        5        6        7        8        9       10       11       12       13|--------|--------|--------|--------|--------|--------|--------|--------|--------|--------|--------|--------|
M0    [=]
M1             [=============================]
M2                                           [=================]
M3                                                              [=================]
M4                                                                 [===========================]
M5                                                [=================]
```

每个里程碑结束时进行内部验收，确认交付物满足验收标准后进入下一阶段。M1 结束即可获得最小可用产品，后续里程碑逐步叠加核心差异化能力。