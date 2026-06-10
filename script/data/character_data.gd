# 角色数据资源
# 继承自 Resource，用于集中存储角色的基础信息、战斗属性和展示资源
# 这些字段本身不负责业务逻辑，但会被角色、UI 或数值系统读取
class_name CharacterData
extends Resource

# 性别枚举
enum Gender { MALE, FEMALE }
# 阵营枚举
enum Faction { PLAYER, ENEMY, ALLY, NEUTRAL }

# Inspector 可见说明：基础资料。
# 该字段只用于在编辑器中展示中文说明，不参与任何运行时逻辑。
@export_group("说明：基础资料")
@export_multiline var help_basic_info: String = "这一组用于填写角色的基础资料信息。\n\ncharacter_name、age、gender、faction 主要服务于资料展示、UI 和后续系统扩展，默认不直接改变战斗逻辑。\n\n其中 faction 常用于区分玩家、敌人、友军和中立单位，便于未来接入 AI、锁敌和伤害归属规则。 "

# 基本信息组
@export_group("Basic Info")
# 角色名称。
# 用于 UI、调试、策划识别或后续文本展示，不直接影响战斗逻辑。
@export var character_name: String = ""
# 角色年龄。
# 主要用于资料展示或剧情设定，当前默认不参与战斗结算。
@export var age: int = 0
# 角色性别。
# 便于角色资料、外观差异或后续剧情系统读取，默认不直接改变战斗表现。
@export var gender: Gender = Gender.MALE
# 角色阵营。
# 可用于区分玩家、敌人、友军和中立单位，方便 AI、锁敌、伤害判定或 UI 染色等系统扩展。
@export var faction: Faction = Faction.NEUTRAL

# Inspector 可见说明：战斗属性。
# 该字段只用于在编辑器中展示中文说明，不参与任何运行时逻辑。
@export_group("说明：战斗属性")
@export_multiline var help_attributes: String = "这一组用于填写角色面板属性。\n\nmax_health / current_health：生命值上限与当前值。\nmax_stamina / current_stamina：体力上限与当前值，可供冲刺、翻滚或蓄力玩法使用。\nmax_mana / current_mana：能量或念力类资源预留字段。\nmove_speed：基础移动速度，角色移动逻辑会直接读取。\nagility / attack / defense / crit_rate：数值系统预留字段，供未来战斗结算使用。\n\n建议保证“当前值”不要超过对应“最大值”。 "

# 属性组
@export_group("Attributes")
# 最大生命值。
# 表示角色理论上的生命上限，通常用于初始化 current_health 与血条上限。
@export var max_health: float = 100.0
# 当前生命值。
# 表示角色当前剩余生命，运行时通常会被受伤、治疗等逻辑实时修改。
@export var current_health: float = 100.0
# 最大体力值。
# 可用于冲刺、蓄力、翻滚等需要消耗体力的玩法，当前未必已经全部接入逻辑。
@export var max_stamina: float = 100.0
# 当前体力值。
# 表示角色此刻可用的体力余量，建议运行时始终限制在 0 到 max_stamina 之间。
@export var current_stamina: float = 100.0
# 最大法力值。
# 当前项目里更接近“能量槽/念力槽”的预留字段，可供技能系统读取。
@export var max_mana: float = 100.0
# 当前法力值。
# 表示当前可用能量，若未来接入技能消耗，建议始终和 max_mana 配套维护。
@export var current_mana: float = 100.0
# 移动速度。
# Character 在地面与空中移动时都会读取该值作为基础速度，再叠加状态倍率或冲刺倍率。
@export var move_speed: float = 200.0
# 敏捷值。
# 预留给命中、闪避、攻速或 AI 行为权重等数值系统使用，当前默认不直接影响移动。
@export var agility: float = 10.0
# 攻击力。
# 用于计算角色造成伤害时的基础攻击面板，具体如何结算取决于后续伤害公式。
@export var attack: float = 10.0
# 防御力。
# 用于减伤、硬直抵抗或其他防御相关公式，具体效果由战斗系统实现。
@export var defense: float = 5.0
# 暴击率，取值范围为 0.0 到 1.0。
# 例如 0.15 表示 15% 暴击概率。若后续接入暴击系统，建议不要超过 1.0。
@export_range(0.0, 1.0) var crit_rate: float = 0.15

# Inspector 可见说明：视觉资源。
# 该字段只用于在编辑器中展示中文说明，不参与任何运行时逻辑。
@export_group("说明：视觉资源")
@export_multiline var help_visuals: String = "这一组用于填写角色的 UI 或展示资源。\n\navatar_icon：适合在头像框、状态栏、角色列表中显示的小图。\nillustration：适合在立绘界面、对话界面或角色资料页中显示的大图。\n\n这些资源不会直接影响场景中的 AnimatedSprite2D 动画。 "

# 视觉资源组
@export_group("Visuals")
# 头像图标纹理。
# 适合在角色面板、血条头像、选择界面等 UI 中使用，通常是裁切好的小图。
@export var avatar_icon: Texture2D
# 立绘纹理。
# 用于对话、角色资料页或招募界面的完整展示图，不参与角色场景中的实时动画。
@export var illustration: Texture2D
