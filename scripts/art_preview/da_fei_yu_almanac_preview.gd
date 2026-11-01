## 直接打开真实图鉴中的大肥鱼条目，方便检查头像、文字和展示动作。
extends MainAlmanac


## 沿用完整图鉴初始化，只在首次展示时选中大肥鱼，不修改存档解锁记录。
func _ready() -> void:
	super._ready()
	_on_zombie_button_pressed()
	zombie_page.almanac_character_show_panel.almanac_update_zombie_panel(CharacterRegistry.ZombieType.Z1002DaFeiYu)
