class_name P2SkillFx
extends Node2D

# 카드 고유 연출 한 번(끝나면 사라짐). 전투 화면 픽셀 그림판(_fxp)에 세계 좌표로 붙인다.
# slash 난무 한 줄 · streak 그은 방향으로 몸을 뚫고 지나가는 잔광 · shock 충격파 · needle 관통 바늘 · puff 툭 · sigil 마법진 ·
# vortex 물 소용돌이 · dust 발밑 먼지 · charge 힘 모으기(문양을 긋는 동안 점마다 기운이 모임, release로 터짐)

const LIFE := {"slash": 0.26, "streak": 0.16, "shock": 0.42, "needle": 0.34, "puff": 0.24, "sigil": 0.62, "vortex": 0.7, "dust": 0.5,
	"charge": 99.0, "burst": 0.32, "fade": 0.2, "target": 0.42, "flame": 0.55, "notes": 0.6, "heal": 0.8,
	"crack": 1.1, "scorch": 1.4, "ripple": 1.0, "quake": 0.85, "rain": 0.32, "chain": 0.5, "ward": 0.6}
const C_CORE := Color("#fff8e8")

var kind := ""
var dir := Vector2.RIGHT
var size := 1.0
var color := Color.WHITE
var level := 0.0
var life := 0.4
var _t := 0.0
var _seed := 0.0
var _threads: Array = []


static func spawn(parent: Node, kind_: String, at: Vector2, dir_ := Vector2.RIGHT, size_ := 1.0, color_ := Color.WHITE) -> P2SkillFx:
	parent = P2Vfx.pen_for(parent, false)
	var f := P2SkillFx.new()
	f.kind = kind_
	f.position = at
	f.dir = dir_.normalized() if dir_ != Vector2.ZERO else Vector2.RIGHT
	f.size = size_
	f.color = color_
	f.life = float(LIFE.get(kind_, 0.4))
	f._seed = randf() * 100.0
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


# 힘 모으기: 그 점(이 노드 기준 자리)에서 몸으로 기운 한 줄
func add_thread(from: Vector2) -> void:
	_threads.append({"p": from, "t": _t})


func release(ok: bool) -> void:
	kind = "burst" if ok else "fade"
	_t = 0.0
	life = float(LIFE[kind])


func _draw() -> void:
	var u := clampf(_t / life, 0.0, 1.0)
	var fade := 1.0 - u
	match kind:
		"slash":
			var grow := clampf(u / 0.25, 0.0, 1.0)
			var l := 150.0 * size
			var a := -dir * l
			var b := a.lerp(dir * l, grow)
			var w := lerpf(8.0, 2.0, u)
			draw_line(a, b, Color(color, 0.55 * fade), P2Pixel.w(w + 4.0), false)
			draw_line(a, b, Color(C_CORE, fade), P2Pixel.w(w), false)
			draw_rect(Rect2(b - Vector2(4, 4), Vector2(8, 8)), Color(Color.WHITE, fade))
		"streak":
			var a := -dir * 70.0 * size
			var b := dir * (70.0 + 230.0 * clampf(u * 3.0, 0.0, 1.0)) * size
			draw_line(a, b, Color(color, 0.5 * fade), P2Pixel.w(8.0 * size), false)
			draw_line(a, b, Color(C_CORE, 0.95 * fade), P2Pixel.w(3.0), false)
		"shock":
			for k in range(3):
				var uk := clampf(u * 1.4 - k * 0.2, 0.0, 1.0)
				if uk <= 0.0 or uk >= 1.0:
					continue
				var ry := lerpf(24.0, 96.0, 1.0 - pow(1.0 - uk, 2.0)) * size
				_ellipse(dir * lerpf(0.0, 120.0, uk) * size, ry * 0.34, ry, Color(color.lerp(C_CORE, 0.4), (1.0 - uk) * 0.9), lerpf(8.0, 2.0, uk))
			for k in range(7):
				var d := dir.rotated((k - 3) * 0.32)
				draw_line(d * (30.0 + 70.0 * u) * size, d * (60.0 + 130.0 * u) * size, Color(C_CORE, fade), P2Pixel.w(3.0), false)
		"needle":
			var a := -dir * 130.0 * size
			var b := dir * 280.0 * size
			draw_line(a, b, Color(color, 0.45 * fade), P2Pixel.w(6.0), false)
			draw_line(a, b, Color(C_CORE, fade), P2Pixel.w(2.0), false)
			var g := sin(u * PI) * 22.0
			draw_line(b - Vector2(g, 0), b + Vector2(g, 0), Color(Color.WHITE, fade), P2Pixel.w(3.0), false)
			draw_line(b - Vector2(0, g), b + Vector2(0, g), Color(Color.WHITE, fade), P2Pixel.w(3.0), false)
		"puff":
			draw_arc(Vector2.ZERO, lerpf(10.0, 36.0, u) * size, 0.0, TAU, 20, Color(C_CORE, fade), P2Pixel.w(lerpf(5.0, 2.0, u)), false)
			for k in range(4):
				var d := Vector2.RIGHT.rotated(TAU * (k + 0.5) / 4.0 + _seed)
				draw_line(d * 20.0 * u, d * (14.0 + 26.0 * u), Color(color, fade), P2Pixel.w(3.0), false)
		"sigil":
			var appear := clampf(u / 0.22, 0.0, 1.0)
			var k := 1.0 - pow(1.0 - appear, 3.0) + sin(appear * PI) * 0.12
			var boom := clampf((u - 0.72) / 0.28, 0.0, 1.0)
			var r := 92.0 * size * k * (1.0 + boom * 0.6)
			var a := (1.0 - boom)
			var spin := _t * 2.4
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 0.9 * a), P2Pixel.w(4.0), false)
			draw_arc(Vector2.ZERO, r * 0.74, 0.0, TAU, 40, Color(C_CORE, 0.7 * a), P2Pixel.w(2.0), false)
			for tri in range(2):
				var pts := PackedVector2Array()
				for j in range(4):
					pts.append(Vector2.RIGHT.rotated(-PI / 2.0 + TAU * j / 3.0 + tri * PI / 3.0 + spin * (1.0 if tri == 0 else -1.0)) * r * 0.72)
				draw_polyline(pts, Color(color.lerp(C_CORE, 0.3), 0.85 * a), P2Pixel.w(2.0), false)
			for j in range(6):
				var q := Vector2.RIGHT.rotated(TAU * j / 6.0 - spin * 0.6) * r * 0.87
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(5, 0), q + Vector2(0, 7), q + Vector2(-5, 0)]), Color(C_CORE, a))
			if boom > 0.0:
				draw_circle(Vector2.ZERO, r * 0.6 * (1.0 - boom), Color(Color.WHITE, 0.6 * (1.0 - boom)))
		"vortex":
			var shrink := 1.0 - u * 0.7
			for arm in range(3):
				for j in range(12):
					var ang := TAU * arm / 3.0 + j * 0.42 + _t * 9.0
					var rad := 110.0 * size * (1.0 - j / 13.0) * shrink
					var q := Vector2(cos(ang), sin(ang) * 0.55) * rad
					var s := 6.0 - j * 0.35
					draw_rect(Rect2(q - Vector2(s, s) / 2.0, Vector2(s, s)), Color(color.lerp(C_CORE, j / 12.0), (0.9 - j * 0.04) * clampf(fade * 1.6, 0.0, 1.0)))
			if u > 0.72:
				var su := (u - 0.72) / 0.28
				_ellipse(Vector2.ZERO, lerpf(20.0, 140.0, su) * size, lerpf(8.0, 50.0, su) * size, Color(C_CORE, 1.0 - su), 4.0)
		"dust":
			for k in range(6):
				var sx := (k - 2.5) * 14.0 - dir.x * 30.0 * u
				var rise := -18.0 * u - (k % 2) * 6.0 * u
				var r := (6.0 + 10.0 * u) * size * (0.8 + (k % 3) * 0.15)
				draw_circle(Vector2(sx, rise), r, Color(Color("#b8ad9e"), 0.5 * fade))
		"charge":
			var r := (34.0 + 24.0 * level) * size
			var pulse := 0.5 + 0.5 * sin(_t * 20.0)
			var hot := color.lerp(C_CORE, 0.45)
			draw_circle(Vector2.ZERO, r * (0.92 + 0.08 * pulse), Color(color, 0.22 + 0.3 * level))
			for j in range(3 + int(level * 8.0)):
				var x := sin(j * 12.9898 + _seed) * r * 0.85
				var cyc := fmod(_t * (1.3 + level * 1.4) + j * 0.37, 1.0)
				var y := r * 0.8 - cyc * r * 2.4
				draw_line(Vector2(x, y), Vector2(x, y + 12.0 + 18.0 * level), Color(hot, 1.0 - cyc * cyc), P2Pixel.w(6.0), false)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, color, P2Pixel.w(6.0 + 6.0 * level), false)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(C_CORE, 0.5 + 0.5 * pulse), P2Pixel.w(2.0 + 2.0 * level), false)
			var n := 4 + int(level * 8.0)
			for j in range(n):
				var q := Vector2.RIGHT.rotated(TAU * j / n + _t * (3.0 + level * 6.0)) * r * (1.12 + 0.1 * sin(_t * 7.0 + j))
				draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), color)
				draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), C_CORE)
			for th in _threads:
				var tu := clampf((_t - float(th.t)) / 0.2, 0.0, 1.0)
				if tu >= 1.0:
					continue
				var from: Vector2 = th.p
				var head := from.lerp(Vector2.ZERO, tu * tu)
				var tail := from.lerp(Vector2.ZERO, maxf(0.0, tu * tu - 0.3))
				draw_line(tail, head, color, P2Pixel.w(8.0), false)
				draw_line(tail, head, C_CORE, P2Pixel.w(2.0), false)
				draw_rect(Rect2(head - Vector2(6, 6), Vector2(12, 12)), C_CORE)
		"burst":
			draw_circle(Vector2.ZERO, 64.0 * size * fade, Color(color, 0.5 * fade))
			draw_circle(Vector2.ZERO, 30.0 * size * fade * fade, Color(C_CORE, fade))
			draw_arc(Vector2.ZERO, lerpf(40.0, 140.0, u) * size, 0.0, TAU, 40, Color(C_CORE, fade), P2Pixel.w(lerpf(12.0, 2.0, u)), false)
			for j in range(10):
				var d := Vector2.RIGHT.rotated(TAU * j / 10.0 + _seed)
				draw_line(d * 40.0 * (1.0 + u), d * (60.0 + 110.0 * u), Color(color.lerp(C_CORE, 0.5), fade), P2Pixel.w(3.0), false)
		"fade":
			draw_arc(Vector2.ZERO, 30.0 * size, 0.0, TAU, 28, Color(color, 0.4 * fade), P2Pixel.w(2.0), false)
		"target":
			var k := clampf(u / 0.6, 0.0, 1.0)
			var r := lerpf(96.0, 14.0, 1.0 - pow(1.0 - k, 2.0)) * size
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color, fade), P2Pixel.w(4.0), false)
			for j in range(4):
				var d := Vector2.RIGHT.rotated(TAU * j / 4.0 + PI / 4.0 * (1.0 - k))
				draw_line(d * (r + 4.0), d * (r + 24.0), Color(C_CORE, fade), P2Pixel.w(4.0), false)
			if u > 0.6:
				var f := (u - 0.6) / 0.4
				draw_circle(Vector2.ZERO, (40.0 * (1.0 - f) + 6.0) * size, Color(Color.WHITE, 1.0 - f))
		"flame":
			for j in range(7):
				var x := (j - 3) * 15.0 * size + sin(_t * 22.0 + j * 1.3) * 4.0
				var h := (46.0 + 30.0 * sin(j * 1.7 + _seed)) * size * (0.35 + u) * fade
				var w := 9.0 * size
				draw_colored_polygon(PackedVector2Array([Vector2(x - w, 10.0), Vector2(x + w, 10.0), Vector2(x, 10.0 - h)]), Color(color, 0.85 * fade))
				draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.45, 10.0), Vector2(x + w * 0.45, 10.0), Vector2(x, 10.0 - h * 0.6)]), Color(C_CORE, fade))
		"notes":
			for j in range(5):
				var d := Vector2.RIGHT.rotated(-PI * 0.85 + PI * 0.7 * j / 4.0 + sin(_seed + j) * 0.1)
				var q := d * (24.0 + 130.0 * (1.0 - pow(1.0 - u, 2.0))) * size + Vector2(0, sin(_t * 14.0 + j) * 4.0)
				var col := Color(color.lerp(C_CORE, 0.3 * (j % 2)), fade)
				draw_circle(q, 6.0 * size, col)
				draw_line(q + Vector2(5.0, 0) * size, q + Vector2(5.0, -20.0) * size, col, P2Pixel.w(3.0), false)
				draw_line(q + Vector2(5.0, -20.0) * size, q + Vector2(13.0, -13.0) * size, col, P2Pixel.w(3.0), false)
		"crack":
			var grow := clampf(u / 0.12, 0.0, 1.0)
			var a := clampf(1.6 * fade, 0.0, 1.0)
			for j in range(7):
				var ang := PI + PI * (j + 0.5) / 7.0 + sin(_seed + j) * 0.18
				var p0 := Vector2.ZERO
				var len := (34.0 + 26.0 * sin(_seed * 2.0 + j)) * size * grow
				for seg in range(3):
					var p1 := p0 + Vector2(cos(ang + sin(_seed + j * 3 + seg) * 0.5), sin(ang) * 0.32) * len / 3.0
					draw_line(p0, p1, Color(0.08, 0.05, 0.04, 0.85 * a), P2Pixel.w(3.0), false)
					draw_line(p0 + Vector2(0, -2), p1 + Vector2(0, -2), Color(color.lerp(C_CORE, 0.5), 0.5 * a * (1.0 - u)), P2Pixel.w(2.0), false)
					p0 = p1
		"scorch":
			var a := clampf(1.4 * fade, 0.0, 1.0)
			_ellipse_fill(Vector2.ZERO, 54.0 * size, 14.0 * size, Color(0.06, 0.03, 0.02, 0.6 * a))
			for j in range(6):
				var x := (j - 2.5) * 16.0 * size
				var y := -fmod(_t * 40.0 + j * 13.0, 30.0)
				draw_rect(Rect2(Vector2(x, y) - Vector2(2, 2), Vector2(4, 4)), Color(color.lerp(C_CORE, 0.3 * (j % 2)), a * (1.0 + y / 30.0)))
		"ripple":
			for j in range(3):
				var uj := clampf(u * 1.5 - j * 0.25, 0.0, 1.0)
				if uj <= 0.0 or uj >= 1.0:
					continue
				_ellipse(Vector2.ZERO, lerpf(16.0, 120.0, uj) * size, lerpf(5.0, 30.0, uj) * size, Color(color.lerp(C_CORE, 0.5), (1.0 - uj) * 0.8), 3.0)
		"quake":
			# 방패 내려찍기: 발밑에서 땅이 넓게 갈라지고(빛나는 금) 고리 셋이 바닥을 따라 퍼지며 양옆으로 흙먼지
			var a := clampf(1.5 * fade, 0.0, 1.0)
			for j in range(3):
				var uj := clampf(u * 1.6 - j * 0.18, 0.0, 1.0)
				if uj <= 0.0 or uj >= 1.0:
					continue
				_ellipse(Vector2.ZERO, lerpf(30.0, 300.0, 1.0 - pow(1.0 - uj, 2.0)) * size, lerpf(8.0, 52.0, uj) * size, Color(color.lerp(C_CORE, 0.5), (1.0 - uj) * 0.95), lerpf(10.0, 2.0, uj))
			var grow := clampf(u / 0.1, 0.0, 1.0)
			for j in range(10):
				var side := -1.0 if j % 2 == 0 else 1.0
				var ang := (0.08 + 0.13 * (j / 2)) * side
				var p0 := Vector2.ZERO
				var len := (90.0 + 60.0 * sin(_seed + j * 1.7)) * size * grow
				for seg in range(4):
					var step := Vector2(side * cos(ang + sin(_seed + j * 5 + seg) * 0.35), sin(ang) * 0.3 + 0.05 * sin(seg + _seed)) * len / 4.0
					var p1 := p0 + step
					draw_line(p0, p1, Color(0.06, 0.04, 0.03, 0.9 * a), P2Pixel.w(4.0), false)
					draw_line(p0 + Vector2(0, -2), p1 + Vector2(0, -2), Color(color.lerp(C_CORE, 0.6), a * (1.0 - u)), P2Pixel.w(2.0), false)
					p0 = p1
			for j in range(8):
				var side2 := -1.0 if j % 2 == 0 else 1.0
				var dx := side2 * (40.0 + 26.0 * (j / 2)) * size * (0.4 + u)
				var r := (14.0 + 10.0 * u) * size * (0.8 + (j % 3) * 0.2)
				draw_circle(Vector2(dx, -10.0 - 40.0 * u - (j % 3) * 8.0), r, Color(Color("#b8ad9e"), 0.55 * fade))
			if u < 0.25:
				draw_circle(Vector2(0, -20), 70.0 * size * (1.0 - u * 4.0), Color(C_CORE, 0.7 * (1.0 - u * 4.0)))
		"rain":
			# 화살비: 위에서 비스듬히 꽂히는 화살 한 대(깃 · 촉) + 꽂히는 순간 작은 먼지
			var fall := clampf(u / 0.5, 0.0, 1.0)
			var d := Vector2(0.32, 1.0).normalized()
			var tip := -d * 420.0 * (1.0 - fall * fall * (3.0 - 2.0 * fall))
			var tail := tip - d * 130.0 * size
			var a := fade if fall >= 1.0 else 1.0
			draw_line(tail - d * 60.0, tail, Color(color, 0.25 * a), P2Pixel.w(4.0), false)
			draw_line(tail, tip, Color(color, 0.7 * a), P2Pixel.w(8.0), false)
			draw_line(tail, tip, Color(C_CORE, a), P2Pixel.w(3.0), false)
			var n := d.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip + d * 18.0, tip + n * 9.0, tip - n * 9.0]), Color(C_CORE, a))
			draw_line(tail, tail - d * 20.0 + n * 11.0, Color(color, a), P2Pixel.w(3.0), false)
			draw_line(tail, tail - d * 20.0 - n * 11.0, Color(color, a), P2Pixel.w(3.0), false)
			if fall >= 1.0:
				var su := (u - 0.5) / 0.5
				draw_arc(Vector2.ZERO, lerpf(8.0, 46.0, su) * size, 0.0, TAU, 16, Color(C_CORE, 1.0 - su), P2Pixel.w(4.0), false)
				for j in range(4):
					var sd := Vector2.RIGHT.rotated(-PI / 2.0 + (j - 1.5) * 0.6)
					draw_line(sd * 10.0, sd * (14.0 + 26.0 * su), Color(color, 1.0 - su), P2Pixel.w(3.0), false)
		"chain":
			# 연쇄 폭발: 표식 고리가 번쩍 조였다가 터지며 번개 가지가 사방으로
			var k := clampf(u / 0.3, 0.0, 1.0)
			var r := lerpf(110.0, 34.0, 1.0 - pow(1.0 - k, 2.0)) * size
			var boom := clampf((u - 0.3) / 0.7, 0.0, 1.0)
			if boom <= 0.0:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.95), P2Pixel.w(5.0), false)
				for j in range(6):
					var q := Vector2.RIGHT.rotated(TAU * j / 6.0 + _t * 8.0) * r
					draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(6, 0), q + Vector2(0, 7), q + Vector2(-6, 0)]), C_CORE)
			else:
				draw_circle(Vector2.ZERO, 70.0 * size * (1.0 - boom), Color(C_CORE, 0.8 * (1.0 - boom)))
				draw_arc(Vector2.ZERO, lerpf(40.0, 170.0, boom) * size, 0.0, TAU, 40, Color(color, 1.0 - boom), P2Pixel.w(lerpf(10.0, 2.0, boom)), false)
				for j in range(7):
					var dir2 := Vector2.RIGHT.rotated(TAU * j / 7.0 + _seed)
					var p0 := dir2 * 30.0 * size
					for seg in range(4):
						var p1 := p0 + dir2.rotated(sin(_seed * 3.0 + j * 7 + seg * 2) * 0.7) * (26.0 + 30.0 * boom) * size
						draw_line(p0, p1, Color(Color("#bfe8ff"), 1.0 - boom), P2Pixel.w(3.0), false)
						p0 = p1
		"ward":
			# 방어: 몸 앞에 육각 방패막이 탁 펼쳐졌다가(살짝 넘침) 빛이 훑고 지나가며 옅어진다
			var open := clampf(u / 0.16, 0.0, 1.0)
			var k := 1.0 - pow(1.0 - open, 3.0) + sin(open * PI) * 0.1
			var rx := 74.0 * size * k
			var ry := 104.0 * size * k
			var a := clampf(1.4 * fade, 0.0, 1.0)
			var pts := PackedVector2Array()
			for j in range(7):
				var ang := -PI / 2.0 + TAU * j / 6.0
				pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
			draw_colored_polygon(pts.slice(0, 6), Color(color, 0.16 * a))
			draw_polyline(pts, Color(color, 0.9 * a), P2Pixel.w(4.0), false)
			draw_polyline(pts, Color(C_CORE, 0.6 * a), P2Pixel.w(2.0), false)
			for j in range(6):
				draw_line(Vector2.ZERO, pts[j] * 0.5, Color(color, 0.35 * a), P2Pixel.w(2.0), false)
			var sweep := lerpf(-ry, ry, clampf((u - 0.12) / 0.4, 0.0, 1.0))
			var half := rx * sqrt(maxf(0.0, 1.0 - pow(sweep / maxf(ry, 1.0), 2.0)))
			draw_line(Vector2(-half, sweep), Vector2(half, sweep), Color(C_CORE, 0.8 * a), P2Pixel.w(3.0), false)
		"heal":
			var ring := clampf(u / 0.5, 0.0, 1.0)
			_ellipse(Vector2(0, 40.0), lerpf(20.0, 110.0, ring) * size, lerpf(6.0, 30.0, ring) * size, Color(Color("#8be08b"), 1.0 - ring), 4.0)
			for j in range(7):
				var rise := clampf((u - j * 0.06) / 0.7, 0.0, 1.0)
				if rise <= 0.0 or rise >= 1.0:
					continue
				var hx := (j - 3) * 22.0 * size + sin(_t * 6.0 + j) * 6.0
				var hy := 30.0 - rise * 150.0 * size
				_heart(Vector2(hx, hy), (7.0 + (j % 3) * 2.0) * size, Color(color.lerp(C_CORE, 0.2 * (j % 2)), 1.0 - rise * rise))


func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.5, -s * 0.25), s * 0.58, col)
	draw_circle(c + Vector2(s * 0.5, -s * 0.25), s * 0.58, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.05, 0.0), c + Vector2(s * 1.05, 0.0), c + Vector2(0.0, s * 1.15)]), col)


func _ellipse_fill(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(24):
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in range(33):
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, P2Pixel.w(w), false)
