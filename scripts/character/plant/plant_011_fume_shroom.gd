extends Plant000Base
class_name Plant011FumeShroom

@onready var attack_component: AttackComponentBulletBase = $AttackComponent
@onready var bullet_fx: Node2D = %Bullet_FX
var all_bullet_fx :Array[GPUParticles2D]
## 货币战争二星以上的前方草坪终点，单位为世界坐标；NAN 表示沿用原版喷雾。
var _row_fume_end_x: float = NAN
## 每个喷口的原始材质，仅用于计算倍率，不修改共享资源。
var _row_fume_originals: Dictionary[GPUParticles2D, ParticleProcessMaterial] = {}
## 原始粒子数，按覆盖距离增加密度时避免重复累加。
var _row_fume_amounts: Dictionary[GPUParticles2D, int] = {}
## 原始裁剪矩形，恢复一星时不依赖引擎默认值。
var _row_fume_rects: Dictionary[GPUParticles2D, Rect2] = {}
## 为本株复制的喷雾材质，二星、三星和移动重算均复用同一份。
var _row_fume_materials: Dictionary[GPUParticles2D, ParticleProcessMaterial] = {}


## [param world_end_x]为前方一整行草坪的右边缘；非有限值恢复原版视觉。
## 仅配置本株的喷雾，不调整攻击范围、伤害、频率或其他植物的粒子资源。
func set_row_fume_end(world_end_x: float) -> void:
	_row_fume_end_x = world_end_x
	if not is_finite(world_end_x):
		# 升星或实体复用后回到一星时，还原原始材质和粒子数量。
		for particles: GPUParticles2D in _row_fume_originals:
			particles.process_material = _row_fume_originals[particles]
			particles.amount = _row_fume_amounts[particles]
			particles.visibility_rect = _row_fume_rects[particles]


## 在发射前按当前喷口位置重算距离，使放置、移动、缩放及不同草坪边界都能正确覆盖。
func _update_row_fume() -> void:
	if not is_finite(_row_fume_end_x):
		return
	# 每个粒子喷口独立复制材质；一星及非货币战争实例继续使用原材质。
	for particles: GPUParticles2D in all_bullet_fx:
		if not _row_fume_originals.has(particles):
			_row_fume_originals[particles] = particles.process_material as ParticleProcessMaterial
			_row_fume_amounts[particles] = particles.amount
			_row_fume_rects[particles] = particles.visibility_rect
			_row_fume_materials[particles] = particles.process_material.duplicate(true) as ParticleProcessMaterial
		# 所有倍率始终从原材质计算，连续射击不会累乘。
		var original: ParticleProcessMaterial = _row_fume_originals[particles]
		# 本株独有的粒子材质，包含独立的速度限制曲线。
		var material: ParticleProcessMaterial = _row_fume_materials[particles]
		# 粒子节点的横轴世界缩放，用于将草坪世界距离换算回粒子局部速度。
		var world_scale: float = maxf(0.01, particles.global_transform.x.length())
		# 喷口到前方草坪右边缘的实际长度，不延伸到植物背后。
		var distance: float = maxf(1.0, _row_fume_end_x - particles.global_position.x)
		# 原版最大速度乘寿命给出基准行进距离，短于原版时也按剩余草坪长度缩短。
		var ratio: float = distance / maxf(1.0, original.initial_velocity_max * particles.lifetime * world_scale)
		material.initial_velocity_min = original.initial_velocity_min * ratio
		material.initial_velocity_max = original.initial_velocity_max * ratio
		material.radial_velocity_min = original.radial_velocity_min * ratio
		material.radial_velocity_max = original.radial_velocity_max * ratio
		# 横向速度增加后保持相近的纵向散布，不让长喷雾越到相邻行。
		material.spread = original.spread / maxf(1.0, ratio)
		# 原材质有最高速度曲线，必须同步放大，否则粒子依然被原来的500像素/秒截断。
		var source_texture: CurveTexture = original.velocity_limit_curve as CurveTexture
		# duplicate(true) 已复制子曲线，只修改当前植物的这一份。
		var target_texture: CurveTexture = material.velocity_limit_curve as CurveTexture
		if source_texture != null and target_texture != null and source_texture.curve != null:
			target_texture.curve.max_value = source_texture.curve.max_value * ratio
			# 保留曲线横轴及形状，只将纵轴速度和切线按同一比例缩放。
			for point_index: int in range(source_texture.curve.point_count):
				target_texture.curve.set_point_value(point_index, source_texture.curve.get_point_position(point_index).y * ratio)
				target_texture.curve.set_point_left_tangent(point_index, source_texture.curve.get_point_left_tangent(point_index) * ratio)
				target_texture.curve.set_point_right_tangent(point_index, source_texture.curve.get_point_right_tangent(point_index) * ratio)
		particles.process_material = material
		particles.amount = clampi(roundi(_row_fume_amounts[particles] * maxf(1.0, ratio)), _row_fume_amounts[particles], 180)
		# GPU 粒子靠静态矩形裁剪，扩大后半行的烟雾也必须处于可见区域。
		particles.visibility_rect = Rect2(-80, -70, distance / world_scale + 160.0, 140)

func ready_norm():
	super()
	for p in bullet_fx.get_children():
		all_bullet_fx.append(p)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)


func _start_shoot():
	_update_row_fume()
	for gpu_particles_2d in all_bullet_fx:
		gpu_particles_2d.emitting = true

func _end_shoot():
	#print("结束")
	for gpu_particles_2d in all_bullet_fx:
		gpu_particles_2d.emitting = false

