# 主角招式表资源
# 用于集中存储并按规则匹配可执行招式
class_name PlayerMoveSet
extends Resource

# 预加载招式脚本，避免类型分析器无法解析新类
const PlayerMoveData = preload("res://script/data/player_move/player_move_data.gd")

# 招式列表
@export var moves: Array[PlayerMoveData] = []

# 通过招式 ID 获取单个招式配置
func get_move_by_id(move_id: StringName) -> PlayerMoveData:
	for move in moves:
		if move and move.move_id == move_id:
			return move
	return null

# 根据输入命令和上下文匹配当前最优招式
func find_best_move(
	command: StringName,
	state_tags: PackedStringArray,
	prev_move_id: StringName,
	phase_name: StringName
) -> PlayerMoveData:
	var best_move: PlayerMoveData = null

	for move in moves:
		if not move or move.input_command != command:
			continue
		if not _contains_all(state_tags, move.required_state_tags):
			continue
		if _has_any(state_tags, move.blocked_state_tags):
			continue
		if String(move.required_prev_move_id) != "" and move.required_prev_move_id != prev_move_id:
			continue
		if String(move.required_phase) != "" and move.required_phase != phase_name:
			continue

		if best_move == null or move.priority > best_move.priority:
			best_move = move

	return best_move

# 判断当前标签集合是否完整包含所有必须标签
func _contains_all(current_tags: PackedStringArray, required_tags: PackedStringArray) -> bool:
	for tag in required_tags:
		if not current_tags.has(tag):
			return false
	return true

# 判断当前标签集合是否命中任意一个禁用标签
func _has_any(current_tags: PackedStringArray, blocked_tags: PackedStringArray) -> bool:
	for tag in blocked_tags:
		if current_tags.has(tag):
			return true
	return false
