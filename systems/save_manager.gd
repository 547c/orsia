extends Node

# 슬롯 하나 = 봉투 하나 {"format", "version", "revision", "checksum", "data"}, data = {profile, run, field, preview} (field = 연습 한 판).
# 모든 변경은 transact() 한 통로: 사본을 고치고 → 검증 → 임시 파일에 쓰고 다시 읽어 확인 → 주 파일을 백업으로 → 교체한 뒤에만 게시.
# 쓰기가 실패하면 같은 결과를 pending으로 붙잡고 다른 변경을 막는다 (난수·보상을 다시 굴리지 않게)

signal save_failed(reason: String)
signal committed(reason: String)

const SLOT_COUNT := 3
const FORMAT := "orsia-profile"
const VERSION := 1

var save_dir := "user://"
var current_slot := 0
var revision := 0
var pending: Dictionary = {}
var last_error := ""
var writes := 0
var notices: Array[String] = []
var fail_next := 0
var fail_after_tmp := 0


func _slot_file(slot: int, suffix := "") -> String:
	return save_dir.path_join("profile_%d%s.json" % [slot, suffix])


func has_save(slot: int) -> bool:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(_slot_file(slot, suffix)):
			return true
	return false


func has_any_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if has_save(slot):
			return true
	return false


func capture_profile() -> Dictionary:
	var f: Dictionary = GameState.flags.duplicate(true)
	for k in GameState.VITAL_FLAGS:
		f[k] = GameState.campaign_flag(k)
	return {"flags": f, "combat": GameState.combat.duplicate(true)}


func publish_profile(c: Dictionary) -> void:
	for k in c.flags:
		var v = c.flags[k]
		if GameState.VITAL_FLAGS.has(k):
			if GameState.campaign_flag(k) != v:
				GameState.set_campaign_vital(k, v)
		elif not GameState.flags.has(k) or GameState.flags[k] != v:
			GameState.set_flag(String(k), v)
	if c.combat != GameState.combat:
		GameState.restore_combat(c.combat)


func _restore_profile(c: Dictionary) -> void:
	GameState.restore_flags(c.get("flags", {}))
	GameState.restore_combat(c.get("combat", {}))


static func encode(rev: int, data: Dictionary) -> String:
	var text := JSON.stringify(data, "", true)
	return JSON.stringify({"format": FORMAT, "version": VERSION, "revision": rev, "checksum": text.sha256_text(), "data": text}, "\t", true)


static func decode(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {"ok": false, "error": "empty"}
	var outer = JSON.parse_string(text)
	if not (outer is Dictionary):
		return {"ok": false, "error": "not json"}
	if String(outer.get("format", "")) != FORMAT:
		return {"ok": false, "incompatible": true, "error": "다른 형식(%s)" % str(outer.get("format"))}
	var ver = outer.get("version", -1)
	if not (ver is float or ver is int) or int(ver) != VERSION:
		return {"ok": false, "incompatible": true, "error": "저장 버전 %s" % str(ver)}
	var rev = outer.get("revision")
	if not (rev is float or rev is int):
		return {"ok": false, "error": "revision missing"}
	var inner = outer.get("data", "")
	if not (inner is String) or String(inner).sha256_text() != String(outer.get("checksum", "")):
		return {"ok": false, "error": "checksum mismatch"}
	var data = JSON.parse_string(inner)
	if not (data is Dictionary):
		return {"ok": false, "error": "data not json"}
	return {"ok": true, "revision": int(rev), "data": normalize(data)}


# JSON은 정수를 실수로 돌려준다 — 소수부 없는 수는 정수로
static func normalize(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = normalize(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(normalize(x))
		return arr
	if v is float and is_finite(v) and v == floor(v) and absf(v) < 9.0e15:
		return int(v)
	return v


func validate_data(data: Dictionary) -> Array:
	if not (data.get("profile") is Dictionary):
		return ["profile missing"]
	var c: Dictionary = data.profile
	var errors: Array = []
	if not (c.get("flags") is Dictionary) or not (c.get("combat") is Dictionary):
		return ["profile shape"]
	for k in ["player_hp", "player_max_hp"]:
		if not (c.flags.get(k) is int):
			errors.append("flags.%s type" % k)
	errors.append_array(P5Campaign.combat_errors(c.combat))
	var r: Dictionary = data.get("run", {})
	var fld: Dictionary = data.get("field", {})
	if not r.is_empty() and not fld.is_empty():
		errors.append("run and practice both active")
	if not r.is_empty():
		errors.append_array(RunService.validate_run(r))
	if not fld.is_empty():
		errors.append_array(RunService.validate_field(fld))
	return errors


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return ""
	return fa.get_as_text()


func _write(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		last_error = "open failed: %s" % error_string(FileAccess.get_open_error())
		return false
	fa.store_string(text)
	fa.flush()
	fa.close()
	return true


func _write_slot(slot: int, rev: int, data: Dictionary) -> bool:
	last_error = ""
	if fail_next > 0:
		fail_next -= 1
		last_error = "test: injected write failure"
		return false
	var text := encode(rev, data)
	var tmp := _slot_file(slot, ".tmp")
	if not _write(tmp, text):
		return false
	var check := decode(_read(tmp))
	if not bool(check.get("ok", false)) or int(check.revision) != rev:
		last_error = "temp verify failed: " + String(check.get("error", "revision"))
		return false
	var errors := validate_data(check.data)
	if not errors.is_empty():
		last_error = "temp invalid: " + "; ".join(PackedStringArray(errors.slice(0, 4)))
		return false
	if fail_after_tmp > 0:
		fail_after_tmp -= 1
		last_error = "test: injected replace failure (temp written)"
		return false
	var primary := _slot_file(slot)
	var backup := _slot_file(slot, ".bak")
	if FileAccess.file_exists(primary):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(primary, backup) != OK:
			last_error = "backup rotate failed"
			return false
	if DirAccess.rename_absolute(tmp, primary) != OK:
		last_error = "replace failed"
		return false
	writes += 1
	return true


# 주 · 임시 · 백업 중 가장 최근의 온전한 봉투. 손상본은 corrupt_* 사본으로 보존
func load_best(slot: int) -> Dictionary:
	var notes: Array[String] = []
	var best: Dictionary = {}
	for suffix in ["", ".tmp", ".bak"]:
		var path := _slot_file(slot, suffix)
		var text := _read(path)
		if text == "":
			continue
		var r := decode(text)
		if bool(r.get("ok", false)):
			var errors := validate_data(r.data)
			if errors.is_empty():
				if best.is_empty() or int(r.revision) > int(best.revision):
					best = {"revision": int(r.revision), "data": r.data, "source": path}
				continue
			r = {"ok": false, "error": "invalid: " + "; ".join(PackedStringArray(errors.slice(0, 4)))}
		if bool(r.get("incompatible", false)):
			notes.append("프로필 %d%s: %s — 파일을 그대로 두었습니다" % [slot, suffix, r.error])
			continue
		var kept := path.get_basename() + ".corrupt_%d.json" % Time.get_unix_time_from_system()
		DirAccess.rename_absolute(path, kept)
		notes.append("프로필 %d%s 손상(%s) → %s 로 보존" % [slot, suffix, r.error, kept.get_file()])
	if best.is_empty():
		return {"ok": false, "notes": notes}
	if String(best.source) != _slot_file(slot):
		notes.append("주 저장 대신 %s (revision %d)에서 불러왔습니다" % [String(best.source).get_file(), int(best.revision)])
	best["ok"] = true
	best["notes"] = notes
	return best


func has_pending() -> bool:
	return not pending.is_empty()


# fn(c, r, f) — c: 프로필 사본, r: 원정 사본, f: 연습 사본. false를 돌려주면 아무것도 바뀌지 않는다
func transact(reason: String, fn: Callable) -> bool:
	if has_pending():
		last_error = "저장되지 않은 행동이 남아 있어 다른 변경을 막았습니다"
		return false
	if current_slot <= 0:
		last_error = "no current slot"
		return false
	var c := capture_profile()
	var r: Dictionary = RunService.run.duplicate(true)
	var fld: Dictionary = RunService.field.duplicate(true)
	var ok = fn.call(c, r, fld)
	if not ok:
		return false
	return _commit(reason, c, r, fld)


func _commit(reason: String, c: Dictionary, r: Dictionary, fld: Dictionary) -> bool:
	var data := {"profile": c, "run": r, "field": fld, "preview": _preview(c, r)}
	var errors := validate_data(data)
	if not errors.is_empty():
		last_error = "invalid after %s: %s" % [reason, "; ".join(PackedStringArray(errors.slice(0, 6)))]
		push_warning(last_error)
		return false
	var next := revision + 1
	if not _write_slot(current_slot, next, data):
		pending = {"reason": reason, "revision": next, "data": data}
		push_warning("save failed: " + last_error)
		save_failed.emit(reason)
		return false
	revision = next
	_publish(data)
	committed.emit(reason)
	return true


func retry_pending() -> bool:
	if pending.is_empty():
		return true
	if not _write_slot(current_slot, int(pending.revision), pending.data):
		return false
	revision = int(pending.revision)
	var data: Dictionary = pending.data
	var reason := String(pending.reason)
	pending = {}
	_publish(data)
	committed.emit(reason)
	return true


# 붙잡은 결과를 버린다. 같은 revision의 임시 파일이 남아 있으면 지워 다음 실행에서 되살아나지 않게
func discard_pending() -> bool:
	if pending.is_empty():
		return true
	var tmp := _slot_file(current_slot, ".tmp")
	var ok := true
	if FileAccess.file_exists(tmp):
		var r := decode(_read(tmp))
		if not bool(r.get("ok", false)) or int(r.get("revision", -1)) >= int(pending.revision):
			ok = DirAccess.remove_absolute(tmp) == OK
	if ok:
		pending = {}
	return ok


func _publish(data: Dictionary) -> void:
	RunService.run = data.run
	RunService.field = data.get("field", {})
	publish_profile(data.profile)


func commit(reason: String) -> bool:
	return transact(reason, func(_c, _r, _f): return true)


static func _preview(c: Dictionary, r: Dictionary) -> Dictionary:
	var st: Dictionary = c.combat.get("stats", {})
	return {
		"class_id": String(r.get("class_id", c.combat.get("class_id", ""))) if not r.is_empty() else String(c.combat.get("class_id", "")),
		"run": String(r.get("sector", "")) if not r.is_empty() else "",
		"diff": String(r.get("diff", "")) if not r.is_empty() else "",
		"hp": int(r.get("hp", 0)) if not r.is_empty() else 0,
		"max_hp": int(r.get("max_hp", 0)) if not r.is_empty() else 0,
		"expeditions": int(st.get("expeditions", 0)),
	}


func _max_revision(slot: int) -> int:
	var m := 0
	for suffix in ["", ".tmp", ".bak"]:
		var r := decode(_read(_slot_file(slot, suffix)))
		if bool(r.get("ok", false)):
			m = maxi(m, int(r.revision))
	return m


# 새 프로필: 메모리를 비우고 슬롯을 정한다. 첫 저장은 commit("new profile")
func begin_new_game(slot: int) -> void:
	pending = {}
	notices.clear()
	GameState.reset_progress()
	RunService.clear_all()
	current_slot = slot
	revision = _max_revision(slot)


# 불러오기만 한다 (화면 이동은 부른 쪽이)
func load_game(slot: int) -> bool:
	if has_pending():
		return false
	notices.clear()
	var best := load_best(slot)
	notices.append_array(best.get("notes", []))
	if not bool(best.get("ok", false)):
		return false
	var data: Dictionary = best.data
	revision = int(best.revision)
	current_slot = slot
	RunService.clear_all()
	_restore_profile(data.profile)
	RunService.run = data.get("run", {})
	RunService.field = data.get("field", {})
	return true


func get_save_summary(slot: int) -> Dictionary:
	for suffix in ["", ".tmp", ".bak"]:
		var r := decode(_read(_slot_file(slot, suffix)))
		if bool(r.get("ok", false)):
			return (r.data.get("preview", {}) as Dictionary).duplicate()
	return {}
