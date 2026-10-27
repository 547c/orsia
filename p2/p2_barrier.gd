class_name P2Barrier
extends Node2D

# 마력 장막: 주인공을 감싸는 앞 호(밝음)·뒤 호(옅음) 타원과 그 위를 도는 빛 알갱이. 방어가 있을 때만 보이고,
# 막을 때 맞은 자리에서 물결이 퍼지며, 다 깎이면 조각나 흩어진다. 위치는 주인공 몸 가운데(position)

const C_FRONT := Color("#8ff3ff")
const C_BACK := Color("#4fb8c8")
const RX := 74.0
const RY := 100.0

var _amount := 0
var _show := 0.0
var _t := 0.0
var _ripples: Array = []
var _flick := 0.0


func set_amount(v: int) -> void:
	_amount = v


# 맞은 자리(이 노드 기준)에서 물결
func ripple(at_local: Vector2) -> void:
	var a := atan2(at_local.y / RY, at_local.x / RX)
	_ripples.append({"a": a, "t": 0.0})
	_flick = 0.18


func _process(delta: float) -> void:
	_t += delta
	_show = move_toward(_show, 1.0 if _amount > 0 else 0.0, delta * 5.0)
	_flick = maxf(0.0, _flick - delta)
	for r in _ripples:
		r.t = float(r.t) + delta
	_ripples = _ripples.filter(func(r): return float(r.t) < 0.4)
	visible = _show > 0.01 or not _ripples.is_empty()
	queue_redraw()


func _pt(a: float, grow := 0.0) -> Vector2:
	return Vector2(cos(a) * (RX + grow), sin(a) * (RY + grow))


func _arc(a0: float, a1: float, c: Color, w: float, grow := 0.0) -> void:
	var pts := PackedVector2Array()
	var n := 28
	for i in range(n + 1):
		pts.append(_pt(lerpf(a0, a1, float(i) / n), grow).round())
	draw_polyline(pts, c, w, false)


func _draw() -> void:
	var k := _show * (0.55 + 0.45 * minf(1.0, _amount / 10.0))
	if _flick > 0.0:
		k *= 0.6 + 0.4 * float(int(_flick * 40.0) % 2)
	if k > 0.0:
		# 뒤 호(왼쪽) → 앞 호(오른쪽, 적 쪽). 살짝 숨쉬듯 커졌다 작아진다
		var g := sin(_t * 2.4) * 2.0
		var fill := PackedVector2Array()
		for i in range(40):
			fill.append(_pt(TAU * i / 40.0, g))
		draw_colored_polygon(fill, Color(C_FRONT, 0.07 * k))
		_arc(PI * 0.62, PI * 1.38, Color(C_BACK, 0.45 * k), 2.0, g)
		_arc(-PI * 0.42, PI * 0.42, Color(C_FRONT, 0.3 * k), 12.0, g)
		_arc(-PI * 0.42, PI * 0.42, Color(C_FRONT, k), 3.0, g)
		_arc(-PI * 0.3, PI * 0.3, Color(1, 1, 1, 0.5 * k), 1.0, g - 4.0)
		for i in range(6):
			var a := fposmod(_t * 0.9 + i * TAU / 6.0, TAU)
			var front := cos(a) > 0.0
			var p := _pt(a, g).round()
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, (0.9 if front else 0.35) * k))
	for r in _ripples:
		var u := float(r.t) / 0.4
		var a0 := float(r.a)
		_arc(a0 - 0.5 - u * 0.4, a0 + 0.5 + u * 0.4, Color(1, 1, 1, 0.9 * (1.0 - u)), 3.0, 4.0 + 18.0 * u)
		_arc(a0 - 0.3, a0 + 0.3, Color(C_FRONT, 0.8 * (1.0 - u)), 6.0, 2.0 + 8.0 * u)
