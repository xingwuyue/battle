# 帧区间资源。
# 用于描述一个攻击阶段或伤害窗的起止帧范围。
class_name FrameRangeData
extends Resource

# 起始帧。
# 采用闭区间定义，表示该帧本身会参与判定。
@export var start_frame: int = 0

# 结束帧。
# 采用闭区间定义，表示该帧本身会参与判定。
@export var end_frame: int = 0


# 判断给定帧是否落在当前区间内。
# 这里统一采用“起始帧 <= 当前帧 <= 结束帧”的闭区间规则。
func contains(frame: int) -> bool:
	return frame >= start_frame and frame <= end_frame


# 获取当前区间的总帧数。
# 这里会额外做最小值保护，避免出现 0 帧或负数帧导致后续除法出错。
func get_frame_count() -> int:
	return max(end_frame - start_frame + 1, 1)
