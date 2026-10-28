class_name P2EchoChart
extends P2NoteChart

# 소환사 보스·미믹의 고유 문장: 리듬 천국식 부름-응답. 적이 먼저 박자를 치고(빛·종소리), 세 박 쉰 뒤 같은 박자를 노트 없이 따라 친다.
# 아래 띠에 박자 눈금이 있고, 부름 때는 칠 자리가 하나씩 빛나며, 응답 때는 커서만 지나간다(show_ghost면 칠 자리가 흐리게 남음).
# 클릭(왼쪽·오른쪽)이나 아무 키. 판정 창·박자·부름 종소리(arrange)·신호는 P2NoteChart 그대로

const C_CALL := Color("#ffd86a")

var lane_y := 572.0
var x0 := 430.0
var x1 := 930.0
var show_ghost := false
var _r0 := 0.0
var _r1 := 1.0
var _marks: Array = []


func setup(list: Array, r: float, tex: Texture2D, wide: bool) -> void:
	super(list, r, tex, wide)
	for n in notes:
		n.pos = Vector2(x0, lane_y)


# 응답 구간(첫 노트 반 박 앞 ~ 마지막 노트 반 박 뒤)을 띠 길이로 잡는다. beat·call을 정한 뒤 부른다
func arrange() -> void:
	super()
	var half := (beat if beat > 0.0 else 0.5) / 2.0
	_r0 = INF
	_r1 = -INF
	for n in notes:
		_r0 = minf(_r0, float(n.at) - half)
		_r1 = maxf(_r1, float(n.at) + half)
	for n in notes:
		n.pos = Vector2(_x_of(float(n.at)), lane_y)


func _x_of(t: float) -> float:
	return lerpf(x0, x1, clampf((t - _r0) / maxf(_r1 - _r0, 0.01), 0.0, 1.0))


func _input(event: InputEvent) -> void:
	_catch_up()
	if event is InputEventMouseButton and event.pressed:
		var mb := (event as InputEventMouseButton).button_index
		if mb == MOUSE_BUTTON_LEFT or mb == MOUSE_BUTTON_RIGHT:
			_answer()
			get_viewport().set_input_as_handled()
		return
	if is_hit_key(event):
		var id := key_id(event as InputEventKey)
		if event.pressed:
			_held[id] = true
			held.emit(id, true, OS.get_keycode_string(id))
			_answer()
		else:
			_held.erase(id)
			held.emit(id, false, OS.get_keycode_string(id))
		get_viewport().set_input_as_handled()


func _answer() -> void:
	cue.emit("stick", 0, -5.0)
	var i := _current()
	if i < 0 or _t - float(notes[i].at) - offset < -good_early:
		_marks.append({"t": _t, "g": ""})
		return
	_hit(i)
	_marks.append({"t": _t, "g": String(notes[i].grade)})


func press_now() -> void:
	var i := _current()
	if i >= 0:
		_hit(i)
		_marks.append({"t": _t, "g": String(notes[i].grade)})


func cue_rect() -> Rect2:
	return Rect2(x0 - 120.0, lane_y - 66.0, x1 - x0 + 150.0, 128.0)


func _paint() -> void:
	var open := _open_amount()
	if open <= 0.0:
		return
	var bt := beat if beat > 0.0 else 0.5
	var first := INF
	for n in notes:
		first = minf(first, float(n.at))
	var calling := _t < _r1 - call
	var answering := _t >= first - bt * 0.5
	var stage := Rect2(x0 - 120.0, lane_y - 66.0, x1 - x0 + 150.0, 128.0)
	_stage(stage, "부름-응답", "들은 대로 클릭 · 아무 키", open, C_CALL)
	var top_y := lane_y - 26.0
	var you_y := lane_y + 26.0
	var on_call := calling and _t >= _r0 - call
	_c.draw_rect(Rect2(x0 - 16.0, top_y - 20.0, x1 - x0 + 32.0, 40.0), Color(C_CALL, (0.1 if on_call else 0.03) * open))
	_c.draw_rect(Rect2(x0 - 16.0, you_y - 20.0, x1 - x0 + 32.0, 40.0), Color(Color("#3fd468"), (0.1 if answering else 0.03) * open))
	_badge(Vector2(x0 - 70.0, top_y), "적", Color("#d8483e"), open)
	_badge(Vector2(x0 - 70.0, you_y), "나", Color("#3fd468"), open)
	var half := bt / 2.0
	var k := 0
	while _r0 + k * half <= _r1 + 0.001:
		var x := _x_of(_r0 + k * half)
		var strong := k % 2 == 1
		for y in [top_y, you_y]:
			_c.draw_line(Vector2(x, y - (10.0 if strong else 5.0)), Vector2(x, y + (10.0 if strong else 5.0)), Color(C_APPROACH, (0.4 if strong else 0.16) * open), P2Pixel.w(2.0), false)
		k += 1
	for y in [top_y, you_y]:
		_c.draw_line(Vector2(x0, y), Vector2(x1, y), Color(C_APPROACH, 0.2 * open), P2Pixel.w(2.0), false)
	for n in notes:
		var x := float(n.pos.x)
		var since := _t - (float(n.at) - call)
		if since >= 0.0 and (calling or show_ghost or _t < first - bt * 2.0):
			var pop := clampf(1.0 - since / 0.15, 0.0, 1.0)
			var fade := 1.0 if calling or _t < first - bt * 2.0 else 0.35
			_note_glyph(Vector2(x, top_y - pop * 10.0), 1.0 + 0.5 * pop, C_CALL.lerp(Color.WHITE, pop), fade * open)
		if show_ghost and n.grade == "" and answering:
			_c.draw_arc(Vector2(x, you_y), 9.0, 0.0, TAU, 20, Color(C_CALL, 0.3 * open), P2Pixel.w(2.0), false)
		if n.grade == "miss":
			var u := clampf((_t - float(n.judged_t)) / BURST, 0.0, 1.0)
			_c.draw_line(Vector2(x - 8, you_y - 8), Vector2(x + 8, you_y + 8), Color(C_MISS, 1.0 - 0.5 * u), P2Pixel.w(3.0), false)
			_c.draw_line(Vector2(x + 8, you_y - 8), Vector2(x - 8, you_y + 8), Color(C_MISS, 1.0 - 0.5 * u), P2Pixel.w(3.0), false)
	for m in _marks:
		if float(m.t) < _r0 - 0.3:
			continue
		var col: Color = {"perfect": C_PERFECT, "good": C_GOOD}.get(String(m.g), C_MISS)
		var u := clampf((_t - float(m.t)) / 0.15, 0.0, 1.0)
		_note_glyph(Vector2(_x_of(float(m.t)), you_y - (1.0 - u) * 10.0), 1.0 + 0.5 * (1.0 - u), col, open)
		if u < 1.0 and String(m.g) == "perfect":
			_c.draw_arc(Vector2(_x_of(float(m.t)), you_y), lerpf(10.0, 26.0, u), 0.0, TAU, 20, Color(C_PERFECT, 1.0 - u), P2Pixel.w(3.0), false)
	if not calling and not answering and _t >= first - bt * 3.0:
		var count := ceili((first - _t) / bt)
		var tx := str(clampi(count, 1, 3))
		var pu := 1.0 - fposmod(first - _t, bt) / bt
		var w := _font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_c.text(_font, (Vector2((x0 + x1) / 2.0 - w / 2.0, you_y + 9.0)).round(), tx, 24, Color(Color("#3fd468").lerp(Color.WHITE, 1.0 - pu), open), 5, Color(C_OUT, open))
	var ct := _t + (call if calling else 0.0)
	if ct >= _r0 and ct <= _r1 and (calling or answering):
		var cx := _x_of(ct)
		var cy := top_y if calling else you_y
		_c.draw_line(Vector2(cx, cy - 18.0), Vector2(cx, cy + 18.0), Color(C_CALL if calling else Color.WHITE, 0.9 * open), P2Pixel.w(4.0), false)


func _badge(at: Vector2, text: String, col: Color, open: float) -> void:
	var r := Rect2(at - Vector2(26, 14), Vector2(52, 28))
	_c.draw_rect(r.grow(3.0), Color(C_OUT, open))
	_c.draw_rect(r, Color(col.darkened(0.55), open))
	_c.draw_rect(r, Color(col, open), false, P2Pixel.w(2.0))
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_c.text(_font, (at + Vector2(-w / 2.0, 7.0)).round(), text, 18, Color(col.lightened(0.5), open), 3, Color(C_OUT, open))


# 음표 ♪: 머리 · 기둥 · 꼬리
func _note_glyph(at: Vector2, k: float, col: Color, a: float) -> void:
	var r := 7.0 * k
	var head := at + Vector2(-2.0, 6.0) * k
	var top := head + Vector2(r - 1.0, -22.0 * k)
	_c.draw_circle(head, r + 3.0, Color(C_OUT, a))
	_c.draw_line(head + Vector2(r - 1.0, 0), top, Color(C_OUT, a), P2Pixel.w(3.0) + 4.0, false)
	_c.draw_line(top, top + Vector2(8.0, 7.0) * k, Color(C_OUT, a), P2Pixel.w(3.0) + 4.0, false)
	_c.draw_circle(head, r, Color(col, a))
	_c.draw_line(head + Vector2(r - 1.0, 0), top, Color(col, a), P2Pixel.w(3.0), false)
	_c.draw_line(top, top + Vector2(8.0, 7.0) * k, Color(col, a), P2Pixel.w(3.0), false)
