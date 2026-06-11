# 单招式资源。
# 每个攻击招式都用一个独立资源保存自己的动画、伤害、位移和判定数据。
class_name MoveData
extends Resource

# 招式唯一 ID。
# 主要用于调试、资源命名和后续策划识别。
@export var move_id: String = ""

# 招式显示名称。
# 便于在编辑器里直接区分当前资源代表的招式。
@export var move_name: String = ""

# 对应动画名称。
# 攻击状态进入该招时会直接播放这个动画。
@export var animation_name: StringName = &""

# 伤害倍率。
# 最终伤害会基于角色的攻击力乘以这个倍率。
@export var damage_multiplier: float = 1.0

# 体力消耗。
# 每次进入该招时只扣一次。
@export var stamina_cost: float = 0.0

# 招式总帧数。
# 攻击逻辑会按照这个总帧数推进，而不是直接依赖动画回调。
@export var total_frames: int = 1

# 招式帧率。
# 用于把总帧数换算成真实播放时长，避免运行时和编辑器节奏不一致。
# 例如 9 帧 / 15 FPS = 0.6 秒。
@export var fps: float = 15.0

# 前摇帧段。
# 该阶段不允许缓存下一招。
@export var startup_frame_range: Resource

# 伤害帧段。
# 允许多段，适合多段判定或多次挥击。
@export var active_frame_ranges: Array[Resource] = []

# 后摇帧段。
# 该阶段允许角色恢复控制，并可按规则续接下一招。
@export var recovery_frame_range: Resource

# 位移段数组。
# 支持一个招式在多个不同帧段内发生位移。
@export var movement_segments: Array[Resource] = []

# 伤害盒偏移。
# 以角色根节点为参考，默认放在角色身前。
@export var hitbox_offset: Vector2 = Vector2(80.0, -100.0)

# 伤害盒尺寸。
# 初版采用简单矩形盒，因此只需要宽高。
@export var hitbox_size: Vector2 = Vector2(120.0, 100.0)

# 出招期是否允许缓存下一招。
# 这对应“攻击出招时按攻击，先记住下一招，等当前招结束再衔接”。
@export var can_queue_next_in_active: bool = true

# 后摇期是否允许缓存下一招。
# 这是地面连段和冲刺派生最主要的续接窗口。
@export var can_queue_next_in_recovery: bool = true


# 获取安全的总帧数。
# 这里做最小值保护，避免资源误配成 0 帧导致攻击状态无法推进。
func get_safe_total_frames() -> int:
	return max(total_frames, 1)
