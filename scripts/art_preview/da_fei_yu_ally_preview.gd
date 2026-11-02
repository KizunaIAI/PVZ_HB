## 伙伴卡和原始尺寸朝右待机的纯美术预览，不进入关卡、不领取奖励、不写用户存档。
extends Node2D

## 真实植物场景，展示模式不启动技能结算。
const ALLY: PackedScene = preload("res://scenes/character/plant/plant_051_da_fei_yu.tscn")
## 伙伴专属的纯显示种子卡。
const CARD: PackedScene = preload("res://scenes/currency_war/da_fei_yu_plant_card.tscn")


## 展示角色原始体型及放大对照，卡面使用游戏中同一个模板。
func _ready() -> void:
	# 左侧放大用于看表情，右侧为实机原始尺寸。
	for index: int in range(2):
		# 展示模式植物，不读取真实草坪，也不生产阳光或召唤实体。
		var plant: Plant000Base = ALLY.instantiate()
		plant.init_plant({Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow})
		plant.position = Vector2(320, 535) if index == 0 else Vector2(820, 535)
		plant.scale = Vector2.ONE * (2.0 if index == 0 else 1.0)
		add_child(plant)
	# 同一张种子卡在预览中放大2.5倍，正式备战栏保持原卡位尺寸。
	var card: Card = CARD.instantiate()
	card.position = Vector2(730, 135)
	card.scale = Vector2.ONE * 2.5
	add_child(card)
