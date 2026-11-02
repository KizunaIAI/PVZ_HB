## 大肥鱼奖励的独立解锁记录与卡面，不将伙伴加入原版随机罐子或未解锁商店。
extends RefCounted

## 植物伙伴的种类编号，避免从Boss场景反向加载植物注册表。
const TYPE: int = 51
## 卡面仅包含原待机图，朝右镜像，不挂载战斗脚本。
const CARD: PackedScene = preload("res://scenes/currency_war/da_fei_yu_plant_card.tscn")
## 缓存纯显示卡片，挂在原AllCards自动加载下统一释放。
static var _card: Card


## 返回当前用户解锁文件；匿名预览不写存档。
static func _path() -> String:
	return "" if Global.user_manager.curr_user_name.is_empty() else "user://%s/da_fei_yu_unlock.cfg" % Global.user_manager.curr_user_name


## 返回当前用户是否曾真实击败Boss，供后续整局商店解锁伙伴卡。
static func is_unlocked() -> bool:
	# 每个用户单独读取，不在切换用户后复用旧解锁结果。
	var config: ConfigFile = ConfigFile.new()
	return not _path().is_empty() and config.load(_path()) == OK and bool(config.get_value("reward", "unlocked", false))


## 保存本用户永久解锁，返回写入结果，失败不影响本局已经发放的卡片。
static func unlock() -> Error:
	if _path().is_empty():
		return ERR_UNCONFIGURED
	# 只写本功能独立文件，不改原版关卡、金币或已有仓库。
	var config: ConfigFile = ConfigFile.new()
	config.set_value("reward", "unlocked", true)
	return config.save(_path())


## 返回[param type]卡片模板，普通植物沿用原表；伙伴卡只供本模式UI，不加入原版选卡列表。
static func card(type: int) -> Card:
	if type != TYPE:
		return AllCards.all_plant_card_prefabs.get(34 if type == 50 else type)
	if not is_instance_valid(_card):
		_card = CARD.instantiate()
		AllCards.add_child(_card)
	return _card
