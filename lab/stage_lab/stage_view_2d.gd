extends Node2D

# A: 간단한 2D 바닥 받침. 같은 바닥 타일을 납작하게(원근 없이) 깔고, 인물은 첨부 PNG를 정수 n배로 화면에 붙인다.
# 인물 · 바닥 끝 · 바닥 빛 자리는 B와 같은 좌표(stage_space)에서 받아 두 보기의 화면 자리가 같다. 접지는 받침 · 그림자 자국 · 반사광을 납작한 타원으로

const Space := preload("res://lab/stage_lab/stage_space.gd")
const View3D := preload("res://lab/stage_lab/stage_view_3d.gd")

var space: Space
var _back: ColorRect
var _floor: TextureRect
var _actors: Array = []
var _lamps: Array = []
var _lamp_v := 0.0
var lamps_on := true


func build(sp: Space, actors: Array, tile: Texture2D) -> void:
	space = sp
	_back = ColorRect.new()
	_back.color = Color("#14111c")
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_floor = TextureRect.new()
	_floor.texture = tile
	_floor.stretch_mode = TextureRect.STRETCH_TILE
	_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor)
	var glow := View3D.radial()
	for a in actors:
		var support := _blob(glow, Color(0.62, 0.6, 0.78, 0.22), false)
		var shadow := _blob(glow, Color(0.02, 0.01, 0.04, 0.55), false)
		var bounce := _blob(glow, Color(1.0, 0.84, 0.6, 0.16), true)
		var spr := Sprite2D.new()
		spr.texture = a.tex
		spr.centered = false
		spr.offset = -(a.foot as Vector2)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		_actors.append({"spr": spr, "support": support, "shadow": shadow, "bounce": bounce, "side": int(a.side)})
	for k in range(4):
		_lamps.append(_blob(glow, Color(0.62, 0.86, 1.0, 1.0), true))
	layout()


func _blob(tex: Texture2D, c: Color, add: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.modulate = c
	if add:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	add_child(s)
	return s


func layout() -> void:
	_back.size = space.view
	_floor.scale = Vector2.ONE * space.n
	_floor.size = Vector2(space.view.x / space.n + 2, space.view.y / space.n + 2)


# 납작한 타원: 무대 단위 크기(w × h)를 화면 n배로
func _put(s: Sprite2D, at: Vector2, w: float, h: float) -> void:
	s.position = at
	s.scale = Vector2(w, h) * space.n / 32.0


func pulse() -> void:
	_lamp_v = 1.0


func update(delta: float, lamp_points: Array) -> void:
	# 바닥 받침 위 끝 = B 무대 바닥 뒤 끝이 보이는 높이
	var top := roundf(space.to_screen(Vector3(0, 0, Space.FLOOR_BACK)).y / space.n) * space.n
	_floor.position = Vector2(0, top)
	var side := space.side_x()
	for a in _actors:
		var x := side * float(a.side)
		var feet := space.to_screen(Vector3(x, 0, 0)).round()
		(a.spr as Sprite2D).position = feet
		(a.spr as Sprite2D).scale = Vector2.ONE * space.n
		_put(a.support, feet, 30, 6)
		_put(a.shadow, feet + Vector2(3, 1) * space.n, 26, 4)
		_put(a.bounce, feet + Vector2(-14.0 * float(a.side), 3) * space.n, 22, 5)
	_lamp_v = maxf(0.0, _lamp_v - delta * 3.0)
	for k in range(_lamps.size()):
		var l: Sprite2D = _lamps[k]
		l.visible = lamps_on
		_put(l, space.to_screen(lamp_points[k]), 10, 3)
		l.modulate.a = 0.18 + 0.5 * _lamp_v
