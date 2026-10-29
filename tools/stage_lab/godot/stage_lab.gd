extends Node2D

# 혼합 리듬 무대 실험(명세 CLAUDE_CLOUD_STAGE_01). 카드 고르기의 가까운 낮은 사선 → 막기의 높은 사선으로 한 번 넘어가며,
# 카드가 있던 가운데~아래 바닥을 리듬 수행 공간으로 쓸 수 있는지 A(간단한 2D 바닥 받침)와 B(3D 바닥 · 낮은 단차 · 빛 하나)로 비교한다.
# 음악 · 노트 판정은 본편 P2Music · P2NoteChart를 그대로 쓴다. A/B는 세계 · 빠르기 · 고리 마디 · 노트 배열 · 화면 자리 · 반경 · 판정 창 · 보정이 같다.
# 본편 시작 장면 · 자동 로드 · 세이브 · 전투 흐름은 건드리지 않는다(이 장면만 따로 실행)

const Space := preload("res://tools/stage_lab/godot/stage_space.gd")
const View2D := preload("res://tools/stage_lab/godot/stage_view_2d.gd")
const View3D := preload("res://tools/stage_lab/godot/stage_view_3d.gd")
const REF := "res://tools/stage_lab/godot/ref/"
# N1 = 척후 둘 → 계면 · 일반 구간 112BPM · 일반 등급 악보
const ROLES := ["scout", "scout"]
const WORLD := "gye"
const TIER := 0
# 판정 창: 세계 음악 전투 기본(본편 _ease_k 1 × 음악 1.5). A/B 같음
const EASE := 1.5
# 고르기 → 막기 구도 전환 시간. 악보 첫 cue(첫 마디 두 박 앞) 전에 끝나고 입력 중에는 움직이지 않는다
const TRANS := 0.55

var space := Space.new()
var mode := "B"
var section := "tap"
var _approach_k := 1.0
var _n_force := 0
var _music: P2Music
var _chart: P2NoteChart
var _v2: View2D
var _v3: View3D
var _ui: CanvasLayer
var _hud: Label
var _hand: Control
var _actors: Array = []
# 구도: u 0 = 고르기 · 1 = 막기. 음악 시계로 [t0, t1] 동안 from → to
var _u := 0.0
var _move := {}
var _state := "select"
var _slot_lock := -1
var _tally := {"perfect": 0, "good": 0, "miss": 0}
var _streak := 0
var _last := ""


func _ready() -> void:
	# 본편 전투와 같은 리듬 설정(보정 · 누르기 키 · 노트 속도 · 막기 음 크기)과 효과음 버스
	var rh := P2Ui.load_rhythm()
	P2NoteChart.offset = clampf(float(rh.offset_ms) / 1000.0, -0.08, 0.08)
	P2NoteChart.hit_keys = P2Ui.hit_keys_of(String(rh.keys))
	_approach_k = clampf(float(rh.approach), 0.7, 1.4)
	P2Beat.gain = clampf(float(rh.beat), 0.0, 1.0)
	P2BattleView._ensure_fx_bus()
	MusicManager.stop()
	# 첨부 참조(64×64): 발 기준점 = 맨 아래 불투명 줄 바로 밑 · 두 발 가운데
	_actors = [
		{"tex": _tex("guardian_reference.png"), "foot": Vector2(31.5, 52), "side": -1},
		{"tex": _tex("puppy_reference.png"), "foot": Vector2(33, 52), "side": 1},
	]
	var tile := _tile()
	space.fit(get_viewport_rect().size)
	_v3 = View3D.new()
	add_child(_v3)
	_v3.build(space, _actors, tile)
	_v2 = View2D.new()
	add_child(_v2)
	_v2.build(space, _actors, tile)
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_hand = _hand_slot()
	_ui.add_child(_hand)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color("#ece6d6"))
	_hud.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05))
	_hud.add_theme_constant_override("outline_size", 4)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	hud_layer.add_child(_hud)
	_music = P2Music.new()
	_music.setup(ROLES, "normal", P2BattleView.FX_BUS)
	add_child(_music)
	_music.start()
	get_viewport().size_changed.connect(_refit)
	_set_mode(mode)


func _tex(file: String) -> Texture2D:
	var path := REF + file
	if ResourceLoader.exists(path):
		return load(path)
	# 에디터가 아직 가져오지(import) 않았으면 PNG를 바로 읽는다
	return ImageTexture.create_from_image(Image.load_from_file(path))


# A/B 같은 바닥 타일(16px, 줄눈 한 칸): 원근이 읽히게 하는 시험용 무늬
func _tile() -> Texture2D:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2a2537"))
	for i in range(16):
		img.set_pixel(i, 0, Color("#383148"))
		img.set_pixel(0, i, Color("#383148"))
	img.set_pixel(8, 8, Color("#2f2a3e"))
	return ImageTexture.create_from_image(img)


# 카드 고르기 때 손패가 있던 자리(빈 카드 판 다섯 장): 막기로 넘어가며 아래로 빠져 그 바닥이 수행 공간이 된다
func _hand_slot() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in range(5):
		var c := ColorRect.new()
		c.color = Color(0.86, 0.82, 0.72, 0.16)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(c)
	var tag := Label.new()
	tag.text = "손패 자리"
	tag.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72, 0.6))
	root.add_child(tag)
	return root


func _layout_hand() -> void:
	var r := space.hand_rect()
	var w := r.size.x / 5.0
	var k := 0
	for c in _hand.get_children():
		if c is ColorRect:
			(c as ColorRect).position = Vector2(r.position.x + w * k + 6.0, r.position.y)
			(c as ColorRect).size = Vector2(w - 12.0, r.size.y)
			k += 1
		elif c is Label:
			(c as Label).position = r.position + Vector2(8, -24)
	_hand.position.y = (space.view.y - r.position.y + 8.0) * _ease(_u)
	_hand.modulate.a = 1.0 - _ease(_u)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _refit() -> void:
	space.fit(get_viewport_rect().size, _n_force)
	_v3.layout()
	_v2.layout()


func _set_mode(m: String) -> void:
	mode = m
	_v3.set_active(mode == "B")
	_v2.visible = mode == "A"


func _process(delta: float) -> void:
	if not _move.is_empty():
		var now := _music.clock()
		var k := clampf((now - float(_move.t0)) / maxf(float(_move.t1) - float(_move.t0), 0.001), 0.0, 1.0)
		_u = lerpf(float(_move.from), float(_move.to), k)
		if k >= 1.0:
			_move = {}
			if _state == "back":
				_state = "select"
			elif _state == "going":
				_state = "defend"
	space.set_frame(Space.SELECT, Space.DEFEND, _ease(_u))
	_v3.update(delta)
	_v2.update(delta, _v3.lamp_points())
	_layout_hand()
	_hud.text = _hud_text()


func _hud_text() -> String:
	var lines := [
		"혼합 무대 실험 · %s · 도트 ×%d (저해상도 %d×%d) · 구도 %s" % ["A 2D 바닥 받침" if mode == "A" else "B 3D 바닥 · 단차 · 빛 하나", space.n, space.low.x, space.low.y,
			{"select": "고르기", "going": "막기로 넘어감", "defend": "막기", "back": "고르기로"}[_state]],
		"구간 %s · 고리 마디 %s · 바닥 빛 %s" % ["N1 탭" if section == "tap" else "홀드(본편 '길게' 규칙)", str(_slot_lock) + " 고정" if _slot_lock >= 0 else "첫 막기 때 정함", "켬" if _v3.lamps_on else "끔"],
		"1 A · 2 B · Space 막기 · H 탭/홀드 · [ ] 도트 배율 · L 바닥 빛 · R 마디 다시 정함 · F7 자동 막기 · Esc 멈춤",
		"완벽 %d · 막음 %d · 놓침 %d %s" % [_tally.perfect, _tally.good, _tally.miss, _last],
	]
	return "\n".join(PackedStringArray(lines))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		if is_instance_valid(_chart):
			_chart.queue_free()
		return
	if _state != "select":
		return
	match k.keycode:
		KEY_1:
			_set_mode("A")
		KEY_2:
			_set_mode("B")
		KEY_SPACE:
			_start()
		KEY_H:
			section = "hold" if section == "tap" else "tap"
		KEY_L:
			_v3.lamps_on = not _v3.lamps_on
			_v2.lamps_on = _v3.lamps_on
		KEY_R:
			_slot_lock = -1
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			_n_force = clampi(space.n + (1 if k.keycode == KEY_BRACKETRIGHT else -1), 2, 6)
			_refit()


# 막기 시작: 다음 문장 첫머리(본편 P2Music.entry)에 첫 마디. A/B가 같은 노트가 되게 첫 막기의 고리 마디를 고정해 두고 그 마디를 기다린다.
# 구도 전환은 첫 cue 전에 끝나게 음악 시계에 맞춰 두고, 음악 진입(필인 · 비우는 박)은 본편 P2Music.enemy 그대로
func _start() -> void:
	var beat := _music.beat
	var ap := beat * 1.2 * _approach_k
	var at := _music.entry(0.25)
	var ns: Array = []
	for _try in range(8):
		var slot := _music.slot_of(at)
		var room := at - 2.0 * beat - _music.clock()
		if (_slot_lock < 0 or slot == _slot_lock) and room >= TRANS + 0.05:
			ns = _section_notes(slot)
			if at - _music.clock() >= _lead(ns, beat, ap):
				_slot_lock = slot
				break
		ns = []
		at += _music.bar * 2.0
	if ns.is_empty():
		return
	_tally = {"perfect": 0, "good": 0, "miss": 0}
	_streak = 0
	_last = ""
	_state = "going"
	var t1 := at - 2.0 * beat - 0.05
	_move = {"from": _u, "to": 1.0, "t0": t1 - TRANS, "t1": t1}
	_music.enemy(WORLD, at, [])
	_make_chart(ns, at, beat, ap)


# N1 한 공격의 노트: 고리 마디 slot부터 세 마디 계면 일반 악보 그대로(본편 _music_pattern과 같은 칸 · 같은 음, 척후는 특수 노트 없음).
# 홀드 구간은 같은 마디에 본편 고리 '길게' 규칙(마디마다 앞이 트인 첫 선율 음 · 한 박 · 그 안의 음은 누르는 동안 저절로)을 얹은 것
func _section_notes(slot: int) -> Array:
	var ns: Array = []
	var charts: Array = P2MusicMeta.WORLDS[WORLD].charts[TIER]
	for b in range(3):
		for n in charts[posmod(slot + b, P2MusicMeta.BARS)]:
			ns.append({"b": float(n[0]) + 4.0 * b, "semi": int(n[1]), "src": String(n[3]), "kind": "t", "hold": 0.0, "under": []})
	if section == "hold":
		for bar in range(3):
			for k in range(ns.size()):
				var a := float(ns[k].b)
				if floori(a / 4.0) != bar or not (String(ns[k].src) in ["lead", "counter"]) or (k > 0 and a - float(ns[k - 1].b) < 0.5) or a + 1.25 > 12.0:
					continue
				ns[k].kind = "h"
				ns[k].hold = 1.0
				while k + 1 < ns.size() and float(ns[k + 1].b) < a + 1.5:
					var u: Dictionary = ns.pop_at(k + 1)
					if float(u.b) < a + 0.99:
						(ns[k].under as Array).append([float(u.b) - a, int(u.semi)])
				break
	return ns


# 첫 노트들이 제때 보이려면 첫 박보다 몇 초 앞서 있어야 하는지(본편 _lead_need와 같음)
static func _lead(ns: Array, beat: float, ap: float) -> float:
	var need := 0.0
	for n in ns:
		need = maxf(need, ap - float(n.b) * beat)
	return need + 0.1


# 노트 자리: 본편 고리 배치 규칙(가로 = 마디 안 시각, 마디마다 왼→오 · 오→왼 번갈아 · 세로 = 음 높이)을 수행 공간 크기로. A/B 같은 화면 좌표
func _note_pos(n: Dictionary, lo: int, hi: int) -> Vector2:
	var r := space.play_rect()
	var b := float(n.b)
	var u := fposmod(b, 4.0) / 4.0
	if floori(b / 4.0) % 2 == 1:
		u = 1.0 - u
	var v := 0.5 if hi <= lo else 1.0 - float(int(n.semi) - lo) / float(hi - lo)
	return Vector2(r.position.x + r.size.x * (0.06 + 0.88 * u), r.position.y + r.size.y * (0.1 + 0.8 * v)).round()


func _make_chart(ns: Array, at: float, beat: float, ap: float) -> void:
	var origin := beat * 2.0
	var lo := 99
	var hi := -99
	for n in ns:
		lo = mini(lo, int(n.semi))
		hi = maxi(hi, int(n.semi))
	var notes: Array = []
	for i in range(ns.size()):
		var n: Dictionary = ns[i]
		notes.append({"pos": _note_pos(n, lo, hi), "at": origin + float(n.b) * beat, "approach": ap, "kind": String(n.kind), "hold": float(n.hold) * beat,
			"num": i + 1, "semi": int(n.semi), "under": (n.under as Array).map(func(u): return [float(u[0]) * beat, int(u[1])])})
	_chart = P2NoteChart.new()
	_chart.setup(notes, P2BattleView.NOTE_R, null, false)
	_chart.bounds = space.play_rect()
	_chart.ease(EASE)
	_chart.beat = beat
	_chart.arrange()
	_chart.follow(_music.clock, at - origin)
	_chart.struck.connect(_on_struck)
	_chart.judged.connect(_on_judged)
	_chart.cue.connect(_on_cue)
	_chart.tree_exited.connect(_on_chart_done)
	_ui.add_child(_chart)


# 막기 음: 본편 세계 음악 전투와 같음(쳐 낸 노트 박에 그 음, 길게 누르는 동안 덮인 음은 제 박에, 두 번의 뒤 타는 16분 칸)
func _on_struck(i: int, k: int) -> void:
	var n: Dictionary = _chart.notes[i]
	var under: Array = n.get("under", [])
	if k == 0:
		_music.tone(WORLD, int(n.semi), _chart.t0 + float(n.at))
	elif k <= under.size():
		_music.tone(WORLD, int(under[k - 1][1]), _chart.t0 + float(n.at) + float(under[k - 1][0]))
	else:
		_music.tone_again(WORLD, int(n.semi), _chart.t0 + float(n.at))


func _on_judged(_i: int, grade: String, dt: float) -> void:
	_tally[grade] = int(_tally.get(grade, 0)) + 1
	_last = "· 마지막 %s %+d ms" % [{"perfect": "완벽", "good": "막음", "miss": "놓침"}.get(grade, grade), roundi(dt * 1000.0)]
	if grade == "miss":
		_music.broke(_streak)
		_streak = 0
	else:
		_streak += 1


# 준비된 음악 사건(악보 반주 cue의 kick = 박)에 바닥 빛 한 묶음
func _on_cue(key: String, _step: int, _vol: float) -> void:
	if key == "kick":
		_v3.pulse()
		_v2.pulse()


# 악보가 끝나면 본편처럼 음악은 내 차례(잔잔하게)로, 구도는 고르기로 돌아온다
func _on_chart_done() -> void:
	if not is_inside_tree():
		return
	_chart = null
	_music.mine()
	_state = "back"
	var now := _music.clock()
	_move = {"from": _u, "to": 0.0, "t0": now, "t1": now + 0.6}
