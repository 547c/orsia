class_name P2Manga
extends CanvasLayer

# 만화 칸 연격(콤보술사 필살): 멈춘 한 장면을 칸 넷에 다른 확대·각도로 차례로 띄운다(칸마다 흰 번쩍 · 집중선 · 효과 글자).
# 마지막 칸이 화면 전체로 커진 뒤 끝(finished) — 그다음 공간베기. 실제 시간으로 돈다

signal panel(k: int)
signal finished

const STEP := 0.17
const GROW := 0.2
# 칸 모양(화면 좌표, 기울어진 네 모서리) · 확대 · 기울기 · 장면 안 초점 이동 · 효과 글자
const PANELS := [
	{"pts": [Vector2(14, 14), Vector2(760, 14), Vector2(700, 352), Vector2(14, 352)], "zoom": 1.7, "rot": -0.06, "shift": Vector2(-90, 0), "word": "퍽!"},
	{"pts": [Vector2(774, 14), Vector2(1266, 14), Vector2(1266, 352), Vector2(714, 352)], "zoom": 2.6, "rot": 0.1, "shift": Vector2(30, -40), "word": "팍!"},
	{"pts": [Vector2(14, 366), Vector2(560, 366), Vector2(500, 706), Vector2(14, 706)], "zoom": 2.2, "rot": 0.14, "shift": Vector2(-150, 10), "word": "쾅!"},
	{"pts": [Vector2(574, 366), Vector2(1266, 366), Vector2(1266, 706), Vector2(514, 706)], "zoom": 3.0, "rot": -0.12, "shift": Vector2(0, -20), "word": "끝이다!"},
]

var shot: Texture2D
var focus := Vector2(860, 280)
var color := Color("#e2643c")
var _t := 0.0
var _host: Control
var _pen: P2Pixel
var _font: Font
var _shown := -1
var _done := false


static func play(parent: Node, shot_: Texture2D, focus_: Vector2, color_: Color) -> P2Manga:
	var m := P2Manga.new()
	m.layer = 38
	m.shot = shot_
	m.focus = focus_
	m.color = color_
	parent.add_child(m)
	return m


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = P2Ui.bold_font(64)
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.size = Vector2(1280, 720)
	_host.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_host)
	# 칸·집중선·멈춘 장면 모두 3배 픽셀 그림판에(장면도 거칠게 · 만화 망점 느낌), 효과 글자는 글자 층에
	_pen = P2Pixel.attach(_host, _paint, false, 3)


func _process(delta: float) -> void:
	_t += delta
	var k := int(_t / STEP)
	if k != _shown and k < PANELS.size():
		_shown = k
		panel.emit(k)
	var end := STEP * PANELS.size() + GROW + 0.06
	if _t >= end and not _done:
		_done = true
		finished.emit()
		queue_free()
		return
	_pen.redraw()


func _panel_pts(i: int, grow: float) -> PackedVector2Array:
	var src: Array = PANELS[i].pts
	var out := PackedVector2Array()
	var full := [Vector2(-20, -20), Vector2(1300, -20), Vector2(1300, 740), Vector2(-20, 740)]
	for j in range(4):
		out.append((src[j] as Vector2).lerp(full[j], grow))
	return out


func _paint() -> void:
	var n := PANELS.size()
	var grow := clampf((_t - STEP * n) / GROW, 0.0, 1.0)
	grow = grow * grow * (3.0 - 2.0 * grow)
	_pen.draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.02, 0.03, clampf(_t / 0.06, 0.0, 1.0)))
	for i in range(n):
		var age := _t - STEP * i
		if age < 0.0:
			continue
		if grow > 0.0 and i < n - 1:
			continue
		_paint_panel(i, age, grow if i == n - 1 else 0.0)


func _paint_panel(i: int, age: float, grow: float) -> void:
	var p: Dictionary = PANELS[i]
	var pts := _panel_pts(i, grow)
	var c := (pts[0] + pts[1] + pts[2] + pts[3]) / 4.0
	var pop := 1.0 + 0.18 * clampf(1.0 - age / 0.1, 0.0, 1.0)
	var zoom: float = float(p.zoom) * pop * lerpf(1.0, 0.9, grow)
	var rot: float = float(p.rot) * (1.0 - grow)
	var look: Vector2 = focus + (p.shift as Vector2) * (1.0 - grow)
	var jolt := Vector2.ZERO
	if age < 0.08:
		jolt = Vector2(randf_range(-6, 6), randf_range(-6, 6))
	var uvs := PackedVector2Array()
	for q in pts:
		var w: Vector2 = look + ((q - c - jolt) / zoom).rotated(-rot)
		uvs.append(w / Vector2(1280, 720))
	_pen.draw_colored_polygon(pts, Color.WHITE, uvs, shot)
	# 집중선: 칸 가운데로 모이는 흰 선
	var lines := 22
	for k in range(lines):
		var a := TAU * k / lines + i * 0.37
		var d := Vector2.RIGHT.rotated(a)
		var r0 := 120.0 + 40.0 * sin(k * 2.3 + i)
		var r1 := 900.0
		var p0 := c + d * r0
		var p1 := c + d * r1
		_pen.draw_line(p0, p1, Color(1, 1, 1, 0.22 if grow <= 0.0 else 0.22 * (1.0 - grow)), 2.0 + (k % 3))
	if age < 0.09:
		_pen.draw_colored_polygon(pts, Color(1, 1, 1, 0.85 * (1.0 - age / 0.09)))
	var border := pts.duplicate()
	border.append(pts[0])
	_pen.draw_polyline(border, Color(0.02, 0.01, 0.02), 14.0)
	_pen.draw_polyline(border, Color(1, 1, 1), 5.0)
	# 효과 글자: 칸 모서리에서 기울어져 튀어나옴
	var word := String(p.word)
	var wpop := clampf(age / 0.08, 0.0, 1.0)
	var sz := int(64 * (1.4 - 0.4 * wpop) * (1.4 if word.length() > 2 else 1.0))
	var at := pts[0].lerp(c, 0.35) + Vector2(10, 40)
	_pen.text(_font, Vector2.ZERO, word, sz, Color(color.lightened(0.35), wpop), 18, Color(0.05, 0.02, 0.02, wpop), Transform2D(-0.18 + 0.05 * i, at))
