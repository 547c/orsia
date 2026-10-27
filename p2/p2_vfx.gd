class_name P2Vfx
extends Node2D

# 원소·필살 연출 한 번(매끈한 선·빛, 픽셀 그림판 밖 세계 층 _fx에 붙인다). life가 0 아래면 직접 지울 때까지 남는다(모으기 구슬).
# 빛 계열은 더하기 섞기로 겹칠수록 밝게. opts: to(끝 자리) · size · color · dir · level · seed

const LIFE := {"fire_burst": 0.95, "frost_burst": 0.75, "ice_form": 0.32, "spear_tele": 0.2, "spear_hit": 0.55, "rift_burst": 0.9,
	"wind": 0.65, "poison_puff": 1.3, "muzzle": 0.09, "streak": 0.16, "beam": 0.6, "charge_orb": -1.0, "crosshair": 0.7,
	"trap_snap": 0.45, "skull": 1.0, "shout": 0.8, "wall_rise": 0.5, "fist": 0.22, "eye": 2.6, "giant_shield": 0.55,
	"orbs5": 1.1, "arrow_sky": 2.3, "flash": 0.18, "embers": 1.2, "shatter_shards": 0.9, "light_pillar": 0.7, "react_text": 1.1,
	"missile": 0.2, "freeze_form": 0.45, "crack_ring": 0.5, "fire_pillar": 0.95, "spin_shield": -1.0, "chains": 0.95, "aura": 1.1, "smoke": 1.8,
	"hourglass": 1.3, "trap_set": 0.7, "uplift": 0.55, "down_arrows": 0.9, "chain_line": 0.9, "counter": -1.0,
	"cut_line": 0.2, "shield_pop": 0.32, "crescent": 0.34, "card_burn": 0.55, "card_fly": 0.36}
const ADD := ["spear_tele", "spear_hit", "muzzle", "beam", "charge_orb", "flash", "light_pillar", "orbs5", "streak", "uplift", "cut_line", "crescent"]
const C_CORE := Color("#fffaf0")
# 손으로 그린 효과처럼 초당 15장으로 끊어 그린다(움직이는 위치는 매끈하게) · 글자는 픽셀 그림판에 보내지 않는다
const FPS := 15.0
const TEXT_KINDS := ["react_text", "counter"]
# 세계 층(그 노드) → 픽셀 그림판 둘(보통 · 빛 더하기). 등록된 층에 붙이면 알맞은 그림판으로 간다
static var pens := {}

var kind := ""
var to := Vector2.ZERO
var size := 1.0
var color := Color.WHITE
var dir := Vector2.RIGHT
var level := 0.0
var text := ""
var style := ""
var arc_h := 0.0
var life := 0.5
var _from := Vector2.ZERO
var _trail: Array = []
var _t := 0.0
var _seed := 0.0
var _parts: Array = []
var _font: Font
var _pop_t := -9.0
var _boil := 0
var _end_t := -1.0


static func route(host: Node, normal: Node, add: Node) -> void:
	pens[host.get_instance_id()] = {"n": normal, "a": add}


static func pen_for(parent: Node, add: bool) -> Node:
	var key := parent.get_instance_id()
	if pens.has(key):
		var pr: Dictionary = pens[key]
		var to_pen: Node = pr.a if add else pr.n
		if is_instance_valid(to_pen):
			return to_pen
	return parent


static func spawn(parent: Node, kind_: String, at: Vector2, opts := {}) -> P2Vfx:
	if not TEXT_KINDS.has(kind_):
		parent = pen_for(parent, ADD.has(kind_))
	var f := P2Vfx.new()
	f.kind = kind_
	f.position = at
	f.to = opts.get("to", at)
	f.size = float(opts.get("size", 1.0))
	f.color = opts.get("color", Color.WHITE)
	f.dir = (opts.get("dir", Vector2.RIGHT) as Vector2).normalized()
	f.level = float(opts.get("level", 0.0))
	f.text = String(opts.get("text", ""))
	f.style = String(opts.get("style", ""))
	f.arc_h = float(opts.get("arc", 0.0))
	f._from = at
	f.life = float(opts.get("life", LIFE.get(kind_, 0.5)))
	f._seed = randf() * 100.0
	if ADD.has(kind_):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		f.material = m
	f._prepare()
	parent.add_child(f)
	return f


func _prepare() -> void:
	match kind:
		"fire_burst", "embers":
			for i in range(26 if kind == "fire_burst" else 18):
				var a := randf() * TAU
				_parts.append({"p": Vector2.ZERO, "v": Vector2.RIGHT.rotated(a) * randf_range(120.0, 420.0) * size + Vector2(0, -80), "s": randf_range(2.0, 5.0) * size, "l": randf_range(0.5, 1.0)})
		"frost_burst", "shatter_shards":
			var n := 10 if kind == "frost_burst" else 26
			for i in range(n):
				var a := TAU * i / n + randf_range(-0.2, 0.2)
				_parts.append({"p": Vector2.ZERO, "v": Vector2.RIGHT.rotated(a) * randf_range(260.0, 620.0) * size, "r": randf() * TAU, "w": randf_range(-12.0, 12.0),
					"s": randf_range(8.0, 22.0) * size, "g": 900.0 if kind == "shatter_shards" else 0.0})
		"ice_form":
			for i in range(7):
				_parts.append({"from": Vector2(randf_range(-120, 120), randf_range(-110, 60)) * size, "r": randf() * TAU, "k": i})
		"wind":
			for i in range(24):
				_parts.append({"y": randf_range(-140.0, 120.0) * size, "x": randf_range(-500.0, 100.0), "len": randf_range(80.0, 260.0), "sp": randf_range(1800.0, 2600.0), "w": randf_range(1.5, 4.0)})
			for i in range(10):
				_parts.append({"leaf": true, "p": Vector2(randf_range(-300, -60), randf_range(-120, 80)), "v": Vector2(randf_range(900, 1400), randf_range(-160, 120)), "r": randf() * TAU})
		"poison_puff":
			for i in range(9):
				_parts.append({"p": Vector2(randf_range(-70, 70), randf_range(-30, 20)) * size, "r": randf_range(26.0, 50.0) * size, "d": randf_range(0.0, 0.3)})
			for i in range(14):
				_parts.append({"bubble": true, "p": Vector2(randf_range(-80, 80), randf_range(-10, 30)) * size, "s": randf_range(3.0, 7.0), "d": randf_range(0.0, 0.8)})
		"skull":
			for i in range(14):
				var a2 := randf() * TAU
				_parts.append({"p": Vector2.ZERO, "v": Vector2.RIGHT.rotated(a2) * randf_range(80.0, 260.0), "s": randf_range(10.0, 26.0)})
		"arrow_sky":
			for i in range(280):
				_parts.append({"x": randf_range(-80.0, 1360.0), "y0": randf_range(-900.0, -60.0), "d": randf_range(0.0, 1.3), "sp": randf_range(1700.0, 2400.0), "land": randf_range(250.0, 470.0)})
		"freeze_form":
			for i in range(11):
				_parts.append({"x": randf_range(-60.0, 60.0) * size, "h": randf_range(40.0, 150.0) * size, "w": randf_range(10.0, 22.0) * size, "d": randf_range(0.0, 0.35), "tilt": randf_range(-0.4, 0.4)})
		"fire_pillar":
			for i in range(12):
				_parts.append({"x": randf_range(-30.0, 30.0) * size, "v": randf_range(180.0, 420.0), "d": randf_range(0.0, 0.5), "s": randf_range(2.0, 5.0)})
		"aura":
			for i in range(14):
				_parts.append({"a": TAU * i / 14.0 + randf_range(-0.2, 0.2), "h": randf_range(40.0, 90.0), "w": randf_range(8.0, 16.0), "ph": randf() * TAU})
			for i in range(16):
				_parts.append({"spark": true, "x": randf_range(-50.0, 50.0), "v": randf_range(60.0, 160.0), "d": randf_range(0.0, 0.6)})
		"smoke":
			for i in range(16):
				_parts.append({"p": Vector2(randf_range(-110, 110), randf_range(-90, 10)) * size, "r": randf_range(34.0, 70.0) * size, "d": randf_range(0.0, 0.25), "v": Vector2(randf_range(-40, 40), randf_range(-30, 0))})
		"chains":
			for j in range(3):
				for k in range(26):
					_parts.append({"loop": j, "k": k, "a": TAU * k / 26.0, "v": Vector2.RIGHT.rotated(TAU * k / 26.0 + randf_range(-0.3, 0.3)) * randf_range(160.0, 360.0), "w": randf_range(-14.0, 14.0)})
		"uplift":
			for i in range(18):
				_parts.append({"x": randf_range(-80.0, 80.0) * size, "y": randf_range(-40.0, 120.0), "len": randf_range(50.0, 150.0), "sp": randf_range(900.0, 1600.0)})
		"orbs5":
			for i in range(5):
				_parts.append({"c": [Color("#ff6a2a"), Color("#6fd0ff"), Color("#7fe0a0"), Color("#ffe27a"), Color("#a066ff")][i], "a": TAU * i / 5.0})


# 쌓이는 숫자(연타 합계): 바꿀 때마다 톡 튐. end()를 부르면 크게 한 번 튀고 사라진다
func bump(t: String) -> void:
	text = t
	_pop_t = _t


func end(after: float) -> void:
	_pop_t = _t
	_end_t = _t + after


func _process(delta: float) -> void:
	_t += delta
	if kind == "counter" and _end_t > 0.0 and _t >= _end_t:
		queue_free()
		return
	if kind == "spin_shield":
		_trail.push_front(global_position)
		if _trail.size() > 12:
			_trail.pop_back()
	if kind == "missile":
		var u := clampf(_t / life, 0.0, 1.0)
		var p := _from.lerp(to, u) + Vector2(0, -sin(u * PI) * arc_h)
		_trail.push_front(p)
		if _trail.size() > 14:
			_trail.pop_back()
		position = p
	if life > 0.0 and _t >= life:
		queue_free()
		return
	queue_redraw()


func _font_of() -> Font:
	if _font == null:
		_font = P2Ui.bold_font(48)
	return _font


func _draw() -> void:
	var real := _t
	_t = floorf(_t * FPS) / FPS
	_boil = int(_t * FPS)
	_draw_body()
	_t = real


func _draw_body() -> void:
	var u := clampf(_t / life, 0.0, 1.0) if life > 0.0 else 0.0
	var fade := 1.0 - u
	match kind:
		"flash":
			_glow(Vector2.ZERO, 90.0 * size * (0.6 + 0.4 * fade), Color(color, fade), 5)
		"fire_burst":
			_fire_burst(u, fade)
		"embers":
			for q in _parts:
				var lu := clampf(_t / (float(q.l) * life), 0.0, 1.0)
				if lu >= 1.0:
					continue
				var p: Vector2 = (q.p as Vector2) + (q.v as Vector2) * _t * 0.6 + Vector2(0, -60.0 * _t)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(Color("#ffb43c").lerp(Color("#ff4a1a"), lu), 1.0 - lu))
		"frost_burst":
			_ring(Vector2.ZERO, lerpf(20.0, 150.0, 1.0 - pow(fade, 2.0)) * size, Color("#e8fbff", fade), lerpf(10.0, 2.0, u))
			_glow(Vector2.ZERO, 70.0 * size * fade, Color("#9fe6ff", 0.5 * fade), 4)
			for q in _parts:
				var p: Vector2 = (q.v as Vector2) * _t * (1.0 - u * 0.5)
				_shard(p, float(q.s) * (1.0 - u * 0.6), float(q.r) + float(q.w) * _t, Color("#dff8ff", fade), Color("#6fc4ee", fade))
			for k in range(6):
				var mp := Vector2(cos(k * 1.1 + _seed) * 60.0, sin(k * 1.7) * 26.0 + 20.0) * size * (0.6 + u)
				draw_circle(mp, (18.0 + 26.0 * u) * size, Color(Color("#dff4ff"), 0.22 * fade))
		"shatter_shards":
			for q in _parts:
				var p: Vector2 = (q.v as Vector2) * _t + Vector2(0, 0.5 * float(q.g) * _t * _t)
				_shard(p, float(q.s), float(q.r) + float(q.w) * _t, Color("#f0fcff", fade), Color("#4fb3e8", fade))
		"ice_form":
			var k2 := clampf(u / 0.8, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k2, 3.0)
			for q in _parts:
				var home := dir * (float(q.k) - 3.0) * 14.0 * size
				var p: Vector2 = (q.from as Vector2).lerp(home, e)
				_shard(p, (12.0 + 6.0 * sin(float(q.k))) * size, lerpf(float(q.r), dir.angle(), e), Color("#f0fcff", 0.6 + 0.4 * e), Color("#5fbfee", 0.9))
			if u > 0.8:
				_glow(Vector2.ZERO, 60.0 * size, Color("#bff0ff", (u - 0.8) * 3.0), 3)
		"spear_tele":
			var flick := 0.55 + 0.45 * sin(_t * 90.0)
			draw_line(Vector2(0, -700), Vector2.ZERO, Color(color, 0.5 * flick), 2.0)
			draw_line(Vector2(0, -700), Vector2.ZERO, Color(C_CORE, 0.35 * flick), 1.0)
			_ring(Vector2(0, 0), 26.0 * size * (1.0 - u * 0.6), Color(color, 0.7 * flick), 2.0)
		"spear_hit":
			var k3 := clampf(u / 0.12, 0.0, 1.0)
			var tip := Vector2(0, lerpf(-760.0, 0.0, k3))
			if k3 < 1.0:
				draw_line(tip + Vector2(0, -260), tip, Color(color, 0.5), 16.0)
				draw_line(tip + Vector2(0, -260), tip, Color(C_CORE, 0.95), 5.0)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 26), tip + Vector2(-9, -6), tip + Vector2(9, -6)]), C_CORE)
			else:
				var h := clampf((u - 0.12) / 0.88, 0.0, 1.0)
				var w := lerpf(46.0, 4.0, h) * size
				draw_rect(Rect2(Vector2(-w / 2.0, -900.0), Vector2(w, 900.0)), Color(color, 0.45 * (1.0 - h)))
				draw_rect(Rect2(Vector2(-w / 6.0, -900.0), Vector2(w / 3.0, 900.0)), Color(C_CORE, 0.8 * (1.0 - h)))
				_glow(Vector2.ZERO, 80.0 * size * (1.0 - h * 0.5), Color(color, 0.8 * (1.0 - h)), 4)
				for j in range(8):
					var d := Vector2.RIGHT.rotated(TAU * j / 8.0 + _seed)
					draw_line(d * 20.0 * (1.0 + h * 3.0), d * (40.0 + 90.0 * h) * size, Color(C_CORE, 1.0 - h), 3.0)
		"light_pillar":
			var w2 := lerpf(70.0, 10.0, u) * size
			draw_rect(Rect2(Vector2(-w2 / 2.0, -900.0), Vector2(w2, 980.0)), Color(color, 0.35 * fade))
			draw_rect(Rect2(Vector2(-w2 / 8.0, -900.0), Vector2(w2 / 4.0, 980.0)), Color(C_CORE, 0.7 * fade))
		"rift_burst":
			_rift_burst(u, fade)
		"wind":
			for q in _parts:
				if q.has("leaf"):
					var lp: Vector2 = (q.p as Vector2) + (q.v as Vector2) * _t
					var lr := float(q.r) + _t * 14.0
					var lv := Vector2(7, 0).rotated(lr)
					draw_colored_polygon(PackedVector2Array([lp - lv, lp + lv.orthogonal() * 0.4, lp + lv, lp - lv.orthogonal() * 0.4]), Color(Color("#8fd08a"), fade))
					continue
				var x := float(q.x) + float(q.sp) * _t
				var a := clampf(1.0 - absf(x - 300.0) / 900.0, 0.0, 1.0) * fade
				draw_line(Vector2(x - float(q.len), float(q.y)), Vector2(x, float(q.y)), Color(Color("#e8fff4"), 0.55 * a), float(q.w))
		"poison_puff":
			for q in _parts:
				var lu2 := clampf((u - float(q.d)) / (1.0 - float(q.d)), 0.0, 1.0)
				if lu2 <= 0.0:
					continue
				if q.has("bubble"):
					var bp: Vector2 = (q.p as Vector2) + Vector2(sin(_t * 6.0 + float(q.s)) * 6.0, -120.0 * lu2)
					_ring(bp, float(q.s) * (1.0 + lu2), Color(Color("#b6ff7a"), 1.0 - lu2), 2.0)
					continue
				var cp: Vector2 = (q.p as Vector2) + Vector2(0, -50.0 * lu2)
				draw_circle(cp, float(q.r) * (0.6 + lu2 * 0.8), Color(Color("#5fa83a").lerp(Color("#9ad84a"), lu2), 0.45 * (1.0 - lu2)))
		"muzzle":
			_glow(Vector2.ZERO, 34.0 * size, Color(color, fade), 3)
			for j in range(4):
				var d2 := dir.rotated(TAU * j / 4.0)
				draw_line(Vector2.ZERO, d2 * (40.0 if j == 0 else 18.0) * size, Color(C_CORE, fade), 3.0)
		"streak":
			var end := to - position
			var fly := clampf(u / 0.55, 0.0, 1.0)
			if fly < 1.0:
				var head := end * fly
				var tail := end * maxf(0.0, fly - 0.4)
				var dn := end.normalized()
				draw_line(tail, head, Color(color, 0.35), 7.0)
				draw_line(tail, head, Color(color, 0.85), 3.0)
				draw_line(tail.lerp(head, 0.5), head, Color(C_CORE, 1.0), 1.6)
				draw_colored_polygon(PackedVector2Array([head + dn * 9.0, head - dn * 5.0 + dn.orthogonal() * 4.0, head - dn * 5.0 - dn.orthogonal() * 4.0]), C_CORE)
			else:
				var k := (u - 0.55) / 0.45
				_glow(end, 22.0 * (1.0 - k * 0.5), Color(color, 1.0 - k), 3)
				for j in range(5):
					var d := Vector2.RIGHT.rotated(TAU * j / 5.0 + _seed)
					draw_line(end + d * 4.0, end + d * (8.0 + 22.0 * k), Color(C_CORE, 1.0 - k), 2.0)
		"beam":
			_beam(u, fade)
		"charge_orb":
			_charge_orb()
		"crosshair":
			var k4 := clampf(u / 0.5, 0.0, 1.0)
			var r := lerpf(120.0, 34.0, 1.0 - pow(1.0 - k4, 3.0)) * size
			var rot := (1.0 - k4) * 2.4
			var c := Color(Color("#ff3a3a"), fade if u > 0.5 else 1.0)
			_ring(Vector2.ZERO, r, c, 3.0)
			_ring(Vector2.ZERO, r * 0.45, Color(c, c.a * 0.7), 2.0)
			for j in range(4):
				var d3 := Vector2.RIGHT.rotated(TAU * j / 4.0 + rot)
				draw_line(d3 * r * 0.7, d3 * r * 1.35, c, 4.0)
			draw_line(to - position, Vector2.ZERO, Color(Color("#ff5a4a"), 0.4 * c.a), 1.5)
		"trap_snap":
			var close := clampf(u / 0.18, 0.0, 1.0)
			var gap := lerpf(1.0, 0.0, close * close)
			_trap_jaws(Vector2.ZERO, gap, fade)
			if close >= 1.0:
				for j in range(10):
					var d4 := Vector2.RIGHT.rotated(-PI + PI * j / 9.0)
					draw_line(d4 * 12.0, d4 * (30.0 + 60.0 * (u - 0.18)), Color(Color("#ffe08a"), fade), 2.0)
		"skull":
			_skull(u, fade)
		"shout":
			for j in range(4):
				var uj := clampf(u * 1.4 - j * 0.15, 0.0, 1.0)
				if uj <= 0.0 or uj >= 1.0:
					continue
				_ring(Vector2.ZERO, lerpf(30.0, 520.0, 1.0 - pow(1.0 - uj, 2.0)) * size, Color(color.lerp(C_CORE, 0.3), (1.0 - uj) * 0.85), lerpf(14.0, 3.0, uj))
			for j in range(16):
				var d5 := Vector2.RIGHT.rotated(TAU * j / 16.0 + _seed)
				draw_line(d5 * (60.0 + 300.0 * u), d5 * (120.0 + 460.0 * u), Color(color, 0.6 * fade), 3.0)
		"wall_rise":
			_hex_wall(Vector2.ZERO, clampf(u / 0.6, 0.0, 1.0), 1.0, 0.0, size)
		"fist":
			var reach := clampf(u / 0.35, 0.0, 1.0)
			var p2 := dir * lerpf(-90.0, 0.0, reach) * size
			draw_line(p2 - dir * 70.0 * size, p2, Color(color, 0.5 * fade), 18.0 * size)
			draw_circle(p2, 16.0 * size, Color(C_CORE, fade))
			draw_circle(p2, 11.0 * size, Color(color, fade))
			if reach >= 1.0:
				_ring(p2, lerpf(14.0, 50.0, (u - 0.35) / 0.65) * size, Color(C_CORE, fade), 3.0)
		"eye":
			_eye(u)
		"giant_shield":
			var fall := clampf(u / 0.55, 0.0, 1.0)
			var s4 := 190.0 * size
			var y := lerpf(-560.0, 0.0, fall * fall) - s4 * 0.7
			var hold := 1.0 if u < 0.75 else clampf((1.0 - u) / 0.25, 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, maxf(1.0, s4 * 0.9 * fall), Color(0.02, 0.01, 0.0, 0.55 * fall * hold))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_glow(Vector2(0, y), s4 * 1.3, Color(Color("#ffe9a8"), 0.55 * hold), 5)
			_shield_shape(Vector2(0, y), s4, Color(color, 0.92 * hold), Color(C_CORE, hold))
			if fall < 1.0:
				for k in range(6):
					var lx := (k - 2.5) * s4 * 0.28
					draw_line(Vector2(lx, y - s4 * 0.7), Vector2(lx, y - s4 * 0.7 - 260.0), Color(Color("#fff3c8"), 0.35), 4.0)
		"orbs5":
			_orbs5(u)
		"arrow_sky":
			var sky := clampf(_t / 0.3, 0.0, 1.0) * clampf((life - _t) / 0.5, 0.0, 1.0)
			draw_polygon(PackedVector2Array([Vector2(-200, -200), Vector2(1500, -200), Vector2(1500, 320), Vector2(-200, 320)]),
				PackedColorArray([Color(0.02, 0.02, 0.06, 0.75 * sky), Color(0.02, 0.02, 0.06, 0.75 * sky), Color(0.02, 0.02, 0.06, 0.0), Color(0.02, 0.02, 0.06, 0.0)]))
			for q in _parts:
				var tt := _t - float(q.d)
				if tt < 0.0:
					continue
				var y2 := float(q.y0) + float(q.sp) * tt
				var land := float(q.land)
				var stuck := y2 >= land
				var head2 := Vector2(float(q.x) - position.x, minf(y2, land) - position.y)
				var dv := Vector2(0.28, 1.0).normalized()
				if stuck:
					var a3 := clampf(1.0 - (_t - float(q.d) - (land - float(q.y0)) / float(q.sp)) / 1.4, 0.0, 1.0)
					draw_line(head2 - dv * 30.0, head2, Color(Color("#c8b48a"), a3), 3.0)
					draw_line(head2 - dv * 30.0, head2 - dv * 22.0, Color(Color("#f0e6d0"), a3), 5.0)
				else:
					draw_line(head2 - dv * 110.0, head2, Color(color, 0.25), 9.0)
					draw_line(head2 - dv * 80.0, head2, Color(color, 0.9), 3.5)
					draw_line(head2 - dv * 34.0, head2, Color(C_CORE, 1.0), 2.0)
					draw_colored_polygon(PackedVector2Array([head2 + dv * 10.0, head2 - dv * 4.0 + dv.orthogonal() * 5.0, head2 - dv * 4.0 - dv.orthogonal() * 5.0]), C_CORE)
		"missile":
			_missile()
		"freeze_form":
			for q in _parts:
				var k5 := clampf((u - float(q.d)) / 0.4, 0.0, 1.0)
				if k5 <= 0.0:
					continue
				var hh := float(q.h) * (1.0 - pow(1.0 - k5, 3.0))
				var base := Vector2(float(q.x), 0)
				var tipp := base + Vector2(sin(float(q.tilt)) * hh, -hh)
				var ww := float(q.w)
				var poly := PackedVector2Array([base + Vector2(-ww / 2.0, 0), tipp, base + Vector2(ww / 2.0, 0)])
				draw_colored_polygon(poly, Color(0.62, 0.9, 1.0, 0.75))
				draw_colored_polygon(PackedVector2Array([base, tipp, base + Vector2(ww / 2.0, 0)]), Color(0.9, 0.98, 1.0, 0.6))
				draw_polyline(poly, Color(1, 1, 1, 0.9), 1.5, false)
			if u < 0.3:
				_glow(Vector2(0, -60), 110.0 * size, Color("#bff0ff", 0.5 * (1.0 - u / 0.3)), 4)
		"crack_ring":
			for k in range(10):
				var d := Vector2.RIGHT.rotated(TAU * k / 10.0 + _seed)
				var p0 := Vector2.ZERO
				for seg in range(4):
					var p1 := p0 + d.rotated(sin(_seed + k * 3.0 + seg) * 0.7) * (16.0 + 26.0 * u) * size
					draw_line(p0, p1, Color(color, fade), 2.5, false)
					p0 = p1
		"counter":
			var pk := clampf(1.0 - (_t - _pop_t) / 0.12, 0.0, 1.0)
			var fin := _end_t > 0.0
			var f2 := _font_of()
			var sz2 := int((44.0 + (26.0 if fin else 0.0)) * size * (1.0 + (0.6 if fin else 0.25) * pk))
			var w2 := f2.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2).x
			var a5 := 1.0 if not fin else clampf((_end_t - _t) / 0.3, 0.0, 1.0)
			var c2 := color.lerp(C_CORE, pk * 0.6)
			draw_string_outline(f2, Vector2(-w2 / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2, 12, Color(0.06, 0.03, 0.02, a5))
			draw_string(f2, Vector2(-w2 / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2, Color(c2, a5))
		"fire_pillar":
			_fire_pillar(u)
		"spin_shield":
			for k in range(_trail.size()):
				var tp: Vector2 = (_trail[k] as Vector2) - global_position
				var a6 := 1.0 - float(k) / _trail.size()
				draw_circle(tp, 40.0 * size * a6, Color(Color("#ffd27a"), 0.28 * a6))
			_glow(Vector2.ZERO, 70.0 * size, Color(Color("#ffe9a8"), 0.7), 3)
			_shield_turn(Vector2.ZERO, 64.0 * size, _t * 22.0)
		"chains":
			_chains(u)
		"aura":
			_aura(u, fade)
		"smoke":
			for q in _parts:
				var lu3 := clampf((u - float(q.d)) / (1.0 - float(q.d)), 0.0, 1.0)
				if lu3 <= 0.0:
					continue
				var grow2 := 1.0 - pow(1.0 - clampf(lu3 / 0.3, 0.0, 1.0), 3.0)
				var cp2: Vector2 = (q.p as Vector2) + (q.v as Vector2) * lu3
				var al := 0.8 * (1.0 - pow(lu3, 2.0))
				draw_circle(cp2, float(q.r) * (0.4 + 0.8 * grow2), Color(Color("#8a8f99").lerp(Color("#cfd3da"), 0.5 * lu3), al))
				draw_circle(cp2 + Vector2(-6, -8), float(q.r) * (0.25 + 0.5 * grow2), Color(Color("#e8ebf0"), al * 0.5))
		"hourglass":
			_hourglass(u, fade)
		"trap_set":
			var pop2 := 1.0 - pow(1.0 - clampf(u / 0.2, 0.0, 1.0), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (0.6 + 0.4 * pop2) * size)
			_trap_jaws(Vector2.ZERO, 1.0, minf(1.0, fade * 3.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var gl := clampf(1.0 - absf(u - 0.35) / 0.15, 0.0, 1.0)
			if gl > 0.0:
				var sp3 := Vector2(30, -14) * size
				draw_line(sp3 + Vector2(-18 * gl, 0), sp3 + Vector2(18 * gl, 0), Color(C_CORE, gl), 2.0)
				draw_line(sp3 + Vector2(0, -18 * gl), sp3 + Vector2(0, 18 * gl), Color(C_CORE, gl), 2.0)
				_glow(sp3, 14.0, Color(C_CORE, gl), 2)
			if u < 0.4:
				_ring(Vector2(0, 4), lerpf(20.0, 80.0, u / 0.4) * size, Color(Color("#c9b89a"), 0.6 * (1.0 - u / 0.4)), 3.0)
		"uplift":
			for q in _parts:
				var y3 := float(q.y) - float(q.sp) * _t
				draw_line(Vector2(float(q.x), y3), Vector2(float(q.x), y3 + float(q.len)), Color(color, 0.7 * fade), 3.0)
			_ring(Vector2.ZERO, lerpf(20.0, 140.0, u) * size, Color(Color("#e8dcc8"), fade), 4.0 * fade + 1.0)
		"down_arrows":
			for j in range(3):
				var yy := -60.0 + j * 34.0 + 60.0 * u
				var aa := fade * clampf(u * 4.0 - j * 0.4, 0.0, 1.0)
				var ww2 := 30.0 * size
				draw_polyline(PackedVector2Array([Vector2(-ww2, yy - 14.0), Vector2(0, yy + 6.0), Vector2(ww2, yy - 14.0)]), Color(color, aa), 7.0, false)
				draw_polyline(PackedVector2Array([Vector2(-ww2, yy - 14.0), Vector2(0, yy + 6.0), Vector2(ww2, yy - 14.0)]), Color(C_CORE, aa * 0.6), 2.0, false)
		"chain_line":
			var grow3 := clampf(u / 0.35, 0.0, 1.0)
			var end2 := (to - position) * (1.0 - pow(1.0 - grow3, 3.0))
			var n2 := int(end2.length() / 16.0)
			var dd := end2.normalized()
			var al2 := fade if u > 0.6 else 1.0
			_glow(end2, 30.0, Color(color, 0.6 * al2), 3)
			for k in range(n2):
				var c3 := dd * (k * 16.0 + 8.0) + Vector2(0, sin(k * 0.6 + _t * 8.0) * 3.0)
				var rot2 := dd.angle() + (PI / 2.0 if k % 2 == 1 else 0.0)
				draw_set_transform(c3, rot2, Vector2(1.0, 0.55 if k % 2 == 1 else 1.0))
				draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 14, Color(Color("#2a1038"), al2), 5.0, false)
				draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 14, Color(color, al2), 2.5, false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cut_line":
			var half := (to - position) * 0.5
			var w := lerpf(7.0, 0.5, u) * size
			draw_line(-half * (1.0 + u * 0.3), half * (1.0 + u * 0.3), Color(color, 0.45 * fade), w * 3.0)
			draw_line(-half * (1.0 + u * 0.3), half * (1.0 + u * 0.3), Color(C_CORE, fade), w)
			var n := half.normalized().orthogonal()
			for k in range(3):
				var back := -half.normalized() * (18.0 + k * 16.0) * (1.0 + u)
				draw_arc(back + n * 30.0 * size, 60.0 * size, half.angle() - 0.9, half.angle() + 0.9, 16, Color(color, (0.5 - k * 0.14) * fade), 3.0 - k * 0.6, false)
		"shield_pop":
			var sc := lerpf(0.5, 2.6, 1.0 - pow(1.0 - u, 2.0))
			_shield_shape(Vector2.ZERO, 70.0 * sc * size, Color(Color("#e0ad4a"), 0.55 * fade), Color(C_CORE, fade))
		"crescent":
			var sweep := 1.0 - pow(1.0 - clampf(u / 0.6, 0.0, 1.0), 2.0)
			var r := 230.0 * size
			var a0 := -PI * 0.85
			var a1 := lerpf(a0, PI * 0.3, sweep)
			for k in range(4):
				draw_arc(Vector2.ZERO, r - k * 14.0, maxf(a0, a1 - 1.4), a1, 32, Color(color.lerp(C_CORE, 0.3 * k), (0.8 - k * 0.15) * fade), 10.0 - k * 2.0, false)
			for k in range(8):
				var a := a1 - k * 0.12
				var d := Vector2.RIGHT.rotated(a)
				draw_line(d * (r + 10.0), d * (r + 50.0 + 20.0 * sin(k)), Color(C_CORE, 0.5 * fade), 2.0)
		"card_burn":
			var cw := 54.0 * size
			var ch := 76.0 * size
			var left := 1.0 - u
			var top := -ch / 2.0 + ch * u
			if left > 0.02:
				draw_rect(Rect2(Vector2(-cw / 2.0, top), Vector2(cw, ch * left)), Color("#3a2a44"))
				draw_rect(Rect2(Vector2(-cw / 2.0 + 4, top + 4), Vector2(cw - 8, maxf(0.0, ch * left - 8))), Color("#6a4a8a"))
				for k in range(7):
					var fx := -cw / 2.0 + cw * k / 6.0
					var fh := 10.0 + 8.0 * sin(_t * 30.0 + k * 1.7)
					draw_colored_polygon(PackedVector2Array([Vector2(fx - 6, top + 2), Vector2(fx, top - fh), Vector2(fx + 6, top + 2)]), Color("#ff8a2a"))
				draw_line(Vector2(-cw / 2.0, top), Vector2(cw / 2.0, top), Color("#ffe08a"), 3.0)
		"card_fly":
			var e2 := 1.0 - pow(1.0 - u, 3.0)
			var p2 := Vector2.ZERO.lerp(to - _from, e2) + Vector2(0, -sin(e2 * PI) * 90.0)
			draw_set_transform(p2, (1.0 - e2) * -2.4, Vector2.ONE * size)
			draw_rect(Rect2(-22, -31, 44, 62), Color("#2a2036"))
			draw_rect(Rect2(-18, -27, 36, 54), Color(color, 0.95))
			draw_rect(Rect2(-22, -31, 44, 62), Color(C_CORE, 0.9), false, 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if u > 0.85:
				_glow(to - _from, 40.0, Color(C_CORE, (1.0 - u) / 0.15), 3)
		"react_text":
			var pop := 1.0 + 0.35 * sin(clampf(u / 0.2, 0.0, 1.0) * PI)
			var f := _font_of()
			var sz := int(40 * size * pop)
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var at := Vector2(-w / 2.0, -40.0 * u)
			var a4 := 1.0 if u < 0.7 else 1.0 - (u - 0.7) / 0.3
			draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 10, Color(0.05, 0.03, 0.06, a4))
			draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(color.lerp(C_CORE, 0.25), a4))


# 날아가는 것: 모양별 머리 + 지나온 길(꼬리)
func _missile() -> void:
	var c := color
	var vdir := (to - _from).normalized()
	for k in range(_trail.size()):
		var tp: Vector2 = _trail[k] - position
		var a := 1.0 - float(k) / _trail.size()
		match style:
			"fire":
				draw_circle(tp, 14.0 * size * a, Color(Color("#ff6a1e").lerp(Color("#5a2a1a"), 1.0 - a), 0.75 * a))
			"ice":
				draw_rect(Rect2(tp - Vector2(2, 2), Vector2(4, 4)), Color(0.9, 0.98, 1.0, a))
			"dark", "hex":
				draw_circle(tp, 12.0 * size * a, Color(Color("#5a1a8a"), 0.6 * a))
			"poison":
				draw_circle(tp, 10.0 * size * a, Color(Color("#6fd83a"), 0.5 * a))
			"soul":
				draw_circle(tp + Vector2(0, sin(_t * 18.0 + k) * 4.0), 11.0 * size * a, Color(c, 0.4 * a))
			"blood":
				draw_circle(tp, 4.0 * size * a, Color(Color("#e0303a"), 0.8 * a))
			"steel":
				pass
			_:
				draw_circle(tp, 10.0 * size * a, Color(c, 0.55 * a))
	match style:
		"fire":
			_glow(Vector2.ZERO, 40.0 * size, Color("#ff8a2a", 0.9), 4)
			draw_circle(Vector2.ZERO, 16.0 * size, Color("#ffb43c"))
			draw_circle(Vector2.ZERO, 9.0 * size, Color("#fff3c0"))
			for k in range(5):
				var fl := Vector2.RIGHT.rotated(vdir.angle() + PI + (k - 2) * 0.35) * (20.0 + 10.0 * sin(_t * 40.0 + k)) * size
				draw_colored_polygon(PackedVector2Array([fl.orthogonal().normalized() * 6.0 * size, fl, -fl.orthogonal().normalized() * 6.0 * size]), Color("#ff6a1e", 0.8))
		"ice":
			var n := vdir.orthogonal()
			var s := 30.0 * size
			var pts := PackedVector2Array([vdir * s, n * s * 0.22, -vdir * s * 0.9, -n * s * 0.22])
			_glow(Vector2.ZERO, 30.0 * size, Color("#bff0ff", 0.7), 3)
			draw_colored_polygon(pts, Color(0.7, 0.93, 1.0, 0.95))
			draw_colored_polygon(PackedVector2Array([pts[0], pts[1], Vector2.ZERO]), Color(1, 1, 1, 0.9))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 1), 1.5, false)
		"dark":
			_glow(Vector2.ZERO, 46.0 * size, Color("#8a3ad8", 0.8), 4)
			draw_circle(Vector2.ZERO, 16.0 * size, Color("#12041a"))
			for k in range(8):
				var d := Vector2.RIGHT.rotated(TAU * k / 8.0 + _t * 9.0)
				draw_line(d * 14.0 * size, d * (22.0 + 6.0 * sin(_t * 30.0 + k)) * size, Color("#d08aff"), 2.0)
		"hex":
			_glow(Vector2.ZERO, 40.0 * size, Color("#b05ad8", 0.8), 4)
			draw_circle(Vector2.ZERO, 13.0 * size, Color("#c890ff"))
			draw_circle(Vector2(-4, -2) * size, 3.0 * size, Color("#12041a"))
			draw_circle(Vector2(4, -2) * size, 3.0 * size, Color("#12041a"))
		"ki":
			_glow(Vector2.ZERO, 50.0 * size, Color("#7fd6ff", 0.9), 5)
			draw_circle(Vector2.ZERO, 14.0 * size, Color("#fffaf0"))
		"poison":
			_glow(Vector2.ZERO, 34.0 * size, Color("#8ae04a", 0.7), 3)
			draw_circle(Vector2.ZERO, 12.0 * size, Color("#b6ff7a"))
			for k in range(3):
				draw_circle(Vector2(sin(_t * 20.0 + k * 2.0) * 8.0, cos(_t * 17.0 + k) * 8.0) * size, 4.0 * size, Color("#e8ffd0"))
		"soul":
			_glow(Vector2.ZERO, 30.0 * size, Color(c, 0.8), 3)
			draw_circle(Vector2.ZERO, 11.0 * size, Color(c.lerp(C_CORE, 0.5), 0.95))
			draw_circle(Vector2(-3.5, -2) * size, 2.5 * size, Color(0.1, 0.02, 0.15))
			draw_circle(Vector2(3.5, -2) * size, 2.5 * size, Color(0.1, 0.02, 0.15))
		"blood":
			var bn := vdir.orthogonal()
			draw_line(-vdir * 40.0 * size, Vector2.ZERO, Color("#ff5a5a", 0.6), 6.0 * size)
			draw_line(-vdir * 34.0 * size, Vector2.ZERO, Color("#fff0e8"), 2.0)
			draw_colored_polygon(PackedVector2Array([vdir * 12.0 * size, bn * 5.0 * size, -bn * 5.0 * size]), Color("#ff3a3a"))
		"steel":
			draw_set_transform(Vector2.ZERO, _t * 14.0, Vector2.ONE * size * 0.5)
			_trap_jaws(Vector2.ZERO, 0.0, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			_glow(Vector2.ZERO, 34.0 * size, Color(c, 0.8), 3)
			draw_circle(Vector2.ZERO, 10.0 * size, C_CORE)


# ── 모양 도우미 ──

# 손그림처럼 매 장마다 조금씩 떨리는 값(같은 장 안에서는 고정)
func _wob(i: float) -> float:
	var x := sin((_boil + _seed * 7.0) * 12.9898 + i * 78.233) * 43758.5453
	return x - floorf(x) - 0.5


func _glow(c: Vector2, r: float, col: Color, layers: int) -> void:
	for k in range(layers):
		var f := 1.0 - float(k) / layers
		draw_circle(c, r * (0.35 + 0.65 * f) * (1.0 + 0.08 * _wob(k)), Color(col, col.a * 0.22 * (1.0 + (1.0 - f))))


func _ring(c: Vector2, r: float, col: Color, w: float) -> void:
	var n := clampi(int(r / 6.0), 10, 40)
	var pts := PackedVector2Array()
	for k in range(n + 1):
		var a := TAU * k / n
		var j := 1.0 + 0.05 * _wob(k % n)
		pts.append(c + Vector2(cos(a), sin(a)) * r * j)
	draw_polyline(pts, col, w, false)


func _shard(p: Vector2, s: float, rot: float, light: Color, dark: Color) -> void:
	var d := Vector2.RIGHT.rotated(rot)
	var n := d.orthogonal()
	var pts := PackedVector2Array([p + d * s, p + n * s * 0.32, p - d * s * 0.6, p - n * s * 0.28])
	draw_colored_polygon(pts, dark)
	draw_colored_polygon(PackedVector2Array([p + d * s, p + n * s * 0.32, p]), light)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(light, light.a * 0.9), 1.2, false)


func _fire_burst(u: float, fade: float) -> void:
	if u < 0.1:
		_glow(Vector2.ZERO, 130.0 * size, Color("#fff4c8", 1.0 - u * 10.0), 5)
	var grow := 1.0 - pow(1.0 - clampf(u / 0.45, 0.0, 1.0), 3.0)
	var r := lerpf(20.0, 96.0, grow) * size
	var layers := [[1.0, Color("#c8301a")], [0.78, Color("#ff6a1e")], [0.55, Color("#ffb43c")], [0.3, Color("#fff0b0")]]
	for L in layers:
		var pts := PackedVector2Array()
		for k in range(28):
			var a := TAU * k / 28.0
			var wob := 1.0 + 0.16 * sin(a * 5.0 + _t * 14.0 + _seed) + 0.1 * sin(a * 9.0 - _t * 20.0)
			pts.append(Vector2(cos(a), sin(a) * 0.86) * r * float(L[0]) * wob)
		draw_colored_polygon(pts, Color(L[1], fade * (0.9 if u < 0.6 else 1.6 * fade)))
	if u > 0.15:
		var su := (u - 0.15) / 0.85
		for k in range(7):
			var sp := Vector2(cos(k * 0.9 + _seed) * 70.0, -40.0 - 90.0 * su + sin(k * 2.1) * 20.0) * size
			draw_circle(sp, (24.0 + 30.0 * su) * size, Color(Color("#3a3036"), 0.45 * (1.0 - su)))
	_ring(Vector2.ZERO, lerpf(30.0, 190.0, clampf(u / 0.4, 0.0, 1.0)) * size, Color(Color("#ffe0a0"), clampf(1.0 - u / 0.4, 0.0, 1.0)), 4.0)
	for q in _parts:
		var lu := clampf(_t / (float(q.l) * life), 0.0, 1.0)
		if lu >= 1.0:
			continue
		var p: Vector2 = (q.v as Vector2) * _t + Vector2(0, 260.0 * _t * _t)
		draw_rect(Rect2(p - Vector2(float(q.s), float(q.s)) / 2.0, Vector2(float(q.s), float(q.s))), Color(Color("#ffd25a").lerp(Color("#ff4a1a"), lu), 1.0 - lu))


func _rift_burst(u: float, fade: float) -> void:
	var grow := 1.0 - pow(1.0 - clampf(u / 0.3, 0.0, 1.0), 3.0)
	if grow < 0.02:
		return
	var spikes := PackedVector2Array()
	for k in range(24):
		var a := TAU * k / 24.0 + _seed
		var r := (120.0 if k % 2 == 0 else 46.0) * (0.8 + 0.4 * sin(_seed * 3.0 + k * 1.7)) * size * grow
		spikes.append(Vector2.RIGHT.rotated(a) * r)
	draw_colored_polygon(spikes, Color(Color("#120418"), 0.9 * fade))
	var inner := PackedVector2Array()
	for p in spikes:
		inner.append(p * 0.62)
	draw_colored_polygon(inner, Color(Color("#5a1a8a"), 0.85 * fade))
	draw_polyline(spikes + PackedVector2Array([spikes[0]]), Color(Color("#d08aff"), fade), 3.0, false)
	_glow(Vector2.ZERO, 80.0 * size * grow, Color(Color("#b45aff"), 0.6 * fade), 4)
	for k in range(8):
		var d := Vector2.RIGHT.rotated(TAU * k / 8.0 + _seed * 2.0)
		var p0 := d * 30.0
		for seg in range(4):
			var p1 := p0 + d.rotated(sin(_seed + k * 3.0 + seg) * 0.8) * (34.0 + 50.0 * u) * size
			draw_line(p0, p1, Color(Color("#f0d0ff"), fade), 2.0, false)
			p0 = p1


func _beam(u: float, fade: float) -> void:
	var v := to - position
	var len := v.length()
	if len <= 1.0:
		return
	var d := v / len
	var n := d.orthogonal()
	var open := clampf(u / 0.08, 0.0, 1.0)
	var w := lerpf(60.0, 6.0, clampf((u - 0.08) / 0.92, 0.0, 1.0)) * size * open
	var end := d * len * open
	for k in range(4):
		var ww := w * (1.6 - k * 0.35)
		draw_line(Vector2.ZERO, end, Color(color, (0.18 + 0.12 * k) * fade), ww)
	draw_line(Vector2.ZERO, end, Color(C_CORE, fade), w * 0.28)
	for k in range(14):
		var t := fmod(_seed * 13.0 + k * 0.137 + _t * 3.0, 1.0)
		var sp := end * t + n * sin(k * 7.3 + _t * 30.0) * w * 0.9
		draw_line(sp, sp + d * 30.0, Color(C_CORE, fade * 0.8), 2.0)
	_glow(Vector2.ZERO, 70.0 * size * fade, Color(color, fade), 4)


func _charge_orb() -> void:
	var lv := clampf(level, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * (10.0 + lv * 30.0))
	var r := lerpf(8.0, 46.0, lv) * size
	_glow(Vector2.ZERO, r * (2.4 + pulse * 0.6), Color(color, 0.55 + 0.45 * lv), 5)
	draw_circle(Vector2.ZERO, r * 0.55, C_CORE)
	var flare := lerpf(20.0, 260.0, lv) * (0.85 + 0.15 * pulse)
	draw_line(Vector2(-flare, 0), Vector2(flare, 0), Color(C_CORE, 0.5 + 0.4 * lv), 2.0 + 2.0 * lv)
	draw_line(Vector2(0, -flare * 0.4), Vector2(0, flare * 0.4), Color(C_CORE, 0.4 + 0.4 * lv), 1.5 + 1.5 * lv)
	for k in range(int(6 + lv * 18)):
		var cyc := fmod(_t * (1.2 + lv * 2.0) + k * 0.173, 1.0)
		var a := k * 2.399 + _seed
		var p := Vector2.RIGHT.rotated(a) * lerpf(180.0, r, cyc * cyc)
		draw_line(p, p * 0.86, Color(color.lerp(C_CORE, cyc), 1.0 - cyc * 0.3), 2.0)
	if lv >= 0.92:
		_ring(Vector2.ZERO, r * 2.0 + pulse * 10.0, Color(Color("#ffe27a"), 0.9), 3.0)


func _trap_jaws(c: Vector2, gap: float, a: float) -> void:
	# 바닥의 쇠 덫: 받침 막대 + 이빨 달린 반원 턱 둘. gap 1 = 활짝, 0 = 닫힘
	var steel := Color(Color("#b8c2cc"), a)
	var dark := Color(Color("#3a3f46"), a)
	var w := 44.0
	draw_rect(Rect2(c + Vector2(-w - 6.0, 2), Vector2(w * 2.0 + 12.0, 6)), dark)
	draw_circle(c + Vector2(0, 5), 7.0, dark)
	for side in [-1.0, 1.0]:
		var lift: float = lerpf(0.12, 1.3, gap) * float(side)
		var pts := PackedVector2Array()
		for k in range(13):
			var t := k / 12.0
			var arc := Vector2(lerpf(-w, w, t), -sin(t * PI) * 16.0)
			var tooth := (-7.0 if k % 2 == 0 else 0.0)
			pts.append(c + Vector2(arc.x, (arc.y + tooth) * cos(lift) * side * -1.0 - absf(sin(lift)) * 18.0 * absf(arc.x) / w * 0.0))
		draw_polyline(pts, steel, 3.0, false)
		draw_polyline(pts, Color(Color("#fffaf0"), a * 0.5), 1.0, false)


func _skull(u: float, fade: float) -> void:
	var grow := 1.0 - pow(1.0 - clampf(u / 0.25, 0.0, 1.0), 3.0)
	var s := 70.0 * size * grow * (1.0 + 0.3 * u)
	var col := Color(Color("#b46aff"), fade)
	for q in _parts:
		var p: Vector2 = (q.v as Vector2) * _t * 1.4
		draw_circle(p, float(q.s) * (1.0 + u), Color(Color("#2a1038"), 0.4 * fade))
	draw_circle(Vector2(0, -s * 0.15), s * 0.62, Color(col, 0.75 * fade))
	draw_rect(Rect2(Vector2(-s * 0.32, s * 0.2), Vector2(s * 0.64, s * 0.32)), Color(col, 0.75 * fade))
	draw_circle(Vector2(-s * 0.24, -s * 0.12), s * 0.15, Color(Color("#12041a"), fade))
	draw_circle(Vector2(s * 0.24, -s * 0.12), s * 0.15, Color(Color("#12041a"), fade))
	for k in range(3):
		draw_line(Vector2(-s * 0.18 + k * s * 0.18, s * 0.22), Vector2(-s * 0.18 + k * s * 0.18, s * 0.5), Color(Color("#12041a"), fade), 3.0)
	_ring(Vector2.ZERO, lerpf(20.0, 200.0, u) * size, Color(Color("#e0b0ff"), fade), 3.0)


func _hex_wall(c: Vector2, rise: float, a: float, crack: float, s: float) -> void:
	var cell := 22.0 * s
	var cols := 3
	var rows := 7
	var top := c + Vector2(0, -rows * cell * 1.5 * rise)
	for r in range(rows):
		for k in range(cols):
			var hc := c + Vector2((k - 1) * cell * 1.75 + (cell * 0.87 if r % 2 == 1 else 0.0), -(r + 0.5) * cell * 1.5 * rise)
			if hc.y < top.y - 2.0:
				continue
			var pts := PackedVector2Array()
			for j in range(7):
				var ang := PI / 6.0 + TAU * j / 6.0
				pts.append(hc + Vector2(cos(ang), sin(ang)) * cell * 0.92)
			draw_colored_polygon(pts.slice(0, 6), Color(Color("#ffd27a"), 0.3 * a))
			draw_polyline(pts, Color(Color("#fff3c8"), 0.95 * a), 3.0, false)
	if crack > 0.0:
		var p0 := c + Vector2(-10, -rows * cell * 0.8)
		for seg in range(6):
			var p1 := p0 + Vector2(sin(seg * 2.3 + _seed) * 22.0, cell * 1.1) * s
			draw_line(p0, p1, Color(Color("#fffaf0"), crack * a), 2.5, false)
			p0 = p1


func _shield_shape(c: Vector2, s: float, fill: Color, rim: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.6), c + Vector2(s * 0.55, -s * 0.6), c + Vector2(s * 0.5, s * 0.1), c + Vector2(0, s * 0.7), c + Vector2(-s * 0.5, s * 0.1)])
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), rim, 6.0, false)
	draw_line(c + Vector2(0, -s * 0.5), c + Vector2(0, s * 0.55), rim, 5.0)
	draw_line(c + Vector2(-s * 0.4, -s * 0.15), c + Vector2(s * 0.4, -s * 0.15), rim, 5.0)


func _eye(u: float) -> void:
	# 0~0.25 뜸 · 0.25~0.85 깜빡임 셋 · 0.85~1 감김
	var open := clampf(u / 0.25, 0.0, 1.0)
	if u > 0.85:
		open = clampf((1.0 - u) / 0.15, 0.0, 1.0)
	for k in range(3):
		var bt := 0.32 + k * 0.18
		if absf(u - bt) < 0.04:
			open *= absf(u - bt) / 0.04
	var w := 300.0 * size
	var h := 110.0 * size * open
	var pts := PackedVector2Array()
	for k in range(33):
		var t := k / 32.0
		pts.append(Vector2(lerpf(-w, w, t), -sin(t * PI) * h))
	for k in range(31, 0, -1):
		var t2 := k / 32.0
		pts.append(Vector2(lerpf(-w, w, t2), sin(t2 * PI) * h))
	_glow(Vector2.ZERO, w * 0.9, Color(Color("#8a2ac8"), 0.5 * open), 4)
	if pts.size() >= 3 and h > 1.0:
		draw_colored_polygon(pts, Color(Color("#f0e6ff"), 0.92))
		var ir := 70.0 * size * minf(1.0, h / (70.0 * size))
		draw_circle(Vector2.ZERO, ir, Color(Color("#a02a6a"), 1.0))
		draw_circle(Vector2.ZERO, ir * 0.55, Color(Color("#1a0418"), 1.0))
		draw_circle(Vector2(-ir * 0.3, -ir * 0.3), ir * 0.14, Color(1, 1, 1, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Color("#2a0838"), 1.0), 6.0, false)


# 불기둥: 땅에서 솟아 너울거리는 혀 네 겹 + 위로 날리는 불티
func _fire_pillar(u: float) -> void:
	var rise := 1.0 - pow(1.0 - clampf(u / 0.18, 0.0, 1.0), 3.0)
	var sink := clampf((u - 0.55) / 0.45, 0.0, 1.0)
	var h := 300.0 * size * rise * (1.0 - 0.7 * sink)
	var w := 44.0 * size * (1.0 - 0.4 * sink)
	var a := 1.0 - sink
	if h < 6.0:
		return
	_glow(Vector2(0, -h * 0.4), w * 2.2, Color(Color("#ff7a2a"), 0.5 * a), 4)
	var layers := [[1.0, Color("#c8301a")], [0.76, Color("#ff6a1e")], [0.52, Color("#ffb43c")], [0.28, Color("#fff0b0")]]
	for L in layers:
		var k := float(L[0])
		var pts := PackedVector2Array()
		var n := 10
		for j in range(n + 1):
			var t := float(j) / n
			pts.append(Vector2((-w + sin(t * 9.0 + _t * 18.0 + _seed) * 8.0) * k * (1.0 - t * 0.85), -h * k * t))
		pts.append(Vector2(sin(_t * 14.0 + _seed) * 10.0, -h * k * 1.08))
		for j in range(n, -1, -1):
			var t2 := float(j) / n
			pts.append(Vector2((w + sin(t2 * 7.0 - _t * 16.0 + _seed * 2.0) * 8.0) * k * (1.0 - t2 * 0.85), -h * k * t2))
		draw_colored_polygon(pts, Color(L[1], a * (0.85 if k > 0.5 else 1.0)))
	for q in _parts:
		var tt := _t - float(q.d)
		if tt < 0.0:
			continue
		var p := Vector2(float(q.x) + sin(tt * 9.0 + float(q.v)) * 10.0, -40.0 - float(q.v) * tt)
		var la := clampf(1.0 - tt / 0.6, 0.0, 1.0) * a
		draw_rect(Rect2(p - Vector2(float(q.s), float(q.s)) / 2.0, Vector2(float(q.s), float(q.s))), Color(Color("#ffd25a"), la))
	if u < 0.15:
		_ring(Vector2.ZERO, lerpf(20.0, 90.0, u / 0.15) * size, Color(Color("#ffe0a0"), 1.0 - u / 0.15), 4.0)


# 돌아가는 방패(방패 부메랑): 금테 방패를 rot만큼 돌려서
func _shield_turn(c: Vector2, s: float, rot: float) -> void:
	var base := [Vector2(-0.55, -0.6), Vector2(0.55, -0.6), Vector2(0.5, 0.1), Vector2(0, 0.7), Vector2(-0.5, 0.1)]
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for p in base:
		pts.append(c + ((p as Vector2) * s).rotated(rot))
		inner.append(c + ((p as Vector2) * s * 0.7).rotated(rot))
	draw_colored_polygon(pts, Color("#b8862e"))
	draw_colored_polygon(inner, Color("#e0ad4a"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#fff3c8"), 4.0, false)
	draw_line(c + (Vector2(0, -0.5) * s).rotated(rot), c + (Vector2(0, 0.55) * s).rotated(rot), Color("#fff3c8"), 3.0)
	draw_line(c + (Vector2(-0.4, -0.15) * s).rotated(rot), c + (Vector2(0.4, -0.15) * s).rotated(rot), Color("#fff3c8"), 3.0)


# 쇠사슬 셋이 몸을 감아 조이다(0~0.4) 번쩍(0.4~0.5) 끊어져 고리가 사방으로 튐
func _chains(u: float) -> void:
	var tight := 1.0 - pow(1.0 - clampf(u / 0.4, 0.0, 1.0), 2.0)
	var snapped := u > 0.5 and style != "hold"
	var rx := lerpf(110.0, 58.0, tight) * size
	var ry := lerpf(30.0, 18.0, tight) * size
	var link := TAU * rx / 26.0
	for q in _parts:
		var j := int(q.loop)
		var cy := (-44.0 + j * 44.0) * size
		var a := float(q.a) + _t * (2.0 if j % 2 == 0 else -2.0) * (1.0 - tight)
		var p := Vector2(cos(a) * rx, cy + sin(a) * ry)
		var tan := atan2(ry * cos(a), -rx * sin(a))
		var al := 1.0
		if snapped:
			var st := u - 0.5
			p += (q.v as Vector2) * st + Vector2(0, 700.0 * st * st)
			tan += float(q.w) * st
			al = clampf(1.0 - st / 0.45, 0.0, 1.0)
		elif sin(a) < 0.0:
			al = 0.5
		if style == "hold" and u > 0.6:
			al *= clampf((1.0 - u) / 0.4, 0.0, 1.0)
		var side := int(q.k) % 2 == 1
		draw_set_transform(p, tan, Vector2(1.0, 0.18 if side else 0.55))
		draw_arc(Vector2.ZERO, link * 0.62, 0.0, TAU, 14, Color(Color("#14101a"), al), 6.0, false)
		draw_arc(Vector2.ZERO, link * 0.62, 0.0, TAU, 14, Color(color, al), 3.0, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if u > 0.4 and u < 0.62 and style != "hold":
		_glow(Vector2.ZERO, 120.0 * size, Color(C_CORE, 1.0 - absf(u - 0.5) / 0.12), 4)


# 몸에 서리는 기운(분노·피의 계약·독 바르기): 발밑 타원 둘레에서 불꽃 혀가 솟고 불티가 오른다
func _aura(u: float, fade: float) -> void:
	var on := clampf(u / 0.15, 0.0, 1.0) * (fade / 0.4 if u > 0.6 else 1.0)
	_glow(Vector2(0, -70), 110.0 * size, Color(color, 0.35 * on), 4)
	for q in _parts:
		if q.has("spark"):
			var tt := _t - float(q.d)
			if tt < 0.0:
				continue
			var sp := Vector2(float(q.x) * size, -float(q.v) * tt * 2.0)
			draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color(color.lerp(C_CORE, 0.4), on * clampf(1.0 - tt, 0.0, 1.0)))
			continue
		var a := float(q.a)
		var base := Vector2(cos(a) * 52.0, sin(a) * 14.0) * size
		var h := float(q.h) * size * (0.7 + 0.3 * sin(_t * 16.0 + float(q.ph)))
		var w := float(q.w) * size
		var col := Color(color, on * (0.5 if sin(a) < 0.0 else 0.85))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w / 2.0, 0), base + Vector2(sin(_t * 9.0 + float(q.ph)) * 6.0, -h), base + Vector2(w / 2.0, 0)]), col)


# 모래시계(저주): 머리 위에 떠올라 뒤집히고, 모래가 흐른다
func _hourglass(u: float, fade: float) -> void:
	var pop := 1.0 - pow(1.0 - clampf(u / 0.15, 0.0, 1.0), 3.0)
	var flip := clampf((u - 0.2) / 0.25, 0.0, 1.0)
	var rot := PI * (flip * flip * (3.0 - 2.0 * flip))
	var s := 34.0 * size * pop
	if s < 2.0:
		return
	var a := fade / 0.3 if u > 0.7 else 1.0
	_glow(Vector2.ZERO, s * 2.4, Color(Color("#b05ad8"), 0.5 * a), 4)
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.7, -s), Vector2(s * 0.7, -s), Vector2(0, 0)]), Color(Color("#2a1038"), 0.85 * a))
	draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.7, s), Vector2(s * 0.7, s), Vector2(0, 0)]), Color(Color("#2a1038"), 0.85 * a))
	var sand := clampf((u - 0.45) / 0.5, 0.0, 1.0)
	var k := 1.0 - sand
	if k > 0.02:
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.7 * k, -s * k), Vector2(s * 0.7 * k, -s * k), Vector2(0, 0)]), Color(Color("#e0b0ff"), a))
	if sand > 0.02:
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.7, s), Vector2(s * 0.7, s), Vector2(s * 0.7 * (1.0 - sand), s * (1.0 - sand)), Vector2(-s * 0.7 * (1.0 - sand), s * (1.0 - sand))]), Color(Color("#e0b0ff"), a))
		draw_line(Vector2.ZERO, Vector2(0, s), Color(Color("#e0b0ff"), a), 2.0)
	draw_polyline(PackedVector2Array([Vector2(-s * 0.8, -s), Vector2(s * 0.8, -s), Vector2(0, 0), Vector2(s * 0.8, s), Vector2(-s * 0.8, s), Vector2(0, 0), Vector2(-s * 0.8, -s)]), Color(Color("#d8a0ff"), a), 3.0, false)
	draw_line(Vector2(-s, -s - 4), Vector2(s, -s - 4), Color(Color("#fff0ff"), a), 4.0)
	draw_line(Vector2(-s, s + 4), Vector2(s, s + 4), Color(Color("#fff0ff"), a), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if u > 0.85:
		var e := (u - 0.85) / 0.15
		_ring(Vector2.ZERO, lerpf(s, s * 4.0, e), Color(Color("#e0b0ff"), 1.0 - e), 3.0)


func _orbs5(u: float) -> void:
	var merge := clampf((u - 0.55) / 0.3, 0.0, 1.0)
	for q in _parts:
		var a := float(q.a) + _t * lerpf(3.0, 14.0, u)
		var rad := lerpf(120.0, 0.0, merge * merge) * size
		var p := Vector2(cos(a), sin(a) * 0.45) * rad
		_glow(p, 30.0 * size, Color(q.c, 0.9), 3)
		draw_circle(p, 9.0 * size, C_CORE)
	if merge > 0.0:
		_glow(Vector2.ZERO, 160.0 * size * merge, Color(C_CORE, merge), 5)
		for k in range(12):
			var d := Vector2.RIGHT.rotated(TAU * k / 12.0 + _t * 2.0)
			draw_line(d * 20.0, d * 220.0 * merge * size, Color(C_CORE, 0.6 * merge), 3.0)
