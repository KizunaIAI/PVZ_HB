## 庭院左侧常驻装备栏，装备按图标显示并拖向植物，不再弹出背包窗口。
extends Panel

## 当前整局状态，只读背包与可操作阶段。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 左栏可拖出的原生装备图标。
const Icon = preload("res://scripts/currency_war/currency_war_equipment_icon.gd")
## 左侧图标的介绍请求，不改变装备所有权。
signal item_inspected(item: String)
## 可滚动图标容器，同种物品聚合为数量角标。
var _items: GridContainer
## 空背包提示，不展示不存在的免费装备。
var _empty: Label
## 背包内容签名，拖动过程中不因HUD刷新重建来源。
var _signature: String = ""
## 始终留在屏幕边缘的三角收放按钮。
var _toggle: Button
## 当前是否已向左隐藏装备栏。
var _collapsed: bool = false
## 装备栏移动动画，连续点击时从当前坐标反向。
var _slide_tween: Tween


## 将装备放在用户指定的房屋左侧纵栏，不覆盖草坪和小推车。
func _ready() -> void:
	position = Vector2(8, 132)
	size = Vector2(76, 438)
	_toggle = Button.new()
	_toggle.position = Vector2(76, 8)
	_toggle.size = Vector2(24, 28)
	_toggle.text = "◀"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = "收起装备栏"
	_toggle.pressed.connect(_toggle_equipment)
	add_child(_toggle)
	# 局部半透明底板只覆盖左侧窄栏。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.20, 0.14, 0.88)
	style.border_color = Color("9ca775")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	# 常驻标题无需点击展开。
	var title: Label = Label.new()
	title.position = Vector2(7, 5)
	title.size = Vector2(62, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "装备"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	# 物品增加时仅在左栏内部滚动，不把装备面板铺到战场中间。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(4, 34)
	scroll.size = Vector2(68, 396)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	_items = GridContainer.new()
	_items.columns = 2
	_items.add_theme_constant_override("h_separation", 2)
	_items.add_theme_constant_override("v_separation", 5)
	scroll.add_child(_items)
	_empty = Label.new()
	_empty.position = Vector2(7, 45)
	_empty.size = Vector2(62, 85)
	_empty.text = "暂无\n装备"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)


## 左移隐藏装备栏，仅保留三角按钮；再次点击从左侧展开，不修改库存或暂停战斗。
func _toggle_equipment() -> void:
	_collapsed = not _collapsed
	if is_instance_valid(_slide_tween):
		_slide_tween.kill()
	_toggle.text = "▶" if _collapsed else "◀"
	_toggle.tooltip_text = "展开装备栏" if _collapsed else "收起装备栏"
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property(self, "position:x", -76.0 if _collapsed else 8.0, 0.25)


## 用[param run]刷新可拖动物品；[param _selected_id]不再是佩戴前提，装备直接落到目标植物。
func render_run(run: RunRules, _selected_id: int) -> void:
	run.sync_helmet()
	# 包含可操作状态，镜头预览期间图标可见但不能拖动。
	var signature: String = JSON.stringify([run.equipment_inventory, run.can_manage(), run.helmet_unit_id, run.pea_bonus().tier])
	if signature == _signature:
		return
	_signature = signature
	# 数量聚合不改变真实库存，每次有效拖放仍然只消耗一件。
	var counts: Dictionary = {}
	# 所有重复掉落逐件计数。
	for item: String in run.equipment_inventory:
		counts[item] = int(counts.get(item, 0)) + 1
	if run.pea_bonus().tier > 0 and run.helmet_unit_id == -1:
		counts["helmet"] = 1
	# 内容变化时替换图标，攻击叠层不会触发这一步。
	for child: Node in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	_empty.visible = counts.is_empty()
	# 图标采用原生绘制的临时占位形状，不自行发放测试装备。
	for item: String in counts:
		# 固定大小适配两列装备栏。
		var icon: Control = Icon.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.size = Vector2(32, 32)
		icon.configure(item, int(counts[item]), run.can_manage())
		icon.inspected.connect(item_inspected.emit)
		_items.add_child(icon)
