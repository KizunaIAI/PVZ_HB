## 大肥鱼偷阳光的纯视觉飞行：从阳光余额位置逐颗飞向头部，不创建可拾取物或重复修改余额。
extends CanvasLayer

## 每颗阳光飞行所需的原速游戏秒，继承 Boss 的冻结、减速和全局倍速。
const FLIGHT_SECONDS: float = 0.85
## 相邻阳光离开余额框的原速秒间隔，让实际偷取数量可以逐颗辨认。
const EMIT_INTERVAL: float = 0.07
## 原版阳光完整拼图的显示倍率，不使用1点阳光会缩至不可见的拾取物脚本。
const SUN_SCALE: float = 0.42
## 偷取关键帧的余额框中心，使用视口坐标，避免把界面坐标误当世界坐标。
var _origin: Vector2
## 吸取目标锚点弱引用，角色换行或镜头移动时实时跟随，不延长目标生命周期。
var _target: WeakRef
## 施法 Boss 的弱引用，仅用于读取个体控制倍率和死亡状态。
var _caster: WeakRef
## 仍在等待或飞行的阳光，每条保存绘制节点、原速年龄和弧线高度。
var _particles: Array[Dictionary] = []


## 从[param origin]余额框向[param target]飞出[param amount]颗阳光；[param caster]提供控制倍率，金额已由技能同步结算。
func start_flight(origin: Vector2, target: Node2D, amount: int, caster: Zombie000Base) -> void:
	layer = 85
	_origin = origin
	_target = weakref(target)
	_caster = weakref(caster)
	# 只复制原版阳光的绘制子树，不带点击、自动收集、阳光事件和十秒消失计时。
	var template: Node2D = SceneRegistry.SUN.instantiate() as Node2D
	# 一颗绘制阳光代表实际扣除的一点，不因原版阳光面值25而减少或放大数量。
	for index: int in range(amount):
		# 每颗保留原版三层光芒与中心，动画只操作该独立拼图。
		var sun: Node2D = template.get_node("body").duplicate(0) as Node2D
		add_child(sun)
		sun.position = _origin
		sun.scale = Vector2.ONE * SUN_SCALE
		sun.visible = false
		_particles.append({"visual": sun, "age": -index * EMIT_INTERVAL, "arc": 30.0 + index * 4.0})
	template.free()
	if _particles.is_empty():
		queue_free()


## 按[param delta]推进原速飞行；暂停继承场景，个体冻结停在当前进度，Boss死亡或目标释放立即取消。
func _process(delta: float) -> void:
	if _caster == null or _target == null:
		return
	# 弱引用失效时不能继续吸向旧坐标，也不触发任何返还或收集事件。
	var caster: Zombie000Base = _caster.get_ref() as Zombie000Base
	# 世界角色锚点转换到与余额框相同的视口坐标，兼容镜头、缩放和换行。
	var target: Node2D = _target.get_ref() as Node2D
	if not is_instance_valid(caster) or caster.is_death or not is_instance_valid(target):
		queue_free()
		return
	# 与视频技能共享个体倍率，全局暂停和倍速由正常节点处理及delta继承。
	var step: float = delta * maxf(0.0, float(caster.get("_speed_factor")))
	if step <= 0.0:
		return
	# 当前吸入口，逐帧更新可避免Boss换行时阳光飞向残留位置。
	var destination: Vector2 = target.get_global_transform_with_canvas().origin
	# 到达后仅释放绘制节点，金额不在动画回调中二次记账。
	for index: int in range(_particles.size() - 1, -1, -1):
		# 字典保留原速年龄，冻结后无需重新创建Tween。
		var particle: Dictionary = _particles[index]
		particle.age += step
		if float(particle.age) < 0.0:
			continue
		# 独立阳光节点没有按钮，不会在经过植物或阳光框时被拾取。
		var sun: Node2D = particle.visual
		# 归一化时间及加速吸入的插值比例，最后一帧精确抵达头部。
		var progress: float = clampf(float(particle.age) / FLIGHT_SECONDS, 0.0, 1.0)
		# 前段完整显示阳光，接近吸入口时缩小并消失。
		var shrink: float = lerpf(1.0, 0.15, smoothstep(0.65, 1.0, progress))
		sun.show()
		sun.position = _origin.lerp(destination, progress * progress) + Vector2(0.0, -sin(progress * PI) * float(particle.arc))
		sun.scale = Vector2.ONE * SUN_SCALE * shrink
		sun.rotation = progress * 1.2
		sun.modulate.a = 1.0 - smoothstep(0.85, 1.0, progress)
		if progress >= 1.0:
			sun.queue_free()
			_particles.remove_at(index)
	if _particles.is_empty():
		queue_free()
