# RST Lore 导入转换器增强方案 —— 语义识别优化

> 版本: 2.0  
> 日期: 2026-03-03  
> 状态: 待实施  
> 前置文档: [lore-converter-spec.md](./lore-converter-spec.md)

---

## 目录

1. [问题诊断](#1-问题诊断)
2. [优化目标](#2-优化目标)
3. [技术方案](#3-技术方案)
4. [实施细节](#4-实施细节)
5. [测试计划](#5-测试计划)
6. [影响评估](#6-影响评估)

---

## 1. 问题诊断

### 1.1 现状

当前 `LoreConverter` 采用 v1.0 规格实现，存在以下核心缺陷，导致在真实 Lore 文件上效果极差：

#### 缺陷 1：YAML 解析在真实数据上大面积失败

源格式的 `content` 字段是**伪 YAML**——人工编写的类 YAML 格式文本，包含大量让标准 YAML 解析器失败的内容：

| 问题类型 | 示例 | 说明 |
|---------|------|------|
| 值中未转义的冒号 | `初临尘世: 862年，曾经去往尘世, 抵达钦斯国-康藏雪原` | 值部分的冒号被 YAML 解析器误解为嵌套 |
| 带括号的键名 | `clothing(gilr_form):`, `灵力水平(冥域本体) : 300k+` | 括号干扰键名解析 |
| 不一致的缩进 | 同一文档内混合 2 空格和 4 空格缩进 | 缩进层级判断错误 |
| 逗号分隔的多值键名 | `girl_form, the first form:` | 逗号使 YAML 解析器产生歧义 |
| 多文档分隔 | 以 `# 遐蝶 能力设定 (Abilities)` 等 markdown 标题分隔 | 当前仅简单移除 `#` 行，未分段解析 |

**实际效果**：约 60-70% 的角色条目 YAML 解析失败，导致整个 content 被原样扔进 `features` 字段。

#### 缺陷 2：字段提取完全依赖精确英文键名

`_take_value` 方法只匹配硬编码的英文键名（如 `"strength"`, `"power"`, `"combat_power"`），但真实数据大量使用中文键名：

```yaml
# 实际数据中出现的键名 → 当前解析器无法识别
灵力水平: 14k              # 应映射到 form.mana_potency
外貌: ...                   # 应映射到 appearance
能力设定: ...               # 应映射到 abilities
成长经历: ...               # 应映射到 growth_experience
说话风格: ...               # 应映射到 speech_style
习惯性小动作: ...           # 应映射到 habitual_mannerisms
```

#### 缺陷 3：灵力数值提取完全不工作

`mana_potency` 字段（CharacterForm 上）需要从以下格式中提取数值：

```yaml
灵力水平: 14k
灵力水平: 16k-28k  
灵力水平: 300k+
灵力水平: 约18k
灵力水平接近人类巅峰（约18k）
cultivation_base: 灵力水平 14k
```

当前 `_to_non_negative_int` 无法解析这些格式，全部回退到默认值。

> **重要区分**：
> - `灵力水平` → 映射到 `CharacterForm.mana_potency`（灵力/法力水平）
> - `strength`（CharacterData 上）→ 偏向物理/肉体力量，不是灵力
> - `features`（CharacterForm 上）→ 用于存放不适合其他特定字段的角色特点

#### 缺陷 4：abilities 内嵌的结构化信息被丢弃

abilities/Abilities 部分通常包含：
- `灵力水平` → 应提取到 `form.mana_potency`
- 技能列表（如 `剑术`, `风`, `火`）→ 应提取到 form 的 `skills` 和 `element`
- 能力描述 → 应保留到 form 的 `features`（角色特点描述）

当前实现将 abilities 整段作为"未映射内容"扔进 features，丢失了结构化提取的机会。

#### 缺陷 5：Faction 内嵌角色的键名检测过于简单

当前通过正则 `^\s*name\s*:\s*.+$` 检测是否有嵌入的角色块。但实际数据中可能使用中文键名或其他格式，导致检测不到。

### 1.2 典型失败案例

以角色"遐蝶"的 content 为例：

```
# YAML 遐蝶-冥域 人物设定

name: 遐蝶
age: 与世长存
gender: Female
species: 仙灵
identities:
  - 冥域本身(True form)的意识化, 尘世没有生灵知道遐蝶的存在
  ...
appearance:
  遐蝶拥有人类少女(gilr_form)和死龙(Dragon_form)两种身躯...
  girl_form, the first form:
    - 体态匀称的少女(外表17岁), 以紫色和白色为主色调
    length: 1.68m
    ...
 clothing(gilr_form):
  - 连衣裙, 白色为主, 带有紫色点缀.
  ...
# 遐蝶 能力设定 (Abilities)
Abilities:
  灵力水平(冥域本体) : 300k+
  灵力水平(进入尘世): 10k(平静状态) - 72k(灵力激发)
  冥域化身: 
    - 一系列与冥域、灵魂相关的能力
```

**当前解析结果**：
- YAML 解析失败（多处格式错误）
- 整个 content 原样存入 `features`
- `race` = "Unknown", `mana_potency` = 100 (默认), `personality` = ""
- **0 个字段被正确提取**

**期望解析结果**：
- `name` = "遐蝶"
- `race` = "仙灵"  
- `gender` = "female"
- `birth` = "与世长存"
- `role` = "冥域本身(True form)的意识化; 以少女形态(girl_form)意识化; ..."
- `personality` = 完整提取
- `physique` = 合并 appearance 相关信息
- `form.mana_potency` = 300（从 `灵力水平(冥域本体) : 300k+` 提取，取最大值）
- `form.element` = [] (无元素信息)
- `form.skills` = ["冥域化身"] (从 abilities 提取)
- `form.features` = 能力描述文本 + 其他不适合特定字段的角色特点

---

## 2. 优化目标

### 2.1 量化目标

| 指标 | 当前 | 目标 |
|------|------|------|
| 角色条目字段提取率 | ~30%（大部分 YAML 解析失败） | ≥90% |
| `mana_potency` 正确提取率 | ~0% | ≥80% |
| `race` 正确提取率 | ~30% | ≥95% |
| `personality` 正确提取率 | ~30% | ≥85% |
| `relationship` 正确提取率 | ~30% | ≥80% |
| 外貌信息提取率 | ~30% | ≥85% |

### 2.2 设计原则

1. **纯本地处理**：所有增强逻辑都在本地完成，不依赖 LLM fallback
2. **向后兼容**：增强后的解析器应该对已经能正确解析的内容保持一致的输出
3. **优雅降级**：每一层增强都有 fallback，最终保底仍然是原始 content 保留
4. **不引入新依赖**：仅使用 Python 标准库 + PyYAML（已有）

### 2.3 字段语义定义

在实施前明确各目标字段的语义，避免错误映射：

| RST 字段 | 所属模型 | 语义说明 |
|---------|---------|---------|
| `strength` | `CharacterData` | 物理/肉体力量，不是灵力 |
| `mana_potency` | `CharacterForm` | 灵力/法力水平，对应源数据中的 `灵力水平` |
| `features` | `CharacterForm` | 角色特点：不适合其他特定字段的角色特征描述 |
| `physique` | `CharacterForm` | 外貌/体格描述 |
| `skills` | `CharacterForm` | 技能名称列表 |
| `element` | `CharacterForm` | 元素亲和列表 |
| `clothing` | `CharacterForm` | 衣着描述 |
| `personality` | `CharacterData` | 性格、气质、社交举止、习惯动作的综合描述 |
| `role` | `CharacterData` | 身份/职业/定位 |
| `relationship` | `CharacterData` | 人际关系列表 |

---

## 3. 技术方案

### 3.1 整体架构

```
Content 输入
    │
    ▼
┌─────────────────────────┐
│  Phase 1: 内容预处理      │  修复常见的伪 YAML 格式问题
│  _preprocess_content()   │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phase 2: YAML 解析      │  使用 PyYAML 解析预处理后的内容
│  _parse_character_yaml() │  （增强：分段解析 + 预处理输入）
└────────────┬────────────┘
             │
         成功?──────┐
         │Yes       │No
         ▼          ▼
    已有流程   ┌─────────────────────────┐
         │    │  Phase 3: 行级语义解析    │  逐行解析 key:value 结构
         │    │  _parse_content_lines()  │  构建层级化 dict
         │    └────────────┬────────────┘
         │                 │
         │            成功?──────┐
         │            │Yes       │No
         │            ▼          ▼
         │       使用解析结果   保留原始 content（现有兜底）
         │            │
         ▼            ▼
┌─────────────────────────┐
│  Phase 4: 语义键名匹配    │  中英文同义词映射提取字段
│  增强 _take_value()      │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phase 5: 增强数值提取    │  解析 "14k", "300k+" 等格式
│  _extract_mana_potency() │  映射到 form.mana_potency
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phase 6: 技能/元素提取   │  从 abilities 中提取 skills/element
│  _extract_skills_and_    │
│  _elements()             │
└────────────┬────────────┘
             │
             ▼
      CharacterData + CharacterForm 输出
```

### 3.2 各 Phase 详细设计

#### Phase 1: 内容预处理（`_preprocess_content`）

**输入**：原始 content 字符串  
**输出**：预处理后的字符串，更容易被 YAML 解析器处理

**处理步骤**：

```python
def _preprocess_content(self, content: str) -> str:
    lines = content.replace("\r\n", "\n").split("\n")
    result_lines = []
    
    for line in lines:
        # 1. 移除 markdown 标题行
        if line.lstrip().startswith("#"):
            continue
        
        # 2. 处理带括号的键名: "clothing(gilr_form):" → "clothing_gilr_form:"
        line = self._fix_parenthesized_key(line)
        
        # 3. 处理逗号分隔的键名描述: "girl_form, the first form:" → "girl_form:"
        line = self._fix_comma_key(line)
        
        # 4. 修复值中的冒号（对于看起来像自由文本的行进行引号包裹）
        line = self._fix_value_colons(line)
        
        result_lines.append(line)
    
    return "\n".join(result_lines)
```

**子方法设计**：

```python
_RE_PAREN_KEY = re.compile(r'^(\s*)([\w\u4e00-\u9fff]+)\s*\(([^)]*)\)\s*:\s*(.*)$')

def _fix_parenthesized_key(self, line: str) -> str:
    """
    'clothing(gilr_form):' → 'clothing_gilr_form:'
    '灵力水平(冥域本体) : 300k+' → '灵力水平_冥域本体: 300k+'
    """

def _fix_comma_key(self, line: str) -> str:
    """
    'girl_form, the first form:' → 'girl_form:'
    '尘世,  生机勃勃的世间:' → '尘世:'
    仅处理以冒号结尾或冒号后跟值的行
    """

def _fix_value_colons(self, line: str) -> str:
    """
    检测第一个冒号后的值部分是否还包含冒号，
    如果值看起来像自由文本（长度较长、包含中文），则用引号包裹值。
    """
```

#### Phase 2: 分段式 YAML 解析（增强现有 `_parse_character_yaml`）

```python
def _parse_character_yaml(self, content: str) -> dict[str, Any] | None:
    # 1. 按 markdown 标题分段
    segments = self._split_by_headers(content)
    
    # 2. 对每一段分别预处理和 YAML 解析
    merged = {}
    for segment in segments:
        preprocessed = self._preprocess_content(segment)
        cleaned = "\n".join(
            line for line in preprocessed.split("\n")
            if not line.lstrip().startswith("#")
        ).strip()
        if not cleaned:
            continue
        parsed = self._safe_load_yaml(cleaned)
        if isinstance(parsed, dict):
            merged.update(parsed)
    
    if merged:
        return merged
    
    # 3. 分段失败则整体预处理 + 解析
    preprocessed = self._preprocess_content(content)
    cleaned_lines = [
        line for line in preprocessed.split("\n")
        if not line.lstrip().startswith("#")
    ]
    cleaned = "\n".join(cleaned_lines).strip()
    parsed = self._safe_load_yaml(cleaned)
    if isinstance(parsed, dict):
        return parsed
    
    # 4. 多文档尝试
    merged2: dict[str, Any] = {}
    for doc in self._safe_load_all_yaml(cleaned):
        if isinstance(doc, dict):
            merged2.update(doc)
    
    return merged2 or None

def _split_by_headers(self, content: str) -> list[str]:
    """按 markdown 标题行 (# ...) 分割内容为多个段落"""
    segments = []
    current = []
    for line in content.split("\n"):
        if line.lstrip().startswith("#") and current:
            segments.append("\n".join(current))
            current = []
        elif not line.lstrip().startswith("#"):
            current.append(line)
    if current:
        segments.append("\n".join(current))
    return segments if segments else [content]
```

#### Phase 3: 行级语义解析器（`_parse_content_lines`）

当 YAML 解析完全失败时启用，逐行解析伪 YAML 内容：

```python
_KV_PATTERN = re.compile(
    r'^([\w\u4e00-\u9fff][\w\u4e00-\u9fff\s_.]*?)\s*[:：]\s*(.*)',
)

def _parse_content_lines(self, content: str) -> dict[str, Any] | None:
    """
    逐行解析伪 YAML 内容，构建层级化字典。
    
    策略：
    1. 每行检测 "key: value" 或 "key：value" 模式
    2. 通过缩进层级判断嵌套关系
    3. "- " 开头的行识别为列表项
    4. 无冒号的行作为上一个键的续行值
    
    如果识别率 < 30%，返回 None（内容不是 key:value 格式）
    """
```

核心逻辑要点：
- 支持中文冒号 `：` 和英文冒号 `:`
- 通过缩进层级构建嵌套 dict
- 检测 `- ` 列表项并自动转为 list
- 设定识别率阈值（30%），低于阈值则认为不是结构化内容

#### Phase 4: 语义键名映射

```python
SEMANTIC_KEY_MAP: dict[str, list[str]] = {
    # RST标准键名 → [同义词列表]
    "name": ["name", "名字", "姓名", "名称", "角色名"],
    "species": ["species", "race", "种族", "族类", "种类", "race_name"],
    "gender": ["gender", "sex", "性别"],
    "birth": ["age", "birth", "年龄", "出生", "生辰", "岁数"],
    "homeland": ["homeland", "origin", "故乡", "出身", "出身地", "出生地"],
    "identities": ["identities", "identity", "身份", "职业", "角色身份"],
    "aliases": ["aliases", "nicknames", "别名", "别称", "称号", "绰号"],
    "faction": ["faction", "organization", "阵营", "组织", "势力", "所属", "归属"],
    "objective": ["objective", "goal", "motivation", "目标", "志向", "目的", "动机"],
    "personality": ["personality", "个性", "性格", "人格"],
    "temperament": ["temperament", "气质", "风度", "性情"],
    "social_deportment": ["social_deportment", "社交举止", "社交", "待人接物", "社交风格"],
    "habitual_mannerisms": [
        "habitual_mannerisms", "习惯动作", "小动作", "习惯性小动作", "习惯",
    ],
    "relationship": [
        "relationships", "relationship", "关系", "人际关系", "人物关系",
    ],
    "appearance": ["appearance", "外貌", "外观", "容貌", "相貌"],
    "overall_impression": ["overall_impression", "总体印象", "整体印象", "第一印象"],
    "physique": ["physique", "体格", "体型", "身材", "body_shape", "身体"],
    "facial_features": ["facial_features", "面部特征", "五官", "面容", "脸部"],
    "hair_style": ["hair_style", "hairstyle", "hair", "发型", "头发"],
    "features": ["features", "特征", "特点", "特殊"],
    "clothing": ["clothing", "clothing_style", "服装", "衣着", "穿着", "装扮", "服饰"],
    "abilities": ["abilities", "Abilities", "能力", "技能", "法术", "术法", "能力设定"],
    "growth_experience": [
        "growth_experience", "experience", "成长经历", "经历", "背景", "人物背景",
    ],
    "key_events": ["key_events", "关键事件", "重要事件", "大事记", "事件"],
    "family_background": ["family_background", "家庭背景", "家世", "出身背景", "家族背景"],
    "hobbies": ["hobbies", "爱好", "兴趣", "嗜好", "喜好"],
    "speech_style": [
        "speech_style", "vocal_characteristics", "communication",
        "说话风格", "语言风格", "说话方式",
    ],
    "common_phrases": ["common_phrases", "口头禅", "常用词", "常用语"],
    "accessories": ["accessories", "配饰", "饰品", "装饰", "佩饰"],
    # 灵力/mana 相关（注意：不是 strength）
    "mana_potency": [
        "灵力水平", "灵力", "法力", "mana", "mana_potency",
        "cultivation_base", "修为", "灵力储量",
    ],
    # 物理力量（strength）
    "strength": ["strength", "力量", "体力", "物理力量", "肉体力量"],
}
```

**重构 `_take_value`**：

```python
def _take_value(self, parsed, used_keys, *candidate_keys):
    """
    增强版：先尝试精确匹配 candidate_keys，
    再尝试通过语义映射匹配。
    """
    # 1. 现有的精确匹配逻辑（保持向后兼容）
    # 2. 语义映射匹配（新增）
```

#### Phase 5: 灵力数值提取（`_extract_mana_potency`）

> **注意**：灵力水平映射到 `CharacterForm.mana_potency`，不是 `CharacterData.strength`。

```python
_POWER_LEVEL_RE = re.compile(r'(\d+(?:\.\d+)?)\s*[kK万]')

def _extract_mana_potency(self, parsed: dict, used_keys: set) -> int:
    """
    从多个可能的位置提取灵力/法力数值，映射到 form.mana_potency。
    
    搜索优先级：
    1. 顶级 灵力水平/mana 相关键
    2. abilities 嵌套中的 灵力水平/cultivation_base 键
    3. 任意键值中包含 "灵力水平" 文本的内容
    
    数值解析规则：
    - "14k" → 14000 (或保持 k 单位原值: 14)
    - "300k+" → 300000 (或: 300)
    - "16k-28k" → 取较大值 28000 (或: 28)
    - "10k(平静状态) - 72k(灵力激发)" → 取较大值 72000 (或: 72)
    - "约18k" → 18000 (或: 18)
    
    返回值范围与 mana_potency 字段兼容（默认 100, ge=0）
    """
    # 1. 查找灵力相关键
    raw = self._take_value(
        parsed, used_keys,
        "灵力水平", "灵力", "mana_potency", "cultivation_base",
    )
    if raw is not None:
        value = self._parse_power_number(raw)
        if value > 0:
            return value
    
    # 2. 查找 abilities 内嵌的灵力水平
    abilities = self._find_abilities_section(parsed)
    if abilities and isinstance(abilities, dict):
        for key, val in abilities.items():
            key_text = self._as_text(key)
            if "灵力" in key_text or "mana" in key_text.lower() or "cultivation" in key_text.lower():
                value = self._parse_power_number(val)
                if value > 0:
                    return value
    
    # 3. 默认值
    return 100

def _parse_power_number(self, raw: Any) -> int:
    """
    从各种格式中解析灵力数值。
    取所有匹配中的最大值。
    返回 0 表示无法解析。
    """
    text = self._as_text(raw).strip()
    if not text:
        return 0
    
    # 匹配所有 "数字k" 格式，取最大值
    matches = self._POWER_LEVEL_RE.findall(text)
    if matches:
        values = []
        for m in matches:
            try:
                values.append(int(float(m) * 1000))
            except (ValueError, TypeError):
                pass
        if values:
            return max(values)
    
    # 尝试直接整数
    try:
        val = int(text)
        return val if val > 0 else 0
    except (ValueError, TypeError):
        pass
    
    # 匹配纯数字
    nums = re.findall(r'\d+', text)
    if nums:
        try:
            return int(nums[0])
        except (ValueError, TypeError):
            pass
    
    return 0
```

#### Phase 6: 技能与元素提取（`_extract_skills_and_elements`）

```python
KNOWN_ELEMENTS = {
    "风", "火", "冰", "金", "木", "土", "雷",
    "water", "fire", "ice", "wind", "earth", "metal", "thunder",
    "lightning", "wood",
}

def _extract_skills_and_elements(
    self, parsed: dict, used_keys: set,
) -> tuple[list[str], list[str], str]:
    """
    从 abilities 部分提取技能和元素。
    
    返回: (skills_list, element_list, abilities_text_for_features)
    - skills_list → form.skills
    - element_list → form.element
    - abilities_text → 追加到 form.features（角色特点描述）
    """
```

提取规则：
- 已知元素名（风/火/冰/金/木/土/雷）→ `element`
- 具名能力（如 `剑术`, `冥域化身`, `清辉`）→ `skills`
- 整体能力描述文本 → `features`
- 跳过已在 `mana_potency` 中处理的 `灵力水平` 键

### 3.3 重构 `_convert_character` 流程

```python
async def _convert_character(self, src, faction_override=None):
    # 1. 尝试增强 YAML 解析（Phase 1 + Phase 2）
    parsed = self._parse_character_yaml(src.content)
    
    # 2. YAML 失败时，使用行级语义解析器（Phase 3）
    if parsed is None:
        parsed = self._parse_content_lines(src.content)
    
    # 3. 行级解析也失败且启用 LLM fallback → 使用 LLM
    if parsed is None and self.llm_fallback:
        parsed, llm_note = await self._parse_character_with_llm(src)
    
    # 4. 使用增强的语义键名匹配提取字段（Phase 4）
    # 5. 使用增强的灵力数值提取（Phase 5）→ form.mana_potency
    # 6. 使用技能/元素提取（Phase 6）→ form.skills, form.element, form.features
    # 7. 构建 CharacterData + CharacterForm
    ...
```

### 3.4 `_build_default_form` 增强

```python
def _build_default_form(self, parsed, used_keys) -> CharacterForm:
    form = CharacterForm(...)
    
    # 现有: physique, features, clothing
    form.physique = self._merge_appearance(parsed, used_keys)
    
    # 新增: mana_potency
    form.mana_potency = self._extract_mana_potency(parsed, used_keys)
    
    # 新增: skills, element (从 abilities 提取)
    skills, elements, abilities_text = self._extract_skills_and_elements(parsed, used_keys)
    form.skills = skills
    form.element = elements
    
    # features: 先取源数据中的 features 字段（角色特点）
    features_text = self._flatten_yaml_value(
        self._take_value(parsed, used_keys, "features")
    )
    # 再追加 abilities 描述
    if abilities_text:
        if features_text:
            features_text += f"\n\n---\n# 能力描述\n{abilities_text}"
        else:
            features_text = abilities_text
    form.features = features_text
    
    # 现有: clothing
    clothing = self._flatten_yaml_value(
        self._take_value(parsed, used_keys, "clothing", "clothing_style")
    )
    if clothing:
        form.clothing = clothing
    
    return form
```

### 3.5 Faction 内嵌角色检测增强

```python
# 增强正则，同时支持中英文键名
_name_block_pattern = re.compile(
    r"(?im)^\s*(?:name|名字|姓名|角色名)\s*[:：]\s*.+$"
)
```

---

## 4. 实施细节

### 4.1 文件修改清单

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `backend/app/services/lore_converter.py` | 重构 | 核心增强逻辑 |
| `backend/tests/test_lore_converter.py` | 新增测试 | 使用真实样本数据验证 |

### 4.2 新增方法清单

| 方法 | 所属 Phase | 说明 |
|------|-----------|------|
| `_preprocess_content()` | Phase 1 | 预处理伪 YAML 内容 |
| `_fix_parenthesized_key()` | Phase 1 | 修复带括号的键名 |
| `_fix_comma_key()` | Phase 1 | 修复逗号分隔的键描述 |
| `_fix_value_colons()` | Phase 1 | 修复值中的冒号 |
| `_split_by_headers()` | Phase 2 | 按 markdown 标题分段 |
| `_parse_content_lines()` | Phase 3 | 行级语义解析器 |
| `_looks_like_kv()` | Phase 3 | 判断是否是 key:value 格式 |
| `_split_kv()` | Phase 3 | 分割 key:value |
| `_semantic_resolve_key()` | Phase 4 | 语义键名解析 |
| `_extract_mana_potency()` | Phase 5 | 灵力数值提取（→ form.mana_potency） |
| `_parse_power_number()` | Phase 5 | 解析灵力数值格式 |
| `_extract_skills_and_elements()` | Phase 6 | 提取技能和元素 |

### 4.3 修改方法清单

| 方法 | 修改内容 |
|------|---------|
| `__init__()` | 初始化反向语义映射表 |
| `_parse_character_yaml()` | 增加预处理 + 分段解析 |
| `_take_value()` | 增加语义映射匹配 |
| `_extract_character_fields()` | 整合增强提取；移除 strength 从灵力字段提取的逻辑 |
| `_build_default_form()` | 填充 mana_potency, skills, element 字段 |
| `_convert_character()` | 增加行级解析 fallback |
| `_name_block_pattern` | 支持中文键名检测 |

### 4.4 新增常量

| 常量 | 说明 |
|------|------|
| `SEMANTIC_KEY_MAP` | 语义键名映射表（中英文同义词） |
| `KNOWN_ELEMENTS` | 已知元素类型集合 |
| `_POWER_LEVEL_RE` | 灵力数值匹配正则 |
| `_KV_PATTERN` | key:value 行模式正则 |
| `_RE_PAREN_KEY` | 带括号键名正则 |

---

## 5. 测试计划

### 5.1 新增测试用例

#### 测试 1: 真实角色条目完整解析

使用"遐蝶"的完整 content，验证：
- `name` = "遐蝶"
- `race` = "仙灵"
- `gender` = "Female"
- `birth` = "与世长存"
- `role` 包含 "冥域"
- `personality` 非空
- `physique` 包含外貌信息
- `form.mana_potency` ≥ 10000（从 `灵力水平(冥域本体) : 300k+` 提取）
- `form.features` 包含能力描述

#### 测试 2: 灵力数值解析（_parse_power_number）

测试各种格式：
- `"14k"` → 14000
- `"300k+"` → 300000
- `"16k-28k"` → 28000（取最大值）
- `"10k(平静状态) - 72k(灵力激发)"` → 72000（取最大值）
- `"约18k"` → 18000

#### 测试 3: 行级解析器

使用故意构造的无法被 YAML 解析的内容，验证行级解析器能正确提取字段。

#### 测试 4: 语义键名映射

验证中文键名（如 `种族`, `灵力水平`, `外貌`）能正确映射到对应的 RST 字段。

#### 测试 5: 技能和元素提取

验证从 abilities 部分能提取出：
- 元素列表（风、火、冰等）
- 技能名称列表
- 灵力数值到 mana_potency

#### 测试 6: 向后兼容

使用现有测试数据，验证增强后的解析器不破坏已有的正确解析行为。

### 5.2 现有测试影响

所有现有测试应继续通过，增强是纯增量的。

---

## 6. 影响评估

### 6.1 风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| 预处理误改正常 YAML 值 | 低 | 中 | 预处理规则保守，仅处理明确的格式问题；分段解析提供容错 |
| 行级解析器误识别非结构化文本 | 低 | 低 | 设置 30% 识别率阈值，低于阈值回退到原始 content |
| 语义映射产生错误匹配 | 低 | 中 | 映射表人工审核；精确匹配优先于语义匹配 |
| 灵力数值解析错误 | 中 | 低 | 提供默认值兜底；转换报告中记录提取结果供用户审核 |
| 现有测试回归 | 低 | 高 | 精确匹配优先保证向后兼容；所有现有测试必须通过 |

### 6.2 性能评估

- 预处理和行级解析均为 O(n) 复杂度（n 为行数），不会引入性能问题
- 语义映射表为常量查找，O(1)
- 整体转换时间预计无明显变化

### 6.3 影响范围

- 仅修改 `backend/app/services/lore_converter.py` 和测试文件
- 不影响 API 路由、前端代码、数据模型
- 不引入新的依赖
