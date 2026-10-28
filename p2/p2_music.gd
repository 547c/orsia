class_name P2Music
extends Node

# 전투 음악(일곱 세계). 세계마다 구운 8마디 겹 고리를 AudioStreamSynchronized 하나로 늘 함께 돌리고, 음량만 바꿔 세계와 겹을 고른다.
# 그 재생 위치가 박자 시계(clock)라 막기 악보도 이 시계로 가고, 적 공격 첫 노트는 반 마디 칸에 떨어진다(그 한 박 전에 새 세계 필인).
# 소리는 tools/music/bake.js로 굽는다(구운 세계는 P2MusicMeta). 겹 쌓기 · 부서짐 규칙은 tools/music 시험 페이지와 같다.
# 모든 시각 인자는 들리는 시각(clock 기준)이고, 안에서는 출력 지연을 더한 섞는 시각으로 바꿔 맞춘다

const DIR := "res://assets/music/"
const VOLUME_DB := -4.0
const TONE_DB := 2.0
const BPM_OF := {"normal": 112, "hard": 124, "extreme": 136}
const WORLD_OF := {
	"scout": "gye", "scout_h": "gye",
	"archer": "lyd", "archer_h": "lyd",
	"breaker": "tez", "guard_h": "tez", "elite": "tez", "maek_elite_low": "tez", "leader": "tez",
	"hexer": "bhv", "poisoner": "bhv",
	"shieldbearer": "hun", "banner": "hun", "boss": "hun", "hard_boss": "hun", "maek_noble_mid": "hun", "ruins_boss": "hun",
	"cannon": "mac", "curse": "mac",
	"x_boss": "core",
	"maek_summoner_low": "echo", "maek_spawn_low": "echo", "mimic_n": "echo", "mimic_h": "echo", "mimic_x": "echo",
}
# 연속으로 얹히는 겹(쌓이는 순서, 필요한 연속, 화면 이름). 놓치면 위에서부터 꺼진다
const PARTS := [["hat", 5, "하이햇"], ["perc", 5, "타악"], ["kick4", 10, "킥"], ["bass", 10, "베이스"], ["counter", 20, "맞받는 선율"], ["spark", 20, "반짝이"]]

var bpm := 112
var beat := 0.5
var bar := 2.0
var loop_len := 1.0
var fx_bus := "Master"
var earned := 0
var cut := 0
var cracks := 0
var run := 0
var _bus := ""
var _worlds: Array = []
var _world := ""
# mine 내 차례(받침 + 가벼운 타악 + 얇은 그루브: 킥 1·3 · 하이햇 · 앞 악기 작게) · enemy 적 차례 · rest 이긴 뒤 · off 진 뒤
var _mode := "mine"
var _next := ""
var _hush := false
var _sync: AudioStreamSynchronized
var _player: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _drone_v := 0.0
var _drone_want := [0.0, 1.0]
var _idx := {}
var _cur := {}
var _want := {}
var _loops := 0
var _last_pos := 0.0
var _mix := 0.0
var _events: Array = []
var _shots: Array = []
var _pool: Array[AudioStreamPlayer] = []
var _next_shot := 0
var _lp: AudioEffectLowPassFilter
var _fill := {}
var _end := {}
var _tones := {}
var _thud: AudioStream
var _crack: AudioStream
var _cad := 0
var _released := false


static func world_of(role: String) -> String:
	return String(WORLD_OF.get(role, ""))


static func _path(world: String, b: int, stem: String) -> String:
	return "%s%s/%d/%s.ogg" % [DIR, world, b, stem]


# 이 전투의 적이 모두 구운 세계에 속하고(세계 셋까지), 그 빠르기로 구웠을 때만. 점검 드라이버(빠르게 감기)와 --old-music은 예전 방식
static func supports(roles: Array, sector: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if String(a) == "--old-music" or String(a).begins_with("--p5-smoke"):
			return false
	var b := int(BPM_OF.get(sector, 112))
	var ws: Array = []
	for r in roles:
		var w := world_of(String(r))
		if w == "" or not P2MusicMeta.WORLDS.has(w) or not (P2MusicMeta.WORLDS[w].bpms as Array).has(b):
			return false
		if not ws.has(w):
			ws.append(w)
		if not ResourceLoader.exists(_path(w, b, "bed")):
			return false
	return not ws.is_empty() and ws.size() * P2MusicMeta.STEMS.size() <= AudioStreamSynchronized.MAX_STREAMS and ResourceLoader.exists(DIR + "common/drone.ogg")


func setup(roles: Array, sector: String, fx: String) -> void:
	bpm = int(BPM_OF.get(sector, 112))
	beat = 60.0 / float(bpm)
	bar = beat * 4.0
	loop_len = bar * float(P2MusicMeta.BARS)
	fx_bus = fx
	for r in roles:
		var w := world_of(String(r))
		if not _worlds.has(w):
			_worlds.append(w)
	_world = String(_worlds[0])
	_make_bus()
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = _worlds.size() * P2MusicMeta.STEMS.size()
	var i := 0
	for w in _worlds:
		for st in P2MusicMeta.STEMS:
			var s := load(_path(w, bpm, st)) as AudioStreamOggVorbis
			s.loop = true
			_sync.set_sync_stream(i, s)
			_sync.set_sync_stream_volume(i, -80.0)
			_idx["%s/%s" % [w, st]] = i
			_cur[i] = 0.0
			i += 1
		_fill[w] = load(_path(w, bpm, "fill"))
		_end[w] = load(_path(w, bpm, "end"))
		var bank := {}
		for kind in ["perfect", "block"]:
			var m := {}
			for semi in P2MusicMeta.WORLDS[w].tones:
				var sm := int(semi)
				m[sm] = load("%s%s/tone/%s_%s.ogg" % [DIR, w, kind, ("m%d" % -sm) if sm < 0 else str(sm)])
			bank[kind] = m
		_tones[w] = bank
	_thud = load(DIR + "common/thud.ogg")
	_crack = load(DIR + "common/crack.ogg")
	_player = AudioStreamPlayer.new()
	_player.stream = _sync
	_player.bus = _bus
	_player.volume_db = VOLUME_DB
	add_child(_player)
	var d := load(DIR + "common/drone.ogg") as AudioStreamOggVorbis
	d.loop = true
	_drone = AudioStreamPlayer.new()
	_drone.stream = d
	_drone.bus = _bus
	_drone.volume_db = -80.0
	add_child(_drone)
	for _k in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


# 전투 음악 버스(이 전투만): 휘청용 저역 통과 · 겹을 더해도 넘치지 않게 압축 · 한계. 음악 버스로 보내 음소거 설정을 따른다
func _make_bus() -> void:
	_bus = "P2Music%d" % get_instance_id()
	AudioServer.add_bus()
	var b := AudioServer.bus_count - 1
	AudioServer.set_bus_name(b, _bus)
	var music := String(MusicManager.MUSIC_BUS_NAME)
	AudioServer.set_bus_send(b, music if AudioServer.get_bus_index(music) >= 0 else "Master")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(b, _lp)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 2.5
	comp.attack_us = 12000.0
	comp.release_ms = 220.0
	AudioServer.add_bus_effect(b, comp)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(b, lim)


func start() -> void:
	_player.play()
	_drone.play()
	_mode = "mine"
	_retarget(0.8)


# ── 박자 시계 ──
# 섞인 위치(아직 스피커에 닿기 전) · 들리는 위치(clock)
func mixed() -> float:
	if _player == null or not _player.playing:
		return _mix
	var pos := _player.get_playback_position()
	var loops := _loops + (1 if pos < _last_pos - loop_len * 0.5 else 0)
	return maxf(_mix, loops * loop_len + pos + AudioServer.get_time_since_last_mix())


func clock() -> float:
	return mixed() - AudioServer.get_output_latency()


# 적 공격 첫 마디 첫 박 자리: 지금부터 lead초 넘게 남은 가장 가까운 마디 첫 박
func entry(lead: float) -> float:
	return ceilf((clock() + lead) / bar) * bar


func _process(delta: float) -> void:
	if _player == null:
		return
	var pos := _player.get_playback_position()
	if pos < _last_pos - loop_len * 0.5:
		_loops += 1
	_last_pos = pos
	_mix = maxf(_mix, _loops * loop_len + pos + AudioServer.get_time_since_last_mix())
	while not _events.is_empty() and float(_events[0].at) <= _mix + delta * 0.5:
		var ev: Dictionary = _events.pop_front()
		var fn: Callable = ev.fn
		fn.call()
	_poll_shots()
	for i in _want:
		var w: Array = _want[i]
		var c := float(_cur[i])
		if is_equal_approx(c, float(w[0])):
			continue
		c = move_toward(c, float(w[0]), delta / maxf(float(w[1]), 0.001))
		_cur[i] = c
		_sync.set_sync_stream_volume(i, linear_to_db(c) if c > 0.0001 else -80.0)
	if not is_equal_approx(_drone_v, float(_drone_want[0])):
		_drone_v = move_toward(_drone_v, float(_drone_want[0]), delta / maxf(float(_drone_want[1]), 0.001))
		if not _released:
			_drone.volume_db = VOLUME_DB + (linear_to_db(_drone_v) if _drone_v > 0.0001 else -80.0)


func _at(t: float, fn: Callable) -> void:
	_events.append({"at": t + AudioServer.get_output_latency(), "fn": fn})
	_events.sort_custom(func(a, b): return float(a.at) < float(b.at))


func _at_bar(fn: Callable) -> void:
	_at(ceilf(clock() / bar + 0.001) * bar, fn)


# 한 번 소리: 파일 안 anchor초 자리가 들리는 시각 t에 오게. 늦게 틀면 늦은 만큼 앞(무음 여백)을 건너뛴다
func _shot(s: AudioStream, anchor: float, t: float, db: float, bus: String, tag := "") -> void:
	if s == null:
		return
	_shots.append({"start": t + AudioServer.get_output_latency() - anchor, "s": s, "db": db, "bus": bus, "tag": tag})
	_poll_shots()


func _poll_shots() -> void:
	if _shots.is_empty() or _player == null:
		return
	var pos := _player.get_playback_position()
	var m := float(_loops + (1 if pos < _last_pos - loop_len * 0.5 else 0)) * loop_len + pos
	for k in range(_shots.size() - 1, -1, -1):
		var sh: Dictionary = _shots[k]
		if m < float(sh.start):
			continue
		_shots.remove_at(k)
		var skip := m - float(sh.start)
		var s: AudioStream = sh.s
		if skip >= s.get_length():
			continue
		var p := _pool[_next_shot]
		_next_shot = (_next_shot + 1) % _pool.size()
		p.stream = s
		p.bus = String(sh.bus)
		p.volume_db = float(sh.db)
		p.play(skip)


# ── 세계 · 겹 고르기 ──
func _parts_on() -> Array:
	var out: Array = []
	for k in range(earned - cut):
		out.append(String(PARTS[k][0]))
	return out


func _retarget(secs: float) -> void:
	var on := _parts_on()
	var lv := 3 if on.has("counter") or on.has("spark") else (2 if on.has("kick4") or on.has("bass") else (1 if not on.is_empty() else 0))
	for w in _worlds:
		var here: bool = w == _world
		var fight := here and _mode == "enemy"
		var calm := here and _mode == "mine" and not _hush
		var bed := 0.0
		if here:
			bed = float({"mine": 0.9, "enemy": 0.55 + 0.15 * lv, "rest": 0.6}.get(_mode, 0.0))
		_vol(w, "bed", bed, secs)
		_vol(w, "light", 1.0 if calm else 0.0, secs)
		_vol(w, "kick", 1.0 if fight and not _hush else (0.6 if calm else 0.0), secs)
		_vol(w, "lead", 1.0 if fight and not _hush else (0.35 if calm else 0.0), secs)
		for p in PARTS:
			var nm := String(p[0])
			_vol(w, nm, 1.0 if fight and not _hush and on.has(nm) else (0.5 if calm and nm == "hat" else 0.0), secs)
	var dv := 0.0
	match _mode:
		"mine":
			dv = 0.85
		"enemy":
			dv = 0.5 if on.has("bass") else 1.0
		"rest":
			dv = 0.8
	_drone_want = [dv, maxf(secs, 0.3)]


func _vol(w: String, stem: String, v: float, secs: float) -> void:
	var i := int(_idx.get("%s/%s" % [w, stem], -1))
	if i >= 0:
		_want[i] = [v, secs]


# 예약해 둔 넘어가기(와 아직 안 울린 필인 · 끝맺음)를 거둠
func _clear_events() -> void:
	_events.clear()
	_next = ""
	_hush = false
	_shots = _shots.filter(func(sh): return String(sh.tag) != "turn")


# 적 차례: entry(들리는 시각)에 그 세계가 들어온다. 세계가 바뀌거나 내 차례에서 넘어오면 한 박 전에 필인 + 차오름(그 박은 비움).
# 같은 세계가 이어지면(이미 그 세계로 가는 중이어도) 그대로 둔다
func enemy(world: String, at: float) -> void:
	if not _idx.has(world + "/bed") or _mode in ["rest", "off"]:
		return
	var going := _next if _next != "" else (_world if _mode == "enemy" else "")
	if world == going:
		return
	_clear_events()
	_next = world
	_shot(_fill.get(world), P2MusicMeta.PRE + beat, at, 0.0, _bus, "turn")
	_at(at - beat, func() -> void:
		_hush = true
		_retarget(0.04))
	_at(at, func() -> void:
		_world = world
		_mode = "enemy"
		_hush = false
		_next = ""
		_retarget(0.03))


# 내 차례: 다음 박에서 겹이 빠지고 받침 · 가벼운 타악 위에 얇은 그루브만
func mine() -> void:
	if _mode in ["mine", "rest", "off"]:
		return
	_clear_events()
	_at(ceilf(clock() / beat + 0.05) * beat, func() -> void:
		_mode = "mine"
		_hush = false
		_retarget(0.2))


# 막기 음 높이: 묶음(타격)마다 세계 동기를 따라가고 끝음은 솔 · 도를 번갈아(짧은 묶음은 동기 꼬리부터)
func pitches(world: String, groups: Array, count: int) -> Array:
	var out: Array = []
	out.resize(count)
	out.fill(0)
	if not P2MusicMeta.WORLDS.has(world):
		return out
	var m: Dictionary = P2MusicMeta.WORLDS[world]
	for g in groups:
		var ids: Array = g
		var motif: Array = m.motif_g if _cad % 2 == 0 else m.motif_c
		_cad += 1
		var body := motif.slice(0, motif.size() - 1)
		var n := ids.size()
		for k in range(n):
			var semi := int(motif.back()) if k == n - 1 else int(body[posmod(body.size() - (n - 1) + k, body.size())])
			if int(ids[k]) < count:
				out[int(ids[k])] = semi
	return out


# 긋기 점마다(내 차례): 지금 세계 막기 음을 아래부터 차례로
func step(n: int) -> void:
	if not P2MusicMeta.WORLDS.has(_world):
		return
	var ts: Array = P2MusicMeta.WORLDS[_world].tones
	tone(_world, int(ts[posmod(n, ts.size())]), "perfect", clock())


# 막기 판정 소리: 완벽은 온음, 막음은 작고 짧게(둘 다 일찍 눌렀으면 노트 박 at에 맞춰), 놓침은 음 없는 둔탁한 소리
func tone(world: String, semi: int, grade: String, at: float) -> void:
	var g := linear_to_db(maxf(P2Beat.gain, 0.001))
	if grade == "miss":
		_shot(_thud, P2MusicMeta.PRE, clock(), g, fx_bus)
		return
	var kind := "perfect" if grade == "perfect" else "block"
	var bank: Dictionary = (_tones.get(world, {}) as Dictionary).get(kind, {})
	var s: AudioStream = bank.get(semi, bank.get(0))
	_shot(s, P2MusicMeta.PRE, maxf(at, clock()), g + TONE_DB, fx_bus)


# 연속(전투 콤보)이 바뀜. 이으면 쌓기 · 회복(4번 연달아면 금이 아물고 꺼진 겹 하나가 다음 마디에 돌아옴).
# 끊기면 금: 처음엔 음악이 휘청만, 금 간 채 또 끊기면 맨 위 겹 하나가 테이프 멈추듯 처지며 꺼짐. 돌아온 · 꺼진 겹 이름을 돌려준다
func combo(ok: bool, before: int, now: int) -> Dictionary:
	var out := {}
	if _mode in ["rest", "off"]:
		return out
	if ok:
		var e := 0
		for p in PARTS:
			if now >= int(p[1]):
				e += 1
		if e > earned:
			earned = e
			_at_bar(func() -> void: _retarget(0.25))
		run += 1
		if run >= 4:
			cracks = 0
			if cut > 0:
				cut -= 1
				run = 0
				out["back"] = String(PARTS[earned - cut - 1][2])
				_at_bar(func() -> void: _retarget(0.3))
		return out
	var left := earned - cut
	run = 0
	cracks += 1
	if before >= 5:
		_shot(_crack, P2MusicMeta.PRE, clock(), 0.0, fx_bus)
	if cracks >= 2 and left > 0:
		cut += 1
		cracks = 0
		var p: Array = PARTS[earned - cut]
		_tape_stop([String(p[0])])
		out["cut"] = String(p[2])
	else:
		cracks = mini(cracks, 1)
		_stumble()
	return out


# 그 겹만 복제해 지금 자리에서 음이 처지며(재생 속도를 늦춤) 사라지게 하고, 원래 겹은 소리만 끈다(박은 그대로 맞물린 채)
func _tape_stop(stems: Array) -> void:
	for stem in stems:
		var i := int(_idx.get("%s/%s" % [_world, stem], -1))
		if i < 0 or float(_cur.get(i, 0.0)) < 0.01:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = _sync.get_sync_stream(i)
		p.bus = _bus
		p.volume_db = _player.volume_db + linear_to_db(float(_cur[i]))
		add_child(p)
		p.play(fmod(_player.get_playback_position(), loop_len))
		_cur[i] = 0.0
		_want[i] = [0.0, 0.01]
		_sync.set_sync_stream_volume(i, -80.0)
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "pitch_scale", 0.3, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "volume_db", p.volume_db - 30.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(p.queue_free)
	_retarget(0.05)


# 한 번 놓침: 음악 전체가 잠깐 먹먹해졌다 돌아옴(겹은 그대로)
func _stumble() -> void:
	var tw := create_tween()
	tw.tween_method(_set_cutoff, 14.3, 9.35, 0.05)
	tw.tween_method(_set_cutoff, 9.35, 14.3, 0.45)
	var tv := create_tween()
	tv.tween_property(_player, "volume_db", VOLUME_DB - 4.0, 0.04)
	tv.tween_property(_player, "volume_db", VOLUME_DB, 0.41)


func _set_cutoff(x: float) -> void:
	_lp.cutoff_hz = pow(2.0, x)


# 전투 끝: 이기면 다음 마디 첫 박에 끝맺음(솔 → 도)과 함께 리듬이 빠지고 받침만, 지면 모든 소리가 테이프 멈추듯 처진다
func finish(won: bool) -> void:
	_clear_events()
	if won:
		var t := ceilf((clock() + beat) / bar) * bar
		_shot(_end.get(_world), P2MusicMeta.PRE + beat, t, 0.0, _bus, "turn")
		_at(t, func() -> void:
			_mode = "rest"
			_retarget(0.25))
		return
	_tape_stop(P2MusicMeta.STEMS)
	_mode = "off"
	_retarget(0.3)
	_drone_want = [0.0, 2.0]


# 전투 화면이 닫힐 때: 지도 음악과 겹치게 천천히 줄이고 스스로 사라짐
func release(fade: float) -> void:
	if _released:
		return
	_released = true
	_clear_events()
	var tw := create_tween().set_parallel()
	tw.tween_property(_player, "volume_db", -60.0, fade)
	tw.tween_property(_drone, "volume_db", -60.0, fade)
	tw.chain().tween_callback(queue_free)


# 듣기 점검: F7로 자동 막기를 켜고 끔(악보가 박에 맞춰 저절로 완벽). 음악과 막기 음이 박에 붙는지 귀로 확인하는 용도
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F7:
		P2NoteChart.auto = not P2NoteChart.auto
		print("자동 막기: ", "켬" if P2NoteChart.auto else "끔")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		var ps: Array = [_player, _drone]
		ps.append_array(_pool)
		for p in ps:
			if p != null:
				(p as AudioStreamPlayer).stream_paused = what == NOTIFICATION_APPLICATION_FOCUS_OUT
	elif what == NOTIFICATION_PREDELETE:
		var b := AudioServer.get_bus_index(_bus)
		if b >= 0:
			AudioServer.remove_bus(b)
