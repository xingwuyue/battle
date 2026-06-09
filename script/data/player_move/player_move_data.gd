# 单个招式资源
# 用于描述招式的触发条件、动画、位移和阶段窗口
class_name PlayerMoveData
extends Resource

# 预加载关联资源脚本，避免类型分析器无法解析新类
const MoveRootMotionData = preload("res://script/data/player_move/move_root_motion_data.gd")
const PlayerMovePhaseWindow = preload("res://script/data/player_move/player_move_phase_window.gd")

# 招式基础信息
@export_group("Identity")
# 招式唯一 ID
@export var move_id: StringName = &""
# 编辑器展示名称
@export var display_name: String = ""
# 触发该招式的逻辑输入命令
@export var input_command: StringName = &"light_attack"
# 规则匹配优先级，数值越高越优先
@export var priority: int = 0

# 动画和时长配置
@export_group("Animation")
# 角色帧动画名称
@export var animation_name: StringName = &""
# 视觉运动动画名称，可为空
@export var motion_animation_name: StringName = &""
# 自定义动作时长，<= 0 时回退到帧动画时长
@export var duration_override: float = 0.0

# 触发条件
@export_group("Conditions")
# 需要满足的状态标签
@export var required_state_tags: PackedStringArray = PackedStringArray()
# 不允许出现的状态标签
@export var blocked_state_tags: PackedStringArray = PackedStringArray()
# 必须从哪个前置招式接入
@export var required_prev_move_id: StringName = &""
# 必须命中的前置阶段
@export var required_phase: StringName = &""

# 运行时与行为配置
@export_group("Runtime")
# 命中后是否消耗缓冲输入
@export var consume_input_buffer: bool = true
# 是否启用程序驱动位移
@export var root_motion_enabled: bool = false
# 位移资源
@export var root_motion_curve: MoveRootMotionData
# 招式阶段窗口
@export var phase_windows: Array[PlayerMovePhaseWindow] = []
# 允许衔接的后续招式 ID
@export var combo_links: PackedStringArray = PackedStringArray()
# 当前招式标签
@export var tags: PackedStringArray = PackedStringArray()

# 获取当前招式实际持续时间
func get_duration(default_duration: float) -> float:
	if duration_override > 0.0:
		return duration_override
	return default_duration

# 根据归一化进度获取当前所处阶段
func get_phase_at_progress(progress: float) -> StringName:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	for window in phase_windows:
		if window and window.contains(clamped_progress):
			return window.phase_name
	return &""

# 判断当前招式是否带某个标签
func has_tag(tag_name: StringName) -> bool:
	return tags.has(String(tag_name))
