## 临时装备图标：原生绘制刀剑、护甲、符石等形状，支持从装备栏拖出，不生成免费装备。
extends Control

## 装备名称与说明，只读取已定义物品。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 与植物拖拽区分的数据类型。
const DRAG_KIND: String = "currency_war_equipment"
## 点击图标时展示[param item]的已定义属性和介绍。
signal inspected(item: String)
## 当前绘制的装备标识，空字符串表示空槽。
var _item: String = ""
## 左侧同类装备数量，小于二时不显示角标。
var _quantity: int = 1
## 仅左侧未佩戴装备允许拖动，植物脚下图标只显示。
var _draggable: bool = false
## 拖动预览不接收点击，真实装备图标可显示介绍。
var _inspectable: bool = true
## 左键按下后等待释放；开始拖动时取消，避免拖放结束误弹介绍。
var _click_armed: bool = false


## 用[param item]、[param quantity]和[param draggable]更新外观与拖动；[param inspectable]控制点击介绍，空物品不接收点击。
func configure(item: String, quantity: int = 1, draggable: bool = false, inspectable: bool = true) -> void:
	_item = item
	_quantity = quantity
	_draggable = draggable
	_inspectable = inspectable and not item.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP if draggable or _inspectable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_DRAG if draggable else Control.CURSOR_ARROW
	tooltip_text = "%s\n%s\n%s" % [Equipment.ITEMS[item].name, Equipment.ITEMS[item].tip, "点击查看介绍；拖到植物身上佩戴。" if draggable else "点击查看加成与介绍。"] if Equipment.ITEMS.has(item) else "空装备槽"
	queue_redraw()


## 处理[param event]的单击介绍，拖动已取消点击资格，不影响原生装备拖放。
func _gui_input(event: InputEvent) -> void:
	if not _inspectable or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_click_armed = true
	elif _click_armed:
		_click_armed = false
		inspected.emit(_item)
	accept_event()


## 在统一32像素坐标系绘制占位图标，植物脚下使用同一图案缩小显示。
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(32, 32))
	draw_rect(Rect2(1, 1, 30, 30), Color("263a28"))
	draw_rect(Rect2(1, 1, 30, 30), Color("b9ba79") if not _item.is_empty() else Color("6b7654"), false, 1.2)
	if _item.is_empty():
		return
	# 小件和成装分别使用银白与金色武器；非武器用不同轮廓区分。
	var metal: Color = Color("e0e9db") if Equipment.BASIC.has(_item) else Color("f3ce76")
	match _item:
		"knife", "sword", "spine", "breaker":
			draw_colored_polygon(PackedVector2Array([Vector2(12, 21), Vector2(21, 6), Vector2(26, 5), Vector2(25, 11), Vector2(15, 23)]), metal)
			draw_line(Vector2(8, 20), Vector2(18, 26), Color("af8556"), 3, true)
			draw_line(Vector2(12, 23), Vector2(8, 29), Color("e8c48c"), 3, true)
			if _item == "spine":
				draw_line(Vector2(9, 8), Vector2(25, 26), metal, 3, true)
			if _item == "breaker":
				draw_line(Vector2(17, 8), Vector2(25, 15), Color("e98664"), 3, true)
		"armor", "chain":
			draw_colored_polygon(PackedVector2Array([Vector2(6, 8), Vector2(16, 4), Vector2(26, 8), Vector2(24, 21), Vector2(16, 28), Vector2(8, 21)]), metal)
			draw_line(Vector2(16, 8), Vector2(16, 23), Color("426c60"), 3, true)
			if _item == "chain":
				draw_line(Vector2(9, 15), Vector2(23, 15), Color("426c60"), 3, true)
		"charm", "pendant":
			draw_arc(Vector2(16, 11), 7, PI, TAU, 16, metal, 2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(16, 10), Vector2(24, 18), Vector2(16, 28), Vector2(8, 18)]), Color("e97886") if _item == "pendant" else Color("90d5bc"))
			draw_circle(Vector2(16, 17), 2, Color("fff3cd"))
		"shiv":
			draw_colored_polygon(PackedVector2Array([Vector2(18, 4), Vector2(7, 18), Vector2(14, 18), Vector2(12, 29), Vector2(26, 13), Vector2(18, 13)]), Color("f5dc64"))
		"helmet":
			draw_circle(Vector2(16, 16), 11, Color("81bd68"))
			draw_rect(Rect2(7, 15, 19, 7), Color("476b52"))
			draw_line(Vector2(20, 11), Vector2(28, 8), metal, 4, true)
	if _quantity > 1:
		draw_circle(Vector2(25, 25), 7, Color("15271c"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 29), str(_quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff1ba"))


## 从[param at_position]拖出一个装备；取消拖动不会移出背包，实际消耗由装备规则处理。
func _get_drag_data(at_position: Vector2) -> Variant:
	if not _draggable or _item.is_empty():
		return null
	_click_armed = false
	# 预览根由引擎跟随鼠标，内部图标抵消抓取偏移。
	var preview: Control = Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 复制纯绘制图标，不复制背包状态或制造物品。
	var icon: Control = get_script().new()
	icon.size = size
	icon.position = -at_position
	icon.configure(_item, 1, false, false)
	preview.add_child(icon)
	set_drag_preview(preview)
	return {"kind": DRAG_KIND, "item": _item}
