class_name P2HitBits
extends Node2D

# 맞는 순간 튀는 모양 있는 조각 한 묶음(픽셀 그림판 _fxp에 붙인다). 카드마다 모양이 달라 무엇을 썼는지 손끝으로 느끼게:
# feather 깃털 결 · chunk 돌조각(떨어짐) · shard 유리 파편(돌며 날아감) · drop 물방울 · ember 불티(솟음·깜빡) · note 음표(통통 떠오름) ·
# rune 마름모 룬(돌며 퍼짐) · heart 하트 · star 반짝 별

const LIFE := {"feather": 0.45, "chunk": 0.7, "shard": 0.5, "drop": 0.6, "ember": 0.9, "note": 1.0, "rune": 0.7, "heart": 0.9, "star": 0.45}
const C_CORE := Color("#fff8e8")
const C_EDGE := Color("#1a1220")

var shape := ""
var _p: Array = []
var _t := 0.0
var _life := 0.5


static func spawn(parent: Node, shape_: String, at: Vector2, dir: Vector2, count: int, colors: Array, power := 1.0) -> P2HitBits:
	parent = P2Vfx.pen_for(parent, false)
	var b := P2HitBits.new()
	b.shape = shape_
	b.position = at
	b._life = float(LIFE.get(shape_, 0.5))
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	for i in range(count):
		var q := {"pos": Vector2(randf_range(-8, 8), randf_range(-12, 12)), "rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
			"c": colors[randi() % colors.size()], "s": randf_range(1.0, 1.6) * power, "life": b._life * randf_range(0.65, 1.0), "seed": randf() * 10.0}
		var a := d.angle()
		match shape_:
			"chunk":
				a = -PI / 2.0 + randf_range(-1.1, 1.1) + d.x * 0.4
				q.vel = Vector2.RIGHT.rotated(a) * randf_range(220.0, 460.0) * power
				q.g = 1300.0
				q.drag = 0.5
			"ember":
				q.vel = Vector2(randf_range(-60.0, 60.0), randf_range(-260.0, -120.0)) * power
				q.g = -120.0
				q.drag = 0.3
			"note", "heart":
				a = -PI / 2.0 + randf_range(-1.25, 1.25)
				q.vel = Vector2.RIGHT.rotated(a) * randf_range(140.0, 330.0) * power
				q.g = 220.0
				q.drag = 0.08
			"rune", "star":
				a = randf() * TAU
				q.vel = Vector2.RIGHT.rotated(a) * randf_range(120.0, 320.0) * power
				q.g = 0.0
				q.drag = 0.04
			"drop":
				a = -PI / 2.0 + randf_range(-1.3, 1.3)
				q.vel = Vector2.RIGHT.rotated(a) * randf_range(200.0, 420.0) * power
				q.g = 1100.0
				q.drag = 0.4
			_:
				a += randf_range(-0.55, 0.55)
				q.vel = Vector2.RIGHT.rotated(a) * randf_range(320.0, 700.0) * power
				q.g = 260.0 if shape_ == "shard" else 80.0
				q.drag = 0.05 if shape_ == "shard" else 0.02
		b._p.append(q)
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	for q in _p:
		q.vel = (q.vel as Vector2) * pow(float(q.drag), delta) + Vector2(0, float(q.g) * delta)
		q.pos = (q.pos as Vector2) + (q.vel as Vector2) * delta
		q.rot = float(q.rot) + float(q.spin) * delta
	if _t > _life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for pass_ in [0, 1]:
		for q in _p:
			var u := clampf(_t / float(q.life), 0.0, 1.0)
			if u < 1.0:
				_draw_bit(q, 1.0 - u * u, u, pass_ == 0)


# 하얗게 번쩍이는 몸 위에서도 보이게 먼저 어두운 테두리(한 칸 크게)를 깔고 그 위에 색
func _draw_bit(q: Dictionary, a: float, u: float, edge: bool) -> void:
	var g := 2.0 if edge else 0.0
	var c: Color = Color(C_EDGE, a * 0.85) if edge else Color(q.c, a)
	var core := Color(C_CORE, a)
	var p: Vector2 = (q.pos as Vector2).round()
	var s := float(q.s)
	match shape:
		"feather":
			var v := (q.vel as Vector2).normalized()
			draw_line(p - v * (10.0 * s + g), p + v * (6.0 * s + g), c, P2Pixel.w(3.0 + g * 2.0), false)
			if not edge:
				draw_line(p - v * 4.0 * s, p + v * 2.0 * s, core, P2Pixel.w(2.0), false)
		"chunk":
			var r := 4.0 * s
			draw_colored_polygon(_poly(p, r + g, float(q.rot), 4), c)
			if not edge:
				draw_rect(Rect2(p - Vector2(1, 1) - Vector2(r * 0.3, r * 0.3), Vector2(2, 2)), Color(C_CORE, a * 0.6))
		"shard":
			var d := Vector2.RIGHT.rotated(float(q.rot))
			var n := d.orthogonal()
			draw_colored_polygon(PackedVector2Array([p + d * (9.0 * s + g), p + n * (3.0 * s + g), p - d * (5.0 * s + g), p - n * (2.0 * s + g)]), c)
			if not edge:
				draw_line(p - d * 3.0 * s, p + d * 6.0 * s, core, P2Pixel.w(2.0), false)
		"drop":
			var r2 := 3.5 * s
			draw_circle(p, r2 + g, c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r2 - g, -0.5), p + Vector2(r2 + g, -0.5), p - (q.vel as Vector2).normalized() * (r2 * 2.6 + g)]), c)
			if not edge:
				draw_rect(Rect2(p + Vector2(-1, -2), Vector2(2, 2)), core)
		"ember":
			var flick := 0.6 + 0.4 * sin(_t * 30.0 + float(q.seed) * 7.0)
			var e := 3.0 * s + g * 2.0
			draw_rect(Rect2(p - Vector2(e, e) / 2.0, Vector2(e, e)), Color(c, c.a * flick))
			if not edge:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(C_CORE, a * flick))
		"note":
			var k := 1.0 + 0.25 * sin(clampf(u * 6.0, 0.0, PI))
			var h := 6.0 * s * k
			var tilt := sin(_t * 6.0 + float(q.seed)) * 0.3
			var st := Vector2(h * 0.9, 0).rotated(tilt)
			var top := p + st + Vector2(0, -h * 2.6).rotated(tilt)
			draw_circle(p, h * 0.6 + g, c)
			draw_line(p + st, top, c, P2Pixel.w(3.0 + g * 2.0), false)
			draw_line(top, p + st + Vector2(h * 1.4, -h * 1.7).rotated(tilt), c, P2Pixel.w(3.0 + g * 2.0), false)
			if not edge:
				draw_circle(p + Vector2(-h * 0.2, -h * 0.2), h * 0.18, core)
		"rune":
			var r3 := 5.0 * s
			draw_colored_polygon(_poly(p, r3 + g, float(q.rot), 4), Color(c, c.a * (1.0 if edge else 0.85)))
			if not edge:
				draw_colored_polygon(_poly(p, r3 * 0.45, float(q.rot), 4), core)
		"heart":
			var hs := 5.0 * s
			draw_circle(p + Vector2(-hs * 0.5, -hs * 0.25), hs * 0.58 + g, c)
			draw_circle(p + Vector2(hs * 0.5, -hs * 0.25), hs * 0.58 + g, c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-hs * 1.05 - g, 0), p + Vector2(hs * 1.05 + g, 0), p + Vector2(0, hs * 1.15 + g)]), c)
		"star":
			var tw := (0.5 + 0.5 * sin(_t * 24.0 + float(q.seed) * 5.0)) * 7.0 * s + g
			draw_line(p - Vector2(tw, 0), p + Vector2(tw, 0), c, P2Pixel.w(2.0 + g * 2.0), false)
			draw_line(p - Vector2(0, tw), p + Vector2(0, tw), c, P2Pixel.w(2.0 + g * 2.0), false)
			if not edge:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), core)


func _poly(c: Vector2, r: float, rot: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		pts.append(c + Vector2.RIGHT.rotated(rot + TAU * i / n) * r)
	return pts
