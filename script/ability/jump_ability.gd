## 跳跃能力
## 这是玩家专属的主动能力脚本，只负责读取“想跳”的意图，
## 以及在合适时机通过 Character 的公共高度接口触发起跳。
class_name JumpAbility
extends Node

# 跳跃冲量。
# 数值越大，角色起跳时获得的向上初速度越强。
@export var jump_impulse: float = 520.0


# 当前帧是否记录到了跳跃请求。
# 该请求由输入层记录，再由状态层在合适的状态中消费。
var jump_requested: bool = false


# 采集输入。
# 这里只记录一次性跳跃请求，不直接修改角色状态。
func capture_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_requested = true


# 尝试开始跳跃。
# 若成功，会消费本次请求。
# 若当前状态不允许跳跃，直接作废本次请求。
func try_start_jump() -> bool:
	if not jump_requested:
		return false

	# === 新增：查询状态机，判断当前是否“有资格”消耗这个请求 ===
	var sm := _get_state_machine()
	if sm:
		# 只有在地面环境或处于冲刺状态时才允许起跳
		var can_jump = (
			sm.current_environment_state == Core.EnvironmentState.GROUND or
			sm.current_action_state == Core.ActionState.DASH
		)
		
		if not can_jump:
			jump_requested = false # 直接吞掉这个请求，防止落地后误触
			return false
		
	# 再次确认角色物理状态
	var character := _get_character()
	if not character or not character.can_receive_vertical_impulse():
		jump_requested = false # 物理上也不允许，吞掉请求
		return false

	# 消耗请求
	jump_requested = false

	# 施加冲量
	return character.apply_vertical_impulse(jump_impulse)


# 获取角色引用。
# JumpAbility 不直接持有独立角色数据，而是通过父级 PlayerController 找到当前角色。
func _get_character() -> Character:
	var controller := get_parent() as PlayerController
	if not controller:
		return null
	return controller.character


# === 新增：获取状态机引用的方法 ===
func _get_state_machine() -> StateMachine:
	var character := _get_character()
	if not character:
		return null
	return character.state_machine
