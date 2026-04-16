extends Node

signal ability_sacrificed(ability_name: String)
signal ability_reclaimed(ability_name: String)

var player_abilities: Dictionary = {
	"dash": true,
	"projectile": true,
	"jump": true
}

var boss_abilities: Dictionary = {
	"dash": true,
	"projectile": true,
	"jump": true
}

func sacrifice_ability(ability_name: String) -> void:
	if player_abilities.has(ability_name):
		player_abilities[ability_name] = false
		ability_sacrificed.emit(ability_name)

func reclaim_ability(ability_name: String) -> void:
	if player_abilities.has(ability_name):
		player_abilities[ability_name] = true
		ability_reclaimed.emit(ability_name)

func load_scene(path: String) -> void:
	# Assuming TransitionOverlay is also added as an AutoLoad Singleton
	TransitionOverlay.fade_out()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(path)
