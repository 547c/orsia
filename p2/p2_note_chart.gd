class_name P2NoteChart
extends Node2D

# 손맛 시험판 적 공격 악보 (osu 방식): 노트마다 바깥 고리가 줄어들어 원에 닿는 순간이 칼이 닿는 순간.
# 마우스는 겨누기, 누르기는 키보드 아무 키(Esc·Tab·F키·조합키 빼고, 설정에 따라 Z·X만)나 왼쪽 클릭. 무엇이든 하나라도 누르고 있으면 누른 채로 본다.
# 판정 보정(offset): 내 손·기기가 늘 늦으면 그만큼 판정 순간을 뒤로 옮긴다(화면·소리는 그대로).
# 종류(색으로 구분): t 짧은(청백, 클릭) · h 롱(주황, 누른 채 둘레가 찰 때까지) · d 두 번(분홍, 닿을 때 클릭하고 곧바로 한 번 더) ·
# s 따라가기(초록, 누른 채 움직이는 공을 따라감) · f 도망(보라, 커서가 다가가면 두 번까지 달아남) · x 페인트(빨강, 누르면 속음 · 참으면 완벽).
# 클릭은 아직 판정 안 된 가장 앞 노트만 받는다(순서 잠금). 완벽 · 막음 · 놓침. 방어가 있으면(wide) 완벽 창이 넓고 금빛 띠가 두껍다.
# 겹치면 앞 번호가 위에 또렷하고, 뒤 번호는 앞 노트가 끝날 때까지 흐리다.
# 박자: beat가 있으면 시작부터 끝까지 반주(박마다 킥, 반 박마다 하이햇, 2·4박 스네어)를 cue로 내보낸다. 노트는 이 박자 위에 놓인다.
# 부름(call): 노트마다 at - call 시각에 같은 자리에서 빛과 음이 먼저 울린다(보스가 리듬을 보여 주고 플레이어가 따라 친다). 그때는 누를 수 없다.
# 시계는 이 노드의 _process로만 간다: 일시정지·창 포커스가 빠지면 같이 멈춘다. 세계 슬로모션과 무관하게 일정하다.
# 박자 시계(follow)가 있으면 시간은 전투 음악 재생 위치를 따른다(노트가 음악 박에서 어긋나지 않게, 멈춤은 음악 쪽이 맡음)

signal closed(i: int)
signal judged(i: int, grade: String, dt: float)
signal cue(key: String, step: int, vol: float)
signal timing(d: float, grade: String)
signal held(id: Variant, down: bool, label: String)

const PERFECT := [0.05, 0.04]
const PERFECT_WIDE := [0.08, 0.06]
const GOOD_EARLY := 0.14
const GOOD_LATE := 0.1
const TOO_EARLY := 0.4
const FADE_IN := 0.14
const BURST := 0.32
const HOLD_SLACK := 0.08
const DOUBLE_WIN := 0.28
const FLEE_R := 86.0
static var offset := 0.0
# 듣기 점검용 자동 막기(P2Music의 F7): 노트가 닫히는 순간 저절로 누른다
static var auto := false
static var hit_keys: Array = []
const COLOR := {"t": Color("#bfe9e2"), "h": Color("#ff9a3a"), "d": Color("#ff6fcf"), "s": Color("#6fe07a"), "f": Color("#b48cff"), "x": Color("#ff4a3a")}
const LABEL := {"h": "길게", "d": "두 번", "s": "따라가기", "f": "도망", "x": "누르지 마"}
const C_APPROACH := Color("#fff0ca")
const C_PERFECT := Color("#ffe04a")
const C_GOOD := Color("#8fc3e8")
const C_MISS := Color("#b3a58c")
const C_HOLD := Color("#ff9a3a")
const C_OUT := Color(0.04, 0.03, 0.05)

# 노트: pos(이 노드 기준) · at(닫히는 시각) · approach · kind · hold(h·s 길이) · to(s 끝 자리) · num(표시 번호, 0이면 방패 그림) · crush(강타 표시)
var notes: Array = []
var radius := 32.0
var perfect_early := 0.05
var perfect_late := 0.04
var good_early := GOOD_EARLY
var good_late := GOOD_LATE
var icon: Texture2D
var bounds := Rect2(-9999, -9999, 19999, 19999)
var beat := 0.0
# 히든 모드: 다가오는 고리·완벽 띠가 접근 시간의 40~60% 사이에 사라진다
var hidden_mod := false
var call := 0.0
var clock := Callable()
var t0 := 0.0
var _cues: Array = []
var _t := 0.0
var _cursor := Vector2(-9999, -9999)
var _focus_lost := false
var _held := {}
var _lat := 0.0
var _font: Font
var _small: Font
var _c: P2Pixel


func setup(list: Array, r: float, tex: Texture2D, wide: bool) -> void:
	notes = list
	radius = r
	icon = tex
	var w: Array = PERFECT_WIDE if wide else PERFECT
	perfect_early = w[0]
	perfect_late = w[1]
	for n in notes:
		if not n.has("kind"):
			n.kind = "h" if float(n.get("hold", 0.0)) > 0.0 else "t"
		n.grade = ""
		n.closed = false
		n.holding = false
		n.start = ""
		n.judged_t = -1.0
		n.second = -1.0
		n.moves = 0
		n.home = n.pos
		n.ok = 0.0
		n.flee_at = -1.0
		n.tick = 0.0
	_font = P2Ui.bold_font(24)
	_small = P2Ui.pixel_font(12)
	# 소리가 스피커에 닿기까지 걸리는 시간만큼 반주를 앞당겨 낸다(눈과 귀가 같은 순간에 닿게)
	_lat = clampf(AudioServer.get_output_latency(), 0.0, 0.1)


func _ready() -> void:
	_c = P2Pixel.attach(self, _paint)
	if _cursor.x < -9000.0:
		_cursor = get_local_mouse_position()


func follow(c: Callable, start: float) -> void:
	clock = c
	t0 = start
	_t = float(c.call()) - start


# 이번 프레임만큼 시간을 보내고 흐른 시간을 돌려줌
func _advance(delta: float) -> float:
	if clock.is_valid():
		var now := float(clock.call()) - t0
		var dt := maxf(0.0, now - _t)
		_t = maxf(_t, now)
		if auto:
			_auto_press()
		return dt
	var d := 0.0 if _focus_lost else delta
	_t += d
	return d


# 누른 순간의 시간(박자 시계가 있으면 프레임을 기다리지 않고 바로 읽음)
func _catch_up() -> void:
	if clock.is_valid():
		_t = maxf(_t, float(clock.call()) - t0)


func _auto_press() -> void:
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if n.grade != "" or n.kind == "x":
			continue
		if n.holding:
			if n.kind == "s":
				_cursor = ball(i)
			continue
		if n.kind == "d" and float(n.second) >= 0.0:
			if _t - float(n.second) >= 0.06:
				press_now()
			return
		if n.start == "" and _t >= float(n.at) + offset:
			press_now()
		return


func remaining() -> float:
	return end_time() - _t


# 누르기 키: 키보드 아무 키(되풀이 제외). Esc·Tab·F1~F12·Shift·Ctrl·Alt·Win·잠금 키는 원래 쓰임대로 둔다
static func is_hit_key(event: InputEvent) -> bool:
	if not event is InputEventKey or (event as InputEventKey).echo:
		return false
	var k := key_id(event as InputEventKey)
	if not hit_keys.is_empty():
		return k in hit_keys
	if k >= KEY_F1 and k <= KEY_F12:
		return false
	return k not in [KEY_ESCAPE, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_PRINT, KEY_PAUSE, KEY_MENU]


static func key_id(k: InputEventKey) -> Key:
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode


# 반주·부름·페인트 단서 소리 일정을 짠다 (setup 뒤, beat·call을 정한 다음)
func arrange() -> void:
	_cues.clear()
	var last := end_time()
	if beat > 0.0:
		var k := 0
		var t := 0.0
		while t <= last + beat * 0.5:
			_cues.append({"t": t, "key": "kick" if k % 2 == 0 else "hat", "step": 0, "vol": 0.0 if k % 2 == 0 else -2.0})
			if k % 4 == 2:
				_cues.append({"t": t, "key": "snare", "step": 0, "vol": -4.0})
			k += 1
			t = k * beat * 0.5
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if call > 0.0:
			_cues.append({"t": float(n.at) - call, "key": "chime", "step": i, "vol": -3.0})
		if n.kind == "x":
			var show := float(n.at) - float(n.approach)
			_cues.append({"t": show, "key": "stick", "step": 0, "vol": -2.0})
			_cues.append({"t": show + 0.07, "key": "stick", "step": 0, "vol": -4.0})
	_cues.sort_custom(func(a, b): return float(a.t) < float(b.t))


# 입문 판정: 완벽·막음 창을 k배로
func ease(k: float) -> void:
	perfect_early *= k
	perfect_late *= k
	good_early = GOOD_EARLY * k
	good_late = GOOD_LATE * k


# 악보가 뜰 자리(뜨기 전 붉은 예고 틀)
func cue_rect() -> Rect2:
	return bounds.grow(8.0)


func time_until(i: int) -> float:
	return float(notes[i].at) - _t


func end_time() -> float:
	var e := 0.0
	for n in notes:
		e = maxf(e, float(n.at) + float(n.get("hold", 0.0)) + (DOUBLE_WIN if n.kind == "d" else 0.0))
	return e + maxf(offset, 0.0)


func grade_of(i: int) -> String:
	return String(notes[i].grade)


# 따라가기 노트의 공 자리
func ball(i: int) -> Vector2:
	var n: Dictionary = notes[i]
	var u := clampf((_t - float(n.at)) / float(n.hold), 0.0, 1.0)
	return (n.pos as Vector2).lerp(n.to, u)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_lost = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_lost = false


func _process(delta: float) -> void:
	var dt := _advance(delta)
	while not _cues.is_empty() and float(_cues[0].t) - _lat <= _t:
		var c: Dictionary = _cues.pop_front()
		cue.emit(String(c.key), int(c.step), float(c.vol))
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if not n.closed and _t >= float(n.at):
			n.closed = true
			closed.emit(i)
		if n.grade != "":
			continue
		match String(n.kind):
			"f":
				_flee(n)
			"s":
				if n.holding:
					if _cursor.distance_to(ball(i)) <= radius * 1.6:
						n.ok = float(n.ok) + dt
		if n.holding:
			n.tick = float(n.tick) + dt
			if float(n.tick) >= 0.11:
				n.tick = 0.0
				cue.emit("hat", 0, 2.0)
		if n.holding and _t >= float(n.at) + float(n.hold):
			_finish_long(i)
		elif n.kind == "d" and float(n.second) >= 0.0 and _t > float(n.second) + DOUBLE_WIN:
			_judge(i, _drop(n.start), _t - float(n.at))
		elif n.kind == "x" and _t > float(n.at) + offset + good_late:
			_judge(i, "perfect")
		elif n.start == "" and not n.holding and n.kind != "x" and float(n.second) < 0.0 and _t > float(n.at) + offset + good_late:
			_judge(i, "miss", _t - float(n.at) - offset)
	var done := true
	for n in notes:
		if n.grade == "" or _t - float(n.judged_t) < BURST:
			done = false
	if done and _t > end_time() + good_late:
		queue_free()
	_c.redraw()


# 도망 노트: 아직 이를 때 커서가 다가오면 갈 쪽을 화살표로 0.15초 보여 준 뒤 비켜난다(두 번까지, 정해진 칸 안).
# 닫히기 0.45초 전부터는 새로 움직이지 않아 마지막 이동 뒤 0.3초 남짓 잡을 시간이 있다
func _flee(n: Dictionary) -> void:
	var p: Vector2 = n.pos
	if float(n.flee_at) >= 0.0:
		if _t >= float(n.flee_at):
			n.home = n.flee_to
			n.moves = int(n.moves) + 1
			n.flee_at = -1.0
			cue.emit("stick", 0, -6.0)
	elif int(n.moves) < 2 and _t - (float(n.at) - float(n.approach)) > FADE_IN and float(n.at) - _t > 0.45 and _cursor.distance_to(p) < FLEE_R * radius / 32.0:
		var away := (p - _cursor).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		var hop := radius * 3.0
		var to := p + away * hop
		to = Vector2(clampf(to.x, bounds.position.x, bounds.end.x), clampf(to.y, bounds.position.y, bounds.end.y))
		if to.distance_to(p) < hop * 0.5:
			to = p - away * hop
		n.flee_to = to
		n.flee_at = _t + 0.15
	n.pos = p.lerp(n.home, 0.35)


func _input(event: InputEvent) -> void:
	_catch_up()
	if is_hit_key(event):
		var id := key_id(event as InputEventKey)
		if event.pressed:
			_held[id] = true
			held.emit(id, true, OS.get_keycode_string(id))
			_press(_cursor)
		else:
			_held.erase(id)
			held.emit(id, false, OS.get_keycode_string(id))
			if _held.is_empty():
				_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at := (make_input_local(event) as InputEventMouseButton).position
		_cursor = at
		if event.pressed:
			_held["mouse"] = true
			held.emit("mouse", true, "클릭")
			if _press(at):
				get_viewport().set_input_as_handled()
		else:
			_held.erase("mouse")
			held.emit("mouse", false, "클릭")
			if _held.is_empty():
				_release()
	elif event is InputEventMouseMotion:
		var at2 := (make_input_local(event) as InputEventMouseMotion).position
		_cursor = at2
		for i in range(notes.size()):
			var n: Dictionary = notes[i]
			if n.holding and n.kind == "h" and at2.distance_to(n.pos) > radius * 1.9:
				_release()


# 지금 누를 차례인 노트(판정 안 된 것 중 가장 앞, 누르는 중인 것은 건너뜀): 너무 이른 때는 받지 않는다
func _current() -> int:
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if n.grade == "" and n.start == "" and float(n.second) < 0.0:
			return i if _t - float(n.at) - offset >= -TOO_EARLY else -1
	return -1


func _press(at: Vector2) -> bool:
	# 두 번 노트의 두 번째 클릭이 먼저
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if n.grade == "" and n.kind == "d" and float(n.second) >= 0.0:
			if at.distance_to(n.pos) <= radius * 1.6:
				_judge(i, n.start if _t - float(n.second) >= 0.04 else _drop(n.start), _t - float(n.at))
				return true
	var i := _current()
	if i < 0 or at.distance_to(notes[i].pos) > radius * 1.4:
		return false
	_hit(i)
	return true


# 점검 드라이버용: 지금 누를 차례 노트(또는 두 번 노트의 두 번째)를 누름 · 놓음 · 커서 옮김
func press_now() -> void:
	for i in range(notes.size()):
		var n: Dictionary = notes[i]
		if n.grade == "" and n.kind == "d" and float(n.second) >= 0.0:
			_judge(i, n.start if _t - float(n.second) >= 0.04 else _drop(n.start), _t - float(n.at))
			return
	var i := _current()
	if i >= 0:
		_cursor = notes[i].pos
		_hit(i)


func release_now() -> void:
	_release()


func set_cursor(p: Vector2) -> void:
	_cursor = p


func _drop(g: String) -> String:
	return "good" if g == "perfect" else "miss"


func _hit(i: int) -> void:
	var n: Dictionary = notes[i]
	var d := _t - float(n.at) - offset
	if n.kind == "x":
		_judge(i, "miss", d)
		return
	var g := "miss"
	if d >= -perfect_early and d <= perfect_late:
		g = "perfect"
	elif d >= -good_early and d <= good_late:
		g = "good"
	timing.emit(d, g)
	if g == "miss":
		_judge(i, g, d)
		return
	match String(n.kind):
		"h", "s":
			n.start = g
			n.holding = true
		"d":
			n.start = g
			n.second = _t
		_:
			_judge(i, g, d)


func _release() -> void:
	for i in range(notes.size()):
		if notes[i].holding:
			_finish_long(i)


# 롱·따라가기 끝: 롱은 끝까지(조금 일찍 떼도 됨), 따라가기는 공을 따라간 비율로
func _finish_long(i: int) -> void:
	var n: Dictionary = notes[i]
	n.holding = false
	var got := clampf((_t - float(n.at)) / float(n.hold), 0.0, 1.0)
	if n.kind == "s":
		var follow := float(n.ok) / float(n.hold)
		_judge(i, n.start if follow >= 0.85 else ("good" if follow >= 0.5 else "miss"))
	elif _t >= float(n.at) + float(n.hold) - HOLD_SLACK:
		_judge(i, n.start)
	else:
		_judge(i, "good" if got >= 0.5 else "miss")


func _judge(i: int, g: String, d := 0.0) -> void:
	var n: Dictionary = notes[i]
	n.grade = g
	n.holding = false
	n.judged_t = _t
	judged.emit(i, g, d)


func _paint() -> void:
	for i in range(notes.size() - 1):
		_draw_link(i)
	if call > 0.0:
		for n in notes:
			_draw_call(n)
	# 뒤 번호부터 그려 앞 번호가 위에 오게
	for i in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[i]
		var since := _t - (float(n.at) - float(n.approach))
		if since < 0.0:
			continue
		if n.grade != "":
			_draw_burst(n, clampf((_t - float(n.judged_t)) / BURST, 0.0, 1.0))
		else:
			_draw_note(i, clampf(since / FADE_IN, 0.0, 1.0) * (0.3 if _covered(i) else 1.0))


# 앞 번호 중 아직 안 끝난 노트와 겹치면 흐리게
func _covered(i: int) -> bool:
	for j in range(i):
		var m: Dictionary = notes[j]
		if m.grade == "" and (m.pos as Vector2).distance_to(notes[i].pos) < radius * 2.0:
			return true
	return false


# 부름: 노트가 울릴 자리에서 짧게 번쩍이고 퍼진다(누를 수 없음)
func _draw_call(n: Dictionary) -> void:
	var u := (_t - (float(n.at) - call)) / 0.35
	if u < 0.0 or u > 1.0:
		return
	var p: Vector2 = (n.pos as Vector2).round()
	var col: Color = COLOR[n.kind]
	_c.draw_colored_polygon(_body(String(n.kind), p, radius * 0.9, n), Color(col, 0.35 * (1.0 - u)))
	_ring(String(n.kind), p, radius * lerpf(0.9, 1.6, u), n, Color(Color.WHITE, 1.0 - u), 3.0)


func _draw_link(i: int) -> void:
	var a: Dictionary = notes[i]
	var b: Dictionary = notes[i + 1]
	if b.grade != "" or _t < float(b.at) - float(b.approach):
		return
	var k := clampf((_t - (float(b.at) - float(b.approach))) / FADE_IN, 0.0, 1.0) * (0.35 if a.grade == "" else 0.2)
	var p0: Vector2 = a.to if a.kind == "s" else a.pos
	var p1: Vector2 = b.pos
	var dist := p0.distance_to(p1)
	var dir := (p1 - p0) / maxf(dist, 0.001)
	var s := radius + 6.0
	while s < dist - radius - 6.0:
		_c.draw_line(p0 + dir * s, p0 + dir * minf(s + 6.0, dist - radius - 6.0), Color(C_APPROACH, k), P2Pixel.w(2.0), false)
		s += 12.0


func _draw_note(i: int, k: float) -> void:
	var n: Dictionary = notes[i]
	var kind := String(n.kind)
	var col: Color = COLOR[kind]
	var p: Vector2 = (n.pos as Vector2).round()
	var r := radius
	if kind == "s":
		# 따라가기: 굵은 길과 끝 세모, 누르는 동안 세모 공이 굴러간다(바깥 세모 = 커서가 머물러야 할 범위)
		var to: Vector2 = (n.to as Vector2).round()
		_c.draw_line(p, to, Color(col, 0.22 * k), radius * 1.3, false)
		_c.draw_line(p, to, Color(col, 0.6 * k), P2Pixel.w(2.0), false)
		_ring("s", to, radius * 0.7, n, Color(col, 0.7 * k), 2.0)
		if n.holding:
			var bp := ball(i).round()
			_c.draw_colored_polygon(_body("s", bp, radius * 0.8, n), Color(col, 0.85))
			_ring("s", bp, radius * 1.6, n, Color(col, 0.45), 2.0)
	if kind == "f" and int(n.moves) < 2:
		r += sin(_t * 30.0 + i) * 1.5
	var body := _body(kind, p, r, n)
	_c.draw_colored_polygon(body, Color(col.darkened(0.75), 0.75 * k))
	var inner := PackedVector2Array()
	for q in body:
		inner.append(p + (q - p) * 0.9)
	_c.draw_colored_polygon(inner, Color(col, 0.18 * k))
	var rim := body.duplicate()
	rim.append(body[0])
	_c.draw_polyline(rim, Color(C_OUT, 0.8 * k), P2Pixel.w(3.0) + 4.0, false)
	_c.draw_polyline(rim, Color(col, k), P2Pixel.w(3.0), false)
	match kind:
		"h":
			# 바깥 네모 테두리, 누르는 동안 그 테두리를 따라 네모로 차오른다
			var outer := _body("h", p, r + 7.0, n)
			_ring("h", p, r + 7.0, n, Color(col, 0.55 * k), 3.0)
			if n.holding:
				var got := clampf((_t - float(n.at)) / float(n.hold), 0.0, 1.0)
				_c.draw_polyline(_partial(outer, got), Color(C_PERFECT if n.start == "perfect" else C_GOOD, 1.0), P2Pixel.w(6.0), false)
		"d":
			_c.draw_arc(p, r - 8.0, 0.0, TAU, 40, Color(col, 0.8 * k), P2Pixel.w(2.0), false)
			if float(n.second) >= 0.0:
				var u := clampf((_t - float(n.second)) / DOUBLE_WIN, 0.0, 1.0)
				_c.draw_arc(p, lerpf(r * 1.6, r * 0.6, u), 0.0, TAU, 40, Color(col, 1.0 - u), P2Pixel.w(4.0), false)
		"x":
			# 페인트 단서: 테두리가 끊긴 점선 + X
			for seg in range(12):
				var a0 := TAU * seg / 12.0
				_c.draw_arc(p, r + 5.0, a0, a0 + TAU / 24.0, 6, Color(col, k), P2Pixel.w(3.0), false)
			_c.draw_line(p + Vector2(-14, -14), p + Vector2(14, 14), Color(col, k), 4.0, false)
			_c.draw_line(p + Vector2(14, -14), p + Vector2(-14, 14), Color(col, k), 4.0, false)
		"f":
			if float(n.flee_at) >= 0.0:
				# 갈 쪽 화살표
				var to: Vector2 = n.flee_to
				var dir := (to - p).normalized()
				var aw := P2Pixel.w(3.0)
				_c.draw_line(p + dir * r, to, Color(col, 0.8 * k), aw, false)
				_c.draw_line(to, to - dir.rotated(0.5) * 14.0, Color(col, 0.8 * k), aw, false)
				_c.draw_line(to, to - dir.rotated(-0.5) * 14.0, Color(col, 0.8 * k), aw, false)
	if bool(n.get("crush", false)):
		_ring(kind, p, r + 12.0, n, Color("#8a1c0c", 0.9 * k), 4.0)
	if kind != "x":
		if int(n.num) > 0:
			var txt := str(n.num)
			var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			_c.text(_font, (p + Vector2(-w / 2.0, 9.0)).round(), txt, 24, Color(1, 1, 1, k), 5, Color(0.04, 0.03, 0.02, k))
		elif icon != null:
			var s := icon.get_size()
			_c.icon(icon, Rect2((p - s / 2.0).round(), s), Color(1, 1, 1, 0.9 * k))
	if bool(n.get("bomb", false)):
		# 소환수 폭발: 주황 테가 빠르게 깜빡인다
		var fl := 0.5 + 0.5 * sin(_t * 22.0)
		_c.draw_arc(p, r + 9.0 + fl * 3.0, 0.0, TAU, 48, Color("#ff8a2a", (0.45 + 0.55 * fl) * k), P2Pixel.w(4.0), false)
	var lab := "강타 ½" if bool(n.get("crush", false)) else ("폭발" if bool(n.get("bomb", false)) else String(LABEL.get(kind, "")))
	if lab != "" and not n.holding:
		var tw := _small.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_c.text(_small, (p + Vector2(-tw / 2.0, r + 20.0)).round(), lab, 12, Color(col, k), 3, Color(0, 0, 0, k))
	if n.holding or float(n.second) >= 0.0:
		return
	# 완벽 띠: 바깥 고리가 이 띠 안에 있을 때 누르면 완벽(페인트는 없음)
	var speed := radius * 2.0 / float(n.approach)
	var prog := clampf((_t - (float(n.at) - float(n.approach))) / float(n.approach), 0.0, 1.0)
	if hidden_mod:
		k *= clampf((0.6 - prog) / 0.2, 0.0, 1.0)
		if k <= 0.01:
			return
	if kind != "x":
		var band := perfect_early * speed
		_ring(kind, p, radius + band * 0.5, n, Color(C_PERFECT, 0.28 * k), band + 1.0)
	var ar := lerpf(radius * 3.0, radius, prog)
	var near := kind != "x" and _t - float(n.at) - offset >= -perfect_early
	var ac := C_PERFECT if near else (col if kind != "t" else C_APPROACH)
	_ring(kind, p, ar, n, Color(ac, lerpf(0.3, 1.0, prog) * k), 4.0 if near else 3.0, true)


# 다가오는 고리·완벽 띠: 노트 몸과 같은 모양(□면 □, △면 △)으로 줄어들어 몸 테두리에 겹치는 순간이 닿는 순간.
# outline이면 어두운 테를 먼저 깔아 밝은 바닥 위에서도 고리가 보이게
func _ring(kind: String, p: Vector2, rr: float, n: Dictionary, col: Color, w: float, outline := false) -> void:
	var lw := P2Pixel.w(w)
	if kind in ["h", "f", "s"]:
		var pts := _body(kind, p, rr, n)
		pts.append(pts[0])
		if outline:
			_c.draw_polyline(pts, Color(C_OUT, col.a * 0.7), lw + 4.0, false)
		_c.draw_polyline(pts, col, lw, false)
	else:
		if outline:
			_c.draw_arc(p, rr, 0.0, TAU, 64, Color(C_OUT, col.a * 0.7), lw + 4.0, false)
		_c.draw_arc(p, rr, 0.0, TAU, 64, col, lw, false)


# 노트 몸 모양(색을 못 가려도 알아보게): 짧은 ○ · 길게 □ · 두 번 ◎(안쪽 고리) · 따라가기 △(갈 쪽을 가리킴) · 도망 ◇ · 페인트 점선 ○ + ✕
func _body(kind: String, p: Vector2, r: float, n: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		"h":
			var a := r * 0.86
			var c := r * 0.24
			for q in [Vector2(-a + c, -a), Vector2(a - c, -a), Vector2(a, -a + c), Vector2(a, a - c), Vector2(a - c, a), Vector2(-a + c, a), Vector2(-a, a - c), Vector2(-a, -a + c)]:
				pts.append(p + q)
		"f":
			var d := r * 1.14
			for q in [Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)]:
				pts.append(p + q)
		"s":
			var dir := ((n.to as Vector2) - (n.home as Vector2)).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			for k in range(3):
				pts.append(p + dir.rotated(TAU * k / 3.0) * r * 1.18)
		_:
			for k in range(40):
				pts.append(p + Vector2.RIGHT.rotated(TAU * k / 40.0) * r)
	return pts


# 닫힌 테두리를 첫 꼭짓점부터 시계 방향으로 frac만큼만(길게 노트가 차오르는 정도)
func _partial(pts: PackedVector2Array, frac: float) -> PackedVector2Array:
	var loop := pts.duplicate()
	loop.append(pts[0])
	var total := 0.0
	for k in range(loop.size() - 1):
		total += loop[k].distance_to(loop[k + 1])
	var want := total * clampf(frac, 0.0, 1.0)
	var out := PackedVector2Array([loop[0]])
	for k in range(loop.size() - 1):
		var seg := loop[k].distance_to(loop[k + 1])
		if want <= seg:
			out.append(loop[k].lerp(loop[k + 1], want / maxf(seg, 0.001)))
			return out
		want -= seg
		out.append(loop[k + 1])
	return out


func _draw_burst(n: Dictionary, u: float) -> void:
	var p: Vector2 = ((n.to if n.kind == "s" else n.pos) as Vector2).round()
	var fade := 1.0 - u
	var feint: bool = n.kind == "x"
	var kind := String(n.kind)
	var g := String(n.grade)
	# 박자 시계 악보(세계 음악)에서는 막음도 완벽처럼 터진다(색과 글자만 파랑)
	if g == "good" and clock.is_valid():
		g = "perfect"
	var col := C_GOOD if String(n.grade) == "good" else C_PERFECT
	match g:
		"perfect":
			if u < 0.3:
				_c.draw_colored_polygon(_body(kind, p, radius * (1.0 + u), n), Color(1, 1, 1, 0.85 * (1.0 - u / 0.3)))
			_ring(kind, p, radius * lerpf(1.0, 2.0, u), n, Color(col, fade), lerpf(5.0, 1.0, u))
			for i in range(8):
				var dir := Vector2.RIGHT.rotated(TAU * (i + 0.5) / 8.0)
				_c.draw_line(p + dir * radius * lerpf(1.1, 1.7, u), p + dir * radius * lerpf(1.4, 2.3, u), Color(col, fade), P2Pixel.w(3.0), false)
			_label(p, "막음" if String(n.grade) == "good" else ("참음!" if feint else "완벽!"), col, u)
		"good":
			_ring(kind, p, radius * lerpf(1.0, 1.5, u), n, Color(C_GOOD, fade), 3.0)
			_label(p, "막음", C_GOOD, u)
		_:
			_ring(kind, p, radius * lerpf(1.0, 0.6, u), n, Color(C_MISS, fade * 0.8), 2.0)
			_label(p, "속음" if feint else "놓침", COLOR.x if feint else C_MISS, u)


func _label(p: Vector2, text: String, c: Color, u: float) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var at := (p + Vector2(-w / 2.0, -radius - 26.0 - 16.0 * u)).round()
	var a := 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
	_c.text(_font, at, text, 24, Color(c, a), 6, Color(0.05, 0.03, 0.02, a))


# 장르 무대 틀(osu 말고 모두 같은 모양): 그림자 · 어두운 바탕 · 상아 두 겹 테 · 모서리 깎기 · 위 이름표(장르 이름 + 조작 한 줄)
func _stage(rect: Rect2, title: String, hint: String, open: float, accent: Color) -> void:
	var frame := Color("#f3ead7")
	_c.draw_rect(rect.grow(9.0), Color(C_OUT, 0.45 * open))
	_c.draw_rect(rect.grow(5.0), Color(C_OUT, 0.95 * open))
	_c.draw_rect(rect, Color(0.03, 0.03, 0.07, 0.88 * open))
	_c.draw_rect(rect.grow(1.0), Color(frame, open), false, P2Pixel.w(4.0))
	_c.draw_rect(rect.grow(-5.0), Color(frame, 0.14 * open), false, P2Pixel.w(2.0))
	for k in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		_c.draw_rect(Rect2(k - Vector2(5, 5), Vector2(10, 10)), Color(C_OUT, open))
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var hw := _small.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var tab := Rect2(rect.position.x + 16.0, rect.position.y - 28.0, tw + hw + 44.0, 26.0)
	_c.draw_rect(tab.grow(3.0), Color(C_OUT, 0.95 * open))
	_c.draw_rect(tab, Color(accent.darkened(0.7), 0.96 * open))
	_c.draw_rect(Rect2(tab.position, Vector2(4, tab.size.y)), Color(accent, open))
	_c.draw_rect(tab, Color(accent, 0.8 * open), false, P2Pixel.w(2.0))
	_c.text(_font, (Vector2(tab.position.x + 12.0, tab.end.y - 6.0)).round(), title, 18, Color(accent.lightened(0.45), open), 4, Color(C_OUT, open))
	_c.text(_small, (Vector2(tab.position.x + 26.0 + tw, tab.end.y - 8.0)).round(), hint, 12, Color(C_APPROACH, 0.85 * open), 3, Color(C_OUT, open))


# 무대가 열리고(0.16초) 마지막 판정 뒤 닫히는(0.2초) 정도
func _open_amount() -> float:
	var open := clampf(_t / 0.16, 0.0, 1.0)
	var last := 0.0
	for n in notes:
		if n.grade == "":
			return open
		last = maxf(last, float(n.judged_t))
	return minf(open, 1.0 - clampf((_t - last - 0.25) / 0.2, 0.0, 1.0))
