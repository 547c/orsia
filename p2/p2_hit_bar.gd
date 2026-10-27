class_name P2HitBar
extends Control

# 판정 오차 막대(osu hit error meter): 가운데 흰 줄 = 고리가 원에 닿은 순간, 왼쪽 = 이르게, 오른쪽 = 늦게.
# 금빛 = 완벽 창, 푸른 = 막음 창. 이르게·늦게 창 길이가 달라도 막대는 좌우 대칭으로 그리고, 칸마다 제 창에 맞춰 늘인다
# (금빛 안의 눈금 = 완벽, 푸른 안 = 막음). 누를 때마다 눈금이 찍혀 4초에 걸쳐 흐려지고, 위 화살표는 최근 평균

const PH := 34.0
const GH := 104.0
const LIFE := 4.0

var on := false
var early_p := 0.05
var late_p := 0.04
var early_g := P2NoteChart.GOOD_EARLY
var late_g := P2NoteChart.GOOD_LATE
var eased := false
var beat_src: P2NoteChart
var beat_phase := 0.0
var _beat_i := 0
var marks: Array = []
var avg := 0.0
var hits := 0
var _a := 0.0
var _small: Font
var _c: P2Pixel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(320, 30)
	_small = P2Ui.pixel_font(12)
	_c = P2Pixel.attach(self, _paint)


func set_windows(pe: float, pl: float, ge := P2NoteChart.GOOD_EARLY, gl := P2NoteChart.GOOD_LATE) -> void:
	early_p = pe
	late_p = pl
	early_g = ge
	late_g = gl
	eased = ge > P2NoteChart.GOOD_EARLY + 0.001


func add(d: float, g: String) -> void:
	marks.append({"d": d, "g": g, "age": 0.0})
	avg = d if hits == 0 else lerpf(avg, d, 0.25)
	hits += 1


# 오차(초) → 가운데에서의 가로 거리(px)
func x_of(d: float) -> float:
	var p := early_p if d < 0.0 else late_p
	var g := early_g if d < 0.0 else late_g
	var a := absf(d)
	var x := a / p * PH if a <= p else PH + (a - p) / (g - p) * (GH - PH)
	return signf(d) * minf(x, GH + 8.0)


func _process(delta: float) -> void:
	if is_instance_valid(beat_src) and float(beat_src.beat) > 0.0:
		var bt := float(beat_src.beat)
		beat_phase = fposmod(float(beat_src._t), bt) / bt
		_beat_i = int(floor(float(beat_src._t) / bt))
	_a = move_toward(_a, 1.0 if on else 0.0, delta * 5.0)
	visible = _a > 0.01
	for m in marks:
		m.age = float(m.age) + delta
	marks = marks.filter(func(m): return float(m.age) < LIFE)
	_c.redraw()


func _paint() -> void:
	var mid := Vector2(size.x / 2.0, 16)
	var frame := Rect2(mid.x - GH - 8, mid.y - 10, GH * 2 + 16, 20)
	_c.draw_rect(frame, Color(0.05, 0.04, 0.06, 0.88 * _a))
	_c.draw_rect(frame, Color(P2Ui.C_EDGE, _a), false, P2Pixel.w(2.0))
	_c.draw_rect(Rect2(frame.position + Vector2(2, 2), Vector2(frame.size.x - 4, 2)), Color(P2Ui.C_BEVEL, 0.5 * _a))
	_band(Rect2(mid.x - GH, mid.y - 4, GH * 2, 8), P2NoteChart.C_GOOD, 0.8)
	_band(Rect2(mid.x - PH, mid.y - 6, PH * 2, 12), P2NoteChart.C_PERFECT, 1.0)
	_c.draw_rect(Rect2(mid.x - 2, mid.y - 12, 4, 24), Color(1, 1, 1, _a))
	for m in marks:
		var x := roundf(mid.x + x_of(float(m.d)))
		var col: Color = P2NoteChart.C_PERFECT if m.g == "perfect" else (P2NoteChart.C_GOOD if m.g == "good" else Color("#e0533a"))
		var f := 1.0 - float(m.age) / LIFE
		_c.draw_rect(Rect2(x - 2, mid.y - 14, 4, 28), Color(P2NoteChart.C_OUT, 0.7 * f * _a))
		_c.draw_rect(Rect2(x - 1, mid.y - 12, 2, 24), Color(col.lightened(0.3), f * _a))
	if hits > 0:
		var ax := roundf(mid.x + x_of(avg))
		var tri := PackedVector2Array([Vector2(ax, mid.y - 13), Vector2(ax - 7, mid.y - 21), Vector2(ax + 7, mid.y - 21)])
		_c.draw_colored_polygon(PackedVector2Array([Vector2(ax, mid.y - 11), Vector2(ax - 9, mid.y - 23), Vector2(ax + 9, mid.y - 23)]), Color(P2NoteChart.C_OUT, 0.8 * _a))
		_c.draw_colored_polygon(tri, Color(1, 1, 1, 0.95 * _a))
	for side in [[-1.0, "이르게"], [1.0, "늦게"]]:
		var t: String = side[1]
		var w := _small.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var x0: float = mid.x - GH - 16 - w if side[0] < 0.0 else mid.x + GH + 16
		_c.text(_small, Vector2(x0, mid.y + 5), t, 12, Color(0.85, 0.8, 0.7, _a), 3, Color(0, 0, 0, _a))
	# 박자 심장(NecroDancer식): 양쪽 막대가 박마다 가운데로 모이고 닿는 순간 심장이 뛴다. 마디 첫 박은 금빛
	if is_instance_valid(beat_src) and float(beat_src.beat) > 0.0:
		var hy := mid.y - 30.0
		var down := _beat_i % 4 == 0
		var hc := P2NoteChart.C_PERFECT if down else Color(0.85, 0.92, 1.0)
		for sgn in [-1.0, 1.0]:
			var bx: float = roundf(mid.x + float(sgn) * (1.0 - beat_phase) * 92.0)
			_c.draw_rect(Rect2(bx - 2, hy - 6, 4, 12), Color(hc, (0.25 + 0.6 * beat_phase) * _a))
		var flash := 1.0 - clampf(beat_phase / 0.18, 0.0, 1.0)
		var hs := roundf(6.0 + 4.0 * flash)
		_c.draw_colored_polygon(PackedVector2Array([Vector2(mid.x, hy - hs - 2), Vector2(mid.x + hs + 2, hy), Vector2(mid.x, hy + hs + 2), Vector2(mid.x - hs - 2, hy)]), Color(P2NoteChart.C_OUT, 0.8 * _a))
		_c.draw_colored_polygon(PackedVector2Array([Vector2(mid.x, hy - hs), Vector2(mid.x + hs, hy), Vector2(mid.x, hy + hs), Vector2(mid.x - hs, hy)]), Color(hc, (0.55 + 0.45 * flash) * _a))
	if eased:
		var tw := _small.get_string_size("입문 판정", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_c.text(_small, Vector2(mid.x - tw / 2.0, mid.y + 25), "입문 판정", 12, Color(0.75, 0.9, 1.0, _a), 3, Color(0, 0, 0, _a))


# 계기 칸 하나: 바탕 · 위 밝은 줄 · 아래 어두운 줄
func _band(r: Rect2, col: Color, k: float) -> void:
	_c.draw_rect(r, Color(col.darkened(0.15), k * _a))
	_c.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(col.lightened(0.35), k * _a))
	_c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), Color(col.darkened(0.45), k * _a))
