extends Control
class_name AlmanacZombieCard

@onready var almanac_zombie_card_bg: TextureRect = $AlmanacZombieCardBg

var zombie_type:CharacterRegistry.ZombieType

signal signal_card_click

func _ready() -> void:
	if zombie_type == CharacterRegistry.ZombieType.Z1002DaFeiYu:
		# Boss 尚未开放战斗卡槽，图鉴头像直接使用独立美术场景，不要求 AllCards 中有召唤卡。
		var boss_portrait: Node2D = load("res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_video_visual.tscn").instantiate()
		almanac_zombie_card_bg.add_child(boss_portrait)
		boss_portrait.scale = Vector2.ONE * 0.21
		boss_portrait.position = Vector2(35, 62)
		boss_portrait.pause_animation()
		return
	var zombie_card:Card = AllCards.all_zombie_card_prefabs[zombie_type]
	var character_static:Node2D = zombie_card.character_static.duplicate()
	almanac_zombie_card_bg.add_child(character_static)
	character_static.scale = Vector2(1.6, 1.6)
	character_static.position = Vector2(40, 50)

func init_almanac_zombie_card(curr_zombie_type:CharacterRegistry.ZombieType):
	zombie_type = curr_zombie_type

func _on_button_pressed() -> void:
	signal_card_click.emit()
