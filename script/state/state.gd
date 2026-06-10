# state.gd
class_name State
extends Node

# 状态所属的角色引用
var character

# 状态机引用
var state_machine

# 玩家控制器引用
# 对于玩家角色状态，可通过该引用访问 JumpAbility、DashAbility 等玩家专属能力。
var player_controller

# 进入状态时调用
func enter() -> void:
	pass

# 退出状态时调用
func exit() -> void:
	pass

# 每帧更新
func update(_delta: float) -> void:
	pass

# 物理帧更新
func physics_update(_delta: float) -> void:
	pass

# 处理输入
func handle_input(_event: InputEvent) -> void:
	pass

# 检查是否可以切换到目标状态
func can_transition_to(_state_name: String) -> bool:
	return true
