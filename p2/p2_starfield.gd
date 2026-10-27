class_name P2Starfield
extends Control
# 원정 지도 배경: 검은 우주 · 옅은 성운 두 겹(구간마다 색이 다름) · 은은히 반짝이는 별(흰·푸른·노란·붉은 별을 섞음) ·
# 가끔 지나가는 별똥별 · 가운데 균열의 핵으로 소용돌이치며 빨려 드는 먼지.
# 고리를 돌리면 별도 아주 조금 따라 돈다(먼 별은 덜, 가까운 별은 더) — 깊이감

const PALETTE := [[Color(1, 1, 1), 30], [Color("#d7e6ff"), 22], [Color("#a8c8ff"), 14], [Color("#fff1c9"), 12], [Color("#ffd27f"), 8],
	[Color("#ffab85"), 6], [Color("#c9b4ff"), 5], [Color("#9ff0ff"), 3]]
const NEBULA := {"normal": [Color("#3a1d5c"), Color("#0e3b4f")], "hard": [Color("#162a63"), Color("#0b4a55")], "extreme": [Color("#5a1426"), Color("#3a1650")]}
const FAR := 0.03
const NEAR := 0.075

var core := Vector2(640, 308)
# 픽셀 지도에서 절반 해상도로 그릴 때 별·먼지가 사라지지 않게 크기를 키우는 배수
var px := 1.0
var rot := 0.0
var _stars: Array = []
var _dust: Array = []
var _t := 0.0
var _shoot := {}
var _next_shoot := 5.0
var _rng := RandomNumberGenerator.new()
var _sky: Control
var warp_k := 0.0
var _warp_at := Vector2.ZERO
var _warp_tw: Tween


func setup(sector: String, at: Vector2) -> void:
	core = at
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color("#04050a")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var cols: Array = NEBULA.get(sector, NEBULA.normal)
	for k in range(2):
		_nebula(cols[k], 31 + k * 17 + sector.length(), 0.006 + k * 0.004, 0.75 - k * 0.15)
	_sky = Control.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	_rng.seed = 7 + sector.length()
	var total := 0
	for pc in PALETTE:
		total += int(pc[1])
	for i in range(300):
		var near := i >= 210
		var pick := _rng.randi_range(0, total - 1)
		var col: Color = PALETTE[0][0]
		for pc in PALETTE:
			pick -= int(pc[1])
			if pick < 0:
				col = pc[0]
				break
		_stars.append({"p": Vector2(_rng.randf_range(-260, 1540), _rng.randf_range(-360, 1080)), "s": _rng.randf_range(2.0, 3.2) if near else _rng.randf_range(1.0, 2.0),
			"c": col, "ph": _rng.randf() * TAU, "sp": _rng.randf_range(0.5, 2.0), "base": _rng.randf_range(0.25, 0.7), "near": near})
	for i in range(54):
		_dust.append({"a": _rng.randf() * TAU, "r": _rng.randf_range(0.15, 1.0), "sp": _rng.randf_range(0.6, 1.4), "s": _rng.randf_range(1.0, 2.0)})


# 성운: 노이즈 텍스처(작게 만들어 부드럽게 키움)를 한 가지 색으로 칠해 옅게 깐다
func _nebula(col: Color, sd: int, freq: float, alpha: float) -> void:
	var n := FastNoiseLite.new()
	n.seed = sd
	n.frequency = freq
	n.fractal_octaves = 4
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, col)
	g.add_point(0.5, Color(col, 0.0))
	var tex := NoiseTexture2D.new()
	tex.width = 320
	tex.height = 180
	tex.noise = n
	tex.color_ramp = g
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.modulate.a = alpha
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


# 소용돌이에 빨려 들 때(또는 나올 때): 별이 그 자리에서 바깥으로 길게 늘어났다가 돌아온다(워프)
func warp(at: Vector2) -> void:
	_warp_at = at
	if _warp_tw != null and _warp_tw.is_valid():
		_warp_tw.kill()
	_warp_tw = create_tween()
	_warp_tw.tween_property(self, "warp_k", 1.0, 0.22).set_ease(Tween.EASE_IN)
	_warp_tw.tween_property(self, "warp_k", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	for d in _dust:
		d.r = float(d.r) - delta * 0.045 * float(d.sp)
		d.a = float(d.a) + delta * float(d.sp) * (0.35 / maxf(0.12, float(d.r)))
		if float(d.r) < 0.08:
			d.r = 1.0
			d.a = _rng.randf() * TAU
	_next_shoot -= delta
	if _next_shoot <= 0.0 and _shoot.is_empty():
		var from := Vector2(_rng.randf_range(80, 900), _rng.randf_range(60, 260))
		_shoot = {"p": from, "v": Vector2(_rng.randf_range(520, 760), _rng.randf_range(160, 300)), "life": 0.0}
		_next_shoot = _rng.randf_range(7.0, 14.0)
	if not _shoot.is_empty():
		_shoot.life = float(_shoot.life) + delta
		if float(_shoot.life) > 0.7:
			_shoot = {}
	if _sky != null:
		_sky.queue_redraw()


func _draw_sky() -> void:
	var view := Rect2(Vector2.ZERO, size).grow(6.0)
	for st in _stars:
		var k := NEAR if bool(st.near) else FAR
		var p: Vector2 = core + ((st.p as Vector2) - core).rotated(deg_to_rad(rot * k))
		if not view.has_point(p):
			continue
		var tw := pow(maxf(0.0, sin(_t * float(st.sp) + float(st.ph))), 6.0)
		var a := float(st.base) + (1.0 - float(st.base)) * tw
		var s := float(st.s) * px
		var col: Color = st.c
		if warp_k > 0.02:
			var away := (p - _warp_at).normalized()
			var L2 := (8.0 + 90.0 * warp_k) * (1.5 if bool(st.near) else 1.0) * clampf(p.distance_to(_warp_at) / 500.0, 0.3, 1.6)
			_sky.draw_line(p, p + away * L2, Color(col, a * (0.5 + 0.5 * warp_k)), maxf(1.0, s * 0.8))
			continue
		_sky.draw_rect(Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), Color(col, a))
		# 밝은 별이 반짝이는 순간: 십자 빛
		if s >= 2.0 and tw > 0.35:
			var L := s * (1.5 + 3.0 * tw)
			var ca := Color(col, 0.5 * tw)
			_sky.draw_line(p - Vector2(L, 0), p + Vector2(L, 0), ca, px)
			_sky.draw_line(p - Vector2(0, L), p + Vector2(0, L), ca, px)
	# 핵으로 빨려 드는 먼지(타원 소용돌이)
	for d in _dust:
		var r := float(d.r)
		var q := core + Vector2(cos(float(d.a)) * 300.0 * r, sin(float(d.a)) * 110.0 * r)
		var a2 := 0.55 * (1.0 - r) * minf(1.0, r * 6.0)
		_sky.draw_rect(Rect2(q, Vector2.ONE * float(d.s) * px), Color(1.0, 0.62, 0.45, a2))
	# 별똥별
	if not _shoot.is_empty():
		var life := float(_shoot.life)
		var head: Vector2 = (_shoot.p as Vector2) + (_shoot.v as Vector2) * life
		var dir: Vector2 = (_shoot.v as Vector2).normalized()
		var fade := 1.0 - life / 0.7
		for i in range(10):
			var t0 := float(i) / 10.0
			_sky.draw_line(head - dir * 120.0 * t0, head - dir * 120.0 * (t0 + 0.1), Color(0.85, 0.93, 1.0, fade * (1.0 - t0) * 0.85), (2.0 if i < 3 else 1.0) * px)
		_sky.draw_rect(Rect2(head - Vector2(1.5, 1.5) * px, Vector2(3, 3) * px), Color(1, 1, 1, fade))
