# 全局核心类
# 定义游戏中使用的枚举常量，供所有系统引用
class_name Core
extends Node

# 环境状态枚举
# 定义角色所处的物理环境，影响可用的行为状态
enum EnvironmentState {
	GROUND,  # 地面状态
	AIR      # 空中状态
}

# 行为状态枚举
# 定义角色可以执行的行为动作
# 地面可执行：IDLE、ATTACK、DEFEND、HIT、PICKUP、INTERACTION、TOOL、DASH、DIE
# 空中可执行：IDLE、ATTACK、HIT、DIE
enum ActionState {
	IDLE,         # 空闲状态
	ATTACK,       # 攻击状态
	DEFEND,       # 防御状态
	HIT,          # 受击状态
	PICKUP,       # 拾取状态
	INTERACTION,  # 交互状态
	TOOL,         # 使用道具状态
	DASH,         # 冲刺状态
	DIE           # 死亡状态
}

# 攻击子状态枚举
# 定义攻击动作的内部阶段，用于管理攻击动画和判定时机
enum AttackPhase {
	STARTUP,   # 抬手阶段（前摇）
	ACTIVE,    # 出招阶段（生效期）
	RECOVERY   # 后摇阶段（收招）
}
