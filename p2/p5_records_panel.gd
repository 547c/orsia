class_name P5RecordsPanel
extends CanvasLayer
# 기록실 (일시정지 메뉴 · 원정 준비 창): 세 칸 — 기록(정복 배지 · 오늘의 원정 · 보스·정예 연습 · 최근 원정) · 도전과제 · 도감(만난 적).
# 연습과 오늘의 원정은 진행 중인 원정 · 연습이 없을 때만 시작한다. 이 창은 아무것도 저장하지 않는다(연습 난이도 고르기는 창 안에서만)

signal closed

const W := 1080.0
const H := 624.0
const TOP := 78.0
const DIFF_COL := {"easy": Color("#8be08b"), "normal": Color("#f3ead7"), "hard": Color("#ff9a6a"), "extreme": Color("#ff5a5a")}
const RANK_COL := {"S": Color("#ffe04a"), "A": Color("#8fe08b"), "B": Color("#8fc3e8"), "C": Color("#f3ead7"), "D": Color("#e0533a")}
const RESULT_NAME := {"clear": "정복", "return": "마침", "lost": "쓰러짐", "abandon": "포기"}
const TABS := [["records", "기록"], ["achv", "도전과제"], ["dex", "도감"]]
const NOTE_GLYPH := {"t": "○", "h": "□", "d": "◎", "s": "△", "f": "◇", "x": "✕"}
const RANK_TAG := {"boss": ["보스", Color("#c08aff")], "elite": ["정예", Color("#ff9a6a")], "mimic": ["상자", Color("#d8c08a")], "device": ["장치", Color("#8fc3e8")]}

var tab := "records"
var practice_diff := ""
var _panel: Panel
var _body: Control


static func open_in(tree: SceneTree) -> P5RecordsPanel:
	for n in tree.get_nodes_in_group("records_room_layer"):
		(n as P5RecordsPanel).refresh()
		return n
	var p := P5RecordsPanel.new()
	tree.root.add_child(p)
	return p


static func can_start() -> bool:
	return RunService.run.is_empty() and RunService.field.is_empty() and not Flow.busy()


func _ready() -> void:
	layer = 106
	add_to_group("records_room_layer")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_to_group("records_room")
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	_panel = Panel.new()
	_panel.size = Vector2(W, H)
	_panel.position = (root.get_viewport_rect().size - _panel.size) / 2.0
	_panel.add_theme_stylebox_override("panel", P2Ui.style("leaf"))
	root.add_child(_panel)
	practice_diff = String(GameState.combat.get("diff_pick", "normal"))
	refresh()
	P2Ui.pop_in(_panel, dim)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func refresh() -> void:
	if _body != null:
		_body.queue_free()
	_body = Control.new()
	_body.size = _panel.size
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body)
	var cb: Dictionary = GameState.combat
	var st: Dictionary = cb.get("stats", {})
	_text(_body, "기록실", Vector2(24, 12), P2Ui.T_BIG, P2Ui.C_GOLD, 4)
	P2Ui.chip_row(_body, Vector2(180, 20), [[P2Ui.kit_tex("status_crit", 1), "원정 %d" % int(st.get("expeditions", 0))],
		[P2Ui.kit_tex("status_mark", 1), "도전과제 %d/%d" % [(cb.get("achievements", {}) as Dictionary).size(), P2Catalog.ACHIEVEMENTS.size()], P2Ui.C_GOLD],
		[P2Ui.kit_tex("intent_multi", 1), "연습 %d" % int(st.get("practice", 0)), P2Ui.C_BLOCK]], 8.0, 32.0)
	var tx := W - 24.0 - TABS.size() * 128.0
	for t in TABS:
		var b := P2Ui.crisp(P2Ui.button(String(t[1]), Vector2(tx, 14), Vector2(122, 40)), P2Ui.T_BODY) as Button
		b.set_meta("skin", "tile")
		b.set_meta("tab", t[0])
		P2Ui.mark(b, tab == String(t[0]))
		var id := String(t[0])
		b.pressed.connect(func() -> void:
			tab = id
			refresh())
		_body.add_child(b)
		tx += 128.0
	P2Ui.rule(_body, Vector2(24, 66), W - 48, Color(P2Ui.C_GOLD, 0.45))
	match tab:
		"achv":
			_achievements(cb)
		"dex":
			_dex(cb)
		_:
			_badges(cb)
			_daily(cb)
			_practice(cb)
			_history(cb)
	var shut := P2Ui.primary(P2Ui.crisp(P2Ui.button("닫기", Vector2(W - 204, H - 60), Vector2(180, 44)), P2Ui.T_HEAD) as Button)
	shut.tooltip_text = "Esc"
	shut.pressed.connect(close)
	_body.add_child(shut)
	shut.grab_focus.call_deferred()


func _text(parent: Control, t: String, pos: Vector2, size: int, col: Color, outline := 0, clip := 0.0) -> Label:
	var l := P2Ui.text(t, size, col)
	if outline > 0:
		P2Ui.outlined(l, outline)
	if clip > 0.0:
		l.clip_text = true
		l.size = Vector2(clip, size + 6)
	l.position = pos
	parent.add_child(l)
	return l


func _box(pos: Vector2, size: Vector2, edge := P2Ui.C_EDGE) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", P2Ui.calm_box(edge, 0.97))
	_body.add_child(p)
	return p


# 정복 배지: 난이도마다 ★(최종 보스를 잡음) · 최고 점수
func _badges(cb: Dictionary) -> void:
	_text(_body, "정복 배지", Vector2(24, TOP + 2), P2Ui.T_HEAD, P2Ui.C_GOLD, 3)
	var cleared: Dictionary = cb.get("diff_clear", {})
	var best: Dictionary = cb.get("best_score", {})
	for i in range(P2Catalog.DIFFS.size()):
		var id := String(P2Catalog.DIFFS[i])
		var won := bool(cleared.get(id, false))
		var open := P2Catalog.diff_unlocked(cleared, id)
		var row := _box(Vector2(16, TOP + 38 + i * 50), Vector2(330, 44), P2Ui.C_GOLD if won else P2Ui.C_EDGE)
		row.set_meta("badge", id)
		row.set_meta("won", won)
		_text(row, ("★ " if won else "") + String(P2Catalog.DIFF[id].name), Vector2(12, 8), P2Ui.T_BODY, DIFF_COL[id] if open else P2Ui.C_DIM, 3)
		var b: Dictionary = best.get(id, {})
		var tail := "%s  %d" % [String(b.rank), int(b.score)] if not b.is_empty() else ("잠김" if not open else "기록 없음")
		var t := _text(row, tail, Vector2(130, 8), P2Ui.T_BODY, RANK_COL.get(String(b.get("rank", "")), P2Ui.C_DIM) if not b.is_empty() else P2Ui.C_DIM, 0, 186.0)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


# 오늘의 원정: 날짜로 정해진 직업 · 모드 · 지도(노멀). 그날 최고 점수와 지난 며칠
func _daily(cb: Dictionary) -> void:
	var date := RunModel.today()
	var spec := RunModel.daily_spec(date)
	var y := TOP + 252.0
	_text(_body, "오늘의 원정", Vector2(24, y), P2Ui.T_HEAD, P2Ui.C_GOLD, 3)
	_text(_body, date, Vector2(190, y + 4), P2Ui.T_BODY, P2Ui.C_DIM)
	var box := _box(Vector2(16, y + 36), Vector2(330, 170))
	var mods: Array = spec.mods
	_text(box, "%s · 노멀%s" % [P2Catalog.CLASSES[spec.class_id].name, ("  " + " ".join(PackedStringArray(mods.map(func(m): return String(P2Catalog.MOD[m].short))))) if not mods.is_empty() else ""],
		Vector2(12, 8), P2Ui.T_BODY, P2Ui.C_TEXT, 0, 306.0)
	_text(box, "모두 같은 지도 · 같은 직업 · 같은 모드", Vector2(12, 34), P2Ui.T_SMALL, P2Ui.C_DIM)
	var days: Dictionary = cb.get("daily", {})
	var today: Dictionary = days.get(date, {})
	_text(box, "오늘 최고  " + ("%s  %d" % [String(today.rank), int(today.score)] if not today.is_empty() else "아직 없음"), Vector2(12, 56), P2Ui.T_BODY,
		RANK_COL.get(String(today.get("rank", "")), P2Ui.C_DIM) if not today.is_empty() else P2Ui.C_DIM, 0, 306.0)
	var past: Array = days.keys().filter(func(d): return String(d) != date)
	past.sort()
	past.reverse()
	var line := "  ".join(PackedStringArray(past.slice(0, 4).map(func(d): return "%s %s" % [String(d).substr(5), String(days[d].rank)])))
	_text(box, ("지난 기록  " + line) if line != "" else "지난 기록 없음", Vector2(12, 84), P2Ui.T_SMALL, P2Ui.C_DIM, 0, 306.0)
	var go := P2Ui.crisp(P2Ui.button("도전하기", Vector2(12, 112), Vector2(306, 46)), P2Ui.T_HEAD) as Button
	go.set_meta("daily", true)
	var why := "" if can_start() else "진행 중인 원정이 있습니다"
	if why == "":
		var errs := RunService.entry_errors()
		why = "" if errs.is_empty() else "; ".join(PackedStringArray(errs))
	go.disabled = why != ""
	go.tooltip_text = why if why != "" else "고른 직업·난이도와 상관없이 오늘의 구성으로 출발합니다"
	go.pressed.connect(func() -> void: start_daily())
	box.add_child(go)


func start_daily() -> bool:
	if not can_start():
		return false
	if not Flow.start_expedition(RunModel.daily_spec(RunModel.today())):
		return false
	for n in get_tree().get_nodes_in_group("expedition_prep_layer"):
		(n as P5PrepPanel).close()
	close()
	return true


# 보스·정예 연습: 원정에서 만난 무리만 열림. 고른 난이도의 연습 최고와 원정 보스 기록
func _practice(cb: Dictionary) -> void:
	var x := 362.0
	_text(_body, "보스·정예 연습", Vector2(x + 8, TOP + 2), P2Ui.T_HEAD, P2Ui.C_GOLD, 3)
	var cleared: Dictionary = cb.get("diff_clear", {})
	if not P2Catalog.diff_unlocked(cleared, practice_diff):
		practice_diff = "normal"
	var dx := x
	for id in P2Catalog.DIFFS:
		var open := P2Catalog.diff_unlocked(cleared, id)
		var b := P2Ui.crisp(P2Ui.button(String(P2Catalog.DIFF[id].name), Vector2(dx, TOP + 36), Vector2(84, 34)), P2Ui.T_BODY) as Button
		b.set_meta("skin", "tile")
		b.set_meta("practice_diff", id)
		P2Ui.mark(b, id == practice_diff)
		b.disabled = not open
		b.add_theme_color_override("font_color", DIFF_COL[id])
		var did := String(id)
		b.pressed.connect(func() -> void:
			practice_diff = did
			refresh())
		_body.add_child(b)
		dx += 90.0
	var pb: Dictionary = cb.get("practice_best", {})
	var bb: Dictionary = cb.get("boss_best", {})
	var y := TOP + 80.0
	for p in P2Catalog.PRACTICE:
		var gid := String(p[0])
		var sector := String(p[1])
		var open := RunModel.practice_open(cb, gid)
		var row := _box(Vector2(x, y), Vector2(356, 60), P2Ui.C_EDGE)
		row.set_meta("practice", gid)
		var nm := String(P2Catalog.GROUPS[gid].name) if open else "???"
		_text(row, nm, Vector2(12, 6), P2Ui.T_BODY, P2Ui.C_TEXT if open else P2Ui.C_DIM, 0, 220.0)
		var tag := String(P2Catalog.SECTOR_NAMES[sector]).get_slice(" · ", 0) + (" 보스" if RunModel.is_boss(gid) else " 정예")
		var rec: Array = []
		var pr: Dictionary = pb.get(RunModel.practice_key(gid, practice_diff), {})
		if not pr.is_empty():
			rec.append("연습 %s %d" % [String(pr.grade), int(pr.acc)])
		var br: Dictionary = bb.get(RunModel.boss_key(gid, practice_diff), {})
		if not br.is_empty():
			rec.append("원정 %s %d" % [String(br.grade), int(br.acc)])
		_text(row, tag + ("  ·  " + " · ".join(PackedStringArray(rec)) if not rec.is_empty() else ("" if open else "  ·  원정에서 만나면 열림")), Vector2(12, 34), P2Ui.T_SMALL, P2Ui.C_DIM, 0, 250.0)
		var go := P2Ui.crisp(P2Ui.button("연습", Vector2(264, 10), Vector2(80, 40)), P2Ui.T_BODY) as Button
		go.set_meta("practice_go", gid)
		go.disabled = not open or not can_start()
		go.tooltip_text = "피해·보상 없이 한 판 (%s)" % P2Catalog.DIFF[practice_diff].name if open else "원정에서 만나면 열립니다"
		go.pressed.connect(func() -> void: start_practice(gid))
		row.add_child(go)
		y += 66.0


func start_practice(gid: String) -> bool:
	if not can_start() or not Flow.start_practice(gid, practice_diff):
		return false
	for n in get_tree().get_nodes_in_group("expedition_prep_layer"):
		(n as P5PrepPanel).close()
	close()
	return true


# 최근 원정: 직업 · 난이도 · 모드 · 결과 · 랭크 · 점수 · 날짜 (새것부터)
func _history(cb: Dictionary) -> void:
	var x := 734.0
	_text(_body, "최근 원정", Vector2(x + 8, TOP + 2), P2Ui.T_HEAD, P2Ui.C_GOLD, 3)
	var hist: Array = (cb.get("history", []) as Array).duplicate()
	hist.reverse()
	if hist.is_empty():
		_text(_body, "아직 원정 기록이 없습니다", Vector2(x + 8, TOP + 44), P2Ui.T_BODY, P2Ui.C_DIM)
		return
	var y := TOP + 38.0
	for h in hist.slice(0, 6):
		var row := _box(Vector2(x, y), Vector2(330, 58))
		row.set_meta("history", true)
		var diff := String(h.get("diff", "normal"))
		var mods: Array = h.get("mods", [])
		var cls := String((P2Catalog.CLASSES.get(String(h.get("class_id", "")), {}) as Dictionary).get("name", "?"))
		var head := "%s · %s%s" % [cls, P2Catalog.diff_of(diff).name, ("  " + " ".join(PackedStringArray(mods.map(func(m): return String(P2Catalog.MOD.get(m, {}).get("short", m)))))) if not mods.is_empty() else ""]
		_text(row, head, Vector2(10, 4), P2Ui.T_BODY, DIFF_COL.get(diff, P2Ui.C_TEXT), 0, 250.0)
		var res := String(h.get("result", ""))
		var sc: Dictionary = h.get("score", {})
		var parts: Array = [String(RESULT_NAME.get(res, res))]
		if res in ["lost", "abandon"]:
			parts[0] += " · " + String(P2Catalog.SECTOR_NAMES.get(String(h.get("sector", "")), "")).get_slice(" · ", 0)
		if not sc.is_empty():
			parts.append(str(int(sc.score)))
		if String(h.get("date", "")) != "":
			parts.append(String(h.date).substr(5))
		if String(h.get("daily", "")) != "":
			parts.append("오늘의 원정")
		_text(row, " · ".join(PackedStringArray(parts)), Vector2(10, 32), P2Ui.T_SMALL, P2Ui.C_DIM, 0, 250.0)
		if not sc.is_empty():
			var rk := _text(row, String(sc.rank), Vector2(272, 4), P2Ui.T_BIG, RANK_COL.get(String(sc.rank), P2Ui.C_TEXT), 4)
			rk.size = Vector2(48, 44)
			rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		y += 64.0


# 도전과제: 두 줄 열네 칸. 연 것은 금빛 이름 · 연 날짜, 아직이면 흐린 이름 · 조건
func _achievements(cb: Dictionary) -> void:
	var got: Dictionary = cb.get("achievements", {})
	for i in range(P2Catalog.ACHIEVEMENTS.size()):
		var a: Array = P2Catalog.ACHIEVEMENTS[i]
		var on := got.has(a[0])
		var row := _box(Vector2(16 + (i % 2) * 528, TOP + 4 + floori(i / 2.0) * 66), Vector2(520, 60), P2Ui.C_GOLD if on else P2Ui.C_EDGE)
		row.set_meta("achv", a[0])
		row.set_meta("on", on)
		var ic := P2Ui.tex_icon(P2Ui.kit_tex(String(a[3]), 1), 36)
		ic.position = Vector2(12, 12)
		ic.modulate = Color.WHITE if on else Color(0.45, 0.45, 0.5)
		row.add_child(ic)
		_text(row, String(a[1]), Vector2(60, 6), P2Ui.T_BODY, P2Ui.C_GOLD if on else P2Ui.C_DIM, 3 if on else 0, 300.0)
		_text(row, String(a[2]), Vector2(60, 34), P2Ui.T_SMALL, P2Ui.C_TEXT if on else P2Ui.C_DIM, 0, 330.0)
		var when := _text(row, String(got[a[0]]) if on else "잠김", Vector2(380, 18), P2Ui.T_SMALL, P2Ui.C_GOLD if on else P2Ui.C_DIM, 0, 128.0)
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


# 도감: 원정에 나오는 적(만난 것만 이름·체력·노트·성향 설명). 연습할 수 있는 무리에 들면 표시
func _dex(cb: Dictionary) -> void:
	var met: Array = cb.get("seen_enemies", [])
	var roles: Array = []
	for gid in P2Catalog.GROUPS:
		if String(gid).begins_with("field_"):
			continue
		for role in P2Catalog.GROUPS[gid].enemies:
			if not roles.has(role):
				roles.append(role)
	var practiced := {}
	for p in P2Catalog.PRACTICE:
		for role in P2Catalog.GROUPS[p[0]].enemies:
			practiced[role] = true
	_text(_body, "만난 적 %d / %d" % [roles.filter(func(r): return met.has(r)).size(), roles.size()], Vector2(24, TOP + 2), P2Ui.T_BODY, P2Ui.C_DIM)
	for i in range(roles.size()):
		var role := String(roles[i])
		var d: Dictionary = P2Catalog.ENEMIES[role]
		var seen := met.has(role)
		var row := _box(Vector2(16 + (i % 3) * 352, TOP + 34 + floori(i / 3.0) * 60), Vector2(344, 56))
		row.set_meta("dex", role)
		row.set_meta("seen", seen)
		if not seen:
			_text(row, "???", Vector2(12, 6), P2Ui.T_BODY, P2Ui.C_DIM)
			_text(row, "원정에서 만나면 기록됩니다", Vector2(12, 32), P2Ui.T_SMALL, P2Ui.C_DIM)
			continue
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "%s — %s" % [String(d.name), String(d.get("role", ""))]
		_text(row, String(d.name), Vector2(12, 4), P2Ui.T_BODY, P2Ui.C_TEXT, 0, 210.0)
		var tag: Array = RANK_TAG.get(String(d.get("rank", "")), [])
		if not tag.is_empty():
			var t := _text(row, String(tag[0]), Vector2(224, 6), P2Ui.T_SMALL, tag[1], 0, 108.0)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var pool: Array = P2BattleView.NOTE_POOL.get(role, ["t"])
		var glyphs: Array = []
		for k in pool:
			var g := String(NOTE_GLYPH.get(String(k), "○"))
			if not glyphs.has(g):
				glyphs.append(g)
		_text(row, "체력 %d · 노트 %s%s" % [int(d.hp), " ".join(PackedStringArray(glyphs)), "  · 연습 가능" if practiced.has(role) else ""], Vector2(12, 32), P2Ui.T_SMALL, P2Ui.C_DIM, 0, 320.0)
