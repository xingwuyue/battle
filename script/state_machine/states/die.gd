# 死亡状态类
# 继承自 State 基类，用于处理角色的死亡行为
# 当角色进入死亡状态时，停止所有移动（速度重置为零）
class_name DieState
extends State

# 进入死亡状态时调用
# 参数 _msg: 可选的消息字典，用于传递额外信息（当前未使用）
func enter(_msg: Dictionary = {}) -> void:
	# 获取角色节点（状态机的父节点）
	var character := state_machine.get_parent() as Character
	if character:
		# 将角色速度重置为零，停止所有移动
		character.velocity = Vector2.ZERO