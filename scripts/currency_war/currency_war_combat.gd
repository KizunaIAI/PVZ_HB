## 本模式装备、羁绊、攻击动作叠层和机枪头盔大招；不替未定义植物添加星级属性。
extends Node

## 已定义的普通装备属性与配方。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 整局规则类型，装备记录独立于战斗节点生命周期。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 已定义冰球、大豌豆与紫球共用原版豌豆场景，只扩展模式专有命中效果。
const SpecialPea = preload("res://scripts/currency_war/currency_war_pea_bullet.gd")
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


## 给新建[param plant]记录原版基础攻击并连接[param unit_id]的攻击动作；节点重建不重置本局装备。
func register_plant(plant: Plant000Base, unit_id: int) -> void:
	# 发射类组件在一次攻击动画开始时计数，不按多发子弹、命中或大招弹丸计数。
	var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
	if attack != null:
		# 只读取一个未入树的原版子弹以取得该植物真实基础伤害，随后立即释放。
		var sample: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack.attack_bullet_type).instantiate()
		plant.set_meta("war_base_damage", sample.attack_value if sample is Bullet000NormBase else 0)
		sample.free()
		attack.signal_attack_action.connect(_on_attack_action.bind(unit_id))
		attack.currency_war_bullet_factory = _create_attack_bullet.bind(unit_id)
	# 爆炸是一轮攻击动作，原版土豆地雷爆炸结束后才累计下一轮装备属性。
	var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
	if bomb != null:
		plant.set_meta("war_base_damage", bomb.bomb_value)
		bomb.signal_bomb_once.connect(_on_attack_action.bind(unit_id))


## 从[param original_type]建立[param unit_id]的实时伤害子弹；只判定已确认规则，尚待确认的组合概率不自行补写。
func _create_attack_bullet(original_type: int, unit_id: int) -> Bullet000Base:
	# 攻击动画可能在植物被消耗的同帧回调，缺少记录时仅返回原版实例。
	var unit: Dictionary = _run.find_unit(unit_id)
	# 类型默认沿用原版，特殊火球只替换本颗实例，不更改植物共享场景。
	var bullet_type: int = original_type
	# 双发二星20%火球已经明确；三星火球与紫球的组合判定仍等待用户确认。
	if not unit.is_empty() and int(unit.type) == 8 and int(unit.star) == 2 and _random.randf() < 0.2:
		bullet_type = BulletRegistry.BulletType.Bullet006PeaFire
	# 火球复用原版动画、解冻和溅射；普通与寒冰子弹保持对应原版场景。
	var bullet: Bullet000NormBase = Global.bullet_registry.get_bullet_scenes(bullet_type).instantiate() as Bullet000NormBase
	if is_instance_valid(_plants.get(unit_id)):
		# 工厂在发射瞬间读取攻击，旧弹不随新装备叠层再次变强。
		var plant: Plant000Base = _plants[unit_id]
		bullet.attack_value = int(plant.get_meta("currency_war_attack_value", bullet.attack_value))
		if bullet_type == BulletRegistry.BulletType.Bullet006PeaFire:
			bullet.attack_value *= 2
		bullet.set_meta("currency_war_execute", plant.get_meta("currency_war_execute", 0.0))
	return bullet


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
		var rate: float = (1.0 + _run.star_speed_bonus(int(unit.type), int(unit.star)) + float(gear.speed) + (float(pea.speed) if is_pea else 0.0)) / float(plant.get_meta("war_base_attack_cd", 1.0)) if attack != null else 0.0
		# 地雷星级倍率来自最新大纲，不把攻速装备擅自转成出土速度。
		var damage_scale: float = [1.0, 1.5, 2.5][int(unit.star) - 1] if int(unit.type) == 5 else 1.0 + star_bonus
		# 所有固定攻击加成在百分比之后，无法攻击的植物不应用攻击装备。
		var damage: float = float(plant.get_meta("war_base_damage", 0)) * damage_scale + float(gear.attack) + (float(pea.attack) if is_pea else 0.0) if attack != null or bomb != null else 0.0
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
		# 最大生命只在确实变化时同步，避免反复刷新产生取整治疗。
		var maximum: int = int(plant.get_meta("war_base_hp")) + int(value.gear.health)
		if maximum != plant.hp_component.max_hp:
			# 新增生命装备不重建植物，现有伤势按比例保留。
			var ratio: float = float(plant.hp_component.curr_hp) / plant.hp_component.max_hp
			plant.hp_component.max_hp = maximum
			plant.hp_component.curr_hp = maxi(1, roundi(maximum * ratio))
		plant.set_meta("currency_war_defense", value.gear.defense)
		plant.set_meta("currency_war_reduction", value.gear.reduction)
		plant.set_meta("currency_war_attack_value", roundi(value.damage))
		plant.set_meta("currency_war_execute", value.gear.execute)
		# 真正的攻击组件沿用原版动画与发射点，只调整动作频率。
		var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
		if attack != null and value.rate > 0.0:
			attack.attack_cd = 1.0 / value.rate
			attack.bullet_attack_cd_timer.wait_time = attack.attack_cd
		# 爆炸仍使用原版范围，装备只改变伤害，不让向日葵获得攻击能力。
		var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
		if bomb != null:
			bomb.bomb_value = roundi(value.damage)


## 每个攻击动作给[param unit_id]增加一次无上限叠层，随后判定一次机枪头盔概率；大招弹丸不反向产生攻击动作。
func _on_attack_action(unit_id: int) -> void:
	if _run.phase != RunRules.Phase.BATTLE or _run.find_unit(unit_id).is_empty():
		return
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
