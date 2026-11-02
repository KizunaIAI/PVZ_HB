extends BombEffectBase
class_name BombEffectFire

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var exist_time := 1.0

func set_exist_time(new_exist_time:float = 1.0):
	self.exist_time = new_exist_time

func activate_bomb_effect():
	super()
	animation_player.play("fire_flame")
	# 模式持续火焰与伤害共享精确时长并跟随暂停，普通关卡保留原版随机尾差。
	var mode_fire: bool = bool(get_meta("currency_war_duration", false))
	await get_tree().create_timer(exist_time if mode_fire else exist_time + randf() / 5, not mode_fire).timeout
	animation_player.play("fire_done")

func _fire_end():
	queue_free()
