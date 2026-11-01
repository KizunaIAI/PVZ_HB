extends Resource
class_name ResourcePlantCondition

@export_group("植物种植")
@export_flags("1 无", "2 草地", "4 花盆", "8 水", "16 睡莲", "32 屋顶/裸地")
## 植物种植地形条件（满足一个即可），默认（草地2+花盆4+睡莲16 = 22）
var plant_condition:int = 22

## 植物在格子中占的位置，
@export var place_plant_in_cell :CharacterRegistry.PlacePlantInCell = CharacterRegistry.PlacePlantInCell.Norm

## 是否为特殊植物，非特殊植物满足上面两点（地形条件、格子位置）种植即可,
## 特殊植物调用重写方法判断是否可以种植judge_special_plants_condition
@export var is_special_plants := false
## 是否为紫卡  紫卡非特殊植物, 特殊植物只走特殊植物判定方法,特殊紫卡(玉米炮)走特殊植物判定方法
@export var is_purple_card := false
### 是否为双格植物,用于南瓜壳判断是否可以种植
#@export var is_double_plant_cell:=false


## 判断是否可以种植
func judge_is_can_plant(plant_cell:PlantCell, curr_plant_type:CharacterRegistry.PlantType) -> bool:
	if uses_currency_war_direct_placement():
		return judge_currency_war_direct(plant_cell, curr_plant_type)
	## 特殊植物
	if is_special_plants:
		return judge_special_plants_condition(plant_cell)
	## 普通植物非紫卡
	elif not is_purple_card:
		## 当前可以种植普通植物 and 当前格子地形符合 and 当前格子对应的植物位置为空
		if plant_cell.can_common_plant and plant_condition & plant_cell.curr_condition and not is_instance_valid(plant_cell.plant_in_cell[place_plant_in_cell]):
			## 如果是壳类植物,若当前植物格子中Norm为玉米加农炮
			if place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Shell \
			and is_instance_valid(plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm])\
			and plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm].plant_type == CharacterRegistry.PlantType.P048CobCannon:
				return false

			return true
		else:
			return false
	else:
		if get_preplant_purple(plant_cell, curr_plant_type) != null:
			return true
		else:
			return false


## 返回是否为货币战争可直接放置的升级植物，其他模式保持原版前置升级。
func uses_currency_war_direct_placement() -> bool:
	return is_purple_card and Global.game_para != null and Global.game_para.game_mode == MainSceneRegistry.MainScenes.CurrencyWar


## 校验[param plant_cell]直接放[param curr_plant_type]的地形与占格；猫尾草只在水路，玉米炮保留两格且两格均须合法。
## [param allow_occupied]仅供准备交换预校验，实际创建保持false；[param ignored_plant]允许双格植物平移时重叠自己的旧位置。
func judge_currency_war_direct(plant_cell: PlantCell, curr_plant_type: int, allow_occupied: bool = false, ignored_plant: Plant000Base = null) -> bool:
	# 普通升级植物占一格，玉米炮额外占右侧一格，不能从最右列越界。
	var cells: Array[PlantCell] = [plant_cell]
	if curr_plant_type == CharacterRegistry.PlantType.P048CobCannon:
		if plant_cell.row_col.y >= Global.main_game.plant_cell_manager.row_col.y - 1:
			return false
		cells.append(Global.main_game.plant_cell_manager.all_plant_cells[plant_cell.row_col.x][plant_cell.row_col.y + 1])
	# 每个实际占用格都检查；死去实体的指针允许交给原版清理流程释放。
	for cell: PlantCell in cells:
		if not cell.can_common_plant:
			return false
		if curr_plant_type == CharacterRegistry.PlantType.P044Cattail:
			if not cell.ori_condition & 8:
				return false
		elif curr_plant_type == CharacterRegistry.PlantType.P047SpikeRock and not cell.curr_condition & 2:
			# 地刺王保留地刺仅草地的地形限制，不能因紫卡共用资源而放到花盆或睡莲上。
			return false
		elif not plant_condition & cell.curr_condition:
			return false
		# 此接口只用于普通升级植物层，不消耗已拥有的睡莲或其他前置植物。
		var occupant: Plant000Base = cell.plant_in_cell[place_plant_in_cell]
		if is_instance_valid(occupant) and not occupant.is_death and occupant != ignored_plant and not allow_occupied:
			return false
		if curr_plant_type == CharacterRegistry.PlantType.P048CobCannon:
			# 原版玉米炮不能与南瓜壳共格。
			var shell: Plant000Base = cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Shell]
			if is_instance_valid(shell) and not shell.is_death:
				return false
	return true


## 判断当前场上是否有紫卡预种植植物,紫卡是否可以种植
func judge_purple_card_can_plant(all_plant_cells, curr_plant_type:CharacterRegistry.PlantType)->bool:
	for plant_cells_row in all_plant_cells:
		for plant_cell in plant_cells_row:
			if get_preplant_purple(plant_cell, curr_plant_type) != null:
				return true
	return false

## 获取当前格子紫卡预种植植物
## 返回预种植植物,若当前植物格子可以种植紫卡,返回预种植紫卡,
func get_preplant_purple(plant_cell:PlantCell, curr_plant_type:CharacterRegistry.PlantType) ->Plant000Base:
	## 紫卡前置植物
	var precondition_plant:CharacterRegistry.PlantType = Global.character_registry.AllPrePlantPurple[curr_plant_type]
	## 当前格子存在前置种植植物
	var condition_precondition_plant :ResourcePlantCondition = Global.character_registry.get_plant_info(precondition_plant, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var place_precondition_plant:CharacterRegistry.PlacePlantInCell = condition_precondition_plant.place_plant_in_cell
	if is_instance_valid(plant_cell.plant_in_cell[place_precondition_plant]) and\
	plant_cell.plant_in_cell[place_precondition_plant].plant_type == precondition_plant:
		## 如果种植位置不相同,并且当前植物格子已有紫卡植物位置的植物
		if place_precondition_plant != place_plant_in_cell and is_instance_valid(plant_cell.plant_in_cell[place_plant_in_cell]):
			return null
		else:
			return plant_cell.plant_in_cell[place_precondition_plant]
	else:
		return null


## 获取当前场上所有的紫卡植物的对应预种植植物
func get_all_preplant_purple(all_plant_cells, curr_plant_type:CharacterRegistry.PlantType):
	var all_preplant_purple:Array[Plant000Base]
	for plant_cells_row in all_plant_cells:
		for plant_cell in plant_cells_row:
			var preplant_purple:Plant000Base = get_preplant_purple(plant_cell, curr_plant_type)
			if preplant_purple != null:
				all_preplant_purple.append(preplant_purple)

	return all_preplant_purple

## 一般特殊植物(不能有同一位置植物)种植函数判断是否可以种植
func judge_special_plants_condition(plant_cell:PlantCell) -> bool:
	if is_instance_valid(plant_cell.plant_in_cell[place_plant_in_cell]):
		return false
	else:
		return _judge_special_plants_condition(plant_cell)

## 特殊植物种植函数判断是否可以种植，特殊植物重写,如墓碑吞噬者，咖啡豆等
func _judge_special_plants_condition(_plant_cell) -> bool:
	return true
