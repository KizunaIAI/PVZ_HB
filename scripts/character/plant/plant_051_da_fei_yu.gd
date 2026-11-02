## 植物阵营大肥鱼：原始体型朝右，保留视频交互，以较低频率产阳光、召唤友军、换行和主动砸盆。
extends Plant000Base

## 每个完整技能结束后的等待游戏秒，显著低于Boss每2秒选招的频率。
@export var skill_interval: float = 10.0
## 钢盆直接命中伤害，沿用Boss默认值。
@export var basin_damage: int = 100
## 允许命中的世界距离，目标离开锁定落点可以躲开。
@export var basin_hit_radius: float = 45.0
## 常规随机僵尸池，生成前按出生行地形过滤。
const POOL: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 15, 17, 19, 22, 25]
## 召唤脚底法阵，与Boss共享美术资源。
const CIRCLE: PackedScene = preload("res://scenes/fx/da_fei_yu_summon_effect.tscn")
## 当前技能冷却剩余原速秒数。
var _remaining: float = 10.0
## 个体控制倍率，暂停由场景树继承。
var _speed: float = 1.0
## 下潜后计划转移的植物格子，提交时重新检查占用。
var _destination: PlantCell
## 共用原Boss视频外观，只有外观镜像，不镜像文字。
@onready var visual: Node2D = $Body/DaFeiYuVisual


## 初始化植物受击、种植及视频回调；图鉴和卡面只播放待机，不启动技能或Boss音乐。
func _ready() -> void:
	is_death_free = false
	super._ready()
	visual.get_node("TokenText").caption = "Token回"
	visual.get_node("TokenText").scale.x = -1.0
	visual.entrance_finished.connect(_reset_interval)
	visual.skill_finished.connect(_reset_interval)
	visual.attack_finished.connect(_reset_interval)
	visual.dream_finished.connect(_finish_dream)
	visual.skill_triggered.connect(_skill_triggered)
	visual.lane_submerged.connect(_change_lane)
	visual.basin_arrived.connect(_basin_arrived)
	visual.exit_finished.connect(_exit_finished)
	_remaining = skill_interval
	if character_init_type == E_CharacterInitType.IsNorm:
		hp_component.show()
		visual.play_entrance()
	else:
		visual.play_idle()


## [param delta]为游戏帧秒数；仅正式出战的待机阶段选招，不截断任何视频动作。
func _process(delta: float) -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm or visual.phase != &"idle":
		return
	_remaining -= delta * _speed
	if _remaining > 0.0:
		return
	# 每次只从有条件执行的动作中随机抽一项，避免无空地时反复换行。
	var actions: Array[StringName] = [&"token", &"summon", &"dream"]
	# 下潜前锁定目标格，完整下潜后再验证。
	var destinations: Array[PlantCell] = _lane_destinations()
	_destination = destinations.pick_random() if not destinations.is_empty() else null
	if _destination != null:
		actions.append(&"lane_dive")
	# 本轮技能，所有动作共用相同的低频间隔。
	var action: StringName = actions.pick_random()
	if action == &"dream":
		visual.play_attack_1()
	else:
		visual.play_skill(action)


## 每次完整演出结束后重置等待，不按原Boss受击条件启动反击。
func _reset_interval() -> void:
	_remaining = skill_interval


## 返回本列其他开放且允许种植的空格，保持睡莲、花盆、地形与占用判定。
func _lane_destinations() -> Array[PlantCell]:
	# 候选格子只保留可以真实承接本株植物的空位。
	var result: Array[PlantCell] = []
	# 当前游戏与本植物的种植条件。
	var game: MainGameManager = Global.main_game
	# 用原种植条件筛选水路、屋顶及同层占用。
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	# 货币战争开放行；其他模式没有此限制。
	var active: Array = game.get_meta("currency_war_active_lanes", [])
	# 实际地图行号，列保持当前列。
	for index: int in range(game.plant_cell_manager.all_plant_cells.size()):
		if index == lane or (game.has_meta("currency_war_active_lanes") and not active.has(index)):
			continue
		# 目标格子使用原工厂中的相同合法性条件。
		var cell: PlantCell = game.plant_cell_manager.all_plant_cells[index][row_col.y]
		if condition.judge_is_can_plant(cell, plant_type):
			result.append(cell)
	return result


## 下潜结束后提交移动，同步植物格子、死亡回调、行号及货币战争逻辑单位，不复制植物。
func _change_lane() -> void:
	if is_death or not is_instance_valid(_destination) or not _lane_destinations().has(_destination):
		return
	# 普通植物层号，地形与壳层保持原位。
	var layer: int = CharacterRegistry.PlacePlantInCell.Norm
	# 死亡时应释放新格子，不能继续通知旧格。
	var old_callback: Callable = plant_cell.one_plant_free.bind(self)
	if signal_character_death.is_connected(old_callback):
		signal_character_death.disconnect(old_callback)
	plant_cell.plant_in_cell[layer] = null
	plant_cell = _destination
	row_col = plant_cell.row_col
	lane = row_col.x
	plant_cell.plant_in_cell[layer] = self
	signal_character_death.connect(plant_cell.one_plant_free.bind(self))
	reparent(plant_cell.plant_container_node[layer], false)
	position = Vector2.ZERO
	GlobalUtils.update_plant_cell_slope_y_array(plant_cell, node2d_detect_in_slope)
	# 对应模式的逻辑记录，防止下一次装备刷新或切节点把本株移回旧行。
	var game: MainGameManager = Global.main_game
	if "_run" in game:
		# 以真实植物实例定位逻辑编号，不依赖显示名称。
		for id: int in game._plants:
			if game._plants[id] == self:
				game._run.find_unit(id)["cell"] = row_col
				break
	_destination = null


## [param action]为视频关键帧所属技能；只有正式出战存活时结算。
func _skill_triggered(action: StringName) -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm:
		return
	if action == &"token":
		_produce_sun()
	elif action == &"summon":
		_summon_allies()


## Token回随机生成1至2颗阳光，每颗计1点，可点击收集；保持正常可见大小。
func _produce_sun() -> void:
	# 本次阳光实体数量，单颗价值为1点，不直接改玩家余额。
	var count: int = randi_range(1, 2)
	# 逐颗向角色前上方弹出，拾取事件沿用原版Sun。
	for index: int in range(count):
		# 每颗独立阳光，随游戏场景统一清理。
		var sun: Sun = SceneRegistry.SUN.instantiate()
		sun.init_sun(1, Global.main_game.suns.to_local(global_position + Vector2(0, -85)))
		Global.main_game.suns.add_child(sun)
		sun.scale = Vector2.ONE * 0.7
		# 弹出至脚前，沿用原阳光落地后的自动收集接口。
		var tween: Tween = sun.create_tween()
		tween.tween_property(sun, "position", sun.position + Vector2(25 + index * 25, -30), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sun, "position:y", sun.position.y + 60, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sun.spawn_sun_tween = tween
		tween.finished.connect(sun.on_sun_tween_finished)


## 随机召唤1至2只地形合法的魅惑僵尸，在前一列随机开放行出生，法阵与翘尾帧一致。
func _summon_allies() -> void:
	# 原生僵尸管理器，确保阵营转换前完成正常登记。
	var manager: ZombieManager = Global.main_game.zombie_manager
	# 目标开放行，水路按每行地形选择可用类型。
	var lanes: Array = Global.main_game.get_meta("currency_war_active_lanes", range(manager.all_zombie_rows.size()))
	if lanes.is_empty():
		return
	# 生成数量，与偷取库存无关。
	var count: int = randi_range(1, 2)
	# 每只独立随机行与类型。
	for index: int in range(count):
		# 本只出生行，前一列超右边界时保留在最右列。
		var target_lane: int = lanes.pick_random()
		# 出生行节点提供标准脚底高度。
		var row: ZombieRow = manager.all_zombie_rows[target_lane]
		# 按该行地形筛选的常规召唤池。
		var pool: Array[int] = []
		# 候选类型，Boss及蹦极等特殊类型不在池中。
		for type: int in POOL:
			# 该类型原版允许的行地形。
			var terrain: int = Global.character_registry.get_zombie_info(type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
			if terrain == CharacterRegistry.ZombieRowType.Both or terrain == row.zombie_row_type:
				pool.append(type)
		if pool.is_empty():
			continue
		# 前一列格子，朝右面向敌人。
		var cell: PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[target_lane][mini(row_col.y + 1, 8)]
		# 工厂设置真实位置和行号，再通过原接口魅惑，不伪装为敌军。
		var zombie: Zombie000Base = manager.create_norm_zombie(pool.pick_random(), row, {Zombie000Base.E_ZInitAttr.Lane: target_lane}, Vector2(cell.get_global_rect().get_center().x, row.zombie_create_position.global_position.y), _tag_ally)
		zombie.be_hypno()
		# 脚底法阵复用Boss效果，随友军自身生命周期释放。
		var effect: Node2D = CIRCLE.instantiate()
		zombie.add_child(effect)
		effect.global_scale = Vector2.ONE


## [param zombie]入树前标记友军召唤，避免奖励关一血、清场奖励及额外亡语递归生成。
func _tag_ally(zombie: Zombie000Base) -> void:
	zombie.set_meta("currency_war_summon", true)
	zombie.is_can_death_language = false


## 返回本行最靠近我方的存活敌军，排除魅惑友军；无敌军返回null。
func _front_enemy() -> Zombie000Base:
	# 当前最前排目标，按世界横坐标最小选择。
	var target: Zombie000Base
	# 本行真实敌军快照来源。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_2d[lane]:
		if is_instance_valid(zombie) and not zombie.is_death and not zombie.is_hypno:
			if target == null or zombie.global_position.x < target.global_position.x:
				target = zombie
	return target


## 幻想上完整播完立即锁定本行最前排敌军并播放幻想下，无敌军则完成空投演出。
func _finish_dream() -> void:
	if not is_death:
		visual.play_dream_down(_front_enemy())


## [param target]为离手时锁定的原敌军；删除、魅惑或离开落点后不改选其他目标。
func _basin_arrived(target: Node2D) -> void:
	if not is_death and is_instance_valid(target) and target is Zombie000Base and not target.is_death and not target.is_hypno:
		if target.global_position.distance_to(visual.flight_end_global) <= basin_hit_radius:
			target.be_attacked_bullet(basin_damage, BulletRegistry.AttackMode.Norm, false, false)


## 死亡沿用植物格子释放与管理器登记，再播放完整退场；重复调用不重复登记。
func character_death() -> void:
	if is_death:
		return
	super.character_death()
	hp_component.hide()
	shadow.hide()
	visual.play_exit()


## 退场完成后释放植物节点。
func _exit_finished() -> void:
	if is_death:
		queue_free()


## [param value]与[param factor]沿用植物控制接口，同步所有视频、飘字及技能等待。
func update_speed_factor(value: float, factor: E_Influence_Speed_Factor) -> void:
	super.update_speed_factor(value, factor)
	if is_node_ready() and not is_death:
		_speed = GlobalUtils.get_dic_product(influence_speed_factors)
		visual.set_playback_speed(_speed)
