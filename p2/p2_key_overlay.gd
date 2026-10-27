class_name P2KeyOverlay
extends Control

# 키 표시(리듬 게임 키 오버레이): 다가오는 공격 판 위. 1~4 네 칸이 늘 보이고, 키·클릭은 처음 쓴 순서대로 칸에 앉는다
# (다섯 번째 입력은 오래 안 쓴 칸을 물려받음). 누르는 동안 칸이 맥 빛(푸른색)으로 차고, 누른 길이만큼의 막대가 칸 위로 솟아
# 올라가며 흐려진다. 오른쪽은 초당 누름(KPS)과 이번 전투에서 누른 수

const COLS := 4
const BOX := Vector2(34, 28)
const GAP := 5.0
const RISE := 140.0
const LANE := 92.0
const C_ON := Color("#6cc0ff")
const C_BAR := Color("#9fd4ff")
const C_RIM := Color("#3f7fc4")
const C_TEXT := Color("#dcefff")

var on := false
var total := 0
var cols: Array = []
var _bars: Array = []
var _times: Array = []
var _t := 0.0
var _a := 0.0
var _font: Font
var _small: Font
var _c: P2Pixel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(COLS):
		cols.append({"id": null, "down": false, "pop": -9.0, "used": -9.0})
	size = Vector2(200, LANE + BOX.y)
	_font = P2Ui.bold_font(16)
	_small = P2Ui.pixel_font(12)
	_c = P2Pixel.attach(self, _paint)


func press(id: Variant, is_down: bool, label: String) -> void:
	var ci := _find(id)
	if ci < 0:
		if not is_down:
			return
		ci = _col(id, label)
	var c: Dictionary = cols[ci]
	if is_down:
		if bool(c.down):
			return
		c.down = true
		c.pop = _t
		c.used = _t
		_bars.append({"col": ci, "t0": _t, "t1": -1.0})
		_times.append(_t)
		total += 1
	else:
		c.down = false
		for b in _bars:
			if int(b.col) == ci and float(b.t1) < 0.0:
				b.t1 = _t


# 악보·긋기가 먼저 끝나 떼기를 못 전해 줘도, 키·버튼을 떼면 칸이 바로 풀린다
func _input(event: InputEvent) -> void:
	var id: Variant = null
	if event is InputEventKey and not (event as InputEventKey).pressed:
		id = P2NoteChart.key_id(event as InputEventKey)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		id = "mouse"
	if id == null:
		return
	var ci := _find(id)
	if ci >= 0 and bool(cols[ci].down):
		press(id, false, "")


func _release_all() -> void:
	for i in range(cols.size()):
		if bool(cols[i].down):
			press(cols[i].id, false, "")


func kps() -> int:
	return _times.filter(func(x): return _t - float(x) <= 1.0).size()


func _find(id: Variant) -> int:
	for i in range(cols.size()):
		if cols[i].id != null and str(cols[i].id) == str(id):
			return i
	return -1


func used() -> int:
	return cols.filter(func(c): return c.id != null).size()


func _col(id: Variant, _label: String) -> int:
	var fresh := {"id": id, "down": false, "pop": -9.0, "used": _t}
	for i in range(cols.size()):
		if cols[i].id == null:
			cols[i] = fresh
			return i
	var old := -1
	for i in range(cols.size()):
		if not bool(cols[i].down) and (old < 0 or float(cols[i].used) < float(cols[old].used)):
			old = i
	old = maxi(old, 0)
	cols[old] = fresh
	_bars = _bars.filter(func(b): return int(b.col) != old)
	return old


func _process(delta: float) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if on else 0.0, delta * 5.0)
	visible = _a > 0.01
	if not on:
		_release_all()
	_bars = _bars.filter(func(b): return float(b.t1) < 0.0 or (_t - float(b.t1)) * RISE < LANE)
	_times = _times.filter(func(x): return _t - float(x) <= 1.0)
	_c.redraw()


func _paint() -> void:
	for i in range(cols.size()):
		var c: Dictionary = cols[i]
		var x := i * (BOX.x + GAP)
		# 솟는 막대: 위 끝 = 누른 때, 아래 끝 = 뗀 때(쥐고 있으면 칸에 붙어 있음)
		for b in _bars:
			if int(b.col) != i:
				continue
			var top := LANE - (_t - float(b.t0)) * RISE
			var bot := LANE - 2.0 - (maxf(0.0, (_t - float(b.t1)) * RISE) if float(b.t1) >= 0.0 else 0.0)
			top = maxf(top, 0.0)
			if bot - top < 2.0:
				top = bot - 2.0
			if bot <= 0.0:
				continue
			var fade := clampf(bot / (LANE * 0.5), 0.0, 1.0)
			_c.draw_rect(Rect2(x + 6, roundf(top), BOX.x - 12, roundf(bot - top)), Color(C_BAR, 0.8 * fade * _a))
			_c.draw_rect(Rect2(x + 6, roundf(top), 2, roundf(bot - top)), Color(1, 1, 1, 0.35 * fade * _a))
		var lit := bool(c.down)
		var u := clampf((_t - float(c.pop)) / 0.12, 0.0, 1.0)
		var sink := 4.0 if lit else roundf((1.0 - u) * 2.0)
		var lip := Rect2(Vector2(x, LANE + 4), BOX - Vector2(0, 4))
		_c.draw_rect(lip, Color(0.02, 0.03, 0.06, 0.9 * _a))
		var face := Rect2(Vector2(x, LANE + sink), BOX - Vector2(0, 4))
		_c.draw_rect(face, Color(C_ON, 0.95 * _a) if lit else Color(0.09, 0.12, 0.19, 0.92 * _a))
		_c.draw_rect(Rect2(face.position + Vector2(2, 2), Vector2(face.size.x - 4, 2)), Color(Color.WHITE if lit else C_RIM.lightened(0.2), 0.55 * _a))
		_c.draw_rect(Rect2(Vector2(x, LANE + sink), Vector2(BOX.x, BOX.y - sink)), Color(P2NoteChart.C_OUT, _a), false, P2Pixel.w(2.0))
		var cap := str(i + 1)
		var w := _small.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_c.text(_small, (face.get_center() + Vector2(-w / 2.0, 5)).round(), cap, 12, Color(Color(0.03, 0.08, 0.16) if lit else C_TEXT, _a))
	var rx := COLS * (BOX.x + GAP) + 2.0
	var k := str(kps())
	_c.text(_font, Vector2(rx, LANE + 12), k, 16, Color(C_TEXT, _a), 4, Color(0, 0, 0, _a))
	var kw := _font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_c.text(_small, Vector2(rx + kw + 3, LANE + 12), "KPS", 12, Color(C_RIM, _a))
	_c.text(_small, Vector2(rx, LANE + 27), str(total), 12, Color(C_RIM, _a), 3, Color(0, 0, 0, _a))
