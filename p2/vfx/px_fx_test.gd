extends Node3D

# 픽셀 효과 샘플 시험 장면(본편 · 3D 무대 실험실과 따로). 위: 3D 무대(선택 화면 카메라 값 FOV 35° · 사선 22°, 배우 발 자리는 실험실과 같음),
# 아래 줄: 같은 효과의 2D 재생(정수 2배). 시각은 본편 P2Music.clock에서만 받는다(새 시계 없음).
# 1 베기 · 2 맞는 순간 · 3 완벽 패링 · 4 셋을 이어서 · R 효과 줄이기 · L 실제 순간 광원 · P 멈춤 · [ ] 효과 시각 0.1초 되감기/앞으로(되감기 시험)

const REF := "res://p2/vfx/test_ref/"
const GUARD := Vector3(-86, 0, -5)
const PUPPY := Vector3(70, 0, -5)
const PARRY_AT := Vector3(-64, 0, -5)
const ROW_Y := 660.0
const ROW_K := 2.0

var _music: P2Music
var _ui: CanvasLayer
var _row: Node2D
var _hud: Label
var _reduced := false
var _flash := true
var _shift := 0.0
var _fx: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_music = P2Music.new()
	_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	_music.setup(["scout", "scout"], "normal", "Master")
	add_child(_music)
	_music.start()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#11141d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.35
	sun.transform = Transform3D(Basis.looking_at(Vector3(0.3, -0.8, -0.5).normalized(), Vector3.UP), Vector3.ZERO)
	add_child(sun)
	# 바닥 · 뒷벽(건축 층 1): 순간 광원이 비추는 걸 보려고
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("#3a4150")
	grey.roughness = 0.9
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(520, 260)
	ground.material_override = grey
	ground.layers = 1
	add_child(ground)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	(wall.mesh as BoxMesh).size = Vector3(520, 160, 8)
	wall.position = Vector3(0, 80, -70)
	wall.material_override = grey
	wall.layers = 1
	add_child(wall)
	var cam := Camera3D.new()
	cam.fov = 35.0
	var p := deg_to_rad(22.0)
	var target := Vector3(0, 22, 0)
	cam.position = target + Vector3(0, sin(p), cos(p)) * 330.0
	add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true
	_actor3d("guardian.png", Vector2(31.5, 52), GUARD)
	_actor3d("puppy.png", Vector2(33, 52), PUPPY)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_row = Node2D.new()
	_ui.add_child(_row)
	_actor2d("guardian.png", Vector2(31.5, 52), GUARD)
	_actor2d("puppy.png", Vector2(33, 52), PUPPY)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_ui.add_child(_hud)


func _tex(file: String) -> Texture2D:
	return P2PxSheet._tex(REF + file)


func _actor3d(file: String, foot: Vector2, at: Vector3) -> void:
	var s := Sprite3D.new()
	s.texture = _tex(file)
	s.centered = false
	s.offset = Vector2(-foot.x, -(64.0 - foot.y))
	s.pixel_size = 1.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.layers = P2PxFx3D.LAYER_ACTORS
	s.position = at
	add_child(s)


# 2D 줄: 무대 x를 화면 가운데 기준 정수배로
func _row_at(at: Vector3) -> Vector2:
	return Vector2(640.0 + at.x * ROW_K, ROW_Y)


func _actor2d(file: String, foot: Vector2, at: Vector3) -> void:
	var s := Sprite2D.new()
	s.texture = _tex(file)
	s.centered = false
	s.offset = -foot
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = _row_at(at)
	s.scale = Vector2.ONE * ROW_K
	_row.add_child(s)


# 시험용 시계: 음악 시각 + 되감기 시험 이동량
func _clock() -> float:
	return _music.clock() + _shift


func _fire(name: String, at: Vector3, contact_at: float) -> void:
	var s := P2PxSheet.get_sheet(name)
	if s == null:
		return
	var f3 := P2PxFx3D.new()
	f3.light_flash = _flash
	f3.reduced = _reduced
	f3.position = at
	add_child(f3)
	f3.play(s, contact_at, _clock)
	var f2 := P2PxFx2D.new()
	f2.reduced = _reduced
	f2.position = _row_at(at)
	f2.scale = Vector2.ONE * ROW_K
	_row.add_child(f2)
	f2.play(s, contact_at, _clock)
	_fx.append_array([f3, f2])


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# 접촉은 지금부터 0.25초 뒤(입력 결과 · 피해 시점이라 치고), 그 앞 장(휘두름)은 미리 보인다
	var hit_at := _clock() + 0.25
	match k.keycode:
		KEY_1:
			_fire("slash_basic", GUARD, hit_at)
		KEY_2:
			_fire("hit_spark", PUPPY, hit_at)
		KEY_3:
			_fire("parry_perfect", PARRY_AT, hit_at)
		KEY_4:
			_fire("slash_basic", GUARD, hit_at)
			_fire("hit_spark", PUPPY, hit_at)
			_fire("parry_perfect", PARRY_AT, hit_at + _music.beat * 2.0)
		KEY_R:
			_reduced = not _reduced
			for f in _fx:
				if is_instance_valid(f):
					f.reduced = _reduced
		KEY_L:
			_flash = not _flash
		KEY_P:
			get_tree().paused = not get_tree().paused
		KEY_BRACKETLEFT:
			_shift -= 0.1
		KEY_BRACKETRIGHT:
			_shift += 0.1


func _process(_delta: float) -> void:
	_fx = _fx.filter(func(f): return is_instance_valid(f))
	_hud.text = "픽셀 효과 샘플 · 1 베기 · 2 맞는 순간 · 3 완벽 패링 · 4 이어서 · R 효과 줄이기 %s · L 순간 광원 %s · P 멈춤 %s · [ ] 되감기 %+.1f초\n음악 시각 %.2f · 위 3D(무대 1 = 원본 1px) · 아래 2D(정수 2배)" % [
		"켬" if _reduced else "끔", "켬" if _flash else "끔", "중" if get_tree().paused else "", _shift, _clock()]


# 닫힐 때 튼 음악을 멈춘다(재생 중인 채로 끝나면 종료 때 음악 조각이 정리되지 않는다)
func _exit_tree() -> void:
	if is_instance_valid(_music):
		for p in _music.find_children("*", "AudioStreamPlayer", true, false):
			(p as AudioStreamPlayer).stop()
