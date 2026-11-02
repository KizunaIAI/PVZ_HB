extends BombComponentBase
class_name BombComponentJalapeno

var owner_plant:Plant000Base

func _ready() -> void:
	owner_plant = owner as Plant000Base

## 爆炸特效\冰道\梯子
func _start_bomb_fx():
	# 模式按星级创建本行、十字或全屏持续火焰，不重复生成旧本行特效。
	if owner_plant.has_meta("currency_war_jalapeno_callback"):
		return
	EventBus.push_event("jalapeno_bomb_effect", [owner_plant.row_col.x])

## 炸死所有敌人
func _bomb_all_enemy():
	# 模式回调接管目标和持续伤害，其他关卡仍发送原版事件。
	if owner_plant.has_meta("currency_war_jalapeno_callback"):
		owner_plant.get_meta("currency_war_jalapeno_callback").call()
		return
	EventBus.push_event("jalapeno_bomb_lane_zombie", [owner_plant.row_col.x, bomb_value])
	## 销毁当前行道具[冰道和梯子]
	EventBus.push_event("jalapeno_bomb_item_lane", [owner_plant.row_col.x])

