## 原版普通植物的通用费用与升星模板；已有独有设定优先，之后可逐株覆盖而不改通用公式。
extends RefCounted

## 一至三星通用攻击、攻速增幅，不额外增加生命或改变原版功能。
const STAR_BONUS: Array[float] = [0.0, 0.5, 1.0]
## 通用费用的阳光上界，边界归较低档：50为一费、100二费、175三费、250四费，以上五费。
const SUN_LIMITS: Array[int] = [50, 100, 175, 250]


## 返回原版[param sun_cost]阳光价格对应的一至五费；负值视为0，不读取本局折扣。
static func tier_from_sun_cost(sun_cost: int) -> int:
	# 从低档依次比较，重叠边界稳定落在较低费用。
	for index: int in range(SUN_LIMITS.size()):
		if sun_cost <= SUN_LIMITS[index]:
			return index + 1
	return 5


## 根据原版注册表生成全部48种正常植物，再以[param overrides]覆盖已经写明的独有设定；不加入内部衍生体或小游戏道具。
static func build_catalog(overrides: Dictionary) -> Dictionary:
	# 使用本地原版图鉴的中文名称，不在界面暴露资源脚本名。
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/almanac_data.json"))
	# 缺少图鉴字段时仅回退原注册名，费用与星级模板不受影响。
	var names: Dictionary = parsed.get("Plant", {}) if parsed is Dictionary else {}
	# 独立字典避免覆盖原版注册信息或修改用户已经写明的常量。
	var catalog: Dictionary = {}
	# 前48个枚举是正常植物，49为内部反向双发，999以上需要独立选择或为小游戏道具。
	for plant_type: int in range(1, 49):
		# 直接读取原版基础阳光，不用旧模式单局1至5阳光价格反推。
		var info: Dictionary = CharacterRegistry.PlantInfo[plant_type]
		# 原注册名是图鉴索引，不作为新的玩法规则。
		var native_name: String = info[CharacterRegistry.PlantInfoAttribute.PlantName]
		# 通用模板仅规定费用与攻击/攻速，未定义植物的羁绊保持空白。
		catalog[plant_type] = {"name": names.get(native_name, {}).get("名字", native_name), "tier": tier_from_sun_cost(int(info[CharacterRegistry.PlantInfoAttribute.SunCost])), "trait": "", "tip": "通用模板：一星原版；二星攻击/攻速+50%；三星攻击/攻速+100%", "generic": true}
	# 费用、属性、产出和特殊弹优先遵守已有独有设定，睡莲花盆也保留直购例外。
	for plant_type: int in overrides:
		catalog[plant_type] = overrides[plant_type].duplicate(true)
		catalog[plant_type]["generic"] = false
	return catalog


## 读取[param plant]尚未入树的原版攻击资料；返回伤害和动作间隔，不给无攻击功能的植物新增攻击。
static func native_attack_profile(plant: Plant000Base) -> Dictionary:
	# 子弹组件的导出值可在入树前读取，不依赖onready字段。
	var attack: AttackComponentBulletBase = plant.get_node_or_null("AttackComponent") as AttackComponentBulletBase
	if attack != null:
		# 面板以实际普通弹型为基准，玉米投手使用玉米粒伤害。
		var base_type: int = BulletRegistry.BulletType.Bullet010Corn if attack is AttackComponentBulletCorn else attack.attack_bullet_type
		# 玉米投手动画会选玉米/黄油，面板不能沿用场景初始的卷心菜伤害。
		var bullet: Bullet000NormBase = Global.bullet_registry.get_bullet_scenes(base_type).instantiate() as Bullet000NormBase
		# 保存数值后释放实例，避免商店或面板查询泄漏节点。
		var profile: Dictionary = {"damage": bullet.attack_value, "interval": attack.attack_cd}
		bullet.free()
		return profile
	# 爆炸型包括寒冰菇，其冻结伤害原版为20，资源的bomb_value字段未被原版使用。
	var bomb: BombComponentBase = plant.get_node_or_null("BombComponent") as BombComponentBase
	if bomb != null:
		return {"damage": 20 if bomb is BombComponentIce else bomb.bomb_value, "interval": 0.0}
	if plant is Plant007Chomper:
		return {"damage": plant.eat_attack, "interval": plant.eat_CD}
	if plant is Plant022Caltrop or plant is Plant047SpikeRock:
		# 地刺一轮一次、地刺王一轮两次；从原版动画长度计算每次平均间隔，不新增计时器。
		var animation: Animation = preload("res://animation/character/plant/022_caltrop/Caltrop_attack.tres") if plant is Plant022Caltrop else preload("res://animation/character/plant/047_spike_rock/SpikeRock_attack.tres")
		return {"damage": plant.attack_value, "interval": animation.length / (2.0 if plant is Plant047SpikeRock else 1.0)}
	if plant is Plant018Squash:
		return {"damage": 1800, "interval": 0.0}
	if plant is Plant048CobCannon:
		# 加农炮的爆炸组件挂在子弹上，读取实际资源而非猜测固定伤害。
		var cannon: Bullet000Base = Global.bullet_registry.get_bullet_scenes(BulletRegistry.BulletType.Bullet016CobCannon).instantiate()
		# 子弹未入树，使用节点路径读取导出的爆炸数值。
		var damage: int = cannon.get_node("BombComponent").bomb_value
		cannon.free()
		return {"damage": damage, "interval": plant.charge_cd}
	return {"damage": 0, "interval": 0.0}


## 将[param damage]和[param rate]应用到[param plant]的原版特殊攻击；不改变控制、生产、种植或一次性消耗规则。
static func apply_special_attack(plant: Plant000Base, damage: int, rate: float) -> void:
	if plant is Plant007Chomper:
		plant.eat_attack = damage
	elif plant is Plant022Caltrop or plant is Plant047SpikeRock:
		plant.attack_value = damage
	elif plant is Plant048CobCannon and rate > 0.0:
		plant.charge_cd = 1.0 / rate
		plant.charge_cd_timer.wait_time = plant.charge_cd
		if not plant.charge_cd_timer.is_stopped() and plant.charge_cd_timer.time_left > plant.charge_cd:
			plant.charge_cd_timer.start(plant.charge_cd)
	# 大嘴花与地刺由原版动画/咀嚼驱动攻速，使用独立速度因子保留冰冻、随机速度等原有因子。
	if (plant is Plant007Chomper or plant is Plant022Caltrop or plant is Plant047SpikeRock) and rate > 0.0:
		# 原版间隔只缓存一次，避免每次装备同步重复乘星级倍率。
		var factor: float = rate * float(plant.get_meta("war_base_attack_cd", 1.0))
		if not is_equal_approx(float(plant.get_meta("war_special_speed", 1.0)), factor):
			plant.set_meta("war_special_speed", factor)
			plant.update_speed_factor(factor, Character000Base.E_Influence_Speed_Factor.CurrencyWarAttackSpeed)
