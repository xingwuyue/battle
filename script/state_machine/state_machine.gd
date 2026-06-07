# 状态机类
# 继承自 Node，负责管理角色的状态切换和更新
# 通过状态字典存储所有状态，并处理状态之间的转换逻辑
class_name StateMachine
extends Node

# 状态变化信号，当状态发生变化时发出
# 参数 new_state_name: 新状态名称
# 参数 old_state_name: 旧状态名称
signal state_changed(new_state_name: StringName, old_state_name: StringName)

# 初始状态（在编辑器中设置）
@export var initial_state: State

# 当前状态引用
var current_state: State
# 状态字典，存储所有状态（键为状态名称小写，值为状态节点）
var _states: Dictionary = {}

# 节点就绪时调用（初始化状态机）
func _ready() -> void:
	# 遍历所有子节点，将状态节点添加到状态字典中
	for child in get_children():
		if child is State:
			# 将状态名称转换为小写作为键
			_states[child.name.to_lower()] = child
			# 设置状态的状态机引用
			child.state_machine = self
	# 如果设置了初始状态，则切换到初始状态
	if initial_state:
		transition_to(initial_state.name)

# 转换到指定状态
# 参数 state_name: 要转换到的状态名称
# 参数 msg: 可选的消息字典，用于传递额外信息
func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	# 检查是否允许转换到目标状态
	if not _can_transition_to(state_name):
		return
	# 从状态字典中获取目标状态
	var new_state = _states.get(state_name.to_lower())
	if not new_state:
		push_warning("State not found: " + state_name)
		return

	# 记录旧状态名称
	var old_name := current_state.name if current_state else &""
	# 如果有当前状态，则调用其退出方法
	if current_state:
		current_state.exit()

	# 设置新的当前状态
	current_state = new_state
	# 调用新状态的进入方法
	current_state.enter(msg)
	# 发出状态变化信号
	state_changed.emit(current_state.name, old_name)

# 检查是否允许转换到指定状态
# 参数 state_name: 要转换到的状态名称
# 返回值: 是否允许转换
func _can_transition_to(state_name: StringName) -> bool:
	# 将状态名称转换为小写
	var to := state_name.to_lower()
	# 总是允许转换到死亡状态
	if to == "die":
		return true
	# 如果当前状态是死亡状态，则不允许转换到其他状态
	if current_state and current_state.name.to_lower() == "die":
		return false
	# 其他情况允许转换
	return true

# 检查当前状态是否是指定状态
# 参数 state_name: 要检查的状态名称
# 返回值: 当前状态是否是指定状态
func is_current_state(state_name: StringName) -> bool:
	if not current_state:
		return false
	return current_state.name.to_lower() == state_name.to_lower()

# 每帧更新函数
# 参数 delta: 帧时间间隔
func _process(delta: float) -> void:
	# 如果有当前状态，则调用其更新方法
	if current_state:
		current_state.update(delta)

# 物理更新函数（由角色类调用）
# 参数 delta: 物理帧时间间隔
func physics_update(delta: float) -> void:
	# 如果有当前状态，则调用其物理更新方法
	if current_state:
		current_state.physics_update(delta)