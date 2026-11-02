## 货币战争磁力菇：消化后保留实际铁器，投向原版吸铁范围内最近的敌方僵尸。
extends Node

## 复用原版投掷轨迹、普通承伤与来源记录，铁器外观由每次吸来的节点提供。
const IRON_PROJECTILE: PackedScene = preload("res://scenes/currency_war/bullets/magnet_iron.tscn")
## 铁器弹脚本类型，用于显式调用实际铁器外观交接接口。
const IronProjectile = preload("res://scripts/currency_war/currency_war_iron_projectile.gd")
## 对应磁力菇实体；被吃掉后停止投掷，不生成额外铁器。
var _plant: Plant032MagnetShroom
## 原版吸铁和消化计时组件，本组件不改变吸铁范围或可吸铁器种类。
var _magnet: MagnetComponent
## 铁器已经消化完成，正在等待范围内出现有效敌人。
var _ready_to_throw: bool = false


## 为[param plant]接管消化完成回调，其他模式仍使用原版消失逻辑。
func configure(plant: Plant032MagnetShroom) -> void:
	_plant = plant
	_magnet = plant.magnet_component
	_magnet.currency_war_digest_callback = _on_digested


## 将消化间隔设为[param interval]游戏秒；属性刷新保留当前消化百分比，不重置已完成的等待。
func set_interval(interval: float) -> void:
	if interval <= 0.0 or is_equal_approx(_magnet.attack_cd, interval):
		return
	# 用旧间隔计算完成比例，避免装备同步或攻击叠层反复延长消化。
	var previous_interval: float = _magnet.attack_cd
	# 消化结束时计时器已停止，此时只更新下一轮间隔。
	var remaining: float = _magnet.attack_cd_timer.time_left
	_magnet.attack_cd = interval
	_magnet.attack_cd_timer.wait_time = interval
	if not _magnet.attack_cd_timer.is_stopped():
		_magnet.attack_cd_timer.start(maxf(0.001, remaining * interval / previous_interval))


## 消化完成后暂存铁器；实际投掷由战斗阶段调用[method try_throw]，准备或暂停不会提前发射。
func _on_digested() -> void:
	_ready_to_throw = true


## 战斗中尝试投出一件已消化铁器；无目标时保持持有，不立即吸取下一件。
func try_throw() -> void:
	if not _ready_to_throw or _plant.is_death or not _magnet.is_enabling or not is_instance_valid(_magnet.curr_iron):
		return
	# 每次投掷重新查询原版区域，离开范围、阵亡及魅惑友军不会成为新的目标。
	var target: Zombie000Base = _nearest_enemy()
	if target == null:
		return
	# 一次投掷计一次攻击动作，复用装备叠层后再快照本颗铁器的实际伤害。
	_plant.currency_war_attack_action()
	# 铁器沿用原版持有位置作为出手点，坐标先换到子弹容器的局部空间。
	var origin: Vector2 = _magnet.curr_iron.global_position
	# 独立子弹脱离植物生命周期；发出后源植物阵亡不会收回铁器。
	var projectile: IronProjectile = IRON_PROJECTILE.instantiate() as IronProjectile
	projectile.attack_value = int(_plant.get_meta("currency_war_attack_value", 100))
	projectile.set_meta("currency_war_execute", _plant.get_meta("currency_war_execute", 0.0))
	projectile.init_bullet({
		Bullet000NormBase.E_InitParasAttr.Position: Global.main_game.bullets.to_local(origin),
		Bullet000NormBase.E_InitParasAttr.BulletLane: target.lane,
		Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
		Bullet000NormBase.E_InitParasAttr.Enemy: target,
		Bullet000NormBase.E_InitParasAttr.EnemyGloPos: target.hurt_box_component.global_position,
		Bullet000NormBase.E_InitParasAttr.SourceCharacter: _plant,
	})
	Global.main_game.bullets.add_child(projectile)
	projectile.attach_iron(_magnet.curr_iron)
	_ready_to_throw = false
	# 铁器已移交子弹，再解除原版消化状态并允许下一次吸铁。
	_magnet.finish_currency_war_throw()


## 返回当前吸铁碰撞区域内距磁力菇最近的存活敌军；无有效目标返回null，不扩大原版范围。
func _nearest_enemy() -> Zombie000Base:
	# 最近候选只保留一个，多受击框属于同一僵尸时不会额外触发攻击。
	var nearest: Zombie000Base
	# 使用平方距离比较，避免每个候选都开平方。
	var nearest_distance: float = INF
	# 与原版吸铁共用碰撞结果，地形和坡道位置继续由原版组件维护。
	for area: Area2D in _magnet.area_2d.get_overlapping_areas():
		# 梯子等场景道具可被吸取，但不能成为造成伤害的僵尸目标。
		var enemy: Zombie000Base = area.owner as Zombie000Base
		if not is_instance_valid(enemy) or enemy.is_death or enemy.is_hypno:
			continue
		# 按植物与僵尸的脚底世界坐标衡量最近距离，允许吸铁范围内跨行投掷。
		var distance: float = _plant.global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest
