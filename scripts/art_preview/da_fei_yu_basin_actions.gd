## 大肥鱼普通待机及攻击动作1：取盆幻想，以及受击后向攻击者丢盆。
## 保留用户调整的基础场景；新动作使用关键姿势与独立道具 Tween。
extends Node2D

## 已确认的攻击动作名称，供预览、图鉴与动作目录统一使用。
const ATTACK_1_NAME: String = "攻击动作1"

## 动作阶段改变时通知预览或战斗宿主；[param phase] 是当前阶段标识。
signal phase_changed(phase: StringName)
## 钢盆离手时通知宿主；[param attacker] 为本次打破幻想的攻击者。
signal basin_released(attacker: Node2D)
## 钢盆到达目标时通知宿主；[param attacker] 可能已被释放，此时传 null。
signal basin_arrived(attacker: Node2D)

## 新动作对应的阶段，不承担 Boss 血量或伤害计算。
var phase: StringName = &"idle"
## 当前动作 Tween，重播时取消，避免旧回调污染新动作。
var action_tween: Tween
## 打破幻想的植物引用；仅第一下有效受击会锁定。
var source_plant: Node2D
## 攻击者最后有效的全局位置，目标被移除时用于落点回退。
var last_target_position: Vector2
## 道具飞行的局部起点。
var flight_start: Vector2
## 道具飞行的局部终点，在离手瞬间采样。
var flight_end: Vector2
## 用户微调后的盆相对于本动作根节点的完整变换。
var original_basin_transform: Transform2D
## 端盆时的道具中心，单位为角色局部像素。
const HOLD_POSITION: Vector2 = Vector2(-175, -170)
## 呼吸与气泡轻晃使用的累计秒数。
var elapsed: float = 0.0
## 原始骨骼角色，不修改其内部资源。
@onready var standing: Node2D = $Standing
## 原始头盆，取盆时读取其实际变换。
@onready var helmet: Sprite2D = $Standing/Rig/Skeleton2D/Head/SteelBasin
## 原始呼吸循环播放器。
@onready var standing_player: AnimationPlayer = $Standing/AnimationPlayer
## 四张动作关键姿势的公共容器。
@onready var poses: Node2D = $Poses
## 端盆姿势自己的呼吸播放器，脚底不跟随根节点起伏。
@onready var hold_idle_player: AnimationPlayer = $Poses/hold/AnimationPlayer
## 双手控制骨骼，独立钢盆直接跟随同一关节的细微位移。
@onready var hold_hands: Bone2D = $Poses/hold/Rig/Skeleton2D/Hands
## 双手的绑定位置，用来计算端盆过程中相对于静态姿势的呼吸偏移，单位为贴图像素。
const HOLD_HANDS_REST: Vector2 = Vector2(65, 305)
## 空盆与倒扣盆共用的可移动道具。
@onready var basin: Sprite2D = $Basin
## 气泡节点，含可扩散的云朵及米饭贴图。
@onready var thought: Node2D = $Thought
## 气泡中的米饭盆；破碎时比外轮廓更早消失。
@onready var rice: Sprite2D = $Thought/Rice
## 五种姿势的真实眼睑播放器，切换动作时清理上一姿势的闭眼状态。
@onready var blink_nodes: Array[Node] = [
	$Standing/Rig/Skeleton2D/Head/Blink,
	$Poses/reach/Blink,
	$Poses/hold/Rig/Skeleton2D/Head/Blink,
	$Poses/angry/Blink,
	$Poses/throw/Blink,
]
## 端正摆放的钢盆贴图。
const EMPTY_BASIN: Texture2D = preload("res://assets/image/character/boss/da_fei_yu/basin_actions_v1/empty_basin.png")


## 缓存用户当前的头盆变换；不回写基础场景。
func _ready() -> void:
	reset_idle()


## [param delta] 为本帧秒数；幻想时仅让道具跟随手部骨骼，气泡独立缓慢漂浮。
func _process(delta: float) -> void:
	elapsed += delta
	if phase == &"dream":
		basin.position = HOLD_POSITION + hold_hands.position - HOLD_HANDS_REST
		basin.rotation = hold_hands.rotation
		thought.position = Vector2(10 + sin(elapsed * TAU / 8.0) * 1.5, -650.0 + sin(elapsed * TAU / 8.0 - 0.4) * 2.0)


## 恢复用户原始待机外观，并取消未完成的取盆、丢盆动作。
func reset_idle() -> void:
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	source_plant = null
	standing.visible = true
	helmet.visible = true
	standing_player.play(&"idle")
	standing_player.seek(0.0, true)
	hold_idle_player.pause()
	# 每种姿势重新开始时先睁眼，再按自己的拍点真正闭合眼睑。
	for blink: Node in blink_nodes:
		blink.reset_blink()
	poses.visible = false
	poses.position = Vector2.ZERO
	poses.rotation = 0.0
	basin.visible = false
	thought.visible = false
	_set_phase(&"idle")


## 播放攻击动作1的准备段：双手取盆并幻想米饭，受击后进入丢盆反击。
func play_attack_1() -> void:
	reset_idle()
	standing_player.pause()
	original_basin_transform = global_transform.affine_inverse() * helmet.global_transform
	basin.texture = helmet.texture
	basin.transform = original_basin_transform
	basin.visible = true
	helmet.visible = false
	_show_pose(0)
	_set_phase(&"take")
	action_tween = create_tween()
	action_tween.tween_property(basin, "position", original_basin_transform.origin + Vector2(-8, -56), 0.45).set_trans(Tween.TRANS_SINE)
	action_tween.tween_interval(0.12)
	action_tween.tween_callback(_turn_basin_upright)
	action_tween.tween_property(basin, "position", HOLD_POSITION, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	action_tween.parallel().tween_property(basin, "rotation", 0.0, 0.65)
	action_tween.tween_callback(_begin_dream)


## 兼容旧预览入口；正式动作名称已改为攻击动作1。
func play_dream_idle() -> void:
	play_attack_1()


## [param speed]为当前动作倍率；静态关键姿势的眼睑同样跟随冻结及慢速播放。
func set_blink_speed(speed: float) -> void:
	# 骨骼姿势另外读取所属 AnimationPlayer，静态姿势使用此倍率。
	for blink: Node in blink_nodes:
		blink.playback_speed = speed


## [param attacker] 是打破幻想的植物；只在幻想阶段接受一次有效受击。
## 返回是否触发反击。无效或已移除攻击者不会触发，宿主负责实际伤害。
func react_to_hit(attacker: Node2D) -> bool:
	if phase != &"dream" or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return false
	source_plant = attacker
	last_target_position = attacker.global_position
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	_set_phase(&"angry")
	poses.position = Vector2.ZERO
	_show_pose(2)
	thought.set("burst", 0.0)
	action_tween = create_tween()
	action_tween.tween_property(thought, "burst", 1.0, 0.28)
	action_tween.parallel().tween_property(thought, "modulate:a", 0.0, 0.28)
	action_tween.parallel().tween_property(rice, "modulate:a", 0.0, 0.14)
	action_tween.tween_callback(_wind_up)
	action_tween.tween_property(poses, "rotation", 0.045, 0.24).set_trans(Tween.TRANS_SINE)
	action_tween.parallel().tween_property(basin, "position", Vector2(-125, -195), 0.24)
	action_tween.tween_interval(0.35)
	action_tween.tween_callback(_release_basin)
	action_tween.tween_method(_fly_basin, 0.0, 1.0, 0.72)
	action_tween.tween_callback(_arrive)
	return true


## 将盆翻正并切换为端盆姿势；道具尺寸从用户头盆的宽度继承。
func _turn_basin_upright() -> void:
	# 新旧贴图宽度不同，保持用户所设定的盆的屏幕宽度。
	var retained_width: float = helmet.texture.get_width() * original_basin_transform.get_scale().x
	basin.texture = EMPTY_BASIN
	basin.scale = Vector2.ONE * retained_width / EMPTY_BASIN.get_width()
	_show_pose(1)


## 气泡弹出后停留，等待实际攻击者或美术预览触发受击。
func _begin_dream() -> void:
	_set_phase(&"dream")
	thought.visible = true
	thought.position = Vector2(10, -650)
	thought.scale = Vector2.ONE * 0.08
	thought.modulate.a = 1.0
	thought.set("burst", 0.0)
	rice.modulate.a = 1.0
	action_tween = create_tween()
	action_tween.tween_property(thought, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 幻想破灭后切换鼓脸表情，保持盆在双手附近。
func _wind_up() -> void:
	thought.visible = false
	_show_pose(2)


## 离手瞬间锁定攻击者位置，并发出不含伤害数值的接入信号。
func _release_basin() -> void:
	_set_phase(&"throw")
	_show_pose(3)
	poses.rotation = -0.035
	if is_instance_valid(source_plant) and source_plant.is_inside_tree():
		last_target_position = source_plant.global_position
	flight_start = Vector2(-170, -305)
	flight_end = to_local(last_target_position)
	basin.position = flight_start
	basin_released.emit(source_plant if is_instance_valid(source_plant) else null)


## [param progress] 为 0～1 飞行进度；插值落点并增加抛物线及旋转。
func _fly_basin(progress: float) -> void:
	basin.position = flight_start.lerp(flight_end, progress) + Vector2(0, -145.0 * sin(progress * PI))
	basin.rotation = -TAU * progress


## 通知钢盆抵达；隐藏盆，等待宿主决定后续动作，不自动凭空补盆。
func _arrive() -> void:
	basin.visible = false
	poses.rotation = 0.0
	_set_phase(&"recover")
	basin_arrived.emit(source_plant if is_instance_valid(source_plant) else null)


## [param index] 为取盆、端盆、蓄力、丢盆四个姿势的索引。
func _show_pose(index: int) -> void:
	standing.visible = false
	poses.visible = true
	# 每次仅显示一个完整关键姿势，防止切换时叠出多余手脚。
	for child_index: int in range(poses.get_child_count()):
		poses.get_child(child_index).visible = child_index == index
	if index == 1:
		hold_idle_player.play(&"idle")
		hold_idle_player.seek(0.0, true)
	else:
		hold_idle_player.pause()
	# 取盆轻眨、被打断时闭眼一瞬、抛盆后短眨；每个关键姿势都具有独立眼型。
	var blink: Node = blink_nodes[index + 1]
	blink.reset_blink()
	blink.play_blink(0.15 if index != 2 else 0.0)


## [param value] 为新阶段；同步通知外部的文字提示和预览按钮。
func _set_phase(value: StringName) -> void:
	phase = value
	phase_changed.emit(value)
