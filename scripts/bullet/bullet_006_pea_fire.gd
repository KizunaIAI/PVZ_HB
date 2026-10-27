extends BulletLinear000Base
class_name Bullet006PeaFire

@onready var anim_lib: AnimationPlayer = $Body/AnimLib
@onready var spatter_component: SpatterComponent = $SpatterComponent

func _ready() -> void:
	super()
	anim_lib.play(&"ALL_ANIMS")

## 命中[param enemy]后沿用原版解冻与溅射；撞到屋顶斜面时目标为空，只销毁子弹。
func attack_once(enemy:Character000Base):
	super(enemy)
	if not is_instance_valid(enemy):
		return
	enemy.cancel_ice()
	spatter_component.spatter_all_area_zombie(enemy)
