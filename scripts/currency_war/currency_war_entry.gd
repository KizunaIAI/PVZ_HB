## 货币战争整局入口：只创建一次规则，并跳转到随机确定的第一大关真实场景。
extends Node

## 显式加载整局会话，主菜单与F6运行使用同一入口。
const Session = preload("res://scripts/currency_war/currency_war_session.gd")


## 开始新整局后延迟切换场景，避免在入口节点进入树期间移除场景。
func _ready() -> void:
	Session.start_new()
	get_tree().call_deferred("change_scene_to_file", Session.get_run().campaign.scene_path())
