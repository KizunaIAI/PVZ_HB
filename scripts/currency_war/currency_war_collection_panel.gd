## 主菜单仓库界面，只展示整局结束保留的植物；不提前加入未来冒险的取用或出售规则。
extends CanvasLayer

## 仓库读取与整局存入接口。
const Collection = preload("res://scripts/currency_war/currency_war_collection.gd")
## 未能保存的最终结果仍由会话保留，允许用户在主菜单选好用户后重试。
const Session = preload("res://scripts/currency_war/currency_war_session.gd")
## 现有植物中文名称，缺失类型使用原版注册名而不补写玩法数据。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 复用已有图片卡展示植物外观和星级，不提供购买操作。
const PlantCard = preload("res://scripts/currency_war/currency_war_plant_card.gd")
## 仓库存储装备的中文名称与说明。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 库状态标签，显示当前用户、植物数或读取失败原因。
var _status: Label
## 展示每株永久植物的可滚动网格，不新增数量限制或自动合成。
var _grid: GridContainer
## 无用户或存储失败时的手动重试按钮，成功后隐藏。
var _retry: Button
## 仓库内未佩戴装备的数量摘要。
var _equipment_summary: Label


## 建立覆盖主菜单的仓库面板，尺寸沿用1066×600的原版主菜单视口。
func _ready() -> void:
	layer = 100
	# 全屏遮罩拦截后方主菜单按钮，关闭后恢复原菜单。
	var overlay: ColorRect = ColorRect.new()
	overlay.size = Vector2(1066, 600)
	overlay.color = Color(0.03, 0.07, 0.04, 0.72)
	add_child(overlay)
	# 面板沿用已有草绿和金色，不生成新的图片资产。
	var panel: Panel = Panel.new()
	panel.position = Vector2(118, 52)
	panel.size = Vector2(830, 496)
	panel.theme = Theme.new()
	panel.theme.default_font = preload("res://assets/fonts/方正少儿_GBK.ttf")
	panel.theme.default_font_size = 17
	# 独立样式不修改原版主菜单的主题资源。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("182d25")
	style.border_color = Color("b9cc8e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	# 标题不增加库容量、装备槽或未来冒险部署等尚未定义的功能。
	var title: Label = Label.new()
	title.position = Vector2(24, 16)
	title.text = "仓库"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("f0cf7b"))
	panel.add_child(title)
	_status = Label.new()
	_status.position = Vector2(24, 58)
	_status.size = Vector2(782, 30)
	panel.add_child(_status)
	# 一株一个展示项，同种植物也保留独立记录与星级。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(24, 98)
	scroll.size = Vector2(782, 260)
	panel.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 13)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_equipment_summary = Label.new()
	_equipment_summary.position = Vector2(24, 372)
	_equipment_summary.size = Vector2(782, 58)
	_equipment_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_summary.add_theme_font_size_override("font_size", 15)
	panel.add_child(_equipment_summary)
	_retry = Button.new()
	_retry.position = Vector2(24, 442)
	_retry.size = Vector2(280, 34)
	_retry.text = "重试保存本局植物"
	_retry.pressed.connect(_retry_store)
	panel.add_child(_retry)
	# 关闭只返回原主菜单，不消费或领取任何植物。
	var close: Button = Button.new()
	close.position = Vector2(650, 442)
	close.size = Vector2(156, 34)
	close.text = "返回主菜单"
	close.pressed.connect(hide)
	panel.add_child(close)
	hide()


## 打开仓库并按当前主菜单用户重新读取，不缓存其他用户的植物数据。
func open_collection() -> void:
	show()
	_refresh()


## 刷新卡面与保存状态，读取失败时保留磁盘原文件且不显示假成功。
func _refresh() -> void:
	# 清理旧用户显示节点，当前帧即可重新填充，不保留可交互的旧卡面。
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	# 存储接口按当前已选择用户定位文件。
	var data: Dictionary = Collection.load_collection()
	_status.text = "%s · 共%d株植物" % [Global.user_manager.curr_user_name, data.plants.size()]
	if Global.user_manager.curr_user_name.is_empty():
		_status.text = "请先在主菜单选择用户，仓库按用户分别保存。"
	elif not data.ok:
		_status.text = "仓库读取失败，原文件已保留。"
	# 只显示已保存实体的数据；不实例化战斗植物，不参与生产或攻击。
	for unit: Variant in data.plants:
		if not unit is Dictionary or not CharacterRegistry.PlantInfo.has(int(unit.get("type", -1))):
			continue
		# 图片卡沿用现有外观，关闭鼠标交互以避免被误认为可购买或可取用。
		var card: PlantCard = PlantCard.new()
		card.custom_minimum_size = Vector2(140, 130)
		card.size = Vector2(140, 130)
		_grid.add_child(card)
		# 名称优先使用现有中文配置，后续冒险可继续沿用稳定的植物类型编号。
		var plant_name: String = RunRules.CATALOG[int(unit.type)].name if RunRules.CATALOG.has(int(unit.type)) else str(CharacterRegistry.PlantInfo[int(unit.type)][CharacterRegistry.PlantInfoAttribute.PlantName])
		card.show_plant(int(unit.type), plant_name, "地形植物" if int(unit.type) == 17 or int(unit.type) == 34 else "★".repeat(int(unit.star)), "", false, true, Color("ecf1df"))
		# 仓库卡仅查看，悬浮显示已佩戴物品，不提供未来冒险的取用操作。
		var names: PackedStringArray = []
		# 普通槽位逐件显示，头盔另列。
		for item: String in unit.get("equipment", []):
			names.append(Equipment.ITEMS[item].name if Equipment.ITEMS.has(item) else item)
		if bool(unit.get("helmet", false)):
			names.append("机枪头盔")
		card.tooltip_text = "装备：" + ("、".join(names) if not names.is_empty() else "无")
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_HELP
	# 背包装备聚合仅供显示，文件和运行状态保留每件物品。
	var counts: Dictionary = {}
	# 旧文件没有装备时返回空数组，不生成免费物品。
	for item: String in data.equipment:
		counts[item] = int(counts.get(item, 0)) + 1
	# 每类名称只显示一次并标出数量。
	var summary: PackedStringArray = []
	# 未来扩展装备保留原标识，不错误丢弃旧库中已有数据。
	for item: String in counts:
		summary.append("%s×%d" % [Equipment.ITEMS[item].name if Equipment.ITEMS.has(item) else item, counts[item]])
	_equipment_summary.text = "背包装备：" + ("、".join(summary) if not summary.is_empty() else "无")
	_retry.visible = Session.active_run != null and Session.active_run.phase == RunRules.Phase.FINISHED and not Session.active_run.collection_saved


## 用户选好主菜单用户后重试保存待入库的最终整局，不在中途节点复制植物。
func _retry_store() -> void:
	if Session.active_run == null or Session.active_run.phase != RunRules.Phase.FINISHED:
		return
	# 同一整局批次再次提交时由存储层保证幂等，不重复加植物。
	var error: Error = Collection.store_run(Session.active_run.campaign.run_key, Session.active_run.warehouse_units(), Session.active_run.warehouse_equipment())
	Session.active_run.collection_saved = error == OK
	_refresh()
	if error != OK:
		_status.text = "保存失败，本局植物仍保留，请检查用户与存档后重试。"
