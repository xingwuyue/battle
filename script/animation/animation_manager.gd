# 动画管理器类
# 继承自 Node，负责管理角色动画的播放和切换
# 通过状态名称映射到对应的动画名称，并处理动画播放逻辑
class_name AnimationManager
extends Node

# 精灵动画节点引用（用于播放动画）
@export var animated_sprite: AnimatedSprite2D

# 动画名称组
@export_group("Animation Names")
# 空闲状态动画名称
@export var idle_anim: String = "idle"
# 移动状态动画名称（步行）
@export var move_anim: String = "walk"
# 冲刺状态动画名称
@export var sprint_anim: String = "sprint"
# 跳跃状态动画名称
@export var jump_anim: String = "jump"
# 攻击状态动画名称
@export var attack_anim: String = "punch_attack001"
# 防御状态动画名称
@export var defend_anim: String = "defend"
# 受击状态动画名称
@export var hit_anim: String = "hit"
# 拾取状态动画名称
@export var pickup_anim: String = "pickup"
# 交互状态动画名称
@export var interaction_anim: String = "interaction"
# 工具状态动画名称
@export var tool_anim: String = "tool"
# 死亡状态动画名称
@export var die_anim: String = "die"

# 状态到动画的映射字典（在 _ready 中初始化）
var _state_anim_map: Dictionary = {}

# 节点就绪时调用（初始化状态动画映射）
func _ready() -> void:
	# 初始化状态到动画的映射关系
	_state_anim_map = {
		"idle": idle_anim,
		"move": move_anim,
		"sprint": sprint_anim,
		"jump": jump_anim,
		"attack": attack_anim,
		"defend": defend_anim,
		"hit": hit_anim,
		"pickup": pickup_anim,
		"interaction": interaction_anim,
		"tool": tool_anim,
		"die": die_anim,
	}

# 播放指定名称的动画
# 参数 anim_name: 要播放的动画名称
# 参数 restart: 是否重新开始播放（默认为 false）
func play(anim_name: String, restart: bool = false) -> void:
	# 检查精灵动画节点和精灵帧是否存在
	if not animated_sprite or animated_sprite.sprite_frames == null:
		return
	# 如果精灵不可见，则显示它
	if not animated_sprite.visible:
		animated_sprite.show()
	# 检查动画是否存在
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		push_warning("Animation not found: " + anim_name)
		# 如果找不到动画且不是空闲动画，则回退到空闲动画
		if anim_name != idle_anim and animated_sprite.sprite_frames.has_animation(idle_anim):
			play(idle_anim, restart)
		return
	# 如果需要重新开始，则播放动画并重置到第一帧
	if restart:
		animated_sprite.play(anim_name)
		animated_sprite.frame = 0
		return
	# 如果当前动画不是目标动画或动画未在播放，则播放目标动画
	if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
		animated_sprite.play(anim_name)

# 根据状态名称播放对应的动画
# 参数 state_name: 状态名称
func play_state(state_name: StringName) -> void:
	# 将状态名称转换为小写
	var state_key := state_name.to_lower()
	# 从映射字典中获取对应的动画名称
	var anim: String = _state_anim_map.get(state_key, "")
	# 特殊处理移动状态：如果角色正在冲刺，则使用冲刺动画
	if state_key == "move":
		var character := get_parent() as Character
		if character and character.is_dashing:
			anim = sprint_anim
	# 如果找到了对应的动画，则播放它
	if anim != "":
		play(anim)

# 状态变化时的回调函数（由状态机调用）
# 参数 new_state: 新状态名称
# 参数 _old_state: 旧状态名称（未使用）
func on_state_changed(new_state: StringName, _old_state: StringName) -> void:
	# 判断是否需要重新开始播放动画（非空闲和非移动状态需要重新开始）
	var should_restart := new_state.to_lower() != "idle" and new_state.to_lower() != "move"
	# 将状态名称转换为小写
	var state_key := new_state.to_lower()
	# 从映射字典中获取对应的动画名称
	var anim: String = _state_anim_map.get(state_key, "")
	# 特殊处理移动状态：如果角色正在冲刺，则使用冲刺动画
	if state_key == "move":
		var character := get_parent() as Character
		if character and character.is_dashing:
			anim = sprint_anim
	# 如果找到了对应的动画，则播放它（根据 should_restart 决定是否重新开始）
	if anim != "":
		play(anim, should_restart)

# 设置精灵的水平翻转状态
# 参数 flip: 是否翻转（true 为翻转，false 为不翻转）
func set_flip(flip: bool) -> void:
	if animated_sprite:
		animated_sprite.flip_h = flip