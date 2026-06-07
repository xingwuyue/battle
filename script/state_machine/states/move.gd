# 移动状态类
# 继承自 State 基类，用于处理角色的移动行为
# 在物理更新时根据输入方向和移动速度更新角色速度
class_name MoveState
extends State

# 物理更新函数，每个物理帧调用
# 参数 _delta: 物理帧时间间隔（当前未使用）
func physics_update(_delta: float) -> void:
	# 获取角色节点（状态机的父节点）
	var character := state_machine.get_parent() as Character
	if character and character.data:
		# 获取基础移动速度
		var speed := character.data.move_speed
		# 如果角色正在冲刺，则速度翻倍
		if character.is_dashing:
			speed *= 2.0
		# 根据输入方向和速度计算角色速度
		character.velocity = character.input_direction * speed