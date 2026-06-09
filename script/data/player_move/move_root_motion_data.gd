# 招式位移资源
# 用关键时间点和累计位移点描述整段动作的程序位移
class_name MoveRootMotionData
extends Resource

# 是否根据角色朝向镜像水平位移
@export var apply_facing: bool = true
# 位移曲线关键时间点（0 到 1）
@export var time_points: PackedFloat32Array = PackedFloat32Array([0.0, 1.0])
# 每个关键时间点对应的累计位移
@export var position_points: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

# 按归一化进度采样累计位移
func sample(progress: float) -> Vector2:
	# 如果配置不完整，则返回零位移
	if time_points.size() == 0 or time_points.size() != position_points.size():
		return Vector2.ZERO

	# 进度在首尾之外时直接钳制到边界
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if clamped_progress <= time_points[0]:
		return position_points[0]
	if clamped_progress >= time_points[time_points.size() - 1]:
		return position_points[position_points.size() - 1]

	# 在线性区间中插值当前累计位移
	for index in range(time_points.size() - 1):
		var from_time: float = time_points[index]
		var to_time: float = time_points[index + 1]
		if clamped_progress >= from_time and clamped_progress <= to_time:
			var segment_ratio: float = inverse_lerp(from_time, to_time, clamped_progress)
			return position_points[index].lerp(position_points[index + 1], segment_ratio)

	return position_points[position_points.size() - 1]
