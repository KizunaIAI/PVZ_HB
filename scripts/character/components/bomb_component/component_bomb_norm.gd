extends BombComponentBase
class_name BombComponentNorm
## 普通炸弹使用爆炸组件

@onready var bomb_effect: BombEffectBase = $BombEffect

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 炸死所有敌人[僵尸有两个受击组件检测框,会被检测两次]
func _bomb_all_enemy():
	# 货币战争毁灭菇使用全屏目标，其他植物与原版模式继续按碰撞范围结算。
	if owner.has_meta("currency_war_fullscreen_bomb"):
		owner.get_meta("currency_war_fullscreen_bomb").call()
		return
	## 被爆炸炸到的敌人
	var character_be_bomb :Array[Character000Base] = []
	# 原版爆炸范围内的受击区域，同一敌人的多个受击框在下方去重。
	var areas = area_2d_bomb.get_overlapping_areas()
	# 逐个区域取得实际角色，保留原版状态与行范围校验。
	for area in areas:
		# 受击区域的拥有者为植物、僵尸或梯子。
		var area_owner = area.owner
		if area_owner is Plant000Base:
			# 保留植物类型检测，实际伤害仍仅由下方僵尸分支执行。
			var plant:Plant000Base = area_owner as Plant000Base
			if plant.curr_be_attack_status & can_attack_plant_status:
				if not character_be_bomb.has(plant):
					if judge_lane(plant):
						character_be_bomb.append(plant)
		if area_owner is Zombie000Base:
			# 同一僵尸只加入一次，不能因两个受击框重复触发装备增伤。
			var zombie:Zombie000Base = area_owner as Zombie000Base
			if zombie.curr_be_attack_status & can_attack_zombie_status:
				if not character_be_bomb.has(zombie):
					if judge_lane(zombie):
						character_be_bomb.append(zombie)
		## 如果是梯子
		if area_owner is Ladder:
			if bomb_lane == -1 or (owner.lane + bomb_lane >= area_owner.lane and owner.lane - bomb_lane <= area_owner.lane ):
				area_owner.ladder_death()
	# 对去重后的敌人逐个计算模式装备增伤，原版没有元数据时保持原伤害。
	for c:Character000Base in character_be_bomb:
		if c is Zombie000Base:
			# 基础伤害已由模式按星级和固定装备计算，不在这里重复加基础属性。
			var damage: int = bomb_value
			if owner.has_meta("currency_war_execute"):
				# 总生命包含僵尸护甲，与同模式子弹的50%阈值一致。
				var maximum: int = c.hp_component.max_hp
				if c.hp_component is HpComponentZombie:
					maximum += c.hp_component.max_hp_armor1 + c.hp_component.max_hp_armor2
				if float(c.hp_component.get_all_hp()) < maximum * 0.5:
					damage = roundi(damage * (1.0 + float(owner.get_meta("currency_war_execute", 0.0))))
			c.be_bomb(damage, is_cherry_bomb)


func judge_lane(enemy:Character000Base) -> bool:
	return bomb_lane == -1 or (owner.lane + bomb_lane >= enemy.lane and owner.lane - bomb_lane <= enemy.lane )
