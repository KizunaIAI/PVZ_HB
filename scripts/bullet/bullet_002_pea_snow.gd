extends BulletLinear000Base
class_name Bullet002PeaSnow

@export var time_be_decelerated :float = 3.0

## 命中[param enemy]后施加原版冰减速；模式子弹可携带星级剩余速度倍率，其他模式仍为0.5。
func attack_once(enemy:Character000Base):
	super(enemy)
	if enemy is Zombie000Base:
		if enemy.hp_component.curr_hp_armor2 <= 0:
			enemy.be_ice_decelerate(time_be_decelerated, float(get_meta("currency_war_slow_factor", 0.5)))


