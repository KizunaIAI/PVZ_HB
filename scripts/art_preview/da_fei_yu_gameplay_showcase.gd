## 真实开发者场景的可视化展示驱动：用既有放置接口摆放大肥鱼和豌豆射手，不运行断言。
extends Node


## 等待场景及开发面板就绪后安排演示；不改存档，不领取通关奖励。
func _ready() -> void:
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	# 当前前院实例使用原有组件、行管理器及开发者面板。
	var game = Global.main_game
	if not is_instance_valid(game) or not is_instance_valid(game._developer):
		return
	# 自由放置接口与用户在面板点击相同，Boss 不依赖专用刷怪器。
	var developer = game._developer
	developer._place("zombie", CharacterRegistry.ZombieType.Z1002DaFeiYu, 1, game.plant_cell_manager.all_plant_cells[2][7])
	developer._place("plant", CharacterRegistry.PlantType.P001PeaShooterSingle, 1, game.plant_cell_manager.all_plant_cells[2][2])
	developer._set_open(false)
