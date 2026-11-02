## Token系列动作施放期间的连续文字：小字迅速放大并向上飘出，随宿主暂停和控制倍率推进。
extends Node2D

## 伙伴版使用Token回，默认保留Boss的Token来。
@export var caption: String = "Token来"

## 与项目UI一致的中文字体，兼容Token英文及“来”“回”字。
const FONT: Font = preload("res://assets/fonts/方正少儿_GBK.ttf")
## 每条文字的原速存活秒数。
const LIFETIME: float = 0.65
## 连续飘字间隔，单位为原速游戏秒，同屏最多约三条。
const INTERVAL: float = 0.22
## 文字基准字号，缩放从0.3倍快速增加到1.2倍。
const FONT_SIZE: int = 32
## 当前是否允许发射，动作切换时立即清空。
var _emitting: bool = false
## 个体控制倍率，0冻结；全局暂停和倍速由delta继承。
var _speed: float = 1.0
## 距离下一条文字产生的剩余原速秒数。
var _until_next: float = 0.0
## 现存文字的年龄及左右漂移方向，固定受生命周期和间隔限制。
var _particles: Array[Dictionary] = []
## 发射序号，用于交替左右轻微飘动。
var _serial: int = 0


## [param enabled]控制连续发射；关闭时清空残留，防止其他技能或退场仍出现文字。
func set_emitting(enabled: bool) -> void:
	_emitting = enabled
	_until_next = 0.0
	if not enabled:
		_particles.clear()
	queue_redraw()


## [param speed]为与视频一致的个体倍率，0暂停文字运动及发射。
func set_playback_speed(speed: float) -> void:
	_speed = maxf(0.0, speed)


## [param delta]为游戏帧秒数；不使用独立Tween或TIME，确保文字与视频冻结同步。
func _process(delta: float) -> void:
	if not _emitting or _speed <= 0.0:
		return
	# 本帧原速进度，兼容游戏倍速与个体控制。
	var step: float = delta * _speed
	# 倒序移除到期文字，避免遍历时漏项。
	for index: int in range(_particles.size() - 1, -1, -1):
		_particles[index].age += step
		if float(_particles[index].age) >= LIFETIME:
			_particles.remove_at(index)
	_until_next -= step
	if _until_next <= 0.0:
		_particles.append({"age": 0.0, "side": -1.0 if _serial % 2 == 0 else 1.0})
		_serial += 1
		_until_next = INTERVAL
	queue_redraw()


## 在头顶绘制当前Token文字，快速放大、上升并在尾段淡出，深色描边保证草坪上可读。
func _draw() -> void:
	# 文字中心对齐所需的本地基准宽度。
	var width: float = FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# 每条文字独立缩放，年龄决定位置和透明度。
	for particle: Dictionary in _particles:
		# 生命周期归一化进度。
		var progress: float = clampf(float(particle.age) / LIFETIME, 0.0, 1.0)
		# 前半段迅速由小变大，尾段保留轻微增长。
		var growth: float = lerpf(0.3, 1.2, 1.0 - pow(1.0 - progress, 3.0))
		# 上飘距离及交替侧偏，不遮住角色眼睛。
		var offset: Vector2 = Vector2(float(particle.side) * 16.0 * progress, -100.0 * progress)
		# 前段保持明亮，最后约一半时间逐渐消散。
		var opacity: float = 1.0 - smoothstep(0.4, 1.0, progress)
		draw_set_transform(offset, float(particle.side) * 0.05 * progress, Vector2.ONE * growth)
		draw_string_outline(FONT, Vector2(-width * 0.5, 0.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color(0.08, 0.18, 0.32, opacity))
		draw_string(FONT, Vector2(-width * 0.5, 0.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.88, 0.32, opacity))
	draw_set_transform(Vector2.ZERO)
