## 货币战争节点控制器：十五节点共享一局，复用原版关卡，整局结束保存仓库。
extends MainGameManager

## 显式加载有限牌库和单局经济规则。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 显式加载底部商店、上方备战卡牌、节点结果和设置界面。
const WarInterface = preload("res://scripts/currency_war/currency_war_ui.gd")
## 备战植物的原生拖拽数据类型与显示组件。
const ReserveSlot = preload("res://scripts/currency_war/currency_war_reserve_slot.gd")
## 跨节点共享本局状态，避免重载场景时重置阳光、植物、吃脑次数。
const Session = preload("res://scripts/currency_war/currency_war_session.gd")
## 整局结束后的永久植物存储，不在每个节点重复保存。
const Collection = preload("res://scripts/currency_war/currency_war_collection.gd")
## 复用原版SodRoll的草坪扩展显示，不改变后续泳池与屋顶资源。
const LawnVisual = preload("res://scripts/currency_war/currency_war_lawn.gd")
## 模式装备、攻击动作叠层、生命回复与头盔大招。
const Combat = preload("res://scripts/currency_war/currency_war_combat.gd")
## 识别左侧装备栏拖出的物品，不与植物移动数据混用。
const EquipmentIcon = preload("res://scripts/currency_war/currency_war_equipment_icon.gd")
## 场上植物脚下的微型装备槽，普通三格加独立头盔。
const EquipmentSlots = preload("res://scripts/currency_war/currency_war_equipment_slots.gd")
## 使用原版1066×600视口，所有模式界面叠放显示，不加高、压缩或移动地图。
const MODE_SIZE: Vector2i = Vector2i(1066, 600)
## 奖励关每只僵尸的固定总生命，包含本体和两类护甲，不受节点难度加成。
const REWARD_ZOMBIE_HP: int = 1
## 屋顶黑夜的背景色调，主贴图与左上角房屋遮罩使用相同倍率以避免接缝。
const ROOF_NIGHT_TINT: Color = Color(0.48, 0.54, 0.72)
## 货币战争点击开始后到首波僵尸出现的等待秒数。
const FIRST_WAVE_DELAY: float = 3.0
## 十五节点共享的阳光、持有植物与整局进度。
var _run: RunRules
## 在准备与节点结果暂停期间仍可响应操作的模式界面。
var _war_ui: WarInterface
## 选中的手牌或已种植物标识；-1表示未选中。
var _selected_id: int = -1
## 单位标识到实际场上植物的映射，只包含已种植单位。
var _plants: Dictionary = {}
## 合成或铲除时抑制自然阵亡回调，避免材料或已出售的场上单位重复退库。
var _synchronizing: bool = false
## 当前是否启用二倍游戏速度。
var _fast: bool = false
## 实时界面刷新间隔，以游戏秒计。
var _hud_wait: float = 0.0
## 进入模式前的窗口逻辑视口大小，退出时恢复。
var _previous_content_size: Vector2i
## 进入模式前的实际窗口大小，窗口模式退出时恢复。
var _previous_window_size: Vector2i
## 进入模式前的窗口位置，图片界面居中后退出时恢复。
var _previous_window_position: Vector2i
## 是否已设置模式视口，避免不完整初始化时恢复无效尺寸。
var _window_configured: bool = false
## 本节点的装备效果处理器，与整局装备记录分离。
var _combat: Combat
## 第一大关的连续原版草坪贴图和新增行草卷，镜头返回后才开始铺开。
var _opening_lawn: LawnVisual


## 在原版子管理器进入树前加载当前节点的原版参数与扩展视口，兼容整局入口和F6节点场景。
func _enter_tree() -> void:
	_run = Session.get_run()
	_previous_content_size = get_window().content_scale_size
	_previous_window_size = get_window().size
	_previous_window_position = get_window().position
	get_window().content_scale_size = MODE_SIZE
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().size = MODE_SIZE
		get_window().move_to_center()
	_window_configured = true
	game_para = ResourceLevelData.new()
	# 沿用原版关卡的地形与背景，实际波数、阵容及出怪倍率由本模式节点规则覆盖。
	var original: ResourceLevelData = (load(_run.campaign.level_path()) as ResourceLevelData).duplicate(true)
	# 只复制战场配置，卡牌、预种植、阳光余额和节点流程由本模式持有，避免额外赠送植物。
	for property: String in ["game_sences", "game_BG", "game_BGM", "is_fog", "is_day", "max_wave", "zombie_refresh_types", "is_bungi", "range_num_bungi", "is_have_tombston", "init_tombstone_num", "zombie_multy"]:
		# 老资源中的null不覆盖新资源的有效默认值。
		var value: Variant = original.get(property)
		if value != null:
			game_para.set(property, value)
	# 使用用户最新的一至四个实际小波，不再沿用原版整面旗帜波数及整套僵尸名单。
	game_para.max_wave = _run.configured_wave_count()
	game_para.zombie_refresh_types = _run.configured_zombies()
	# 每波使用更高的战力预算以生成更多僵尸，不改变原版随机权重与五十只的数量上限。
	game_para.zombie_multy = maxi(game_para.zombie_multy, RunRules.ZOMBIE_WAVE_MULTIPLIER)
	game_para.is_bungi = false
	game_para.game_mode = MainSceneRegistry.MainScenes.CurrencyWar
	game_para.level_id = "currency_war"
	game_para.look_show_zombie = false
	game_para.can_choosed_card = false
	game_para.monster_mode = ConstLevelData.E_MonsterMode.Norm
	# 新大纲使用节点结算经济，不接入原版25点天降阳光，防止混入两套货币数值。
	game_para.is_day_sun = false
	game_para.is_lawn_mover = true
	game_para.is_shovel = false
	game_para.is_day = not bool(_run.campaign.theme().night)
	game_para.start_sun = RunRules.STARTING_SUN
	Global.game_para = game_para
	super._enter_tree()


## 初始化原版战斗管理器，但不创建传统无限种子卡槽，使收集和花费只进入一个阳光账户。
func _ready() -> void:
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	_run.phase = RunRules.Phase.PREVIEW
	Global.time_scale = 1.0
	Engine.time_scale = 1.0
	game_para.init_para()
	main_game_progress = E_MainGameProgress.PREPARE
	EventBus.subscribe("zombie_go_home", on_zombie_go_home)
	EventBus.subscribe("create_trophy", create_trophy)
	EventBus.subscribe("add_sun_value", _on_collect_sun)
	detect_component_global.disable_component(ComponentNormBase.E_IsEnableFactor.Global)
	plant_cell_manager.init_manager()
	game_item_manager.init_manager()
	hand_manager.init_manager()
	zombie_manager.init_manager()
	# 遭遇关后续波次缩短最短等待和自然刷新时间，普通节点的一波只使用首波等待。
	var wave_refresh: ZombieWaveRefreshManager = zombie_manager.zombie_wave_manager.zombie_wave_refresh_manager
	wave_refresh.time_min_wave = 4.0
	wave_refresh.wave_min_time_timer.wait_time = wave_refresh.time_min_wave
	wave_refresh.norm_refresh_time_range_in_half_refresh = Vector2(15.0, 20.0)
	wave_refresh.norm_refresh_time_range_in_total_refresh = Vector2(22.0, 28.0)
	background_manager.init_manager()
	drop_item_manager.init_manager()
	day_suns_manager.init_manager()
	# 本模式只使用阳光货币，不让持续防守产生原版金币或花园掉落。
	EventBus.unsubscribe("create_coin", drop_item_manager.dim_coin.create_coin)
	EventBus.unsubscribe("create_garden_plant", drop_item_manager.dim_garden_plant.create_garden_plant)
	canvas_layer_ui.visible = false
	canvas_layer_ui.process_mode = Node.PROCESS_MODE_DISABLED
	get_node("CanvasLayerCardSlot").visible = false
	get_node("CanvasLayerCardSlot").process_mode = Node.PROCESS_MODE_DISABLED
	get_node("CanvasLayerCardSlotFront").visible = false
	get_node("CanvasLayerCardSlotFront").process_mode = Node.PROCESS_MODE_DISABLED
	coin_bank_label.hide()
	hand_manager.process_mode = Node.PROCESS_MODE_DISABLED
	# 原版格子只保留本模式的点击入口，种植完全依赖持有的手牌。
	for cells: Array in plant_cell_manager.all_plant_cells:
		# 格子按钮在开局暂停时也允许放置手牌，植物实体继续继承暂停状态。
		for cell: PlantCell in cells:
			cell.click_cell.disconnect(hand_manager._on_click_cell)
			cell.click_cell.connect(_on_cell_pressed)
			cell.button.process_mode = Node.PROCESS_MODE_ALWAYS
			cell.button.gui_input.connect(_on_lawn_input.bind(cell))
			cell.button.set_drag_forwarding(_drag_from_lawn.bind(cell), _can_drop_on_lawn.bind(cell), _drop_on_lawn.bind(cell))
	# 所有正常出战僵尸都从原版行容器进入，创建时应用本节点难度和奖励关属性。
	for row: ZombieRow in zombie_manager.all_zombie_rows:
		row.child_entered_tree.connect(_on_zombie_entered)
	# 同一大关五节点使用对应场景的实际行数和地形商品。
	var support: int = 17 if _run.campaign.theme().scene == "back" else (34 if _run.campaign.theme().scene == "roof" else -1)
	_run.configure_node(plant_cell_manager.all_plant_cells.size(), game_para.max_wave, support)
	if _run.campaign.theme().scene == "roof" and bool(_run.campaign.theme().night):
		# 主背景的self_modulate不会传给子节点，屋顶房屋遮罩需单独使用同一夜色色调。
		background_manager.background.self_modulate = ROOF_NIGHT_TINT
		background_manager.home.door_masks[ConstLevelData.GameBg.Roof].self_modulate = ROOF_NIGHT_TINT
	zombie_manager.zombie_wave_manager.signal_wave_refresh.connect(_on_wave_refreshed)
	_init_game_BGM()
	SoundManager.play_bgm(bgm_choose_card)
	_war_ui = WarInterface.new()
	add_child(_war_ui)
	_war_ui.attach_game_widgets(zombie_manager.zombie_wave_manager.flag_progress_bar, ui_remind_word)
	_war_ui.set_node_preview(game_para.zombie_refresh_types)
	marker_2d_sun_target = _war_ui.sun_target
	_connect_war_ui()
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)
	_combat = Combat.new()
	add_child(_combat)
	_combat.configure(_run, _plants, bullets, plant_cell_manager.all_plant_cells, zombie_manager.all_zombie_rows)
	_configure_open_lanes()
	_sync_battlefield()
	_configure_opening_lawn()
	_redraw()
	call_deferred("_preview_node_zombies")


## 使用原版展示僵尸与镜头移动，右移查看下一节点阵容后返回草坪，随后开放准备操作。
func _preview_node_zombies() -> void:
	# 准备暂停只冻结战斗，相机与展示姿态仍可按原版速度播放。
	camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	zombie_manager.create_prepare_show_zombies()
	await get_tree().create_timer(1.0).timeout
	await camera_2d.move_look_zombie()
	await get_tree().create_timer(1.0).timeout
	await camera_2d.move_back_ori()
	zombie_manager.delete_prepare_show_zombies()
	camera_2d.process_mode = Node.PROCESS_MODE_INHERIT
	_run.phase = RunRules.Phase.PREPARATION
	if is_instance_valid(_opening_lawn):
		_opening_lawn.begin_expansion()
	_redraw()


## 同步本节点开放行的格子输入、原版选行权重与小推车；不裁掉真实行数组，避免中行植物跨节点错位。
func _configure_open_lanes() -> void:
	# 按真实行号控制可见格子与按钮，未开放行仍保留给后续一至三至五行扩建。
	for lane: int in range(plant_cell_manager.all_plant_cells.size()):
		# 本节点行是否已经铺草，规则和视觉使用同一份行号集合。
		var opened: bool = _run.is_lane_open(lane)
		# 格子行容器内仅包含该行的九个原版格子。
		for cell: PlantCell in plant_cell_manager.all_plant_cells[lane]:
			cell.visible = opened
			cell.button.disabled = not opened
		if not opened and lane < game_item_manager.gim_lawn_mover.all_lawn_movers.size():
			# 未铺草行不显示或保留可触发的小推车，下一节点会按新行数重新建立。
			var mower: LawnMover = game_item_manager.gim_lawn_mover.all_lawn_movers[lane]
			if is_instance_valid(mower):
				mower.hide()
				mower.queue_free()
			game_item_manager.gim_lawn_mover.all_lawn_movers[lane] = null
	# 只修改本节点选行器实例，普通冒险与后续大关的原版权重不受影响。
	var chooser: ZombieChooseRowSystem = zombie_manager.zombie_wave_manager.zombie_wave_create_manager.zombie_choose_row_system
	# 陆地、水面和通用类型分别屏蔽未开放行，保留其余原版平滑选行逻辑。
	for type: int in chooser.base_weigth_all_type:
		# 克隆数组避免误改其他配置引用，未铺草行的权重严格设为零。
		var weights: Array = chooser.base_weigth_all_type[type].duplicate()
		# 每个索引仍对应真实战场行号，不把中间一行映射成最上面一行。
		for lane: int in range(weights.size()):
			if not _run.is_lane_open(lane):
				weights[lane] = 0.0
		chooser.base_weigth_all_type[type] = weights
		chooser.total_base_weight_all_type[type] = GlobalUtils.sum_arr(weights)


## 第一大关在原版泥地背景上显示一、三、五行草坪；仅新增行播放原版48帧草卷动画。
func _configure_opening_lawn() -> void:
	if _run.campaign.stage_number() != 1:
		return
	background_manager.background.texture = preload("res://assets/image/background/background1unsodded.jpg")
	# 节点切换虽重建场景，先前已铺好的行直接显示，不重复播放。
	var previous: Array[int] = []
	match _run.campaign.node_number():
		2:
			previous = [2]
		3:
			previous = [1, 2, 3]
		4, 5:
			previous = [0, 1, 2, 3, 4]
	# 草坪节点使用背景局部坐标，跟随原版背景画布，不加入用户交互层。
	_opening_lawn = LawnVisual.new()
	background_manager.background.add_child(_opening_lawn)
	_opening_lawn.expansion_finished.connect(_on_lawn_expansion_finished)
	_run.lawn_expanding = _opening_lawn.configure(_run.active_lanes, previous)


## 所有新增行铺完后允许开战和草坪拖放，保持原本准备节点暂停。
func _on_lawn_expansion_finished() -> void:
	_run.lawn_expanding = false
	_redraw()


## 实时刷新阳光与原版进攻信息；[param delta]为受游戏速度影响的帧时长，不负责自制出怪。
func _process(delta: float) -> void:
	if _run.phase != RunRules.Phase.BATTLE:
		return
	_hud_wait -= delta
	if _hud_wait <= 0.0:
		_hud_wait = 0.25
		_redraw()


## 退出模式时恢复原窗口、速度及暂停状态，不改动原版关卡存档。
func _exit_tree() -> void:
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = 1.0
	if _window_configured:
		get_window().content_scale_size = _previous_content_size
		if get_window().mode == Window.MODE_WINDOWED:
			get_window().size = _previous_window_size
			get_window().position = _previous_window_position
	if Global.game_para == game_para:
		Global.game_para = null
	super._exit_tree()


## 僵尸[param _zombie]吃脑仅结算当前节点，前三次仍能继续，第四次才终止整局。
func on_zombie_go_home(_zombie: Zombie000Base) -> void:
	_finish_game(false)


## 原版最后一波清空后调用；[param _global_position]为原奖杯位置，本模式改为显示最终结果。
func create_trophy(_global_position: Vector2) -> void:
	_finish_game(true)


## 把商店、手牌和海克斯请求接入规则层；界面不直接操作植物或波次管理器。
func _connect_war_ui() -> void:
	_war_ui.buy_requested.connect(_on_buy)
	_war_ui.unit_selected.connect(_on_unit_selected)
	_war_ui.merge_lock_requested.connect(_on_toggle_merge_lock)
	_war_ui.refresh_requested.connect(_on_refresh_shop)
	_war_ui.lock_requested.connect(_on_lock_shop)
	_war_ui.sell_requested.connect(_on_sell)
	_war_ui.sale_requested.connect(_on_sell_unit)
	_war_ui.battle_requested.connect(_start_battle)
	_war_ui.speed_requested.connect(_on_speed)
	_war_ui.speed_selected.connect(_on_speed_selected)
	_war_ui.menu_requested.connect(_on_menu)
	_war_ui.restart_requested.connect(_on_restart)
	_war_ui.hex_requested.connect(_on_hex_chosen)
	_war_ui.cancel_requested.connect(_on_cancel_selection)
	_war_ui.reserve_rearrange_requested.connect(_on_reserve_rearranged)
	_war_ui.settings_toggled.connect(_on_settings_toggled)
	_war_ui.volume_changed.connect(_on_volume_changed)
	_war_ui.next_node_requested.connect(_on_next_node)
	_war_ui.support_requested.connect(_on_buy_support)
	_war_ui.experience_requested.connect(_on_buy_experience)
	_war_ui.equipment_requested.connect(_on_equip_item)
	_war_ui.encounter_selected.connect(_on_encounter_selected)


## 按大纲1.3将[param value]应用到[param bus]音乐或音效总线，使用已有配置即时保存。
func _on_volume_changed(value: float, bus: int) -> void:
	if bus != SoundManager.Bus.BGM and bus != SoundManager.Bus.SFX:
		return
	SoundManager.set_volume(bus, clampf(value, 0.0, 1.0))
	Global.config_service.save_config()


## 设置按[param opened]增减菜单暂停因素，保留开局、海克斯和结束时各自的暂停状态。
func _on_settings_toggled(opened: bool) -> void:
	if opened:
		TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.Menu)
	else:
		TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.Menu)
		if Global.config_service.auto_collect_sun and _run.phase == RunRules.Phase.BATTLE:
			# 已经落地的旧阳光也接入收集；尚在下落的阳光仍由原版动画结束回调处理。
			for sun: Node in suns.get_children():
				if sun is Sun and not sun.collected and (not is_instance_valid(sun.spawn_sun_tween) or not sun.spawn_sun_tween.is_running()):
					sun.on_sun_tween_finished()


## 从本节点准备阶段开始原版波次，节点内不恢复植物；节点结束后由结果流程接续同一整局。
func _start_battle() -> void:
	if _run.phase != RunRules.Phase.PREPARATION or _run.lawn_expanding or _run.count_units() == 0:
		return
	_run.phase = RunRules.Phase.BATTLE
	main_game_progress = E_MainGameProgress.MAIN_GAME
	_run.message = "%s %s开始；阵亡植物不会恢复。" % [_run.campaign.node_label(), _run.campaign.node_kind()]
	SoundManager.play_bgm(bgm_main_game)
	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)
	zombie_manager.start_game(FIRST_WAVE_DELAY)
	_redraw()


## 收取原版阳光事件[param value]，立即更新唯一的阳光余额；收集动作仍由原版Sun处理。
func _on_collect_sun(value: int) -> void:
	_run.collect_sun(value)
	_redraw()


## 原版刷新当前波时更新进度；[param _is_end_wave]保留原信号签名，最终胜利仍由清空敌人触发。
func _on_wave_refreshed(_is_end_wave: bool) -> void:
	if _run.phase != RunRules.Phase.BATTLE:
		return
	_run.current_wave = zombie_manager.zombie_wave_manager.curr_wave + 1
	_redraw()


## 应用[param hex_id]当前候选并恢复同一片草坪，植物血量、僵尸和阳光均保留。
func _on_hex_chosen(hex_id: String) -> void:
	if not _run.choose_hex(hex_id):
		return
	_apply_current_bonuses()
	_redraw()
	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)


## 根据逻辑牌记录增删战场实体，合成和铲除不会被误判为自然阵亡退库。
func _sync_battlefield() -> void:
	_synchronizing = true
	# 准备阶段允许自由移动，先清理普通层再清理底座，防止底座销毁时带走上方植物容器。
	for layer: int in [CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Down]:
		# 使用标识快照，删除实体映射不会影响本轮遍历。
		for unit_id: int in _plants.keys():
			if not is_instance_valid(_plants[unit_id]):
				_plants.erase(unit_id)
				continue
			# 当前实体保留原格信息，规则层可能已被拖拽移动到新格。
			var plant: Plant000Base = _plants[unit_id]
			if _run.placement(int(plant.plant_type)) != layer:
				continue
			if _run.phase == RunRules.Phase.PREPARATION or _run.find_unit(unit_id).is_empty():
				_discard_battle_plant(plant)
				_plants.erase(unit_id)
	# 先重建睡莲/花盆，再按原版地形条件放置普通植物；不适配新地图的植物回到备战席。
	for layer: int in [CharacterRegistry.PlacePlantInCell.Down, CharacterRegistry.PlacePlantInCell.Norm]:
		# 持有数组不删除元素，退回备战只修改当前单位位置。
		for unit: Dictionary in _run.units:
			if unit.cell == RunRules.BENCH_CELL or _plants.has(unit.id) or _run.placement(int(unit.type)) != layer:
				continue
			_create_battle_unit(unit)
	_synchronizing = false
	_apply_current_bonuses()
	# 原版随机速度初始化在帧末运行，随后重新同步生产速度以保留星级与海克斯效果。
	call_deferred("_apply_current_bonuses")


## 移除[param plant]战斗实体并清理原格的死亡引用；规则记录由上层处理，不返库、不判自然阵亡。
func _discard_battle_plant(plant: Plant000Base) -> void:
	# 底座和普通植物分层清理，死亡回调仍通过原版恢复容器与地形条件。
	var layer: int = _run.placement(int(plant.plant_type))
	# 实体的plant_cell始终是旧格，不能使用已经被拖拽改写的逻辑cell。
	var cell: PlantCell = plant.plant_cell
	# 合成、出售和准备移动不是战斗阵亡，不能触发土豆地雷等植物的临终爆炸。
	plant.is_can_death_language = false
	plant.character_death_disappear()
	if cell.plant_in_cell[layer] == plant:
		cell.plant_in_cell[layer] = null


## 将[param unit]在原版格子中实例化；原版地形条件不满足时保留拥有记录并退回备战，不凭空生成睡莲或花盆。
func _create_battle_unit(unit: Dictionary) -> void:
	# 新节点行数可能缩减，先保护索引，配置步骤已优先将超范围植物退回备战。
	if unit.cell.x < 0 or unit.cell.x >= plant_cell_manager.all_plant_cells.size() or not _run.is_lane_open(unit.cell.x):
		_run.restore_reserve(int(unit.id))
		return
	# 使用真实场景格子，使泳池与屋顶继续使用原版碰撞、坡度及种植容器。
	var cell: PlantCell = plant_cell_manager.all_plant_cells[unit.cell.x][unit.cell.y]
	# 规则与实体使用相同层号，底座不会占掉普通植物层。
	var layer: int = _run.placement(int(unit.type))
	# 原版死亡指针在帧末释放，立即清除已死亡引用让合成后的重建可以承接同格。
	var previous: Variant = cell.plant_in_cell[layer]
	if is_instance_valid(previous) and previous.is_death:
		cell.plant_in_cell[layer] = null
	# 原有种植条件资源控制水、花盆、睡莲和墓碑，模式不绕过它们。
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(unit.type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if not condition.judge_is_can_plant(cell, unit.type):
		_run.restore_reserve(int(unit.id))
		return
	# 工厂负责原版动画、行号和死亡信号，节点切换重建时自然恢复满血。
	var plant: Plant000Base = cell.create_plant(unit.type, false, true)
	if not is_instance_valid(plant):
		_run.restore_reserve(int(unit.id))
		return
	plant.set_meta("war_base_hp", plant.hp_component.max_hp)
	plant.random_speed_range = Vector2.ONE
	plant.signal_character_death.connect(_on_plant_died.bind(int(unit.id)))
	_plants[unit.id] = plant
	# 原版攻击组件的基础间隔只记录一次，后续同步不会重复叠乘。
	var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
	if is_instance_valid(attack):
		plant.set_meta("war_base_attack_cd", attack.attack_cd)
	# 地形植物不显示星级，也不进入合成；其他植物保留可见星级标记。
	var rank: Label = Label.new()
	rank.name = "CurrencyWarRank"
	rank.visible = not _run.is_support(int(unit.type))
	rank.position = Vector2(-30, -100)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank.add_theme_font_override("font", preload("res://assets/fonts/方正少儿_GBK.ttf"))
	rank.add_theme_font_size_override("font_size", 15)
	rank.add_theme_color_override("font_color", WarInterface.GOLD_COLOR)
	rank.add_theme_color_override("font_outline_color", Color("183024"))
	rank.add_theme_constant_override("outline_size", 4)
	plant.add_child(rank)
	# 小装备栏跟随植物实体，植物移动或节点重建后仍由持有记录恢复。
	var equipment_slots: EquipmentSlots = EquipmentSlots.new()
	equipment_slots.name = "CurrencyWarEquipmentSlots"
	# 装备栏使用世界水平坐标，不继承植物身体的朝向、缩放和待机摇摆。
	equipment_slots.top_level = true
	equipment_slots.process_mode = Node.PROCESS_MODE_ALWAYS
	equipment_slots.visible = not _run.is_support(int(unit.type))
	equipment_slots.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_slots.configure_drop_target(_can_drop_plant_equipment.bind(int(unit.id)), _drop_plant_equipment.bind(int(unit.id)))
	equipment_slots.item_inspected.connect(_war_ui.show_equipment_details)
	plant.add_child(equipment_slots)
	if is_instance_valid(_combat):
		_combat.register_plant(plant, int(unit.id))


## 应用大纲已定义的植物星级与向日葵结算生产，攻击、攻速分别读取当前规则。
func _apply_current_bonuses() -> void:
	_run.sync_helmet()
	# 逐株从保存的基础属性重新计算。
	for unit_id: int in _plants:
		if not is_instance_valid(_plants[unit_id]):
			continue
		# 只有尚未被合成、铲除或自然死亡的逻辑单位能获得强化。
		var unit: Dictionary = _run.find_unit(unit_id)
		if unit.is_empty():
			continue
		# 确认节点有效后才赋给强类型变量，避免释放后引用导致运行错误。
		var plant: Plant000Base = _plants[unit_id]
		if plant.is_death:
			continue
		# 星级攻速与伤害独立，装备和羁绊随后统一同步。
		var speed: float = 1.0 + _run.star_speed_bonus(int(unit.type), int(unit.star))
		plant.set_meta("currency_war_attack_multiplier", 1.0 + _run.star_attack_bonus(int(unit.type), int(unit.star)))
		if plant is Plant005PotatoMine:
			plant.configure_currency_war(int(unit.star))
		# 并非所有植物都有攻击组件，例如向日葵与坚果。
		var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
		if is_instance_valid(attack):
			attack.attack_cd = float(plant.get_meta("war_base_attack_cd")) / speed
			attack.bullet_attack_cd_timer.wait_time = attack.attack_cd
		# 新经济不混入原版25点生产阳光，向日葵的1/4/10在节点结算处理。
		var sun_component: CreateSunComponent = plant.get_node_or_null("CreateSunComponent") as CreateSunComponent
		if is_instance_valid(sun_component):
			sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
		plant.get_node("CurrencyWarRank").text = "%s%s %d星" % ["锁 · " if bool(unit.get("merge_locked", false)) else "", "★".repeat(unit.star), unit.star]
		plant.get_node("CurrencyWarEquipmentSlots").visible = not _run.is_support(int(unit.type)) and (not unit.get("equipment", []).is_empty() or _run.helmet_unit_id == unit_id)
		plant.get_node("CurrencyWarEquipmentSlots").render_items(unit.get("equipment", []), _run.helmet_unit_id == unit_id)
		_align_equipment_slots(plant)
	if is_instance_valid(_combat):
		_combat.sync()


## 将[param plant]的装备栏按真实可见身体的底边居中，三格与四格都保持水平，不使用固定右偏坐标。
func _align_equipment_slots(plant: Plant000Base) -> void:
	# 只读取原版身体校正子树，临时种植尘土、血条和装备栏不参与范围计算。
	var bounds: Rect2 = _plant_visual_bounds(plant.body.get_node("BodyCorrect"), plant.body.transform)
	# 世界坐标中的脚下中心，缺少可见身体时使用原版影子作为边界保护。
	var foot: Vector2 = plant.to_global(Vector2(bounds.get_center().x, bounds.end.y + 5.0)) if bounds.has_area() else plant.shadow.global_position + Vector2(0, 8)
	# 装备栏在自身尺寸确定后再定位，独立头盔出现时也自动重新居中。
	var slots: Control = plant.get_node("CurrencyWarEquipmentSlots")
	slots.rotation = 0.0
	slots.scale = Vector2.ONE
	slots.global_position = foot - Vector2(slots.size.x * 0.5, 0)


## 返回[param node]可见精灵在[param parent_transform]下的联合范围，隐藏帧和非精灵效果不计入。
func _plant_visual_bounds(node: Node2D, parent_transform: Transform2D) -> Rect2:
	if not node.visible:
		return Rect2()
	# 保留原版身体校正节点的位置、缩放和旋转。
	var transform: Transform2D = parent_transform * node.transform
	# 空范围表示尚未找到可见植物精灵。
	var bounds: Rect2 = Rect2()
	if node is Sprite2D and node.texture != null:
		bounds = transform * node.get_rect()
	# 仅遍历植物身体下的二维绘制部件。
	for child: Node in node.get_children():
		if child is Node2D:
			# 当前身体部件的实际可见包围盒。
			var part: Rect2 = _plant_visual_bounds(child, transform)
			if part.has_area():
				bounds = bounds.merge(part) if bounds.has_area() else part
	return bounds


## 自然阵亡的[param unit_id]永久失去本局持有资格，后续节点与仓库存储均不包含它。
func _on_plant_died(unit_id: int) -> void:
	if _synchronizing or _run.phase == RunRules.Phase.FINISHED:
		return
	_run.lose_plant(unit_id)
	_plants.erase(unit_id)
	call_deferred("_apply_current_bonuses")
	_redraw()


## 购买[param slot]商品后同步场上与备战合成结果，被消耗的场上植物由同步流程实际移除。
func _on_buy(slot: int) -> void:
	if _run.buy(slot):
		_sync_battlefield()
		if not _run.last_merges.is_empty():
			# 连锁升星突出最终结果，结果仍在备战席时自动选中以便查看与种植。
			var result: Dictionary = _run.last_merges.back()
			# 通过标识查询最终记录，并只允许选中仍在备战席中的有效结果。
			var upgraded: Dictionary = _run.find_unit(result.id)
			if not upgraded.is_empty() and upgraded.cell == RunRules.BENCH_CELL:
				_selected_id = int(upgraded.id)
			_war_ui.show_merge_result(result)
	_redraw()


## 选择或取消[param unit_id]对应手牌，不在海克斯选择或结局期间改变选择。
func _on_unit_selected(unit_id: int) -> void:
	if _run.can_manage():
		_selected_id = -1 if _selected_id == unit_id else unit_id
		_redraw()


## 右键切换[param unit_id]的合成锁定；只有实际发生合成时才同步增删实体，普通锁定不重建植物。
func _on_toggle_merge_lock(unit_id: int) -> void:
	if not _run.toggle_merge_lock(unit_id):
		return
	if not _run.last_merges.is_empty():
		_sync_battlefield()
		_war_ui.show_merge_result(_run.last_merges.back())
	else:
		_apply_current_bonuses()
	_redraw()


## 准备阶段草坪按钮收到[param event]右键时切换[param cell]内植物的合成锁定，其他阶段不改变锁定状态。
func _on_lawn_input(event: InputEvent, cell: PlantCell) -> void:
	if _run.phase != RunRules.Phase.PREPARATION or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	# 上层植物优先，没有上层时才操作睡莲或花盆，避免误锁底座。
	var unit: Dictionary = _run.unit_at(cell.row_col)
	if unit.is_empty():
		unit = _run.unit_at(cell.row_col, CharacterRegistry.PlacePlantInCell.Down)
	if not unit.is_empty():
		cell.button.accept_event()
		_on_toggle_merge_lock(int(unit.id))


## 点击原版草坪[param cell]：有手牌时种植，没有选择时选中该格已有植物供铲除。
func _on_cell_pressed(cell: PlantCell) -> void:
	if not _run.can_manage():
		return
	if _selected_id != -1:
		if _can_drop_on_lawn(Vector2.ZERO, {"kind": ReserveSlot.DRAG_KIND, "unit_id": _selected_id}, cell) and _run.plant_card(_selected_id, cell.row_col):
			_selected_id = -1
			_sync_battlefield()
	else:
		_selected_id = _run.unit_at(cell.row_col).get("id", -1)
	_redraw()


## 检查拖拽[param data]能否落到主草坪[param cell]；[param _at_position]为目标按钮局部坐标。
func _can_drop_on_lawn(_at_position: Vector2, data: Variant, cell: PlantCell) -> bool:
	if data is Dictionary and data.get("kind", "") == ReserveSlot.SHOVEL_DRAG_KIND:
		return _run.can_manage() and not _sale_target(cell).is_empty()
	if data is Dictionary and data.get("kind", "") == EquipmentIcon.DRAG_KIND:
		# 装备落到当前格的上层植物，底座本身仍禁止装备。
		var target: Dictionary = _run.unit_at(cell.row_col)
		return not target.is_empty() and _run.can_equip_item(int(target.id), str(data.get("item", "")))
	if not _run.can_manage() or _run.lawn_expanding or not _run.is_lane_open(cell.row_col.x) or not data is Dictionary or data.get("kind", "") != ReserveSlot.DRAG_KIND:
		return false
	# 释放鼠标时重新查询唯一标识，防止合成、出售或海克斯切换使旧拖拽数据失效。
	var unit: Dictionary = _run.find_unit(int(data.get("unit_id", -1)))
	if unit.is_empty() or (unit.cell != RunRules.BENCH_CELL and _run.phase != RunRules.Phase.PREPARATION) or not cell.can_common_plant:
		return false
	# 水与屋顶沿用原版条件；准备阶段同层有植物时由规则层交换，战斗阶段不可覆盖。
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(unit.type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	# 已有底座会把当前条件改成睡莲/花盆，替换底座时应检查原地形，而非其自身转换后的条件。
	var terrain: int = cell.ori_condition if _run.is_support(int(unit.type)) else cell.curr_condition
	if not condition.plant_condition & terrain:
		return false
	# 两株场上植物交换时，另一株也必须能放在源格，不能把花盆或睡莲换到非法地形。
	var occupant: Dictionary = _run.unit_at(cell.row_col, _run.placement(int(unit.type)))
	if not occupant.is_empty() and int(occupant.id) != int(unit.id):
		if _run.phase != RunRules.Phase.PREPARATION:
			return false
		if unit.cell != RunRules.BENCH_CELL:
			# 取目标植物条件与源格真实地形进行对称校验，校验失败不消费或挪动任何植物。
			var other_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(occupant.type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
			# 源格由本局有效部署记录定位，范围已在节点初始化时处理。
			var source_cell: PlantCell = plant_cell_manager.all_plant_cells[unit.cell.x][unit.cell.y]
			# 对称交换底座时同样使用原地形，普通植物仍要求已有合适底座。
			var source_terrain: int = source_cell.ori_condition if _run.is_support(int(occupant.type)) else source_cell.curr_condition
			if not other_condition.plant_condition & source_terrain:
				return false
	return true


## 将拖拽[param data]的备战植物种到[param cell]；[param at_position]复用落点校验，失败保持原备战格。
func _drop_on_lawn(at_position: Vector2, data: Variant, cell: PlantCell) -> void:
	if not _can_drop_on_lawn(at_position, data, cell):
		return
	if data.get("kind", "") == ReserveSlot.SHOVEL_DRAG_KIND:
		_on_sell_unit(int(_sale_target(cell).id))
		return
	if data.get("kind", "") == EquipmentIcon.DRAG_KIND:
		_on_equip_item(int(_run.unit_at(cell.row_col).id), str(data.item))
		return
	if _run.plant_card(int(data.unit_id), cell.row_col):
		_selected_id = -1
		_sync_battlefield()
	_redraw()


## 将备战植物[param unit_id]移到[param target_slot]，有占用时交换；不创建或销毁战斗实体。
func _on_reserve_rearranged(unit_id: int, target_slot: int) -> void:
	# 场上退回并与备战植物交换时，先检查备战植物是否能承接原来的地形。
	var source: Dictionary = _run.find_unit(unit_id)
	# 空备战格不需要反向种植校验。
	var target: Dictionary = _run.reserve_at(target_slot)
	if not source.is_empty() and source.cell != RunRules.BENCH_CELL and not target.is_empty():
		# 反向种植仍使用同一落点校验，不能免费绕过水池或屋顶条件。
		var cell: PlantCell = plant_cell_manager.all_plant_cells[source.cell.x][source.cell.y]
		if not _can_drop_on_lawn(Vector2.ZERO, {"kind": ReserveSlot.DRAG_KIND, "unit_id": target.id}, cell):
			return
	if _run.move_reserve(unit_id, target_slot):
		_selected_id = unit_id
		_sync_battlefield()
	_redraw()


## 准备阶段从[param cell]发起拖动，[param at_position]为鼠标在按钮内的位置；战斗阶段或空格返回null。
func _drag_from_lawn(at_position: Vector2, cell: PlantCell) -> Variant:
	if _run.phase != RunRules.Phase.PREPARATION or _run.lawn_expanding:
		return null
	# 优先拖普通植物，没有普通植物时再拖睡莲或花盆，避免点击上层却抓到底座。
	var unit: Dictionary = _run.unit_at(cell.row_col)
	if unit.is_empty():
		unit = _run.unit_at(cell.row_col, CharacterRegistry.PlacePlantInCell.Down)
	if unit.is_empty() or not is_instance_valid(_plants.get(unit.id)):
		return null
	# 复制真实身体姿态，换算到按钮局部坐标后减去抓取点，不受摄像机偏移影响。
	var plant: Plant000Base = _plants[unit.id]
	# 引擎移动根预览，偏移全部保留在其可见子节点上。
	var preview: Control = Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 身体副本只绘制，不运行角色脚本、攻击或动画。
	var visual: Node2D = plant.body.duplicate(0) as Node2D
	visual.transform = cell.button.get_global_transform_with_canvas().affine_inverse() * plant.body.get_global_transform_with_canvas()
	visual.position -= at_position
	visual.process_mode = Node.PROCESS_MODE_DISABLED
	preview.add_child(visual)
	cell.button.set_drag_preview(preview)
	plant.body.modulate.a = 0.3
	_selected_id = int(unit.id)
	return {"kind": ReserveSlot.DRAG_KIND, "unit_id": int(unit.id)}


## 收到[param what]拖动结束通知时恢复场上植物显示，无效落点和取消不会丢失植物。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# 场景离开时映射可能已有失效节点，跳过它们。
		for plant: Variant in _plants.values():
			if is_instance_valid(plant):
				plant.body.modulate.a = 1.0


## 在当前地形花费1阳光直购[param plant_type]睡莲或花盆，不触发升星。
func _on_buy_support(plant_type: int) -> void:
	_run.buy_support(plant_type)
	_redraw()


## 继续本局的下一个节点，不返回主菜单；新场景只重建仍持有的植物并恢复它们满血。
func _on_next_node() -> void:
	if not _run.advance_node():
		return
	# 场景路径均来自本局已确定的大关配置，不在同一大关每小关重新随机。
	var error: Error = get_tree().change_scene_to_file(_run.campaign.scene_path())
	if error != OK:
		_run.campaign.node_index -= 1
		_run.phase = RunRules.Phase.NODE_RESULT
		_run.message = "无法进入下一节点，请重试。"
		_redraw()


## 整局结束保存全部仍持有植物；写盘失败保留结果与本局状态，不标记成功或自动丢弃。
func _save_final_collection() -> bool:
	# 入库接口按整局批次幂等，反复点击返回或重开不会重复发植物。
	var error: Error = Collection.store_run(_run.campaign.run_key, _run.warehouse_units(), _run.warehouse_equipment())
	_run.collection_saved = error == OK
	if error != OK:
		_run.message = "仓库未保存：请先选择用户或检查存档文件，再重试。"
	return _run.collection_saved


## 原版行容器加入[param node]时应用节点属性；奖励关仅总生命固定1点，双方攻击保持正常，其他节点沿用难度倍率。
func _on_zombie_entered(node: Node) -> void:
	if not node is Zombie000Base:
		return
	# 在角色ready之前修改基础上限，原版初始化会据此填满生命与护甲并计算波次总生命。
	var hp: HpComponentZombie = node.get_node_or_null("HpComponent") as HpComponentZombie
	if hp != null:
		if _run.campaign.node_kind() == "奖励关":
			# 本体与护甲总计只能有1点，护甲不在本体之外额外叠加。
			hp.max_hp_armor1 = 0
			hp.max_hp_armor2 = 0
			hp.max_hp = REWARD_ZOMBIE_HP
		else:
			# 其他节点难度从1起，每级增加5%生命。
			var factor: float = 1.0 + _run.node_difficulty() * 0.05
			hp.max_hp = maxi(1, roundi(hp.max_hp * factor))
			hp.max_hp_armor1 = roundi(hp.max_hp_armor1 * factor)
			hp.max_hp_armor2 = roundi(hp.max_hp_armor2 * factor)
	if _run.campaign.node_kind() == "奖励关":
		# 角色及子组件全部初始化后再次同步当前血量，避免仅改上限而保留原版当前血量。
		if node.is_node_ready():
			_finalize_reward_zombie(node)
		else:
			node.ready.connect(_finalize_reward_zombie.bind(node), CONNECT_ONE_SHOT)


## 确保奖励关[param zombie]初始化后的实际总生命为1；不修改植物伤害、僵尸攻击或伤害计算公式。
func _finalize_reward_zombie(zombie: Zombie000Base) -> void:
	# 此处所有血条节点已就绪，赋值同步真实生命和界面，不通过承伤上限模拟一血。
	var hp: HpComponentZombie = zombie.hp_component as HpComponentZombie
	hp.max_hp = REWARD_ZOMBIE_HP
	hp.max_hp_armor1 = 0
	hp.max_hp_armor2 = 0
	# 原版按最大生命三分之一减1计算死亡阈值，一血时会变成-1，必须恢复为0才能正常死亡。
	hp.set_death_hp(0)
	hp.curr_hp = REWARD_ZOMBIE_HP
	hp.curr_hp_armor1 = 0
	hp.curr_hp_armor2 = 0
	# 一血僵尸的掉手、掉头阶段也在归零时触发，不保留永远无法到达的负血量阈值。
	for index: int in range(zombie.hp_stage_change_component.boundary_value_hp.size()):
		zombie.hp_stage_change_component.boundary_value_hp[index] = 0


## D牌只消耗阳光或免费券，原版进攻不会因此暂停。
func _on_refresh_shop() -> void:
	_run.refresh_shop()
	_redraw()


## 切换当前商品是否保留到下一节点，节点进入时消费一次保留状态。
func _on_lock_shop() -> void:
	_run.toggle_lock()
	_redraw()


## 铲除或出售当前选择，先修改规则记录再同步实体，避免死亡回调重复返还副本。
func _on_sell() -> void:
	_on_sell_unit(_selected_id)


## 使用同一售卖接口处理拖铲子、拖卡到铲子及选中后点击铲子的[param unit_id]，成功后返还装备并同步实体。
func _on_sell_unit(unit_id: int) -> void:
	if _run.sell(unit_id):
		_selected_id = -1
		_sync_battlefield()
	_redraw()


## 返回[param cell]中铲子的售卖对象，优先上层植物，空上层才选择睡莲或花盆。
func _sale_target(cell: PlantCell) -> Dictionary:
	# 上下层独立售卖，不能一次把上层植物和底座都出售。
	var unit: Dictionary = _run.unit_at(cell.row_col)
	return unit if not unit.is_empty() else _run.unit_at(cell.row_col, CharacterRegistry.PlacePlantInCell.Down)


## 购买一次4点经验并刷新等级与种类上限，满级不扣阳光。
func _on_buy_experience() -> void:
	_run.buy_experience()
	_redraw()


## 校验拖到脚下小栏的[param data]能否给[param unit_id]装备或用铲子售卖；[param _at_position]不影响目标标识。
func _can_drop_plant_equipment(_at_position: Vector2, data: Variant, unit_id: int) -> bool:
	if data is Dictionary and data.get("kind", "") == ReserveSlot.SHOVEL_DRAG_KIND:
		return _run.can_manage() and not _run.find_unit(unit_id).is_empty()
	return data is Dictionary and data.get("kind", "") == EquipmentIcon.DRAG_KIND and _run.can_equip_item(unit_id, str(data.get("item", "")))


## 脚下装备栏收到[param data]后给[param unit_id]装备或售卖；[param at_position]复用最终校验，失败不消耗库存。
func _drop_plant_equipment(at_position: Vector2, data: Variant, unit_id: int) -> void:
	if _can_drop_plant_equipment(at_position, data, unit_id):
		if data.get("kind", "") == ReserveSlot.SHOVEL_DRAG_KIND:
			_on_sell_unit(unit_id)
		else:
			_on_equip_item(unit_id, str(data.item))


## 将拖出的[param item]放到落点植物[param unit_id]，合成与槽位由规则层处理，不重建受伤实体。
func _on_equip_item(unit_id: int, item: String) -> void:
	if _run.equip_item(unit_id, item):
		_apply_current_bonuses()
	_redraw()


## 准备时切换遭遇档位[param selected]，同步本节点难度、实际波数与结算奖励。
func _on_encounter_selected(selected: int) -> void:
	_run.set_encounter_level(selected)
	_configure_node_wave_count()
	_redraw()


## 遭遇选择改变时同步原版波次管理器的实际总波数；仅准备阶段执行，不重复创建旗帜控件。
func _configure_node_wave_count() -> void:
	if _run.phase != RunRules.Phase.PREPARATION:
		return
	game_para.max_wave = _run.configured_wave_count()
	_run.node_wave_limit = game_para.max_wave
	# 短局仍使用原版出怪、清场与结算，只改变尚未开始的轮次上限。
	var waves: ZombieWaveManager = zombie_manager.zombie_wave_manager
	waves.max_wave = game_para.max_wave
	waves.max_wave_one_round = game_para.max_wave
	waves.progress_bar_segment_every_wave = 100.0 / maxi(1, game_para.max_wave - 1)
	waves.flag_progress_bar.set_progress(0)


## 清空选择，让下一次点击草坪恢复为查看已种植物。
func _on_cancel_selection() -> void:
	_selected_id = -1
	_redraw()


## 在战斗阶段切换一倍或二倍速度；不修改原版波次时间参数。
func _on_speed() -> void:
	_on_speed_selected(not _fast)


## 按[param fast]应用一倍或二倍速度，同步菜单滑轨及外侧按钮；准备与结果阶段不改变速度。
func _on_speed_selected(fast: bool) -> void:
	if _run.phase == RunRules.Phase.BATTLE:
		_fast = fast
		Global.time_scale = 2.0 if _fast else 1.0
		Engine.time_scale = Global.time_scale
		_war_ui.set_speed(_fast)


## 根据[param won]结算当前节点并冻结战场；仅第四次吃脑或最后节点结算触发整局结束与永久入库。
func _finish_game(won: bool) -> void:
	if _run.phase != RunRules.Phase.BATTLE:
		return
	_run.settle_node(won)
	_selected_id = -1
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.GameOver)
	if _run.phase == RunRules.Phase.FINISHED:
		_save_final_collection()
		call_deferred("_redraw")
	else:
		# 物理回调结束后直接进入下一节点，不展示中途结算弹窗；经济与经验已在上面结算一次。
		call_deferred("_on_next_node")


## 返回原有主菜单，退出过程会恢复窗口与暂停状态。
func _on_menu() -> void:
	if _run.phase == RunRules.Phase.FINISHED and not _run.collection_saved:
		if not _save_final_collection():
			# 未选择用户或写盘失败时保留本局内存，允许回菜单选择用户后在仓库重试保存。
			get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
			return
	Session.clear()
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])


## 开始新的十五节点整局，仅重置5阳光和空备战席；未保存的最终植物需要先保存才能被新局覆盖。
func _on_restart() -> void:
	if _run.phase == RunRules.Phase.FINISHED and not _run.collection_saved and not _save_final_collection():
		_redraw()
		return
	Session.clear()
	get_tree().change_scene_to_file("res://scenes/main/13CurrencyWar.tscn")


## 清理失效选择并刷新阳光、商店、备战与节点结果，不创建或复活植物。
func _redraw() -> void:
	if not is_instance_valid(_war_ui):
		return
	if _run.find_unit(_selected_id).is_empty():
		_selected_id = -1
	_war_ui.render(_run, _selected_id)
