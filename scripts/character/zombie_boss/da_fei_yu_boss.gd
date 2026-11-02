## 大肥鱼视频 Boss：入场、待机、偷阳光、换行、召唤、幻想丢盆及死亡退场，沿用原生战斗登记。
## 人物仅播放用户视频，独立飞行盆取自离手帧并保持原尺寸、方向和接棒位置；旧骨骼版本保持隔离。
extends Zombie000Base

## 本曲与当前Boss场景共享生命周期，多只Boss不会叠播或反复重启。
const BossMusic = preload("res://scripts/character/zombie_boss/da_fei_yu_boss_music.gd")

## 普通待机后再次施放技能的间隔，单位为原速游戏秒；默认2秒，提高出招频率但不截断技能视频。
@export_range(0.1, 30.0, 0.01) var dream_delay: float = 2.0
## 战斗动作视频倍率；入场、普通待机和退场保留原有速度。
@export var combat_animation_speed: float = 1.0
## Token来单次偷取数量的闭区间，Boss关按大关配置提高，允许余额为负。
@export var sun_steal_range: Vector2i = Vector2i(4, 10)
## 单次召唤数量闭区间，仍只消耗自己的库存，不超支召唤。
@export var summon_count_range: Vector2i = Vector2i(3, 5)
## 丢盆命中的普通伤害，与之前钢盆反击的默认值一致。
@export_range(0, 10000, 1) var basin_damage: int = 100
## 原攻击者脚底与锁定落点的最大命中距离，单位为世界像素；移动离开可躲避。
@export_range(1.0, 200.0, 1.0) var basin_hit_radius: float = 45.0
## 本次同步子弹结算的来源，结算完成后由子弹清空，不用于猜测攻击者。
var _damage_source: Character000Base
## 当前个体控制倍率，供普通待机间隔继承冰冻和减速。
var _speed_factor: float = 1.0
## 普通待机至下一技能开始的剩余原速游戏秒。
var _idle_remaining: float = 2.0
## 偷来的可用阳光，每召唤一只消耗一点，仅本只 Boss 持有。
var stolen_sun: int = 0
## 本只 Boss 累计实际偷取且尚未返还的阳光；召唤花费不扣此账，死亡时全额返还一次。
var _refundable_sun: int = 0
## 清场直接移除时不发放击败奖励，避免开发工具刷取永久伙伴。
var _suppress_plant_reward: bool = false
## 仅绘制从余额UI向Boss飞行的阳光，不参与收集和经济结算。
const StolenSunFlight = preload("res://scripts/fx/other_effect/da_fei_yu_stolen_sun.gd")
## 召唤兵死亡的固定1阳光奖励与自动回收，不依赖本只Boss继续存活。
const SummonSunDrop = preload("res://scripts/fx/other_effect/da_fei_yu_summon_sun.gd")
## 用户确认Token来之后下一次出招的召唤概率，其余20%只选择其他动作。
const TOKEN_SUMMON_CHANCE: float = 0.8
## 本次Token来已成功获得阳光，等待下一次选招消费优先召唤判定。
var _token_followup: bool = false
## 下潜期间锁定的合法目标行，-1表示本次不移动。
var _target_lane: int = -1
## 每只召唤僵尸脚底的法阵，生命周期跟随被召唤僵尸。
const SUMMON_EFFECT: PackedScene = preload("res://scenes/fx/da_fei_yu_summon_effect.tscn")
## 可召唤的常规僵尸池，按行地形进一步过滤，不包含 Boss、蹦极或组合生成单位。
const SUMMON_POOL: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 15, 17, 19, 22, 25]
## 当前视频外观，负责帧播放、暂停与速度同步。
@onready var visual: Node2D = $Body/DaFeiYuVisual


## 复用原僵尸生命与受击登记，并按初始化类型选择入场或展示待机。
func _ready() -> void:
	head1_path_candidate = [NodePath("Body/DaFeiYuVisual/HeadAnchor")]
	super._ready()
	visual.entrance_finished.connect(_reset_dream_delay)
	visual.entrance_music_cue.connect(_start_boss_music)
	visual.exit_finished.connect(_on_exit_finished)
	visual.attack_finished.connect(_reset_dream_delay)
	visual.basin_arrived.connect(_on_basin_arrived)
	visual.skill_finished.connect(_reset_dream_delay)
	visual.skill_triggered.connect(_on_skill_triggered)
	visual.lane_submerged.connect(_on_lane_submerged)
	visual.phase_changed.connect(_update_visual_speed)
	hp_component.set_death_hp(0)
	hp_stage_change_component.boundary_value_hp = [0]
	hp_stage_change_component.body_change = [null]
	if character_init_type == E_CharacterInitType.IsNorm:
		hp_component.show()
		_reset_dream_delay()
		visual.play_entrance()
	else:
		visual.play_idle()


## 所有技能原地进行，关闭行走与普通啃食，保留原版生命、行号和管理器信号。
func ready_norm() -> void:
	super.ready_norm()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)


## [param delta]为游戏帧时长；只在正式出战普通待机时计时，冻结、减速与视频使用同一倍率。
func _process(delta: float) -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm or visual.phase != &"idle":
		return
	_idle_remaining = maxf(0.0, _idle_remaining - delta * _speed_factor)
	if _idle_remaining <= 0.0:
		_start_next_skill()


## 入场、反击或新技能结束后重新开始普通待机间隔，图鉴不触发攻击。
func _reset_dream_delay() -> void:
	_idle_remaining = dream_delay


## 正式出战且存活时，在叉腰关键帧开始背景音乐；图鉴静态展示不抢占音乐。
func _start_boss_music() -> void:
	if not is_death and character_init_type == E_CharacterInitType.IsNorm:
		BossMusic.acquire(self)


## [param source]为当前子弹发射者；null 清除同步结算的来源，无来源伤害不会引发反击。
func set_damage_source(source: Character000Base) -> void:
	_damage_source = source


## [param attack_value]为本次伤害，[param bullet_mode]、[param is_drop]、[param trigger_be_attack_SFX]沿用原版结算。
## 仅有效植物造成的非致死正伤害可打破幻想，同一轮后续受击不会重复发盆。
func be_attacked_bullet(attack_value: int, bullet_mode: BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm, is_drop: bool = true, trigger_be_attack_SFX := true):
	if is_death:
		return
	super.be_attacked_bullet(attack_value, bullet_mode, is_drop, trigger_be_attack_SFX)
	if not is_death and attack_value > 0 and is_instance_valid(_damage_source) and _damage_source is Plant000Base and not _damage_source.is_death:
		visual.react_to_hit(_damage_source)


## [param attacker]为原攻击者，删除或移动离开落点后不会追伤或改打其他植物。
func _on_basin_arrived(attacker: Node2D) -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm:
		return
	if is_instance_valid(attacker) and attacker is Plant000Base and attacker.is_inside_tree() and not attacker.is_death:
		if attacker.global_position.distance_to(visual.flight_end_global) <= basin_hit_radius:
			attacker.set_damage_source(self)
			attacker.be_attacked_bullet(basin_damage, BulletRegistry.AttackMode.Norm, true, false)
			if is_instance_valid(attacker):
				attacker.set_damage_source(null)


## 死亡时立即停止战斗并完成一次管理器死亡登记，再完整播放用户退场视频，不套用普通淡出。
func character_death() -> void:
	if is_death:
		return
	# 先还款再发管理器死亡信号，最后一只敌军死亡触发节点结算时也能保留全部返还。
	_refund_stolen_sun()
	_grant_plant_reward()
	# 已扣款的未抵达阳光同步取消，死亡后不能继续向退场角色吸取。
	for child: Node in get_children():
		if child is StolenSunFlight:
			child.queue_free()
	super.character_death()
	_damage_source = null
	_target_lane = -1
	hp_component.hide()
	shadow.hide()
	visual.play_exit()


## 退场末帧结束后才释放角色；美术预览播放退场时不误删仍存活的Boss。
func _on_exit_finished() -> void:
	if is_death:
		queue_free()


## 开发者清场沿用正常死亡登记，确保删除后僵尸计数与行管理器一致。
func character_death_disappear() -> void:
	_suppress_plant_reward = true
	if not is_death:
		hp_component.Hp_loss_death(false)
	queue_free()


## 击败时在管理器结算前发放伙伴卡；开发者只发临时卡，清场不触发。
func _grant_plant_reward() -> void:
	# 伙伴卡使用当前模式持有记录，不通过原版随机掉落或金币系统。
	var game: MainGameManager = Global.main_game
	if _suppress_plant_reward or character_init_type != E_CharacterInitType.IsNorm or not is_instance_valid(game) or not "_run" in game:
		return
	game._run.grant_da_fei_yu(not game._run.developer_testing and not get_meta("currency_war_developer_zombie", false))
	game._redraw()


## [param value]为总速度倍率，[param factor]为控制来源；冰冻、减速与黄油同步影响视频帧播放。
func update_speed_factor(value: float, factor: E_Influence_Speed_Factor) -> void:
	if is_death:
		return
	super.update_speed_factor(value, factor)
	if is_node_ready():
		_speed_factor = GlobalUtils.get_dic_product(influence_speed_factors)
		_update_visual_speed(visual.phase)


## [param phase]为当前动作阶段；只加速战斗技能，同步原视频、Token飘字和钢盆飞行。
func _update_visual_speed(phase: StringName) -> void:
	if not is_death:
		visual.set_playback_speed(_speed_factor * (1.0 if phase in [&"idle", &"entrance", &"exit"] else combat_animation_speed))


## [param attack_value]为爆炸伤害，[param is_cherry_bomb]保留原接口；视频 Boss 不套用普僵灰烬造型。
func be_bomb(attack_value: int, is_cherry_bomb: bool = false):
	be_attacked_bullet(attack_value, BulletRegistry.AttackMode.Penetration, false, false)


## 保留 Boss 的击退免疫；仍正常承受伤害以及现有冰冻、减速和中毒效果。
func can_be_knocked_back() -> bool:
	return false


## 普通待机后随机选择技能；Token来后下一招80%召唤，无自身库存或无合法前列时不播放召唤动作。
func _start_next_skill() -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm or visual.phase != &"idle":
		return
	# 非召唤的可用动作继续随机，不固定开场或技能轮次。
	var skills: Array[StringName] = [&"token", &"dream"]
	# 换行只在同地形且已经铺草的其他行之间选择。
	var candidates: Array[int] = _legal_lanes()
	candidates.erase(lane)
	if not candidates.is_empty():
		skills.append(&"lane_dive")
	# 只消耗Boss自己的库存；有前一列和合法行才能实际召唤，不能空播动作。
	var can_summon: bool = stolen_sun > 0 and not _legal_lanes().is_empty() and _summon_column() > 0
	# Token后的20%分支不混入召唤，使最终概率准确为80%。
	var skill: StringName = skills.pick_random()
	if _token_followup:
		if can_summon and randf() < TOKEN_SUMMON_CHANCE:
			skill = &"summon"
	elif can_summon:
		skills.append(&"summon")
		skill = skills.pick_random()
	_token_followup = false
	_target_lane = -1
	match skill:
		&"dream":
			visual.play_attack_1()
		&"lane_dive":
			_target_lane = candidates.pick_random()
			visual.play_skill(skill)
		_:
			visual.play_skill(skill)


## 返回与本 Boss 相同地形的开放行；避免移入货币战争尚未铺草的行。
func _legal_lanes() -> Array[int]:
	# 当前地图管理器与模式允许进入的行号。
	var manager: ZombieManager = Global.main_game.zombie_manager
	# 无模式限制时为空，保留原版所有合法行。
	var active: Array = Global.main_game.get_meta("currency_war_active_lanes", [])
	# 本次候选行，不包含越界或异地形行。
	var result: Array[int] = []
	# 地图实际行号。
	for index: int in range(manager.all_zombie_rows.size()):
		if Global.main_game.has_meta("currency_war_active_lanes") and not active.has(index):
			continue
		if manager.all_zombie_rows[index].zombie_row_type == curr_zombie_row_type:
			result.append(index)
	return result


## [param action]为原视频当前技能；仅正式出战存活状态结算一次。
func _on_skill_triggered(action: StringName) -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm:
		return
	if action == &"token":
		_steal_sun()
	elif action == &"summon":
		_summon_zombies()


## 按关卡配置随机偷取阳光，允许余额扣成负数；模式与原版分别更新真实余额，并显示等量吸取阳光。
func _steal_sun() -> void:
	# 本次期望偷取量，不使用阳光收集事件，避免受到收集增幅。
	var amount: int = randi_range(sun_steal_range.x, sun_steal_range.y)
	# 当前游戏实例，通过模式脚本属性识别共享经济。
	var game: MainGameManager = Global.main_game
	if not is_instance_valid(game):
		return
	if "_run" in game:
		# 即使余额不足或已经为负，也完整扣除本次偷取量并计入返还账目。
		game._run.sun -= amount
		game._redraw()
	elif is_instance_valid(game.card_manager) and is_instance_valid(game.card_manager.card_slot_battle):
		# 原版卡槽同样允许负数，沿用属性setter刷新数量和种植条件。
		game.card_manager.card_slot_battle.sun_value -= amount
	else:
		amount = 0
	stolen_sun += amount
	_refundable_sun += amount
	_token_followup = amount > 0
	if amount > 0:
		_play_stolen_sun(game, amount)


## 将本只Boss累计实际偷取的全部阳光直接返还真实账户，包括已经用于召唤的部分；重复死亡不重复返还。
func _refund_stolen_sun() -> void:
	if _refundable_sun <= 0:
		return
	# 必须赶在死亡登记触发过关前更新同一局余额，不走可受增幅影响的阳光收集事件。
	var game: MainGameManager = Global.main_game
	if not is_instance_valid(game):
		return
	# 保存本次返还金额，清账先于刷新UI，防止重入重复返还。
	var amount: int = _refundable_sun
	if "_run" in game:
		_refundable_sun = 0
		stolen_sun = 0
		game._run.sun += amount
		game._redraw()
	elif is_instance_valid(game.card_manager) and is_instance_valid(game.card_manager.card_slot_battle):
		_refundable_sun = 0
		stolen_sun = 0
		game.card_manager.card_slot_battle.sun_value += amount


## 从[param game]阳光数量UI飞出[param amount]颗原版阳光，始终以视口坐标衔接界面与世界角色。
func _play_stolen_sun(game: MainGameManager, amount: int) -> void:
	# 默认使用当前出战阳光目标，缺失时沿用原版的默认锚点。
	var marker: Marker2D = game.marker_2d_sun_target if is_instance_valid(game.marker_2d_sun_target) else game.marker_2d_sun_target_default
	if not is_instance_valid(marker):
		return
	# 数字标签与阳光图标分开定位，优先从用户指定的数量UI中心发射。
	var counter: Control = marker.get_parent().get_node_or_null("CurrSunValue") as Control
	# 两种坐标统一转换到视口，不能简单相加相机位置导致窗口缩放后偏移。
	var origin: Vector2 = counter.get_global_transform_with_canvas() * (counter.size * 0.5) if is_instance_valid(counter) else marker.get_global_transform_with_canvas().origin
	# 单次技能独立效果，生命周期随本只Boss，多个Boss不会共用飞行队列或返还账目。
	var flight: StolenSunFlight = StolenSunFlight.new()
	add_child(flight)
	flight.start_flight(origin, visual.get_node("HeadAnchor") as Node2D, amount, self)


## 在下潜完全结束时更新真实行及管理器，再在目标行播放出水；横坐标保持精确不变。
func _on_lane_submerged() -> void:
	if is_death or not _legal_lanes().has(_target_lane):
		return
	# 原横向位置保持不变，不能因为父行位置改变而漂移列号。
	var original_x: float = global_position.x
	# 目标行拥有对应的绘制层级及标准脚底高度。
	var target_row: ZombieRow = Global.main_game.zombie_manager.all_zombie_rows[_target_lane]
	lane = _target_lane
	signal_lane_update.emit()
	reparent(target_row)
	global_position = Vector2(original_x, target_row.zombie_create_position.global_position.y)
	_target_lane = -1


## 返回Boss当前最近格子的列号；召唤必须有前一列，0或-1表示无法召唤。
func _summon_column() -> int:
	# 当前地图格子用于确定真实列宽，选招与释放帧使用同一位置判定。
	var cells: Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	# 当前 Boss 所在的最近格子列号。
	var column: int = -1
	# 最近格子中心距，支持屋顶和不同地图偏移。
	var nearest: float = INF
	# 查找所在列的格子序号。
	for index: int in range(cells.size()):
		# 本列中心与 Boss 横坐标的距离。
		var distance: float = absf(cells[index].get_global_rect().get_center().x - global_position.x)
		if distance < nearest:
			nearest = distance
			column = index
	return column


## 每只消耗1点Boss自身阳光；按关卡配置随机召唤，库存不足只召唤可支付数量，0库存不执行。
func _summon_zombies() -> void:
	if stolen_sun <= 0:
		return
	# 合法行共享同一地形，随机分布允许同一行出现多只。
	var lanes: Array[int] = _legal_lanes()
	if lanes.is_empty():
		return
	# 释放帧再次校验前一列，不因动作期间的位置变化绕过边界。
	var column: int = _summon_column()
	if column <= 0:
		return
	# 本次可支付的数量不超过关卡配置上限，不从玩家余额直接支付召唤。
	var count: int = mini(randi_range(summon_count_range.x, summon_count_range.y), stolen_sun)
	# 按地形筛选的普通僵尸类型。
	var pool: Array[int] = []
	# 类型只从预设常规池抽取，避免递归 Boss 或特殊刷怪器。
	for type: int in SUMMON_POOL:
		# 该类型的原版地形限制。
		var terrain: int = Global.character_registry.get_zombie_info(type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
		if terrain == CharacterRegistry.ZombieRowType.Both or terrain == curr_zombie_row_type:
			pool.append(type)
	if pool.is_empty():
		return
	# 每次创建均走真实僵尸管理器，正常参加计数、死亡及换行登记。
	for index: int in range(count):
		# 本只随机行及目标行节点。
		var target_lane: int = lanes.pick_random()
		# 目标行的脚底高度和层级。
		var row: ZombieRow = Global.main_game.zombie_manager.all_zombie_rows[target_lane]
		# 前一列格子中心的横坐标，脚底仍由行节点决定。
		var spawn_position: Vector2 = Vector2(Global.main_game.plant_cell_manager.all_plant_cells[target_lane][column - 1].get_global_rect().get_center().x, row.zombie_create_position.global_position.y)
		# 完成真实出生登记后，在同帧将法阵挂到该僵尸脚底。
		var summoned: Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(pool.pick_random(), row, {E_ZInitAttr.Lane: target_lane, E_ZInitAttr.CurrWave: curr_wave}, spawn_position, _tag_summon)
		# 根节点原点对应脚底，随宿主移动、死亡及清场释放。
		var effect: Node2D = SUMMON_EFFECT.instantiate()
		summoned.add_child(effect)
		effect.global_scale = Vector2.ONE
		stolen_sun -= 1


## [param zombie]为尚未入树的召唤单位；标记敌军召唤来源；不使用友军标记，确保最后一只死亡仍可结算关卡。
func _tag_summon(zombie: Zombie000Base) -> void:
	zombie.set_meta("da_fei_yu_summon", true)
	# 工厂尚未连接末只敌军的过关判断，先登记掉落以保证切节点前准确入账。
	SummonSunDrop.register(zombie)
	if get_meta("currency_war_developer_zombie", false):
		zombie.set_meta("currency_war_developer_zombie", true)
