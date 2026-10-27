class_name P5Campaign
extends RefCounted
# 프로필(원정 밖 저장) 규칙. c = SaveManager가 넘기는 프로필 사본 {flags, combat}

const COMBAT_VERSION := 6
const CLASS_IDS := ["rune_caster", "warden", "hunter", "combo", "shaman"]
const DEFAULT_CLASS := "warden"
const CLASS_BASE := {
	"rune_caster": {"hp": 34, "mana": 4},
	"warden": {"hp": 38, "mana": 3},
	"hunter": {"hp": 36, "mana": 3},
	"combo": {"hp": 36, "mana": 3},
	"shaman": {"hp": 38, "mana": 3},
}
const MANA_CAP := 6
const POTION_HEAL := 6
const MANA_POTION_AMOUNT := 2


static func default_combat() -> Dictionary:
	return {
		"version": COMBAT_VERSION,
		"class_id": DEFAULT_CLASS,
		"notices": {"prep_intro": false},
		"run_counter": 0,
		"settled": [],
		"history": [],
		"last_result": {},
		"onboarded": {},
		"stats": {"expeditions": 0, "normal_clears": 0, "hard_clears": 0, "extreme_clears": 0, "returned": 0, "lost": 0, "abandoned": 0},
	}


static func derived(c: Dictionary) -> Dictionary:
	var cb: Dictionary = c.get("combat", default_combat())
	var cid := String(cb.get("class_id", DEFAULT_CLASS))
	var base: Dictionary = CLASS_BASE.get(cid, CLASS_BASE[DEFAULT_CLASS])
	return {"class_id": cid, "max_hp": int(base.hp), "max_mana": mini(MANA_CAP, int(base.mana))}


# 원정을 시작할 때 얼리는 준비값
static func build_entry_loadout(c: Dictionary) -> Dictionary:
	var d := derived(c)
	return {
		"class_id": d.class_id,
		"max_hp": int(d.max_hp),
		"max_mana": int(d.max_mana),
		"level": 1,
	}


static func potion_heal() -> int:
	return POTION_HEAL


static func refresh_vitals(c: Dictionary) -> void:
	var d := derived(c)
	c.flags.player_base_max_hp = int(d.max_hp)
	c.flags.player_max_hp = int(d.max_hp)
	c.flags.player_max_mana = int(d.max_mana)
	c.flags.player_hp = int(d.max_hp)
	c.flags.player_mana = int(d.max_mana)


static func record_event(c: Dictionary, key: String, list := "settled", keep := 64) -> bool:
	var cb: Dictionary = c.combat
	var arr: Array = cb.get(list, [])
	if arr.has(key):
		return false
	arr.append(key)
	while arr.size() > keep:
		arr.pop_front()
	cb[list] = arr
	return true


static func combat_errors(cb: Dictionary) -> Array:
	var errors: Array = []
	if not (cb.get("class_id") is String) or not CLASS_IDS.has(String(cb.get("class_id"))):
		errors.append("combat.class_id")
	for key in ["notices", "last_result", "onboarded", "stats"]:
		if not (cb.get(key) is Dictionary):
			errors.append("combat.%s" % key)
	for key in ["settled", "history"]:
		if not (cb.get(key) is Array):
			errors.append("combat.%s" % key)
	if not (cb.get("run_counter") is int):
		errors.append("combat.run_counter")
	return errors
