## 货币战争整局规则：管理阳光、持有植物、地形直购、升星与十五节点进度。
class_name CurrencyWarRun
extends RefCounted

## 显式加载十五节点进度，旧海克斯数据不再推进节点。
const CampaignRules = preload("res://scripts/currency_war/currency_war_campaign.gd")
## 大纲装备、合成配方和纯属性计算。
const Equipment = preload("res://scripts/currency_war/currency_war_equipment.gd")
## 一至八级升到下一级所需经验，九级为文档规定上限。
const EXPERIENCE_THRESHOLDS: Array[int] = [4, 6, 8, 16, 32, 40, 52, 64]
## 大纲九级概率表暂存；用户最新要求暂不启用，所有已定义普通植物等概率出现。
const SHOP_ODDS: Array[Array] = [[100, 0, 0, 0, 0], [85, 15, 0, 0, 0], [75, 20, 5, 0, 0], [60, 25, 15, 0, 0], [43, 32, 22, 3, 0], [32, 40, 23, 5, 0], [24, 25, 35, 15, 1], [18, 22, 30, 25, 5], [13, 17, 20, 35, 15]]
## 费用档位对应的一至三星售卖价格，直接使用用户大纲1.1的数值。
const SELL_PRICES: Array[Array] = [[1, 3, 9], [2, 5, 17], [3, 8, 26], [4, 11, 35], [5, 14, 44]]

## 每个节点经历准备、战斗和结果；旧海克斯阶段仅保留兼容标识，不再触发。
enum Phase {
	PREPARATION, ## 开局准备，不刷新僵尸和阳光。
	BATTLE, ## 持续防守，可实时D牌、购买和种植。
	NODE_RESULT, ## 当前节点已结算，继续后进入下一节点准备阶段。
	HEX_CHOICE, ## 旗帜点三选一海克斯，选择后继续同一片战场。
	FINISHED, ## 房屋被突破或清空最终波。
	PREVIEW, ## 原版镜头右移预览敌人，返回后才允许准备操作。
}

## 旧海克斯界面兼容常量，不用于新节点的实际波数；实际波数读取[member node_wave_limit]。
const WAVE_LIMIT: int = 60
## 独立备战草坪固定十格，高星植物仍只占一格，不占用主草坪。
const BENCH_LIMIT: int = 10
## D牌后同时提供的商品数量。
const SHOP_SIZE: int = 5
## 大纲1.1指定的每次D牌费用，以阳光计价。
const REROLL_COST: int = 2
## 用户确认取消开局植物赠送，仅保留5点初始阳光。
const STARTING_SUN: int = 5
## 货币战争每波的出怪战力倍率；提高数量时仍沿用原版随机选怪与每波数量上限。
const ZOMBIE_WAVE_MULTIPLIER: int = 2
## 一级可上场的不同普通植物种类数；升级后每级再增加一种。
const STARTING_SPECIES_LIMIT: int = 3
## 尚未种下的手牌位置标记；草坪位置为从零开始的行、列。
const BENCH_CELL: Vector2i = Vector2i(-1, -1)
## 大纲已定义的白绿蓝紫植物与两种直购地形植物；未定义的金卡不填入。
const CATALOG: Dictionary = {
	1: {"name": "豌豆射手", "tier": 1, "trait": "豌豆", "tip": "稳定的单行远程输出"},
	2: {"name": "向日葵", "tier": 1, "trait": "阳光", "tip": "节点结束按星级产生1/4/10阳光"},
	5: {"name": "土豆地雷", "tier": 1, "trait": "灰烬", "tip": "爆炸后重新入土；二三星加快出土并提升伤害"},
	6: {"name": "寒冰豌豆", "tier": 2, "trait": "豌豆", "tip": "二三星强化减速，并有概率发射可冰冻1秒的冰球"},
	8: {"name": "双发豌豆", "tier": 2, "trait": "豌豆", "tip": "二三星提高攻速；概率发射火球，三星可发射紫球"},
	19: {"name": "三发豌豆", "tier": 3, "trait": "豌豆", "tip": "三个头独立判定大豌豆，命中造成一格范围伤害"},
	41: {"name": "机枪豌豆", "tier": 4, "trait": "豌豆", "tip": "可直接种植；二三星有概率发射8颗，三星可发射火豌豆"},
	17: {"name": "睡莲", "tier": 1, "trait": "", "tip": "泳池场景1阳光直购，不参与升星", "support": true},
	34: {"name": "花盆", "tier": 1, "trait": "", "tip": "屋顶场景1阳光直购，不参与升星", "support": true},
}
## 已定义植物一至三星的攻击增幅；缺省类型不擅自添加星级攻击。
const STAR_ATTACK_BONUS: Dictionary = {1: [0.0, 0.2, 0.5], 19: [0.0, 0.2, 0.5], 41: [0.0, 0.3, 1.0]}
## 普通、双发、三发与机枪豌豆分别增加0%、50%、100%攻击频率，寒冰不加文档未写的攻速。
const STAR_SPEED_BONUS: Dictionary = {1: [0.0, 0.5, 1.0], 8: [0.0, 0.5, 1.0], 19: [0.0, 0.5, 1.0], 41: [0.0, 0.5, 1.0]}
## 羁绊只计算草坪上不同植物种类，同名植物不重复计数。
const TRAITS: Dictionary = {
	"豌豆": "2种：豌豆攻速+25%；4种：+55%",
	"坚守": "2种：全部植物最大生命+40%",
	"菌群": "2种：菌群攻速+35%",
	"丰收": "2种：产阳光植物生产速度+25%",
}
## 海克斯配置；每种强化一局最多选择一次，效果持续到本局结束。
const HEXES: Dictionary = {
	"solar_focus": {"name": "光合增幅", "tip": "每次收集阳光获得额外25%阳光。"},
	"bargain": {"name": "园艺特卖", "tip": "后续从商店购买植物的阳光费用降低20%。"},
	"reroll_master": {"name": "戴夫会员", "tip": "每次D牌费用从25阳光降至10阳光。"},
	"vitality": {"name": "坚韧根系", "tip": "所有植物最大生命提高35%，已有植物保留当前血量比例。"},
	"rapid_fire": {"name": "火力全开", "tip": "所有发射子弹植物的攻击速度提高20%。"},
	"fertilizer": {"name": "高效光合", "tip": "所有产阳光植物的生产速度提高25%。"},
	"windfall": {"name": "阳光空投", "tip": "立刻获得200阳光。"},
	"flag_dividend": {"name": "旗帜红利", "tip": "立即获得100阳光，此后每到一面旗帜再获得100阳光。"},
	"free_rolls": {"name": "刷新赠券", "tip": "立即获得2次免费D牌，此后每面旗帜再获得2次。"},
}
## 当前阶段；准备与战斗均允许从牌库购买及种植。
var phase: Phase = Phase.PREPARATION
## 唯一可消费的局内货币，与收集到的阳光共用余额。
var sun: int = STARTING_SUN
## 当前节点的原版进攻波次，从零开始等待第一波，上限为[member node_wave_limit]。
var current_wave: int = 0
## 已处理的旗帜波次，防止一次旗帜重复发奖励和弹出海克斯。
var visited_flags: Array[int] = []
## 持有植物；id唯一，cell标记主草坪或备战状态，reserve_slot保存固定备战格，种下后为-1。
var units: Array[Dictionary] = []
## 当前商店的植物类型；-1表示售出或该次没有可抽取的卡。
var shop: Array[int] = []
## 是否把当前商品保留到下一节点，使用一次后自动解除。
var shop_locked: bool = false
## 当前供选择的三个海克斯标识，选择后清空。
var hex_options: Array[String] = []
## 本局已经选择的海克斯标识。
var selected_hexes: Array[String] = []
## 最近一次成功购买产生的合成结果，记录保留标识、消耗标识、植物类型与目标星级。
var last_merges: Array[Dictionary] = []
## 尚可使用的免费D牌次数。
var free_refreshes: int = 0
## 最近操作提示，显示在抬头区域。
var message: String = "初始5阳光；按空格打开商店，购买后拖到主草坪种植。"
## 是否在第四次吃脑之前打赢最后一个节点。
var campaign_won: bool = false
## 下一张新植物的唯一标识，合成后不复用已移除标识。
var _next_id: int = 1
## 独立随机源，D牌和海克斯抽取不会改变原版波次的随机状态。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## 当前整局十五节点、随机场景、吃脑次数和连胜记录。
var campaign: CampaignRules = CampaignRules.new()
## 当前原版关卡配置的波数，由每个节点场景加载后设置。
var node_wave_limit: int = 30
## 当前场景实际草坪行数，泳池为六行，其余为五行。
var board_rows: int = 5
## 当前节点开放的真实行号，保留中间行索引使草坪扩建不会搬动原有植物。
var active_lanes: Array[int] = []
## 正在播放原版铺草动画，期间禁止开战和在草坪上拖放，商店操作仍可进行。
var lawn_expanding: bool = false
## 当前场景可直购的地形植物，17为睡莲、34为花盆、-1为无。
var support_type: int = -1
## 当前节点结算信息，不与实时阳光提示混用。
var settlement_text: String = ""
## 最终结果是否已成功写入当前用户的主菜单仓库。
var collection_saved: bool = false
## 当前等级，上限九级；不增加文档未定义的十级。
var level: int = 1
## 当前等级尚未消耗的经验；满级后节点奖励仍记入余额，购买经验禁用。
var experience: int = 0
## 进入本节点准备阶段时的阳光快照，后续买牌、D牌和战斗内收入不改变本节点利息基数。
var node_opening_sun: int = STARTING_SUN
## 玩家未佩戴的普通装备，每个字符串代表一件，可重复。
var equipment_inventory: Array[String] = []
## 单位标识对应的本节点攻击动作计数，升星不修改，进入新节点清空。
var attack_actions: Dictionary = {}
## 每株每个装备槽在本节点佩戴期间的攻击动作数，新增装备不补算佩戴前攻击。
var equipment_actions: Dictionary = {}
## 当前唯一机枪头盔的佩戴者，-1表示背包可用或尚未激活羁绊。
var helmet_unit_id: int = -1
## 遭遇关选择的难度档位，一至四，仅影响当前遭遇节点。
var encounter_level: int = 1


## 建立初始商店；按用户确认取消十株赠送，备战席初始为空，不叠加大纲未指定的20张副本上限。
func _init() -> void:
	_random.randomize()
	refresh_shop(false)


## 返回是否允许买牌、D牌、铲除或种植；海克斯选择与结局期间禁止交易。
func can_manage() -> bool:
	return phase == Phase.PREPARATION or phase == Phase.BATTLE


## 查找[param unit_id]对应的植物，找不到时返回空字典。
func find_unit(unit_id: int) -> Dictionary:
	# 逻辑单位在阵亡、铲除或合成后会从该列表移除。
	for unit: Dictionary in units:
		if unit.id == unit_id:
			return unit
	return {}


## 返回[param cell]的[param layer]地形层植物，默认普通层；手牌标记与空地均返回空字典。
func unit_at(cell: Vector2i, layer: int = CharacterRegistry.PlacePlantInCell.Norm) -> Dictionary:
	if cell == BENCH_CELL:
		return {}
	# 已种植物必须占用唯一的草坪格子。
	for unit: Dictionary in units:
		if unit.cell == cell and placement(int(unit.type)) == layer:
			return unit
	return {}


## 返回草坪植物数量；[param on_board]为false时返回手牌数量。
func count_units(on_board: bool = true) -> int:
	# 高星植物仍按一张手牌或一株植物计数。
	var count: int = 0
	# 根据逻辑位置区分场上与手牌。
	for unit: Dictionary in units:
		if (unit.cell != BENCH_CELL) == on_board:
			count += 1
	return count


## 返回固定备战格[param slot]中的植物；空格或超出十格范围时返回空字典。
func reserve_at(slot: int) -> Dictionary:
	if slot < 0:
		return {}
	# 通过独立的格号查询，不因其他植物被种下、出售或合成而重新排列。
	for unit: Dictionary in units:
		if unit.cell == BENCH_CELL and int(unit.get("reserve_slot", -1)) == slot:
			return unit
	return {}


## 将[param unit_id]放回备战格[param slot]；准备期间场上植物可退回或换位，战斗期间仅备战席内部可换位。
func move_reserve(unit_id: int, slot: int) -> bool:
	if not can_manage() or slot < 0 or slot >= reserve_display_count():
		return false
	# 已经种下的植物不能通过拖拽免费退回备战席。
	var unit: Dictionary = find_unit(unit_id)
	if unit.is_empty() or (unit.cell != BENCH_CELL and phase != Phase.PREPARATION):
		return false
	# 保留交换前的位置与头盔绑定，种类超限时必须原样回滚。
	var previous_cell: Vector2i = unit.cell
	# 固定备战格号不能因一次失败的拖动被重排。
	var previous_slot: int = int(unit.reserve_slot)
	# 头盔取下只在位置变更成功后生效。
	var previous_helmet: int = helmet_unit_id
	# 目标格可以为空，也可以和源格互换，十个格位始终固定。
	var occupant: Dictionary = reserve_at(slot)
	if not occupant.is_empty():
		if unit.cell != BENCH_CELL:
			# 从场上换回备战时，目标备战植物承接原格；不同地形层有其他植物时拒绝覆盖。
			var board_occupant: Dictionary = unit_at(unit.cell, placement(int(occupant.type)))
			if not board_occupant.is_empty() and int(board_occupant.id) != unit_id:
				return false
		occupant["cell"] = unit.cell
		occupant["reserve_slot"] = int(unit["reserve_slot"])
	unit["cell"] = BENCH_CELL
	unit["reserve_slot"] = slot
	if helmet_unit_id == unit_id and previous_cell != BENCH_CELL:
		helmet_unit_id = -1
	if deployed_species_count() > species_limit():
		unit.cell = previous_cell
		unit.reserve_slot = previous_slot
		if not occupant.is_empty():
			occupant.cell = BENCH_CELL
			occupant.reserve_slot = slot
		helmet_unit_id = previous_helmet
		message = "交换后超过当前等级的上场种类上限。"
		return false
	message = "备战植物已换位；拖到主草坪空格即可种植。"
	return true


## 按大纲1.1返回[param plant_type]的1至5费价格，不读取原版25至数百点的种植费用。
func base_price(plant_type: int) -> int:
	return int(CATALOG[plant_type].tier)


## 返回[param plant_type]的[param star]星攻击增幅，未定义类型返回0，不包括装备和羁绊。
func star_attack_bonus(plant_type: int, star: int) -> float:
	return float(STAR_ATTACK_BONUS[plant_type][clampi(star, 1, 3) - 1]) if STAR_ATTACK_BONUS.has(plant_type) else 0.0


## 返回[param plant_type]的[param star]星攻速增幅，未定义类型返回0，频率增幅不能作为伤害倍率。
func star_speed_bonus(plant_type: int, star: int) -> float:
	return float(STAR_SPEED_BONUS[plant_type][clampi(star, 1, 3) - 1]) if STAR_SPEED_BONUS.has(plant_type) else 0.0


## 返回[param plant_type]的费用档位价格；新大纲未定义海克斯折扣，不再应用旧折扣。
func purchase_price(plant_type: int) -> int:
	return base_price(plant_type)


## 返回大纲指定的2点D牌费用，不再使用旧海克斯减价和赠券。
func refresh_price() -> int:
	return REROLL_COST


## 收集[param value]点原版阳光，应用收集增幅并返回实际入账值；结局后不再计入。
func collect_sun(value: int) -> int:
	if phase == Phase.FINISHED or value <= 0:
		return 0
	# 收集强化在原版收集事件抵达时统一计算，避免修改阳光实体。
	var received: int = roundi(value * (1.25 if has_hex("solar_focus") else 1.0))
	sun += received
	return received


## 购买[param slot]栏位的一张植物；余额或手牌容量不足时不扣款，返回是否成功。
func buy(slot: int) -> bool:
	if not can_manage() or slot < 0 or slot >= shop.size() or shop[slot] == -1:
		return false
	# 使用当前商品类型，不额外引入大纲未规定的有限副本库存。
	var plant_type: int = shop[slot]
	# 购买只花阳光，种植已持有手牌时不重复收费。
	var price: int = purchase_price(plant_type)
	if sun < price:
		message = "阳光不足，购买需要%d阳光。" % price
		return false
	if count_units(false) >= BENCH_LIMIT and not _can_merge_purchase(plant_type):
		message = "十格备战席已满，请先种植或出售植物。"
		return false
	sun -= price
	last_merges.clear()
	shop[slot] = -1
	_add_unit(plant_type)
	message = "已花费%d阳光购买%s，已放入备战草坪。" % [price, CATALOG[plant_type].name]
	_merge_all()
	_assign_reserve_slots()
	return true


## 统计[param plant_type]恰为[param star]星且未锁定的备战与场上植物；高星不折算为低星副本。
func count_same_star(plant_type: int, star: int = 1) -> int:
	if is_support(plant_type):
		return 0
	# 统计真实参与同星三合一的单位，供购买校验和卡面进度共同使用。
	var count: int = 0
	# 场上与备战席共同参与合成，商店进度和满席购买使用同一计数标准。
	for unit: Dictionary in units:
		if int(unit["type"]) == plant_type and int(unit["star"]) == star and not bool(unit.get("merge_locked", false)):
			count += 1
	return count


## 将手牌[param unit_id]种到[param cell]；禁止覆盖、移动已有植物，成功返回true。
func plant_card(unit_id: int, cell: Vector2i) -> bool:
	if not can_manage():
		return false
	# 被升星消耗或已经种下的牌不能重复种植。
	var unit: Dictionary = find_unit(unit_id)
	if unit.is_empty():
		return false
	if unit.cell != BENCH_CELL and phase != Phase.PREPARATION:
		message = "已种下的植物不能移动，可选择后铲除。"
		return false
	if cell.x < 0 or cell.x >= board_rows or not is_lane_open(cell.x) or lawn_expanding or cell.y < 0 or cell.y >= 9:
		message = "这块草坪已有植物，请选择空地。"
		return false
	# 为失败的种类上限校验保留原始位置与绑定，拖放失败不改备战格号。
	var previous_cell: Vector2i = unit.cell
	# 上场单位为-1，备战单位保留其固定位置。
	var previous_slot: int = int(unit.reserve_slot)
	# 交换可能将佩戴头盔的目标退回备战，回滚时需恢复绑定。
	var previous_helmet: int = helmet_unit_id
	# 普通植物与睡莲/花盆分层占格；准备期间可在同层交换位置。
	var occupant: Dictionary = unit_at(cell, placement(int(unit.type)))
	if not occupant.is_empty() and int(occupant.id) != unit_id:
		if phase != Phase.PREPARATION:
			return false
		occupant["cell"] = unit.cell
		occupant["reserve_slot"] = int(unit.get("reserve_slot", -1))
	unit.cell = cell
	unit["reserve_slot"] = -1
	if not occupant.is_empty() and occupant.cell == BENCH_CELL and helmet_unit_id == int(occupant.id):
		helmet_unit_id = -1
	# 种类限制只检查上场阵容，底座与同种多株不额外占种类名额；失败时回滚交换。
	if deployed_species_count() > species_limit():
		if not occupant.is_empty() and int(occupant.id) != unit_id:
			occupant["cell"] = cell
			occupant["reserve_slot"] = -1
		unit["cell"] = previous_cell
		unit["reserve_slot"] = previous_slot
		helmet_unit_id = previous_helmet
		message = "当前等级最多上场%d种植物，睡莲和花盆不计入。" % species_limit()
		return false
	message = "已种植%s；备战席已空出一格。" % CATALOG[unit.type].name
	return true


## 仅在战场实体创建失败时将[param unit_id]退回空备战格，防止落点竞争造成植物凭空丢失。
func restore_reserve(unit_id: int) -> void:
	# 种植刚刚释放了一格备战位置，因此回滚不应扩展十格容量或生成额外副本。
	var unit: Dictionary = find_unit(unit_id)
	if not unit.is_empty():
		unit.cell = BENCH_CELL
		unit["reserve_slot"] = _first_free_reserve_slot(true)
		if helmet_unit_id == unit_id:
			helmet_unit_id = -1
		message = "该位置暂时无法种植，植物已回到备战草坪。"


## 按大纲售卖表出售[param unit_id]，已佩戴普通装备解除绑定回背包，不恢复阵亡植物。
func sell(unit_id: int) -> bool:
	if not can_manage():
		return false
	# 手上的牌和场上的植物使用相同退款规则。
	var unit: Dictionary = find_unit(unit_id)
	if unit.is_empty():
		return false
	# 直接按费用与星级查表，不再采用旧原型50%的退款比例。
	var refund: int = sell_value(unit)
	sun += refund
	_release_equipment(unit)
	units.erase(unit)
	message = "已移除%s，返还%d阳光。" % [CATALOG[unit.type].name, refund]
	return true


## 返回[param unit]在大纲售卖表中的价格；底座不升星，按一费一星返还1阳光。
func sell_value(unit: Dictionary) -> int:
	return int(SELL_PRICES[base_price(unit.type) - 1][int(unit.star) - 1])


## 植物[param unit_id]阵亡后永久移除本局拥有记录；不返阳光，节点切换也不复活。
func lose_plant(unit_id: int) -> void:
	# 清理或合成可能已先移除该标识，重复死亡回调应当无副作用。
	var unit: Dictionary = find_unit(unit_id)
	if not unit.is_empty():
		_release_equipment(unit)
		units.erase(unit)
		message = "%s已阵亡，需要重新D牌购买。" % CATALOG[unit.type].name


## D出全部商品；[param paid]为false时表示开局或进入新节点的免费刷新，返回是否成功。
func refresh_shop(paid: bool = true) -> bool:
	if not can_manage():
		return false
	# 先确认费用，阳光不足时不能退还旧商品或改变随机结果。
	var price: int = refresh_price() if paid else 0
	if sun < price:
		message = "D牌需要%d阳光。" % price
		return false
	if paid:
		sun -= price
		if free_refreshes > 0:
			free_refreshes -= 1
		message = "已花费%d阳光D牌。" % price
	shop.clear()
	# 每个商店位置分别从当前已定义的可抽取植物中产生商品。
	for slot: int in range(SHOP_SIZE):
		shop.append(_draw_card())
	return true


## 切换保留到下一节点的状态；主动D牌仍可替换当前商品，锁店只影响下一节点自动刷新。
func toggle_lock() -> void:
	if can_manage():
		shop_locked = not shop_locked
		message = "当前商品将保留到下一节点，届时自动解除保留。" if shop_locked else "已取消保留，下一节点自动免费刷新商店。"


## 仅准备阶段切换[param unit_id]的合成锁定；解除后立即合成三张同名同星未锁定植物，其他阶段返回false且不改状态。
func toggle_merge_lock(unit_id: int) -> bool:
	if phase != Phase.PREPARATION:
		return false
	# 锁定记录跟随持有单位，场上与备战移动及跨节点均保留。
	var unit: Dictionary = find_unit(unit_id)
	if unit.is_empty():
		return false
	last_merges.clear()
	unit["merge_locked"] = not bool(unit.get("merge_locked", false))
	message = "%s%s。" % [CATALOG[unit.type].name, "已锁定，不参与升星" if unit.merge_locked else "已解除锁定"]
	if not unit.merge_locked:
		_merge_all()
		_assign_reserve_slots()
	return true


## 返回当前草坪上各羁绊的不同种类数量，植物死亡后会失去对应计数。
func trait_counts() -> Dictionary:
	# 每种植物只计数一次。
	var seen: Dictionary = {}
	# 只统计大纲中的两种待开发羁绊和暂缓制作的灰烬标记，不混入旧原型的羁绊类别。
	var counts: Dictionary = {"豌豆": 0, "阳光": 0, "灰烬": 0}
	# 手牌不提供任何羁绊。
	for unit: Dictionary in units:
		if unit.cell != BENCH_CELL and not is_support(int(unit.type)) and not seen.has(unit.type):
			seen[unit.type] = true
			counts[CATALOG[unit.type].trait] += 1
	return counts


## 记录[param wave]旗帜进度、发放已持有的旗帜奖励并抽取海克斯；重复旗帜返回false。
func reach_flag(wave: int) -> bool:
	if phase != Phase.BATTLE or wave % 10 != 0 or visited_flags.has(wave):
		return false
	visited_flags.append(wave)
	if has_hex("flag_dividend"):
		sun += 100
	if has_hex("free_rolls"):
		free_refreshes += 2
	if not shop_locked:
		refresh_shop(false)
	# 从尚未选择的强化中抽取三个，防止同一局重复叠加难以说明的效果。
	var candidates: Array[String] = []
	# 候选标识与效果文案均来自固定配置。
	for hex_id: String in HEXES:
		if not has_hex(hex_id):
			candidates.append(hex_id)
	hex_options.clear()
	while not candidates.is_empty() and hex_options.size() < 3:
		# 独立随机挑选后移除，保证本次三个选项互不重复。
		var index: int = _random.randi_range(0, candidates.size() - 1)
		hex_options.append(candidates[index])
		candidates.remove_at(index)
	phase = Phase.HEX_CHOICE
	message = "第%d波旗帜点：选择一项海克斯后继续防守。" % wave
	return true


## 选择当前候选[param hex_id]并立即应用经济奖励；属性强化由战场同步函数应用，成功返回true。
func choose_hex(hex_id: String) -> bool:
	if phase != Phase.HEX_CHOICE or not hex_options.has(hex_id):
		return false
	selected_hexes.append(hex_id)
	match hex_id:
		"windfall":
			sun += 200
		"flag_dividend":
			sun += 100
		"free_rolls":
			free_refreshes += 2
	hex_options.clear()
	phase = Phase.BATTLE
	message = "已获得海克斯：%s。" % HEXES[hex_id].name
	return true


## 返回是否已经拥有[param hex_id]，供价格、产出和战斗属性计算共用。
func has_hex(hex_id: String) -> bool:
	return selected_hexes.has(hex_id)


## 添加[param plant_type]的一张一星手牌，获得单局唯一标识。
func _add_unit(plant_type: int) -> void:
	units.append({"id": _next_id, "type": plant_type, "star": 1, "cell": BENCH_CELL, "reserve_slot": _first_free_reserve_slot(), "equipment": [], "merge_locked": false})
	_next_id += 1


## 返回首个空备战格；[param allow_overflow]仅用于跨地图退回，允许十格之外的保留位置；正常满席购买时返回-1。
func _first_free_reserve_slot(allow_overflow: bool = false) -> int:
	# 固定十格按从左到右顺序优先使用空位。
	for slot: int in range(maxi(BENCH_LIMIT, units.size() + 1) if allow_overflow else BENCH_LIMIT):
		if reserve_at(slot).is_empty():
			return slot
	return -1


## 为满席直接合成产生的临时无位置植物补齐空格，不重排已有备战植物。
func _assign_reserve_slots() -> void:
	# 正常购买和开局都已有格位，只处理直接合成后仍然存在的临时记录。
	for unit: Dictionary in units:
		if unit.cell == BENCH_CELL and int(unit.get("reserve_slot", -1)) == -1:
			unit["reserve_slot"] = _first_free_reserve_slot(true)


## 返回购买[param plant_type]后是否立即合成，以允许手牌已满时直接升星。
func _can_merge_purchase(plant_type: int) -> bool:
	return count_same_star(plant_type, 1) >= 2


## 将场上与备战席的三张未锁定同名同星植物合成，可连锁升至三星；锁定植物不作为材料或保留者。
func _merge_all() -> void:
	# 按种类和星级稳定处理，一星合成的结果还会参与后面的二星合成。
	for plant_type: int in CATALOG:
		# 三星是上限，不再把三个三星单位继续合成。
		for star: int in range(1, 3):
			while count_same_star(plant_type, star) >= 3:
				_merge_three(plant_type, star)
	if not last_merges.is_empty():
		# 连锁合成时展示最后获得的最高星级，不被普通购买提示覆盖。
		var result: Dictionary = last_merges.back()
		message = "%s合成成功 → %s（%d星）" % [CATALOG[result.type].name, "★".repeat(result.star), result.star]


## 合并[param plant_type]的三张[param star]星单位，记录保留者与消耗者；调用前必须确认同星数量至少为三。
func _merge_three(plant_type: int, star: int) -> void:
	# 分别保存候选标识，恢复场上植物参与合成，不改变已经使用的唯一标识同步方式。
	var hand_ids: Array[int] = []
	# 有场上植物时沿用原来的原位合成方式，避免将它自动搬回备战席。
	var board_ids: Array[int] = []
	# 通过唯一标识操作，避免删除数组元素时使其他候选的数组索引失效。
	for unit: Dictionary in units:
		if int(unit["type"]) != plant_type or int(unit["star"]) != star or bool(unit.get("merge_locked", false)):
			continue
		if unit.cell == BENCH_CELL:
			hand_ids.append(int(unit.id))
		else:
			board_ids.append(int(unit.id))
	# 优先保留一株场上候选；所有候选都在备战席时保留最早的一株。
	var keeper_id: int = board_ids.pop_front() if not board_ids.is_empty() else hand_ids.pop_front()
	# 沿用先消耗备战植物的顺序，三合一仍然只消耗两个其他同星单位。
	var candidates: Array[int] = hand_ids + board_ids
	# 每次精确消耗两个其他单位，其代表的副本转移到保留者，不退回牌库。
	var consumed_ids: Array[int] = [candidates[0], candidates[1]]
	# 从后向前删除，防止跳过相邻的已消耗记录。
	for index: int in range(units.size() - 1, -1, -1):
		if consumed_ids.has(int(units[index]["id"])):
			# 升星不合并、销毁或重算装备；保留者装备不变，材料单位的装备解除绑定回背包。
			_release_equipment(units[index])
			units.remove_at(index)
	# 重新找到保留者并显式替换数组中的记录，确保后续界面和战场读到新星级。
	for index: int in range(units.size()):
		if int(units[index]["id"]) == keeper_id:
			# 使用独立的新记录写回，避免合成候选与拥有数组之间存在旧的星级快照。
			var upgraded: Dictionary = units[index].duplicate()
			upgraded["star"] = star + 1
			units[index] = upgraded
			break
	last_merges.append({"id": keeper_id, "type": plant_type, "star": star + 1, "consumed": consumed_ids})


## 按用户最新确认从全部已定义的普通植物中等概率抽取，暂不启用等级费用概率或添加金卡。
func _draw_card() -> int:
	# 地形直购品始终排除，普通植物保留大纲费用，不因等概率抽取改变价格。
	var candidates: Array[int] = []
	# 每个已定义类型占一个候选位置，与费用和等级无关。
	for plant_type: int in CATALOG:
		if not is_support(plant_type):
			candidates.append(plant_type)
	if candidates.is_empty():
		return -1
	return candidates[_random.randi_range(0, candidates.size() - 1)]


## 返回[param plant_type]是否为用户新增的睡莲或花盆直购品，两者永不参与升星。
func is_support(plant_type: int) -> bool:
	return plant_type == 17 or plant_type == 34


## 返回[param plant_type]的地形层，睡莲和花盆使用底座层，其余使用普通层。
func placement(plant_type: int) -> int:
	return CharacterRegistry.PlacePlantInCell.Down if is_support(plant_type) else CharacterRegistry.PlacePlantInCell.Norm


## 返回备战席需要展示的格数；正常为十格，跨场景退回的额外植物保留在可滚动溢出格，绝不丢弃。
func reserve_display_count() -> int:
	# 固定十格之外的格子仅为跨场景保留植物提供展示，不提高正常购买的十格容量。
	var count: int = BENCH_LIMIT
	# 空洞格位仍保留编号，避免换场景后其他植物自行挪位。
	for unit: Dictionary in units:
		if unit.cell == BENCH_CELL:
			count = maxi(count, int(unit.get("reserve_slot", -1)) + 1)
	return count


## 在对应场景花费1阳光直购[param plant_type]；不经过随机商店、不占牌库副本、不触发三合一。
func buy_support(plant_type: int) -> bool:
	if not can_manage() or not is_support(plant_type) or plant_type != support_type:
		return false
	if sun < 1 or count_units(false) >= BENCH_LIMIT:
		message = "需要1阳光和一个空备战格。"
		return false
	sun -= 1
	_add_unit(plant_type)
	message = "已购买%s，不参与升星。" % CATALOG[plant_type].name
	return true


## 配置新节点的[param rows]实际行数、[param waves]实际小波数及[param support]直购品；未开放行或超出范围的植物回备战席。
func configure_node(rows: int, waves: int, support: int) -> void:
	board_rows = rows
	node_opening_sun = sun
	attack_actions.clear()
	equipment_actions.clear()
	active_lanes = campaign.active_lanes(rows)
	lawn_expanding = false
	node_wave_limit = waves
	support_type = support
	# 保持仍有效的部署位置，第六行退回时允许溢出十格，防止静默删除幸存植物。
	for unit: Dictionary in units:
		if unit.cell != BENCH_CELL and not is_lane_open(unit.cell.x):
			restore_reserve(int(unit.id))


## 返回真实行号[param lane]是否开放；所有种植入口共用此规则，未铺草的泥地不能放植物。
func is_lane_open(lane: int) -> bool:
	return active_lanes.has(lane)


## 记录[param won]的节点结算并切入节点结果阶段；同一节点只结算一次，永久存库只由最终结果触发。
func settle_node(won: bool) -> void:
	if phase != Phase.BATTLE:
		return
	campaign.record_result(won)
	# 向日葵只在节点结算产出，备战席植物不参与本节点的场上产出。
	var plant_income: int = 0
	# 星级产出严格使用大纲2.1的1、4、10，不沿用旧版生产速度加成。
	for unit: Dictionary in units:
		if int(unit.type) == 2 and unit.cell != BENCH_CELL:
			plant_income += [1, 4, 10][int(unit.star) - 1]
	# 连胜节点按大纲明确档位奖励；失败已经由record_result清空连胜。
	var streak_income: int = 3 if campaign.win_streak >= 5 else (2 if campaign.win_streak >= 3 else (1 if campaign.win_streak == 2 else 0))
	# 用户明确失败只扣除连胜收入，奖励关额外五点和装备仍照常发放。
	var reward_income: int = 5 if campaign.node_kind() == "奖励关" else 0
	# 每节点只结算一次，失败仅失去连胜奖励；利息基于本节点准备开始时的阳光。
	var interest_income: int = mini(5, floori(node_opening_sun / 10.0))
	# 阳光羁绊只计算场上不同种类，收益为该档位的一次额外结算。
	var solar_count: int = int(trait_counts().get("阳光", 0))
	# 目前名单不足时不补充植物，后续同阵营新增后可直接达到这些文档阈值。
	var solar_income: int = 4 if solar_count >= 4 else (2 if solar_count >= 3 else (1 if solar_count >= 2 else 0))
	# 遭遇难度一的经济和经验奖励在常规结算外增加。
	var encounter_income: int = 2 if campaign.node_kind() == "遭遇关" and encounter_level == 1 else 0
	sun += 5 + plant_income + streak_income + reward_income + interest_income + solar_income + encounter_income
	gain_experience(2 + (2 if encounter_income > 0 else 0))
	if campaign.node_kind() == "奖励关":
		grant_equipment(3, false)
	elif campaign.node_kind() == "遭遇关":
		if encounter_level == 2:
			grant_equipment(1, false)
		elif encounter_level == 3:
			grant_equipment(2, false)
		elif encounter_level == 4:
			grant_equipment(2, true)
	phase = Phase.FINISHED if campaign.is_final_result() else Phase.NODE_RESULT
	campaign_won = won and campaign.brain_losses < CampaignRules.FINAL_BRAIN_LOSS and campaign.node_index == CampaignRules.NODE_COUNT - 1
	settlement_text = "%s %s\n连胜%d · 已吃脑%d次（第4次结束）\n存活植物%d株，备战植物%d株。" % [campaign.node_label(), "获胜" if won else "被吃脑", campaign.win_streak, campaign.brain_losses, count_units(), count_units(false)]
	settlement_text += "\n阳光：固定5 + 植物%d + 连胜%d + 利息%d + 节点%d\n等级%d · 经验%d · 背包装备%d件" % [plant_income + solar_income, streak_income, interest_income, reward_income + encounter_income, level, experience, equipment_inventory.size()]
	message = "节点已结束，存活植物将在下一准备节点满血，阵亡植物不会恢复。"


## 从节点结果进入下一准备阶段；复用整局单位与阳光，绝不重新发放开局资源。
func advance_node() -> bool:
	if phase != Phase.NODE_RESULT or not campaign.advance():
		return false
	phase = Phase.PREPARATION
	current_wave = 0
	encounter_level = 1
	if shop_locked:
		# 商品及已售空栏位原样保留一次，之后的节点恢复自动刷新。
		shop_locked = false
	else:
		refresh_shop(false)
	message = "准备%s %s，可拖动场上和备战席植物调整位置。" % [campaign.node_label(), campaign.node_kind()]
	return true


## 返回当前等级的场上不同植物种类上限；一级为三种，同一种多株和地形底座不额外计数。
func species_limit() -> int:
	return STARTING_SPECIES_LIMIT + level - 1


## 只计算场上非地形植物的不同类型，备战席与装备不计入。
func deployed_species_count() -> int:
	# 用类型集合去重，同种多株不重复占名额。
	var types: Dictionary = {}
	# 地形植物固定排除，不能用买睡莲或花盆触发人口限制。
	for unit: Dictionary in units:
		if unit.cell != BENCH_CELL and not is_support(int(unit.type)):
			types[int(unit.type)] = true
	return types.size()


## 增加[param amount]经验并按文档阈值升级；九级不再增加等级，节点奖励经验仍保留。
func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	while level < 9 and experience >= EXPERIENCE_THRESHOLDS[level - 1]:
		experience -= EXPERIENCE_THRESHOLDS[level - 1]
		level += 1


## 花费4阳光获得4经验；阳光不足、非可操作阶段或已九级时不扣款，返回是否成功。
func buy_experience() -> bool:
	if not can_manage() or sun < 4 or level >= 9:
		return false
	sun -= 4
	gain_experience(4)
	message = "已购买4经验，当前%d级。" % level
	return true


## 按[param count]数量等概率、可重复地发放基础或成装；[param completed]决定使用已定义的哪组装备。
func grant_equipment(count: int, completed: bool) -> void:
	# 两组掉落候选不含机枪头盔，头盔仅由羁绊生成。
	var pool: Array[String] = Equipment.COMPLETED if completed else Equipment.BASIC
	# 每个掉落独立抽取，不在本次抽取后移出候选。
	for index: int in range(count):
		equipment_inventory.append(pool[_random.randi_range(0, pool.size() - 1)])


## 检查[param item]能否拖到[param unit_id]，只读取规则而不消耗装备或生成合成结果。
func can_equip_item(unit_id: int, item: String) -> bool:
	if not can_manage() or not Equipment.ITEMS.has(item):
		return false
	# 目标必须仍持有且不是睡莲或花盆，防止拖动期间死亡或合成导致装备落到旧标识上。
	var unit: Dictionary = find_unit(unit_id)
	if unit.is_empty() or is_support(int(unit.type)):
		return false
	if item == "helmet":
		return pea_bonus().tier > 0 and helmet_unit_id == -1 and CATALOG[unit.type].trait == "豌豆"
	return equipment_inventory.has(item) and unit.get("equipment", []).size() < Equipment.SLOT_LIMIT


## 将背包中的[param item]装备到[param unit_id]；满三格拒绝放入，小件只有与已有小件匹配已知配方时才自动合成。
func equip_item(unit_id: int, item: String) -> bool:
	if not can_manage() or not Equipment.ITEMS.has(item):
		return false
	# 所有绑定基于逻辑单位标识，不与星级或战斗实体的重建绑定。
	var unit: Dictionary = find_unit(unit_id)
	if unit.is_empty() or is_support(int(unit.type)):
		message = "请先选中普通植物；睡莲和花盆不能装备。"
		return false
	if item == "helmet":
		sync_helmet()
		if pea_bonus().tier == 0 or helmet_unit_id != -1 or CATALOG[unit.type].trait != "豌豆":
			return false
		helmet_unit_id = unit_id
		return true
	if not equipment_inventory.has(item):
		return false
	# 旧存档无装备字段时按空装备处理，不修改其他单位。
	var loadout: Array = unit.get("equipment", []).duplicate()
	if loadout.size() >= Equipment.SLOT_LIMIT:
		message = "该植物的三个装备槽已满。"
		return false
	# 各槽佩戴起点独立，不因另一格新装备或升星而重置旧装备叠层。
	var counters: Array = equipment_actions.get(unit_id, []).duplicate()
	while counters.size() < loadout.size():
		counters.append(0)
	# 依次寻找可合成的小件；不匹配时占用新的普通装备槽。
	for slot: int in range(loadout.size()):
		# 只使用文档已定义的配方，成装之间不再合成。
		var result: String = Equipment.recipe(str(loadout[slot]), item)
		if not result.is_empty():
			loadout[slot] = result
			counters[slot] = 0
			equipment_actions[unit_id] = counters
			unit["equipment"] = loadout
			equipment_inventory.erase(item)
			message = "已合成%s。" % Equipment.ITEMS[result].name
			return true
	loadout.append(item)
	counters.append(0)
	equipment_actions[unit_id] = counters
	unit["equipment"] = loadout
	equipment_inventory.erase(item)
	message = "已装备%s。" % Equipment.ITEMS[item].name
	return true


## 单位移除时只解除普通装备的绑定并保留玩家物品，不把装备合成或销毁；卖出植物不会卖掉装备。
func _release_equipment(unit: Dictionary) -> void:
	# 同种物品逐件保留，不能用集合去重。
	for item: String in unit.get("equipment", []):
		equipment_inventory.append(item)
	unit["equipment"] = []
	attack_actions.erase(int(unit.id))
	equipment_actions.erase(int(unit.id))
	if helmet_unit_id == int(unit.id):
		helmet_unit_id = -1


## 返回大纲豌豆羁绊当前档位、普通加成和大招概率，只使用场上不同种类。
func pea_bonus() -> Dictionary:
	# 其他阵营、备战席和同名多株不提高羁绊档位。
	var count: int = int(trait_counts().get("豌豆", 0))
	# 从最高档向下匹配，最多应用一档普通属性。
	for tier: int in range(3, -1, -1):
		if count >= [3, 5, 7, 10][tier]:
			return {"tier": tier + 1, "attack": [20.0, 40.0, 80.0, 150.0][tier], "speed": [0.15, 0.25, 0.45, 1.0][tier], "chance": [0.01, 0.02, 0.035, 0.08][tier]}
	return {"tier": 0, "attack": 0.0, "speed": 0.0, "chance": 0.0}


## 实时同步唯一羁绊头盔；失去羁绊或佩戴者不存在/不属豌豆时装备消失。
func sync_helmet() -> void:
	if pea_bonus().tier == 0:
		helmet_unit_id = -1
		return
	# 背包状态不需要自动分配，玩家自行选择任何豌豆单位佩戴。
	var unit: Dictionary = find_unit(helmet_unit_id)
	if not unit.is_empty() and CATALOG[unit.type].trait != "豌豆":
		helmet_unit_id = -1
	elif helmet_unit_id != -1 and unit.is_empty():
		helmet_unit_id = -1


## 设置当前遭遇关的[param selected]档位，准备阶段可选一至四，开战后不能更改。
func set_encounter_level(selected: int) -> void:
	if phase == Phase.PREPARATION and campaign.node_kind() == "遭遇关" and selected >= 1 and selected <= 4:
		encounter_level = selected
		node_wave_limit = selected


## 返回实际小波数：普通节点一波，遭遇关的难度一至四分别一至四波，不换算成旗帜。
func configured_wave_count() -> int:
	return encounter_level if campaign.node_kind() == "遭遇关" else 1


## 根据整局节点逐渐开放随机池：前两节点只有普通，第三加入路障和撑杆，第四起加入铁桶。
func configured_zombies() -> Array[CharacterRegistry.ZombieType]:
	# 新类型只加入池子，不保证每波固定出现。
	var types: Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]
	if campaign.node_index >= 2:
		types.append(CharacterRegistry.ZombieType.Z003Cone)
		types.append(CharacterRegistry.ZombieType.Z004PoleVaulter)
	if campaign.node_index >= 3:
		types.append(CharacterRegistry.ZombieType.Z005Bucket)
	return types


## 返回本节点实际难度，遭遇关分别在当前节点基础上增加3/6/9/20，不擅自改变后续节点基础成长。
func node_difficulty() -> int:
	return campaign.difficulty() + ([3, 6, 9, 20][encounter_level - 1] if campaign.node_kind() == "遭遇关" else 0)


## 返回仓库需要保存的植物快照，普通装备与独立头盔均保留，不保存节点内攻击叠层。
func warehouse_units() -> Array[Dictionary]:
	# 独立快照避免序列化时给本局单位混入仓库状态。
	var saved: Array[Dictionary] = units.duplicate(true)
	# 独立头盔不挤占三个普通装备槽。
	for unit: Dictionary in saved:
		unit["helmet"] = int(unit.id) == helmet_unit_id and pea_bonus().tier > 0
	return saved


## 返回背包装备快照，羁绊仍激活且头盔未佩戴时也保存这件独立装备。
func warehouse_equipment() -> Array[String]:
	# 不将虚拟羁绊物品直接追加到实际普通背包，避免重复生成。
	var saved: Array[String] = equipment_inventory.duplicate()
	if pea_bonus().tier > 0 and helmet_unit_id == -1:
		saved.append("helmet")
	return saved
