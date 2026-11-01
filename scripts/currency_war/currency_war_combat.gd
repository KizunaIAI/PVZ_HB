## 本模式装备、羁绊、攻击动作叠层与星级属性；独有设定优先，其余植物使用通用模板。
extends Node

## 已定义的普通装备属性与配方。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 整局规则类型，装备记录独立于战斗节点生命周期。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 模式特殊弹的命中规则，用于配置当前实例，不改写原版子弹资源。
const SpecialPea = preload("res://scripts/currency_war/currency_war_pea_bullet.gd")
## 用户生成的大豌豆图片封装为独立子弹，保持原版飞行与三线换行接口。
const LARGE_PEA_SCENE: PackedScene = preload("res://scenes/currency_war/bullets/large_pea.tscn")
## 用户生成的长冰棱图片封装为独立子弹，保留原版寒冰命中特效并冰冻一秒。
const ICICLE_SCENE: PackedScene = preload("res://scenes/currency_war/bullets/icicle.tscn")
## 双发二、三星每颗火球概率；一星保持原版普通弹，不影响其他模式。
const REPEATER_FIRE_CHANCE: Array[float] = [0.0, 0.2, 0.3]
## 三发三个头分别独立判定大豌豆，二星20%、三星33.3%。
const THREEPEATER_LARGE_CHANCE: Array[float] = [0.0, 0.2, 0.333]
## 寒冰豌豆特殊冰棱概率，二星20%、三星33.3%。
const SNOWPEA_ICICLE_CHANCE: Array[float] = [0.0, 0.2, 0.333]
## 用户确认减速幅度为50%、60%、70%，子弹传递的是剩余速度倍率50%、40%、30%。
const SNOWPEA_SPEED_FACTOR: Array[float] = [0.5, 0.4, 0.3]
## 胆小菇一至三星每次缩地的固定范围伤害；独立于普通孢子伤害的星级加成。
const SCAREDY_BURST_DAMAGE: Array[int] = [50, 100, 100]
## 机枪每轮八发概率，一星不触发，二星20%、三星50%。
const GATLING_EIGHT_CHANCE: Array[float] = [0.0, 0.2, 0.5]
## 每次啃食大蒜新增一层中毒的每秒伤害，一至三星分别10、20、50，独立持续五秒。
const GARLIC_POISON_DAMAGE: Array[int] = [10, 20, 50]
## 与中毒层共享生命周期的原生绿色染色和气泡，不修改原有毒伤规则。
const PoisonEffect = preload("res://scripts/fx/other_effect/zombie_poison_effect.gd")
## 已附着于僵尸的独立中毒层；植物死亡不取消，场景销毁时自然清空。
var _poisons: Array[Dictionary] = []
## 大喷菇已积累的全力攻击游戏秒，满五秒后保留到下一次正常攻击。
var _fume_elapsed: Dictionary = {}
## 魅惑菇的本节点召唤计时与是否已释放开场友军，按唯一单位编号保存。
var _hypno_clocks: Dictionary = {}
## 当前整局规则引用。
var _run: RunRules
## 控制器持有的实体映射，同一字典会随种植、移动和死亡更新。
var _plants: Dictionary
## 原版子弹父节点，用于大招发射与坐标换算。
var _bullets: Node2D
## 真实格子数组，扇形上下沿使用实际开放草坪边界，不另定射程。
var _cells: Array[Array]
## 原版僵尸行，用于确定战场前沿。
var _rows: Array[ZombieRow]
## 不含头盔自身循环加成的每株即时属性。
var _stats: Dictionary = {}
## 最大生命百分比回复的累计游戏秒。
var _regen_time: float = 0.0
## 正在持续两秒发射的大招任务，各自记录已发数量和经过时间。
var _ultimates: Array[Dictionary] = []
## 独立随机源，用于特殊弹和头盔概率，避免影响原版出怪随机状态。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


## 注入[param run]、[param plants]、[param bullets]、[param cells]及[param rows]，不接管原版出怪或植物移动。
func configure(run: RunRules, plants: Dictionary, bullets: Node2D, cells: Array[Array], rows: Array[ZombieRow]) -> void:
	_run = run
	_plants = plants
	_bullets = bullets
	_cells = cells
	_rows = rows
	_random.randomize()
	Global.main_game.set_meta("currency_war_sunburn_reader", _sunburn_bonus)


## 给新建[param plant]记录原版基础攻击并连接[param unit_id]的攻击动作；节点重建不重置本局装备。
func register_plant(plant: Plant000Base, unit_id: int) -> void:
	# 发射类组件在一次攻击动画开始时计数，不按多发子弹、命中或大招弹丸计数。
	var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
	if attack != null:
		# 选择实际普通弹型作为基础；玉米投手按玉米粒而非场景占位的卷心菜计算。
		var base_type: int = BulletRegistry.BulletType.Bullet010Corn if attack is AttackComponentBulletCorn else attack.attack_bullet_type
		# 玉米投手场景的初始类型沿用了卷心菜，实际攻击动画会选玉米/黄油，基准应以玉米粒计算。
		var sample: Bullet000Base = Global.bullet_registry.get_bullet_scenes(base_type).instantiate()
		plant.set_meta("war_base_damage", sample.attack_value if sample is Bullet000NormBase else 0)
		plant.set_meta("war_base_bullet_type", base_type)
		sample.free()
		attack.signal_attack_action.connect(_on_attack_action.bind(unit_id))
		attack.currency_war_bullet_factory = _create_attack_bullet.bind(unit_id)
		if int(plant.plant_type) == 41:
			plant.set_meta("war_gatling_animation_speed", attack.animation_tree.get("parameters/TimeScale 2/scale"))
	if int(plant.plant_type) == 11 and not _fume_elapsed.has(unit_id):
		_fume_elapsed[unit_id] = 0.0
	if int(plant.plant_type) == 13 and not _hypno_clocks.has(unit_id):
		_hypno_clocks[unit_id] = {"started": false, "elapsed": 0.0}
	if plant is Plant014ScaredyShroom:
		plant.set_meta("currency_war_scared_callback", _on_scaredy_entered.bind(unit_id))
		plant.scaredy_component.configure_currency_war_query(_scaredy_targets.bind(unit_id))
	if int(plant.plant_type) == 37:
		plant.set_meta("currency_war_garlic_callback", _on_garlic_bitten.bind(plant))
	# 爆炸是一轮攻击动作，原版土豆地雷爆炸结束后才累计下一轮装备属性。
	var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
	if bomb != null:
		plant.set_meta("war_base_damage", 20 if bomb is BombComponentIce else bomb.bomb_value)
		bomb.signal_bomb_once.connect(_on_attack_action.bind(unit_id))
	if attack == null and bomb == null:
		# 特殊攻击读取各自的原版数值，不能因为没有子弹组件而丢失星级加成。
		var profile: Dictionary = RunRules.PlantTemplate.native_attack_profile(plant)
		plant.set_meta("war_base_damage", profile.damage)
		plant.set_meta("war_base_attack_cd", profile.interval)
		if profile.damage > 0:
			plant.set_meta("currency_war_action_callback", _on_attack_action.bind(unit_id))


## 从[param original_type]建立[param unit_id]的子弹，逐颗判定火球、大豌豆或冰棱，发射时快照实时伤害。
## [param shot_direction]为本颗发射方向，向左的裂荚弹使用火球池，向右使用冰球池。
func _create_attack_bullet(original_type: int, shot_direction: Vector2, unit_id: int) -> Bullet000Base:
	# 攻击动画可能在植物被消耗的同帧回调，缺少记录时仅返回原版实例。
	var unit: Dictionary = _run.find_unit(unit_id)
	# 类型默认沿用原版，特殊火球只替换本颗实例，不更改植物共享场景。
	var bullet_type: int = original_type
	# 默认场景保持原版，特殊美术只替换当前抽中的实例。
	var scene: PackedScene = Global.bullet_registry.get_bullet_scenes(original_type)
	# 特殊弹伤害倍率在装备与羁绊计算后只乘一次，不与原版火球40点基础伤害重复相乘。
	var damage_multiplier: float = 1.0
	if not unit.is_empty():
		# 星级钳制防止旧记录或开发者参数越界，不给一星增加特殊弹概率。
		var star_index: int = clampi(int(unit.star), 1, 3) - 1
		match int(unit.type):
			8:
				if _random.randf() < REPEATER_FIRE_CHANCE[star_index]:
					bullet_type = BulletRegistry.BulletType.Bullet006PeaFire
					scene = Global.bullet_registry.get_bullet_scenes(bullet_type)
					damage_multiplier = 2.0
			29:
				if _random.randf() < [0.0, 0.1, 0.3][star_index]:
					if shot_direction.x < 0.0:
						scene = Global.bullet_registry.get_bullet_scenes(BulletRegistry.BulletType.Bullet006PeaFire)
						damage_multiplier = 2.0
					else:
						# 右脑概率弹为原版寒冰射手冰球：普通伤害倍率、原版减速，不附加冰棱的伤害和定身。
						bullet_type = BulletRegistry.BulletType.Bullet002PeaSnow
						scene = Global.bullet_registry.get_bullet_scenes(bullet_type)
			41:
				if star_index == 2 and _random.randf() < 0.2:
					bullet_type = BulletRegistry.BulletType.Bullet006PeaFire
					scene = Global.bullet_registry.get_bullet_scenes(bullet_type)
					damage_multiplier = 2.0
			19:
				if _random.randf() < THREEPEATER_LARGE_CHANCE[star_index]:
					scene = LARGE_PEA_SCENE
					damage_multiplier = 1.5
			6:
				if _random.randf() < SNOWPEA_ICICLE_CHANCE[star_index]:
					scene = ICICLE_SCENE
					damage_multiplier = 1.5
	# 每发都走植物攻击组件的统一工厂，三发的各头也独立调用，不仅改变攻击组件的类型字段。
	var bullet: Bullet000NormBase = scene.instantiate() as Bullet000NormBase
	if is_instance_valid(_plants.get(unit_id)):
		# 工厂在发射瞬间读取攻击，旧弹不随新装备叠层再次变强。
		var plant: Plant000Base = _plants[unit_id]
		# 玉米投手的黄油保持原版相对于玉米粒的伤害比例，不将随机黄油强制改成普通玉米伤害。
		var native_damage: int = bullet.attack_value
		if int(unit.type) == 11:
			damage_multiplier *= float(plant.get_meta("war_fume_power", 1.0))
			bullet.max_distance = 2000.0 if int(unit.star) >= 2 else bullet.max_distance
			bullet.set_meta("currency_war_fume", true)
			bullet.set_meta("currency_war_fume_push", plant.get_meta("war_fume_push", 0.0))
		if original_type != int(plant.get_meta("war_base_bullet_type", original_type)) and damage_multiplier == 1.0:
			damage_multiplier = float(native_damage) / maxf(1.0, float(plant.get_meta("war_base_damage", native_damage)))
		bullet.attack_value = roundi(float(plant.get_meta("currency_war_attack_value", native_damage)) * damage_multiplier)
		# 西瓜、冰瓜与火球的溅射资源也按本颗实际伤害同比缩放，一星仍保持原始伤害比例。
		var spatter: SpatterComponent = bullet.get_node_or_null("SpatterComponent") as SpatterComponent
		if spatter != null and native_damage > 0:
			# 溅射组件有总量和上下限，三者需同步变化才能让升星真正影响群伤。
			var scale: float = float(bullet.attack_value) / native_damage
			spatter.sum_attack_value = roundi(spatter.sum_attack_value * scale)
			spatter.range_attack_value = Vector2i(roundi(spatter.range_attack_value.x * scale), roundi(spatter.range_attack_value.y * scale))
		bullet.set_meta("currency_war_execute", plant.get_meta("currency_war_execute", 0.0))
	if not unit.is_empty() and int(unit.type) == 29 and shot_direction.x < 0.0:
		bullet.set_meta("currency_war_bounce_left", true)
	if bullet is SpecialPea and scene == LARGE_PEA_SCENE:
		# 用户已确认半径一格；按真实格子两轴尺寸归一化距离，不以贴图尺寸决定伤害范围。
		bullet.splash_radius = _lawn_cell_radius()
	if not unit.is_empty() and int(unit.type) == 6:
		# 普通寒冰弹与特殊冰棱使用同一星级减速，冻结结束后也保留本次60%或70%的减速强度。
		var speed_factor: float = SNOWPEA_SPEED_FACTOR[clampi(int(unit.star), 1, 3) - 1]
		if bullet is SpecialPea:
			bullet.slow_factor = speed_factor
		else:
			bullet.set_meta("currency_war_slow_factor", speed_factor)
	return bullet


## 返回一格草坪的世界坐标跨度，包含格间留白，避免把76×95的点击区误当成完整80×100草坪。
func _lawn_cell_radius() -> Vector2:
	# 默认以真实格子尺寸兜底，正常地图拥有多行九列，可从相邻格子的中心间距计算。
	var radius: Vector2 = _cells[0][0].size
	# 原点使用同一世界坐标系，不受镜头平移影响。
	var center: Vector2 = _cells[0][0].get_global_rect().get_center()
	if _cells[0].size() > 1:
		radius.x = absf(_cells[0][1].get_global_rect().get_center().x - center.x)
	if _cells.size() > 1:
		radius.y = absf(_cells[1][0].get_global_rect().get_center().y - center.y)
	return radius


## 同步装备与羁绊属性：百分比相加，固定攻击在百分比之后计算；生命上限变化保留当前生命比例。
func sync() -> void:
	if _run == null:
		return
	_run.sync_helmet()
	_stats.clear()
	# 一次读取场上不同种类的羁绊档位，所有豌豆使用同一档普通加成。
	var pea: Dictionary = _run.pea_bonus()
	# 第一遍只计算不含头盔的实时属性，避免头盔把自己的加成重复加回总和。
	for unit_id: int in _plants:
		if not is_instance_valid(_plants[unit_id]):
			continue
		# 阵亡与合成材料可能已从规则移除，不能再参与属性总和。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty():
			continue
		# 真实战斗实体与逻辑记录分开持有，升星时复用同一装备数组。
		var plant: Plant000Base = _plants[unit_id]
		if plant.is_death:
			continue
		# 每件同种装备独立累加，叠层次数由攻击动作而非子弹数量决定。
		var gear: Dictionary = Equipment.stats(unit.get("equipment", []), _run.equipment_actions.get(unit_id, []))
		# 攻击与攻速分别查最新星级表，避免把50%攻速错误套成20%攻击。
		var star_bonus: float = _run.star_attack_bonus(int(unit.type), int(unit.star))
		# 地形植物和非豌豆不获得豌豆羁绊属性。
		var is_pea: bool = RunRules.CATALOG[unit.type].trait == "豌豆"
		# 发射与爆炸能力决定攻击装备是否生效，向日葵不因装备而获得新的攻击功能。
		var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
		# 土豆地雷的原版爆炸组件仍控制范围和触发方式。
		var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
		# 发射频率使用每秒攻击动作数，便于按实时总和的5%计算头盔加成。
		var base_interval: float = float(plant.get_meta("war_base_attack_cd", 0.0))
		# 普通发射、咀嚼、地刺动画与加农炮充能都有原版频率；一次性爆炸没有重复攻击间隔。
		var rate: float = (1.0 + _run.star_speed_bonus(int(unit.type), int(unit.star)) + float(gear.speed) + (float(pea.speed) if is_pea else 0.0)) / base_interval if base_interval > 0.0 else 0.0
		# 地雷星级倍率来自最新大纲，不把攻速装备擅自转成出土速度。
		var damage_scale: float = [1.0, 1.5, 2.5][int(unit.star) - 1] if int(unit.type) == 5 else 1.0 + star_bonus
		# 所有固定攻击加成在百分比之后，无法攻击的植物不应用攻击装备。
		var damage: float = float(plant.get_meta("war_base_damage", 0)) * damage_scale + float(gear.attack) + (float(pea.attack) if is_pea else 0.0) if float(plant.get_meta("war_base_damage", 0)) > 0.0 else 0.0
		_stats[unit_id] = {"rate": rate, "damage": damage, "gear": gear, "pea": is_pea}
	# 第二遍只给玩家选择的唯一佩戴者加上其他豌豆的实时属性，不含自身。
	if _stats.has(_run.helmet_unit_id):
		# 已佩戴头盔者的记录与其他单位不同，不将总和写回共享装备定义。
		var wearer: Dictionary = _stats[_run.helmet_unit_id]
		# 逐株求和，同种多株能贡献属性，但不重复增加羁绊种类。
		for unit_id: int in _stats:
			if unit_id != _run.helmet_unit_id and _stats[unit_id].pea:
				wearer.rate += _stats[unit_id].rate * 0.05
				wearer.damage += _stats[unit_id].damage * 0.05
	# 最后统一应用实体，不在计算下一株属性时读到半更新的总和。
	for unit_id: int in _stats:
		# 每个实体此时仍由控制器映射持有，所有临时属性只写入模式元数据。
		var plant: Plant000Base = _plants[unit_id]
		# 读取本轮计算结果和装备属性。
		var value: Dictionary = _stats[unit_id]
		# 自由测试可覆盖该类型、星级的最终面板值；结束测试后立即恢复星级、装备与羁绊原规则。
		var unit: Dictionary = _run.find_unit(unit_id)
		# 使用字符串键避免嵌套枚举字典序列化，未设置覆盖时完全沿用正常计算。
		var override: Dictionary = _run.developer_overrides.get("%d:%d" % [unit.type, unit.star], {}) if _run.developer_testing else {}
		if not override.is_empty():
			value.damage = float(override.damage)
			value.rate = 1.0 / maxf(0.02, float(override.interval))
			value.gear.defense = float(override.defense)
			value.gear.reduction = float(override.reduction)
		# 最大生命只在确实变化时同步，避免反复刷新产生取整治疗。
		var maximum: int = int(override.health) if not override.is_empty() else int(plant.get_meta("war_base_hp")) + int(value.gear.health)
		if maximum != plant.hp_component.max_hp:
			# 新增生命装备不重建植物，现有伤势按比例保留。
			var ratio: float = float(plant.hp_component.curr_hp) / plant.hp_component.max_hp
			plant.hp_component.max_hp = maximum
			plant.hp_component.curr_hp = maxi(1, roundi(maximum * ratio))
		plant.set_meta("currency_war_defense", value.gear.defense)
		plant.set_meta("currency_war_reduction", value.gear.reduction)
		plant.set_meta("currency_war_attack_value", roundi(value.damage))
		plant.set_meta("currency_war_execute", value.gear.execute)
		if int(unit.type) == 37:
			plant.set_meta("war_garlic_poison_damage", GARLIC_POISON_DAMAGE[clampi(int(unit.star), 1, 3) - 1])
		# 真正的攻击组件沿用原版动画与发射点，只调整动作频率。
		if plant is Plant011FumeShroom:
			# 视觉按本行真实草坪右边缘覆盖；每次发射再读取喷口位置，兼容场上移动及升星。
			var row_end_x: float = _cells[plant.lane][-1].get_global_rect().end.x if int(unit.star) >= 2 else NAN
			plant.set_row_fume_end(row_end_x)
		var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
		if attack != null and value.rate > 0.0:
			attack.attack_cd = 1.0 / value.rate
			attack.bullet_attack_cd_timer.wait_time = attack.attack_cd
			if int(unit.type) == 11 and int(unit.star) >= 2 and not plant.has_meta("war_fume_fullscreen"):
				# 复制碰撞资源后扩展前向检测，避免修改共享资源而影响一星或其他模式。
				var shape_node: CollisionShape2D = attack.detect_component.get_node("Area2D/CollisionShape2D")
				shape_node.shape = shape_node.shape.duplicate()
				(shape_node.shape as RectangleShape2D).size.x = 2000.0
				shape_node.position.x = 1000.0
				plant.set_meta("war_fume_fullscreen", true)
			if int(unit.type) == 41:
				# 机枪原版四发动画单独有三倍速轨道；攻速提升时同步加速，避免下一轮请求截掉旧轮尾弹。
				var animation_speed: float = float(plant.get_meta("war_gatling_animation_speed", 3.0)) * float(value.rate) * float(plant.get_meta("war_base_attack_cd", 1.5))
				attack.animation_tree.set("parameters/TimeScale 2/scale", animation_speed)
				attack.currency_war_extra_shot_delay = 0.25 / maxf(0.01, animation_speed * float(attack.animation_tree.get("parameters/TimeScale/scale")))
			if not override.is_empty() and not attack.bullet_attack_cd_timer.is_stopped() and attack.bullet_attack_cd_timer.time_left > attack.attack_cd:
				attack.bullet_attack_cd_timer.start(attack.attack_cd)
		# 爆炸仍使用原版范围，装备只改变伤害，不让向日葵获得攻击能力。
		var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
		if bomb != null:
			bomb.bomb_value = roundi(value.damage)
		RunRules.PlantTemplate.apply_special_attack(plant, roundi(value.damage), float(value.rate))


## 每个攻击动作给[param unit_id]增加一次无上限叠层，随后判定一次机枪头盔概率；大招弹丸不反向产生攻击动作。
func _on_attack_action(unit_id: int) -> void:
	if _run.phase != RunRules.Phase.BATTLE or _run.find_unit(unit_id).is_empty():
		return
	# 八发按整轮判定一次，下一轮重新置回四发；特殊火弹仍按每颗独立判定。
	var unit: Dictionary = _run.find_unit(unit_id)
	if int(unit.type) == 11 and is_instance_valid(_plants.get(unit_id)):
		# 充能满后强化下一轮正常攻击，没有敌人时不凭空发弹或浪费充能。
		var charged: bool = float(_fume_elapsed.get(unit_id, 0.0)) >= 5.0
		_plants[unit_id].set_meta("war_fume_power", [2.0, 3.0, 6.0][clampi(int(unit.star), 1, 3) - 1] if charged else 1.0)
		_plants[unit_id].set_meta("war_fume_push", [0.5, 1.0, 2.0][clampi(int(unit.star), 1, 3) - 1] * _lawn_cell_radius().x if charged else 0.0)
		if charged:
			_fume_elapsed[unit_id] = 0.0
	if int(unit.type) == 41 and is_instance_valid(_plants.get(unit_id)):
		# 原版机枪一轮动画四个发射点回调，倍数2得到八颗而非八次装备叠层。
		var attack: AttackComponentBulletBase = _plants[unit_id].get_node("AttackComponent") as AttackComponentBulletBase
		attack.currency_war_volley_multiplier = 2 if _random.randf() < GATLING_EIGHT_CHANCE[clampi(int(unit.star), 1, 3) - 1] else 1
	_run.attack_actions[unit_id] = int(_run.attack_actions.get(unit_id, 0)) + 1
	# 按佩戴的每个槽记录一次动作，新买装备不追溯该单位此前的攻击。
	var counters: Array = _run.equipment_actions.get(unit_id, []).duplicate()
	# 已拥有单位本次实际佩戴的普通装备数。
	var slots: int = _run.find_unit(unit_id).get("equipment", []).size()
	while counters.size() < slots:
		counters.append(0)
	# 同种多件同时获得本次动作叠层，但多颗子弹不重复发出动作信号。
	for slot: int in range(slots):
		counters[slot] = int(counters[slot]) + 1
	_run.equipment_actions[unit_id] = counters
	sync()
	if unit_id == _run.helmet_unit_id and _random.randf() < float(_run.pea_bonus().chance):
		_ultimates.append({"id": unit_id, "elapsed": 0.0, "sent": 0})


## 用[param delta]游戏秒推进生命吊坠和两秒大招，暂停或节点结果期间不攻击、不回血。
func _process(delta: float) -> void:
	if _run == null or _run.phase != RunRules.Phase.BATTLE:
		return
	_update_special_plants(delta)
	_update_poison(delta)
	# 最后一只僵尸可能刚被毒击杀并触发节点结算，本帧也停止回复和大招。
	if _run.phase != RunRules.Phase.BATTLE:
		return
	_regen_time += delta
	if _regen_time >= 1.0:
		# 游戏速度较快时按实际经过的整秒恢复，不丢失回复次数。
		var seconds: int = floori(_regen_time)
		_regen_time -= seconds
		# 每件生命吊坠分别贡献最大生命2%的回复，超过上限时截到最大生命。
		for unit_id: int in _stats:
			if is_instance_valid(_plants.get(unit_id)) and not _plants[unit_id].is_death:
				# 植物生命组件保持原版死亡处理，不对已死亡实体复活。
				var hp: HpComponent = _plants[unit_id].hp_component
				hp.curr_hp = mini(hp.max_hp, hp.curr_hp + roundi(hp.max_hp * float(_stats[unit_id].gear.regen) * seconds))
	# 任务逆序处理，完成或佩戴者消失时可安全删除。
	for index: int in range(_ultimates.size() - 1, -1, -1):
		# 每轮大招独立累计168枚，不设置文档未定义的额外冷却。
		var job: Dictionary = _ultimates[index]
		if not is_instance_valid(_plants.get(job.id)) or _plants[job.id].is_death:
			_ultimates.remove_at(index)
			continue
		job.elapsed += delta
		# 总量168、时长2秒，帧率较低时同帧补足应发数量。
		var target: int = mini(168, floori(float(job.elapsed) / 2.0 * 168.0))
		while int(job.sent) < target:
			_fire_ultimate_bullet(int(job.id), int(job.sent))
			job.sent += 1
		if int(job.sent) >= 168:
			_ultimates.remove_at(index)


## 为[param unit_id]大招发射第[param index]枚普通伤害豌豆，扇形边界取当前开放草坪上下沿，射程不额外增加。
func _fire_ultimate_bullet(unit_id: int, index: int) -> void:
	# 只有具有原版发射点的植物才实际发弹。
	var plant: Plant000Base = _plants[unit_id]
	# 沿用原版组件的子弹类型、发射点、命中状态和坐标转换。
	var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
	if attack == null or attack.markers_2d_bullet.is_empty():
		return
	# 发射原点和战场前沿均为同一世界坐标，不混入顶部界面或摄像机偏移。
	var origin: Vector2 = attack.markers_2d_bullet[0].global_position
	# 开放草坪的上下边界决定扇形，无需新增未经定义的角度或范围常量。
	var top: float = INF
	# 累计最下方开放行边界。
	var bottom: float = -INF
	# 只覆盖实际草坪，不向尚未开放的泥地额外扩展攻击区域。
	for lane: int in _run.active_lanes:
		# 各行格子处于同一水平带，读取一个格子的真实范围即可。
		var rect: Rect2 = _cells[lane][0].get_global_rect()
		top = minf(top, rect.position.y)
		bottom = maxf(bottom, rect.end.y)
	# 向前扇形使用原版僵尸出现前沿，不改变子弹本身最大距离。
	var distance: float = maxf(1.0, _rows[plant.lane].zombie_create_position.global_position.x - origin.x)
	# 168枚依次覆盖整个扇形，两秒内一轮，不生成新的元素变种。
	var angle: float = lerpf(atan2(top - origin.y, distance), atan2(bottom - origin.y, distance), float(index) / 167.0)
	# 每枚子弹独立实例化，不改写共享场景的伤害值。
	var bullet: Bullet000NormBase = Global.bullet_registry.get_bullet_scenes(attack.attack_bullet_type).instantiate() as Bullet000NormBase
	# 大招与普通豌豆使用当前同一攻击值，不额外乘伤害系数。
	var parameters: Dictionary = attack.get_bullet_paras(origin, Vector2.from_angle(angle))
	parameters[Bullet000NormBase.E_InitParasAttr.IsActivateLane] = false
	bullet.attack_value = int(plant.get_meta("currency_war_attack_value"))
	bullet.set_meta("currency_war_execute", plant.get_meta("currency_war_execute", 0.0))
	bullet.init_bullet(parameters)
	_bullets.add_child(bullet)


## [param zombie]啃食[param source]大蒜后新增一层中毒，每层独立五次伤害；致死一口仍可附毒，不依赖已移除的单位记录。
func _on_garlic_bitten(zombie: Zombie000Base, source: Plant000Base) -> void:
	if _run.phase != RunRules.Phase.BATTLE or not is_instance_valid(zombie) or zombie.is_death or not is_instance_valid(source):
		return
	_poisons.append({"target": zombie, "damage": int(source.get_meta("war_garlic_poison_damage", 10)), "elapsed": 0.0, "ticks": 5, "effect": PoisonEffect.acquire(zombie)})


## 以[param delta]游戏秒推进每层中毒；暂停和倍速跟随战斗，每秒一次，死亡后不再处理该目标。
func _update_poison(delta: float) -> void:
	# 逆序移除到期层，叠层的持续时间各自保存。
	for index: int in range(_poisons.size() - 1, -1, -1):
		# 本层状态只引用目标，不依赖大蒜是否仍然存活。
		var poison: Dictionary = _poisons[index]
		if not is_instance_valid(poison.target) or poison.target.is_death:
			_release_poison_layer(index)
			continue
		poison.elapsed += delta
		while poison.elapsed >= 1.0 and int(poison.ticks) > 0 and not poison.target.is_death:
			if _run.phase != RunRules.Phase.BATTLE:
				return
			poison.elapsed -= 1.0
			poison.ticks -= 1
			poison.target.hp_component.Hp_loss(int(poison.damage), BulletRegistry.AttackMode.Norm, true, false)
			if is_instance_valid(poison.effect) and not poison.effect.is_queued_for_deletion():
				poison.effect.damage_tick()
		if int(poison.ticks) == 0 or poison.target.is_death:
			_release_poison_layer(index)


## 移除[param index]对应的独立毒伤层，同时释放共享特效的一层引用。
func _release_poison_layer(index: int) -> void:
	# 该层可能已因僵尸死亡而提前销毁显示，释放前先判断实例有效性。
	var effect = _poisons[index].effect
	if is_instance_valid(effect) and not effect.is_queued_for_deletion():
		effect.release_layer()
	_poisons.remove_at(index)


## 控制器切换或退出时归还所有显示层，避免仍存活的僵尸保留绿色。
func _exit_tree() -> void:
	# 逆序释放，不改动相邻层索引，也不继续计算毒伤。
	for index: int in range(_poisons.size() - 1, -1, -1):
		_release_poison_layer(index)


## 返回[param unit_id]周围实际3×3格内的敌人；害怕检测与缩地攻击共用此方法，统一按行号与受击中心判断。
func _scaredy_targets(unit_id: int) -> Array[Zombie000Base]:
	# 地图边缘裁剪到实际开放草坪，备战和已销毁的植物不检测。
	var targets: Array[Zombie000Base] = []
	# 查询单位唯一编号，移动、出售或合成后不沿用旧位置。
	var unit: Dictionary = _run.find_unit(unit_id)
	if unit.is_empty() or unit.cell == RunRules.BENCH_CELL or not is_instance_valid(_plants.get(unit_id)) or _plants[unit_id].is_death:
		return targets
	# 使用原版可检测僵尸状态，魅惑友军不会触发害怕。
	var plant: Plant014ScaredyShroom = _plants[unit_id] as Plant014ScaredyShroom
	if plant == null:
		return targets
	# 原版名单每个僵尸仅一条记录，不按多个受击框重复命中。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno or absi(zombie.lane - int(unit.cell.x)) > 1 or not _run.is_lane_open(zombie.lane):
			continue
		if not (zombie.curr_be_attack_status & plant.scaredy_component.detect_component.can_attack_zombie_status):
			continue
		# 每行左右各一格，使用真实草坪矩形边界，屋顶坡度不影响跨行判断。
		var left: float = _cells[zombie.lane][maxi(0, int(unit.cell.y) - 1)].get_global_rect().position.x
		# 右边界包含所在格和右邻格，格间留白也归入连续范围。
		var right: float = _cells[zombie.lane][mini(_cells[zombie.lane].size() - 1, int(unit.cell.y) + 1)].get_global_rect().end.x
		# 害怕和受击使用同一坐标点，不会出现身体边缘触发害怕、中心却在攻击区外的情况。
		var target_x: float = zombie.hurt_box_component.global_position.x
		if target_x >= left and target_x <= right:
			targets.append(zombie)
	return targets


## [param unit_id]首次缩地时记录本次触发目标；延迟到当前回调结束后施放，移动或碰撞状态变化不会漏掉触发者。
func _on_scaredy_entered(unit_id: int) -> void:
	if _run.phase == RunRules.Phase.BATTLE:
		call_deferred("_release_scaredy_burst", unit_id, _scaredy_targets(unit_id))


## 对[param unit_id]本次缩地记录的[param targets]各攻击一次；三星击退存活目标一格，Boss继续免疫击退。
func _release_scaredy_burst(unit_id: int, targets: Array[Zombie000Base]) -> void:
	# 场景退出、单位出售或节点结束后，旧回调不再产生伤害。
	var unit: Dictionary = _run.find_unit(unit_id)
	if _run.phase != RunRules.Phase.BATTLE or unit.is_empty() or not is_instance_valid(_plants.get(unit_id)):
		return
	# 保留原版缩地停火与起身恢复机制。
	var plant: Plant014ScaredyShroom = _plants[unit_id] as Plant014ScaredyShroom
	if plant == null or plant.is_death:
		return
	_on_attack_action(unit_id)
	# 星级决定固定冲击伤害与击退，不把普通弹伤害再次乘到固定值上。
	var star_index: int = clampi(int(unit.star), 1, 3) - 1
	# 真实格子跨度用于一格击退，保持与地图缩放和镜头坐标一致。
	var distance: float = _lawn_cell_radius().x
	# 目标来自触发瞬间，不在延迟回调中重新裁剪边缘，避免一帧移动使触发者漏判。
	for zombie: Zombie000Base in targets:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		zombie.be_attacked_bullet(SCAREDY_BURST_DAMAGE[star_index], BulletRegistry.AttackMode.Norm, true, false)
		if star_index == 2 and not zombie.is_death:
			zombie.apply_knockback(distance)


## 返回当前存活上场阳光菇的晒伤百分比之和；实时读取成长状态，离场立即失效，不作用于友军。
func _sunburn_bonus() -> float:
	# 不设置上限或额外羁绊，按用户确认的多株相加。
	var bonus: float = 0.0
	# 逐株独立贡献，同种多株也可叠加晒伤。
	for unit_id: int in _plants:
		# 只读取当前仍部署的单位，出售和合成移除者不贡献。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty() or int(unit.type) != 10 or unit.cell == RunRules.BENCH_CELL or not is_instance_valid(_plants[unit_id]) or _plants[unit_id].is_death:
			continue
		# 原版成长计时保留，成长前后各使用文档明确的三个档位。
		var source: Plant010SunShroom = _plants[unit_id] as Plant010SunShroom
		bonus += ([0.1, 0.3, 1.0] if source.is_grow else [0.05, 0.15, 0.5])[clampi(int(unit.star), 1, 3) - 1]
	return bonus


## 以[param delta]游戏秒推进大喷菇充能和魅惑菇召唤，准备、暂停、节点结束时均不计时。
func _update_special_plants(delta: float) -> void:
	# 字典快照允许召唤或死亡回调改变实体映射。
	for unit_id: int in _plants.keys():
		# 只为活着的上场植物推进计时。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty() or not is_instance_valid(_plants[unit_id]) or _plants[unit_id].is_death:
			continue
		if int(unit.type) == 11:
			_fume_elapsed[unit_id] = minf(5.0, float(_fume_elapsed.get(unit_id, 0.0)) + delta)
		elif int(unit.type) == 13:
			# 开场保证对应星级的普通/路障/铁桶，之后才使用随机池。
			var clock: Dictionary = _hypno_clocks[unit_id]
			if not clock.started:
				clock.started = true
				call_deferred("_summon_hypno", unit_id, true)
			else:
				clock.elapsed += delta
				if clock.elapsed >= [10.0, 7.0, 3.0][clampi(int(unit.star), 1, 3) - 1]:
					clock.elapsed -= [10.0, 7.0, 3.0][clampi(int(unit.star), 1, 3) - 1]
					call_deferred("_summon_hypno", unit_id, false)


## 为[param unit_id]召唤原版生命的魅惑友军；[param initial]为开场保底，召唤物不套奖励关一血、不计敌方自然数量。
func _summon_hypno(unit_id: int, initial: bool) -> void:
	# 原植物消失或节点结束就取消尚未执行的召唤。
	var unit: Dictionary = _run.find_unit(unit_id)
	if _run.phase != RunRules.Phase.BATTLE or unit.is_empty() or not is_instance_valid(_plants.get(unit_id)) or _plants[unit_id].is_death:
		return
	# 星级决定保底和后续概率，所有类型都使用原版资源。
	var star: int = clampi(int(unit.star), 1, 3)
	# 初始为普通，二、三星再按指定规则替换。
	var type: int = CharacterRegistry.ZombieType.Z001Norm
	if initial:
		type = [CharacterRegistry.ZombieType.Z001Norm, CharacterRegistry.ZombieType.Z003Cone, CharacterRegistry.ZombieType.Z005Bucket][star - 1]
	elif star == 2:
		type = CharacterRegistry.ZombieType.Z001Norm if _random.randf() < 0.5 else CharacterRegistry.ZombieType.Z003Cone
	elif star == 3:
		# 百分位累计区间为20/30/45/5，不因敌方解锁池限制友军召唤。
		var roll: int = _random.randi_range(1, 100)
		type = CharacterRegistry.ZombieType.Z001Norm if roll <= 20 else (CharacterRegistry.ZombieType.Z003Cone if roll <= 50 else (CharacterRegistry.ZombieType.Z005Bucket if roll <= 95 else CharacterRegistry.ZombieType.Z008Football))
	# 使用同排原版生成高度，横坐标在魅惑菇所在格中心。
	var position: Vector2 = _rows[unit.cell.x].zombie_create_position.global_position
	position.x = _cells[unit.cell.x][unit.cell.y].get_global_rect().get_center().x
	# 先走原版工厂登记，再魅惑，确保阵营、朝向、攻击目标、数量列表都由原流程更新。
	var zombie: Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(type, _rows[unit.cell.x], {Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm, Zombie000Base.E_ZInitAttr.Lane: unit.cell.x}, position, _tag_hypno_summon)
	zombie.be_hypno()


## 给未入树的[param zombie]标记友军召唤来源，原版初始化后仍使用其正常生命与护甲。
func _tag_hypno_summon(zombie: Zombie000Base) -> void:
	zombie.set_meta("currency_war_summon", true)
	zombie.is_can_death_language = false
