class_name P2ScaleRing
extends Control

# 음계 고리(독립 시안): 지금 세계 음계 모양 · 지금 박 · 쳐 낸 음을 한눈에. 보기만 하는 장식이라 몰라도 막기에는 지장이 없다.
# 12음 자리를 시계처럼 돌려 놓고(맨 위 = 도), 세계 음계를 세계 색 다각형으로, 모든 세계가 함께 가진 음(worlds.json common)은 금색으로.
# 테두리의 박 눈금 4개 중 지금 박이 켜지고 점 하나가 한 마디에 한 바퀴 돈다. 쳐 낸 음은 하얗게 켜졌다 잦아들고, 길게 누르는 동안은 켜진 채.
# 세계가 바뀌면 필인 한 박 동안 옛 음계 다각형이 새 모양으로 바뀐다. 아래 작은 점 여섯 = 쌓인 겹
# 바깥에서 받는 값(얇은 인터페이스): feed(음악 시각 · 박 · 마디 길이 · 쌓인 겹) · note_hit(막기 음, 등급, 시각) · hold(음, 켬/끔, 시각) · set_world(세계, 전환 시작, 길이)

const DATA := "res://p2/scale_ring/worlds.json"
const G := 48
const C := Vector2(24, 24)
const R_PT := 14.0
const R_RIM := 20.0
const GOLD := Color("#e8c46a")
const DIM := Color("#4a4560")
const INK := Color("#0e0c15")
const LIT_LEN := 0.35

static var _data := {}

# 도트 한 칸 = 화면 pix px
@export var pix := 3:
	set(v):
		pix = maxi(1, v)
		custom_minimum_size = Vector2(G, G + 6) * pix
var world := ""
var _from: Array = []
var _to: Array = []
var _from_col := Color.WHITE
var _to_col := Color.WHITE
var _morph_t0 := -1.0
var _morph_len := 0.0
var _now := 0.0
var _beat := 0.5
var _bar := 2.0
var _earned := 0
var _hits := {}
var _held := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = j if j is Dictionary else {"order": [], "worlds": {}, "common": [], "names": []}
	return _data


func _ready() -> void:
	pix = pix
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# 세계를 정한다. at < 0이면 바로, 아니면 음악 시각 at부터 secs 동안 다각형이 옛 음계에서 바뀐다(필인 한 박)
func set_world(id: String, at := -1.0, secs := 0.0) -> void:
	var w: Dictionary = (data().worlds as Dictionary).get(id, {})
	if w.is_empty():
		return
	var pts := _shape(w.scale)
	var col := Color(String(w.color))
	if world == "" or at < 0.0:
		_from = pts
		_from_col = col
		_morph_t0 = -1.0
	else:
		_from = _blend()
		_from_col = _color()
		_morph_t0 = at
		_morph_len = maxf(secs, 0.05)
	_to = pts
	_to_col = col
	world = id
	queue_redraw()


# 매 프레임 바깥(예: P2Music)에서: 음악 시각 · 한 박 · 한 마디 길이(초) · 쌓인 겹 수
func feed(now: float, beat: float, bar: float, earned: int) -> void:
	_now = now
	_beat = maxf(beat, 0.01)
	_bar = maxf(bar, 0.01)
	_earned = earned
	queue_redraw()


# 막기 판정 하나: 완벽 · 막음이면 그 음 자리가 켜진다(놓침은 아무것도 안 함). semi = 막기 음(도 기준 반음)
func note_hit(semi: int, grade: String, at: float) -> void:
	if grade == "miss":
		return
	_hits[posmod(semi, 12)] = at


# 길게 누르는 동안 그 음 자리를 켜 둔다
func hold(semi: int, on: bool, at: float) -> void:
	var pc := posmod(semi, 12)
	if on:
		_held[pc] = true
		_hits[pc] = at
	else:
		_held.erase(pc)
		_hits[pc] = at


static func _angle(pc: float) -> float:
	return -PI / 2.0 + pc * TAU / 12.0


static func _at(pc: float, r: float) -> Vector2:
	return C + Vector2(cos(_angle(pc)), sin(_angle(pc))) * r


# 음계 다각형을 12점으로: 음계 음은 제자리, 그 밖의 음은 앞뒤 음계 음을 잇는 변 위에 놓아 모양이 같다(서로 다른 음계끼리 점마다 이어 바꿀 수 있게)
static func _shape(scale: Array) -> Array:
	var s: Array = scale.duplicate()
	s.sort()
	var out: Array = []
	for pc in range(12):
		if s.has(pc):
			out.append(_at(pc, R_PT))
			continue
		var a: int = s[s.size() - 1] - 12
		var b: int = s[0] + 12
		for q in s:
			if int(q) < pc:
				a = int(q)
			elif int(q) > pc:
				b = int(q)
				break
		var k := float(pc - a) / float(b - a)
		out.append(_at(posmod(a, 12), R_PT).lerp(_at(posmod(b, 12), R_PT), k))
	return out


func _morph_k() -> float:
	if _morph_t0 < 0.0:
		return 1.0
	var k := clampf((_now - _morph_t0) / _morph_len, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _blend() -> Array:
	if _from.is_empty():
		return _to
	var k := _morph_k()
	var out: Array = []
	for i in range(12):
		out.append((_from[i] as Vector2).lerp(_to[i], k))
	return out


# 색은 색상환을 따라(OKHSL, 가까운 쪽으로) 바꾼다. RGB를 그대로 섞으면 반대쪽 색끼리 가운데가 회색이 된다
func _color() -> Color:
	var k := _morph_k()
	if k >= 1.0:
		return _to_col
	var dh := fposmod(_to_col.ok_hsl_h - _from_col.ok_hsl_h + 0.5, 1.0) - 0.5
	return Color.from_ok_hsl(fposmod(_from_col.ok_hsl_h + dh * k, 1.0), lerpf(_from_col.ok_hsl_s, _to_col.ok_hsl_s, k),
		lerpf(_from_col.ok_hsl_l, _to_col.ok_hsl_l, k), lerpf(_from_col.a, _to_col.a, k))


# ── 그리기: 48칸 격자에 한 칸씩(최근접, 안티에일리어싱 없음) ──
func _px(x: int, y: int, c: Color) -> void:
	draw_rect(Rect2(x * pix, y * pix, pix, pix), c)


func _line(a: Vector2, b: Vector2, c: Color) -> void:
	var x0 := roundi(a.x)
	var y0 := roundi(a.y)
	var x1 := roundi(b.x)
	var y1 := roundi(b.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_px(x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _fill(poly: Array, c: Color) -> void:
	for y in range(G):
		var cy := y + 0.5
		var xs: Array = []
		for i in range(poly.size()):
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			if (a.y <= cy and b.y > cy) or (b.y <= cy and a.y > cy):
				xs.append(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			for x in range(ceili(float(xs[i]) - 0.5), floori(float(xs[i + 1]) - 0.5) + 1):
				_px(x, y, c)


func _draw() -> void:
	if world == "":
		return
	var d := data()
	var w: Dictionary = d.worlds[world]
	var col := _color()
	var common: Array = d.common
	# 바탕 원과 테두리 점선
	_fill(_disc(R_RIM + 2.5), Color(INK, 0.82))
	for i in range(72):
		if i % 2 == 0:
			var p := C + Vector2(cos(i * TAU / 72.0), sin(i * TAU / 72.0)) * R_RIM
			_px(roundi(p.x), roundi(p.y), Color(GOLD, 0.28))
	# 음계 다각형
	var poly := _blend()
	_fill(poly, Color(col, 0.22))
	for i in range(12):
		_line(poly[i], poly[(i + 1) % 12], Color(col, 0.75))
	# 12음 자리: 음계 음 2×2(공통음 금색), 그 밖 1칸 흐리게. 쳐 낸 음은 하얗게 켜졌다 잦아든다
	for pc in range(12):
		var p := _at(pc, R_PT)
		var x := roundi(p.x)
		var y := roundi(p.y)
		var on := (w.scale as Array).has(pc)
		var lit := 1.0 if _held.has(pc) else clampf(1.0 - (_now - float(_hits.get(pc, -99.0))) / LIT_LEN, 0.0, 1.0)
		if lit > 0.0:
			var halo := Color(Color.WHITE, 0.35 * lit)
			for o in [Vector2i(-1, -1), Vector2i(2, -1), Vector2i(-1, 2), Vector2i(2, 2)]:
				_px(x + o.x, y + o.y, halo)
			for o in [Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]:
				_px(x + o.x, y + o.y, Color(Color.WHITE, 0.7 * lit))
		if on:
			var c: Color = GOLD if common.has(pc) else col
			c = c.lerp(Color.WHITE, lit)
			for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				_px(x + o.x, y + o.y, c)
		else:
			_px(x, y, DIM.lerp(Color.WHITE, lit * 0.6))
	# 박: 테두리 위 눈금 넷(맨 위 = 첫 박), 지금 박이 켜지고 점 하나가 마디를 따라 돈다
	var bar_t := fposmod(_now, _bar) / _bar
	var cur := int(floor(bar_t * 4.0))
	for b in range(4):
		var p := C + Vector2(cos(-PI / 2.0 + b * TAU / 4.0), sin(-PI / 2.0 + b * TAU / 4.0)) * R_RIM
		var c: Color = col if b == cur else Color(GOLD, 0.45)
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_px(roundi(p.x) + o.x - (1 if b == 2 else 0), roundi(p.y) + o.y - (1 if b == 1 else 0), c)
	var run := C + Vector2(cos(-PI / 2.0 + bar_t * TAU), sin(-PI / 2.0 + bar_t * TAU)) * (R_RIM + 2.0)
	_px(roundi(run.x), roundi(run.y), Color(Color.WHITE, 0.85))
	# 쌓인 겹: 아래 점 여섯
	for k in range(6):
		var c := Color(col, 0.9) if k < _earned else Color(DIM, 0.8)
		_px(24 - 6 + k * 2, G + 2, c)


static func _disc(r: float) -> Array:
	var out: Array = []
	for i in range(36):
		out.append(C + Vector2(cos(i * TAU / 36.0), sin(i * TAU / 36.0)) * r)
	return out
