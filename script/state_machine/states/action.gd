# 通用动作状态类
# 负责驱动主角招式表中的所有主动招式
class_name ActionState
extends State

# 进入动作状态时初始化当前招式
func enter(msg: Dictionary = {}) -> void:
	var character := state_machine.get_parent() as Character
	if not character:
		return
	if not character.enter_action(msg):
		# 如果未能成功进入招式，则回退到空闲状态
		state_machine.transition_to("idle")

# 物理更新时推进招式时间、位移和连招缓冲
func physics_update(delta: float) -> void:
	var character := state_machine.get_parent() as Character
	if not character:
		return

	# 如果缓存输入可以命中新招式，则直接切段
	if character.try_consume_buffered_command():
		return

	# 推进当前招式，结束后回到合适的基础状态
	if character.advance_action(delta):
		if character.is_airborne_context():
			state_machine.transition_to("jump")
		elif character.input_direction != Vector2.ZERO:
			state_machine.transition_to("move")
		else:
			state_machine.transition_to("idle")

# 退出动作状态时清理当前招式运行时数据
func exit() -> void:
	var character := state_machine.get_parent() as Character
	if character:
		character.exit_action()
