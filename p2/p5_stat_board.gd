class_name P5StatBoard
extends Panel

# 능력치 판(세피리아식): 위에 원정 레벨과 경험치 줄, 아래로 능력치마다 그림 · 이름 · 값 한 줄(0이면 흐림, 한도 있는 것은 얇은 막대).
# 후보에 올리면 그 줄이 밝아지며 +N과 바뀔 값이 보이고, 고르면 숫자가 올라가며 번쩍인다

const ROW_H := 42.0
const HEAD_H := 78.0

var _rows := {}
var _stats := {}
var _base := {}


static func make(run: Dictionary, w := 300.0, titled := true) -> P5StatBoard:
	var b := P5StatBoard.new()
	b._build(run, w, titled)
	return b


static func value_text(id: String, v: int) -> String:
	if v <= 0:
		return "—"
	return "+%d%s" % [v, "%p" if id == "crit" else ("%" if id in ["cdmg", "focus"] else "")]


func _build(run: Dictionary, w: float, titled: bool) -> void:
	_base = run.get("stats", {})
	_stats = P2Catalog.stats_with_relics(_base, run.get("relics", []))
	size = Vector2(w, HEAD_H + ROW_H * P2Catalog.STAT_ORDER.size() + 10.0)
	add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_EDGE, 0.97))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lv := int(run.get("lv", 1))
	var title := P2Ui.outlined(P2Ui.text(tr("능력치") if titled else tr("원정 레벨"), P2Ui.T_HEAD, P2Ui.C_GOLD if titled else P2Ui.C_DIM), 3)
	title.position = Vector2(14, 8)
	add_child(title)
	var lvl := P2Ui.outlined(P2Ui.text("Lv %d" % lv, P2Ui.T_HEAD, P2Ui.C_TEXT), 3)
	lvl.position = Vector2(w - 96, 8)
	lvl.size = Vector2(82, 30)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lvl)
	var need := P2Catalog.lv_need(lv)
	var xp := int(run.get("lv_xp", 0))
	var bar := ColorRect.new()
	bar.color = Color(P2Ui.C_EDGE, 0.8)
	bar.position = Vector2(14, 44)
	bar.size = Vector2(w - 28, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var fill := ColorRect.new()
	fill.color = P2Ui.C_GOLD
	fill.size = Vector2((w - 28) * clampf(float(xp) / maxf(1.0, need), 0.0, 1.0), 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var xl := P2Ui.text(tr("경험치 %d / %d") % [xp, need], P2Ui.T_SMALL, P2Ui.C_DIM)
	xl.position = Vector2(14, 54)
	add_child(xl)
	var y := HEAD_H
	for k in P2Catalog.STAT_ORDER:
		_rows[k] = _row(String(k), y, w)
		y += ROW_H


func _row(id: String, y: float, w: float) -> Dictionary:
	var d: Dictionary = P2Catalog.STATS[id]
	var v := int(_stats.get(id, 0))
	var root := Control.new()
	root.position = Vector2(8, y)
	root.size = Vector2(w - 16, ROW_H - 4)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var from_relic := v - int(_base.get(id, 0))
	root.tooltip_text = P2Catalog.stat_text(id, maxi(v, int(d.step))) + (tr("
레벨업으로 %s · 유물로 %s (석판 단계 포함)") % [value_text(id, v - from_relic), value_text(id, from_relic)] if from_relic > 0 else "")
	add_child(root)
	var glow := ColorRect.new()
	glow.color = Color(P2Ui.C_GOLD, 0.0)
	glow.size = root.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	var ic := P2Ui.tex_icon(P2Ui.kit_tex(String(d.icon), 1), 26)
	ic.position = Vector2(6, 6)
	root.add_child(ic)
	var nm := P2Ui.text(String(d.name), P2Ui.T_BODY, P2Ui.C_TEXT)
	nm.position = Vector2(40, 4)
	root.add_child(nm)
	if from_relic > 0:
		var rl := P2Ui.outlined(P2Ui.text(tr("유물 %s") % value_text(id, from_relic), P2Ui.T_SMALL, P2Ui.C_GOLD), 2)
		rl.position = Vector2(132, 8)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rl)
	var val := P2Ui.outlined(P2Ui.text(value_text(id, v), P2Ui.T_BODY, P2Ui.C_TEXT), 3)
	val.position = Vector2(w - 190, 4)
	val.size = Vector2(80, 28)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.pivot_offset = Vector2(60, 14)
	root.add_child(val)
	var delta := P2Ui.outlined(P2Ui.text("", P2Ui.T_BODY, P2Ui.C_GOOD), 3)
	delta.position = Vector2(w - 104, 4)
	delta.size = Vector2(84, 28)
	root.add_child(delta)
	var cap := int(P2Catalog.STAT_CAP.get(id, 0))
	var meter: ColorRect = null
	if cap > 0:
		var back := ColorRect.new()
		back.color = Color(P2Ui.C_EDGE, 0.7)
		back.position = Vector2(40, 32)
		back.size = Vector2(w - 230, 4)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(back)
		meter = ColorRect.new()
		meter.color = P2Ui.C_GOLD
		meter.size = Vector2(back.size.x * clampf(float(v) / cap, 0.0, 1.0), 4)
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.set_meta("full", back.size.x)
		back.add_child(meter)
	var r := {"root": root, "glow": glow, "icon": ic, "name": nm, "val": val, "delta": delta, "meter": meter, "cap": cap}
	_tint(r, v)
	return r


func _tint(r: Dictionary, v: int) -> void:
	var on := v > 0
	(r.name as Label).add_theme_color_override("font_color", P2Ui.C_TEXT if on else P2Ui.C_DIM)
	(r.val as Label).add_theme_color_override("font_color", P2Ui.C_TEXT if on else Color(P2Ui.C_DIM, 0.6))
	(r.icon as Control).modulate = Color.WHITE if on else Color(0.6, 0.6, 0.66, 0.7)


# 후보 미리보기: 그 줄만 금빛으로 밝히고 +N · 바뀔 값. id ""이면 모두 끔
func preview(id: String, amount: int) -> void:
	for k in _rows:
		var r: Dictionary = _rows[k]
		var on := String(k) == id
		var glow: ColorRect = r.glow
		var tw := glow.create_tween()
		tw.tween_property(glow, "color:a", 0.22 if on else 0.0, 0.08)
		var dl: Label = r.delta
		if on:
			var after := int(_stats.get(id, 0)) + amount
			if int(r.cap) > 0:
				after = mini(after, int(r.cap))
			dl.text = "▲ " + value_text(id, after)
			dl.modulate.a = 1.0
			var pulse := dl.create_tween().set_loops(3)
			pulse.tween_property(dl, "modulate:a", 0.55, 0.22)
			pulse.tween_property(dl, "modulate:a", 1.0, 0.22)
		else:
			dl.text = ""


# 고른 순간: 숫자가 올라가며 크게 튀었다 돌아오고, 줄이 번쩍, 막대가 찬다
func bump(id: String, amount: int) -> void:
	if not _rows.has(id):
		return
	var r: Dictionary = _rows[id]
	var from := int(_stats.get(id, 0))
	var to := from + amount
	if int(r.cap) > 0:
		to = mini(to, int(r.cap))
	_stats[id] = to
	_tint(r, to)
	(r.delta as Label).text = ""
	var val: Label = r.val
	var glow: ColorRect = r.glow
	glow.color = Color(1.0, 0.95, 0.75, 0.6)
	var t := create_tween()
	t.tween_method(func(x: float) -> void: val.text = value_text(id, roundi(x)), float(from), float(to), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(val, "scale", Vector2.ONE * 1.45, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(glow, "color", Color(P2Ui.C_GOLD, 0.25), 0.3)
	t.tween_property(val, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var meter: ColorRect = r.meter
	if meter != null:
		var full := float(meter.get_meta("full"))
		create_tween().tween_property(meter, "size:x", full * clampf(float(to) / int(r.cap), 0.0, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fly := P2Ui.outlined(P2Ui.text("+%d" % (to - from), P2Ui.T_HEAD, P2Ui.C_GOOD), 3)
	fly.position = (r.root as Control).position + Vector2(size.x - 100, -2)
	add_child(fly)
	var f := create_tween()
	f.tween_property(fly, "position:y", fly.position.y - 30.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	f.parallel().tween_property(fly, "modulate:a", 0.0, 0.5).set_delay(0.15)
	f.tween_callback(fly.queue_free)


func row_center(id: String) -> Vector2:
	var r: Dictionary = _rows.get(id, {})
	if r.is_empty():
		return global_position + size / 2.0
	return (r.root as Control).get_global_rect().get_center()
