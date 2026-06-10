# 玩家控制器
# 负责处理玩家输入，更新角色的移动方向和其他状态
class_name PlayerController
extends Node

# 角色引用
# 缓存父节点角色节点的引用，避免每帧获取。
var character

# 跳跃能力引用
# 负责处理玩家主动跳跃输入与起跳触发。
@onready var jump_ability: JumpAbility = $JumpAbility

# 冲刺能力引用
# 负责处理玩家主动冲刺输入与冲刺判定。
@onready var dash_ability: DashAbility = $DashAbility

# 初始化函数
# 在场景树节点就绪时调用，获取角色引用
func _ready() -> void:
	# 获取父节点作为角色引用
	character = get_parent()
	if not character:
		push_error("PlayerController: 未找到父级角色节点")
	else:
		print("PlayerController: 成功获取角色引用")
		
		# === 新增：能力就绪后，通知当前状态重新应用效果 ===
		# 解决 StateMachine._ready 先于 PlayerController._ready 导致的能力脚本空引用问题
		if character.state_machine and character.state_machine.current_state:
			character.state_machine.current_state.enter()

# 物理更新函数
# 每个物理帧调用，处理玩家输入并更新角色状态
func _physics_process(_delta: float) -> void:
	if not character:
		return
	
	# 处理移动输入
	_handle_movement_input()
	# 处理跳跃和冲刺输入
	_update_abilities_input()

# 处理移动输入
# 读取 WASD 和方向键输入，更新角色的 input_direction
func _handle_movement_input() -> void:
	# 初始化输入方向
	var direction := Vector2.ZERO
	
	# 处理左右输入（A/D 或 左/右方向键）
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	
	# 处理上下输入（W/S 或 上/下方向键）
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	
	# 归一化方向向量，确保对角线移动速度不会更快
	if direction != Vector2.ZERO:
		direction = direction.normalized()
	
	# 更新角色的输入方向
	character.input_direction = direction

# 更新能力输入。
# PlayerController 只负责读取输入，再把输入分发给各个玩家专属能力脚本。
func _update_abilities_input() -> void:
	if jump_ability:
		jump_ability.capture_input()

	if dash_ability:
		dash_ability.capture_input()
