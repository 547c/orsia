class_name PlayerCombatant
extends RefCounted

# 전투 속 주인공. 상태를 복사해 들고 있지 않고 전부 GameState/매니저로 위임한다

var display_name: String = "플레이어"
var status: StatusEffects # 매니저의 player_status를 그대로 가리킨다 (복사 아님)


func _init(status_: StatusEffects) -> void:
	status = status_


func is_alive() -> bool:
	return GameState.get_flag("player_hp") > 0


func take_damage(amount: int) -> int:
	var before: int = GameState.get_flag("player_hp")
	GameState.damage_player(amount)
	return before - GameState.get_flag("player_hp")


func heal(amount: int) -> int:
	var max_hp: int = GameState.get_flag("player_max_hp")
	if max_hp <= 0:
		return 0
	var before: int = GameState.get_flag("player_hp")
	GameState.heal_player_partial(float(amount) / max_hp)
	return GameState.get_flag("player_hp") - before
