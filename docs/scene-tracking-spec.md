# Scene 场景跟踪系统 —— 技术规格文档

> 版本: 1.0  
> 日期: 2026-03-04  
> 状态: 待审阅  
> 前置依赖: rst-lores-technical-spec.md v1.1

---

## 目录

1. [背景与动机](#1-背景与动机)
2. [方案概述](#2-方案概述)
3. [数据结构](#3-数据结构)
4. [核心流程](#4-核心流程)
5. [后端改动](#5-后端改动)
6. [前端改动](#6-前端改动)
7. [与现有模块的集成](#7-与现有模块的集成)
8. [容错与边界处理](#8-容错与边界处理)
9. [开发任务清单](#9-开发任务清单)
10. [决策记录](#10-决策记录)

---

## 1. 背景与动机

### 1.1 问题

RST 系统的 Preset 中预留了 `scene` 系统条目（用于向主 LLM 注入当前对话场景的时间和地点），但目前 `prompt_assembler.py` 中 `scene` 返回 `None`，未实现。

故事的时间和地点信息面临以下挑战：

1. **时间推进由主 LLM 叙事驱动**：主 LLM 写出"三天后""翌日清晨"等文本，系统无法用规则/正则可靠提取相对时间。
2. **地点转移由主 LLM 叙事驱动**：主 LLM 可能将角色移动到新地点、描述未在 Lore 中注册的地点，规则匹配无法覆盖。
3. **调度器异步更新有延迟**：`lore_sync_interval` 默认 3 轮，场景变化可能发生在更新间隔之间。
4. **Status Panel 当前通过 plot/place Lore 的 tags 猜测场景**：不可靠且依赖用户手动维护。

### 1.2 方案选择

经讨论，选择 **方案 A：主 LLM 显式输出场景标记**。

核心思路：在 Preset 的 `scene` 条目中指示主 LLM 在每次回复末尾附加 `<scene>` 结构化标记，后端从中提取场景状态。主 LLM 最清楚故事推进了什么，由它直接输出最准确。

---

## 2. 方案概述

### 2.1 数据流总览

```
┌──────────────────────────────────────────────────────────────┐
│                       每轮对话流程                             │
│                                                              │
│  Prompt 组装阶段:                                             │
│    scene 槽位 → 注入上一轮的 SceneState + 输出格式指令          │
│                                                              │
│  主 LLM 回复:                                                 │
│    [故事正文...]                                               │
│    <scene>                                                    │
│    time: 1042年3月18日 午后                                │
│    location: 泽源·潮汐城·港口                                  │
│    characters: 柳璃, 小溪, 老船长                               │
│    </scene>                                                   │
│                                                              │
│  后端处理:                                                     │
│    1. 从 assistant_text 中解析 <scene> 标记                     │
│    2. 更新 SceneState（内存 + 持久化）                          │
│    3. 原始 content（含 <scene>）存入 messages.json              │
│    4. 调度器获得新的 location → 可驱动地点相关 Lore 检索         │
│                                                              │
│  前端渲染:                                                     │
│    MarkdownMessage 将 <scene> 渲染为精简的场景标签样式           │
│                                                              │
│  Prompt 组装（chat_history 去重）:                              │
│    历史消息中连续相同的 <scene> 只保留最后一条，去掉重复         │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 关键设计决策

| 决策 | 方案 | 理由 |
|------|------|------|
| `<scene>` 标记是否从消息中剥离 | **不剥离**，保留在 `messages.json` 的 `content` 中 | 历史消息保留时间地点上下文，后续 LLM 在 chat_history 中可参考过去的场景信息 |
| 前端如何渲染 `<scene>` | 精简标签样式（小字体、淡色、可折叠, 去除键名只保留值） | 不影响阅读体验，又保留信息可见性 |
| chat_history 组装中的 `<scene>` 去重 | 连续相同 `<scene>` 只保留最后一条 | 节省 token，避免冗余 |
| SceneState 持久化 | 写入 `rst_data/scene_state.json` | 重启后不丢失；StatusPanel 可直接读取 |
| ST 模式 | 不启用 `<scene>` 机制 | ST 模式无调度器，场景追踪不适用 |

---

## 3. 数据结构

### 3.1 SceneState 模型

```python
# backend/app/models/lore.py 中新增

class SceneState(BaseModel):
    """当前场景状态，由主 LLM 输出的 <scene> 标记提取而来"""
    current_time: str = ""           # 故事内时间，如 "灵纪1042年3月18日 午后"
    current_location: str = ""       # 当前地点名称，如 "泽源·潮汐城"
    characters: list[str] = Field(default_factory=list)  # 在场人物名列表
    raw_tag: str = ""                # <scene>...</scene> 之间的原始文本
    updated_at: str = ""             # 最后更新时间（UTC ISO）
```

### 3.2 SceneState 文件

```python
class SceneStateFile(BaseModel):
    scene: SceneState = Field(default_factory=SceneState)
    version: int = 1
```

存储路径：`data/sessions/{session_name}/rst_data/scene_state.json`

### 3.3 Message 模型无变化

`Message.content` 继续存储完整文本（含 `<scene>` 标记），不新增字段。

---

## 4. 核心流程

### 4.1 `<scene>` 标记格式

主 LLM 被要求在每次回复末尾附加如下格式的标记：

```
<scene>
time: [绝对时间]
location: [地点名称]
characters: [在场人物, 逗号分隔]
</scene>
```

**格式要求**（注入 Prompt 中的指令）：

- `time` 必须是具体绝对时间，不允许"三天后"等相对表述
- 如果本轮时间/地点/人物均未变化，不需要输出 `<scene>`
- `location` 应使用地点全称
- `characters` 只列出当前场景中**在场**的人物

### 4.2 后端提取流程

```python
import re

SCENE_TAG_RE = re.compile(
    r'<scene>\s*(.*?)\s*</scene>',
    re.DOTALL | re.IGNORECASE
)

SCENE_FIELD_RE = re.compile(
    r'^(time|location|characters)\s*[:：]\s*(.+)$',
    re.MULTILINE | re.IGNORECASE
)

def parse_scene_tag(text: str) -> SceneState | None:
    """
    从文本中提取最后一个 <scene> 标记并解析为 SceneState。
    返回 None 表示文本中没有 <scene> 标记。
    """
    matches = list(SCENE_TAG_RE.finditer(text))
    if not matches:
        return None
    
    raw = matches[-1].group(1).strip()
    state = SceneState(raw_tag=raw)
    
    for field_match in SCENE_FIELD_RE.finditer(raw):
        key = field_match.group(1).strip().lower()
        value = field_match.group(2).strip()
        if key == "time":
            state.current_time = value
        elif key == "location":
            state.current_location = value
        elif key == "characters":
            state.characters = [
                name.strip() for name in value.split(",")
                if name.strip()
            ]
    
    return state
```

### 4.3 chat_history 中的 `<scene>` 去重

在 `prompt_assembler.py` 组装 `chat_history` 时，对历史消息做去重处理：

```
规则：
1. 遍历 chat_history 中的 assistant 消息
2. 提取每条的 <scene> 标记内容（normalized）
3. 如果当前消息的 <scene> 与前一条 assistant 消息的 <scene> 内容完全相同，
   则从当前消息 content 中去除 <scene>...</scene> 部分
4. 仅在组装 prompt 时去除，不修改存储的原始 content
5. 最后一条 assistant 消息的 <scene> 始终保留（即使与前一条相同）
```

去重示例：

```
原始 chat_history:
  msg1 (assistant): 故事A... <scene>time:3月15日\nlocation:云隐山\ncharacters:A,B</scene>
  msg2 (user): 继续
  msg3 (assistant): 故事B... <scene>time:3月15日\nlocation:云隐山\ncharacters:A,B</scene>
  msg4 (user): 去潮汐城
  msg5 (assistant): 故事C... <scene>time:3月18日\nlocation:潮汐城\ncharacters:A,B,C</scene>

去重后组装进 prompt 的 chat_history:
  msg1 (assistant): 故事A...                  ← <scene> 被去掉（与 msg3 相同，非最后一条）
  msg2 (user): 继续
  msg3 (assistant): 故事B...                  ← <scene> 被去掉（与 msg1 相同，非最后一条）
  msg4 (user): 去潮汐城
  msg5 (assistant): 故事C... <scene>time:3月18日\nlocation:潮汐城\ncharacters:A,B,C</scene>
                                               ← 保留（场景变化 且 是最后一条）
```

> 注意：上述去重只在 prompt 组装阶段进行，`messages.json` 中存储的原始内容不受影响。

### 4.4 scene 槽位注入内容

`prompt_assembler._resolve_content()` 中 `scene` 条目的渲染逻辑：

```python
case "scene":
    scene_state = self._load_scene_state(session)  # 从 rst_runtime 或文件加载
    if scene_state is None or not scene_state.current_time:
        return self._render_scene_instruction_only()
    return self._render_scene_with_state(scene_state)
```

**首轮（无 SceneState）注入内容**：

```
## 场景标记指令
在你的每次回复最末尾，附加以下格式的场景标记：
<scene>
time: [当前故事内的绝对时间，如：灵纪1042年3月15日 黄昏]
location: [当前场景地点全称]
characters: [当前在场人物名，逗号分隔]
</scene>

要求：
- time 必须写绝对时间，禁止写"三天后""翌日"等相对表述
- 如果本轮回复中时间、地点、在场人物均未发生任何变化，则不需要输出 <scene> 标记
- <scene> 标记不属于故事正文，仅用于系统追踪
```

**后续轮次（有 SceneState）注入内容**：

```
## 当前场景
time: 灵纪1042年3月15日 黄昏
location: 今庭·云隐山
characters: 苍角, 小溪

## 场景标记指令
生成正文之前,在你的每次回复开头,如果时间、地点或在场人物发生了变化,附加以下格式的场景标记：
<scene>
time: [更新后的绝对时间]
location: [更新后的地点全称]
characters: [更新后的在场人物名，逗号分隔]
</scene>

如果本轮回复中场景完全没有变化，则不需要输出 <scene> 标记。
```

### 4.5 前端渲染

`MarkdownMessage.vue` 在渲染前将 `<scene>` 标记转换为精简的 HTML 标签：

```
原始文本:
  这是<scene>time: 灵纪1042年3月18日 午后\nlocation: 潮汐城\ncharacters: 苍角, 小溪</scene> + 故事正文...

渲染效果:
  ┌─────────────────────────────────────┐
  │ 📍 灵纪1042年3月18日 午后 · 潮汐城   │  ← 单行精简标签，小字体淡色
  │    苍角, 小溪                        │  ← 可选：在场人物（可折叠）
  └─────────────────────────────────────┘
  这是故事正文...

```

样式特征：
- 小字体（10-11px）、降低不透明度的色调
- 圆角边框、微淡背景
- 单行显示 time + location，人物列表在同行或第二行
- 不使用 Markdown 渲染，直接替换为自定义 HTML

---

## 5. 后端改动

### 5.1 涉及文件

| 文件 | 改动类型 | 描述 |
|------|----------|------|
| `backend/app/models/lore.py` | 新增模型 | `SceneState`, `SceneStateFile` |
| `backend/app/services/scene_service.py` | **新建** | SceneState 的解析、加载、保存、去重逻辑 |
| `backend/app/services/chat_service.py` | 修改 | `run_chat()` 中提取 `<scene>` 并更新 SceneState |
| `backend/app/services/prompt_assembler.py` | 修改 | `scene` 槽位渲染 + chat_history 去重 |
| `backend/app/storage/lore_store.py` | 修改 | 新增 `load_scene_state()` / `save_scene_state()` |
| `backend/app/services/lore_scheduler.py` | 修改 | 可选：用 SceneState.current_location 补充检索 |
| `backend/app/services/session_service.py` | 修改 | Session 初始化时创建空 `scene_state.json` |
| `backend/app/routers/lores.py` | 修改 | 新增 SceneState 查询/手动更新 API |

### 5.2 `scene_service.py` — 新建

```python
class SceneService:
    """Scene 标记的解析、存储、去重"""

    def parse_scene_tag(self, text: str) -> SceneState | None:
        """从文本中提取最后一个 <scene> 标记"""
        ...

    def normalize_scene(self, scene: SceneState) -> str:
        """将 SceneState 归一化为可比较的字符串（用于去重）"""
        ...

    def scenes_equal(self, a: SceneState | None, b: SceneState | None) -> bool:
        """判断两个 SceneState 是否内容相同（忽略 updated_at）"""
        ...

    def strip_scene_tag(self, text: str) -> str:
        """从文本中移除 <scene>...</scene> 标记，返回纯正文"""
        ...

    def deduplicate_history(
        self,
        messages: list[Message],
    ) -> list[Message]:
        """
        对 chat_history 做 <scene> 去重。
        返回新的消息列表（浅拷贝），重复的 <scene> 被去掉。
        不修改原始 Message 对象。
        规则：
        - 从后往前遍历 assistant 消息
        - 每条 assistant 消息提取 <scene>
        - 如果与后一条 assistant 消息的 <scene> 相同，则去掉当前消息的 <scene>
        - 最后一条 assistant 消息的 <scene> 始终保留
        """
        ...

    def load_scene_state(self, session_name: str) -> SceneState:
        """从文件或 rst_runtime 加载最新 SceneState"""
        ...

    def save_scene_state(self, session_name: str, scene: SceneState) -> None:
        """持久化 SceneState + 更新 rst_runtime"""
        ...

    def render_scene_prompt(self, scene: SceneState | None) -> str:
        """渲染 scene 槽位注入内容"""
        ...
```

### 5.3 `chat_service.py` 改动

在 `run_chat()` 中 assistant 回复存入后，增加 SceneState 提取：

```python
# --- 现有代码 ---
assistant_message = Message(...)
store.append(assistant_message)
touch_session(session_name)

# --- 新增：Scene 提取 ---
if session.mode == "RST":
    parsed_scene = scene_service.parse_scene_tag(assistant_text)
    if parsed_scene is not None:
        parsed_scene.updated_at = _utc_iso()
        scene_service.save_scene_state(session_name, parsed_scene)
```

### 5.4 `prompt_assembler.py` 改动

#### scene 槽位

```python
case "scene":
    if session.mode != "RST":
        return None
    scene = scene_service.load_scene_state(session_name)
    return scene_service.render_scene_prompt(scene)
```

需要让 `PromptAssembler.build()` 接收 `session_name` 参数（当前未传入），或者将 scene_prompt 作为预计算参数传入（类似 `lores_block`）。

**推荐方案**：新增 `scene_block: str` 参数传入 `build()`，在 `chat_service.run_chat()` 中预计算。

```python
# prompt_assembler.py
def build(
    self,
    session: SessionMeta,
    preset: Preset,
    messages: list[Message],
    lores_block: str,
    scene_block: str,       # ← 新增
    user_input: str,
) -> list[dict]:
    ...
```

```python
# _resolve_content 中
case "scene":
    return scene_block or None
```

#### chat_history 去重

在 `_select_history()` 返回后，对结果调用 `scene_service.deduplicate_history()`:

```python
def build(self, ...):
    history = self._select_history(session, messages)
    if session.mode == "RST":
        history = scene_service.deduplicate_history(history)
    ...
```

或者直接在 `build()` 中，展开 chat_history 时进行去重处理。

### 5.5 `lore_store.py` 改动

```python
# 新增方法

def load_scene_state(self) -> SceneState:
    """加载 scene_state.json，不存在则返回空 SceneState"""
    path = self._rst_data / "scene_state.json"
    if not path.exists():
        return SceneState()
    data = read_json(path)
    return SceneStateFile.model_validate(data).scene

def save_scene_state(self, scene: SceneState) -> None:
    """持久化 SceneState"""
    path = self._rst_data / "scene_state.json"
    file = SceneStateFile(scene=scene)
    write_json(path, file.model_dump(mode="json"))
```

### 5.6 `session_service.py` 改动

Session 初始化时创建空的 `scene_state.json`：

```python
# create_session() 中已有的初始化逻辑之后新增:
empty_scene = SceneStateFile()
write_json(rst_data / "scene_state.json", empty_scene.model_dump(mode="json"))
```

### 5.7 `lore_scheduler.py` 可选改动

在 `full_schedule()` 的检索阶段，可用 `SceneState.current_location` 作为额外检索关键词：

```python
# full_schedule() 中，在 user_ids 检索之后
scene_state = lore_store.load_scene_state()
if scene_state.current_location:
    location_ids = engine.retrieve(scene_state.current_location, top_k=5)
else:
    location_ids = []

merged = self._merge_ids(constant_ids, cached, user_ids, location_ids)
```

这确保当前地点相关的 `place` Lore 条目有更高概率被选中。

### 5.8 API 接口

| 方法 | 路径 | 描述 | Request Body | Response |
|------|------|------|-------------|----------|
| `GET` | `/api/sessions/{session_name}/lores/scene` | 获取当前 SceneState | - | `SceneState` |
| `PUT` | `/api/sessions/{session_name}/lores/scene` | 手动更新 SceneState | `SceneStateUpdate` | `SceneState` |

```python
class SceneStateUpdate(BaseModel):
    current_time: str | None = None
    current_location: str | None = None
    characters: list[str] | None = None
```

---

## 6. 前端改动

### 6.1 涉及文件

| 文件 | 改动类型 | 描述 |
|------|----------|------|
| `frontend/src/components/MarkdownMessage.vue` | 修改 | 将 `<scene>` 标记渲染为精简标签 |
| `frontend/src/components/StatusPanel.vue` | 修改 | 从 SceneState API 读取时间/地点，替代现有的 plot/place tags 猜测 |
| `frontend/src/types/lore.ts` | 修改 | 新增 `SceneState` 类型 |
| `frontend/src/api/lores.ts` | 修改 | 新增 SceneState API 调用 |

### 6.2 MarkdownMessage 改动

在 Markdown 渲染之前（或之后），将 `<scene>` 标记替换为自定义 HTML：

```typescript
function renderSceneTag(content: string): string {
  // 匹配 <scene>...</scene>
  return content.replace(
    /<scene>([\s\S]*?)<\/scene>/gi,
    (_, inner: string) => {
      const fields = parseSceneFields(inner.trim());
      return buildSceneHtml(fields);
    }
  );
}

function parseSceneFields(raw: string): { time: string; location: string; characters: string } {
  const result = { time: '', location: '', characters: '' };
  for (const line of raw.split('\n')) {
    const match = line.match(/^(time|location|characters)\s*[:：]\s*(.+)$/i);
    if (match) {
      const key = match[1].toLowerCase() as keyof typeof result;
      result[key] = match[2].trim();
    }
  }
  return result;
}

function buildSceneHtml(fields: { time: string; location: string; characters: string }): string {
  const parts: string[] = [];
  if (fields.time) parts.push(fields.time);
  if (fields.location) parts.push(fields.location);
  const mainLine = parts.join(' · ');
  
  let html = `<div class="scene-tag">`;
  html += `<span class="scene-tag__main">📍 ${escapeHtml(mainLine)}</span>`;
  if (fields.characters) {
    html += `<span class="scene-tag__characters">${escapeHtml(fields.characters)}</span>`;
  }
  html += `</div>`;
  return html;
}
```

调用时机：在 `renderedHtml` computed 中，在 `markdown.render()` **之前**先处理 `<scene>` 标记（因为 MarkdownIt 的 `html: false` 会转义尖括号）。

```typescript
const renderedHtml = computed(() => {
  const withScene = renderSceneTag(props.content ?? "");
  const rawHtml = markdown.render(withScene);
  return wrapQuotedTextInHtml(rawHtml);
});
```

> 注意：`renderSceneTag` 将 `<scene>` 替换为 `<div class="scene-tag">` HTML 后，需要将 MarkdownIt 的 `html` 选项调整为允许 scene-tag 相关的 HTML 通过。或者改为在 `markdown.render()` 之后用 DOM 操作处理。推荐后者，避免 XSS 风险。

**推荐实现**：在 `markdown.render()` 之后，用正则处理转义后的 `<scene>` 文本。由于 `html: false`，MarkdownIt 会将 `<scene>` 转义为 `&lt;scene&gt;`，因此应在渲染后匹配转义形式：

```typescript
const SCENE_ESCAPED_RE = /&lt;scene&gt;([\s\S]*?)&lt;\/scene&gt;/gi;

const renderedHtml = computed(() => {
  let html = markdown.render(props.content ?? "");
  html = html.replace(SCENE_ESCAPED_RE, (_, inner: string) => {
    // inner 中的 HTML 实体需要反转义
    const decoded = decodeHtmlEntities(inner.trim());
    const fields = parseSceneFields(decoded);
    return buildSceneHtml(fields);
  });
  return wrapQuotedTextInHtml(html);
});
```

### 6.3 Scene 标签样式

```scss
// 在 MarkdownMessage.vue 的 <style> 中新增

.message-markdown :deep(.scene-tag) {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin-top: 0.8em;
  padding: 4px 10px;
  border-radius: 8px;
  border: 1px solid var(--rst-border-color);
  background: rgba(var(--rst-accent-rgb), 0.06);
  font-size: 11px;
  line-height: 1.5;
  color: var(--rst-text-secondary);
  opacity: 0.75;
}

.message-markdown :deep(.scene-tag__main) {
  font-weight: 500;
}

.message-markdown :deep(.scene-tag__characters) {
  font-size: 10px;
  opacity: 0.8;
  padding-left: 1.2em;
}
```

### 6.4 StatusPanel 改动

当前 `StatusPanel.vue` 通过以下方式获取时间/地点信息：
- 从 `plot` 条目的 `tags` 中提取 `time:xxx` / `place:xxx`
- 从 `place` 条目中匹配 "current" 标签

改为：**优先从 SceneState API 读取**，无数据时回退到现有逻辑。

```typescript
// StatusPanel.vue 中新增
import { getSceneState } from "@/api/lores";

const sceneState = ref<SceneState | null>(null);

async function loadStatusPanelData(sessionName: string): Promise<void> {
  // ... 现有的 listEntries / listCharacters 请求 ...
  
  // 新增：加载 SceneState
  try {
    sceneState.value = await getSceneState(sessionName);
  } catch {
    sceneState.value = null;
  }
}

// 修改 storyTime / storyLocation computed
const storyTime = computed(() => {
  if (sceneState.value?.current_time) {
    return sceneState.value.current_time;
  }
  // 回退到现有的 plot tags 逻辑
  ...
});

const storyLocation = computed(() => {
  if (sceneState.value?.current_location) {
    return sceneState.value.current_location;
  }
  // 回退到现有的 place/plot 逻辑
  ...
});

// 修改 presentCharacters computed
const presentCharacters = computed(() => {
  if (sceneState.value?.characters?.length) {
    // 按 SceneState 中的 characters 列表过滤
    const sceneNames = new Set(
      sceneState.value.characters.map(name => name.trim().toLowerCase())
    );
    const matched = characters.value.filter(char =>
      sceneNames.has(char.name.trim().toLowerCase()) && !char.disabled
    );
    if (matched.length > 0) {
      return matched;
    }
  }
  // 回退到现有逻辑
  ...
});
```

### 6.5 TypeScript 类型

```typescript
// frontend/src/types/lore.ts 新增

export interface SceneState {
  current_time: string;
  current_location: string;
  characters: string[];
  raw_tag: string;
  updated_at: string;
}

export interface SceneStateUpdate {
  current_time?: string;
  current_location?: string;
  characters?: string[];
}
```

### 6.6 API 调用

```typescript
// frontend/src/api/lores.ts 新增

export const getSceneState = (session: string) =>
  client.get<SceneState>(`${BASE(session)}/scene`).then(r => r.data);

export const updateSceneState = (session: string, data: SceneStateUpdate) =>
  client.put<SceneState>(`${BASE(session)}/scene`, data).then(r => r.data);
```

---

## 7. 与现有模块的集成

### 7.1 与 lore_updater 的协同

`lore_updater.sync_from_conversation()` 的 `extract_prompt` 模板**不需要**额外增加 `scene_update` 提取类型——因为 SceneState 已由主 LLM 的 `<scene>` 标记直接提供，不需要调度器重复提取。

但调度器 LLM 仍然可以在 `extract_prompt` 中接收当前 SceneState 作为上下文，帮助它更好地判断哪些人物在场、事件发生在哪里：

```python
# lore_updater._render_extract_prompt() 中可选新增:
def _render_extract_prompt(self, ..., scene_state: SceneState | None = None) -> str:
    prompt = ...
    if scene_state and scene_state.current_time:
        scene_context = f"\n## 当前场景\ntime: {scene_state.current_time}\nlocation: {scene_state.current_location}\ncharacters: {', '.join(scene_state.characters)}\n"
        prompt = prompt.replace("{scene_context}", scene_context)
    else:
        prompt = prompt.replace("{scene_context}", "")
    return prompt
```

### 7.2 与 lore_scheduler 的协同

调度器的 `_present_character_ids()` 方法当前通过对话文本关键词匹配判断在场人物。可以增加从 SceneState 获取在场人物作为补充/优先数据源：

```python
def _present_character_ids(self, store: LoreStore, conversation_text: str) -> set[str]:
    # 优先使用 SceneState
    scene_state = store.load_scene_state()
    if scene_state.characters:
        present = set()
        name_map = {
            char.name.strip().lower(): char.character_id
            for char in store.list_characters()
        }
        for name in scene_state.characters:
            char_id = name_map.get(name.strip().lower())
            if char_id:
                present.add(char_id)
        if present:
            return present
    
    # 回退到原有的文本匹配逻辑
    ...
```

### 7.3 与 lore_date 的关系

`lore_date.extract_scene_date()` 和 `lore_date.compute_age_at()` 等函数继续保留。SceneState 的 `current_time` 是自由文本格式，`lore_scheduler._build_candidate_text()` 中仍需要 `extract_scene_date()` 来解析具体日期用于年龄计算。可以增加从 `SceneState.current_time` 中优先提取日期的逻辑。

### 7.4 ST 模式

ST 模式下不启用 Scene 机制：
- `scene` 槽位返回 `None`（现有行为不变）
- 不提取 `<scene>` 标记
- `chat_history` 不做 `<scene>` 去重
- StatusPanel 继续使用现有的 plot/place tags 逻辑

---

## 8. 容错与边界处理

### 8.1 主 LLM 未输出 `<scene>` 标记

- 保留上一轮的 `SceneState` 不变
- `scene` 槽位在下一轮仍注入上次的 SceneState
- 不影响正常对话流程

### 8.2 主 LLM 输出格式错误

- `parse_scene_tag()` 返回 `None`（无法匹配正则）
- 或者返回部分字段为空的 `SceneState`（某些字段无法解析）
- 部分解析成功时：仅更新有值的字段，空字段保留上一轮值

```python
def merge_scene_state(previous: SceneState, parsed: SceneState) -> SceneState:
    """合并新解析的 scene 与前一轮 scene，填补空字段"""
    return SceneState(
        current_time=parsed.current_time or previous.current_time,
        current_location=parsed.current_location or previous.current_location,
        characters=parsed.characters if parsed.characters else previous.characters,
        raw_tag=parsed.raw_tag,
        updated_at=parsed.updated_at or previous.updated_at,
    )
```

### 8.3 `<scene>` 出现在非末尾位置

正则匹配最后一个 `<scene>` 标记（`matches[-1]`），不要求必须在文本末尾。

### 8.4 用户消息中包含 `<scene>`

仅从 `assistant` 消息中提取 `<scene>` 标记。`user` 消息中的 `<scene>` 忽略不处理。

### 8.5 Session 重启 / 服务重启

SceneState 持久化在 `scene_state.json` 中，服务重启后可从文件恢复。同时在 `rst_runtime_service` 中缓存一份供快速访问。

### 8.6 首次对话（无历史 SceneState）

`scene` 槽位注入纯指令文本（见 §4.4 首轮注入内容），不附带"当前场景"信息。主 LLM 首次回复后提取到 SceneState 即可开始追踪。

### 8.7 手动编辑 SceneState

用户可通过 StatusPanel 的时间/地点编辑框手动修改 SceneState（调用 `PUT /lores/scene` API）。手动修改后，下一轮主 LLM 收到更新后的 scene 状态。

---

## 9. 开发任务清单

### 阶段 1：后端核心（必须）

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| B1 | 在 `lore.py` 中新增 `SceneState`, `SceneStateFile`, `SceneStateUpdate` 模型 | `models/lore.py` | P0 |
| B2 | 新建 `scene_service.py`：`parse_scene_tag()`, `strip_scene_tag()`, `scenes_equal()`, `deduplicate_history()`, `render_scene_prompt()`, `load_scene_state()`, `save_scene_state()`, `merge_scene_state()` | `services/scene_service.py` | P0 |
| B3 | 在 `lore_store.py` 中新增 `load_scene_state()` / `save_scene_state()` | `storage/lore_store.py` | P0 |
| B4 | 修改 `chat_service.run_chat()`：assistant 回复后提取 `<scene>` 并更新 SceneState（仅 RST 模式） | `services/chat_service.py` | P0 |
| B5 | 修改 `prompt_assembler.build()`：新增 `scene_block` 参数；`scene` 条目返回 `scene_block` | `services/prompt_assembler.py` | P0 |
| B6 | 修改 `prompt_assembler`（或 `chat_service`）：chat_history 组装时调用 `deduplicate_history()` 去重（仅 RST 模式） | `services/prompt_assembler.py` 或 `services/chat_service.py` | P0 |
| B7 | 修改 `chat_service.run_chat()`：在组装 prompt 前计算 `scene_block`，传入 `assembler.build()` | `services/chat_service.py` | P0 |
| B8 | 修改 `session_service.create_session()`：初始化空 `scene_state.json` | `services/session_service.py` | P1 |
| B9 | 在 `lores.py` 路由中新增 `GET /scene` 和 `PUT /scene` 接口 | `routers/lores.py` | P1 |
| B10 | 可选：`lore_scheduler.full_schedule()` 中用 `current_location` 补充检索 | `services/lore_scheduler.py` | P2 |
| B11 | 可选：`lore_scheduler._present_character_ids()` 优先使用 SceneState.characters | `services/lore_scheduler.py` | P2 |
| B12 | 可选：`lore_updater._render_extract_prompt()` 中注入 SceneState 上下文 | `services/lore_updater.py` | P2 |

### 阶段 2：前端改动（必须）

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| F1 | `lore.ts` 新增 `SceneState`, `SceneStateUpdate` 类型定义 | `types/lore.ts` | P0 |
| F2 | `lores.ts` 新增 `getSceneState()`, `updateSceneState()` API 调用 | `api/lores.ts` | P0 |
| F3 | `MarkdownMessage.vue`：将 `<scene>` 标记渲染为精简标签样式 | `components/MarkdownMessage.vue` | P0 |
| F4 | `StatusPanel.vue`：优先从 SceneState API 读取时间/地点/在场人物 | `components/StatusPanel.vue` | P1 |
| F5 | `StatusPanel.vue`：SceneState 手动编辑保存调用 `PUT /scene` API | `components/StatusPanel.vue` | P1 |

### 阶段 3：测试

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| T1 | `test_scene_service.py`：`parse_scene_tag` 各种格式的解析测试 | `tests/test_scene_service.py` | P0 |
| T2 | `test_scene_service.py`：`deduplicate_history` 去重逻辑测试 | `tests/test_scene_service.py` | P0 |
| T3 | `test_scene_service.py`：`merge_scene_state` 部分解析合并测试 | `tests/test_scene_service.py` | P1 |
| T4 | `test_scene_service.py`：`render_scene_prompt` 首轮/后续轮输出测试 | `tests/test_scene_service.py` | P1 |
| T5 | 集成测试：完整对话流程中 SceneState 的提取和注入 | `tests/test_chat_flow.py` | P2 |

---

## 10. 决策记录

| # | 决策点 | 最终方案 | 理由 |
|---|--------|---------|------|
| S1 | Scene 信息由谁负责 | 主 LLM 输出 `<scene>` 标记，系统提取 | 主 LLM 推进剧情，最清楚时间/地点变化；规则/调度器无法可靠提取相对时间和隐含地点转移 |
| S2 | `<scene>` 是否从消息中剥离 | 不剥离，保留在 `messages.json` 的 content 中 | 历史消息保留时间地点上下文，后续 LLM 在 chat_history 中可参考过去场景 |
| S3 | 前端渲染方式 | 精简标签样式（小字体、淡色、圆角边框） | 不影响阅读体验，信息仍可见 |
| S4 | chat_history 去重策略 | 连续相同 `<scene>` 只保留最后一条 | 节省 prompt token，避免冗余注入 |
| S5 | SceneState 持久化 | `rst_data/scene_state.json` + 内存缓存 | 重启不丢失；StatusPanel 可读取 |
| S6 | 场景未变化时 `<scene>` 输出 | 主 LLM 不输出 `<scene>`（指令中明确要求） | 减少输出 token；不变时无需重复标记 |
| S7 | ST 模式处理 | 不启用 Scene 机制 | ST 模式无调度器，不适用 |
| S8 | `prompt_assembler` 接口变化 | 新增 `scene_block: str` 参数 | 与 `lores_block` 保持一致的注入模式 |
