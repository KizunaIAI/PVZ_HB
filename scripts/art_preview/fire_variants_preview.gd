## 火球美术对照：原版、紫火和红火沿用同一动画，独立展示本体及命中火焰。
extends Node2D

## 原版及两个继承变体，供美术预览实例化，不连接正式关卡。
const CLIPS: Array[PackedScene] = [preload("res://scenes/bullet/bullet_006_pea_fire.tscn"), preload("res://scenes/currency_war/bullets/purple_fire.tscn"), preload("res://scenes/currency_war/bullets/red_fire.tscn")]


## 展示放大的三种本体与命中特效，不产生攻击、碰撞或玩家经济变动。
func _ready() -> void:
	# 三列依次对应原版橙火、紫火与红火。
	for index: int in range(CLIPS.size()):
		# 每列上半部分循环展示飞行火焰。
		var bullet: Bullet006PeaFire = CLIPS[index].instantiate()
		bullet.position = Vector2(220.0 + index * 310.0, 230.0)
		bullet.scale = Vector2.ONE * 3.0
		add_child(bullet)
		bullet.set_physics_process(false)
		bullet.set_process(false)
		bullet.bullet_shadow.hide()
		bullet.area_2d_attack.monitoring = false
		# 下半部分展示对应命中火焰，共用同一换色路径。
		var impact: Bullet006PeaFire = CLIPS[index].instantiate()
		impact.position = Vector2(220.0 + index * 310.0, 460.0)
		impact.scale = Vector2.ONE * 3.0
		add_child(impact)
		impact.set_physics_process(false)
		impact.set_process(false)
		impact.body.hide()
		impact.bullet_shadow.hide()
		impact.area_2d_attack.monitoring = false
		impact.bullet_effect.show()
		# 使用原版循环火焰，便于逐列比较，正式命中仍播放fire_done后释放。
		impact.bullet_effect.get_node("AnimationPlayer").play(&"fire_flame")
