## 大肥鱼开发者场景的快捷入口；F6 打开现有自由召唤面板，不推进正式整局。
extends Node

## 独立开发者会话，进入前保留正常货币战争整局。
const Session = preload("res://scripts/currency_war/currency_war_session.gd")
## 录像展示驱动只在显式命令行参数下创建，普通 F6 不自动放置实体。
const SHOWCASE = preload("res://scripts/art_preview/da_fei_yu_gameplay_showcase.gd")


## 启动现有开发者模式；可通过 --showcase-da-fei-yu 展示实际召唤及植物攻击。
func _ready() -> void:
	Session.start_developer()
	if OS.get_cmdline_user_args().has("--showcase-da-fei-yu"):
		# 驱动位于树根，切换到真实前院场景后仍可安排演示动作。
		var driver: Node = SHOWCASE.new()
		get_tree().root.add_child.call_deferred(driver)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/currency_war/currency_war_front.tscn")
