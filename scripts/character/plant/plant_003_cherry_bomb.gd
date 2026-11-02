extends Plant000Base
class_name Plant003CherryBomb

@onready var bomb_component: BombComponentBase = %BombComponent

## 正常爆炸的自毁帧改为模式回备战；真实被吃掉时血量为零，仍走原版阵亡与亡语。
func character_death():
	# 模式控制器同步保存持有状态，再延迟清除本次实体，避免在动画回调中直接释放。
	var callback: Callable = get_meta("currency_war_return_callback", Callable())
	if callback.is_valid() and bomb_component.is_bomb and hp_component.curr_hp > 0:
		callback.call()
		return
	super()

## 亡语
func death_language():
	bomb_component.judge_death_bomb()
