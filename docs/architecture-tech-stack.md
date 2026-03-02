# RST 需求书（功能与数据要求）

本文档在现有说明基础上固化为可执行的需求书，覆盖功能范围、数据结构、交互规则与存储要求，用于后续设计与开发对齐。

## 1. 目标与范围
### 目标
1. 解决SillyTavern在长对话中的“记忆模糊、设定遗漏”问题，核心在精细化 Prompt 组装与世界/人物状态机（RST Lore）。
2. 提供稳定的本地部署体验与高可配置会话管理。
3. 保留 SillyTavern 兼容模式（ST | RST）。

### 范围
1. 基础对话交互与会话管理。
2. API 配置管理与请求-响应处理。
3. Preset（Prompt 组建器）与配置管理。
4. RST Lore（世界/实体设定 + 动态状态）与调度器。
5. Appearance（界面主题与样式配置）。
6. 统一配置面板（Preset, API, Session, Lores, Appearance）。

### 非目标
1. 在线多人协作与云同步。
2. 插件市场或脚本引擎。

## 2. 术语
1. Session：会话/存档，包含会话配置与消息历史。
2. Preset：Prompt 组建配置，由多个条目按顺序组成。
3. RST Lore：世界与实体的基础设定与动态状态条目集合。
4. Lore 调度器：从上下文中检索 Lore 并生成注入块的流程。
5. Appearance：UI 主题与样式配置。
6. ST | RST 模式：兼容模式与完整模式的功能开关。

## 3. 功能需求
### 3.1 会话与消息管理
1. 系统必须支持会话的创建、打开、重命名、删除与列表展示。
2. 每个会话必须包含以下配置字段（键名统一为 snake_case）：
- session_name
- mode（ST 或 RST）
- user_description
- scan_depth（Lore 调度的上下文扫描深度）
- mem_length（进入提示词的最近消息条数）
- created_at
- updated_at
- main_api_config_id
- scheduler_api_config_id
- preset_id
3. 每条消息必须保存以下字段：
- role（System | User | Assistant）
- timestamp
- content
- visible（是否参与提示词组装与 Lore 调度）
4. 用户必须能编辑与删除单条消息，并触发必要的索引/缓存更新。
5. 用户输入区为空时，系统仍必须允许触发 Send。
6. 当本次发送没有显式输入内容（空文本且无附件）时，系统不得新增 user 会话消息。
7. 当本次发送有显式输入内容（非空文本或附件）时，系统必须新增 user 会话消息，并参与后续提示词组装。

### 3.2 API 配置管理
1. 系统必须支持 API 配置的创建、查看、编辑、重命名、删除与列表展示。
2. API 配置字段必须包含：
- api_type（OpenAI, Google Gemini, Deepseek, OpenAI 兼容, Anthropic）
- base_url
- api_key
- model
- temperature
- max_tokens
- stream
3. 对主流 API 类型应提供默认 base_url，用户可修改。
4. 用户确认 base_url 与 api_key 后，系统应可从服务商获取模型列表供选择；若获取失败仍允许手动输入。
5. api_key 必须采取安全管理措施，不得以明文直接存储在配置文件中。

### 3.3 Preset 系统
1. Preset 用于定义 Prompt 组装顺序与条目内容。
2. Preset 条目字段必须包含：name, role, content, disabled, comment。
3. 每份 Preset 必须包含以下系统内置条目且不可删除、不可改名：
- Main_Prompt(用户自定义)
- lores (Lores注入调度器输出)
- user_description (Session配置项)
- chat_history (最近 mem_length 条 visible 消息)
- scene (对话语境下的时间地点)
- user_input (用户最新输入)
4. 系统内置条目允许调整顺序与禁用，但其 content 不可直接编辑。
5. Preset 界面只允许编辑非系统内置条目的 content。
6. Prompt 组装必须严格按 Preset 条目顺序执行，disabled 条目不参与组装。
7. 空输入发送时，Prompt 组装必须遵循以下 user_input 规则：
- 若最新一条 visible 消息的 role 为 user，则将该消息内容作为 user_input，且该消息不得重复出现在 chat_history 展开结果中。
- 否则，user_input 固定为字符串 "continue"。
8. 上述两种空输入组装方式都不得新增会话消息。

### 3.4 RST Lore 数据管理
1. RST Lore 必须支持根据会话内容动态更新, 使用另一个LLM解析会话消息, 与主会话异步进行。
2. 特定实体范围包括：人物、国家与地区、组织与势力。
3. 基础设定包括：世界观与地理、人物姓名种族出生、国家与地区制度、地区与组织概况。
4. 动态状态包括：当前时间地点、人物年龄外貌、人物行动、人物属性、人物记忆、人物关系、地区或组织事件与形势。
5. Lore 范畴固定为：world_base, society, place, faction, character, skills, others。
6. 存储规则：所有 Lore 数据存储在 sessions/{session_name}/rst_data/ 下。
7. character 条目必须拆分为单独文件（每个 character 一份文件）。
8. 其他范畴共同存储在 sessions/{session_name}/rst_data/{world_id}/下，每个范畴一个文件,文件内包含多个条目。{world_id}即保留扩展为多世界的更宏大世界观的可能.
9. Lore 条目字段必须包含：name, category, content, disabled, constant, tags。

### 3.5 Lore 调度器
1. 调度器必须基于最近 scan_depth 条 visible 消息进行检索与判断。
2. 调度器必须能基于 lore/或rst_data下各个条目的tags、name、category 等元数据检索相关条目。
3. 可选支持向量检索以增强召回, 利用好Python的NLP优势。
4. 调度器必须调用独立 LLM 对候选条目进行确认、整理与摘要。
5. 注入粒度必须精细到文件内的单条目或小节，避免整文件注入。
6. 输出结果必须为可直接用于 Prompt 的注入块。

### 3.6 Appearance
1. Appearance 作为独立配置文件存在并可热更新, 用户必须能创建、编辑、删除自定义主题，并在界面上选择应用。
2. 支持主题色、字体、间距等基础参数。
3. 支持会话消息Markdown的样式配置(对标题, 常规段落, 斜体, 中英文双引号包裹的文字, 代码块设置其颜色)
4. 后续扩展不应破坏现有配置兼容性。

### 3.7 统一配置面板
1. Preset, API, Session, Lores, Appearance 每份配置必须存储为独立文件。
2. 系统必须提供统一的新建/删除/重命名/查看/编辑条目的 Panel。
3. Panel 默认折叠在界面左侧，以图标入口展开。
4. Panel 的交互与行为必须在上述五类配置中保持一致。

### 3.8 ST | RST 模式
1. ST 模式要求：Lore 调度器关闭，采用传统的常驻/关键词触发决定lore条目注入, RST 专属面板隐藏，Prompt 组装保持 SillyTavern 兼容条目。
2. RST 模式要求：启用 Lore 调度与动态更新，显示 RST 专属面板，Preset 自动补齐系统条目。

### 3.9 双 API 管理
1. 系统必须区分主对话 API 与调度器 API。
2. 每个会话必须能分别指定 main_api_config_id 与 scheduler_api_config_id。
3. UI 必须提供清晰入口分别配置与切换。

### 3.10 请求日志（Log）
1. 每次会话请求都必须记录日志，成功与失败都不能丢失。
2. Log 必须保留完整的原始请求与原始响应（raw_request, raw_response），用于排障和复盘。
3. Log 必须包含以下可检索元信息：
- chat_name
- provider
- model
- status（success 或 error）
- request_time
- response_time
- duration_ms
- prompt_tokens
- completion_tokens
- total_tokens
- stop_reason
4. Log 面板列表必须展示至少以下信息：会话名、Provider、Model、状态、耗时、Token 用量、停止原因、请求/响应时间。
5. Log 面板详情必须展示完整 raw request / raw response JSON，不得只展示文本内容。

## 4. 数据与存储要求
1. 以 JSON 作为主存储格式，确保可读可编辑。
2. 每份配置一个文件，禁止多个配置共享同一文件。
3. 必须采用原子写入策略（临时文件写入后替换），并生成 .bak 备份。
4. JSON 须包含 version 字段，以支持后续迁移。
5. 目录建议如下：
- data/sessions/{session_name}/session.json
- data/essions/{session_name}/messages.json
- data/sessions/{session_name}/rst_data/
- data/sessions/{session_name}/rst_data/characters/{character_id}.json
- data/sessions/{session_name}/rst_data/.index/
- data/presets/{preset_id}.json
- data/api_configs/{api_id}.json
- data/appearance/{theme_id}.json

## 5. 安全要求
1. api_key 不得明文存储，必须使用本地 Keyring 或加密字段保存。
2. 若加密存储，必须提供安全解密流程，不可阻断正常调用。

## 6. 性能与可靠性要求
1. 会话与配置的本地读写应在 100ms 量级内完成。
2. 调度器与 LLM 调用可异步，不应阻塞主对话 UI。
3. 任何写入失败必须保持数据一致性（不得产生半写入状态）。

## 7. 验收要点（MVP）
1. 能完成会话 CRUD、消息编辑/删除、提示词正确组装。
2. 能完成 API 配置 CRUD，并使用指定配置完成一次对话请求。
3. Preset 必须强制包含系统条目并参与组装。
4. Lore 能按条目粒度注入，并可从对话中更新。
5. ST 与 RST 模式切换后界面与功能符合要求。
6. 输入区为空时可正常 Send，且空输入发送不新增 user 会话消息。
7. Log 面板可查看完整请求/响应及关键元数据（tokens、时间戳、stop reason、状态、耗时）。
