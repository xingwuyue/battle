# 招式阶段窗口资源
# 用于描述某个阶段在整段动作中的起止进度
class_name PlayerMovePhaseWindow
extends Resource

# 阶段名称，例如 startup、active、recovery、combo_window
@export var phase_name: StringName = &""
# 阶段开始进度（0 到 1）
@export_range(0.0, 1.0, 0.01) var start_ratio: float = 0.0
# 阶段结束进度（0 到 1）
@export_range(0.0, 1.0, 0.01) var end_ratio: float = 1.0

# 判断给定进度是否命中当前阶段
func contains(progress: float) -> bool:
	return progress >= start_ratio and progress <= end_ratio
