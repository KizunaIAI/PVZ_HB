## 原版50×70卡位上的持有植物交互层，卡面直接复制原植物CardBg，不重绘或放大种子包。
class_name CurrencyWarReserveSlot
extends Control

## 拖拽数据类型，主草坪和备战格只接受本模式植物。
const DRAG_KIND: String = "currency_war_reserve_plant"
## 原版铲子拖动到植物或卡面时执行售卖，不是种植数据。
const SHOVEL_DRAG_KIND: String = "currency_war_sell_shovel"
## 装备图标的拖拽类型，植物和物品分别校验。
const EquipmentIcon = preload("res://scripts/currency_war/currency_war_equipment_icon.gd")
## 备战植物下方的小装备栏。
const EquipmentSlots = preload("res://scripts/currency_war/currency_war_equipment_slots.gd")
## 当前固定格位，从零开始，跨场景溢出的植物使用十格之后的位置，不随其他植物离场改变。
var slot_index: int = 0
## 请求选择备战植物[param unit_id]，兼容点击后在主草坪种植。
signal unit_selected(unit_id: int)
## 请求右键切换备战植物[param unit_id]的合成锁定，不影响拖动与出战。
signal merge_lock_requested(unit_id: int)
## 请求将[param item]拖放给本格的[param unit_id]，只有控制器成功装备后才消耗库存。
signal equipment_dropped(unit_id: int, item: String)
## 已佩戴装备的小图标被点击时，请求展示[param item]的介绍。
signal equipment_inspected(item: String)
## 铲子落到卡面时请求出售[param unit_id]，库存与装备返还由规则层处理。
signal sale_requested(unit_id: int)
## 请求将备战植物[param unit_id]移动或交换到[param target_slot]。
signal rearrange_requested(unit_id: int, target_slot: int)

## 当前单位标识，-1表示空格。
var _unit_id: int = -1
## 当前植物类型，-1表示不显示植物。
var _plant_type: int = -1
## 开局与正常战斗时可操作，海克斯和结局阶段禁用拖拽。
var _available: bool = false
## 只有准备阶段允许右键锁定或解除锁定，与战斗中仍可拖动备战植物的权限分开。
var _merge_lock_enabled: bool = false
## 是否为当前被选中的储备植物，绘制柔和的脚下光圈。
var _selected: bool = false
## 鼠标是否位于该格，决定悬浮草坪提示。
var _hovered: bool = false
## 本格是否是当前拖拽的来源，用于暂时淡化原地植物。
var _dragging_from_me: bool = false
## 植物静态拼图容器，不含任何攻击、生产或受击组件。
var _portrait_holder: Control
## 原版种子包背景，不运行原卡牌的无限种植或冷却逻辑。
var _card_face: TextureRect
## 卡片顶部的植物名称，费用区由持有星级替代。
var _card_name: Label
## 从原版卡面复制的完整植物拼图。
var _portrait: Node2D
## 星级标记显示在植物脚下，不使用卡牌边框。
var _rank: Label
## 锁定标记只表示不参与三合一，不限制移动或出售。
var _lock_mark: Label
## 普通三格和独立头盔的微型图标栏。
var _equipment_slots: EquipmentSlots
## 规则层的只读装备校验入口，参数为单位标识和物品标识。
var _equipment_validator: Callable
## 固定位置编号，让十格草坪的位置关系清晰且保持稳定。
var _number: Label


## 创建纯显示植物与格位标记；鼠标输入由本格处理，所有显示节点穿透输入。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_portrait_holder = Control.new()
	_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_holder.size = size
	add_child(_portrait_holder)
	_card_name = _label(Rect2(0, 0, 0, 0), 10)
	_card_name.hide()
	_rank = _label(Rect2(2, 55, 44, 12), 10)
	_rank.add_theme_color_override("font_color", Color("ffe096"))
	_lock_mark = _label(Rect2(29, 0, 20, 14), 11)
	_lock_mark.text = "锁"
	_lock_mark.add_theme_color_override("font_color", Color("ffe096"))
	_lock_mark.hide()
	_equipment_slots = EquipmentSlots.new()
	_equipment_slots.position = Vector2(10, 42)
	_equipment_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_slots.configure_drop_target(_can_drop_data, _drop_data)
	_equipment_slots.item_inspected.connect(equipment_inspected.emit)
	add_child(_equipment_slots)
	# 空卡位编号显示在卡面中央，已持有植物时隐藏，避免与装备条重叠。
	_number = _label(Rect2(2, 28, 46, 22), 14)
	_number.text = str(slot_index + 1)
	_number.add_theme_color_override("font_color", Color(0.92, 0.93, 0.70, 0.6))
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


## 用[param unit]更新外观；[param selected_id]控制光圈，[param enabled]控制交互，[param equipment_validator]校验装备，[param merge_lock_enabled]仅在准备阶段允许右键锁定；空字典清空该格。
func show_unit(unit: Dictionary, selected_id: int, enabled: bool, equipment_validator: Callable, merge_lock_enabled: bool) -> void:
	_unit_id = int(unit.get("id", -1))
	_available = enabled
	_merge_lock_enabled = merge_lock_enabled
	_equipment_validator = equipment_validator
	_selected = _unit_id != -1 and _unit_id == selected_id
	_set_plant_type(int(unit.get("type", -1)))
	_card_name.text = str(unit.get("display_name", "空位"))
	_number.visible = unit.is_empty()
	if is_instance_valid(_card_face):
		_card_face.modulate = Color.WHITE
	_rank.text = "★".repeat(int(unit.get("star", 0)))
	_rank.visible = not unit.is_empty() and _plant_type != 17 and _plant_type != 34
	_lock_mark.visible = not unit.is_empty() and bool(unit.get("merge_locked", false))
	_equipment_slots.visible = not unit.is_empty() and _plant_type != 17 and _plant_type != 34 and (not unit.get("equipment", []).is_empty() or bool(unit.get("helmet", false)))
	if _equipment_slots.visible:
		_equipment_slots.render_items(unit.get("equipment", []), bool(unit.get("helmet", false)), 10.0)
		_equipment_slots.position.x = (size.x - _equipment_slots.size.x) * 0.5
	tooltip_text = "空备战格 %d，可拖入其他备战植物换位。" % (slot_index + 1)
	if not unit.is_empty():
		tooltip_text = "%s · %d星\n拖动卡牌到草坪种植，或拖到其他卡位换位。\n装备图标可拖到卡面佩戴；备战期间不攻击、不产阳光。" % [unit.get("display_name", "植物"), unit.star]
		if _plant_type == 17 or _plant_type == 34:
			tooltip_text = "%s · 地形植物，不参与升星\n拖到对应地形放置，其他植物可种在其上方。" % unit.get("display_name", "植物")
		if _merge_lock_enabled:
			tooltip_text += "\n已锁定，右键解除合成锁定。" if bool(unit.get("merge_locked", false)) else "\n右键锁定，锁定后不参与升星。"
		else:
			tooltip_text += "\n已锁定；仅准备阶段可解除。" if bool(unit.get("merge_locked", false)) else "\n仅准备阶段可右键锁定。"
	_portrait_holder.modulate.a = 0.25 if _dragging_from_me else 1.0
	queue_redraw()


## 用卡片外沿表示选中和悬浮，不再绘制备战草坪上的阴影或摆动植物。
func _draw() -> void:
	if _selected or (_hovered and _available):
		draw_rect(Rect2(-1, -1, 52, 72), Color("ffe096") if _selected else Color("b9ed96"), false, 2)


## 处理[param event]的左键选择与右键合成锁定；拖动仍由原生流程接管。
func _gui_input(event: InputEvent) -> void:
	if not _available or _unit_id == -1 or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		unit_selected.emit(_unit_id)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT and _merge_lock_enabled:
		merge_lock_requested.emit(_unit_id)
		accept_event()


## 从本格局部坐标[param at_position]启动拖拽，保持抓取位置和植物尺寸；空格、外观缺失或禁用时返回null。
func _get_drag_data(at_position: Vector2) -> Variant:
	if not _available or _unit_id == -1 or not is_instance_valid(_portrait):
		return null
	# 根节点由引擎跟随鼠标；偏移放在子容器上，避免根位置被原生拖拽覆盖。
	var preview: Control = Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 用拖拽开始时的实际鼠标位置抵消格内坐标，植物不会突然跳到鼠标右下方。
	var grab_origin: Control = Control.new()
	grab_origin.position = -at_position
	grab_origin.size = size
	grab_origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(grab_origin)
	# 复制当前姿态及变换，保留备战席上的大小，不在拖动时重新适配另一套预览尺寸。
	var portrait: Node2D = _portrait.duplicate(0) as Node2D
	grab_origin.add_child(portrait)
	set_drag_preview(preview)
	_dragging_from_me = true
	_portrait_holder.modulate.a = 0.25
	return {"kind": DRAG_KIND, "unit_id": _unit_id}


## 检查从[param _at_position]落下的[param data]是否属于本局植物，场上回备战仅由规则层在准备阶段放行。
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _available and _unit_id != -1 and data is Dictionary and data.get("kind", "") == SHOVEL_DRAG_KIND:
		return true
	if _available and _unit_id != -1 and data is Dictionary and data.get("kind", "") == EquipmentIcon.DRAG_KIND:
		return _equipment_validator.is_valid() and _equipment_validator.call(_unit_id, str(data.get("item", "")))
	return _available and data is Dictionary and data.get("kind", "") == DRAG_KIND and data.has("unit_id")


## 将[param data]中的单位放入本格；[param _at_position]不影响固定格号，换位由规则层原子处理。
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		if data.get("kind", "") == SHOVEL_DRAG_KIND:
			sale_requested.emit(_unit_id)
		elif data.get("kind", "") == EquipmentIcon.DRAG_KIND:
			equipment_dropped.emit(_unit_id, str(data.item))
		else:
			rearrange_requested.emit(int(data.unit_id), slot_index)


## 处理[param what]拖拽结束通知；无效落点、窗口失焦或取消都会恢复原地显示。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging_from_me:
		_dragging_from_me = false
		if is_instance_valid(_portrait_holder):
			_portrait_holder.modulate.a = 1.0


## 切换到[param plant_type]的原版完整CardBg子树，只替换价格标签为本模式持有星级。
func _set_plant_type(plant_type: int) -> void:
	if plant_type == _plant_type:
		return
	_plant_type = plant_type
	if is_instance_valid(_card_face):
		_portrait_holder.remove_child(_card_face)
		_card_face.queue_free()
	_card_face = null
	_portrait = null
	if plant_type != -1:
		# 原卡面包含边框、完整植物和正确裁剪，复制时不挂载无限种植、冷却和原价消费逻辑。
		var source: Card = AllCards.all_plant_card_prefabs.get(plant_type)
		if not is_instance_valid(source):
			return
		_card_face = source.card_bg.duplicate(0) as TextureRect
		_card_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_holder.add_child(_card_face)
		_card_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_card_face.get_node("Cost").hide()
		_portrait = _card_face.get_node("CharacterStatic") as Node2D
		_card_face.process_mode = Node.PROCESS_MODE_DISABLED


## 在[param parent]的卡面[param rect]范围添加[param plant_type]完整拼图；返回纯绘制节点，资源缺失时返回null。
func _add_portrait(parent: Control, plant_type: int, rect: Rect2) -> Node2D:
	# 原版已经提供完整植物静态姿态，复制时不带卡牌按钮或角色脚本。
	var source: Card = AllCards.all_plant_card_prefabs.get(plant_type)
	if not is_instance_valid(source):
		return null
	# 禁止复制脚本和信号，确保储备外观不会攻击、产资源或参与碰撞。
	var portrait: Node2D = source.character_static.duplicate(0) as Node2D
	portrait.transform = Transform2D.IDENTITY
	portrait.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(portrait)
	# 完整包围盒防止高坚果被截断，小喷菇等小植物保留相对矮小的形象。
	var bounds: Rect2 = _portrait_bounds(portrait, Transform2D.IDENTITY)
	if bounds.has_area():
		# 缩放上限避免将矮小蘑菇强行放大到高坚果的高度。
		var factor: float = minf(2.15, minf(rect.size.x / bounds.size.x, rect.size.y / bounds.size.y))
		portrait.scale = Vector2.ONE * factor
		portrait.position = Vector2(rect.get_center().x - bounds.get_center().x * factor, rect.end.y - bounds.end.y * factor)
	return portrait


## 返回[param node]可见精灵在[param parent_transform]下的完整包围盒，隐藏的眨眼帧不参与计算。
func _portrait_bounds(node: Node2D, parent_transform: Transform2D) -> Rect2:
	if not node.visible:
		return Rect2()
	# 保留原版身体、花瓣与叶片的层级变换。
	var transform: Transform2D = parent_transform * node.transform
	# 空矩形表示尚未发现可绘制精灵。
	var bounds: Rect2 = Rect2()
	if node is Sprite2D and node.texture != null:
		bounds = transform * node.get_rect()
	# 所有原版静态身体部件都是二维绘制节点。
	for child: Node in node.get_children():
		if child is Node2D:
			# 当前子树在植物拼图局部坐标中的范围。
			var child_bounds: Rect2 = _portrait_bounds(child, transform)
			if child_bounds.has_area():
				bounds = bounds.merge(child_bounds) if bounds.has_area() else child_bounds
	return bounds


## 根据[param hovered]切换悬浮草坪提示，不改变植物所有权或位置。
func _on_hover(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()


## 创建备战格[param rect]范围内、字号为[param font_size]的标签，供星级和固定格号使用。
func _label(rect: Rect2, font_size: int) -> Label:
	# 标签不阻挡整株植物的拖拽手势。
	var label: Label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color("294120"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label


