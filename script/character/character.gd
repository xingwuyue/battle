# 角色类
# 继承自 CharacterBody2D，是游戏中角色的核心类
# 负责管理角色的状态机、动画、输入响应和物理移动
class_name Character
extends CharacterBody2D

# 角色数据资源，包含角色的属性配置（如移动速度等）
@export var data: CharacterData
# 视觉动画组
@export_group("Visual Motion")
# 跳跃时的视觉动画名称（用于播放视觉效果，如跳跃运动动画）
@export var jump_motion_anim: StringName = &"jump_motion"
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

# 节点就绪时调用（初始化）
func _ready() -> void:
	# 记录视觉根节点的原始位置
	if visual_root:
		_visual_root_origin = visual_root.position
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
		controller.attack_input.connect(func(): _try_act("attack"))
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
	if new_state.to_lower() == "jump":
		play_visual_animation(jump_motion_anim)
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
	# 执行物理移动（Godot 内置方法）
	move_and_slide()

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