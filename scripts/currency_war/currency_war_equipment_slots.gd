## 植物脚下的小装备栏，普通三槽与独立头盔使用同一套占位图标，仅显示已持有装备。
extends Control

## 共用图标，不允许从植物身上拖出普通装备。
const Icon = preload("res://scripts/currency_war/currency_war_equipment_icon.gd")
## 向界面转发点击物品[param item]的介绍请求。
signal item_inspected(item: String)
## 当前图标签名，防止战斗刷新不断重建节点。
var _signature: String = ""
## 装备落点的只读校验入口，来自场上植物或备战卡。
var _can_drop_callback: Callable
## 装备有效落下后的处理入口，不自行修改库存。
var _drop_callback: Callable


## 注入[param can_drop]与[param drop]，让小图标上的落点与整株植物使用相同规则。
func configure_drop_target(can_drop: Callable, drop: Callable) -> void:
	_can_drop_callback = can_drop
	_drop_callback = drop


## 校验落到图标上的[param data]；[param at_position]传给目标统一处理，不决定装备槽。
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _can_drop_callback.is_valid() and _can_drop_callback.call(at_position, data)


## 将[param at_position]与[param data]转发给植物，拖动取消或校验失败不会消耗装备。
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data) and _drop_callback.is_valid():
		_drop_callback.call(at_position, data)


## 显示[param items]的三个普通槽和独立[param helmet]；[param icon_size]决定场上及备战的小栏尺寸。
func render_items(items: Array, helmet: bool, icon_size: float = 18.0) -> void:
	# 只在装备内容变化时重建，不让攻击动作叠层影响拖放目标。
	var signature: String = JSON.stringify([items, helmet, icon_size])
	if signature == _signature:
		return
	_signature = signature
	# 所有子图标透传鼠标，整个栏的拖放交给植物自身或父控制器。
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	size = Vector2((4 if helmet else 3) * icon_size, icon_size)
	# 三个普通槽始终可见，帮助判断是否满装。
	for slot: int in range(4 if helmet else 3):
		# 独立头盔只在第四格显示，不挤占三件普通装备。
		var item: String = "helmet" if slot == 3 else (str(items[slot]) if slot < items.size() else "")
		# 点击只展示介绍；已佩戴装备不能直接拖出或卸下。
		var icon: Control = Icon.new()
		icon.size = Vector2.ONE * icon_size
		icon.position.x = slot * icon_size
		icon.configure(item)
		icon.inspected.connect(item_inspected.emit)
		icon.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
		add_child(icon)
