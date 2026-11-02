## 原版火球及紫、红变体；共用原版动画与命中特效，变体仅移动色相。
extends BulletLinear000Base
class_name Bullet006PeaFire

## 原版火焰动画播放器。
@onready var anim_lib: AnimationPlayer = $Body/AnimLib
## 原版范围溅射结算组件，换色不修改伤害。
@onready var spatter_component: SpatterComponent = $SpatterComponent

## 美术阶段：1原版橙火、2紫火、3红火；模式升级元数据优先于场景默认值。
@export_range(1, 3, 1) var fire_visual_stage: int = 1


## 播放原版火焰，并为本体和独立命中特效配置同色相材质。
func _ready() -> void:
	super()
	anim_lib.play(&"ALL_ANIMS")
	if has_meta("currency_war_large_fire_radius"):
		# 大豌豆原始宽度56对应普通28的两倍，变火后保留其大弹辨识度。
		body.scale *= 2.0
	# 只读取已有升级阶段，不改变原版子弹类型、伤害或升阶规则。
	var stage: int = int(get_meta("currency_war_fire_stage", fire_visual_stage))
	if stage >= 2:
		# 材质只属于本颗火球，本体和命中特效共享同一颜色配置。
		var flame_material: ShaderMaterial = ShaderMaterial.new()
		flame_material.shader = preload("res://shaders/my_shader/pea_fire_variant.gdshader")
		flame_material.set_shader_parameter("flame_hue", 0.77 if stage == 2 else 0.0)
		_apply_flame_material(body, flame_material)
		_apply_flame_material(bullet_effect.get_node("Body"), flame_material)

## 命中[param enemy]后沿用原版解冻与溅射；撞到屋顶斜面时目标为空，只销毁子弹。
func attack_once(enemy:Character000Base):
	super(enemy)
	if not is_instance_valid(enemy):
		return
	enemy.cancel_ice()
	if has_meta("currency_war_large_fire_radius") and enemy is Zombie000Base:
		# 大豌豆的整格范围与原版小范围火焰溅射二选一，避免中心或邻居叠算两种群伤。
		var radius: Vector2 = get_meta("currency_war_large_fire_radius")
		# 范围沿用被命中角色的受击中心，行列缩放与原大豌豆一致。
		var center: Vector2 = enemy.hurt_box_component.global_position
		# 伤害可能移除目标，用独立敌军快照且排除已经直接命中的中心一次。
		for target: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
			if not is_instance_valid(target) or target == enemy or target.is_death or target.is_hypno or not target.curr_be_attack_status & can_attack_zombie_status:
				continue
			if ((target.hurt_box_component.global_position - center) / radius).length_squared() <= 1.0:
				target.set_damage_source(source_character if is_instance_valid(source_character) else null)
				_attack_zombie(target)
				target.set_damage_source(null)
				target.cancel_ice()
		return
	spatter_component.spatter_all_area_zombie(enemy)


## 将[param flame_material]应用于[param root]的原火焰精灵；命中特效脱离子弹后仍保留自身材质。
func _apply_flame_material(root: Node2D, flame_material: ShaderMaterial) -> void:
	# 每张动画贴图单独持有材质引用，不依赖脱离后失效的父级继承。
	for item: Node in root.find_children("*", "Sprite2D", true, false):
		item.material = flame_material
		item.use_parent_material = false
