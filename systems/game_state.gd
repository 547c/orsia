extends Node

signal flag_changed(flag_name: String, value)
signal combat_changed

const VITAL_FLAGS: Array[String] = ["player_hp", "player_base_max_hp", "player_max_hp", "player_mana", "player_max_mana"]
const DEFAULT_FLAGS: Dictionary = {
	"player_hp": 38,
	"player_base_max_hp": 38,
	"player_max_hp": 38,
	"player_mana": 3,
	"player_max_mana": 3,
}

var flags: Dictionary = DEFAULT_FLAGS.duplicate()
var combat: Dictionary = P5Campaign.default_combat()
var combat_scope_active := false
var _campaign_vitals: Dictionary = {}


func set_flag(flag_name: String, value) -> void:
	if flags.get(flag_name, null) == value:
		return
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)


func get_flag(flag_name: String):
	return flags.get(flag_name, false)


func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)


func reset_progress() -> void:
	for k in flags.keys().duplicate():
		if not DEFAULT_FLAGS.has(k):
			flags.erase(k)
	for k in DEFAULT_FLAGS:
		set_flag(k, DEFAULT_FLAGS[k])
	combat = P5Campaign.default_combat()
	combat_scope_active = false
	_campaign_vitals = {}
	combat_changed.emit()


func restore_flags(data: Dictionary) -> void:
	reset_progress()
	for key in data:
		var value = data[key]
		if DEFAULT_FLAGS.has(key):
			var d = DEFAULT_FLAGS[key]
			if d is int:
				value = int(value)
			elif d is bool:
				value = bool(value)
		set_flag(String(key), value)


func damage_player(amount: int) -> void:
	set_flag("player_hp", maxi(0, int(get_flag("player_hp")) - amount))


func heal_player(amount: int) -> void:
	set_flag("player_hp", mini(int(get_flag("player_max_hp")), int(get_flag("player_hp")) + amount))


func spend_mana(amount: int) -> void:
	set_flag("player_mana", maxi(0, int(get_flag("player_mana")) - amount))


func restore_mana(amount: int) -> void:
	set_flag("player_mana", mini(int(get_flag("player_max_mana")), int(get_flag("player_mana")) + amount))


func can_afford_mana(amount: int) -> bool:
	return int(get_flag("player_mana")) >= amount


func heal_player_full() -> void:
	set_flag("player_hp", get_flag("player_max_hp"))


func campaign_view() -> Dictionary:
	var f := flags
	if combat_scope_active:
		f = flags.duplicate()
		for k in _campaign_vitals:
			f[k] = _campaign_vitals[k]
	return {"flags": f, "combat": combat}


# 전투 중에는 전투 계산이 flags의 체력/마나를 쓰고, 저장에는 붙잡아 둔 프로필 값을 쓴다
func begin_combat_scope() -> void:
	if combat_scope_active:
		return
	_campaign_vitals = {}
	for k in VITAL_FLAGS:
		_campaign_vitals[k] = get_flag(k)
	combat_scope_active = true


func end_combat_scope() -> void:
	if not combat_scope_active:
		return
	combat_scope_active = false
	for k in _campaign_vitals:
		set_flag(k, _campaign_vitals[k])
	_campaign_vitals = {}


func campaign_flag(name: String):
	if combat_scope_active and _campaign_vitals.has(name):
		return _campaign_vitals[name]
	return get_flag(name)


func set_campaign_vital(name: String, value) -> void:
	if combat_scope_active and _campaign_vitals.has(name):
		_campaign_vitals[name] = value
	else:
		set_flag(name, value)


func restore_combat(data: Dictionary) -> void:
	var base := P5Campaign.default_combat()
	for k in data:
		base[k] = data[k]
	combat = base
	combat_changed.emit()
