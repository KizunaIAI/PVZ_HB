## 大纲3.1的整局进度：三大关各五节点，跨节点共享植物与阳光，第四次吃脑才结束。
class_name CurrencyWarCampaign
extends RefCounted

## 整局节点数，三大关各五小关。
const NODE_COUNT: int = 15
## 每个大关包含的节点数量。
const NODES_PER_STAGE: int = 5
## 前三次吃脑仍能继续，第四次终止本局。
const FINAL_BRAIN_LOSS: int = 4
## 用户授权复用的六种场景；屋顶黑夜复用屋顶资源并单独使用夜色显示。
const THEMES: Array[Dictionary] = [
	{"name": "后院", "scene": "front", "level": "adventure_01_day", "night": false},
	{"name": "后院黑夜", "scene": "front", "level": "adventure_02_night", "night": true},
	{"name": "泳池", "scene": "back", "level": "adventure_03_pool", "night": false},
	{"name": "泳池黑夜", "scene": "back", "level": "adventure_04_fog", "night": true},
	{"name": "屋顶", "scene": "roof", "level": "adventure_05_Roof", "night": false},
	{"name": "屋顶黑夜", "scene": "roof", "level": "adventure_05_Roof", "night": true},
]
## 当前节点，从零开始，15表示全部节点已完成。
var node_index: int = 0
## 整局吃脑次数，不随大关或小关重置。
var brain_losses: int = 0
## 连续获胜节点数，失败时清零。
var win_streak: int = 0
## 上一个节点是否获胜，用于结算展示。
var last_won: bool = false
## 三大关分别使用的场景索引，同一大关五个节点使用相同场景。
var stage_themes: Array[int] = []
## 整局植物存档批次，重复点击结算不会生成重复永久植物。
var run_key: String = ""
## 独立场景随机源，不改变原版出怪随机状态。
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


## 开始整局时固定第一大关为普通草坪后院，第二、三大关随机并排除紧邻的上一大关。
func _init() -> void:
	_random.randomize()
	run_key = "%d_%d" % [Time.get_unix_time_from_system(), _random.randi()]
	# 每个大关只选一次，节点切换不能再次随机导致同一大关换图。
	for stage: int in range(3):
		if stage == 0:
			stage_themes.append(0)
			continue
		# 后续大关保留原有六种候选，但排除紧邻的上一大关以保证换场景。
		var candidates: Array[int] = []
		# 遍历场景索引以保留文档授权的完整候选集。
		for theme_index: int in range(THEMES.size()):
			if theme_index != stage_themes[stage - 1]:
				candidates.append(theme_index)
		stage_themes.append(candidates[_random.randi_range(0, candidates.size() - 1)])


## 返回当前节点的一基大关号；整局结束时仍显示第三大关。
func stage_number() -> int:
	return mini(node_index / NODES_PER_STAGE + 1, 3)


## 返回当前节点的一基小关号；整局结束时仍显示第五小关。
func node_number() -> int:
	return 5 if node_index >= NODE_COUNT else node_index % NODES_PER_STAGE + 1


## 返回进度条旁显示的大关与节点编号，例如1-1。
func node_label() -> String:
	return "%d-%d" % [stage_number(), node_number()]


## 每个大关第五节点为大肥鱼Boss关，前三个节点类型及遭遇关保持原规则。
func node_kind() -> String:
	return ["奖励关", "战斗关", "战斗关", "遭遇关", "Boss关"][node_number() - 1]


## 返回当前节点在[param row_count]行场景里开放的零基行号；1-1中行、1-2中三行、1-3以后全部开放。
func active_lanes(row_count: int) -> Array[int]:
	if stage_number() == 1:
		if node_number() == 1:
			return [2]
		if node_number() == 2:
			return [1, 2, 3]
	# 行号保留真实场景索引，扩建时不会把中行已有植物挪到第一行。
	var lanes: Array[int] = []
	# 后续地图按真实行数开放，包括六行泳池。
	for lane: int in range(row_count):
		lanes.append(lane)
	return lanes


## 返回当前节点难度，开局为1，每完成节点增加3。
func difficulty() -> int:
	return 1 + node_index * 3


## 返回当前大关的主题配置，不在小关间更换主题。
func theme() -> Dictionary:
	return THEMES[stage_themes[stage_number() - 1]]


## 返回当前大关使用的战斗场景路径；入口与后续节点均使用此方法选择真实行数和地形。
func scene_path() -> String:
	return "res://scenes/currency_war/currency_war_%s.tscn" % theme().scene


## 返回当前地图的原版资源路径；实际波数和随机池由本模式节点规则覆盖，原版出怪机制保留。
func level_path() -> String:
	return "res://resources/level_date_resource/mode_adventure/%s.tres" % theme().level


## 根据[param won]记录一次节点结果；同节点只应调用一次，推进由[method advance]单独执行。
func record_result(won: bool) -> void:
	last_won = won
	if won:
		win_streak += 1
	else:
		win_streak = 0
		brain_losses += 1


## 返回整局是否因第四次吃脑或最后一个节点结算而结束，不能在中途节点退出整局。
func is_final_result() -> bool:
	return brain_losses >= FINAL_BRAIN_LOSS or node_index >= NODE_COUNT - 1


## 前往下一准备节点；最终结果不能继续，成功返回true。
func advance() -> bool:
	if is_final_result():
		return false
	node_index += 1
	return true
