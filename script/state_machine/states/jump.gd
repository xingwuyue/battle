# 跳跃状态类
# 继承自 State 基类，用于处理角色的跳跃行为
# 当角色进入跳跃状态时，播放跳跃动画，并在动画结束后根据输入切换到移动或空闲状态
class_name JumpState
extends State

# 跳跃动画计时器，用于跟踪动画剩余时间
var _timer: float = 0.0

# 进入跳跃状态时调用
# 参数 _msg: 可选的消息字典，用于传递额外信息（当前未使用）
func enter(_msg: Dictionary = {}) -> void:
	# 重置计时器
	_timer = 0.0
	# 获取角色节点（状态机的父节点）
	var character := state_machine.get_parent() as Character
	if character:
		# 进入跳跃时，将角色速度重置为零
		character.velocity = Vector2.ZERO
		# 如果角色有动画管理器，则播放跳跃动画并获取动画时长
		if character.animation_manager:
			var anim_name := character.animation_manager.jump_anim
			_timer = character.get_animation_duration(anim_name)

# 物理更新函数，每个物理帧调用
# 参数 _delta: 物理帧时间间隔（当前未使用）
func physics_update(_delta: float) -> void:
	# 获取角色节点
	var character := state_machine.get_parent() as Character
	if character and character.data:
		# 根据输入方向、移动速度和空中移动倍率更新角色速度
		character.velocity = character.input_direction * character.data.move_speed * character.air_move_multiplier

# 每帧更新函数
# 参数 delta: 帧时间间隔，用于递减计时器
func update(delta: float) -> void:
	# 递减计时器
	_timer -= delta
	# 如果计时器结束（跳跃动画播放完毕）
	if _timer <= 0:
		# 获取角色节点
		var character := state_machine.get_parent() as Character
		if character and character.input_direction != Vector2.ZERO:
			# 如果角色有输入方向，则切换到移动状态
			state_machine.transition_to("move")
		else:
			# 否则切换到空闲状态
			state_machine.transition_to("idle")
