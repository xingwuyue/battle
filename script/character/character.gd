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
# 地面/天空状态由移动组件驱动。
var environment_state: Core.EnvironmentState = Core.EnvironmentState.GROUND

# 当前行为状态。
# 角色默认处于 IDLE，冲刺时切到 DASH。
var action_state: Core.ActionState = Core.ActionState.IDLE

# === 新增：显式引用状态机 ===
@onready var state_machine = $StateMachine

# 移动组件引用
# 负责承接平面移动、高度系统和朝向更新。
@onready var movement_component: MovementComponent = $MovementComponent

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
	
	# 初始化移动组件，并同步初始视觉高度。
	if movement_component:
		movement_component.setup(self)
	else:
		push_error("Character: 未找到 MovementComponent 节点")

# 物理更新函数
# 每个物理帧调用，转发给移动组件处理位移与高度系统。
func _physics_process(delta: float) -> void:
	if movement_component:
		movement_component.physics_update(delta)

# 加载角色数据资源
# 如果未配置数据资源，则创建默认数据
func _load_character_data() -> void:
	if not data:
		# 如果未配置数据资源，则创建默认数据
		data = CharacterData.new()
		push_warning("Character: 未配置 CharacterData 资源，使用默认数据")

# 角色是否处于空中。
func is_airborne() -> bool:
	if not movement_component:
		return environment_state == Core.EnvironmentState.AIR
	return movement_component.is_airborne()

# 是否可以接收新的垂直冲量。
# 当前先约束为只有地面状态可再次施加起跳类冲量，后续若要做二段跳可在这里扩展。
func can_receive_vertical_impulse() -> bool:
	if not movement_component:
		return environment_state == Core.EnvironmentState.GROUND
	return movement_component.can_receive_vertical_impulse()

# 对角色施加一个向上的垂直冲量。
# 这是一个中性接口，既可用于主动跳跃，也可用于被打飞、弹跳等公共高度系统。
func apply_vertical_impulse(impulse: float) -> bool:
	if not movement_component:
		return false
	return movement_component.apply_vertical_impulse(impulse)

# 获取角色基础移动速度。
# 冲刺、减速、Buff 等效果都应在基础速度外层叠加，而不是直接改 CharacterData。
func get_base_move_speed() -> float:
	return data.move_speed

# 设置角色当前速度倍率。
# 这是一个通用接口，调用方不需要知道倍率如何参与最终速度计算。
func set_movement_speed_multiplier(multiplier: float) -> void:
	if movement_component:
		movement_component.set_movement_speed_multiplier(multiplier)

# 获取当前移动速度。
func get_current_move_speed() -> float:
	if not movement_component:
		return get_base_move_speed()
	return movement_component.get_current_move_speed()

# === 新增：播放动画的公共接口 ===
# 只有当前不是这个动画时才播放，避免频繁重置
func play_animation(anim_name: String) -> void:
	if animated_sprite:
		if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)
