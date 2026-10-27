## 阳光战争的图片卡牌；复用原版静态植物拼图，统一显示名称、阳光费用、星级和合成进度。
class_name CurrencyWarPlantCard
extends Button

## 是否为商店卡；手牌展示星级，商店展示阳光价格和买入合成提示。
var is_shop_card: bool = false
## 当前植物图案所属种类；-1代表空位，避免每次阳光变化都重新创建图案。
var _portrait_type: int = -1
## 植物图片的裁剪容器，只负责绘制，不拦截鼠标。
var _portrait_holder: Control
## 从原版静态卡牌复制的植物图案，不挂载任何战斗逻辑。
var _portrait: Node2D
## 卡牌顶部的植物中文名称。
var _name_label: Label
## 商店阳光价格或手牌星级的醒目标记。
var _badge: Label
## 当前同名同星的合成进度或购买后可升星提示。
var _progress_label: Label
## 空手牌或售出栏位的占位文字。
var _empty_label: Label
## 暗绿色普通背景样式，初始化后重复使用。
var _normal_style: StyleBoxFlat
## 金色高亮样式，表示选中或买入即合成。
var _highlight_style: StyleBoxFlat


## 创建只负责显示的子节点；全部穿透鼠标，让整张图片都能点击。
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_normal_style = _make_style(Color("24402f"), Color("52684a"), 1)
	_highlight_style = _make_style(Color("3e482a"), Color("f2d280"), 2)
	add_theme_stylebox_override("normal", _normal_style)
	add_theme_stylebox_override("hover", _make_style(Color("365438"), Color("c5e8a0"), 2))
	add_theme_stylebox_override("pressed", _highlight_style)
	add_theme_stylebox_override("disabled", _make_style(Color("192b22"), Color("344b39"), 1))
	_name_label = _make_label(Rect2(5, 4, size.x - 10, 18), 12)
	_badge = _make_label(Rect2(4, size.y - 23, size.x - 8, 19), 16)
	_badge.add_theme_color_override("font_color", Color("f2d280"))
	_progress_label = _make_label(Rect2(size.x - 28, 24, 25, 17), 11)
	_empty_label = _make_label(Rect2(3, 0, size.x - 6, size.y), 12)
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", Color("788d79"))
	_portrait_holder = Control.new()
	_portrait_holder.position = Vector2(6, 23)
	_portrait_holder.size = Vector2(size.x - 12, size.y - 48)
	_portrait_holder.clip_contents = true
	_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_holder)
	move_child(_portrait_holder, 0)
	if is_shop_card:
		_name_label.position = Vector2(3, 3)
		_name_label.size = Vector2(size.x - 6, 17)
		_badge.position = Vector2(3, 61)
		_badge.size = Vector2(size.x - 6, 19)
		_badge.add_theme_font_size_override("font_size", 14)
		_progress_label.position = Vector2(3, 81)
		_progress_label.size = Vector2(size.x - 6, 13)
		_progress_label.add_theme_font_size_override("font_size", 10)
		_portrait_holder.position = Vector2((size.x - 48) * 0.5, 20)
		_portrait_holder.size = Vector2(48, 41)


## 显示[param plant_type]植物，使用[param plant_name]、[param badge]和[param progress]文案；[param highlighted]高亮选择，[param available]控制可点击性，[param tint]为稀有度颜色。
func show_plant(plant_type: int, plant_name: String, badge: String, progress: String, highlighted: bool, available: bool, tint: Color) -> void:
	_set_portrait(plant_type)
	_name_label.text = plant_name
	_name_label.add_theme_color_override("font_color", tint if available else Color("a2aa98"))
	_badge.text = badge
	_badge.add_theme_color_override("font_color", Color("f2d280") if available else Color("c98a78"))
	_progress_label.text = progress
	_progress_label.add_theme_color_override("font_color", Color("f2d280") if highlighted else Color("a8c1a0"))
	_portrait_holder.modulate = Color.WHITE if available else Color(0.62, 0.62, 0.62, 0.85)
	_name_label.show()
	_badge.show()
	_progress_label.show()
	_portrait_holder.show()
	_empty_label.hide()
	disabled = not available
	add_theme_stylebox_override("normal", _highlight_style if highlighted else _normal_style)


## 显示[param caption]占位，移除之前的植物图案，防止售空卡仍显示旧植物。
func show_empty(caption: String) -> void:
	_set_portrait(-1)
	_name_label.hide()
	_badge.hide()
	_progress_label.hide()
	_portrait_holder.hide()
	_empty_label.text = caption
	_empty_label.show()
	disabled = true
	tooltip_text = ""


## 切换为[param plant_type]的原版植物拼图；只复制静态绘制节点，不复制原版种植按钮和脚本。
func _set_portrait(plant_type: int) -> void:
	if plant_type == _portrait_type:
		return
	_portrait_type = plant_type
	if is_instance_valid(_portrait):
		_portrait_holder.remove_child(_portrait)
		_portrait.queue_free()
		_portrait = null
	if plant_type == -1:
		return
	# 原版自动加载已经整理好每种植物的完整卡面，无需只截取头部或额外生成素材。
	var source: Card = AllCards.all_plant_card_prefabs.get(plant_type)
	if not is_instance_valid(source):
		return
	_portrait = source.character_static.duplicate(0) as Node2D
	_portrait.transform = Transform2D.IDENTITY
	_portrait.process_mode = Node.PROCESS_MODE_DISABLED
	_portrait_holder.add_child(_portrait)
	# 根据所有可见精灵的完整包围盒等比缩放，高坚果等高个植物也不会被截断。
	var bounds: Rect2 = _portrait_bounds(_portrait, Transform2D.IDENTITY)
	if bounds.has_area():
		# 给图片四周留白，不让叶片触及边框。
		var factor: float = minf((_portrait_holder.size.x - 4.0) / bounds.size.x, (_portrait_holder.size.y - 4.0) / bounds.size.y)
		_portrait.scale = Vector2.ONE * factor
		_portrait.position = _portrait_holder.size * 0.5 - bounds.get_center() * factor


## 返回[param node]所有可见精灵在[param parent_transform]坐标下的包围盒，隐藏的眨眼帧不参与布局。
func _portrait_bounds(node: Node2D, parent_transform: Transform2D) -> Rect2:
	if not node.visible:
		return Rect2()
	# 累积原版拼图中的局部变换，保留叶片、花瓣与身体的相对位置。
	var transform: Transform2D = parent_transform * node.transform
	# 空包围盒表示当前子树还没有可绘制内容。
	var bounds: Rect2 = Rect2()
	if node is Sprite2D and node.texture != null:
		bounds = transform * node.get_rect()
	# 普通节点仅递归Node2D子节点，原卡面拼图全部由二维绘制节点组成。
	for child: Node in node.get_children():
		if child is Node2D:
			# 当前子树在植物图案坐标中的绘制范围。
			var child_bounds: Rect2 = _portrait_bounds(child, transform)
			if child_bounds.has_area():
				bounds = bounds.merge(child_bounds) if bounds.has_area() else child_bounds
	return bounds


## 在卡面[param rect]区域创建字号为[param font_size]的标签，不接收鼠标输入。
func _make_label(rect: Rect2, font_size: int) -> Label:
	# 标签独立定位，刷新价格或星级不会改变图片区域尺寸。
	var label: Label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


## 创建以[param fill]填充、[param border]描边、边宽为[param width]像素的卡牌样式。
func _make_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	# 每种状态仅创建一次，后续刷新不重复分配背景资源。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	return style
