class_name P2DodgeChart
extends P2NoteChart

# 범위 마법(주술사·독침병·포격 장치): 크립트 오브 더 네크로댄서처럼 박자에 맞춰 칸 피하기. 주인공 자리 3×3 판.
# 심장은 마우스가 있는 칸으로 가고(판 밖이면 가장 가까운 칸), 방향키·WASD로 한 칸씩도 간다(마지막에 쓴 쪽).
# 칸이 붉게 깜빡이며 박자를 세다가(2 · 1) 그 박자에 터진다. 터질 때 그 칸 밖이면 피함(완벽), 안이면 맞음(놓침).
# 보라 = 나를 노림(터지기 한 박 전에 내가 선 칸에 고정). 판정·박자·부름·신호는 P2NoteChart 그대로

const CELL := 72.0
const WARN_BEATS := 2.0
const LOCK_BEATS := 0.75
const GRACE := 0.03
const KEYS := [[KEY_UP, KEY_W], [KEY_RIGHT, KEY_D], [KEY_DOWN, KEY_S], [KEY_LEFT, KEY_A]]
const STEP := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const C_WARN := Color("#ff5a3c")
const C_CHASE := Color("#b48cff")
const C_SOUL := Color("#3fd468")
const C_FRAME := Color("#f3ead7")
const HEART := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]

var center := Vector2(640, 540)
var cell := Vector2i(1, 1)
var _from := Vector2i(1, 1)
var _moved_t := -9.0
var _hurt_t := -9.0
var _slow := 1.0
var _blasts: Array = []
var _key_anchor := Vector2(-9999, -9999)


func setup(list: Array, r: float, tex: Texture2D, wide: bool) -> void:
	super(list, r, tex, wide)
	for n in notes:
		n.sub = String(n.get("sub", "row"))
		n.tiles = (n.get("tiles", []) as Array).duplicate()
		n.pos = center


func ease(k: float) -> void:
	super(k)
	_slow = clampf(k, 0.75, 1.5)


func origin() -> Vector2:
	return center - Vector2(1.5, 1.5) * CELL


func tile_rect(v: Vector2i) -> Rect2:
	return Rect2(origin() + Vector2(v) * CELL, Vector2(CELL, CELL))


func warn(n: Dictionary) -> float:
	return (beat if beat > 0.0 else 0.5) * WARN_BEATS * _slow


func lock_t(n: Dictionary) -> float:
	return float(n.at) - (beat if beat > 0.0 else 0.5) * LOCK_BEATS


func danger(n: Dictionary) -> Array:
	if n.sub == "chase" and (n.tiles as Array).is_empty():
		return [cell]
	return n.tiles


func end_time() -> float:
	var e := 0.0
	for n in notes:
		e = maxf(e, float(n.at))
	return e + GRACE


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
			# 터지는 박에 비켜나 있으면 그 박에 소리(판정은 GRACE 뒤)
			if n.grade == "" and not (danger(n) as Array).has(cell):
				n.rang = true
				struck.emit(i, 0)
		if n.grade == "":
			if n.sub == "chase" and (n.tiles as Array).is_empty() and _t >= lock_t(n):
				n.tiles = [cell]
				cue.emit("stick", 0, -4.0)
			if _t >= float(n.at) + GRACE:
				var hit := (danger(n) as Array).has(cell)
				for v in danger(n):
					_blasts.append({"v": v, "t": _t, "c": C_CHASE if n.sub == "chase" else C_WARN})
				if hit:
					_hurt_t = _t
				elif not bool(n.get("rang", false)):
					struck.emit(i, 0)
				_judge(i, "miss" if hit else "perfect", 0.0)
		if n.grade == "" or _t - float(n.judged_t) < 0.45:
			done = false
	_blasts = _blasts.filter(func(b): return _t - float(b.t) < 0.35)
	if done and _t > end_time():
		queue_free()
	_c.redraw()


func _input(event: InputEvent) -> void:
	_catch_up()
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
		held.emit(id, true, ["W", "D", "S", "A"][l])
		_key_anchor = get_local_mouse_position()
		_move(cell + STEP[l])
	else:
		_held.erase(id)
		held.emit(id, false, ["W", "D", "S", "A"][l])
	get_viewport().set_input_as_handled()


# 마우스: 커서가 판 안(16px 여유)일 때만 그 칸으로. 키로 옮긴 뒤에는 마우스가 24px 넘게 움직여야 다시 마우스를 따른다
func _aim(p: Vector2) -> void:
	if not Rect2(origin(), Vector2(CELL, CELL) * 3.0).grow(16.0).has_point(p):
		return
	if _key_anchor.x > -9000.0:
		if p.distance_to(_key_anchor) < 24.0:
			return
		_key_anchor = Vector2(-9999, -9999)
	var v := ((p - origin()) / CELL).floor()
	_move(Vector2i(clampi(int(v.x), 0, 2), clampi(int(v.y), 0, 2)))


func _move(to: Vector2i) -> void:
	to = Vector2i(clampi(to.x, 0, 2), clampi(to.y, 0, 2))
	if to == cell:
		return
	_from = cell
	cell = to
	_moved_t = _t


# 점검 드라이버·봇: 지금 터질 칸을 피해 가장 가까운 안전한 칸으로
func press_now() -> void:
	var i := _current()
	if i < 0:
		return
	var bad: Array = danger(notes[i])
	if not bad.has(cell):
		return
	var best := cell
	var bd := 99
	for y in range(3):
		for x in range(3):
			var v := Vector2i(x, y)
			var d := absi(v.x - cell.x) + absi(v.y - cell.y)
			if not bad.has(v) and d < bd:
				bd = d
				best = v
	_move(best)


func cue_rect() -> Rect2:
	var board := Rect2(origin(), Vector2(CELL, CELL) * 3.0)
	return Rect2(board.position - Vector2(16, 14), board.size + Vector2(32, 62))


func release_now() -> void:
	pass


func _paint() -> void:
	var open := _open_amount()
	if open <= 0.0:
		return
	var hurt := clampf(1.0 - (_t - _hurt_t) / 0.3, 0.0, 1.0)
	var shake := Vector2(sin(_t * 90.0), cos(_t * 70.0)) * 4.0 * hurt
	var board := Rect2(origin() + shake, Vector2(CELL, CELL) * 3.0)
	var stage := Rect2(board.position - Vector2(16, 14), board.size + Vector2(32, 62))
	_stage(stage, "박자 피하기", "판 안 마우스 칸 · WASD", open, C_WARN)
	var bt := beat if beat > 0.0 else 0.5
	var phase := fposmod(_t, bt) / bt
	var pulse := pow(1.0 - phase, 3.0)
	var odd := int(floorf(_t / bt)) % 2 == 1
	for y in range(3):
		for x in range(3):
			var r := tile_rect(Vector2i(x, y))
			r.position += shake
			var even := (x + y) % 2 == 0
			var base := Color("#2c2836") if even else Color("#221f2b")
			_c.draw_rect(r.grow(-2.0), Color(base, open))
			if even == odd:
				_c.draw_rect(r.grow(-2.0), Color(Color("#7fd7d0") if odd else Color("#d79a6a"), 0.1 * pulse * open))
			_c.draw_rect(r.grow(-2.0), Color(C_FRAME, 0.1 * open), false, P2Pixel.w(2.0))
	for n in notes:
		if n.grade != "" or _t < float(n.at) - warn(n):
			continue
		var left := float(n.at) - _t
		var k := 1.0 - clampf(left / warn(n), 0.0, 1.0)
		var chase: bool = n.sub == "chase"
		var col := C_CHASE if chase else C_WARN
		var locked: bool = not chase or not (n.tiles as Array).is_empty()
		for v in danger(n):
			var r := tile_rect(v)
			r.position += shake
			_c.draw_rect(r.grow(-2.0), Color(col, (0.12 + 0.4 * k) * open))
			var w := lerpf(2.0, 6.0, pulse) if locked else 2.0
			_c.draw_rect(r.grow(-5.0), Color(col.lightened(0.2), (0.5 + 0.5 * pulse) * open), false, P2Pixel.w(w))
			if chase:
				var cc := r.get_center()
				var rr := lerpf(26.0, 14.0, k)
				_c.draw_arc(cc, rr, 0.0, TAU, 24, Color(col.lightened(0.3), open), P2Pixel.w(3.0), false)
				for d in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
					_c.draw_line(cc + d * (rr - 6.0), cc + d * (rr + 8.0), Color(col.lightened(0.3), open), P2Pixel.w(3.0), false)
			elif locked:
				var count := ceili(left / bt)
				if count >= 1 and count <= 3:
					var tx := str(count)
					var tw := _font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
					_c.text(_font, (r.get_center() + Vector2(-tw / 2.0, 10.0)).round(), tx, 24, Color(col.lightened(0.45), (0.6 + 0.4 * pulse) * open), 5, Color(C_OUT, open))
		if bool(n.get("crush", false)):
			_c.draw_rect(board.grow(4.0), Color("#8a1c0c", 0.7 * k * open), false, P2Pixel.w(6.0))
	for b in _blasts:
		var u := (_t - float(b.t)) / 0.35
		var r := tile_rect(b.v)
		r.position += shake
		var c := r.get_center()
		_c.draw_rect(r.grow(-2.0), Color(Color.WHITE.lerp(b.c, minf(1.0, u * 2.5)), 0.9 * (1.0 - u)))
		for f in range(5):
			var fx := c.x - 24.0 + f * 12.0
			var h := (28.0 + 14.0 * sin(f * 1.7 + _t * 30.0)) * (1.0 - u)
			_c.draw_line(Vector2(fx, c.y + 20.0), Vector2(fx, c.y + 20.0 - h - 20.0 * u), Color(Color("#ffd27a").lerp(b.c, u), 1.0 - u), P2Pixel.w(6.0), false)
		for k2 in range(4):
			var d := Vector2.RIGHT.rotated(TAU * (k2 + 0.5) / 4.0)
			var sp := c + d * lerpf(10.0, 44.0, u)
			_c.draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(b.c, 1.0 - u))
	if hurt > 0.0:
		_c.draw_rect(board.grow(2.0), Color(C_WARN, 0.5 * hurt), false, P2Pixel.w(8.0))
	_draw_beat_bar(Vector2(board.get_center().x, board.end.y + 26.0), board.size.x, bt, pulse, open)
	_draw_soul(shake, open, hurt)


# 네크로댄서식 박자 막대: 양쪽에서 박자 표시가 가운데 심장으로 모여들고, 박마다 심장이 뛴다
func _draw_beat_bar(at: Vector2, width: float, bt: float, pulse: float, open: float) -> void:
	var half := width / 2.0
	_c.draw_line(at - Vector2(half, 0), at + Vector2(half, 0), Color(C_FRAME, 0.15 * open), P2Pixel.w(2.0), false)
	var span := bt * 3.0
	var k := 0.0
	while k < 4.0:
		var u := (fposmod(_t, bt) + k * bt) / span
		if u <= 1.0:
			var off := half * (1.0 - u)
			var a := clampf(u * 2.0, 0.0, 1.0) * open
			for s in [-1.0, 1.0]:
				var x: float = at.x + s * off
				_c.draw_rect(Rect2(Vector2(x - 2.0, at.y - 9.0), Vector2(4, 18)), Color(Color("#7fd7d0"), a))
		k += 1.0
	var hr := 9.0 + 4.0 * pulse
	_c.draw_circle(at, hr + 3.0, Color(C_OUT, open))
	_c.draw_circle(at, hr, Color(Color("#ff5a6a").lerp(Color.WHITE, 0.4 * pulse), open))


func _draw_soul(shake: Vector2, open: float, hurt: float) -> void:
	var u := clampf((_t - _moved_t) / 0.08, 0.0, 1.0)
	var at := tile_rect(_from).get_center().lerp(tile_rect(cell).get_center(), u) + shake + Vector2(0, -sin(u * PI) * 10.0)
	var blink := hurt > 0.0 and int(_t * 30.0) % 2 == 0
	var soul := Color.WHITE if blink else C_SOUL
	_c.draw_circle(tile_rect(cell).get_center() + shake + Vector2(0, 18), 15.0 - 4.0 * sin(u * PI), Color(0, 0, 0, 0.4 * open))
	_c.draw_circle(at, 22.0, Color(C_SOUL, 0.14 * open))
	var px := 4.0
	var o := at - Vector2(HEART[0].length() * px, HEART.size() * px) / 2.0
	for pass_i in range(2):
		for y in range(HEART.size()):
			var row: String = HEART[y]
			for x in range(row.length()):
				if row[x] != "X":
					continue
				var q := o + Vector2(x, y) * px
				if pass_i == 0:
					_c.draw_rect(Rect2(q - Vector2(2, 2), Vector2(px + 4.0, px + 4.0)), Color(C_OUT, 0.9 * open))
				else:
					_c.draw_rect(Rect2(q, Vector2(px, px)), Color(soul, open))
	_c.draw_rect(Rect2(o + Vector2(1, 1) * px, Vector2(px, px)), Color(1, 1, 1, 0.7 * open))
