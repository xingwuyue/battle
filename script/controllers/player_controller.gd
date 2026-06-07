# 玩家控制器类
# 继承自 Node，负责处理玩家输入并发出相应的信号
# 需要在项目设置 -> 输入映射中配置以下动作：move_left, move_right, move_up, move_down, dash, jump, attack, defend, pickup, interact, tool
class_name PlayerController
extends Node

# 移动输入信号，当玩家按下移动键时发出，参数为移动方向向量
signal move_input(direction: Vector2)
# 冲刺输入信号，当玩家同时按下移动键和冲刺键时发出，参数为冲刺方向向量
signal dash_input(direction: Vector2)
# 跳跃输入信号，当玩家按下跳跃键时发出
signal jump_input
# 攻击输入信号，当玩家按下攻击键时发出
signal attack_input
# 防御输入信号，当玩家按下防御键时发出
signal defend_input
# 拾取输入信号，当玩家按下拾取键时发出
signal pickup_input
# 交互输入信号，当玩家按下交互键时发出
signal interact_input
# 工具输入信号，当玩家按下工具键时发出
signal tool_input

# 每帧处理输入（使用 _process 而非 _input 以确保每帧检测）
# 参数 _delta: 帧时间间隔（当前未使用）
func _process(_delta: float) -> void:
	# 获取移动方向向量（基于输入映射中的移动键）
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 如果有移动输入且同时按下冲刺键，则发出冲刺信号
	if dir != Vector2.ZERO and Input.is_action_pressed("dash"):
		dash_input.emit(dir)
	else:
		# 否则发出移动信号
		move_input.emit(dir)

	# 检测跳跃输入（刚按下时触发）
	if Input.is_action_just_pressed("jump"):
		jump_input.emit()
	# 检测攻击输入
	if Input.is_action_just_pressed("attack"):
		attack_input.emit()
	# 检测防御输入
	if Input.is_action_just_pressed("defend"):
		defend_input.emit()
	# 检测拾取输入
	if Input.is_action_just_pressed("pickup"):
		pickup_input.emit()
	# 检测交互输入
	if Input.is_action_just_pressed("interact"):
		interact_input.emit()
	# 检测工具输入
	if Input.is_action_just_pressed("tool"):
		tool_input.emit()
