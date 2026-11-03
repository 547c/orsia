class_name P2PxFx2D
extends Node2D

# 픽셀 효과 한 번(2D 화면): P2PxFx3D와 같은 시트 · 같은 시각 규칙을 Sprite2D로. 노드 scale을 배우와 같은 정수배로 두면 도트가 맞는다.
# 본체는 그대로, 빛 마스크는 더하기. 시각은 바깥 음악 시계에서 샘플링(멈춤 · 되감기), reduced면 빛 끄고 본체만

signal finished

var sheet: P2PxSheet
var clock := Callable()
var start := 0.0
var reduced := false
var free_on_end := true
var _flip := false
var _body: Sprite2D
var _glow: Sprite2D
var _done := false


func play(s: P2PxSheet, contact_at: float, c: Callable, flip := false) -> P2PxFx2D:
	sheet = s
	clock = c
	start = contact_at - s.contact_t
	_flip = flip
	_body = _plate(s.color, false)
	_glow = _plate(s.light, true)
	return self


func _plate(tex: Texture2D, add: bool) -> Sprite2D:
	var p := Sprite2D.new()
	p.texture = tex
	p.region_enabled = true
	p.centered = false
	p.flip_h = _flip
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.visible = false
	if add:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
	add_child(p)
	return p


func _process(_delta: float) -> void:
	if sheet != null and clock.is_valid():
		sample(float(clock.call()))


func sample(now: float) -> void:
	var t := now - start
	var i := sheet.frame_at(t)
	if i < 0:
		_body.visible = false
		_glow.visible = false
		if t >= sheet.length and not _done:
			_done = true
			finished.emit()
			if free_on_end:
				queue_free()
		return
	var r: Rect2 = sheet.rects[i]
	var off := Vector2(-(r.size.x - sheet.pivot.x) if _flip else -sheet.pivot.x, -sheet.pivot.y)
	for p in [_body, _glow]:
		var s: Sprite2D = p
		s.region_rect = r
		s.offset = off
	_body.visible = true
	_glow.visible = not reduced
