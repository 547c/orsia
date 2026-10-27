class_name P2SlashPad
extends Control

# 손맛 시험판 긋기: 적 몸의 약점 점들을 누른 채 그어 지나간다(왼쪽 버튼이나 키보드 아무 키를 누른 채 마우스를 움직임). 우클릭·Esc는 카드 취소(마나 그대로).
# 완벽 = 다 지나감 + 점 한가운데(가운데 고리 안) + 시간 막대 금색 구간 안에 끝냄. 다 지나갔지만 느리거나 가장자리면 정확(기본 피해),
# 몇 개만이면 일부, 못 지나가면 빗나감. ordered면 번호 순서대로만 센다. 처음 점과 같은 자리의 마지막 점은 문양을 닫는 점(차례 전엔 흐린 고리).
# 박자 문양(beat > 0): 점마다 고리가 줄어드는 그 순간 앞뒤에만 센다(놓치면 그 점은 건너뜀, 속도는 보지 않음). 점 차례마다 tick이 울린다.
# 한 번 긋기(cut): 순서 있는 두 점 + 큰 화살표. 완벽은 두 점 사이를 flick초 안에 휙 지나가야 한다. 가시(thorns)에 닿으면 획이 끊긴다.
# 시간은 _process로만 센다(일시정지·창 포커스가 빠지면 같이 멈춤)

signal crossed(i: int, total: int)
signal finished(result: Dictionary)
signal tick(i: int)
signal held(id: Variant, down: bool, label: String)

const INTRO := 0.14
const OUTRO := 0.16
const LEAD := 0.55
const WIN_EARLY := 0.16
const WIN_LATE := 0.2
const THORN_R := 13.0
const C_POINT := Color("#ffe9a8")
const C_CORE := Color("#fffaf0")
const C_GLOW := Color("#ffd98a")
const C_DONE := Color("#ffe04a")
const C_THORN := Color("#ff4a3a")
const C_SLOW := Color("#8a7d68")

var points: Array[Vector2] = []
var radius := 18.0
var limit := 1.5
var ordered := false
var fast := 0.55
var precise := 0.6
var beat := 0.0
var flick := 0.0
var thorns: Array = []
var can_reverse := false
var reversed := false
var eat_thorns := false
var _eaten := {}
var _ticks: Array = []
var hit: Array[bool] = []
var stroke := PackedVector2Array()
var stroke_t := PackedFloat32Array()
var grade := ""
var _next := 0
var _focus_lost := false
var _c_point := C_POINT
var _c_glow := C_GLOW
var _t := 0.0
var _hit_t: Array[float] = []
var _dist: Array[float] = []
var _missed: Array[bool] = []
var _target: Array[float] = []
var _drawing := false
var _held := {}
var _aim := Vector2.INF
var _broken := false
var _all_t := -1.0
var _last := -1
var _done_t := -1.0
var _font: Font
var _num: Font
var _small: Font
var _c: P2Pixel


# opts: fast(금색 구간 = 시간의 몇 할) · precise(가운데 고리 = 반지름의 몇 할) · beat(박자 문양 간격초) · thorns(가시 자리들)
func setup(pts: Array[Vector2], r: float, limit_s: float, in_order := false, rune := false, opts := {}) -> void:
	points = pts
	radius = r
	limit = limit_s
	ordered = in_order or float(opts.get("beat", 0.0)) > 0.0
	fast = float(opts.get("fast", 0.55))
	precise = float(opts.get("precise", 0.6))
	beat = float(opts.get("beat", 0.0))
	flick = float(opts.get("flick", 0.0))
	thorns = opts.get("thorns", [])
	eat_thorns = bool(opts.get("eat_thorns", false))
	if rune:
		_c_point = Color("#9ff3ff")
		_c_glow = Color("#5fd8cf")
	var n := pts.size()
	hit.resize(n)
	hit.fill(false)
	_hit_t.resize(n)
	_hit_t.fill(-1.0)
	_dist.resize(n)
	_dist.fill(999.0)
	_missed.resize(n)
	_missed.fill(false)
	if beat > 0.0:
		for i in range(n):
			_target.append(INTRO + LEAD + i * beat)
		limit = _target[n - 1] + WIN_LATE + 0.15 - INTRO
		# 앞에 두 번 세고(-2, -1) 점마다 한 번
		for k in range(-2, n):
			_ticks.append(INTRO + LEAD + k * beat)
	can_reverse = bool(opts.get("reverse", false)) and beat <= 0.0 and n >= 2 and _twin(n - 1) < 0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = P2Ui.bold_font(36)
	_num = P2Ui.bold_font(24)
	_small = P2Ui.pixel_font(12)


func _ready() -> void:
	_c = P2Pixel.attach(self, _paint)


func crossed_count() -> int:
	return hit.count(true)


func precise_count() -> int:
	var c := 0
	for i in range(points.size()):
		if hit[i] and _dist[i] <= radius * precise:
			c += 1
	return c


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_lost = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_lost = false


func _process(delta: float) -> void:
	if not _focus_lost or grade != "":
		_t += delta
	while not _ticks.is_empty() and float(_ticks[0]) <= _t and grade == "":
		_ticks.pop_front()
		tick.emit(_next)
	if grade == "" and beat > 0.0:
		while _next < points.size() and _t > _target[_next] + WIN_LATE:
			_missed[_next] = true
			_next += 1
	if grade == "" and (_t > INTRO + limit or (beat > 0.0 and _next >= points.size() and _all_t < 0.0) or (_all_t >= 0.0 and _t - _all_t > 0.25)):
		_finish()
	if _done_t >= 0.0 and _t - _done_t > OUTRO + 0.3:
		queue_free()
	queue_redraw()
	_c.redraw()


func _gui_input(event: InputEvent) -> void:
	if grade != "":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_finish("cancel")
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_aim = mb.position
			if _held.is_empty():
				_pen_down(mb.position)
			_held["mouse"] = true
			held.emit("mouse", true, "클릭")
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_held.erase("mouse")
			held.emit("mouse", false, "클릭")
			if _held.is_empty():
				_pen_up()
		accept_event()
	elif event is InputEventMouseMotion:
		_aim = (event as InputEventMouseMotion).position
		if _drawing:
			add_point(_aim)
			accept_event()


func _input(event: InputEvent) -> void:
	if grade == "" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("cancel")
	elif grade == "" and P2NoteChart.is_hit_key(event):
		var id := P2NoteChart.key_id(event as InputEventKey)
		if event.pressed:
			if _held.is_empty():
				_pen_down(_aim if _aim != Vector2.INF else get_local_mouse_position())
			_held[id] = true
			held.emit(id, true, OS.get_keycode_string(id))
		else:
			_held.erase(id)
			held.emit(id, false, OS.get_keycode_string(id))
			if _held.is_empty():
				_pen_up()
		get_viewport().set_input_as_handled()


func _pen_down(at: Vector2) -> void:
	_drawing = true
	stroke = PackedVector2Array([at])
	stroke_t = PackedFloat32Array([_t])
	_touch(at, at)


func _pen_up() -> void:
	if not _drawing:
		return
	_drawing = false
	if crossed_count() > 0 or _length() > 40.0:
		_finish()


# 그은 자리 하나 더 (점검 드라이버도 이 길로 긋는다)
func add_point(pos: Vector2) -> void:
	if grade != "":
		return
	if stroke.is_empty():
		stroke.append(pos)
		stroke_t.append(_t)
		return
	var last := stroke[stroke.size() - 1]
	if last.distance_to(pos) < 3.0:
		return
	stroke.append(pos)
	stroke_t.append(_t)
	_touch(last, pos)


func release() -> void:
	_drawing = false
	if grade == "":
		_finish()


func _touch(a: Vector2, b: Vector2) -> void:
	for ti in range(thorns.size()):
		var th: Vector2 = thorns[ti]
		if Geometry2D.get_closest_point_to_segment(th, a, b).distance_to(th) <= THORN_R + 2.0:
			if eat_thorns:
				if not _eaten.has(ti):
					_eaten[ti] = _t
				continue
			_broken = true
			_finish()
			return
	# 이미 지난 점은 지나가는 동안 가장 가까웠던 거리로 (정밀도)
	for i in range(points.size()):
		if hit[i]:
			_dist[i] = minf(_dist[i], _gap(points[i], a, b))
	if ordered:
		# 거꾸로 붓: 아무 점도 안 지났을 때 마지막 점부터 들어오면 그 뒤로는 거꾸로 센다
		var last_i := points.size() - 1
		if can_reverse and not reversed and crossed_count() == 0 and _gap(points[last_i], a, b) <= radius + 4.0 and _gap(points[0], a, b) > radius + 4.0:
			reversed = true
			_next = last_i
		if reversed:
			while _next >= 0 and _gap(points[_next], a, b) <= radius + 4.0:
				_mark(_next, _gap(points[_next], a, b))
				_next -= 1
		else:
			while _next < points.size() and _gap(points[_next], a, b) <= radius + 4.0 and _in_window(_next):
				_mark(_next, _gap(points[_next], a, b))
				_next += 1
	else:
		for i in range(points.size()):
			if not hit[i] and _gap(points[i], a, b) <= radius + 4.0:
				_mark(i, _gap(points[i], a, b))
	# 다 지났으면 마지막 점을 빠져나가거나(손을 떼거나) 잠깐 뒤에 끝
	if crossed_count() == points.size():
		if _all_t < 0.0:
			_all_t = _t
		elif b.distance_to(points[_last]) > radius + 4.0:
			_finish()


func _in_window(i: int) -> bool:
	return beat <= 0.0 or (_t >= _target[i] - WIN_EARLY and _t <= _target[i] + WIN_LATE)


func _gap(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)


func _mark(i: int, d: float) -> void:
	_last = i
	hit[i] = true
	_hit_t[i] = _t
	_dist[i] = d
	crossed.emit(i, crossed_count())


# 앞선 점과 같은 자리(문양을 닫는 점)면 그 앞 점 번호
func _twin(i: int) -> int:
	for j in range(i):
		if points[j].distance_to(points[i]) < 2.0:
			return j
	return -1


func _length() -> float:
	var d := 0.0
	for i in range(1, stroke.size()):
		d += stroke[i - 1].distance_to(stroke[i])
	return d


func _finish(force := "") -> void:
	if grade != "":
		return
	var n := crossed_count()
	var sharp := precise_count() == points.size()
	var quick := beat > 0.0 or (_all_t if _all_t >= 0.0 else _t) - INTRO <= limit * fast
	if flick > 0.0 and n == points.size():
		quick = quick and absf(_hit_t[n - 1] - _hit_t[0]) <= flick
	if force != "":
		grade = force
	elif n == points.size() and not _broken:
		grade = "perfect" if sharp and quick else "hit"
	else:
		grade = "part" if n > 0 else "graze"
	_done_t = _t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit({"grade": grade, "crossed": n, "total": points.size(), "precise": precise_count(), "quick": quick, "broken": _broken,
		"reversed": reversed, "thorns_eaten": _eaten.size(),
		"stroke": stroke.duplicate(), "points": points.duplicate()})


# 화면을 덮는 어둠·번쩍임은 원래 해상도로, 점·길·획은 픽셀 그림판(_paint)에
func _draw() -> void:
	var out := 0.0 if _done_t < 0.0 else clampf((_t - _done_t) / OUTRO, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 0.42 * clampf(_t / INTRO, 0.0, 1.0) * (1.0 - out)))
	if grade == "perfect" and _t - _done_t < 0.12:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.16 * (1.0 - (_t - _done_t) / 0.12)))


func _paint() -> void:
	var k := clampf(_t / INTRO, 0.0, 1.0)
	var out := 0.0 if _done_t < 0.0 else clampf((_t - _done_t) / OUTRO, 0.0, 1.0)
	var a := k * (1.0 - out)
	if flick > 0.0 and points.size() == 2:
		_draw_arrow(points[0], points[1], a)
	# 잇는 길잡이: 점선 (순서 문양은 지난 구간을 흐리게)
	for i in range(points.size() - 1):
		var done := ordered and (hit[i + 1] or _missed[i + 1])
		_dashed(points[i], points[i + 1], Color(_c_point, (0.15 if done else 0.4) * a))
	for th in thorns:
		_draw_thorn(th, a)
	# 뒤 번호부터 그려 앞 번호가 위에 오게
	for i in range(points.size() - 1, -1, -1):
		_draw_point(i, a)
	_draw_stroke(a)
	if grade == "" and k >= 1.0 and beat <= 0.0:
		_draw_timer()
	if grade != "" and grade != "cancel":
		var text: String = {"perfect": "완벽!", "hit": "정확", "part": "일부", "graze": "빗나감"}[grade]
		if _broken:
			text = "끊김!"
		var c := C_DONE if grade == "perfect" else (C_CORE if grade == "hit" else Color("#b3a58c"))
		var mid := _bounds().get_center()
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		var at := (mid + Vector2(-w / 2.0, -_bounds().size.y / 2.0 - 40.0 - 20.0 * out)).round()
		_c.text(_font, at, text, 36, Color(c, 1.0 - out), 8, Color(0.06, 0.03, 0.02, 1.0 - out))


func _draw_point(i: int, a: float) -> void:
	var p := points[i].round()
	var twin := _twin(i)
	if hit[i]:
		var u := clampf((_t - _hit_t[i]) / 0.26, 0.0, 1.0)
		var sharp := _dist[i] <= radius * precise
		_c.draw_arc(p, radius * lerpf(1.0, 2.0 if sharp else 1.5, u), 0.0, TAU, 40, Color(C_DONE if sharp else C_CORE, (1.0 - u) * a), P2Pixel.w(lerpf(4.0, 1.0, u)), false)
		if sharp:
			for s in range(6):
				var dir := Vector2.RIGHT.rotated(TAU * s / 6.0 + 0.3)
				_c.draw_line(p + dir * radius * lerpf(0.6, 1.6, u), p + dir * radius * lerpf(0.9, 2.2, u), Color(C_CORE, (1.0 - u) * a), P2Pixel.w(2.0), false)
		return
	if _missed[i]:
		_c.draw_arc(p, radius * 0.8, 0.0, TAU, 32, Color(C_SLOW, 0.5 * a), P2Pixel.w(2.0), false)
		return
	# 문양을 닫는 점: 차례가 오기 전에는 흐린 고리만(앞 번호가 위에 또렷이)
	if twin >= 0 and _next != i:
		if not hit[twin]:
			return
		_c.draw_arc(p, radius + 4.0, 0.0, TAU, 40, Color(_c_point, 0.25 * a), P2Pixel.w(2.0), false)
		return
	var now := not ordered or i == _next
	# 거꾸로 붓: 시작 전에는 마지막 점도 들어갈 수 있는 자리(푸른 바깥 고리)
	if can_reverse and not reversed and crossed_count() == 0 and i == points.size() - 1:
		_c.draw_arc(points[i].round(), radius + 9.0 + 2.0 * sin(_t * 8.0), 0.0, TAU, 40, Color(0.56, 0.76, 0.91, 0.85 * a), P2Pixel.w(3.0), false)
	var pulse := 1.0 + (0.12 if now and ordered else 0.07) * sin(_t * 10.0 + i)
	var r := radius * pulse * lerpf(0.5, 1.0, clampf(_t / INTRO, 0.0, 1.0))
	var k := a * (1.0 if now else 0.45)
	_c.draw_circle(p, r + 10.0, Color(_c_glow, 0.12 * k))
	_c.draw_circle(p, r + 5.0, Color(_c_glow, 0.16 * k))
	_c.draw_circle(p, r, Color(0.08, 0.04, 0.02, 0.5 * k))
	_c.draw_arc(p, r, 0.0, TAU, 40, Color(P2NoteChart.C_OUT, 0.7 * k), P2Pixel.w(3.0) + 4.0, false)
	_c.draw_arc(p, r, 0.0, TAU, 40, Color(_c_point, k), P2Pixel.w(3.0), false)
	# 가운데 고리: 이 안을 지나가야 완벽
	_c.draw_arc(p, radius * precise, 0.0, TAU, 32, Color(_c_point, 0.55 * k), P2Pixel.w(1.0), false)
	if beat > 0.0 and now:
		var u := clampf(1.0 - (_target[i] - _t) / LEAD, 0.0, 1.0)
		var on := _in_window(i)
		_c.draw_arc(p, lerpf(radius * 3.0, radius, u), 0.0, TAU, 48, Color(C_DONE if on else _c_point, lerpf(0.3, 1.0, u) * k), P2Pixel.w(4.0 if on else 3.0), false)
	if ordered:
		var txt := str(i + 1)
		var w := _num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var at := (p + Vector2(-w / 2.0, 9.0)).round()
		_c.text(_num, at, txt, 24, Color(C_CORE, k), 5, Color(0.05, 0.03, 0.02, k))
		return
	var d := 4.0
	_c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), Color(C_CORE, a))


# 한 번 긋기: 시작점에서 끝점까지 굵은 화살표(이 방향으로 휙)
func _draw_arrow(p0: Vector2, p1: Vector2, a: float) -> void:
	var dir := (p1 - p0).normalized()
	var s0 := p0 - dir * (radius + 30.0)
	var s1 := p1 + dir * (radius + 30.0)
	_c.draw_line(s0, s1, Color(_c_glow, 0.18 * a), 22.0, false)
	_c.draw_line(s0, s1, Color(_c_point, 0.55 * a), P2Pixel.w(3.0), false)
	for side in [0.55, -0.55]:
		_c.draw_line(s1, s1 - dir.rotated(side) * 26.0, Color(_c_point, 0.9 * a), 4.0, false)


func _draw_thorn(c: Vector2, a: float) -> void:
	var p := c.round()
	var ti := thorns.find(c)
	if _eaten.has(ti):
		# 삼킨 가시: 금빛으로 터지며 사라짐
		var u := clampf((_t - float(_eaten[ti])) / 0.3, 0.0, 1.0)
		_c.draw_arc(p, THORN_R * lerpf(1.0, 2.4, u), 0.0, TAU, 24, Color(C_DONE, (1.0 - u) * a), P2Pixel.w(3.0), false)
		for s in range(6):
			var d := Vector2.RIGHT.rotated(TAU * s / 6.0)
			_c.draw_line(p + d * THORN_R * u, p + d * THORN_R * (1.0 + 1.6 * u), Color(C_THORN, (1.0 - u) * a), P2Pixel.w(2.0), false)
		return
	_c.draw_circle(p, THORN_R, Color(0.25, 0.02, 0.02, 0.55 * a))
	_c.draw_arc(p, THORN_R, 0.0, TAU, 24, Color(C_THORN, a), P2Pixel.w(2.0), false)
	for s in range(8):
		var dir := Vector2.RIGHT.rotated(TAU * s / 8.0 + sin(_t * 3.0) * 0.1)
		_c.draw_line(p + dir * THORN_R, p + dir * (THORN_R + 6.0), Color(C_THORN, a), P2Pixel.w(2.0), false)
	_c.draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), Color(C_THORN, a), P2Pixel.w(2.0), false)
	_c.draw_line(p + Vector2(5, -5), p + Vector2(-5, 5), Color(C_THORN, a), P2Pixel.w(2.0), false)


func _draw_stroke(a: float) -> void:
	if stroke.size() < 2:
		return
	for i in range(1, stroke.size()):
		var age := _t - stroke_t[i]
		var ga := clampf(1.0 - age / 0.45, 0.0, 1.0) * 0.32 * a
		if ga > 0.0:
			_c.draw_line(stroke[i - 1], stroke[i], Color(_c_glow, ga), 12.0, P2Pixel.smooth())
	for i in range(1, stroke.size()):
		var age := _t - stroke_t[i]
		var ca := clampf(1.0 - age / 0.9, 0.15, 1.0) * a
		_c.draw_line(stroke[i - 1], stroke[i], Color(C_THORN if _broken else C_CORE, ca), 4.0, P2Pixel.smooth())
	if _drawing:
		_c.draw_circle(stroke[stroke.size() - 1], 5.0, Color(C_CORE, a))


# 시간 막대: 앞쪽 금색 구간 안에 끝내야 완벽. 지나면 회색(이제 정확까지만)
func _draw_timer() -> void:
	var b := _bounds()
	var w := 140.0
	var at := Vector2(b.get_center().x - w / 2.0, b.end.y + radius + 22.0).round()
	var used := clampf((_t - INTRO) / limit, 0.0, 1.0)
	var left := 1.0 - used
	_c.draw_rect(Rect2(at - Vector2(2, 2), Vector2(w + 4, 8)), Color(0.04, 0.03, 0.03, 0.85))
	_c.draw_rect(Rect2(at, Vector2(roundf(w * left), 4)), C_SLOW if used > fast else C_DONE)
	var mark := at.x + roundf(w * (1.0 - fast))
	_c.draw_rect(Rect2(Vector2(mark - 1.0, at.y - 4.0), Vector2(2, 12)), Color(C_DONE, 0.9))
	var lab := "완벽 구간" if used <= fast else "느림"
	_c.text(_small, at + Vector2(w + 8.0, 6.0), lab, 12, C_DONE if used <= fast else C_SLOW, 3, Color(0, 0, 0, 0.9))


func _bounds() -> Rect2:
	var b := Rect2(points[0], Vector2.ZERO)
	for p in points:
		b = b.expand(p)
	return b


func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var dist := a.distance_to(b)
	var dir := (b - a) / maxf(dist, 0.001)
	var s := radius + 4.0
	while s < dist - radius - 4.0:
		_c.draw_line(a + dir * s, a + dir * minf(s + 7.0, dist - radius - 4.0), c, P2Pixel.w(2.0), false)
		s += 14.0
