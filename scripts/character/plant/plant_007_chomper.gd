extends Plant000Base
class_name Plant007Chomper

@onready var detect_component: DetectComponent = $DetectComponent

## 咀嚼时间计时器
@onready var chew_timer: Timer = $ChewTimer
## 啃咬伤害
@export var eat_attack:int = 1800
## 咀嚼时间
@export var eat_CD :float = 5

@export_group("动画状态")
## 是否啃咬
@export var is_bite := false
## 是否咀嚼
@export var is_chewing = false


func ready_norm() -> void:
	super()
	## 咀嚼计时器
	chew_timer.wait_time = eat_CD

func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(owner_update_speed)
	detect_component.signal_can_attack.connect(change_is_attack.bind(true))

## 根据[param speed_product]更新咀嚼计时；模式按新旧倍率比保留进度，零倍率只暂停，其他关卡沿用原版。
func owner_update_speed(speed_product:float):
	if has_meta("currency_war_chomper_callback"):
		# 模式同步可能反复设置总倍率；剩余时间只按新旧倍率之比调整，避免重复除速。
		var previous: float = float(get_meta("currency_war_chomper_speed", 1.0))
		if speed_product <= 0.0:
			chew_timer.paused = true
			return
		chew_timer.paused = false
		if not chew_timer.is_stopped():
			chew_timer.start(maxf(0.001, chew_timer.time_left * previous / speed_product))
		set_meta("currency_war_chomper_speed", speed_product)
		chew_timer.wait_time = maxf(0.001, eat_CD / speed_product)
		return
	if not chew_timer.is_stopped():
		if speed_product == 0:
			chew_timer.paused = true
		else:
			chew_timer.paused = false
			chew_timer.start(chew_timer.time_left / speed_product)

	chew_timer.wait_time = eat_CD / speed_product

## 改变是否正在攻击,即攻击范围内是否有敌人
func change_is_attack(is_attack:bool):
	if is_attack:
		## 不在咀嚼状态,并且不在啃咬状态
		if not is_chewing and not is_bite:
			is_bite = true

## 咀嚼完成
func _on_chew_timer_timeout() -> void:
	is_chewing = false
#endregion

#region 动画轨道调用
## 吞咽动画结束
func swallow_end():
	if is_instance_valid(detect_component.enemy_can_be_attacked):
		is_bite = true

## 啃咬动画结束
func bite_end():
	is_bite = false
	## 如果没有啃咬到僵尸
	if not is_chewing:
		if is_instance_valid(detect_component.enemy_can_be_attacked):
			is_bite = true
#endregion

## 大嘴花吃一次僵尸,动画调用
func _eat_zombie():
	## 播放音效
	SoundManager.play_character_SFX(&"BigChomp")
	## 如果有僵尸
	if is_instance_valid(detect_component.enemy_can_be_attacked):
		# 模式在本次吞噬前先占用咀嚼状态，防止同一尸体又被死亡吸收回调重复统计。
		var callback: Callable = get_meta("currency_war_chomper_callback", Callable())
		if callback.is_valid():
			callback.call(detect_component.enemy_can_be_attacked)
			return
		currency_war_attack_action()
		# 当前实际啃咬目标，星级伤害由模式控制器写入eat_attack。
		var zombie :Zombie000Base = detect_component.enemy_can_be_attacked
		zombie.be_chomper_eat(eat_attack)
		chew_timer.start()

		is_chewing = true
