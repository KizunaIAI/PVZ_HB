## 原画眼睛的连续 UV 形变：上睫毛下移，眼球收拢，原眼皮展开。
## 控制器不创建可视节点或加载眼部贴片，只驱动原人物自身的形变材质。
extends Node2D

## 原人物 Polygon2D 或 Sprite2D 的相对路径；其纹理和骨骼绑定保持原样。
@export var mesh_path: NodePath
## 左 X、右 X、左眼角 Y、右眼角 Y，单位为原图像素。
@export var eye_shape: Vector4
## 从左到右九个等距采样点的上眼缘高度，单位为原图像素。
@export var upper_line: PackedFloat32Array
## 与上眼缘一一对应的下眼缘高度，单位为原图像素。
@export var lower_line: PackedFloat32Array
## 随上眼睑移动的原睫毛厚度，单位为原图像素。
@export var lash_height: float = 6.0
## 参与展开的原有上眼皮高度，单位为原图像素，限制在眉毛下方。
@export var skin_height: float = 0.8
## 带骨骼的姿势指定其播放器；静态姿势留空，使用外部传入的速度。
@export var player_path: NodePath
## 静态动作的控制倍率，0 暂停，1 正常；全局游戏倍速仍由 delta 决定。
var playback_speed: float = 1.0
## 当前姿势显示后的累计游戏秒，隐藏时停止计时。
var _time: float = 0.0
## 手动眨眼的开始时刻，负数表示没有指定。
var _manual_start: float = -1.0
## 本次手动眨眼的时长倍率。
var _manual_scale: float = 1.0
## 此人物实例独享的形变材质，避免不同个体共用眨眼程度。
var _surface: ShaderMaterial
## 姿势播放器，缺失时按外部传入倍率播放。
var _player: AnimationPlayer
## 当前可见眼睑状态，供预览界面读取：0睁眼、1半闭、2全闭。
var eye_state: int = 0
## 原人物单次绘制使用的眼睛 UV 形变着色器。
const EYE_DEFORMATION = preload("res://shaders/my_shader/da_fei_yu_blink.gdshader")


## 为原人物绑定独立形变材质，不生成盖住眼睛的精灵。
func _ready() -> void:
	_player = get_node_or_null(player_path) as AnimationPlayer if not player_path.is_empty() else null
	# 只改变已有绘制节点的采样坐标，所有像素均来自原人物纹理。
	var mesh: CanvasItem = get_node_or_null(mesh_path) as CanvasItem
	if mesh == null:
		return
	_surface = ShaderMaterial.new()
	_surface.shader = EYE_DEFORMATION
	_surface.set_shader_parameter("eye_shape", eye_shape)
	_surface.set_shader_parameter("upper_line", upper_line)
	_surface.set_shader_parameter("lower_line", lower_line)
	_surface.set_shader_parameter("lash_height", lash_height)
	_surface.set_shader_parameter("skin_height", skin_height)
	mesh.material = _surface


## [param delay]为从当前时刻起的等待游戏秒，[param slow]为时长倍率；可与动作节拍对齐。
func play_blink(delay: float = 0.0, slow: float = 1.0) -> void:
	_manual_start = _time + maxf(0.0, delay)
	_manual_scale = maxf(0.5, slow)


## 切换姿势时从睁眼开始，避免上一姿势的闭眼帧被带到下一姿势。
func reset_blink() -> void:
	_time = 0.0
	_manual_start = -1.0
	eye_state = 0
	if is_instance_valid(_surface):
		_surface.set_shader_parameter("closure", 0.0)


## [param delta]为游戏帧时长；连续驱动原眼睛闭合，暂停与倍率同步所属动作。
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# 骨骼姿势随播放器暂停；静态攻击姿势由宿主同步速度。
	var speed: float = _player.speed_scale if is_instance_valid(_player) and _player.is_playing() else (0.0 if is_instance_valid(_player) else playback_speed)
	_time += delta * speed
	# 十二秒内安排不等间隔的自然眨眼，含一次连眨，避免机械等间隔。
	var cycle: float = fposmod(_time, 12.0)
	# 原眼睛的闭合程度，0 完全睁开，1 完全闭合。
	var amount: float = 0.0
	# 不等间隔眨眼拍点，不使用全局随机数影响游戏概率。
	for at: float in [1.25, 4.05, 4.36, 7.9, 10.7]:
		amount = maxf(amount, _blink_amount(cycle - at, 1.0))
	if _manual_start >= 0.0:
		amount = maxf(amount, _blink_amount(_time - _manual_start, _manual_scale))
		if _time > _manual_start + 0.27 * _manual_scale:
			_manual_start = -1.0
	if is_instance_valid(_surface):
		_surface.set_shader_parameter("closure", amount)
	eye_state = 2 if amount > 0.96 else (1 if amount > 0.01 else 0)


## [param elapsed]为开始后的秒数，[param duration_scale]为时长倍率；返回 0 至 1 的连续闭合程度。
func _blink_amount(elapsed: float, duration_scale: float) -> float:
	# 闭合 70 毫秒、停留 55 毫秒、睁开 135 毫秒，起落均缓动。
	var time: float = elapsed / duration_scale
	if time < 0.0 or time >= 0.26:
		return 0.0
	if time < 0.07:
		return smoothstep(0.0, 0.07, time)
	if time <= 0.125:
		return 1.0
	return 1.0 - smoothstep(0.125, 0.26, time)
