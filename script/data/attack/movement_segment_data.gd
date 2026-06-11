# 攻击位移段资源。
# 用于描述一段攻击期间的位移生效时间和总位移距离。
class_name MovementSegmentData
extends Resource

# 位移开始帧。
# 当攻击推进到这个帧时，开始按帧分摊位移。
@export var start_frame: int = 0

# 位移结束帧。
# 采用闭区间定义，结束帧本身也会产生位移。
@export var end_frame: int = 0

# 该位移段的总位移距离。
# 正数表示朝角色面向方向推进，负数可用于后撤类动作。
@export var distance: float = 0.0


# 判断当前帧是否位于本段位移区间内。
func contains(frame: int) -> bool:
	return frame >= start_frame and frame <= end_frame


# 获取当前位移段总帧数。
# 这里做最小值保护，避免后续做“总位移 / 总帧数”时出现除零问题。
func get_frame_count() -> int:
	return max(end_frame - start_frame + 1, 1)


# 获取当前位移段的单帧位移。
# 攻击状态会在每个命中本段的物理帧里调用这个值，从而做平滑推进。
func get_distance_per_frame() -> float:
	return distance / float(get_frame_count())
