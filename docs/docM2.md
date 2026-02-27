# M2 — 配置管理面板 技术文档

> 版本: 1.0
> 日期: 2026-02-26
> 状态: 待开发
> 前置依赖: M1 全部完成（含第 3-4 周的 Session/Preset CRUD、Prompt 组装、流式对话）
> 交付目标: 统一侧边 Panel 框架完成，Session / API Config / Preset 三类配置的完整 CRUD 可用，Lore 与 Appearance 面板占位就绪

---

## 1. 本期范围与边界

### 包含

- **后端**：Session CRUD 全链路（路由 + 服务层 + 存储）、Preset CRUD 全链路（路由 + 服务层 + 存储）、API Config 面板适配调整
- **前端**：统一 Panel 框架（PanelShell + ConfigSelector + ContentOverlay）、Session Panel、API Config Panel 重构、Preset Panel（含 vuedraggable 拖拽排序）、Lore / Appearance 占位面板
- **交互**：blur 自动保存、Overlay 内容编辑（Save/Discard）、删除确认与保护、保存状态指示
- **Pinia Store**：`useSessionStore`、`usePresetStore`、重构 `useApiConfigStore`

### 不包含

- Lore Panel 具体编辑功能（M3）
- Appearance Panel 具体编辑功能（M5）
- 流式对话、消息管理、Prompt 组装器（M1 第 3-4 周，假设已完成）
- 导入/导出功能

---

## 2. 新增依赖

### 前端 (`package.json`)

| 包 | 用途 |
|---|------|
| `vuedraggable` (`vuedraggable@next`) | Preset 条目拖拽排序，基于 SortableJS |

### 后端

无新增依赖。

---

## 3. 目录结构增量

基于 M1 完成态，本期新增/修改的文件：

```
backend/app/
├── models/
│   ├── session.py              # (M1 已有) 新增 SessionCreate, SessionUpdate, SessionResponse, SessionSummary
│   └── preset.py               # (M1 已有) 新增 PresetCreate, PresetUpdate, PresetResponse, PresetSummary
├── services/
│   ├── session_service.py      # 新增：Session CRUD 业务逻辑
│   └── preset_service.py       # 扩展：从 M1 的 ensure_default 升级为完整 CRUD
├── routers/
│   ├── sessions.py             # 新增：Session CRUD 路由
│   └── presets.py              # 新增：Preset CRUD 路由
│
backend/tests/
├── test_session_crud.py        # 新增：Session CRUD 集成测试
└── test_preset_crud.py         # 新增：Preset CRUD 集成测试

frontend/src/
├── components/
│   ├── panels/
│   │   ├── PanelShell.vue      # 新增：侧边栏容器，管理 5 个面板的展开/折叠
│   │   ├── ConfigSelector.vue  # 新增：通用顶部下拉选择器 + CRUD 按钮
│   │   ├── ContentOverlay.vue  # 新增：通用内容编辑 Overlay
│   │   ├── SaveIndicator.vue   # 新增：保存状态指示器
│   │   ├── SessionPanel.vue    # 新增：Session 配置面板
│   │   ├── ApiConfigPanel.vue  # 新增：重构后的 API 配置面板
│   │   ├── PresetPanel.vue     # 新增：Preset 配置面板
│   │   ├── LorePanel.vue       # 新增：Lore 占位面板
│   │   └── AppearancePanel.vue # 新增：Appearance 占位面板
│   └── api-config/             # 保留：ApiConfigForm.vue, ModelSelector.vue 移入 panels/ 或被重构引用
├── api/
│   ├── sessions.ts             # 新增：Session 请求封装
│   └── presets.ts              # 新增：Preset 请求封装
├── stores/
│   ├── session.ts              # 新增：Session Pinia store
│   ├── preset.ts               # 新增：Preset Pinia store
│   └── api-config.ts           # 重构：适配 ConfigSelector 模式
├── types/
│   ├── session.ts              # 新增：Session 相关 TS 类型
│   └── preset.ts               # 新增：Preset 相关 TS 类型
├── composables/
│   └── useAutoSave.ts          # 新增：自动保存 composable
└── App.vue                     # 重构：替换为 PanelShell 组件
```

---

## 4. 后端：Session CRUD 规格

### 4.1 数据模型扩展

文件：`app/models/session.py`

在 M1 已有的 `SessionMeta` 和 `Message` 基础上，新增请求/响应 Schema：

```python
class SessionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    mode: Literal["ST", "RST"] = "RST"
    main_api_config_id: str
    scheduler_api_config_id: str | None = None
    preset_id: str
    user_description: str = ""
    scan_depth: int = Field(default=4, ge=1, le=50)
    mem_length: int = Field(default=40, ge=1, le=500)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        if not NAME_PATTERN.fullmatch(value):
            raise ValueError("Session name contains invalid characters or length")
        return value


class SessionUpdate(BaseModel):
    """所有字段可选，仅更新传入的字段"""
    mode: Literal["ST", "RST"] | None = None
    main_api_config_id: str | None = None
    scheduler_api_config_id: str | None = None
    preset_id: str | None = None
    user_description: str | None = None
    scan_depth: int | None = Field(default=None, ge=1, le=50)
    mem_length: int | None = Field(default=None, ge=1, le=500)


class SessionRename(BaseModel):
    new_name: str = Field(min_length=1, max_length=64)

    @field_validator("new_name")
    @classmethod
    def validate_new_name(cls, value: str) -> str:
        if not NAME_PATTERN.fullmatch(value):
            raise ValueError("Session name contains invalid characters or length")
        return value


class SessionSummary(BaseModel):
    name: str
    mode: Literal["ST", "RST"]
    updated_at: datetime


class SessionResponse(BaseModel):
    name: str
    mode: Literal["ST", "RST"]
    user_description: str
    scan_depth: int
    mem_length: int
    created_at: datetime
    updated_at: datetime
    main_api_config_id: str
    scheduler_api_config_id: str | None
    preset_id: str
    version: int
```

### 4.2 API 端点

文件：`app/routers/sessions.py`

| 方法 | 路径 | 说明 | 请求体 | 响应 |
|------|------|------|--------|------|
| POST | `/sessions` | 创建会话 | `SessionCreate` | `SessionResponse` (201) |
| GET | `/sessions` | 列表 | — | `list[SessionSummary]` |
| GET | `/sessions/{name}` | 详情 | — | `SessionResponse` |
| PUT | `/sessions/{name}` | 更新设置 | `SessionUpdate` | `SessionResponse` |
| DELETE | `/sessions/{name}` | 删除会话 | — | 204 |
| PATCH | `/sessions/{name}/rename` | 重命名 | `SessionRename` | `SessionResponse` |

路由注册：

```python
# main.py
app.include_router(sessions_router, prefix="/sessions", tags=["Sessions"])
```

### 4.3 服务层

文件：`app/services/session_service.py`

#### 核心职责

- **创建**：验证名称唯一性 → 创建目录 `data/sessions/{name}/` → 创建 `session.json`（填充 `created_at`, `updated_at`）→ 创建空 `messages.json`（`[]`）→ 创建 `rst_data/` 子目录（含 `characters/` 和 `.index/`）
- **列表**：扫描 `data/sessions/` 下所有子目录，读取每个 `session.json` 的摘要字段
- **详情**：读取 `data/sessions/{name}/session.json` 并返回
- **更新**：读取现有 session.json → 合并变更 → 更新 `updated_at` → 原子写回
- **删除**：检查目录存在 → 递归删除 `data/sessions/{name}/` 整个目录
- **重命名**：验证新名称唯一性 → 重命名目录 `data/sessions/{old_name}/` → `data/sessions/{new_name}/` → 更新 session.json 中的 `name` 字段 → 更新 `updated_at`

#### 错误类型

```python
class SessionNotFoundError(RuntimeError):
    def __init__(self, name: str) -> None:
        super().__init__(f"Session '{name}' not found")
        self.name = name

class SessionNameExistsError(RuntimeError):
    def __init__(self, name: str) -> None:
        super().__init__(f"Session name '{name}' already exists")
        self.name = name
```

#### 关键接口

```python
def create_session(payload: SessionCreate) -> SessionResponse: ...
def list_sessions() -> list[SessionSummary]: ...
def get_session(name: str) -> SessionResponse: ...
def update_session(name: str, payload: SessionUpdate) -> SessionResponse: ...
def delete_session(name: str) -> None: ...
def rename_session(name: str, payload: SessionRename) -> SessionResponse: ...
```

#### 创建时的目录初始化

```
data/sessions/{name}/
├── session.json        # SessionMeta 序列化
├── messages.json       # 空数组 []
└── rst_data/           # M3 使用
    ├── characters/
    └── .index/
```

### 4.4 引用保护

删除 API Config 或 Preset 时，需要检查是否被任何 Session 引用：

- `delete_api_config` 需扫描所有 session.json，检查 `main_api_config_id` 和 `scheduler_api_config_id`
- `delete_preset` 需扫描所有 session.json，检查 `preset_id`
- 若存在引用，返回 409 错误，detail 中列出引用该配置的 Session 名称

在 `api_config_service.py` 中实现（替换 M1 留下的 `# TODO: check if referenced`）：

```python
class ApiConfigInUseError(RuntimeError):
    def __init__(self, config_id: str, session_names: list[str]) -> None:
        names = ", ".join(session_names)
        super().__init__(f"API config '{config_id}' is used by sessions: {names}")
        self.config_id = config_id
        self.session_names = session_names
```

---

## 5. 后端：Preset CRUD 规格

### 5.1 数据模型扩展

文件：`app/models/preset.py`

在 M1 已有的 `Preset`、`PresetEntry`、`SYSTEM_ENTRIES` 基础上，新增：

```python
class PresetCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)


class PresetUpdate(BaseModel):
    """整体更新 entries 数组（包含排序变更）"""
    entries: list[PresetEntry]


class PresetRename(BaseModel):
    new_name: str = Field(min_length=1, max_length=64)


class PresetSummary(BaseModel):
    id: str
    name: str


class PresetResponse(BaseModel):
    id: str
    name: str
    entries: list[PresetEntry]
    version: int
```

### 5.2 API 端点

文件：`app/routers/presets.py`

| 方法 | 路径 | 说明 | 请求体 | 响应 |
|------|------|------|--------|------|
| POST | `/presets` | 创建 Preset | `PresetCreate` | `PresetResponse` (201) |
| GET | `/presets` | 列表 | — | `list[PresetSummary]` |
| GET | `/presets/{id}` | 详情 | — | `PresetResponse` |
| PUT | `/presets/{id}` | 更新条目 | `PresetUpdate` | `PresetResponse` |
| DELETE | `/presets/{id}` | 删除 | — | 204 |
| PATCH | `/presets/{id}/rename` | 重命名 | `PresetRename` | `PresetResponse` |

路由注册：

```python
# main.py
app.include_router(presets_router, prefix="/presets", tags=["Presets"])
```

### 5.3 服务层

文件：`app/services/preset_service.py`（扩展 M1 已有文件）

#### 核心职责

- **创建**：生成 ID → 自动填充 6 个系统条目（使用 `DEFAULT_PRESET_ENTRIES`）→ 写入 `data/presets/{id}.json`
- **列表**：扫描 `data/presets/` 目录，读取每个 JSON 的 id 和 name
- **详情**：读取指定 Preset 文件并返回
- **更新**：接收完整 entries 数组 → 校验系统条目完整性（自动补齐缺失的系统条目）→ 校验系统条目不可删除 → 原子写回
- **删除**：检查是否被 Session 引用 → 删除文件
- **重命名**：验证名称唯一性 → 更新 name 字段 → 原子写回

#### 系统条目校验规则

在 `PresetUpdate` 处理时：

1. 检查传入的 entries 中是否包含所有 6 个 `SYSTEM_ENTRIES`
2. 如果缺失任何系统条目，自动将缺失条目追加到 entries 末尾（使用默认值）
3. 系统条目的 `name` 不可被修改（若发现 entries 中不存在某系统条目 name，视为缺失）
4. 自定义条目的 `name` 不可与系统条目重名

```python
def _validate_and_normalize_entries(entries: list[PresetEntry]) -> list[PresetEntry]:
    """
    校验并补齐系统条目。
    - 确保所有 SYSTEM_ENTRIES 存在
    - 自定义条目名称不可与系统条目重名
    - 缺失的系统条目追加到末尾
    """
```

#### 错误类型

```python
class PresetNotFoundError(RuntimeError):
    def __init__(self, preset_id: str) -> None:
        super().__init__(f"Preset '{preset_id}' not found")
        self.preset_id = preset_id

class PresetNameExistsError(RuntimeError):
    def __init__(self, name: str) -> None:
        super().__init__(f"Preset name '{name}' already exists")
        self.name = name

class PresetInUseError(RuntimeError):
    def __init__(self, preset_id: str, session_names: list[str]) -> None:
        names = ", ".join(session_names)
        super().__init__(f"Preset '{preset_id}' is used by sessions: {names}")
        self.preset_id = preset_id
        self.session_names = session_names

class PresetValidationError(RuntimeError):
    def __init__(self, detail: str) -> None:
        super().__init__(detail)
```

#### 关键接口

```python
def create_preset(payload: PresetCreate) -> PresetResponse: ...
def list_presets() -> list[PresetSummary]: ...
def get_preset(preset_id: str) -> PresetResponse: ...
def update_preset(preset_id: str, payload: PresetUpdate) -> PresetResponse: ...
def delete_preset(preset_id: str) -> None: ...
def rename_preset(preset_id: str, payload: PresetRename) -> PresetResponse: ...

# M1 已有，保留
def ensure_default_preset(data_dir: Path) -> str: ...
```

---

## 6. 后端：main.py 更新

在 M1 的 `create_app()` 中新增路由挂载：

```python
from app.routers.sessions import router as sessions_router
from app.routers.presets import router as presets_router

app.include_router(sessions_router, prefix="/sessions", tags=["Sessions"])
app.include_router(presets_router, prefix="/presets", tags=["Presets"])
```

---

## 7. 前端：TypeScript 类型

### 7.1 Session 类型

文件：`frontend/src/types/session.ts`

```typescript
export interface SessionSummary {
  name: string;
  mode: "ST" | "RST";
  updated_at: string;
}

export interface SessionDetail {
  name: string;
  mode: "ST" | "RST";
  user_description: string;
  scan_depth: number;
  mem_length: number;
  created_at: string;
  updated_at: string;
  main_api_config_id: string;
  scheduler_api_config_id: string | null;
  preset_id: string;
  version: number;
}

export interface SessionCreate {
  name: string;
  mode?: "ST" | "RST";
  main_api_config_id: string;
  scheduler_api_config_id?: string;
  preset_id: string;
  user_description?: string;
  scan_depth?: number;
  mem_length?: number;
}

export interface SessionUpdate {
  mode?: "ST" | "RST";
  main_api_config_id?: string;
  scheduler_api_config_id?: string | null;
  preset_id?: string;
  user_description?: string;
  scan_depth?: number;
  mem_length?: number;
}

export interface SessionRename {
  new_name: string;
}
```

### 7.2 Preset 类型

文件：`frontend/src/types/preset.ts`

```typescript
export interface PresetEntry {
  name: string;
  role: "system" | "user" | "assistant";
  content: string;
  disabled: boolean;
  comment: string;
}

export const SYSTEM_ENTRIES: string[] = [
  "Main_Prompt",
  "lores",
  "user_description",
  "chat_history",
  "scene",
  "user_input",
];

export interface PresetSummary {
  id: string;
  name: string;
}

export interface PresetDetail {
  id: string;
  name: string;
  entries: PresetEntry[];
  version: number;
}

export interface PresetCreate {
  name: string;
}

export interface PresetUpdate {
  entries: PresetEntry[];
}

export interface PresetRename {
  new_name: string;
}
```

---

## 8. 前端：API 请求层

### 8.1 Session API

文件：`frontend/src/api/sessions.ts`

```typescript
export function fetchSessions(): Promise<SessionSummary[]>
export function fetchSession(name: string): Promise<SessionDetail>
export function createSession(data: SessionCreate): Promise<SessionDetail>
export function updateSession(name: string, data: SessionUpdate): Promise<SessionDetail>
export function deleteSession(name: string): Promise<void>
export function renameSession(name: string, data: SessionRename): Promise<SessionDetail>
```

### 8.2 Preset API

文件：`frontend/src/api/presets.ts`

```typescript
export function fetchPresets(): Promise<PresetSummary[]>
export function fetchPreset(id: string): Promise<PresetDetail>
export function createPreset(data: PresetCreate): Promise<PresetDetail>
export function updatePreset(id: string, data: PresetUpdate): Promise<PresetDetail>
export function deletePreset(id: string): Promise<void>
export function renamePreset(id: string, data: PresetRename): Promise<PresetDetail>
```

---

## 9. 前端：Pinia Stores

### 9.1 useSessionStore

文件：`frontend/src/stores/session.ts`

```typescript
State:
  sessions: SessionSummary[]       // 会话列表
  currentSession: SessionDetail | null  // 当前编辑的会话
  loading: boolean

Actions:
  loadSessions()                   // 拉取列表
  loadSession(name: string)        // 拉取详情，设置 currentSession
  createSession(data: SessionCreate)  // 创建并刷新列表
  saveSession(name: string, data: SessionUpdate)  // 更新设置
  removeSession(name: string)      // 删除并刷新列表
  renameSession(name: string, data: SessionRename)  // 重命名并刷新列表
```

### 9.2 usePresetStore

文件：`frontend/src/stores/preset.ts`

```typescript
State:
  presets: PresetSummary[]         // Preset 列表
  currentPreset: PresetDetail | null  // 当前编辑的 Preset
  loading: boolean

Actions:
  loadPresets()                    // 拉取列表
  loadPreset(id: string)          // 拉取详情，设置 currentPreset
  createPreset(data: PresetCreate)  // 创建并刷新列表
  savePreset(id: string, data: PresetUpdate)  // 更新 entries
  removePreset(id: string)         // 删除并刷新列表
  renamePreset(id: string, data: PresetRename)  // 重命名并刷新列表
```

### 9.3 useApiConfigStore 重构

文件：`frontend/src/stores/api-config.ts`

在 M1 已有基础上调整：

- 保持原有 state 和 actions 不变
- 新增 `renameConfig(id, newName)` action
- `saveConfig` 不再根据是否有 id 判断 create/update，由调用方明确调用 `createConfig` 或 `saveConfig`

---

## 10. 前端：Panel 框架组件规格

### 10.1 PanelShell.vue

**替换 App.vue 中现有的 panel 管理逻辑**，成为独立组件。

#### 职责

- 管理 5 个面板的展开/折叠状态
- 渲染左侧图标栏（5 个图标按钮）
- 根据 activePanel 渲染对应面板组件

#### Props / State

```typescript
type PanelType = "session" | "api" | "preset" | "lore" | "appearance" | null;

const activePanel = ref<PanelType>(null);
```

#### 图标栏

纵向排列，固定宽度 48px，5 个图标按钮：

| 序号 | 标签 | PanelType | M2 状态 |
|------|------|-----------|---------|
| 1 | SES | `session` | 启用 |
| 2 | API | `api` | 启用 |
| 3 | PRE | `preset` | 启用 |
| 4 | LOR | `lore` | 启用（占位面板） |
| 5 | APP | `appearance` | 启用（占位面板） |

点击图标切换对应面板（toggle）。点击主内容区关闭面板。Esc 键关闭面板。

#### 布局

```
┌──────┬──────────────────┬─────────────────────────────┐
│ Icon │    Panel Area    │        Main Content         │
│ Bar  │   (360px, 可选)  │      (flex: 1)              │
│ 48px │                  │                             │
└──────┴──────────────────┴─────────────────────────────┘
```

面板展开时容器宽度 = 48 + 360 = 408px。面板关闭时容器宽度 = 48px。transition 0.2s ease。

### 10.2 ConfigSelector.vue

**通用顶部配置选择器**，所有面板共用。

#### Props

```typescript
interface ConfigSelectorProps {
  options: Array<{ label: string; value: string }>;  // 下拉选项
  selectedValue: string | null;                       // 当前选中值
  placeholder?: string;                               // 下拉占位文字
  loading?: boolean;                                  // 加载状态
}
```

#### Emits

```typescript
interface ConfigSelectorEmits {
  (e: "select", value: string): void;
  (e: "create"): void;       // 点击 + 按钮
  (e: "rename"): void;       // 点击 🖊 按钮
  (e: "delete"): void;       // 点击 🗑 按钮
}
```

#### 布局

正常模式：

```
┌──────────────────────────────────────┐
│ [▼ 下拉选择器           ] [+] [🖊] [🗑] │
└──────────────────────────────────────┘
```

- 下拉选择器：使用 NSelect，显示配置名称列表
- [+] 按钮：触发 `create` 事件（由父面板处理具体的新建流程）
- [🖊] 按钮：触发 `rename` 事件，当无选中项时 disabled
- [🗑] 按钮：红色，触发 `delete` 事件，当无选中项时 disabled

#### 重命名行为

点击 🖊 按钮后，ConfigSelector 内部进入重命名模式：

```
┌──────────────────────────────────────┐
│ [输入新名称...          ] [✓] [✕]   │
└──────────────────────────────────────┘
```

- 输入框预填当前名称，自动 focus
- Enter 或点击 ✓ 提交重命名
- Esc 或点击 ✕ 取消
- 提交时 emit `(e: "rename-confirm", newName: string)`

因此完整的 emits 应补充为：

```typescript
interface ConfigSelectorEmits {
  (e: "select", value: string): void;
  (e: "create"): void;
  (e: "rename-confirm", newName: string): void;
  (e: "delete"): void;
}
```

### 10.3 ContentOverlay.vue

**通用内容编辑 Overlay**，用于 Preset 条目内容编辑，后续 M3 的 Lore 条目编辑也复用此组件。

#### Props

```typescript
interface ContentOverlayProps {
  visible: boolean;
  title: string;                  // Overlay 标题，如 "编辑: Main_Prompt"
  fields: OverlayField[];        // 表单字段定义
  contentValue: string;          // 主内容区的值
  contentReadonly?: boolean;     // 主内容区是否只读
  contentLabel?: string;         // 主内容区标签，默认 "Content"
}

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: Array<{ label: string; value: string }>;  // select 类型时使用
}
```

#### Emits

```typescript
interface ContentOverlayEmits {
  (e: "save", data: { fields: Record<string, unknown>; content: string }): void;
  (e: "discard"): void;
}
```

#### 布局

Overlay 以半透明遮罩覆盖在面板上方，内容区域为卡片：

```
┌─────────────────────────────────┐
│ 编辑: Main_Prompt          [✕]  │
│─────────────────────────────────│
│ Name:    [Main_Prompt   ] (只读) │
│ Role:    [system        ] (只读) │
│ Comment: [               ]      │
│─────────────────────────────────│
│ Content:                        │
│ ┌─────────────────────────────┐ │
│ │ You are a helpful assistant.│ │
│ │                             │ │
│ │                             │ │
│ │                             │ │
│ └─────────────────────────────┘ │
│─────────────────────────────────│
│              [Discard]  [Save]  │
└─────────────────────────────────┘
```

- Content 区域使用 NInput type="textarea"，自适应高度，最小 200px
- 只读字段灰显（opacity 0.5，不可交互）
- Save 按钮：primary 类型，提交所有修改
- Discard 按钮：secondary 类型，放弃修改关闭 Overlay
- 点击 ✕ 按钮等同 Discard
- 点击遮罩背景不关闭（防止误触丢失编辑）

### 10.4 SaveIndicator.vue

**保存状态指示器**，嵌入到各面板中。

#### Props

```typescript
interface SaveIndicatorProps {
  status: "idle" | "saving" | "saved" | "error";
}
```

#### 显示

| status | 显示 | 颜色 |
|--------|------|------|
| `idle` | 不显示 | — |
| `saving` | "保存中..." | text-secondary |
| `saved` | "已保存 ✓" | green，2 秒后淡出回 idle |
| `error` | "保存失败" | red |

位置：面板 header 右侧或 ConfigSelector 下方。

---

## 11. 前端：自动保存 Composable

文件：`frontend/src/composables/useAutoSave.ts`

```typescript
interface UseAutoSaveOptions {
  /** 保存回调，返回 Promise */
  saveFn: () => Promise<void>;
  /** debounce 延迟，默认 300ms */
  delay?: number;
}

interface UseAutoSaveReturn {
  /** 保存状态 */
  saveStatus: Ref<"idle" | "saving" | "saved" | "error">;
  /** 标记数据已变更（在 watch 或事件中调用） */
  markDirty: () => void;
  /** 手动触发保存（如失焦时） */
  flush: () => Promise<void>;
  /** 取消待执行的保存 */
  cancel: () => void;
}

export function useAutoSave(options: UseAutoSaveOptions): UseAutoSaveReturn
```

#### 行为

1. 调用 `markDirty()` 后启动 debounce 计时器
2. 计时器到期后调用 `saveFn()`
3. 保存期间 `saveStatus` 为 `"saving"`
4. 保存成功后 `saveStatus` 设为 `"saved"`，2 秒后自动回 `"idle"`
5. 保存失败后 `saveStatus` 设为 `"error"`
6. `flush()` 立即执行保存（取消计时器），用于 blur 事件
7. `cancel()` 取消待执行的保存，用于切换配置时

#### 使用模式

面板中 blur 触发自动保存的典型用法：

```typescript
const { saveStatus, markDirty, flush, cancel } = useAutoSave({
  saveFn: async () => {
    await store.saveSession(currentName, formData);
  },
  delay: 300,
});

// 在 watch 中检测变更
watch(formData, () => markDirty(), { deep: true });

// 在字段 blur 时立即保存
function onFieldBlur() {
  flush();
}

// 切换选中配置时取消未完成的保存
watch(selectedName, () => cancel());
```

---

## 12. 前端：各面板规格

### 12.1 SessionPanel.vue

#### 结构

```
┌──────────────────────────────────────┐
│ Session                [SaveIndicator] │  ← panel header
│──────────────────────────────────────│
│ [▼ 选择会话...      ] [+] [🖊] [🗑]  │  ← ConfigSelector
│──────────────────────────────────────│
│                                      │
│   （新建模式时：新建表单卡片）          │
│   （编辑模式时：设置表单）             │
│   （无选中时：空状态提示）             │
│                                      │
└──────────────────────────────────────┘
```

#### 新建流程

点击 [+] 按钮后，在面板主体区域显示**新建表单卡片**（accent 色边框）：

```
┌──────────────────────────────────┐
│  ✨ 新建会话                      │
│                                  │
│  名称:       [________________]  │
│  Mode:       [RST         ▼]    │
│  Main API:   [选择 API 配置 ▼]   │
│  Preset:     [选择 Preset   ▼]   │
│                                  │
│          [取消]  [创建]           │
└──────────────────────────────────┘
```

- 名称为必填
- Main API 和 Preset 为必填下拉选择（NSelect，选项来自对应 store 的列表）
- Mode 默认 RST
- Scheduler API、scan_depth、mem_length、user_description 可在创建后编辑
- 点击"创建"后调用 `createSession`，成功后自动选中新会话并进入编辑模式
- 点击"取消"关闭新建卡片

#### 编辑表单

选中会话后，面板主体显示设置表单：

| 字段 | 控件 | 说明 |
|------|------|------|
| Mode | NSelect (`ST` / `RST`) | 模式选择 |
| Main API | NSelect | 列出所有 API 配置（id → name 映射） |
| Scheduler API | NSelect (可清空) | 列出所有 API 配置，可选 |
| Preset | NSelect | 列出所有 Preset（id → name 映射） |
| Scan Depth | NInputNumber | 范围 [1, 50] |
| Mem Length | NInputNumber | 范围 [1, 500] |
| User Description | NInput type="textarea" | 多行文本 |

所有字段使用 `useAutoSave`，blur 时触发保存。

#### 空状态

```
┌──────────────────────────────────┐
│          💬                       │
│    请选择或新建一个会话            │
└──────────────────────────────────┘
```

### 12.2 ApiConfigPanel.vue（重构）

**替换 M1 的 `components/api-config/ApiConfigPanel.vue`**，迁移到 `components/panels/ApiConfigPanel.vue`。

#### 结构变更

- 顶部使用 `ConfigSelector`（替换 M1 的列表 + 新建按钮模式）
- 编辑区域复用 M1 的 `ApiConfigForm.vue` 中的表单字段
- 不再显示列表项卡片，改为下拉选择

#### 新建流程

点击 [+] 后显示新建表单卡片：

```
┌──────────────────────────────────┐
│  ✨ 新建 API 配置                 │
│                                  │
│  名称:       [________________]  │
│  Provider:   [OpenAI       ▼]    │
│  API Key:    [________________]  │
│                                  │
│          [取消]  [创建]           │
└──────────────────────────────────┘
```

- Provider 选择后自动填充 base_url 默认值
- 创建后自动进入编辑模式，可设置其余字段

#### 编辑表单

与 M1 的 `ApiConfigForm.vue` 字段一致：

| 字段 | 控件 | 自动保存 |
|------|------|----------|
| Provider | NSelect | blur 保存 |
| Base URL | NInput | blur 保存 |
| API Key | NInput type=password | blur 保存（仅非空时提交） |
| Model | ModelSelector | 选择后保存 |
| Temperature | NSlider + NInputNumber | blur 保存 |
| Max Tokens | NInputNumber | blur 保存 |
| Stream | NSwitch | 变更后保存 |

API Key 特殊处理：
- 编辑模式下显示 `api_key_preview`（如 `****xxxx`）作为 placeholder
- 用户输入新值后 blur 时提交
- 若用户清空输入框再 blur，视为未修改，不提交 api_key 字段

### 12.3 PresetPanel.vue

#### 结构

```
┌──────────────────────────────────────┐
│ Preset                [SaveIndicator] │
│──────────────────────────────────────│
│ [▼ 选择 Preset...   ] [+] [🖊] [🗑]  │
│──────────────────────────────────────│
│                                      │
│  Entries                [+ 添加条目]  │
│  ┌──────────────────────────────┐    │
│  │ ≡ Main_Prompt         [●]   │    │  ← 可拖拽，toggle
│  │ ≡ lores            🔒 [●]   │    │
│  │ ≡ user_description 🔒 [○]   │    │
│  │ ≡ chat_history     🔒 [●]   │    │
│  │ ≡ my_custom_entry     [●]   │    │  ← 自定义条目
│  │ ≡ scene            🔒 [●]   │    │
│  │ ≡ user_input       🔒 [●]   │    │
│  └──────────────────────────────┘    │
│                                      │
└──────────────────────────────────────┘
```

#### 新建流程

点击 [+] 后显示新建表单卡片（仅需名称）：

```
┌──────────────────────────────────┐
│  ✨ 新建 Preset                   │
│                                  │
│  名称:       [________________]  │
│                                  │
│          [取消]  [创建]           │
└──────────────────────────────────┘
```

创建后自动填充 6 个系统条目。

#### 条目列表

使用 `vuedraggable` 实现拖拽排序。每个条目行显示：

```
┌────────────────────────────────────────────────┐
│  ≡   Main_Prompt                          [●]  │
└────────────────────────────────────────────────┘
 拖拽   名称                         disabled toggle
```

- **≡**：拖拽手柄（drag handle），所有条目均可拖拽
- **名称**：显示 `entry.name`
- **🔒**：系统条目标记（除 Main_Prompt 外的系统条目显示锁图标，表示 content 只读）
- **[●] / [○]**：disabled toggle（NSwitch），所有条目均可切换
- 点击条目行（拖拽手柄和 toggle 除外的区域）打开 `ContentOverlay`

#### 条目 Toggle 保存

切换 disabled 状态后，立即将完整 entries 数组提交到后端（整体 PUT）。

#### 拖拽排序保存

拖拽结束（`@end`）后，将重排后的 entries 数组立即提交到后端。

#### ContentOverlay 调用

点击条目行时，打开 ContentOverlay，传入以下参数：

**系统条目（非 Main_Prompt）—— lores, user_description, chat_history, scene, user_input**：

| 字段 | 可编辑 |
|------|--------|
| name | ❌ 只读 |
| role | ❌ 只读 |
| content | ❌ 只读（灰显，显示提示"由系统在 Prompt 组装时自动填充"） |
| disabled | ✅ 可编辑 |
| comment | ✅ 可编辑 |

**Main_Prompt**：

| 字段 | 可编辑 |
|------|--------|
| name | ❌ 只读 |
| role | ❌ 只读 |
| content | ✅ 可编辑 |
| disabled | ✅ 可编辑 |
| comment | ✅ 可编辑 |

**自定义条目**：

| 字段 | 可编辑 |
|------|--------|
| name | ✅ 可编辑 |
| role | ✅ 可编辑（NSelect: system / user / assistant） |
| content | ✅ 可编辑 |
| disabled | ✅ 可编辑 |
| comment | ✅ 可编辑 |

Overlay 底部额外显示：自定义条目有**删除按钮**（红色，NPopconfirm 二次确认）。

Save 时将修改后的 entry 更新回 entries 数组，整体 PUT 提交。

#### [+ 添加条目] 按钮

点击后打开 ContentOverlay，所有字段为空的新条目模板：

- name：空，可编辑
- role：默认 `system`
- content：空
- disabled：`false`
- comment：空

Save 时将新条目追加到 entries 数组末尾，整体 PUT 提交。

### 12.4 LorePanel.vue（占位）

```
┌──────────────────────────────────────┐
│ Lore                                  │
│──────────────────────────────────────│
│                                      │
│          🏗️                          │
│    Lore 编辑器将在 M3 中实现          │
│                                      │
└──────────────────────────────────────┘
```

仅显示面板标题和占位提示。

### 12.5 AppearancePanel.vue（占位）

```
┌──────────────────────────────────────┐
│ Appearance                            │
│──────────────────────────────────────│
│                                      │
│          🎨                          │
│    外观设置将在 M5 中实现             │
│                                      │
└──────────────────────────────────────┘
```

仅显示面板标题和占位提示。

---

## 13. 前端：App.vue 重构

将 M1 的 panel 管理逻辑迁移到 `PanelShell.vue`，App.vue 简化为：

```vue
<template>
  <n-message-provider>
    <div class="rst-app">
      <PanelShell />
      <main class="rst-main">
        <RouterView />
      </main>
    </div>
  </n-message-provider>
</template>
```

`PanelShell` 内部管理图标栏和面板渲染，不再由 App.vue 直接处理。

点击 `main` 区域关闭面板的逻辑由 `PanelShell` 通过 `@click.self` 或 event delegation 实现。

---

## 14. 错误处理规范

### 后端

在 M1 的基础上扩展，统一模式：

| 场景 | 状态码 | detail |
|------|--------|--------|
| Session 不存在 | 404 | `Session '{name}' not found` |
| Session 名称重复 | 409 | `Session name '{name}' already exists` |
| Session 名称非法字符 | 422 | FastAPI 自动处理（field_validator） |
| Preset 不存在 | 404 | `Preset '{id}' not found` |
| Preset 名称重复 | 409 | `Preset name '{name}' already exists` |
| Preset 被 Session 引用 | 409 | `Preset '{id}' is used by sessions: {names}` |
| API Config 被 Session 引用 | 409 | `API config '{id}' is used by sessions: {names}` |
| Preset 自定义条目与系统条目重名 | 400 | `Entry name '{name}' conflicts with system entry` |

### 前端

沿用 M1 的 `parseApiError` 模式：
- 409 错误显示 detail 信息（"该配置正在被会话 xxx 使用"）
- 删除失败时不关闭面板，仅显示错误提示

---

## 15. 测试要求

### 后端

#### test_session_crud.py

- 测试 POST 创建：返回 201，session.json 和 messages.json 存在，rst_data/ 目录存在
- 测试 POST 名称重复返回 409
- 测试 POST 名称含非法字符返回 422
- 测试 GET 列表：创建多个后列表长度正确，按 updated_at 或 name 排序
- 测试 GET 详情：字段完整
- 测试 PUT 更新：仅传 mode 时其他字段不变
- 测试 DELETE：删除后目录不存在，GET 返回 404
- 测试 PATCH rename：目录名变更，session.json 中 name 更新
- 测试 PATCH rename 新名称重复返回 409
- 测试 GET 不存在的 Session 返回 404

#### test_preset_crud.py

- 测试 POST 创建：返回 201，entries 包含 6 个系统条目
- 测试 POST 名称重复返回 409
- 测试 GET 列表：创建多个后列表长度正确
- 测试 GET 详情：字段完整
- 测试 PUT 更新 entries：修改排序后读回验证顺序
- 测试 PUT 更新缺失系统条目时自动补齐
- 测试 PUT 自定义条目名称与系统条目重名返回 400
- 测试 DELETE：删除后 GET 返回 404
- 测试 DELETE 被 Session 引用时返回 409
- 测试 PATCH rename：名称更新成功
- 测试 PATCH rename 重复返回 409

#### api_config_service 补充测试

- 测试 DELETE 被 Session 引用时返回 409

### 前端

#### 测试范围（Vitest + @vue/test-utils）

- `session store` 测试：mock axios，验证 CRUD actions 对 state 的变更
- `preset store` 测试：mock axios，验证 CRUD actions 对 state 的变更
- `useAutoSave` composable 测试：验证 debounce、flush、cancel 行为
- `ConfigSelector` 组件测试：验证选择、重命名模式切换、按钮 disabled 状态

---

## 16. 样式规范

### CSS 变量复用

所有新组件使用 M0/M1 已定义的 CSS 变量（`variables.scss`）：

| 用途 | 变量 |
|------|------|
| 面板背景 | `--rst-bg-panel` |
| 顶栏背景 | `--rst-bg-topbar` |
| 边框 | `--rst-border-color` |
| 主文字 | `--rst-text-primary` |
| 次文字 | `--rst-text-secondary` |
| 强调色 | `--rst-accent` |
| 圆角 | `--rst-radius-sm/md/lg` |
| 间距 | `--rst-spacing-xs/sm/md/lg/xl` |

### 新增 CSS 变量

在 `variables.scss` 中补充（如需）：

```scss
:root {
  /* M2 新增 */
  --rst-success: #22c55e;       // 保存成功
  --rst-danger: #ef4444;        // 删除、错误
  --rst-warning: #f59e0b;       // 警告
  --rst-overlay-bg: rgba(0, 0, 0, 0.5);  // Overlay 遮罩
}
```

### Naive UI 主题

M2 不引入 Naive UI 全局主题覆盖，使用组件级 props 调整样式（如 `size="small"`）。Naive UI 的暗色模式通过 `<n-config-provider>` 包裹并设置 `theme` 为 dark theme。

需要在 App.vue 中添加 `<n-config-provider :theme="darkTheme">`：

```vue
import { darkTheme } from "naive-ui";
```

---

## 17. 开发顺序建议

按依赖关系推荐的实现顺序：

```
第 5 周:

Day 1-2:  后端 Session CRUD
          - models/session.py 扩展 Schema
          - services/session_service.py
          - routers/sessions.py
          - test_session_crud.py
          - main.py 挂载路由

Day 3:    后端 Preset CRUD
          - models/preset.py 扩展 Schema
          - services/preset_service.py 升级
          - routers/presets.py
          - test_preset_crud.py
          - main.py 挂载路由

Day 4:    后端引用保护 + API Config 补充
          - api_config_service.py 添加引用检查
          - preset_service.py 添加引用检查
          - 补充测试

Day 5:    前端通用组件
          - types/ 新增 session.ts, preset.ts
          - api/ 新增 sessions.ts, presets.ts
          - composables/useAutoSave.ts
          - components/panels/ConfigSelector.vue
          - components/panels/ContentOverlay.vue
          - components/panels/SaveIndicator.vue

Day 6-7:  前端 PanelShell + 各面板
          - PanelShell.vue（替换 App.vue 面板逻辑）
          - App.vue 重构
          - stores/ 新增 session.ts, preset.ts
          - stores/api-config.ts 重构

第 6 周:

Day 1-2:  SessionPanel.vue 完整实现
          - 新建流程
          - 编辑表单 + 自动保存
          - 前端 store 测试

Day 3-4:  PresetPanel.vue 完整实现
          - 安装 vuedraggable
          - 条目列表 + 拖拽排序
          - ContentOverlay 集成
          - 系统条目权限控制
          - 前端 store 测试

Day 5:    ApiConfigPanel.vue 重构
          - 迁移到 ConfigSelector 模式
          - 自动保存集成
          - API Key 特殊处理

Day 6:    LorePanel / AppearancePanel 占位
          - 交互打磨（Esc 关闭、键盘导航）
          - useAutoSave composable 测试
          - ConfigSelector 组件测试

Day 7:    集成测试 + Bug 修复
          - 全链路手动验证
          - lint + type-check
```

---

## 18. 验收标准

| # | 验收项 | 验证方法 |
|---|--------|----------|
| 1 | 左侧图标栏 5 个图标均可点击，展开/折叠对应 Panel | 手动验证 |
| 2 | Session Panel：可新建、重命名、删除会话 | 通过 UI 操作 + 检查 data/sessions/ 目录 |
| 3 | Session Panel：编辑设置后 blur 自动保存，刷新后状态一致 | 修改 → blur → 刷新 → 验证 |
| 4 | Session Panel：可选择关联的 API Config 和 Preset | 下拉选择 → 保存 → 验证 session.json |
| 5 | API Config Panel：使用 ConfigSelector 模式，CRUD 可用 | 通过 UI 操作完成创建→编辑→删除 |
| 6 | API Config Panel：blur 自动保存正常工作 | 修改字段 → blur → 检查文件 |
| 7 | Preset Panel：可新建、重命名、删除 Preset | 通过 UI 操作 + 检查 data/presets/ 目录 |
| 8 | Preset Panel：新建 Preset 自动包含 6 个系统条目 | 创建后检查 entries |
| 9 | Preset Panel：条目可拖拽排序，排序后自动保存 | 拖拽 → 刷新 → 验证顺序 |
| 10 | Preset Panel：系统条目不可删除、不可改名 | UI 上无删除按钮，name 字段只读 |
| 11 | Preset Panel：Main_Prompt content 可编辑，其他系统条目 content 只读 | Overlay 中验证 |
| 12 | Preset Panel：自定义条目全字段可编辑，可删除 | Overlay 中验证 |
| 13 | ContentOverlay：Save/Discard 正常工作 | 编辑 → Save → 验证；编辑 → Discard → 验证未保存 |
| 14 | 删除被引用的 API Config 或 Preset 时显示错误提示 | 创建 Session 引用 → 尝试删除 → 验证 409 |
| 15 | 保存状态指示器正确显示（保存中/已保存/失败） | 观察 UI 状态变化 |
| 16 | Lore 和 Appearance 面板显示占位内容 | 点击图标 → 验证占位面板 |
| 17 | Esc 键可关闭面板 | 键盘操作验证 |
| 18 | 全部后端测试通过 | `uv run pytest` 全部 pass |
| 19 | 前端 TypeScript 类型检查通过 | `pnpm type-check` 无错误 |
| 20 | ruff + eslint 无错误 | `scripts/lint.bat` 通过 |

---

## 19. 关键设计决策回顾

| 决策点 | 选择 | 理由 |
|--------|------|------|
| Panel 通用化程度 | ConfigSelector（下拉+按钮）通用，编辑区各面板独立 | 5 类配置差异大，过度抽象反而增加复杂度 |
| 拖拽排序 | vuedraggable (sortablejs) | 成熟稳定，Vue 3 支持良好 |
| 自动保存策略 | blur + dirty check + debounce 300ms | 平衡用户体验与保存频率；API Key 等敏感字段仅非空时提交 |
| Preset 条目编辑 | 元数据 inline 展示（name + disabled），content 通过 Overlay 编辑 | 列表简洁，内容编辑有足够空间 |
| 新建交互 | 面板主体区域显示醒目的新建表单卡片 | 比 inline 输入框更明显，不易被忽视 |
| Session 关联选择 | NSelect 下拉选择 | 简单直接，M2 阶段够用 |
| Lore / Appearance 面板 | 图标启用，面板显示占位 | 让用户感知完整的功能布局 |
| Preset 整体 PUT | 每次修改都提交完整 entries 数组 | 避免复杂的增量更新 API，entries 数量有限（通常 < 20） |
