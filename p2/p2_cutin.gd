class_name P2CutIn
extends CanvasLayer

# 필살 컷인(화면 맨 위 층): 흰 번쩍 + 흔들림 → 기울어진 띠가 오른쪽에서 쓱(망점·속도선) → 띠 안에 직업 그림이 띠 위로 넘칠 만큼 크게
# (흰 테두리 · 직업 색 테두리 빛 · 뒤에 큰 그림자) → 기울어진 기술 이름이 왼쪽에서 밀려 들어옴 → 눈에 반짝 → 띠가 위아래로 찢어지며 흰 섬광 → 끝(finished).
# 실제 시간으로 돈다(세계 느려짐과 무관)

signal finished

const DUR := 1.2
const TEAR := 0.95
const TILT := -0.16
const BAND_Y := 340.0
const BAND_H := 230.0

var title := ""
var sub := "필살"
var color := Color.WHITE
var art: Texture2D
var art_region := Rect2()
var art_flip := false
var art_tint := Color.WHITE
var _t := 0.0
var _host: Control
var _pen: P2Pixel
var _art_node: Control
var _font: Font
var _small: Font
var _lines: Array = []
var _sfx: Callable
var _done := false


static func play(parent: Node, title_: String, color_: Color, art_: Texture2D, sfx: Callable = Callable()) -> P2CutIn:
	var c := P2CutIn.new()
	c.layer = 40
	c.title = title_
	c.color = color_
	c.art = art_
	c._sfx = sfx
	if art_ != null:
		c.art_region = solid_rect(art_)
	parent.add_child(c)
	return c


# 그림에서 진하게 칠해진 곳만(옅은 그림자·빛 번짐 제외): 1/8로 줄여 알파 0.5 넘는 칸의 범위
static func solid_rect(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	if img == null:
		return Rect2()
	if img.is_compressed():
		img.decompress()
	var full := Vector2(img.get_width(), img.get_height())
	var small := img.duplicate() as Image
	var k := 8
	small.resize(maxi(1, img.get_width() / k), maxi(1, img.get_height() / k), Image.INTERPOLATE_BILINEAR)
	var lo := Vector2i(small.get_width(), small.get_height())
	var hi := Vector2i(-1, -1)
	for y in range(small.get_height()):
		for x in range(small.get_width()):
			if small.get_pixel(x, y).a > 0.5:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2(img.get_used_rect())
	var sx := full.x / small.get_width()
	var sy := full.y / small.get_height()
	return Rect2(Vector2(lo.x * sx, lo.y * sy), Vector2((hi.x - lo.x + 1) * sx, (hi.y - lo.y + 1) * sy)).intersection(Rect2(Vector2.ZERO, full))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = P2Ui.bold_font(80)
	_small = P2Ui.bold_font(26)
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.size = Vector2(1280, 720)
	_host.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_host)
	# 띠·망점·속도선은 3배 픽셀 그림판에, 직업 그림은 매끈한 층에, 글자는 맨 위 글자 층에
	_pen = P2Pixel.attach(_host, _paint, false, 3)
	_art_node = Control.new()
	_art_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_node.size = Vector2(1280, 720)
	_art_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host.add_child(_art_node)
	_art_node.draw.connect(_paint_art_now)
	for i in range(60):
		_lines.append({"y": randf_range(-BAND_H / 2.0, BAND_H / 2.0), "x": randf_range(0.0, 1800.0), "len": randf_range(80.0, 420.0), "sp": randf_range(2200.0, 4200.0), "w": randf_range(1.0, 5.0)})
	_beep("swing", 0.6)
	_beep("whoosh", 0.8)


func _beep(name: String, pitch: float) -> void:
	if _sfx.is_valid():
		_sfx.call(name, pitch)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < 0.18 and _t >= 0.18:
		_beep("whoosh", 1.4)
	if before < 0.5 and _t >= 0.5:
		_beep("crit_ready", 1.0)
	if before < TEAR and _t >= TEAR:
		_beep("burst", 1.1)
		_beep("boom_m", 1.2)
	if _t >= DUR and not _done:
		_done = true
		finished.emit()
		queue_free()
		return
	_pen.redraw()
	_art_node.queue_redraw()


func _ease_back(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return 1.0 + 2.4 * pow(c - 1.0, 3.0) + 1.4 * pow(c - 1.0, 2.0)


func _paint() -> void:
	var shake := Vector2.ZERO
	if _t < 0.16:
		var s := (1.0 - _t / 0.16) * 10.0
		shake = Vector2(randf_range(-s, s), randf_range(-s, s))
	var dim := clampf(_t / 0.08, 0.0, 1.0) * (1.0 - clampf((_t - TEAR) / 0.2, 0.0, 1.0))
	_pen.draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.01, 0.03, 0.8 * dim))
	if _t < 0.07:
		_pen.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.7 * (1.0 - _t / 0.07)))
	var slide := lerpf(1600.0, 0.0, clampf(_ease_back((_t - 0.03) / 0.22), 0.0, 1.15))
	var tear := clampf((_t - TEAR) / 0.2, 0.0, 1.0)
	if tear >= 1.0:
		return
	var split := tear * tear * 460.0
	var center := Vector2(640, BAND_Y) + shake
	var dark := color.darkened(0.75)
	# 띠 둘(위·아래 절반)을 기울인 좌표에서 그림. 찢어질 때 서로 반대로 벌어짐
	for half in [-1, 1]:
		var off := Vector2(-split * 0.5 * half, split * half)
		_pen.draw_set_transform(center + off, TILT, Vector2.ONE)
		var y0 := -BAND_H / 2.0 if half < 0 else 0.0
		var r := Rect2(Vector2(-1000 + slide, y0), Vector2(2000, BAND_H / 2.0))
		_pen.draw_rect(r, Color(dark, 0.97))
		# 망점: 오른쪽으로 갈수록 커지는 점
		for gx in range(0, 40):
			for gy in range(0, 4):
				var px := -1000.0 + slide + gx * 50.0 + (25.0 if gy % 2 == 1 else 0.0)
				var py := y0 + 14.0 + gy * 28.0
				var rad := clampf((px - slide + 200.0) / 1400.0, 0.0, 1.0) * 7.0
				if rad > 0.5:
					_pen.draw_circle(Vector2(px, py), rad, Color(color, 0.16))
		for q in _lines:
			var ly := float(q.y)
			if (half < 0 and ly >= 0.0) or (half > 0 and ly < 0.0):
				continue
			var x := fmod(float(q.x) - float(q.sp) * _t + 6000.0, 1800.0) - 900.0 + slide
			_pen.draw_line(Vector2(x, ly), Vector2(x + float(q.len), ly), Color(color.lightened(0.55), 0.4), float(q.w))
		var edge_y := -BAND_H / 2.0 if half < 0 else BAND_H / 2.0
		_pen.draw_line(Vector2(-1000 + slide, edge_y), Vector2(1000 + slide, edge_y), Color(color.lightened(0.4), 1.0), 6.0)
		_pen.draw_line(Vector2(-1000 + slide, edge_y + (8.0 if half < 0 else -8.0)), Vector2(1000 + slide, edge_y + (8.0 if half < 0 else -8.0)), Color(color, 0.6), 2.0)
	_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_paint_title(center, slide, split)
	if tear > 0.0:
		_pen.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.8 * (1.0 - tear)))


# 직업 그림: 띠 위로 넘칠 만큼 크게. 뒤에는 직업 색의 더 큰 그림자, 앞은 흰 테두리 + 직업 색 테두리 빛
func _paint_art_now() -> void:
	var tear := clampf((_t - TEAR) / 0.2, 0.0, 1.0)
	if tear >= 1.0:
		return
	var slide := lerpf(1600.0, 0.0, clampf(_ease_back((_t - 0.03) / 0.22), 0.0, 1.15))
	var shake := Vector2.ZERO
	if _t < 0.16:
		var sk := (1.0 - _t / 0.16) * 10.0
		shake = Vector2(randf_range(-sk, sk), randf_range(-sk, sk))
	_art_node.modulate.a = 1.0 - tear
	_paint_art(Vector2(640, BAND_Y) + shake, slide, tear * tear * 460.0)


func _paint_art(center: Vector2, slide: float, split: float) -> void:
	if art == null or art_region.size.x <= 0.0:
		return
	var h := BAND_H * 1.75
	var sc := h / art_region.size.y
	var size := art_region.size * sc
	var drift := lerpf(40.0, -40.0, clampf(_t / TEAR, 0.0, 1.0))
	var foot := center + Vector2(-260.0 + slide * 0.85 + drift - split * 0.3, BAND_H * 0.5 + 40.0 + split * 0.2)
	var pos := foot - Vector2(size.x * 0.5, size.y)
	var big := Rect2(foot - Vector2(size.x * 0.7, size.y * 1.4) + Vector2(60, 0), size * 1.4)
	_art_node.draw_texture_rect_region(art, big, art_region, Color(color.r, color.g, color.b, 0.22))
	var rect := Rect2(pos, size)
	if art_flip:
		rect = Rect2(pos + Vector2(size.x, 0), Vector2(-size.x, size.y))
	for o in [Vector2(-5, 0), Vector2(5, 0), Vector2(0, -5), Vector2(0, 5)]:
		_art_node.draw_texture_rect_region(art, Rect2(rect.position + o, rect.size), art_region, Color(1, 1, 1, 1))
	_art_node.draw_texture_rect_region(art, Rect2(rect.position + Vector2(8, -4), rect.size), art_region, Color(color.lightened(0.3), 1.0))
	_art_node.draw_texture_rect_region(art, rect, art_region, art_tint)
	if _t > 0.5 and _t < 0.72:
		var g := 1.0 - absf(_t - 0.61) / 0.11
		var eye := pos + Vector2(size.x * 0.6, size.y * 0.16)
		for k in range(4):
			var d := Vector2.RIGHT.rotated(k * PI / 4.0)
			var ln := (46.0 if k % 2 == 0 else 20.0) * g
			_art_node.draw_line(eye - d * ln, eye + d * ln, Color(1, 1, 1, g), 3.0 if k % 2 == 0 else 2.0)
		_art_node.draw_circle(eye, 6.0 * g, Color(1, 1, 1, g))


# 기술 이름: 기울인 굵은 글씨가 왼쪽에서 밀려 들어와 살짝 넘쳤다 자리 잡음 + 아래로 직업 색 줄이 그어짐
func _paint_title(center: Vector2, slide: float, split: float) -> void:
	var tin := (_t - 0.16) / 0.22
	if tin <= 0.0:
		return
	var tx := lerpf(-900.0, 0.0, clampf(_ease_back(tin), 0.0, 1.1))
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 80).x
	var at := center + Vector2(560.0 - tw + tx + split * 0.5, 38.0 - split)
	var xf := Transform2D(TILT, at) * Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)
	var under := clampf((_t - 0.3) / 0.18, 0.0, 1.0)
	_pen.draw_set_transform_matrix(xf)
	_pen.draw_rect(Rect2(Vector2(0, 22), Vector2(tw * under, 9)), color.lightened(0.2))
	_pen.draw_rect(Rect2(Vector2(tw * under - 12.0, 16), Vector2(12, 21)), Color(1, 1, 1, under))
	_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pen.text(_small, Vector2(6, -86), sub, 26, color.lightened(0.45), 8, Color(0.02, 0.01, 0.03), xf)
	_pen.text(_font, Vector2(6, 6), title, 80, color.lightened(0.5), 16, Color(0.02, 0.01, 0.03), xf)
	_pen.text(_font, Vector2.ZERO, title, 80, Color(1.0, 0.98, 0.92), 0, Color.BLACK, xf)
