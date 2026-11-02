extends Plant000Base
class_name Plant021Jalapeno

@onready var bomb_component: BombComponentBase = %BombComponent

## 模式爆炸动画完成时回备战；真实零生命仍沿用原版阵亡。
func character_death() -> void:
	# 回调由模式控制器绑定，其他关卡为空。
	var callback: Callable = get_meta("currency_war_return_callback", Callable())
	if callback.is_valid() and bomb_component.is_bomb and hp_component.curr_hp > 0:
		callback.call()
		return
	super()


## 亡语
func death_language():
	bomb_component.judge_death_bomb()
