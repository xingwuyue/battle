# 状态机核心类
# 负责管理角色的所有状态，协调状态之间的切换
# 继承自 Node，作为角色场景树中的一个节点
class_name StateMachine
extends Node

# 当前活跃的状态引用
# 状态机同一时间只能有一个活跃状态，所有更新和输入都由当前状态处理
var current_state

# 所有状态的字典
# 键为状态名称（字符串），值为状态对象引用
# 用于快速查找和切换状态
var states: Dictionary = {}

# 状态切换历史记录
# 用于调试目的，记录最近10次状态切换的名称
# 可以帮助开发者追踪角色的状态变化轨迹
var state_history: Array[String] = []

# === 新增：三层状态查询变量 ===
# 1. 环境状态 (地面/空中)
var current_environment_state: Core.EnvironmentState = Core.EnvironmentState.GROUND
# 2. 行为大类状态 (待机/攻击/受击...)
var current_action_state: Core.ActionState = Core.ActionState.IDLE
# 3. 攻击子状态 (抬手/出招/收招)
var current_sub_attack_state = null

# 初始化函数
# 在场景树节点就绪时调用，负责：
# 1. 收集所有子节点中的状态对象
# 2. 建立状态字典
# 3. 设置初始状态
func _ready() -> void:
	# 遍历所有子节点，收集状态对象
	for child in get_children():
		# 检查子节点是否为 State 类型
		if child is State:
			# 将状态添加到字典，以节点名称为键
			states[child.name] = child
			# 设置状态的状态机引用，让状态可以调用 transition_to()
			child.state_machine = self
			# 设置状态的角色引用，让状态可以访问角色属性和方法
			child.character = get_parent()
			# 设置玩家控制器引用，让玩家角色状态可访问主动能力脚本
			child.player_controller = get_parent().get_node_or_null("PlayerController")
	
	# 设置初始状态为 GroundState
	# 如果存在名为 "GroundState" 的状态，则将其设为当前状态并进入
	if states.has("GroundState"):
		current_state = states["GroundState"]
		# 调用状态的进入方法，执行初始化逻辑
		current_state.enter()
	elif states.has("Idle"):
		current_state = states["Idle"]
		# 调用状态的进入方法，执行初始化逻辑
		current_state.enter()

# 物理帧更新函数
# 每个物理帧调用一次（默认60次/秒）
# 用于处理物理相关的状态逻辑，如移动、碰撞检测等
func _physics_process(delta: float) -> void:
	# 如果当前状态存在，则调用其物理更新方法
	if current_state:
		current_state.physics_update(delta)

# 渲染帧更新函数
# 每个渲染帧调用一次（帧率不固定）
# 用于处理视觉相关的状态逻辑，如动画、特效等
func _process(delta: float) -> void:
	# 如果当前状态存在，则调用其更新方法
	if current_state:
		current_state.update(delta)

# 输入事件处理函数
# 处理未被其他节点消费的输入事件
# 用于状态内部的输入响应，如按键触发攻击、跳跃等
func _unhandled_input(event: InputEvent) -> void:
	# 如果当前状态存在，则将输入事件传递给当前状态处理
	if current_state:
		current_state.handle_input(event)

# 状态切换方法
# 将当前状态切换到指定名称的新状态
# 新状态名称: 要切换到的状态名称（必须与节点名称一致）
func transition_to(new_state_name: String) -> void:
	# 检查目标状态是否存在
	if not states.has(new_state_name):
		push_warning("StateMachine: 状态 '%s' 不存在" % new_state_name)
		return
	
	# 获取目标状态对象
	var new_state = states[new_state_name]
	
	# 检查当前状态是否允许切换到目标状态
	# 每个状态都可以定义自己的切换规则（如攻击动画播放中不能切换到其他状态）
	if current_state and not current_state.can_transition_to(new_state_name):
		return
	
	# 退出当前状态
	# 执行当前状态的清理逻辑（如停止动画、重置变量等）
	if current_state:
		current_state.exit()
	
	# 更新当前状态引用
	current_state = new_state
	
	# === 新增：同步更新三层状态 ===
	# 1. 更新环境状态 (读取角色当前的物理环境)
	current_environment_state = current_state.character.environment_state
	# 2. 更新行为状态 (根据状态名映射)
	_update_action_state_mapping(new_state_name)
	# 3. 除非是攻击状态，否则重置攻击子状态
	if new_state_name != "AttackState":
		current_sub_attack_state = null

	# 进入新状态
	# 执行新状态的初始化逻辑（如播放动画、设置属性等）
	current_state.enter()
	
	# 记录状态切换历史
	state_history.append(new_state_name)
	# 保持历史记录不超过10条，避免内存占用过大
	if state_history.size() > 10:
		state_history.pop_front()

# === 新增：供 AttackState 调用的更新方法 ===
func update_sub_attack_state(phase) -> void:
	current_sub_attack_state = phase

# === 新增：映射状态名到枚举 ===
func _update_action_state_mapping(state_name: String) -> void:
	match state_name:
		"GroundState", "AirState": 
			current_action_state = Core.ActionState.IDLE
		"AttackState": 
			current_action_state = Core.ActionState.ATTACK
		"DefendState": 
			current_action_state = Core.ActionState.DEFEND
		"HitState": 
			current_action_state = Core.ActionState.HIT
		"DashState": 
			current_action_state = Core.ActionState.DASH
		"DieState": 
			current_action_state = Core.ActionState.DIE
		_: 
			current_action_state = Core.ActionState.IDLE
