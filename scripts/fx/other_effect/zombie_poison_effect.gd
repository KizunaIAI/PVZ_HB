## 僵尸中毒的绿色染色及上升气泡；仅负责显示，不计算伤害或持续时间。
## 每只僵尸共用一个实例，由伤害状态逐层申请和释放，随宿主暂停、变速及销毁。
extends Node2D

## 挂接到僵尸根节点的唯一名称，用来合并重复施毒的视觉实例。
const EFFECT_NAME: StringName = &"PoisonStatusEffect"
## 普通中毒颜色；保留原画明暗，以独立槽位与其他状态颜色叠加。
const POISON_COLOR: Color = Color(0.55, 1.2, 0.32, 1.0)
## 同屏每只僵尸的气泡数，固定上限避免中毒叠层时遮挡画面。
const BUBBLE_COUNT: int = 11
## 当前中毒宿主，死亡或释放后停止显示。
var _target: Zombie000Base
## 仍在生效的中毒层数；只在最后一层释放后还原颜色。
var _layers: int = 0
## 动画累计游戏秒数，不使用不随暂停的着色器 TIME。
var _elapsed: float = 0.0
## 最近一次毒伤脉冲强度，0～1，在约 0.2 秒内衰减。
var _pulse: float = 0.0
## 气泡发射区域，以当前特效节点的局部像素为单位。
var _body_rect: Rect2 = Rect2(-28, -110, 56, 110)


## 为[param target]申请一层中毒显示，返回共用实例；死亡或无效目标返回 null。
## 必须在目标入树并完成 ready 后调用，不修改血量及中毒时间。
static func acquire(target: Zombie000Base) -> Node2D:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_death:
		return null
	# 已有实例由所有独立中毒层共享；队列释放的旧实例不再复用。
	var effect = target.get_node_or_null(NodePath(EFFECT_NAME))
	if not is_instance_valid(effect) or effect.is_queued_for_deletion():
		effect = load("res://scripts/fx/other_effect/zombie_poison_effect.gd").new()
		effect.name = EFFECT_NAME
		effect._target = target
		target.add_child(effect)
	effect._layers += 1
	effect.damage_tick()
	return effect


## 初始化气泡范围，并监听角色死亡；只在首次附毒时遍历可见身体精灵。
func _ready() -> void:
	z_index = 2
	_measure_body()
	_target.signal_character_death.connect(stop)


## 按[param delta]游戏秒推进气泡和绿色脉冲；跟随树暂停及 Engine.time_scale。
func _process(delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_death:
		stop()
		return
	_elapsed += delta
	_pulse = maxf(0.0, _pulse - delta * 5.0)
	_target.body.set_other_color(BodyCharacter.E_ChangeColors.PoisonColor, POISON_COLOR.lerp(Color(0.7, 1.4, 0.4), _pulse))
	queue_redraw()


## 持续毒伤发生时短暂增强绿色，不影响受击闪亮槽位和僵尸动画位置。
func damage_tick() -> void:
	_pulse = 1.0
	if is_instance_valid(_target) and is_instance_valid(_target.body):
		_target.body.set_other_color(BodyCharacter.E_ChangeColors.PoisonColor, POISON_COLOR)


## 释放一层显示；仍有其他中毒层时保留气泡，否则恢复原色并移除。
func release_layer() -> void:
	_layers = maxi(0, _layers - 1)
	if _layers == 0:
		stop()


## 死亡、状态结束或场景清理时立即停用；重复调用安全。
func stop() -> void:
	_clear_tint()
	visible = false
	set_process(false)
	if not is_queued_for_deletion():
		# 让同帧再次附毒能建立新实例，而不会命中待删除节点。
		name = &"ExpiredPoisonEffect"
		queue_free()


## 宿主切场景或特效被外部移除时同样清理自己的颜色槽。
func _exit_tree() -> void:
	_clear_tint()


## 恢复中毒颜色为白色乘数，不写回整份 modulate，不清除冰冻和魅惑。
func _clear_tint() -> void:
	if is_instance_valid(_target) and is_instance_valid(_target.body):
		# 新实例可能已在同帧接管染色，此时旧节点退出不能把新效果清掉。
		var current: Node = _target.get_node_or_null(NodePath(EFFECT_NAME))
		if current == self or current == null:
			_target.body.set_other_color(BodyCharacter.E_ChangeColors.PoisonColor, Color.WHITE)


## 测量可见身体及防具的范围，让气泡适配普通、路障、巨人等不同僵尸。
func _measure_body() -> void:
	# 首个可见精灵用于建立非空包围框，避免把角色原点也计入头部区域。
	var found: bool = false
	# 只测量身体下的精灵，不包含血条、影子和灰烬分支。
	for node: Node in _target.body.find_children("*", "Sprite2D", true, false):
		# 单个身体部件，可以是防具或动画中的精灵。
		var sprite: Sprite2D = node as Sprite2D
		if not sprite.is_visible_in_tree() or sprite.texture == null or sprite.self_modulate.a <= 0.0:
			continue
		# 将已旋转和缩放的精灵矩形变换到宿主特效的局部空间。
		var rect: Rect2 = (global_transform.affine_inverse() * sprite.global_transform) * sprite.get_rect()
		_body_rect = _body_rect.merge(rect) if found else rect
		found = true


## 绘制稀疏的绿色半透明气泡、亮边与高光，靠近末端时破裂消散。
func _draw() -> void:
	# 每个气泡具有固定相位和轨迹差异，不使用全局随机数干扰出怪或战斗概率。
	for index: int in range(BUBBLE_COUNT):
		# 周期为约 1.4～2.0 秒，局部相位打散以保持持续冒泡。
		var cycle: float = 1.4 + float(index % 4) * 0.2
		# 单泡归一化寿命，末尾 10% 由空心裂弧替代完整圆。
		var life: float = fposmod(_elapsed / cycle + float(index) * 0.618, 1.0)
		# 发射点覆盖身体中下部，再向肩部及头顶上方漂浮。
		var center: Vector2 = Vector2(
			_body_rect.position.x + _body_rect.size.x * (0.18 + fmod(float(index) * 0.37, 0.68)),
			_body_rect.end.y - _body_rect.size.y * (0.12 + float(index % 3) * 0.16 + life * 0.72)
		)
		center.x += sin(life * TAU + float(index)) * 7.0
		# 半径按角色尺寸适度缩放，普通僵尸约 2～5 像素。
		var radius: float = (2.3 + float(index % 4) * 0.85) * clampf(_body_rect.size.y / 115.0, 0.75, 1.8)
		# 生灭透明度避免突然出现；叠毒不增加颗粒数量。
		var opacity: float = smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.78, 1.0, life))
		if life < 0.9:
			draw_circle(center, radius, Color(0.25, 0.8, 0.04, opacity * 0.24))
			draw_arc(center, radius, 0.0, TAU, 18, Color(0.42, 0.92, 0.12, opacity * 0.9), 1.1, true)
			draw_arc(center, radius * 0.68, PI, PI * 1.5, 6, Color(0.85, 1.0, 0.5, opacity), 1.2, true)
		else:
			draw_arc(center, radius * 1.25, 0.3, 1.8, 6, Color(0.6, 1.0, 0.2, opacity), 1.0, true)
			draw_arc(center, radius * 1.25, 3.2, 4.6, 6, Color(0.6, 1.0, 0.2, opacity), 1.0, true)
