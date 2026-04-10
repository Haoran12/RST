# RST MVP 接口契约

## 1. 目标

本文件冻结 Dart 与 Rust 在 MVP 阶段的最小协作接口，避免出现：

- Dart 自行拼 Prompt
- Dart 自行做 Lore 检索规则
- Rust 与 Dart 维护两套字段语义

以下签名为逻辑契约，不强制绑定具体代码生成格式。

---

## 2. 基础类型

### SessionConfig

```ts
SessionConfig {
  sessionId: string
  sessionName: string
  mode: "ST" | "RST"
  userDescription: string
  scanDepth: number
  memLength: number
  mainApiConfigId: string
  presetId: string
  stWorldBookId?: string
  loreInjectionMode: "st_keyword" | "rst_direct"
  loreBudget: number
  maxEntryTokens: number
  createdAt: string
  updatedAt: string
  version: number
}
```

约束：

- `userDescription` 属于当前 Session 的上下文描述，不等同于 Preset 的系统指令
- `scanDepth` 与 `memLength` 都只统计 `visible=true` 的消息
- `presetId` 决定当前 Session 默认使用的预设
- `mode="ST"` 时要求 `stWorldBookId` 非空
- `mode="RST"` 时要求 `stWorldBookId` 为空

### ApiConfig

```ts
ApiConfig {
  apiId: string
  name: string
  providerType: "openai" | "openai_compatible"
  baseUrl: string
  requestPath: string
  apiKeyCiphertext: string
  apiKeyHint?: string
  defaultModel: string
  customHeaders: Record<string, string>
  requestTimeoutMs?: number
  createdAt: string
  updatedAt: string
  version: number
}
```

约束：

- `apiKeyCiphertext` 是唯一允许持久化的 API key 真值
- `apiKeyHint` 仅用于 UI 脱敏展示
- `providerType="openai"` 时固定走 Responses API
- `providerType="openai_compatible"` 时固定走 Chat Completions 协议
- `baseUrl + requestPath` 必须能稳定构成最终聊天请求地址
- `defaultModel` 是当前 Session 默认模型来源，除非运行时显式覆盖
- `customHeaders` 中的敏感值在日志中必须脱敏

### PresetConfig

```ts
PresetConfig {
  presetId: string
  name: string
  description?: string
  mainPrompt: string
  temperature?: number
  topP?: number
  presencePenalty?: number
  frequencyPenalty?: number
  maxCompletionTokens?: number
  stopSequences: string[]
  createdAt: string
  updatedAt: string
  version: number
}
```

约束：

- `mainPrompt` 是 Prompt 主系统指令文本
- 生成参数由 Dart 在请求 Provider 时透传；Rust 的 `buildPrompt` 不直接消费这些 HTTP 参数
- `stopSequences` 为空数组时表示不额外传停止序列

### WorldBookMeta

```ts
WorldBookMeta {
  worldBookId: string
  name: string
  description?: string
  createdAt: string
  updatedAt: string
  version: number
}
```

### SessionRuntimeState

```ts
SessionRuntimeState {
  sessionId: string
  activeMessageId?: string
  streamingStatus: "idle" | "receiving" | "error"
  lastError?: string
  lastPromptTokenEstimate?: number
  lastCompletionTokenEstimate?: number
  lastUsedModel?: string
  lastRequestStartedAt?: string
  lastRequestFinishedAt?: string
  updatedAt: string
}
```

约束：

- 该模型持久化存储于 `session.db`
- `loadSession` 必须始终返回该对象
- 若加载时发现上次状态仍为 `receiving`，Rust 应先将其收敛为 `error`

### MessageRecord

```ts
MessageRecord {
  messageId: string
  sessionId: string
  role: "system" | "user" | "assistant"
  content: string
  visible: boolean
  status: "pending" | "streaming" | "completed" | "error"
  createdAt: string
  updatedAt: string
}
```

### SceneState

```ts
SceneState {
  sessionId: string
  currentTime?: string
  currentLocation?: string
  presentCharacterIds: string[]
  notes?: string
  updatedAt: string
  updatedBy: "user" | "system_suggestion"
}
```

约束：

- MVP 中持久化的 SceneState 必须是完整对象
- `updatedBy="system_suggestion"` 只允许用于未确认建议的预览态或显式接受后的保存记录

### RequestLog

```ts
RequestLog {
  logId: string
  sessionId: string
  provider: string
  model: string
  status: "success" | "error"
  requestTime: string
  responseTime?: string
  durationMs?: number
  promptTokens?: number
  completionTokens?: number
  totalTokens?: number
  stopReason?: string
  redacted: boolean
  payloadTruncated: boolean
  requestPreviewJson?: string
  responsePreviewJson?: string
}
```

---

## 3. Prompt 契约

### PromptBuildRequest

```ts
PromptBuildRequest {
  sessionId: string
  userInput: string
  includeMessageIds: string[]
  maxContextTokens: number
  reservedCompletionTokens: number
}
```

### PromptBuildResult

```ts
PromptBuildResult {
  messages: Array<{
    role: "system" | "user" | "assistant"
    content: string
  }>
  usedLoreIds: string[]
  omittedLoreIds: string[]
  promptTokenEstimate: number
  truncated: boolean
  truncationNotes: string[]
}
```

约束：

- `PromptBuildResult.messages` 是唯一允许送入 Provider 的 Prompt 结果
- `PromptBuildResult.messages[0]` 必须是按统一模板拼装出的单条 `system` 消息
- 历史消息必须保持原始时序，且只允许包含 `visible=true` 的消息
- 当前轮 `userInput` 必须作为最后一条 `user` 消息出现
- 截断策略必须由 Rust 执行
- Dart 只能显示 `usedLoreIds` 等调试信息，不能自行改写注入内容
- Dart 必须基于统一内部字段做请求体映射，不得让 UI 直接操作 OpenAI wire 字段名

---

## 4. Lore 检索契约

### LoreRetrievalQuery

```ts
LoreRetrievalQuery {
  sessionId: string
  recentText: string
  scanDepth: number
  sceneOverride?: SceneState
  maxResults: number
  maxEntryTokens: number
}
```

### LoreRetrievalHit

```ts
LoreRetrievalHit {
  id: string
  sourceType: "lore" | "character_public"
  title: string
  content: string
  score: number
  estimatedTokens: number
  constant: boolean
}
```

### LoreRetrievalResult

```ts
LoreRetrievalResult {
  hits: LoreRetrievalHit[]
  totalEstimatedTokens: number
  truncated: boolean
}
```

MVP 约束：

- `mode`、`presetId`、`stWorldBookId` 由 `sessionId` 对应的 SessionConfig 决定，不在调用时重复传入
- `search_lore` 仅用于调试预览和 UI 解释，不用于正式发送链路
- RST 模式只返回公共可注入信息
- 私有字段不通过该接口暴露
- Agent 专用视角检索不属于本文件的 MVP 接口
- `sceneOverride` 仅用于“尚未保存到数据库的预览态”；为空时必须使用数据库中的 SceneState 真值
- `scope="global_st"` 的 LoreEntry 其 `owner_id` 必须等于 `worldBookId`
- `scope="session_rst"` 的 LoreEntry 其 `owner_id` 必须等于 `sessionId`

---

## 5. 状态更新契约

### CharacterFieldUpdate

```ts
CharacterFieldUpdate {
  characterId: string
  fieldPath: string
  visibility: "public" | "private" | "uncertain"
  operation: "set" | "append" | "remove"
  value?: string
  reason?: string
}
```

### StateUpdateDiff

```ts
StateUpdateDiff {
  sessionId: string
  characterUpdates: CharacterFieldUpdate[]
}
```

### ApplyStateDiffResult

```ts
ApplyStateDiffResult {
  applied: boolean
  rejectedUpdates: Array<{
    fieldPath: string
    reason: string
  }>
  updatedAt: string
}
```

规则：

- `visibility=public` 只允许写入 `public_profile` 或 `public_state`
- `visibility=private` 只允许写入 `private_profile` 或 `private_state`
- `visibility=uncertain` 直接拒绝自动写入
- `fieldPath` 非法时整条 update 拒绝

MVP 实现说明：

- 首期主要用于统一编辑路径和未来扩展
- 即使暂不接 LLM updater，也要先把校验语义固定
- `SceneState` 保存不走该接口，改用单独的 `saveSceneState`

---

## 6. Rust FFI 方法

### Workspace 管理

```ts
listSessions() -> Array<{
  sessionId: string
  sessionName: string
  mode: "ST" | "RST"
  updatedAt: string
}>
```

```ts
createSession(configSeed: {
  sessionName: string
  mode: "ST" | "RST"
  mainApiConfigId: string
  presetId: string
  stWorldBookId?: string
}) -> SessionConfig
```

```ts
renameSession(sessionId: string, newName: string) -> SessionConfig
```

```ts
deleteSession(sessionId: string) -> { deleted: boolean }
```

```ts
listWorldBooks() -> Array<{
  worldBookId: string
  name: string
  updatedAt: string
}>
```

```ts
listPresets() -> Array<{
  presetId: string
  name: string
  updatedAt: string
}>
```

```ts
listApiConfigs() -> Array<{
  apiId: string
  name: string
  providerType: "openai" | "openai_compatible"
  defaultModel: string
  updatedAt: string
}>
```

```ts
createWorldBook(name: string) -> {
  worldBookId: string
  name: string
  updatedAt: string
}
```

```ts
createPreset(name: string) -> PresetConfig
```

```ts
createApiConfig(name: string) -> ApiConfig
```

```ts
renameWorldBook(worldBookId: string, newName: string) -> {
  worldBookId: string
  name: string
  updatedAt: string
}
```

```ts
renamePreset(presetId: string, newName: string) -> PresetConfig
```

```ts
renameApiConfig(apiId: string, newName: string) -> ApiConfig
```

```ts
deleteWorldBook(worldBookId: string) -> { deleted: boolean }
```

```ts
deletePreset(presetId: string) -> { deleted: boolean }
```

```ts
deleteApiConfig(apiId: string) -> { deleted: boolean }
```

规则：

- `workspace.db` 是懒扫描缓存，不是真值来源
- `listSessions()` 在返回前必须懒扫描 `sessions/` 并刷新缓存
- `listWorldBooks()` 在返回前必须懒扫描 `world_books/` 并刷新缓存
- `listPresets()` 在返回前必须懒扫描 `config/presets/` 并刷新缓存
- `listApiConfigs()` 在返回前必须懒扫描 `config/api_configs/` 并刷新缓存
- 配置列表或按 ID 读取配置时，必须对 `config/` 做同样的懒扫描
- 若发现重复 ID，仅保留本次扫描中第一个读取到的对象，其余对象忽略并记录冲突
- 删除成功表示真值文件与缓存都已同步删除
- 若文件系统操作失败，应返回错误并回滚缓存变更
- 若扫描时发现索引缺失或缓存可重建，应自动重建后继续返回

### `save_session`

```ts
saveSession(config: SessionConfig) -> SessionConfig
```

语义：

- 新建或更新 Session 配置
- 使用事务更新 `updated_at`

### `get_preset`

```ts
getPreset(presetId: string) -> PresetConfig
```

### `get_api_config`

```ts
getApiConfig(apiId: string) -> ApiConfig
```

### `save_preset`

```ts
savePreset(config: PresetConfig) -> PresetConfig
```

### `save_api_config`

```ts
saveApiConfig(config: ApiConfig) -> ApiConfig
```

语义：

- 新建或更新 Preset 配置
- 使用文件写回更新 `updated_at`
- `saveApiConfig` 写回前必须保证 API key 已加密；若调用方提供的是明文，应在持久化前完成加密替换

### `load_session`

```ts
loadSession(sessionId: string) -> {
  config: SessionConfig
  runtime: SessionRuntimeState
  sceneState?: SceneState
}
```

语义：

- 该接口允许直接加载通过离线拷贝导入的 `session.db`
- 若 `sessionId` 不在缓存中，Rust 应先尝试懒扫描 `sessions/`
- 若结构存在可补全缺项，应先补全再返回；无法容纳时返回错误

### 消息接口

```ts
createMessage(message: {
  sessionId: string
  role: "system" | "user" | "assistant"
  content: string
  visible: boolean
  status: "pending" | "streaming" | "completed" | "error"
}) -> MessageRecord
```

```ts
updateMessageContent(messageId: string, content: string) -> MessageRecord
```

```ts
setMessageStatus(messageId: string, status: "pending" | "streaming" | "completed" | "error", errorMessage?: string) -> MessageRecord
```

```ts
setMessageVisibility(messageId: string, visible: boolean) -> MessageRecord
```

```ts
deleteMessages(sessionId: string, messageIds: string[]) -> {
  deletedMessageIds: string[]
}
```

语义：

- user 发送时先创建 user message
- assistant 响应开始时创建一个占位 assistant message
- 流式过程中只更新同一条 assistant message 的 content 和 status
- 同一轮重试默认复用原 assistant 占位消息，不创建第二条最终 assistant 消息
- 用户主动停止生成时，中断 Provider 请求并保留已生成内容；MVP 中该 assistant 消息应收敛为 `completed`
- `重试` 与 `重新生成` 都复用原 user 输入，不要求 UI 把原文本重新回填到 composer
- `setMessageVisibility(..., false)` 后，消息仍保留在本地历史中，但在提示词组装、上下文裁剪和 RST 调度中必须被忽略
- `setMessageVisibility(..., true)` 后，该消息重新参与后续上下文计算
- `setMessageStatus(..., "error")` 后必须保留已生成内容，供 UI 展示和重试
- 应用重启后若 `SessionRuntimeState.activeMessageId` 指向一条 `streaming` 消息，该消息状态必须一并收敛为 `error`
- `deleteMessages` 只删除调用方明确传入的消息，不隐式重写后续消息
- UI 若执行“删除本轮”，应一次性传入该轮 user / assistant 对应消息 ID，避免留下孤立半轮对话

### `list_messages`

```ts
listMessages(sessionId: string, limit?: number) -> MessageRecord[]
```

### `search_lore`

```ts
searchLore(query: LoreRetrievalQuery) -> LoreRetrievalResult
```

### `build_prompt`

```ts
buildPrompt(request: PromptBuildRequest) -> PromptBuildResult
```

语义：

- `mode`、`presetId` 和世界书绑定信息由 `sessionId` 对应配置推导
- `includeMessageIds` 为空时，由 Rust 按 `memLength` 自动选择最近且 `visible=true` 的消息
- 即使 `includeMessageIds` 显式传入，`visible=false` 的消息也不得进入最终 Prompt
- `userInput` 视为不可裁剪输入
- 最终输出固定为：1 条 `system` 消息 + 0..N 条历史消息 + 1 条当前轮 `user` 消息
- `system` 消息内部块顺序固定为：`Preset.mainPrompt` -> `Session.userDescription` -> 模式说明 -> `SceneState` -> `constant lore` -> 普通命中 Lore
- 该接口是正式发送链路唯一允许使用的 Prompt 组装入口

### OpenAI 字段映射约束

统一内部字段：

- `messages`
- `model`
- `outputTokenLimit`
- `temperature`
- `topP`
- `presencePenalty`
- `frequencyPenalty`
- `stopSequences`
- `stream`
- `reasoningEffort`
- `verbosity`

映射规则：

- `providerType="openai"` 时：
  - `messages -> input`
  - `outputTokenLimit -> max_output_tokens`
  - `reasoningEffort -> reasoning.effort`
  - `verbosity -> text.verbosity`
- `providerType="openai_compatible"` 时：
  - `messages -> messages`
  - `outputTokenLimit -> max_tokens`
  - 主系统指令优先映射为 `system` 角色

兼容规则：

- OpenAI 官方路径只允许 Responses API
- OpenAI-compatible 路径只允许 Chat Completions 协议
- 同一请求不得同时发送 `max_tokens` 与 `max_completion_tokens`
- OpenAI-compatible 路径下，MVP 不透传 `verbosity`
- OpenAI-compatible 路径下，MVP 不透传 `reasoningEffort`
- 若服务端字段能力与 `providerType` 不匹配，应直接报配置错误，不做隐式猜测切换

### `save_scene_state`

```ts
saveSceneState(sceneState: SceneState) -> SceneState
```

语义：

- 每次保存都提交完整 `SceneState`
- 保存后数据库中的值立即成为新的唯一真值
- 该接口不接受 partial merge
- `sceneState.updatedAt` 由 Rust 写入最终值，调用方传入值仅作占位

### `apply_state_diff`

```ts
applyStateDiff(diff: StateUpdateDiff) -> ApplyStateDiffResult
```

语义：

- MVP 中仅用于 Character 的 public/private 字段更新校验
- 不承担 SceneState 持久化

### 日志接口

```ts
listRequestLogs(filter?: {
  sessionId?: string
  status?: "success" | "error"
  limit?: number
}) -> Array<{
  logId: string
  sessionId: string
  provider: string
  model: string
  status: "success" | "error"
  requestTime: string
  durationMs?: number
  redacted: boolean
  payloadTruncated: boolean
}>
```

```ts
getRequestLog(logId: string) -> RequestLog
```

### 懒扫描与容错规则

```ts
WorkspaceScanIssue {
  objectType: "session" | "world_book" | "api_config" | "preset" | "theme"
  objectId: string
  severity: "warning" | "error"
  code: string
  message: string
}
```

规则：

- 扫描时应尽量容纳旧版本或缺失可推导字段，并在返回前完成运行时补全
- 无法容纳的对象不进入可用列表，并返回或记录 `WorkspaceScanIssue`
- 重复 ID 被忽略时应产生 `warning`
- 无法读取或迁移失败时应产生 `error`

---

## 7. 错误约定

Rust FFI 返回错误时，统一提供：

```ts
RustDomainError {
  code: string
  message: string
  details?: string
  retryable: boolean
}
```

错误分类建议：

- `not_found`
- `validation_error`
- `storage_error`
- `migration_error`
- `budget_overflow`
- `serialization_error`
- `fs_sync_error`
- `workspace_scan_error`

---

## 8. 日志与脱敏约束

日志生成前必须完成：

- Header 脱敏
- API key 脱敏
- Authorization 脱敏
- 超长 prompt 截断
- 私有人物字段过滤

禁止写入：

- `private_profile`
- `private_state`
- 原始 API key
- 完整未截断响应体

MVP 展示规则：

- 日志列表只展示摘要字段
- 日志详情展示脱敏后的 request/response preview，不展示完整原始报文

---

## 9. 向后兼容预留

以下类型仅预留，不加入 MVP 主调用链：

- `CharacterViewForSelf`
- `CharacterViewForOthers`
- `AgentPromptContext`
- `AgentLoreQuery`
- `AgentLoreHit`

原则：

- 可以在 Rust model 层预留定义
- 不可以让 MVP 的 `build_prompt` 依赖这些结构
