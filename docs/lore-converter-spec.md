# RST Lore 初始化转换器 —— 技术规格文档

> 版本: 1.0  
> 日期: 2026-02-28  
> 状态: 已定稿，可交付开发

---

## 目录

1. [概述](#1-概述)
2. [源格式分析](#2-源格式分析)
3. [转换规则](#3-转换规则)
4. [后端实现](#4-后端实现)
5. [前端实现](#5-前端实现)
6. [转换报告](#6-转换报告)
7. [错误处理](#7-错误处理)
8. [决策记录](#8-决策记录)

---

## 1. 概述

初始化转换器用于将旧版静态 Lore JSON 文件（SillyTavern 格式）一次性转换为 RST Lores 系统所需的完整数据结构。

### 集成方式

- **后端**：新增 `lore_converter.py` 服务 + API 路由 `POST /sessions/{session_name}/lores/import`
- **前端**：在 `RstLorePanel.vue` 面板顶部添加"导入静态 Lore"按钮，通过文件上传触发导入
- **前置条件**：必须有已创建且未关闭的活跃 Session
- **导入模式**：追加（不覆盖已有数据）

### 参考文件

以 `D:\AI\RST\data\lore\wwRP_latest_1.json` 作为源格式的参考样本。

---

## 2. 源格式分析

### 2.1 源文件结构

```json
{
  "scanDepth": 4,
  "entries": [
    {
      "id": "dd46def4-8769-48b6-be82-d8cdf5fbd1df",
      "name": "主世界总览",
      "category": "world_base",
      "object": null,
      "role": "System",
      "disable": false,
      "content": "# YAML 总体世界设定\nworldview:\n  realms: [尘世, 冥域]\n  ...",
      "comment": "主世界总览",
      "constant": true,
      "key": ["世界设定", "五国"],
      "preventRecursion": true,
      "excludeRecursion": true
    }
  ]
}
```

### 2.2 源格式字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | UUID v4 格式的唯一标识 |
| `name` | string | 条目名称 |
| `category` | string | 范畴：`world_base` / `characters` / `skills` / `elements` / `society` / `place` / `factions` / `others` |
| `object` | string \| null | 关联对象描述（RST 不使用） |
| `role` | string | 注入角色 `System` / `User`（RST 不使用） |
| `disable` | bool | 是否禁用 |
| `content` | string | YAML 格式的纯文本设定内容 |
| `comment` | string | 备注（RST 不使用） |
| `constant` | bool | 是否常驻注入 |
| `key` | string[] | 检索关键词列表 |
| `preventRecursion` | bool | 防止递归匹配（RST 不使用） |
| `excludeRecursion` | bool | 排除递归匹配（RST 不使用） |

### 2.3 源格式的 category 值（实际出现）

从参考样本中观察到的范畴值：

- `world_base` — 世界观设定（如"主世界总览"、"灵力水平"、"冥域"、"邪祟"、"妖精"）
- `characters` — 人物设定（如"遐蝶"、"云景"、"长离"、"吴晔"等）
- `skills` — 技能设定（如"时间操控"、"冥域化身"）
- `elements` — 元素设定（如"清辉"）— RST 中无此范畴，需映射
- `society` — 社会制度/国家设定（如"今庭与苍角"、"黎罗与碧骓"、"朔原与朱雀"）
- `place` — 地点设定（如"珑云山"、"乘霄山"）
- `factions` — 组织势力（如"南云村村民"、"宜河吴氏"、"阳关裴氏"）— 注意部分 faction 条目内嵌了多个人物设定
- `others` — 其他（如"临时NPC"）

### 2.4 源格式与 RST 格式的关键差异

| 维度 | 旧格式 (ST) | RST 格式 |
|------|------------|----------|
| **ID 格式** | UUID v4 | nanoid 12 chars |
| **范畴名** | `characters` / `factions` / `elements` | `character` / `faction` / 无 `elements`（归入 `skills`） |
| **禁用字段** | `disable` | `disabled` |
| **标签字段** | `key` | `tags` |
| **人物存储** | 与其他条目混合在 `entries` 数组中 | 独立 `CharacterFile`，每人一文件 |
| **人物数据** | 扁平 YAML content 文本 | 结构化字段（`CharacterData` + `CharacterForm`） |
| **丢弃字段** | — | `object`, `role`, `comment`, `preventRecursion`, `excludeRecursion` |
| **新增字段** | — | `created_at`, `updated_at`, `character_id`, `form_id`, `memories`, 结构化 `relationship` 等 |
| **文件组织** | 单个 JSON 文件 | 多文件目录结构（每范畴一文件 + 每人物一文件 + 索引） |

---

## 3. 转换规则

### 3.1 范畴映射表

| 源 `category` | 目标 `LoreCategory` | 处理方式 |
|---|---|---|
| `world_base` | `WORLD_BASE` | 直接转为 `LoreEntry` |
| `society` | `SOCIETY` | 直接转为 `LoreEntry` |
| `place` | `PLACE` | 直接转为 `LoreEntry` |
| `factions` | `FACTION` | 范畴名修正 → `LoreEntry` |
| `skills` | `SKILLS` | 直接转为 `LoreEntry` |
| `elements` | `SKILLS` | 合并归入 `skills` 范畴 → `LoreEntry` |
| `others` | `OTHERS` | 直接转为 `LoreEntry` |
| `characters` | `CHARACTER` | **特殊处理**：解析 content → `CharacterData` + `CharacterForm` |
| 其他未知值 | `OTHERS` | 兜底映射 + 记录 warning |

### 3.2 通用条目转换（非 character）

适用范畴：`world_base`, `society`, `place`, `factions`, `skills`, `elements`, `others`

```
源字段                    → 目标 LoreEntry 字段
──────────────────────────────────────────────
id (uuid)                → id (新生成 nanoid 12)
name                     → name
category                 → category (经映射表转换)
content                  → content (原样保留)
disable                  → disabled
constant                 → constant
key[]                    → tags[]
—                        → created_at (取转换执行时间)
—                        → updated_at (取转换执行时间)

丢弃字段：comment, object, role, preventRecursion, excludeRecursion
```

### 3.3 人物条目转换（category = characters）

人物条目需要**两层转换**，采用 **"尽力解析 + 兜底保留"** 策略。

#### 3.3.1 第一层：基础字段映射

```
源字段                    → 目标字段
──────────────────────────────────────
id (uuid)                → 丢弃（新生成 character_id，nanoid 12）
name                     → name（优先使用外层 name）
category                 → 固定为 CHARACTER
disable                  → disabled
constant                 → constant
key[]                    → tags[]
—                        → created_at, updated_at (转换时间)
—                        → memories = []（初始化为空）
—                        → active_form_id = 默认形态 ID
```

#### 3.3.2 第二层：Content 内容解析

**步骤 1**：尝试 YAML 解析 `content` 字段

源格式的 content 通常以 `# YAML ...` 或 `# 人物名 ...` 注释开头，后续为 YAML 格式内容。解析时需处理：
- 移除 Markdown 标题行（`# ...`）后再进行 YAML 解析
- 若 content 中包含多个 YAML 文档（以 `# ` 分隔的不同章节），尝试分别解析再合并
- YAML 解析库使用 `PyYAML`，设置 `yaml.safe_load()`

**步骤 2**：若 YAML 解析成功，按字段名模糊匹配提取到 RST `CharacterData` 对应字段

| Content 中的键（模糊匹配） | 目标 `CharacterData` 字段 | 提取规则 |
|---|---|---|
| `name` | `name` | 取值（但优先使用外层 `name` 字段） |
| `species` / `race` | `race` | 取值；缺失则默认 `"未知"` |
| `age` / `birth` | `birth` | 取原始字符串值 |
| `homeland` / `origin` | `homeland` | 取值 |
| `identities` | `role` | 若为列表则用 `; ` 拼接为字符串 |
| `aliases` / `nicknames` | `aliases` | 取列表 |
| `faction` / `organization` | `faction` | 取值 |
| `objective` / `goal` | `objective` | 取值 |
| `personality` | `personality` | 若为嵌套结构则递归拼接所有子项 |
| `relationships` / `relationship` | `relationship[]` | 尝试解析为 `Relationship` 结构列表（见 §3.3.5） |
| `appearance` / `physique` / `overall_impression` / `facial_features` / `hair_style` | 默认形态 `physique` | 递归拼接外貌描述 |
| `features` | 默认形态 `features` | 取值 |
| `clothing` / `clothing_style` | 默认形态 `clothing` | 递归拼接衣着描述 |
| `abilities` / `Abilities` | 不映射到数值字段 | 保留在兜底 content 中（见步骤 4） |
| `growth_experience` / `experience` / `key_events` / `family_background` | 不直接映射 | 保留在兜底 content 中 |
| `temperament` / `social_deportment` / `habitual_mannerisms` | 追加到 `personality` | 拼接 |
| `hobbies` / `vocal_characteristics` / `common_phrases` / `speech_style` / `communication` | 不直接映射 | 保留在兜底 content 中 |

**步骤 3**：形态生成规则

- 始终生成一个 `is_default=True` 的默认形态（`form_name="默认形态"`）
- 即使 content 中描述了多形态（如遐蝶的 `girl_form` / `dragon_form`），**不自动拆分**
- 多形态信息整合到默认形态的 `features` 和 `physique` 字段中
- 原因：自动拆分多形态的可靠性不足，容易出错，留待用户手动拆分

**步骤 4**：兜底策略

- YAML 解析失败时：将完整原始 `content` 存入默认形态的 `features` 字段，`race` 设为 `"未知"`
- YAML 解析成功但存在未匹配字段时：将 **未匹配到的 YAML 顶级键值对** 序列化后追加到默认形态 `features` 字段末尾，用分隔线标注：

```
---
# 以下为未自动解析的原始内容
key1: value1
key2: ...
```

- 所有兜底情况在转换报告中记录 `ConversionWarning`

#### 3.3.3 递归拼接策略

用于将 YAML 嵌套结构转换为可读文本（`_flatten_yaml_value`）：

```python
def _flatten_yaml_value(value: Any, indent: int = 0) -> str:
    """将 YAML 值递归拼接为可读文本"""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "; ".join(str(item) for item in value)
    if isinstance(value, dict):
        lines = []
        for k, v in value.items():
            flat_v = _flatten_yaml_value(v, indent + 1)
            lines.append(f"{'  ' * indent}{k}: {flat_v}")
        return "\n".join(lines)
    return str(value)
```

示例：

```yaml
# 源格式
personality:
  core:
    - 踏实勤恳
    - 理想主义
  surface:
    - 恭敬有礼
  inner:
    - 对未知世界和强大力量抱有好奇向往
```

转换结果（`personality` 字段）：

```
core: 踏实勤恳; 理想主义
surface: 恭敬有礼
inner: 对未知世界和强大力量抱有好奇向往
```

#### 3.3.4 外貌信息合并策略

多个外貌相关键值合并到 `physique` 字段中，合并顺序：

1. `overall_impression`（总体印象）
2. `physique`（体格）
3. `facial_features`（面部特征）
4. `hair_style`（发型）
5. `appearance`（外观描述）

各段之间用换行分隔，每段以键名作为小标题：

```
【总体印象】质朴敦厚的少年修士，眉目清秀眼神干净
【体格】身高170cm，体重59kg，身形尚在发育略显单薄
【面部特征】清秀的鹅蛋脸，健康的麦色肌肤，清澈的黑色眼眸
【发型】黑色短发整齐利落
```

#### 3.3.5 关系（Relationship）解析规则

源格式中 `relationships` 可能有多种格式：

**格式 A**：列表中的简单文本

```yaml
relationships:
  - 苍角：表面崇敬的守护神，内心视为君权障碍
  - 朝廷官员：善于平衡掌控的臣属与对手
```

解析规则：以中文冒号 `：` 或英文冒号 `:` 分割，前半为 `target`（人物名），后半为 `relation`（关系描述）。

**格式 B**：字典结构

```yaml
relationships:
  齐松: 如父如师的恩师
  师姐: 向往的师姐
```

解析规则：key 为 `target`，value 为 `relation`。
解析失败时：将原始文本追加到 `personality` 字段末尾。

### 3.4 Faction 条目中嵌入的人物处理

某些 `factions` 类条目中实际包含了多个人物设定（如 "宜河吴氏" 包含吴岳、吴晗两个人物；"阳关裴氏" 包含裴明关、裴明舟、裴方宏三个人物）。

转换器提供两种策略，通过参数 `split_faction_characters` 控制：

#### 策略 A（保守，默认，`split_faction_characters=false`）

保持为 `LoreEntry(category=FACTION)`，content 原样保留。用户可以事后在 RstLorePanel 中手动拆分。

#### 策略 B（激进，可选，`split_faction_characters=true`）

1. 检测 content 中是否存在多个 `name:` 字段（通过正则 `^name:\s*` 多行匹配）
2. 若检测到多个 `name:` 块，按 `name:` 行将 content 分割为多个人物块
3. 每个人物块按 §3.3 的人物解析规则转换为独立的 `CharacterFile`
4. 同时保留一个精简的 faction 条目（仅包含 `overview:` 等组织级信息，去除人物详情）
5. 拆分出的人物自动设置 `faction` 字段为该组织条目名称
6. 拆分结果在报告中详细记录

### 3.5 ID 映射表

转换器维护一个 **旧 ID → 新 ID** 的映射表，用于：

- 保留条目间的可追溯性
- 生成转换报告
- 未来可能的引用修复

映射表格式：`dict[str, str]`，key 为源 UUID，value 为新 nanoid。

---

## 4. 后端实现

### 4.1 新增文件

| 文件 | 职责 |
|------|------|
| `backend/app/services/lore_converter.py` | 转换器核心逻辑 |
| `backend/tests/test_lore_converter.py` | 转换器测试 |

### 4.2 新增数据模型

在 `backend/app/models/lore.py` 中新增以下模型：

```python
class SourceEntry(BaseModel):
    """旧格式的单条 Lore 条目"""
    id: str = ""
    name: str = ""
    category: str = ""
    object: str | None = None
    role: str = "System"
    disable: bool = False
    content: str = ""
    comment: str = ""
    constant: bool = False
    key: list[str] = Field(default_factory=list)
    preventRecursion: bool = True
    excludeRecursion: bool = False


class SourceLoreFile(BaseModel):
    """旧格式完整 Lore 文件"""
    scanDepth: int = 4
    entries: list[SourceEntry] = Field(default_factory=list)


class ConversionWarning(BaseModel):
    source_id: str
    name: str
    type: str              # "partial_parse" | "category_unknown" | "yaml_parse_error"
                           # | "faction_embedded_characters"
    message: str


class ConversionReport(BaseModel):
    source_file: str
    session_name: str
    timestamp: str
    statistics: dict       # 详见 §6
    id_mapping: dict[str, str]
    category_summary: dict[str, int]
    warnings: list[ConversionWarning] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)
```

### 4.3 转换器服务类设计

```python
# backend/app/services/lore_converter.py

class LoreConverter:
    """将静态 Lore JSON 转换为 RST 数据结构，写入指定 Session"""

    CATEGORY_MAP: dict[str, LoreCategory] = {
        "world_base": LoreCategory.WORLD_BASE,
        "society":    LoreCategory.SOCIETY,
        "place":      LoreCategory.PLACE,
        "factions":   LoreCategory.FACTION,
        "faction":    LoreCategory.FACTION,
        "skills":     LoreCategory.SKILLS,
        "elements":   LoreCategory.SKILLS,
        "others":     LoreCategory.OTHERS,
        "characters": LoreCategory.CHARACTER,
    }

    KNOWN_CHARACTER_KEYS: set[str] = {
        "name", "species", "race", "age", "birth", "gender",
        "homeland", "origin", "identities", "aliases", "nicknames",
        "faction", "organization", "objective", "goal",
        "personality", "temperament", "social_deportment", "habitual_mannerisms",
        "relationships", "relationship",
        "appearance", "physique", "overall_impression", "facial_features", "hair_style",
        "features", "clothing", "clothing_style",
    }

    PASSTHROUGH_KEYS: set[str] = {
        # 这些键不映射到 CharacterData 字段，保留在兜底 content 中
        "abilities", "Abilities",
        "growth_experience", "experience", "key_events", "family_background",
        "hobbies", "vocal_characteristics", "common_phrases", "speech_style",
        "communication", "accessories",
    }

    def __init__(
        self,
        session_name: str,
        source_data: dict,
        source_filename: str = "",
        split_faction_characters: bool = False,
    ) -> None: ...

    def convert(self) -> ConversionReport:
        """
        执行转换主流程：
        1. 将 source_data 解析为 SourceLoreFile
        2. 遍历 entries，按 category 分流
        3. character → _convert_character()
        4. 其他 → _convert_generic_entry()
        5. 使用 LoreStore 写入文件
        6. 调用 store.rebuild_index()
        7. 生成 ConversionReport
        """
        ...

    def _map_category(self, src_category: str) -> LoreCategory:
        """映射范畴，未知值兜底到 OTHERS 并记录 warning"""
        ...

    def _convert_generic_entry(self, src: SourceEntry) -> LoreEntry:
        """
        通用条目转换（§3.2）：
        - 生成新 nanoid
        - 映射 disable→disabled, key→tags
        - content 原样保留
        """
        ...

    def _convert_character(self, src: SourceEntry) -> CharacterFile:
        """
        人物条目转换（§3.3）：
        - 第一层：基础字段映射
        - 第二层：尝试 YAML 解析 content
        - 提取字段 → CharacterData + CharacterForm
        - 兜底保留未解析内容
        """
        ...

    def _parse_character_yaml(self, content: str) -> dict | None:
        """
        预处理 content 后进行 YAML 解析：
        - 移除 # 标题行
        - 处理多文档结构
        - 返回解析后的 dict 或 None
        """
        ...

    def _extract_character_fields(self, parsed: dict, src: SourceEntry) -> CharacterData:
        """从 YAML 解析结果提取 CharacterData 字段"""
        ...

    def _build_default_form(self, parsed: dict) -> CharacterForm:
        """构建默认形态，合并外貌/衣着信息"""
        ...

    def _parse_relationships(self, raw: Any) -> list[Relationship]:
        """解析关系数据（§3.3.5），支持多种格式"""
        ...

    def _flatten_yaml_value(self, value: Any, indent: int = 0) -> str:
        """递归拼接 YAML 值为可读文本（§3.3.3）"""
        ...

    def _merge_appearance(self, parsed: dict) -> str:
        """合并多个外貌相关字段（§3.3.4）"""
        ...

    def _collect_remaining(self, parsed: dict, used_keys: set[str]) -> str:
        """收集未匹配的键值对，序列化为兜底文本"""
        ...
```

### 4.4 API 路由

在 `backend/app/routers/lores.py` 中新增：

```python
from fastapi import File, UploadFile

@router.post(
    "/sessions/{session_name}/lores/import",
    response_model=ConversionReport,
)
async def import_lore_route(
    session_name: str,
    file: UploadFile = File(...),
    split_faction_characters: bool = Query(default=False),
):
    """
    上传静态 Lore JSON 文件并转换导入到当前 Session。

    前置条件：
    - Session 必须存在
    - Session 必须未关闭（is_closed=False）

    行为：
    - 追加模式，不覆盖已有 Lore 数据
    - 转换完成后自动重建索引
    """
    # 1. 验证 session 存在且 is_closed=False
    session = get_session_storage(session_name)
    if session.is_closed:
        raise HTTPException(status_code=400, detail="Session is closed")

    # 2. 读取并解析 JSON
    raw = await file.read()
    try:
        source_data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid JSON file") from exc

    if "entries" not in source_data:
        raise HTTPException(status_code=400, detail="Missing 'entries' field in JSON")

    # 3. 执行转换
    converter = LoreConverter(
        session_name=session_name,
        source_data=source_data,
        source_filename=file.filename or "unknown",
        split_faction_characters=split_faction_characters,
    )
    report = converter.convert()

    return report
```

### 4.5 与现有代码的集成

| 集成点 | 说明 |
|--------|------|
| `LoreStore` | 转换器通过 `LoreStore` 进行文件读写，复用原子写入、索引重建 |
| `generate_id()` | 复用现有 `backend/app/models/__init__.py` 中的 nanoid 生成器 |
| `get_session_dir()` | 复用现有 session 目录定位逻辑 |
| `get_session_storage()` | 复用现有 session 存在性验证 |
| `store.add_entry()` | 追加条目到范畴文件 |
| `store.save_character()` | 保存人物文件 |
| `store.rebuild_index()` | 转换完成后一次性重建索引 |

### 4.6 依赖

转换器使用 `PyYAML`（已在项目依赖中）进行 YAML 解析，不引入新依赖。

---

## 5. 前端实现

### 5.1 修改文件

| 文件 | 修改内容 |
|------|---------|
| `frontend/src/api/lores.ts` | 新增 `importLore()` API 方法 |
| `frontend/src/types/lore.ts` | 新增 `ConversionReport` 等类型定义 |
| `frontend/src/components/panels/RstLorePanel.vue` | 添加导入按钮和上传交互 |

### 5.2 TypeScript 类型定义

在 `frontend/src/types/lore.ts` 中新增：

```typescript
export interface ConversionWarning {
  source_id: string
  name: string
  type: string
  message: string
}

export interface ConversionReport {
  source_file: string
  session_name: string
  timestamp: string
  statistics: Record<string, number>
  id_mapping: Record<string, string>
  category_summary: Record<string, number>
  warnings: ConversionWarning[]
  errors: string[]
}
```

### 5.3 API 封装

在 `frontend/src/api/lores.ts` 中新增：

```typescript
import type { ConversionReport } from "@/types/lore"

export async function importLore(
  sessionName: string,
  file: File,
  splitFactionCharacters: boolean = false,
): Promise<ConversionReport> {
  const formData = new FormData()
  formData.append("file", file)
  const { data } = await apiClient.post<ConversionReport>(
    `${BASE(sessionName)}/import`,
    formData,
    {
      headers: { "Content-Type": "multipart/form-data" },
      params: { split_faction_characters: splitFactionCharacters },
    },
  )
  return data
}
```

### 5.4 RstLorePanel 导入 UI

在 `RstLorePanel.vue` 面板的顶部工具栏中添加导入功能：

#### UI 交互流程

```
1. 用户点击 [📥 导入静态 Lore] 按钮
   ↓
2. 弹出原生文件选择器（accept=".json"）
   ↓
3. 选择文件后显示确认对话框（NDialog 或 NModal）：
   ┌──────────────────────────────────────┐
   │  导入静态 Lore                        │
   │                                      │
   │  文件: wwRP_latest_1.json            │
   │  目标: 当前 Session (xxx)            │
   │                                      │
   │  ⚠️ 导入将追加到现有数据中，           │
   │     不会覆盖已有条目。                 │
   │                                      │
   │  ☐ 拆分 faction 中嵌入的人物          │
   │                                      │
   │         [取消]  [确认导入]             │
   └──────────────────────────────────────┘
   ↓
4. 确认后显示 loading 状态，调用 importLore() API
   ↓
5. 成功后显示转换报告摘要（NMessage 或 NNotification）：
   "✅ 导入完成：18 个条目 + 7 个人物，3 个警告"
   ↓
6. 刷新 Lore 列表（重新加载条目和人物数据）
```

#### 错误处理

- API 返回 400：显示错误详情（如 "Session is closed"、"Invalid JSON"）
- API 返回 404：显示 "Session not found"
- 网络错误：显示通用错误提示

---

## 6. 转换报告

### 6.1 报告结构

```json
{
  "source_file": "wwRP_latest_1.json",
  "session_name": "my_session",
  "timestamp": "2026-02-28T16:00:00Z",
  "statistics": {
    "total_source_entries": 25,
    "converted_entries": 18,
    "converted_characters": 7,
    "skipped": 0,
    "warnings_count": 3,
    "errors_count": 0
  },
  "id_mapping": {
    "dd46def4-8769-48b6-be82-d8cdf5fbd1df": "aBcDeFgHiJkL",
    "c3d976a7-a19e-471c-98a5-9c9a6bc287e4": "mNoPqRsTuVwX"
  },
  "category_summary": {
    "world_base": 4,
    "society": 3,
    "place": 2,
    "faction": 3,
    "skills": 3,
    "others": 1,
    "character": 7
  },
  "warnings": [
    {
      "source_id": "c3d976a7-a19e-471c-98a5-9c9a6bc287e4",
      "name": "遐蝶",
      "type": "partial_parse",
      "message": "部分字段未能自动映射（abilities, experience 等），已保留到默认形态 features 字段"
    },
    {
      "source_id": "579ef754-ad76-49ed-a41d-8eba6aaf953c",
      "name": "长离",
      "type": "partial_parse",
      "message": "relationships 中存在未完整解析项，已附加到 personality 原文"
    },
    {
      "source_id": "76d25a05-7f8c-475f-b908-2c00e3c3b594",
      "name": "清辉",
      "type": "category_unknown",
      "message": "源范畴 'elements' 已映射到 'skills'"
    }
  ],
  "errors": []
}
```

### 6.2 Warning 类型说明

| `type` | 触发条件 | 说明 |
|--------|---------|------|
| `partial_parse` | 人物 content YAML 解析成功但有字段未映射 | 未映射内容已保留到 features |
| `yaml_parse_error` | 人物 content YAML 解析失败 | 原始 content 已兜底保留到 features |
| `category_unknown` | 源 category 不在已知映射表中 | 已映射到 OTHERS |
| `faction_embedded_characters` | Faction 条目中检测到嵌入的人物数据 | 仅当 split=false 时提示 |

---

## 7. 错误处理

| 场景 | HTTP 状态码 | 响应 | 说明 |
|------|------------|------|------|
| Session 不存在 | 404 | `{"detail": "Session 'xxx' not found"}` | — |
| Session 已关闭 | 400 | `{"detail": "Session is closed"}` | 必须先打开 Session |
| 上传文件不是合法 JSON | 400 | `{"detail": "Invalid JSON file"}` | — |
| JSON 缺少 entries 字段 | 400 | `{"detail": "Missing 'entries' field in JSON"}` | — |
| 上传文件过大（>10MB） | 413 | — | 可选：在路由中限制文件大小 |
| 单个条目转换失败 | 正常返回 | 记录到 `report.errors` | 继续处理其他条目，不中断 |
| YAML 解析失败（人物） | 正常返回 | 记录 warning + 兜底保留 | 不影响整体转换 |
| 未知 category | 正常返回 | 映射到 OTHERS + 记录 warning | 不影响整体转换 |

---

## 8. 决策记录

| # | 决策点 | 最终方案 | 原因 |
|---|--------|---------|------|
| 1 | 人物 content 解析失败处理 | 保留到默认形态 `features` 字段 + warning | 确保不丢失数据，用户可事后手动整理 |
| 2 | `elements` 范畴处理 | 合并到 `skills` | RST 规格文档 §2.2 已定义 skills 含 elements 子类 |
| 3 | 导入入口 | 后端 API `POST /import` + 前端 RstLorePanel 上传按钮 | 用户要求前端集成，需有活跃 Session |
| 4 | 输出位置 | 当前活跃 Session 的 `rst_data/` 目录 | 用户确认 |
| 5 | Faction 嵌入人物 | 默认不拆分，可选参数 `split_faction_characters` 启用 | 保守策略更安全，避免误拆 |
| 6 | 导入模式 | 追加（不覆盖已有数据） | 避免误删已有 Lore |
| 7 | 多形态自动拆分 | 不拆分，合并到默认形态 | 自动拆分不可靠 |
| 8 | `Relationship.target` | 直接使用人物名称或泛指目标 | 与 RST 关系字段语义一致，避免无意义 ID 映射 |
| 9 | 能力数值自动提取 | 不提取，保留原文 | 源格式数值格式不统一，自动提取不可靠 |
| 10 | CLI 工具 vs API | 仅提供 API（前端上传），不另建 CLI | 用户明确要求前端集成 |
