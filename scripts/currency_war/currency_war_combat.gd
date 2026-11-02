## 本模式装备、羁绊、攻击动作叠层与星级属性；独有设定优先，其余植物使用通用模板。
extends Node

## 已定义的普通装备属性与配方。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 整局规则类型，装备记录独立于战斗节点生命周期。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 磁力菇消化后的实际铁器投掷，保持原版吸铁组件与范围。
const MagnetLogic = preload("res://scripts/currency_war/currency_war_magnet.gd")
## 火炬树桩逐级变弹，只影响本模式当前实例。
const TorchLogic = preload("res://scripts/currency_war/currency_war_torch.gd")
## 吸金菇追踪钱币的目标查询、原版素材和伤害定义。
const CoinProjectile = preload("res://scripts/currency_war/currency_war_coin_projectile.gd")
## 钱币作为独立攻击弹生成，完全隔离可拾取金币及其收入逻辑。
const TRACKING_COIN_SCENE: PackedScene = preload("res://scenes/currency_war/bullets/tracking_coin.tscn")
## 一至三星的累计概率边界：x为银币，y为银币加金币，其余为钻石。
const COIN_CHANCE_LIMITS: Array[Vector2] = [Vector2(0.8, 0.98), Vector2(0.5, 0.95), Vector2(0.1, 0.6)]
## 一至三星路灯花的最终伤害增幅x和攻速增幅y；重叠覆盖按最高星级取一组。
const PLANTERN_BONUS: Array[Vector2] = [Vector2(0.5, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.5)]
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
## 辣椒留下的燃烧区域；仅保存格子、独立剩余时间、每秒伤害，不依赖已经回备战的植株。
var _fires: Array[Dictionary] = []
## 三叶草的临时全屏攻速，按游戏秒独立到期，节点切换自然清除。
var _blover_buffs: Array[Dictionary] = []
## 每株水草本节点已缠过的敌军实例编号，同一株对同一僵尸仅生效一次。
var _kelp_seen: Dictionary = {}
## 尚在生效的水草缠绕窗口，死亡回调只在窗口内发放整局增伤。
var _kelp_roots: Array[Dictionary] = []
## 喂食目标的重检间隔，单位为战斗游戏秒，正常敌军的原版碰撞信号仍即时更新。
var _feeding_elapsed: float = 0.0
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
## 包含路灯花且不含头盔自身循环加成的每株即时属性。
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
	Global.main_game.set_meta("currency_war_chomper_feeding", true)


## 给新建[param plant]记录原版基础攻击并连接[param unit_id]的攻击动作；节点重建不重置本局装备。
func register_plant(plant: Plant000Base, unit_id: int) -> void:
	if plant is Plant022Caltrop:
		plant.set_meta("currency_war_spike_callback", _spike_from_unit.bind(unit_id))
	plant.set_meta("currency_war_guard_damage", _route_guard_damage.bind(unit_id))
	plant.set_meta("currency_war_guard_flatten", _guard_flatten.bind(unit_id))
	if plant is Plant020Tanglekelp:
		plant.set_meta("currency_war_kelp_callback", _kelp_passed.bind(unit_id))
		plant.set_meta("currency_war_ignore_zombie_target", true)
		if not _kelp_seen.has(unit_id):
			_kelp_seen[unit_id] = {}
	if plant is Plant021Jalapeno:
		plant.set_meta("currency_war_jalapeno_callback", _jalapeno_bomb.bind(unit_id))
	if plant is Plant028Blover:
		plant.set_meta("currency_war_blover_callback", _blover_blow.bind(unit_id))
	if plant is Plant023TorchWood:
		plant.set_meta("currency_war_torch_callback", TorchLogic.upgrade.bind(plant, int(_run.find_unit(unit_id).star)))
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
		attack.detect_component.currency_war_fallback_target = _feeding_target.bind(unit_id)
		attack.detect_component.need_judge = true
		if int(plant.plant_type) == 41:
			plant.set_meta("war_gatling_animation_speed", attack.animation_tree.get("parameters/TimeScale 2/scale"))
	if int(plant.plant_type) == 11 and not _fume_elapsed.has(unit_id):
		_fume_elapsed[unit_id] = 0.0
	if plant is Plant011FumeShroom:
		plant.attack_component.currency_war_instant_shot = _fire_fume.bind(unit_id)
	if int(plant.plant_type) == 13 and not _hypno_clocks.has(unit_id):
		_hypno_clocks[unit_id] = {"started": false, "elapsed": 0.0}
	if plant is Plant014ScaredyShroom:
		plant.set_meta("currency_war_scared_callback", _on_scaredy_entered.bind(unit_id))
		plant.scaredy_component.configure_currency_war_query(_scaredy_targets.bind(unit_id))
	if int(plant.plant_type) == 37:
		plant.set_meta("currency_war_garlic_callback", _on_garlic_bitten.bind(plant))
	if plant is Plant032MagnetShroom:
		# 仅在货币战争实体上启用消化后投掷，原版关卡不挂载此组件。
		var magnet_logic: MagnetLogic = MagnetLogic.new()
		magnet_logic.name = "CurrencyWarMagnet"
		plant.add_child(magnet_logic)
		magnet_logic.configure(plant)
	if plant is Plant046GoldMagnet:
		# 复用原版动作的释放帧，模式回调替换吸金，不同时执行旧收入逻辑。
		plant.configure_currency_war(_fire_coin_volley.bind(unit_id), RunRules.PlantTemplate.GOLD_MAGNET_ATTACK_INTERVAL)
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

	if plant is Plant007Chomper:
		plant.set_meta("currency_war_chomper_callback", _chomper_bite.bind(unit_id))
		plant.set_meta("currency_war_accept_bullet", _chomper_accept_bullet.bind(unit_id))
		# 准备换位不能清空尚未结束的消化，跨节点由规则层明确重置。
		var unit: Dictionary = _run.find_unit(unit_id)
		if float(unit.get("chomper_remaining", 0.0)) > 0.0:
			plant.is_chewing = true
			plant.chew_timer.start(float(unit.chomper_remaining))
			var playback: AnimationNodeStateMachinePlayback = plant.get_node("AnimationTree").get("parameters/StateMachine/playback") # 恢复原版咀嚼动画状态。
			playback.start("Chomper_chew")


## 在[param unit_id]大喷菇喷雾开始的同一帧结算原版检测范围内敌人，取消隐形弹飞行造成的延迟。
func _fire_fume(unit_id: int) -> void:
	if _run.phase != RunRules.Phase.BATTLE or not is_instance_valid(_plants.get(unit_id)):
		return
	# 沿用本株检测器的行号、状态与星级射程，不额外扩大攻击范围。
	var plant: Plant011FumeShroom = _plants[unit_id] as Plant011FumeShroom
	if plant == null or plant.is_death:
		return
	# 获取去重快照，伤害可能同步移除敌人。
	var targets: Array[Character000Base] = plant.attack_component.detect_component.get_all_enemy_can_be_attacked()
	# 使用既有模式工厂保留装备、全力攻击、破军、来源与击退，仅取消弹丸实际飞行。
	var bullet: Bullet000NormBase = _create_attack_bullet(plant.attack_component.attack_bullet_type, Vector2.RIGHT, unit_id) as Bullet000NormBase
	bullet.init_bullet(plant.attack_component.get_bullet_paras(plant.attack_component.markers_2d_bullet[0].global_position, Vector2.RIGHT))
	_bullets.add_child(bullet)
	if targets.is_empty():
		var feeding: Plant007Chomper = _feeding_target(unit_id) # 气体没有真实飞行，直接送到同排前方嘴中。
		if feeding != null:
			bullet.try_currency_war_feed(feeding)
	bullet.set_physics_process(false)
	# 同一角色只在检测器快照出现一次，原版穿透承伤与Boss击退豁免继续生效。
	for target: Character000Base in targets:
		if target is Zombie000Base and not target.is_death and not target.is_hypno:
			bullet.attack_once(target)
	bullet.queue_free()


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
	if not unit.is_empty() and int(unit.type) == 27:
		bullet.max_attack_num = [1, 3, -1][clampi(int(unit.star), 1, 3) - 1]
		bullet.set_meta("currency_war_unique_hits", [])
		bullet.set_meta("currency_war_spike_callback", _spike_hit.bind(27, int(unit.star), float(_plants[unit_id].get_meta("currency_war_plantern_damage", 0.0)) if is_instance_valid(_plants.get(unit_id)) else 0.0))
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


## 同步装备、羁绊和路灯花：攻击百分比后加固定值，再乘路灯花最终伤害倍率；生命上限变化保留当前比例。
func sync() -> void:
	if _run == null:
		return
	_run.sync_helmet()
	_stats.clear()
	# 一次读取场上不同种类的羁绊档位，所有豌豆使用同一档普通加成。
	var pea: Dictionary = _run.pea_bonus()
	# 只读取本轮仍存活、上场的路灯花，不将备战、售出或阵亡者纳入光环。
	var lights: Array[Dictionary] = _plantern_sources()
	# 第一遍只计算不含头盔的实时属性，避免头盔把自己的加成重复加回总和。
	for unit_id: int in _plants:
		if not is_instance_valid(_plants[unit_id]):
			continue
		# 阵亡与合成材料可能已从规则移除，不能再参与属性总和。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty() or unit.cell == RunRules.BENCH_CELL:
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
		# 实际占格与光环范围相交即可生效，多个路灯花只保留最高星级一份。
		var light: Vector2 = _plantern_bonus(unit, lights)
		# 普通发射、咀嚼、地刺动画与加农炮充能都有原版频率；一次性爆炸没有重复攻击间隔。
		var rate: float = (1.0 + _run.star_speed_bonus(int(unit.type), int(unit.star)) + float(gear.speed) + light.y + _blover_speed() + (float(pea.speed) if is_pea else 0.0)) / base_interval if base_interval > 0.0 else 0.0
		# 地雷星级倍率来自最新大纲，不把攻速装备擅自转成出土速度。
		var damage_scale: float = [1.0, 1.5, 2.5][int(unit.star) - 1] if int(unit.type) == 5 else 1.0 + star_bonus
		if int(unit.type) == 7:
			# 本节点吞噬与喂食的百分比相加，固定装备攻击仍在百分比之后添加。
			damage_scale += int(unit.get("chomper_eaten", 0)) * [0.1, 0.3, 0.5][clampi(int(unit.star), 1, 3) - 1] + int(unit.get("chomper_bullets", 0)) * [0.01, 0.015, 0.03][clampi(int(unit.star), 1, 3) - 1]
		# 所有固定攻击加成在百分比之后，无法攻击的植物不应用攻击装备。
		var damage: float = float(plant.get_meta("war_base_damage", 0)) * damage_scale + float(gear.attack) + (float(pea.attack) if is_pea else 0.0) if float(plant.get_meta("war_base_damage", 0)) > 0.0 else 0.0
		# 用户确认光环为独立最终倍率，例如升星后的30点伤害在一星路灯花下变为45。
		damage *= 1.0 + light.x
		_stats[unit_id] = {"rate": rate, "damage": damage, "gear": gear, "pea": is_pea, "plantern_damage": light.x}
	# 第二遍只给玩家选择的唯一佩戴者加上其他豌豆的实时属性，不含自身。
	if _stats.has(_run.helmet_unit_id):
		# 已佩戴头盔者的记录与其他单位不同，不将总和写回共享装备定义。
		var wearer: Dictionary = _stats[_run.helmet_unit_id]
		# 逐株求和，同种多株能贡献属性，但不重复增加羁绊种类。
		for unit_id: int in _stats:
			if unit_id != _run.helmet_unit_id and _stats[unit_id].pea:
				wearer.rate += _stats[unit_id].rate * 0.05
				# 其他豌豆先按各自范围得到实时伤害；头盔转移后再应用佩戴者自身的最终增伤。
				wearer.damage += _stats[unit_id].damage * 0.05 * (1.0 + float(wearer.plantern_damage))
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
		# 坚果独有生命增幅只作用原版基础血量，再追加固定装备生命，不反复累乘。
		var health_scale: float = [1.0, 1.7, 2.2][clampi(int(unit.star), 1, 3) - 1] if int(unit.type) == 4 else ([1.0, 2.0, 6.0][clampi(int(unit.star), 1, 3) - 1] if int(unit.type) == 24 else 1.0)
		# 最大生命只在确实变化时同步，避免反复刷新产生取整治疗；开发者最终覆盖保持最高优先级。
		var maximum: int = int(override.health) if not override.is_empty() else roundi(float(plant.get_meta("war_base_hp")) * health_scale) + int(value.gear.health)
		if maximum != plant.hp_component.max_hp:
			# 新增生命装备不重建植物，现有伤势按比例保留。
			var ratio: float = float(plant.hp_component.curr_hp) / plant.hp_component.max_hp
			plant.hp_component.max_hp = maximum
			plant.hp_component.curr_hp = maxi(1, roundi(maximum * ratio))
		if int(unit.type) == 24:
			plant.set_meta("currency_war_damage_cap", [1000, 700, 500][clampi(int(unit.star), 1, 3) - 1])
		plant.set_meta("currency_war_defense", value.gear.defense)
		plant.set_meta("currency_war_reduction", value.gear.reduction)
		plant.set_meta("currency_war_attack_value", roundi(value.damage))
		# 独立固定伤害技能和钱币基础差值读取同一份光环，不重复乘普通攻击或升星倍率。
		plant.set_meta("currency_war_plantern_damage", float(value.plantern_damage))
		plant.set_meta("currency_war_execute", value.gear.execute)
		if int(unit.type) == 37:
			plant.set_meta("war_garlic_poison_damage", roundi(GARLIC_POISON_DAMAGE[clampi(int(unit.star), 1, 3) - 1] * (1.0 + float(value.plantern_damage))))
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
		# 装备只改变爆炸伤害；毁灭菇的全屏目标由手动释放组件控制，其他炸弹沿用原版范围。
		var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
		if bomb != null:
			bomb.bomb_value = roundi(value.damage)
		if plant is Plant032MagnetShroom and value.rate > 0.0:
			plant.get_node("CurrencyWarMagnet").set_interval(1.0 / float(value.rate))
		if plant is Plant046GoldMagnet and value.rate > 0.0:
			plant.set_currency_war_attack_interval(1.0 / float(value.rate))
		if plant is Plant007Chomper:
			# 只缩短消化时间，不把吞噬成长擅自变成整套攻击动画加速。
			plant.eat_CD = maxf(0.001, float(plant.get_meta("war_base_attack_cd", 40.0)) * pow([0.9, 0.85, 0.8][clampi(int(unit.star), 1, 3) - 1], int(unit.get("chomper_eaten", 0))))
			plant.chew_timer.wait_time = maxf(0.001, plant.eat_CD / maxf(0.001, float(plant.get_meta("currency_war_chomper_speed", 1.0))))
		RunRules.PlantTemplate.apply_special_attack(plant, roundi(value.damage), float(value.rate))


## 返回保护[param unit_id]的最近存活高坚果；防护阵营不互相转伤，同距离按先上场记录稳定选择。
func _guard_for(unit_id: int) -> Plant024TallNut:
	# 所有范围以逻辑真实占格为准，备战与已经回备战的临时实体不参与。
	var unit: Dictionary = _run.find_unit(unit_id)
	if unit.is_empty() or unit.cell == RunRules.BENCH_CELL or "防护" in RunRules.CATALOG[unit.type].get("traits", [RunRules.CATALOG[unit.type].trait]):
		return null
	# 保留最短的世界坐标距离，身体待机动画不改变脚点距离。
	var best_distance: float = INF
	# 多株范围重叠时只转给一株，避免重复承担同一次伤害。
	var guard: Plant024TallNut = null
	# 候选必须同时拥有场上记录与活着的战斗实体。
	for id: int in _plants:
		# 本次候选记录可能刚被死亡回调移除。
		var candidate: Dictionary = _run.find_unit(id)
		# 只认高坚果的防护能力，不给同阵营未来植物擅自添加能力。
		var plant: Plant024TallNut = _plants[id] as Plant024TallNut
		if candidate.is_empty() or candidate.cell == RunRules.BENCH_CELL or plant == null or plant.is_death or plant.hp_component.curr_hp <= 0:
			continue
		# 双格植物任一实际占格被覆盖即可保护；边缘区域自然裁剪。
		for part: Vector2i in _run.occupied_cells(int(unit.type), unit.cell):
			if absi(part.x - int(candidate.cell.x)) > 1 or absi(part.y - int(candidate.cell.y)) > 1:
				continue
			# 距离取两株的实际脚点，单位为世界像素的平方。
			var distance: float = plant.global_position.distance_squared_to(_plants[unit_id].global_position)
			if distance < best_distance:
				guard = plant
				best_distance = distance
	return guard


## 将[param attack_value]转移到保护[param unit_id]的高坚果，返回是否成功接管；其余参数沿用血量组件的原版承伤语义。
## [param mode]为伤害模式，[param drop]为死亡掉落，[param sound]为受击音效，[param drop_extra]为额外掉落条件。
func _route_guard_damage(attack_value: int, mode: BulletRegistry.AttackMode, drop: bool, sound: bool, drop_extra: bool, unit_id: int) -> bool:
	# 防护阵营已在查询中排除，因此不会递归转伤或互相形成循环。
	var guard: Plant024TallNut = _guard_for(unit_id)
	if guard == null:
		return false
	guard.hp_component.Hp_loss(attack_value, mode, drop, sound, drop_extra)
	return true


## 阻止[param unit_id]被压扁；由自身或最近高坚果承担一次其星级上限伤害，无保护返回false。
func _guard_flatten(unit_id: int) -> bool:
	# 自身高坚果也享受不被压扁，其他防护阵营不能借此互相转伤。
	var unit: Dictionary = _run.find_unit(unit_id)
	if unit.is_empty() or not is_instance_valid(_plants.get(unit_id)):
		return false
	# 自身为高坚果时直接承伤，否则按玩家确认的最近者查找。
	var guard: Plant024TallNut = _plants[unit_id] as Plant024TallNut if int(unit.type) == 24 else _guard_for(unit_id)
	if guard == null or guard.is_death:
		return false
	guard.hp_component.Hp_loss(int(guard.get_meta("currency_war_damage_cap", 1000)), BulletRegistry.AttackMode.Hammer, true, false)
	return true


## 返回当前存活上场路灯花的位置、星级快照，供一次属性同步复用；准备换位或死亡后重新收集。
func _plantern_sources() -> Array[Dictionary]:
	# 光环仅保存纯数值，避免随后查询时使用已经释放的实体引用。
	var sources: Array[Dictionary] = []
	# 只遍历控制器实际持有的场上实体。
	for unit_id: int in _plants:
		# 规则记录与实体必须同时存在，备战植物不提供光环。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty() or int(unit.type) != 26 or unit.cell == RunRules.BENCH_CELL or not is_instance_valid(_plants[unit_id]) or _plants[unit_id].is_death:
			continue
		sources.append({"cell": unit.cell, "star": clampi(int(unit.star), 1, 3)})
	return sources


## 返回[param unit]被[param sources]覆盖时的最高星级光环；x为最终伤害增幅，y为攻速增幅，无覆盖返回零向量。
func _plantern_bonus(unit: Dictionary, sources: Array[Dictionary]) -> Vector2:
	if unit.cell == RunRules.BENCH_CELL:
		return Vector2.ZERO
	# 只保留最高覆盖星级，实现不同星级和同星级均不叠加。
	var strongest: int = 0
	# 3×3按实际行列各相差不超过一格，地图边缘自然裁剪，不依赖身体动画或像素偏移。
	for source: Dictionary in sources:
		# 双格加农炮任一实际占格位于范围内即可获益，其余植物只有一格。
		for cell: Vector2i in _run.occupied_cells(int(unit.type), unit.cell):
			if absi(cell.x - int(source.cell.x)) <= 1 and absi(cell.y - int(source.cell.y)) <= 1:
				strongest = maxi(strongest, int(source.star))
				break
	return PLANTERN_BONUS[strongest - 1] if strongest > 0 else Vector2.ZERO


## 为[param unit_id]吸金菇发射一轮五枚钱币，各枚独立抽取，整轮仅计一次攻击动作。
func _fire_coin_volley(unit_id: int) -> void:
	if _run.phase != RunRules.Phase.BATTLE or not is_instance_valid(_plants.get(unit_id)):
		return
	# 模式逻辑记录可能已因出售、阵亡或准备换位移除。
	var unit: Dictionary = _run.find_unit(unit_id)
	# 本株提供原版动画释放点和同步后的面板攻击。
	var plant: Plant046GoldMagnet = _plants[unit_id] as Plant046GoldMagnet
	if unit.is_empty() or plant == null or plant.is_death:
		return
	# 全场无敌军时不发空弹、不累计攻击叠层。
	var target: Zombie000Base = CoinProjectile.select_target()
	if target == null:
		return
	_on_attack_action(unit_id)
	# 本轮统一读取当前星级，概率不套用通用升星攻击增幅。
	var limits: Vector2 = COIN_CHANCE_LIMITS[clampi(int(unit.star), 1, 3) - 1]
	# 五枚可重复抽到相同类型，每枚独立随机，伤害不会整轮共用一次结果。
	for index: int in range(5):
		# 单次均匀随机数对应当前星级累计概率。
		var roll: float = _random.randf()
		# 钱币类型与素材、基础伤害的下标保持一致。
		var kind: int = 0 if roll < limits.x else (1 if roll < limits.y else 2)
		# 各钱币为独立命中一次的追踪弹，目标死亡后由自身重选。
		var projectile: CoinProjectile = TRACKING_COIN_SCENE.instantiate() as CoinProjectile
		projectile.coin_kind = kind
		# 银币面板已含路灯花，金币/钻石补足的基础差值也只乘一次光环，固定装备不重复追加。
		projectile.attack_value = maxi(0, roundi(float(plant.get_meta("currency_war_attack_value", 20)) + (CoinProjectile.COIN_DAMAGE[kind] - CoinProjectile.COIN_DAMAGE[0]) * (1.0 + float(plant.get_meta("currency_war_plantern_damage", 0.0)))))
		projectile.set_meta("currency_war_execute", plant.get_meta("currency_war_execute", 0.0))
		projectile.init_bullet({
			Bullet000NormBase.E_InitParasAttr.Position: _bullets.to_local(plant.marker_2d_coin.global_position),
			Bullet000NormBase.E_InitParasAttr.BulletLane: plant.lane,
			Bullet000NormBase.E_InitParasAttr.IsActivateLane: false,
			Bullet000NormBase.E_InitParasAttr.Direction: Vector2.from_angle(lerpf(-0.6, 0.6, float(index) / 4.0)),
			Bullet000NormBase.E_InitParasAttr.Enemy: target,
			Bullet000NormBase.E_InitParasAttr.SourceCharacter: plant,
		})
		_bullets.add_child(projectile)


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
	_update_feeding_targets(delta)
	_update_special_plants(delta)
	_update_poison(delta)
	_update_temporary_effects(delta)
	# 最后一只僵尸可能刚被毒击杀并触发节点结算，本帧也停止回复和大招。
	if _run.phase != RunRules.Phase.BATTLE:
		return
	_regen_time += delta
	if _regen_time >= 1.0:
		# 游戏速度较快时按实际经过的整秒恢复，不丢失回复次数。
		var seconds: int = floori(_regen_time)
		_regen_time -= seconds
		# 每件生命吊坠贡献最大生命2%回复，坚果二/三星另有2%/4%，合并后截到最大生命。
		for unit_id: int in _stats:
			if is_instance_valid(_plants.get(unit_id)) and not _plants[unit_id].is_death:
				# 植物生命组件保持原版死亡处理，不对已死亡实体复活。
				var hp: HpComponent = _plants[unit_id].hp_component
				# 规则记录用来区分坚果独有再生与装备再生，不赋予其他植物额外回血。
				var unit: Dictionary = _run.find_unit(unit_id)
				# 无装备时一星坚果不回血，二/三星分别按当前最大生命计算。
				var regen: float = float(_stats[unit_id].gear.regen) + ([0.0, 0.02, 0.04][clampi(int(unit.star), 1, 3) - 1] if not unit.is_empty() and int(unit.type) == 4 else 0.0)
				hp.curr_hp = mini(hp.max_hp, hp.curr_hp + roundi(hp.max_hp * regen * seconds))
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


## 返回[param unit_id]后排发射植物可喂食的最近前方大嘴花；本行任何存活敌军都会禁止喂食。
func _feeding_target(unit_id: int) -> Plant007Chomper:
	# 只有正式战斗的上场源植物可以主动攻击喂食目标。
	var source: Dictionary = _run.find_unit(unit_id)
	if _run.phase != RunRules.Phase.BATTLE or source.is_empty() or source.cell == RunRules.BENCH_CELL or not is_instance_valid(_plants.get(unit_id)) or _plants[unit_id].is_death:
		return null
	# 僵尸在射程外也算本行有敌人，不能趁未进入攻击射线时喂食。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie) and not zombie.is_death and not zombie.is_hypno and zombie.lane == source.cell.x:
			return null
	# 后方多株射手都瞄准最先遇到的大嘴花，前方的大嘴花不会穿过后一株吃弹。
	var nearest: Plant007Chomper = null
	# 用真实脚点的水平距离排序，不受待机身体变形影响。
	var best_x: float = INF
	# 只有实际存活的场上大嘴花参与喂食。
	for id: int in _plants:
		var unit: Dictionary = _run.find_unit(id) # 当前候选的逻辑位置。
		var plant: Plant007Chomper = _plants[id] as Plant007Chomper # 非大嘴花类型转换为空。
		if unit.is_empty() or unit.cell == RunRules.BENCH_CELL or plant == null or plant.is_death or unit.cell.x != source.cell.x:
			continue
		if plant.global_position.x > _plants[unit_id].global_position.x and plant.global_position.x < best_x:
			nearest = plant
			best_x = plant.global_position.x
	return nearest


## 按[param delta]游戏秒重检无敌军时的喂食目标；目标没变化不重启原版攻击计时器。
func _update_feeding_targets(delta: float) -> void:
	_feeding_elapsed += delta
	if _feeding_elapsed < 0.2:
		return
	_feeding_elapsed = 0.0
	# 活着的原版发射组件仍管理自身冷却与射击动画。
	for unit_id: int in _plants:
		if not is_instance_valid(_plants[unit_id]) or _plants[unit_id].is_death:
			continue
		var attack: AttackComponentBulletBase = _plants[unit_id].get_node_or_null("AttackComponent") as AttackComponentBulletBase # 仅为发射类添加喂食。
		if attack == null:
			continue
		var target: Plant007Chomper = _feeding_target(unit_id) # 当前空行目标可能因新僵尸到来而消失。
		if target != attack.detect_component.get_meta("currency_war_last_feeding", null):
			attack.detect_component.set_meta("currency_war_last_feeding", target)
			attack.detect_component.need_judge = true


## [param bullet]到达[param unit_id]大嘴花时吞掉整颗并增加一次喂食成长；返回是否接收。
func _chomper_accept_bullet(bullet: Bullet000NormBase, unit_id: int) -> bool:
	# 子弹是否仍存在由碰撞入口检查；这里严格判断来源和本行敌军。
	var unit: Dictionary = _run.find_unit(unit_id)
	if _run.phase != RunRules.Phase.BATTLE or unit.is_empty() or unit.cell == RunRules.BENCH_CELL or not is_instance_valid(_plants.get(unit_id)) or _plants[unit_id].is_death or bullet.lane != unit.cell.x:
		return false
	# 原版射击源被卖掉后弹丸仍可到达，退回使用该弹实际出生点判断后方。
	var origin_x: float = bullet.source_character.global_position.x if is_instance_valid(bullet.source_character) else _bullets.to_global(bullet.start_pos).x
	if origin_x >= _plants[unit_id].global_position.x:
		return false
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie) and not zombie.is_death and not zombie.is_hypno and zombie.lane == unit.cell.x:
			return false
	unit["chomper_bullets"] = int(unit.get("chomper_bullets", 0)) + 1
	sync()
	return true


## [param zombie]在[param unit_id]大嘴花的原版啃咬帧受击，真正吞死后才获得吞噬成长。
func _chomper_bite(zombie: Zombie000Base, unit_id: int) -> void:
	# 咀嚼中重复动画回调不能额外吞噬或重置计时。
	var unit: Dictionary = _run.find_unit(unit_id)
	var plant: Plant007Chomper = _plants.get(unit_id) as Plant007Chomper # 当前原版实体，不保存跨节点引用。
	if _run.phase != RunRules.Phase.BATTLE or unit.is_empty() or plant == null or plant.is_death or plant.is_chewing or not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	plant.is_chewing = true
	zombie.set_meta("currency_war_consumed", true)
	_on_attack_action(unit_id)
	zombie.be_chomper_eat(plant.eat_attack)
	if is_instance_valid(zombie) and zombie.is_death:
		unit["chomper_eaten"] = int(unit.get("chomper_eaten", 0)) + 1
	elif is_instance_valid(zombie):
		zombie.remove_meta("currency_war_consumed")
	if is_instance_valid(plant) and not plant.is_death:
		sync()
		plant.chew_timer.start()
		unit["chomper_remaining"] = plant.chew_timer.wait_time


## [param zombie]本行死亡时，由最近的空闲大嘴花吸收；已经被大嘴花或墓碑吞噬者吞掉的目标不重复统计。
func enemy_died(zombie: Zombie000Base) -> void:
	if _run.phase != RunRules.Phase.BATTLE or not is_instance_valid(zombie) or zombie.is_hypno or bool(zombie.get_meta("currency_war_consumed", false)):
		return
	# 最短水平距离用于同一行多株空闲大嘴花的稳定分配。
	var best_distance: float = INF
	# 保存逻辑编号而非在异步动画中继续访问旧植物记录。
	var chosen: int = -1
	for id: int in _plants:
		var unit: Dictionary = _run.find_unit(id) # 排除备战及已移除单位。
		var plant: Plant007Chomper = _plants[id] as Plant007Chomper # 仅空闲大嘴花有吸收能力。
		if unit.is_empty() or unit.cell == RunRules.BENCH_CELL or plant == null or plant.is_death or plant.is_chewing or unit.cell.x != zombie.lane:
			continue
		var distance: float = absf(plant.global_position.x - zombie.global_position.x) # 整行尸体均可吸收，不擅自增加距离上限。
		if distance < best_distance:
			best_distance = distance
			chosen = id
	if chosen == -1:
		return
	zombie.set_meta("currency_war_consumed", true)
	var unit: Dictionary = _run.find_unit(chosen) # 本次吸收的持有记录。
	var plant: Plant007Chomper = _plants[chosen] as Plant007Chomper # 同步占用咀嚼，防止同帧吸入多个尸体。
	plant.is_chewing = true
	plant.is_bite = false
	unit["chomper_eaten"] = int(unit.get("chomper_eaten", 0)) + 1
	_on_attack_action(chosen)
	plant.chew_timer.start()
	unit["chomper_remaining"] = plant.chew_timer.wait_time
	var playback: AnimationNodeStateMachinePlayback = plant.get_node("AnimationTree").get("parameters/StateMachine/playback") # 无需伪造一次额外攻击伤害。
	playback.start("Chomper_chew")
	# 复制尸体的纯绘制身体拉向花嘴，原僵尸仍由死亡流程清理列表与波次。
	var corpse: Node2D = zombie.body.duplicate(0) as Node2D
	_bullets.add_child(corpse)
	corpse.global_transform = zombie.body.global_transform
	zombie.body.hide()
	var tween: Tween = create_tween() # 吸收仅为视觉，成长与消化已经同步记账。
	tween.tween_property(corpse, "global_position", plant.hurt_box_component.global_position, 0.3)
	tween.parallel().tween_property(corpse, "scale", Vector2.ONE * 0.15, 0.3)
	tween.tween_callback(corpse.queue_free)


## [param unit_id]地刺的原版直接攻击命中[param zombie]时，按当前星级与光环转入统一状态结算。
func _spike_from_unit(zombie: Zombie000Base, unit_id: int) -> void:
	# 地刺命中与伤害在同一动画帧，不保留失效的来源记录。
	var unit: Dictionary = _run.find_unit(unit_id)
	if not unit.is_empty():
		_spike_hit(zombie, int(unit.type), int(unit.star), float(_plants[unit_id].get_meta("currency_war_plantern_damage", 0.0)) if is_instance_valid(_plants.get(unit_id)) else 0.0)


## [param zombie]命中时施加[param plant_type]、[param star]的尖刺，[param aura]为发射时路灯花增幅；弹丸来源离场后仍生效。
func _spike_hit(zombie: Zombie000Base, plant_type: int, star: int, aura: float) -> void:
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
		return
	# 地刺二/三星提高状态50%/150%，仙人掌状态固定为基础50%反伤。
	var index: int = clampi(star, 1, 3) - 1
	# 同类状态保留最高强度，不因同一敌军的多个受击框重复叠加。
	var ratio: float = [0.5, 0.75, 1.25][index] if plant_type == 22 else 0.5
	zombie.set_meta("currency_war_spike_ratio", maxf(ratio, float(zombie.get_meta("currency_war_spike_ratio", 0.0))))
	if plant_type == 27:
		# 玩家确认以目标当前每秒攻击力的50%乘1/3/5秒，一次性结算额外伤害。
		var attack: AttackComponentZombieNorm = zombie.attack_component as AttackComponentZombieNorm
		if attack != null:
			zombie.hp_component.Hp_loss(roundi(attack.curr_attack_value_per_min * 0.5 * [1.0, 3.0, 5.0][index] * (1.0 + aura)), BulletRegistry.AttackMode.Norm, true, false)


## 为经过[param unit_id]水草原版检测范围的敌军施加一次缠绕及独立毒素，不消耗植株。
func _kelp_passed(unit_id: int) -> void:
	# 准备和预览期间即使碰撞区重叠也不能释放。
	var unit: Dictionary = _run.find_unit(unit_id)
	if _run.phase != RunRules.Phase.BATTLE or unit.is_empty() or unit.cell == RunRules.BENCH_CELL or not is_instance_valid(_plants.get(unit_id)):
		return
	# 原版检测器保留水下目标和短距离，不扩展成全行攻击。
	var plant: Plant020Tanglekelp = _plants[unit_id] as Plant020Tanglekelp
	if plant == null or plant.is_death:
		return
	# 字典按源植株独立保存，同一僵尸可以被不同水草各缠一次。
	var seen: Dictionary = _kelp_seen[unit_id]
	# 星级明确控制缠绕秒数、每秒毒伤、毒素秒数与击杀增伤。
	var index: int = clampi(int(unit.star), 1, 3) - 1
	# 原版检测器已经去重同一僵尸的多个受击框。
	for enemy: Character000Base in plant.detect_component.get_all_enemy_can_be_attacked():
		# 只对敌方存活僵尸执行，不影响魅惑友军。
		var target: Zombie000Base = enemy as Zombie000Base
		if target == null or target.is_death or target.is_hypno or seen.has(target.get_instance_id()):
			continue
		seen[target.get_instance_id()] = true
		target.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.CurrencyWarKelp)
		# 原版藤蔓只复制静态绘制，不调用会强制拖水和杀死敌军的抓取组件。
		var visual: Node2D = plant.grap_component.get_node("Body").duplicate(0) as Node2D
		target.add_child(visual)
		visual.position += Vector2(0, -10)
		# 回调与计时器共享该字典，缠绕结束后即使毒仍在也不再奖励。
		var root: Dictionary = {"target": target, "remaining": [1.0, 1.5, 2.0][index], "bonus": [0.01, 0.015, 0.03][index], "rewarded": false, "visual": visual}
		_kelp_roots.append(root)
		target.signal_character_death.connect(_kelp_killed.bind(root), CONNECT_ONE_SHOT)
		_poisons.append({"target": target, "damage": roundi([20.0, 30.0, 50.0][index] * (1.0 + float(plant.get_meta("currency_war_plantern_damage", 0.0)))), "elapsed": 0.0, "ticks": [3, 5, 7][index], "effect": PoisonEffect.acquire(target)})
		_on_attack_action(unit_id)


## [param root]所缠敌军死亡时只奖励一次；窗口结束、友军或植物已退场均不伪造额外击杀。
func _kelp_killed(root: Dictionary) -> void:
	if float(root.remaining) <= 0.0 or bool(root.rewarded) or not is_instance_valid(root.target) or root.target.is_hypno:
		return
	root.rewarded = true
	_run.kelp_damage_bonus += float(root.bonus)


## 返回当前尚未到期的三叶草全屏攻速增幅，与现有百分比攻速相加。
func _blover_speed() -> float:
	# 每次实际吹风各自产生限时增幅，不改变无攻击植物的行为。
	var bonus: float = 0.0
	# 战斗计时统一由临时效果更新，准备不扣除剩余时间。
	for buff: Dictionary in _blover_buffs:
		bonus += float(buff.speed)
	return bonus


## 在[param unit_id]三叶草的原版吹风帧击退敌军并启动全屏攻速，不吹动魅惑友军。
func _blover_blow(unit_id: int) -> void:
	# 多次调用原版释放帧由植物自身is_blow_away_once防重。
	var unit: Dictionary = _run.find_unit(unit_id)
	if _run.phase != RunRules.Phase.BATTLE or unit.is_empty() or not is_instance_valid(_plants.get(unit_id)) or _plants[unit_id].is_death:
		return
	# 星级只改变文档列出的距离、攻速和时长。
	var index: int = clampi(int(unit.star), 1, 3) - 1
	_blover_buffs.append({"speed": [1.0, 2.0, 9.99][index], "remaining": [2.0, 3.0, 20.0][index]})
	# 死亡或魅惑可能修改管理器数组，遍历快照避免跳过敌人。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		# 三星回到本行原版出怪位置，一/二星按真实格宽击退。
		var distance: float = maxf(0.0, _rows[zombie.lane].zombie_create_position.global_position.x - zombie.global_position.x) if index == 2 else [2.0, 4.0][index] * _lawn_cell_radius().x
		zombie.apply_knockback(distance)
	_on_attack_action(unit_id)


## 返回[param zombie]当前是否位于[param cells]燃烧格内，同行火焰覆盖整个横向草坪，十字交点不重复命中。
func _in_fire(zombie: Zombie000Base, cells: Array[Vector2i]) -> bool:
	# 以真实行号与脚点所属列计算，身体上下摆动不导致漏伤。
	for cell: Vector2i in cells:
		if zombie.lane != cell.x:
			continue
		# 单格燃烧范围使用实际完整列距，包含原版格子间空隙。
		var center: float = _cells[cell.x][cell.y].get_global_rect().get_center().x
		if absf(zombie.global_position.x - center) <= _lawn_cell_radius().x * 0.5:
			return true
	return false


## 在[param unit_id]辣椒原版爆炸帧结算本行、十字或全屏爆炸，并保留独立持续火焰。
func _jalapeno_bomb(unit_id: int) -> void:
	# 亡语仍可使用本次爆炸，规则记录存在且实体有效即可读取释放时属性。
	var unit: Dictionary = _run.find_unit(unit_id)
	if unit.is_empty() or not is_instance_valid(_plants.get(unit_id)):
		return
	# 星级决定区域与持续伤害；初始爆炸沿用原版1800及现有装备计算。
	var index: int = clampi(int(unit.star), 1, 3) - 1
	# 冻结区域坐标，使辣椒回备战或换位不移动旧火焰。
	var cells: Array[Vector2i] = []
	# 只为真正开放的行创建火焰，避免一/三条草坪时烧到未铺区域。
	for lane: int in _run.active_lanes:
		# 同行全覆盖；二星额外覆盖本列；三星覆盖所有格。
		for column: int in range(_cells[lane].size()):
			if lane == unit.cell.x or index == 2 or (index == 1 and column == unit.cell.y):
				cells.append(Vector2i(lane, column))
	# 火焰持续时间和每秒伤害均直接取自文档，路灯花只按释放时位置乘一次。
	var duration: float = [3.0, 5.0, 20.0][index]
	_fires.append({"cells": cells, "remaining": duration, "elapsed": 0.0, "damage": roundi([30.0, 90.0, 100.0][index] * (1.0 + float(_plants[unit_id].get_meta("currency_war_plantern_damage", 0.0))))})
	# 复用原版可设持续时间的火苗，不反复触发额外爆炸伤害。
	for cell: Vector2i in cells:
		# 原版火苗自行播放结束动画，与节点场景共同释放。
		var fire: BombEffectFire = SceneRegistry.FIRE.instantiate() as BombEffectFire
		fire.set_exist_time(duration)
		fire.set_meta("currency_war_duration", true)
		fire.z_index = cell.x * 50 + 40
		fire.z_as_relative = false
		_cells[cell.x][cell.y].add_child(fire)
		fire.global_position = _cells[cell.x][cell.y].global_position + Vector2(_cells[cell.x][cell.y].size.x * 0.5, _cells[cell.x][cell.y].size.y)
		fire.activate_bomb_effect()
		# 火焰接触的梯子移除，原版冰道事件仍按完整燃烧行处理。
		if is_instance_valid(_cells[cell.x][cell.y].ladder):
			_cells[cell.x][cell.y].ladder.queue_free()
	# 同行与全屏保留原版辣椒清冰道行为，十字竖列不凭空清整条横向冰道。
	for lane: int in _run.active_lanes:
		if lane == unit.cell.x or index == 2:
			EventBus.push_event("jalapeno_bomb_item_lane", [lane])
	# 先生成火焰再结算伤害，最后一只敌人死亡触发切节点时不继续创建场景对象。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		# 本行和三星为整行爆炸，二星竖列根据实际列范围判断。
		if zombie.lane == unit.cell.x or index == 2 or (index == 1 and _in_fire(zombie, cells)):
			zombie.cancel_ice()
			zombie.be_bomb(int(_plants[unit_id].get_meta("currency_war_attack_value", 1800)), true)


## 按[param delta]战斗游戏秒推进临时攻速与燃烧；到期时同步真实攻速，连续帧不重复结算同一秒。
func _update_temporary_effects(delta: float) -> void:
	# 先推进已有缠绕窗口，毒伤造成死亡时再按剩余窗口判断奖励。
	for index: int in range(_kelp_roots.size() - 1, -1, -1):
		# 计时记录由死亡回调共享，不能复制成独立字典。
		var root: Dictionary = _kelp_roots[index]
		root.remaining = maxf(0.0, float(root.remaining) - delta)
		if not is_instance_valid(root.target) or root.target.is_death or root.target.is_hypno or float(root.remaining) <= 0.0:
			if is_instance_valid(root.visual):
				root.visual.queue_free()
			_kelp_roots.remove_at(index)
			# 多株水草的缠绕重叠时，最后一个窗口到期才解除该移动因素。
			if is_instance_valid(root.target) and not root.target.is_death:
				var still_rooted: bool = false # 同一敌军是否还被其他水草缠绕。
				for other: Dictionary in _kelp_roots:
					if other.target == root.target and float(other.remaining) > 0.0:
						still_rooted = true
						break
				root.target.move_component.update_move_factor(still_rooted, MoveComponent.E_MoveFactor.CurrencyWarKelp)
	# 仅攻速项到期时重算属性，避免每帧遍历全场装备。
	var speed_changed: bool = false
	# 逆序删除互不影响其他来源的时长。
	for index: int in range(_blover_buffs.size() - 1, -1, -1):
		_blover_buffs[index].remaining -= delta
		if float(_blover_buffs[index].remaining) <= 0.0:
			_blover_buffs.remove_at(index)
			speed_changed = true
	if speed_changed:
		sync()
	# 每片火焰独立累计整秒；返回备战不取消已释放区域。
	for index: int in range(_fires.size() - 1, -1, -1):
		# 本帧只推进剩余有效时间，精确保留最后一整秒的伤害。
		var fire: Dictionary = _fires[index]
		fire.elapsed += minf(delta, float(fire.remaining))
		fire.remaining = maxf(0.0, float(fire.remaining) - delta)
		while float(fire.elapsed) >= 1.0:
			fire.elapsed -= 1.0
			# 持续火焰影响后来进入区域的敌军，同一秒每片火焰只命中一次。
			for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
				if _run.phase != RunRules.Phase.BATTLE:
					return
				if is_instance_valid(zombie) and not zombie.is_death and not zombie.is_hypno and _in_fire(zombie, fire.cells):
					zombie.be_attacked_bullet(int(fire.damage), BulletRegistry.AttackMode.Norm, true, false)
		if float(fire.remaining) <= 0.0:
			_fires.remove_at(index)


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
	# 组件销毁时解除自身停步因素，普通关卡移动因素不受影响。
	for root: Dictionary in _kelp_roots:
		if is_instance_valid(root.target) and not root.target.is_death:
			root.target.move_component.update_move_factor(false, MoveComponent.E_MoveFactor.CurrencyWarKelp)
		if is_instance_valid(root.visual):
			root.visual.queue_free()
	_kelp_roots.clear()
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
	# 只应用本株当前路灯花的最终增伤，不将普通射击的星级或装备攻击再次叠给冲击。
	var burst_damage: int = roundi(SCAREDY_BURST_DAMAGE[star_index] * (1.0 + float(plant.get_meta("currency_war_plantern_damage", 0.0))))
	# 真实格子跨度用于一格击退，保持与地图缩放和镜头坐标一致。
	var distance: float = _lawn_cell_radius().x
	# 目标来自触发瞬间，不在延迟回调中重新裁剪边缘，避免一帧移动使触发者漏判。
	for zombie: Zombie000Base in targets:
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		zombie.be_attacked_bullet(burst_damage, BulletRegistry.AttackMode.Norm, true, false)
		if star_index == 2 and not zombie.is_death:
			zombie.apply_knockback(distance)


## 返回当前存活上场阳光菇的晒伤百分比之和；实时读取成长状态，离场立即失效，不作用于友军。
func _sunburn_bonus() -> float:
	# 不设置上限或额外羁绊，按用户确认的多株相加。
	var bonus: float = _run.kelp_damage_bonus
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


## 以[param delta]游戏秒推进大喷菇充能、魅惑菇召唤与磁力菇投掷，准备、暂停、节点结束时均不处理。
func _update_special_plants(delta: float) -> void:
	# 字典快照允许召唤或死亡回调改变实体映射。
	for unit_id: int in _plants.keys():
		# 只为活着的上场植物推进计时。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty() or not is_instance_valid(_plants[unit_id]) or _plants[unit_id].is_death:
			continue
		if int(unit.type) == 7:
			# 持有记录保存未结束的本节点咀嚼，准备换位时由新实体恢复。
			unit["chomper_remaining"] = _plants[unit_id].chew_timer.time_left
		elif int(unit.type) == 11:
			_fume_elapsed[unit_id] = minf(5.0, float(_fume_elapsed.get(unit_id, 0.0)) + delta)
		elif int(unit.type) == 20:
			_kelp_passed(unit_id)
		elif int(unit.type) == 32:
			_plants[unit_id].get_node("CurrencyWarMagnet").try_throw()
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
