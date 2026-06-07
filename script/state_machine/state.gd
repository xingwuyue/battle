# 状态基类
# 继承自 Node，是所有具体状态的基类
# 定义了状态的基本接口方法，子类可以重写这些方法来实现具体行为
class_name State
extends Node

# 状态机引用（由状态机在初始化时设置）
var state_machine: StateMachine = null

# 进入状态时调用（子类重写此方法以实现具体行为）
# 参数 _msg: 可选的消息字典，用于传递额外信息
func enter(_msg: Dictionary = {}) -> void:
	pass

# 退出状态时调用（子类重写此方法以实现清理逻辑）
func exit() -> void:
	pass

# 每帧更新函数（子类重写此方法以实现每帧逻辑）
# 参数 _delta: 帧时间间隔
func update(_delta: float) -> void:
	pass

# 物理更新函数（子类重写此方法以实现物理帧逻辑）
# 参数 _delta: 物理帧时间间隔
func physics_update(_delta: float) -> void:
	pass