extends Plant000Base
class_name Plant037Garlic

@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

func ready_norm_signal_connect():
	super()
	## 连接信号
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

## 被[param attack_zombie]啃食时保留原版换行，并通知货币战争独立叠加中毒；其他模式无回调。
func _be_zombie_eat_once_special(attack_zombie:Zombie000Base):
	attack_zombie.update_lane_on_eat_garlic()
	# 模式控制器持有毒层生命周期，避免大蒜被吃掉时毒层一同消失。
	var callback: Callable = get_meta("currency_war_garlic_callback", Callable())
	if callback.is_valid():
		callback.call(attack_zombie)
