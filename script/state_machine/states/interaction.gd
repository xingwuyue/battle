# 交互状态类
# 继承自 State 基类，用于处理角色的交互行为
# 当角色进入交互状态时，播放交互动画，动画结束后切换回空闲状态
class_name InteractionState
extends State

# 交互动画计时器，用于跟踪动画剩余时间
var _timer: float = 0.0

# 进入交互状态时调用
# 参数 _msg: 可选的消息字典，用于传递额外信息（当前未使用）
func enter(_msg: Dictionary = {}) -> void:
	# 重置计时器
	_timer = 0.0
	# 获取角色节点（状态机的父节点）
	var character := state_machine.get_parent() as Character
	if character:
		# 进入交互状态时，将角色速度重置为零
		character.velocity = Vector2.ZERO
		# 如果角色有动画管理器，则播放交互动画并获取动画时长
		if character.animation_manager:
			var anim_name := character.animation_manager.interaction_anim
			_timer = character.get_animation_duration(anim_name)

# 每帧更新函数
# 参数 delta: 帧时间间隔，用于递减计时器
func update(delta: float) -> void:
	# 递减计时器
	_timer -= delta
	# 如果计时器结束（交互动画播放完毕）
	if _timer <= 0:
		# 切换到空闲状态
		state_machine.transition_to("idle")