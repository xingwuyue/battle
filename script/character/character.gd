# 角色类
# 继承自 CharacterBody2D，是所有角色的基础类
# 负责加载角色数据资源
class_name Character
extends CharacterBody2D

# 角色数据资源
# 在编辑器中配置，用于初始化角色的各项属性
@export var data: CharacterData

# 高度系统重力。
# 这是一个公共基础参数，不只服务跳跃，也可用于被打飞、浮空等高度变化表现。
@export var height_gravity: float = 1200.0

# 输入方向
# 由 PlayerController 设置，用于控制角色移动
var input_direction := Vector2.ZERO

# 当前环境状态。
# 地面/天空状态由高度系统控制。
var environment_state: Core.EnvironmentState = Core.EnvironmentState.GROUND

# 当前行为状态。
# 角色默认处于 IDLE，冲刺时切到 DASH。
var action_state: Core.ActionState = Core.ActionState.IDLE

# 当前高度。
# 角色起跳时只提升 height，不改动 CharacterBody2D 的垂直位置。
var height: float = 0.0

# 高度速度。
# 正值表示上升，负值表示下落。
var vertical_velocity: float = 0.0

# 移动速度倍率，由当前状态写入。
# 这是一个通用速度倍率，不绑定任何具体玩法。
var movement_speed_multiplier: float = 1.0

# === 新增：显式引用状态机 ===
@onready var state_machine = $StateMachine

# === 新增：显式引用动画播放器 ===
@onready var animated_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

# 视觉根节点引用
# 用于翻转角色朝向
@onready var visual_root: Node2D = $VisualRoot

# 初始化函数
# 在场景树节点就绪时调用，负责加载数据
func _ready() -> void:
	# 加载角色数据资源
	_load_character_data()
	_update_visual_height()

# 物理更新函数
# 每个物理帧调用，处理角色移动、动画和朝向
func _physics_process(delta: float) -> void:
	# 更新高度系统，驱动地面/空中状态变化
	_update_height(delta)

	var sm = state_machine
	var can_move := _can_move_by_state(sm)

	# 应用移动
	if can_move:
		velocity = input_direction * get_current_move_speed()
	else:
		velocity = Vector2.ZERO

	# 移动角色
	move_and_slide()

	# 只有在地面、处于 IDLE、且正在移动时才播放 walk 动画
	_update_move_animation(sm)

	# 更新角色朝向
	_update_facing()
	# 更新视觉高度表现
	_update_visual_height()

# 更新角色朝向
# 根据水平移动方向翻转视觉根节点
func _update_facing() -> void:
	if input_direction.x < 0:
		visual_root.scale.x = -1
	elif input_direction.x > 0:
		visual_root.scale.x = 1

# 加载角色数据资源
# 如果未配置数据资源，则创建默认数据
func _load_character_data() -> void:
	if not data:
		# 如果未配置数据资源，则创建默认数据
		data = CharacterData.new()
		push_warning("Character: 未配置 CharacterData 资源，使用默认数据")

# 角色是否处于空中。
func is_airborne() -> bool:
	return environment_state == Core.EnvironmentState.AIR

# 是否可以接收新的垂直冲量。
# 当前先约束为只有地面状态可再次施加起跳类冲量，后续若要做二段跳可在这里扩展。
func can_receive_vertical_impulse() -> bool:
	return environment_state == Core.EnvironmentState.GROUND

# 对角色施加一个向上的垂直冲量。
# 这是一个中性接口，既可用于主动跳跃，也可用于被打飞、弹跳等公共高度系统。
func apply_vertical_impulse(impulse: float) -> bool:
	if not can_receive_vertical_impulse():
		return false
	height = max(height, 0.0)
	vertical_velocity = impulse
	environment_state = Core.EnvironmentState.AIR
	return true

# 获取角色基础移动速度。
# 冲刺、减速、Buff 等效果都应在基础速度外层叠加，而不是直接改 CharacterData。
func get_base_move_speed() -> float:
	return data.move_speed

# 设置角色当前速度倍率。
# 这是一个通用接口，调用方不需要知道倍率如何参与最终速度计算。
func set_movement_speed_multiplier(multiplier: float) -> void:
	movement_speed_multiplier = max(multiplier, 0.0)

# 获取当前移动速度。
func get_current_move_speed() -> float:
	return get_base_move_speed() * movement_speed_multiplier

# 根据当前状态机状态判断角色是否允许发生位移。
# 允许位移的行为状态：IDLE、PICKUP、INTERACTION、TOOL、DASH。
# 攻击状态仅在后摇阶段允许位移。
func _can_move_by_state(sm: StateMachine) -> bool:
	if not sm:
		# 如果状态机还没准备好，默认允许移动，避免初始化阶段角色卡死。
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

# 根据移动条件处理 walk / idle 动画。
# 规则：角色在地面、行为状态为 IDLE，且存在移动输入时，播放 walk。
func _update_move_animation(sm: StateMachine) -> void:
	if not sm:
		return

	if is_airborne():
		return

	if sm.current_action_state != Core.ActionState.IDLE:
		return

	if input_direction != Vector2.ZERO:
		play_animation("walk")
	else:
		play_animation("idle")

# === 新增：播放动画的公共接口 ===
# 只有当前不是这个动画时才播放，避免频繁重置
func play_animation(anim_name: String) -> void:
	if animated_sprite:
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)

# 更新高度系统。
# 当高度回到 0 时，视为回到地面。
# 这个项目当前采用的是“高度变量 + 视觉位移”的方案：
# 角色真实碰撞体仍在地面平面移动，跳跃表现通过 VisualRoot 上抬完成。
func _update_height(delta: float) -> void:
	if height <= 0.0 and vertical_velocity <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		environment_state = Core.EnvironmentState.GROUND
		return

	vertical_velocity -= height_gravity * delta
	height = max(height + vertical_velocity * delta, 0.0)

	if height <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		environment_state = Core.EnvironmentState.GROUND
	else:
		environment_state = Core.EnvironmentState.AIR

# 更新视觉高度。
# 通过抬高视觉根节点表现跳跃，不改动实际碰撞位置。
func _update_visual_height() -> void:
	visual_root.position.y = -height
