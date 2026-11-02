## 水盆沿用花盆的生命、占层、承托高度和动画，仅将承托地形改为水。
extends Plant000DownBase


## 初始化[param plant_init_para]并把实际放置格转换为水面；展示实例不修改战场。
func init_plant(plant_init_para: Dictionary) -> void:
	super(plant_init_para)
	if character_init_type == E_CharacterInitType.IsNorm:
		plant_cell.curr_condition = 8


## 复用原版花盆绘制，增加盆口水面，不修改原版贴图资源。
func ready_norm() -> void:
	super()
	set_meta("currency_war_water_pot", true)
	# 水面随花盆身体动画移动，不影响碰撞或植物承托位置。
	var water: Polygon2D = Polygon2D.new()
	water.color = Color("69bfd5")
	# 盆口椭圆顶点，单位为花盆身体局部像素。
	var outline: PackedVector2Array = []
	# 平滑椭圆使用24个顶点，避开原贴图盆沿。
	for index: int in range(24):
		outline.append(Vector2(40, 47) + Vector2(cos(TAU * index / 24.0) * 19.0, sin(TAU * index / 24.0) * 5.0))
	water.polygon = outline
	get_node("Body/BodyCorrect").add_child(water)


## 移除水盆时恢复原格地形，并沿用原版底座释放容器和死亡信号。
func character_death() -> void:
	# 原版花盆以4位识别已放置底座，先恢复该标记使其正常还原原地形。
	plant_cell.curr_condition = 4
	super()
