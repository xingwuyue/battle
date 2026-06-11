# 攻击状态
# 该状态负责执行一个完整的攻击流程：
# 1. 读取攻击入口上下文并选择当前招式
# 2. 推进攻击帧
# 3. 更新攻击子阶段
# 4. 控制伤害盒开关与命中结算
# 5. 处理攻击位移与连段缓存
class_name AttackState
extends State

# 当前正在执行的招式资源。
var current_move: Resource

# 当前招式入口类型。
# 例如 ground / dash / air，用于决定下一招如何派生。
var current_variant: StringName = &""

# 当前地面连段索引。
# 仅当地面普攻链生效时使用。
var current_combo_index: int = 0

# 当前招式已经推进到第几帧。
# 采用从 0 开始的帧编号，与资源中的帧段定义保持一致。
var current_move_frame: int = 0

# 招式每帧的真实时长。
# 由 1 / 招式帧率计算，用于把真实时间累积成招式帧推进。
var seconds_per_move_frame: float = 0.0

# 当前招式内部的时间累加器。
# 用于在物理帧之间累积真实时间，等到足够推进一整帧时才真正推进招式逻辑。
var move_accumulator: float = 0.0

# 是否已经缓存了下一招。
# 这个标记用于在当前招式结束时决定是否直接切到下一段。
var queued_next_attack: bool = false

# 已缓存的下一招入口类型。
var queued_variant: StringName = &""

# 已缓存的下一招地面连段索引。
var queued_combo_index: int = 0

# 当前活跃伤害窗索引。
# 当攻击切换到不同的伤害窗时，会用它来决定是否清空本窗已命中目标集合。
var active_hit_window_index: int = -1

# 当前伤害窗内已经命中过的目标。
# 用实例 ID 做 key，避免同一窗口内重复打到同一个目标。
var already_hit_targets: Dictionary = {}


# 进入攻击状态。
# 这里会从 AttackAbility 中读取“这次攻击打算怎么起手”的上下文。
func enter() -> void:
	if not player_controller or not player_controller.attack_ability:
		push_warning("AttackState: 未找到 AttackAbility，无法进入攻击状态")
		_return_to_base_state()
		return

	var request: Dictionary = player_controller.attack_ability.consume_pending_transition_context()
	var variant: StringName = request.get("variant", &"")
	var combo_index: int = request.get("combo_index", 0)

	if variant == &"":
		push_warning("AttackState: 缺少攻击入口上下文，回退到基础状态")
		_return_to_base_state()
		return

	if not _start_move(variant, combo_index):
		_return_to_base_state()


# 退出攻击状态。
# 必须确保退出时关闭伤害盒并清理本次攻击过程中的运行时数据。
func exit() -> void:
	_disable_hitbox()
	queued_next_attack = false
	queued_variant = &""
	queued_combo_index = 0
	active_hit_window_index = -1
	already_hit_targets.clear()
	move_accumulator = 0.0
	seconds_per_move_frame = 0.0


# 攻击状态的物理帧更新。
# 这里按真实时间累积驱动招式帧推进，而不是每个物理帧都强制推进一次。
# 这样才能和美术配置的 FPS 严格对齐，避免运行时比编辑器更快。
func physics_update(delta: float) -> void:
	if not current_move:
		_return_to_base_state()
		return

	# 先把本帧真实时间累加进来。
	move_accumulator += delta

	# 只有累加到足够推进一次招式帧时，才执行该帧对应的逻辑并推进帧数。
	while move_accumulator >= seconds_per_move_frame:
		move_accumulator -= seconds_per_move_frame
		_update_attack_phase()
		_apply_attack_displacement()
		_update_hitbox_state()
		_consume_combo_input()
		current_move_frame += 1

		if current_move_frame >= current_move.get_safe_total_frames():
			if queued_next_attack:
				if not _start_move(queued_variant, queued_combo_index):
					_return_to_base_state()
					return
			else:
				_return_to_base_state()
				return


# 当前状态是否允许切换到其他状态。
# 攻击期间默认只允许被强制状态打断；若处于后摇，则和普通待机类似，可被更多状态打断。
func can_transition_to(state_name: String) -> bool:
	# 如果当前招式都还没成功启动，就不要阻止状态机回退，
	# 否则一旦进入攻击状态失败，角色会被卡在这个状态里。
	if not current_move:
		return true

	if state_name == "HitState" or state_name == "DieState":
		return true

	if state_machine.current_sub_attack_state == Core.AttackPhase.RECOVERY:
		return true

	return state_name == "AttackState"


# 启动一个新的招式。
# 无论是第一段攻击还是缓存后的下一段攻击，都会统一走这个入口。
func _start_move(variant: StringName, combo_index: int) -> bool:
	var move: Resource = character.get_attack_move(variant, combo_index)
	if not move:
		push_warning("AttackState: 未找到对应的招式资源，variant=%s combo_index=%d" % [String(variant), combo_index])
		return false

	if not character.consume_stamina(move.stamina_cost):
		push_warning("AttackState: 体力不足，无法释放招式 %s" % move.move_name)
		return false

	current_move = move
	current_variant = variant
	current_combo_index = combo_index
	current_move_frame = 0
	move_accumulator = 0.0
	seconds_per_move_frame = _calc_seconds_per_move_frame(current_move)
	queued_next_attack = false
	queued_variant = &""
	queued_combo_index = 0
	active_hit_window_index = -1
	already_hit_targets.clear()

	# 每次启动新招式时都先关闭旧伤害盒，再根据新招式配置重新打开。
	_disable_hitbox()
	_apply_hitbox_shape()

	if current_move.animation_name == &"":
		push_warning("AttackState: 招式 %s 未配置动画名" % current_move.move_name)
	else:
		character.play_animation(current_move.animation_name)

	_update_attack_phase()
	return true


# 更新当前攻击子阶段。
# 这个阶段会同步写回状态机，供冲刺、移动和下一招输入窗口判断使用。
func _update_attack_phase() -> void:
	if not current_move:
		return

	var next_phase = Core.AttackPhase.RECOVERY
	if current_move.startup_frame_range and current_move.startup_frame_range.contains(current_move_frame):
		next_phase = Core.AttackPhase.STARTUP
	elif _get_active_hit_window_index(current_move_frame) != -1:
		next_phase = Core.AttackPhase.ACTIVE
	elif current_move.recovery_frame_range and current_move.recovery_frame_range.contains(current_move_frame):
		next_phase = Core.AttackPhase.RECOVERY

	state_machine.update_sub_attack_state(next_phase)


# 根据当前帧应用攻击位移。
# 这里不走 CharacterBody2D 的常规移动速度，而是直接做水平推进，
# 用于表现攻击中的“上步”“突进”这类固定招式位移。
func _apply_attack_displacement() -> void:
	if not current_move:
		return

	for segment in current_move.movement_segments:
		if segment and segment.contains(current_move_frame):
			character.apply_attack_displacement(segment.get_distance_per_frame())


# 更新伤害盒开关和命中结算。
# 只有当前帧命中任一伤害窗时，才会激活伤害盒。
func _update_hitbox_state() -> void:
	var hit_window_index := _get_active_hit_window_index(current_move_frame)
	if hit_window_index == -1:
		active_hit_window_index = -1
		_disable_hitbox()
		return

	# 当切换到新的伤害窗时，清空这个窗口的命中记录，
	# 这样同一招的多段攻击窗可以分别造成伤害。
	if hit_window_index != active_hit_window_index:
		active_hit_window_index = hit_window_index
		already_hit_targets.clear()

	_enable_hitbox()
	_update_hitbox_transform()
	_resolve_hit_targets()


# 在允许的攻击阶段里消费一次攻击输入，并把下一招缓存下来。
# 当前规则是：
# - 前摇不允许缓存
# - 出招期和后摇期允许缓存
# - 空中攻击当前不支持续接
func _consume_combo_input() -> void:
	if not player_controller or not player_controller.attack_ability:
		return

	if not player_controller.attack_ability.consume_attack_request():
		return

	var current_phase = state_machine.current_sub_attack_state
	if current_phase == Core.AttackPhase.STARTUP:
		# 前摇阶段按攻击不会保留输入，直接吞掉。
		return

	if current_phase == Core.AttackPhase.ACTIVE and not current_move.can_queue_next_in_active:
		return

	if current_phase == Core.AttackPhase.RECOVERY and not current_move.can_queue_next_in_recovery:
		return

	var next_request := _get_next_attack_request()
	var next_variant: StringName = next_request.get("variant", &"")
	if next_variant == &"":
		return

	var next_combo_index: int = next_request.get("combo_index", 0)
	var next_move: Resource = character.get_attack_move(next_variant, next_combo_index)
	if not next_move:
		return

	if not character.can_consume_stamina(next_move.stamina_cost):
		return

	queued_next_attack = true
	queued_variant = next_variant
	queued_combo_index = next_combo_index


# 计算下一招的派生规则。
# 这里不走资源化攻击树，而是直接在代码中写清楚：
# - 地面 1 -> 地面 2
# - 地面 2 -> 地面 3
# - 冲刺攻击 -> 地面 2
# - 空中攻击当前不派生
func _get_next_attack_request() -> Dictionary:
	match current_variant:
		&"ground":
			if current_combo_index == 0:
				return {"variant": &"ground", "combo_index": 1}
			if current_combo_index == 1:
				return {"variant": &"ground", "combo_index": 2}
		&"dash":
			return {"variant": &"ground", "combo_index": 1}

	return {}


# 获取当前帧命中的伤害窗索引。
# 若返回 -1，说明当前帧不应该打开伤害盒。
func _get_active_hit_window_index(frame: int) -> int:
	if not current_move:
		return -1

	for index in range(current_move.active_frame_ranges.size()):
		var frame_range = current_move.active_frame_ranges[index]
		if frame_range and frame_range.contains(frame):
			return index

	return -1


# 按当前招式配置更新伤害盒的矩形尺寸。
# 初版统一使用 RectangleShape2D。
func _apply_hitbox_shape() -> void:
	var collision_shape: CollisionShape2D = character.get_attack_hitbox_shape()
	if not collision_shape:
		return

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if not rectangle_shape:
		rectangle_shape = RectangleShape2D.new()
		collision_shape.shape = rectangle_shape

	rectangle_shape.size = current_move.hitbox_size


# 根据角色当前朝向和招式配置，更新伤害盒位置。
# 朝左时只翻转 X 偏移，Y 偏移保持原值。
func _update_hitbox_transform() -> void:
	var attack_hitbox: Area2D = character.get_attack_hitbox()
	if not attack_hitbox:
		return

	attack_hitbox.position = Vector2(
		current_move.hitbox_offset.x * character.get_facing_sign(),
		current_move.hitbox_offset.y
	)


# 打开伤害盒。
# 同时启用 Area2D 的监控和碰撞形状，确保本帧可以拿到重叠结果。
func _enable_hitbox() -> void:
	var attack_hitbox: Area2D = character.get_attack_hitbox()
	var collision_shape: CollisionShape2D = character.get_attack_hitbox_shape()
	if not attack_hitbox or not collision_shape:
		return

	attack_hitbox.monitoring = true
	collision_shape.disabled = false


# 关闭伤害盒。
# 退出伤害窗或退出攻击状态时都要调用，避免待机时仍然保留命中能力。
func _disable_hitbox() -> void:
	var attack_hitbox: Area2D = character.get_attack_hitbox()
	var collision_shape: CollisionShape2D = character.get_attack_hitbox_shape()
	if attack_hitbox:
		attack_hitbox.monitoring = false
	if collision_shape:
		collision_shape.disabled = true


# 处理当前伤害窗内的所有重叠目标。
# 初版只结算一次基础伤害，不处理受击、击退和浮空。
func _resolve_hit_targets() -> void:
	var attack_hitbox: Area2D = character.get_attack_hitbox()
	if not attack_hitbox:
		return

	for body in attack_hitbox.get_overlapping_bodies():
		if not _is_valid_hit_target(body):
			continue

		var target_id: int = body.get_instance_id()
		if already_hit_targets.has(target_id):
			continue

		character.apply_damage_to_target(body, _calculate_damage())
		already_hit_targets[target_id] = true


# 计算当前招式伤害。
# 目前先按“角色攻击力 * 招式伤害倍率”做简单乘法。
func _calculate_damage() -> float:
	if not character or not character.data or not current_move:
		return 0.0

	return character.data.attack * current_move.damage_multiplier


# 判断一个节点是否可作为命中目标。
# 当前只排除角色自身及其子节点，后续若接入阵营系统，可在这里继续扩展。
func _is_valid_hit_target(target: Node) -> bool:
	if not target:
		return false

	if target == character:
		return false

	if character.is_ancestor_of(target):
		return false

	return true


# 计算“每招式帧对应多少真实秒”。
# 优先使用招式资源自身的 fps；若未配置或无效，则兜底取 15 FPS。
func _calc_seconds_per_move_frame(move: Resource) -> float:
	var fps: float = 15.0
	var source_fps = move.get("fps")
	if source_fps != null and float(source_fps) > 0.0:
		fps = float(source_fps)

	return 1.0 / fps


# 攻击结束后回退到基础状态。
# 若角色仍在空中，回 AirState；否则回 GroundState。
func _return_to_base_state() -> void:
	_disable_hitbox()

	if not state_machine:
		return

	if character and character.is_airborne():
		state_machine.transition_to("AirState")
	else:
		state_machine.transition_to("GroundState")
