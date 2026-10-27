class_name P2ArrowChart
extends P2NoteChart

# 원거리 공격(사수 화살 · 맥 귀족 물창): 언다인식 방향 막기. 주인공 자리 상자 가운데 심장으로 네 방향에서 화살이 날아온다.
# 방패는 마우스가 있는 쪽(심장 기준 위·오른쪽·아래·왼쪽)을 보고, 방향키·WASD로도 돌린다(마지막에 쓴 쪽이 이김). 처음엔 적 쪽(오른쪽).
# 닿는 순간 그쪽을 보고 있으면 막음(완벽), 아니면 맞음(놓침) — 누르는 타이밍은 보지 않는다(장르 그대로).
# 노랑 = 가까이 와서 심장을 넘어 반대쪽에서 닿음 · 붉은 꼬리 = 빠른 화살 · 굵고 붉은 화살 = 강타(막아도 절반).
# 박자 반주·부름·신호는 P2NoteChart 그대로 쓰고, 판정·그림·입력만 다르다

const DIRS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const KEYS := [[KEY_UP, KEY_W], [KEY_RIGHT, KEY_D], [KEY_DOWN, KEY_S], [KEY_LEFT, KEY_A]]
const LETTER := ["W", "D", "S", "A"]
const BOX := 236.0
const SOUL_R := 30.0
const SPAWN := 260.0
const TRAVEL := 1.6
const HOP := 0.18
const HOP_AT := 96.0
const GRACE := 0.03
const OPEN := 0.16
const AIM_DEAD := 14.0
const C_NORMAL := Color("#e6f3ff")
const C_REV := Color("#ffd447")
const C_FAST := Color("#ff6a3d")
const C_HEAVY := Color("#ff4a3a")
const C_SHIELD := Color("#59b8ff")
const C_SOUL := Color("#3fd468")
const C_FRAME := Color("#f3ead7")
const HEART := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]

var center := Vector2(430, 280)
var face := 1
var _prev_face := 1
var _turn_t := -9.0
var _slow := 1.0
var _hurt_t := -9.0
var _block_t := -9.0
var _shards: Array = []
var _key_anchor := Vector2(-9999, -9999)


func setup(list: Array, r: float, tex: Texture2D, wide: bool) -> void:
	super(list, r, tex, wide)
	for n in notes:
		n.lane = clampi(int(n.get("lane", 1)), 0, 3)
		n.arrow = String(n.get("arrow", "n"))
		n.pos = center + _dir(int(n.lane)) * SOUL_R


# 입문·난이도 판정 배수는 화살이 날아오는 시간으로 받는다(넓을수록 느리게)
func ease(k: float) -> void:
	super(k)
	_slow = clampf(k, 0.75, 1.5)


func _dir(l: int) -> Vector2:
	return DIRS[l]


func travel(n: Dictionary) -> float:
	return float(n.approach) * TRAVEL * _slow


func _speed(n: Dictionary) -> float:
	return (SPAWN - SOUL_R) / travel(n)


func hop_t(n: Dictionary) -> float:
	return float(n.at) - (HOP_AT - SOUL_R) / _speed(n) - HOP


func appear_t(n: Dictionary) -> float:
	if n.arrow == "rev":
		return hop_t(n) - (SPAWN - HOP_AT) / _speed(n)
	return float(n.at) - travel(n)


func lane_at(n: Dictionary) -> int:
	if n.arrow == "rev" and _t < hop_t(n) + HOP * 0.5:
		return (int(n.lane) + 2) % 4
	return int(n.lane)


func head_pos(n: Dictionary) -> Vector2:
	var v := _speed(n)
	var l := int(n.lane)
	if n.arrow == "rev":
		var h := hop_t(n)
		var from := (l + 2) % 4
		if _t < h:
			return center + _dir(from) * (HOP_AT + (h - _t) * v)
		if _t < h + HOP:
			var u := (_t - h) / HOP
			var a := center + _dir(from) * HOP_AT
			var b := center + _dir(l) * HOP_AT
			return a.lerp(b, u) + _dir(l).orthogonal() * sin(u * PI) * 74.0
	return center + _dir(l) * (SOUL_R + maxf(float(n.at) - _t, 0.0) * v)


func end_time() -> float:
	var e := 0.0
	for n in notes:
		e = maxf(e, float(n.at))
	return e + GRACE


func _process(delta: float) -> void:
	var dt := 0.0 if _focus_lost else delta
	_t += dt
	while not _cues.is_empty() and float(_cues[0].t) - _lat <= _t:
		var c: Dictionary = _cues.pop_front()
		cue.emit(String(c.key), int(c.step), float(c.vol))
	var done := true
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if not n.closed and _t >= float(n.at):
			n.closed = true
			closed.emit(i)
		if n.grade == "" and _t >= float(n.at) + GRACE:
			var ok := face == int(n.lane)
			if ok:
				_block_t = _t
				_shatter(n)
			else:
				_hurt_t = _t
			_judge(i, "perfect" if ok else "miss", 0.0)
		if n.grade == "" or _t - float(n.judged_t) < 0.45:
			done = false
	for s in _shards:
		s.p += s.v * dt
		s.v *= 0.9
	_shards = _shards.filter(func(s): return _t - float(s.t) < 0.32)
	if done and _t > end_time():
		queue_free()
	_c.redraw()


func _shatter(n: Dictionary) -> void:
	var d := _dir(int(n.lane))
	var hit := center + d * (SOUL_R + 4.0)
	var col := _color(n)
	for k in range(6):
		var a := d.rotated((k - 2.5) * 0.45)
		_shards.append({"p": hit, "v": a * (140.0 + 50.0 * (k % 2)), "t": _t, "c": col if k % 2 == 0 else C_SHIELD})


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim((make_input_local(event) as InputEventMouseMotion).position)
		return
	if not event is InputEventKey or (event as InputEventKey).echo:
		return
	var id := key_id(event as InputEventKey)
	var l := -1
	for k in range(4):
		if id in KEYS[k]:
			l = k
	if l < 0:
		return
	if event.pressed:
		_held[id] = true
		held.emit(id, true, LETTER[l])
		_key_anchor = get_local_mouse_position()
		_turn(l)
	else:
		_held.erase(id)
		held.emit(id, false, LETTER[l])
	get_viewport().set_input_as_handled()


# 마우스: 심장에서 본 커서 쪽(가로·세로 중 더 큰 쪽). 심장 바로 위(가운데 14px)에서는 그대로 둔다
# 마우스: 커서가 상자 안(테두리 24px 여유)일 때만 방패가 따라간다. 키로 돌린 뒤에는 마우스가 24px 넘게 움직여야 다시 마우스를 따른다
# (키보드로 하는 사람이 마우스를 아무 데나 둬도 방패가 끌려가지 않게)
func _aim(p: Vector2) -> void:
	var half := BOX / 2.0 + 24.0
	var v := p - center
	if absf(v.x) > half or absf(v.y) > half or v.length() < AIM_DEAD:
		return
	if _key_anchor.x > -9000.0:
		if p.distance_to(_key_anchor) < 24.0:
			return
		_key_anchor = Vector2(-9999, -9999)
	if absf(v.x) >= absf(v.y):
		_turn(1 if v.x > 0.0 else 3)
	else:
		_turn(0 if v.y < 0.0 else 2)


func _turn(l: int) -> void:
	if l != face:
		_prev_face = face
		_turn_t = _t
	face = l


# 점검 드라이버·봇: 다음 화살이 올 쪽으로 방패를 돌린다
func press_now() -> void:
	var i := _current()
	if i >= 0:
		_turn(int(notes[i].lane))


func cue_rect() -> Rect2:
	return Rect2(center - Vector2(BOX, BOX) / 2.0, Vector2(BOX, BOX))


func release_now() -> void:
	pass


func _color(n: Dictionary) -> Color:
	if bool(n.get("crush", false)):
		return C_HEAVY
	return {"rev": C_REV, "fast": C_FAST}.get(String(n.arrow), C_NORMAL)


func _paint() -> void:
	var open := _open_amount()
	if open <= 0.0:
		return
	var hurt := clampf(1.0 - (_t - _hurt_t) / 0.3, 0.0, 1.0)
	var shake := Vector2(sin(_t * 90.0), cos(_t * 70.0)) * 4.0 * hurt
	var half := BOX * lerpf(0.82, 1.0, ease_out(open)) / 2.0
	var box := Rect2(center + shake - Vector2(half, half), Vector2(half, half) * 2.0)
	_draw_frame(box, open, hurt)
	_draw_guard(open)
	for l in range(4):
		var d := _dir(l)
		var edge := center + shake + d * (half - 16.0)
		var side := d.orthogonal() * 9.0
		var on := face == l
		_c.draw_colored_polygon(PackedVector2Array([edge - d * 8.0, edge + d * 4.0 + side, edge + d * 4.0 - side]), Color(C_SHIELD if on else C_APPROACH, (0.9 if on else 0.28) * open))
		var lw := _small.get_string_size(LETTER[l], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_c.text(_small, (edge + side * 1.9 + Vector2(-lw / 2.0, 5.0)).round(), LETTER[l], 12, Color(C_APPROACH, 0.5 * open), 3, Color(C_OUT, 0.8 * open))
	if call > 0.0:
		for n in notes:
			var u := (_t - (float(n.at) - call)) / 0.3
			if u >= 0.0 and u <= 1.0:
				var d := _dir(int(n.lane))
				_c.draw_line(center + d * (SOUL_R + 14.0), center + d * (half - 16.0), Color(_color(n), 0.55 * (1.0 - u)), 8.0, false)
	for i in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[i]
		if n.grade == "" and _t >= appear_t(n):
			_draw_spear(n)
	for s in _shards:
		var u := (_t - float(s.t)) / 0.32
		var p: Vector2 = s.p
		var sz := lerpf(7.0, 3.0, u)
		_c.draw_rect(Rect2(p - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(s.c, 1.0 - u))
	_draw_soul(shake, open, hurt)


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


# 상자 틀: 그림자 · 어두운 바탕(옅은 점 무늬) · 상아 테두리 · 모서리 한 칸 깎기. 맞으면 붉은 안쪽 테
func _draw_frame(box: Rect2, open: float, hurt: float) -> void:
	_stage(box, "화살 막기", "상자 안 마우스 쪽 · WASD", open, C_SHIELD)
	var y := box.position.y + 12.0
	while y < box.end.y - 6.0:
		var x := box.position.x + 12.0
		while x < box.end.x - 6.0:
			_c.draw_rect(Rect2(x, y, 2, 2), Color(C_FRAME, 0.05 * open))
			x += 24.0
		y += 24.0
	if hurt > 0.0:
		_c.draw_rect(box.grow(-6.0), Color(C_HEAVY, 0.45 * hurt), false, P2Pixel.w(8.0))


# 방패가 지키는 쪽: 심장에서 상자 끝까지 옅은 푸른 부채꼴(어느 쪽이 막히는지 한눈에)
func _draw_guard(open: float) -> void:
	var d := _dir(face)
	var reach := BOX / 2.0 - 8.0
	var swing := clampf((_t - _turn_t) / 0.08, 0.0, 1.0)
	var lit := clampf(1.0 - (_t - _block_t) / 0.2, 0.0, 1.0)
	var fan := PackedVector2Array([center + d * (SOUL_R + 6.0)])
	for k in range(9):
		fan.append(center + d.rotated(-PI / 4.0 + PI / 2.0 * k / 8.0) * reach)
	_c.draw_colored_polygon(fan, Color(C_SHIELD, (0.07 + 0.1 * lit) * open * swing))


func _draw_soul(shake: Vector2, open: float, hurt: float) -> void:
	var blink := hurt > 0.0 and int(_t * 30.0) % 2 == 0
	var soul := Color.WHITE if blink else C_SOUL
	var c := center + shake
	_c.draw_circle(c, 24.0, Color(C_SOUL, 0.12 * open))
	_c.draw_arc(c, SOUL_R + 14.0, 0.0, TAU, 48, Color(C_SOUL, 0.3 * open), P2Pixel.w(2.0), false)
	var px := 4.0
	var o := c - Vector2(HEART[0].length() * px, HEART.size() * px) / 2.0
	for pass_i in range(2):
		for y in range(HEART.size()):
			var row: String = HEART[y]
			for x in range(row.length()):
				if row[x] != "X":
					continue
				var at := o + Vector2(x, y) * px
				if pass_i == 0:
					_c.draw_rect(Rect2(at - Vector2(2, 2), Vector2(px + 4.0, px + 4.0)), Color(C_OUT, 0.9 * open))
				else:
					_c.draw_rect(Rect2(at, Vector2(px, px)), Color(soul, open))
	_c.draw_rect(Rect2(o + Vector2(1, 1) * px, Vector2(px, px)), Color(1, 1, 1, 0.7 * open))
	var lit := clampf(1.0 - (_t - _block_t) / 0.18, 0.0, 1.0)
	var ang := _dir(face).angle()
	var swing := clampf((_t - _turn_t) / 0.08, 0.0, 1.0)
	var r := SOUL_R - 4.0 * lit
	if swing < 1.0:
		var a0 := _dir(_prev_face).angle()
		var diff := wrapf(ang - a0, -PI, PI)
		_c.draw_arc(c, r, a0, a0 + diff * swing, 16, Color(C_SHIELD, 0.4 * (1.0 - swing)), P2Pixel.w(6.0), false)
	if lit > 0.0:
		_c.draw_arc(c, lerpf(SOUL_R + 30.0, SOUL_R + 4.0, lit), ang - 0.9, ang + 0.9, 20, Color(C_SHIELD, 0.6 * lit), P2Pixel.w(4.0), false)
	var w := lerpf(8.0, 12.0, lit)
	var col := C_SHIELD.lerp(Color.WHITE, lit)
	_c.draw_arc(c, r, ang - 0.8, ang + 0.8, 16, Color(C_OUT, 0.95 * open), P2Pixel.w(w) + 4.0, false)
	_c.draw_arc(c, r, ang - 0.8, ang + 0.8, 16, Color(col, open), P2Pixel.w(w), false)
	_c.draw_arc(c, r - 2.0, ang - 0.55, ang + 0.55, 12, Color(Color.WHITE, 0.55 * open), P2Pixel.w(2.0), false)


func _draw_spear(n: Dictionary) -> void:
	var head := head_pos(n)
	var col := _color(n)
	var since := _t - appear_t(n)
	var k := clampf(since / FADE_IN, 0.0, 1.0)
	if hidden_mod and head.distance_to(center) < SPAWN * 0.45 and not (n.arrow == "rev" and _t < hop_t(n) + HOP):
		k *= clampf((head.distance_to(center) - SOUL_R - 30.0) / 40.0, 0.0, 1.0)
	if k <= 0.01:
		return
	var to_soul := (center - head).normalized()
	if n.arrow == "rev" and _t >= hop_t(n) and _t < hop_t(n) + HOP:
		to_soul = -_dir((int(n.lane) + 2) % 4).rotated(PI * (_t - hop_t(n)) / HOP)
	if to_soul == Vector2.ZERO:
		to_soul = -_dir(int(n.lane))
	var heavy := bool(n.get("crush", false))
	var length := 54.0 if heavy else 40.0
	var shaft := 6.0 if heavy else 4.0
	var tail := head - to_soul * length
	var side := to_soul.orthogonal()
	if since < 0.12:
		var g := 1.0 - since / 0.12
		var star := 10.0 * g + 4.0
		_c.draw_line(head - side * star, head + side * star, Color(Color.WHITE, 0.8 * g), P2Pixel.w(2.0), false)
		_c.draw_line(head - to_soul * star, head + to_soul * star, Color(Color.WHITE, 0.8 * g), P2Pixel.w(2.0), false)
	if n.arrow == "fast":
		for s in [-1.0, 1.0]:
			_c.draw_line(tail + side * 5.0 * s, tail - to_soul * 30.0 + side * 5.0 * s, Color(col, 0.45 * k), P2Pixel.w(2.0), false)
	if n.arrow == "rev":
		_c.draw_line(tail, head, Color(col, 0.25 * k), P2Pixel.w(shaft) + 8.0, false)
		if _t < hop_t(n) and hop_t(n) - _t < 0.12 and int(_t * 24.0) % 2 == 0:
			col = Color.WHITE
	_c.draw_line(tail, head - to_soul * 6.0, Color(C_OUT, 0.9 * k), P2Pixel.w(shaft) + 4.0, false)
	_c.draw_line(tail, head - to_soul * 6.0, Color(col, k), P2Pixel.w(shaft), false)
	for s in [-1.0, 1.0]:
		_c.draw_line(tail + to_soul * 8.0, tail - to_soul * 2.0 + side * 7.0 * s, Color(col.darkened(0.25), k), P2Pixel.w(2.0), false)
	var hw := 10.0 if heavy else 8.0
	var tip := PackedVector2Array([head + to_soul * 3.0, head - to_soul * 13.0 + side * hw, head - to_soul * 13.0 - side * hw])
	var rim := PackedVector2Array([head + to_soul * 6.0, head - to_soul * 15.0 + side * (hw + 3.0), head - to_soul * 15.0 - side * (hw + 3.0)])
	_c.draw_colored_polygon(rim, Color(C_OUT, 0.9 * k))
	_c.draw_colored_polygon(tip, Color(col, k))
