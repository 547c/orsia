class_name P2StatusAura
extends Node2D

# 적 몸에 붙어 다니는 상태 모습(세계 층 _fx). 화면이 매 프레임 feet·body_h·st·link_to를 넣는다.
# (화상 · 독 · 냉기 · 저주 해골은 손그림 묶음 P2StatusPack이 그림)
# 얼어붙음 = 몸을 덮은 얼음 덩어리 · 출혈 = 몸에서 떨어지는 핏방울 · 취약 = 몸에 간 금 · 약화 = 머리 위로 내려앉는 보라 꺾쇠 ·
# 저주 = 보라 그림자 불꽃 + 머리 위 해골과 남은 턴 · 덫 = 앞쪽 바닥의 쇠 덫 · 고통 연결 = 묶인 적까지 보라 사슬

var feet := Vector2.ZERO
var body_h := 120.0
var body_w := 80.0
var st: Dictionary = {}
var link_to := Vector2.INF
var alive := true
var doom_mult := P2Catalog.DOOM_MULT
var _t := 0.0
var _drips: Array = []
var _font: Font
var _ice_open := 0.0
# 픽셀 그림판 밖(매끈한 층)에 화면이 대신 써 주는 글자: 저주 피해·남은 턴
var label := ""
var label_at := Vector2.ZERO


func _ready() -> void:
	_font = P2Ui.bold_font(24)


func _process(delta: float) -> void:
	_t += delta
	var target_ice := 1.0 if int(st.get("frozen", 0)) > 0 and alive else 0.0
	_ice_open = move_toward(_ice_open, target_ice, delta * (6.0 if target_ice > 0.0 else 9.0))
	if int(st.get("bleed", 0)) > 0 and alive and randf() < delta * (2.0 + float(st.bleed)):
		_drips.append({"p": Vector2(randf_range(-body_w * 0.3, body_w * 0.3), -body_h * randf_range(0.35, 0.7)), "v": 0.0})
	for d in _drips:
		d.v = float(d.v) + 900.0 * delta
		d.p = (d.p as Vector2) + Vector2(0, float(d.v) * delta)
	_drips = _drips.filter(func(d): return (d.p as Vector2).y < 6.0)
	queue_redraw()


func _draw() -> void:
	label = ""
	if not alive:
		return
	var real := _t
	_t = floorf(_t * P2Vfx.FPS) / P2Vfx.FPS
	_draw_states()
	_t = real


func _draw_states() -> void:
	position = feet
	var h := body_h
	var w := body_w
	if int(st.get("doom", 0)) > 0:
		_doom(h, w)
	if int(st.get("vuln", 0)) > 0:
		_cracks(h, w)
	if int(st.get("weak", 0)) > 0:
		_weak(h)
	for d in _drips:
		var p: Vector2 = d.p
		draw_circle(p, 3.0, Color("#c81e2a"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(0, -8)]), Color("#c81e2a"))
	if int(st.get("trap", 0)) > 0:
		_trap(Vector2(-w * 0.75, 2))
	if _ice_open > 0.0:
		_ice(h, w, _ice_open)
	if link_to != Vector2.INF:
		_chain(Vector2(0, -h * 0.5), link_to - feet + Vector2(0, -h * 0.5))


func _ice(h: float, w: float, k: float) -> void:
	# 얼음 덩어리: 몸을 감싼 다각형(아래에서 위로 차오름), 면마다 밝기 다른 반투명 청록, 흰 모서리와 비스듬한 반사
	var top := -h * 1.08
	var fill := lerpf(0.0, top, k)
	var pts := PackedVector2Array([Vector2(-w * 0.62, 0), Vector2(-w * 0.7, -h * 0.35), Vector2(-w * 0.5, -h * 0.82), Vector2(-w * 0.18, top),
		Vector2(w * 0.28, top * 0.96), Vector2(w * 0.62, -h * 0.7), Vector2(w * 0.7, -h * 0.2), Vector2(w * 0.55, 0)])
	var clipped := PackedVector2Array()
	for p in pts:
		clipped.append(Vector2(p.x, maxf(p.y, fill)))
	draw_colored_polygon(clipped, Color(0.55, 0.86, 1.0, 0.58 * k))
	var facets := [[0, 2, 3], [3, 4, 5], [5, 6, 7], [0, 1, 2]]
	for f in facets:
		var tri := PackedVector2Array()
		for idx in f:
			tri.append(clipped[int(idx)])
		draw_colored_polygon(tri, Color(0.88, 0.98, 1.0, 0.26 * k))
	draw_polyline(clipped + PackedVector2Array([clipped[0]]), Color(0.2, 0.45, 0.6, 0.8 * k), 5.0, false)
	draw_polyline(clipped + PackedVector2Array([clipped[0]]), Color(0.92, 1.0, 1.0, 0.95 * k), 2.5, false)
	draw_line(clipped[3], clipped[0].lerp(clipped[7], 0.4), Color(1, 1, 1, 0.35 * k), 1.5, false)
	var shine := fmod(_t * 0.5, 1.6) - 0.3
	var sx := lerpf(-w * 0.6, w * 0.6, shine)
	draw_line(Vector2(sx - 16, maxf(fill, -h * 0.9)), Vector2(sx + 16, -h * 0.1), Color(1, 1, 1, 0.45 * k * clampf(1.0 - absf(shine - 0.5), 0.0, 1.0)), 4.0)
	for j in range(5):
		var mp := Vector2(sin(j * 1.9 + _t * 0.7) * w * 0.6, -4.0)
		draw_circle(mp, 14.0 + 4.0 * sin(_t + j), Color(0.9, 0.98, 1.0, 0.18 * k))


func _cracks(h: float, w: float) -> void:
	var c := Vector2(0, -h * 0.55)
	for j in range(5):
		var d := Vector2.RIGHT.rotated(j * 1.26 + 0.3)
		var p0 := c
		for seg in range(3):
			var p1 := p0 + d.rotated(sin(j * 3.0 + seg) * 0.6) * w * 0.14
			draw_line(p0, p1, Color(1, 0.95, 0.9, 0.7), 1.8, false)
			p0 = p1


func _weak(h: float) -> void:
	for j in range(3):
		var cyc := fmod(_t * 0.5 + j * 0.33, 1.0)
		var y := -h - 30.0 + cyc * 26.0
		var a := sin(cyc * PI)
		draw_polyline(PackedVector2Array([Vector2(-10, y), Vector2(0, y + 8), Vector2(10, y)]), Color(0.75, 0.5, 1.0, a), 3.0, false)


func _doom(h: float, w: float) -> void:
	var head := Vector2(0, -h - 46.0)
	var n := int(st.get("doom", 0))
	var t := int(st.get("doom_t", 0))
	var txt := "%d·%d턴" % [n * doom_mult, t]
	label = txt
	label_at = head + Vector2(20, 7)
	if t <= 1:
		var pulse := 0.5 + 0.5 * sin(_t * 12.0)
		draw_arc(head, 20.0 + pulse * 6.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.9, pulse), 2.0, false)


func _trap(at: Vector2) -> void:
	var steel := Color("#b8c2cc")
	draw_rect(Rect2(at + Vector2(-26, -3), Vector2(52, 5)), Color("#3a3f46"))
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for k in range(11):
			var t := k / 10.0
			pts.append(at + Vector2(lerpf(-24.0, 24.0, t), side * (-6.0 - sin(t * PI) * 9.0) + (-5.0 if k % 2 == 0 else 0.0) * side))
		draw_polyline(pts, steel, 2.5, false)
	var glint := fmod(_t * 0.7, 1.0)
	if glint < 0.15:
		var gp := at + Vector2(lerpf(-24.0, 24.0, glint / 0.15), -12.0)
		draw_line(gp - Vector2(6, 0), gp + Vector2(6, 0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(gp - Vector2(0, 6), gp + Vector2(0, 6), Color(1, 1, 1, 0.9), 2.0)


func _chain(a: Vector2, b: Vector2) -> void:
	var v := b - a
	var len := v.length()
	if len < 10.0:
		return
	var d := v / len
	var n := d.orthogonal()
	var links := int(len / 18.0)
	for k in range(links):
		var t := (k + 0.5) / links
		var sag := sin(t * PI) * 26.0
		var p := a + v * t + Vector2(0, sag)
		var e := 0.5 + 0.5 * sin(_t * 8.0 - k * 0.6)
		var ax := d * 7.0 if k % 2 == 0 else n * 5.0
		draw_line(p - ax, p + ax, Color(0.7, 0.35, 1.0, 0.75), 3.0, false)
		draw_circle(p, 2.0, Color(1.0, 0.8, 1.0, e * 0.7))
