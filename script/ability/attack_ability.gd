## 攻击能力
## 这是玩家专属的主动能力脚本，只负责记录攻击输入，
## 并把“这次攻击打算从哪个入口状态发起”交给状态层消费。
class_name AttackAbility
extends Node

# 当前帧是否记录到了攻击请求。
# 该请求和跳跃请求一样，会先被能力层缓存，再由状态层在合适的时机消费。
var attack_requested: bool = false

# 待进入攻击状态时使用的攻击入口类型。
# 例如：ground / dash / air。
var pending_attack_variant: StringName = &""

# 待进入攻击状态时使用的地面连段索引。
# 仅在地面普攻链中生效，0 代表第一段。
var pending_combo_index: int = 0


# 采集输入。
# 攻击只记录“按下瞬间”，避免长按攻击键时不停重复触发。
func capture_input() -> void:
	if Input.is_action_just_pressed("attack"):
		attack_requested = true


# 当前是否存在还未被消费的攻击请求。
func has_attack_request() -> bool:
	return attack_requested


# 消费一次攻击按下请求。
# 这个接口主要给 AttackState 在连段窗口内读取输入时使用。
func consume_attack_request() -> bool:
	if not attack_requested:
		return false

	attack_requested = false
	return true


# 尝试准备一次“进入攻击状态”的请求。
# 这里不仅要检查是否按下了攻击键，还要验证当前是否满足进入攻击状态的条件。
func try_prepare_attack_transition(variant: StringName, combo_index: int = 0) -> bool:
	if not attack_requested:
		return false

	var state_machine := _get_state_machine()
	if not state_machine:
		# 状态机都不存在时，说明当前角色结构尚未就绪。
		# 这里直接吞掉输入，避免后面残留旧请求。
		attack_requested = false
		return false

	if not _can_enter_attack(state_machine):
		# 攻击不允许跨帧保留到未来的任意状态，因此这里直接吞掉。
		attack_requested = false
		return false

	var character := _get_character()
	if not character:
		attack_requested = false
		return false

	var move: Resource = character.get_attack_move(variant, combo_index)
	if not move:
		attack_requested = false
		return false

	if not character.can_consume_stamina(move.stamina_cost):
		attack_requested = false
		return false

	pending_attack_variant = variant
	pending_combo_index = combo_index
	attack_requested = false
	return true


# 消费一次“进入攻击状态”的上下文。
# GroundState / DashState / AirState 在切入 AttackState 前先写入这里，
# 然后由 AttackState.enter() 读取并清空。
func consume_pending_transition_context() -> Dictionary:
	var result := {
		"variant": pending_attack_variant,
		"combo_index": pending_combo_index
	}

	pending_attack_variant = &""
	pending_combo_index = 0
	return result


# 判断当前状态是否允许进入攻击。
# 这里严格对应设计文档里约定的三个条件：
# 1. 入口状态允许地面、冲刺、空中
# 2. 行为状态允许 idle / attack / pickup / dash
# 3. 若当前已经处于攻击状态，则必须位于后摇阶段
func _can_enter_attack(state_machine: StateMachine) -> bool:
	var is_allowed_environment := (
		state_machine.current_environment_state == Core.EnvironmentState.GROUND or
		state_machine.current_environment_state == Core.EnvironmentState.AIR
	)

	var is_allowed_action := (
		state_machine.current_action_state == Core.ActionState.IDLE or
		state_machine.current_action_state == Core.ActionState.ATTACK or
		state_machine.current_action_state == Core.ActionState.PICKUP or
		state_machine.current_action_state == Core.ActionState.DASH
	)

	var is_attack_recovery: bool = (
		state_machine.current_action_state == Core.ActionState.ATTACK and
		state_machine.current_sub_attack_state == Core.AttackPhase.RECOVERY
	)

	# 冲刺状态是一个特殊入口。
	# 它虽然仍处于地面环境，但语义上要被视为“允许进入攻击”的独立状态。
	var is_dash_state := state_machine.current_action_state == Core.ActionState.DASH

	if not is_allowed_action:
		return false

	if not (is_allowed_environment or is_dash_state):
		return false

	if state_machine.current_action_state == Core.ActionState.ATTACK and not is_attack_recovery:
		return false

	return true


# 获取角色引用。
# AttackAbility 与 JumpAbility / DashAbility 保持一致，都通过 PlayerController 间接访问角色。
func _get_character() -> Character:
	var controller := get_parent() as PlayerController
	if not controller:
		return null
	return controller.character


# 获取状态机引用。
func _get_state_machine() -> StateMachine:
	var character := _get_character()
	if not character:
		return null
	return character.state_machine
