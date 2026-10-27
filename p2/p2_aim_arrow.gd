class_name P2AimArrow
extends Node2D

# 조준 화살표: 카드에서 대상까지 위로 휜 곡선을 따라 작은 화살 마디가 대상 쪽으로 흐르고, 끝에 큰 화살촉

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var _t := 0.0
var _c: P2Pixel


func _ready() -> void:
	_c = P2Pixel.attach(self, _paint)


func set_arrow(a: Vector2, b: Vector2, c: Color) -> void:
	from = a
	to = b
	color = c
	visible = true
	_c.redraw()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_c.redraw()


func _point(u: float) -> Vector2:
	var ctrl := from.lerp(to, 0.5) + Vector2(0, -minf(from.distance_to(to) * 0.35, 190.0))
	return from.lerp(ctrl, u).lerp(ctrl.lerp(to, u), u)


func _paint() -> void:
	var dist := from.distance_to(to)
	if dist < 20.0:
		return
	var line := PackedVector2Array()
	for k in range(25):
		line.append(_point(k / 24.0 * 0.92))
	_c.draw_polyline(line, Color(0.08, 0.05, 0.03, 0.55), P2Pixel.w(7.0), P2Pixel.smooth())
	_c.draw_polyline(line, Color(color, 0.45), P2Pixel.w(3.0), P2Pixel.smooth())
	var n := clampi(int(dist / 30.0), 4, 24)
	var phase := fmod(_t * 1.6, 1.0)
	for k in range(n):
		var u := (float(k) + phase) / float(n)
		if u > 0.93:
			continue
		var p := _point(u)
		var dir := (_point(minf(u + 0.02, 1.0)) - p).normalized()
		var a := lerpf(0.55, 1.0, clampf(u * 2.0, 0.0, 1.0))
		var s := lerpf(6.0, 10.0, u)
		var side := dir.orthogonal()
		_c.draw_colored_polygon(PackedVector2Array([p + dir * s, p - dir * s * 0.4 + side * s * 0.8, p - dir * s * 0.1, p - dir * s * 0.4 - side * s * 0.8]),
			Color(color, a))
	var tip := to
	var back := (to - _point(0.92)).normalized()
	var side2 := back.orthogonal()
	_c.draw_colored_polygon(PackedVector2Array([tip, tip - back * 26.0 + side2 * 15.0, tip - back * 18.0, tip - back * 26.0 - side2 * 15.0]), color)
	_c.draw_polyline(PackedVector2Array([tip, tip - back * 26.0 + side2 * 15.0, tip - back * 18.0, tip - back * 26.0 - side2 * 15.0, tip]), Color(0.1, 0.06, 0.04, 0.9), P2Pixel.w(2.0))
