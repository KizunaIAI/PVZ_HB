extends BombComponentBase
class_name BombComponentIce

@onready var bomb_effect: BombEffectBase = $BombEffect

@export var time_ice:float = 3
@export var time_decelerate: float = 5

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 爆炸冰冻所有敌人
func _bomb_all_enemy():
	# 只有货币战争传入星级后的伤害，原版事件继续使用默认20点。
	if owner.has_meta("currency_war_attack_value"):
		EventBus.push_event("ice_all_zombie", [time_ice, time_decelerate, bomb_value])
	else:
		EventBus.push_event("ice_all_zombie", [time_ice, time_decelerate])
