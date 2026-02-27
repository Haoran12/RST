# M1 第 2 周 — 数据模型 + 存储层 + API 配置 技术文档

> 版本: 1.0
> 日期: 2026-02-26
> 状态: 待开发
> 前置依赖: M0 工程脚手架已完成
> 交付目标: 核心数据模型定义完毕，存储层可靠运行，API 配置 CRUD 可用，Key 加密存储，模型列表可获取

---

## 1. 本周范围与边界

### 包含

- 核心 Pydantic 模型定义（SessionMeta, Message, ApiConfig, PresetEntry, Preset）
- 存储层基础工具（原子写入、JSON 读写、文件锁、分页消息存储）
- API 配置 CRUD 全链路（后端路由 + 服务层 + 存储 + 前端页面）
- API Key Fernet 加密存储
- 各 Provider 模型列表获取适配

### 不包含

- Preset CRUD 界面（M1 阶段使用硬编码默认 Preset）
- Session CRUD（第 3 周）
- 对话交互与消息发送（第 3-4 周）
- Lore 相关功能（M2）

### M1 阶段 Preset 策略

系统内置一份默认 Preset，硬编码在后端服务层中。包含 6 个系统条目，按以下默认顺序排列：

| 序号 | name | role | content | 说明 |
|------|------|------|---------|------|
| 1 | Main_Prompt | system | "You are a helpful assistant." | 唯一可在 M1 阶段修改 content 的系统条目 |
| 2 | lores | system | （系统注入，M1 为空串） | 不可编辑 |
| 3 | user_description | system | （系统注入） | 不可编辑 |
| 4 | chat_history | — | （系统注入） | 不可编辑，占位标记 |
| 5 | scene | system | （系统注入，M1 为空串） | 不可编辑 |
| 6 | user_input | user | （系统注入） | 不可编辑 |

创建会话时自动关联此默认 Preset。Preset 文件仍按规范写入 `data/presets/`，但 M1 不提供 Preset 管理 UI。

---

## 2. 新增依赖

### 后端 (`pyproject.toml`)

在 M0 基础上新增：

| 包 | 用途 |
|---|------|
| `cryptography` | Fernet 对称加密，用于 API Key 加密存储 |
| `httpx` | 从 dev 依赖提升为主依赖，用于向 LLM Provider 发起模型列表请求 |
| `nanoid` | 生成短 ID（`python-nanoid`） |

### 前端 (`package.json`)

在 M0 基础上新增：

| 包 | 用途 |
|---|------|
| 无新增 | M0 已有 axios、naive-ui、pinia，本周够用 |

---

## 3. 环境变量新增

在 `.env.example` 中追加：

| 变量名 | 默认值 | 用途 | 说明 |
|--------|--------|------|------|
| `RST_ENCRYPTION_KEY` | （空） | Fernet 加密密钥，base64 编码的 32 字节 | 优先级最高 |

加密密钥解析优先级：
1. 环境变量 `RST_ENCRYPTION_KEY`（若非空）
2. 文件 `{RST_DATA_DIR}/.keyfile`（若存在）
3. 两者均不存在时，首次启动自动生成密钥写入 `{RST_DATA_DIR}/.keyfile`

`.keyfile` 必须加入 `.gitignore`。

---

## 4. 目录结构增量

基于 M0 结构，本周新增/修改的文件：

```
backend/app/
├── models/
│   ├── __init__.py
│   ├── api_config.py        # ApiConfig, ProviderType
│   ├── session.py           # SessionMeta, Message
│   └── preset.py            # Preset, PresetEntry, SYSTEM_ENTRIES
├── storage/
│   ├── __init__.py
│   ├── init_dirs.py          # (M0 已有)
│   ├── file_io.py            # atomic_write, read_json, write_json, 文件锁
│   ├── encryption.py         # Fernet 密钥管理、加密/解密函数
│   └── message_store.py      # 分页消息存储逻辑
├── services/
│   ├── __init__.py
│   ├── api_config_service.py # API 配置 CRUD 业务逻辑
│   └── preset_service.py     # 默认 Preset 初始化（M1 硬编码）
├── providers/
│   ├── __init__.py
│   ├── base.py               # 抽象基类 BaseProvider
│   ├── openai.py             # OpenAI + OpenAI 兼容
│   ├── anthropic.py          # Anthropic
│   ├── gemini.py             # Google Gemini
│   ├── deepseek.py           # Deepseek（继承 openai 兼容）
│   └── registry.py           # provider_type → Provider 实例映射
├── routers/
│   ├── health.py             # (M0 已有)
│   └── api_configs.py        # API 配置 CRUD 路由
│
backend/tests/
├── test_health.py            # (M0 已有)
├── test_file_io.py           # 存储层单元测试
├── test_encryption.py        # 加密模块单元测试
├── test_message_store.py     # 分页消息存储测试
├── test_api_config_crud.py   # API 配置 CRUD 集成测试
└── conftest.py               # 共享 fixtures（tmp 数据目录、测试客户端）

frontend/src/
├── types/
│   └── api-config.ts         # ApiConfig 相关 TS 类型
├── api/
│   └── api-configs.ts        # API 配置请求封装
├── stores/
│   └── api-config.ts         # API 配置 Pinia store
├── components/
│   └── api-config/
│       ├── ApiConfigPanel.vue    # 配置列表 + CRUD 面板
│       ├── ApiConfigForm.vue     # 单个配置的编辑表单
│       └── ModelSelector.vue     # 模型选择器（列表获取 + 手动输入）
└── views/
    └── ChatView.vue          # 扩展：添加 API 配置面板入口图标
```

---

## 5. 数据模型规格

### 5.1 ID 生成策略

所有实体 ID 使用 nanoid 生成，字母表 `0-9a-z`，长度 12。格式示例：`a3f8k2m9x1b4`。

提供统一工具函数，位于 `app/models/__init__.py`：

```python
def generate_id() -> str:
    """生成 12 位 nanoid，字母表 0-9a-z"""
```

### 5.2 ApiConfig

文件：`app/models/api_config.py`

```python
class ProviderType(str, Enum):
    OPENAI = "openai"
    GEMINI = "gemini"
    DEEPSEEK = "deepseek"
    ANTHROPIC = "anthropic"
    OPENAI_COMPAT = "openai_compat"

class ApiConfig(BaseModel):
    id: str                     # nanoid
    name: str                   # 用户可读名称
    provider: ProviderType
    base_url: str
    encrypted_key: str          # Fernet 加密后的 key（存储态）
    model: str = ""
    temperature: float = 0.7
    max_tokens: int = 4096
    stream: bool = True
    version: int = 1
```

各 Provider 默认 base_url：

| ProviderType | 默认 base_url |
|---|---|
| `openai` | `https://api.openai.com/v1` |
| `gemini` | `https://generativelanguage.googleapis.com/v1beta` |
| `deepseek` | `https://api.deepseek.com/v1` |
| `anthropic` | `https://api.anthropic.com/v1` |
| `openai_compat` | （空，用户必填） |

默认值映射定义为模块级常量 `DEFAULT_BASE_URLS: dict[ProviderType, str]`。

### 5.3 SessionMeta

文件：`app/models/session.py`

```python
class SessionMeta(BaseModel):
    name: str                   # 会话名称，同时作为目录名
    mode: Literal["ST", "RST"] = "RST"
    user_description: str = ""
    scan_depth: int = 4
    mem_length: int = 40
    created_at: datetime
    updated_at: datetime
    main_api_config_id: str
    scheduler_api_config_id: str | None = None
    preset_id: str
    version: int = 1
```

`name` 作为目录名的约束：仅允许 `[a-zA-Z0-9_\- \u4e00-\u9fff]`，长度 1-64。提供验证器。

### 5.4 Message

文件：`app/models/session.py`

```python
class Message(BaseModel):
    id: str                     # nanoid
    role: Literal["system", "user", "assistant"]
    content: str
    timestamp: datetime
    visible: bool = True
```

### 5.5 Preset / PresetEntry

文件：`app/models/preset.py`

```python
SYSTEM_ENTRIES: list[str] = [
    "Main_Prompt", "lores", "user_description",
    "chat_history", "scene", "user_input"
]

class PresetEntry(BaseModel):
    name: str
    role: Literal["system", "user", "assistant"] = "system"
    content: str = ""
    disabled: bool = False
    comment: str = ""

class Preset(BaseModel):
    id: str
    name: str
    entries: list[PresetEntry]
    version: int = 1
```

---

## 6. 存储层规格

### 6.1 file_io 模块

文件：`app/storage/file_io.py`

#### 文件锁机制

- 模块级维护 `_locks: dict[str, threading.Lock]`，key 为文件绝对路径字符串
- 提供 `_get_lock(path: Path) -> threading.Lock`，使用一个全局 `threading.Lock` 保护 `_locks` 字典的读写
- 所有写操作必须先获取对应路径的锁

#### atomic_write(path: Path, data: bytes) -> None

1. 获取 `path` 的文件锁
2. 写入临时文件 `path.with_suffix(".tmp")`
3. 若 `path` 已存在，复制为 `path.with_suffix(".bak")`
4. 将临时文件 `rename` 为目标路径（原子操作）
5. 异常时删除临时文件，不影响原文件

#### read_json(path: Path) -> dict | list | None

- 文件不存在返回 `None`
- 读取并 `json.loads`，编码 UTF-8
- 不需要加锁（读操作）

#### write_json(path: Path, data: dict | list) -> None

- 调用 `atomic_write`，内容为 `json.dumps(data, ensure_ascii=False, indent=2)`
- 自动创建父目录

### 6.2 分页消息存储

文件：`app/storage/message_store.py`

#### 存储结构

```
sessions/{session_name}/
├── session.json
├── messages.json          # 第 1 页，消息 1-100
├── messages_2.json        # 第 2 页，消息 101-200
├── messages_3.json        # 第 3 页，消息 201-300
└── ...
```

每个文件为 JSON 数组，元素为 Message 的序列化对象。

#### 分页规则

- 每个文件最多存储 100 条消息（常量 `PAGE_SIZE = 100`）
- `messages.json` 为第 1 页
- 第 N 页（N ≥ 2）文件名为 `messages_{N}.json`
- 新消息追加到最新页，满 100 条后创建新页

#### 核心接口

```python
class MessageStore:
    """管理单个会话的消息分页存储"""

    def __init__(self, session_dir: Path): ...

    def get_total_count(self) -> int:
        """返回消息总数（基于文件数和最新页条数）"""

    def get_latest_page_number(self) -> int:
        """返回最新页码"""

    def append(self, message: Message) -> None:
        """追加消息到最新页，满页则创建新页"""

    def load_recent(self, count: int) -> list[Message]:
        """加载最近 count 条消息，跨页读取"""

    def load_page(self, page: int) -> list[Message]:
        """加载指定页的全部消息"""

    def load_for_frontend(self) -> tuple[list[Message], int]:
        """
        前端加载策略：返回最新页全部消息 + 上一页最后 10 条（若有）。
        返回 (messages, total_count)。
        """

    def update_message(self, message_id: str, content: str | None = None, visible: bool | None = None) -> Message | None:
        """按 ID 定位消息所在页，更新字段，原子写回"""

    def delete_message(self, message_id: str) -> bool:
        """按 ID 删除消息。删除后不重排页码，允许页内少于 100 条"""
```

#### 设计决策

- 删除消息后不做跨页重排（避免大量文件重写），允许页内少于 100 条
- `load_for_frontend` 是前端首次加载的专用接口，后续滚动加载通过 `load_page` 按页请求
- 所有写操作使用 `file_io.write_json` 保证原子性

### 6.3 encryption 模块

文件：`app/storage/encryption.py`

#### 密钥管理

```python
def get_or_create_key() -> bytes:
    """
    按优先级获取 Fernet 密钥：
    1. 环境变量 RST_ENCRYPTION_KEY（base64 编码的 32 字节）
    2. {data_dir}/.keyfile 文件内容
    3. 均不存在则生成新密钥，写入 .keyfile 并返回
    """
```

- 密钥在进程生命周期内缓存（模块级变量）
- `.keyfile` 文件权限：创建后不做特殊权限设置（Windows 兼容），但在文档中提醒用户注意保护

#### 加密/解密接口

```python
def encrypt_api_key(plain_key: str) -> str:
    """加密 API Key，返回 Fernet token 的 base64 字符串"""

def decrypt_api_key(encrypted_key: str) -> str:
    """解密 API Key，返回明文"""
```

- 使用 `cryptography.fernet.Fernet`
- 加密结果为 URL-safe base64 字符串，可直接存入 JSON

---

## 7. API 配置 CRUD 规格

### 7.1 API 端点

文件：`app/routers/api_configs.py`

| 方法 | 路径 | 说明 | 请求体 | 响应 |
|------|------|------|--------|------|
| POST | `/api-configs` | 创建配置 | `ApiConfigCreate` | `ApiConfigResponse` (201) |
| GET | `/api-configs` | 列表 | — | `list[ApiConfigSummary]` |
| GET | `/api-configs/{id}` | 详情 | — | `ApiConfigResponse` |
| PUT | `/api-configs/{id}` | 更新 | `ApiConfigUpdate` | `ApiConfigResponse` |
| DELETE | `/api-configs/{id}` | 删除 | — | 204 |
| GET | `/api-configs/{id}/models` | 获取模型列表 | — | `ModelListResponse` |

### 7.2 请求/响应 Schema

#### ApiConfigCreate（创建请求）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | 是 | 配置名称，1-64 字符 |
| provider | ProviderType | 是 | |
| base_url | string | 否 | 不传则使用 provider 默认值 |
| api_key | string | 是 | 明文，后端加密后存储 |
| model | string | 否 | 默认空串 |
| temperature | float | 否 | 默认 0.7，范围 [0, 2] |
| max_tokens | int | 否 | 默认 4096，范围 [1, 1000000] |
| stream | bool | 否 | 默认 true |

#### ApiConfigUpdate（更新请求）

所有字段均为可选（`Optional`）。`api_key` 若传入则重新加密；若不传则保留原加密值。

#### ApiConfigResponse（响应）

与 `ApiConfig` 模型一致，但 `encrypted_key` 字段替换为 `api_key_preview: string`（仅显示后 4 位，格式 `****xxxx`）。绝不返回完整 key 或加密值。

#### ApiConfigSummary（列表项）

| 字段 | 类型 |
|------|------|
| id | string |
| name | string |
| provider | ProviderType |
| model | string |

#### ModelListResponse

```python
class ModelListResponse(BaseModel):
    models: list[str]       # 模型 ID 列表
    error: str | None = None  # 获取失败时的错误信息
```

### 7.3 服务层

文件：`app/services/api_config_service.py`

职责：
- 接收路由层传入的 Create/Update schema，执行业务逻辑
- 创建时：生成 ID、填充默认 base_url、加密 api_key、写入文件
- 更新时：读取现有文件、合并变更、条件加密、写回
- 删除时：检查是否被活跃会话引用（M1 阶段可跳过引用检查，留 TODO）
- 列表时：扫描 `data/api_configs/` 目录，读取每个 JSON 文件的摘要字段

存储路径：`{data_dir}/api_configs/{id}.json`

### 7.4 模型列表获取

文件：`app/providers/` 下各模块

#### 抽象基类

```python
# app/providers/base.py
class BaseProvider(ABC):
    @abstractmethod
    async def list_models(self, base_url: str, api_key: str) -> list[str]:
        """返回可用模型 ID 列表，失败抛出 ProviderError"""

    @abstractmethod
    async def chat(self, ...):
        """M1 第 3-4 周实现，本周留抽象方法"""
```

#### 各 Provider 的 list_models 实现要点

| Provider | 端点 | 认证方式 | 响应解析 |
|----------|------|----------|----------|
| OpenAI | `GET {base_url}/models` | `Authorization: Bearer {key}` | `data[].id` |
| OpenAI 兼容 | 同 OpenAI | 同 OpenAI |
| Deepseek | 同 OpenAI（兼容接口） | 同 OpenAI | 同 OpenAI |
| Anthropic | 无官方 list-models 端点 | — | 返回硬编码常用模型列表 + 提示用户可手动输入 |
| Gemini | `GET {base_url}/models?key={key}` | Query 参数 | `models[].name`，去掉 `models/` 前缀 |

- 所有请求使用 `httpx.AsyncClient`，超时 15 秒
- 失败时不抛异常到路由层，而是返回空列表 + error 信息

#### Provider 注册表

```python
# app/providers/registry.py
def get_provider(provider_type: ProviderType) -> BaseProvider:
    """根据 provider_type 返回对应 Provider 实例"""
```

使用简单字典映射，不需要动态注册。

---

## 8. 前端规格

### 8.1 TypeScript 类型

文件：`frontend/src/types/api-config.ts`

与后端 Schema 对齐，定义以下类型：

- `ProviderType`：联合类型 `"openai" | "gemini" | "deepseek" | "anthropic" | "openai_compat"`
- `ApiConfigSummary`：`{ id, name, provider, model }`
- `ApiConfigDetail`：`{ id, name, provider, base_url, api_key_preview, model, temperature, max_tokens, stream }`
- `ApiConfigCreate`：创建请求体类型
- `ApiConfigUpdate`：更新请求体类型（所有字段可选）
- `ModelListResponse`：`{ models: string[], error?: string }`
- `DEFAULT_BASE_URLS`：`Record<ProviderType, string>` 常量，与后端保持一致

### 8.2 API 请求层

文件：`frontend/src/api/api-configs.ts`

封装以下函数，均基于 `client.ts` 的 axios 实例：

```typescript
export function fetchApiConfigs(): Promise<ApiConfigSummary[]>
export function fetchApiConfig(id: string): Promise<ApiConfigDetail>
export function createApiConfig(data: ApiConfigCreate): Promise<ApiConfigDetail>
export function updateApiConfig(id: string, data: ApiConfigUpdate): Promise<ApiConfigDetail>
export function deleteApiConfig(id: string): Promise<void>
export function fetchModels(id: string): Promise<ModelListResponse>
```

### 8.3 Pinia Store

文件：`frontend/src/stores/api-config.ts`

State：
- `configs: ApiConfigSummary[]` — 配置列表
- `currentConfig: ApiConfigDetail | null` — 当前编辑的配置详情
- `loading: boolean`

Actions：
- `loadConfigs()` — 调用 `fetchApiConfigs`，更新列表
- `loadConfig(id)` — 调用 `fetchApiConfig`，设置 currentConfig
- `saveConfig(data)` — 根据是否有 id 决定 create 或 update，完成后刷新列表
- `removeConfig(id)` — 调用 delete，完成后刷新列表
- `loadModels(id)` — 调用 `fetchModels`，返回结果

### 8.4 组件设计

#### ApiConfigPanel.vue

位置：左侧面板区域，通过图标按钮触发展开/收起。

布局：
```
┌─────────────────────────┐
│ API 配置          [+ 新建] │
│─────────────────────────│
│ ┌─────────────────────┐ │
│ │ 配置项 1 (name)     │ │  ← 点击加载详情进入编辑
│ │ provider · model    │ │
│ ├─────────────────────┤ │
│ │ 配置项 2 (name)     │ │
│ │ provider · model    │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

- 列表项显示 name、provider 图标/标签、model
- 点击列表项 → 加载详情 → 展示 `ApiConfigForm`
- 新建按钮 → 展示空白 `ApiConfigForm`

#### ApiConfigForm.vue

表单字段与交互：

| 字段 | 控件 | 交互说明 |
|------|------|----------|
| name | NInput | 必填 |
| provider | NSelect | 选择后自动填充 base_url 默认值（仅当 base_url 为空或等于上一个 provider 的默认值时） |
| base_url | NInput | 预填默认值，用户可修改 |
| api_key | NInput (type=password) | 编辑模式下显示 `****xxxx` 占位，用户清空后输入新值才提交；不修改则不传该字段 |
| model | ModelSelector | 见下方 |
| temperature | NSlider + NInputNumber | 范围 [0, 2]，步长 0.1 |
| max_tokens | NInputNumber | 范围 [1, 1000000] |
| stream | NSwitch | 默认开启 |

底部操作栏：保存按钮、删除按钮（编辑模式）、取消按钮。

删除操作需二次确认（NPopconfirm 或 NModal）。

#### ModelSelector.vue

- 提供"获取模型列表"按钮，点击后调用 `/api-configs/{id}/models`
- 获取成功：展示 NSelect 下拉列表供选择
- 获取失败：显示错误提示，同时展示 NInput 允许手动输入
- 配置尚未保存（无 id）时：仅显示手动输入框，提示"请先保存配置后获取模型列表"
- 始终保留手动输入的切换入口

### 8.5 面板入口集成

在 `ChatView.vue`（或 `App.vue` 的 aside 区域）添加图标按钮栏，M1 阶段仅启用 API 配置图标，其余图标（Preset、Session、Lore、Appearance）显示为 disabled 状态。

图标栏为纵向排列，固定在左侧，宽度约 48px。点击图标展开对应面板（宽度约 360px），再次点击或点击面板外区域收起。

---

## 9. 错误处理规范

### 后端

- 路由层使用 FastAPI 的 `HTTPException` 返回标准错误
- 统一错误响应格式：`{ "detail": "错误描述" }`

| 场景 | 状态码 | detail |
|------|--------|--------|
| 配置不存在 | 404 | `API config '{id}' not found` |
| 名称重复 | 409 | `API config name '{name}' already exists` |
| 请求体校验失败 | 422 | FastAPI 自动处理 |
| 模型列表获取失败 | 200 | 正常返回，error 字段携带信息 |
| 加密/解密失败 | 500 | `Encryption error` |

### 前端

- API 层捕获 axios 错误，统一通过 Naive UI 的 `useMessage()` 展示错误提示
- 网络错误显示"无法连接到后端"
- 422 错误解析 detail 中的字段级错误信息

---

## 10. 测试要求

### 后端

#### conftest.py

- 提供 `tmp_data_dir` fixture：使用 `tmp_path` 创建临时数据目录结构，并 monkeypatch `settings.RST_DATA_DIR`
- 提供 `async_client` fixture：基于 httpx ASGITransport 的异步测试客户端
- 提供 `sample_api_config` fixture：返回一个有效的 `ApiConfigCreate` 字典

#### test_file_io.py

- 测试 `atomic_write`：正常写入、覆盖写入生成 .bak、写入异常不破坏原文件
- 测试 `read_json`：正常读取、文件不存在返回 None
- 测试 `write_json`：自动创建父目录、内容正确

#### test_encryption.py

- 测试密钥自动生成与缓存
- 测试加密后解密还原
- 测试不同密钥无法解密

#### test_message_store.py

- 测试追加消息不超过 PAGE_SIZE 时只有 `messages.json`
- 测试追加第PAGE_SIZE+1条消息时自动创建 `messages_2.json`
- 测试 `load_recent(n)` 跨页读取正确性
- 测试 `load_for_frontend` 返回最新页全部 + 上一页最后 10 条
- 测试 `load_for_frontend` 仅有一页时不报错
- 测试 `update_message` 能定位跨页消息并更新字段
- 测试 `delete_message` 删除后页内条数减少，不触发跨页重排
- 测试 `delete_message` 对不存在的 ID 返回 False

#### test_api_config_crud.py

- 测试 POST 创建：返回 201，响应包含 `api_key_preview` 而非明文或加密值
- 测试 GET 列表：创建多个后列表长度正确，返回 summary 字段
- 测试 GET 详情：字段完整，`api_key_preview` 格式为 `****xxxx`
- 测试 PUT 更新：仅传 name 时其他字段不变；传 api_key 时重新加密
- 测试 PUT 不传 api_key 时保留原加密值（解密后与原始明文一致）
- 测试 DELETE：删除后 GET 返回 404，列表不再包含
- 测试 GET 不存在的 ID 返回 404
- 测试 POST name 重复返回 409
- 测试 POST provider 选择后 base_url 使用默认值
- 测试 GET models 端点返回 `ModelListResponse` 结构（可 mock httpx 请求）

### 前端

#### 测试范围（Vitest + @vue/test-utils）

M1 第 2 周前端测试聚焦 store 逻辑，组件测试可在第 3-4 周补充：

- `api-config store` 测试：mock axios，验证 `loadConfigs`、`saveConfig`、`removeConfig` 对 state 的变更
- 类型文件无需测试，但需通过 `pnpm type-check` 确认类型正确

---

## 11. 默认 Preset 初始化规格

文件：`app/services/preset_service.py`

### 行为

- 提供 `ensure_default_preset(data_dir: Path) -> str` 函数
- 检查 `{data_dir}/presets/` 下是否存在任何 Preset 文件
- 若不存在，创建默认 Preset 文件并返回其 ID
- 若已存在，返回第一个找到的 Preset ID（M1 阶段只有一份）
- 在 `main.py` 的 lifespan 中调用，紧跟 `ensure_data_dirs()` 之后

### 默认 Preset 内容

```python
DEFAULT_PRESET_ENTRIES = [
    PresetEntry(name="Main_Prompt", role="system", content="You are a helpful assistant."),
    PresetEntry(name="lores", role="system", content=""),
    PresetEntry(name="user_description", role="system", content=""),
    PresetEntry(name="chat_history", role="system", content=""),
    PresetEntry(name="scene", role="system", content=""),
    PresetEntry(name="user_input", role="user", content=""),
]
```

ID 使用 nanoid 生成，name 为 `"Default"`。

---

## 12. main.py lifespan 更新

M0 的 lifespan 仅调用 `ensure_data_dirs()`。本周扩展为：

```
lifespan 启动序列:
1. ensure_data_dirs()— 创建数据目录
2. get_or_create_key()         — 初始化加密密钥（触发缓存）
3. ensure_default_preset()     — 确保默认 Preset 存在
```

同时在 `main.py` 中挂载新路由：

```python
app.include_router(api_configs_router, prefix="/api-configs", tags=["API Configs"])
```

---

## 13. 开发顺序建议

按依赖关系推荐的实现顺序：

```
Day 1-2:  models/ 全部模型定义 + generate_id
          storage/file_io.py + test_file_io.py
          storage/encryption.py + test_encryption.py

Day 3:    storage/message_store.py + test_message_store.py

Day 4:    services/api_config_service.py
          routers/api_configs.py (CRUD 端点)
          test_api_config_crud.py

Day 5:    providers/ 各 Provider 的 list_models 实现
          providers/registry.py
          GET /api-configs/{id}/models 端点集成

Day 6-7:  前端 types/ + api/ + stores/
          组件 ApiConfigPanel + ApiConfigForm + ModelSelector
          ChatView 面板入口集成
          前端 store 单元测试
```

---

## 14. 验收标准

| # | 验收项 | 验证方法 |
|---|--------|----------|
| 1 | 数据模型定义完整，mypy strict 通过 | `uv run mypy app/` 无错误 |
| 2 | atomic_write 保证原子性 | 单元测试：写入中断不破坏原文件 |
| 3 | 加密密钥自动生成并持久化 | 首次启动后 `.keyfile` 存在，重启后密钥一致 |
| 4 | API 配置 CRUD 全链路可用 | 通过 httpx 测试客户端完成创建→列表→详情→更新→删除 |
| 5 | API Key 不以明文出现在存储文件和 API 响应中 | 检查 JSON 文件内容为加密值，GET 响应仅含 preview |
| 6 | 模型列表获取对 OpenAI 类 Provider 可用 | mock 测试验证解析逻辑；可选：真实 Key 手动验证 |
| 7 | 模型列表获取失败时返回空列表 + error | mock 超时/401 场景测试 |
| 8 | 分页消息存储在 100 条边界正确分页 | 单元测试覆盖边界场景 |
| 9 | 前端 API 配置面板可展开，CRUD 操作可完成 | 手动验证：创建→编辑→删除配置，模型列表获取 |
| 10 | 前端 TypeScript 类型检查通过 | `pnpm type-check` 无错误 |
| 11 | 全部后端测试通过 | `uv run pytest` 全部 pass |
| 12 | ruff + eslint 无错误 | `scripts/lint.bat` 通过 |

---

文档完整了。核心设计点回顾：

- ID 用 nanoid 12 位（短且够用，比 UUID 友好）
- 消息分页采用你定义的策略，删除不重排避免写放大
- Anthropic 模型列表走硬编码兜底（他们确实没有稳定的 list models 公开端点）
- 加密密钥自动生成降低用户配置门槛，环境变量覆盖留给高级用户
- M1 阶段 Preset 硬编码但仍写入文件系统，为 M2 的 Preset CRUD 铺路