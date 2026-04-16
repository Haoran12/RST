# RST系统的会话调度模式
分为三类：
- ST模式
- RST模式
- Agent模式

## ST模式
即SillyTavern式的调度方式. 每轮对话一次请求-返回工作流程如下:
- 用户输入
- 根据当前会话采用的Preset, 按顺序寻找各条目内容, 构筑Prompt
- 其中, Lore Before, User Description, Chat History,Lore After, Scene 这几条的content需要系统根据会话配置和聊天记录组装;
- 关键的是两种Lore, 依据用户设定的条件激活条目, 并根据条目注入位置属性决定条目在总Prompt中的位置

### ST模式-Lore注入
ST模式的Lore注入追求复刻SiilyTavern的效果.
[ST_mode注入流程说明](ST_mode.md)
但是为了兼容本系统的RST模式, 每个会话创建时, 都把绑定世界书拷贝到本会话目录内. 这样就形成了一个**静态的**会话专用世界书, 供ST模式使用. 也就是说ST模式的Lore注入是**静态的**, 不会动态更新会话目录下的世界书文件.

## RST模式
RST模式把世界书与会话绑定, 每个会话相当于**存档**, 拥有自己的动态演化的世界书文件.
### RST模式-Lore文件结构
Lore文件分为人物/其他设定/世界记忆三大模块, 详情参见
[RP](rp_agent_framework_spec.md)

RST模式的每一轮对话的工作流程:
- 用户输入
- 根据当前会话采用的Preset, 按顺序寻找各条目内容, 构筑Prompt
- 其中, Lore Before, User Description, Chat History,Lore After, Scene 这几条的content需要系统根据会话配置和聊天记录组装;
- **Lore注入产生差异**
- 更关键的是每隔一段时间**动态更新Lore文件**, 达成RP世界的动态演化.
详情见[RST_mode注入与更新流程说明](RST_mode.md)

## Agent模式
Agent模式沿用RST模式的Lore文件管理方式, 但是有着完全不同的工作流程.
[rp_agent_framework_spec.md](rp_agent_framework_spec.md)