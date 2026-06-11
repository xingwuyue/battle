# 角色移动组件
# 负责承接角色的平面移动、高度系统、朝向更新与基础移动动画。
class_name MovementComponent
extends Node

# 宿主角色引用。
# 所有移动结算都写回这个角色实例。
var character: Character

# 当前高度。
# 角色跳跃时提升该值，并通过 VisualRoot 做视觉上抬。
var height: float = 0.0

# 当前垂直速度。
# 正值表示上升，负值表示下降。
var vertical_velocity: float = 0.0

# 当前移动速度倍率。
# 冲刺等效果通过修改该倍率影响最终移动速度。
var movement_speed_multiplier: float = 1.0


# 初始化移动组件。
# 在 Character._ready() 中调用，用于缓存宿主角色并同步初始视觉高度。
func setup(host: Character) -> void:
	character = host
	_update_visual_height()


# 移动物理更新入口。
# 每个物理帧统一驱动高度系统、平面移动、动画与朝向。
func physics_update(delta: float) -> void:
	if not character:
		return

	# 先更新高度系统，确保本帧环境状态最新。
	_update_height(delta)

	var sm: StateMachine = character.state_machine

	# 根据当前状态决定是否允许发生位移。
	_apply_horizontal_movement(sm)

	# 位移完成后，再更新动画和视觉表现。
	_update_move_animation(sm)
	_update_facing()
	_update_visual_height()


# 判断角色当前是否处于空中。
func is_airborne() -> bool:
	if not character:
		return false
	return character.environment_state == Core.EnvironmentState.AIR


# 当前是否允许接收新的向上冲量。
# 当前规则是只有地面状态才允许再次起跳。
func can_receive_vertical_impulse() -> bool:
	if not character:
		return false
	return character.environment_state == Core.EnvironmentState.GROUND


# 对角色施加一个向上的垂直冲量。
# 该接口供跳跃、击飞、弹跳等公共高度能力复用。
func apply_vertical_impulse(impulse: float) -> bool:
	if not can_receive_vertical_impulse():
		return false

	height = max(height, 0.0)
	vertical_velocity = impulse
	character.environment_state = Core.EnvironmentState.AIR
	return true


# 设置当前移动速度倍率。
# 做最小值保护，避免出现负速度倍率。
func set_movement_speed_multiplier(multiplier: float) -> void:
	movement_speed_multiplier = max(multiplier, 0.0)


# 获取当前移动速度倍率。
func get_movement_speed_multiplier() -> float:
	return movement_speed_multiplier


# 获取当前移动速度。
# 在角色基础速度外层叠加移动倍率。
func get_current_move_speed() -> float:
	if not character:
		return 0.0
	return character.get_base_move_speed() * movement_speed_multiplier


# 获取当前高度。
func get_height() -> float:
	return height


# 获取当前垂直速度。
func get_vertical_velocity() -> float:
	return vertical_velocity


# 应用平面移动。
# 若当前状态不允许移动，则直接清空水平速度。
func _apply_horizontal_movement(sm: StateMachine) -> void:
	if _can_move_by_state(sm):
		character.velocity = character.input_direction * get_current_move_speed()
	else:
		character.velocity = Vector2.ZERO

	character.move_and_slide()


# 根据当前状态机状态判断角色是否允许移动。
# 保持与重构前 Character 中的规则一致。
func _can_move_by_state(sm: StateMachine) -> bool:
	if not sm:
		# 状态机未就绪时默认允许移动，避免初始化阶段卡死。
		return true

	var is_allowed_action: bool = (
		sm.current_action_state == Core.ActionState.IDLE or
		sm.current_action_state == Core.ActionState.PICKUP or
		sm.current_action_state == Core.ActionState.INTERACTION or
		sm.current_action_state == Core.ActionState.TOOL or
		sm.current_action_state == Core.ActionState.DASH
	)

	var is_attack_recovery: bool = (
		sm.current_action_state == Core.ActionState.ATTACK and
		sm.current_sub_attack_state == Core.AttackPhase.RECOVERY
	)

	return is_allowed_action or is_attack_recovery


# 更新地面移动动画。
# 只有地面、IDLE 且存在输入时才播放 walk，否则播放 idle。
func _update_move_animation(sm: StateMachine) -> void:
	if not character or not sm:
		return

	if is_airborne():
		return

	if sm.current_action_state != Core.ActionState.IDLE:
		return

	if character.input_direction != Vector2.ZERO:
		character.play_animation("walk")
	else:
		character.play_animation("idle")


# 更新角色朝向。
# 根据水平输入翻转 VisualRoot 的 x 缩放。
func _update_facing() -> void:
	if not character or not character.visual_root:
		return

	if character.input_direction.x < 0:
		character.visual_root.scale.x = -1
	elif character.input_direction.x > 0:
		character.visual_root.scale.x = 1


# 更新高度系统。
# 高度归零后回到地面环境状态。
func _update_height(delta: float) -> void:
	if not character:
		return

	if height <= 0.0 and vertical_velocity <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		character.environment_state = Core.EnvironmentState.GROUND
		return

	vertical_velocity -= character.height_gravity * delta
	height = max(height + vertical_velocity * delta, 0.0)

	if height <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		character.environment_state = Core.EnvironmentState.GROUND
	else:
		character.environment_state = Core.EnvironmentState.AIR


# 更新视觉高度表现。
# 通过抬高 VisualRoot 来表现跳跃高度，不修改碰撞体位置。
func _update_visual_height() -> void:
	if not character or not character.visual_root:
		return
	character.visual_root.position.y = -height
