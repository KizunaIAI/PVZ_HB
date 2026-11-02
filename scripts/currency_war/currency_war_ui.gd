## 阳光战争界面：直接复用原版上方种子卡槽，下方商店叠放在原地图中，不修改地图视口和草坪。
class_name CurrencyWarUI
extends CanvasLayer

## 显式加载规则脚本，首次导入也可解析类型与配置。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 复用原版植物拼图的图片卡牌，隔离显示逻辑与购买、种植规则。
const PlantCard = preload("res://scripts/currency_war/currency_war_plant_card.gd")
## 原版种子包样式的备战卡牌与原生植物拖拽。
const ReserveSlot = preload("res://scripts/currency_war/currency_war_reserve_slot.gd")
## 右侧可收起装备栏，不在界面中修改规则记录。
const EquipmentPanel = preload("res://scripts/currency_war/currency_war_equipment_panel.gd")
## 底部商店面板高度，收起时整体向下移出裁剪区。
const SHOP_HEIGHT: float = 124.0
## 上方十张备战卡的托盘高度，不包含下缘三角按钮。
const RESERVE_HEIGHT: float = 90.0
## 原版普通卡槽场景，直接取出其中的CardSlotBattle及原生占位节点。
const NativeCardSlot: PackedScene = preload("res://scenes/card_slot/card_slot_norm.tscn")
## 装备加成、配方和已有介绍，不添加额外物品设定。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 面板的深绿色底色。
const PANEL_COLOR: Color = Color("182d25")
## 强调文字和悬浮边框的嫩绿色。
const ACCENT: Color = Color("b9ed96")
## 阳光余额和选中状态的金色。
const GOLD_COLOR: Color = Color("f0cf7b")
## 大纲规定白绿蓝紫金分别对应一至五费，未定义的高费植物不填入商店。
const TIER_COLORS: Array[Color] = [Color("e8efdf"), Color("9fdfaf"), Color("96cafa"), Color("d7adf8"), Color("f0cf7b")]
## 左侧阵营展示顺序与不同植物种类门槛；空数组表示大纲尚未定义羁绊效果。
const TRAIT_DISPLAY_TIERS: Dictionary = {"豌豆": [3, 5, 7, 10], "阳光": [2, 3, 4], "灰烬": [], "毒": [], "孢子": [], "召唤": [], "毁灭者": [], "双子": [], "增益": [], "水生": [], "守护": [], "大卫戴": [], "尖刺": [], "防护": [], "轻装上阵": []}
## 羁绊门槛未达成时的暗色，与高亮金色形成明确区分。
const TRAIT_INACTIVE_COLOR: Color = Color("6b7770")
## 羁绊名称始终使用的亮白色，配合深色描边在浅色地图上保持可读。
const TRAIT_NAME_COLOR: Color = Color("f8fbf5")
## 左栏悬浮说明只描述当前已实现效果，灰烬明确标记尚未开放。
const TRAIT_DISPLAY_TIPS: Dictionary = {
	"豌豆": "豌豆：3/5/7/10种分别激活攻击、攻速与头盔效果；只计算场上不同种类。",
	"阳光": "阳光：2/3/4种在节点结算时额外获得1/2/4阳光；只计算场上不同种类。",
	"灰烬": "灰烬：当前尚无已实现的羁绊档位。",
	"毒": "毒：当前仅标记植物阵营，羁绊效果尚未定义。",
	"孢子": "孢子：当前仅标记植物阵营，羁绊效果尚未定义。",
	"召唤": "召唤：当前仅标记植物阵营，羁绊效果尚未定义。",
	"毁灭者": "毁灭者：当前仅标记植物阵营，羁绊效果尚未定义。",
	"双子": "双子：当前仅标记植物阵营，羁绊效果尚未定义。",
	"增益": "增益：当前仅标记植物阵营，羁绊效果尚未定义；路灯花自身的范围强化照常生效。",
	"水生": "水生：当前仅标记植物阵营，羁绊效果尚未定义；水生植物可在所有地图D到，种植仍需符合水面或水盆条件。",
	"大卫戴": "大卫戴：只记录场上不同种类，额外羁绊尚未定义。",
	"尖刺": "尖刺：只记录场上不同种类；地刺和仙人掌自身施加反伤效果。",
	"防护": "防护：高坚果自身提供3×3承伤保护，额外羁绊尚未定义。",
	"轻装上阵": "轻装上阵：三叶草不占用上场种类名额。",
	"守护": "守护：当前仅标记植物阵营，羁绊效果尚未定义；坚果墙自身的生命与回复效果照常生效。",
}

## 请求购买从零开始的[param slot]商品。
signal buy_requested(slot: int)
## 请求选中[param unit_id]对应的手牌。
signal unit_selected(unit_id: int)
## 请求右键切换植物[param unit_id]是否参与自动升星。
signal merge_lock_requested(unit_id: int)
## 请求将植物[param unit_id]移动或交换到固定备战格[param target_slot]。
signal reserve_rearrange_requested(unit_id: int, target_slot: int)
## 请求消耗阳光D牌。
signal refresh_requested
## 请求保留当前商店到下一节点或取消保留。
signal lock_requested
## 请求铲除或出售当前植物。
signal sell_requested
## 请求出售铲子或卡面落点指定的[param unit_id]，无需先选中。
signal sale_requested(unit_id: int)
## 请求从准备阶段开始持续防守。
signal battle_requested
## 请求切换一倍与二倍速度。
signal speed_requested
## 请求应用墓碑菜单选择的[param fast]一倍或二倍速度。
signal speed_selected(fast: bool)
## 请求返回主菜单。
signal menu_requested
## 请求重新开始一局。
signal restart_requested
## 请求选择当前候选[param hex_id]海克斯。
signal hex_requested(hex_id: String)
## 请求取消当前手牌或场上植物选择。
signal cancel_requested
## 设置面板[param opened]切换时通知控制器，仅增减菜单暂停因素。
signal settings_toggled(opened: bool)
## 将[param value]音量提交给[param bus]总线，取值为0到1，控制器负责应用和保存。
signal volume_changed(value: float, bus: int)
## 请求进入本局下一节点，而不是退出到主菜单。
signal next_node_requested
## 请求花费1阳光直购当前场景支持的[param plant_type]睡莲或花盆。
signal support_requested(plant_type: int)
## 请求花费4阳光购买4经验。
signal experience_requested
## 请求把拖出的[param item]装备给落点植物[param unit_id]。
signal equipment_requested(unit_id: int, item: String)
## 请求将准备阶段的遭遇档位改为[param selected]。
signal encounter_selected(selected: int)

## 阳光收集动画的界面目标，控制器交给原版Sun使用。
var sun_target: Marker2D
## 所有独立界面节点的根，鼠标可穿透到草坪和阳光。
var _root: Control
## 阳光、波数与手牌数量的状态标签。
var _status: Label
## 独立金色阳光余额，位于收集动画目标附近。
var _sun_amount: Label
## 当前操作、选中植物或战斗提示。
var _message: Label
## 商店上方的羁绊摘要。
var _traits: Label
## 固定十个备战卡位，保留各自拖放与锁定状态。
var _reserve_slots: Array[ReserveSlot] = []
## 五个固定商店位置。
var _shop_buttons: Array[PlantCard] = []
## 备战席占用数量与拖拽说明。
var _reserve_title: Label
## 与等级按钮同进退的底部商店面板，不影响战场暂停状态。
var _shop_drawer: Panel
## 承载整组居中商店控件，收放动画移动此节点以保持按钮同步。
var _market_drawer: Control
## 始终可触及的三角收起与展开按钮，随抽屉底边移动。
var _shop_toggle: Button
## 当前抽屉移动动画，重复点击时从当前位置反向。
var _drawer_tween: Tween
## 底部商店默认展开，不遮挡600像素的原版战场；可通过三角或空格向下收起。
var _shop_collapsed: bool = false
## 短暂显示的升星通知，不拦截草坪点击。
var _merge_notice: Label
## 当前升星通知的淡出动画，新合成时替换，避免旧通知提前隐藏新通知。
var _notice_tween: Tween
## 显示当前D牌费用的按钮。
var _refresh_button: Button
## 控制下一节点是否跳过一次自动刷新，独立于植物合成锁定。
var _lock_button: Button
## 镜头预览期间禁止商店快捷键，准备阶段再恢复。
var _previewing: bool = false
## 开发者面板打开时停止处理商店快捷键，避免数字输入和空格误触交易；面板关闭后恢复。
var developer_input_blocked: bool = false
## 当前选择的铲除按钮。
var _sell_button: Button
## 准备阶段开始防守的按钮。
var _battle_button: Button
## 战斗速度切换按钮。
var _speed_button: Button
## 旗帜海克斯选择面板。
var _hex_panel: Panel
## 三个海克斯候选按钮，标识随每次选择刷新。
var _hex_buttons: Array[Button] = []
## 海克斯面板的旗帜波次标题。
var _hex_title: Label
## 通关或失守时的结果面板。
var _result: Panel
## 本局结果标题。
var _result_title: Label
## 本局结果详情。
var _result_detail: Label
## 设置遮罩覆盖整个逻辑视口，打开时阻挡草坪与商店操作。
var _settings_overlay: ColorRect
## 原版墓碑菜单的返回按钮，打开菜单时接收焦点。
var _menu_return: BaseButton
## 与局外二倍速按钮保持同步的原版菜单滑轨，只允许一倍、二倍。
var _menu_speed: HSlider
## 原版菜单速度说明，不另外维护一套速度数值。
var _menu_speed_label: Label
## 复用已初始化的原版选项设置，隐藏本模式不适用的自动收集与调试项。
var _native_options: CanvasLayerConsole
## 原版图鉴的独立上层画布，打开时继续保留菜单暂停因素。
var _almanac_layer: CanvasLayer
## 僵尸进度条左侧的大关与小关编号。
var _node_progress: Label
## 节点结果的继续按钮，整局结束时隐藏。
var _next_node_button: Button
## 备战席滚动容器，跨地图退回超过十株时仍能访问全部植物。
var _reserve_scroll: ScrollContainer
## 所有固定备战格的内容容器，宽度按必要的溢出格扩展。
var _reserve_holder: Control
## 上方备战卡托盘，收起时向上移出裁剪区。
var _reserve_drawer: Control
## 原版出战卡槽的完整显示节点，保留种子框、阳光框及HBox布局。
var _native_reserve_bank: PanelContainer
## 从原版卡槽打包的空卡位，扩展固定十格或溢出格时仍使用原节点。
var _native_placeholder: PackedScene
## 上方备战席始终可见的三角按钮。
var _reserve_toggle: Button
## 备战席默认展开，玩家可单独隐藏，不影响商店状态。
var _reserve_collapsed: bool = false
## 上方托盘收放动画，不重复创建或删除持有植物。
var _reserve_tween: Tween
## 点击装备显示的小型介绍面板，不暂停游戏。
var _equipment_detail: Panel
## 当前查看的装备名称。
var _equipment_detail_title: Label
## 已定义加成、特殊效果和合成配方。
var _equipment_detail_text: Label
## 准备阶段显示原版关卡阵容的标签，战斗开始后隐藏。
var _node_preview: Label
## 显示当前等级并点击购买一次经验的左侧按钮。
var _level_button: Button
## 左上角三张直接种植的地形商品，不与普通商店或备战席混用。
var _support_cards: Dictionary = {}
## 可下拉地形栏的裁剪容器。
var _support_clip: Control
## 地形商品抽屉，向上移出裁剪区即可收起。
var _support_drawer: Panel
## 地形栏三角入口。
var _support_toggle: Button
## 左上角地形栏当前是否收起。
var _support_collapsed: bool = true
## 地形栏当前展开动画，重新点击时终止旧动画。
var _support_tween: Tween
## 当前手持地形的纯视觉植物，跟随鼠标但不拦截落点。
var _support_cursor: Control
## 已绘制的手持地形类型，避免每次HUD刷新重复拷贝拼图。
var _support_cursor_type: int = -1
## 右侧常驻装备栏，通过图标拖放到植物佩戴。
var _equipment_panel: EquipmentPanel
## 左侧只显示当前场上已有种类的羁绊面板。
var _trait_panel: Panel
## 羁绊名称到各行节点与门槛标签的映射，刷新时复用节点。
var _trait_rows: Dictionary = {}
## 仅遭遇关准备阶段显示的难度选择。
var _encounter_choice: OptionButton
## 最近渲染的本局规则，只用于拖放校验，不在界面中改变经济记录。
var _current_run: RunRules
## 中央半透明人数显示，统计实际场上种类与等级上限。
var _population: Label
## 原版铲子图像，拖动时淡化，取消或结束后恢复。
var _shovel_art: Control


## 按原版1066×600建立叠加界面，不添加底部画布，不改动草坪和地图位置。
func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = preload("res://assets/fonts/方正少儿_GBK.ttf")
	_root.theme.default_font_size = 15
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_reserve()
	_build_market()
	_build_header()
	_build_supports()
	_build_result()
	_build_trait_panel()
	_equipment_panel = EquipmentPanel.new()
	_root.add_child(_equipment_panel)
	_equipment_panel.item_inspected.connect(show_equipment_details)
	_build_equipment_details()
	_build_settings()
	_merge_notice = _label(_root, Rect2(288, 108, 490, 38), "", 25, GOLD_COLOR)
	_merge_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merge_notice.add_theme_color_override("font_outline_color", Color("14241a"))
	_merge_notice.add_theme_constant_override("outline_size", 7)
	_merge_notice.hide()
	sun_target = _native_reserve_bank.get_node("SunLabelControl/Marker2DSunTarget")


## 接入原版[param progress]旗帜进度条和[param reminder]大波文字，保留波次管理器原有引用。
func attach_game_widgets(progress: Control, reminder: Control) -> void:
	progress.reparent(_root, false)
	progress.position = Vector2(875, 76)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.show()
	_node_progress = _label(_root, Rect2(812, 75, 58, 25), "1-1", 18, GOLD_COLOR)
	_node_progress.add_theme_color_override("font_outline_color", Color("183024"))
	_node_progress.add_theme_constant_override("outline_size", 4)
	reminder.reparent(_root, false)
	reminder.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	reminder.position = Vector2.ZERO
	reminder.size = Vector2(1066, 600)
	reminder.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 根据[param run]刷新经济、商店与手牌，用[param selected_id]高亮当前选择。
func render(run: RunRules, selected_id: int) -> void:
	_current_run = run
	_population.text = "%d/%d" % [run.deployed_species_count(), run.species_limit()]
	_population.visible = run.phase == RunRules.Phase.PREPARATION and not _settings_overlay.visible
	_previewing = run.phase == RunRules.Phase.PREVIEW
	_market_drawer.visible = not _previewing
	_reserve_drawer.visible = not _previewing
	_sun_amount.text = str(run.sun)
	_status.text = "第%d/%d波 · 连胜%d · 吃脑%d/4" % [run.current_wave, run.node_wave_limit, run.campaign.win_streak, run.campaign.brain_losses]
	_node_progress.text = run.campaign.node_label()
	_message.text = run.message
	# 被购买合成或阵亡消耗的标识可能已不存在。
	var selected: Dictionary = run.find_unit(selected_id)
	if not selected.is_empty():
		_message.text = "选中%s %s｜%s" % [RunRules.CATALOG[selected.type].name, "★".repeat(selected.star), "拖到主草坪种植" if selected.cell == RunRules.BENCH_CELL else "场上星级固定；可铲除返还阳光"]
		if run.phase == RunRules.Phase.PREPARATION:
			_message.text += "｜已锁定，右键解除" if bool(selected.get("merge_locked", false)) else "｜右键植物锁定升星"
		else:
			_message.text += "｜已锁定，准备阶段可解除" if bool(selected.get("merge_locked", false)) else "｜准备阶段可右键锁定"
		if run.is_support(int(selected.type)):
			_message.text = "选中%s｜地形植物，不参与升星；准备阶段可拖动调整。" % RunRules.CATALOG[selected.type].name
	_sell_button.disabled = not run.can_manage()
	_sell_button.tooltip_text = "拖动铲子到植物，或把备战卡拖到铲子处出售。" + ("当前选中植物售价：%d阳光。" % run.sell_value(selected) if not selected.is_empty() else "")
	_refresh_button.text = "D牌\n%d" % run.refresh_price()
	_refresh_button.disabled = not run.can_manage() or run.sun < run.refresh_price()
	_lock_button.disabled = not run.can_manage()
	_lock_button.set_pressed_no_signal(run.shop_locked)
	_lock_button.text = "已锁定" if run.shop_locked else "锁定"
	_level_button.disabled = not run.can_manage() or run.sun < 4 or run.level >= 9
	_level_button.text = "等级%d\n满级" % run.level if run.level >= 9 else "等级%d\n%d/%d" % [run.level, run.experience, RunRules.EXPERIENCE_THRESHOLDS[run.level - 1]]
	_battle_button.visible = run.phase == RunRules.Phase.PREPARATION
	_battle_button.disabled = run.count_units() == 0 or run.lawn_expanding
	_battle_button.text = "铺草中" if run.lawn_expanding else "开始"
	_speed_button.visible = run.phase == RunRules.Phase.BATTLE
	_menu_speed.editable = run.phase == RunRules.Phase.BATTLE
	_support_clip.visible = not _previewing
	_support_toggle.visible = not _previewing
	# 地形商品全部常驻，点击或拖动后仅在成功种下时付费。
	for type: int in _support_cards:
		# 水盆借用花盆卡面，名称明确区分，不伪造额外素材。
		var card: PlantCard = _support_cards[type]
		card.show_plant(type, RunRules.CATALOG[type].name, "☀ 1", "直接种植", false, run.can_manage() and run.sun >= 1, TIER_COLORS[0])
		card.tooltip_text = RunRules.CATALOG[type].tip
	# 阵容通过原版镜头展示，不再把整段名单覆盖在草坪上。
	_node_preview.hide()
	_ensure_reserve_slots(run.reserve_display_count())
	# 固定十格逐格查询，买牌、种植和合成不会使其他备战植物自动挪位。
	for index: int in range(_reserve_slots.size()):
		# 显示名称只放入独立的界面快照，不修改规则层的单位记录。
		var unit: Dictionary = run.reserve_at(index).duplicate()
		if not unit.is_empty():
			unit["display_name"] = RunRules.CATALOG[unit.type].name
			unit["helmet"] = run.helmet_unit_id == int(unit.id)
		_reserve_slots[index].show_unit(unit, selected_id, run.can_manage(), run.can_equip_item, run.phase == RunRules.Phase.PREPARATION)
	_reserve_title.text = "备战席 %d株 · 拖卡种植 · 准备时右键锁定%s" % [run.count_units(false), " · 横向滚动查看其余卡牌" if run.reserve_display_count() > RunRules.BENCH_LIMIT else ""]
	_reserve_drawer.tooltip_text = _reserve_title.text
	_message.tooltip_text = _message.text
	# 商店价格与阳光余额一致，没有独立金币或传统无限种子包。
	for index: int in range(_shop_buttons.size()):
		_update_shop_button(_shop_buttons[index], run.shop[index], run)
	_traits.text = "%s %s · %d级 经验%s · 上场%d/%d种 · 难度%d" % [run.campaign.node_label(), run.campaign.node_kind(), run.level, "%d/%d" % [run.experience, RunRules.EXPERIENCE_THRESHOLDS[run.level - 1]] if run.level < 9 else "满级", run.deployed_species_count(), run.species_limit(), run.node_difficulty()]
	_traits.tooltip_text = "豌豆%d种 · 阳光%d种\n本节点利息基数：进入准备时的%d阳光" % [run.trait_counts().get("豌豆", 0), run.trait_counts().get("阳光", 0), run.node_opening_sun]
	_render_trait_panel(run)
	_equipment_panel.render_run(run, selected_id)
	_encounter_choice.visible = run.phase == RunRules.Phase.PREPARATION and run.campaign.node_kind() == "遭遇关"
	_encounter_choice.select(run.encounter_level - 1)
	_result.visible = run.phase == RunRules.Phase.NODE_RESULT or run.phase == RunRules.Phase.FINISHED
	_result_title.text = "本局结束" if run.phase == RunRules.Phase.FINISHED else "%s 节点结束" % run.campaign.node_label()
	_result_detail.text = run.settlement_text
	if run.phase == RunRules.Phase.FINISHED:
		_result_detail.text += "\n植物与装备已存入主菜单仓库。" if run.collection_saved else "\n" + run.message
	_next_node_button.visible = run.phase == RunRules.Phase.NODE_RESULT


## 使用[param text]临时展示战斗信息，不改变规则层最近操作记录。
func set_detail(text: String) -> void:
	_message.text = text


## 使用[param fast]同步速度按钮，实际时间缩放由控制器负责。
func set_speed(fast: bool) -> void:
	_speed_button.text = "×2" if fast else "×1"
	_menu_speed.set_value_no_signal(2.0 if fast else 1.0)
	_menu_speed_label.text = "倍速 %s 倍" % ("2.0" if fast else "1.0")


## 用[param result]的植物类型和新星级显示短暂升星通知，避免被当前选择或阳光刷新覆盖。
func show_merge_result(result: Dictionary) -> void:
	if is_instance_valid(_notice_tween):
		_notice_tween.kill()
	_merge_notice.text = "%s  →  %s  %d星！" % [RunRules.CATALOG[result.type].name, "★".repeat(result.star), result.star]
	_merge_notice.modulate.a = 1.0
	_merge_notice.show()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.2)
	_notice_tween.tween_property(_merge_notice, "modulate:a", 0.0, 0.35)
	_notice_tween.tween_callback(_merge_notice.hide)


## 优先处理[param event]中的D键和空格，避免焦点按钮先消费空格；设置打开时停用局内快捷键，允许Esc关闭。
func _input(event: InputEvent) -> void:
	if developer_input_blocked:
		return
	if _equipment_detail.visible and event is InputEventMouseButton and event.pressed and not _equipment_detail.get_global_rect().has_point(get_viewport().get_mouse_position()):
		_equipment_detail.hide()
	if _previewing:
		return
	if not event is InputEventKey:
		return
	if _settings_overlay.visible:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo:
				if _native_options.visible:
					_native_options._on_texture_button_pressed()
				elif _almanac_layer.get_child_count() == 0:
					_set_settings_visible(false)
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_D or event.keycode == KEY_SPACE:
		# 同时消费按下、抬起与重复事件，长按不会重复扣阳光，也不会误触焦点按钮。
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			if event.keycode == KEY_D:
				# 大纲1.4限定只有商店打开时D键才刷新；收起时不扣阳光、不改变商品。
				if not _shop_collapsed:
					refresh_requested.emit()
			else:
				_toggle_shop()


## 接收[param event]中的右键取消；设置打开时保留现有选择，不让输入穿透遮罩。
func _unhandled_input(event: InputEvent) -> void:
	if developer_input_blocked:
		return
	if _settings_overlay.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_requested.emit()
		get_viewport().set_input_as_handled()


## 阳光直接使用原版卡槽中的数字，只在右侧保留模式操作和进度，不再另建标题条或阳光框。
func _build_header() -> void:
	_population = _label(_root, Rect2(431, 110, 230, 136), "0/3", 70, Color(1.0, 1.0, 1.0, 0.36))
	_population.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_population.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 透明容器不绘制背景、不阻挡鼠标，只有实际按钮接收输入。
	var header: Control = Control.new()
	header.position = Vector2.ZERO
	header.size = Vector2(1066, 100)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)
	_status = _label(header, Rect2(818, 42, 238, 22), "", 12, Color("d0ddc5"))
	_message = _label(header, Rect2(8, 573, 172, 22), "", 12, Color("e0e5d7"))
	# 描边代替整条底色，文字在浅色栅栏与绿色草地上都能分辨。
	for label: Label in [_status, _message]:
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.04, 0.95))
		label.add_theme_constant_override("outline_size", 4)
	_speed_button = _button(header, Rect2(880, 7, 72, 28), "×1", speed_requested.emit)
	# 直接复用原版菜单按钮的石板、字体与边框，入口合并后不再直接退出本局。
	var menu: BaseButton = Global.main_game.get_node("CanvasLayerUI/All_UI/MainGameMenuButton").duplicate(0)
	menu.theme = preload("res://data/PVZ_theme.tres")
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.position = Vector2(962, 0)
	menu.size = Vector2(104, 38)
	menu.pressed.connect(_set_settings_visible.bind(true))
	header.add_child(menu)


## 在左上角创建独立地形抽屉，三种商品均不进入备战席。
func _build_supports() -> void:
	_support_clip = Control.new()
	_support_clip.position = Vector2(4, 28)
	_support_clip.size = Vector2(142, 103)
	_support_clip.clip_contents = true
	_support_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_support_clip)
	_support_drawer = _panel(_support_clip, Rect2(0, -103, 142, 103))
	# 三张种子包等宽排列，空备战格不影响购买地形。
	for index: int in range(3):
		# 花盆、水盆、睡莲按文档顺序展示。
		var type: int = [34, 50, 17][index]
		# 卡面只用于直接种植选择，消费由落点统一处理。
		var card: PlantCard = _plant_card(_support_drawer, Rect2(3 + index * 46, 3, 44, 96), true, _on_support_pressed.bind(type))
		card.set_drag_forwarding(_drag_support.bind(type, card), Callable(), Callable())
		_support_cards[type] = card
	_support_toggle = _button(_root, Rect2(8, 3, 132, 23), "地形 ▼", _toggle_supports)
	_support_toggle.tooltip_text = "展开花盆、水盆、睡莲；1阳光直接种植"


## 切换地形抽屉，动画不移动地图、备战席或普通商店。
func _toggle_supports() -> void:
	_support_collapsed = not _support_collapsed
	_support_toggle.text = "地形 ▼" if _support_collapsed else "地形 ▲"
	if is_instance_valid(_support_tween):
		_support_tween.kill()
	_support_tween = create_tween()
	_support_tween.tween_property(_support_drawer, "position:y", -103.0 if _support_collapsed else 0.0, 0.2)


## 从[param card]拖出[param type]直购地形；[param _position]不影响落点，成功种植前不扣阳光。
func _drag_support(_position: Vector2, type: int, card: PlantCard) -> Variant:
	if _current_run == null or not _current_run.can_manage() or _current_run.sun < 1:
		return null
	# 拷贝原生静态种子包，不复制商品脚本或运行第二套界面初始化。
	var source: Card = preload("res://scripts/currency_war/da_fei_yu_reward.gd").card(type)
	# 预览使用原生种子包，不生成任何持有或战斗记录。
	var preview: Control = Control.new()
	# 可见副本居中跟随鼠标，右键取消时由引擎释放。
	var face: Control = source.card_bg.duplicate(0) as Control
	face.position = Vector2(-25, -35)
	face.process_mode = Node.PROCESS_MODE_DISABLED
	(face.get_node("Cost") as Label).text = "1"
	preview.add_child(face)
	card.set_drag_preview(preview)
	return {"kind": "currency_war_support", "type": type}


## 展示手持[param type]的原版植物形象；-1清空，不创建备战或战斗单位。
func show_support_cursor(type: int) -> void:
	if type == _support_cursor_type:
		return
	_support_cursor_type = type
	if is_instance_valid(_support_cursor):
		_support_cursor.queue_free()
		_support_cursor = null
	if type == -1:
		return
	_support_cursor = Control.new()
	_support_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_support_cursor.z_index = 100
	_root.add_child(_support_cursor)
	# 水盆卡面复用花盆形象，实际落地使用带水面的独立水盆场景。
	var source: Card = preload("res://scripts/currency_war/da_fei_yu_reward.gd").card(type)
	# 纯绘制植物不带攻击或生产组件，半透明表示尚未付款种植。
	var portrait: Node2D = source.character_static.duplicate(0) as Node2D
	portrait.transform = Transform2D.IDENTITY
	portrait.process_mode = Node.PROCESS_MODE_DISABLED
	portrait.modulate.a = 0.75
	_support_cursor.add_child(portrait)
	# 鼠标位于完整植物的中部，避免沿用种子卡槽的局部偏移。
	var bounds: Rect2 = _support_cards[type]._portrait_bounds(portrait, Transform2D.IDENTITY)
	portrait.position = -bounds.get_center()
	_support_cursor.position = _root.get_local_mouse_position()


## 按[param _delta]帧时长更新手持地形的显示位置；设置或预览时隐藏图像，暂停不会阻断取消操作。
func _process(_delta: float) -> void:
	if is_instance_valid(_support_cursor):
		_support_cursor.position = _root.get_local_mouse_position()
		_support_cursor.visible = not _previewing and not _settings_overlay.visible


## 在画面底部居中排列等级、商品、D牌与开始按钮；整组随商店抽屉收放。
func _build_market() -> void:
	# 裁剪区跨越整组按钮，收起时只保留商店三角入口。
	var clip_host: Control = Control.new()
	clip_host.position = Vector2(76, 452)
	clip_host.size = Vector2(914, SHOP_HEIGHT + 24)
	clip_host.clip_contents = true
	clip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(clip_host)
	_market_drawer = Control.new()
	_market_drawer.position.y = SHOP_HEIGHT if _shop_collapsed else 0.0
	_market_drawer.size = clip_host.size
	_market_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_host.add_child(_market_drawer)
	_shop_drawer = _panel(_market_drawer, Rect2(100, 24, 566, SHOP_HEIGHT))
	_label(_shop_drawer, Rect2(10, 2, 125, 20), "商店 · 阳光买牌", 13, ACCENT)
	_traits = _label(_shop_drawer, Rect2(142, 2, 416, 20), "", 12, Color("d0ddc5"))
	_traits.mouse_filter = Control.MOUSE_FILTER_PASS
	# 五张随机商品保持固定位置，所有地图共用候选植物池；地形卡位于左上角独立抽屉。
	for slot: int in range(RunRules.SHOP_SIZE):
		# 商品按钮只绑定稳定栏位序号，刷新时替换内容。
		var button: PlantCard = _plant_card(_shop_drawer, Rect2(8 + slot * 101, 24, 96, 96), true, buy_requested.emit.bind(slot))
		_shop_buttons.append(button)
	_refresh_button = _button(_shop_drawer, Rect2(518, 24, 44, 44), "D牌", refresh_requested.emit)
	_refresh_button.add_theme_font_size_override("font_size", 12)
	_lock_button = _button(_shop_drawer, Rect2(518, 76, 44, 44), "锁定", lock_requested.emit)
	_lock_button.add_theme_font_size_override("font_size", 13)
	_lock_button.toggle_mode = true
	_lock_button.tooltip_text = "开启后，下一节点保留商品及售空位置一次，随后自动解除；跨地图保留商品，仅停用或改为直购的商品按原稀有度替换。关闭时新节点免费刷新。"
	_level_button = _button(_market_drawer, Rect2(0, 51, 76, 76), "等级1\n0/4", experience_requested.emit)
	_level_button.add_theme_font_size_override("font_size", 17)
	_level_button.tooltip_text = "点击花费4阳光购买4经验，增加上场植物种类上限；地形植物与三叶草不计入。"
	_battle_button = _button(_root, Rect2(917, 545, 149, 55), "开始", battle_requested.emit)
	_battle_button.add_theme_font_size_override("font_size", 22)
	_shop_toggle = _button(_shop_drawer, Rect2(517, -24, 37, 22), "▲" if _shop_collapsed else "▼", _toggle_shop)
	_shop_toggle.add_theme_font_size_override("font_size", 13)
	_shop_toggle.tooltip_text = "展开D牌商店（空格）" if _shop_collapsed else "收起D牌商店（空格）"
	_layout_market()
	_node_preview = _label(_root, Rect2(205, 242, 720, 70), "", 15, Color("f1ebcd"))
	_node_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_node_preview.add_theme_color_override("font_outline_color", Color("183024"))
	_node_preview.add_theme_constant_override("outline_size", 4)
	_encounter_choice = OptionButton.new()
	_encounter_choice.position = Vector2(185, 420)
	_encounter_choice.size = Vector2(686, 29)
	# 每个档位只使用用户更新3.1中的难度增量与奖励。
	for index: int in range(4):
		_encounter_choice.add_item(["遭遇难度1：难度+3 · 额外2阳光、2经验", "遭遇难度2：难度+6 · 随机1个基础装备", "遭遇难度3：难度+9 · 随机2个基础装备", "遭遇难度4：难度+20 · 随机2个成装"][index])
	_encounter_choice.item_selected.connect(_on_encounter_option)
	_root.add_child(_encounter_choice)


## 保持底部五张商品的固定宽度；地形商品另设左上角抽屉。
func _layout_market() -> void:
	# 五张商品用窄面板，新增地形卡时再向两侧扩展整组宽度。
	var panel_width: float = 566.0
	# 保留原商店组的水平位置；开始按钮固定在画面右下角。
	var group_width: float = panel_width + 200.0
	# 裁剪区自身以1066像素视口中心定位，组内按当前宽度左右留白。
	var group_left: float = (914.0 - group_width) * 0.5
	_level_button.position.x = group_left + 16.0
	_shop_drawer.position.x = group_left + 100.0
	_shop_drawer.size.x = panel_width
	_refresh_button.position.x = panel_width - 48.0
	_lock_button.position.x = panel_width - 48.0
	_shop_toggle.position.x = panel_width - 49.0
	_traits.size.x = panel_width - 150.0


## 在左侧庭院边缘创建透明背景的羁绊列表，显示已上场种类与每档门槛的独立颜色。
func _build_trait_panel() -> void:
	_trait_panel = _panel(_root, Rect2(8, 132, 112, 338))
	# 覆盖通用面板样式，保留羁绊内容和悬浮说明但不遮住庭院背景。
	_trait_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_trait_panel.hide()
	# 固定顺序创建当前牌库会出现的阵营行，未定义羁绊只显示未开放，实时刷新只切换内容和颜色。
	for trait_name: String in TRAIT_DISPLAY_TIERS:
		# 单行承载图标、名称和门槛，不显示当前种类数量。
		var row: Control = Control.new()
		row.size = Vector2(104, 55)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = TRAIT_DISPLAY_TIPS[trait_name]
		_trait_panel.add_child(row)
		# 简洁符号对应豌豆、阳光和灰烬，色彩表示是否已激活有效档位。
		var icon: Label = _label(row, Rect2(2, 6, 25, 27), "☀" if trait_name == "阳光" else ("✦" if trait_name == "灰烬" else "◆"), 20, TRAIT_INACTIVE_COLOR)
		# 名称始终亮白并加深色描边，场上不同种类只决定图标和门槛颜色。
		var name_label: Label = _label(row, Rect2(30, 4, 72, 22), trait_name, 14, TRAIT_NAME_COLOR)
		name_label.add_theme_color_override("font_outline_color", Color("242a27"))
		name_label.add_theme_constant_override("outline_size", 3)
		# 灰底只衬托实际门槛数字，透明面板其余区域仍显示原地图。
		var tiers: Array = TRAIT_DISPLAY_TIERS[trait_name]
		if not tiers.is_empty():
			# 背板仅覆盖当前羁绊的门槛数字和斜杠。
			var tier_background: Panel = _panel(row, Rect2(27, 27, 8 + tiers.size() * 18, 23))
			# 独立样式使背板呈半透明灰色，不影响左栏整体透明度。
			var tier_style: StyleBoxFlat = StyleBoxFlat.new()
			tier_style.bg_color = Color(0.23, 0.24, 0.24, 0.62)
			tier_style.set_corner_radius_all(4)
			tier_background.add_theme_stylebox_override("panel", tier_style)
			tier_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 数字与斜杠分开着色，羁绊激活后只有未达门槛的数字保持暗色。
		var tier_labels: Array[Label] = []
		var separators: Array[Label] = []
		for tier_index: int in range(tiers.size()):
			# 斜杠是连接符，达到首档后与名称一同高亮。
			if tier_index > 0:
				var separator: Label = _label(row, Rect2(24 + tier_index * 18, 29, 6, 19), "/", 11, TRAIT_INACTIVE_COLOR)
				separators.append(separator)
			# 后续档位未达到时仅压暗其数字。
			var tier_label: Label = _label(row, Rect2(30 + tier_index * 18, 29, 18, 19), str(tiers[tier_index]), 11, TRAIT_INACTIVE_COLOR)
			tier_labels.append(tier_label)
		if tiers.is_empty():
			_label(row, Rect2(30, 29, 72, 19), "未开放", 11, TRAIT_INACTIVE_COLOR)
		_trait_rows[trait_name] = {"row": row, "icon": icon, "tiers": tier_labels, "separators": separators}


## 按[param run]的场上不同植物种类刷新左栏；达到的羁绊门槛高亮，未达到保持暗色。
func _render_trait_panel(run: RunRules) -> void:
	# 每次读取真实部署结果，植物死亡、出售、合成或换位后立即同步。
	var counts: Dictionary = run.trait_counts()
	# 仅为当前场上已有的羁绊占用行位置，空场隐藏整个面板。
	var visible_count: int = 0
	for trait_name: String in TRAIT_DISPLAY_TIERS:
		# 灰烬目前没有生效门槛，出现时仍保持暗色。
		var count: int = int(counts.get(trait_name, 0))
		var row_data: Dictionary = _trait_rows[trait_name]
		var row: Control = row_data["row"]
		row.visible = count > 0
		if count <= 0:
			continue
		row.position = Vector2(4, 8 + visible_count * 62)
		visible_count += 1
		# 图标与斜杠在首档激活后高亮，名称始终亮白。
		var tiers: Array = TRAIT_DISPLAY_TIERS[trait_name]
		var active: bool = not tiers.is_empty() and count >= int(tiers[0])
		var main_color: Color = GOLD_COLOR if active else TRAIT_INACTIVE_COLOR
		var icon: Label = row_data["icon"]
		icon.add_theme_color_override("font_color", main_color)
		# 斜杠不是档位数字，激活羁绊时与名称使用相同的高亮色。
		var separators: Array = row_data["separators"]
		for separator: Label in separators:
			separator.add_theme_color_override("font_color", main_color)
		# 每一档独立比较，较高档未达成时不会跟随低档一起高亮。
		var tier_labels: Array = row_data["tiers"]
		for tier_index: int in range(tier_labels.size()):
			var tier_label: Label = tier_labels[tier_index]
			tier_label.add_theme_color_override("font_color", GOLD_COLOR if count >= int(tiers[tier_index]) else TRAIT_INACTIVE_COLOR)
	_trait_panel.visible = visible_count > 0


## 将从零开始的[param index]转换为文档一至四档遭遇难度。
func _on_encounter_option(index: int) -> void:
	encounter_selected.emit(index + 1)


## 直接复用原版CardSlotBattle、阳光框、CardUiList与铲子，不再绘制自定义备战托盘或扩展地图。
func _build_reserve() -> void:
	# 从原版场景取出实际卡槽节点，入树前解除原版无限种子与独立阳光账户的脚本。
	var native_template: Control = NativeCardSlot.instantiate()
	_native_reserve_bank = native_template.get_node("CardSlotBattle")
	native_template.remove_child(_native_reserve_bank)
	_native_reserve_bank.set_script(null)
	native_template.free()
	# 与原版CardSlotRoot一样放在(150,0)，使用原版590×90卡槽和50×70种子包尺寸。
	_reserve_drawer = Control.new()
	_reserve_drawer.position = Vector2(150, 0)
	_reserve_drawer.size = Vector2(660, 90)
	_reserve_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_reserve_drawer)
	_native_reserve_bank.position = Vector2.ZERO
	_native_reserve_bank.size = Vector2(590, 90)
	_reserve_drawer.add_child(_native_reserve_bank)
	_sun_amount = _native_reserve_bank.get_node("SunLabelControl/CurrSunValue")
	_reserve_title = _label(_reserve_drawer, Rect2(0, 0, 0, 0), "", 12, ACCENT)
	_reserve_title.hide()
	# 原版HBox及其空卡位保持原样，只加透明滚动层供跨地图溢出卡访问。
	_reserve_holder = _native_reserve_bank.get_node("CardUiList")
	_native_reserve_bank.remove_child(_reserve_holder)
	# 打包原生空卡位，后续十格和溢出格都从同一个节点克隆。
	var placeholder: Node = _reserve_holder.get_node("CardPlaceholder_ori")
	_native_placeholder = PackedScene.new()
	_native_placeholder.pack(placeholder)
	_reserve_holder.remove_child(placeholder)
	placeholder.free()
	_reserve_scroll = ScrollContainer.new()
	_reserve_scroll.custom_minimum_size = Vector2(500, 70)
	_reserve_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_reserve_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_native_reserve_bank.add_child(_reserve_scroll)
	_reserve_scroll.add_child(_reserve_holder)
	_ensure_reserve_slots(RunRules.BENCH_LIMIT)
	# 原地图中的原版铲子外观也直接复用，按钮仍走本模式出售规则。
	var shovel: Control = Global.main_game.get_node("CanvasLayerCardSlot/CardSlotRoot/CardSlotContainer/ShovelContainer/UIShovel").duplicate(0)
	shovel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	shovel.position = Vector2(590, 0)
	shovel.size = Vector2(70, 72)
	shovel.show()
	_reserve_drawer.add_child(shovel)
	shovel.get_node("Label").hide()
	_shovel_art = shovel.get_node("Shovel")
	_sell_button = shovel.get_node("Button")
	_sell_button.pressed.connect(sell_requested.emit)
	_sell_button.set_drag_forwarding(_drag_shovel, _can_drop_to_shovel, _drop_to_shovel)
	_reserve_toggle = _button(_reserve_drawer, Rect2(663, 3, 25, 22), "▲", _toggle_reserve)
	_reserve_toggle.tooltip_text = "收起备战卡牌"
	# 向左翻页入口只访问已有溢出植物，普通十格时不显示。
	var previous: Button = _button(_reserve_drawer, Rect2(510, 72, 26, 16), "‹", _scroll_reserve.bind(-1))
	previous.set_meta("overflow_navigation", true)
	# 向右翻页与左翻页使用同一条原生卡槽，不拉长卡槽背景。
	var next: Button = _button(_reserve_drawer, Rect2(540, 72, 26, 16), "›", _scroll_reserve.bind(1))
	next.set_meta("overflow_navigation", true)


## 保留十个可见卡位，按[param count]扩展跨场景溢出卡；不丢弃植物或改变格号。
func _ensure_reserve_slots(count: int) -> void:
	_reserve_holder.custom_minimum_size.x = maxi(count, RunRules.BENCH_LIMIT) * 50.0
	# 翻页入口只为已有的溢出植物显示，不提高正常购买容量。
	for child: Node in _reserve_drawer.get_children():
		if child.has_meta("overflow_navigation"):
			child.visible = count > RunRules.BENCH_LIMIT and not _reserve_collapsed
	# 只在格位不足时创建新节点，阳光和状态刷新不重建植物外观。
	for index: int in range(_reserve_slots.size(), count):
		# 每张备战卡支持原生拖拽、右键锁定与装备拖入。
		var slot: ReserveSlot = ReserveSlot.new()
		slot.slot_index = index
		slot.size = Vector2(50, 70)
		slot.unit_selected.connect(unit_selected.emit)
		slot.merge_lock_requested.connect(merge_lock_requested.emit)
		slot.equipment_dropped.connect(equipment_requested.emit)
		slot.equipment_inspected.connect(show_equipment_details)
		slot.sale_requested.connect(sale_requested.emit)
		slot.rearrange_requested.connect(reserve_rearrange_requested.emit)
		# 原版占位图片负责布局，交互层直接覆盖在原卡位中。
		var placeholder: Control = _native_placeholder.instantiate()
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reserve_holder.add_child(placeholder)
		placeholder.add_child(slot)
		_reserve_slots.append(slot)


## 按[param direction]左右浏览已持有的溢出卡，不改变植物排列与备战容量。
func _scroll_reserve(direction: int) -> void:
	_reserve_scroll.scroll_horizontal += direction * 50


## 从原版铲子按钮的[param at_position]拖出售卖工具，预览不改变植物或装备记录。
func _drag_shovel(at_position: Vector2) -> Variant:
	if _current_run == null or not _current_run.can_manage():
		return null
	# 根节点跟随鼠标，内部铲子保留抓取偏移。
	var preview: Control = Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 使用原版铲子图片，不额外生成工具美术。
	var art: TextureRect = TextureRect.new()
	art.texture = preload("res://assets/image/ui/ui_card/Shovel.png")
	art.position = -at_position
	art.size = Vector2(70, 72)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(art)
	_sell_button.set_drag_preview(preview)
	_shovel_art.modulate.a = 0.25
	return {"kind": ReserveSlot.SHOVEL_DRAG_KIND}


## 判断[param data]是否为当前仍持有的植物卡；[param _at_position]不改变售卖目标。
func _can_drop_to_shovel(_at_position: Vector2, data: Variant) -> bool:
	return _current_run != null and _current_run.can_manage() and data is Dictionary and data.get("kind", "") == ReserveSlot.DRAG_KIND and not _current_run.find_unit(int(data.get("unit_id", -1))).is_empty()


## 将落到铲子上的[param data]交给控制器售卖；[param at_position]复用最终校验，取消不产生退款。
func _drop_to_shovel(at_position: Vector2, data: Variant) -> void:
	if _can_drop_to_shovel(at_position, data):
		sale_requested.emit(int(data.unit_id))


## 拖动结束通知[param what]恢复铲子外观，取消或无效落点也不会隐藏原版铲子。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_instance_valid(_shovel_art):
		_shovel_art.modulate.a = 1.0


## 将底部D牌页面向下收起或拉回；只改变界面位置，不暂停游戏或刷新商品。
func _toggle_shop() -> void:
	_shop_collapsed = not _shop_collapsed
	if is_instance_valid(_drawer_tween):
		_drawer_tween.kill()
	_shop_toggle.text = "▲" if _shop_collapsed else "▼"
	_shop_toggle.tooltip_text = "展开D牌商店（空格）" if _shop_collapsed else "收起D牌商店（空格）"
	_drawer_tween = create_tween()
	_drawer_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_drawer_tween.tween_property(_market_drawer, "position:y", SHOP_HEIGHT if _shop_collapsed else 0.0, 0.25)


## 上方备战卡托盘独立向上收起，再次点击三角恢复，不移动或删除任何植物。
func _toggle_reserve() -> void:
	_reserve_collapsed = not _reserve_collapsed
	if is_instance_valid(_reserve_tween):
		_reserve_tween.kill()
	_reserve_toggle.text = "▼" if _reserve_collapsed else "▲"
	_reserve_toggle.tooltip_text = "展开备战卡牌" if _reserve_collapsed else "收起备战卡牌"
	_reserve_tween = create_tween()
	_reserve_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_reserve_tween.tween_property(_reserve_drawer, "position:y", -RESERVE_HEIGHT if _reserve_collapsed else 0.0, 0.25)
	_reserve_tween.parallel().tween_property(_reserve_toggle, "position:y", RESERVE_HEIGHT if _reserve_collapsed else 3.0, 0.25)


## 建立点击装备后显示的介绍浮层，关闭或点击外部只收起浮层，不暂停战斗。
func _build_equipment_details() -> void:
	_equipment_detail = _panel(_root, Rect2(110, 150, 350, 220))
	_equipment_detail_title = _label(_equipment_detail, Rect2(16, 12, 286, 30), "", 20, GOLD_COLOR)
	_equipment_detail_text = _label(_equipment_detail, Rect2(16, 52, 318, 152), "", 15, Color("e9efdd"))
	_equipment_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_equipment_detail, Rect2(308, 10, 30, 28), "×", _equipment_detail.hide)
	_equipment_detail.hide()


## 显示已定义[param item]的加成、效果和配方，未知物品忽略，落点限定在可见视口内。
func show_equipment_details(item: String) -> void:
	if not Equipment.ITEMS.has(item):
		return
	_equipment_detail_title.text = Equipment.ITEMS[item].name
	_equipment_detail_text.text = Equipment.ITEMS[item].tip
	# 成装配方直接读取现有配置，不另写一套可能失效的装备数据。
	for pair: String in Equipment.RECIPES:
		if Equipment.RECIPES[pair] == item:
			# 配方只有两个已定义基础小件。
			var parts: PackedStringArray = pair.split("+")
			_equipment_detail_text.text += "\n\n合成：%s + %s" % [Equipment.ITEMS[parts[0]].name, Equipment.ITEMS[parts[1]].name]
	# 贴近点击位置展开，并避开视口边缘裁切。
	var origin: Vector2 = get_viewport().get_mouse_position() + Vector2(18, 18)
	_equipment_detail.position = Vector2(clampf(origin.x, 8, 708), clampf(origin.y, 80, 372))
	_equipment_detail.show()


## 保留旧旗帜选择面板的兼容构建函数，当前节点规则不调用。
func _build_hex_panel() -> void:
	_hex_panel = _panel(_root, Rect2(126, 166, 814, 294))
	_hex_title = _label(_hex_panel, Rect2(22, 14, 770, 38), "", 24, GOLD_COLOR)
	_hex_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(_hex_panel, Rect2(22, 55, 770, 28), "僵尸、植物与阳光已暂停，选择后继续当前战场。", 16, ACCENT)
	# 每个候选按钮显示完整效果，不依赖额外弹窗。
	for slot: int in range(3):
		# 使用稳定位置，在render时写入本次候选的标识。
		var button: Button = _button(_hex_panel, Rect2(22 + slot * 261, 96, 248, 176), "", _on_hex_pressed.bind(slot))
		button.add_theme_font_size_override("font_size", 17)
		_hex_buttons.append(button)
	_hex_panel.hide()


## 创建最终胜负面板，支持重开和返回菜单。
func _build_result() -> void:
	_result = _panel(_root, Rect2(210, 158, 646, 300))
	_result_title = _label(_result, Rect2(22, 18, 602, 42), "", 27, ACCENT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail = _label(_result, Rect2(28, 82, 590, 130), "", 17, Color("e0e5d7"))
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(_result, Rect2(22, 238, 190, 38), "重新开始整局", restart_requested.emit)
	_button(_result, Rect2(434, 238, 190, 38), "返回菜单", menu_requested.emit)
	_result.hide()
	_next_node_button = _button(_result, Rect2(220, 238, 206, 38), "继续本局 · 下一节点", next_node_requested.emit)


## 将[param types]阵容写入准备阶段预览；[param boss_stage]为1至3时额外显示对应Boss光环与技能配置，0为普通节点。
func set_node_preview(types: Array[CharacterRegistry.ZombieType], boss_stage: int = 0) -> void:
	# 名称仅用于显示，数组下标对应原版稳定僵尸枚举，不改变任何出怪权重。
	var names: Array[String] = ["", "普通", "旗帜", "路障", "撑杆", "铁桶", "读报", "铁门", "橄榄球", "舞王", "伴舞", "鸭子圈", "潜水", "冰车", "雪橇", "海豚", "小丑", "气球", "矿工", "跳跳", "雪人", "蹦极", "扶梯", "投篮", "巨人", "小鬼"]
	# 只展示此节点规则实际开放的僵尸类型。
	var roster: PackedStringArray = []
	# 未知扩展僵尸显示原版资源名，避免给未定义类型编造中文名称。
	for type: int in types:
		roster.append("大肥鱼（Boss）" if type == CharacterRegistry.ZombieType.Z1002DaFeiYu else (names[type] if type < names.size() else str(CharacterRegistry.ZombieInfo[type][CharacterRegistry.ZombieInfoAttribute.ZombieName])))
	_node_preview.text = "本节点僵尸阵容：\n" + " · ".join(roster)
	if boss_stage > 0:
		# 准备阶段展示实际集中配置，便于玩家识别各Boss关的在场强化。
		var settings: Dictionary = preload("res://scripts/currency_war/da_fei_yu_boss_stage.gd").profile(boss_stage)
		_node_preview.text += "\n大肥鱼在场：敌军免伤%d%%，伤害+%d%%\n偷取%d–%d阳光，召唤%d–%d只，技能间隔%.1f秒" % [roundi(settings.reduction * 100.0), roundi((settings.damage - 1.0) * 100.0), settings.sun.x, settings.sun.y, settings.summons.x, settings.summons.y, settings.delay]


## 请求手持[param plant_type]固定地形卡，不把它作为普通商店卡抽取，付款由成功落地完成。
func _on_support_pressed(plant_type: int) -> void:
	support_requested.emit(plant_type)


## 复用原版墓碑菜单的完整美术与布局，操作接入本模式的重开、退出和倍速流程。
func _build_settings() -> void:
	_settings_overlay = ColorRect.new()
	_settings_overlay.size = Vector2(1066, 600)
	_settings_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_settings_overlay)
	# 克隆只保留原版视觉节点，避免重新开始或退出误用原版流程而遗失本局状态。
	var source: Control = Global.main_game.get_node("CanvasLayerUI/All_UI/MainGameMenuOptionDialog")
	# 剥离脚本、旧信号及嵌套画布后，菜单仅由当前模式统一驱动。
	var menu: TextureRect = source.duplicate(0)
	menu.get_node("Option/Button1/CanvasLayerAlmanac").free()
	menu.get_node("Option/Button4/CanvasLayerConsole").free()
	menu.theme = preload("res://data/PVZ_theme.tres")
	_settings_overlay.add_child(menu)
	menu.show()
	# 原版两条音量滑轨仍提交给现有音乐与音效总线，并由控制器即时保存。
	for bus: int in [SoundManager.Bus.BGM, SoundManager.Bus.SFX]:
		# 节点名称与原版菜单一致，不另造音量控件。
		var row: String = "Music" if bus == SoundManager.Bus.BGM else "SoundEffect"
		# 初始赋值不发出变更，避免打开菜单覆盖原配置。
		var slider: HSlider = menu.get_node("Option/VBoxContainer/" + row + "/HSlider")
		slider.set_value_no_signal(SoundManager.get_volum(bus))
		slider.value_changed.connect(volume_changed.emit.bind(bus))
	_menu_speed = menu.get_node("Option/VBoxContainer/TimeScale/HSlider")
	_menu_speed_label = menu.get_node("Option/VBoxContainer/TimeScale/Label")
	_menu_speed.min_value = 1.0
	_menu_speed.max_value = 2.0
	_menu_speed.step = 1.0
	_menu_speed.value_changed.connect(_on_menu_speed_changed)
	_menu_return = menu.get_node("Return")
	_menu_return.pressed.connect(_set_settings_visible.bind(false))
	menu.get_node("Option/Button2").pressed.connect(restart_requested.emit)
	menu.get_node("Option/Button3").pressed.connect(menu_requested.emit)
	# 已初始化的原选项窗口移到模式界面外层，保留配置回调，但不开放本模式无关的收集和调试项。
	_native_options = source.get_node("Option/Button4/CanvasLayerConsole")
	_native_options.reparent(_root)
	_native_options.process_mode = Node.PROCESS_MODE_ALWAYS
	_native_options.layer = 130
	_native_options.hide()
	_native_options.get_node("OptionBG/Label").text = "选项设置"
	# 隐藏节点而不销毁，原版配置同步仍可安全访问已有的复选框引用。
	for path: String in ["VBoxContainer/CheckBox", "VBoxContainer/CheckBox2", "VBoxContainer2/CheckBox10", "VBoxContainer2/CheckBox11"]:
		_native_options.get_node("OptionBG/HBoxContainer/" + path).hide()
	menu.get_node("Option/Button4").pressed.connect(_native_options.appear_canvas_layer_control)
	_almanac_layer = CanvasLayer.new()
	_almanac_layer.layer = 129
	_almanac_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_almanac_layer)
	menu.get_node("Option/Button1").pressed.connect(_show_almanac)
	SoundManager.setup_ui_main_game_sound(menu)
	set_speed(false)
	_settings_overlay.hide()


## 展示原版图鉴，不新增本模式尚未定义的植物或图鉴条目。
func _show_almanac() -> void:
	if _almanac_layer.get_child_count() > 0:
		return
	# 使用原版图鉴及其关闭流程，关闭后回到仍暂停的墓碑菜单。
	var almanac: Node = load(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac]).instantiate()
	_almanac_layer.add_child(almanac)


## 把原版滑轨[param value]映射到已保留的一倍、二倍速度，不引入额外速度档位。
func _on_menu_speed_changed(value: float) -> void:
	speed_selected.emit(value >= 2.0)


## 按[param opened]显示菜单并更新暂停因素；关闭时保存原版选项，准备人数显示立即恢复。
func _set_settings_visible(opened: bool) -> void:
	if _settings_overlay.visible == opened:
		return
	_settings_overlay.visible = opened
	_population.visible = not opened and _current_run != null and _current_run.phase == RunRules.Phase.PREPARATION
	if opened:
		_equipment_detail.hide()
		_menu_return.grab_focus()
	else:
		if _native_options.visible:
			_native_options._on_texture_button_pressed()
	settings_toggled.emit(opened)


## 根据[param run]的实时价格和同星进度更新[param button]中的[param plant_type]商品，-1表示售空。
func _update_shop_button(button: PlantCard, plant_type: int, run: RunRules) -> void:
	if plant_type == -1:
		button.show_empty("已售出 / 缺货")
		return
	# 同一计数方法驱动合成校验、进度文案与金色购买提示。
	var count: int = run.count_same_star(plant_type)
	# 第三张可直接合成，所以满手牌时仍允许这类购买。
	var capacity_available: bool = run.count_units(false) < RunRules.BENCH_LIMIT or count >= 2
	# 不满足余额或手牌容量时，卡图变暗且价格保持可见。
	var available: bool = run.can_manage() and capacity_available and run.sun >= run.purchase_price(plant_type)
	button.show_plant(plant_type, RunRules.CATALOG[plant_type].name, "☀ %d" % run.purchase_price(plant_type), "买入即可升星 ↑" if count >= 2 else "同名1星 %d/3" % count, count >= 2, available, TIER_COLORS[int(RunRules.CATALOG[plant_type].tier) - 1])
	button.tooltip_text = "%s｜%s\n未锁定备战同名1星：%d/3；备战席三个相同1/2星植物合成为2/3星，场上星级固定。%s" % ["/".join(RunRules.CATALOG[plant_type].get("traits", [RunRules.CATALOG[plant_type].trait])), RunRules.CATALOG[plant_type].tip, count, "\n十格备战席已满，请先种植或出售。" if not capacity_available else ""]


## 发送[param slot]当前存储的海克斯候选标识，选择有效性由规则层复核。
func _on_hex_pressed(slot: int) -> void:
	# 海克斯每个旗帜重新抽取，不能把旧标识固定在按钮连接上。
	var hex_id: String = _hex_buttons[slot].get_meta("hex_id", "")
	if not hex_id.is_empty():
		hex_requested.emit(hex_id)


## 将[param text]每十二个字符手动换行，以适合海克斯卡片；不改变原始配置。
func _wrap_text(text: String) -> String:
	# 逐段收集短行，适合目前以中文为主的强化说明。
	var parts: PackedStringArray = []
	# 字符起点以十二为步长，避免依赖按钮的自动折行支持。
	for offset: int in range(0, text.length(), 12):
		parts.append(text.substr(offset, 12))
	return "\n".join(parts)


## 在[param parent]下的[param rect]创建背景面板，返回新面板供添加控件。
func _panel(parent: Node, rect: Rect2) -> Panel:
	# 面板独立拥有样式，不影响其他界面资源。
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(PANEL_COLOR, Color("536448")))
	parent.add_child(panel)
	return panel


## 在[param parent]的[param rect]创建[param text]标签，使用[param font_size]和[param color]。
func _label(parent: Node, rect: Rect2, text: String, font_size: int, color: Color) -> Label:
	# 标签默认不拦截原版阳光与草坪的鼠标事件。
	var label: Label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## 在[param parent]的[param rect]创建[param text]按钮，点击调用无参[param action]。
func _button(parent: Node, rect: Rect2, text: String, action: Callable) -> Button:
	# 按钮使用固定区域，长名称通过字体大小与显式换行适配。
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", Color("ecf1df"))
	button.add_theme_color_override("font_disabled_color", Color("758176"))
	button.add_theme_stylebox_override("normal", _style(Color("294332"), Color("536448")))
	button.add_theme_stylebox_override("hover", _style(Color("3d5938"), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color("192f25"), GOLD_COLOR))
	button.add_theme_stylebox_override("disabled", _style(Color("1b2a23"), Color("344437")))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## 在[param parent]的[param rect]创建图片卡，使用[param is_shop]区分商品和手牌，点击调用[param action]。
func _plant_card(parent: Node, rect: Rect2, is_shop: bool, action: Callable) -> PlantCard:
	# 图片卡只绘制静态植物，不连接原版无限种子包的种植事件。
	var card: PlantCard = PlantCard.new()
	card.is_shop_card = is_shop
	card.position = rect.position
	card.size = rect.size
	card.pressed.connect(action)
	parent.add_child(card)
	return card


## 在[param parent]的[param rect]中显示[param texture]，不拦截植物拖拽或主草坪点击。
func _texture(parent: Node, rect: Rect2, texture: Texture2D) -> TextureRect:
	# 原版纹理按布局拉伸，不生成新的位图资源。
	var image: TextureRect = TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image


## 返回以[param fill]填充、[param border]描边的新圆角样式。
func _style(fill: Color, border: Color) -> StyleBoxFlat:
	# 为选中高亮和鼠标状态提供互不共享的样式资源。
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style
