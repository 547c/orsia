class_name P2DrumChart
extends P2NoteChart

# 무거운 연타(파괴자·철갑 수비병·정예): 태고식 북 장단. 아래 띠 오른쪽에서 북이 흘러와 왼쪽 판정 원에 닿을 때 친다.
# 빨강 = 둥(왼쪽 클릭 · F J) · 파랑 = 딱(오른쪽 클릭 · D K) · 노랑 띠 = 연타(띠가 지나는 동안 아무 쪽이나 여러 번) ·
# 큰 북 = 강타(완벽해도 절반). 색이 틀리면 놓침. 판정 창·박자·부름·신호는 P2NoteChart 그대로

const DON_KEYS := [KEY_F, KEY_J]
const KA_KEYS := [KEY_D, KEY_K]
const C_DON := Color("#f0503c")
const C_KA := Color("#4fb4e8")
const C_ROLL := Color("#ffcf3a")
const LANE_H := 64.0
const SCROLL := 2.0
const ROLL_RATE := 6.0

var judge_x := 400.0
var lane_y := 572.0
var spawn_x := 1030.0
var _slow := 1.0
var _flash := {"don": -9.0, "ka": -9.0}
var _pops: Array = []
var _flying: Array = []
var _streak := 0


func setup(list: Array, r: float, tex: Texture2D, wide: bool) -> void:
	super(list, r, tex, wide)
	for n in notes:
		n.drum = String(n.get("drum", "don"))
		n.rolls = 0
		n.pos = Vector2(judge_x, lane_y)


func ease(k: float) -> void:
	super(k)
	_slow = clampf(k, 0.75, 1.5)


func travel(n: Dictionary) -> float:
	return float(n.approach) * SCROLL * _slow


func x_at(n: Dictionary, t: float) -> float:
	return judge_x + (t - _t) / travel(n) * (spawn_x - judge_x)


func roll_need(n: Dictionary) -> int:
	return maxi(3, ceili(float(n.hold) * ROLL_RATE))


func end_time() -> float:
	var e := 0.0
	for n in notes:
		e = maxf(e, float(n.at) + float(n.hold))
	return e + good_late + maxf(offset, 0.0)


func _process(delta: float) -> void:
	var dt := _advance(delta)
	while not _cues.is_empty() and float(_cues[0].t) - _lat <= _t:
		var c: Dictionary = _cues.pop_front()
		cue.emit(String(c.key), int(c.step), float(c.vol))
	var done := true
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if not n.closed and _t >= float(n.at):
			n.closed = true
			closed.emit(i)
		if n.grade == "":
			if n.drum == "roll":
				if _t > float(n.at) + float(n.hold) + offset:
					var got := int(n.rolls)
					_judge(i, "perfect" if got >= roll_need(n) else ("good" if got * 2 >= roll_need(n) else "miss"))
			elif _t > float(n.at) + offset + good_late:
				_judge(i, "miss", _t - float(n.at) - offset)
		if n.grade == "" or _t - float(n.judged_t) < BURST:
			done = false
	_pops = _pops.filter(func(p): return _t - float(p.t) < 0.4)
	if done and _t > end_time():
		queue_free()
	_c.redraw()


func _input(event: InputEvent) -> void:
	_catch_up()
	if event is InputEventMouseButton and event.pressed:
		var mb := (event as InputEventMouseButton).button_index
		if mb == MOUSE_BUTTON_LEFT or mb == MOUSE_BUTTON_RIGHT:
			_strike("don" if mb == MOUSE_BUTTON_LEFT else "ka")
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or (event as InputEventKey).echo:
		return
	var id := key_id(event as InputEventKey)
	var side := "don" if id in DON_KEYS else ("ka" if id in KA_KEYS else "")
	if side == "":
		return
	if event.pressed:
		_held[id] = true
		held.emit(id, true, OS.get_keycode_string(id))
		_strike(side)
	else:
		_held.erase(id)
		held.emit(id, false, OS.get_keycode_string(id))
	get_viewport().set_input_as_handled()


func _strike(side: String) -> void:
	_flash[side] = _t
	cue.emit("stick" if side == "ka" else "thud", 0, -6.0)
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if n.grade != "":
			continue
		if n.drum == "roll":
			if _t >= float(n.at) - good_early and _t <= float(n.at) + float(n.hold) + offset:
				n.rolls = int(n.rolls) + 1
				_pops.append({"t": _t, "c": C_ROLL})
				return
			if _t < float(n.at) - good_early:
				return
			continue
		var d := _t - float(n.at) - offset
		if d < -good_early:
			return
		if n.drum != side:
			timing.emit(d, "miss")
			_judge(i, "miss", d)
			return
		_hit(i)
		return


# 점검 드라이버·봇: 지금 칠 북을 맞는 쪽으로(연타는 다 채운 것으로)
func press_now() -> void:
	var i := _current()
	if i < 0:
		return
	var n: Dictionary = notes[i]
	if n.drum == "roll":
		n.rolls = roll_need(n)
		return
	_strike(String(n.drum))


func cue_rect() -> Rect2:
	var left := judge_x - 104.0
	return Rect2(left, lane_y - 52.0, spawn_x + 24.0 - left, 104.0)


func release_now() -> void:
	pass


func _side_color(drum: String) -> Color:
	if drum == "roll":
		return C_ROLL
	return C_KA if drum == "ka" else C_DON


func _judge(i: int, g: String, d := 0.0) -> void:
	super(i, g, d)
	if g == "miss":
		_streak = 0
		return
	_streak += 1
	_flying.append({"t": _t, "c": _side_color(String(notes[i].drum)), "big": bool(notes[i].get("crush", false)), "g": g})


func _paint() -> void:
	var open := _open_amount()
	if open <= 0.0:
		return
	var left := judge_x - 104.0
	var stage := Rect2(left, lane_y - 52.0, spawn_x + 24.0 - left, 104.0)
	_stage(stage, "북 장단", "빨강 둥 = 왼쪽 클릭·F J    파랑 딱 = 오른쪽 클릭·D K", open, C_DON)
	var don_lit := clampf(1.0 - (_t - float(_flash.don)) / 0.14, 0.0, 1.0)
	var ka_lit := clampf(1.0 - (_t - float(_flash.ka)) / 0.14, 0.0, 1.0)
	var lane := Rect2(judge_x - 44.0, lane_y - LANE_H / 2.0, spawn_x + 16.0 - (judge_x - 44.0), LANE_H)
	_c.draw_rect(lane, Color("#1b1520", open))
	_c.draw_rect(Rect2(lane.position + Vector2(0, 10), Vector2(lane.size.x, lane.size.y - 20)), Color("#241c2a", open))
	if don_lit > 0.0 or ka_lit > 0.0:
		var glow := C_DON if don_lit >= ka_lit else C_KA
		_c.draw_rect(Rect2(lane.position, Vector2(160, lane.size.y)), Color(glow, 0.22 * maxf(don_lit, ka_lit) * open))
	_c.draw_line(lane.position, Vector2(lane.end.x, lane.position.y), Color("#c89a5a", 0.55 * open), P2Pixel.w(2.0), false)
	_c.draw_line(Vector2(lane.position.x, lane.end.y), lane.end, Color("#c89a5a", 0.55 * open), P2Pixel.w(2.0), false)
	if beat > 0.0 and not notes.is_empty():
		var tr0 := travel(notes[0])
		var k := floorf(_t / beat)
		while true:
			var bx := judge_x + (k * beat - _t) / tr0 * (spawn_x - judge_x)
			if bx > spawn_x:
				break
			if bx > judge_x + 30.0:
				_c.draw_line(Vector2(bx, lane.position.y + 4.0), Vector2(bx, lane.end.y - 4.0), Color("#c89a5a", 0.16 * open), P2Pixel.w(2.0), false)
			k += 1.0
	var jc := Vector2(judge_x, lane_y)
	_c.draw_circle(jc, 28.0, Color(0.0, 0.0, 0.0, 0.35 * open))
	_c.draw_arc(jc, 30.0, 0.0, TAU, 40, Color(Color.WHITE, 0.9 * open), P2Pixel.w(3.0), false)
	_c.draw_arc(jc, 22.0, 0.0, TAU, 40, Color(Color.WHITE, 0.3 * open), P2Pixel.w(2.0), false)
	_draw_drum(Vector2(left + 52.0, lane_y), don_lit, ka_lit, open)
	for pp in _pops:
		var pu := (_t - float(pp.t)) / 0.4
		_c.draw_arc(jc, lerpf(24.0, 40.0, pu), 0.0, TAU, 32, Color(C_ROLL, 0.8 * (1.0 - pu)), P2Pixel.w(3.0), false)
	for i in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[i]
		if n.grade != "":
			continue
		var x := x_at(n, float(n.at))
		if x > spawn_x + 30.0:
			continue
		if n.drum == "roll":
			_draw_roll(n, x, open)
		else:
			_note_disc(Vector2(x, lane_y), _side_color(String(n.drum)), bool(n.get("crush", false)), open)
	for f in _flying:
		var u := clampf((_t - float(f.t)) / 0.42, 0.0, 1.0)
		var p := jc.lerp(jc + Vector2(300, -10), u) + Vector2(0, -sin(u * PI) * 130.0)
		if u < 0.12:
			_c.draw_arc(jc, lerpf(26.0, 48.0, u / 0.12), 0.0, TAU, 40, Color(C_PERFECT if f.g == "perfect" else C_GOOD, 1.0 - u / 0.12), P2Pixel.w(6.0), false)
		_note_disc(p, f.c, bool(f.big), (1.0 - u) * open, lerpf(1.0, 0.6, u))
	_flying = _flying.filter(func(f): return _t - float(f.t) < 0.42)
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if n.grade != "" and _t - float(n.judged_t) < BURST:
			_draw_hit(n, clampf((_t - float(n.judged_t)) / BURST, 0.0, 1.0))


func _draw_drum(at: Vector2, don_lit: float, ka_lit: float, open: float) -> void:
	_c.draw_circle(at + Vector2(0, 6), 38.0, Color(0, 0, 0, 0.4 * open))
	_c.draw_circle(at, 38.0, Color(C_OUT, open))
	_c.draw_circle(at, 35.0, Color(C_KA.darkened(0.25).lerp(Color.WHITE, ka_lit * 0.55), open))
	_c.draw_circle(at, 27.0, Color(C_OUT, open))
	_c.draw_circle(at, 25.0, Color(Color("#f4e2c4").lerp(C_DON, 0.25 + 0.6 * don_lit), open))
	_c.draw_arc(at, 31.0, -2.4, -0.7, 12, Color(1, 1, 1, 0.35 * open), P2Pixel.w(2.0), false)
	if _streak >= 2:
		var tx := str(_streak)
		var w := _font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_c.text(_font, (at + Vector2(-w / 2.0, 9.0)).round(), tx, 24, Color(1, 1, 1, open), 5, Color(C_OUT, open))


func _note_disc(at: Vector2, col: Color, big: bool, a: float, scale_k := 1.0) -> void:
	var r := (30.0 if big else 21.0) * scale_k
	_c.draw_circle(at, r + 4.0, Color(C_OUT, a))
	_c.draw_circle(at, r + 1.0, Color(1, 1, 1, 0.95 * a))
	_c.draw_circle(at, r - 2.5, Color(col, a))
	_c.draw_arc(at, r - 7.0, -2.6, -1.0, 10, Color(1, 1, 1, 0.4 * a), P2Pixel.w(3.0), false)
	if big:
		_c.draw_arc(at, r + 8.0, 0.0, TAU, 36, Color("#8a1c0c", 0.9 * a), P2Pixel.w(4.0), false)


func _draw_roll(n: Dictionary, x: float, open: float) -> void:
	var x1 := minf(x_at(n, float(n.at) + float(n.hold)), spawn_x)
	var x0 := maxf(x, judge_x)
	var w := maxf(x1 - x0, 0.0)
	_c.draw_rect(Rect2(x0, lane_y - 21.0, w, 42.0), Color(C_OUT, open))
	_c.draw_rect(Rect2(x0, lane_y - 18.0, w, 36.0), Color(1, 1, 1, 0.95 * open))
	_c.draw_rect(Rect2(x0, lane_y - 15.0, w, 30.0), Color(C_ROLL, open))
	_c.draw_circle(Vector2(x1, lane_y), 21.0, Color(C_OUT, open))
	_c.draw_circle(Vector2(x1, lane_y), 18.0, Color(1, 1, 1, 0.95 * open))
	_c.draw_circle(Vector2(x1, lane_y), 15.0, Color(C_ROLL, open))
	_note_disc(Vector2(x0, lane_y), C_ROLL, false, open)
	if w > 70.0:
		_c.text(_small, Vector2(x0 + 30.0, lane_y + 5.0).round(), "연타", 12, Color("#5a3a00", open), 0)
	var rolling := _t >= float(n.at) - good_early
	if rolling:
		var need := roll_need(n)
		var got := int(n.rolls)
		var b := Vector2(judge_x, lane_y - 58.0)
		var tx := "%d / %d" % [got, need]
		var tw := _font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var bub := Rect2(b - Vector2(tw / 2.0 + 10.0, 14.0), Vector2(tw + 20.0, 26.0))
		_c.draw_rect(bub.grow(3.0), Color(C_OUT, open))
		_c.draw_rect(bub, Color(C_ROLL if got >= need else Color("#fff4d0"), open))
		_c.draw_colored_polygon(PackedVector2Array([b + Vector2(-6, 12), b + Vector2(6, 12), b + Vector2(0, 20)]), Color(C_ROLL if got >= need else Color("#fff4d0"), open))
		_c.text(_font, (b + Vector2(-tw / 2.0, 6.0)).round(), tx, 18, Color("#3a2400", open), 0)


func _draw_hit(n: Dictionary, u: float) -> void:
	var p := Vector2(judge_x, lane_y)
	match String(n.grade):
		"perfect":
			_label(p, "연타!" if n.drum == "roll" else "완벽", C_PERFECT, u)
		"good":
			_label(p, "막음", C_GOOD, u)
		_:
			_c.draw_line(p + Vector2(-10, -10), p + Vector2(10, 10), Color(C_MISS, 1.0 - u), P2Pixel.w(4.0), false)
			_c.draw_line(p + Vector2(10, -10), p + Vector2(-10, 10), Color(C_MISS, 1.0 - u), P2Pixel.w(4.0), false)
			_label(p, "놓침", C_MISS, u)


func _label(p: Vector2, text: String, c: Color, u: float) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var at := (p + Vector2(-w / 2.0, -38.0 - 14.0 * u)).round()
	var a := 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
	_c.text(_font, at, text, 18, Color(c, a), 5, Color(0.05, 0.03, 0.02, a))
