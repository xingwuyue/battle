## 冲刺能力
## 这是玩家专属的主动能力脚本，只负责记录冲刺输入和判断是否满足冲刺进入条件。
class_name DashAbility
extends Node

# 冲刺速度阈值。
# 只有冲刺后的理论速度高于该阈值时，才允许进入冲刺状态。
@export var dash_speed_threshold: float = 220.0

# 冲刺速度倍率。
# 冲刺状态会在角色基础移动速度上叠加该倍率。
@export var dash_speed_multiplier: float = 1.6

# 当前是否按住冲刺键。
# 这是一个持续态输入，不是一次性触发。
var dash_pressed: bool = false


# 采集输入。
# 冲刺键按住期间持续为 true，松开后恢复为 false。
func capture_input() -> void:
	dash_pressed = Input.is_action_pressed("dash")


# 当前是否满足进入冲刺状态的条件。
# 该能力只关心玩家意图与门槛判定，不直接切换状态。
func can_start_dash() -> bool:
	var character := _get_character()
	if not character:
		return false

	# === 新增：通过 Character 访问状态机，做更精准的判断 ===
	var sm := _get_state_machine()
	if sm:
		# 1. 必须处于地面环境
		if sm.current_environment_state != Core.EnvironmentState.GROUND:
			return false
			
		# 2. 行为状态限制：只允许在 待机(IDLE)、拾取(PICKUP) 时进入
		# 3. 或者：处于攻击(ATTACK)状态且当前子阶段为后摇(RECOVERY)时，允许取消后摇进入冲刺
		var is_allowed_action = (
			sm.current_action_state == Core.ActionState.IDLE or
			sm.current_action_state == Core.ActionState.PICKUP
		)
		
		var is_attack_recovery = (
			sm.current_action_state == Core.ActionState.ATTACK and 
			sm.current_sub_attack_state == Core.AttackPhase.RECOVERY
		)
		
		if not (is_allowed_action or is_attack_recovery):
			return false

	if not dash_pressed:
		return false

	if character.input_direction == Vector2.ZERO:
		return false

	return get_dash_speed() > dash_speed_threshold


# 当前是否应当继续维持冲刺。
# 逻辑修正：一旦进入冲刺，不再要求必须处于 IDLE 状态，
# 只要没被强制打断且仍按住冲刺键，就维持。
func should_keep_dashing() -> bool:
	var character := _get_character()
	if not character:
		return false
	
	# 只要松开 Shift，立刻退出
	if not dash_pressed:
		return false
	
	# 如果被打断（受击、死亡），退出
	var sm := _get_state_machine()
	if sm:
		if sm.current_action_state == Core.ActionState.HIT or sm.current_action_state == Core.ActionState.DIE:
			return false
	
	return true


# 获取冲刺速度倍率。
func get_dash_speed_multiplier() -> float:
	return dash_speed_multiplier


# 获取冲刺后的理论速度。
# 用于状态切换前的门槛判断，不依赖 Character 当前帧已结算的 velocity。
func get_dash_speed() -> float:
	var character := _get_character()
	if not character:
		return 0.0
	return character.get_base_move_speed() * dash_speed_multiplier


# 获取角色引用。
# DashAbility 不直接保存角色，而是通过父级 PlayerController 间接访问。
func _get_character() -> Character:
	var controller := get_parent() as PlayerController
	if not controller:
		return null
	return controller.character


# 获取状态机引用的方法。
func _get_state_machine() -> StateMachine:
	var character := _get_character()
	if not character:
		return null
	return character.state_machine
