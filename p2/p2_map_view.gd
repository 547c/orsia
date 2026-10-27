class_name P2MapView
extends Node2D
# 원정 지도: 균열의 핵을 가운데 두고 구간 I·II·III이 바깥에서 안으로 겹친 고리(비스듬히 본 타원)다. 지금 구간의 고리가
# 화면 가운데 크게 놓이고 다음에 갈 곳이 앞(아래 가운데)으로 오게 돈다. 지나온 구간은 바깥 큰 고리, 갈 구간은 안쪽 작은 고리.
# 여러 곳 중 고르는 자리는 소용돌이로 묶어 따로 펼친다. 진행은 run.defeated·route·choice·service에서만 읽는다

signal engage_requested(id: String)
signal portal_requested
signal menu_requested
signal deck_requested
signal route_requested(route: String)
signal service_requested
signal choice_requested
signal level_requested
signal relics_requested

const REWARD_SHORT := {"upgrade": "강화", "relic": "유물", "upgrade_or_heal": "강화/회복", "upgrade_or_relic": "강화/유물"}
const C_STREAM := Color("#3f9aa3")
const BOARD := Rect2(16, 112, 1248, 470)
const RING_C := Vector2(624, 196)
const RX := 470.0
const RY := 150.0
const SIDE_RS := 0.8
const CARD := Vector2(440, 96)
const CARD_GAP := 18.0
const HUB_X := 470.0
const STEPS := {"normal": [["n1"], ["n2"], ["n3"], ["n4"], ["boss"]], "hard": [["h1a", "h1b"], ["h2"], ["hboss"]], "extreme": [["x1"], ["x2"], ["xboss"]]}
const SFX_DIR := "res://assets/sfx/400 Sounds pack/"
const F := 16
const SYM_MANDATORY := Color("#d8483e")
const SYM_OPTIONAL := Color("#ff9a6a")
const SYM_BOSS := Color("#b58cff")
const SYM_MERCHANT := Color("#f2c461")
const SYM_CHOICE := Color("#7fd7d0")
const SYM_PORTAL := Color("#8fc3e8")
const SYM_DONE := Color("#7fd7b0")
# 픽셀 지도: 우주 배경과 고리 그림(행성·길·소용돌이)을 절반 해상도로 그려 최근접으로 두 배 키운다. 글자는 원래 해상도
const PIX := 2
const RING_K := 0.55
const SPAN := 300.0
const SECTOR_IDX := {"normal": 0, "hard": 1, "extreme": 2}
const RING_DOTS := [6, 4, 4]

var model: RunModel
var sector := "normal"
var layout: Dictionary
var hard := false
var locked := false
var hud_layer: CanvasLayer
var _hud: Control
var _relic_row: HBoxContainer
var _contract_label: Label
var _legend: RichTextLabel
var _legend_bg: Panel
var _prompt_bg: Panel
var _ctx_name: Label
var _prompt: Label
var _message: Label
var _current: Dictionary = {}
var _map: Control
var _lines: Control
var _nodes := {}
var _flow := 0.0
var _sel := ""
var _calm := false
var _board: Control
var _rot := 0.0
var _rot_tw: Tween
var _entries: Array = []
var _hubs := {}
var _hub_open := ""
var _hub_layer: Control
var _hub_lines: Control
var _hub_title: Label
var _hub_hint: Label
var _hub_tw: Tween
var _hub_zoom := 0.0
var _drag_rot := {}
var _spun_for := -999.0
var _wins := -1
var _font: Font
var _core_lbl := true
var _strip_l := {}
var _sky: P2Starfield
var _pixel := true
var _aa := false
var _ink: Control
var _info: Button
var _lv_btn: Button
var _lv_label: Label
var _hub_ink: Control
var _hint: Panel
var _hint_key := ""
var _hint_target := ""
var _ctx_chips: Control
var _snd: Array = []
var _snd_i := 0
var sfx_log: Array = []


func setup(m: RunModel) -> void:
	model = m
	layout = m.run.layout
	sector = String(layout.get("sector", "normal"))
	hard = sector != "normal"
	_calm = false
	_build_hud()
	_build_ring_map()
	refresh()
	_focus_next()
	MusicManager.play("Frozen Abyss")


func _add_node(key: String, kind: String, id: String, pos: Vector2, label_up: bool) -> void:
	var half := 12.0 if kind == "start" else (38.0 if RunModel.is_boss(id) else 30.0)
	var b := Button.new()
	b.flat = true
	b.size = Vector2.ONE * half * 2.84
	b.position = pos - b.size / 2.0
	b.focus_mode = Control.FOCUS_NONE if kind == "start" else Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if kind == "start":
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var ring := _diamond(b, half + 7.0)
	var plate := _diamond(b, half)
	var sym := P2Ui.outlined(P2Ui.text("", P2Ui.T_HEAD, Color.WHITE), 3)
	sym.size = b.size
	sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(sym)
	var name_l := P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, P2Ui.C_TEXT), 4)
	var sub_l := P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, P2Ui.C_DIM), 4)
	for i in range(2):
		var l: Label = [name_l, sub_l][i]
		l.size = Vector2(280, 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(b.size.x / 2.0 - 140.0, (-54.0 if label_up else b.size.y + 6.0) + i * 24.0)
		b.add_child(l)
	b.mouse_entered.connect(_hover.bind(key, true))
	b.mouse_exited.connect(_hover.bind(key, false))
	b.focus_entered.connect(_hover.bind(key, true))
	b.focus_exited.connect(_hover.bind(key, false))
	b.pressed.connect(_press.bind(key))
	b.pivot_offset = b.size / 2.0
	(_board if _board != null else _map).add_child(b)
	_nodes[key] = {"kind": kind, "id": id, "btn": b, "ring": ring, "plate": plate, "sym": sym, "name": name_l, "sub": sub_l, "st": "locked", "it": {}}


func _diamond(parent: Control, half: float) -> Panel:
	var d := Panel.new()
	d.size = Vector2.ONE * half * 2.0
	d.position = parent.size / 2.0 - d.size / 2.0
	d.pivot_offset = d.size / 2.0
	d.rotation_degrees = 45
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	return d


# ── 상태: 저장된 원정 상태와 기존 규칙 함수에서만 읽는다 ─────────────────────────────

func _state_of(n: Dictionary) -> Dictionary:
	var run := model.run
	var defeated: Array = run.defeated
	var over := String(run.phase) != "explore"
	match String(n.kind):
		"start":
			return {"st": "done", "it": {}}
		"service":
			if over:
				return {"st": "locked", "it": {"kind": "gate", "id": "service", "name": tr("상인"), "prompt": tr("이 구간의 일은 끝났습니다")}}
			if model.service_unlocked():
				return {"st": "open", "it": {"kind": "service", "id": "service"}}
			return {"st": "locked", "it": {"kind": "locked", "id": "service", "prompt": "상인 — 앞 전투를 이겨야 거래할 수 있습니다"}}
		"choice":
			if String(run.choice.get("picked", "")) != "":
				return {"st": "done", "it": {"kind": "done", "id": "choice", "name": tr(String(P2Catalog.EVENTS[RunModel.event_of(run)].name))}}
			if over:
				return {"st": "locked", "it": {"kind": "gate", "id": "choice", "name": tr(String(P2Catalog.EVENTS[RunModel.event_of(run)].name)), "prompt": tr("이 구간의 일은 끝났습니다")}}
			var need := _missing(layout.choice.get("requires", []))
			if not need.is_empty():
				return {"st": "locked", "it": {"kind": "gate", "id": "choice", "name": tr(String(P2Catalog.EVENTS[RunModel.event_of(run)].name)), "prompt": tr("먼저 이겨야 할 전투: ") + ", ".join(need)}}
			return {"st": "open", "it": {"kind": "choice", "id": "choice"}}
	var id := String(n.id)
	var gname := String(P2Catalog.GROUPS[layout.encounters[id].group].name)
	if RunModel.is_boss(id) and String(run.phase) == "portal":
		return {"st": "open", "it": {"kind": "portal", "id": "portal"}}
	if defeated.has(id):
		return {"st": "done", "it": {"kind": "done", "id": id, "name": gname}}
	var route := String(run.get("route", ""))
	if id in ["h1a", "h1b"] and not over:
		if route == "":
			return {"st": "open", "it": {"kind": "route", "id": id.substr(2)}}
		if route != id.substr(2):
			return {"st": "sealed", "it": {"kind": "sealed", "id": id.substr(2), "prompt": "봉인된 길 — 이번 원정은 경로 %s로 확정했습니다" % route.to_upper()}}
	if model.can_start_encounter(id):
		return {"st": "open", "it": {"kind": "enemy", "id": id}}
	var why := tr("이 구간의 일은 끝났습니다")
	if not over:
		var need := _missing(layout.encounters[id].get("requires", []))
		if id == "h2":
			need = PackedStringArray([tr("경로 A 또는 B의 전투")]) if route == "" else _missing(["h1" + route])
		why = tr("먼저 이겨야 할 전투: ") + ", ".join(need)
	return {"st": "locked", "it": {"kind": "gate", "id": id, "name": gname, "prompt": why}}


func _missing(req: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for r in req:
		if not (model.run.defeated as Array).has(r):
			out.append(String(P2Catalog.GROUPS[layout.encounters[r].group].name))
	return out


func _enemy_tag(id: String) -> Array:
	var e: Dictionary = layout.encounters[id]
	var g: Dictionary = P2Catalog.GROUPS[e.group]
	var risk := tr(" · 위험 +%d") % P2Catalog.RISK_ATTACK if bool(e.get("risk", false)) else ""
	match id:
		"elite":
			if String(e.get("kind", "elite")) == "mimic":
				return ["?! " + tr("수상한 상자") + risk, SYM_OPTIONAL]
			return ["★ %s%s" % [g.name, risk], SYM_OPTIONAL]
		"boss", "hboss", "xboss":
			return ["☠ %s" % g.name, SYM_BOSS]
		"h1a", "h1b":
			return ["%s %s" % [id.substr(2).to_upper(), g.name], P2Ui.C_BLOCK]
	return ["! %s" % g.name, SYM_MANDATORY]


func _reward_short(id: String) -> String:
	var parts: Array[String] = [tr("정산") if RunModel.is_boss(id) else tr("카드")]
	for t in P2Catalog.REWARD_PLAN.get(RunModel._reward_key(id), []):
		parts.append(tr(String(REWARD_SHORT.get(t, t))))
	return " · ".join(parts)


# [기호, 색, 이름, 한 줄 정보]
func _look_of(n: Dictionary) -> Array:
	var st := String(n.st)
	match String(n.kind):
		"start":
			return ["", P2Ui.C_DIM, tr("입구"), ""]
		"service":
			return ["상", SYM_MERCHANT, tr("상인"), tr("미확정 금화 %d") % int(model.run.gold) if st == "open" else ("" if String(model.run.phase) != "explore" else tr("앞 전투를 이기면 열림"))]
		"choice":
			return ["?", SYM_CHOICE, tr(String(P2Catalog.EVENTS[RunModel.event_of(model.run)].name)), tr("지나감") if st == "done" else ("" if String(model.run.phase) != "explore" else tr("사건 · 하나 고르기"))]
	if String((n.it as Dictionary).get("kind", "")) == "portal":
		return ["◎", SYM_PORTAL, tr("출구 포탈"), tr("원정 마치기")]
	var id := String(n.id)
	var tag: Array = _enemy_tag(id)
	var sym := String(tag[0]).get_slice(" ", 0)
	var sub := _reward_short(id)
	if st == "sealed":
		sub = tr("봉인됨")
	elif st == "done":
		sub = ""
	return [sym, tag[1], String(tag[0]).substr(sym.length() + 1), sub]


func _paint() -> void:
	if model.run.is_empty():
		return
	for key in _nodes:
		var n: Dictionary = _nodes[key]
		var s := _state_of(n)
		n.st = s.st
		n.it = s.it
		var look := _look_of(n)
		var col: Color = look[1]
		var edge := col
		var ink := col
		var fill := Color(0.16, 0.13, 0.12, 0.98)
		var name_col := P2Ui.C_TEXT
		var sub_col := P2Ui.C_GOLD
		var sym := String(look[0])
		match String(n.st):
			"done":
				edge = SYM_DONE.darkened(0.35)
				ink = SYM_DONE
				fill = Color(0.08, 0.10, 0.10, 0.96)
				name_col = P2Ui.C_DIM.darkened(0.2)
				sub_col = name_col
				if n.kind != "start":
					sym = "✓"
			"locked":
				edge = Color(0.36, 0.38, 0.42)
				ink = Color(0.52, 0.54, 0.58)
				fill = Color(0.08, 0.08, 0.10, 0.96)
				name_col = Color(0.60, 0.58, 0.54)
				sub_col = Color(0.50, 0.49, 0.47)
			"sealed":
				edge = Color(0.5, 0.2, 0.2)
				ink = Color(0.8, 0.36, 0.3)
				fill = Color(0.10, 0.06, 0.06, 0.96)
				name_col = Color(0.60, 0.50, 0.48)
				sub_col = Color(0.8, 0.36, 0.3)
				sym = "X"
		(n.plate as Panel).add_theme_stylebox_override("panel", P2Ui.box(fill, edge, 3))
		(n.plate as Panel).scale = Vector2.ONE * (1.08 if key == _sel else 1.0)
		var rs := StyleBoxFlat.new()
		rs.draw_center = false
		rs.border_color = P2Ui.C_GOLD if key == _sel else col
		rs.set_border_width_all(2)
		(n.ring as Panel).add_theme_stylebox_override("panel", rs)
		(n.ring as Panel).visible = key == _sel or String(n.st) == "open"
		(n.sym as Label).text = sym
		(n.sym as Label).add_theme_color_override("font_color", ink)
		(n.name as Label).text = String(look[2])
		(n.name as Label).add_theme_color_override("font_color", name_col)
		(n.sub as Label).text = String(look[3])
		(n.sub as Label).add_theme_color_override("font_color", sub_col)
		if n.has("ang"):
			(n.plate as Panel).visible = false
			(n.ring as Panel).visible = false
			(n.sym as Label).add_theme_color_override("font_color", P2Ui.C_TEXT if String(n.st) == "open" else (Color(0.82, 0.86, 0.84) if String(n.st) == "done" else Color(0.7, 0.7, 0.74)))
	_paint_hubs()
	_lines.queue_redraw()


func refresh() -> void:
	if model.run.is_empty():
		return
	_paint()
	_update_hud()
	# 싸우고 돌아오면 소용돌이에서 나와 고리가 다음 곳으로 돈다
	var wins := (model.run.defeated as Array).size()
	if wins != _wins and _wins >= 0:
		_close_hub(true)
	_wins = wins
	_spin_to_next()
	_maybe_hint.call_deferred()


func _update_hud() -> void:
	var run := model.run
	if run.is_empty():
		return
	for c in _relic_row.get_children():
		c.queue_free()
	var rlv := P2Catalog.relic_levels(run.relics)
	for id in run.relics:
		var slot := Button.new()
		slot.flat = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(32, 32)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var ic := P2Ui.tex_icon(P2Ui.relic_tex(id), 28)
		ic.position = Vector2(2, 2)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ic)
		var n := int(rlv.get(String(id), 1))
		P2Ui.relic_level_mark(slot, n, 32.0)
		slot.tooltip_text = "%s\n%s%s\n(눌러서 유물 창)" % [P2Catalog.RELICS[id].name, P2Catalog.RELICS[id].text, P2Ui.relic_level_text(n)]
		slot.pressed.connect(func() -> void:
			if not locked:
				relics_requested.emit())
		_relic_row.add_child(slot)
	if not (run.relics as Array).is_empty():
		var arr := P2Ui.crisp(P2Ui.button(tr("배치"), Vector2.ZERO, Vector2(58, 30), 12), 12) as Button
		arr.focus_mode = Control.FOCUS_NONE
		arr.tooltip_text = tr("유물 칸 순서 바꾸기 (석판은 옆 칸에 영향)")
		arr.pressed.connect(func() -> void:
			if not locked:
				relics_requested.emit())
		_relic_row.add_child(arr)
	for t in run.get("traits", []):
		var ti := P2Ui.tex_icon(P2Catalog.icon_tex(String(t)), 28)
		ti.tooltip_text = "계속 특성 · %s\n%s" % [P2Catalog.TRAITS[t].name, P2Catalog.TRAITS[t].text]
		ti.mouse_filter = Control.MOUSE_FILTER_STOP
		ti.modulate = Color(1.2, 1.1, 0.8)
		_relic_row.add_child(ti)
	var info := String(P2Catalog.SECTOR_NAMES[sector])
	if sector == "hard":
		var route := String(run.get("route", ""))
		info += " · 갈림길에서 경로 A/B를 고르세요 (반대 길은 봉인)" if route == "" else " · 경로 %s: %s" % [route.to_upper(), P2Catalog.GROUPS["h1" + route].name]
	_contract_label.text = info
	_update_strip()


func _process(delta: float) -> void:
	if _calm or model.run.is_empty():
		return
	_flow += delta
	var a := 0.6 + 0.4 * sin(_flow * 4.0)
	for key in _nodes:
		(_nodes[key].ring as Panel).modulate.a = 1.0 if key == _sel else a
	_layout_ring()
	_sky.rot = _rot
	_place_hint()
	_ink.queue_redraw()
	if _hub_open != "":
		_hub_lines.queue_redraw()
	_lines.queue_redraw()


# ── 입력: 올리거나(마우스·방향키) 고르면 아래 칸에 설명, 누르면 기존 창 ─────────────

func _hover(key: String, on: bool) -> void:
	if locked or model.run.is_empty():
		return
	if on:
		_sel = key
	elif _sel == key and not _btn_of(key).has_focus():
		_sel = ""
	if _sel == "":
		_current = {}
	elif _hubs.has(_sel):
		_current = {"kind": "hub", "id": _sel}
	else:
		_current = _nodes[_sel].it
	_show_context()
	_paint()


func _btn_of(key: String) -> Button:
	return (_hubs[key] if _hubs.has(key) else _nodes[key]).btn


func _press(key: String) -> void:
	if locked or model.run.is_empty():
		return
	if _hubs.has(key):
		var direct := _hub_direct(_hubs[key])
		if direct != "" and String(_nodes[direct].st) == "open":
			_press(direct)
		else:
			_open_hub(key)
		return
	_current = _nodes[key].it
	if String(_nodes[key].get("hub", "")) != "":
		_dismiss_hint("map_hub")
	if String(_current.get("kind", "")) == "done":
		show_message("이미 끝난 곳입니다.")
		return
	interact()


func _name_of(it: Dictionary) -> String:
	var id := String(it.get("id", ""))
	match String(it.kind):
		"gate", "done":
			return String(it.name)
		"route":
			return tr("경로 %s · %s") % [id.to_upper(), P2Catalog.GROUPS["h1" + id].name]
		"hub":
			return tr("갈림길 (경로 하나만)") if bool(_hubs[id].route) else tr("곁길 소용돌이")
		"enemy":
			return String(P2Catalog.GROUPS[layout.encounters[id].group].name)
		"service":
			return tr("상인")
		"locked":
			return tr("상인 (닫힘)")
		"choice":
			return tr("선택 지점")
		"sealed":
			return tr("봉인된 길")
		"portal":
			return tr("출구 포탈")
	return String(it.get("prompt", ""))


func interact() -> void:
	if _current.is_empty():
		return
	match String(_current.kind):
		"hub":
			_press(String(_current.id))
			return
		"enemy":
			engage_requested.emit(String(_current.id))
		"service":
			service_requested.emit()
		"choice":
			choice_requested.emit()
		"route":
			route_requested.emit(String(_current.id))
		"locked", "gate", "sealed":
			show_message(String(_current.prompt))
		"portal":
			portal_requested.emit()
	refresh()


func use_heal() -> void:
	if model.use_heal_charge():
		show_message("회복약을 마셨다. 체력 %d / %d" % [int(model.run.hp), int(model.run.max_hp)])
		refresh()


func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(_message, "modulate:a", 0.0, 0.5)


func set_locked(value: bool) -> void:
	locked = value
	if value:
		_current = {}
		_show_context()
	if model.run.is_empty():
		return
	if value:
		_sel = ""
		_paint()
		_hide_hint()
	else:
		_calm = false
		_focus_next()
		_maybe_hint.call_deferred()


# 다음에 갈 곳(본 길의 열린 곳, 없으면 열린 곁길)에 초점을 둬서 방향키·E로도 바로 고를 수 있게 한다
func _focus_next() -> void:
	if locked:
		return
	if _hub_open == "":
		for e in _entries:
			if bool(e.main) and _entry_state(String(e.key)) == "open":
				_btn_of(String(e.key)).grab_focus()
				return
	var pick := ""
	for key in _nodes:
		var n: Dictionary = _nodes[key]
		if String(n.st) != "open" or not (n.btn as Button).is_visible_in_tree():
			continue
		if n.kind == "enemy" and n.id != "elite":
			pick = key
			break
		if pick == "":
			pick = key
	if pick != "":
		(_nodes[pick].btn as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not locked and _info != null and event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_I or (key == KEY_ESCAPE and _legend.visible):
			_toggle_legend()
			get_viewport().set_input_as_handled()
			return
	if not locked and _hub_open != "" and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close_hub()
		get_viewport().set_input_as_handled()
		return
	if not locked and is_visible_in_tree() and get_viewport().gui_get_focus_owner() == null:
		for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			if event.is_action_pressed(a):
				_focus_next()
				get_viewport().set_input_as_handled()
				return
	if locked or not is_visible_in_tree():
		return
	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				use_heal()
			KEY_TAB:
				deck_requested.emit()
			KEY_ESCAPE:
				menu_requested.emit()


# ── 고리 지도 ─────────────────────────────────────────────────────────────────
# 고리 위에는 본 길(입구 → 전투들 → 보스)과 곁길 하나짜리만 놓는다. 두 곳 이상을 고르는 자리(경로 A/B, 상인+선택 전투 등)는
# 소용돌이 하나로 묶고, 누르면 고리가 그 소용돌이로 빨려 들어가며 따로 펼친 갈림길 화면에서 고른다.
# 고리는 끌거나 휠로 돌릴 수 있고, 놓으면 가장 가까운 곳이 앞(아래 가운데)에 맞춰 선다

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_hud)
	_relic_row = HBoxContainer.new()
	_relic_row.position = Vector2(16, 50)
	_relic_row.add_theme_constant_override("separation", 4)
	_hud.add_child(_relic_row)
	_contract_label = P2Ui.outlined(P2Ui.label("", F, P2Ui.C_GOLD, 600))
	_contract_label.position = Vector2(340, 48)
	_contract_label.size = Vector2(600, 44)
	_contract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_contract_label)
	_legend = RichTextLabel.new()
	_legend.bbcode_enabled = true
	_legend.fit_content = true
	_legend.scroll_active = false
	_legend.add_theme_font_override("normal_font", P2Ui.pixel_font(P2Ui.T_BODY))
	_legend.add_theme_font_size_override("normal_font_size", P2Ui.T_BODY)
	_legend.add_theme_color_override("default_color", P2Ui.C_DIM)
	_legend.add_theme_color_override("font_outline_color", Color.BLACK)
	_legend.add_theme_constant_override("outline_size", 3)
	_legend.text = "[color=%s]![/color] %s   [color=%s]★ ?![/color] %s\n[color=%s]☠[/color] %s   [color=%s]상[/color] %s\n[color=%s]?[/color] %s   [color=%s]◎[/color] %s\n[color=%s]✓[/color] %s" % [
		SYM_MANDATORY.to_html(false), tr("필수"), SYM_OPTIONAL.to_html(false), tr("선택·미믹"), SYM_BOSS.to_html(false), tr("보스"),
		SYM_MERCHANT.to_html(false), tr("상인"), SYM_CHOICE.to_html(false), tr("선택 지점"), SYM_PORTAL.to_html(false), tr("포탈"), SYM_DONE.to_html(false), tr("끝남")]
	_legend_bg = Panel.new()
	_legend_bg.position = Vector2(1030, 46)
	_legend_bg.size = Vector2(242, 104)
	_legend_bg.add_theme_stylebox_override("panel", P2Ui.box(Color(P2Ui.C_SLATE, 0.88), P2Ui.C_EDGE, 2))
	_legend_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_bg.visible = false
	_hud.add_child(_legend_bg)
	_legend.position = Vector2(1038, 50)
	_legend.size = Vector2(232, 96)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.visible = false
	_hud.add_child(_legend)
	# 아래 카드: 이름(왼쪽) · 누를 것(오른쪽) · 칩 한 줄
	_prompt_bg = Panel.new()
	_prompt_bg.position = Vector2(262, 588)
	_prompt_bg.size = Vector2(776, 100)
	_prompt_bg.add_theme_stylebox_override("panel", P2Ui.calm_box(Color(0.8, 0.62, 0.36), 0.94))
	_prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_bg.visible = false
	_hud.add_child(_prompt_bg)
	_ctx_name = P2Ui.outlined(P2Ui.text("", P2Ui.T_HEAD, P2Ui.C_GOLD), 3)
	_ctx_name.position = Vector2(16, 6)
	_ctx_name.size = Vector2(440, 30)
	_ctx_name.clip_text = true
	_prompt_bg.add_child(_ctx_name)
	_prompt = P2Ui.text("", P2Ui.T_BODY, P2Ui.C_GOLD)
	_prompt.position = Vector2(300, 10)
	_prompt.size = Vector2(460, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.clip_text = true
	_prompt_bg.add_child(_prompt)
	_ctx_chips = Control.new()
	_ctx_chips.position = Vector2(14, 50)
	_ctx_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_bg.add_child(_ctx_chips)
	_message = P2Ui.outlined(P2Ui.label("", F, P2Ui.C_TEXT), 5)
	_message.position = Vector2(140, 560)
	_message.size = Vector2(1000, 26)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.clip_text = true
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hud.add_child(_message)
	var keys := P2Ui.outlined(P2Ui.label("끌거나 휠로 고리 돌리기 · 클릭 또는 E 살펴보기 · H 회복약 · Tab 덱 · I 기호 · Esc 메뉴", F, P2Ui.C_DIM))
	keys.position = Vector2(140, 694)
	keys.size = Vector2(1000, 24)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(keys)
	_build_strip()


func _build_ring_map() -> void:
	_font = P2Ui.pixel_font(12)
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_map)
	_hud.move_child(_map, 0)
	_pixel = not P2Pixel.smooth() and not "--map-smooth" in OS.get_cmdline_user_args()
	_aa = not _pixel
	_sky = P2Starfield.new()
	if _pixel:
		var sky_vp := _pixel_canvas(_map, Vector2.ZERO, Vector2(1280, 720), false)
		var dm := ShaderMaterial.new()
		dm.shader = load("res://p2/p2_pixel_dither.gdshader")
		(sky_vp.get_parent() as Control).material = dm
		sky_vp.add_child(_sky)
		_sky.px = PIX
		_sky.setup(sector, BOARD.position + RING_C)
		_sky.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_sky.position = Vector2.ZERO
		_sky.size = Vector2(1280, 720)
		_sky.scale = Vector2.ONE / PIX
	else:
		_map.add_child(_sky)
		_sky.setup(sector, BOARD.position + RING_C)
	_board = Control.new()
	_board.position = BOARD.position
	_board.size = BOARD.size
	_board.clip_contents = true
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.gui_input.connect(_on_board_input)
	_map.add_child(_board)
	_lines = Control.new()
	_lines.size = BOARD.size
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_ring)
	if _pixel:
		_pixel_canvas(_board, Vector2.ZERO, BOARD.size, true).add_child(_lines)
		_lines.scale = Vector2.ONE / PIX
	else:
		_board.add_child(_lines)
	# 글자(핵 이름 · 위성 기호)는 픽셀 그림 위에 원래 해상도로
	_ink = Control.new()
	_ink.size = BOARD.size
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_ink)
	_board.add_child(_ink)
	_build_hub_layer()
	_legend.text += "   [color=%s]@[/color] %s" % [P2Ui.C_GOLD.to_html(false), tr("소용돌이")]

	# 고리 위 차례: 곁길(그 단계 앞, 이긴 수로 열림) → 그 단계 전투. 곁길이 둘 이상이거나 단계가 갈림길이면 소용돌이
	var steps: Array = STEPS[sector]
	var side := {}
	if (layout.get("choice", {}) as Dictionary).has("pos"):
		_side_add(side, (layout.choice.get("requires", []) as Array).size(), ["choice", "choice", "choice"])
	if (layout.get("service", {}) as Dictionary).has("pos"):
		var after := String(P2Catalog.SERVICE_AFTER[sector])
		for st in range(steps.size()):
			if (steps[st] as Array).any(func(id): return String(id).begins_with(after)):
				_side_add(side, st + 1, ["service", "service", "service"])
	if layout.encounters.has("elite"):
		_side_add(side, (layout.encounters.elite.get("requires", []) as Array).size(), ["enemy:elite", "enemy", "elite"])
	_entries = [{"key": "start", "main": true}]
	for st in range(steps.size()):
		var stops: Array = side.get(st, [])
		if stops.size() == 1:
			_entries.append({"key": String(stops[0][0]), "main": false, "kind": String(stops[0][1]), "id": String(stops[0][2])})
		elif stops.size() > 1:
			_entries.append({"key": "hub:s%d" % st, "main": false, "hub": stops, "route": false})
		var ids: Array = steps[st]
		if ids.size() == 1:
			_entries.append({"key": "enemy:" + String(ids[0]), "main": true, "kind": "enemy", "id": String(ids[0])})
		else:
			_entries.append({"key": "hub:r%d" % st, "main": true, "hub": ids.map(func(id): return ["enemy:" + String(id), "enemy", String(id)]), "route": true})
	var gap := SPAN / (_entries.size() - 1)
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var ang := gap * i
		var rs := 1.0 if bool(e.main) else SIDE_RS
		if e.has("hub"):
			_add_hub(String(e.key), e.hub, bool(e.route), ang, rs)
		elif String(e.key) == "start":
			_add_ring_node("start", "start", "", ang, rs)
		else:
			_add_ring_node(String(e.key), String(e.kind), String(e.id), ang, rs)
	_rot = 90.0 - _next_angle() - 40.0


func _side_add(side: Dictionary, at: int, stop: Array) -> void:
	if not side.has(at):
		side[at] = []
	(side[at] as Array).append(stop)


func _add_ring_node(key: String, kind: String, id: String, ang: float, rs: float) -> void:
	_add_node(key, kind, id, Vector2.ZERO, false)
	_nodes[key].ang = ang
	_nodes[key].rs = rs


# 소용돌이: 고리 위 버튼(마름모 대신 그리는 소용돌이) + 안에 펼칠 카드들
func _add_hub(hkey: String, stops: Array, route: bool, ang: float, rs: float) -> void:
	_add_node(hkey, "hub", "", Vector2.ZERO, false)
	var h: Dictionary = _nodes[hkey]
	_nodes.erase(hkey)
	(h.ring as Panel).visible = false
	(h.plate as Panel).visible = false
	h.ang = ang
	h.rs = rs
	h.route = route
	h.keys = stops.map(func(s): return String(s[0]))
	_hubs[hkey] = h
	for s in stops:
		_add_card(String(s[0]), String(s[1]), String(s[2]), hkey)


func _add_card(key: String, kind: String, id: String, hkey: String) -> void:
	var b := Button.new()
	b.flat = true
	b.size = CARD
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var bg := Panel.new()
	bg.size = CARD
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	var holder := Control.new()
	holder.size = Vector2(92, CARD.y)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(holder)
	var ring := _diamond(holder, 33.0)
	var plate := _diamond(holder, 26.0)
	var sym := P2Ui.outlined(P2Ui.text("", P2Ui.T_HEAD, Color.WHITE), 3)
	sym.size = holder.size
	sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(sym)
	var name_l := P2Ui.outlined(P2Ui.text("", P2Ui.T_HEAD, P2Ui.C_TEXT), 4)
	name_l.position = Vector2(96, 10)
	name_l.size = Vector2(CARD.x - 110, 32)
	name_l.clip_text = true
	b.add_child(name_l)
	var sub_l := P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, P2Ui.C_DIM), 4)
	sub_l.position = Vector2(96, 44)
	sub_l.size = Vector2(CARD.x - 110, 24)
	sub_l.clip_text = true
	b.add_child(sub_l)
	var st_l := P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, P2Ui.C_DIM), 3)
	st_l.position = Vector2(96, 68)
	st_l.size = Vector2(CARD.x - 110, 22)
	st_l.clip_text = true
	b.add_child(st_l)
	b.mouse_entered.connect(_hover.bind(key, true))
	b.mouse_exited.connect(_hover.bind(key, false))
	b.focus_entered.connect(_hover.bind(key, true))
	b.focus_exited.connect(_hover.bind(key, false))
	b.pressed.connect(_press.bind(key))
	b.visible = false
	_hub_layer.add_child(b)
	_nodes[key] = {"kind": kind, "id": id, "btn": b, "ring": ring, "plate": plate, "sym": sym, "name": name_l, "sub": sub_l, "st": "locked", "it": {},
		"bg": bg, "st_l": st_l, "hub": hkey}


func _build_hub_layer() -> void:
	_hub_layer = Control.new()
	_hub_layer.position = BOARD.position
	_hub_layer.size = BOARD.size
	_hub_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_hub_layer.visible = false
	_hub_layer.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_close_hub())
	_map.add_child(_hub_layer)
	_hub_lines = Control.new()
	_hub_lines.size = BOARD.size
	_hub_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hub_lines.draw.connect(_draw_hub)
	if _pixel:
		_pixel_canvas(_hub_layer, Vector2.ZERO, BOARD.size, true).add_child(_hub_lines)
		_hub_lines.scale = Vector2.ONE / PIX
	else:
		_hub_layer.add_child(_hub_lines)
	_hub_title = P2Ui.outlined(P2Ui.text("", P2Ui.T_HEAD, P2Ui.C_GOLD), 4)
	_hub_title.position = Vector2(HUB_X, 18)
	_hub_title.size = Vector2(700, 32)
	_hub_layer.add_child(_hub_title)
	_hub_hint = P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, P2Ui.C_DIM), 3)
	_hub_hint.position = Vector2(HUB_X, 50)
	_hub_hint.size = Vector2(700, 24)
	_hub_layer.add_child(_hub_hint)
	var back := P2Ui.crisp(P2Ui.button(tr("고리로 돌아가기 (Esc)"), Vector2(18, 14), Vector2(270, 44)), 20) as Button
	back.pressed.connect(_close_hub)
	_hub_layer.add_child(back)


# 소용돌이 안: 왼쪽 큰 소용돌이에서 오른쪽 카드들로 물길이 갈라진다
func _place_hub(hkey: String) -> void:
	var h: Dictionary = _hubs[hkey]
	for key in _nodes:
		if _nodes[key].has("hub"):
			(_nodes[key].btn as Button).visible = String(_nodes[key].hub) == hkey
	var keys: Array = h.keys
	var top := BOARD.size.y / 2.0 + 18.0 - (keys.size() * CARD.y + (keys.size() - 1) * CARD_GAP) / 2.0
	for i in range(keys.size()):
		var b: Button = _nodes[keys[i]].btn
		b.position = Vector2(HUB_X, top + i * (CARD.y + CARD_GAP))
	if bool(h.route):
		_hub_title.text = tr("갈림길 — 경로를 하나 고르세요")
		_hub_hint.text = tr("고른 쪽만 갈 수 있고 반대 길은 이번 원정 동안 봉인됩니다")
	else:
		_hub_title.text = tr("곁길 — 들러도 되고 지나쳐도 됩니다")
		_hub_hint.text = tr("여기 있는 곳은 모두 고를 수 있습니다 (본 길과 따로)")


func _open_hub(hkey: String) -> void:
	_dismiss_hint("map_hub")
	if _hub_open == hkey:
		return
	_hub_open = hkey
	_place_hub(hkey)
	_paint()
	var hb: Button = _hubs[hkey].btn
	_board.pivot_offset = hb.position + hb.pivot_offset
	if _hub_tw != null and _hub_tw.is_valid():
		_hub_tw.kill()
	_hub_layer.visible = true
	_hub_layer.modulate.a = 0.0
	_hub_zoom = 0.0
	_map_sfx("Other/whoosh_1.wav", -11.0, 0.7)
	_sky.warp(BOARD.position + hb.position + hb.pivot_offset)
	_hub_tw = create_tween().set_parallel()
	_hub_tw.tween_property(_board, "scale", Vector2.ONE * 2.6, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_hub_tw.tween_property(_board, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
	_hub_tw.tween_property(_hub_layer, "modulate:a", 1.0, 0.28).set_delay(0.24)
	_hub_tw.tween_property(self, "_hub_zoom", 1.0, 0.5).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hub_tw.chain().tween_callback(func() -> void: _board.visible = false)
	_sel = ""
	_current = {}
	_show_context()
	for key in _hubs[hkey].keys:
		if String(_nodes[key].st) == "open":
			(_nodes[key].btn as Button).grab_focus()
			break


func _close_hub(instant := false) -> void:
	if _hub_open == "":
		return
	_hub_open = ""
	_sel = ""
	_current = {}
	_show_context()
	if _hub_tw != null and _hub_tw.is_valid():
		_hub_tw.kill()
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and _hub_layer.is_ancestor_of(fo):
		fo.release_focus()
	_board.visible = true
	if not instant:
		_map_sfx("Other/whoosh_2.wav", -14.0, 1.15)
		_sky.warp(BOARD.position + _board.pivot_offset)
	if instant:
		_board.scale = Vector2.ONE
		_board.modulate.a = 1.0
		_hub_layer.visible = false
		return
	_hub_tw = create_tween().set_parallel()
	_hub_tw.tween_property(_board, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hub_tw.tween_property(_board, "modulate:a", 1.0, 0.3)
	_hub_tw.tween_property(_hub_layer, "modulate:a", 0.0, 0.18)
	_hub_tw.chain().tween_callback(func() -> void: _hub_layer.visible = false)
	# 소용돌이에서 나오면 키보드 초점은 고리의 다음 곳으로
	_focus_next.call_deferred()


# 점검·키보드용: key가 보이도록 소용돌이를 열거나 닫고 끝날 때까지 기다린다
func reveal(key: String) -> void:
	var want := String(_nodes[key].get("hub", "")) if _nodes.has(key) else ""
	if want == _hub_open:
		return
	if want == "":
		_close_hub()
	else:
		_open_hub(want)
	await get_tree().create_timer(0.6).timeout


func _hub_state(h: Dictionary) -> String:
	var sts: Array = (h.keys as Array).map(func(k): return String(_nodes[k].st))
	if sts.has("open"):
		return "open"
	if sts.all(func(s): return s == "done" or s == "sealed"):
		return "done"
	return "locked"


# 경로를 이미 정한 갈림길은 남은 한 곳으로 바로 간다
func _hub_direct(h: Dictionary) -> String:
	if not bool(h.route):
		return ""
	var live: Array = (h.keys as Array).filter(func(k): return String(_nodes[k].st) != "sealed")
	if live.size() == 1 and (h.keys as Array).size() > 1:
		return String(live[0])
	return ""


func _paint_hubs() -> void:
	for hkey in _hubs:
		var h: Dictionary = _hubs[hkey]
		h.st = _hub_state(h)
		var chosen := _hub_direct(h)
		var name_col := P2Ui.C_TEXT if h.st == "open" else (P2Ui.C_DIM.darkened(0.2) if h.st == "done" else Color(0.60, 0.58, 0.54))
		var title := tr("갈림길") if bool(h.route) else tr("곁길")
		var sub := ""
		if chosen != "":
			title = String(_look_of(_nodes[chosen])[2])
			sub = String(_look_of(_nodes[chosen])[3])
		else:
			sub = "  ".join((h.keys as Array).map(func(k): return String(_look_of(_nodes[k])[0]) if String(_nodes[k].st) != "done" else "✓"))
			sub = (tr("경로 둘 · 하나만") if bool(h.route) else tr("%d곳") % (h.keys as Array).size()) if h.st != "done" else tr("끝남")
		(h.name as Label).text = title
		(h.name as Label).add_theme_color_override("font_color", name_col)
		(h.sub as Label).text = sub
		(h.sub as Label).add_theme_color_override("font_color", P2Ui.C_GOLD if h.st == "open" else name_col)
	for key in _nodes:
		var n: Dictionary = _nodes[key]
		if not n.has("bg"):
			continue
		var edge: Color = {"open": P2Ui.C_GOLD, "done": SYM_DONE.darkened(0.35), "sealed": Color(0.5, 0.2, 0.2)}.get(String(n.st), Color(0.36, 0.38, 0.42))
		if key == _sel:
			edge = edge.lightened(0.3)
		(n.bg as Panel).add_theme_stylebox_override("panel", P2Ui.box(Color(0.07, 0.07, 0.09, 0.96) if n.st != "open" else Color(0.11, 0.10, 0.09, 0.98), edge, 3 if key == _sel else 2))
		var it: Dictionary = n.it
		var line := ""
		match String(n.st):
			"open":
				line = tr("열림 — 눌러서 살펴보기")
			"done":
				line = tr("끝남")
			"sealed":
				line = tr("봉인됨")
			_:
				line = String(it.get("prompt", tr("잠김"))).trim_prefix("상인 — ")
		(n.st_l as Label).text = line
		(n.st_l as Label).add_theme_color_override("font_color", {"open": Color(0.72, 0.97, 0.96), "sealed": Color(0.8, 0.36, 0.3)}.get(String(n.st), P2Ui.C_DIM))


func _ring_items() -> Array:
	var out: Array = []
	for key in _nodes:
		if _nodes[key].has("ang"):
			out.append([key, _nodes[key]])
	for key in _hubs:
		out.append([key, _hubs[key]])
	return out


func _entry_state(key: String) -> String:
	if _hubs.has(key):
		return String(_hubs[key].get("st", "locked"))
	return String(_nodes[key].st)


func _entry_ang(key: String) -> float:
	return float((_hubs[key] if _hubs.has(key) else _nodes[key]).ang)


# 고리 위 자리(타원): ang는 고리 기준 각도, rs는 고리 반지름 배율. 화면에서 아래(90도)가 앞이다
func _ring_pos(ang: float, rs: float, k := 1.0) -> Vector2:
	var th := deg_to_rad(ang + _rot)
	return RING_C + Vector2(cos(th) * RX * rs * k, sin(th) * RY * rs * k)


func _depth(ang: float) -> float:
	return (sin(deg_to_rad(ang + _rot)) + 1.0) / 2.0


# 다음에 갈 본 길 각도(열린 단계, 없으면 마지막 끝난 곳)
func _next_angle() -> float:
	var last := 0.0
	for e in _entries:
		if not bool(e.main):
			continue
		var st := _entry_state(String(e.key))
		if st == "open":
			return _entry_ang(String(e.key))
		if st == "done":
			last = _entry_ang(String(e.key))
	return last


func _spin_to(target: float, dur := 1.0) -> void:
	if _rot_tw != null and _rot_tw.is_valid():
		_rot_tw.kill()
	target = _rot + wrapf(target - _rot, -180.0, 180.0)
	if absf(target - _rot) < 0.3:
		_rot = target
		return
	_rot_tw = create_tween()
	_rot_tw.tween_property(self, "_rot", target, dur).set_trans(Tween.TRANS_CUBIC if dur > 0.5 else Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT if dur > 0.5 else Tween.EASE_OUT)


# 이겨서 다음 곳이 바뀌었을 때만 돈다(직접 돌려 본 고리를 창 하나 닫을 때마다 되돌리지 않음)
func _spin_to_next() -> void:
	var a := _next_angle()
	if a == _spun_for:
		return
	_spun_for = a
	_spin_to(90.0 - a)


func _front_entry() -> int:
	var best := 0
	var best_d := 999.0
	for i in range(_entries.size()):
		var d := absf(wrapf(_entry_ang(String(_entries[i].key)) + _rot - 90.0, -180.0, 180.0))
		if d < best_d:
			best_d = d
			best = i
	return best


func _snap_to(i: int) -> void:
	i = clampi(i, 0, _entries.size() - 1)
	var key := String(_entries[i].key)
	_map_sfx("UI/select_2.wav", -17.0, 1.35)
	_spin_to(90.0 - _entry_ang(key), 0.32)
	if key != "start":
		_hover(key, true)


func _on_board_input(e: InputEvent) -> void:
	if locked or model.run.is_empty() or _hub_open != "":
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_rot = {"x": mb.position.x, "rot": _rot, "moved": false}
			else:
				if not _drag_rot.is_empty() and bool(_drag_rot.moved):
					_snap_to(_front_entry())
					_dismiss_hint("map_ring")
				_drag_rot = {}
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_snap_to(_front_entry() + (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			_dismiss_hint("map_ring")
	elif e is InputEventMouseMotion and not _drag_rot.is_empty() and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		if bool(_drag_rot.moved):
			_snap_to(_front_entry())
		_drag_rot = {}
	elif e is InputEventMouseMotion and not _drag_rot.is_empty():
		var dx := (e as InputEventMouseMotion).position.x - float(_drag_rot.x)
		if absf(dx) > 6.0:
			_drag_rot.moved = true
		if bool(_drag_rot.moved):
			if _rot_tw != null and _rot_tw.is_valid():
				_rot_tw.kill()
			_rot = float(_drag_rot.rot) - rad_to_deg(dx / RX)


# 노드 자리·크기·밝기·앞뒤 순서: 앞(아래)일수록 크고 밝고 위에 그린다
func _layout_ring() -> void:
	var order: Array = []
	var icons: Array = []
	for item in _ring_items():
		var key := String(item[0])
		var n: Dictionary = item[1]
		var b: Button = n.btn
		var d := _depth(float(n.ang))
		b.position = _ring_pos(float(n.ang), float(n.rs)) - b.size / 2.0
		b.scale = Vector2.ONE * lerpf(0.8, 1.0, d) * (0.88 if float(n.rs) < 1.0 else 1.0)
		var v := lerpf(0.68, 1.0, d)
		b.modulate = Color(v, v, v)
		var sn := sin(deg_to_rad(float(n.ang) + _rot))
		var up := sn > 0.2 if float(n.rs) < 1.0 else sn < -0.35
		var r := b.size.x * 0.34 * b.scale.x
		icons.append([key, Rect2(b.position + b.pivot_offset - Vector2(r, r), Vector2(r, r) * 2.0)])
		var pri := d + (8.0 if key == _sel else 0.0) + (4.0 if _entry_state(key) == "open" else 0.0) + (2.0 if RunModel.is_boss(String(n.id)) else 0.0)
		order.append([d, b, pri, key, up, n])
	# 글자는 고리 바깥쪽(곁길은 핵 쪽)으로 달고, 고른 곳 → 갈 수 있는 곳 → 보스 → 앞쪽 순으로 자리를 잡는다.
	# 막히면 반대쪽에 달고, 그래도 다른 글자·노드를 덮게 되면 흐려진다(올리면 다시 보임). 핵 이름은 맨 마지막
	var by_pri := order.duplicate()
	by_pri.sort_custom(func(x, y): return float(x[2]) > float(y[2]))
	var taken: Array = []
	var fade := clampf(get_process_delta_time() * 8.0, 0.0, 1.0)
	for o in by_pri:
		var n: Dictionary = o[5]
		var b: Button = n.btn
		var want_sub := float(o[0]) > 0.45 or float(o[2]) >= 2.0
		var ok := false
		var ok_sub := false
		var rn := Rect2()
		var rsub := Rect2()
		for up in [bool(o[4]), not bool(o[4])]:
			_set_label_side(n, up)
			rn = _label_rect(b, n.name)
			rsub = _label_rect(b, n.sub)
			ok = _label_free(rn, taken, icons, o[3])
			ok_sub = ok and want_sub and _label_free(rsub, taken, icons, o[3])
			if ok and (ok_sub or not want_sub):
				break
		if not ok:
			_set_label_side(n, bool(o[4]))
		if ok:
			taken.append(rn)
		if ok_sub:
			taken.append(rsub)
		for pair in [[n.name, ok], [n.sub, ok_sub]]:
			var l: Label = pair[0]
			l.modulate.a = lerpf(l.modulate.a, 1.0 if pair[1] else 0.0, fade)
			l.visible = l.modulate.a > 0.02
	_core_lbl = taken.all(func(t): return not (t as Rect2).intersects(_core_rect()))
	order.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	for i in range(order.size()):
		if (order[i][1] as Button).get_index() != i + 2:
			_board.move_child(order[i][1], i + 2)


func _core_rect() -> Rect2:
	var cw := _font.get_string_size("균열의 핵", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	return Rect2(RING_C + Vector2(-cw / 2.0, -54.0), Vector2(cw, 16.0))


func _set_label_side(n: Dictionary, up: bool) -> void:
	var b: Button = n.btn
	(n.name as Label).position.y = -54.0 if up else b.size.y + 6.0
	(n.sub as Label).position.y = -30.0 if up else b.size.y + 30.0


func _label_rect(b: Button, l: Label) -> Rect2:
	var w := l.get_minimum_size().x * b.scale.x
	var top := b.position.y + b.pivot_offset.y + (l.position.y - b.pivot_offset.y) * b.scale.y
	return Rect2(b.position.x + b.pivot_offset.x - w / 2.0, top + 2.0 * b.scale.y, w, 20.0 * b.scale.y).grow(3.0)


func _label_free(r: Rect2, taken: Array, icons: Array, own: String) -> bool:
	if r.size.x < 8.0:
		return true
	if not Rect2(Vector2.ZERO, BOARD.size).encloses(r.grow(-3.0)):
		return false
	for t in taken:
		if r.intersects(t):
			return false
	for ic in icons:
		if String(ic[0]) != own and r.intersects(ic[1]):
			return false
	return true


func _ellipse(k: float, n := 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var th := TAU * i / n
		pts.append(RING_C + Vector2(cos(th) * RX * k, sin(th) * RY * k))
	return pts


func _arc_points(a0: float, a1: float, rs: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		pts.append(_ring_pos(lerpf(a0, a1, float(i) / n), rs))
	return pts


# 흐르는 물결: 꺾은선을 따라 짧은 밝은 마디가 앞으로 흐른다
func _flow_dashes(c: Control, pts: PackedVector2Array) -> void:
	var off := fmod(_flow * 36.0, 30.0)
	var walked := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var len_ := a.distance_to(b)
		var t := fposmod(off - walked, 30.0)
		while t < len_:
			var dir := (b - a) / maxf(len_, 0.001)
			c.draw_line(a + dir * t, a + dir * minf(t + 11.0, len_), Color(0.72, 0.97, 0.96, 0.95), 2.0)
			t += 30.0
		walked += len_


func _path_line(c: Control, pts: PackedVector2Array, st: String) -> void:
	match st:
		"done":
			c.draw_polyline(pts, C_STREAM.darkened(0.25), 6.0, _aa)
		"open":
			c.draw_polyline(pts, C_STREAM, 6.0, _aa)
			_flow_dashes(c, pts)
		"sealed":
			c.draw_polyline(pts, Color(0.42, 0.15, 0.15, 0.85), 4.0, _aa)
		_:
			c.draw_polyline(pts, Color(0.30, 0.34, 0.38, 0.75), 4.0, _aa)


# 소용돌이: 세 갈래 팔이 돌며 가운데로 빨려 든다
func _spiral(c: Control, at: Vector2, r: float, col: Color, phase: float, a := 1.0) -> void:
	c.draw_circle(at, r * 1.15, Color(col, 0.07 * a))
	c.draw_circle(at, r * 0.8, Color(col, 0.08 * a))
	for arm in range(3):
		var pts := PackedVector2Array()
		for i in range(28):
			var t := float(i) / 27.0
			var th := phase + TAU * arm / 3.0 + t * 4.6
			pts.append(at + Vector2(cos(th), sin(th)) * r * (1.0 - 0.86 * t))
		c.draw_polyline(pts, Color(col, 0.85 * a), maxf(2.0, r * 0.07), _aa)
	c.draw_circle(at, r * 0.16, Color(col.lightened(0.55), a))


# ── 행성 노드: 종류마다 색·크기·고리, 상태는 밝기·빛으로 (기호는 버튼 글자가 그대로 위에) ──────────────

func _planet_look(n: Dictionary) -> Dictionary:
	var kind := String(n.kind)
	var id := String(n.id)
	if kind == "start":
		return {"star": true}
	if String((n.it as Dictionary).get("kind", "")) == "portal":
		return {"base": Color("#3a78b4"), "band": Color("#8fd0ff"), "ring": Color("#bfe6ff"), "r": 1.05}
	match kind:
		"service":
			return {"base": Color("#9c7629"), "band": Color("#e0b85a"), "ring": Color("#f2c461"), "r": 0.8}
		"choice":
			return {"base": Color("#2b7a82"), "band": Color("#8fe0d8"), "r": 0.82}
	match id:
		"elite":
			if String(layout.encounters.elite.get("kind", "")) == "mimic":
				return {"base": Color("#5a2c74"), "band": Color("#a070c8"), "r": 0.92}
			return {"base": Color("#8a2830"), "band": Color("#d0604a"), "r": 0.95}
		"boss", "hboss":
			return {"base": Color("#55388c"), "band": Color("#9a7ad0"), "ring": Color("#e2c080"), "r": 1.3}
		"xboss":
			return {"base": Color("#46101e"), "band": Color("#c03040"), "ring": Color("#ff8a5a"), "r": 1.4}
	# 필수 전투: 바위 행성. 노드마다 색을 조금씩 달리
	var hue := float(hash(id) % 100) / 100.0
	return {"base": Color("#74503c").lerp(Color("#5c5a4a"), hue), "band": Color("#a8784e").lerp(Color("#8c8a6a"), hue), "r": 1.0}


func _planet_tint(col: Color, st: String, v: float) -> Color:
	match st:
		"done":
			col = col.lerp(Color(0.3, 0.36, 0.36), 0.62)
		"locked":
			col = col.darkened(0.18).lerp(Color(0.3, 0.31, 0.36), 0.25)
		"sealed":
			col = col.lerp(Color(0.32, 0.07, 0.07), 0.6)
	return Color(col.r * v, col.g * v, col.b * v, col.a)


func _draw_planets(c: Control) -> void:
	var list: Array = []
	for key in _nodes:
		var n: Dictionary = _nodes[key]
		if n.has("ang"):
			list.append([_depth(float(n.ang)), key, n])
	list.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var pulse := 0.5 + 0.5 * sin(_flow * 3.0)
	for e in list:
		var n: Dictionary = e[2]
		var b: Button = n.btn
		var look := _planet_look(n)
		var at := b.position + b.pivot_offset
		var st := String(n.st)
		var v := lerpf(0.68, 1.0, float(e[0]))
		if bool(look.get("star", false)):
			var r0 := 8.0 * b.scale.x
			c.draw_circle(at, r0 * 2.2, Color(0.6, 0.9, 1.0, 0.08))
			c.draw_circle(at, r0, Color(0.78, 0.95, 1.0, 0.95 * v))
			c.draw_line(at - Vector2(r0 * 2.0, 0), at + Vector2(r0 * 2.0, 0), Color(0.8, 0.95, 1.0, 0.5 * v), 1.0)
			c.draw_line(at - Vector2(0, r0 * 2.0), at + Vector2(0, r0 * 2.0), Color(0.8, 0.95, 1.0, 0.5 * v), 1.0)
			continue
		var R := 30.0 * float(look.r) * b.scale.x
		var base := _planet_tint(look.base, st, v)
		var band := _planet_tint(look.band, st, v)
		var light := base.lightened(0.3)
		var dark := base.darkened(0.5)
		if st == "open":
			c.draw_circle(at, R * 1.55, Color(light, 0.06 + 0.05 * pulse))
			c.draw_circle(at, R * 1.25, Color(light, 0.1))
		if look.has("ring"):
			_planet_ring(c, at, R, _planet_tint(look.ring, st, v), true)
		c.draw_circle(at, R, dark)
		var cc := at - Vector2(R * 0.1, R * 0.1)
		var rr := R * 0.86
		c.draw_circle(cc, rr, base)
		for k in [-0.42, -0.05, 0.32]:
			var yy: float = rr * k
			var hw := sqrt(maxf(0.0, rr * rr - yy * yy)) * 0.94
			c.draw_line(cc + Vector2(-hw, yy), cc + Vector2(hw, yy), Color(band, 0.5), maxf(2.0, R * 0.13))
		c.draw_circle(at - Vector2(R * 0.36, R * 0.36), R * 0.26, Color(light, 0.75))
		c.draw_arc(at, R, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 2.0)
		if look.has("ring"):
			_planet_ring(c, at, R, _planet_tint(look.ring, st, v), false)
		# 고른 곳은 금빛 궤도, 갈 수 있는 곳은 숨 쉬는 궤도
		var key := String(e[1])
		if key == _sel or st == "open":
			var oc := P2Ui.C_GOLD if key == _sel else light.lightened(0.3)
			c.draw_arc(at, R + 7.0, 0.0, TAU, 48, Color(oc, 0.95 if key == _sel else 0.35 + 0.4 * pulse), 2.0)


# 행성 고리: 뒤 반쪽은 행성 뒤에, 앞 반쪽은 앞에
func _planet_ring(c: Control, at: Vector2, R: float, col: Color, back: bool) -> void:
	var pts := PackedVector2Array()
	var a0 := PI if back else 0.0
	for i in range(25):
		var th := a0 + PI * float(i) / 24.0
		pts.append(at + Vector2(cos(th) * R * 1.7, sin(th) * R * 0.42).rotated(-0.25))
	c.draw_polyline(pts, Color(col, 0.85 if not back else 0.55), maxf(2.0, R * 0.12), _aa)


# 소용돌이 둘레를 도는 위성: 안에 든 곳들의 기호(상태 색). 들어가 보지 않아도 무엇이 있는지 보인다
func _moons(c: Control, h: Dictionary, at: Vector2, s: float) -> void:
	var keys: Array = h.keys
	for m in range(keys.size()):
		var n: Dictionary = _nodes[keys[m]]
		var th := -_flow * 0.6 + TAU * m / keys.size()
		var q := at + Vector2(cos(th) * 50.0, sin(th) * 24.0) * s
		var col: Color = {"open": P2Ui.C_GOLD, "done": SYM_DONE, "sealed": Color(0.8, 0.36, 0.3)}.get(String(n.st), Color(0.55, 0.58, 0.64))
		var r := 12.0 * s
		c.draw_circle(q, r, Color(0.07, 0.08, 0.11, 0.96))
		c.draw_arc(q, r, 0.0, TAU, 20, col, 2.0, _aa)


# 위성 기호와 핵 이름: 픽셀 그림 위에 원래 해상도 글자로 (위성 자리는 _moons와 같은 계산)
func _draw_ink() -> void:
	var c := _ink
	for hkey in _hubs:
		var h: Dictionary = _hubs[hkey]
		var b: Button = h.btn
		var at := b.position + b.pivot_offset
		var s := b.scale.x
		var keys: Array = h.keys
		for m in range(keys.size()):
			var n: Dictionary = _nodes[keys[m]]
			var th := -_flow * 0.6 + TAU * m / keys.size()
			var q := at + Vector2(cos(th) * 50.0, sin(th) * 24.0) * s
			var col: Color = {"open": P2Ui.C_GOLD, "done": SYM_DONE, "sealed": Color(0.8, 0.36, 0.3)}.get(String(n.st), Color(0.55, 0.58, 0.64))
			var sym := "✓" if String(n.st) == "done" else String(_look_of(n)[0])
			var w := _font.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			c.draw_string(_font, q + Vector2(-w / 2.0, 5.0), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	if _core_lbl:
		var cp := _core_rect().position + Vector2(0, 12)
		c.draw_string_outline(_font, cp, "균열의 핵", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
		c.draw_string(_font, cp, "균열의 핵", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.65, 0.55, 0.9))


func _pixel_canvas(parent: Control, pos: Vector2, size: Vector2, transparent: bool) -> SubViewport:
	return P2Pixel.canvas(parent, pos, size, transparent)


func _hub_color(h: Dictionary) -> Color:
	match String(h.get("st", "locked")):
		"open":
			return P2Ui.C_GOLD if bool(h.route) else SYM_CHOICE
		"done":
			return SYM_DONE.darkened(0.3)
	return Color(0.45, 0.48, 0.54)


func _draw_ring() -> void:
	var c := _lines
	var cur := int(SECTOR_IDX.get(sector, 0))
	# 다른 구간 고리: 지나온 곳(바깥, 끝남) · 갈 곳(안쪽, 아직 모름)
	for i in range(3):
		if i == cur:
			continue
		var k := pow(RING_K, i - cur)
		var done := i < cur
		var col := C_STREAM.darkened(0.25) if done else Color(0.42, 0.46, 0.52)
		c.draw_polyline(_ellipse(k), Color(col, 0.45 if done else 0.3), 3.0 if done else 2.0, _aa)
		var n: int = RING_DOTS[i]
		for j in range(n):
			var th := deg_to_rad(SPAN / (n - 1) * j + _rot * (0.6 if not done else 1.0))
			var q := RING_C + Vector2(cos(th) * RX * k, sin(th) * RY * k)
			c.draw_circle(q, 5.0 * minf(k, 1.6), Color(col, 0.6 if done else 0.4))
	# 균열의 핵: 천천히 도는 빛살 + 숨 쉬는 빛
	var pulse := 0.5 + 0.5 * sin(_flow * 2.2)
	for i in range(12):
		var th := _flow * 0.12 + TAU * i / 12.0
		var dir := Vector2(cos(th), sin(th) * 0.6)
		var reach := 64.0 + 26.0 * sin(_flow * 0.9 + i * 1.7)
		c.draw_line(RING_C + dir * 22.0, RING_C + dir * reach, Color(1.0, 0.5, 0.36, 0.05 + 0.03 * pulse), 4.0)
	c.draw_circle(RING_C, 30.0 + 6.0 * pulse, Color(0.9, 0.25, 0.2, 0.12 + 0.08 * pulse))
	c.draw_circle(RING_C, 18.0, Color(0.85, 0.22, 0.18, 0.55))
	c.draw_circle(RING_C, 9.0 + 2.0 * pulse, Color("#ff8a5a"))
	# 지금 구간 고리 바탕(바깥에 옅은 빛 띠)과 앞쪽(지금 자리) 빛
	c.draw_polyline(_ellipse(1.0), Color(C_STREAM, 0.045), 26.0, _aa)
	c.draw_polyline(_ellipse(1.0), Color(C_STREAM, 0.14), 10.0, _aa)
	var front := RING_C + Vector2(0, RY)
	c.draw_circle(front, 70.0, Color(0.55, 0.85, 0.85, 0.05))
	c.draw_circle(front, 44.0, Color(0.55, 0.85, 0.85, 0.06))
	# 본 길: 본 길끼리 고리를 따라 잇고 다음 곳의 상태로 칠한다. 곁길은 고리에서 안쪽으로 짧게 갈라진다
	var prev := ""
	for e in _entries:
		var key := String(e.key)
		if not bool(e.main):
			var a := _entry_ang(key)
			_path_line(c, PackedVector2Array([_ring_pos(a, 1.0), _ring_pos(a, SIDE_RS)]), _entry_state(key))
			continue
		if prev != "":
			_path_line(c, _arc_points(_entry_ang(prev), _entry_ang(key), 1.0), _entry_state(key))
		prev = key
	for e in _entries:
		if not bool(e.main):
			var q := _ring_pos(_entry_ang(String(e.key)), 1.0)
			c.draw_circle(q, 6.0, Color(0.16, 0.20, 0.22))
			c.draw_arc(q, 6.0, 0.0, TAU, 16, C_STREAM.darkened(0.2), 2.0)
	_draw_planets(c)
	for hkey in _hubs:
		var h: Dictionary = _hubs[hkey]
		var b: Button = h.btn
		var spd := 1.6 if String(h.get("st", "")) == "open" else 0.4
		_spiral(c, b.position + b.pivot_offset, 30.0 * b.scale.x, _hub_color(h), -_flow * spd, 1.0 if hkey != _sel else 1.2)
		_moons(c, h, b.position + b.pivot_offset, b.scale.x)
	# 보스 뒤: 다음 구간(안쪽 고리)으로 내려가는 물길
	if cur < 2:
		var bkey := String(_entries.back().key)
		var a := _entry_ang(bkey)
		var pts2 := PackedVector2Array()
		for i in range(19):
			var t := float(i) / 18.0
			pts2.append(_ring_pos(a + 40.0 * t, lerpf(1.0, RING_K, t)))
		var open_down := _entry_state(bkey) == "done"
		c.draw_polyline(pts2, Color(C_STREAM, 0.7) if open_down else Color(0.32, 0.36, 0.42, 0.45), 4.0 if open_down else 2.0, _aa)
		if open_down:
			_flow_dashes(c, pts2)


func _draw_hub() -> void:
	if _hub_open == "":
		return
	var c := _hub_lines
	var h: Dictionary = _hubs[_hub_open]
	var at := Vector2(200, BOARD.size.y / 2.0 + 18.0)
	var r := 96.0 * _hub_zoom
	_spiral(c, at, r, _hub_color(h), -_flow * 1.4)
	for key in h.keys:
		var b: Button = _nodes[key].btn
		var to := b.position + Vector2(0, CARD.y / 2.0)
		var from := at + Vector2(r * 0.95, 0)
		var pts := PackedVector2Array()
		for i in range(25):
			var t := float(i) / 24.0
			var p := from.bezier_interpolate(from + Vector2(90, 0), to - Vector2(90, 0), to, t)
			pts.append(p)
		_path_line(c, pts, String(_nodes[key].st))
		c.draw_circle(to, 6.0, Color(0.16, 0.20, 0.22))


# ── 고리 지도 윗띠 · 아래 카드 · 소리 ───────────────────────────────────────────────
# 윗띠는 전투 화면과 같은 얇은 돌 띠(직업 · 체력 · 금화 셋 · 제목 · 물약 · 덱 · 메뉴), 아래 카드는 이름 + 아이콘 칩 한 줄

func _build_strip() -> void:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(strip)
	for part in [["top_left", Vector2.ZERO, Vector2(24, 42)], ["top_strip", Vector2(24, 0), Vector2(1232, 42)], ["top_right", Vector2(1256, 0), Vector2(24, 42)]]:
		var t := TextureRect.new()
		t.texture = P2Ui.kit_tex(String(part[0]))
		t.stretch_mode = TextureRect.STRETCH_TILE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.position = part[1]
		t.size = part[2]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(t)
	_strip_l.cls = _strip_label(strip, Vector2(14, 8), 200.0, P2Ui.C_TEXT)
	for spec in [["hp", "hud_heart_compact", 232.0, 110.0], ["gold", "hud_coin_compact", 356.0, 300.0], ["potion", "potion_health_compact", 820.0, 40.0],
			["mana_potion", "potion_mana_compact", 900.0, 40.0], ["deck", "hud_deck_compact", 1110.0, 90.0]]:
		var ic := P2Ui.tex_icon(P2Ui.kit_tex(String(spec[1])), 30)
		ic.position = Vector2(float(spec[2]), 6)
		strip.add_child(ic)
		_strip_l[spec[0]] = _strip_label(strip, Vector2(float(spec[2]) + 38.0, 8), float(spec[3]), P2Ui.C_TEXT)
	_lv_btn = Button.new()
	_lv_btn.flat = true
	_lv_btn.focus_mode = Control.FOCUS_NONE
	_lv_btn.position = Vector2(700, 3)
	_lv_btn.size = Vector2(112, 36)
	_lv_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var lvi := P2Ui.tex_icon(P2Ui.kit_tex("status_crit", 1), 26)
	lvi.position = Vector2(2, 5)
	_lv_btn.add_child(lvi)
	_lv_label = _strip_label(_lv_btn, Vector2(32, 5), 80.0, P2Ui.C_TEXT)
	_lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lv_btn.pressed.connect(func() -> void:
		if not locked:
			level_requested.emit())
	strip.add_child(_lv_btn)
	var gear := Button.new()
	gear.flat = true
	gear.focus_mode = Control.FOCUS_NONE
	gear.position = Vector2(1228, 3)
	gear.size = Vector2(36, 36)
	gear.tooltip_text = tr("메뉴 (Esc)")
	gear.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var gi := P2Ui.tex_icon(load(P2Ui.GUI2X + "Mini icons/Icon_19.png"), 28)
	gi.position = Vector2(4, 4)
	gear.add_child(gi)
	gear.pressed.connect(func() -> void:
		if not locked:
			menu_requested.emit())
	strip.add_child(gear)
	# 기호 설명은 평소엔 숨기고 i 단추(또는 I 키)로 편다
	_info = Button.new()
	_info.text = "i"
	_info.position = Vector2(1064, 7)
	_info.size = Vector2(28, 28)
	_info.focus_mode = Control.FOCUS_NONE
	_info.add_theme_font_override("font", P2Ui.bold_font(P2Ui.T_HEAD))
	_info.add_theme_font_size_override("font_size", P2Ui.T_HEAD)
	_info.add_theme_color_override("font_color", P2Ui.C_GOLD)
	_info.add_theme_color_override("font_hover_color", Color("#ffe9a8"))
	_info.add_theme_color_override("font_pressed_color", Color("#ffe9a8"))
	_paint_info(false)
	_info.tooltip_text = tr("기호 설명 (I)")
	_info.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_info.pressed.connect(_toggle_legend)
	strip.add_child(_info)


# 교전 시작: 지도(우주·고리)만 고른 곳으로 줌한다(위 띠·아래 칸은 그대로). 고른 곳의 화면 자리를 돌려준다. 다시 보이면 원래 크기
func dive(id: String, dur: float) -> Vector2:
	var at := Vector2(640, 360)
	var n: Dictionary = _nodes.get("enemy:" + id, {})
	if n.has("btn") and is_instance_valid(n.btn) and (n.btn as Control).is_visible_in_tree():
		at = (n.btn as Control).get_global_rect().get_center()
	if _map != null:
		_map.pivot_offset = at
		var t := _map.create_tween()
		t.tween_property(_map, "scale", Vector2.ONE * 1.35, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return at


# 구간 이동 1: 지금 지도에서 안쪽 고리(다음 구간) 쪽으로 빨려 들어간다(별이 늘어나는 워프, 휙). 끝나면 호스트가 막을 덮는다
func zoom_inward(dur := 1.0) -> void:
	var at := BOARD.position + RING_C
	if _map == null:
		return
	if _sky != null:
		_sky.warp(at)
	_map_sfx("Other/whoosh_1.wav", -8.0, 0.55)
	_map.pivot_offset = at
	var t := _map.create_tween().set_parallel()
	t.tween_property(_map, "scale", Vector2.ONE * 2.6, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(_map, "modulate", Color(1.4, 1.4, 1.6, 1.0), dur).set_ease(Tween.EASE_IN)
	await t.finished


# 구간 이동 2: 새 구간 지도가 가까이서 물러나며 자리 잡고(바깥 고리 = 이번 구간), 가운데에 구간 이름판
func arrive(dur := 1.1) -> void:
	var at := BOARD.position + RING_C
	if _map != null:
		_map.pivot_offset = at
		_map.scale = Vector2.ONE * 1.8
		_map.modulate = Color(1.5, 1.5, 1.7, 1.0)
		var t := _map.create_tween().set_parallel()
		t.tween_property(_map, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_map, "modulate", Color.WHITE, dur * 0.8)
	if _sky != null:
		_sky.warp(at)
	_map_sfx("Other/whoosh_2.wav", -10.0, 0.8)
	_sector_card()


func _sector_card() -> void:
	var idx := int(SECTOR_IDX.get(sector, 0))
	var accent: Color = [P2Ui.C_GOLD, Color("#7fb8ff"), Color("#ff7a6a")][idx]
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(340, 250)
	card.size = Vector2(600, 150)
	card.pivot_offset = card.size / 2.0
	_hud.add_child(card)
	var band := ColorRect.new()
	band.color = Color(0.02, 0.02, 0.05, 0.78)
	band.position = Vector2(0, 26)
	band.size = Vector2(600, 100)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	for y in [26.0, 124.0]:
		var line := ColorRect.new()
		line.color = accent
		line.position = Vector2(0, y)
		line.size = Vector2(600, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(line)
	var parts := String(P2Catalog.SECTOR_NAMES.get(sector, sector)).split(" · ")
	var big := P2Ui.outlined(P2Ui.text(parts[0], P2Ui.T_BIG, accent), 4)
	big.position = Vector2(0, 34)
	big.size = Vector2(600, 48)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(big)
	var sub := P2Ui.outlined(P2Ui.text(tr("더 깊이 — %s") % (parts[1] if parts.size() > 1 else ""), P2Ui.T_BODY, P2Ui.C_TEXT), 3)
	sub.position = Vector2(0, 88)
	sub.size = Vector2(600, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(sub)
	card.modulate.a = 0.0
	card.scale = Vector2(1.25, 1.25)
	var t := card.create_tween()
	t.tween_interval(0.35)
	t.tween_property(card, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.2)
	t.tween_property(card, "modulate:a", 0.0, 0.4)
	t.tween_callback(card.queue_free)


# 전투 화면이 떠 있는 동안 지도와 HUD(별도 층)를 내려 둔다
func set_suspended(value: bool) -> void:
	visible = not value
	hud_layer.visible = not value
	process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if not value and _map != null:
		_map.scale = Vector2.ONE


func _toggle_legend() -> void:
	var on := not _legend.visible
	_legend.visible = on
	_legend_bg.visible = on
	_paint_info(on)
	P2Ui.ui_sound("click")
	if on:
		P2Ui.pop_in(_legend_bg)


func _paint_info(on: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var b := P2Ui.calm_box(P2Ui.C_GOLD if on or st == "hover" else P2Ui.C_EDGE, 0.95)
		b.set_content_margin_all(0)
		_info.add_theme_stylebox_override(st, b)


func _strip_label(parent: Control, pos: Vector2, w: float, col: Color) -> Label:
	var l := P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, col), 3)
	l.position = pos
	l.size = Vector2(w, 26)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(l)
	return l


func _update_strip() -> void:
	if _strip_l.is_empty():
		return
	var run := model.run
	var risk := model.at_risk_summary()
	var dname := String(P2Catalog.diff_of(String(run.get("diff", "normal"))).name)
	var mods := " ".join(PackedStringArray((run.get("mods", []) as Array).map(func(x): return String(P2Catalog.MOD[x].short))))
	(_strip_l.cls as Label).text = String(P2Catalog.CLASSES[run.class_id].name) + " · " + dname + (" " + mods if mods != "" else "")
	(_strip_l.hp as Label).text = "%d/%d" % [int(run.hp), int(run.max_hp)]
	(_strip_l.gold as Label).text = tr("미확정 %d") % int(risk.pending_gold)
	(_strip_l.gold as Label).tooltip_text = tr("금화 구분\n· 미확정 %d — 이번 구간에서 번 금화. 원정 상인은 이것만 씀. 구간 보스를 이기면 확정, 지거나 포기하면 잃음\n· 확정 %d — 이긴 구간 보스 정산분 (점수에 들어감)") % [int(risk.pending_gold), int(risk.banked_gold)]
	(_strip_l.gold as Label).mouse_filter = Control.MOUSE_FILTER_STOP
	(_strip_l.potion as Label).text = str(model.potion_count("hp_potion"))
	(_strip_l.potion as Label).tooltip_text = tr("원정 물약 칸 %d개. [H] 회복약: 체력 +%d") % [P2Catalog.POTION_CAP, int(run.loadout.get("potion_heal", 6))]
	(_strip_l.mana_potion as Label).text = str(model.potion_count("mana_potion"))
	(_strip_l.deck as Label).text = tr("덱 %d") % (run.deck as Array).size()
	var tnames: Array = (run.get("traits", []) as Array).map(func(t): return String(P2Catalog.TRAITS[t].name))
	(_strip_l.deck as Label).tooltip_text = tr("덱 %d장 · 유물 %d/%d%s · Tab 덱·유물 보기") % [(run.deck as Array).size(), (run.relics as Array).size(), P2Catalog.relic_capacity(run),
		" · 특성 " + ", ".join(PackedStringArray(tnames)) if not tnames.is_empty() else ""]
	if _lv_btn != null:
		var picks := model.stat_pending()
		_lv_label.text = "Lv %d%s" % [int(run.get("lv", 1)), " ▲%d" % picks if picks > 0 else ""]
		_lv_label.add_theme_color_override("font_color", P2Ui.C_GOLD if picks > 0 else P2Ui.C_TEXT)
		_lv_btn.tooltip_text = P2Ui.stat_tooltip(run) + (tr("\n눌러서 능력치 고르기 (%d번 남음)") % picks if picks > 0 else "")


func _show_context() -> void:
	if _ctx_chips == null:
		return
	for c in _ctx_chips.get_children():
		c.queue_free()
	if _current.is_empty():
		_prompt_bg.visible = false
		_prompt.text = ""
		return
	_ctx_name.text = _name_of(_current)
	_prompt.text = _hint_of(_current)
	_prompt.add_theme_color_override("font_color", P2Ui.C_GOLD if _prompt.text != "" else P2Ui.C_DIM)
	P2Ui.chip_row(_ctx_chips, Vector2.ZERO, _chips_of(_current), 6.0, 34.0)
	_prompt_bg.visible = true


func _hint_of(it: Dictionary) -> String:
	match String(it.get("kind", "")):
		"enemy":
			return tr("클릭·E: 교전 창 (바로 싸우지 않음)")
		"route":
			return tr("클릭·E: 이 경로로 정하기")
		"service":
			return tr("클릭·E: 거래 창")
		"choice":
			return tr("클릭·E: 고르기 창")
		"hub":
			return tr("클릭·E: 들어가서 고르기")
		"portal":
			return tr("클릭·E: 원정 마치기")
	return ""


func _chips_of(it: Dictionary) -> Array:
	var kind := String(it.get("kind", ""))
	match kind:
		"enemy":
			var id := String(it.id)
			return _group_chips(String(layout.encounters[id].group), RunModel.diff_hp_mult(model.run)) + _gain_chips(id)
		"route":
			var rid := "h1" + String(it.id)
			return [[null, tr("경로 %s") % String(it.id).to_upper(), P2Ui.C_GOLD]] + _group_chips(rid, RunModel.diff_hp_mult(model.run)) + _gain_chips(rid)
		"service":
			return [[P2Ui.kit_tex("hud_coin", 1), tr("가진 %d") % int(model.run.gold), P2Ui.C_GOLD], [P2Ui.kit_tex("pile_draw", 1), tr("카드 %d") % P2Catalog.SHOP_CARD],
				[P2Ui.kit_tex("status_crit", 1), tr("강화 %d") % P2Catalog.SHOP_UPGRADE], [P2Ui.kit_tex("potion_health", 1), tr("치료 %d") % P2Catalog.SHOP_HEAL],
				[P2Ui.kit_tex("pile_exhaust", 1), tr("제거 %d") % model.removal_price()]]
		"choice":
			return [[P2Ui.kit_tex("hud_coin", 1), tr("금화 +%d") % P2Catalog.CHEST_GOLD], [P2Ui.kit_tex("potion_health", 1), tr("회복약")],
				[P2Ui.kit_tex("hud_heart", 1), tr("체력 → 강화")], [P2Ui.kit_tex("intent_heavy", 1), tr("위험 전투")], [null, tr("하나만"), P2Ui.C_DIM]]
		"hub":
			var h: Dictionary = _hubs[String(it.id)]
			var out: Array = []
			for k in h.keys:
				var n: Dictionary = _nodes[k]
				var col: Color = {"open": P2Ui.C_GOLD, "done": SYM_DONE, "sealed": Color(0.8, 0.36, 0.3)}.get(String(n.st), P2Ui.C_DIM)
				out.append([null, "%s %s" % [String(_look_of(n)[0]) if String(n.st) != "done" else "✓", String(_look_of(n)[2])], col])
			return out
		"portal":
			return [[P2Ui.kit_tex("potion_health", 1), tr("기록을 남기고 원정 마치기")]]
		"done":
			return [[null, tr("이미 끝난 곳"), P2Ui.C_DIM]]
		"sealed":
			return [[P2Ui.kit_tex("intent_seal", 1), tr("봉인된 길 — 반대 경로로 정함"), P2Ui.C_WARN]]
		"gate", "locked":
			return [[P2Ui.kit_tex("intent_seal", 1), String(it.get("prompt", tr("잠김"))).trim_prefix("상인 — "), P2Ui.C_WARN]]
	return []


# 적마다 칩 하나(이름 · 체력), 소환으로 나오는 적은 뺀다
func _group_chips(group: String, hpm := 1.0) -> Array:
	var g: Dictionary = P2Catalog.GROUPS[group]
	var out: Array = []
	for i in range(g.enemies.size()):
		var d: Dictionary = P2Catalog.ENEMIES[g.enemies[i]]
		if bool(d.get("summon_slot", false)):
			continue
		out.append([P2Ui.kit_tex("hud_heart", 1), "%s %d" % [String(d.name), maxi(1, roundi(int(d.hp) * hpm))]])
	return out


func _gain_chips(id: String) -> Array:
	var out: Array = []
	out.append([P2Ui.kit_tex("hud_coin", 1), tr("정산"), P2Ui.C_SAFE] if RunModel.is_boss(id) else [P2Ui.kit_tex("pile_draw", 1), tr("카드")])
	for t in P2Catalog.REWARD_PLAN.get(RunModel._reward_key(id), []):
		out.append({"upgrade": [P2Ui.kit_tex("status_crit", 1), tr("강화")], "relic": [P2Ui.relic_tex("rift_heart"), tr("유물")],
			"upgrade_or_heal": [P2Ui.kit_tex("status_crit", 1), tr("강화/회복")], "upgrade_or_relic": [P2Ui.kit_tex("status_crit", 1), tr("강화/유물")]}.get(String(t), [null, String(t)]))
	out.append([P2Ui.kit_tex("hud_coin", 1), "+%d" % RunModel.mod_gold(model.run, int(RunModel.pay_for(sector, id)[0])), P2Ui.C_GOLD])
	return out


# 지도 소리: 고리가 한 칸 맞춰 설 때 딸깍, 소용돌이에 들어가고 나올 때 휙
func _map_sfx(file: String, db: float, pitch := 1.0) -> void:
	if _snd.is_empty():
		for i in range(3):
			var pl := AudioStreamPlayer.new()
			add_child(pl)
			_snd.append(pl)
	var p: AudioStreamPlayer = _snd[_snd_i]
	_snd_i = (_snd_i + 1) % _snd.size()
	p.stream = load(SFX_DIR + file)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
	sfx_log.append(file)


# ── 처음 한 번 안내 말풍선: 고리 돌리기 → 소용돌이. 직접 해 보면 사라지고 다시 안 뜬다(전투 두 번을 이기면 저절로 끝).
# 말풍선은 클릭을 가로막지 않는다 ─────────────

func _maybe_hint() -> void:
	if locked or _hint != null or _hub_open != "" or not is_inside_tree():
		return
	if (model.run.defeated as Array).size() >= 2:
		for k in ["map_ring", "map_hub"]:
			if not P2Ui.hint_seen(k):
				P2Ui.set_hint(k)
		return
	if not P2Ui.hint_seen("map_ring"):
		_show_hint("map_ring", tr("고리 빈 곳을 끌거나 휠을 굴려 돌려 보세요") + "\n" + tr("놓으면 가장 가까운 곳이 앞에 섭니다"), "")
	elif not P2Ui.hint_seen("map_hub") and not _hubs.is_empty():
		var target := String(_hubs.keys()[0])
		for hk in _hubs:
			if String(_hubs[hk].get("st", "")) == "open":
				target = hk
				break
		_show_hint("map_hub", tr("소용돌이 = 여러 곳 중 고르는 자리") + "\n" + tr("눌러서 들어가 보세요 (Esc로 나옴)"), target)


func _show_hint(key: String, text: String, target: String) -> void:
	_hint_key = key
	_hint_target = target
	_hint = Panel.new()
	_hint.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_GOLD, 0.97))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := P2Ui.outlined(P2Ui.text(text, P2Ui.T_BODY, P2Ui.C_TEXT), 3)
	l.position = Vector2(14, 10)
	_hint.add_child(l)
	var ts := P2Ui.pixel_font(P2Ui.T_BODY).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY)
	l.size = ts + Vector2(4, 4)
	_hint.size = ts + Vector2(32, 24)
	var tip := Control.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.position = Vector2(_hint.size.x / 2.0 - 10.0, _hint.size.y - 1.0)
	tip.size = Vector2(20, 12)
	tip.draw.connect(func() -> void:
		tip.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(10, 12)]), P2Ui.C_GOLD))
	_hint.add_child(tip)
	_hud.add_child(_hint)
	_place_hint()
	P2Ui.pop_in(_hint)


# 말풍선 꼬리가 가리키는 곳: 고리 안내는 앞쪽 왼편의 빈 고리, 소용돌이 안내는 그 소용돌이(고리와 같이 돈다)
func _place_hint() -> void:
	if _hint == null:
		return
	var at := BOARD.position + _ring_pos(_entry_ang(String(_entries[_front_entry()].key)) - 30.0, 1.0) + Vector2(0, -8)
	if _hint_target != "" and _hubs.has(_hint_target):
		var hb: Button = _hubs[_hint_target].btn
		at = BOARD.position + hb.position + hb.pivot_offset + Vector2(0, -34.0 * hb.scale.y)
	var pos := at - Vector2(_hint.size.x / 2.0, _hint.size.y + 12.0)
	pos.x = clampf(pos.x, 8.0, 1272.0 - _hint.size.x)
	pos.y = clampf(pos.y, 48.0, 560.0 - _hint.size.y)
	_hint.position = pos
	_hint.visible = _hub_open == ""


# 직접 해 봤으면 말풍선이 떠 있든 아니든 본 것으로 친다
func _dismiss_hint(key: String) -> void:
	if not P2Ui.hint_seen(key):
		P2Ui.set_hint(key)
	if _hint == null or _hint_key != key:
		return
	_hide_hint()
	_maybe_hint.call_deferred()


func _hide_hint() -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.queue_free()
	_hint = null
	_hint_key = ""
