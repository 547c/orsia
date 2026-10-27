class_name P2Ambience
extends Node2D

# 전장 분위기 입자(픽셀 그림판): 수로 = 천장에서 떨어지는 물방울과 바닥 물결 · 횃불빛 먼지, 심층 = 푸른 불티가 오름,
# 균열 = 붉은 불씨가 오르고 재가 내림, 들판 = 떠도는 먼지. 보스방은 더 촘촘. 규칙·저장과 무관한 표현이고 배우 뒤에 그린다

const FLOOR_Y := 380.0
const MOTE_ZONES := [Vector2(156, 230), Vector2(640, 260), Vector2(1223, 200)]

var kind := "dust"
var rate := 1.0
var speed := 1.0
var _p: Array = []
var _rings: Array = []
var _t := 0.0
var _spawn := 0.0
var _rng := RandomNumberGenerator.new()
var _c: P2Pixel


func setup(k: String, boss: bool) -> void:
	kind = k
	rate = 1.6 if boss else 1.0
	_rng.seed = hash([k, boss])
	for i in range(int(36 * rate)):
		_p.append(_mote(true))


func _ready() -> void:
	_c = P2Pixel.attach(self, _paint)


func _process(delta: float) -> void:
	var dt := delta * speed
	_t += dt
	_spawn += dt * rate * {"water": 2.4, "frost": 10.0, "ember": 12.0, "dust": 0.0}.get(kind, 0.0)
	while _spawn >= 1.0:
		_spawn -= 1.0
		_p.append(_drop() if kind == "water" else _ember())
	if kind == "ember" and _rng.randf() < dt * 3.0 * rate:
		_p.append(_ash())
	var keep: Array = []
	for q in _p:
		q.age = float(q.age) + dt
		match String(q.k):
			"drop":
				q.vel = (q.vel as Vector2) + Vector2(0, 900.0 * dt)
				q.pos = (q.pos as Vector2) + (q.vel as Vector2) * dt
				if (q.pos as Vector2).y >= float(q.floor):
					_rings.append({"pos": Vector2((q.pos as Vector2).x, float(q.floor)), "age": 0.0})
					continue
			"mote":
				q.pos = (q.home as Vector2) + Vector2(sin(_t * 0.4 + float(q.ph)) * 18.0, sin(_t * 0.27 + float(q.ph) * 1.7) * 10.0)
			_:
				q.pos = (q.pos as Vector2) + Vector2(sin(_t * 1.6 + float(q.ph)) * 14.0 * dt, (q.vel as Vector2).y * dt)
		if q.k == "mote" or float(q.age) < float(q.life):
			keep.append(q)
	_p = keep
	_rings = _rings.filter(func(r): return float(r.age) < 0.5)
	for r in _rings:
		r.age = float(r.age) + dt
	_c.redraw()


func _mote(fresh: bool) -> Dictionary:
	var z: Vector2 = MOTE_ZONES[_rng.randi() % MOTE_ZONES.size()]
	var home := z + Vector2(_rng.randf_range(-170, 170), _rng.randf_range(-110, 110))
	var col: Color = {"water": Color(1.0, 0.86, 0.6), "frost": Color(0.7, 0.86, 1.0), "ember": Color(1.0, 0.7, 0.45)}.get(kind, Color(0.95, 0.9, 0.75))
	return {"k": "mote", "home": home, "pos": home, "ph": _rng.randf() * TAU, "age": _rng.randf() * 10.0 if fresh else 0.0, "life": 0.0, "c": col,
		"tw": _rng.randf_range(0.6, 1.6)}


func _drop() -> Dictionary:
	var x := _rng.randf_range(60, 1220)
	return {"k": "drop", "pos": Vector2(x, _rng.randf_range(30, 110)), "vel": Vector2(0, _rng.randf_range(20, 80)), "floor": FLOOR_Y + _rng.randf_range(-6, 60),
		"age": 0.0, "life": 4.0, "c": Color(0.72, 0.88, 1.0), "ph": 0.0}


func _ember() -> Dictionary:
	var col: Color = [Color("#8fe8ff"), Color("#5fb8ff"), Color("#d8f4ff")][_rng.randi() % 3] if kind == "frost" else [Color("#ff9a3a"), Color("#ffcf4a"), Color("#ff5a3a")][_rng.randi() % 3]
	return {"k": "ember", "pos": Vector2(_rng.randf_range(20, 1260), FLOOR_Y + _rng.randf_range(0, 80)), "vel": Vector2(0, -_rng.randf_range(28, 70)),
		"age": 0.0, "life": _rng.randf_range(2.5, 5.0), "c": col, "ph": _rng.randf() * TAU, "s": 2.0 if _rng.randf() < 0.6 else 4.0}


func _ash() -> Dictionary:
	return {"k": "ash", "pos": Vector2(_rng.randf_range(20, 1260), -10.0), "vel": Vector2(0, _rng.randf_range(16, 34)),
		"age": 0.0, "life": 12.0, "c": Color(0.55, 0.5, 0.5), "ph": _rng.randf() * TAU, "s": 4.0}


func _paint() -> void:
	for q in _p:
		var p: Vector2 = (q.pos as Vector2).round()
		var c: Color = q.c
		match String(q.k):
			"mote":
				var tw := 0.5 + 0.5 * sin(_t * float(q.tw) * 2.0 + float(q.ph))
				_c.draw_rect(Rect2(p, Vector2(2, 2)), Color(c, 0.18 + 0.4 * tw))
			"drop":
				_c.draw_rect(Rect2(p, Vector2(2, 6)), Color(c, 0.75))
			_:
				var u := float(q.age) / float(q.life)
				var a := minf(1.0, u * 6.0) * (1.0 - u)
				var s := float(q.get("s", 2.0))
				if q.k == "ember" and s > 2.0:
					_c.draw_rect(Rect2(p - Vector2(2, 2), Vector2(s + 4.0, s + 4.0)), Color(c, a * 0.3))
				_c.draw_rect(Rect2(p, Vector2(s, s)), Color(c, a * (0.55 if q.k == "ash" else 0.95)))
	for r in _rings:
		var u := float(r.age) / 0.5
		var w := 4.0 + 18.0 * u
		var pts := PackedVector2Array()
		for k in range(17):
			var ang := TAU * k / 16.0
			pts.append((r.pos as Vector2) + Vector2(cos(ang) * w, sin(ang) * w * 0.3))
		_c.draw_polyline(pts, Color(0.75, 0.9, 1.0, 0.6 * (1.0 - u)), P2Pixel.w(2.0))
