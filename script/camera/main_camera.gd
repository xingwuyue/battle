# 主相机控制器
# 跟随目标角色移动，并使用插值实现平滑滞后效果。
class_name MainCamera
extends Camera2D

# 跟随目标的引用。
# 在 _ready() 中自动寻找场景中的 Character 节点。
var target: Character

# 插值速度。
# 值越大相机跟随越紧密，值越小滞后感越强。
@export var follow_speed: float = 5.0

# 相机偏移量。
# 相对于跟随目标的偏移，正值 X 表示相机在目标右侧，正值 Y 表示相机在目标下方。
@export var follow_offset: Vector2 = Vector2(80.0, 0.0)

# 相机缩放。
# 值越大相机离角色越远（视野越宽），值越小离角色越近。
@export_range(0.1, 5.0, 0.1) var zoom_level: float = 1.0

# 初始化相机。
# 查找场景中的 Character 节点作为跟随目标。
func _ready() -> void:
	# 应用初始缩放。
	zoom = Vector2(zoom_level, zoom_level)
	# 延迟一帧查找目标，确保 Character 已经完成初始化。
	_find_target.call_deferred()

# 物理帧更新。
# 使用 lerp 平滑跟随目标位置。
func _physics_process(delta: float) -> void:
	if not target:
		return

	# 目标位置 = 角色位置 + 偏移量。
	var target_position: Vector2 = target.global_position + follow_offset

	# 通过 lerp 实现平滑滞后跟随。
	global_position = global_position.lerp(target_position, follow_speed * delta)

	# 每帧同步缩放，支持编辑器中实时调整 zoom_level。
	zoom = Vector2(zoom_level, zoom_level)

# 查找场景中的玩家角色。
# 通过 PlayerController 子组件识别玩家角色，避免误匹配到敌人或 NPC。
func _find_target() -> void:
	for node in get_tree().current_scene.get_children():
		if node is Character and node.get_node_or_null("PlayerController"):
			target = node
			print("MainCamera: 成功获取跟随目标")
			# 立即对准目标位置（含偏移），避免开局相机跳动。
			global_position = target.global_position + follow_offset
			return

	push_warning("MainCamera: 未找到玩家角色（需挂载 PlayerController）")
