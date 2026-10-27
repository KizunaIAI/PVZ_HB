## 第一大关直接显示原版单行、三行草坪与完整庭院；连续贴图不逐行重复，新增草坪仍使用原版草卷。
extends Node2D

## 原版SodRoll的48帧、24fps关键帧。
const ROLL_ANIMATION: Animation = preload("res://resources/currency_war/sod_roll.tres")
## 连续草坪的原版遮罩和新增区域展开效果，不改变源图片。
const LAWN_SHADER: Shader = preload("res://shaders/my_shader/currency_war_lawn.gdshader")
## 新增草坪铺完后允许开战。
signal expansion_finished
## 本节点新增的真实草坪行号。
var _new_lanes: Array[int] = []
## 连续草坪材质，所有新增行共享同一展开进度。
var _material: ShaderMaterial
## 是否已经启动本节点的草卷，防止重复播放。
var _started: bool = false


## 根据[param lanes]选取原版整块草坪；[param previous_lanes]决定已铺区域，返回是否需要在镜头返回后播放扩建。
func configure(lanes: Array[int], previous_lanes: Array[int]) -> bool:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 只记新增行，已开放行不重新播放草卷。
	for lane: int in lanes:
		if not previous_lanes.has(lane):
			_new_lanes.append(lane)
	# 单行与三行直接使用原版对应的完整贴图，五行直接使用完整庭院背景。
	var texture: Texture2D = preload("res://assets/image/background/background1.jpg")
	# 完整庭院与背景同原点，不缩放草坪格子。
	var origin: Vector2 = Vector2.ZERO
	# 五行背景没有黑边，不需要草皮边缘遮罩。
	var mask: Texture2D = null
	if lanes.size() == 1:
		texture = preload("res://assets/image/background/sod1row.jpg")
		mask = preload("res://assets/image/background/sod1row_.png")
		origin = Vector2(237, 270)
	elif lanes.size() == 3:
		texture = preload("res://assets/image/background/sod3row.jpg")
		mask = preload("res://assets/image/background/sod3row_.png")
		origin = Vector2(237, 150)
	# 只建一块连续草坪，保留原版771像素宽度及完整的内部格子纹理。
	var grass: Sprite2D = Sprite2D.new()
	grass.texture = texture
	grass.centered = false
	grass.position = origin
	_material = ShaderMaterial.new()
	_material.shader = LAWN_SHADER
	_material.set_shader_parameter("image_origin", origin)
	_material.set_shader_parameter("image_size", texture.get_size())
	_material.set_shader_parameter("use_edge_mask", mask != null)
	if mask != null:
		_material.set_shader_parameter("edge_mask", mask)
	# 初始只显示上一节点已经开放的水平带，新增区域留给原版草卷铺开。
	_material.set_shader_parameter("previous_band", Vector2(280, 380) if previous_lanes.size() == 1 else (Vector2(180, 480) if previous_lanes.size() == 3 else Vector2(-1, -1)))
	_material.set_shader_parameter("reveal", 1.0 if _new_lanes.is_empty() else 0.0)
	grass.material = _material
	add_child(grass)
	return not _new_lanes.is_empty()


## 原版镜头返回后启动新增草坪的铺开；无新增行或已播放时不重复触发。
func begin_expansion() -> void:
	if _started or _new_lanes.is_empty():
		return
	_started = true
	# 草卷只负责动画，最终地面始终来自同一块原版连续贴图。
	for lane: int in _new_lanes:
		_create_roll(lane)
	# 展开速度与原版草卷关键帧的总时长保持一致。
	var tween: Tween = create_tween()
	tween.tween_property(_material, "shader_parameter/reveal", 1.0, ROLL_ANIMATION.length)
	tween.tween_callback(expansion_finished.emit)


## 给新增的[param lane]播放原版草卷，只对整段动画做行高平移。
func _create_roll(lane: int) -> void:
	# 动画原始关键帧以中行为基准。
	var roll: Node2D = Node2D.new()
	roll.position = Vector2(237, (lane - 2) * 100)
	add_child(roll)
	# 草卷主体以左上角为原点，对齐原版reanim关键帧。
	var body: Sprite2D = Sprite2D.new()
	body.name = "Roll"
	body.centered = false
	body.texture = preload("res://assets/reanim/SodRoll.png")
	roll.add_child(body)
	# 草卷端盖仍使用原版逐帧旋转与缩放。
	var cap: Sprite2D = Sprite2D.new()
	cap.name = "Cap"
	cap.centered = false
	cap.texture = preload("res://assets/reanim/SodRollCap.png")
	roll.add_child(cap)
	# 每条新行共享动画资源，各自拥有播放进度。
	var player: AnimationPlayer = AnimationPlayer.new()
	roll.add_child(player)
	# 不改写共享的原始动画关键帧。
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("unroll", ROLL_ANIMATION)
	player.add_animation_library("", library)
	player.animation_finished.connect(_on_roll_finished.bind(roll), CONNECT_ONE_SHOT)
	player.play("unroll")


## [param _animation_name]播放结束后仅释放[param roll]，连续草坪保持显示。
func _on_roll_finished(_animation_name: StringName, roll: Node2D) -> void:
	roll.queue_free()
