## 磁力菇铁器弹：复用原版抛物线，仅命中投出时选定的敌人，不新增穿透或范围伤害。
extends Bullet000ParabolaBase


## 将实际吸来的[param iron]移交给本弹丸显示；保留铁桶、头盔、梯子等各自原版外观。
func attach_iron(iron: Node2D) -> void:
	iron.reparent(body)
	iron.position = Vector2.ZERO
	iron.show()


## 只有选定敌人的受击区域[param area]能够触发命中，避免跨行飞行途中打到其他僵尸。
func _on_area_2d_attack_area_entered(area: Area2D) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_death or target_enemy.is_hypno or area.owner != target_enemy:
		return
	super(area)
