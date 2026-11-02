## 植物血量组件
extends HpComponent
class_name HpComponentPlant

## 强制移除、压扁和铲除不经过防御计算，避免逻辑删除后的实体仍然存活。
var _forcing_death: bool = false


## 对[param attack_value]应用模式防御后沿用原版扣血；[param _bullet_mode]、[param is_drop_on_death]、[param trigger_be_attack_SFX]、[param is_drop_2]保留原义，返回是否零生命。
func Hp_loss(attack_value: int, _bullet_mode: BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm, is_drop_on_death = true, trigger_be_attack_SFX := true, is_drop_2 := true):
	# 来源只在当前命中期间有效，固定保存后再转伤或触发死亡，避免后续清理丢失反伤来源。
	var source: Character000Base = owner.get_meta("currency_war_current_damage_source", null)
	if not _forcing_death:
		# 敌军啃食、抛射及Boss钢盆统一在防护转伤之前增伤，避免转移后重复乘倍率。
		attack_value = preload("res://scripts/currency_war/da_fei_yu_boss_stage.gd").outgoing_damage(source, attack_value)
	# 反伤按本次攻击原值计算，受保护者的转伤和防御不重复缩放尖刺状态。
	var reflected: int = roundi(attack_value * float(source.get_meta("currency_war_spike_ratio", 0.0))) if not _forcing_death and attack_value > 0 and is_instance_valid(source) and source is Zombie000Base else 0
	if not _forcing_death and attack_value > 0 and owner.has_meta("currency_war_guard_damage"):
		# 转移在受保护植物自己的减伤前完成，只由最终承伤高坚果应用防御与单次上限。
		var route: Callable = owner.get_meta("currency_war_guard_damage")
		if route.is_valid() and route.call(attack_value, _bullet_mode, is_drop_on_death, trigger_be_attack_SFX, is_drop_2):
			_reflect_spikes(source, reflected)
			return curr_hp == 0
	if not _forcing_death and owner.has_meta("currency_war_defense"):
		# 按用户授权采用每满10防御减1伤害，再应用相加后的百分比免伤。
		var flat_reduction: int = floori(float(owner.get_meta("currency_war_defense", 0.0)) / 10.0)
		# 免伤不能超过100%变成治疗，无模式元数据的植物保持原版计算。
		var reduction: float = clampf(float(owner.get_meta("currency_war_reduction", 0.0)), 0.0, 1.0)
		attack_value = maxi(0, roundi(maxi(0, attack_value - flat_reduction) * (1.0 - reduction)))
	if not _forcing_death and owner.has_meta("currency_war_damage_cap"):
		attack_value = mini(attack_value, int(owner.get_meta("currency_war_damage_cap")))
	# 承伤与反伤分别结算，致死一口仍能对存活攻击者反伤。
	var died: bool = super.Hp_loss(attack_value, _bullet_mode, is_drop_on_death, trigger_be_attack_SFX, is_drop_2)
	_reflect_spikes(source, reflected)
	return died


## 向[param source]结算一次[param damage]尖刺反伤；强制移除、无来源和已死亡攻击者不触发。
func _reflect_spikes(source: Character000Base, damage: int) -> void:
	if damage > 0 and is_instance_valid(source) and source is Zombie000Base and not source.is_death:
		source.hp_component.Hp_loss(damage, BulletRegistry.AttackMode.Norm, true, false)


## 强制扣除全部生命并按[param is_drop]保留原版掉落规则，忽略装备防御与免伤。
func Hp_loss_death(is_drop := true):
	_forcing_death = true
	Hp_loss(get_all_hp(), BulletRegistry.AttackMode.Norm, is_drop, false)
	_forcing_death = false
