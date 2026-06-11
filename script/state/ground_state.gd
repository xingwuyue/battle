# 地面状态
# 负责处理角色站立、普通移动，以及从地面进入跳跃/冲刺的状态切换。
class_name GroundState
extends State


# 进入地面状态时：
# 1. 强制把环境状态标记为地面
# 2. 把行为状态恢复为普通待机
# 3. 把移动倍率恢复为基础速度
func enter() -> void:
	character.environment_state = Core.EnvironmentState.GROUND
	character.action_state = Core.ActionState.IDLE
	character.set_movement_speed_multiplier(1.0)


# 地面状态的每帧物理逻辑主要负责“判定是否离开地面状态”。
# 处理顺序是：
# 1. 先询问 JumpAbility 是否成功触发起跳，若成功则立刻切到空中状态
# 2. 再询问 DashAbility 是否满足冲刺条件，满足则切到冲刺状态
# 3. 最后做兜底判断，若角色已经离地，也切到空中状态
func physics_update(_delta: float) -> void:
	if player_controller and player_controller.jump_ability and player_controller.jump_ability.try_start_jump():
		state_machine.transition_to("AirState")
		return

	if player_controller and player_controller.dash_ability and player_controller.dash_ability.can_start_dash():
		state_machine.transition_to("DashState")
		return

	# 地面攻击入口。
	# 这里在普通地面状态下消费一次攻击请求，并把入口类型标记为 ground，
	# 供 AttackState.enter() 决定当前应当起手哪一招。
	if player_controller and player_controller.attack_ability and player_controller.attack_ability.try_prepare_attack_transition(&"ground", 0):
		state_machine.transition_to("AttackState")
		return

	if character.is_airborne():
		state_machine.transition_to("AirState")
