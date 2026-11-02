## 火炬树桩的模式变弹规则；只替换经过当前树桩的实例，保留来源、轨迹、装备和已乘过的增伤。
extends RefCounted

## 特殊豌豆脚本用来区分参与变弹的大豌豆和明确不参与的冰棱。
const SpecialPea = preload("res://scripts/currency_war/currency_war_pea_bullet.gd")


## 将[param plant]范围内的[param bullet]按[param star]升级；同一树桩每次穿越只处理一次，红球不再升级。
static func upgrade(bullet: Bullet000Base, plant: Plant023TorchWood, star: int) -> void:
	if not bullet is Bullet000NormBase or bullet.is_queued_for_deletion() or bullet.bullet_camp != CharacterRegistry.CharacterType.Plant:
		return
	if bullet in plant.curr_bullet_up:
		return
	# 冰棱不参与任何星级变弹，不能因为与原版冰球共用类型号而被误转换。
	if bullet is SpecialPea and bullet.freeze_seconds > 0.0:
		return
	if bullet.bullet_type == BulletRegistry.BulletType.Bullet002PeaSnow:
		_upgrade_snow(bullet, plant)
		return
	# 场景可自带紫/红美术阶段，模式升级元数据优先；普通豌豆为零级。
	var native_stage: int = bullet.fire_visual_stage if bullet is Bullet006PeaFire else 0
	# 本次变弹按已有实际阶段处理，不能把原生紫火再当成普通火球加倍。
	var stage: int = int(bullet.get_meta("currency_war_fire_stage", native_stage))
	if stage >= 3 or bullet.bullet_type not in [BulletRegistry.BulletType.Bullet001Pea, BulletRegistry.BulletType.Bullet006PeaFire]:
		return
	# 一星逐级升级，二星普通弹直接到紫球，三星全部升为红球。
	var next_stage: int = mini(3, maxi(stage + 1, clampi(star, 1, 3)))
	# 火球2倍、紫球4倍、红球8倍；只乘本次升级的比例，避免多株重复叠乘基础伤害。
	var factor: float = pow(2.0, next_stage - stage)
	# 复用原版火球动画及溅射，不额外生成美术资源。
	var upgraded: Bullet006PeaFire = Global.bullet_registry.get_bullet_scenes(BulletRegistry.BulletType.Bullet006PeaFire).instantiate() as Bullet006PeaFire
	upgraded.attack_value = roundi(bullet.attack_value * factor)
	upgraded.is_can_up = true
	# 大豌豆变弹后保留一格范围，后续火炬继续携带该记录，避免退化为普通单体火球。
	if bullet is SpecialPea and bullet.splash_radius != Vector2.ZERO:
		upgraded.set_meta("currency_war_large_fire_radius", bullet.splash_radius)
	elif bullet.has_meta("currency_war_large_fire_radius"):
		upgraded.set_meta("currency_war_large_fire_radius", bullet.get_meta("currency_war_large_fire_radius"))
	upgraded.set_meta("currency_war_fire_stage", next_stage)
	upgraded.set_meta("currency_war_execute", bullet.get_meta("currency_war_execute", 0.0))
	upgraded.init_bullet(bullet.get_bullet_paras())
	# 原版火球溅射基础对应40伤害，按本次最终伤害缩放共享资源的实例字段。
	var spatter: SpatterComponent = upgraded.get_node("SpatterComponent") as SpatterComponent
	spatter.sum_attack_value = roundi(spatter.sum_attack_value * upgraded.attack_value / 40.0)
	spatter.range_attack_value = Vector2i(roundi(spatter.range_attack_value.x * upgraded.attack_value / 40.0), roundi(spatter.range_attack_value.y * upgraded.attack_value / 40.0))
	# 本体与命中特效由火球脚本按已有阶段统一换色，避免橙色贴图乘色导致紫火发暗。
	if bullet.has_meta("currency_war_bounce_left"):
		upgraded.set_meta("currency_war_bounce_left", bullet.get_meta("currency_war_bounce_left"))
	plant.curr_bullet_up.append(upgraded)
	plant.bullets.call_deferred("add_child", upgraded)
	bullet.queue_free()


## 将[param bullet]原版寒冰球变为深蓝冰球，任意星级[param plant]只转换一次，保留来源及星级减速。
static func _upgrade_snow(bullet: Bullet000NormBase, plant: Plant023TorchWood) -> void:
	if bool(bullet.get_meta("currency_war_torch_snow", false)):
		return
	# 使用寒冰射手原版子弹脚本，既保留原减速，也避免引入冰棱的一秒冰冻。
	var upgraded: Bullet000NormBase = Global.bullet_registry.get_bullet_scenes(BulletRegistry.BulletType.Bullet002PeaSnow).instantiate() as Bullet000NormBase
	upgraded.attack_value = bullet.attack_value * 2
	upgraded.init_bullet(bullet.get_bullet_paras())
	upgraded.set_meta("currency_war_torch_snow", true)
	upgraded.set_meta("currency_war_slow_factor", bullet.get_meta("currency_war_slow_factor", 0.5))
	upgraded.set_meta("currency_war_execute", bullet.get_meta("currency_war_execute", 0.0))
	if bullet.has_meta("currency_war_bounce_left"):
		upgraded.set_meta("currency_war_bounce_left", bullet.get_meta("currency_war_bounce_left"))
	# 只调整本颗身体颜色，不修改原版寒冰纹理或其他植物的冰球。
	var body_node: Node2D = upgraded.get_node("Body") as Node2D
	body_node.modulate = Color(0.2, 0.4, 1.4)
	plant.curr_bullet_up.append(upgraded)
	plant.bullets.call_deferred("add_child", upgraded)
	bullet.queue_free()
