## 用真实开发者放置接口展示一至三星大喷菇的喷雾距离，F6即可观察，不运行断言或保存战斗结果。
extends Node

## 演示使用独立开发者会话，不覆盖正常整局。
const Session = preload("res://scripts/currency_war/currency_war_session.gd")


## 入口切换到真实前院，独立树根驱动等待切换后安排三行对照。
func _ready() -> void:
	if name != &"FumeRowDriver":
		Session.start_developer()
		# 驱动必须在场景切换后保留，且不依赖编辑器插件。
		var driver: Node = get_script().new()
		driver.name = &"FumeRowDriver"
		get_tree().root.add_child.call_deferred(driver)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/currency_war/currency_war_front.tscn")
		return
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	# 真实场景与开发者工具均完成初始化后才放置。
	var game = Global.main_game
	if not is_instance_valid(game) or not is_instance_valid(game._developer):
		return
	# 使用现有界面接口，与手动选择星级及点击格子相同。
	var developer = game._developer
	developer._zombie_health.value = 50000
	# 从上到下依次展示一星、二星、三星。
	for row: int in range(3):
		developer._place("plant", 11, row + 1, game.plant_cell_manager.all_plant_cells[row][0])
		developer._place("zombie", 1, 1, game.plant_cell_manager.all_plant_cells[row][3 if row == 0 else 8])
	developer._set_open(false)
