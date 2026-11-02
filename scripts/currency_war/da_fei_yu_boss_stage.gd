## 三个大肥鱼Boss关的集中配置，以及只在Boss存活在场时生效的敌军全局光环。
extends RefCounted

## 一至三大关的技能及光环配置；伤害倍率1.5/2分别表示伤害增加50%/100%。
const PROFILES: Array[Dictionary] = [
	{"reduction": 0.0, "damage": 1.0, "delay": 2.0, "speed": 1.0, "sun": Vector2i(4, 10), "summons": Vector2i(3, 5)},
	{"reduction": 0.5, "damage": 1.5, "delay": 1.2, "speed": 1.25, "sun": Vector2i(8, 15), "summons": Vector2i(5, 7)},
	{"reduction": 0.7, "damage": 2.0, "delay": 0.8, "speed": 1.5, "sun": Vector2i(12, 20), "summons": Vector2i(7, 10)},
]


## 返回[param stage]一基大关的独立配置，越界按最近合法档位处理。
static func profile(stage: int) -> Dictionary:
	return PROFILES[clampi(stage, 1, 3) - 1].duplicate()


## 返回仍存活在树中的当前关卡Boss；死亡、魅惑或换场景后立即视为没有光环。
static func _active_boss() -> Node:
	if not is_instance_valid(Global.main_game):
		return null
	# 仅保存弱引用，不延长Boss退场生命周期。
	var reference: WeakRef = Global.main_game.get_meta("da_fei_yu_stage_boss", null)
	# 当前Boss实例，不缓存全体僵尸的永久属性。
	var boss: Node = reference.get_ref() if reference != null else null
	if not is_instance_valid(boss) or not boss.is_inside_tree() or boss.is_death or boss.is_hypno:
		return null
	return boss


## 返回[param zombie]应承受的伤害倍率；敌军含Boss自身及后续召唤，魅惑友军不受敌军光环影响。
static func taken_multiplier(zombie: Character000Base) -> float:
	# 光环仅由当前Boss关实际在场的Boss提供，开发者普通召唤默认不带关卡光环。
	var boss: Node = _active_boss()
	if boss == null or not zombie is Zombie000Base or zombie.is_hypno:
		return 1.0
	return 1.0 - float(PROFILES[clampi(int(boss.get_meta("da_fei_yu_stage", 1)), 1, 3) - 1].reduction)


## 对[param source]敌军造成的[param damage]应用在场Boss增伤；无来源或魅惑友军保持原值。
static func outgoing_damage(source: Character000Base, damage: int) -> int:
	# 读取当次伤害结算时的Boss状态，Boss倒下后已发出的飞行物也不再享受光环。
	var boss: Node = _active_boss()
	if damage <= 0 or boss == null or not is_instance_valid(source) or not source is Zombie000Base or source.is_hypno:
		return damage
	return roundi(damage * float(PROFILES[clampi(int(boss.get_meta("da_fei_yu_stage", 1)), 1, 3) - 1].damage))
