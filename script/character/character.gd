# 角色类
# 继承自 CharacterBody2D，是所有角色的基础类
# 负责加载角色数据资源
class_name Character
extends CharacterBody2D

# 角色数据资源
# 在编辑器中配置，用于初始化角色的各项属性
@export var data: CharacterData

# 输入方向
# 由 PlayerController 设置，用于控制角色移动
var input_direction := Vector2.ZERO

# 视觉根节点引用
# 用于翻转角色朝向
@onready var visual_root: Node2D = $VisualRoot

# 初始化函数
# 在场景树节点就绪时调用，负责加载数据
func _ready() -> void:
	# 加载角色数据资源
	_load_character_data()

# 物理更新函数
# 每个物理帧调用，处理角色移动和朝向
func _physics_process(_delta: float) -> void:
	# 根据输入方向和移动速度更新速度
	velocity = input_direction * data.move_speed
	# 移动角色
	move_and_slide()
	# 更新角色朝向
	_update_facing()

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