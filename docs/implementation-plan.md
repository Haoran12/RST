# RST MVP 实施方案

## 1. 文档目标

这份文档用于把 `RST` 从“完整愿景”收敛为“可直接开工的 MVP 规格”。

本版只覆盖首个可交付版本需要冻结的内容：

- Android 优先的 Flutter + Rust 单仓架构
- OpenAI-compatible Provider 的完整聊天闭环
- `ST` 模式世界书
- `RST` 模式基础人物与场景状态
- Rust 统一负责检索、Prompt 组装、Token Budget 与状态校验

以下能力明确后置，不作为 MVP 阻塞项：

- Agent 三阶段多人物模式
- 自动 Lore 更新器
- 记忆系统与 `known_by` 不对称可见性
- 向量检索
- 多 Provider 正式支持
- 深度 Windows 桌面体验优化

---

## 2. MVP 范围

### 2.1 In Scope

- 创建、打开、重命名、删除 Session
- 配置 OpenAI-compatible API，并完成流式聊天
- Preset 编辑与 Prompt 组装
- 请求日志查看，默认脱敏和截断
- `ST` 模式世界书：constant 常驻 + keyword 命中注入
- `RST` 模式：
  - Session 绑定独立世界状态
  - Character CRUD
  - Character Form / Relation 编辑
  - `public_* / private_*` 字段分层
  - SceneState 手动编辑
  - direct injection 检索与注入

### 2.2 Out of Scope

- Anthropic / Gemini / DeepSeek 原生适配
- LLM 驱动的 scheduler / updater
- Agent Phase 1/2/3 并发管线
- 自动 Scene 覆盖写回
- Windows 专属交互增强

### 2.3 平台策略

- 主验收平台：Android
- 次验收平台：Windows，仅保证基础运行与布局不崩溃
- Android UI 的交互、导航与聊天操作基线参照 `Tavo`，但配色与品牌视觉保持 RST 自主设计；具体规范以 `docs/DESIGN.md` 为准

---

## 3. 技术选型

| 层 | 技术 | 用途 |
|---|---|---|
| UI | Flutter 3.x + Dart | 跨平台 UI、状态管理、HTTP/SSE |
| 状态管理 | Riverpod 2.x | 页面状态与依赖注入 |
| HTTP | dio | OpenAI-compatible 流式响应 |
| 核心库 | Rust + flutter_rust_bridge v2 | 存储、检索、Prompt、预算、加密 |
| 存储 | SQLite + FTS5 | Session、Message、Lore、Scene、Character |
| 配置 | JSON | API Config、Preset、Theme |
| NLP | jieba-rs + 自实现 BM25 | 分词与检索 |
| 加密 | Rust aes-gcm / ring | API key 本地加密 |

选择原则：

- 运行时业务规则尽量集中在 Rust，避免 Dart/Rust 双份逻辑
- SQLite 作为运行时状态的唯一持久化中心
- JSON 仅保留静态配置，避免跨文件一致性问题

---

## 4. 架构边界

### 4.1 Flutter / Dart

职责：

- 页面渲染与交互
- Provider 状态流转
- OpenAI-compatible HTTP/SSE 调用
- 流式消息生命周期管理
- 调用 Rust FFI 并消费结果

非职责：

- 不在 Dart 内做 Lore 可见性判定
- 不在 Dart 内拼接检索规则
- 不在 Dart 内实现 Token Budget
- 不在 Dart 内维护 Prompt 模板顺序

### 4.2 Rust

职责：

- SQLite 读写、迁移与事务
- Lore / Character / Scene 检索
- BM25 检索与 keyword 匹配
- Prompt 组装
- Token Budget 估算与裁剪
- `StateUpdateDiff` 与字段可见性校验
- API key 加密与解密

非职责：

- 不直接发起 Provider HTTP 请求
- 不管理 Flutter 页面状态
- 不承担 SSE UI 展示

### 4.3 设计原则

- 所有“检索什么、注入什么、能看到什么、怎么裁剪”只在 Rust 定义一次
- Dart 只做编排，不做规则复制
- 先实现单路径闭环，再为后置能力预留接口

---

## 5. 存储方案

### 5.1 总体原则

MVP 统一采用“运行时 SQLite + 静态 JSON 配置”。

### 5.2 目录布局

```text
{app_data}/
├── workspace.db
├── config/
│   ├── api_configs/{api_id}.json
│   ├── presets/{preset_id}.json
│   └── themes/{theme_id}.json
├── world_books/
│   └── {world_book_id}.db
├── sessions/
│   └── {session_id}/
│       └── session.db
└── logs/
    └── {date}/
        └── {log_id}.json
```

### 5.3 数据库职责划分

`workspace.db` 负责：

- `session_catalog`
- `world_book_catalog`
- `config_catalog`（可选缓存）

约束：

- `workspace.db` 是工作区缓存与索引层，不是真值来源
- Session、ST 世界书、API Config、Preset、Theme 的真值来源分别是各自目录下的数据库或 JSON 文件
- 系统在进入相关列表页或首次读取目标对象时执行懒扫描
- 发现新文件时自动注册或刷新 `workspace.db`
- 若发现重复 ID，只保留本次扫描中第一个读取到的对象，其余对象忽略并记录冲突日志
- 对缺失可补的字段尽量在运行时补全并继续使用；无法容纳时将对象标记为错误并对 UI 报错
- 对缺失索引或损坏的 FTS/缓存，系统应自动重建

`session.db` 负责：

- `sessions`
- `session_runtime_state`
- `messages`
- `scene_state`
- `lore_entries` (`scope=session_rst`)
- `fts_lore`
- `characters`
- `character_forms`
- `character_relationships`

`world_books/{world_book_id}.db` 负责：

- `world_book_meta`
- `lore_entries` (`scope=global_st`)
- `fts_lore`

约束：

- `ST` Session 只引用一个全局世界书
- `RST` Session 的 Lore 直接存放在自己的 `session.db`
- 运行时不同时写多份 Lore 真值数据

### 5.4 懒扫描与导入规则

- 离线拷贝到约定目录的 `session.db`、`world_book.db`、`api_config.json`、`preset.json`、`theme.json` 都应被系统识别
- 懒扫描触发点：
  - 打开 Session 列表时扫描 `sessions/`
  - 打开 World Book 列表时扫描 `world_books/`
  - 打开对应配置列表或首次按 ID 读取配置时扫描 `config/`
- 懒扫描结果写入 `workspace.db` 作为缓存，供后续快速列表与状态展示
- 若文件在系统外被替换或新增，下一次相关懒扫描应让改动生效
- 若文件在系统外被删除，下一次相关懒扫描应将缓存项标记失效或清理
- 不要求用户必须先经过系统 UI 创建对象，符合格式的离线拷贝文件应可直接导入

### 5.5 事务与一致性

- 一次用户发送消息的本地写入必须保证：
  - user message 入库
  - assistant streaming 占位消息创建
  - 流结束后 assistant 消息完成态更新
- 一次 Session / World Book 的创建、重命名、删除必须同时满足：
  - 真值文件已创建/重命名/删除
  - `workspace.db` 缓存已同步
- RST 中一次状态修改使用单事务提交
- 失败时回滚事务，不允许出现“scene 已写入但 character 未写入”的半状态
- 工作区级文件操作失败时，不允许留下缓存已改但真值文件未同步的半状态

### 5.6 日志

- 仅保存脱敏后的 `request_preview_json` 与 `response_preview_json`
- 超过阈值的 payload 必须截断，并记录 `payload_truncated=true`
- API key 绝不进入日志
- 日志列表展示摘要，详情页只展示 preview，不展示完整原始报文

---

## 6. 核心数据模型

### 6.1 SessionConfig

用户可编辑配置，持久化于 `sessions` 表：

```text
session_id
session_name
mode(ST|RST)
user_description
scan_depth
mem_length
main_api_config_id
preset_id
st_world_book_id
lore_injection_mode(st_keyword|rst_direct)
lore_budget
max_entry_tokens
created_at
updated_at
version
```

说明：

- `session_id` = Session 的稳定主键，同时对应目录名 `sessions/{session_id}/`
- `session_name` = 用户可见名称，可修改，不参与对象寻址
- `mode` = 该 Session 的检索与注入模式开关；MVP 仅允许 `ST` 或 `RST`
- `user_description` = 当前用户在该 Session 内的补充描述，属于 Prompt 主上下文，不等同于系统指令
- `scan_depth` = 参与 Lore 检索的最近可见消息条数
- `mem_length` = 参与 `chat_history` 注入的最近可见消息条数
- `main_api_config_id` = 当前 Session 默认使用的 API 配置 ID
- `preset_id` = 当前 Session 绑定的预设 ID；Prompt 组装和生成参数默认从该预设读取
- `st_world_book_id` = ST 模式绑定的全局世界书 ID；RST 模式必须为空
- `lore_injection_mode` = Lore 注入策略；MVP 中只允许 `st_keyword` 或 `rst_direct`
- `lore_budget` = 本轮 Prompt 中分配给 Lore 注入块的总 token 预算
- `max_entry_tokens` = 单条 LoreEntry 注入前允许占用的最大 token 数
- `version` = SessionConfig 自身的 schema 版本，不代表会话消息版本
- `mode=ST` 时要求 `st_world_book_id` 非空，且 `lore_injection_mode=st_keyword`
- `mode=RST` 时要求 `st_world_book_id` 为空，且 `lore_injection_mode=rst_direct`
- MVP 不包含 `scheduler_api_config_id`
- MVP 不包含 `agent_mode_enabled`
- 这些字段在后续版本通过迁移新增

### 6.2 ApiConfig

API 配置真值来源是 `config/api_configs/{api_id}.json`。

```text
api_id
name
provider_type(openai|openai_compatible)
base_url
request_path
api_key_ciphertext
api_key_hint
default_model
custom_headers_json
request_timeout_ms
created_at
updated_at
version
```

说明：

- `api_id` = API 配置稳定主键，同时对应文件名 `{api_id}.json`
- `name` = 用户可见名称，可修改，不参与对象寻址
- `provider_type` = 服务类型；`openai` 使用官方 Responses API，`openai_compatible` 使用 Chat Completions 协议
- `base_url` = Provider 服务根地址，不包含具体聊天路径
- `request_path` = 实际请求路径；`openai` 默认 `/v1/responses`，`openai_compatible` 默认 `/v1/chat/completions`
- `api_key_ciphertext` = 本地加密后的 API key 真值；明文不得落盘
- `api_key_hint` = 用于 UI 展示的脱敏提示，例如尾号或前缀摘要
- `default_model` = 当前 API 配置默认使用的模型名
- `custom_headers_json` = 附加请求头；用于兼容 OpenAI-compatible 服务的非标准鉴权或版本头
- `request_timeout_ms` = 单次请求默认超时
- `version` = ApiConfig 文件 schema 版本

规则：

- API key 只允许在请求发起前短暂解密，不进入日志、不进入 Prompt、不回传给 UI
- `base_url` 与 `request_path` 组合后，必须能稳定构成最终请求 URL
- `default_model` 是默认值；若后续版本支持临时切换模型，只能作为运行时覆盖，不改写 ApiConfig 真值
- `custom_headers_json` 中若包含敏感头，日志层必须一并脱敏
- `provider_type=openai` 时，必须按 Responses API 字段发送
- `provider_type=openai_compatible` 时，必须按 Chat Completions 协议发送
- MVP 中不允许手工切换 `OpenAI` 到 Chat Completions，也不允许手工切换 `OpenAI-compatible` 到 Responses

### 6.3 PresetConfig

Preset 真值来源是 `config/presets/{preset_id}.json`。

```text
preset_id
name
description
main_prompt
temperature
top_p
presence_penalty
frequency_penalty
max_completion_tokens
stop_sequences_json
created_at
updated_at
version
```

说明：

- `preset_id` = Preset 的稳定主键，同时对应文件名 `{preset_id}.json`
- `name` = 用户可见名称，可修改，不参与对象寻址
- `description` = 仅用于 UI 说明与选择器展示，不参与 Prompt 组装
- `main_prompt` = Prompt 主系统指令文本，对应文档中的 `Main_Prompt`
- `temperature` / `top_p` / `presence_penalty` / `frequency_penalty` = 生成参数；由 Dart 在实际请求时透传给 Provider
- `max_completion_tokens` = 该预设默认希望保留给模型输出的 token 数
- `stop_sequences_json` = Provider 请求时使用的停止序列数组；为空表示不额外设置
- `version` = Preset 文件 schema 版本

规则：

- `build_prompt` 只消费 `main_prompt` 等 Prompt 相关字段，不承担 HTTP 参数透传
- Dart 发请求时必须以当前 Session 绑定的 Preset 为默认生成参数来源
- 若 Provider 不支持某项生成参数，Dart 可在请求层忽略，但不得改写 Preset 真值

### 6.4 SessionRuntimeState

运行时状态单独持久化于 `session_runtime_state` 表，不与用户配置混写：

```text
session_id
active_message_id
streaming_status(idle|receiving|error)
last_error
last_prompt_token_estimate
last_completion_token_estimate
last_used_model
last_request_started_at
last_request_finished_at
updated_at
```

规则：

- `SessionRuntimeState` 是正式持久化模型，`load_session` 必须稳定返回
- 应用重启后若发现 `streaming_status=receiving`，必须在加载时收敛为 `error`
- 因异常中断导致的流式失败，`last_error` 应写入可展示的错误码或错误摘要
- 成功完成一轮请求后，保留最近一次 token 估算和 model 信息，供日志与调试展示

### 6.5 WorldBookMeta

世界书真值来源是 `world_books/{world_book_id}.db` 中的 `world_book_meta` 单行记录。

```text
world_book_id
name
description
created_at
updated_at
version
```

说明：

- `world_book_id` = 世界书稳定主键，同时对应数据库文件名 `{world_book_id}.db`
- `name` = 世界书用户可见名称，可修改，不参与对象寻址
- `description` = 世界书简介，仅用于 UI 展示与选择器说明
- `version` = 世界书 schema 版本

规则：

- `list_world_books`、`rename_world_book` 的 `name` 与 `updated_at` 以 `world_book_meta` 为真值来源
- 不允许仅靠文件名推导世界书名称
- 每个世界书数据库必须且只能有一条 `world_book_meta` 记录

### 6.6 Message

```text
message_id
session_id
role(system|user|assistant)
content
visible
status(pending|streaming|completed|error)
created_at
updated_at
```

### 6.7 LoreEntry

```text
id
owner_id
scope(global_st|session_rst)
name
category
content
keywords_json
disabled
constant
keyword_mode(exact_tokens)
tags_json
created_at
updated_at
```

说明：

- `owner_id` 在 `scope=global_st` 时等于 `world_book_id`，在 `scope=session_rst` 时等于 `session_id`
- `name` = Lore 条目的人类可读标题
- `category` = Lore 的 UI 分类字段，不直接参与检索打分
- `content` = 真正注入 Prompt 的正文内容
- `keywords_json` = ST 模式 keyword 命中的关键词数组；`constant=true` 时可为空且默认忽略
- `disabled=true` 的条目不可参与检索或注入
- `constant=true` 的条目在预算允许时恒定进入 Lore 注入块
- `keyword_mode=exact_tokens` 表示按分词后的完整 token 命中，不做子串模糊匹配
- `tags_json` = 仅用于 UI 筛选与管理，不直接参与 MVP 检索逻辑

规则：

- ST 模式下，非 `constant` 条目默认依赖 `keywords_json` 做命中
- RST 模式下，`keywords_json` 可为空；检索主要依赖 direct injection / BM25
- `keywords_json` 为空且 `constant=false` 的 ST LoreEntry 视为不可命中条目，应在导入或编辑时提示

### 6.8 Character

```text
character_id
session_id
name
gender
race
birth
homeland
aliases_json
role
faction
public_profile_json
private_profile_json
public_state_json
private_state_json
disabled
tags_json
created_at
updated_at
```

说明：

- MVP 人物模型不包含记忆字段
- 记忆条目、`known_by` 和不对称记忆检索全部后置

### 6.9 SceneState

```text
session_id
current_time
current_location
present_character_ids_json
notes
updated_at
updated_by(user|system_suggestion)
```

规则：

- MVP 中 `SceneState` 的唯一真值来自用户确认后的数据库记录
- 模型只能生成 suggestion，不能直接覆盖已确认值
- 编辑页保存时始终提交完整 `SceneState` 对象，不做字段级 merge
- 预览态仅存在于内存或临时 UI 状态中，不通过 `apply_state_diff` 持久化

### 6.10 RequestLog

```text
log_id
session_id
provider
model
status(success|error)
request_time
response_time
duration_ms
prompt_tokens
completion_tokens
total_tokens
stop_reason
redacted
payload_truncated
request_preview_json
response_preview_json
```

---

## 7. Prompt 与检索流程

### 7.1 ST 模式

1. Dart 拉取当前 Session、Preset、最近消息
2. Rust 从 `st_world_book_id` 对应的全局世界书读取 Lore
3. Rust 根据最近消息做 keyword 分词匹配
4. Rust 取 constant Lore + keyword 命中 Lore
5. Rust 执行 Token Budget
6. Rust 输出最终 Prompt
7. Dart 发送到 OpenAI-compatible API

调试路径：

- UI 可额外调用 `search_lore` 查看命中条目与分数
- `search_lore` 仅用于预览和排错，不能作为正式发送前置步骤

### 7.2 RST 模式

1. Dart 拉取当前 Session、Preset、最近消息
2. Rust 读取 SceneState 与当前 Session 下的 Lore / Character
3. Rust 根据 scene 和消息执行 direct injection 检索
4. Rust 对角色私有字段做可见性裁剪
5. Rust 执行 Token Budget
6. Rust 输出最终 Prompt
7. Dart 发送到 OpenAI-compatible API

调试路径：

- UI 可额外调用 `search_lore` 预览当前 scene 下的候选 Lore
- 正式请求仍只允许依赖 `build_prompt`

### 7.3 Token Budget 规则

优先级从高到低：

1. `Main_Prompt`、`user_description`
2. `scene`
3. `constant lore`
4. `user_input`
5. 命中 Lore / RST 检索结果
6. chat history

MVP 规则：

- 使用统一估算器计算 token
- 预留固定安全余量，避免请求因超长失败
- 历史消息优先从最旧开始裁剪
- 系统指令、scene 和 `user_input` 不可裁剪为零

### 7.4 Prompt 组装模板约定

MVP 中，`build_prompt` 输出给 Provider 的结构固定为：

1. 1 条 `system` 消息
2. 0..N 条按时间顺序排列的历史消息
3. 1 条当前轮 `user_input`

其中 `system` 消息内部按以下顺序拼装文本块：

1. `Preset.main_prompt`
2. `Session.user_description`
3. 模式说明块
4. `SceneState` 摘要块
5. `constant lore` 块
6. 非 constant 的命中 Lore 块

块级规则：

- `Preset.main_prompt` 始终位于最前，作为最高优先级指令
- `Session.user_description` 紧随其后，不允许跑到历史消息之后
- `SceneState` 仅在 RST 模式或存在有效场景信息时注入
- `constant lore` 在普通命中 Lore 之前
- 普通命中 Lore 按检索结果顺序拼接
- 历史消息只包含 `visible=true` 的消息，且保持原始时序
- 当前轮 `user_input` 不与历史消息合并，不复用 composer 草稿以外的来源

格式规则：

- 每个文本块之间使用稳定分隔符，避免因换行数量不同导致 Prompt 抖动
- Lore 块必须带条目标题，便于调试和审查
- 不在 MVP 中输出 XML、JSON schema prompt 或复杂 role 嵌套
- `build_prompt` 不输出空块；空字符串字段直接跳过

职责边界：

- Rust 负责决定哪些块出现、顺序如何、哪些内容被裁剪
- Dart 只负责把 `PromptBuildResult.messages` 原样交给 Provider
- Dart 不得在发送前追加系统提示、临时 lore 或隐藏消息

### 7.5 OpenAI / OpenAI-compatible 字段约束

内部统一字段：

- `messages`
- `model`
- `output_token_limit`
- `temperature`
- `top_p`
- `presence_penalty`
- `frequency_penalty`
- `stop_sequences`
- `stream`
- `reasoning_effort`
- `verbosity`

规则：

- Rust `build_prompt` 只负责产出统一的 `messages`
- Dart 网络层负责把统一字段按 `ApiConfig.provider_type` 映射为实际请求体
- 业务层与页面层禁止直接使用 `max_tokens`、`max_completion_tokens`、`max_output_tokens` 这类 wire 字段名

#### 7.5.1 `openai`

映射规则：

- 使用 `POST /v1/responses`
- 使用 `input` 承载上下文
- `output_token_limit -> max_output_tokens`
- `reasoning_effort -> reasoning.effort`
- `verbosity -> text.verbosity`

约束：

- MVP 中不额外拆分 `instructions`；统一把 `build_prompt` 产出的完整消息序列映射到 `input`
- MVP 不使用 `previous_response_id` 管理会话状态，仍由本地消息历史重放上下文
- MVP 不依赖 Responses 的持久化会话能力
- MVP 不使用 `n`

#### 7.5.2 `openai_compatible`

映射规则：

- 使用 `POST /v1/chat/completions`
- 使用 `messages` 承载上下文
- `output_token_limit -> max_tokens`

约束：

- 主系统指令在 wire 层使用 `system` 角色
- 不发送 `max_completion_tokens`
- 不发送 `reasoning_effort`
- 不发送 `verbosity`
- 不发送 OpenAI 新版专属的嵌套对象字段
- 若第三方兼容服务额外支持新字段，只能通过后续显式扩展，不在 MVP 主链路默认启用
- MVP 不使用 `n`

#### 7.5.3 新旧字段兼容原则

- 对 OpenAI 官方，只使用 Responses API，不在 MVP 主链路走 Chat Completions
- 对第三方 OpenAI-compatible 服务，只使用 Chat Completions 协议，不在 MVP 主链路走 Responses
- OpenAI-compatible 路径优先保证 `messages + model + stream + max_tokens` 这一最小兼容集合
- 同一请求不得同时发送 `max_tokens` 与 `max_completion_tokens`
- 同一请求不得同时混用 `instructions` 与人为重复注入到消息数组中的系统块
- 若 `provider_type` 与目标服务实际能力不匹配，视为配置错误，不在运行时隐式猜测切换

---

## 8. Rust FFI 最小闭环

MVP 固定以下接口，详细契约见 [contracts.md](./contracts.md)。

- `list_sessions`
- `create_session`
- `save_session`
- `rename_session`
- `delete_session`
- `list_world_books`
- `create_world_book`
- `rename_world_book`
- `delete_world_book`
- `list_presets`
- `create_preset`
- `rename_preset`
- `delete_preset`
- `get_preset`
- `save_preset`
- `list_api_configs`
- `create_api_config`
- `rename_api_config`
- `delete_api_config`
- `get_api_config`
- `save_api_config`
- `load_session`
- `create_message`
- `update_message_content`
- `set_message_status`
- `set_message_visibility`
- `delete_messages`
- `list_messages`
- `search_lore`
- `build_prompt`
- `save_scene_state`
- `apply_state_diff`
- `list_request_logs`
- `get_request_log`

约束：

- Dart 不能绕过 `build_prompt` 自行拼 Prompt
- `search_lore` 只用于调试和预览，不能作为生产发送链路前置步骤
- `save_scene_state` 是 Scene 编辑页唯一持久化入口
- `apply_state_diff` 即使 MVP 初期主要供手工编辑路径调用，也必须保留字段校验逻辑
- `set_message_visibility` 后，隐藏消息在后续 Prompt 组装和 RST 调度中一律忽略
- `delete_messages` 仅删除指定消息，不负责自动重写历史轮次
- Preset 的 Prompt 字段与生成参数语义必须以 `PresetConfig` 为唯一真值
- API 地址、鉴权和默认模型语义必须以 `ApiConfig` 为唯一真值

---

## 9. 推荐项目结构

```text
RST/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── bridge/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── chat_service.dart
│   │   │   ├── session_service.dart
│   │   │   └── log_service.dart
│   │   └── routing/
│   ├── features/
│   │   ├── chat/
│   │   ├── lore/
│   │   ├── character/
│   │   ├── session/
│   │   ├── preset/
│   │   ├── settings/
│   │   └── log/
│   └── shared/
│       ├── widgets/
│       └── theme/
├── rust/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── api/
│       ├── models/
│       ├── prompt/
│       ├── storage/
│       ├── retrieval/
│       └── security/
└── docs/
    ├── implementation-plan.md
    ├── contracts.md
    └── DESIGN.md
```

---

## 10. 里程碑

### Phase 0: 仓库脚手架

- Flutter 项目初始化
- Rust 库初始化
- flutter_rust_bridge 接通
- Android 基础运行
- Windows 基础运行

### Phase 1: 最小聊天闭环

- API Config JSON 存储与加密
- Workspace 懒扫描缓存 + Session CRUD
- Message 状态机（占位、流式更新、完成、失败）
- OpenAI-compatible 聊天
- 请求日志
- `SessionRuntimeState` 持久化

验收标准：

- 用户能创建 Session 并完成一轮聊天
- 关闭 App 后重新打开还能继续对话
- 异常中断后的流式状态会收敛为可展示错误态
- API key 仅以加密形式落盘，日志中无明文泄漏

### Phase 2: Preset + ST Lore

- Preset CRUD
- ST World Book CRUD
- `build_prompt`
- `search_lore` 调试预览
- keyword 检索
- constant Lore 注入
- Token Budget

验收标准：

- ST 模式下 Lore 命中稳定
- 预算裁剪不破坏系统指令

### Phase 3: RST 基线

- Session 独立 `session.db`
- Character CRUD
- Character Form / Relation 编辑
- SceneState 手动编辑
- `save_scene_state` 整对象替换
- RST direct injection
- private/public 字段隔离

验收标准：

- 每个 RST Session 拥有独立世界状态
- private 字段不会进入公共注入块
- Scene 编辑页保存后，下次 prompt 注入使用新值

### Phase 4: 稳定性与体验

- 错误态与重试
- 编辑体验优化
- Android 交互打磨
- Windows 基础适配补齐

---

## 11. 后置能力预留

以下能力不进入 MVP 验收，但保留类型和接口扩展位：

- `scheduler_api_config_id`
- `agent_api_config_id`
- `CharacterViewForSelf`
- `CharacterViewForOthers`
- `AgentPromptContext`
- 向量检索字段
- LLM Scene 建议结构

要求：

- 这些类型只能出现在扩展文档和占位模型中
- 不能污染 MVP 主链路接口

---

## 12. 测试计划

### 单元测试

- Rust：token 估算、Budget 裁剪、keyword 匹配、BM25 排序、字段可见性校验
- Rust：懒扫描缓存与真值文件一致性、冲突 ID 忽略规则、索引自动重建、SceneState 整对象保存
- Dart：Provider 状态流转、SSE 流式消息更新、错误态恢复
- Dart：`openai` 与 `openai_compatible` 两种模式下的请求体字段映射正确性

### 集成测试

- 创建 Session -> 发送消息 -> 流式完成 -> 持久化恢复
- 创建 / 重命名 / 删除 API Config，并验证默认模型与请求地址可读取
- 创建 / 重命名 / 删除 Session 与 ST World Book
- 创建 / 重命名 / 删除 Preset，并验证 Session 绑定不丢失
- 离线拷贝 Session / World Book / Config 文件后，在对应页面懒扫描并生效
- `openai` / `openai_compatible` 两种配置下均能形成预期请求体
- ST 模式 Lore 命中与注入顺序
- `search_lore` 仅用于调试，不影响正式发送结果
- RST 模式 direct injection 与 SceneState 注入
- RequestLog 脱敏与截断

### 验收测试

- Android 真机完成完整聊天流程
- RST Session 独立世界状态不串档
- private 数据不会出现在公共上下文和日志中
- 重启后 `SessionRuntimeState` 与错误态可恢复

### 后置能力回归

- MVP 主链路中不存在记忆表依赖
- Character 编辑页不存在记忆入口
- `search_lore` 与 `build_prompt` 均不返回记忆相关命中

---

## 13. 非目标提醒

本阶段不是“把 v3 全部做完”，而是确保我们拥有：

- 明确的 MVP 边界
- 不重复的模块职责
- 能落地的存储与事务模型
- 可直接编码的 FFI 契约
- 可验证的测试清单

完成这份规格后，下一步应优先开始脚手架和最小聊天闭环，而不是直接进入 Agent 或自动更新链路。
