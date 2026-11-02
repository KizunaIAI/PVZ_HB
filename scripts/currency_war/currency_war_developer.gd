## 开始菜单进入的开发者工具：临时属性覆盖与免费摆放，不改写植物资源或正常整局。
extends CanvasLayer

## 本模式已有植物与规则，未开发植物不加入正式牌库。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 独立开发者会话，退出时恢复开始菜单进入前保留的正常整局。
const Session = preload("res://scripts/currency_war/currency_war_session.gd")
## 当前货币战争控制器，使用动态引用接入其已有战场接口，避免脚本预加载循环。
var _game: Variant
## 当前整局规则，测试前复制其可恢复记录。
var _run: RunRules
## 进入测试前的纯数据快照，不包含角色节点和资源引用。
var _snapshot: Dictionary = {}
## 全屏透明根容器，关闭面板后不阻挡草坪。
var _root: Control
## 打开面板时拦截输入的遮罩。
var _overlay: ColorRect
## 面板以外的测试状态及连续放置提示。
var _notice: Label
## 当前编辑的已有植物类型。
var _plant_choice: OptionButton
## 当前编辑与生成的星级，一至三星，底座始终一星。
var _star: SpinBox
## 可手动生成的原版僵尸列表，排除蹦极和不能独立自然生成的伴生单位。
var _zombie_choice: OptionButton
## 原版僵尸选择项对应的稳定枚举，避免将界面序号当成类型。
var _zombie_types: Array[int] = []
## 属性键对应的数字输入框，应用时统一校验。
var _fields: Dictionary = {}
## 直接放置的行号，一基显示。
var _row: SpinBox
## 直接放置的列号，一基显示。
var _column: SpinBox
## 手动僵尸总生命覆盖，0表示使用原版生命与护甲。
var _zombie_health: SpinBox
## 正在连续摆放的对象种类，空字符串表示普通鼠标操作。
var _placement: String = ""
## 连续摆放开始时确定的植物或僵尸类型。
var _placement_type: int = -1
## 连续摆放开始时确定的星级。
var _placement_star: int = 1
## 用户主动暂停测试，与打开面板的临时暂停相互独立。
var _manual_pause: bool = false
## 显示手动暂停状态的按钮。
var _pause_button: Button
## 独立测试战场右上角的面板开关，关闭面板后仍可通过鼠标重新打开。
var _panel_button: Button


## 注入[param game]控制器及[param run]本局规则，必须在加入场景树前调用。
func configure(game: Node, run: RunRules) -> void:
	_game = game
	_run = run


## 创建独立测试场景的开发者界面，初始化完成后由开始菜单入口自动打开，不注册键盘开关。
func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = preload("res://assets/fonts/方正少儿_GBK.ttf")
	_root.theme.default_font_size = 15
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = ColorRect.new()
	_overlay.size = Vector2(1066, 600)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	_root.add_child(_overlay)
	# 独立测试窗口覆盖原版界面，不移动地图与正常商店。
	var panel: Panel = Panel.new()
	panel.position = Vector2(155, 128)
	panel.size = Vector2(756, 440)
	# 使用本模式现有的绿色与金色，输入框保留清晰的原生数字编辑。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("182d25")
	style.border_color = Color("b9cf8c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	_overlay.add_child(panel)
	_label(panel, Rect2(20, 12, 710, 32), "开发者模式", 24)
	_label(panel, Rect2(20, 44, 390, 24), "属性覆盖：同种植物、同星级共同生效", 14)
	_plant_choice = _option(panel, Rect2(20, 72, 236, 30))
	# 下拉框仅列出本模式已经开发的植物，不增加商店内容或原版新规则。
	for plant_type: int in RunRules.CATALOG:
		if not _run.is_plant_enabled(plant_type):
			continue
		_plant_choice.add_item(RunRules.CATALOG[plant_type].name, plant_type)
	_label(panel, Rect2(267, 74, 45, 24), "星级")
	_star = _spin(panel, Rect2(316, 72, 68, 30), 1, 3, 1)
	_star.value = 1
	_plant_choice.item_selected.connect(_on_plant_changed)
	_star.value_changed.connect(_on_star_changed)
	# 五项覆盖的是最终面板值，清除覆盖后恢复星级、装备和羁绊公式。
	var specs: Array[Array] = [["health", "最大生命", 1, 1000000, 1], ["damage", "伤害（单颗／爆炸）", 0, 1000000, 1], ["interval", "攻击间隔（秒）", 0.02, 120, 0.02], ["defense", "防御", 0, 100000, 1], ["reduction", "免伤（%）", 0, 100, 1]]
	# 字段顺序固定，标签与数字框逐行对齐。
	for index: int in range(specs.size()):
		# 当前字段定义包含内部键、说明与输入范围。
		var spec: Array = specs[index]
		_label(panel, Rect2(20, 115 + index * 41, 167, 28), str(spec[1]))
		_fields[spec[0]] = _spin(panel, Rect2(190, 112 + index * 41, 194, 31), spec[2], spec[3], spec[4])
	_button(panel, Rect2(20, 326, 174, 30), "应用属性", _apply_profile)
	_button(panel, Rect2(210, 326, 174, 30), "恢复此植物原值", _reset_profile)
	_label(panel, Rect2(20, 360, 390, 30), "临时覆盖最终属性；非攻击植物不会获得攻击能力。", 12)
	_label(panel, Rect2(420, 45, 316, 28), "放置工具 · 植物使用左侧种类与星级", 14)
	_zombie_choice = _option(panel, Rect2(420, 80, 316, 30))
	# 允许测试未在当前节点解锁的原版僵尸，实际放置时仍检查陆地或水路。
	for zombie_type: int in CharacterRegistry.ZombieType.values():
		if (zombie_type in Global.global_read_data.blacklist_refresh_zombie_types and zombie_type != CharacterRegistry.ZombieType.Z1002DaFeiYu) or zombie_type == CharacterRegistry.ZombieType.Z021Bungi:
			continue
		_zombie_types.append(zombie_type)
		_zombie_choice.add_item("%d · %s" % [zombie_type, _zombie_name(zombie_type)])
	_label(panel, Rect2(420, 121, 170, 24), "僵尸生命（0=原版）", 13)
	_zombie_health = _spin(panel, Rect2(592, 118, 144, 30), 0, 1000000, 1)
	_label(panel, Rect2(420, 168, 40, 25), "行")
	_row = _spin(panel, Rect2(460, 165, 91, 30), 1, _game.plant_cell_manager.all_plant_cells.size(), 1)
	_row.value = 3
	_label(panel, Rect2(580, 168, 40, 25), "列")
	_column = _spin(panel, Rect2(620, 165, 116, 30), 1, 9, 1)
	_column.value = 5
	_button(panel, Rect2(420, 208, 150, 32), "放植物到行列", _place_from_fields.bind("plant"))
	_button(panel, Rect2(586, 208, 150, 32), "放僵尸到行列", _place_from_fields.bind("zombie"))
	_button(panel, Rect2(420, 248, 150, 32), "鼠标连续放植物", _arm_placement.bind("plant"))
	_button(panel, Rect2(586, 248, 150, 32), "鼠标连续放僵尸", _arm_placement.bind("zombie"))
	_pause_button = _button(panel, Rect2(420, 288, 150, 32), "暂停测试", _toggle_pause)
	_button(panel, Rect2(586, 288, 150, 32), "清空僵尸与子弹", _clear_zombies)
	_button(panel, Rect2(420, 328, 150, 32), "植物全部回满血", _heal_plants)
	_button(panel, Rect2(586, 328, 150, 32), "清空植物", _clear_plants)
	_label(panel, Rect2(420, 363, 316, 27), "测试不刷波、不结算；僵尸默认用原版血量。", 12)
	_button(panel, Rect2(20, 398, 174, 30), "重新开始测试", _game._on_restart)
	_button(panel, Rect2(210, 398, 205, 30), "返回开始菜单", _end_test)
	_button(panel, Rect2(586, 398, 150, 30), "收起面板", _set_open.bind(false))
	_notice = _label(_root, Rect2(165, 94, 745, 30), "", 15)
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 4)
	_notice.hide()
	_overlay.hide()
	_panel_button = _button(_root, Rect2(921, 94, 130, 30), "打开工具面板", _toggle_panel)
	_load_profile()


## 处理[param event]的Esc关闭与右键取消连续放置，不使用F2等开发者开关快捷键。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo and _overlay.visible:
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif not _placement.is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_placement = ""
		_notice.text = "自由测试 · 已取消连续放置 · 点击右上角打开工具面板"
		get_viewport().set_input_as_handled()


## 从开始菜单进入后直接启动自由测试并打开面板，不播放普通节点预览或启动正常波次。
func open_session() -> void:
	_begin_test()
	_set_open(true)


## 点击独立测试场景右上角按钮时切换面板，不改变手动暂停状态。
func _toggle_panel() -> void:
	_set_open(not _overlay.visible)


## 按[param opened]切换面板与临时暂停，关闭面板不会结束正在运行的自由测试。
func _set_open(opened: bool) -> void:
	_placement = ""
	if opened:
		_game._war_ui._set_settings_visible(false)
		_load_profile()
		TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.DeveloperPanel)
	else:
		TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.DeveloperPanel)
	_overlay.visible = opened
	_panel_button.text = "收起工具面板" if opened else "打开工具面板"
	_game._war_ui.developer_input_blocked = opened
	_notice.visible = _run.developer_testing
	if _run.developer_testing:
		_notice.text = "自由测试 · %s · 点击右上角打开工具面板" % ("已暂停" if _manual_pause else "运行中")


## 进入测试前复制本局纯数据，暂停自然波次，开放全部真实行；不改变场景地形或添加免费的底座。
func _begin_test() -> void:
	if _run.developer_testing:
		return
	# 只快照脚本变量的值类型，保留随机源、整局进度对象与开发者覆盖独立生命周期。
	for property: Dictionary in _run.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or str(property.name) in ["developer_testing", "developer_overrides", "_random", "campaign"]:
			continue
		# 数组和字典深拷贝，避免测试中的购买、死亡或合成回写进入前的记录。
		var value: Variant = _run.get(property.name)
		if value is Array or value is Dictionary:
			_snapshot[property.name] = value.duplicate(true)
		elif not value is Object:
			_snapshot[property.name] = value
	_run.developer_testing = true
	_run.phase = RunRules.Phase.BATTLE
	_run.lawn_expanding = false
	_run.active_lanes.clear()
	# 只开放已有地图真实行，不创建额外地图或改变泳池、屋顶条件。
	for lane: int in range(_game.plant_cell_manager.all_plant_cells.size()):
		_run.active_lanes.append(lane)
		# 原版格子继续承接输入与地形验证，允许在任意真实行做实验。
		for cell: PlantCell in _game.plant_cell_manager.all_plant_cells[lane]:
			cell.show()
			cell.button.disabled = false
	_game.set_meta("currency_war_active_lanes", _run.active_lanes.duplicate())
	if is_instance_valid(_game._opening_lawn):
		_game._opening_lawn.hide()
		_game.background_manager.background.texture = preload("res://assets/image/background/background1.jpg")
	# 取消尚未出场的自然僵尸并停止计时器，已排队的波次刷新也由独立标记拦截。
	var waves: ZombieWaveManager = _game.zombie_manager.zombie_wave_manager
	waves.developer_refresh_suspended = true
	waves.cancel_pending_spawns()
	for timer: Node in waves.find_children("*", "Timer", true, false):
		timer.stop()
	_game.zombie_manager.is_end_wave = false
	_game.zombie_manager.check_zombie_end_wave_timer.stop()
	_game.main_game_progress = MainGameManager.E_MainGameProgress.MAIN_GAME
	_game._selected_id = -1
	# 测试中临时显示生命条，便于观察修改后的血量；不写入用户全局显示偏好。
	for plant: Plant000Base in _game._plants.values():
		if is_instance_valid(plant):
			plant.hp_component.show()
	# 已在场的正常僵尸也显示生命，不改变其原本生命与护甲。
	for zombie: Zombie000Base in _game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie):
			zombie.hp_component.show()
	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)
	_notice.show()
	_notice.text = "自由测试 · 收起面板后运行 · 自动出怪与节点结算已暂停"
	_game._redraw()


## 恢复进入测试前的纯数据；场景退出时也调用，避免测试植物或临时数值进入后续节点与仓库。
func restore_snapshot() -> void:
	if not _run.developer_testing:
		return
	# 恢复包括植物、商店、装备、阳光和经验在内的本局可变记录。
	for key: String in _snapshot:
		_run.set(key, _snapshot[key])
	_run.developer_testing = false
	_run.developer_overrides.clear()
	_snapshot.clear()


## 结束独立测试并返回开始菜单，丢弃测试单位与参数，恢复进入前保留的正常整局。
func _end_test() -> void:
	restore_snapshot()
	# 成功离开后才恢复正常整局；失败时保留入口标记，允许再次点击返回。
	var error: Error = get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
	if error == OK:
		Session.end_developer()
	else:
		_notice.text = "无法返回开始菜单：%s" % error_string(error)
		_notice.show()


## 接收[param cell]草坪点击；连续放置时返回true，普通鼠标操作返回false交回原控制器。
func handle_cell(cell: PlantCell) -> bool:
	if _placement.is_empty() or _overlay.visible:
		return false
	_place(_placement, _placement_type, _placement_star, cell)
	return true


## 将[param kind]的当前选择放到行列输入对应的原版格子，仍允许暂停状态下摆放。
func _place_from_fields(kind: String) -> void:
	_begin_test()
	# 输入框范围与真实场景同步，数组使用零基索引。
	var cell: PlantCell = _game.plant_cell_manager.all_plant_cells[int(_row.value) - 1][int(_column.value) - 1]
	_place(kind, _selected_plant() if kind == "plant" else _zombie_types[_zombie_choice.selected], int(_star.value), cell)


## 选定[param kind]对象后隐藏面板，左键格子可重复摆放，右键取消。
func _arm_placement(kind: String) -> void:
	_begin_test()
	_set_open(false)
	_placement = kind
	_placement_type = _selected_plant() if kind == "plant" else _zombie_types[_zombie_choice.selected]
	_placement_star = int(_star.value)
	_notice.text = "自由测试 · 左键格子连续放%s · 右键取消 · 右上角打开面板" % ("植物" if kind == "plant" else "僵尸")


## 免费将[param kind]的[param type]、[param star]对象放到[param cell]；地形不匹配或植物占位时保留已有单位。
func _place(kind: String, type: int, star: int, cell: PlantCell) -> void:
	if kind == "plant":
		if type == 12:
			# 墓碑吞噬者直接释放到僵尸，不能沿用原版必须种在墓碑上的判定。
			if _game._grave_target(cell) == null:
				_notice.text = "该格没有可吞噬的敌军僵尸。"
				return
			# 测试专用备战卡仍走正式技能入口，保留真实星级冷却和友军生成。
			var skill_id: int = _run.developer_add_skill_card(type, star)
			_game._use_grave_buster(skill_id, cell)
			return
		# 机枪沿用模式的直接种植条件，水面和屋顶仍需先放睡莲或花盆。
		var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		if not condition.judge_is_can_plant(cell, type):
			_notice.text = "该格已有同层植物或地形不符；泳池先放睡莲、屋顶先放花盆。"
			return
		if _run.developer_add_plant(type, star, cell.row_col) != -1:
			_game._sync_battlefield()
	else:
		# 原版陆地与水路限制继续有效，防止潜水僵尸等进入没有对应地形的行。
		var terrain: int = Global.character_registry.get_zombie_info(type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
		# 行节点保存真实地形类型，普通、路障等Both僵尸由原版初始化其水上状态。
		var row: ZombieRow = _game.zombie_manager.all_zombie_rows[cell.row_col.x]
		if terrain != CharacterRegistry.ZombieRowType.Both and terrain != row.zombie_row_type:
			_notice.text = "此僵尸不适合该行地形，请换到对应陆地或水路。"
			return
		# 脚底沿用原版行生成高度，只将横坐标移到选中的格子中央。
		var position: Vector2 = row.zombie_create_position.global_position
		position.x = cell.get_global_rect().get_center().x
		_game.zombie_manager.create_norm_zombie(type, row, {Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm, Zombie000Base.E_ZInitAttr.Lane: cell.row_col.x}, position, _tag_zombie)
	_notice.text = "自由测试 · 已放置%s · 右键取消连续放置，右上角打开面板" % (RunRules.CATALOG[type].name if kind == "plant" else _zombie_name(type))
	_game._redraw()


## 给[param zombie]标记手动测试来源；生命输入为正时仅覆盖本只总生命，0保留原版，不应用奖励关一血。
func _tag_zombie(zombie: Zombie000Base) -> void:
	zombie.set_meta("currency_war_developer_zombie", true)
	zombie.ready.connect(_show_test_zombie.bind(zombie), CONNECT_ONE_SHOT)
	if _zombie_health.value > 0:
		# 创建前修改基础生命，ready后修正一血等小数值的原版负死亡阈值。
		var hp: HpComponentZombie = zombie.get_node("HpComponent")
		hp.max_hp = int(_zombie_health.value)
		hp.max_hp_armor1 = 0
		hp.max_hp_armor2 = 0
		zombie.ready.connect(_fix_test_health.bind(zombie), CONNECT_ONE_SHOT)


## [param zombie]完成原版生命组件初始化后显示血条，仅影响当前测试实体。
func _show_test_zombie(zombie: Zombie000Base) -> void:
	zombie.hp_component.show()


## 校正[param zombie]手动生命覆盖后的死亡阈值，保持归零死亡，不限制植物造成的单次伤害。
func _fix_test_health(zombie: Zombie000Base) -> void:
	zombie.hp_component.set_death_hp(0)
	# 过低生命生成的阶段阈值不得为负，手部与头部仍可按原版在归零时掉落。
	for index: int in range(zombie.hp_stage_change_component.boundary_value_hp.size()):
		zombie.hp_stage_change_component.boundary_value_hp[index] = maxi(0, zombie.hp_stage_change_component.boundary_value_hp[index])


## 切换自由测试手动暂停，关闭面板后也保留用户指定的暂停状态。
func _toggle_pause() -> void:
	_begin_test()
	_manual_pause = not _manual_pause
	_pause_button.text = "继续测试" if _manual_pause else "暂停测试"
	if _manual_pause:
		TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.DeveloperTest)
	else:
		TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.DeveloperTest)


## 清空测试战场的僵尸和现存子弹，不发节点奖励、不推进整局。
func _clear_zombies() -> void:
	_begin_test()
	# 复制列表后逐个清除，并关闭亡语，避免雪橇或巨人清理时再次召唤测试残留。
	for zombie: Zombie000Base in _game.zombie_manager.all_zombies_1d.duplicate():
		if is_instance_valid(zombie):
			zombie.is_can_death_language = false
			zombie.character_death_disappear()
	# 删除现存飞行物，避免新放入的目标被上一轮测试的子弹误伤。
	for bullet: Node in _game.bullets.get_children():
		bullet.queue_free()


## 清空测试植物，进入测试前的植物仍保存在快照中，结束测试可恢复。
func _clear_plants() -> void:
	_begin_test()
	_run.units.clear()
	_run.helmet_unit_id = -1
	_game._sync_battlefield()
	_game._redraw()


## 将当前存活植物恢复到其测试最大生命，不复活已经阵亡的逻辑单位。
func _heal_plants() -> void:
	_begin_test()
	# 仅处理仍有效的实体，不在节点记录外重复创建植物。
	for plant: Plant000Base in _game._plants.values():
		if is_instance_valid(plant) and not plant.is_death:
			plant.hp_component.curr_hp = plant.hp_component.max_hp


## 使用下拉选中的植物枚举，界面位置不作为植物类型。
func _selected_plant() -> int:
	return _plant_choice.get_selected_id()


## [param _index]改变时刷新属性预览，底座始终只编辑一星。
func _on_plant_changed(_index: int) -> void:
	_star.editable = not _run.is_support(_selected_plant())
	if not _star.editable:
		_star.set_value_no_signal(1)
	_load_profile()


## [param _value]星级改变时刷新该类型与星级的属性，不立即改变战场。
func _on_star_changed(_value: float) -> void:
	_load_profile()


## 从未入树的原版资源读取默认生命、单发或爆炸伤害及星级间隔，不产生战斗实体。
func _load_profile() -> void:
	# 按类型与星级独立覆盖，恢复原值时不会影响其他植物或星级。
	var key: String = "%d:%d" % [_selected_plant(), int(_star.value)]
	# 显示尚未覆盖时的原版星级基准，不把别株植物的装备加成当成资源基础值。
	var values: Dictionary = _default_profile(_selected_plant(), int(_star.value))
	if _run.developer_overrides.has(key):
		values = _run.developer_overrides[key]
	# 内部免伤采用0至1，输入框以百分比显示。
	for field: String in _fields:
		_fields[field].set_value_no_signal(float(values[field]) * (100.0 if field == "reduction" else 1.0))


## 返回[param type]植物的[param star]星默认面板快照；非攻击植物伤害0，不凭空赋予攻击能力。
func _default_profile(type: int, star: int) -> Dictionary:
	# 资源实例不进入树，通用模板统一读取普通、爆炸和特殊攻击的真实基础数值。
	var sample: Plant000Base = Global.character_registry.get_plant_info(type, CharacterRegistry.PlantInfoAttribute.PlantScenes).instantiate()
	# 无攻击植物返回0伤害、0间隔，输入框的间隔仅为面板占位，不创建新的攻击能力。
	var profile: Dictionary = RunRules.PlantTemplate.native_attack_profile(sample)
	# 土豆地雷遵守独有倍率，其余按独有或通用攻击模板，不把通用值覆盖已定义植物。
	var damage_scale: float = [1.0, 1.5, 2.5][star - 1] if type == 5 else 1.0 + _run.star_attack_bonus(type, star)
	# 坚果默认血量使用独有70%/120%提升，开发者面板与实际生成保持一致。
	var health_scale: float = [1.0, 1.7, 2.2][clampi(star, 1, 3) - 1] if type == 4 else ([1.0, 2.0, 6.0][clampi(star, 1, 3) - 1] if type == 24 else 1.0)
	# 默认属性不混入现存植物的装备或羁绊，以免重复计算。
	var values: Dictionary = {"health": roundi(sample.get_node("HpComponent").max_hp * health_scale), "damage": float(profile.damage) * damage_scale, "interval": float(profile.interval) / (1.0 + _run.star_speed_bonus(type, star)) if profile.interval > 0.0 else 1.5, "defense": 0.0, "reduction": 0.0}
	sample.free()
	return values


## 应用五项临时最终值，并立即同步同类型同星级的现存植物与后续生成植物。
func _apply_profile() -> void:
	_begin_test()
	# 输入框已限制范围，内部免伤换算为0至1。
	var values: Dictionary = {}
	# 每个覆盖字段写入独立字典，不改共享植物资源或正常装备定义。
	for field: String in _fields:
		values[field] = float(_fields[field].value) / (100.0 if field == "reduction" else 1.0)
	_run.developer_overrides["%d:%d" % [_selected_plant(), int(_star.value)]] = values
	_game._apply_current_bonuses()
	_notice.text = "自由测试 · 已应用%s %d星属性 · 返回开始菜单后丢弃临时参数" % [RunRules.CATALOG[_selected_plant()].name, int(_star.value)]


## 清除当前类型与星级的覆盖，恢复正常星级、装备及羁绊公式。
func _reset_profile() -> void:
	_run.developer_overrides.erase("%d:%d" % [_selected_plant(), int(_star.value)])
	_game._apply_current_bonuses()
	_load_profile()


## 返回[param type]原版僵尸中文名，未知扩展类型使用注册资源名。
func _zombie_name(type: int) -> String:
	if type == CharacterRegistry.ZombieType.Z1002DaFeiYu:
		return "大肥鱼（Boss）"
	# 枚举顺序保持与原版注册表一致，仅用于显示，不决定出怪解锁顺序。
	var names: Array[String] = ["", "普通", "旗帜", "路障", "撑杆", "铁桶", "读报", "铁门", "橄榄球", "舞王", "伴舞", "鸭子圈", "潜水", "冰车", "雪橇", "海豚", "小丑", "气球", "矿工", "跳跳", "雪人", "蹦极", "扶梯", "投篮车", "巨人", "小鬼"]
	return names[type] if type < names.size() else str(Global.character_registry.get_zombie_info(type, CharacterRegistry.ZombieInfoAttribute.ZombieName))


## 在[param parent]的[param rect]创建显示[param text]、字号[param font_size]的鼠标穿透标签。
func _label(parent: Node, rect: Rect2, text: String, font_size: int = 15) -> Label:
	# 标签不抢占数字框、按钮或草坪输入。
	var label: Label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("dcebcf"))
	parent.add_child(label)
	return label


## 在[param parent]的[param rect]创建显示[param text]的按钮，点击时调用[param action]。
func _button(parent: Node, rect: Rect2, text: String, action: Callable) -> Button:
	# 固定位置不依赖原版隐藏卡槽的布局。
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## 在[param parent]的[param rect]创建数字框，范围为[param minimum]至[param maximum]，精度由[param step]决定。
func _spin(parent: Node, rect: Rect2, minimum: float, maximum: float, step: float) -> SpinBox:
	# 非法数值通过控件范围限制，避免0生命或0攻击间隔导致除零。
	var spin: SpinBox = SpinBox.new()
	spin.position = rect.position
	spin.size = rect.size
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	parent.add_child(spin)
	return spin


## 在[param parent]的[param rect]创建可搜索前缀的原生下拉框。
func _option(parent: Node, rect: Rect2) -> OptionButton:
	# 植物和僵尸选择项分别保存实际类型，不依赖中文名称反查。
	var option: OptionButton = OptionButton.new()
	option.position = rect.position
	option.size = rect.size
	parent.add_child(option)
	return option
