## 植物血量组件
extends HpComponent
class_name HpComponentPlant

## 强制移除、压扁和铲除不经过防御计算，避免逻辑删除后的实体仍然存活。
var _forcing_death: bool = false


## 对[param attack_value]应用模式防御后沿用原版扣血；[param _bullet_mode]、[param is_drop_on_death]、[param trigger_be_attack_SFX]、[param is_drop_2]保留原义，返回是否零生命。
func Hp_loss(attack_value: int, _bullet_mode: BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm, is_drop_on_death = true, trigger_be_attack_SFX := true, is_drop_2 := true):
	if not _forcing_death and owner.has_meta("currency_war_defense"):
		# 按用户授权采用每满10防御减1伤害，再应用相加后的百分比免伤。
		var flat_reduction: int = floori(float(owner.get_meta("currency_war_defense", 0.0)) / 10.0)
		# 免伤不能超过100%变成治疗，无模式元数据的植物保持原版计算。
		var reduction: float = clampf(float(owner.get_meta("currency_war_reduction", 0.0)), 0.0, 1.0)
		attack_value = maxi(0, roundi(maxi(0, attack_value - flat_reduction) * (1.0 - reduction)))
	return super.Hp_loss(attack_value, _bullet_mode, is_drop_on_death, trigger_be_attack_SFX, is_drop_2)


## 强制扣除全部生命并按[param is_drop]保留原版掉落规则，忽略装备防御与免伤。
func Hp_loss_death(is_drop := true):
	_forcing_death = true
	Hp_loss(get_all_hp(), BulletRegistry.AttackMode.Norm, is_drop, false)
	_forcing_death = false
