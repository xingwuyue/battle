# 冲刺状态
# 只有在地面上按住冲刺键，并且冲刺后的理论速度高于阈值时，才会进入该状态。
class_name DashState
extends State


# 进入冲刺状态时：
# 1. 把行为状态标记为 DASH
# 2. 通过 DashAbility 提供的倍率，把角色移动倍率切到冲刺速度
# 3. 播放冲刺动画
func enter() -> void:
	character.action_state = Core.ActionState.DASH
	if player_controller and player_controller.dash_ability:
		character.set_movement_speed_multiplier(player_controller.dash_ability.get_dash_speed_multiplier())
	else:
		character.set_movement_speed_multiplier(1.0)
	
	# === 新增：播放冲刺动画 ===
	character.play_animation("sprint")


# 退出冲刺状态时必须把移动倍率恢复，
# 否则回到地面或空中后仍会保留冲刺速度。
func exit() -> void:
	character.set_movement_speed_multiplier(1.0)


# 冲刺状态下的切换优先级：
# 1. 若 JumpAbility 成功触发跳跃，则立刻转空中状态
# 2. 若角色已经离地，则直接转空中状态
# 3. 若 DashAbility 判断冲刺条件失效，则回地面状态
func physics_update(_delta: float) -> void:
	# 冲刺攻击入口优先于跳跃。
	# 这样玩家在冲刺过程中按攻击，会优先触发冲刺攻击而不是先跳起。
	if player_controller and player_controller.attack_ability and player_controller.attack_ability.try_prepare_attack_transition(&"dash", 0):
		state_machine.transition_to("AttackState")
		return

	if player_controller and player_controller.jump_ability and player_controller.jump_ability.try_start_jump():
		state_machine.transition_to("AirState")
		return

	if character.is_airborne():
		state_machine.transition_to("AirState")
		return

	if not player_controller or not player_controller.dash_ability or not player_controller.dash_ability.should_keep_dashing():
		state_machine.transition_to("GroundState")
