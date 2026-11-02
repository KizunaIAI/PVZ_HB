## 大肥鱼召唤兵死亡后返还1阳光，并自动飞向余额UI；不依赖召唤者继续存活。
class_name DaFeiYuSummonSun
extends CanvasLayer

## 自动飞回UI的游戏秒数，随全局暂停与倍速推进。
const FLIGHT_SECONDS: float = 0.65
## 1阳光的可见倍率，避免原版按1/25缩放导致看不见。
const SUN_SCALE: float = 0.42
## 死亡掉落瞬间的视口坐标，僵尸随后释放不影响轨迹。
var _origin: Vector2
## 余额UI弱引用，不阻止节点切换时界面正常释放。
var _target: WeakRef
## 纯绘制阳光，不携带拾取按钮或自动收集脚本。
var _sun: Node2D
## 当前累计飞行游戏秒，暂停时不增加。
var _elapsed: float = 0.0


## 为[param zombie]登记一次死亡奖励，在原版工厂连接过关判断前调用；不保存Boss引用。
static func register(zombie: Zombie000Base) -> void:
	if bool(zombie.get_meta("da_fei_yu_sun_registered", false)):
		return
	zombie.set_meta("da_fei_yu_sun_registered", true)
	zombie.signal_character_death.connect(_on_summon_died.bind(zombie), CONNECT_ONE_SHOT)


## [param zombie]死亡时先结算准确1阳光，再自动回收；先于末只敌军的过关判断执行。
static func _on_summon_died(zombie: Zombie000Base) -> void:
	if not is_instance_valid(zombie) or bool(zombie.get_meta("da_fei_yu_sun_dropped", false)):
		return
	# 无论被炸、吞噬或普通击杀都只掉落一次，不依赖原版随机掉落开关。
	zombie.set_meta("da_fei_yu_sun_dropped", true)
	# 直接进入真实账户，不让自动收集开关或收集增幅改变固定1点。
	var game: MainGameManager = Global.main_game
	if not is_instance_valid(game):
		return
	if "_run" in game:
		game._run.sun += 1
		game._redraw()
	elif is_instance_valid(game.card_manager) and is_instance_valid(game.card_manager.card_slot_battle):
		game.card_manager.card_slot_battle.sun_value += 1
	else:
		return
	# 金额先入账，防止最后一只敌军死亡切节点时丢钱；动画不二次收集。
	var marker: Marker2D = game.marker_2d_sun_target if is_instance_valid(game.marker_2d_sun_target) else game.marker_2d_sun_target_default
	if not is_instance_valid(marker):
		return
	# 优先飞向数量标签，缺失时沿用原版阳光图标锚点。
	var counter: Control = marker.get_parent().get_node_or_null("CurrSunValue") as Control
	# 挂在战场上，不能随已死亡的僵尸或Boss被提前释放。
	var flight: DaFeiYuSummonSun = DaFeiYuSummonSun.new()
	game.add_child(flight)
	flight.start_flight(zombie.get_global_transform_with_canvas().origin + Vector2(0, -36), counter if is_instance_valid(counter) else marker)


## 从[param origin]死亡点向[param target]余额UI飞行，此时1阳光已同步入账。
func start_flight(origin: Vector2, target: CanvasItem) -> void:
	layer = 85
	_origin = origin
	_target = weakref(target)
	# 只复制绘制树，不启动原版25点拾取物的任何逻辑。
	var template: Node2D = SceneRegistry.SUN.instantiate() as Node2D
	_sun = template.get_node("body").duplicate(0) as Node2D
	add_child(_sun)
	_sun.position = _origin
	_sun.scale = Vector2.ONE * SUN_SCALE
	template.free()


## 按[param delta]游戏秒自动回收，无需点击；Boss死亡、冻结或关闭自动收集均不影响此效果。
func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_sun):
		return
	# 界面离场时结束视觉，不修改已经结算的奖励。
	var target: CanvasItem = _target.get_ref() as CanvasItem
	if not is_instance_valid(target):
		queue_free()
		return
	_elapsed += delta
	# 数量标签与死亡点统一使用视口坐标，避免相机和CanvasLayer偏移。
	var destination: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5) if target is Control else target.get_global_transform_with_canvas().origin
	# 先轻微弹起，再加速飞回，体现掉落后自动收集。
	var progress: float = clampf(_elapsed / FLIGHT_SECONDS, 0.0, 1.0)
	_sun.position = _origin.lerp(destination, progress * progress) + Vector2(0.0, -36.0 * sin(progress * PI))
	_sun.scale = Vector2.ONE * SUN_SCALE * lerpf(1.0, 0.35, smoothstep(0.7, 1.0, progress))
	_sun.rotation = progress
	if progress >= 1.0:
		queue_free()
