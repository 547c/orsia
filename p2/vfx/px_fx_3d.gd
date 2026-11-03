class_name P2PxFx3D
extends Node3D

# 픽셀 효과 한 번(3D 무대): 배우와 같은 단위(무대 1 = 배우 원본 1px, pixel_size 1)로 카메라를 향한 판에 장을 그린다.
# 본체는 알파 자르기 · 최근접. 빛 마스크는 더하기로 얹을 뿐 장면을 비추지 않는다. light_flash면 따로 OmniLight3D가 장별 빛 양만큼 켜져
# 벽 · 바닥을 실제로 비춘다(light_mask 층만: 기본 건축 1 + 배우 8, 3D UI 2 · 물 4 · 안개에는 기여 없음).
# 시각은 바깥 음악 시계(clock, 예: P2Music.clock)에서 샘플링한다: 멈추면 멈추고 되감으면 그 장으로. reduced(효과 줄이기)면 빛을 끄고 본체만

signal finished

const LAYER_ACTORS := 8

var sheet: P2PxSheet
var clock := Callable()
# 음악 시각으로 효과 0초(첫 장) 자리. play()는 접촉 장이 contact_at에 오게 정한다
var start := 0.0
var reduced := false
var light_flash := false
var light_mask := 1 | 8
var flash_energy := 16.0
var flash_range := 90.0
# 실제 광원 자리(기준점에서, 무대 단위)
var flash_at := Vector3(0, 26, 6)
var free_on_end := true
var _flip := false
var _body: Sprite3D
var _glow: Sprite3D
var _lamp: OmniLight3D
var _done := false


# 효과를 건다. contact_at = 접촉 장이 보여야 할 음악 시각(입력 결과 · 피해 시점). flip = 왼쪽을 향함(원본은 오른쪽)
func play(s: P2PxSheet, contact_at: float, c: Callable, flip := false) -> P2PxFx3D:
	sheet = s
	clock = c
	start = contact_at - s.contact_t
	_flip = flip
	_body = _plate(s.color, false)
	_glow = _plate(s.light, true)
	if light_flash:
		_lamp = OmniLight3D.new()
		_lamp.light_cull_mask = light_mask
		_lamp.light_volumetric_fog_energy = 0.0
		_lamp.shadow_enabled = false
		_lamp.omni_range = flash_range
		_lamp.light_color = s.glow_color
		_lamp.position = Vector3(-flash_at.x if flip else flash_at.x, flash_at.y, flash_at.z)
		_lamp.visible = false
		add_child(_lamp)
	return self


func _plate(tex: Texture2D, add: bool) -> Sprite3D:
	var p := Sprite3D.new()
	p.texture = tex
	p.region_enabled = true
	p.centered = false
	p.pixel_size = 1.0
	p.flip_h = _flip
	p.layers = LAYER_ACTORS
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visible = false
	if add:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.render_priority = 1
		p.material_override = m
	else:
		p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		p.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		p.shaded = false
	add_child(p)
	return p


func _process(_delta: float) -> void:
	if sheet != null and clock.is_valid():
		sample(float(clock.call()))


# 음악 시각 now의 장을 그린다(바깥에서 직접 불러도 된다)
func sample(now: float) -> void:
	var t := now - start
	var i := sheet.frame_at(t)
	if i < 0:
		_body.visible = false
		_glow.visible = false
		if _lamp != null:
			_lamp.visible = false
		if t >= sheet.length and not _done:
			_done = true
			finished.emit()
			if free_on_end:
				queue_free()
		return
	var r: Rect2 = sheet.rects[i]
	# 판 원점은 장의 왼쪽 아래: 기준점(장 왼쪽 위에서 잰 px)이 노드 원점에 오게. 뒤집으면 기준점도 거울로
	var off := Vector2(-(r.size.x - sheet.pivot.x) if _flip else -sheet.pivot.x, -(r.size.y - sheet.pivot.y))
	for p in [_body, _glow]:
		var s: Sprite3D = p
		s.region_rect = r
		s.offset = off
	_body.visible = true
	_glow.visible = not reduced
	if _lamp != null:
		_lamp.visible = not reduced
		_lamp.light_energy = flash_energy * sheet.glow_at(i)
