# 角色数据类
# 继承自 Resource，用于存储角色的各种属性和配置
# 可以在编辑器中创建资源实例并设置属性
class_name CharacterData
extends Resource

# 性别枚举
enum Gender { MALE, FEMALE }
# 阵营枚举
enum Faction { PLAYER, ENEMY, ALLY, NEUTRAL }

# 基本信息组
@export_group("Basic Info")
# 角色名称
@export var character_name: String = ""
# 角色年龄
@export var age: int = 0
# 角色性别
@export var gender: Gender = Gender.MALE
# 角色阵营
@export var faction: Faction = Faction.NEUTRAL

# 属性组
@export_group("Attributes")
# 最大生命值
@export var max_health: float = 100.0
# 当前生命值
@export var current_health: float = 100.0
# 最大体力值
@export var max_stamina: float = 100.0
# 当前体力值
@export var current_stamina: float = 100.0
# 最大法力值
@export var max_mana: float = 100.0
# 当前法力值
@export var current_mana: float = 100.0
# 移动速度
@export var move_speed: float = 200.0
# 敏捷值
@export var agility: float = 10.0
# 攻击力
@export var attack: float = 10.0
# 防御力
@export var defense: float = 5.0
# 暴击率（0.0 到 1.0）
@export_range(0.0, 1.0) var crit_rate: float = 0.15

# 视觉资源组
@export_group("Visuals")
# 头像图标纹理
@export var avatar_icon: Texture2D
# 立绘纹理
@export var illustration: Texture2D