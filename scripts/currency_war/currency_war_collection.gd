## 主菜单仓库：仅在整局结束时保存全部仍持有植物，为后续冒险模式保留类型和星级。
class_name CurrencyWarCollection
extends RefCounted

## 每个用户使用独立文件，不混入原版金币、花园或关卡进度。
const FILE_NAME: String = "currency_war_collection.json"


## 返回当前用户仓库路径；未选择原版用户时返回空字符串，避免把不同用户植物混存。
static func _path() -> String:
	if Global.user_manager.curr_user_name.is_empty():
		return ""
	return "user://%s/%s" % [Global.user_manager.curr_user_name, FILE_NAME]


## 读取当前用户仓库，文件不存在返回空库；格式损坏返回读取失败而不覆盖原文件。
static func load_collection() -> Dictionary:
	# 用户路径为空时仍可查看空库，但不能保存到匿名位置。
	var path: String = _path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"plants": [], "equipment": [], "saved_runs": [], "ok": true}
	# 只读取原文件，任何解析失败都不会触发写回。
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"plants": [], "equipment": [], "saved_runs": [], "ok": false}
	# JSON解析结果需检查容器类型，避免错误存档被静默清空。
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.get("plants") is Array or not data.get("saved_runs") is Array:
		return {"plants": [], "equipment": [], "saved_runs": [], "ok": false}
	# 兼容此前只保存植物的旧库文件，不更换文件名、不清空原有植物。
	data["equipment"] = data.get("equipment", [])
	if not data.equipment is Array:
		return {"plants": [], "equipment": [], "saved_runs": [], "ok": false}
	data["ok"] = true
	return data


## 按[param run_key]保存[param units]植物及已佩戴装备、[param equipment]背包；同局不重复入库，写入失败不标记成功。
static func store_run(run_key: String, units: Array[Dictionary], equipment: Array[String] = []) -> Error:
	# 未选用户时让调用者显示可重试结果，不伪装成已保存。
	var path: String = _path()
	if path.is_empty():
		return ERR_UNCONFIGURED
	# 已保存批次独立于植物数量，即使整局没有幸存植物也能保证幂等。
	var data: Dictionary = load_collection()
	if not data.ok:
		return ERR_FILE_CORRUPT
	if data.saved_runs.has(run_key):
		return OK
	# 保留每株植物，不增加自动升星、数量上限、出售或取用等未定义规则。
	for unit: Dictionary in units:
		data.plants.append({"type": int(unit.type), "star": int(unit.star), "equipment": unit.get("equipment", []).duplicate(), "helmet": bool(unit.get("helmet", false))})
	# 背包逐件追加，允许保存同种装备多件，不做自动合成或去重。
	for item: String in equipment:
		data.equipment.append(item)
	data.saved_runs.append(run_key)
	data.erase("ok")
	# 用户目录由原版用户服务创建；缺失时按当前用户路径补齐，不修改其他用户。
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return directory_error
	# 先写临时文件，写入或关闭失败时不覆盖已有仓库。
	var temporary_path: String = path + ".tmp"
	# 临时文件只保存数据，不引用运行时植物节点或草坪坐标。
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	# 写入结果须在关闭前读取，失败时留下原库供用户重试。
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary_path, path)
