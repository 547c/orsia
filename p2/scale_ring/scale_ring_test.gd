extends Control

# 음계 고리 시험 장면(본편 HUD · 에너지 구슬에는 아직 안 붙임). 실제 P2Music(계면 · 리디안 · 테제타)을 적 차례로 틀고,
# 그 마디 음악 악보(P2MusicMeta, 심층 등급)의 음을 제 박에 쳐 낸 것으로 고리에 넣는다(자동 완벽, 긴 음은 길게 누른 것으로).
# 1 계면 · 2 리디안 · 3 테제타: 음악이 다음 문장에서 그 세계로 넘어가고 고리는 필인 한 박 동안 모양을 바꾼다.
# 4~7 고리만 다른 세계(바이라브 · 헝가리 단조 · 기계 · 핵, 음악은 그대로) · + 겹 하나 더(전투 진행) · 크게(6배) · 작게(2배) 두 개

const ROLES := ["scout", "archer", "breaker"]
const TIER := 1

var _music: P2Music
var _rings: Array[P2ScaleRing] = []
var _world := "gye"
var _switch_at := -1.0
var _old := "gye"
var _next_bar := -1
var _queue: Array = []
var _progress := 0.0
var _hud: Label


func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1a1d29")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_music = P2Music.new()
	_music.setup(ROLES, "normal", "Master")
	add_child(_music)
	_music.start()
	for k in [6, 2]:
		var r := P2ScaleRing.new()
		r.pix = k
		r.position = Vector2(90, 110) if k == 6 else Vector2(560, 170)
		add_child(r)
		r.set_world("gye")
		_rings.append(r)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	add_child(_hud)
	_switch("gye")


# 음악까지 그 세계로: 다음 문장 첫머리에 들어가고(본편 P2Music.enemy, 그 한 박 전 필인), 고리는 필인 한 박 동안 바뀐다
func _switch(w: String) -> void:
	var at := _music.entry(0.25)
	_music.enemy(w, at, [])
	for r in _rings:
		r.set_world(w, at - _music.beat, _music.beat)
	_old = _world
	_world = w
	_switch_at = at


func _bar_world(t: float) -> String:
	return _world if _switch_at < 0.0 or t >= _switch_at - 0.001 else _old


func _process(_delta: float) -> void:
	var now := _music.clock()
	var bar := _music.bar
	# 앞으로 반 초 안에 시작하는 마디의 악보 음을 미리 줄 세운다
	if _next_bar < 0:
		_next_bar = ceili(now / bar)
	while _next_bar * bar <= now + 0.5:
		var t0 := _next_bar * bar
		var w := _bar_world(t0)
		var slot := _music.slot_of(t0)
		for n in (P2MusicMeta.WORLDS[w].charts[TIER][slot] as Array):
			var at := t0 + float(n[0]) * _music.beat
			_queue.append([at, int(n[1]), "hit"])
			if int(n[2]) >= 6:
				_queue.append([at, int(n[1]), "hold_on"])
				_queue.append([at + float(n[2]) / 4.0 * _music.beat, int(n[1]), "hold_off"])
		_next_bar += 1
	_queue.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	while not _queue.is_empty() and float(_queue[0][0]) <= now:
		var q: Array = _queue.pop_front()
		for r in _rings:
			match String(q[2]):
				"hit":
					r.note_hit(int(q[1]), "perfect", float(q[0]))
				"hold_on":
					r.hold(int(q[1]), true, float(q[0]))
				"hold_off":
					r.hold(int(q[1]), false, float(q[0]))
	for r in _rings:
		r.feed(now, _music.beat, bar, _music.earned)
	var d := P2ScaleRing.data()
	var w: Dictionary = d.worlds.get(_rings[0].world, {})
	_hud.text = "음계 고리 시안 · 지금 %s(%s) · 음악 시각 %.2f · 겹 %d\n1 계면 · 2 리디안 · 3 테제타(음악도 바뀜) · 4~7 고리만 바이라브 · 헝가리 단조 · 기계 · 핵 · + 겹 더하기" % [
		String(w.get("name", "")), String(w.get("where", "")), now, _music.earned]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1:
			_switch("gye")
		KEY_2:
			_switch("lyd")
		KEY_3:
			_switch("tez")
		KEY_4, KEY_5, KEY_6, KEY_7:
			var id := String(["bhv", "hun", "mac", "core"][k.keycode - KEY_4])
			for r in _rings:
				r.set_world(id, _music.clock(), _music.beat)
		KEY_EQUAL, KEY_KP_ADD:
			_progress = minf(1.0, _progress + 0.16)
			_music.progress(_progress)


# 닫힐 때 튼 음악을 멈춘다(재생 중인 채로 끝나면 종료 때 음악 조각이 정리되지 않는다)
func _exit_tree() -> void:
	if is_instance_valid(_music):
		for p in _music.find_children("*", "AudioStreamPlayer", true, false):
			(p as AudioStreamPlayer).stop()
