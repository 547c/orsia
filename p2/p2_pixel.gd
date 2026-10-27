class_name P2Pixel
extends Node2D

# 픽셀 그림판의 붓: 화면 전체를 덮는 절반 해상도 SubViewport 안에서 host와 같은 좌표로 그리면 최근접 두 배로 보인다(안티에일리어싱 없음,
# 반투명은 몇 단계로 줄여 점 무늬로). 글자·아이콘은 text()·icon()으로 맡기면 host 위 원래 해상도 층(ink)에 찍는다. --smooth면 예전처럼 매끈하게

const PIX := 2
const ALPHA_SHADER := preload("res://p2/p2_pixel_alpha.gdshader")

var host: CanvasItem
var pix := PIX
var box: SubViewportContainer
var ink: Node2D
var _paint: Callable
var _texts: Array = []


static func smooth() -> bool:
	return "--smooth" in OS.get_cmdline_user_args()


# 굵기를 그림판 칸에 맞춘다(한 칸 = 2px, 최소 한 칸)
static func w(width: float) -> float:
	return width if smooth() else maxf(PIX, floorf(width / PIX) * PIX)


# 절반 해상도 그림판 하나: 안에 붙인 것을 최근접으로 PIX배 키워 보인다. 붙일 SubViewport를 돌려준다
static func canvas(parent: Node, pos: Vector2, size: Vector2, transparent: bool, internal := Node.INTERNAL_MODE_DISABLED, pix := PIX) -> SubViewport:
	var b := SubViewportContainer.new()
	b.stretch = true
	b.stretch_shrink = pix
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = pos
	b.size = size
	if transparent:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		b.material = mat
	parent.add_child(b, false, internal)
	b.set_process_input(false)
	var vp := SubViewport.new()
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	b.add_child(vp)
	return vp


# host 아래 붓을 단다. paint가 있으면 붓이 그릴 때마다 부른다(그 안의 글자는 text()로). on_top이면 host의 다른 자식들 위에
# pix: 그림판 한 칸 크기(화면 px) · shader: 그림판을 화면에 얹는 셰이더(없으면 반투명 단계만)
static func attach(host_item: CanvasItem, paint := Callable(), on_top := false, pix := PIX, shader: Shader = null) -> P2Pixel:
	var pen := P2Pixel.new()
	pen.host = host_item
	pen._paint = paint
	pen.pix = pix
	var mode := Node.INTERNAL_MODE_BACK if on_top else Node.INTERNAL_MODE_FRONT
	if smooth():
		host_item.add_child(pen, false, mode)
	else:
		var vp := canvas(host_item, Vector2.ZERO, host_item.get_viewport_rect().size if host_item.is_inside_tree() else Vector2(1280, 720), true, mode, pix)
		pen.box = vp.get_parent()
		var mat := ShaderMaterial.new()
		mat.shader = shader if shader != null else ALPHA_SHADER
		pen.box.material = mat
		vp.add_child(pen)
		pen._follow()
	if paint.is_valid():
		pen.ink = Node2D.new()
		pen.ink.draw.connect(pen._flush)
		host_item.add_child(pen.ink, false, Node.INTERNAL_MODE_BACK)
	return pen


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if box == null or not is_instance_valid(host):
		return
	var g := host.get_global_transform()
	var s := g.get_scale()
	box.scale = Vector2.ONE / s
	box.position = -g.origin / s
	position = g.origin / pix
	scale = s / pix


func redraw() -> void:
	queue_redraw()
	if ink != null:
		ink.queue_redraw()


func text(font: Font, at: Vector2, s: String, size: int, col: Color, outline := 0, ocol := Color.BLACK, xf := Transform2D.IDENTITY) -> void:
	_texts.append([font, at, s, size, col, outline, ocol, xf])


func icon(tex: Texture2D, rect: Rect2, col := Color.WHITE) -> void:
	_texts.append([tex, rect, col])


func _draw() -> void:
	_texts.clear()
	if _paint.is_valid():
		_paint.call()


func _flush() -> void:
	for t in _texts:
		if t[0] is Texture2D:
			ink.draw_texture_rect(t[0], t[1], false, t[2])
			continue
		var xf: Transform2D = t[7]
		if xf != Transform2D.IDENTITY:
			ink.draw_set_transform_matrix(xf)
		if int(t[5]) > 0:
			ink.draw_string_outline(t[0], t[1], t[2], HORIZONTAL_ALIGNMENT_LEFT, -1, t[3], t[5], t[6])
		ink.draw_string(t[0], t[1], t[2], HORIZONTAL_ALIGNMENT_LEFT, -1, t[3], t[4])
		if xf != Transform2D.IDENTITY:
			ink.draw_set_transform_matrix(Transform2D.IDENTITY)
