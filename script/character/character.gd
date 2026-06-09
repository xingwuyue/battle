# 角色类
# 继承自 CharacterBody2D，是游戏中角色的核心类
# 负责管理角色的状态机、动画、输入响应和物理移动
class_name Character
extends CharacterBody2D

# 预加载招式系统脚本，避免类型分析器无法解析新类
const PlayerMoveSet = preload("res://script/data/player_move/player_move_set.gd")
const PlayerMoveData = preload("res://script/data/player_move/player_move_data.gd")

# 角色数据资源，包含角色的属性配置（如移动速度等）
@export var data: CharacterData
# 视觉动画组
@export_group("Visual Motion")
# 跳跃时的视觉动画名称（用于播放视觉效果，如跳跃运动动画）
@export var jump_motion_anim: StringName = &"jump_motion"
# 阴影节点路径，用于根据腾空高度缩放阴影
@export var shadow_node_path: NodePath = ^"Shadow"
# 阴影最小缩放比例（跳到最高点时的缩放值）
@export_range(0.1, 1.0, 0.01) var shadow_min_scale_ratio: float = 0.6
# 达到最小阴影缩放时对应的视觉高度
@export_range(1.0, 500.0, 1.0) var shadow_height_for_min_scale: float = 150.0
# 招式系统组
@export_group("Action System")
# 主角招式表资源
@export var player_move_set: PlayerMoveSet
# 输入缓冲时长，用于优化连招手感
@export_range(0.0, 0.5, 0.01) var input_buffer_time: float = 0.15
# 移动参数组
@export_group("Movement")
# 空中移动倍率，控制角色在空中时的移动速度比例（0.0 到 1.0）
@export_range(0.0, 1.0, 0.05) var air_move_multiplier: float = 1

# 状态机节点引用（通过节点名 "StateMachine" 获取）
@onready var state_machine: StateMachine = get_node_or_null("StateMachine")
# 动画管理器节点引用（通过节点名 "AnimationManager" 获取）
@onready var animation_manager: AnimationManager = get_node_or_null("AnimationManager")
# 视觉根节点引用（用于控制视觉效果的位置）
@onready var visual_root: Node2D = get_node_or_null("VisualRoot")
# 阴影节点引用（用于根据高度缩放阴影）
@onready var shadow: Node2D = get_node_or_null(shadow_node_path) as Node2D
# 视觉动画播放器引用（用于播放视觉动画）
@onready var visual_animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
# 控制器节点引用（用于处理输入）
@onready var controller: Node = get_node_or_null("PlayerController")

# 当前输入方向向量
var input_direction: Vector2 = Vector2.ZERO
# 是否正在冲刺
var is_dashing: bool = false
# 视觉根节点的原始位置（用于重置位置）
var _visual_root_origin: Vector2 = Vector2.ZERO
# 阴影原始缩放（用于根据高度做比例缩放）
var _shadow_origin_scale: Vector2 = Vector2.ONE
# 当前缓冲中的逻辑输入命令
var _buffered_command: StringName = &""
# 当前缓冲命令剩余时间
var _buffered_command_time: float = 0.0
# 当前正在执行的招式配置
var _current_move: PlayerMoveData = null
# 当前招式已经执行的时间
var _current_move_elapsed: float = 0.0
# 当前招式总时长
var _current_move_duration: float = 0.0
# 当前招式上一帧已应用的累计位移
var _current_move_last_motion: Vector2 = Vector2.ZERO

# 节点就绪时调用（初始化）
func _ready() -> void:
	# 记录视觉根节点的原始位置
	if visual_root:
		_visual_root_origin = visual_root.position
	# 记录阴影的原始缩放
	if shadow:
		_shadow_origin_scale = shadow.scale
	# 连接状态机的状态变化信号到动画管理器
	if state_machine and animation_manager:
		state_machine.state_changed.connect(animation_manager.on_state_changed)
	# 连接状态机的状态变化信号到角色自身的状态变化处理函数
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)

	# 如果控制器是玩家控制器，则连接输入信号
	if controller is PlayerController:
		controller.move_input.connect(_on_move_input)
		controller.dash_input.connect(_on_dash_input)
		controller.jump_input.connect(func(): _try_act("jump"))
		controller.attack_input.connect(func(): queue_command(&"light_attack"))
		controller.defend_input.connect(func(): _try_act("defend"))
		controller.pickup_input.connect(func(): _try_act("pickup"))
		controller.interact_input.connect(func(): _try_act("interaction"))
		controller.tool_input.connect(func(): _try_act("tool"))

# 尝试转换状态（内部方法）
# 参数 state_name: 要转换到的状态名称
# 参数 msg: 可选的消息字典，用于传递额外信息
func _try_transition(state_name: StringName, msg: Dictionary = {}) -> void:
	if state_machine:
		state_machine.transition_to(state_name, msg)

# 尝试执行动作（仅在当前状态为 idle、move 或 defend 时允许）
# 参数 state_name: 要执行的动作对应的状态名称
func _try_act(state_name: StringName) -> void:
	if not state_machine or not state_machine.current_state:
		return
	# 获取当前状态名称（小写）
	var current := state_machine.current_state.name.to_lower()
	# 只有在空闲、移动或防御状态下才允许执行其他动作
	if current == "idle" or current == "move" or current == "defend":
		_try_transition(state_name)

# 缓冲一个逻辑输入命令，并立刻尝试匹配可执行招式
# 参数 command_name: 逻辑输入命令名称
func queue_command(command_name: StringName) -> void:
	_buffered_command = command_name
	_buffered_command_time = input_buffer_time
	try_consume_buffered_command()

# 尝试消费当前缓冲的命令并切换到对应招式
# 返回值: 是否成功命中并执行了一个招式
func try_consume_buffered_command() -> bool:
	if _buffered_command == &"" or not state_machine or not player_move_set:
		return false

	var move: PlayerMoveData = resolve_move_for_command(_buffered_command)
	if not move:
		return false

	# 命中招式后立即清空缓冲，避免同一输入重复触发
	clear_buffered_command()
	_try_transition("action", {"move_id": move.move_id})
	return true

# 清空当前输入缓冲
func clear_buffered_command() -> void:
	_buffered_command = &""
	_buffered_command_time = 0.0

# 根据逻辑输入命令和当前上下文匹配最优招式
# 参数 command_name: 逻辑输入命令名称
# 返回值: 匹配到的招式配置
func resolve_move_for_command(command_name: StringName) -> PlayerMoveData:
	if not player_move_set:
		return null

	return player_move_set.find_best_move(
		command_name,
		get_state_tags(),
		get_current_move_id(),
		get_current_move_phase()
	)

# 获取当前上下文标签集合，用于招式规则匹配
# 返回值: 当前状态与动作标签数组
func get_state_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	var current_state_name := ""
	if state_machine and state_machine.current_state:
		current_state_name = String(state_machine.current_state.name.to_lower())
		if not tags.has(current_state_name):
			tags.append(current_state_name)

	if is_airborne_context():
		tags.append("air")
	else:
		tags.append("ground")

	if current_state_name == "move" and is_dashing:
		tags.append("sprint")

	if _current_move:
		for tag in _current_move.tags:
			if not tags.has(tag):
				tags.append(tag)

	return tags

# 判断当前是否处于腾空上下文
# 返回值: 是否处于空中或视觉腾空状态
func is_airborne_context() -> bool:
	if state_machine and state_machine.is_current_state("jump"):
		return true
	if _current_move and _current_move.has_tag(&"air_attack"):
		return true
	if visual_root and visual_root.position.y < _visual_root_origin.y - 0.1:
		return true
	return false

# 获取当前招式 ID
# 返回值: 当前招式 ID；如果没有招式则返回空
func get_current_move_id() -> StringName:
	if _current_move:
		return _current_move.move_id
	return &""

# 获取当前招式所处阶段
# 返回值: 当前阶段名称；如果没有阶段则返回空
func get_current_move_phase() -> StringName:
	if not _current_move or _current_move_duration <= 0.0:
		return &""
	var progress: float = clampf(_current_move_elapsed / _current_move_duration, 0.0, 1.0)
	return _current_move.get_phase_at_progress(progress)

# 进入一个新招式
# 参数 msg: 由状态机传入的消息，至少包含 move_id
# 返回值: 是否成功进入招式
func enter_action(msg: Dictionary = {}) -> bool:
	if not player_move_set:
		return false

	var move_id: StringName = StringName(str(msg.get("move_id", "")))
	if move_id == &"":
		return false

	var move: PlayerMoveData = player_move_set.get_move_by_id(move_id)
	if not move:
		return false

	_current_move = move
	_current_move_elapsed = 0.0
	_current_move_last_motion = Vector2.ZERO
	_current_move_duration = max(
		move.get_duration(get_animation_duration(String(move.animation_name))),
		0.01
	)

	# 进入主动招式时先将常规移动速度归零，改由招式位移驱动
	velocity = Vector2.ZERO

	# 主招式动画由招式配置驱动，而不是由状态名驱动
	if animation_manager and String(move.animation_name) != "":
		animation_manager.play(String(move.animation_name), true)

	# 如果招式配置了视觉运动动画，则播放对应动画
	if String(move.motion_animation_name) != "":
		play_visual_animation(move.motion_animation_name, true)
	elif not is_airborne_context():
		reset_visual_root()

	return true

# 推进当前招式，并应用位移
# 参数 delta: 物理帧时间间隔
# 返回值: 当前招式是否已经结束
func advance_action(delta: float) -> bool:
	if not _current_move:
		return true

	_current_move_elapsed = min(_current_move_elapsed + delta, _current_move_duration)
	_apply_current_move_root_motion(delta)
	return _current_move_elapsed >= _current_move_duration

# 退出动作状态时清理招式运行时数据
func exit_action() -> void:
	_current_move = null
	_current_move_elapsed = 0.0
	_current_move_duration = 0.0
	_current_move_last_motion = Vector2.ZERO

# 根据当前招式配置应用程序位移
# 参数 delta: 物理帧时间间隔
func _apply_current_move_root_motion(delta: float) -> void:
	if not _current_move:
		velocity = Vector2.ZERO
		return
	if not _current_move.root_motion_enabled or _current_move.root_motion_curve == null:
		velocity = Vector2.ZERO
		return

	var progress: float = clampf(_current_move_elapsed / maxf(_current_move_duration, 0.01), 0.0, 1.0)
	var motion: Vector2 = _current_move.root_motion_curve.sample(progress)
	if _current_move.root_motion_curve.apply_facing and animation_manager and animation_manager.animated_sprite:
		if animation_manager.animated_sprite.flip_h:
			motion.x = -motion.x

	var delta_motion: Vector2 = motion - _current_move_last_motion
	_current_move_last_motion = motion
	velocity = delta_motion / maxf(delta, 0.0001)

# 处理移动输入
# 参数 direction: 移动方向向量
func _on_move_input(direction: Vector2) -> void:
	# 记录之前是否在冲刺
	var was_dashing := is_dashing
	# 更新输入方向
	input_direction = direction
	# 设置为非冲刺状态
	is_dashing = false
	# 更新角色朝向
	_update_facing(direction)
	if not state_machine:
		return
	# 如果没有输入方向（停止移动）
	if direction == Vector2.ZERO:
		# 如果当前是移动状态，则切换到空闲状态
		if state_machine.is_current_state("move"):
			_try_transition("idle")
		return
	# 如果当前是空闲状态，则切换到移动状态
	if state_machine.is_current_state("idle"):
		_try_transition("move")
	# 如果当前是移动状态且之前是冲刺状态，则重新播放移动动画（切换到普通移动）
	elif state_machine.is_current_state("move") and was_dashing and animation_manager:
		animation_manager.play_state("move")

# 处理冲刺输入
# 参数 direction: 冲刺方向向量
func _on_dash_input(direction: Vector2) -> void:
	# 记录之前是否在冲刺
	var was_dashing := is_dashing
	# 更新输入方向
	input_direction = direction
	# 设置为冲刺状态
	is_dashing = true
	# 更新角色朝向
	_update_facing(direction)
	if not state_machine:
		return
	# 如果当前是空闲状态，则切换到移动状态（开始冲刺）
	if state_machine.is_current_state("idle"):
		_try_transition("move")
	# 如果当前是移动状态且之前不是冲刺状态，则重新播放移动动画（切换到冲刺动画）
	elif state_machine.is_current_state("move") and not was_dashing and animation_manager:
		animation_manager.play_state("move")

# 更新角色朝向（根据水平方向翻转精灵）
# 参数 direction: 方向向量
func _update_facing(direction: Vector2) -> void:
	if not animation_manager:
		return
	# 如果方向向右，则不翻转
	if direction.x > 0.0:
		animation_manager.set_flip(false)
	# 如果方向向左，则翻转
	elif direction.x < 0.0:
		animation_manager.set_flip(true)

# 状态变化处理函数
# 参数 new_state: 新状态名称
# 参数 _old_state: 旧状态名称（未使用）
func _on_state_changed(new_state: StringName, _old_state: StringName) -> void:
	# 如果新状态是跳跃，则播放跳跃视觉动画
	var state_key := String(new_state.to_lower())
	if state_key == "jump":
		play_visual_animation(jump_motion_anim)
	elif state_key == "action":
		# 主动招式的视觉动画交给具体招式配置控制
		pass
	else:
		# 否则停止视觉动画并重置位置
		stop_visual_animation(true)

# 播放视觉动画
# 参数 anim_name: 动画名称
# 参数 restart: 是否重新开始播放（默认为 true）
func play_visual_animation(anim_name: StringName, restart: bool = true) -> void:
	if not visual_animation_player or not visual_animation_player.has_animation(anim_name):
		# 如果动画播放器不存在或没有该动画，则重置视觉根节点位置
		reset_visual_root()
		return
	# 如果需要重新开始或当前播放的不是该动画，则播放动画
	if restart or visual_animation_player.current_animation != anim_name:
		visual_animation_player.play(anim_name)

# 停止视觉动画
# 参数 reset_position: 是否重置视觉根节点位置（默认为 false）
func stop_visual_animation(reset_position: bool = false) -> void:
	if visual_animation_player and visual_animation_player.is_playing():
		visual_animation_player.stop()
	if reset_position:
		reset_visual_root()

# 重置视觉根节点位置到原始位置
func reset_visual_root() -> void:
	if visual_root:
		visual_root.position = _visual_root_origin

# 物理帧处理函数
# 参数 delta: 物理帧时间间隔
func _physics_process(delta: float) -> void:
	# 更新状态机的物理逻辑
	if state_machine:
		state_machine.physics_update(delta)

	# 在状态更新后尝试消费输入缓冲，便于命中连招窗口
	if _buffered_command != &"":
		_buffered_command_time = max(_buffered_command_time - delta, 0.0)
		if _buffered_command_time <= 0.0:
			clear_buffered_command()
		else:
			try_consume_buffered_command()

	# 执行物理移动（Godot 内置方法）
	move_and_slide()
	# 根据视觉高度更新阴影缩放
	_update_shadow_scale()

# 获取动画持续时间
# 参数 anim_name: 动画名称
# 返回值: 动画持续时间（秒），如果无法获取则返回默认值 0.5
func get_animation_duration(anim_name: String) -> float:
	if animation_manager and animation_manager.animated_sprite and animation_manager.animated_sprite.sprite_frames:
		var frames = animation_manager.animated_sprite.sprite_frames
		if frames.has_animation(anim_name):
			var count = frames.get_frame_count(anim_name)
			var speed = frames.get_animation_speed(anim_name)
			if speed > 0:
				return count / speed
	# 默认返回 0.5 秒
	return 0.5

# 根据视觉根节点与原点的高度差缩放阴影
func _update_shadow_scale() -> void:
	if not shadow:
		return

	var height := 0.0
	if visual_root:
		height = max(0.0, _visual_root_origin.y - visual_root.position.y)

	var ratio: float = clampf(height / maxf(shadow_height_for_min_scale, 0.001), 0.0, 1.0)
	var scale_factor: float = lerpf(1.0, shadow_min_scale_ratio, ratio)
	shadow.scale = _shadow_origin_scale * scale_factor
