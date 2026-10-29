extends Node

# B: 실제 3D 바닥 + 낮은 단차 하나 + 빛 하나. 저해상도 SubViewport(화면의 n분의 1)에 그려 최근접 n배로 키운다(원화 도트 한 칸 = 화면 n px).
# 인물은 첨부 PNG를 카메라를 향한 판(billboard)으로 발 기준점에 세운다(세로로 누르지 않음). 접지는 바닥 받침 · 그림자 자국 · 반사광으로

const Space := preload("res://tools/stage_lab/godot/stage_space.gd")

var space: Space
var vp: SubViewport
var rect: TextureRect
var cam: Camera3D
var _floor: MeshInstance3D
var _step: MeshInstance3D
var _actors: Array = []
var _lamps: Array = []
var _lamp_v := 0.0
var lamps_on := true


func build(sp: Space, actors: Array, tile: Texture2D) -> void:
	space = sp
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	rect = TextureRect.new()
	rect.texture = vp.get_texture()
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#14111c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.55, 0.68)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	# 빛 하나: 앞 왼쪽 위에서 뒤 오른쪽 아래로(단차 앞면 · 그림자 방향이 읽히게)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.transform = Transform3D(Basis.looking_at(Vector3(0.45, -0.78, -0.45).normalized(), Vector3.UP), Vector3.ZERO)
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 4000.0
	vp.add_child(cam)
	cam.current = true
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = tile
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.roughness = 1.0
	fm.metallic_specular = 0.0
	_floor = MeshInstance3D.new()
	_floor.mesh = PlaneMesh.new()
	_floor.material_override = fm
	vp.add_child(_floor)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = tile
	sm.albedo_color = Color(1.25, 1.2, 1.3)
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.roughness = 1.0
	sm.metallic_specular = 0.0
	_step = MeshInstance3D.new()
	_step.mesh = BoxMesh.new()
	_step.material_override = sm
	vp.add_child(_step)
	for a in actors:
		var spr := Sprite3D.new()
		spr.texture = a.tex
		spr.pixel_size = 1.0
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.shaded = false
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spr.centered = false
		# 발 기준점(그림 왼쪽 위에서 잰 px)을 판의 원점에: 판은 원점이 왼쪽 아래
		var th := float((a.tex as Texture2D).get_height())
		spr.offset = Vector2(-float(a.foot.x), -(th - float(a.foot.y)))
		vp.add_child(spr)
		var support := _flat(Vector2(30, 11), Color(0.62, 0.6, 0.78, 0.22), false)
		var shadow := _flat(Vector2(26, 8), Color(0.02, 0.01, 0.04, 0.55), false)
		var bounce := _flat(Vector2(22, 9), Color(1.0, 0.84, 0.6, 0.16), true)
		_actors.append({"spr": spr, "support": support, "shadow": shadow, "bounce": bounce, "side": int(a.side)})
	for k in range(4):
		_lamps.append(_flat(Vector2(10, 5), Color(0.62, 0.86, 1.0, 1.0), true))
	layout()


# 바닥에 눕힌 둥근 판(받침 · 그림자 자국 · 반사광 · 바닥 빛). add면 더하기 섞기
func _flat(size: Vector2, c: Color, add: bool) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = radial()
	m.albedo_color = c
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation = Vector3(-PI / 2.0, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
	return mi


static func radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


# 화면 크기 · 배율이 바뀌면 저해상도 판 · 무대 크기 · 자리를 다시
func layout() -> void:
	vp.size = space.low
	rect.size = Vector2(space.low) * space.n
	cam.size = space.low.y
	var depth := Space.FLOOR_FRONT - Space.FLOOR_BACK
	(_floor.mesh as PlaneMesh).size = Vector2(space.low.x * 1.6, depth)
	_floor.position = Vector3(0, 0, (Space.FLOOR_BACK + Space.FLOOR_FRONT) / 2.0)
	(_floor.material_override as StandardMaterial3D).uv1_scale = Vector3(space.low.x * 1.6 / 16.0, depth / 16.0, 1)
	# 낮은 단차: 막기 구도에서 수행 공간 가운데 아래 바닥에, 높이 3(저해상도 3px)
	var keep_p := space.pitch
	var keep_f := space.feet
	space.set_frame(Space.DEFEND, Space.DEFEND, 1.0)
	var c := space.to_floor(space.play_rect().get_center())
	space.pitch = keep_p
	space.feet = keep_f
	var w := roundf(space.low.x * 0.44)
	(_step.mesh as BoxMesh).size = Vector3(w, 3, 64)
	_step.position = Vector3(0, 1.5, roundf(c.z))
	(_step.material_override as StandardMaterial3D).uv1_scale = Vector3(w / 16.0, 64.0 / 16.0, 1)
	var side := space.side_x()
	for a in _actors:
		var x := side * float(a.side)
		(a.spr as Sprite3D).position = Vector3(x, 0, 0)
		(a.support as Node3D).position = Vector3(x, 0.15, 0)
		(a.shadow as Node3D).position = Vector3(x + 3, 0.2, -2)
		# 반사광: 수행 공간 쪽(안쪽) 발 앞 바닥
		(a.bounce as Node3D).position = Vector3(x - 14.0 * float(a.side), 0.25, 6)
	var corners := [Vector3(-w / 2.0 + 6, 3.2, _step.position.z - 26), Vector3(w / 2.0 - 6, 3.2, _step.position.z - 26),
		Vector3(-w / 2.0 + 6, 3.2, _step.position.z + 26), Vector3(w / 2.0 - 6, 3.2, _step.position.z + 26)]
	for k in range(_lamps.size()):
		(_lamps[k] as Node3D).position = corners[k]


func lamp_points() -> Array:
	return _lamps.map(func(l): return (l as Node3D).position)


# 음악 박(악보 cue의 kick)에 바닥 빛 한 묶음이 밝아졌다 잦아든다
func pulse() -> void:
	_lamp_v = 1.0


func update(delta: float) -> void:
	cam.position = space.cam_pos()
	cam.look_at(space.target(), Vector3.UP)
	_lamp_v = maxf(0.0, _lamp_v - delta * 3.0)
	for l in _lamps:
		var mi: MeshInstance3D = l
		mi.visible = lamps_on
		var m: StandardMaterial3D = mi.material_override
		m.albedo_color.a = 0.18 + 0.5 * _lamp_v


func set_active(on: bool) -> void:
	rect.visible = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
