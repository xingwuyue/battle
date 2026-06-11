# 角色攻击配置资源。
# 该资源不描述具体招式细节，而是负责把“这个角色有哪些攻击入口”集中配置起来。
class_name CharacterAttackSet
extends Resource

# 地面普攻链。
# 按顺序对应普攻 1、普攻 2、普攻 3。
@export var ground_combo_moves: Array[Resource] = []

# 冲刺攻击。
# 角色处于冲刺状态时按攻击，会优先使用这个招式。
@export var dash_attack_move: Resource

# 空中攻击。
# 角色处于空中状态时按攻击，会优先使用这个招式。
@export var air_attack_move: Resource
