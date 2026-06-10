# 空中状态
# 该状态表示角色已经成功起跳，当前处于“高度大于 0”的阶段。
class_name AirState
extends "res://script/state/state.gd"


# 进入空中状态时：
# 1. 把环境状态标记为空中
# 2. 把行为状态恢复为普通待机，避免残留地面冲刺标记
# 3. 把移动倍率恢复成普通速度
# 4. 播放跳跃动画
func enter() -> void:
	character.environment_state = Core.EnvironmentState.AIR
	character.action_state = Core.ActionState.IDLE
	character.set_movement_speed_multiplier(1.0)
	
	# === 新增：播放跳跃动画 ===
	character.play_animation("jump")


# 空中状态当前只关心一件事：是否已经回到地面。
# 当高度系统判定角色不再处于空中时，立即回到地面状态。
func physics_update(_delta: float) -> void:
	if not character.is_airborne():
		state_machine.transition_to("GroundState")
