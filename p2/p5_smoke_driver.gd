extends Node
# 점검 드라이버. 명령줄에 --p5-smoke=<단계>가 있을 때만 RunService가 붙인다 (평소 플레이와 내보낸 게임에는 없음).
# 입력은 스크립트로 넣는 이벤트이고, 단계마다 새 프로필(점검용 슬롯)에서 메인 메뉴 → 원정 흐름으로 시작한다

var phase := ""
var out_dir := ""
var lines: Array[String] = []
var fails := 0
const PTR_DEVICE := 77
# 실제 게임은 이제 손맛 전투가 기본. 예전 점검(보상·저장·지도 등 체계)은 예전 전투 방식으로 돌리고, 손맛 점검은 저마다 켠다
const CLASSIC := {"parry": false, "slash": false, "juice": false}
var real_mouse := 0


func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device != PTR_DEVICE:
		real_mouse += 1


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--p5-quiet"):
		_quiet_window()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--p5-smoke="):
			phase = String(a).substr("--p5-smoke=".length())
		elif String(a).begins_with("--p5-out="):
			out_dir = String(a).substr("--p5-out=".length())
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("p5_smoke")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# 점검 프로필의 리듬 설정은 늘 기본에서 시작(이전 점검이 남긴 보정이 판정을 옮기지 않게), 전투 결과 판은 짧게.
	# 사람이 하는 준비된 시작(town_art_sample)은 실제 게임 그대로 둔다
	if phase != "town_art_sample":
		P2Ui.save_rhythm({"offset_ms": 0, "keys": "any", "approach": 1.0, "beat": 1.0, "practiced": true})
		P2Ui.set_hint("map_ring")
		P2Ui.set_hint("map_hub")
		P2BattleView.result_hold = 0.3
		P2BattleView.ease_force = 1.0
		P2BattleView.feel_force = CLASSIC
	Engine.time_scale = 2.0
	await get_tree().create_timer(1.0).timeout
	match phase:
		"scripts":
			run_scripts()
		"perf":
			await run_perf()
		"playcheck":
			await run_playcheck()
		"impact":
			await run_impact()
		"lower":
			await run_lower()
		"lower_elite":
			await run_lower_elite()
		"lower_hunter":
			await run_lower_cls("hunter", "quickshot", "shot:4")
		"lower_rune":
			await run_lower_cls("rune_caster", "bolt", "cast:3")
		"map":
			await run_map()
		"map_mid":
			await run_map_mid()
		"sd_look":
			await run_sd_look()
		"stage_clean":
			await run_stage_clean()
		"sd_battle":
			await run_sd_battle()
		"ui_kit":
			await run_ui_kit()
		"ui_mid":
			await run_ui_mid()
		"ui_drag":
			await run_ui_drag()
		"ui_look":
			await run_ui_look()
		"keys":
			await run_keys()
		"rhythm":
			await run_rhythm()
		"combo":
			await run_combo()
		"real":
			await run_real()
		"real_rm":
			# 사용자 설정처럼 흔들림 줄이기를 켠 채 같은 측정(점검 프로필에서만, 끝나면 되돌림)
			var st := P2Ui.load_settings()
			st.reduce_motion = true
			P2Ui.save_settings(st)
			await run_real()
			st.reduce_motion = false
			P2Ui.save_settings(st)
		"dmg_num":
			await run_dmg_num()
		"feel":
			await run_feel()
		"feel_elite":
			P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
			_fe_auto = true
			fe_autoloop()
			await run_lower_elite()
			if host() != null and host().battle_view != null:
				note("문장 등장 횟수 %s" % str(host().battle_view._phrase_seen))
			_fe_auto = false
			await flush_snaps()
		"feel_rune":
			await run_feel_rune()
		"feel_full":
			await run_feel_full()
		"first":
			await run_first()
		"extras":
			await run_extras()
		"ui_win":
			await run_ui_win()
		"relic_r":
			await run_relic_r()
		"diff":
			await run_diff()
		"settings":
			await run_settings()
		"prep":
			await run_prep()
		"affix":
			await run_affix()
		"records":
			await run_records()
		"practice":
			await run_practice()
		"daily":
			await run_daily()
		"perf_boss":
			await run_perf_boss()
		"fx":
			await run_fx()
		"fx_deep":
			await run_fx_deep()
		"level":
			await run_level()
		"arrow":
			await run_arrow()
		"genres":
			await run_genres()
		"sector":
			await run_sector()
		"combo_class":
			await run_combo_class()
		"combo_def":
			await run_combo_def()
		"pips_hover":
			await run_pips_hover()
		"zone_cue":
			await run_zone_cue()
		"rework":
			await run_rework()
		"elements":
			await run_elements()
		"show1":
			await run_show(["rune_caster", "hunter"])
		"show_hunter":
			await run_show(["hunter"])
		"show_rune":
			await run_show(["rune_caster"])
		"show_warden":
			await run_show(["warden"])
		"show_combo":
			await run_show(["combo"])
		"show_shaman":
			await run_show(["shaman"])
		"balance":
			await run_balance()
		"show_old":
			await run_show(["rune_caster", "warden", "hunter"], SHOW_OLD)
		"show_up":
			await run_show(["rune_caster", "combo", "shaman"], SHOW_UP)
		"show_react":
			await run_show(["rune_caster"], SHOW_REACT)
		"traits12":
			await run_traits12()
		"show_traits":
			await run_show_traits()
		"show_traits_rune":
			await run_show_traits(true)
		"show_ult_rune":
			await run_show_ult(["rune_caster"])
		"show_ult":
			await run_show_ult()
		"glyphs":
			await run_glyphs()
		"skillfx":
			await run_skillfx()
		"relic_drag":
			await run_relic_drag()
		"events":
			await run_events()
		"cards2":
			await run_cards2()
		"slabs":
			await run_slabs()
		"prep_juice":
			await run_prep_juice()
		"feel_lower":
			P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
			_fe_auto = "--feel-auto" in OS.get_cmdline_user_args()
			fe_autoloop()
			await run_lower()
			_fe_auto = false
			await flush_snaps()
	note("RESULT phase=%s fails=%d window=%s" % [phase, fails, str(DisplayServer.window_get_size())])
	var f := FileAccess.open(out_dir.path_join("smoke_%s.log" % phase), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	Engine.time_scale = 1.0
	get_tree().quit(1 if fails > 0 else 0)


# 모든 스크립트·장면을 한 번씩 불러 본다 (자동 로드가 있는 실제 실행 안에서)
func run_scripts() -> void:
	var stack := ["res://"]
	var n := 0
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			if not d.begins_with(".") and d not in ["_archive", "assets"]:
				stack.append(dir.path_join(d))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				var path := dir.path_join(f)
				var r := load(path)
				n += 1
				check(r != null and (not (r is GDScript) or (r as GDScript).can_instantiate()), "불러오기 " + path)
	note("스크립트·장면 %d개" % n)


func note(s: String) -> void:
	lines.append(s)
	print(s)


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	note(("ok   " if cond else "FAIL ") + label)


func wait_until(cond: Callable, timeout := 60.0) -> bool:
	var start := Time.get_ticks_msec()
	while not cond.call():
		await get_tree().process_frame
		if Time.get_ticks_msec() - start > int(timeout * 1000.0):
			return false
	return true


func secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	note("shot %s %dx%d" % [name, img.get_width(), img.get_height()])


func scene_path() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s != null else ""


func host() -> Node:
	var s := get_tree().current_scene
	return s if s != null and s.is_in_group("run_host") else null


func press(action: String, on: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = on
	Input.parse_input_event(ev)


func play_some(h: Node, max_actions: int) -> void:
	var v: P2BattleView = h.battle_view
	var b := v.battle
	var n := 0
	while is_instance_valid(v) and not b.battle_over and n < max_actions:
		if v.current_state() == "PLAYER":
			var choice := P2Bot.choose(b)
			if choice.is_empty():
				await v.end_turn()
			else:
				await v.play_card(choice[0], choice[1], choice[2] if choice.size() > 2 else {})
			n += 1
		else:
			await get_tree().process_frame


func finish_battle(h: Node) -> void:
	await play_some(h, 400)
	await wait_until(func(): return h.battle_view == null, 30.0)


func _pick_simple() -> Dictionary:
	var part := RunService.current_part()
	match String(part.type):
		"trait":
			return {"trait": String(part.traits[0])} if not (part.traits as Array).is_empty() else {}
		"upgrade":
			if (part.upgrades as Array).is_empty():
				return {"category": "gold"}
			var up := String(part.upgrades[0])
			return {"upgrade": up, "copy": RunModel.upgrade_candidates(RunService.run.deck, up)[0]}
		"relic":
			return {"skip": true}
		"upgrade_or_relic":
			if (part.upgrades as Array).is_empty():
				return {"category": "relic", "skip": true}
			var up2 := String(part.upgrades[0])
			return {"category": "upgrade", "upgrade": up2, "copy": RunModel.upgrade_candidates(RunService.run.deck, up2)[0]}
	return {"skip": true}


# ── fix1 점검 (준비된 고정 상태, 자동 입력) ─────────────────────────────────────────

func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func new_profile(slot: int) -> void:
	await wait_until(func(): return scene_path() == Flow.MENU_PATH, 20.0)
	SaveManager.begin_new_game(slot)
	SaveManager.commit("test profile")
	await secs(0.4)


func fixture(fn: Callable) -> bool:
	return RunService._tx("fixture", func(c, r, fl):
		fn.call(c, r, fl)
		return true)


# ── 점검: 스크립트로 넣는 포인터·키 이벤트 (OS 입력·사람 플레이가 아님, 1280×720 설계 좌표) ─────────
# 고정값(공개): 새 게임 프롤로그 생략·엘라라 만남, 원정 덱을 알려진 11장으로, 손패를 원하는 카드로 옮김(더미에서 이동),
# 동작마다 마나를 최대치로·적 체력을 최대치로 되돌림, 다섯 유물·구간 III 상태는 원정 기록을 직접 준비

# 점검 창은 사람이 볼 필요 없음: 주 모니터가 아닌 화면으로 옮기고, 초점을 받지 않고, 진짜 마우스는 통과시키고, 소리 끔.
# 점검 입력은 창 안에 직접 넣으므로(push_input) 영향 없음
func _quiet_window() -> void:
	var prim := DisplayServer.get_primary_screen()
	if DisplayServer.window_get_current_screen() == prim:
		for i in range(DisplayServer.get_screen_count()):
			if i != prim:
				DisplayServer.window_set_current_screen(i)
				break
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]))
	AudioServer.set_bus_mute(0, true)


func ptr_move(p: Vector2, mask := 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.device = PTR_DEVICE
	ev.position = p
	ev.global_position = p
	ev.button_mask = mask
	get_viewport().push_input(ev, true)


func ptr_button(p: Vector2, index: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.device = PTR_DEVICE
	ev.position = p
	ev.global_position = p
	ev.button_index = index
	ev.pressed = pressed
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	get_viewport().push_input(ev, true)


func ptr_click(p: Vector2) -> void:
	ptr_move(p)
	await frames(2)
	ptr_button(p, MOUSE_BUTTON_LEFT, true)
	await frames(1)
	ptr_button(p, MOUSE_BUTTON_LEFT, false)
	await frames(2)


func ptr_drag(from: Vector2, to: Vector2, release := true) -> void:
	ptr_move(from)
	await frames(2)
	ptr_button(from, MOUSE_BUTTON_LEFT, true)
	await frames(1)
	for k in range(1, 11):
		ptr_move(from.lerp(to, k / 10.0), MOUSE_BUTTON_MASK_LEFT)
		await frames(1)
	if release:
		ptr_button(to, MOUSE_BUTTON_LEFT, false)
		await frames(2)


func key_tap(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	get_viewport().push_input(ev, true)
	await frames(1)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up, true)
	await frames(1)


func live(v: P2BattleView) -> Dictionary:
	var b := v.battle
	return {"hand": P2Battle._uids(b.hand.cards), "mana": b.mana_now(), "hp": int(GameState.get_flag("player_hp")),
		"enemies": b.monsters.map(func(m): return m.hp), "block": b.get_pending_defense(), "played": b.cards_played_this_turn,
		"exhausted": (b.deck as P4Deck).exhausted.size(), "rev": SaveManager.revision}


func battle_ready(h: Node) -> bool:
	return await wait_until(func(): return h.battle_view != null and h.battle_view.current_state() == "PLAYER", 30.0)


# ── 점검: 전투 화면 구성 (스크립트 포인터·키 이벤트, 설계 좌표). 고정값은 UI1과 같은 방식으로 공개 ─────────

# ── 점검: 전투 마감 · 보상 · 원정 사물 (스크립트 포인터·키 이벤트, 설계 좌표). 고정값은 공개 ─────────────

# ── 글자·비용·입력·사건 순서 점검과 짧은 연출 기록 ───────────────────────────────
# 고정값(공개): 덱 구성 · 유물 · 적 체력 60 · 최대 마나 · 치명 난수 시작 상태. 입력은 모두 스크립트(push_input)

func av1_tough(v: P2BattleView, hp: int) -> void:
	for m in v.battle.monsters:
		m.max_hp = hp
		m.hp = hp
	v._sync_shown_from_battle()
	v._build_enemy_panels()
	if v._show != null:
		v._show.rebuild_enemies()
	v._render_all()


# 다음 공격 카드들의 치명 판정 순서를 미리 고른 시작 상태로 맞춘다 (규칙은 그대로, 난수 시작점만 고정값)
func av1_seed(b: P2Battle, pattern: Array, chance: int) -> String:
	var probe := RandomNumberGenerator.new()
	probe.seed = b.crit_rng.seed
	probe.state = b.crit_rng.state
	for i in range(20000):
		var st := probe.state
		var ok := true
		for want in pattern:
			if (probe.randi_range(1, 100) <= chance) != bool(want):
				ok = false
				break
		if ok:
			b.crit_rng.state = st
			return str(st)
		probe.state = st
		probe.randi_range(1, 100)
	return ""


# ── 수호기사 고해상도 배우 (대기 · 실제 베기 · 실제 방어 흡수 · 실제 반격) ─────────────────
# 고정값(공개): 덱 구성 · 적 체력 60(전투 시작 직후, 행동 전) · 손패. 피해·반격 사건은 실제 규칙이 만든 것만 씀. 입력은 스크립트

# ── 사냥꾼 고해상도 배우 (실제 속도 Engine.time_scale 1) ─────────────────────────────
# 고정값(공개): 직업 사냥꾼(준비 창이 쓰는 campaign class_id 칸), 덱 구성, 행동 전 적 체력 60 · 최대 마나 9. 사건은 실제 규칙 결과만. 입력은 스크립트

# 행동 전 고정값: 마나를 직업 최대치까지만 채운다 (행동 중에는 바꾸지 않음)
func c4_mana(v: P2BattleView) -> void:
	GameState.set_flag("player_mana", v.battle.max_mana)
	v._render_all()
	v._refresh_card_states()


# ── 수호기사 베기 파동 (실제 속도) ─────────────────────────────────────────────
# 고정값(공개): 수호기사 덱 구성(사본 한도 안), 행동 전 적 체력 60, 손패 [베기 · 가르기 베기(강화) · 마력탄], 행동 전 마나 = 직업 최대치. 입력은 스크립트

# ── 세 직업 숨쉬기 대기 · 피격 · 막기/반격 · 쓰러짐 · 그림자/머리 위 · 초상 · 직업별 공격 하나 (실제 속도) ──────────
# 고정값(공개): 직업(준비 창과 같은 거래), 덱 구성(사본 한도 안), 행동 전 적 체력 60, 손패, 행동 전 마나 = 직업 최대치,
# 쓰러짐 확인은 적 단계 전에 주인공 체력을 낮춤(행동 전). 입력은 스크립트

# ── 수호기사 숨쉬기 대기 · 수호기사/사냥꾼 마법 시전 (실제 속도) ─────────────────────────
# 고정값(공개): 직업(준비 창과 같은 거래), 덱 구성(사본 한도 안), 행동 전 적 체력 60, 손패, 행동 전 마나 = 직업 최대치. 입력은 스크립트

# ── 수호기사 검날 잔상 · 실제 접촉 · 반응 (실제 속도) ─────────────────────────────────
# 고정값(공개): 수호기사(준비 창과 같은 거래), 덱 구성(사본 한도 안), 행동 전 적 체력 60, 손패, 행동 전 마나 = 직업 최대치. 입력은 스크립트

# ── 입력 확인 · 접촉 한 번 · 무게 · 막기/일부 막기 · 처치/쓰러짐 · 저장 경계 (실제 속도) ─────────────────────
# 고정값(공개): 직업(준비 창과 같은 거래), 덱 구성(사본 한도 안), 행동 전 적 체력 60, 손패, 행동 전 마나 = 직업 최대치,
# 잘못된 입력 확인용 마나 0, 처치 확인용 적 체력 3, 쓰러짐 확인용 주인공 체력 2 — 모두 행동 전에만. 입력은 스크립트

# ── N1 앞쪽 척후병 한 명의 맥(Maek) 대기 흐름 (실제 속도) ─────────────────────────────
# 고정값(공개): 새 게임 프롤로그 생략(seen_opening·met_elara), 직업·덱·체력 변경 없음. 처치 확인 차례에만 손패(베기 셋)와 마나 = 최대치.
# 일시정지는 게임 트리 멈춤(저장 창·일시정지 메뉴와 같은 방식)으로, 흔들림 줄이기는 기존 설정 값으로. 입력은 스크립트

func e7_start(slot: int) -> Node:
	await new_profile(slot)
	check(SaveManager.commit("new game"), "슬롯 %d 새 게임" % slot)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	h._on_engage("n1")
	check(await h.engage_confirm("n1"), "N1 전투 (척후 둘)")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	await wait_until(func(): return v.prompt_text() == "" or v._prompt_close.visible, 2.0)
	if v._prompt_close.visible:
		v._prompt_close.pressed.emit()
	return h


# ── 같은 맥 척후병(N1 앞쪽)의 공격·피격 (실제 속도) ─────────────────────────────
# 고정값(공개): 새 게임 프롤로그 생략, 기본 직업(수호기사)·기본 덱 그대로. 각 차례 시작에만 손패(덱에 있는 실제 카드)와 마나 = 최대치.
# 체력·피해는 바꾸지 않음. 일시정지는 게임 트리 멈춤으로 짧게, 흔들림 줄이기는 기존 설정 값. 입력은 스크립트

# ── 강약 대비 연출 실험 (실제 속도) ─────────────────────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 기본 직업 수호기사 · 원정 출발 뒤 기존 강화 검사 함수(_apply_upgrade)로 베기 한 장을 가르기로,
# 기존 카드 추가 함수(_add_card)로 마력탄 한 장 추가(덱 규칙 검사 그대로) · 각 차례 시작 전에만 손패·마나(최대치).
# 점검(av7)만: 전투 시작 직후 적 체력 60(여러 차례 비교용, 행동 전). 입력은 스크립트

func av7_hand(v: P2BattleView, kinds: Array) -> void:
	var b := v.battle
	var want: Array = []
	for k in kinds:
		var parts := String(k).split(":")
		for src in [b.hand.cards, b.deck.draw_pile, b.deck.discard_pile]:
			var hit: Card = null
			for c in src:
				if not want.has(c) and P2Catalog.kind_of(c) == parts[0] and P2Catalog.upgrade_of(c) == (parts[1] if parts.size() > 1 else ""):
					hit = c
					break
			if hit != null:
				want.append(hit)
				break
	for c in b.hand.cards.duplicate():
		if not want.has(c):
			b.hand.cards.erase(c)
			b.deck.draw_pile.append(c)
	for c in want:
		b.deck.draw_pile.erase(c)
		b.deck.discard_pile.erase(c)
		if not b.hand.cards.has(c):
			b.hand.cards.append(c)
	v._build_hand(false)
	c4_mana(v)
	v._refresh_card_states()
	check(RunService.commit_battle("fixture") and want.size() == kinds.size(), "고정값 손패 %s · 마나 최대 (체력 그대로)" % str(kinds))
	await frames(3)


func av7_card(v: P2BattleView, spec: String) -> Card:
	var parts := spec.split(":")
	for c in v.battle.hand.cards:
		if P2Catalog.kind_of(c) == parts[0] and P2Catalog.upgrade_of(c) == (parts[1] if parts.size() > 1 else ""):
			return c
	return null


# 저장(PNG 쓰기)이 게임 루프를 막아 연출 시간을 흐트러뜨리지 않도록, 동작 중에는 그린 화면만 받아 두고 끝난 뒤 한꺼번에 쓴다
var _snaps := {}


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	_snaps[name] = get_viewport().get_texture().get_image()


func flush_snaps() -> void:
	for k in _snaps:
		(_snaps[k] as Image).save_png(out_dir.path_join(String(k) + ".png"))
	_snaps.clear()


# ── 하급(N1 뒤쪽 척후병) · 상급(X1 철갑 수비병) 맥 적 연결 (실제 속도) ─────────────────────
# 고정값(공개): 새 게임 프롤로그 생략, 기본 직업·기본 덱. 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치.
# 상급: 원정 출발 뒤 기존 점검과 같은 방식으로 구간 III(익스트림) 지형·특성 2개로 바로 옮김(구간 I·II 진행 생략).
# 상급 처치 확인 차례에만 행동 전 철갑 수비병 체력을 2로(선언, 균형 근거 아님). 입력은 스크립트

# ── 방패 강타 · 직업별 휩쓸기 · 뒤쪽 표적 접근/접촉 (실제 속도) ─────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 직업(준비 창과 같은 거래) · 원정 출발 뒤 기존 덱 규칙 함수(_add_card)로 휩쓸기 1장 추가 · N1.
# 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 적·주인공 체력은 바꾸지 않음. 입력은 스크립트

# ── 구간 I 소환사 보스 (실제 속도) ─────────────────────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 기본 직업(수호기사)·기본 덱 · 원정 출발 뒤 구간 I 필수 전투 N1–N4를 이긴 것으로 표시(진행 생략) → 실제 구간 I 보스.
# 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 마지막 처치 차례에만 행동 전 소환사 체력 5(선언). 입력은 스크립트

# ── 하급(N2 사수)·중급(샘플 전용) 맥 사수 (실제 속도) ─────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 기본 수호기사·기본 덱. 하급: 원정 출발 뒤 N1을 이긴 것으로 표시 → 실제 N2.
# 중급: 원정 출발 뒤 구간 III(익스트림)로 옮기고(구간 I·II 생략, 특성 2) 이 프로세스에서만 심층 사수 그림을 중급 사수로 바꿔 X2를 보여 줌(캠페인 배치는 그대로).
# 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 쓰러짐 확인 차례에만 행동 전 사수 체력 3(선언). 입력은 스크립트

func e19_ready(h: Node) -> Node:
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	await wait_until(func(): return v.prompt_text() == "" or v._prompt_close.visible, 2.0)
	if v._prompt_close.visible:
		v._prompt_close.pressed.emit()
	return h


# ── FIX_MELEE_PASS_01: 뒤쪽 대상 근접 = 바닥 줄을 따라 곧게 + 겹친 다른 몸만 잠깐 흐림 (실제 속도) ──────────────
# 준비(공개): CHAR8과 같음 — 새 게임 프롤로그 생략 · 기본 수호기사 · 기존 덱 규칙으로 휩쓸기 1장 추가 · N1(앞 = 중급 맥, 뒤 = 하급 맥).
# 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 적·주인공 체력은 바꾸지 않음. 입력은 스크립트.
# 3인 확인(fixmelee3): 구간 III로 옮겨(구간 I·II 생략, 특성 2, X1 이긴 것으로) 기존 X2 편성(기수·심층 사수·척후병)을 그대로 씀

# ── N2 하급 맥 방패병 — 방패 있음/없음 대기·공격·피격, 흡수·놓침 (실제 속도) ─────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 직업(기본 수호기사, 연타 사례만 사냥꾼: 준비 창과 같은 거래) · 기본 덱 · 원정 출발 뒤 N1을 이긴 것으로 표시 → 실제 N2.
# 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 치명 우선순위 사례(enemy25f)만 행동 전 방패병 체력 4(선언, 방패 8 그대로). 입력은 스크립트

# 지금 점검하는 방패병 그림 (ENEMY28 단계만 중층으로 바꿈)
var e25_key := "maek_shield_early"


func e25_start(slot: int, cls := "warden") -> Node:
	await new_profile(slot)
	check(SaveManager.commit("new game"), "슬롯 %d 새 게임" % slot)
	if cls != "warden":
		check(await RunService.commit_profile("class", func(c, r, f):
			if not r.is_empty() or not f.is_empty():
				return false
			c.combat.class_id = cls
			P5Campaign.refresh_vitals(c)
			return true), "직업 %s (준비 창과 같은 거래)" % cls)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		if not (r.defeated as Array).has("n1"):
			r.defeated.append("n1")), "준비: N1 이긴 것으로 (진행 생략)")
	h._on_engage("n2")
	check(await h.engage_confirm("n2"), "N2 전투 (방패병 + 하급 사수)")
	h = await e19_ready(h)
	Engine.time_scale = 1.0
	await secs(0.6)
	return h


# ── H1a 중층 맥 방패병 — ENEMY25 상태 표시 재사용 (실제 속도) ─────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 기본 수호기사·기본 덱(구간 I 보상·강화 없음) · 원정 출발 뒤 구간 I(N1–N4·보스)을 이긴 것으로 표시하고 정산 금화 13·경험치 20(진행 생략),
# 실제 계속 거래로 특성 후보 첫째를 골라 구간 II 진입 → 실제 경로 A 확정 → H1a(방패병 + 기수). 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 입력은 스크립트

func e28_start(slot: int) -> Node:
	e25_key = "maek_shield_mid"
	await new_profile(slot)
	check(SaveManager.commit("new game"), "슬롯 %d 새 게임" % slot)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		for id in ["n1", "n2", "n3", "n4", "boss"]:
			if not (r.defeated as Array).has(id):
				r.defeated.append(id)
		r.banked["normal"] = {"sector": "normal", "gold": 13, "xp": 20, "spent": 0, "bounty": {}, "level_before": 1, "level_after": 1}
		r.gold = 0
		r.xp = 0
		r.trait_offer = RunModel.trait_offer(r)
		r.phase = "sector_choice"), "준비: 구간 I 이긴 것으로 표시·정산 (진행 생략)")
	h.show_sector_choice()
	await secs(0.3)
	h.show_trait_choice()
	await secs(0.3)
	var offer: Array = RunService.run.trait_offer
	var cont: bool = await h.choose_continue(String(offer[0]))
	check(cont and String(RunService.run.sector) == "hard" and (RunService.run.traits as Array).size() == 1, "실제 계속 거래: 구간 II, 특성 %s" % String(offer[0]))
	await secs(0.5)
	h.dismiss_notices()
	check(RunService.commit_route("a"), "실제 경로 A 확정 (H1a 쪽)")
	h._on_engage("h1a")
	check(await h.engage_confirm("h1a"), "H1a 전투 (방패병 + 기수)")
	h = await e19_ready(h)
	Engine.time_scale = 1.0
	await secs(0.6)
	return h


# ── 구간 I 선택 정예 맥 거완 — 직접 타격 3번으로 강타 14 → 6 (실제 속도) ─────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 기본 수호기사·기본 덱 · 원정 출발 뒤 N1·N2를 이긴 것으로 표시(선택 전투 입장 조건, 진행 생략) → 실제 선택 정예(맥 거완 + 사수).
# 각 차례 시작 전 손패(덱의 실제 카드)·마나 최대치. 적·주인공 체력과 피해는 바꾸지 않는다. 입력은 스크립트

func e31_start(slot: int) -> Node:
	await new_profile(slot)
	check(SaveManager.commit("new game"), "슬롯 %d 새 게임" % slot)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	var rolled := String((RunService.run.layout.encounters.elite as Dictionary).get("kind", "elite"))
	check(fixture(func(_c, r, _f):
		for id in ["n1", "n2"]:
			if not (r.defeated as Array).has(id):
				r.defeated.append(id)
		# 구간 I 선택 전투는 기존 규칙대로 정예/미믹 반반. 이번 원정이 미믹으로 나왔으면 정예 쪽으로 고정(편성 내용은 그대로)
		var e: Dictionary = r.layout.encounters.elite
		e["group"] = "elite"
		e["kind"] = "elite"
		r.layout.groups["elite"] = "elite"), "준비: N1·N2 이긴 것으로 (선택 전투 입장 조건, 진행 생략) · 선택 전투 종류 정예%s" % (" (원래 미믹 → 정예로 고정)" if rolled != "elite" else " (원래도 정예)"))
	h._on_engage("elite")
	check(await h.engage_confirm("elite"), "선택 정예 전투 (맥 거완 + 사수)")
	h = await e19_ready(h)
	Engine.time_scale = 1.0
	await secs(0.6)
	return h


# ── N1 척후 둘 · N3 뒤쪽 척후 = 하급 맥 (준비: 프롤로그 생략, N3는 N1·N2 이긴 것으로) ──

func e33_n3_start(slot: int) -> Node:
	await new_profile(slot)
	check(SaveManager.commit("new game"), "슬롯 %d 새 게임" % slot)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		for id in ["n1", "n2"]:
			if not (r.defeated as Array).has(id):
				r.defeated.append(id)), "준비: N1·N2 이긴 것으로 (진행 생략)")
	h._on_engage("n3")
	check(await h.engage_confirm("n3"), "N3 전투 (기수 + 척후)")
	return await e19_ready(h)


# ── 구간 II 보스 맥 귀족 — 공명·봉인 (실제 속도) ─────────────────────────────
# 준비(공개): 새 게임 프롤로그 생략 · 기본 덱(직업은 단계마다 표기) · 구간 I 이긴 것으로 표시·정산 → 실제 계속(특성 후보 첫째) → 실제 경로 A
# → H1a·H2 이긴 것으로 표시 → 실제 구간 II 보스 시작. 손패는 차례 시작 뒤 행동 전에만 덱의 실제 카드로 맞추고, 봉인된 카드는 그대로 둔다

# ── FIX_COMBAT_TEXT_01: '기수 지원' 글자가 머리 위 칸(예고·이름·체력·상태 줄)과 겹치지 않는지 — N3·H1a 적 단계 한 번씩 ──

# ── N3 기수 0번 = 하급 맥 지원술사 (준비: e33_n3_start, 손패는 차례 시작 뒤 덱의 실제 카드로) ──

# ── N4 주술사 0번 = 하급 맥 주술사 (준비: 프롤로그 생략, N1–N3 이긴 것으로, 손패는 차례 시작 뒤 덱의 실제 카드로) ──

# 동작이 끝날 때까지 매 프레임: 주인공 자세 순서, 본 배율·필터(옛 외형으로 돌아가면 다른 값), 실제/표시 사건 수, 체력이 바뀐 시각
func wc_watch(v: P2BattleView, start: Callable, until: Callable, limit := 5.0, stills := {}) -> Dictionary:
	var p := v._player
	var o := {"poses": [], "scales": {}, "linear": 0, "foreign": [], "ms": {}, "hp_ms": -1}
	var n_hit := v.get_display_log().filter(func(e): return String(e.kind) in ["hit", "enemy_hit", "counter"]).size()
	var ev0: int = v.battle.events.size()
	var hp0 := [v.enemy_hp_text(0), v.enemy_hp_text(1)]
	var t0 := Time.get_ticks_msec()
	start.call()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0) and is_instance_valid(v):
		await get_tree().process_frame
		var tag := "%s:%d" % [p.animation, p.frame]
		if (o.poses as Array).is_empty() or (o.poses as Array).back() != tag:
			(o.poses as Array).append(tag)
			if not (o.ms as Dictionary).has(tag):
				o.ms[tag] = Time.get_ticks_msec()
				if stills.has(tag):
					await snap(String(stills[tag]))
		o.scales[snappedf(p.scale.x, 0.0001)] = true
		if p.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			o.linear += 1
		if not P2BattleView.WARDEN_ANIMS.has(String(p.animation)):
			(o.foreign as Array).append(tag)
		if int(o.hp_ms) < 0 and [v.enemy_hp_text(0), v.enemy_hp_text(1)] != hp0:
			o.hp_ms = Time.get_ticks_msec()
		if Time.get_ticks_msec() - t0 > 300 and until.call():
			break
	o["shown"] = v.get_display_log().filter(func(e): return String(e.kind) in ["hit", "enemy_hit", "counter"]).size() - n_hit
	o["real"] = v.battle.events.size() - ev0
	return o


func wc_card(v: P2BattleView, spec: String, target: int, stills := {}) -> Dictionary:
	var c := av7_card(v, spec)
	var o := await wc_watch(v, func(): v.play_card(c, target), func(): return v.current_state() == "PLAYER" and v._player.animation == "idle", 5.0, stills)
	var hits := v.battle.events.filter(func(e): return String(e.kind) == "hit")
	o["hits"] = hits.size()
	note("%s → %d: 자세 %s · 배율 %s · 선형 %d · 옛 동작 %s · 실제 타격 %d / 표시 %d" % [spec, target, str((o.poses as Array).slice(0, 12)), str((o.scales as Dictionary).keys()), int(o.linear), str(o.foreign), int(o.hits), int(o.shown)])
	return o


# PROJECT_HEALTH_01: 같은 짧은 경로(메인 메뉴 대기 → N1 대기 → 첫 베기)의 성능 기록. 측정 구간에는 캡처·파일 쓰기를 넣지 않는다
func perf_idle(sec: float) -> Dictionary:
	var mons := {"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, "objects_drawn": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME, "primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME}
	var sums := {"draw_calls": 0.0, "objects_drawn": 0.0, "primitives": 0.0}
	var n := 0
	var worst := 0.0
	var tp := 0.0
	var tp_max := 0.0
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var prev := t0
	while prev - t0 < int(sec * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - prev) / 1000.0)
		prev = now
		n += 1
		var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		tp += p
		tp_max = maxf(tp_max, p)
		for k in mons:
			sums[k] += Performance.get_monitor(mons[k])
	var dur := (prev - t0) / 1000000.0
	var mib := 1048576.0
	var o := {"frames": n, "fps": n / dur, "frame_ms_avg": dur * 1000.0 / n, "frame_ms_max": worst, "time_process_ms_avg": tp / n, "time_process_ms_max": tp_max,
		"video_mem_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mib, "texture_mem_mib": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mib,
		"buffer_mem_mib": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mib, "static_mem_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / mib,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"window": str(DisplayServer.window_get_size())}
	for k in mons:
		o[k] = sums[k] / n
	return o


# 첫 베기: 카드 실행 호출 → 몸이 움직이기까지, 체력이 바뀌기까지, 그 사이 가장 긴 프레임
func perf_slash(v: P2BattleView) -> Dictionary:
	var p := v._player
	var c := av7_card(v, "slash")
	var hp0 := v.enemy_hp_text(0)
	var worst := 0.0
	var react := -1.0
	var hit := -1.0
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var prev := t0
	v.play_card(c, 0)
	while prev - t0 < 4000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - prev) / 1000.0)
		prev = now
		if react < 0.0 and p.animation != "idle":
			react = (now - t0) / 1000.0
		if hit < 0.0 and v.enemy_hp_text(0) != hp0:
			hit = (now - t0) / 1000.0
		if now - t0 > 300000 and v.current_state() == "PLAYER" and p.animation == "idle":
			break
	return {"react_ms": react, "hit_ms": hit, "total_ms": (prev - t0) / 1000.0, "frame_ms_max": worst}


func run_perf() -> void:
	var out := {"build": {"debug": OS.is_debug_build(), "vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"adapter": RenderingServer.get_video_adapter_name(), "method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "window_mode": DisplayServer.window_get_mode()}}
	await new_profile(241)
	Engine.time_scale = 1.0
	await secs(2.0)
	out["menu_idle"] = await perf_idle(5.0)
	check(SaveManager.commit("perf"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	var t_e := Time.get_ticks_msec()
	h._on_engage("n1")
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	out["n1_enter_ms"] = Time.get_ticks_msec() - t_e
	var v: P2BattleView = h.battle_view
	await wait_until(func(): return v.prompt_text() == "" or v._prompt_close.visible, 2.0)
	if v._prompt_close.visible:
		v._prompt_close.pressed.emit()
	await secs(1.5)
	out["n1_idle"] = await perf_idle(5.0)
	await av7_hand(v, ["slash", "guard"])
	out["first_slash"] = await perf_slash(v)
	check(float(out.first_slash.hit_ms) > 0.0 and v._player.position == Vector2(v._home_x, P2BattleView.FEET_Y), "N1 베기: 피해 표시 · 집 위치 복귀")
	await v.play_card(av7_card(v, "guard"), -1)
	await wait_until(func(): return v.current_state() == "PLAYER" and v._player.animation == "idle", 3.0)
	var e := await wc_watch(v, func(): v.end_turn(), func(): return v.current_state() == "PLAYER", 12.0)
	check((e.poses as Array).has("block:3") and int(e.shown) >= 1 and v.reconcile_fixes == 0, "수호 뒤 적 단계: 방어 동작 · 타격 표시 · 사후 보정 0")
	for k in ["menu_idle", "n1_idle"]:
		var s: Dictionary = out[k]
		note("%s: FPS %.1f · 프레임 평균 %.2fms / 최장 %.2fms · TIME_PROCESS 평균 %.3fms · 그리기 호출 %.0f · 영상 메모리 %.1fMiB · 텍스처 %.1fMiB · 노드 %d · 창 %s" % [k, float(s.fps), float(s.frame_ms_avg), float(s.frame_ms_max),
			float(s.time_process_ms_avg), float(s.draw_calls), float(s.video_mem_mib), float(s.texture_mem_mib), int(s.nodes), String(s.window)])
	note("N1 진입 %dms · 첫 베기: 반응 %.1fms · 피해 표시 %.1fms · 전체 %.1fms · 최장 프레임 %.2fms" % [int(out.n1_enter_ms), float(out.first_slash.react_ms), float(out.first_slash.hit_ms), float(out.first_slash.total_ms), float(out.first_slash.frame_ms_max)])
	var f := FileAccess.open(out_dir.path_join("perf.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()


# 플레이 전 기능 점검: 정상 손패·체력으로 구간 I을 N1부터 보스까지 봇이 한 번 진행 (스크립트 오류·표시 불일치만 본다, 재미·체감 판단 아님)
func run_playcheck() -> void:
	await new_profile(251)
	check(SaveManager.commit("playcheck"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	for id in ["n1", "n2", "n3", "n4", "boss"]:
		h.dismiss_notices()
		h._on_engage(id)
		if not await h.engage_confirm(id):
			check(false, "%s 전투 시작" % id)
			break
		check(await battle_ready(h), "%s 차례" % id)
		var v: P2BattleView = h.battle_view
		var names := v.battle.monsters.map(func(m): return m.display_name)
		var look := [String(v._stage.get_meta("backdrop")), snappedf(v._body_h, 0.1), String(v._player.sprite_frames.get_frame_texture("idle", 0).resource_path).get_file()]
		var hp0 := int(GameState.get_flag("player_hp"))
		await play_some(h, 400)
		var fixes := v.reconcile_fixes if is_instance_valid(v) else -1
		var turns: int = v.battle.turn_number if is_instance_valid(v) else -1
		await wait_until(func(): return h.battle_view == null, 30.0)
		var hp := int(GameState.get_flag("player_hp"))
		note("%s: 적 %s · 배경 %s · 몸 %s · 주인공 그림 %s · %d턴 · 체력 %d → %d · 사후 보정 %d" % [id, str(names), look[0], str(look[1]), look[2], turns, hp0, hp, fixes])
		check(fixes == 0, "%s: 표시 = 실제 결과" % id)
		if hp <= 0:
			note("%s에서 봇이 패배 — 이후 전투는 진행하지 않음 (기능 오류가 아니라 봇의 결과)" % id)
			break
		if await wait_until(func(): return h.current_modal() == "reward", 10.0):
			await h.confirm_reward({"skip": true})
			await secs(0.3)
			for _k in range(4):
				if String(RunService.run.phase) != "reward":
					break
				await h.confirm_reward({"category": "heal"} if String(RunService.current_part().type) == "upgrade_or_heal" else _pick_simple())
				await secs(0.3)
		await secs(0.6)
	note("끝: 원정 단계 %s · 이긴 전투 %s" % [String(RunService.run.get("phase", "")), str(RunService.run.get("defeated", []))])


# 타격감 조정 확인: 보통 타격의 실제 멈춤 길이, 처치 타격의 흑백 임팩트 프레임(행동당 한 번)과 실제로 보인 시간
func run_impact() -> void:
	var h := await e7_start(271)
	var v: P2BattleView = h.battle_view
	var e0: AnimatedSprite2D = v._enemy_sprites[0]
	Engine.time_scale = 1.0
	v.battle.monsters[0].max_hp = 24
	v.battle.monsters[0].hp = 24
	v._sync_shown_from_battle()
	v._render_all()
	await secs(0.8)
	var rows: Array = []
	while v.battle.monsters[0].is_alive() and rows.size() < 6:
		await av7_hand(v, ["slash"])
		v.av7_log.clear()
		v.camera_log.clear()
		var stop_ms := 0.0
		var mono_seen := false
		var prev := Time.get_ticks_usec()
		v.play_card(av7_card(v, "slash"), 0)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			if is_instance_valid(e0) and e0.speed_scale == 0.0:
				stop_ms += (now - prev) / 1000.0
			prev = now
			if v._av7_mono != null and not mono_seen:
				mono_seen = true
				await snap("impact_01_mono")
			if Time.get_ticks_msec() - t0 > 300 and v.current_state() == "PLAYER" and v._player.animation == "idle":
				break
		var hit: Dictionary = v.battle.events.filter(func(x): return String(x.kind) == "hit")[0]
		var monos := v.av7_log.filter(func(x): return String(x.phase) == "mono")
		rows.append({"crit": bool(hit.get("crit", false)), "dead": bool(hit.dead), "stop": stop_ms, "mono": monos.size(), "held": int(monos[0].get("held_ms", -1)) if not monos.is_empty() else -1,
			"cam": v.camera_log.map(func(x): return String(x.profile))})
		note("베기: 치명 %s · 처치 %s · 적 멈춤 %.0fms · 임팩트 프레임 %d회(%dms) · 카메라 %s" % [str(rows.back().crit), str(rows.back().dead), stop_ms, monos.size(), int(rows.back().held), str(rows.back().cam)])
	var plain := rows.filter(func(r): return not r.crit and not r.dead)
	var special := rows.filter(func(r): return r.crit or r.dead)
	check(not plain.is_empty() and plain.all(func(r): return r.mono == 0 and float(r.stop) >= 45.0 and float(r.stop) <= 95.0), "보통 타격: 임팩트 프레임 없음 · 멈춤 약 60ms %s" % str(plain.map(func(r): return int(r.stop))))
	check(not special.is_empty() and special.all(func(r): return r.mono == 1 and int(r.held) >= 60 and int(r.held) <= 110), "치명·처치 타격: 임팩트 프레임 한 번, 약 70ms %s" % str(special.map(func(r): return int(r.held))))
	check(v.reconcile_fixes == 0, "표시 = 실제 결과 (사후 보정 0)")
	await flush_snaps()


# 하층 공통 배치 확인: 전투마다 배경·몸 크기·정보 칸·예상 칸 자리를 보고 한 장 남긴다
func lf_look(v: P2BattleView, id: String) -> void:
	await secs(0.6)
	var p := v._player
	var want := 200.0 / float(v._art.get("body_px", P2BattleView.WARDEN_BODY_PX))
	var slots: Array = v._slots()
	var solo := v.battle.monsters.size() == 1
	var rows: Array = []
	var bad: Array = []
	for i in range(v._enemy_sprites.size()):
		var vis := v._visible_size(i)
		var root := v._enemy_panels[i].root as Control
		var head := P2BattleView.FEET_Y - vis.y
		rows.append("%s %dx%d 칸 y%d%s" % [v.battle.monsters[i].display_name, int(vis.x), int(vis.y), int(root.position.y), " (옆 예상)" if root.has_meta("compact") else ""])
		# 예고 칸은 위 띠(42) 아래·머리 위, 체력 막대는 발밑
		var plate := (v._enemy_panels[i].intent as Control).get_global_rect()
		if plate.position.y < 42.0 or plate.end.y > head + 0.5 or (v._enemy_panels[i].hp_bar as Control).get_global_rect().position.y < P2BattleView.FEET_Y:
			bad.append("예고 칸·체력 막대 자리 %d %s" % [i, str(plate)])
	# 대상을 고르는 카드가 손에 있으면 실제 선택·가리킴으로 예상 칸을 띄워 본다
	var card: Card = null
	for c in v.battle.hand.cards:
		if card == null and P2Catalog.is_targeted(c) and v.battle.can_play_card(c):
			card = c
	var preds: Array = []
	if card != null:
		v._select_card(card)
		for i in range(v._enemy_sprites.size()):
			if not v.battle.monsters[i].is_alive():
				continue
			v._on_enemy_hover(i, true)
			await frames(3)
			if v.pred_text(i) != "":
				var r := v.pred_rect(i)
				preds.append("%d:%s" % [i, str(r.position)])
				if r.position.x < 0.0 or r.end.x > 1280.0 or r.position.y < 0.0 or r.end.y > 377.0:
					bad.append("예상 칸이 화면 밖 %d" % i)
				for k in range(v._enemy_sprites.size()):
					if k != i and v.battle.monsters[k].is_alive():
						var o := v._visible_size(k)
						if r.intersects(Rect2(float(slots[k]) - o.x / 2.0, P2BattleView.FEET_Y - o.y, o.x, o.y)):
							bad.append("예상 칸이 다른 적 몸을 덮음 %d→%d" % [i, k])
			if i == 0:
				await snap("lower_%s" % id)
			v._on_enemy_hover(i, false)
		v._cancel_selection()
		await frames(2)
	else:
		await snap("lower_%s" % id)
	note("%s: 배경 %s · 주인공 %s 배율 %.4f 자리 %s · 적 [%s] · 예상 칸 %s" % [id, String(v._stage.get_meta("backdrop")), v.battle.class_id, p.scale.x, str(p.position), " | ".join(PackedStringArray(rows)), str(preds)])
	check(String(v._stage.get_meta("backdrop")) == "waterworks" and absf((v._pp_base.x if v._pp_base != Vector2.ZERO else p.scale.x) - want) < 0.0001 and p.position == Vector2(380, 366) and bad.is_empty(), "%s: 수로 배경 · 몸 200px · 집 (380,366) · 칸·예상 칸 겹침 없음 %s" % [id, str(bad)])
	await flush_snaps()


func lf_reward(h: Node) -> void:
	if await wait_until(func(): return h.current_modal() == "reward", 10.0):
		await h.confirm_reward({"skip": true})
		await secs(0.3)
		for _k in range(4):
			if String(RunService.run.phase) != "reward":
				break
			await h.confirm_reward({"category": "heal"} if String(RunService.current_part().type) == "upgrade_or_heal" else _pick_simple())
			await secs(0.3)
	for _k in range(4):
		if RunService.stat_pending() == 0 or String(RunService.run.get("phase", "")) == "battle":
			break
		var pick := _pick_stat()
		if h.current_modal() == "level":
			await h.confirm_level(pick)
		else:
			await RunService.choose_stat(pick)
		note("능력치: %s → %s" % [pick, str(RunService.run.get("stats", {}))])
		await secs(0.3)
	await secs(0.6)


# 봇: 직업 가중이 가장 큰 후보, 같으면 희귀
func _pick_stat() -> String:
	var w: Dictionary = P2Catalog.CLASS_STAT_WEIGHT.get(String(RunService.run.class_id), {})
	var best := ""
	var score := -1
	for o in RunService.run.lv_picks[0]:
		var s := int(w.get(String(o.stat), 1)) * 10 + (5 if bool(o.get("rare", false)) else 0)
		if s > score:
			score = s
			best = String(o.stat)
	return best


func run_lower() -> void:
	await new_profile(281)
	check(SaveManager.commit("lower"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	for id in ["n1", "n2", "n3", "n4", "boss"]:
		h.dismiss_notices()
		if id == "boss":
			check(fixture(func(_c, r, _f):
				r.hp = int(r.max_hp)), "보스 전 체력 채움 (배치 점검이라 균형은 보지 않음)")
		h._on_engage(id)
		if not await h.engage_confirm(id):
			check(false, "%s 전투 시작" % id)
			break
		check(await battle_ready(h), "%s 차례" % id)
		var v: P2BattleView = h.battle_view
		await wait_until(func(): return v.prompt_text() == "" or v._prompt_close.visible, 2.0)
		if v._prompt_close.visible:
			v._prompt_close.pressed.emit()
		Engine.time_scale = 1.0
		await lf_look(v, id)
		Engine.time_scale = 2.0
		await play_some(h, 400)
		var fixes := v.reconcile_fixes if is_instance_valid(v) else -1
		await wait_until(func(): return h.battle_view == null, 30.0)
		check(fixes == 0 and int(GameState.get_flag("player_hp")) > 0, "%s: 봇이 끝까지 진행 · 표시 = 실제 결과 (체력 %d)" % [id, int(GameState.get_flag("player_hp"))])
		if int(GameState.get_flag("player_hp")) <= 0:
			break
		await lf_reward(h)


func run_lower_elite() -> void:
	var h := await e31_start(282)
	var v: P2BattleView = h.battle_view
	await lf_look(v, "elite")
	Engine.time_scale = 2.0
	await play_some(h, 12)
	check(is_instance_valid(v) and v.reconcile_fixes == 0, "정예: 몇 턴 진행 · 표시 = 실제 결과")


func run_lower_cls(cls: String, card: String, tag: String) -> void:
	var h := await e25_start(283, cls)
	var v: P2BattleView = h.battle_view
	await lf_look(v, cls)
	await av7_hand(v, [card])
	var o := await wc_card(v, card, 1, {tag: "lower_%s_attack" % cls})
	check(int(o.hits) >= 1 and int(o.shown) == int(o.hits) and v.reconcile_fixes == 0, "%s %s: 실제 타격 %d = 표시" % [cls, card, int(o.hits)])
	await flush_snaps()


# 원정 지도 확인: 지도의 곳을 실제 마우스 클릭으로 눌러 기존 창을 열고, 전투는 봇이 치른다
func mp_states(dv: P2MapView) -> Dictionary:
	var out := {}
	for k in dv._nodes:
		out[k] = String(dv._nodes[k].st)
	return out


# 고리 지도는 열릴 때·이길 때 돌아간다: 다 돌고 글자가 자리 잡을 때까지 기다린다
func mp_settle(dv: P2MapView) -> void:
	await wait_until(func(): return (dv._rot_tw == null or not dv._rot_tw.is_running()) and (dv._hub_tw == null or not dv._hub_tw.is_running()), 3.0)
	await secs(0.5)


# 고리 빈 곳을 눌러 가로로 끌고 놓는다(입력을 한 프레임 안에 판에 직접 넣어 실제 마우스와 섞이지 않게)
func mp_board_drag(dv: P2MapView, x0: float, x1: float) -> void:
	var y := 120.0
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(x0, y)
	dv._on_board_input(down)
	for k in range(1, 11):
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(lerpf(x0, x1, k / 10.0), y)
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		dv._on_board_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(x1, y)
	dv._on_board_input(up)
	await frames(2)


# 보이는 글자끼리, 글자와 다른 노드가 겹치는 수
func mp_label_overlaps(dv: P2MapView) -> Array:
	var labels: Array = []
	var icons: Array = []
	if dv._hub_open != "":
		return []
	for item in dv._ring_items():
		var k := String(item[0])
		var n: Dictionary = item[1]
		var b: Button = n.btn
		var r := b.size.x * 0.3 * b.scale.x
		icons.append([k, Rect2(b.position + b.pivot_offset - Vector2(r, r), Vector2(r, r) * 2.0)])
		for l in [n.name, n.sub]:
			if (l as Label).visible and (l as Label).modulate.a > 0.5 and (l as Label).text != "":
				labels.append([k, (l as Label).text, dv._label_rect(b, l).grow(-3.0)])
	var bad: Array = []
	for i in range(labels.size()):
		for j in range(i + 1, labels.size()):
			if (labels[i][2] as Rect2).intersects(labels[j][2]):
				bad.append("%s/%s" % [labels[i][1], labels[j][1]])
		for ic in icons:
			if String(ic[0]) != String(labels[i][0]) and (labels[i][2] as Rect2).intersects(ic[1]):
				bad.append("%s/%s" % [labels[i][1], ic[0]])
	return bad


# 실제 마우스가 창 위에서 움직이면 넣은 클릭 사이에 끼어들어 버튼이 눌리지 않을 수 있다: 눌림 신호가 올 때까지 몇 번 다시 누른다
func mp_click(dv: P2MapView, key: String) -> void:
	await dv.reveal(key)
	await mp_settle(dv)
	var b: Button = dv._nodes[key].btn
	var hit := [false]
	var cb := func() -> void: hit[0] = true
	b.pressed.connect(cb)
	var real0 := real_mouse
	for i in range(5):
		await ptr_click(b.get_global_rect().get_center())
		await frames(3)
		if hit[0]:
			if i > 0:
				var cur := Vector2(DisplayServer.mouse_get_position())
				note("클릭 %s: %d번 다시 누름 — 그 사이 실제 마우스 이벤트 %d개 · 실제 커서 %s · 창 안 %s · 창 초점 %s" % [key, i, real_mouse - real0, str(cur),
					str(Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size())).has_point(cur)), str(DisplayServer.window_is_focused())])
			break
	if is_instance_valid(b) and b.pressed.is_connected(cb):
		b.pressed.disconnect(cb)


func mp_hover(dv: P2MapView, key: String) -> bool:
	await dv.reveal(key)
	await mp_settle(dv)
	for i in range(5):
		ptr_move((dv._nodes[key].btn as Button).get_global_rect().get_center())
		await frames(4)
		if dv._sel == key and dv._prompt_bg.visible:
			return true
	return false


func mp_fight(h: Node, key: String) -> bool:
	await mp_click(h.dungeon as P2MapView, key)
	if h.current_modal() != "engage" or not await h.engage_confirm(key.trim_prefix("enemy:")):
		return false
	if not await battle_ready(h):
		return false
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 2.0
	await play_some(h, 400)
	var fixes := v.reconcile_fixes if is_instance_valid(v) else -1
	await wait_until(func(): return h.battle_view == null, 30.0)
	Engine.time_scale = 1.0
	await lf_reward(h)
	return fixes == 0 and int(GameState.get_flag("player_hp")) > 0


func run_map() -> void:
	RunModel.event_force = "supply"
	P2Ui.set_hint("map_ring", false)
	P2Ui.set_hint("map_hub", false)
	await new_profile(291)
	check(SaveManager.commit("map"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	await frames(3)
	var dv := h.dungeon as P2MapView
	check(dv != null, "원정 화면 = 지도")
	await mp_settle(dv)
	check(dv._hint != null and dv._hint_key == "map_ring" and dv._hint.visible, "처음 지도: '고리 돌리기' 말풍선")
	await snap("map_00_hint_ring")
	var st := mp_states(dv)
	note("시작(%s): %s" % [String(dv.layout.template), str(st)])
	check(st["enemy:n1"] == "open" and st.values().count("open") == 1 and st.choice == "locked" and st.service == "locked" and st["enemy:elite"] == "locked" and st["enemy:boss"] == "locked", "시작: N1만 열림")
	await mp_click(dv, "enemy:n2")
	check(h.current_modal() == "" and String(RunService.run.phase) == "explore" and dv._message.text.contains("먼저"), "잠긴 N2를 눌러도 창 없이 이유만: %s" % dv._message.text)
	check(await mp_hover(dv, "enemy:n1") and dv._ctx_name.text == "척후 둘", "N1에 올리면 아래 칸에 설명: %s / %s" % [dv._ctx_name.text, dv._prompt.text])
	await mp_settle(dv)
	check(mp_label_overlaps(dv).is_empty(), "map_01_start 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
	await snap("map_01_start")
	# 기호 설명: 평소 숨김 → i 단추(I 키)로 펴고 다시 누르거나 Esc로 접음
	check(not dv._legend.visible and dv._info != null and dv._info.visible, "기호 설명은 평소 숨김, 윗띠에 i 단추")
	await key_tap(KEY_I)
	await secs(0.25)
	check(dv._legend.visible and dv._legend_bg.visible, "I → 기호 설명 펼침")
	await snap("map_01c_legend")
	await key_tap(KEY_ESCAPE)
	await frames(2)
	check(not dv._legend.visible and h.current_modal() == "", "Esc → 기호 설명만 접힘 (메뉴 안 열림)")
	dv._info.pressed.emit()
	await frames(2)
	check(dv._legend.visible, "i 단추 → 펼침")
	dv._info.pressed.emit()
	await frames(2)
	check(not dv._legend.visible, "다시 누르면 접힘")
	# 끌어서 돌리기: 놓으면 가장 가까운 곳이 앞에 맞춰 서고 그곳 설명이 뜬다. 휠은 한 칸씩
	var f0 := dv._front_entry()
	await mp_board_drag(dv, 900.0, 520.0)
	await mp_settle(dv)
	var f1 := dv._front_entry()
	var off1 := absf(wrapf(dv._entry_ang(String(dv._entries[f1].key)) + dv._rot - 90.0, -180.0, 180.0))
	check(f1 != f0 and off1 < 1.0 and (dv._sel == String(dv._entries[f1].key) or String(dv._entries[f1].key) == "start"), "끌어서 돌리기 → %d번째가 앞에 맞춰 섬 (어긋남 %.1f도 · 고른 곳 %s)" % [f1, off1, dv._sel])
	await snap("map_01b_dragged")
	await frames(3)
	check(P2Ui.hint_seen("map_ring") and dv._hint != null and dv._hint_key == "map_hub", "고리를 돌려 보면 첫 말풍선이 사라지고 '소용돌이' 말풍선 (%s)" % dv._hint_key)
	await snap("map_00b_hint_hub")
	# 배치는 원정마다 달라 선택 지점·상인이 소용돌이 안일 수도, 고리 위 하나일 수도 있다. 말풍선이 가리키는 소용돌이에 직접 들어가 본다
	dv._open_hub(String(dv._hint_target))
	await secs(0.6)
	check(P2Ui.hint_seen("map_hub") and dv._hint == null, "소용돌이에 들어가 보면 말풍선 끝")
	await key_tap(KEY_ESCAPE)
	await mp_settle(dv)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(600, 300)
	dv._on_board_input(wheel)
	await mp_settle(dv)
	check(dv._front_entry() == mini(f1 + 1, dv._entries.size() - 1), "휠 한 번 → 다음 곳이 앞으로 (%d → %d)" % [f1, dv._front_entry()])
	dv._snap_to(f0)
	await mp_settle(dv)
	check(await mp_fight(h, "enemy:n1"), "N1: 지도 클릭 → 교전 창 → 전투 → 보상")
	dv = h.dungeon as P2MapView
	st = mp_states(dv)
	var t1 := String(dv.layout.template) == "T1"
	check(st["enemy:n1"] == "done" and st["enemy:n2"] == "open" and st.choice == "open" and st["enemy:elite"] == ("open" if t1 else "locked") and st.service == "locked", "N1 뒤: N2·선택 지점 열림, 선택 전투는 배치(%s)대로 %s" % [String(dv.layout.template), st["enemy:elite"]])
	var gold0 := int(RunService.run.gold)
	await mp_click(dv, "choice")
	check(h.current_modal() == "choice", "선택 지점 클릭 → 기존 선택 창")
	await h._choose_event("chest_gold", {})
	await frames(3)
	check(int(RunService.run.gold) == gold0 + P2Catalog.CHEST_GOLD and mp_states(dv).choice == "done" and h.current_modal() == "", "상자 금화 +%d → 선택 지점 끝남 표시" % P2Catalog.CHEST_GOLD)
	check(await mp_fight(h, "enemy:n2"), "N2")
	st = mp_states(dv)
	check(st.service == "open" and st["enemy:n3"] == "open" and st["enemy:elite"] == "open", "N2 뒤: 상인·N3·선택 전투 열림")
	await mp_click(dv, "service")
	check(h.current_modal() == "service", "상인 클릭 → 기존 상인 창")
	await mp_settle(dv)
	check(mp_label_overlaps(dv).is_empty(), "map_02_service 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
	await snap("map_02_service")
	ptr_move(Vector2(640, 40))
	await frames(2)
	h.close_modal()
	dv.refresh()
	dv.set_locked(false)
	await frames(3)
	if String(dv._nodes["service"].get("hub", "")) != "":
		check(dv._hub_open == String(dv._nodes["service"].hub), "상인이 소용돌이 안이면 창을 닫아도 소용돌이에 남음")
		await key_tap(KEY_ESCAPE)
		await mp_settle(dv)
	# 초점은 키보드용. 실제 커서가 다른 노드 위에 머물러 있으면 아래 칸은 그 노드를 보여 주는 게 맞다.
	# 창이 OS 초점을 잃은 동안(테스트 중 다른 창을 쓰면)에는 키보드 초점이 옮겨지지 않으므로, 그때는 다음 곳 고르기만 본다
	var next_key := ""
	for e in dv._entries:
		if bool(e.main) and dv._entry_state(String(e.key)) == "open":
			next_key = String(e.key)
			break
	var hov := get_viewport().gui_get_hovered_control()
	var hov_key := ""
	for k in dv._nodes:
		if hov != null and hov == dv._nodes[k].btn:
			hov_key = k
	if DisplayServer.window_is_focused():
		check(next_key == "enemy:n3" and get_viewport().gui_get_focus_owner() == dv._nodes["enemy:n3"].btn and (dv._ctx_name.text == "기수와 척후" or (hov_key != "" and dv._sel == hov_key)),
			"창을 닫으면 다음 필수 전투(N3)에 초점 — 아래 칸 %s (커서 아래 %s)" % [dv._ctx_name.text, hov_key])
	else:
		check(next_key == "enemy:n3", "창을 닫으면 다음 곳 = N3 (%s) — 게임 창이 OS 초점을 잃어 키보드 초점 확인은 건너뜀" % next_key)
	await mp_settle(dv)
	check(mp_label_overlaps(dv).is_empty(), "map_03_mid 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
	await snap("map_03_mid")
	# 다시 켠 것처럼 화면을 새로 만들어도 같은 상태 (지도는 저장된 원정 상태에서만 읽는다)
	var before := mp_states(dv)
	h.show_dungeon()
	await frames(3)
	dv = h.dungeon as P2MapView
	check(mp_states(dv) == before, "화면을 새로 만들어도 같은 지도 상태")
	press("interact", true)
	await frames(2)
	press("interact", false)
	await frames(2)
	check(h.current_modal() == "engage", "키보드: 초점 둔 곳에서 E → 교전 창")
	check(await h.engage_confirm("n3") and await battle_ready(h), "N3 시작")
	Engine.time_scale = 2.0
	await finish_battle(h)
	Engine.time_scale = 1.0
	await lf_reward(h)
	for key in ["enemy:n4", "enemy:boss"]:
		if int(GameState.get_flag("player_hp")) <= 0 or not await mp_fight(h, key):
			note("%s에서 멈춤 (봇 결과일 수 있음) — 체력 %d" % [key, int(GameState.get_flag("player_hp"))])
			break
	if String(RunService.run.get("phase", "")) == "sector_choice":
		check(h.current_modal() == "sector_choice", "보스 뒤: 정산 창")
		check(await h.choose_return(), "귀환 선택")
		await frames(3)
		st = mp_states(dv)
		check(st["enemy:boss"] == "open" and String(dv._nodes["enemy:boss"].it.kind) == "portal" and st["enemy:elite"] == "locked" and st.service == "locked", "귀환 선택 뒤: 보스 자리가 귀환 포탈, 남은 선택 전투·상인은 잠김")
		await mp_settle(dv)
		check(mp_label_overlaps(dv).is_empty(), "map_04_portal 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
		await snap("map_04_portal")
		await mp_click(dv, "enemy:boss")
		check(await wait_until(func(): return h.current_modal() == "result", 10.0) and RunService.run.is_empty(), "포탈 클릭 → 귀환 결과 창 · 원정 종료")
	else:
		check(false, "보스까지 가지 못함: 단계 %s" % String(RunService.run.get("phase", "")))
	await flush_snaps()


# 중층·상층 지도: 하층은 이긴 것으로 표시해 건너뛴다(고정값). 경로 A/B 확정·봉인, 상층 배치만 본다
func run_map_mid() -> void:
	await new_profile(292)
	check(SaveManager.commit("map mid"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		for id in ["n1", "n2", "n3", "n4", "boss"]:
			if not (r.defeated as Array).has(id):
				r.defeated.append(id)
		r.banked["normal"] = {"sector": "normal", "gold": 13, "xp": 20, "spent": 0, "bounty": {}, "level_before": 1, "level_after": 1}
		r.gold = 0
		r.xp = 0
		r.trait_offer = RunModel.trait_offer(r)
		r.phase = "sector_choice"), "고정값: 구간 I 이긴 것으로 표시·정산 (진행 생략)")
	h.show_sector_choice()
	await secs(0.3)
	h.show_trait_choice()
	await secs(0.3)
	check(await h.choose_continue(String(RunService.run.trait_offer[0])) and String(RunService.run.sector) == "hard", "실제 계속: 구간 II")
	await secs(0.5)
	h.dismiss_notices()
	var dv := h.dungeon as P2MapView
	var st := mp_states(dv)
	note("중층 시작: %s" % str(st))
	check(st["enemy:h1a"] == "open" and st["enemy:h1b"] == "open" and st["enemy:h2"] == "locked" and st["enemy:hboss"] == "locked" and st.choice == "open" and st["enemy:elite"] == "open" and st.service == "locked", "중층 시작: 두 경로·선택 지점·선택 전투 열림, 관문·보스·상인 잠김")
	check(await mp_hover(dv, "enemy:h1b") and dv._ctx_name.text.contains("주술 통로"), "경로 B에 올리면 설명: %s / %s" % [dv._ctx_name.text, dv._prompt.text])
	await mp_settle(dv)
	check(mp_label_overlaps(dv).is_empty(), "map_05_mid_fork 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
	await snap("map_05_mid_fork")
	await mp_click(dv, "enemy:h1a")
	check(h.current_modal() == "route", "경로 A 클릭 → 기존 경로 확정 창 (바로 싸우지 않음)")
	check(await h.confirm_route("a"), "경로 A 확정")
	await frames(3)
	st = mp_states(dv)
	check(st["enemy:h1a"] == "open" and String(dv._nodes["enemy:h1a"].it.kind) == "enemy" and st["enemy:h1b"] == "sealed" and st["enemy:h2"] == "locked", "확정 뒤: A는 전투, B는 봉인, 관문은 아직 잠김")
	await mp_click(dv, "enemy:h1b")
	check(h.current_modal() == "" and dv._message.text.contains("봉인"), "봉인된 B를 눌러도 창 없음: %s" % dv._message.text)
	check(dv._hub_open == "hub:r0", "경로 고르기는 갈림길 소용돌이 안에서")
	await key_tap(KEY_ESCAPE)
	await secs(0.6)
	check(dv._hub_open == "" and h.current_modal() == "" and dv._board.visible and dv._board.scale.x < 1.01, "Esc → 소용돌이에서 고리로 (메뉴는 안 열림)")
	dv._press("hub:r0")
	await frames(3)
	check(h.current_modal() == "engage", "경로를 정한 갈림길은 누르면 바로 A 교전 창 (%s)" % h.current_modal())
	h.close_modal()
	dv.set_locked(false)
	await frames(3)
	await mp_click(dv, "enemy:h2")
	check(h.current_modal() == "" and dv._message.text.contains("방패 통로"), "잠긴 관문: %s" % dv._message.text)
	await mp_settle(dv)
	check(mp_label_overlaps(dv).is_empty(), "map_06_mid_route 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
	await snap("map_06_mid_route")
	await mp_click(dv, "enemy:h1a")
	check(h.current_modal() == "engage", "확정한 A 클릭 → 교전 창")
	h.close_modal()
	dv.set_locked(false)
	check(fixture(func(_c, r, _f):
		r.sector = "extreme"
		r.layout = P2DungeonGen.generate_sector("extreme", int(r.seed))
		r.defeated = []
		r.route = ""
		r.traits = [P2Catalog.TRAIT_ORDER[0], P2Catalog.TRAIT_ORDER[1]]
		r.trait_offer = []
		r.choice = {"picked": ""}), "고정값: 구간 III 배치로 바꿈 (진행 생략)")
	h.show_dungeon()
	await secs(0.4)
	dv = h.dungeon as P2MapView
	st = mp_states(dv)
	note("상층 시작: %s" % str(st))
	check(st["enemy:x1"] == "open" and st["enemy:x2"] == "locked" and st["enemy:xboss"] == "locked" and st.choice == "open" and st["enemy:elite"] == "open" and st.service == "locked", "상층 시작: X1·선택 지점·선택 전투 열림")
	await mp_settle(dv)
	check(mp_label_overlaps(dv).is_empty(), "map_07_upper 고리 지도 글자 안 겹침 %s" % str(mp_label_overlaps(dv)))
	await snap("map_07_upper")
	# 소용돌이에 들어가는 순간: 별이 바깥으로 늘어나는 워프
	var hk := String(dv._hubs.keys()[0])
	dv._open_hub(hk)
	await secs(0.2)
	check(dv._sky.warp_k > 0.3, "소용돌이에 들어가면 별 워프 (%.2f)" % dv._sky.warp_k)
	await snap("map_08_warp")
	await secs(0.8)
	await snap("map_09_hub_space")
	await flush_snaps()


# SD 외형 시안을 실제 N1 전투 화면에 4배로 세워 본다 (그림 판단용 정지 화면, 동작 없음).
# --sd-look=<폴더> 안의 warden_idle_grid.png(96×64, 발 (30,60)) · scout_low_idle_grid.png(96×64, 발 (66,60))를 지금 배우 자리에 올린다
func run_sd_look() -> void:
	var dir := ""
	var scale := 4.0
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--sd-look="):
			dir = String(a).substr("--sd-look=".length())
		elif String(a).begins_with("--sd-scale="):
			scale = float(String(a).substr("--sd-scale=".length()))
	var h := await e7_start(295)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	await secs(0.8)
	await snap("sd_look_now")
	var actors := [[v._player, "warden_idle_grid.png", Vector2(30, 60)]]
	for e in v._enemy_sprites:
		actors.append([e, "scout_low_idle_grid.png", Vector2(66, 60)])
	for a in actors:
		# 폴더에 없는 그림의 배우는 지금 그림 그대로 둔다
		if not FileAccess.file_exists(dir.path_join(String(a[1]))):
			continue
		var img := Image.load_from_file(dir.path_join(String(a[1])))
		var actor: Node2D = a[0]
		var sp := Sprite2D.new()
		sp.texture = ImageTexture.create_from_image(img)
		sp.centered = false
		# 96칸보다 큰 그림은 격자 파일이 아니라 큰 원본이다: 같은 화면 크기로 줄여 부드럽게 그린다
		var k := img.get_width() / 96.0
		sp.offset = -(a[2] as Vector2) * k
		sp.scale = Vector2.ONE * scale / k
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if k == 1.0 else CanvasItem.TEXTURE_FILTER_LINEAR
		sp.position = actor.position
		sp.z_index = actor.z_index
		actor.get_parent().add_child(sp)
		actor.visible = false
		v._env_shadow(sp)
		note("%s: %dx%d → 화면 %s에 %s배" % [String(a[1]), img.get_width(), img.get_height(), str(actor.position), str(scale)])
	await secs(0.3)
	await snap("sd_look_sd")
	await flush_snaps()


# UI 시안 바탕용: N1 전투 화면을 지금 UI 그대로 한 장, UI를 숨기고 한 장
func run_stage_clean() -> void:
	var h := await e7_start(296)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	await secs(0.8)
	await snap("stage_ui")
	v._ui.visible = false
	await secs(0.2)
	await snap("stage_clean")
	# 손패만 남기고 카드가 다 보이게 올린 장 (시안 바탕)
	v._ui.visible = true
	for c in v._ui.get_children():
		if c is CanvasItem and c != v._hand_root:
			c.visible = false
	v._hand_root.position.y -= 62.0
	await secs(0.2)
	await snap("stage_hand")
	note("손패 자리 %s · _ui 자식 %s" % [str(v._hand_root.position), str(v._ui.get_children().map(func(c): return c.name))])
	await flush_snaps()


# SD 시범(--sd-combat): N1에서 SD 수호기사·척후병이 실제 전투 흐름을 끝까지 도는지. 동작 그림이 없는 동작은 빌린 그림으로 돈다
func run_sd_battle() -> void:
	check(P2BattleView.sd_on(), "SD 그림 켜짐(기본)")
	var h := await e7_start(298)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	await secs(0.8)
	var keys := v._enemy_sprites.map(func(e): return String(e.get_meta("art", "")))
	check(v._art.has("sd") and keys == ["sd:scout_low", "sd:scout_low"], "SD 그림: 주인공 %s · 적 %s" % [str(v._art.get("dir", "")), str(keys)])
	check(absf(v._pp_base.x - 1.0) < 0.001 and absf((v._enemy_sprites[0] as Node2D).scale.x - 1.0) < 0.001, "수로 배치에서 배율 1 (게임 크기로 줄인 그림): 주인공 %.3f · 적 %.3f" % [v._pp_base.x, (v._enemy_sprites[0] as Node2D).scale.x])
	await snap("sd_battle_01_start")
	await av7_hand(v, ["slash", "guard"])
	await wc_card(v, "slash", 0, {"wave:2": "sd_battle_02_slash"})
	Engine.time_scale = 2.0
	await finish_battle(h)
	check(v == null or not is_instance_valid(v) or v.reconcile_fixes == 0, "끝까지 진행 · 표시 = 실제 결과")
	note("끝: 체력 %d · 이긴 전투 %s" % [int(GameState.get_flag("player_hp")), str(RunService.run.get("defeated", []))])
	await flush_snaps()


# UI_KIT_01 1차 구현 대표 흐름(N1 수호기사): 조준·취소 → 실제 맥 소모(0까지) → 턴 종료 → 적 예고·실제 피해·체력·방어 → 새 차례 회복.
# 맥 흐름(시계)·수위·출렁임·일시정지·흔들림 줄이기, 최대 손패 배치, 유물·상태 도움말. 손패·유물·상태를 고정값으로 넣은 곳은 기록에 적는다
func ui_level(v: P2BattleView) -> float:
	return float((v._mana_water.material as ShaderMaterial).get_shader_parameter("surface"))


func run_ui_kit() -> void:
	var h := await e7_start(299)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	await secs(0.6)
	await snap("ui_01_start")
	var c0 := v._ui_clock
	await secs(0.5)
	check(v._ui_clock - c0 > 0.4 and absf(ui_level(v) - P2BattleView.MANA_FULL_Y) < 0.01 and v._mana_label.text == "3/3", "맥 대기: UI 시계 +%.2f초 · 수위 %s(가득 = 12) · 숫자 %s" % [v._ui_clock - c0, str(ui_level(v)), v._mana_label.text])
	# 조준 → 취소
	await av7_hand(v, ["slash", "slash", "bash"])
	v._select_card(av7_card(v, "slash"))
	v._on_enemy_hover(0, true)
	await frames(3)
	var ring: Node2D = v._enemy_panels[0].ring_node
	var during := [v.pred_text(0), v.mana_pred_text(), v._mana_label.text, ring.visible, ui_level(v)]
	await snap("ui_02_target")
	v._on_enemy_hover(0, false)
	v._cancel_selection()
	await frames(3)
	check(during[0] != "" and during[1] == "−1" and during[2] == "3/3" and bool(during[3]) and absf(float(during[4]) - P2BattleView.MANA_FULL_Y) < 0.01
		and v.mana_pred_text() == "" and not ring.visible and v.pred_text(0) == "",
		"조준: 예상 '%s' · 맥 옆 '%s' · 숫자 %s · 발밑 표시 %s · 수위 그대로 → 취소하면 모두 사라짐" % during.slice(0, 4))
	# 실제 소모: 3 → 2 → 1 → 0. 수위는 0.2초 따라가고, 바뀐 직후 수면이 기운다. 0이면 물 없음
	var steps: Array = []
	for kind in ["slash", "slash", "bash"]:
		var c := av7_card(v, kind)
		var tgt := 0 if v.battle.monsters[0].is_alive() else 1
		v.play_card(c, tgt)
		await frames(2)
		var tilt := v._mana_tilt
		await secs(0.35)
		steps.append([v._mana_label.text, snappedf(ui_level(v), 0.01), snappedf(tilt, 0.01)])
		await wait_until(func(): return v.current_state() == "PLAYER" and v._player.animation == "idle", 5.0)
	note("소모: %s" % str(steps))
	check(steps[0][0] == "2/3" and steps[1][0] == "1/3" and steps[2][0] == "0/3" and absf(float(steps[0][1]) - lerpf(41.0, 12.0, 2.0 / 3.0)) < 0.05
		and absf(float(steps[1][1]) - lerpf(41.0, 12.0, 1.0 / 3.0)) < 0.05 and float(steps[2][1]) >= 48.0 and absf(float(steps[0][2])) > 0.5,
		"맥 소모: 숫자 2/3 → 1/3 → 0/3 · 수위 %s · 0이면 물 없음(48) · 바뀐 직후 수면 기울기 %s" % [str(steps.map(func(x): return x[1])), str(steps[0][2])])
	await snap("ui_03_empty")
	# 일시정지: UI 시계가 멈춘다
	var cp := v._ui_clock
	get_tree().paused = true
	await get_tree().create_timer(0.4, true).timeout
	var paused_clock := v._ui_clock
	get_tree().paused = false
	check(absf(paused_clock - cp) < 0.05, "일시정지: 맥 시계 멈춤 (%.3f → %.3f)" % [cp, paused_clock])
	# 흔들림 줄이기: 흐름·물결·기울기 없이 정확한 수위
	v._reduce_motion = true
	var cr := v._ui_clock
	await secs(0.3)
	var mat := v._mana_water.material as ShaderMaterial
	check(absf(v._ui_clock - cr) < 0.001 and float(mat.get_shader_parameter("flow")) == 0.0 and float(mat.get_shader_parameter("tilt")) == 0.0, "흔들림 줄이기: 맥 시계·흐름·기울기 0")
	v._reduce_motion = false
	# 턴 종료 → 적 행동(예고·실제 피해·체력·방어) → 새 차례에 맥 회복
	var hp0 := v._hud_hp_label.text
	var intents := [0, 1].filter(func(i): return v.battle.monsters[i].is_alive()).map(func(i): return (v._enemy_panels[i].intent_label as Label).text)
	await v.end_turn()
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	await secs(0.5)
	note("턴 종료: 예고 %s · 체력 %s → %s · 방어 %s · 맥 %s 수위 %s" % [str(intents), hp0, v._hud_hp_label.text, v._hud_block.text, v._mana_label.text, str(ui_level(v))])
	check(v._mana_label.text == "3/3" and absf(ui_level(v) - P2BattleView.MANA_FULL_Y) < 0.01 and v._hud_hp_label.text != hp0 and v.reconcile_fixes == 0,
		"새 차례: 맥 3/3 · 수위 가득 · 적 피해가 발밑 체력에 반영(%s → %s) · 표시 = 실제 결과" % [hp0, v._hud_hp_label.text])
	# 최대 손패(7장) · 긴 이름: 카드·올린 카드가 화면 안, 턴 종료·맥 수조·더미와 겹치지 않음
	await av7_hand(v, ["slash", "slash", "guard", "guard", "riposte", "bash", "fortify"])
	var bad: Array = []
	var keep := [v._end_button.get_global_rect(), Rect2(P2BattleView.MANA_ORB, Vector2(180, 144)), Rect2(18, P2BattleView.PILES_Y, 160, 90), v._incoming.get_global_rect()]
	for card in v.battle.hand.cards:
		var view: Control = v._card_views[card]
		var r := Rect2(view.get_meta("home"), P2BattleView.REST)
		if r.position.x < 0 or r.end.x > 1280:
			bad.append("화면 밖 " + card.card_name)
		for k in keep:
			if r.intersects(k):
				bad.append("%s 겹침 %s" % [card.card_name, str(k)])
	v._hover = v.battle.hand.cards[6]
	v._update_focus()
	await secs(0.2)
	var big := Rect2(v._big.position, P2BattleView.BIG * v._big.scale) if v._big != null else Rect2()
	if big.position.x < 0 or big.end.x > 1280 or big.position.y < 0 or big.end.y > 720:
		bad.append("올린 카드 화면 밖 %s" % str(big))
	# 올린 카드는 그 카드 자리 바로 위(가운데로 도망가지 않음)
	var home_c := float((v._card_views[v.battle.hand.cards[6]].get_meta("home") as Vector2).x) + P2BattleView.REST.x / 2.0
	var want_c := clampf(home_c, P2BattleView.BIG.x / 2.0 + 8.0, 1280.0 - P2BattleView.BIG.x / 2.0 - 8.0)
	if absf(big.get_center().x - want_c) > 3.0:
		bad.append("올린 카드가 제자리를 벗어남 %.0f ≠ %.0f" % [big.get_center().x, want_c])
	await snap("ui_04_maxhand")
	v._hover = null
	v._update_focus()
	check(bad.is_empty(), "최대 손패 7장 · 올린 마지막 카드 %s: 화면 안 · 제자리 위 · 턴 종료/맥 수조/더미/다가오는 공격과 겹치지 않음 %s" % [str(big), str(bad)])
	# 유물·상태 도움말 (고정값: 유물 하나와 독 상태를 넣어 본다)
	v.battle.relics.append(P2Catalog.RELICS.keys()[0])
	v.battle.poison_amount = 2
	v.battle.poison_ticks = 2
	v._render_hud()
	await frames(2)
	var relic_tip := String((v._hud_relics.get_child(v._hud_relics.get_child_count() - 1) as Control).tooltip_text)
	var chips := v._player_status.get_children().map(func(c): return String(c.tooltip_text).substr(0, 12))
	check(relic_tip != "" and chips.size() >= 1, "고정값 유물·독: 유물 도움말 '%s' · 상태 %s" % [relic_tip.split("\n")[0], str(chips)])
	await snap("ui_05_status")
	await flush_snaps()


# 수로 배경이 아닌 전투(중층 H1a, 옛 배경·136px 배치)에서도 새 전투 UI가 겹치지 않는지 한 장 (하층은 고정값으로 건너뜀)
func run_ui_mid() -> void:
	var h := await e28_start(300)
	var v: P2BattleView = h.battle_view
	await secs(0.6)
	var plates := range(v._enemy_panels.size()).map(func(i): return (v._enemy_panels[i].intent as Control).get_global_rect())
	check(plates.all(func(r): return r.position.y >= 42.0 and r.end.x <= 1280.0), "중층 H1a: 예고 칸이 위 띠 아래·화면 안 %s" % str(plates))
	await snap("ui_06_mid")
	await flush_snaps()


# 피해 숫자: 실제 베기(보통·치명)·흔들림 줄이기·적 공격에서 굵은 숫자와 색·크기가 사건과 맞는지. 치명은 난수 시작점만 고정값
func run_dmg_num() -> void:
	var h := await e7_start(301)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.4)
	await av7_hand(v, ["slash", "slash", "bash"])
	var tgt := func(): return 0 if b.monsters[0].is_alive() else 1
	av1_seed(b, [false], b.crit_chance())
	var plain := await dn_watch(v, func(): v.play_card(av7_card(v, "slash"), tgt.call()))
	var hit0 := b.events.filter(func(e): return String(e.kind) == "hit")
	note("보통 베기: 사건 %s · 숫자 %s" % [str(hit0.map(func(e): return int(e.damage))), str(plain)])
	check(hit0.size() == 1 and plain.size() == 1 and plain[0].text == str(hit0[0].damage) and plain[0].color == P2BattleView.DMG_TONE.phys[0] and int(plain[0].size) >= 36 and float(plain[0].pop) > 1.1,
		"보통 베기: 숫자 1개 = 실제 피해 %s · 물리 색 · %dpx · 튀어나옴 %.2f배" % [plain[0].text if plain.size() > 0 else "-", int(plain[0].size) if plain.size() > 0 else 0, float(plain[0].pop) if plain.size() > 0 else 0.0])
	av1_seed(b, [true], b.crit_chance())
	v.clear_display_log()
	var crit := await dn_watch(v, func(): v.play_card(av7_card(v, "slash"), tgt.call()), "dmg_01_crit")
	var hit1 := b.events.filter(func(e): return String(e.kind) == "hit")
	var crit_log := v.get_display_log().filter(func(e): return String(e.kind) == "crit_shown")
	note("치명 베기: 사건 %s · 숫자 %s" % [str(hit1.map(func(e): return [int(e.damage), bool(e.crit)])), str(crit)])
	check(hit1.size() == 1 and bool(hit1[0].crit) and crit.size() == 1 and crit[0].text == str(hit1[0].damage) and crit[0].color == P2BattleView.DMG_TONE.crit[0] and int(crit[0].size) >= 48 and float(crit[0].pop) > 1.5 and crit_log.size() == 1,
		"치명 베기: 숫자 1개 = 실제 피해 · 금색 · %dpx · 튀어나옴 %.2f배 · 치명 표시 %d번" % [int(crit[0].size) if crit.size() > 0 else 0, float(crit[0].pop) if crit.size() > 0 else 0.0, crit_log.size()])
	v._reduce_motion = true
	var calm := await dn_watch(v, func(): v.play_card(av7_card(v, "bash"), tgt.call()))
	v._reduce_motion = false
	check(calm.size() >= 1 and calm.all(func(e): return float(e.pop) <= 1.001), "흔들림 줄이기: 숫자 %d개 모두 크기 변화 없음" % calm.size())
	var hp0 := int(GameState.get_flag("player_hp"))
	var hurt := await dn_watch(v, func(): v.end_turn(), "", 15.0)
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	var lost := hp0 - int(GameState.get_flag("player_hp"))
	var red := hurt.filter(func(e): return e.color == P2BattleView.DMG_TONE.hurt[0])
	var red_sum := 0
	for e in red:
		red_sum += int(String(e.text).replace("−", ""))
	note("적 단계: 체력 %d 잃음 · 숫자 %s" % [lost, str(hurt)])
	check(lost > 0 and red.size() >= 1 and red_sum == lost, "적 공격: 주인공 피해 숫자 합 %d = 실제 잃은 체력 %d · 빨강" % [red_sum, lost])
	# 고정값 한 줄: 종류별 색·크기 비교 (화면 확인용, 규칙과 무관)
	var row := [["24", "phys", 36, 1.2], ["38", "phys", 48, 1.45], ["61", "crit", 72, 1.8], ["17", "magic", 36, 1.2], ["4", "fire", 24, 1.0], ["9", "hurt", 48, 1.45], ["2", "poison", 36, 1.2], ["0", "zero", 36, 1.2]]
	for k in range(row.size()):
		v._damage_number(row[k][0], Vector2(150 + k * 140, 330), row[k][1], row[k][2], row[k][3])
	await secs(0.2)
	await snap("dmg_02_tones")
	var bold := P2Ui.bold_font(48) as FontFile
	var missing := ""
	for ch in "0123456789−":
		if not bold.has_char(ch.unicode_at(0)):
			missing += ch
	check(missing == "", "굵은 글꼴에 숫자와 − 글자가 있음 (없는 글자 '%s')" % missing)
	await flush_snaps()


# 동작 하나 동안 새로 생긴 피해 숫자(그림자 있는 글자)를 모은다: 글자·크기·색·처음 본 배율. still이면 숫자가 생기고 0.1초 뒤 한 장
func dn_watch(v: P2BattleView, act: Callable, still := "", limit := 6.0) -> Array:
	var seen := {}
	var old := v._numbers.get_children().map(func(l): return l.get_instance_id())
	act.call()
	var t0 := Time.get_ticks_msec()
	var first := -1
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await get_tree().process_frame
		for l in v._numbers.get_children():
			if l is Label and l.has_theme_constant_override("shadow_offset_y") and not seen.has(l.get_instance_id()) and not old.has(l.get_instance_id()):
				seen[l.get_instance_id()] = {"text": (l as Label).text, "size": (l as Label).get_theme_font_size("font_size"), "color": (l as Label).get_theme_color("font_color"), "pop": (l as Label).scale.x}
				if first < 0:
					first = Time.get_ticks_msec()
		if still != "" and first >= 0 and Time.get_ticks_msec() - first >= 100:
			await snap(still)
			still = ""
		if Time.get_ticks_msec() - t0 > 300 and v.current_state() == "PLAYER" and v._player.animation == "idle" and (first < 0 or Time.get_ticks_msec() - first > 400):
			break
	return seen.values()


# ── 손맛 시험판(--feel-proto): 긋기 베기 · 패링 원. 입력은 스크립트(점 따라 긋기, 원이 닫힐 때 누르기)와 실제 마우스 사건 하나씩 ──
func run_feel() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(302)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	check(b.parry_mode, "시험판 켜짐: 적 행동 타격 하나씩")
	await secs(0.4)
	await av7_hand(v, ["slash", "slash", "bash"])
	# 1) 완벽 긋기 (점을 따라 끌기) → 치명 · 맞는 순간 그은 자국
	var hp_e0 := b.monsters[0].hp
	v.play_card(av7_card(v, "slash"), 0)
	var pad := await fe_pad(v)
	check(pad != null and pad.points.size() == 2, "베기: 약점 점 %d개" % (pad.points.size() if pad != null else 0))
	await fe_drag(pad, pad.points, 0.22, "feel_01_slash")
	var trail_seen := await fe_wait_trail(v, "feel_02_trail")
	await fe_idle(v)
	var hit1 := b.events.filter(func(e): return String(e.kind) == "hit")
	check(v.slash_log.back().grade == "perfect" and hit1.size() == 1 and bool(hit1[0].crit) and int(hit1[0].raw) == int(floor(b.card_base_value(av7_card_any(b, "slash")) * 1.3)) and trail_seen and b.monsters[0].hp == hp_e0 - int(hit1[0].damage),
		"완벽 긋기: 치명 %s · 피해 %d · 그은 자국 %s · %s" % [str(hit1[0].crit) if hit1.size() > 0 else "-", int(hit1[0].damage) if hit1.size() > 0 else -1, str(trail_seen), str(v.slash_log.back())])
	# 2) 취소 (우클릭과 같은 길) → 마나·손패 그대로
	var mana0 := int(GameState.get_flag("player_mana"))
	var hand0 := b.hand.cards.size()
	v.play_card(av7_card(v, "bash"), fe_target(b))
	pad = await fe_pad(v)
	pad._finish("cancel")
	await frames(3)
	check(v.current_state() == "PLAYER" and int(GameState.get_flag("player_mana")) == mana0 and b.hand.cards.size() == hand0, "긋기 취소: 마나 %d · 손패 %d장 그대로" % [mana0, hand0])
	# 3) 빗나감 (점에서 먼 곳을 긋기) → 절반. 두 적을 다 살려 두려고 둘째 적에게
	var tgt := 1
	v.play_card(av7_card(v, "slash"), tgt)
	pad = await fe_pad(v)
	await fe_drag(pad, [Vector2(80, 120), Vector2(260, 140)], 0.25)
	await fe_idle(v)
	var hit2 := b.events.filter(func(e): return String(e.kind) == "hit")
	check(v.slash_log.back().grade == "graze" and hit2.size() == 1 and not bool(hit2[0].crit) and int(hit2[0].raw) == int(floor(b.card_base_value(av7_card_any(b, "slash")) * 0.5)),
		"빗나감: 피해 %s (기본의 절반)" % (str(hit2[0].raw) if hit2.size() > 0 else "-"))
	# 4) 실제 마우스 사건으로 하나만 지나가기 (강타: 점 2개 중 1개) → 보통
	tgt = 1
	v.play_card(av7_card(v, "bash"), tgt)
	pad = await fe_pad(v)
	var p0: Vector2 = pad.points[0]
	await fe_mouse(pad, [p0 + Vector2(-40, 0), p0, p0 + Vector2(40, 0)])
	await fe_idle(v)
	var hit3 := b.events.filter(func(e): return String(e.kind) == "hit")
	check(v.slash_log.back().grade == "part" and int(v.slash_log.back().crossed) == 1 and hit3.size() >= 1 and not bool(hit3[0].crit), "실제 마우스 긋기: 점 1/2 지나감 → 일부 (치명 아님, 피해 %s)" % (str(hit3[0].raw) if hit3.size() > 0 else "-"))
	# 5) 적 단계(방어 0, 준비한 반격 없음): 첫 원 완벽(원 가운데 실제 클릭) → 피해 0 · 반격 없음, 둘째 원 막음 → 4분의 1 줄임
	var hp0 := int(GameState.get_flag("player_hp"))
	v.parry_log.clear()
	v.enemy_action_log.clear()
	v.end_turn()
	await fe_parry(v, ["click", "perfect", "good", "good"], "feel_03_parry", "feel_03a_ring")
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	await secs(0.3)
	var ehits: Array = []
	for a in v.enemy_action_log:
		ehits.append_array((a.events as Array).filter(func(e): return String(e.kind) == "enemy_hit"))
	var lost := hp0 - int(GameState.get_flag("player_hp"))
	var taken := 0
	for e in ehits:
		taken += int(e.damage)
	note("적 단계 1: 판정 %s · 타격 %s · 잃은 체력 %d" % [str(v.parry_log), str(ehits.map(func(e): return [e.get("parry", ""), e.get("parried", 0), e.raw, e.damage])), lost])
	var c1: Array = []
	for a in v.enemy_action_log:
		c1.append_array((a.events as Array).filter(func(e): return String(e.kind) == "counter"))
	check(ehits.size() == 2 and String(ehits[0].get("parry", "")) == "perfect" and int(ehits[0].damage) == 0 and c1.is_empty() and lost == taken and v.reconcile_fixes == 0,
		"완벽 패링(실제 클릭): 피해 0 · 준비 없으면 반격 없음(%d) · 잃은 체력 %d = 사건 합 · 표시 = 실제" % [c1.size(), lost])
	check(ehits.size() == 2 and String(ehits[1].get("parry", "")) == "good" and int(ehits[1].parried) >= 1 and int(ehits[1].damage) == 5 - int(ehits[1].parried),
		"막음: 5 중 %s 줄임 → %s" % [str(ehits[1].get("parried", "-")) if ehits.size() > 1 else "-", str(ehits[1].damage) if ehits.size() > 1 else "-"])
	# 6) 맞받아치기(방어 + 반격 준비)와 수호: 완벽 → 방어 그대로 · 준비한 반격이 나감, 안 누름 → 방어가 막음
	await av7_hand(v, ["riposte", "guard", "slash"])
	await v.play_card(av7_card(v, "riposte"), -1)
	await v.play_card(av7_card(v, "guard"), -1)
	await fe_idle(v)
	v.enemy_action_log.clear()
	v.parry_log.clear()
	var ehp := b.monsters.map(func(m): return m.hp)
	v.end_turn()
	var block0 := b.get_pending_defense()
	await fe_parry(v, ["perfect", "perfect", "none", "none"], "feel_04_counter")
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	await secs(0.3)
	var all_ev: Array = []
	for a in v.enemy_action_log:
		all_ev.append_array(a.events)
	var counters := all_ev.filter(func(e): return String(e.kind) == "counter")
	var eh2 := all_ev.filter(func(e): return String(e.kind) == "enemy_hit")
	note("적 단계 2: 판정 %s · 타격 %s · 반격 %s" % [str(v.parry_log), str(eh2.map(func(e): return [e.get("parry", ""), e.get("parried", 0), e.raw, e.absorbed, e.damage])), str(counters.map(func(e): return [e.index, e.damage]))])
	check(eh2.size() >= 1 and String(eh2[0].get("parry", "")) == "perfect" and int(eh2[0].damage) == 0 and int(eh2[0].absorbed) == 0 and int(eh2[0].block) == block0 and counters.size() >= 1 and v.reconcile_fixes == 0,
		"방어 %d + 완벽 패링: 피해 0 · 방어 그대로 · 맞받아치기 반격 %d" % [block0, int(counters[0].damage) if counters.size() > 0 else 0])
	check(eh2.size() < 2 or (String(eh2[1].get("parry", "")) == "miss" and int(eh2[1].absorbed) > 0), "안 누른 원: 놓침 → 방어가 막음 %s" % (str(eh2[1].absorbed) if eh2.size() > 1 else "-"))
	# 7) 악보 단독: 짧은 노트 2 + 롱노트. 이른 클릭은 다음 노트만, 롱노트는 끝까지 누르면 완벽
	var c0 := v._player_body() + Vector2(72, -6)
	var ch := P2NoteChart.new()
	ch.setup([{"pos": c0, "at": 0.6, "approach": 0.6, "hold": 0.0, "num": 1}, {"pos": c0 + Vector2(74, 0), "at": 0.95, "approach": 0.6, "hold": 0.0, "num": 2},
		{"pos": c0 + Vector2(0, 64), "at": 1.3, "approach": 0.6, "hold": 0.5, "num": 3}], 32.0, null, false)
	v._ui.add_child(ch)
	var gs := {}
	ch.judged.connect(func(i: int, g: String, _d: float) -> void: gs[i] = g)
	var t0 := Time.get_ticks_msec()
	var held_shot := false
	while gs.size() < 3 and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
		var cur := ch._current()
		if cur == 0 and ch.time_until(0) <= 0.01:
			ch.press_now()
		elif cur == 1 and ch.time_until(1) <= 0.12:
			ch.press_now()
		elif cur == 2 and ch.time_until(2) <= 0.01:
			ch.press_now()
		if not held_shot and bool(ch.notes[2].holding) and ch.time_until(2) < -0.2:
			held_shot = true
			await snap("feel_05_hold")
	check(gs.get(0) == "perfect" and gs.get(1) == "good" and gs.get(2) == "perfect" and v._group_grade(["perfect", "good", "perfect"]).grade == "good",
		"악보 단독: 완벽 · 막음 · 롱노트 끝까지 완벽 %s · 묶음 판정 %s" % [str(gs), str(v._group_grade(["perfect", "good", "perfect"]))])
	# 8) 순서 문양 단독(별): 거꾸로 그으면 세지 않고, 순서대로 그으면 완벽
	var sp: Array[Vector2] = []
	for q in P2BattleView.GLYPHS.star:
		sp.append(Vector2(640, 300) + (q as Vector2) * 220.0)
	var pad2 := P2SlashPad.new()
	pad2.setup(sp, 16.0, 5.0, true, true)
	v._ui.add_child(pad2)
	await secs(0.2)
	pad2.add_point(sp[2] + Vector2(-30, 0))
	pad2.add_point(sp[2] + Vector2(30, 0))
	var wrong := pad2.crossed_count()
	await fe_drag(pad2, sp, 0.6, "feel_06_star")
	check(wrong == 0 and pad2.grade == "perfect" and pad2.crossed_count() == sp.size(), "별 문양: 순서 틀린 점은 안 셈(%d) · 순서대로 %d/%d → %s" % [wrong, pad2.crossed_count(), sp.size(), pad2.grade])
	await fe_units(v)
	# 억제: 다음 악보가 단순해진다(척후 5 → 노트 2개가 1개)
	var plain := v._parry_pattern(0, [5], false)
	var calm := v._parry_pattern(0, [5], true)
	check((plain[0].kinds as Array).size() == 2 and (calm[0].kinds as Array).size() == 1, "억제된 적의 악보: 노트 %d개 → %d개" % [(plain[0].kinds as Array).size(), (calm[0].kinds as Array).size()])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


var _fe_auto := false
var _fe_shots := {}
var _fe_skill := {"perfect": 1.0, "good": 0.0}
var _fe_rng := RandomNumberGenerator.new()
var _fe_plan := {}
var _fe_charts := {}
var _fe_late := 0.0
var _fe_diff := "normal"


# 봇 옆에서: 원은 닫히는 순간 누르고, 약점은 따라 긋는다 (--feel-auto일 때만)
func fe_autoloop() -> void:
	while _fe_auto:
		await get_tree().process_frame
		var h := host()
		if h == null or h.battle_view == null:
			continue
		var v: P2BattleView = h.battle_view
		for c in v._ui.get_children():
			if not (c is P2NoteChart):
				continue
			var ch := c as P2NoteChart
			var cid := ch.get_instance_id()
			if not _fe_charts.has(cid) and ch.has_meta("enemy"):
				var ei := int(ch.get_meta("enemy"))
				_fe_charts[cid] = {"role": String(v.battle.roles[ei]) if ei < v.battle.roles.size() else "?", "kinds": ch.notes.map(func(q): return String(q.kind))}
			var cur := ch._current()
			for i in range(ch.notes.size()):
				var n: Dictionary = ch.notes[i]
				if n.grade == "" and String(n.kind) == "d" and float(n.second) >= 0.0 and ch._t - float(n.second) >= 0.08 and fe_want("%d:%d" % [cid, i]) != "miss":
					ch.press_now()
				if bool(n.holding) and String(n.kind) == "s":
					ch.set_cursor(ch.ball(i))
			if cur >= 0:
				var want := fe_want("%d:%d" % [cid, cur])
				var kd := String(ch.notes[cur].kind)
				if kd == "x":
					if want == "miss" and ch.time_until(cur) <= 0.0:
						ch.press_now()
				elif want == "perfect" and ch.time_until(cur) <= 0.01 - _fe_late:
					ch.press_now()
				elif want == "good" and ch.time_until(cur) <= 0.1:
					ch.press_now()
			if ch.notes.size() >= 3 and not _fe_shots.has("multi") and cur >= 1:
				_fe_shots["multi"] = true
				snap("feel_chart_multi")
			if ch.call > 0.0 and not _fe_shots.has("call") and ch._t > float(ch.notes[1].at) - ch.call + 0.05:
				_fe_shots["call"] = true
				snap("feel_chart_call")
				note("부름 악보: 노트 %s · 반주 박자 %.3f초" % [str(ch.notes.map(func(n): return String(n.kind))), ch.beat])
			for n in ch.notes:
				if bool(n.holding) and not _fe_shots.has("hold"):
					_fe_shots["hold"] = true
					snap("feel_chart_hold")
		for c in v._ui.get_children():
			if c is P2SlashPad and (c as P2SlashPad).grade == "" and not c.has_meta("auto"):
				c.set_meta("auto", true)
				var sw := fe_want("pad:%d" % c.get_instance_id())
				if sw == "perfect":
					fe_glyph(c, 0.3)
				elif sw == "good":
					fe_glyph(c, maxf(0.9, (c as P2SlashPad).limit * 0.85))


func fe_target(b: P2Battle) -> int:
	for i in range(b.monsters.size()):
		if b.monsters[i].is_alive():
			return i
	return -1


func av7_card_any(b: P2Battle, kind: String) -> Card:
	for src in [b.hand.cards, b.deck.discard_pile, b.deck.draw_pile]:
		for c in src:
			if P2Catalog.kind_of(c) == kind:
				return c
	return null


func fe_pad(v: P2BattleView) -> P2SlashPad:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		for c in v._ui.get_children():
			if c is P2SlashPad and (c as P2SlashPad).grade == "":
				await secs(0.18)
				return c
		await get_tree().process_frame
	return null


# 점들을 따라(조금 앞뒤로 넘겨) dur초 동안 긋는다. 꼭짓점은 정확히 지난다. still이면 첫 점을 지난 뒤 한 장
func fe_drag(pad: P2SlashPad, via: Array, dur: float, still := "") -> void:
	if pad == null:
		return
	var path: Array = []
	var first: Vector2 = via[0]
	var last: Vector2 = via[via.size() - 1]
	path.append(first + (first - last).normalized() * 40.0)
	path.append_array(via)
	path.append(last + (last - first).normalized() * 40.0)
	var per := maxi(2, 24 / (path.size() - 1))
	var total := per * (path.size() - 1)
	pad.add_point(path[0])
	for j in range(1, path.size()):
		for k in range(1, per + 1):
			pad.add_point((path[j - 1] as Vector2).lerp(path[j], float(k) / per))
			await secs(dur / total)
			if still != "" and pad.crossed_count() >= 1:
				await snap(still)
				still = ""
			if pad.grade != "":
				pad.release()
				return
	pad.release()


# 실제 마우스 사건(누름 → 움직임 → 놓음)을 창에 넣는다
func fe_mouse(pad: P2SlashPad, path: Array) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = path[0]
	down.global_position = path[0]
	get_viewport().push_input(down)
	for i in range(1, path.size()):
		for k in range(1, 7):
			var mv := InputEventMouseMotion.new()
			mv.position = (path[i - 1] as Vector2).lerp(path[i], k / 6.0)
			mv.global_position = mv.position
			mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_viewport().push_input(mv)
			await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = path[path.size() - 1]
	up.global_position = up.position
	get_viewport().push_input(up)
	await frames(2)


func fe_wait_trail(v: P2BattleView, still: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		for c in v._fxp.get_children():
			if c is P2SlashTrail:
				await frames(3)
				await snap(still)
				return true
		await get_tree().process_frame
	return false


func fe_idle(v: P2BattleView) -> void:
	await wait_until(func(): return v.current_state() == "PLAYER" and v._player.animation == "idle", 6.0)
	await secs(0.15)


# 적 단계 동안 노트마다 계획대로: perfect = 닫히는 순간, good = 0.12초 이르게, click = 노트 가운데 실제 클릭(닫히는 순간), none = 안 누름
func fe_parry(v: P2BattleView, plan: Array, still := "", approach_still := "") -> void:
	var order := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
		if v.current_state() == "PLAYER":
			break
		for c in v._ui.get_children():
			if not (c is P2NoteChart):
				continue
			var ch := c as P2NoteChart
			for i in range(ch.notes.size()):
				var key := "%d:%d" % [ch.get_instance_id(), i]
				if not order.has(key):
					order[key] = order.size()
			var cur := ch._current()
			for i in range(ch.notes.size()):
				var want := String(plan[mini(int(order["%d:%d" % [ch.get_instance_id(), i]]), plan.size() - 1)])
				if ch.grade_of(i) != "" and still != "" and want in ["perfect", "click"]:
					await frames(4)
					await snap(still)
					still = ""
			if cur < 0:
				continue
			var want_now := String(plan[mini(int(order["%d:%d" % [ch.get_instance_id(), cur]]), plan.size() - 1)])
			if approach_still != "" and ch.time_until(cur) <= 0.3:
				await snap(approach_still)
				approach_still = ""
			for i in range(ch.notes.size()):
				var n: Dictionary = ch.notes[i]
				if n.grade == "" and String(n.kind) == "d" and float(n.second) >= 0.0 and ch._t - float(n.second) >= 0.08:
					ch.press_now()
				if bool(n.holding) and String(n.kind) == "s":
					ch.set_cursor(ch.ball(i))
			if String(ch.notes[cur].kind) == "x":
				continue
			var lead := 0.12 if want_now == "good" else 0.01
			if want_now != "none" and ch.time_until(cur) <= lead:
				if want_now == "click":
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = true
					ev.position = ch.notes[cur].pos
					ev.global_position = ev.position
					get_viewport().push_input(ev)
				else:
					ch.press_now()


# 룬술사 시험판: 마력 장막(방어가 있으면 감싸고, 막을 때 물결) · 마력탄 삼각 문양 · 각인 파열 별 문양(순서 긋기) · 모으는 빛 · 장막 위 패링
func run_feel_rune() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e25_start(303, "rune_caster")
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.4)
	await av7_hand(v, ["guard", "bolt", "fireball"])
	await v.play_card(av7_card(v, "guard"), -1)
	await secs(0.3)
	check(v._barrier != null and v._barrier.visible, "마력 장막: 방어 %d · 장막 보임 %s" % [b.get_pending_defense(), str(v._barrier != null and v._barrier.visible)])
	await snap("rune_01_barrier")
	v.play_card(av7_card(v, "bolt"), fe_target(b))
	var pad := await fe_pad(v)
	check(pad != null and pad.ordered and pad.points.size() == 4, "마력탄: 순서 문양 점 %d개 (삼각형 닫기)" % (pad.points.size() if pad != null else 0))
	fe_glyph(pad)
	await wait_until(func(): return pad == null or not is_instance_valid(pad) or pad.crossed_count() >= 2, 3.0)
	await snap("rune_02_glyph")
	await fe_wait_trail(v, "rune_03_impact")
	await fe_idle(v)
	var hit := b.events.filter(func(e): return String(e.kind) == "hit")
	check(v.slash_log.back().grade == "perfect" and hit.size() >= 1 and bool(hit[0].crit) and float(v.slash_log.back().power) > 1.0, "완벽한 삼각 문양: 치명 · 배율 %s" % str(v.slash_log.back().power))
	if b.monsters.any(func(m): return m.is_alive()):
		v.play_card(av7_card(v, "fireball"), fe_target(b))
		pad = await fe_pad(v)
		check(pad != null and pad.ordered and pad.points.size() >= 3, "화염구: 혜성 문양 점 %d개" % (pad.points.size() if pad != null else 0))
		fe_glyph(pad)
		await wait_until(func(): return pad == null or not is_instance_valid(pad) or pad.crossed_count() >= 3, 4.0)
		await snap("rune_05_star")
		await fe_idle(v)
		check(v.slash_log.back().grade == "perfect" and float(v.slash_log.back().power) >= 1.5, "완벽한 혜성: 배율 %s" % str(v.slash_log.back().power))
	v.enemy_action_log.clear()
	v.end_turn()
	await fe_parry(v, ["none"], "", "rune_04_parry")
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	var absorbed := 0
	for a in v.enemy_action_log:
		for e in (a.events as Array):
			if String(e.kind) == "enemy_hit":
				absorbed += int(e.absorbed)
	check(absorbed > 0 and v.reconcile_fixes == 0, "장막이 막음 %d · 표시 = 실제" % absorbed)
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 단독 점검: 긋기(느림·가장자리 → 정확, 가시 → 끊김, 박자 문양) · 노트(두 번 · 따라가기 · 도망 · 페인트)
func fe_units(v: P2BattleView) -> void:
	var two: Array[Vector2] = [Vector2(560, 260), Vector2(700, 330)]
	var slow := await fe_pad_try(v, two, {}, func(pad): await fe_drag(pad, pad.points, 1.6))
	var edge := await fe_pad_try(v, two, {}, func(pad): await fe_drag(pad, [pad.points[0] + Vector2(0, 14), pad.points[1] + Vector2(0, 14)], 0.4))
	var thorn := await fe_pad_try(v, [Vector2(520, 260), Vector2(640, 300), Vector2(760, 260)] as Array[Vector2], {"thorns": [Vector2(580, 280)]}, func(pad): await fe_drag(pad, pad.points, 0.5))
	var tri: Array[Vector2] = [Vector2(640, 200), Vector2(720, 330), Vector2(560, 330), Vector2(640, 200)]
	var early := await fe_pad_try(v, tri, {"beat": 0.34}, func(pad): await fe_drag(pad, pad.points, 0.3))
	var timed := await fe_pad_try(v, tri, {"beat": 0.34, "thorns": [Vector2(680, 265)]}, func(pad): await fe_glyph(pad))
	note("긋기 단독: 느림 %s · 가장자리 %s(가운데 %d) · 가시 %s · 박자 무시 %s · 박자 맞춤+가시 돌기 %s" % [slow.grade, edge.grade, int(edge.precise), thorn.grade + (" 끊김" if bool(thorn.broken) else ""), early.grade, timed.grade])
	check(slow.grade == "hit" and edge.grade == "hit" and thorn.grade == "part" and bool(thorn.broken) and early.grade != "perfect" and timed.grade == "perfect",
		"긋기 판정: 느림 → 정확 · 가장자리 → 정확 · 가시 → 끊김 · 박자 무시 → %s · 박자 맞추고 가시 피함 → 완벽" % early.grade)
	# 노트 종류
	var c0 := v._player_body() + Vector2(72, -6)
	var specs := [{"pos": c0, "at": 0.5, "approach": 0.5, "kind": "d", "num": 1}, {"pos": c0 + Vector2(74, 0), "at": 1.2, "approach": 0.5, "kind": "d", "num": 2},
		{"pos": c0 + Vector2(-74, 0), "at": 1.8, "approach": 0.5, "kind": "s", "hold": 0.45, "to": c0 + Vector2(-74, 90), "num": 3},
		{"pos": c0 + Vector2(37, -64), "at": 2.7, "approach": 0.5, "kind": "x", "num": 4}, {"pos": c0 + Vector2(-37, -64), "at": 3.2, "approach": 0.5, "kind": "x", "num": 5},
		{"pos": c0 + Vector2(37, 64), "at": 4.0, "approach": 0.7, "kind": "f", "num": 6}]
	var ch := P2NoteChart.new()
	ch.setup(specs, 32.0, null, false)
	ch.bounds = Rect2(c0 - Vector2(120, 96), Vector2(250, 186))
	v._ui.add_child(ch)
	var gs := {}
	ch.judged.connect(func(i: int, g: String, _d: float) -> void: gs[i] = g)
	var plan := {0: "double", 1: "single", 2: "follow", 3: "wait", 4: "press"}
	var flee_from: Vector2 = specs[5].pos
	var moved := false
	var snapped := false
	var t0 := Time.get_ticks_msec()
	while gs.size() < specs.size() and Time.get_ticks_msec() - t0 < 7000:
		await get_tree().process_frame
		if not is_instance_valid(ch):
			break
		var cur := ch._current()
		# 두 번 노트의 두 번째 클릭(계획이 double일 때만)
		if ch.notes[0].grade == "" and float(ch.notes[0].second) >= 0.0 and ch._t - float(ch.notes[0].second) >= 0.08:
			ch.press_now()
		if bool(ch.notes[2].holding):
			ch.set_cursor(ch.ball(2))
			if not snapped and ch._t - float(ch.notes[2].at) > 0.2:
				snapped = true
				await snap("feel_07_kinds")
		if gs.size() >= 5 and not moved and ch.time_until(5) < 0.53 and ch.time_until(5) > 0.46:
			ch.set_cursor(ch.notes[5].pos + Vector2(-20, 0))
			await frames(3)
			await snap("feel_08_flee_arrow")
			await secs(0.2)
			moved = (ch.notes[5].home as Vector2).distance_to(flee_from) > 40.0
		if cur >= 0 and ch.time_until(cur) <= 0.01:
			var want := String(plan.get(cur, "single"))
			if want != "wait":
				ch.press_now()
	note("노트 단독: %s · 도망 이동 %s" % [str(gs), str(moved)])
	check(gs.get(0) == "perfect" and gs.get(1) == "good" and gs.get(2) == "perfect" and gs.get(3) == "perfect" and gs.get(4) == "miss" and gs.get(5) == "perfect" and moved,
		"노트 종류: 두 번 클릭 완벽 · 한 번만 → 막음 · 따라가기 완벽 · 페인트 참음 → 완벽 · 누름 → 속음 · 도망 노트 비켜남 후 잡기")
	await flush_snaps()


# 점 자리로 긋기 판 하나를 띄우고 act로 그은 뒤 결과
func fe_pad_try(v: P2BattleView, pts: Array[Vector2], opts: Dictionary, act: Callable) -> Dictionary:
	var pad := P2SlashPad.new()
	pad.setup(pts, 18.0, 1.5, pts.size() > 2, false, opts)
	v._ui.add_child(pad)
	var out := {}
	pad.finished.connect(func(r: Dictionary) -> void: out.merge(r))
	await secs(0.2)
	await act.call(pad)
	var t0 := Time.get_ticks_msec()
	while out.is_empty() and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	return out


# 문양을 규칙대로: 박자 문양은 점마다 고리가 닿는 순간 지나가고, 가시는 옆으로 돌아간다
func fe_glyph(pad: P2SlashPad, dur := 0.5) -> void:
	var pts := pad.points
	var path: Array = []
	for i in range(pts.size()):
		if i > 0:
			for th in pad.thorns:
				var a: Vector2 = pts[i - 1]
				var b: Vector2 = pts[i]
				if Geometry2D.get_closest_point_to_segment(th, a, b).distance_to(th) < 30.0:
					var side := (b - a).orthogonal().normalized()
					path.append((th as Vector2) + side * 46.0)
		path.append(pts[i])
	if pad.beat <= 0.0:
		await fe_drag(pad, path, dur)
		return
	pad.add_point(path[0] + Vector2(-30, 0))
	var k := 0
	for i in range(pts.size()):
		while pad.grade == "" and pad._t < pad._target[i] - 0.06:
			await get_tree().process_frame
		while k < path.size():
			var q: Vector2 = path[k]
			for st in range(1, 5):
				pad.add_point(pad.stroke[pad.stroke.size() - 1].lerp(q, st / 4.0))
			k += 1
			if q.distance_to(pts[i]) < 1.0:
				break
	pad.release()


# 끌기·놓기와 배치: 작아진 카드가 마우스를 따라오고, 적 위에서 놓으면 빨려 들어가 쓰인다. 나에게 쓰는 칸은 주인공 몸에 맞춘다.
# 빈 곳에 놓으면 돌아온다. 턴 종료는 손패 위 가운데, 오른쪽 아래는 다가오는 공격. 클릭으로 고르고 적을 겨누면 화살표
func run_ui_drag() -> void:
	var h := await e7_start(304)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.5)
	await av7_hand(v, ["slash", "guard", "bash"])
	var er := v._end_button.get_global_rect()
	var pr0 := v._hud_phase.get_global_rect()
	check(absf(er.get_center().x - 640.0) < 10.0 and er.position.y >= pr0.end.y and er.end.y < 140.0 and not er.intersects(Rect2(P2BattleView.HINT_RECT.position, Vector2(P2BattleView.HINT_RECT.size.x, 120))),
		"턴 종료: 위쪽 차례 표시 밑 가운데, 안내 칸과 안 겹침 %s" % str(er))
	check(v._incoming != null and (v._incoming.get_meta("dmg") as Label).text.is_valid_int() and (v._incoming.get_meta("blk") as Label).text.is_valid_int(),
		"다가오는 공격: 칼 %s · 방패 %s → 하트 '%s'" % [(v._incoming.get_meta("dmg") as Label).text, (v._incoming.get_meta("blk") as Label).text, (v._incoming.get_meta("l2") as Label).text])
	await snap("ui_09_layout")
	# 클릭으로 베기 고르기 → 적 겨누기 = 화살표
	v._select_card(av7_card(v, "slash"))
	v._on_enemy_hover(0, true)
	await frames(3)
	check(v._aim_fx.visible, "클릭으로 고르고 적을 겨누면 곡선 화살표")
	await snap("ui_10_aim")
	v._on_enemy_hover(0, false)
	v._cancel_selection()
	await frames(2)
	# 빈 곳에 놓기 → 돌아옴
	var n0 := b.hand.cards.size()
	var mid0 := await ud_drag(v, av7_card(v, "bash"), Vector2(640, 250))
	await secs(0.3)
	var bash_view: Control = v._card_views.get(av7_card(v, "bash"))
	check(b.hand.cards.size() == n0 and bash_view != null and bash_view.visible and v._drag_ghost == null, "빈 곳에 놓기: 손패 그대로 · 카드 돌아옴")
	check(bool(mid0.closed), "끄는 동안 남은 카드가 빈자리를 메움")
	var reopened := range(n0).all(func(i): return absf(((v._card_views[b.hand.cards[i]] as Control).get_meta("home") as Vector2).x - float(v._fan(i, n0).pos.x)) < 1.0)
	check(reopened, "되돌리면 자리가 다시 벌어짐")
	# 방어 카드: 주인공 몸에 맞춘 칸. 손패로 되돌리면 취소, 주인공이 아니어도 손패 위 빈 곳에 놓으면 쓰임
	var pr := v._player_rect()
	var def0 := b.get_pending_defense()
	await ud_drag(v, av7_card(v, "guard"), Vector2(640, 610))
	await secs(0.3)
	check(b.hand.cards.size() == n0 and b.get_pending_defense() == def0 and v._drag_ghost == null, "방어 카드를 손패로 되돌리면 취소")
	var mid := await ud_drag(v, av7_card(v, "guard"), Vector2(700, 240), "ui_08_self")
	check(bool(mid.zone_self) and Rect2(mid.zone_rect).grow(-10.0).encloses(Rect2(pr.get_center() - Vector2(4, 4), Vector2(8, 8))) and absf(Rect2(mid.zone_rect).size.y - pr.size.y - 28.0) < 2.0,
		"나에게 쓰는 칸 = 주인공 몸(%s) · 칸 %s" % [str(pr), str(mid.zone_rect)])
	await wait_until(func(): return b.hand.cards.size() == n0 - 1, 3.0)
	await wait_until(func(): return v.current_state() == "PLAYER" and v._player.animation == "idle", 5.0)
	await secs(0.3)
	check(b.get_pending_defense() >= def0 + 5 and b.hand.cards.size() == n0 - 1, "주인공이 아닌 위쪽 빈 곳에 놓기 → 방어 %d" % b.get_pending_defense())
	check(bool(mid.drop_line) and not (v._drop_line != null and v._drop_line.visible), "끄는 동안 손패 위 금빛 경계 줄, 놓으면 사라짐")
	# 적 위에 놓기 → 빨려 들어가 쓰임
	var hp0 := b.monsters[0].hp
	var mid2 := await ud_drag(v, av7_card(v, "slash"), v._to_ui(v._enemy_torso(0)), "ui_07_drag")
	note("손 조작 기록 %s · 손패 %s" % [str(v.gesture_log.slice(maxi(0, v.gesture_log.size() - 5))), str(b.hand.cards.map(func(c): return c.card_name))])
	check(bool(mid2.ghost) and Vector2(mid2.ghost_pos).distance_to(v._to_ui(v._enemy_torso(0))) < 140.0 and float(mid2.ghost_scale) < 0.7, "끄는 동안 작아진 카드가 마우스를 따라옴 %s" % str(mid2))
	await wait_until(func(): return b.monsters[0].hp < hp0, 3.0)
	await wait_until(func(): return v.current_state() == "PLAYER" and v._player.animation == "idle", 6.0)
	check(b.monsters[0].hp < hp0 and v._drag_ghost == null, "적 위에 놓기 → 빨려 들어가 사용(체력 %d → %d)" % [hp0, b.monsters[0].hp])
	await flush_snaps()


# 손패의 card를 눌러 to까지 끌고 놓는다(손패 입력에 사건을 직접 넣어 실제 마우스와 섞이지 않게). 놓기 직전 상태와 한 장
func ud_drag(v: P2BattleView, card: Card, to: Vector2, still := "") -> Dictionary:
	var view: Control = v._card_views[card]
	var from: Vector2 = v._hand_root.position + (view.get_meta("home") as Vector2) + P2BattleView.REST / 2.0
	var base := v._hand_hit.position
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from - base
	v._on_hand_input(down)
	for k in range(1, 13):
		var mv := InputEventMouseMotion.new()
		mv.position = from.lerp(to, k / 12.0) - base
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		v._on_hand_input(mv)
		await get_tree().process_frame
	await frames(2)
	var gs := v.gesture_state()
	var rest: Array = v.battle.hand.cards.filter(func(c): return c != card)
	var closed := range(rest.size()).all(func(i): return absf(((v._card_views[rest[i]] as Control).get_meta("home") as Vector2).x - float(v._fan(i, rest.size()).pos.x)) < 1.0)
	var mid := {"closed": closed, "zone_self": gs.zone_self, "zone_rect": Rect2(v._zone_self.position, v._zone_self.size), "ghost": v._drag_ghost != null,
		"drop_line": v._drop_line != null and v._drop_line.visible,
		"ghost_pos": (v._drag_ghost.position + P2BattleView.REST / 2.0 - Vector2(0, 30)) if v._drag_ghost != null else Vector2.ZERO,
		"ghost_scale": v._drag_ghost.scale.x if v._drag_ghost != null else 1.0}
	if still != "":
		await snap(still)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to - base
	v._on_hand_input(up)
	await frames(2)
	return mid


# 손패·화면 다듬기 확인: 올린 카드 양옆이 비켜서고 내려놓으면 제자리, 맥 글자가 유리 원 가운데, 위 띠의 회복약 동그라미,
# 돌 틀 설정·정보 창, 맞은 뒤 체력 막대의 노란 잔상, 연속 배지(시험판)
func run_ui_look() -> void:
	P2BattleView.feel_force = {"juice": true}
	var h := await e7_start(305)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.5)
	await av7_hand(v, ["slash", "slash", "guard", "guard", "bash"])
	await secs(0.3)
	var homes: Array = b.hand.cards.map(func(c): return (v._card_views[c] as Control).position.x)
	v._set_hover(b.hand.cards[2])
	await secs(0.35)
	var now: Array = b.hand.cards.map(func(c): return (v._card_views[c] as Control).position.x)
	var shine: bool = v._big != null and v._big.get_children().any(func(c): return c is ColorRect and (c as ColorRect).material is ShaderMaterial)
	await snap("ui_11_hover")
	check(shine, "올린 카드에 빛줄기")
	check(float(now[1]) < float(homes[1]) - 30.0 and float(now[3]) > float(homes[3]) + 30.0 and v._big_card == b.hand.cards[2], "올린 카드 양옆이 비켜섬: %s → %s" % [str(homes), str(now)])
	v._set_hover(null)
	await secs(0.35)
	var back: Array = b.hand.cards.map(func(c): return (v._card_views[c] as Control).position.x)
	check(back.size() == homes.size() and range(homes.size()).all(func(i): return absf(float(back[i]) - float(homes[i])) < 1.5) and (v._card_views[b.hand.cards[2]] as Control).visible, "내려놓으면 제자리 · 카드 다시 보임")
	var mana0 = GameState.get_flag("player_mana")
	GameState.set_flag("player_mana", 0)
	v._set_hover(b.hand.cards[0])
	await secs(0.25)
	v._select_card(b.hand.cards[0])
	await frames(2)
	check(v._big != null and v._big.has_meta("deny") and v._selected == null, "마나가 모자라면 올린 카드가 떨린다")
	await secs(0.08)
	await snap("ui_17_deny")
	GameState.set_flag("player_mana", mana0)
	v._set_hover(null)
	await secs(0.4)
	var mc := v._mana_label.get_global_rect().get_center().x
	check(absf(mc - (P2BattleView.MANA_ORB.x + 83.0)) < 1.5, "맥 숫자가 유리 원 가운데 (%.1f)" % mc)
	var pb := v._potion_button.get_global_rect()
	check(pb.position.y < 40.0 and v._potion_button.visible and pb.size == Vector2(26, 26), "회복약 동그라미가 위 띠에 %s" % str(pb))
	v._toggle_menu()
	await frames(3)
	var stone := v._menu != null and v._menu.get_children().any(func(c): return c is NinePatchRect)
	await snap("ui_12_menu")
	check(stone, "설정 창: 돌 틀")
	v._close_popups()
	v._toggle_info()
	await frames(3)
	await snap("ui_13_info")
	v._close_popups()
	# 연속 배지
	for k in range(6):
		v._combo_hit(true)
		await secs(0.05)
	await secs(0.1)
	await snap("ui_15_combo")
	check(v._combo != null and v._combo.count == 6 and v._combo.visible and v._combo.position.x < 100.0, "연속 표시 6 (왼쪽 아래, 악보 판 밖)")
	# 맞은 뒤 노란 잔상
	var hp0 := int(GameState.get_flag("player_hp"))
	v.end_turn()
	await wait_until(func(): return int(v._shown.hp) < hp0, 10.0)
	await secs(0.08)
	await snap("ui_14_hp_trail")
	var trail_w := 0.0
	var fill_w := 0.0
	for c in v._hud_hp_bar.get_children():
		if c is ColorRect and (c as ColorRect).color == Color("#f2c461"):
			trail_w = (c as ColorRect).size.x
		if c is TextureRect:
			fill_w = (c as TextureRect).size.x
	check(trail_w > fill_w, "맞은 직후 노란 잔상이 남은 체력보다 길다 (%.0f > %.0f)" % [trail_w, fill_w])
	check(v._hand_root.position.y > 50.0, "적 차례에는 손패가 아래로 접힌다 (%.0f)" % v._hand_root.position.y)
	await wait_until(func(): return v._card_views.values().any(func(x): return (x as Control).get_meta("entering", false)), 15.0)
	await secs(0.1)
	var flying: bool = v._card_views.values().any(func(x): return (x as Control).scale.x < 0.95)
	await snap("ui_16_draw")
	check(flying, "새 손패가 뽑기 더미에서 작게 날아온다")
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	await secs(0.9)
	var settled: bool = v._card_views.values().all(func(x): return not (x as Control).get_meta("entering", false) and (x as Control).scale == Vector2.ONE and absf((x as Control).position.x - ((x as Control).get_meta("home") as Vector2).x) < 1.0)
	check(settled and v._hand_root.position == Vector2.ZERO and v._card_views.size() == b.hand.cards.size(), "안착하면 제자리·제 크기, 손패 수 일치")
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 키보드 누르기(osu식): 마우스로 겨누고 키로 누름. 짧은 노트 · 롱노트(두 키를 번갈아 쥐어도 계속) · Esc·Tab·F키는 원래 쓰임 ·
# 긋기도 키를 누른 채 마우스로 · 키 표시 · 판정 오차 막대 · 악보 동안 배경음악 낮춤과 끝나면 걷힘
func run_keys() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(306)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	await secs(0.5)
	check(P2NoteChart.is_hit_key(kev(KEY_Z, true)) and P2NoteChart.is_hit_key(kev(KEY_SPACE, true)) and P2NoteChart.is_hit_key(kev(KEY_E, true))
		and not P2NoteChart.is_hit_key(kev(KEY_ESCAPE, true)) and not P2NoteChart.is_hit_key(kev(KEY_TAB, true)) and not P2NoteChart.is_hit_key(kev(KEY_F3, true))
		and not P2NoteChart.is_hit_key(kev(KEY_SHIFT, true)) and not P2NoteChart.is_hit_key(kev(KEY_Z, true, true)), "누르기 키: Z·Space·E는 받고 Esc·Tab·F3·Shift·되풀이는 안 받음")
	var chart := P2NoteChart.new()
	chart.setup([{"pos": Vector2(520, 250), "at": 0.9, "approach": 0.6, "kind": "t", "num": 1},
		{"pos": Vector2(760, 250), "at": 1.6, "approach": 0.6, "kind": "h", "hold": 0.5, "num": 2}], 44.0, null, false)
	chart.beat = 0.5
	chart.arrange()
	v._ui.add_child(chart)
	v._wire_chart(chart)
	note("소리 지연 보정 %.0fms" % (chart._lat * 1000.0))
	await wait_until(func(): return chart.time_until(0) <= 0.008, 3.0)
	chart.set_cursor(Vector2(520, 250))
	chart._input(kev(KEY_Z, true))
	chart._input(kev(KEY_Z, false))
	await frames(2)
	var g0 := chart.grade_of(0)
	check(g0 == "perfect" or g0 == "good", "Z로 짧은 노트 (%s)" % g0)
	check(v._hitbar != null and v._hitbar.hits == 1 and absf(float(v._hitbar.marks[0].d)) < 0.06, "판정 오차 막대에 눈금 %s" % (str(v._hitbar.marks) if v._hitbar != null else "없음"))
	await wait_until(func(): return chart.time_until(1) <= 0.008, 3.0)
	chart.set_cursor(Vector2(760, 250))
	chart._input(kev(KEY_X, true))
	await secs(0.15)
	chart._input(kev(KEY_C, true))
	chart._input(kev(KEY_X, false))
	await frames(2)
	check(bool(chart.notes[1].holding), "롱노트: X를 떼도 C를 쥐고 있으면 계속 누른 채")
	await snap("keys_01_hold")
	check(v._duck_amp != null and v._duck_amp.volume_db < -6.0 and v._duck_lp.cutoff_hz < 3000.0,
		"악보 동안 배경음악 낮춤 (%s)" % ("%.1f dB · %.0f Hz" % [v._duck_amp.volume_db, v._duck_lp.cutoff_hz] if v._duck_amp != null else "없음"))
	await wait_until(func(): return chart.grade_of(1) != "", 2.0)
	chart._input(kev(KEY_C, false))
	check(chart.grade_of(1) == "perfect" or chart.grade_of(1) == "good", "롱노트 끝까지 (%s)" % chart.grade_of(1))
	check(v._keys != null and v._keys.total == 3 and v._keys.used() == 3 and v._keys.cols.size() == 4, "키 표시: 1~4 네 칸 중 Z·X·C가 세 칸, 누른 수 %s" % (str(v._keys.total) if v._keys != null else "없음"))
	await wait_until(func(): return not is_instance_valid(chart), 3.0)
	await secs(1.2)
	check(not v._keys.on and not v._hitbar.on and v._duck_amp.volume_db > -0.5 and v._duck_lp.cutoff_hz > 15000.0, "악보가 끝나면 키 표시·막대·음악 낮춤이 걷힘")
	var pad := P2SlashPad.new()
	var pts: Array[Vector2] = [Vector2(500, 300), Vector2(700, 300)]
	pad.setup(pts, 30.0, 2.0)
	v._ui.add_child(pad)
	await frames(2)
	pad._gui_input(mmove(Vector2(470, 300)))
	pad._input(kev(KEY_Z, true))
	for k in range(1, 9):
		pad._gui_input(mmove(Vector2(470 + k * 35, 300)))
		await frames(1)
	pad._input(kev(KEY_Z, false))
	await frames(2)
	check(pad.crossed_count() == 2 and pad.grade != "" and pad.grade != "cancel", "긋기: Z를 누른 채 마우스로 (%s · %d점)" % [pad.grade, pad.crossed_count()])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


func kev(code: Key, pressed: bool, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	return e


func mmove(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	return e


# 리듬 설정·결과: 오차 막대 좌우 대칭 · Z·X만 모드 · 판정 보정이 판정 순간을 옮김 · 노트 속도 · 메뉴 리듬 칸 · 연습 악보 ·
# 키 표시가 다가오는 공격 판 바로 위 · 전투 결과 판(등급·보정 단추·아무 키로 넘김)
func run_rhythm() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(307)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	await secs(0.5)
	var hb := v._hitbar_node()
	check(absf(hb.x_of(-P2NoteChart.GOOD_EARLY) + hb.x_of(P2NoteChart.GOOD_LATE)) < 0.5 and absf(hb.x_of(-hb.early_p) + hb.x_of(hb.late_p)) < 0.5
		and absf(hb.position.x + hb.size.x / 2.0 - 640.0) < 1.0, "오차 막대: 금빛·푸른 창이 가운데 줄에서 좌우 같은 거리, 막대 가운데 = 화면 가운데")
	var kr := v._keys_node().get_global_rect()
	check(kr.end.y <= v._seal_label.get_global_rect().position.y and kr.end.y >= v._incoming.get_global_rect().position.y - 40.0 and absf(kr.position.x - v._incoming.get_global_rect().position.x) < 1.0
		and not kr.intersects(v._hitbar_node().get_global_rect()), "키 표시가 다가오는 공격 판 위(봉인 줄 위) %s" % str(kr))
	P2NoteChart.hit_keys = P2Ui.hit_keys_of("zx")
	check(P2NoteChart.is_hit_key(kev(KEY_Z, true)) and P2NoteChart.is_hit_key(kev(KEY_X, true)) and not P2NoteChart.is_hit_key(kev(KEY_A, true)), "Z·X만 모드: A는 안 받음")
	P2NoteChart.hit_keys = P2Ui.hit_keys_of("custom:%d,%d" % [KEY_D, KEY_F])
	check(P2NoteChart.is_hit_key(kev(KEY_D, true)) and P2NoteChart.is_hit_key(kev(KEY_F, true)) and not P2NoteChart.is_hit_key(kev(KEY_Z, true)) and P2Ui.keys_label("custom:%d,%d" % [KEY_D, KEY_F]) == "D·F·클릭만",
		"지정한 두 키(D·F) 모드: Z는 안 받음")
	P2NoteChart.hit_keys = []
	# 보정 +30ms: 30ms 늦게 눌러야 완벽
	P2NoteChart.offset = 0.03
	var chart := P2NoteChart.new()
	chart.setup([{"pos": Vector2(640, 250), "at": 0.8, "approach": 0.6, "kind": "t", "num": 1}], 44.0, null, false)
	v._ui.add_child(chart)
	v._wire_chart(chart)
	await wait_until(func(): return chart.time_until(0) <= -0.024, 3.0)
	chart.set_cursor(Vector2(640, 250))
	chart._input(kev(KEY_Z, true))
	chart._input(kev(KEY_Z, false))
	await frames(2)
	var mark: float = float(hb.marks.back().d) if not hb.marks.is_empty() else 9.0
	check(chart.grade_of(0) == "perfect" and absf(mark) < 0.02, "보정 +30ms: 30ms 늦게 눌러 완벽 (막대 %.0fms)" % (mark * 1000.0))
	P2NoteChart.offset = 0.0
	await wait_until(func(): return not is_instance_valid(chart), 3.0)
	# 노트 속도
	v._approach_k = 1.3
	var ch2 := v._parry_chart(0, [5])
	await frames(1)
	var beat := 60.0 / float(P2BattleView.PARRY_BPM[v._parry_tier(0)])
	var plain: Array = ch2.notes.filter(func(n): return String(n.kind) != "f")
	check(not plain.is_empty() and absf(float(plain[0].approach) - beat * 1.2 * 1.3) < 0.01, "노트 속도 느리게: 고리 시간 ×1.3 (%.2f초)" % (float(plain[0].approach) if not plain.is_empty() else 0.0))
	ch2.queue_free()
	v._approach_k = 1.0
	await secs(0.5)
	# 메뉴 리듬 칸
	v._toggle_menu()
	await frames(3)
	var texts: Array = []
	var stack: Array = [v._menu]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Button:
			texts.append((nd as Button).text)
		if nd is Label and nd.has_meta("offset_label"):
			texts.append((nd as Label).text)
		stack.append_array(nd.get_children())
	await snap("rhythm_01_menu")
	check(texts.any(func(t): return String(t).begins_with("키: ")) and texts.has("지정") and texts.any(func(t): return String(t).begins_with("판정 보정"))
		and texts.any(func(t): return String(t).begins_with("노트 속도")) and texts.any(func(t): return String(t).begins_with("연습 악보")), "메뉴 리듬 칸: %s" % str(texts))
	v._close_popups()
	await frames(2)
	# 연습 악보: 첫 노트만 치고 끝까지 둔다
	var m0 := int(v._rs.m)
	var o0 := (v._rs.offs as Array).size()
	P2BattleView.recent_offsets.clear()
	v.practice()
	await frames(2)
	var pc: P2NoteChart = null
	for c in v._ui.get_children():
		if c is P2NoteChart and c.has_meta("practice"):
			pc = c
	check(pc != null and v.current_state() != "PLAYER", "연습 악보가 뜸 (노트 %d개)" % (pc.notes.size() if pc != null else 0))
	if pc != null:
		await wait_until(func(): return pc.time_until(0) <= 0.006, 4.0)
		pc.set_cursor(pc.notes[0].pos)
		pc._input(kev(KEY_Z, true))
		pc._input(kev(KEY_Z, false))
		await secs(1.2)
		await snap("rhythm_02_practice")
		await wait_until(func(): return not is_instance_valid(pc), 40.0)
	await wait_until(func(): return v.current_state() == "PLAYER", 5.0)
	check(v.current_state() == "PLAYER" and P2BattleView.recent_offsets.size() >= 1 and int(v._rs.m) == m0 and (v._rs.offs as Array).size() == o0,
		"연습 악보: 끝나면 내 차례, 오차는 보정용에만 (결과에는 안 셈)")
	# 전투 결과 판
	v._rs.p = 7
	v._rs.g = 2
	v._rs.m = 1
	v._rs.best = 9
	v._rs.sl = {"perfect": 2, "hit": 1, "part": 0, "graze": 0}
	v._rs.offs = [0.02, 0.022, 0.018, 0.025, 0.019, 0.021, 0.02, 0.023]
	P2BattleView.result_hold = 20.0
	v._show_results()
	await frames(3)
	var cal: Button = null
	var grade := ""
	stack = [v._overlay]
	while not stack.is_empty():
		var nd2: Node = stack.pop_back()
		if nd2 is Button and nd2.has_meta("calibrate"):
			cal = nd2
		if nd2 is Label and nd2.has_meta("grade"):
			grade = String(nd2.get_meta("grade"))
		stack.append_array(nd2.get_children())
	await snap("rhythm_03_result")
	check(v._result_open and grade == "B" and cal != null, "결과 판: 등급 %s · 보정 단추 %s" % [grade, "있음" if cal != null else "없음"])
	if cal != null:
		cal.pressed.emit()
		await frames(2)
	check(absf(P2NoteChart.offset - 0.021) < 0.0005 and int(P2Ui.load_rhythm().offset_ms) == 21, "보정 단추: 가운데 값 21ms 늦음 → 판정 보정 +21ms 저장 (%s)" % str(P2Ui.load_rhythm()))
	v._unhandled_input(kev(KEY_SPACE, true))
	await frames(4)
	check(not v._result_open and v._overlay.get_child_count() == 0, "아무 키로 결과 판을 넘김")
	P2Ui.save_rhythm({"offset_ms": 0, "keys": "any", "approach": 1.0})
	P2NoteChart.offset = 0.0
	P2BattleView.result_hold = 0.3
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 연속 회복 · 반주 음량 · 키 표시 떼기 · 노트 모양 · 원정 기록:
# 연속 5마다 체력 +1(가득 차 있으면 안 셈, 한 전투 최대 5) · 저장에 회복 수가 남음 · 반주 0%면 소리 안 냄 ·
# 악보가 먼저 끝나 떼기를 못 전해도 키를 떼면 칸이 풀림 · 전투 성적이 원정 기록과 원정 끝 화면에
func run_combo() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(308)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.5)
	var mx := int(GameState.get_flag("player_max_hp"))
	GameState.set_flag("player_hp", mx)
	v._shown.hp = mx
	for k in range(5):
		v._combo_hit(true)
	check(b.combo_heals == 0 and int(GameState.get_flag("player_hp")) == mx, "체력이 가득 차 있으면 연속 회복을 세지 않음")
	v._combo_hit(false)
	GameState.set_flag("player_hp", mx - 10)
	v._shown.hp = mx - 10
	v._render_hud()
	for k in range(4):
		v._combo_hit(true)
	check(int(GameState.get_flag("player_hp")) == mx - 10, "연속 4: 아직 회복 없음")
	v._combo_hit(true)
	await frames(2)
	check(int(GameState.get_flag("player_hp")) == mx - 9 and int(v._shown.hp) == mx - 9 and b.combo_heals == 1, "연속 5: 체력 +1 (화면도 %d)" % int(v._shown.hp))
	await secs(0.35)
	await snap("combo_01_heal")
	for k in range(45):
		v._combo_hit(true)
	check(int(GameState.get_flag("player_hp")) == mx - 5 and b.combo_heals == 5, "연속 50: 회복은 +5까지 (+%d)" % b.combo_heals)
	check(int(b.to_dict().get("combo_heals", -1)) == 5, "저장에 연속 회복 수가 남음")
	for pl in v._beat._players:
		(pl as AudioStreamPlayer).stop()
	P2Beat.gain = 0.0
	v._beat.play("kick")
	await frames(1)
	check(not v._beat._players.any(func(pl): return (pl as AudioStreamPlayer).playing), "반주 0%: 소리 안 냄")
	P2Beat.gain = 1.0
	var ko := v._keys_node()
	ko.on = true
	ko.press(KEY_Q, true, "Q")
	await secs(0.3)
	ko._input(kev(KEY_Q, false))
	await frames(2)
	check(ko.used() >= 1 and not ko.cols.any(func(c): return bool(c.down)), "키 표시: 악보가 전해 주지 않은 떼기에도 칸이 풀림")
	ko.press(KEY_W, true, "W")
	ko.on = false
	await frames(2)
	check(not ko.cols.any(func(c): return bool(c.down)), "키 표시가 꺼지면 누른 칸도 풀림")
	# 노트 모양 (그림 확인용)
	var shapes := P2NoteChart.new()
	var list: Array = []
	var kinds := ["t", "h", "d", "s", "f", "x"]
	for k in range(kinds.size()):
		var pos := Vector2(340 + k * 120, 250)
		var nd := {"pos": pos, "at": 2.2, "approach": 1.8, "kind": kinds[k], "num": k + 1}
		if kinds[k] == "h" or kinds[k] == "s":
			nd.hold = 0.5
		if kinds[k] == "s":
			nd.to = pos + Vector2(0, 90)
		list.append(nd)
	shapes.setup(list, 44.0, null, false)
	v._ui.add_child(shapes)
	shapes.set_cursor(Vector2(-999, -999))
	await secs(1.3)
	await snap("combo_02_shapes")
	shapes.queue_free()
	# 누르는 중: 길게 □는 테두리를 따라 네모로 차오르고, 따라가기 △는 세모 공이 굴러간다
	var hc := P2NoteChart.new()
	hc.setup([{"pos": Vector2(500, 250), "at": 0.5, "approach": 0.45, "kind": "h", "hold": 1.0, "num": 1},
		{"pos": Vector2(760, 230), "at": 0.5, "approach": 0.45, "kind": "s", "hold": 1.0, "to": Vector2(880, 230), "num": 2}], 44.0, null, false)
	v._ui.add_child(hc)
	await wait_until(func(): return hc.time_until(0) <= 0.01, 3.0)
	hc.set_cursor(Vector2(500, 250))
	hc._input(kev(KEY_Z, true))
	hc.set_cursor(Vector2(760, 230))
	hc._input(kev(KEY_X, true))
	for f in range(30):
		hc.set_cursor(hc.ball(1))
		await frames(1)
	await snap("combo_04_hold_follow")
	check(bool(hc.notes[0].holding) and bool(hc.notes[1].holding), "길게·따라가기를 누른 채 (그림 확인용)")
	hc.queue_free()
	# 원정 기록과 원정 끝 화면
	var n0 := (RunService.run.get("rhythm", []) as Array).size()
	v._rs.p = 6
	v._rs.g = 1
	v._rs.m = 0
	v._rs.best = 14
	P2BattleView.result_hold = 0.2
	await v._show_results()
	var rl: Array = RunService.run.get("rhythm", [])
	check(rl.size() == n0 + 1 and int(rl.back().heal) == 5, "전투 성적이 원정 기록에 남음 %s" % str(rl.back() if not rl.is_empty() else {}))
	P2BattleView.result_hold = 0.3
	h.show_result({"result": "return", "banked": {}, "rhythm": rl.duplicate(true), "build": "-", "hp": 30})
	await frames(3)
	var found := false
	var stack: Array = [h]
	while not stack.is_empty():
		var nd2: Node = stack.pop_back()
		if nd2 is Label and String((nd2 as Label).text).contains("전투 성적"):
			found = true
		stack.append_array(nd2.get_children())
	await snap("combo_03_run_result")
	check(found, "원정 끝 화면에 전투 성적 줄")
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 실제 게임 기본값 그대로(feel_force 비움 = 실행 인자 없는 본게임): 손맛 전투가 켜지는지, 적 차례 악보 동안
# 주변 느려짐·줌인·비네트·흐림·달려드는 적이 실제로 일어나는지 값으로 잰다
func run_real() -> void:
	P2BattleView.feel_force = {}
	var h := await e7_start(309)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.5)
	note("본게임 기본: parry %s · slash %s · juice %s · 새 연출 %s · 흔들림 줄이기 %s · AV7 %s" % [b.parry_mode, P2BattleView.feel_on("slash"), v._juice, v._new_fx, v._reduce_motion, v._av7_on()])
	check(b.parry_mode and v._juice and P2BattleView.feel_on("slash"), "본게임 기본으로 손맛 전투가 켜짐")
	v.end_turn()
	var seen := {"speed": 1.0, "zoom": 1.0, "vig": 0.0, "blur": 0.0, "chart": false, "enemy_tilt": 0.0, "enemy_hop": 0.0, "player_tilt": 0.0, "breath": 0.0}
	var t0 := Time.get_ticks_msec()
	var shot_done := false
	var sp0: AnimatedSprite2D = v._enemy_sprites[0]
	var y0 := sp0.position.y
	var ps0 := v._player.scale.y
	var hurt_shot := false
	while Time.get_ticks_msec() - t0 < 12000 and v.current_state() != "PLAYER":
		await get_tree().process_frame
		seen.enemy_tilt = maxf(float(seen.enemy_tilt), absf(sp0.rotation_degrees))
		seen.enemy_hop = maxf(float(seen.enemy_hop), y0 - sp0.position.y)
		seen.player_tilt = maxf(float(seen.player_tilt), absf(v._player.rotation_degrees))
		seen.breath = maxf(float(seen.breath), absf(v._player.scale.y - ps0) / ps0)
		if not hurt_shot and v._pp_tilt < -8.0:
			hurt_shot = true
			await snap("real_02_player_hit")
		var has_chart := v._ui.get_children().any(func(c): return c is P2NoteChart)
		if has_chart:
			seen.chart = true
			seen.speed = minf(float(seen.speed), v._world_speed)
			seen.zoom = maxf(float(seen.zoom), v._cam_base_z)
			if v._vig != null:
				seen.vig = maxf(float(seen.vig), float(v._vig.dark))
			if v._av7_fx != null:
				seen.blur = maxf(float(seen.blur), float(v._av7_fx.blur_px))
			if not shot_done and Time.get_ticks_msec() - t0 > 900:
				await snap("real_01_chart")
				shot_done = true
	note("악보 동안 본 값: %s" % str(seen))
	check(bool(seen.chart) and float(seen.speed) < 0.3 and float(seen.zoom) > 1.03 and float(seen.vig) > 0.3, "악보 동안 주변 느려짐·줌인·비네트 (%s)" % str(seen))
	check(float(seen.enemy_tilt) > 6.0 and float(seen.enemy_hop) > 4.0 and float(seen.player_tilt) > 8.0 and float(seen.breath) > 0.004,
		"SD 몸짓: 적 젖힘·찌름 %.0f° · 달려들 때 뜀 %.0fpx · 주인공 맞음 기울기 %.0f° · 숨쉬기 %.1f%%" % [seen.enemy_tilt, seen.enemy_hop, seen.player_tilt, float(seen.breath) * 100.0])
	# 주인공 치기: 베기를 긋고 몸짓을 잰다
	await wait_until(func(): return v.current_state() == "PLAYER", 10.0)
	await secs(0.4)
	await av7_hand(v, ["slash", "slash", "guard"])
	await secs(0.3)
	v.play_card(av7_card(v, "slash"), 0)
	var pad := await fe_pad(v)
	if pad != null:
		var pts: Array = pad.points.map(func(q): return q)
		await fe_drag(pad, [pts[0] - Vector2(40, 0)] + pts + [pts[pts.size() - 1] + Vector2(40, 0)], 0.2)
	var tmax := 0.0
	var tmin := 0.0
	var shots := 0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 2500:
		await get_tree().process_frame
		tmax = maxf(tmax, v._pp_tilt)
		tmin = minf(tmin, v._pp_tilt)
		if shots == 0 and v._pp_tilt < -6.0:
			shots = 1
			await snap("real_03_windup")
		elif shots == 1 and v._pp_tilt > 12.0:
			shots = 2
			await snap("real_04_strike")
	check(tmin < -6.0 and tmax > 12.0, "SD 주인공 치기: 뒤로 당김 %.0f° → 찌름 %.0f°" % [tmin, tmax])
	await flush_snaps()


# 봇 실력: 노트마다 미리 완벽·막음·놓침을 정한다(완벽 = 닿는 순간, 막음 = 0.1초 이르게, 놓침 = 안 누름. 페인트는 놓침이면 눌러 속음).
# 긋기도 같은 비율로 완벽(빠르게) · 정확(느리게) · 스침(안 그음). 기본은 늘 완벽
func fe_want(key: String) -> String:
	if not _fe_plan.has(key):
		var r := _fe_rng.randf()
		_fe_plan[key] = "perfect" if r < float(_fe_skill.perfect) else ("good" if r < float(_fe_skill.perfect) + float(_fe_skill.good) else "miss")
	return String(_fe_plan[key])


# 손맛 전투로 원정 끝까지: 구간 I(n1~n4·정예·보스) → 계속 → 구간 II(경로 A: H1a·H2·정예·보스) → 계속 → 구간 III(X1·X2·정예·최종 보스).
# 봇이 카드를 고르고(P2Bot), 노트·긋기는 정한 실력으로. 전투마다 체력·턴·패링·연속 회복·적별 노트 종류·표시 보정을 적는다
func run_feel_full() -> void:
	var slot := 290
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--skill="):
			var parts := String(a).substr(8).split(",")
			_fe_skill = {"perfect": float(parts[0]), "good": float(parts[1]) if parts.size() > 1 else 0.0}
		elif String(a).begins_with("--slot="):
			slot = int(String(a).substr(7))
		elif String(a).begins_with("--diff="):
			_fe_diff = String(a).substr(7)
	_fe_rng.seed = slot * 7919
	note("봇 실력: 완벽 %.0f%% · 막음 %.0f%% · 놓침 %.0f%%" % [float(_fe_skill.perfect) * 100.0, float(_fe_skill.good) * 100.0, (1.0 - float(_fe_skill.perfect) - float(_fe_skill.good)) * 100.0])
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	_fe_auto = true
	fe_autoloop()
	await new_profile(slot)
	if _fe_diff != "normal":
		check(await RunService.commit_profile("difficulty", func(c, _r, _f):
			c.combat["diff_clear"] = {"normal": true, "hard": true}
			c.combat["diff_pick"] = _fe_diff
			return true), "난이도 %s로 출발" % _fe_diff)
	check(SaveManager.commit("full"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 던전")
	var h := host()
	await secs(0.6)
	var plan := {"normal": ["n1", "n2", "elite", "n3", "n4", "boss"], "hard": ["h1a", "h2", "elite", "hboss"], "extreme": ["x1", "x2", "elite", "xboss"]}
	var dead := false
	var fought := 0
	for sector in ["normal", "hard", "extreme"]:
		if dead:
			break
		if sector != "normal":
			if not await wait_until(func(): return String(RunService.run.get("phase", "")) == "sector_choice", 15.0):
				check(false, "%s 앞: 구간 선택 창 (지금 %s)" % [sector, String(RunService.run.get("phase", ""))])
				break
			h.show_trait_choice()
			await secs(0.3)
			check(await h.choose_continue(String(RunService.run.trait_offer[0])) and String(RunService.run.sector) == sector, "계속 → %s" % sector)
			await secs(0.5)
			h.dismiss_notices()
			if sector == "hard":
				check(RunService.commit_route("a"), "경로 A")
		for id in plan[sector]:
			h.dismiss_notices()
			if not RunService.can_start_encounter(id):
				note("%s %s: 시작할 수 없어 건너뜀 (요구 %s)" % [sector, id, str(RunService.encounter_requires(id))])
				continue
			var hp0 := int(GameState.get_flag("player_hp"))
			h._on_engage(id)
			if not await h.engage_confirm(id):
				check(false, "%s 전투 시작" % id)
				break
			if not await battle_ready(h):
				check(false, "%s 차례" % id)
				break
			var v: P2BattleView = h.battle_view
			var b := v.battle
			var roles: Array = b.roles.duplicate()
			_fe_charts.clear()
			var want_mult := float(P2Catalog.SECTOR_HIT_MULT[sector]) * float(P2Catalog.diff_of(_fe_diff).hit)
			var shown: Array = []
			for i in range(b.monsters.size()):
				if P2Battle._is_damaging(b.intent(i)):
					shown.append("%s %s→%s" % [b.roles[i], str(b.intent(i)), str(b.effective_intent(i))])
			check(absf(b.hit_mult - want_mult) < 0.001, "%s %s: 적 타격 배율 ×%.2f · 첫 예고 %s" % [sector, id, b.hit_mult, str(shown)])
			if v._prompt_close.visible:
				v._prompt_close.pressed.emit()
			Engine.time_scale = 2.0
			var t0 := Time.get_ticks_msec()
			await play_some(h, 400)
			var turns := b.turn_number
			var rs: Dictionary = v._rs.duplicate(true) if is_instance_valid(v) else {}
			var heals := b.combo_heals
			var fixes := v.reconcile_fixes if is_instance_valid(v) else -1
			var over := b.battle_over
			await wait_until(func(): return h.battle_view == null, 30.0)
			Engine.time_scale = 1.0
			var hp1 := int(GameState.get_flag("player_hp"))
			fought += 1
			var kinds := {}
			for k in _fe_charts:
				var e: Dictionary = _fe_charts[k]
				var role := String(e.role)
				if not kinds.has(role):
					kinds[role] = {}
				for kd in e.kinds:
					kinds[role][kd] = int(kinds[role].get(kd, 0)) + 1
			note("전투 %s %s %s: 체력 %d → %d (최대 %d) · %d턴 · 패링 완벽 %d 막음 %d 놓침 %d · 긋기 %s · 최대 연속 %d · 연속 회복 +%d · 걸린 %.0f초 · 적별 노트 %s" % [
				sector, id, str(roles), hp0, hp1, int(GameState.get_flag("player_max_hp")), turns, int(rs.get("p", 0)), int(rs.get("g", 0)), int(rs.get("m", 0)),
				str(rs.get("sl", {})), int(rs.get("best", 0)), heals, (Time.get_ticks_msec() - t0) / 1000.0, str(kinds)])
			check(over and fixes == 0, "%s %s: 끝까지 진행 · 표시 = 실제 (보정 %d)" % [sector, id, fixes])
			if hp1 <= 0:
				note("쓰러짐: %s %s" % [sector, id])
				dead = true
				break
			await lf_reward(h)
			if String(RunService.run.get("phase", "")) == "reward":
				check(false, "%s %s 뒤 보상 단계에서 멈춤: %s" % [sector, id, str(RunService.current_part())])
				dead = true
				break
	note("원정 결과: 전투 %d번 · 쓰러짐 %s · 마지막 단계 %s · 체력 %d" % [fought, str(dead), String(RunService.run.get("phase", "끝")), int(GameState.get_flag("player_hp"))])
	_fe_auto = false
	await flush_snaps()


# 처음 하는 사람: 첫 전투 첫 턴에 연습 악보가 저절로 한 번(늘 30ms 늦게 치는 봇) → 판정 보정이 맞춰지고 저장됨 → 두 번째 전투부터는 안 나옴.
# 첫 원정의 처음 전투는 판정 창이 1.5배(입문 판정), 오차 막대에도 표시
func run_first() -> void:
	P2Ui.save_rhythm({"offset_ms": 0, "practiced": false})
	P2BattleView.ease_force = -1.0
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	_fe_auto = true
	_fe_late = 0.03
	fe_autoloop()
	var h := await e7_start(310)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	var pc: P2NoteChart = null
	var t0 := Time.get_ticks_msec()
	while pc == null and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
		for c in v._ui.get_children():
			if c is P2NoteChart and c.has_meta("practice"):
				pc = c
	check(pc != null and bool(P2Ui.load_rhythm().practiced), "처음: 첫 턴에 연습 악보가 저절로 뜸 · 다시 안 뜨게 기록")
	await secs(1.5)
	await snap("first_01_practice")
	if pc != null:
		await wait_until(func(): return not is_instance_valid(pc), 40.0)
	await wait_until(func(): return v.current_state() == "PLAYER", 5.0)
	await frames(3)
	var ms := int(P2Ui.load_rhythm().offset_ms)
	note("연습 뒤 알림: '%s' · 저장된 보정 %dms" % [v.prompt_text(), ms])
	check(ms >= 15 and ms <= 60 and absf(P2NoteChart.offset * 1000.0 - ms) < 1.0, "연습에서 늘 늦게 친 만큼 판정 보정이 맞춰짐 (+%dms)" % ms)
	_fe_late = 0.0
	v.end_turn()
	var ch: P2NoteChart = null
	t0 = Time.get_ticks_msec()
	while ch == null and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
		for c in v._ui.get_children():
			if c is P2NoteChart and c.has_meta("enemy"):
				ch = c
	check(ch != null and absf(ch.perfect_early - 0.075) < 0.001 and absf(ch.good_early - P2NoteChart.GOOD_EARLY * 1.5) < 0.001 and v._hitbar_node().eased,
		"첫 원정 첫 전투: 입문 판정 1.5배 (완벽 %.3f · 막음 %.3f)" % [ch.perfect_early if ch != null else 0.0, ch.good_early if ch != null else 0.0])
	await secs(0.6)
	await snap("first_02_eased")
	check(v._ease_k() == 1.5, "입문 배율 표: 1·2번째 전투 1.5")
	await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
	_fe_auto = false
	P2Ui.save_rhythm({"offset_ms": 0, "practiced": true})
	P2NoteChart.offset = 0.0
	P2BattleView.ease_force = 1.0
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 연속 반주 층 · 박자 심장 · 박마다 주인공·맥 숫자 · 악보 동안 예고 칸 흐림 · 보스 기록 · 소환수 폭발 노트
func run_extras() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(311)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	await secs(0.5)
	# 반주 층
	var c0: Dictionary = v._beat.counts.duplicate()
	v._rs.streak = 0
	v._on_cue("kick", 0, 0.0)
	v._on_cue("hat", 0, 0.0)
	var c1: Dictionary = v._beat.counts.duplicate()
	v._rs.streak = 12
	v._on_cue("kick", 0, 0.0)
	v._on_cue("hat", 0, 0.0)
	var c2: Dictionary = v._beat.counts.duplicate()
	v._rs.streak = 22
	v._on_cue("kick", 0, 0.0)
	var c3: Dictionary = v._beat.counts.duplicate()
	var d := func(a: Dictionary, z: Dictionary, k: String) -> int: return int(z.get(k, 0)) - int(a.get(k, 0))
	check(d.call(c0, c1, "bass") == 0 and d.call(c0, c1, "chime") == 0 and d.call(c1, c2, "bass") == 1 and d.call(c1, c2, "chime") == 1 and d.call(c2, c3, "snare") == 1,
		"연속 반주 층: 0이면 없음 · 12면 베이스+종소리 · 22면 스네어까지")
	check(v._pp_pulse > 0.5 and v._mana_label.scale.x > 1.01, "킥마다 주인공·맥 숫자가 뜀 (%.2f · %.2f)" % [v._pp_pulse, v._mana_label.scale.x])
	v._rs.streak = 0
	# 박자 심장 · 예고 칸 흐림
	var chart := P2NoteChart.new()
	chart.setup([{"pos": Vector2(640, 250), "at": 1.6, "approach": 0.6, "kind": "t", "num": 1}], 44.0, null, false)
	chart.beat = 0.5
	chart.arrange()
	v._ui.add_child(chart)
	v._wire_chart(chart)
	await secs(0.55)
	var ph0 := v._hitbar.beat_phase
	await secs(0.12)
	var ph1 := v._hitbar.beat_phase
	var ia := (v._enemy_panels[0].intent as Control).modulate.a
	await snap("extras_01_beat_heart")
	check(v._hitbar.beat_src == chart and absf(ph1 - ph0) > 0.05, "박자 심장: 악보 박자를 따라 움직임 (%.2f → %.2f)" % [ph0, ph1])
	check(ia < 0.35, "악보 동안 적 예고 칸이 흐려짐 (%.2f)" % ia)
	await wait_until(func(): return not is_instance_valid(chart), 5.0)
	await secs(0.8)
	check((v._enemy_panels[0].intent as Control).modulate.a > 0.95, "악보가 끝나면 예고 칸이 돌아옴")
	# 소환수 폭발 노트(척후 자리를 잠깐 소환수로 바꿔 악보만 만들어 봄)
	var keep_role := String(b.roles[1])
	b.roles[1] = "maek_spawn_low"
	var bomb := v._parry_chart(1, [6])
	await secs(0.9)
	await snap("extras_02_bomb")
	check(bool(bomb.notes[0].get("bomb", false)) and v.prompt_text().contains("소환수 폭발"), "소환수 폭발 노트 + 처음 설명 ('%s')" % v.prompt_text().replace("\n", " "))
	bomb.queue_free()
	b.roles[1] = keep_role
	await secs(0.6)
	# 보스 기록
	var bb0: Dictionary = GameState.combat.get("boss_best", {}).duplicate(true)
	check(h.boss_record_line("boss").contains("아직 없음") or bb0.has("boss"), "기록 전: '%s'" % h.boss_record_line("boss"))
	RunService.record_rhythm({"enc": "boss", "grade": "A", "acc": 88, "best": 30, "heal": 2})
	RunService.record_rhythm({"enc": "boss", "grade": "B", "acc": 95, "best": 41, "heal": 0})
	var r1: Dictionary = GameState.combat.boss_best.boss
	RunService.record_rhythm({"enc": "boss", "grade": "S", "acc": 97, "best": 12, "heal": 0})
	var r2: Dictionary = GameState.combat.boss_best.boss
	check(String(r1.grade) == "A" and int(r1.acc) == 88 and int(r1.best) == 41 and String(r2.grade) == "S" and int(r2.best) == 41,
		"보스 기록: A 뒤 B는 등급 안 바뀜(연속 41만 갱신) → S로 갱신 %s" % str(r2))
	check(h.boss_record_line("boss").contains("최고 S") and h.boss_record_line("boss").contains("연속 41"), "교전 창 기록 줄: '%s'" % h.boss_record_line("boss"))
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 원정의 모든 창을 차례로 열어 한 장씩 (고정값으로 상태만 만들고 진행은 하지 않음). 창마다 글자가 칸을 넘치거나 화면 밖으로 나가지 않는지 본다
func run_ui_win() -> void:
	await new_profile(296)
	check(SaveManager.commit("ui win"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	ptr_move(Vector2(1270, 710))
	h._on_engage("n1")
	await uw_snap(h, "engage", "w01_engage_n1")
	for pr in [["n1", 0, "w02_reward_card"], ["n2", 1, "w03_reward_upgrade"], ["n3", 1, "w04_reward_relic"], ["n4", 1, "w05_reward_upgrade_or_heal"]]:
		var rid := String(pr[0])
		var idx := int(pr[1])
		check(fixture(func(_c, r, _f):
			r.reward = {"id": rid, "parts": RunModel.build_parts(r, rid), "index": idx, "after": "explore"}
			r.phase = "reward"), "고정값: %s 보상 %d번째" % [rid, idx + 1])
		h.show_reward()
		await secs(0.2)
		if rid == "n2" and not h._tiles.is_empty():
			(h._tiles[0] as Button).pressed.emit()
		await uw_snap(h, "reward", String(pr[2]))
	check(fixture(func(_c, r, _f):
		r.reward = {}
		r.phase = "explore"
		r.defeated.append_array(["n1", "n2"])
		r.gold = 20
		r.hp = int(r.max_hp) - 12), "고정값: N1·N2 승리, 금화 20, 체력 −12")
	h.dungeon.refresh()
	h.show_service()
	await uw_snap(h, "service", "w06_service")
	h._pick_copy_then_upgrade(func(_sel: Dictionary) -> void: pass, tr("사본 강화 (%d금화)") % P2Catalog.SHOP_UPGRADE)
	await secs(0.2)
	var first_tile := uw_first_tile(h)
	if first_tile != null:
		first_tile.pressed.emit()
	await uw_snap(h, "pick_copy", "w07_pick_upgrade")
	h._pick_copy_to_remove()
	await secs(0.2)
	var rt := uw_first_tile(h)
	if rt != null:
		rt.mouse_entered.emit()
	await frames(2)
	check(h._peek != null and is_instance_valid(h._peek) and h._peek.size.x > 180.0, "작은 카드에 올리면 옆에 크게 (%s)" % (str(h._peek.size) if h._peek != null else "없음"))
	await uw_snap(h, "pick_copy", "w08_pick_remove")
	h.show_choice()
	await uw_snap(h, "choice", "w09_choice")
	check(fixture(func(_c, r, _f):
		r.defeated.append_array(["n3", "n4"])), "고정값: N3·N4 승리")
	h.dungeon.refresh()
	h._on_engage("boss")
	await uw_snap(h, "engage", "w10_engage_boss")
	h._dungeon_menu()
	await uw_snap(h, "menu", "w11_menu")
	h._settings_panel(func() -> void: pass)
	await uw_snap(h, "settings", "w12_settings")
	h._confirm_abandon()
	await uw_snap(h, "abandon", "w13_abandon")
	h._deck_view()
	await uw_snap(h, "deck", "w14_deck")
	check(fixture(func(_c, r, _f):
		r.defeated.append("boss")
		r.banked["normal"] = {"sector": "normal", "gold": 13, "xp": 20, "spent": 10, "bounty": {}, "level_before": 1, "level_after": 2}
		r.gold = 0
		r.xp = 0
		r.trait_offer = RunModel.trait_offer(r)
		r.phase = "sector_choice"), "고정값: 구간 I 보스 승리·정산")
	h.show_sector_choice()
	await uw_snap(h, "sector_choice", "w15_sector_choice")
	h.show_trait_choice()
	await uw_snap(h, "trait", "w16_trait")
	h.show_trait_choice()
	await frames(2)
	check(await h.choose_continue(String(RunService.run.trait_offer[0])) and String(RunService.run.sector) == "hard", "계속: 구간 II")
	await secs(0.5)
	h.dismiss_notices()
	h._on_route("a")
	await uw_snap(h, "route", "w17_route")
	var ok_ab: bool = await h._saved(RunService.abandon())
	check(ok_ab, "원정 포기")
	h.show_result(RunService.last_result())
	await secs(0.4)
	await uw_snap(h, "result", "w18_result", false)
	h.show_field_result("retreat")
	await uw_snap(h, "field_result", "w19_field_result", false)
	await flush_snaps()


func uw_first_tile(h: Node) -> Button:
	var stack: Array = [h._overlay]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Button and String((n as Button).get_meta("skin", "")) == "tile" and not (n as Button).disabled:
			return n
		stack.append_array(n.get_children())
	return null


# 창 하나: 떠 있는지, 글자가 칸을 넘치거나 화면 밖으로 나가지 않는지 보고 한 장 찍은 뒤 닫는다
func uw_snap(h: Node, modal: String, still: String, close := true) -> void:
	await secs(0.35)
	check(h.current_modal() == modal, "%s 창 열림 (%s)" % [modal, h.current_modal()])
	var bad := uw_fit(h._overlay)
	check(bad.is_empty(), "%s 글자·단추가 칸과 화면 안 %s" % [still, str(bad.slice(0, 6))])
	await snap(still)
	if close:
		h.close_modal()
		if h.dungeon != null:
			h.dungeon.set_locked(false)
		await frames(2)


func uw_fit(root: Control) -> Array:
	var bad: Array = []
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720)).grow(1.0)
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		stack.append_array(n.get_children())
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var c := n as Control
		if c is ScrollContainer:
			continue
		var r := c.get_global_rect()
		if (c is Label or c is Button) and r.size.x > 1.0 and not screen.encloses(r):
			bad.append("화면 밖: %s %s" % [uw_name(c), str(r)])
		if c is Label:
			var l := c as Label
			if l.text != "" and not l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var need := l.get_minimum_size()
				if need.x > l.size.x + 2.0 or need.y > l.size.y + 2.0:
					bad.append("넘침: %s (필요 %s · 칸 %s)" % [uw_name(c), str(need), str(l.size)])
	return bad


func uw_name(c: Control) -> String:
	if c is Label:
		return "'%s'" % (c as Label).text.substr(0, 18).replace("\n", " ")
	if c is Button:
		return "[%s]" % (c as Button).text.substr(0, 18)
	return c.name


# 리듬 유물 넷: 실제 손맛 전투에서 봇이 노트를 모두 완벽으로 누르고, 사건·상태로 효과를 본다
func run_relic_r() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	_fe_skill = {"perfect": 1.0, "good": 0.0}
	_fe_auto = true
	fe_autoloop()
	var h := await e7_start(313)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	for id in ["beat_pendulum", "echo_edge", "iron_tempo", "rhythm_heart"]:
		b.relics.append(id)
	check(b.combo_heal_cap() == P2Battle.COMBO_HEAL_CAP + P2Battle.RHYTHM_HEART_EXTRA, "리듬 심장: 연속 회복 한도 %d" % b.combo_heal_cap())
	var hp0: Array = b.monsters.map(func(m): return int(m.hp))
	var log: Array = []
	var grab := func() -> void:
		for e in b.events:
			if String(e.get("kind", "")) in ["echo_edge", "iron_tempo", "enemy_hit"] and not log.any(func(x): return is_same(x, e)):
				log.append(e)
	var t0 := b.turn_number
	v.end_turn()
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline and not (v.current_state() == "PLAYER" and b.turn_number > t0):
		grab.call()
		await get_tree().process_frame
	grab.call()
	var kinds: Array = log.map(func(e): return String(e.kind))
	var perfects := log.filter(func(e): return String(e.kind) == "enemy_hit" and String(e.get("parry", "")) == "perfect").size()
	var echo_n := kinds.count("echo_edge")
	var tempo_n := kinds.count("iron_tempo")
	note("적 차례 사건: %s · 완벽 %d · 적 체력 %s → %s" % [str(kinds), perfects, str(hp0), str(b.monsters.map(func(m): return int(m.hp)))])
	check(perfects >= 1 and echo_n == mini(perfects, P2Battle.ECHO_EDGE_MAX), "메아리 칼끝: 완벽 %d번 → 공격자에게 2씩 %d번" % [perfects, echo_n])
	check(tempo_n == mini(perfects, P2Battle.IRON_TEMPO_MAX), "강철 박자: 막은 타격마다 방어 1 (%d번)" % tempo_n)
	check(b.perfect_phase == perfects and b.pendulum_drawn == mini(P2Battle.PENDULUM_MAX, perfects / P2Battle.PENDULUM_PER), "공명 추: 완벽 %d번 → 이번 턴 %d장 더" % [perfects, b.pendulum_drawn])
	check(v.reconcile_fixes == 0, "표시 = 실제 (보정 %d)" % v.reconcile_fixes)
	await snap("relic_r_01_after_phase")
	# 완벽 6번이었다면: 복제본으로 다음 턴 손패 확인 (실제 전투는 건드리지 않음)
	var c := b._clone_for_preview()
	c.perfect_phase = 6
	c._start_turn()
	check(c.pendulum_drawn == 2 and c.hand.cards.size() == mini(P2Battle.HAND_MAX, c.HAND_SIZE + 2), "공명 추: 완벽 6번 → 다음 턴 2장 더 (손패 %d)" % c.hand.cards.size())
	_fe_auto = false
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 창 안의 표시 칸 모으기: 메타 이름 → [노드…]
func metas(root: Node, keys: Array) -> Dictionary:
	var out := {}
	for k in keys:
		out[k] = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n.is_queued_for_deletion():
			continue
		stack.append_array(n.get_children())
		for k in keys:
			if n.has_meta(k):
				(out[k] as Array).append(n)
	return out


func texts_under(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		stack.append_array(n.get_children())
		if n is Label:
			out.append((n as Label).text.replace(String.chr(0x2060), ""))
	return out


# 적 성향(하드 하나 · 익스트림 모두 + 정예 하나)과 난이도별 연속 회복 한도: 시드로 정해짐 · 교전 창 · 전투(체력·피해·이어하기 저장).
# 고정값(공개): 새 프로필(시드 309), 노멀·하드 정복으로 익스트림 출발. 입력은 스크립트
func run_affix() -> void:
	var lay := {"encounters": {"n1": {"group": "n1"}, "elite": {"group": "elite_x"}, "boss": {"group": "boss"}}}
	var base := {"seed": 1234, "sector": "normal", "layout": lay}
	var rn := base.merged({"diff": "normal"})
	var rh := base.merged({"diff": "hard"})
	var rx := base.merged({"diff": "extreme"})
	var cnt := func(a: Array) -> int: return a.filter(func(x): return String(x) != "").size()
	check(cnt.call(RunModel.encounter_affixes(rn, "n1")) == 0 and cnt.call(RunModel.encounter_affixes(rh, "n1")) == 1 and cnt.call(RunModel.encounter_affixes(rx, "n1")) == 2,
		"일반 전투 성향: 노멀 없음 · 하드 하나 · 익스트림 모두 %s" % str(RunModel.encounter_affixes(rx, "n1")))
	check(cnt.call(RunModel.encounter_affixes(rh, "elite")) == 0 and cnt.call(RunModel.encounter_affixes(rx, "elite")) == 1 and cnt.call(RunModel.encounter_affixes(rx, "boss")) == 0,
		"정예는 익스트림만 하나, 보스는 없음")
	check(RunModel.encounter_affixes(rx, "n1") == RunModel.encounter_affixes(rx.duplicate(true), "n1"), "같은 시드·전투면 같은 성향 (다시 불러와도 같음)")
	check(int(P2Catalog.DIFF.hard.heal_cap) == 4 and int(P2Catalog.DIFF.extreme.heal_cap) == 3 and int(P2Catalog.DIFF.normal.heal_cap) == 5, "연속 회복 한도 5 · 5 · 4 · 3")
	await new_profile(309)
	check(await RunService.commit_profile("affix fixture", func(c, _r, _f):
		c.combat["diff_clear"] = {"normal": true, "hard": true}
		c.combat["diff_pick"] = "extreme"
		c.combat["mods_pick"] = []
		return true), "고정값: 익스트림 출발")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	var want := RunModel.encounter_affixes(RunService.run, "n1")
	h._on_engage("n1")
	await secs(0.5)
	var lines := texts_under(h._overlay)
	var note_line := lines.filter(func(t): return String(t).begins_with("적 성향:"))
	var named := lines.filter(func(t): return want.any(func(a): return String(a) != "" and String(t).begins_with(String(P2Catalog.AFFIX[a].name) + " ")))
	check(note_line.size() == 1 and named.size() >= 1, "교전 창: 성향 붙은 이름 %s · 안내 %s" % [str(named), str(note_line)])
	await snap("affix_01_engage")
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	var b := v.battle
	check(b.affixes == want and b.combo_heal_cap() == 3, "전투: 성향 %s · 연속 회복 최대 3" % str(b.affixes))
	var ok := true
	var facts: Array = []
	for i in range(b.monsters.size()):
		var d: Dictionary = P2Catalog.ENEMIES[b.roles[i]]
		var hp_want := maxi(1, roundi(int(d.hp) * 1.3 * (P2Catalog.AFFIX_TOUGH if b.affix(i) == "tough" else 1.0)))
		ok = ok and b.monsters[i].max_hp == hp_want
		var raw := b.intent(i)
		if P2Battle._is_damaging(raw):
			var eff := b.effective_intent(i)
			ok = ok and int(eff[0]) == b.scaled(int(raw[0])) + b.attack_bonus + b.aura_for(i) + (1 if b.affix(i) == "fierce" else 0)
		facts.append("%s %s 체력 %d" % [b.affix(i), b.roles[i], b.monsters[i].max_hp])
	check(ok, "단단한 = 체력 ×1.25, 사나운 = 타격 +1 (%s)" % str(facts))
	var b2 := P2Battle.from_dict(b.to_dict(), RunModel.cards_of(RunService.run.deck), true)
	check(b2.affixes == b.affixes and b2.heal_cap == 3 and b2.monsters.map(func(m): return m.max_hp) == b.monsters.map(func(m): return m.max_hp), "이어하기 저장에도 성향·한도 그대로")
	await snap("affix_02_battle")
	await flush_snaps()


# 기록실: 정복 배지 · 오늘의 원정 · 보스 연습(만난 무리만) · 최근 원정, 원정 준비 창 '바로 출발'(지난 개인 물약).
# 고정값(공개): 새 프로필(시드 303), 날짜 2026-10-17, 아래 기록·물약을 거래로 넣음. 입력은 단추 신호
func run_records() -> void:
	RunModel.today_override = "2026-10-17"
	await new_profile(303)
	check(await RunService.commit_profile("records fixture", func(c, _r, _f):
		c.combat["diff_clear"] = {"normal": true}
		c.combat["best_score"] = {"normal": {"score": 8120, "rank": "B"}}
		c.combat["seen_groups"] = ["n1", "boss"]
		c.combat["practice_best"] = {"boss@normal": {"grade": "A", "acc": 91, "best": 24}}
		c.combat["boss_best"] = {"boss": {"grade": "S", "acc": 96, "best": 30}}
		c.combat["daily"] = {"2026-10-16": {"score": 5000, "rank": "C", "class_id": "hunter", "mods": []}}
		c.combat.history.append({"run_id": "fx-1", "result": "clear", "sector": "extreme", "class_id": "warden", "diff": "normal", "mods": ["hd"],
			"score": {"score": 8120, "rank": "B"}, "date": "2026-10-15", "daily": ""})
		c.combat.history.append({"run_id": "fx-2", "result": "lost", "sector": "hard", "class_id": "hunter", "diff": "normal", "mods": [],
			"score": {"score": 5000, "rank": "C"}, "date": "2026-10-16", "daily": "2026-10-16"})
		c.combat["seen_enemies"] = ["scout", "maek_summoner_low"]
		RunModel.unlock_achievements(c)
		return true), "고정값: 노멀 정복 · 기록 둘 · 소환사 만남")
	var menu := get_tree().current_scene
	var rec_btn := menu.get_node("ParallaxRoot/LoadButton") as Button
	check(rec_btn.visible and not rec_btn.disabled, "메인 메뉴에 기록실 단추")
	await snap("rec_00_menu")
	rec_btn.pressed.emit()
	await secs(0.6)
	var rp := get_tree().get_first_node_in_group("records_room_layer") as P5RecordsPanel
	check(rp != null, "기록실 열림")
	var m := metas(rp, ["badge", "history", "practice", "practice_go", "daily"])
	var won := {}
	for n in m.badge:
		won[String(n.get_meta("badge"))] = bool(n.get_meta("won"))
	var go := {}
	for n in m.practice_go:
		go[String(n.get_meta("practice_go"))] = not (n as Button).disabled
	check(won == {"easy": false, "normal": true, "hard": false, "extreme": false}, "정복 배지: 노멀만 ★ %s" % str(won))
	check((m.history as Array).size() == 2 and (m.practice as Array).size() == 6 and bool(go.get("boss", false)) and not bool(go.get("hboss", true)),
		"최근 원정 둘 · 연습 여섯 중 만난 소환사만 열림 %s" % str(go))
	check((m.daily as Array).size() == 1 and not ((m.daily as Array)[0] as Button).disabled, "오늘의 원정 도전 단추")
	var lines := texts_under(rp)
	check(lines.any(func(t): return String(t).contains("연습 A 91") and String(t).contains("원정 S 96")), "소환사 줄: 연습 A 91 · 원정 S 96")
	await snap("rec_01_room")
	for b in metas(rp, ["tab"]).tab:
		if String(b.get_meta("tab")) == "achv":
			(b as Button).pressed.emit()
	await secs(0.3)
	var ach := metas(rp, ["achv"]).achv as Array
	var on := ach.filter(func(n): return bool(n.get_meta("on"))).map(func(n): return String(n.get_meta("achv")))
	check(ach.size() == P2Catalog.ACHIEVEMENTS.size() and on.size() == 4 and on.has("first_run") and on.has("clear_normal") and on.has("boss_s") and on.has("daily_first"),
		"도전과제 칸: %d개 중 기록으로 열린 넷 %s" % [ach.size(), str(on)])
	await snap("rec_03_achv")
	for b in metas(rp, ["tab"]).tab:
		if String(b.get_meta("tab")) == "dex":
			(b as Button).pressed.emit()
	await secs(0.3)
	var dex := metas(rp, ["dex"]).dex as Array
	var seen := dex.filter(func(n): return bool(n.get_meta("seen"))).map(func(n): return String(n.get_meta("dex")))
	check(dex.size() == 21 and seen.size() == 2 and seen.has("maek_summoner_low"), "도감: 원정 적 21 중 만난 둘 %s" % str(seen))
	await snap("rec_04_dex")
	rp.close()
	await secs(0.3)
	var panel := P5PrepPanel.open_in(get_tree())
	await secs(0.6)
	var q := metas(panel, ["quick"]).quick as Array
	check(q.size() == 1 and not (q[0] as Button).disabled and (q[0] as Button).tooltip_text.begins_with("지난번 그대로"), "원정 준비 첫 단계: 바로 출발 (지난번 그대로)")
	await snap("rec_02_quick")
	(q[0] as Button).pressed.emit()
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "바로 출발 → 원정")
	check(String(RunService.run.class_id) == String(GameState.combat.class_id), "직업 = 지난번 그대로")
	RunModel.today_override = ""
	await flush_snaps()


# 연습실: 만난 보스를 한 판(피해·보상 없이). 그만두기 → 성적 없음 · 원정 기록 그대로, 끝까지 → 성적 · 연습 최고 기록.
# 고정값(공개): 새 프로필(시드 305), 소환사 만남, 두 번째 판은 소환사 체력을 1로 줄이고 봇(완벽 100%)이 카드를 고름
func run_practice() -> void:
	await new_profile(305)
	check(await RunService.commit_profile("practice fixture", func(c, _r, _f):
		c.combat["seen_groups"] = ["boss"]
		return true), "고정값: 소환사 만남")
	var exp0 := int(GameState.combat.stats.get("expeditions", 0))
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var rp := P5RecordsPanel.open_in(get_tree())
	await secs(0.5)
	check(rp.start_practice("boss"), "연습 시작 (맥 소환사 · 노멀)")
	check(await wait_until(func(): return host() != null and host().battle_view != null, 30.0), "연습 전투 화면")
	var h := host()
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	check(v._practice() and v.battle.source == "expedition" and v._potion_count("hp_potion") == 0 and RunService.can_use_battle_potion("hp_potion") != "" and v._enc_label().begins_with("연습"),
		"연습: 원정 무대(SD) · 물약 없음 · 이름 '%s'" % v._enc_label())
	await snap("prac_01_battle")
	check(await v.confirm_retreat(), "그만두기")
	check(await wait_until(func(): return h.current_modal() == "field_result", 10.0), "연습 결과 창")
	var lr := RunService.last_result()
	check(String(lr.get("kind", "")) == "practice" and String(lr.result) == "retreat" and not bool(lr.graded) and int(GameState.combat.stats.get("practice", 0)) == 1,
		"그만둠: 성적 없음 · 연습 1번 %s" % str(lr))
	check(RunService.run.is_empty() and int(GameState.combat.stats.get("expeditions", 0)) == exp0, "원정 기록은 그대로")
	await secs(0.8)
	await snap("prac_02_quit")
	h._leave("practice")
	check(await wait_until(func(): return host() == null and scene_path() == Flow.MENU_PATH, 20.0), "메인 메뉴로 돌아옴")
	await secs(1.0)
	rp = P5RecordsPanel.open_in(get_tree())
	await secs(0.5)
	check(rp.start_practice("boss"), "다시 연습")
	check(await wait_until(func(): return host() != null and host().battle_view != null, 30.0), "연습 전투 화면 2")
	h = host()
	check(await battle_ready(h), "차례 2")
	v = h.battle_view
	v.battle.monsters[0].hp = 1
	_fe_skill = {"perfect": 1.0, "good": 0.0}
	_fe_auto = true
	fe_autoloop()
	await play_some(h, 300)
	check(await wait_until(func(): return h.current_modal() == "field_result", 30.0), "끝까지 → 연습 결과 창")
	_fe_auto = false
	lr = RunService.last_result()
	var pb: Dictionary = (GameState.combat.get("practice_best", {}) as Dictionary).get("boss@normal", {})
	check(String(lr.get("kind", "")) == "practice" and String(lr.result) == "won" and bool(lr.graded) and not pb.is_empty() and String(pb.grade) == String(lr.grade),
		"성적 %s · 연습 최고 %s" % [str(lr.get("grade", "")), str(pb)])
	check(RunService.run.is_empty() and int(GameState.combat.stats.get("expeditions", 0)) == exp0, "원정 기록 그대로 (승리해도 보상 없음)")
	await secs(0.8)
	await snap("prac_03_result")
	h._leave("practice")
	check(await wait_until(func(): return host() == null, 20.0), "메인 메뉴로")
	await flush_snaps()


# 오늘의 원정: 날짜로 시드 · 직업 · 모드가 정해지고(고른 직업은 그대로), 끝나면 그날 기록에만(난이도 최고 점수와 따로).
# 고정값(공개): 새 프로필(시드 307), 날짜 2026-10-17, 고른 직업 수호기사. 출발하자마자 포기
func run_daily() -> void:
	RunModel.today_override = "2026-10-17"
	var s1 := RunModel.daily_spec("2026-10-17")
	var s3 := RunModel.daily_spec("2026-10-18")
	check(s1 == RunModel.daily_spec("2026-10-17") and int(s1.seed) != int(s3.seed) and String(s1.diff) == "normal", "같은 날 = 같은 구성 %s, 다른 날 = 다른 지도" % str(s1))
	await new_profile(307)
	check(await RunService.commit_profile("daily fixture", func(c, _r, _f):
		c.combat["class_id"] = "warden"
		c.combat["mods_pick"] = []
		return true), "고정값: 고른 직업 수호기사")
	var rp := P5RecordsPanel.open_in(get_tree())
	await secs(0.5)
	await snap("daily_01_room")
	check(rp.start_daily(), "오늘의 원정 도전")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var run := RunService.run
	check(String(run.get("daily", "")) == "2026-10-17" and int(run.seed) == int(s1.seed) and String(run.class_id) == String(s1.class_id) and String(run.diff) == "normal" and (run.mods as Array) == (s1.mods as Array),
		"오늘의 구성: %s · 노멀 · %s · 시드 %d" % [run.class_id, str(run.mods), int(run.seed)])
	check(String(GameState.combat.class_id) == "warden", "고른 직업은 그대로 (수호기사)")
	await secs(0.6)
	host().dismiss_notices()
	await snap("daily_02_map")
	check(RunService.abandon(), "포기")
	var dd: Dictionary = GameState.combat.get("daily", {})
	var last: Dictionary = (GameState.combat.history as Array).back()
	check(dd.has("2026-10-17") and not (GameState.combat.get("best_score", {}) as Dictionary).has("normal") and String(last.get("daily", "")) == "2026-10-17" and String(last.get("date", "")) == "2026-10-17",
		"그날 기록에만 남음 %s · 원정 기록에 날짜" % str(dd))
	RunModel.today_override = ""
	await flush_snaps()


# 성능: 가장 붐비는 전투(최종 보스 무리 연습 · 적 셋 · 악보 · 효과)에서 수직 동기를 끄고 프레임 시간과 그리기 호출을 잰다.
# --smooth로 같은 점검을 돌려 픽셀 그림판의 비용을 비교한다. 고정값(공개): 새 프로필(시드 311), 최종 보스 무리 만남, 봇 완벽 85% · 막음 10%
func run_perf_boss() -> void:
	await new_profile(311)
	check(await RunService.commit_profile("perf fixture", func(c, _r, _f):
		c.combat["seen_groups"] = ["xboss"]
		return true), "고정값: 최종 보스 무리 만남")
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var rp := P5RecordsPanel.open_in(get_tree())
	await secs(0.4)
	check(rp.start_practice("xboss"), "최종 보스 무리 연습")
	check(await wait_until(func(): return host() != null and host().battle_view != null, 30.0), "전투 화면")
	var h := host()
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await secs(0.5)
	_fe_skill = {"perfect": 0.85, "good": 0.1}
	_fe_auto = true
	fe_autoloop()
	play_some(h, 40)
	var ms: Array = []
	var draws: Array = []
	var views := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and is_instance_valid(v) and not v.battle.battle_over:
		await get_tree().process_frame
		ms.append(get_process_delta_time() * 1000.0)
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if ms.size() % 60 == 0:
			views = maxi(views, count_viewports(v))
	_fe_auto = false
	DisplayServer.window_set_vsync_mode(vsync)
	Engine.max_fps = 60
	ms.sort()
	var n := ms.size()
	var avg := 0.0
	for x in ms:
		avg += float(x)
	avg /= maxf(1.0, n)
	var dsum := 0
	for x in draws:
		dsum += int(x)
	var p95 := float(ms[int(n * 0.95)]) if n > 0 else 0.0
	var p99 := float(ms[int(n * 0.99)]) if n > 0 else 0.0
	note("성능(%s): 프레임 %d개 · 평균 %.2fms (%.0f FPS) · 95%% %.2fms · 99%% %.2fms · 최대 %.2fms · 그리기 호출 평균 %d · 픽셀 그림판 최대 %d개" % [
		"매끈" if P2Pixel.smooth() else "픽셀", n, avg, 1000.0 / maxf(0.001, avg), p95, p99, float(ms.back()) if n > 0 else 0.0, dsum / maxi(1, draws.size()), views])
	check(n > 300 and p95 < 33.4, "성능: 95%% 프레임이 30 FPS보다 빠름 (%.2fms)" % p95)
	await flush_snaps()


func count_viewports(root: Node) -> int:
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is SubViewport:
			n += 1
		stack.append_array(x.get_children(true))
	return n


# 연출: 지도→전투 점 무늬 전환(지도 줌) · 구간 I 분위기 입자 · 연속 10 금빛 테두리 · 낮은 체력 심장 박동 · 적 차례 뒤 카메라 원위치 ·
# 키 지정(두 키) · 마지막 일격(시간 배율 원래대로). 고정값(공개): 새 프로필(시드 313), 표시 체력만 25%로, 둘째 턴에 적 체력을 1로, 봇(완벽 100%)
func run_fx() -> void:
	await new_profile(313)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	_fe_skill = {"perfect": 1.0, "good": 0.0}
	_fe_auto = true
	fe_autoloop()
	h._on_engage("n1")
	await secs(0.4)
	h.engage_confirm("n1")
	var mid := false
	for i in range(60):
		await get_tree().process_frame
		if h._fade_p > 0.25 and h._fade_p < 0.95 and h.dungeon != null and (h.dungeon as P2MapView)._map.scale.x > 1.05:
			mid = true
			await snap("fx_01_dive")
			break
	check(mid, "교전 시작: 지도가 고른 곳으로 줌 · 점 무늬 막이 좁혀 듦")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	await secs(0.3)
	check(v._amb != null and v._amb.kind == "water" and v._amb._p.size() > 20 and h._fade_p == 0.0, "구간 I: 물방울·먼지 입자 · 전환 막 걷힘")
	await snap("fx_02_battle")
	v._combo_burst(10)
	await secs(0.06)
	check(v._edge != null and float((v._edge.material as ShaderMaterial).get_shader_parameter("amount")) > 0.2, "연속 10: 금빛 테두리")
	await snap("fx_03_combo10")
	v._shown.hp = int(float(v._run_info.max_hp) * 0.25)
	v._render_hud()
	var b0 := v._heart_beat
	await secs(1.4)
	check(float(v._vig.danger) > 0.0 and v._heart_beat >= b0 + 1, "낮은 체력: 심장 박동 (박 %d → %d)" % [b0, v._heart_beat])
	await snap("fx_04_heart")
	v._shown.hp = int(GameState.get_flag("player_hp"))
	v._render_hud()
	v.open_menu_for_test()
	await secs(0.3)
	var pick: Array = metas(v, ["keys_pick"]).keys_pick
	check(pick.size() == 1, "메뉴: 키 지정 단추")
	if pick.size() == 1:
		(pick[0] as Button).pressed.emit()
		await key_tap(KEY_D)
		await key_tap(KEY_F)
		await frames(2)
		check(P2NoteChart.hit_keys == [KEY_D, KEY_F] and String(P2Ui.load_rhythm().keys) == "custom:%d,%d" % [KEY_D, KEY_F], "키 지정: D·F 저장")
		await snap("fx_05_keys")
	v.close_popups_for_test()
	P2Ui.save_rhythm({"keys": "any"})
	P2NoteChart.hit_keys = []
	await secs(0.2)
	await v.end_turn()
	check(await wait_until(func(): return v.current_state() == "PLAYER", 40.0), "둘째 턴")
	await secs(0.4)
	check(absf(v._cam_base_z - 1.0) < 0.001 and v._cam_base_off.length() < 0.01, "적 차례가 끝나면 카메라 원위치")
	for m in v.battle.monsters:
		if m.is_alive():
			m.hp = 1
	var ts := Engine.time_scale
	var flog: Array = v.final_log
	fx_watch_final(v)
	await play_some(h, 40)
	await secs(1.2)
	check(flog.any(func(e): return (e as Dictionary).has("final")) and is_equal_approx(Engine.time_scale, ts), "마지막 일격 · 시간 배율 원래대로 (%.2f)" % Engine.time_scale)
	_fe_auto = false
	await flush_snaps()


func fx_watch_final(v: P2BattleView) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(v) and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		if v.final_log.any(func(e): return (e as Dictionary).has("final")):
			await get_tree().create_timer(0.12, true, false, true).timeout
			await snap("fx_06_final")
			return


# 심층·균열 무대 분위기: 연습으로 구간 II 보스(푸른 불티 · 흔들리는 횃불 빛)와 최종 보스 무리(불씨·재). 고정값(공개): 새 프로필(시드 315), 두 무리 만남
func run_fx_deep() -> void:
	await new_profile(315)
	check(await RunService.commit_profile("fx fixture", func(c, _r, _f):
		c.combat["seen_groups"] = ["hboss", "xboss"]
		return true), "고정값: 구간 II·III 보스 만남")
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	for spec in [["hboss", "frost", "fx_10_frost"], ["xboss", "ember", "fx_11_ember"]]:
		var rp := P5RecordsPanel.open_in(get_tree())
		await secs(0.4)
		check(rp.start_practice(String(spec[0])), "%s 연습" % spec[0])
		check(await wait_until(func(): return host() != null and host().battle_view != null, 30.0), "전투 화면")
		var h := host()
		check(await battle_ready(h), "차례")
		var v: P2BattleView = h.battle_view
		await secs(1.5)
		check(v._amb != null and v._amb.kind == String(spec[1]) and v._amb._p.size() > 20 and v._torches.size() == 2, "%s: %s 입자 %d · 횃불 빛 둘" % [spec[0], spec[1], v._amb._p.size()])
		await snap(String(spec[2]))
		check(await v.confirm_retreat(), "그만두기")
		check(await wait_until(func(): return h.current_modal() == "field_result", 10.0), "결과")
		await secs(0.4)
		h._leave("practice")
		check(await wait_until(func(): return host() == null and scene_path() == Flow.MENU_PATH, 20.0), "메인 메뉴로")
		await secs(0.8)
	await flush_snaps()


# 원정 레벨·능력치: 경험치 곡선 · 후보(직업 가중·한도·같은 시드 같은 후보) · 레벨업 창 · 지도 칩 · 전투 반영(힘·수비·치명) · 저장 이어하기.
# 고정값(공개): 새 프로필(시드 321), 수호기사 노멀, 원정 능력치를 거래로 넣음
func run_level() -> void:
	var r0 := {"seed": 77, "sector": "normal", "class_id": "warden", "log": [], "lv": 1, "lv_xp": 0, "stats": {}, "lv_picks": []}
	var g1 := RunModel.gain_run_xp(r0, 7)
	var g2 := RunModel.gain_run_xp(r0, 1)
	check(g1 == 0 and g2 == 1 and int(r0.lv) == 2 and int(r0.lv_xp) == 0 and (r0.lv_picks as Array).size() == 1, "경험치 8 → 레벨 2, 고르기 하나")
	RunModel.gain_run_xp(r0, 22)
	check(int(r0.lv) == 4 and int(r0.lv_xp) == 0 and (r0.lv_picks as Array).size() == 3, "8 + 10 + 12 = 30 → 레벨 4, 고르기 셋")
	var offer: Array = r0.lv_picks[0]
	var ids := offer.map(func(o): return String(o.stat))
	var distinct := {}
	for i in ids:
		distinct[i] = true
	check(offer.size() == 3 and distinct.size() == 3 and ids.all(func(i): return P2Catalog.STATS.has(i)), "후보 셋, 서로 다름 %s" % str(offer))
	check(str(RunModel.stat_offer(r0, 2)) == str(offer), "같은 시드·레벨 = 같은 후보 (다시 불러와도 같음)")
	var tally := {}
	for s in range(300):
		var rr := {"seed": s, "sector": "normal", "class_id": "warden", "stats": {}}
		for o in RunModel.stat_offer(rr, 2):
			tally[o.stat] = int(tally.get(o.stat, 0)) + 1
	check(int(tally.get("def", 0)) > int(tally.get("arc", 0)) * 1.5, "수호기사는 수비가 마력보다 자주 %s" % str(tally))
	var capped := {"seed": 5, "sector": "normal", "class_id": "rune_caster", "stats": {"focus": 40, "crit": 40}}
	var never := true
	for s in range(60):
		capped.seed = s
		for o in RunModel.stat_offer(capped, 3):
			never = never and not (String(o.stat) in ["focus", "crit"])
	check(never, "한도에 닿은 능력치(집중 40 · 치명 40)는 후보에 안 나옴")

	await new_profile(321)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(int(RunService.run.lv) == 1 and (RunService.run.stats as Dictionary).is_empty(), "새 원정: 레벨 1 · 능력치 없음")
	check(await RunService.commit_profile("level fixture", func(_c, r, _f):
		r.stats = {"str": 2, "def": 3, "crit": 5, "cdmg": 40}
		r.lv = 3
		r.lv_picks = [[{"stat": "vit", "amount": 6, "rare": false}, {"stat": "str", "amount": 2, "rare": true}, {"stat": "focus", "amount": 8, "rare": false}]]
		return true), "고정값: 레벨 3 · 힘 2 · 수비 3 · 치명 5 · 치명 피해 40 · 고르기 하나")
	h.dungeon.refresh()
	await secs(0.3)
	var mv := h.dungeon as P2MapView
	check(mv != null and mv._lv_label.text == "Lv 3 ▲1", "지도 위 띠: %s" % (mv._lv_label.text if mv != null else "없음"))
	mv._lv_btn.pressed.emit()
	await secs(0.5)
	check(h.current_modal() == "level" and h._tiles.size() == 3, "레벨 칩 → 레벨업 창, 후보 셋")
	await snap("level_01_pick")
	var hp0 := int(RunService.run.hp)
	var mx0 := int(RunService.run.max_hp)
	h._tiles[0].pressed.emit()
	await secs(0.2)
	var bd: P5StatBoard = h._level_board
	check(bd != null and (bd._rows.vit.delta as Label).text.contains("+6") and (bd._rows.str.val as Label).text == "+2" and (bd._rows.arc.val as Label).text == "—",
		"능력치 판: 고른 체력 줄에 %s · 힘 %s · 마력 %s" % [(bd._rows.vit.delta as Label).text if bd != null else "-", (bd._rows.str.val as Label).text if bd != null else "-", (bd._rows.arc.val as Label).text if bd != null else "-"])
	await snap("level_02_preview")
	h.confirm_level("vit")
	await secs(0.2)
	check(h.current_modal() == "level" and (bd._rows.vit.val as Label).text != "—", "고른 뒤 잠깐 숫자가 올라가는 모습 (%s)" % (bd._rows.vit.val as Label).text)
	await snap("level_03_bump")
	await secs(0.8)
	check(int(RunService.run.max_hp) == mx0 + 6 and int(RunService.run.hp) == hp0 + 6 and RunService.stat_pending() == 0, "체력 +6: 최대 %d → %d, 지금 %d → %d" % [mx0, int(RunService.run.max_hp), hp0, int(RunService.run.hp)])
	check(h.current_modal() == "" and mv._lv_label.text == "Lv 3", "다 고르면 창 닫힘 · 칩 %s" % mv._lv_label.text)
	mv._lv_btn.pressed.emit()
	await secs(0.4)
	check(h.current_modal() == "stats", "고를 것 없을 때 레벨 칩 → 능력치 판")
	await snap("level_04_stats")
	(h._confirm_button as Button).pressed.emit()
	await secs(0.2)
	check(h.current_modal() == "", "능력치 판 닫기")
	check(not RunService.choose_stat("str"), "남은 고르기 없으면 거절")
	h._on_engage("n1")
	await secs(0.4)
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var b: P2Battle = h.battle_view.battle
	check(b.stat("str") == 2 and b.stat("def") == 3 and b.stat("vit") == 6, "전투에 능력치 %s" % str(b.stats))
	var slash := P2Catalog.build_card("slash", "lvt1")
	var pv := b.preview(slash, 0)
	var dmg := int(pv.monsters[0].hp_before) - int(pv.monsters[0].hp)
	check(dmg == 5 + 2, "베기 5 + 힘 2 = %d" % dmg)
	var twin := P2Catalog.build_card("twin_slash", "lvt2")
	var pt := b.preview(twin, 0)
	check(int(pt.monsters[0].hp_before) - int(pt.monsters[0].hp) == (3 + 2) * 2, "연속 타격: 타격마다 힘 → (3+2)×2")
	var guard := P2Catalog.build_card("guard", "lvt3")
	check(int(b.preview(guard, -1).block) - b._pending_defense == 5 + 3, "수호 5 + 수비 3")
	check(b.crit_chance() == P2Catalog.CRIT_BASE_CHANCE + 5 and is_equal_approx(b.crit_mult(), P2Catalog.CRIT_BASE_MULT + 0.4), "치명 %d%% · 배율 %.2f" % [b.crit_chance(), b.crit_mult()])
	var f := P2Catalog.face(slash, "warden")
	check(String(f[0]) == "물리 7" and int(f[2]) == 2, "카드 얼굴: %s (초록 +%d)" % [String(f[0]), int(f[2])])
	var b2 := P2Battle.from_dict(b.to_dict(), RunModel.cards_of(RunService.run.deck), true)
	check(b2.stats == b.stats, "이어하기 저장에도 능력치 그대로")
	b2.strike_grade = "hit"
	b2.strike_power = 1.5
	b2._crit_override = -1
	b2.stats["crit"] = 100
	b2._decide_crit(slash, 0)
	var hit_crit := b2._card_crit and is_equal_approx(b2._crit_mult_now(0), 1.5 + 0.4)
	b2.stats["crit"] = 0
	b2._decide_crit(slash, 0)
	check(hit_crit and not b2._card_crit, "긋기 '맞힘'은 능력치 치명 확률로만 치명, 배율은 긋기 배율 + 치명 피해")
	b2.strike_grade = ""
	await snap("level_02_battle")
	await finish_battle(h)
	check(await wait_until(func(): return h.current_modal() == "reward", 20.0), "N1 승리 → 보상 창")
	check(int(RunService.run.lv_xp) == int(P2Catalog.RUN_XP.fight) and int(RunService.run.lv) == 3, "원정 경험치 +%d (레벨 3, %d/%d)" % [int(P2Catalog.RUN_XP.fight), int(RunService.run.lv_xp), P2Catalog.lv_need(3)])
	await snap("level_03_reward")
	await h.confirm_reward({"skip": true})
	await secs(0.4)
	check(h.current_modal() == "" and P2Catalog.view_stats.get("str", 0) == 2, "레벨 안 오르면 창 없음 · 지도 카드 얼굴도 능력치 반영")
	await flush_snaps()


# 원거리 적 공격 = 언다인식 화살 막기: 미리 돌린 방패로 막음 · 다른 쪽이면 맞음 · 노랑은 넘어와 반대쪽에서 닿음 · 빠른 강타 화살 · 늦게 돌리면 맞음,
# 그리고 실제 N2(방패병 + 사수)에서 방패병은 고리, 사수는 화살 막기. 고정값(공개): 새 프로필(시드 327), 키는 _input에 직접 넣는다
func run_arrow() -> void:
	P2NoteChart.offset = 0.0
	var h := await e7_start(327)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	var ch := P2ArrowChart.new()
	ch.center = Vector2(430, 280)
	var mk := func(at: float, lane: int, arrow: String, extra: Dictionary) -> Dictionary:
		var d := {"pos": Vector2.ZERO, "at": at, "approach": 0.6, "kind": "a", "hold": 0.0, "num": 0, "lane": lane, "arrow": arrow}
		d.merge(extra, true)
		return d
	ch.setup([mk.call(0.8, 1, "n", {}), mk.call(1.3, 0, "n", {}), mk.call(1.9, 3, "rev", {}), mk.call(2.5, 2, "fast", {"crush": true}), mk.call(3.0, 1, "n", {})], 32.0, null, false)
	v._ui.add_child(ch)
	var aimed: Array = []
	for at in [Vector2(0, -60), Vector2(-80, 10), Vector2(3, 3), Vector2(30, 70)]:
		var mm := InputEventMouseMotion.new()
		mm.position = ch.center + at
		ch._input(mm)
		aimed.append(ch.face)
	check(str(aimed) == str([0, 3, 3, 2]), "마우스로 방패: 위 · 왼쪽 · 심장 위는 그대로 · 아래 %s" % str(aimed))
	var far := InputEventMouseMotion.new()
	far.position = ch.center + Vector2(420, -10)
	ch._input(far)
	var after_far := ch.face
	var kev := InputEventKey.new()
	kev.physical_keycode = KEY_LEFT
	kev.keycode = KEY_LEFT
	kev.pressed = true
	ch._input(kev)
	kev.pressed = false
	ch._input(kev)
	var jig := InputEventMouseMotion.new()
	jig.position = ch.get_local_mouse_position() + Vector2(6, 4)
	ch._input(jig)
	var after_jig := ch.face
	check(after_far == 2 and after_jig == 3, "상자 밖 마우스는 무시 · 키로 돌린 뒤 마우스가 조금 떨려도 키 방향 유지 (%d · %d)" % [after_far, after_jig])
	var gs := {}
	ch.judged.connect(func(i: int, g: String, _d: float) -> void: gs[i] = g)
	var plan := [[0.5, KEY_RIGHT, true], [0.52, KEY_RIGHT, false], [1.7, KEY_A, true], [1.72, KEY_A, false], [2.3, KEY_S, true], [2.32, KEY_S, false], [3.05, KEY_RIGHT, true], [3.07, KEY_RIGHT, false]]
	var k := 0
	var before := []
	var after := -1
	var shot := false
	var t0 := Time.get_ticks_msec()
	while gs.size() < 5 and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
		if before.is_empty() and ch._t >= 1.3:
			before = [ch.lane_at(ch.notes[2]), ch.head_pos(ch.notes[2]).x > ch.center.x]
		if after < 0 and ch._t >= 1.7:
			after = ch.lane_at(ch.notes[2])
		while k < plan.size() and ch._t >= float(plan[k][0]):
			var ev := InputEventKey.new()
			ev.physical_keycode = plan[k][1]
			ev.keycode = plan[k][1]
			ev.pressed = plan[k][2]
			ch._input(ev)
			k += 1
		if not shot and ch._t >= 1.55:
			shot = true
			await snap("arrow_01_hop")
	check(str(gs) == str({0: "perfect", 1: "miss", 2: "perfect", 3: "perfect", 4: "miss"}),
		"화살 막기: 미리 돌림 막음 · 다른 쪽 맞음 · 노랑 넘어온 쪽 막음 · 빠른 강타 막음 · 늦게 돌림 맞음 %s" % str(gs))
	check(str(before) == str([1, true]) and after == 3, "노랑 화살: 처음엔 오른쪽에서 오다가 넘어가 왼쪽에서 닿음 (%s → %d)" % [str(before), after])
	await finish_battle(h)
	check(await wait_until(func(): return h.current_modal() == "reward", 20.0), "N1 승리 → 보상 창")
	await h.confirm_reward({"skip": true})
	await secs(0.4)
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	h._on_engage("n2")
	check(await h.engage_confirm("n2"), "N2 전투 (방패병과 사수)")
	check(await battle_ready(h), "차례")
	v = h.battle_view
	check(v._arrow_enemy(1) and not v._arrow_enemy(0), "사수만 화살 막기")
	_fe_skill = {"perfect": 1.0, "good": 0.0}
	_fe_auto = true
	fe_autoloop()
	var kinds := {}
	var arrow_chart: P2ArrowChart = null
	for turn in range(3):
		if arrow_chart != null:
			break
		v.end_turn()
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 15000:
			await get_tree().process_frame
			for c in v._ui.get_children():
				if c is P2NoteChart and c.has_meta("enemy"):
					kinds[int(c.get_meta("enemy"))] = c.get_class() if not (c is P2ArrowChart) else "P2ArrowChart"
					if c is P2ArrowChart and arrow_chart == null:
						arrow_chart = c
			if arrow_chart != null or (v.current_state() == "PLAYER" and Time.get_ticks_msec() - t0 > 1500):
				break
	check(arrow_chart != null and String(kinds.get(1, "")) == "P2ArrowChart" and String(kinds.get(0, "")) != "P2ArrowChart", "실제 전투: 방패병 고리 · 사수 화살 %s" % str(kinds))
	if arrow_chart != null:
		var ac := arrow_chart
		await wait_until(func(): return not is_instance_valid(ac) or ac._t >= float(ac.notes[0].at) - 0.25, 6.0)
		await snap("arrow_02_battle")
	await wait_until(func(): return v.current_state() == "PLAYER", 20.0)
	_fe_auto = false
	var ar := v.parry_log.filter(func(e): return String(e.kind) == "a")
	check(not ar.is_empty() and ar.all(func(e): return String(e.grade) == "perfect") and v.reconcile_fixes == 0, "봇이 방패를 돌려 화살 %d발 모두 막음 · 표시 = 실제" % ar.size())
	# 손대지 않으면: 처음 방패(오른쪽)에 오는 화살만 막히고, 묶음 피해는 막은 발 수만큼 준다
	_fe_skill = {"perfect": 0.0, "good": 0.0}
	_fe_plan.clear()
	_fe_auto = true
	var idle: P2ArrowChart = null
	for turn in range(3):
		if idle != null:
			break
		v.end_turn()
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 15000:
			await get_tree().process_frame
			for c in v._ui.get_children():
				if c is P2ArrowChart and c.has_meta("enemy"):
					idle = c
			if idle != null or (v.current_state() == "PLAYER" and Time.get_ticks_msec() - t0 > 1500):
				break
	var lanes: Array = idle.notes.map(func(q): return int(q.lane)) if idle != null else []
	var hp0 := int(GameState.get_flag("player_hp"))
	var log0 := v.parry_log.size()
	await wait_until(func(): return v.current_state() == "PLAYER" or v.battle.battle_over, 20.0)
	_fe_auto = false
	var got: Array = v.parry_log.slice(log0).filter(func(e): return String(e.kind) == "a").map(func(e): return String(e.grade))
	var want: Array = lanes.map(func(l): return "perfect" if l == 1 else "miss")
	note("손대지 않은 화살: 방향 %s · 판정 %s · 체력 %d → %d" % [str(lanes), str(got), hp0, int(GameState.get_flag("player_hp"))])
	var blocked := want.count("perfect")
	var dmg_want := 0 if blocked == lanes.size() else 9 - (maxi(1, floori(9.0 * blocked / lanes.size())) if blocked > 0 else 0)
	check(not lanes.is_empty() and str(got) == str(want), "손대지 않으면 오른쪽(처음 방패) 화살만 막힘 %s" % str(got))
	check(hp0 - int(GameState.get_flag("player_hp")) == dmg_want, "피해는 막은 발 수만큼 줄어듦: %d발 중 %d발 → %d" % [lanes.size(), blocked, dmg_want])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 적 공격 장르 셋을 따로 띄워 실제 입력으로: 북 장단(색·연타·큰 북) · 박자 피하기(마우스 칸·키 한 칸·나를 노림·한 칸만 안전) ·
# 부름-응답(부름 중 누름은 무시·클릭·아무 키·안 치면 놓침). 그리고 적 표의 장르 배정. 고정값(공개): 새 프로필(시드 329)
func run_genres() -> void:
	P2NoteChart.offset = 0.0
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(329)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	var want_genre := {"scout": "osu", "archer": "arrow", "breaker": "drum", "leader": "drum", "hexer": "dodge", "cannon": "dodge", "maek_summoner_low": "echo", "mimic_n": "echo", "x_boss": "medley"}
	var bad: Array = []
	for role in want_genre:
		if String(P2Catalog.ENEMIES[role].get("parry", "osu")) != String(want_genre[role]):
			bad.append(role)
	check(bad.is_empty(), "적 표 장르 배정 (틀린 것 %s)" % str(bad))
	var drive := func(ch: P2NoteChart, plan: Array, total: int, shot: String, shot_t: float) -> Dictionary:
		var gs := {}
		ch.judged.connect(func(i: int, g: String, _d: float) -> void: gs[i] = g)
		var k := 0
		var shot_done := false
		var t0 := Time.get_ticks_msec()
		while gs.size() < total and Time.get_ticks_msec() - t0 < 9000:
			await get_tree().process_frame
			while k < plan.size() and ch._t >= float(plan[k][0]):
				ch._input(plan[k][1])
				k += 1
			if not shot_done and ch._t >= shot_t:
				shot_done = true
				await snap(shot)
		return gs
	var key := func(code: Key, down: bool) -> InputEventKey:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		return ev
	var click := func(right: bool) -> InputEventMouseButton:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
		ev.pressed = true
		return ev
	var move := func(at: Vector2) -> InputEventMouseMotion:
		var ev := InputEventMouseMotion.new()
		ev.position = at
		return ev
	var base := func(at: float, kind: String, extra: Dictionary) -> Dictionary:
		var d := {"pos": Vector2.ZERO, "at": at, "approach": 0.6, "kind": kind, "hold": 0.0, "num": 0}
		d.merge(extra, true)
		return d
	# 북 장단
	var dr := P2DrumChart.new()
	dr.judge_x = 400.0
	dr.setup([base.call(0.8, "drum", {"drum": "don"}), base.call(1.2, "drum", {"drum": "ka"}), base.call(1.6, "drum", {"drum": "ka"}),
		base.call(2.0, "drum", {"drum": "roll", "hold": 0.5}), base.call(3.0, "drum", {"drum": "don", "crush": true})], 32.0, null, false)
	dr.beat = 0.5
	v._ui.add_child(dr)
	var dg: Dictionary = await drive.call(dr, [[0.8, click.call(false)], [1.2, key.call(KEY_F, true)], [1.21, key.call(KEY_F, false)], [1.6, key.call(KEY_K, true)], [1.61, key.call(KEY_K, false)],
		[2.02, key.call(KEY_J, true)], [2.55, key.call(KEY_J, false)]], 5, "genre_01_drum", 2.2)
	check(str(dg) == str({0: "perfect", 1: "miss", 2: "perfect", 3: "perfect", 4: "miss"}), "북 장단: 왼쪽 클릭 둥 · 색 틀림 놓침 · K 딱 · 노랑 길게 끝까지 누름 · 안 친 큰 북 놓침 %s" % str(dg))
	if is_instance_valid(dr):
		dr.queue_free()
	# 박자 피하기
	var dz := P2DodgeChart.new()
	dz.center = Vector2(430, 290)
	var row1 := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var col1 := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	var all_but: Array = []
	for y in range(3):
		for x in range(3):
			if Vector2i(x, y) != Vector2i(0, 2):
				all_but.append(Vector2i(x, y))
	dz.setup([base.call(1.2, "dodge", {"sub": "row", "tiles": row1}), base.call(1.7, "dodge", {"sub": "col", "tiles": col1}),
		base.call(2.4, "dodge", {"sub": "chase", "tiles": []}), base.call(3.0, "dodge", {"sub": "all", "tiles": all_but, "crush": true})], 32.0, null, false)
	dz.beat = 0.5
	v._ui.add_child(dz)
	var locked := []
	var zplan := [[0.9, move.call(dz.tile_rect(Vector2i(1, 0)).get_center())], [2.2, key.call(KEY_RIGHT, true)], [2.21, key.call(KEY_RIGHT, false)],
		[2.7, move.call(dz.tile_rect(Vector2i(0, 2)).get_center())]]
	var zg := {}
	dz.judged.connect(func(i: int, g: String, _d: float) -> void: zg[i] = g)
	var zk := 0
	var zshot := false
	var zt0 := Time.get_ticks_msec()
	while zg.size() < 4 and Time.get_ticks_msec() - zt0 < 9000:
		await get_tree().process_frame
		if locked.is_empty() and dz._t >= 2.1:
			locked = (dz.notes[2].tiles as Array).duplicate()
		while zk < zplan.size() and dz._t >= float(zplan[zk][0]):
			dz._input(zplan[zk][1])
			zk += 1
		if not zshot and dz._t >= 2.85:
			zshot = true
			await snap("genre_02_dodge")
	check(str(zg) == str({0: "perfect", 1: "miss", 2: "perfect", 3: "perfect"}), "박자 피하기: 마우스로 위 칸 피함 · 세로줄에 서서 맞음 · 노린 칸에서 키로 비킴 · 한 칸 남은 곳 피함 %s" % str(zg))
	check(str(locked) == str([Vector2i(1, 0)]), "나를 노림: 터지기 한 박 전에 서 있던 칸에 고정 %s" % str(locked))
	if is_instance_valid(dz):
		dz.queue_free()
	# 부름-응답
	var ec := P2EchoChart.new()
	ec.setup([base.call(2.0, "echo", {}), base.call(2.5, "echo", {}), base.call(3.0, "echo", {})], 32.0, null, false)
	ec.beat = 0.5
	ec.call = 2.0
	ec.arrange()
	v._ui.add_child(ec)
	var eg: Dictionary = await drive.call(ec, [[1.0, click.call(false)], [2.0, click.call(false)], [2.5, key.call(KEY_Z, true)], [2.51, key.call(KEY_Z, false)]], 3, "genre_03_echo", 2.6)
	check(str(eg) == str({0: "perfect", 1: "perfect", 2: "miss"}), "부름-응답: 부름 중 누름 무시 · 클릭 · 아무 키 · 안 치면 놓침 %s" % str(eg))
	if is_instance_valid(ec):
		ec.queue_free()
	# 실제 적 차례: 같은 N1에서 장르를 하나씩 강제로 바꿔 무대 자리·손패 숨김·봇 통과를 본다
	_fe_skill = {"perfect": 1.0, "good": 0.0}
	_fe_auto = true
	fe_autoloop()
	var classes := {"arrow": "P2ArrowChart", "drum": "P2DrumChart", "dodge": "P2DodgeChart", "echo": "P2EchoChart"}
	for g in ["drum", "dodge", "echo", "arrow"]:
		P2BattleView.genre_force = g
		await wait_until(func(): return v.current_state() == "PLAYER", 15.0)
		var log0 := v.parry_log.size()
		v.end_turn()
		var seen: P2NoteChart = null
		var gt0 := Time.get_ticks_msec()
		while seen == null and Time.get_ticks_msec() - gt0 < 12000:
			await get_tree().process_frame
			for c in v._ui.get_children():
				if c is P2NoteChart and c.has_meta("enemy"):
					seen = c
		var ok_class := seen != null and not v._plain_chart(seen) and String(seen.get_script().get_global_name()) == String(classes[g])
		await frames(2)
		var hidden := v._hand_root.position.y >= 300.0
		if seen != null:
			var sc := seen
			await wait_until(func(): return not is_instance_valid(sc) or sc._t >= float(sc.notes[0].at) - 0.2, 6.0)
			await snap("genre_real_%s" % g)
			note("%s 손패 y %.0f · 레일 %.2f · 줄임 %s" % [g, v._hand_root.position.y, v._hand_rail.modulate.a if v._hand_rail != null else -1.0, str(v._reduce_motion)])
		await wait_until(func(): return v.current_state() == "PLAYER" or v.battle.battle_over, 25.0)
		var got: Array = v.parry_log.slice(log0).map(func(e): return String(e.grade))
		check(ok_class and not got.is_empty() and got.all(func(x): return x == "perfect") and v.reconcile_fixes == 0 and v._hand_root.position.y < 1.0 and hidden,
			"실제 적 차례 %s: 아래 무대 · 봇 완벽 %d개 · 표시 = 실제 · 다음 차례 손패 복귀" % [g, got.size()])
	P2BattleView.genre_force = ""
	_fe_auto = false
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 구간 이동 연출: 계속하면 지금 지도가 안쪽 고리로 빨려 들어가고(배율이 커짐) 새 구간 지도가 가까이서 물러나며 이름판이 뜬다.
# 고정값(공개): 새 프로필(시드 331), 구간 I을 이긴 것으로 표시
func run_sector() -> void:
	await new_profile(331)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		r.defeated.append_array(["n1", "n2", "n3", "n4", "boss"])
		r.banked["normal"] = {"sector": "normal", "gold": 13, "xp": 20, "spent": 0, "bounty": {}, "level_before": 1, "level_after": 2}
		r.gold = 0
		r.xp = 0
		r.trait_offer = RunModel.trait_offer(r)
		r.phase = "sector_choice"), "고정값: 구간 I 이긴 것으로")
	h.show_sector_choice()
	await secs(0.3)
	h.show_trait_choice()
	await secs(0.3)
	var old_map = h.dungeon
	var old_id: int = old_map.get_instance_id()
	h.choose_continue(String(RunService.run.trait_offer[0]))
	await secs(0.82)
	var zoom: float = old_map._map.scale.x if is_instance_valid(old_map) else -1.0
	await snap("sector_01_zoom")
	check(zoom > 1.2, "안쪽 고리로 빨려 들어감 (배율 %.2f)" % zoom)
	await wait_until(func(): return h.dungeon != null and h.dungeon.get_instance_id() != old_id, 6.0)
	await secs(0.55)
	await snap("sector_02_arrive")
	var mv := h.dungeon as P2MapView
	check(mv != null and mv.sector == "hard", "새 구간 지도 (구간 II)")
	await wait_until(func(): return not h.dungeon.locked, 8.0)
	await secs(0.3)
	check(mv != null and is_equal_approx(mv._map.scale.x, 1.0) and not h.dungeon.locked, "자리 잡고 조작 가능")
	await snap("sector_03_settled")
	await flush_snaps()


# 콤보술사: 연격(같은 적 연타 +1 · 피해 +연격 · 다른 적이면 0) · 마무리 일격(연격×2, 다 씀) · 흐름 유지 · 완벽 패링 이월 · 숨 고르기 ·
# 준비 창 네 직업 · 실제 원정 첫 전투(빌린 그림 · 연격 칸). 고정값(공개): 파괴자 둘 상대 모델 전투(시드 7, 치명 끔), 새 프로필(시드 333)
func run_combo_class() -> void:
	await new_profile(333)
	var kinds := ["flurry", "finisher", "jab", "guard", "flow", "breather", "palm", "focus_strike"]
	var cards: Array[Card] = []
	var by := {}
	for k in kinds:
		var c := P2Catalog.build_card(k, "t_" + k)
		cards.append(c)
		by[k] = c
	var b := P2Battle.new({"enemies": ["breaker", "breaker"], "offsets": [0, 0]}, cards, [] as Array[String], 7, {"class_id": "combo", "crit_mode": "off", "prep_enabled": false})
	b.start()
	var hit := func(card: Card, t: int) -> int:
		var pv := b.preview(card, t)
		return int(pv.monsters[t].hp_before) - int(pv.monsters[t].hp)
	check(hit.call(by.flurry, 0) == 2 + 3 + 4, "연타 2×3: 같은 적이라 2 · 3 · 4 = %d" % hit.call(by.flurry, 0))
	b.hand.cards = [by.flurry, by.finisher, by.jab]
	b._set_mana(3)
	check(b.play_card(by.flurry, 0) and b.combo == 3 and b.combo_target == 0, "연타 뒤 연격 %d (대상 %d)" % [b.combo, b.combo_target])
	check(hit.call(by.finisher, 1) == 6 + 3 * 2, "마무리 일격, 다른 적: 6 + 연격 3×2 = %d (연격 피해는 깨짐)" % hit.call(by.finisher, 1))
	check(hit.call(by.finisher, 0) == 6 + 3 * 2 + 3, "마무리 일격, 같은 적: 6 + 6 + 연격 3 = %d" % hit.call(by.finisher, 0))
	check(b.play_card(by.finisher, 0) and b.combo == 0, "마무리 일격 뒤 연격 0 (다 씀)")
	b.perfect_phase = 4
	b._start_turn()
	check(b.combo == 2, "적 차례 완벽 4번 → 다음 턴 연격 2 (%d)" % b.combo)
	b.hand.cards = [by.flow, by.breather, by.jab]
	b._set_mana(2)
	b.combo = 3
	check(b.play_card(by.breather, -1) and b.combo == 1 and b.mana_now() == 3, "숨 고르기: 연격 2를 써서 마나 1 (연격 %d · 마나 %d)" % [b.combo, b.mana_now()])
	check(b.play_card(by.flow, -1) and b.combo_keep, "흐름 유지: 연격을 다음 턴으로")
	var keep := b.combo
	b.perfect_phase = 0
	b._start_turn()
	check(b.combo == keep, "흐름 유지 뒤 턴이 바뀌어도 연격 %d 그대로" % b.combo)
	var b2 := P2Battle.from_dict(b.to_dict(), {}, true)
	check(b2.combo == b.combo and b2.combo_target == b.combo_target, "이어하기 저장에도 연격")
	var f := P2Catalog.face(by.finisher, "combo")
	check(String(f[0]) == "물리 6 + 연격×2" and P2Catalog.long_text("flurry").contains("세 번"), "카드 글: %s" % String(f[0]))
	# 준비 창: 네 직업
	check(await RunService.commit_profile("combo fixture", func(c, _r, _f):
		c.combat.class_id = "combo"
		P5Campaign.refresh_vitals(c)
		return true), "고정값: 콤보술사")
	var pp := P5PrepPanel.open_in(get_tree())
	await secs(0.8)
	check(pp._figs.size() == P2Catalog.CLASS_ORDER.size() and pp._figs.has("combo") and String(pp._anim.id) == "combo", "준비 창 무대: 직업 수만큼, 고른 콤보술사")
	await snap("combo_01_prep")
	pp.queue_free()
	await secs(0.3)
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	check(Flow.start_expedition(), "콤보술사로 원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	h._on_engage("n1")
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	check(v._art_cid == "warden" and v._player.self_modulate != Color.WHITE and v.battle.class_id == "combo", "그림은 수호기사 것을 빌리고 색만 다름")
	var kinds_hand: Array = v.battle.hand.cards.map(func(c): return P2Catalog.kind_of(c))
	check(kinds_hand.has("flurry") and kinds_hand.has("finisher"), "첫 손패에 핵심 카드 연타 · 마무리 일격 %s" % str(kinds_hand))
	await secs(0.4)
	await snap("combo_02_battle")
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 연출 점검: 실제 손맛 전투에서 새 카드를 하나씩, 연출 동안 일정 간격으로 여러 장 찍는다(눈으로 보는 용)
# 고정값(공개): 직업마다 새 프로필(시드 370+), 적 체력 300, 마나 가득, 차징은 92%에서 놓음, 연타는 0.05초마다 22번
const SHOW_CARDS := {"rune_caster": ["fireball", "frost_lance", "ice_coffin", "slash", "gust", "poison_cloud", "fire_wall", "dark_rift", "light_rain"],
	"hunter": ["focus_shot", "barrage", "bear_trap", "mark_target", "bleed_arrows"],
	"warden": ["shield_boomerang", "rampart", "war_cry", "iron_counter", "war_shout", "expose"],
	"combo": ["launcher", "hundred_fists", "ki_blast", "disarm", "smoke_bomb"],
	"shaman": ["hex_bolt", "doom_brand", "enfeeble", "armor_break", "soul_link", "blood_pact", "soul_drain", "plague", "poison_coat"]}


# 원래 카드 손질 점검(맞는 순간·막기·연료·집중 조각)
const SHOW_OLD := {"rune_caster": ["bolt", "sigil_burst", "torrent", "suppress", "mana_veil", "fuel", "focus"],
	"warden": ["slash", "guard", "guard", "bash", "sweep", "pierce", "riposte", "fortify"], "hunter": ["quickshot", "aimed_shot"]}


# 새 강화 연출 점검("카드:강화"). 불기둥 폭발 전에는 모든 적에 화상 4, 번지는 저주 전에는 대상에 저주 2
# 원소 반응 연출 점검("카드::미리 묻힐 상태") — 모든 적에 그 상태를 묻혀 두고 낸다
const SHOW_REACT := {"rune_caster": ["frost_lance::burn", "fireball::chill", "frost_lance::poison", "fireball::poison", "dark_rift::lumen", "gust::burn"]}
const SHOW_UP := {"rune_caster": ["fireball:fire_bounce", "fire_wall:pyre_burst", "frost_lance:frost_pierce"],
	"combo": ["hundred_fists:thousand_fists"], "shaman": ["hex_bolt:hex_chain", "doom_brand:swift_doom"]}


func show_start(cid: String, slot: int) -> P2BattleView:
	await new_profile(slot)
	check(await RunService.commit_profile("show fixture", func(c, _r, _f):
		c.combat.class_id = cid
		P5Campaign.refresh_vitals(c)
		return true), "고정값: " + cid)
	check(Flow.start_expedition(), cid + " 원정")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	h._on_engage("n1")
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	av1_tough(v, 300)
	await wait_until(func(): return v.prompt_text() == "" or v._prompt_close.visible, 2.0)
	if v._prompt_close.visible:
		v._prompt_close.pressed.emit()
	return v


func ui_child(v: P2BattleView, cls: String) -> Node:
	for c in v._ui.get_children():
		if (cls == "P2ChargePad" and c is P2ChargePad) or (cls == "P2MashPad" and c is P2MashPad):
			return c
	return null


func snap_burst(prefix: String, n: int, gap: float) -> void:
	for k in range(n):
		await secs(gap)
		await snap("%s_%02d" % [prefix, k])


func run_show(classes: Array, table: Dictionary = SHOW_CARDS) -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var slot := 370
	for cid in classes:
		var v := await show_start(String(cid), slot)
		slot += 1
		var b := v.battle
		for spec in table[cid]:
			var kind := String(spec).get_slice(":", 0)
			var upg := String(spec).get_slice(":", 1) if String(spec).contains(":") else ""
			var pre := String(spec).get_slice(":", 2) if String(spec).count(":") >= 2 else ""
			var card := P2Catalog.build_card(kind, "sh_" + kind, upg)
			var list: Array[Card] = [card]
			b.hand.cards = list.duplicate()
			v._build_hand(false)
			await secs(0.3)
			b._set_mana(b.max_mana)
			v._sync_shown_from_battle()
			v._render_all()
			v._refresh_card_states()
			v.skill_log.clear()
			var hp0: Array = b.monsters.map(func(m): return m.hp)
			var tgt := fe_target(b) if P2Catalog.is_targeted(card) else -1
			if upg == "pyre_burst":
				for m in b.alive_monsters():
					b._st_add(m.index, "burn", 4)
			if upg == "hex_chain" and tgt >= 0:
				b._st_add(tgt, "doom", 2)
			if pre != "":
				for m in b.alive_monsters():
					b._st_add(m.index, pre, 2 if pre in ["chill", "umbra"] else 3)
				kind = kind + "_" + pre
				v._sync_shown_from_battle()
				v._show.rebuild_enemies()
				v._render_all()
				v._show_preview(card, tgt)
				await secs(0.4)
				await snap("show_pre_%s" % kind)
				if pre != "chill" and kind != "gust_burn":
					var pl: Label = v._enemy_panels[maxi(tgt, 0)].preview
					check(["증기 폭발", "독 결정", "일식", "유독 폭발"].any(func(x): return pl.text.begins_with(tr(x))), "반응 미리보기 %s: %s" % [kind, pl.text])
				v._clear_preview()
			if upg != "":
				kind = upg
				v._sync_shown_from_battle()
				v._show.rebuild_enemies()
				v._render_all()
			var burst_n: int = {"dark_rift": 26, "light_rain": 18, "focus_shot": 26, "barrage": 34, "ki_blast": 26, "fire_wall": 18, "hundred_fists": 20,
				"shield_boomerang": 16, "soul_drain": 16, "doom_brand": 16, "enfeeble": 14, "armor_break": 14,
				"fire_bounce": 18, "pyre_burst": 28, "frost_pierce": 18, "thousand_fists": 26, "hex_chain": 20, "swift_doom": 18}.get(String(kind), 12)
			if pre != "":
				burst_n = 34
			if kind in ["focus_shot", "ki_blast", "barrage"] or not P2Catalog.is_attack(card):
				snap_burst("show_%s" % kind, burst_n, 0.08)
			v.play_card(card, tgt)
			if kind in ["focus_shot", "ki_blast"]:
				await wait_until(func(): return ui_child(v, "P2ChargePad") != null, 3.0)
				var pad := ui_child(v, "P2ChargePad") as P2ChargePad
				await secs(0.15)
				if pad != null and is_instance_valid(pad):
					pad._press(true)
				await secs(1.1)
				if pad != null and is_instance_valid(pad):
					pad._press(false)
			elif kind == "barrage":
				await wait_until(func(): return ui_child(v, "P2MashPad") != null, 3.0)
				var mp := ui_child(v, "P2MashPad") as P2MashPad
				for k in range(22):
					if mp == null or not is_instance_valid(mp):
						break
					mp._hit()
					await secs(0.05)
			elif P2Catalog.is_attack(card):
				var gp := await fe_pad(v)
				if gp != null:
					await fe_glyph(gp, 0.4)
				snap_burst("show_%s" % kind, burst_n, 0.07)
			await fe_idle(v)
			await secs(0.3)
			var hurt: Array = []
			for i in range(b.monsters.size()):
				hurt.append(int(hp0[i]) - b.monsters[i].hp)
			check(table != SHOW_CARDS or v.skill_log.any(func(e): return String(e.fx) == "show" or String(e.card) == String(kind)) or kind == "slash", "%s %s: 연출 · 피해 %s" % [cid, kind, str(hurt)])
			if kind == "poison_cloud":
				await snap("show_status_icons")
		if cid in ["rune_caster", "shaman"]:
			# 턴을 끝내 화상·독 틱, 얼어붙은 적 쉼 · 저주는 두 번 끝내야 터짐
			for r in range(1 if cid == "rune_caster" else 2):
				snap_burst("show_endturn%d" % r, 14, 0.15)
				await v.end_turn()
				await wait_until(func(): return v.current_state() == "PLAYER", 25.0)
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


func run_show_ult(classes: Array = ["rune_caster", "hunter", "warden", "combo", "shaman"]) -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var slot := 380
	for cid in classes:
		var v := await show_start(cid, slot)
		slot += 1
		var b := v.battle
		b._st_add(0, "burn", 4)
		b._st_add(1, "doom", 2)
		b._st_add(0, "poison", 3)
		b._pending_defense = 10
		b.combo = 3
		b.ult = 100
		v._sync_shown_from_battle()
		v._render_all()
		await secs(0.5)
		await snap("ult_%s_ready" % cid)
		check(v._show._ult_ready, "%s 필살 준비 표시" % cid)
		var hp0: Array = b.monsters.map(func(m): return m.hp)
		snap_burst("ult_%s" % cid, 22, 0.12)
		v._show.use_ult()
		await wait_until(func(): return v.current_state() == "PLAYER" or b.battle_over, 15.0)
		await secs(0.3)
		var hurt: Array = []
		for i in range(b.monsters.size()):
			hurt.append(int(hp0[i]) - b.monsters[i].hp)
		check(b.ult == 0 and hurt.any(func(x): return x > 0), "%s 필살: 피해 %s" % [cid, str(hurt)])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 직업 균형(자동 정책, 사람 플레이 증거 아님): 시작 덱 그대로 정해진 전투를 시드 8개씩 → 이긴 비율 · 걸린 턴 · 잃은 체력.
# 봇은 막기 박자를 치지 않아 적 공격이 그대로 들어오고, 저주처럼 늦게 터지는 효과는 점수에 덜 잡힌다(참고용)
func run_balance() -> void:
	await new_profile(390)
	var rows: Array[String] = []
	var sums := {}
	for cid in P5Campaign.CLASS_IDS:
		var deck: Array = P2Catalog.CLASSES[cid].deck
		var hp := int(P2Catalog.CLASSES[cid].hp)
		var tot := {"win": 0, "n": 0, "turns": 0, "lost": 0}
		var cells: Array[String] = []
		for g in ["n1", "n2", "n3", "n4", "elite", "boss"]:
			var grp: Dictionary = P2Catalog.GROUPS[g]
			var w := 0
			var tn := 0
			var lost := 0
			for sd in range(8):
				var cards: Array[Card] = []
				for k in deck:
					cards.append(P2Catalog.build_card(String(k), "bl_%s_%d" % [String(k), cards.size()]))
				GameState.set_flag("player_max_hp", hp)
				GameState.set_flag("player_hp", hp)
				var b := P2Battle.new({"enemies": grp.enemies, "offsets": grp.offsets}, cards, [] as Array[String], 500 + sd, {"class_id": cid, "prep_enabled": false})
				b.start()
				var rng := RandomNumberGenerator.new()
				rng.seed = 700 + sd
				P2Bot.play_battle(b, Callable(), 30, "greedy", rng)
				var won := b.all_monsters_defeated()
				w += 1 if won else 0
				tn += b.turn_number
				lost += hp - int(GameState.get_flag("player_hp"))
			cells.append("%s %d/8 %.1f턴 −%.1f" % [g, w, tn / 8.0, lost / 8.0])
			tot.win += w
			tot.n += 8
			tot.turns += tn
			tot.lost += lost
		sums[cid] = tot
		rows.append("%s | 승 %d%% | 평균 %.1f턴 | 잃은 체력 %.1f | %s" % [cid, roundi(100.0 * tot.win / tot.n), float(tot.turns) / tot.n, float(tot.lost) / tot.n, " · ".join(cells)])
	for r in rows:
		print("BALANCE ", r)
		note("BALANCE " + r)
	check(true, "균형 표 %d직업" % rows.size())


# 상태이상·반응·필살 규칙(전투 객체만, 치명 끔, 적 체력 200, 갑옷 0으로 맞춤)
func run_elements() -> void:
	await new_profile(360)
	var mk := func(cid: String, kinds: Array, n := 2) -> P2Battle:
		var cards: Array[Card] = []
		for k in kinds:
			cards.append(P2Catalog.build_card(String(k), "el_" + String(k) + str(cards.size())))
		var roles: Array = []
		for i in range(n):
			roles.append("breaker")
		var bb := P2Battle.new({"enemies": roles, "offsets": roles.map(func(_r): return 0)}, cards, [] as Array[String], 11, {"class_id": cid, "crit_mode": "off", "prep_enabled": false})
		bb.start()
		for i in range(bb.monsters.size()):
			bb.monsters[i].max_hp = 200
			bb.monsters[i].hp = 200
			bb.armor[i] = 0
		bb.hand.cards = cards.duplicate()
		bb.max_mana = 12
		bb._set_mana(12)
		return bb
	var hp := func(bb: P2Battle) -> Array:
		return bb.monsters.map(func(m): return m.hp)
	var card := func(bb: P2Battle, k: String) -> Card:
		for c in bb.hand.cards:
			if P2Catalog.kind_of(c) == k:
				return c
		return null
	# 화상: 4 + 화상 3 → 턴 끝 3 → 1
	var b: P2Battle = mk.call("rune_caster", ["fireball"])
	b.play_card(card.call(b, "fireball"), 0)
	check(b.monsters[0].hp == 196 and b.st(0, "burn") == 3, "화염구: 마법 4 · 화상 3 (%d · %d)" % [b.monsters[0].hp, b.st(0, "burn")])
	b.begin_round_resolution()
	check(b.monsters[0].hp == 193 and b.st(0, "burn") == 1, "턴 끝: 화상 3 피해 → 1 남음 (%d · %d)" % [b.monsters[0].hp, b.st(0, "burn")])
	# 빙결 → 쇄빙 ×2 + 파편
	b = mk.call("rune_caster", ["ice_coffin", "slash"])
	b.play_card(card.call(b, "ice_coffin"), 0)
	check(b.st(0, "frozen") == 1 and b.st(0, "chill") == 0, "빙결의 관: 바로 얼어붙음")
	var h0: Array = hp.call(b)
	var mk0 := b.mark_count(0)
	b.play_card(card.call(b, "slash"), 0)
	var h1: Array = hp.call(b)
	var want := (5 + 3 * mk0) * 2
	check(int(h0[0]) - int(h1[0]) == want and int(h0[1]) - int(h1[1]) == want / 2 and b.st(0, "frozen") == 0 and b.events.any(func(e): return String(e.kind) == "react" and String(e.name) == "shatter"),
		"쇄빙: (베기 5 + 표식 %d × 3) × 2 = %d, 파편 옆 적 %d, 얼음 풀림" % [mk0, int(h0[0]) - int(h1[0]), int(h0[1]) - int(h1[1])])
	# 얼어붙은 적은 적 차례를 쉰다
	b = mk.call("rune_caster", ["ice_coffin"])
	b.play_card(card.call(b, "ice_coffin"), 0)
	b.begin_round_resolution()
	var skipped := false
	while true:
		var r := b.take_next_monster_action()
		if not bool(r.acted):
			break
		if b.events.any(func(e): return String(e.kind) == "frozen_skip" and int(e.index) == 0):
			skipped = true
		if bool(r.get("pending", false)):
			break
	check(skipped, "얼어붙은 적은 그 적 차례 공격 없음")
	# 증기 폭발: 얼음 + 불 → (냉기 + 얼음 3) × 3, 옆 적 절반 · 불 + 얼음도 똑같이
	var has_react := func(bb: P2Battle, nm: String) -> bool:
		return bb.events.any(func(e): return String(e.kind) == "react" and String(e.name) == nm)
	b = mk.call("rune_caster", ["ice_coffin", "fireball"])
	b.play_card(card.call(b, "ice_coffin"), 0)
	var sm0: Array = hp.call(b)
	b.play_card(card.call(b, "fireball"), 0)
	var sm1: Array = hp.call(b)
	check(int(sm0[0]) - int(sm1[0]) == 4 + 9 and int(sm0[1]) - int(sm1[1]) == 4 and b.st(0, "frozen") == 0 and b.st(0, "burn") == 0 and has_react.call(b, "steam"),
		"증기 폭발(얼음 → 불): 화염구 4 + 9 = %d, 옆 적 %d, 얼음 · 화상 없음" % [int(sm0[0]) - int(sm1[0]), int(sm0[1]) - int(sm1[1])])
	b = mk.call("rune_caster", ["fireball", "frost_lance"])
	b.play_card(card.call(b, "fireball"), 0)
	var sm2 := b.monsters[0].hp
	b.play_card(card.call(b, "frost_lance"), 0)
	check(sm2 - b.monsters[0].hp == 3 + 9 and b.st(0, "burn") == 0 and b.st(0, "chill") == 0 and has_react.call(b, "steam"),
		"증기 폭발(불 → 얼음): 서리 창 3 + 화상 3 × 3 = %d" % (sm2 - b.monsters[0].hp))
	# 독 결정: 독 + 얼음(어느 쪽 먼저든) → 두 턴 동안 독이 안 줄어듦
	b = mk.call("rune_caster", ["poison_cloud", "frost_lance"])
	b.play_card(card.call(b, "poison_cloud"), -1)
	b.play_card(card.call(b, "frost_lance"), 0)
	var pc_r: bool = has_react.call(b, "pcrys")
	b.begin_round_resolution()
	check(pc_r and b.st(0, "pcrys") > 0 and b.st(0, "poison") == 3 and b.st(1, "poison") == 2,
		"독 결정: 결정 낀 적 독 3 그대로 · 다른 적 2 (%d · %d)" % [b.st(0, "poison"), b.st(1, "poison")])
	b = mk.call("rune_caster", ["frost_lance", "poison_cloud"])
	b.play_card(card.call(b, "frost_lance"), 0)
	b.play_card(card.call(b, "poison_cloud"), -1)
	check(has_react.call(b, "pcrys") and b.st(0, "pcrys") > 0 and b.st(1, "pcrys") == 0, "독 결정(얼음 → 독)도 됨")
	# 일식: 어둠 + 빛(어느 쪽 먼저든) → 그 적 8 · 모든 적 취약 2
	b = mk.call("rune_caster", ["dark_rift", "light_rain"])
	b.play_card(card.call(b, "dark_rift"), 0)
	check(b.st(0, "umbra") > 0, "어둠의 균열: 어둠 기운")
	b.play_card(card.call(b, "light_rain"), -1)
	check(has_react.call(b, "eclipse") and b.st(0, "umbra") == 0 and b.st(0, "lumen") == 0 and b.st(1, "vuln") >= 2 and b.st(1, "lumen") > 0,
		"일식(어둠 → 빛): 기운 둘 다 사라짐 · 옆 적 취약 %d" % b.st(1, "vuln"))
	b = mk.call("rune_caster", ["light_rain", "dark_rift"])
	b.play_card(card.call(b, "light_rain"), -1)
	var ec0 := b.monsters[0].hp
	b.play_card(card.call(b, "dark_rift"), 0)
	check(has_react.call(b, "eclipse") and ec0 - b.monsters[0].hp >= 6 + 8, "일식(빛 → 어둠): 균열 + 일식 8 = %d" % (ec0 - b.monsters[0].hp))
	# 유독 폭발: 독 3 + 불 → 독 × 2 즉시
	b = mk.call("rune_caster", ["poison_cloud", "fireball"])
	b.play_card(card.call(b, "poison_cloud"), -1)
	check(b.st(0, "poison") == 3 and b.st(1, "poison") == 3, "맹독 구름: 모든 적 독 3")
	var ht := b.monsters[0].hp
	b.play_card(card.call(b, "fireball"), 0)
	check(ht - b.monsters[0].hp == 4 + 6 and b.st(0, "poison") == 0 and b.st(0, "burn") == 3, "유독 폭발: 화염구 4 + 독 3 × 2 = %d, 독 0 · 화상 3" % (ht - b.monsters[0].hp))
	# 확산: 돌풍
	b = mk.call("rune_caster", ["fireball", "gust"], 3)
	b.play_card(card.call(b, "fireball"), 0)
	b.play_card(card.call(b, "gust"), 0)
	check(b.st(1, "burn") == 3 and b.st(2, "burn") == 3 and b.suppression[0] == 3, "돌풍: 화상 3이 다른 적에게 번짐 · 날린 적 다음 공격 −3")
	# 취약 · 약화
	b = mk.call("shaman", ["enfeeble", "slash"])
	var raw0 := int(b.effective_intent(0)[0]) if not b.effective_intent(0).is_empty() else 0
	b.play_card(card.call(b, "enfeeble"), 0)
	var hv := b.monsters[0].hp
	b.play_card(card.call(b, "slash"), 0)
	check(hv - b.monsters[0].hp == 7 and int(b.effective_intent(0)[0]) == floori(raw0 * 0.75), "쇠약: 베기 5 × 1.5 = %d · 적 공격 %d → %s" % [hv - b.monsters[0].hp, raw0, str(b.effective_intent(0))])
	# 저주: 2턴 뒤 폭발 + 주술사 회복
	b = mk.call("shaman", ["doom_brand"])
	GameState.set_flag("player_hp", 20)
	b.play_card(card.call(b, "doom_brand"), 0)
	b.begin_round_resolution()
	var after1 := b.monsters[0].hp
	b.finish_round_resolution()
	b.begin_round_resolution()
	check(after1 == 200 and b.monsters[0].hp == 200 - 12 and int(GameState.get_flag("player_hp")) == 21, "파멸의 낙인 4: 첫 턴 끝 그대로 → 둘째 턴 끝 12 폭발 · 체력 +1 (%d → %d)" % [after1, b.monsters[0].hp])
	# 덫: 다음 공격 때 5 + 출혈 3, 첫 타격 사라짐
	b = mk.call("hunter", ["bear_trap"])
	b.play_card(card.call(b, "bear_trap"), 0)
	b.begin_round_resolution()
	var snapped := false
	while true:
		var r := b.take_next_monster_action()
		if not bool(r.acted):
			break
		if b.events.any(func(e): return String(e.kind) == "trap_snap"):
			snapped = true
		if bool(r.get("pending", false)):
			break
	check(snapped and b.monsters[0].hp <= 195 and b.st(0, "trap") == 0, "사냥용 덫: 공격하러 오면 닫힘 (적 체력 %d · 출혈 %d)" % [b.monsters[0].hp, b.st(0, "bleed")])
	# 폭풍 연사 클릭 수 · 집중 사격 차징 · 빛의 창
	b = mk.call("hunter", ["barrage", "focus_shot", "light_rain"])
	b.mash_hits = 23
	b.play_card(card.call(b, "barrage"), 0)
	b.mash_hits = 0
	check(200 - b.monsters[0].hp == 16 * 2 and b.st(0, "bleed") == 3, "폭풍 연사 23번 눌러도 16발: 2 × 16 = 32 피해 · 출혈 3 (%d · %d)" % [200 - b.monsters[0].hp, b.st(0, "bleed")])
	var hf: Array = hp.call(b)
	b.charge_power = 3.0
	b.play_card(card.call(b, "focus_shot"), -1)
	b.charge_power = 0.0
	var hf2: Array = hp.call(b)
	check(int(hf[0]) - int(hf2[0]) == 18 and int(hf[1]) - int(hf2[1]) == 18, "집중 사격 차징 ×3: 모든 적 18 (%d · %d)" % [int(hf[0]) - int(hf2[0]), int(hf[1]) - int(hf2[1])])
	var hl: Array = hp.call(b)
	b.play_card(card.call(b, "light_rain"), -1)
	var hl2: Array = hp.call(b)
	check(int(hl[0]) - int(hl2[0]) == 8 and int(hl[1]) - int(hl2[1]) == 8, "빛의 창 8개: 적마다 4개 × 2 (%s)" % str([int(hl[0]) - int(hl2[0]), int(hl[1]) - int(hl2[1])]))
	# 고통 연결 · 갑옷 부수기 · 피의 계약 · 영혼 흡수
	b = mk.call("shaman", ["soul_link", "slash", "armor_break", "blood_pact", "soul_drain", "hex_bolt"])
	b.monsters[1].hp = 150
	b.play_card(card.call(b, "soul_link"), 0)
	var hk: Array = hp.call(b)
	b.play_card(card.call(b, "slash"), 0)
	var hk2: Array = hp.call(b)
	check(int(hk[0]) - int(hk2[0]) == 5 and int(hk[1]) - int(hk2[1]) == 2, "고통 연결: 베기 5 → 묶인 적에게 2 (%s)" % str([int(hk[0]) - int(hk2[0]), int(hk[1]) - int(hk2[1])]))
	b.armor[1] = 3
	b.play_card(card.call(b, "armor_break"), 1)
	check(b.armor[1] == 0, "갑옷 부수기: 갑옷 3 → 0")
	GameState.set_flag("player_hp", 20)
	b.play_card(card.call(b, "blood_pact"), -1)
	var hb := b.monsters[0].hp
	b.play_card(card.call(b, "hex_bolt"), 0)
	check(int(GameState.get_flag("player_hp")) == 17 and hb - b.monsters[0].hp == 4, "피의 계약: 체력 −3, 저주탄 3 × 1.5 = %d" % (hb - b.monsters[0].hp))
	var hd := int(GameState.get_flag("player_hp"))
	b.play_card(card.call(b, "soul_drain"), -1)
	check(int(GameState.get_flag("player_hp")) > hd, "영혼 흡수: 저주받은 적에게 준 만큼 회복 (%d → %d)" % [hd, int(GameState.get_flag("player_hp"))])
	# 성벽 · 연막 · 철벽 반격
	b = mk.call("warden", ["rampart", "smoke_bomb", "iron_counter"])
	b.play_card(card.call(b, "rampart"), -1)
	b.play_card(card.call(b, "smoke_bomb"), -1)
	b.play_card(card.call(b, "iron_counter"), -1)
	GameState.set_flag("player_hp", 30)
	var he := b.monsters[0].hp
	b.events.clear()
	b._enemy_hit(0, 0, 6, "", -1.0)
	check(b.events.any(func(e): return String(e.kind) == "smoke_miss") and int(GameState.get_flag("player_hp")) == 30, "연막: 첫 타격 빗나감")
	b.events.clear()
	b._enemy_hit(0, 1, 6, "", -1.0)
	check(b.wall == 4 and b.monsters[0].hp == he - 6, "성벽: 6 흡수 · 6 되돌림 (남은 성벽 %d · 적 −%d)" % [b.wall, he - b.monsters[0].hp])
	var hc := b.monsters[0].hp
	b.events.clear()
	b._enemy_hit(0, 2, 6, "perfect", -1.0)
	check(hc - b.monsters[0].hp == 5, "철벽 반격: 완벽 막기 → 5 (%d)" % (hc - b.monsters[0].hp))
	# 필살 게이지: 다른 카드 이어 쓰기 +5 · 같은 카드 0 · 완벽 막기 +8 → 100이면 필살
	b = mk.call("warden", ["slash", "slash", "guard"])
	var u0 := b.ult
	b.play_card(b.hand.cards[0], 0)
	var u1 := b.ult
	b.play_card(b.hand.cards[0], 0)
	var u2 := b.ult
	b.play_card(card.call(b, "guard"), -1)
	var gv := int(P2Catalog.ULT_GAIN.vary)
	check(u1 - u0 == gv and u2 == u1 and b.ult == u2 + gv, "필살 게이지: 다른 카드 +%d · 같은 카드 0 (%d → %d → %d → %d)" % [gv, u0, u1, u2, b.ult])
	for cid in ["rune_caster", "hunter", "warden", "combo", "shaman"]:
		var ub: P2Battle = mk.call(cid, ["guard"])
		ub._pending_defense = 10
		ub.combo = 3
		ub._st_add(0, "burn", 4)
		ub._st_add(1, "doom", 2)
		ub.ult = 100
		var uh: Array = hp.call(ub)
		var ok := ub.use_ultimate(0)
		var uh2: Array = hp.call(ub)
		check(ok and ub.ult == 0 and int(uh[0]) > int(uh2[0]) and ub.events.any(func(e): return String(e.kind) == "ult_used"), "%s 필살: 적 체력 %s → %s" % [cid, str(uh), str(uh2)])
	var bm: P2Battle = mk.call("rune_caster", ["guard"])
	bm.ult = 100
	bm.use_ultimate(0)
	var beams := bm.events.filter(func(e): return String(e.kind) == "beam").map(func(e): return String(e.elem))
	check(beams == ["fire", "ice", "poison", "light", "dark"] and has_react.call(bm, "steam") and has_react.call(bm, "eclipse"),
		"오원소 연사: 빔 %s · 빔끼리 증기 폭발 · 일식" % str(beams))
	# 저장 · 복원에 상태
	b = mk.call("rune_caster", ["fireball", "frost_lance"])
	b.play_card(card.call(b, "fireball"), 0)
	b.play_card(card.call(b, "frost_lance"), 1)
	b.ult = 37
	var b2 := P2Battle.from_dict(b.to_dict(), {}, true)
	check(b2.st(0, "burn") == 3 and b2.st(1, "chill") == 2 and b2.ult == 37, "이어하기 저장에도 화상·냉기·필살 게이지")
	# 새 카드 강화 사본: 하나씩 실제로 내 보고(오류 없음 · 피해나 상태가 생김), 대표 수치는 직접 계산
	var mku := func(cid: String, up: String) -> P2Battle:
		var bb: P2Battle = mk.call(cid, ["guard"])
		var c := P2Catalog.build_card(String(P2Catalog.UPGRADE_KINDS[up].from), "up_" + up, up)
		var list: Array[Card] = [c]
		bb.hand.cards = list
		return bb
	var cls_of := func(kind: String) -> String:
		var k := String(P2Catalog.CARD_CLASS.get(kind, "warden"))
		return k if k in ["rune_caster", "hunter", "warden", "combo", "shaman"] else "warden"
	var n_ok := 0
	var fails: Array = []
	for i in range(40, 52):
		var up := ""
		for u in P2Catalog.UPGRADE_KINDS:
			if int(P2Catalog.UPGRADE_KINDS[u].code) == i:
				up = String(u)
		if up == "":
			continue
		var from := String(P2Catalog.UPGRADE_KINDS[up].from)
		var ub: P2Battle = mku.call(cls_of.call(from), up)
		var c: Card = ub.hand.cards[0]
		var hb_up: Array = hp.call(ub)
		var tgt := 0 if P2Catalog.is_targeted(c) else -1
		var played := ub.play_card(c, tgt)
		var changed: bool = hp.call(ub) != hb_up or ub.events.any(func(e): return String(e.kind) in ["status", "buff", "wall", "guard", "heal", "linked", "debuff_cast", "iron_counter"])
		if played and changed and P2Catalog.card_name(from, up) != P2Catalog.card_name(from):
			n_ok += 1
		else:
			fails.append(up)
	check(fails.is_empty(), "새 강화 사본 %d장: 모두 낼 수 있고 효과가 남 %s" % [n_ok, "" if fails.is_empty() else str(fails)])
	# 새 강화 여섯(보상에 나오는 것): 수치를 직접 계산
	var fbb: P2Battle = mku.call("rune_caster", "fire_bounce")
	fbb.play_card(fbb.hand.cards[0], 0)
	check(fbb.monsters[0].hp == 196 and fbb.monsters[1].hp == 197 and fbb.st(1, "burn") == 3, "튀는 화염구: 대상 4 · 옆 적 3 + 화상 3 (%d · %d · %d)" % [200 - fbb.monsters[0].hp, 200 - fbb.monsters[1].hp, fbb.st(1, "burn")])
	var pyb: P2Battle = mku.call("rune_caster", "pyre_burst")
	pyb._st_add(0, "burn", 4)
	pyb.play_card(pyb.hand.cards[0], -1)
	check(pyb.monsters[0].hp == 190 and pyb.monsters[1].hp == 198 and pyb.st(0, "burn") == 4 and pyb.st(1, "burn") == 4, "불기둥 폭발: 타던 적 2 + 화상 4×2 = 10, 다른 적 2, 둘 다 화상 4 (%d · %d)" % [200 - pyb.monsters[0].hp, 200 - pyb.monsters[1].hp])
	var fpb: P2Battle = mku.call("rune_caster", "frost_pierce")
	fpb.play_card(fpb.hand.cards[0], -1)
	check(fpb.monsters[0].hp == 197 and fpb.monsters[1].hp == 197 and fpb.st(0, "chill") == 2 and fpb.st(1, "chill") == 2, "꿰뚫는 서리: 모든 적 3 + 냉기 2")
	var hcb: P2Battle = mku.call("shaman", "hex_chain")
	hcb._st_add(0, "doom", 2)
	hcb.play_card(hcb.hand.cards[0], 0)
	check(hcb.st(0, "doom") == 3 and hcb.st(1, "doom") == 1, "번지는 저주: 저주 걸린 적을 맞히면 옆 적에게도 저주 1 (%d · %d)" % [hcb.st(0, "doom"), hcb.st(1, "doom")])
	var sdb: P2Battle = mku.call("shaman", "swift_doom")
	sdb.play_card(sdb.hand.cards[0], 0)
	var sd_hp := sdb.monsters[0].hp
	sdb.begin_round_resolution()
	check(sdb.st(0, "doom") == 0 and sd_hp - sdb.monsters[0].hp == 4 * sdb.doom_mult(), "급속 파멸: 이번 턴 끝에 바로 저주 4 × 3 폭발 (%d)" % (sd_hp - sdb.monsters[0].hp))
	var tfb: P2Battle = mku.call("combo", "thousand_fists")
	tfb.play_card(tfb.hand.cards[0], 0)
	check(tfb.monsters[0].hp == 200 - 15 - 2 * P2Catalog.COMBO_MAX, "천열권: 1 × 15 + 마지막 한 방 연격 %d × 2 = %d" % [P2Catalog.COMBO_MAX, 200 - tfb.monsters[0].hp])
	check(not P2Catalog.UPGRADE_ORDER.has("tempest") and not P2Catalog.UPGRADE_ORDER.has("sun_rain") and P2Catalog.UPGRADE_KINDS.has("tempest"), "숫자만 오르는 강화는 보상에서 빠짐(예전 저장의 카드는 그대로 동작)")
	var sb: P2Battle = mku.call("rune_caster", "sun_rain")
	sb.play_card(sb.hand.cards[0], -1)
	check(sb.events.filter(func(e): return String(e.kind) == "hit").size() == 12, "태양의 창: 창 12개")
	var cb: P2Battle = mku.call("shaman", "soul_chain")
	check(cb.hand.cards[0].mana_cost == 0, "영혼 사슬: 비용 0")
	var smb: P2Battle = mku.call("hunter", "smoke_screen")
	smb.play_card(smb.hand.cards[0], -1)
	check(smb.smoke == 2, "연막 장막: 빗나감 둘 (%d)" % smb.smoke)
	var fb: P2Battle = mk.call("combo", ["guard"])
	var fc := P2Catalog.build_card("hundred_fists", "hf")
	var fl: Array[Card] = [fc]
	fb.hand.cards = fl
	fb.play_card(fc, 0)
	check(fb.monsters[0].hp == 185 and fb.combo == P2Catalog.COMBO_MAX, "백열권: 물리 1 × 15 = 15 (연격 피해 없음), 연격 가득 (%d · %d)" % [200 - fb.monsters[0].hp, fb.combo])
	# 12차 파트 1: 연타 상한 · 연타 치명 1/3 · 등급 체력 · 필살 이어받기 · 카드 보상 4장
	var p1_bb: P2Battle = mk.call("hunter", ["barrage"])
	p1_bb.mash_hits = 40
	check(p1_bb.hits_now(card.call(p1_bb, "barrage")) == P2Catalog.BARRAGE_MAX and P2Catalog.BARRAGE_MAX == 16, "폭풍 연사: 40번 눌러도 16발")
	p1_bb.mash_hits = 16
	p1_bb.forced_next = true
	p1_bb.play_card(card.call(p1_bb, "barrage"), 0)
	var p1_arrow := (200 - p1_bb.monsters[0].hp) / 16.0
	check(p1_arrow <= 3.0, "폭풍 연사 확정 치명: 화살 하나 %.1f (치명 배율을 1/3만)" % p1_arrow)
	var p1_mp := P2MashPad.new()
	p1_mp._t = 0.0
	p1_mp._hit()
	p1_mp._t = 0.03
	p1_mp._hit()
	p1_mp._t = 0.1
	p1_mp._hit()
	check(p1_mp.count == 2, "연타 칸: 0.07초보다 빠른 입력은 안 셈 (%d)" % p1_mp.count)
	p1_mp.free()
	var p1_hb := P2Battle.new({"enemies": ["maek_summoner_low", "maek_spawn_low", "maek_spawn_low"], "offsets": [0, 0, 0]}, [P2Catalog.build_card("slash", "p1_hb")] as Array[Card], [] as Array[String], 11,
		{"class_id": "warden", "crit_mode": "p1_off", "prep_enabled": false, "hp_mult": 1.0, "rank_hp": P2Catalog.DIFF.normal.rank_hp, "ult": 40})
	p1_hb.start()
	check(p1_hb.monsters[0].max_hp == roundi(int(P2Catalog.ENEMIES.maek_summoner_low.hp) * 1.8) and p1_hb.ult == 40, "노멀 보스 체력 ×1.8 (%d) · 필살 게이지 이어받기 %d" % [p1_hb.monsters[0].max_hp, p1_hb.ult])
	var p1_bad := []
	for p1_cid in P5Campaign.CLASS_IDS:
		for p1_sd in range(20):
			var p1_rng := RandomNumberGenerator.new()
			p1_rng.seed = 900 + p1_sd
			var p1_off := RunModel.card_offer(p1_rng, String(p1_cid), [], false)
			if p1_off.size() != P2Catalog.REWARD_COUNT or p1_off.any(func(k): return String(k) in ["slash", "guard", "focus", "bolt"]) or (p1_cid == "rune_caster" and p1_off.any(func(k): return String(k) in ["sigil_burst", "mark_amp", "chain_blast"])):
				p1_bad.append([p1_cid, p1_off])
	var p1_board := P5StatBoard.make({"stats": {"str": 1}, "relics": ["whetstone"], "lv": 2, "lv_xp": 0}, 300.0)
	var p1_rl: Array = p1_board.find_children("*", "Label", true, false).filter(func(l): return String((l as Label).text).begins_with("유물"))
	check(p1_rl.size() == 1 and String((p1_rl[0] as Label).text).contains("+2") and String((p1_board._rows["str"].root as Control).tooltip_text).contains("유물로 +2"), "능력치 창: 숫돌로 오른 힘을 '유물 +2'로 따로 표시")
	p1_board.free()
	check(p1_bad.is_empty(), "카드 보상 4장 · 기본 카드 없음 · 원소술사 표식 카드 없음 %s" % str(p1_bad.slice(0, 2)))
	# 새 유물 여덟: 유물 있음/없음을 같은 순서로 비교
	var mkr := func(cid: String, kinds: Array, rel: Array) -> P2Battle:
		var cards: Array[Card] = []
		for k in kinds:
			cards.append(P2Catalog.build_card(String(k), "r_" + String(k) + str(cards.size())))
		var rs: Array[String] = []
		for r in rel:
			rs.append(String(r))
		var bb := P2Battle.new({"enemies": ["breaker", "breaker"], "offsets": [0, 0]}, cards, rs, 11, {"class_id": cid, "crit_mode": "off", "prep_enabled": false})
		bb.start()
		for i in range(bb.monsters.size()):
			bb.monsters[i].max_hp = 200
			bb.monsters[i].hp = 200
			bb.armor[i] = 0
		bb.hand.cards = cards.duplicate()
		bb.max_mana = 12
		bb._set_mana(12)
		return bb
	var pick := func(bb: P2Battle, k: String) -> Card:
		for c in bb.hand.cards:
			if P2Catalog.kind_of(c) == k:
				return c
		return null
	var rb: P2Battle = mkr.call("rune_caster", ["guard"], ["ember_heart"])
	rb._st_add(0, "burn", 4)
	rb.begin_round_resolution()
	check(rb.st(0, "burn") == 3 and rb.monsters[0].hp == 196, "불씨 심장: 화상 4 → 피해 4 · 3 남음 (%d · %d)" % [rb.st(0, "burn"), rb.monsters[0].hp])
	rb = mkr.call("rune_caster", ["ice_coffin"], ["frost_crown"])
	rb.play_card(pick.call(rb, "ice_coffin"), 0)
	var fz0 := rb.st(0, "frozen")
	rb.begin_round_resolution()
	while true:
		var r := rb.take_next_monster_action()
		if not bool(r.acted) or bool(r.get("pending", false)):
			break
	check(fz0 == 2 and rb.st(0, "frozen") == 1, "서리 왕관: 얼면 2번 쉼 (%d → %d)" % [fz0, rb.st(0, "frozen")])
	rb = mkr.call("warden", ["slash"], ["spread_fan"])
	rb._st_add(0, "burn", 3)
	rb._st_add(0, "poison", 2)
	rb.monsters[0].hp = 1
	rb.play_card(pick.call(rb, "slash"), 0)
	check(not rb.monsters[0].is_alive() and rb.st(1, "burn") == 3 and rb.st(1, "poison") == 2, "확산의 부채: 쓰러진 적의 화상 3·독 2가 옆 적에게 (%d · %d)" % [rb.st(1, "burn"), rb.st(1, "poison")])
	rb = mkr.call("hunter", ["bear_trap"], ["trapper_jaw"])
	rb.play_card(pick.call(rb, "bear_trap"), 0)
	rb.begin_round_resolution()
	var jaw_snap := false
	while true:
		var r2 := rb.take_next_monster_action()
		jaw_snap = jaw_snap or rb.events.any(func(e): return String(e.kind) == "trap_snap")
		if not bool(r2.acted) or bool(r2.get("pending", false)):
			break
	check(jaw_snap and rb.st(0, "trap") > 0 and rb.st(0, "trap_re") == 1, "덫꾼의 이빨: 덫이 닫힌 뒤 다시 놓임 (%d)" % rb.st(0, "trap"))
	rb = mkr.call("shaman", ["blood_pact"], ["blood_chalice"])
	var d0 := rb.get_pending_defense()
	rb.play_card(pick.call(rb, "blood_pact"), -1)
	check(rb.get_pending_defense() - d0 == P2Catalog.CHALICE_BLOCK, "피의 성배: 피의 계약으로 방어 +%d" % (rb.get_pending_defense() - d0))
	var ult_of := func(rel: Array) -> int:
		var eb: P2Battle = mkr.call("rune_caster", ["ice_coffin", "slash"], rel)
		eb.play_card(pick.call(eb, "ice_coffin"), 0)
		var eu0 := eb.ult
		eb.play_card(pick.call(eb, "slash"), 0)
		return eb.ult - eu0
	var ua: int = ult_of.call([])
	var ub2: int = ult_of.call(["eclipse_ring"])
	check(ub2 - ua == P2Catalog.ECLIPSE_ULT, "일식 반지: 반응 때 필살 +10 더 (%d → %d)" % [ua, ub2])
	rb = mkr.call("shaman", ["guard"], ["doom_skull"])
	rb._st_add(0, "doom", 2)
	rb._doom_burst(0)
	check(rb.monsters[0].hp == 192, "파멸의 두개골: 저주 2 × 4 = 8 (%d)" % (200 - rb.monsters[0].hp))
	rb = mkr.call("warden", ["slash"], ["cruel_eye"])
	rb._st_add(0, "vuln", 2)
	rb.play_card(pick.call(rb, "slash"), 0)
	check(rb.monsters[0].hp == 190, "잔혹한 눈: 취약한 적에게 베기 5 × 2 = 10 (%d)" % (200 - rb.monsters[0].hp))


# 옛 세 직업 손질: 수치 규칙(직접 계산) + 실제 손맛 전투에서 새 큰 한 방 카드 연출을 찍는다.
# 고정값(공개): 새 프로필(시드 350~353), 적 체력 200, 치명 끔(수치 확인), 직업은 원정 출발 전 고정값으로 바꿈
# 12차 특성 16종: 전투 규칙은 전투 객체로 직접, 원정 쪽(정예 보상 특성 · 수집가 · 넓은 배낭)은 실제 원정 거래로
func run_traits12() -> void:
	await new_profile(362)
	# 실제 원정: 정예 보상 마지막에 특성 고르기 → 거래 · 검증 통과
	check(SaveManager.commit("traits12"), "원정 전 저장")
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		var parts := RunModel.build_parts(r, "elite")
		r.reward = {"id": "elite", "parts": parts, "index": parts.size() - 1, "after": "explore"}
		r.phase = "reward"), "고정값: 정예 보상 마지막 부분")
	var part := RunService.current_part()
	check(String(part.get("type", "")) == "trait" and (part.traits as Array).size() == 3, "정예 보상: 특성 후보 %s" % str(part.get("traits", [])))
	h.show_reward()
	await secs(0.3)
	await shot("t12_reward_trait")
	var pick := String(part.traits[1])
	await h.confirm_reward({"trait": pick})
	await secs(0.3)
	check((RunService.run.traits as Array).has(pick) and String(RunService.run.phase) != "reward", "정예 특성 받음: %s (구간 I · 특성 %d개)" % [pick, (RunService.run.traits as Array).size()])
	var tk := func(cid: String, kinds: Array, tr_ids: Array, n := 2, items: Array = [], extra := {}) -> P2Battle:
		var cards: Array[Card] = []
		for k in kinds:
			cards.append(P2Catalog.build_card(String(k), "t12_" + String(k) + str(cards.size())))
		var roles: Array = []
		for i in range(n):
			roles.append("breaker")
		var op := {"class_id": cid, "crit_mode": "off", "prep_enabled": false, "traits": tr_ids}
		op.merge(extra)
		var its: Array[String] = []
		its.assign(items)
		var bb := P2Battle.new({"enemies": roles, "offsets": roles.map(func(_r): return 0)}, cards, its, 11, op)
		bb.start()
		for i in range(bb.monsters.size()):
			bb.monsters[i].max_hp = 200
			bb.monsters[i].hp = 200
			bb.armor[i] = 0
		bb.hand.cards = cards.duplicate()
		bb.max_mana = 12
		bb._set_mana(12)
		return bb
	var tcard := func(bb: P2Battle, k: String) -> Card:
		for c in bb.hand.cards:
			if P2Catalog.kind_of(c) == k:
				return c
		return null
	var tev := func(bb: P2Battle, kind: String) -> Array:
		return bb.events.filter(func(e): return String(e.kind) == kind)
	GameState.set_flag("player_max_hp", 40)
	GameState.set_flag("player_hp", 40)
	# 연쇄 반응: 1번 적 증기 폭발 9 → 가장 가까운 0번에 절반(5)
	var cr: P2Battle = tk.call("rune_caster", ["fireball", "frost_lance"], ["chain_react"], 3)
	cr.play_card(tcard.call(cr, "fireball"), 1)
	var cr0 := cr.monsters[0].hp
	cr.play_card(tcard.call(cr, "frost_lance"), 1)
	var crc: Array = (tev.call(cr, "react") as Array).filter(func(e): return e.has("chain_from"))
	check(crc.size() == 1 and int(crc[0].index) == 0 and int(crc[0].chain_from) == 1 and cr0 - cr.monsters[0].hp == 5 + 4 and cr.chain_n == 1,
		"연쇄 반응: 옆 적 = 연쇄 절반 5 + 원래 튐 4 = %d (%s)" % [cr0 - cr.monsters[0].hp, str(crc)])
	# 원소 순환: 불 · 얼음 · 독 세 가지 → 마나 1 + 1장
	var ec: P2Battle = tk.call("rune_caster", ["fireball", "frost_lance", "poison_cloud", "slash", "slash", "slash", "guard"], ["elem_cycle"])
	ec.play_card(tcard.call(ec, "fireball"), 0)
	ec.play_card(tcard.call(ec, "frost_lance"), 1)
	check(not ec.trait_used.has("elem_cycle"), "원소 순환: 두 가지까지는 아직")
	ec.play_card(tcard.call(ec, "poison_cloud"), -1)
	var ecm: Array = (tev.call(ec, "mana_refund") as Array).filter(func(e): return String(e.source) == "elem_cycle")
	var ecd: Array = (tev.call(ec, "draw") as Array).filter(func(e): return String(e.source) == "elem_cycle")
	check(ec.trait_used.has("elem_cycle") and ecm.size() == 1 and ecd.size() == 1 and (tev.call(ec, "elem_cycle") as Array).size() == 1, "원소 순환: 세 번째 원소에 마나 1 · 1장 (%s)" % str(ecm))
	# 저주 이자: 터지지 않고 턴을 넘기면 +1
	var di: P2Battle = tk.call("shaman", ["doom_brand"], ["doom_interest"])
	di.play_card(tcard.call(di, "doom_brand"), 0)
	var di0 := di.st(0, "doom")
	di.begin_round_resolution()
	check(di.st(0, "doom") == di0 + 1 and (tev.call(di, "doom_interest") as Array).size() == 1, "저주 이자: 저주 %d → %d" % [di0, di.st(0, "doom")])
	# 파멸의 메아리: 저주 폭발로 쓰러지면 절반(올림)이 가장 약한 다른 적에게
	var de: P2Battle = tk.call("shaman", ["guard"], ["doom_echo"], 3)
	de.monsters[0].hp = 5
	de.monsters[2].hp = 150
	de._st_add(0, "doom", 5)
	de._st_set(0, "doom_t", 1)
	de.begin_round_resolution()
	check(not de.monsters[0].is_alive() and de.st(2, "doom") == 3 and de.st(1, "doom") == 0 and (tev.call(de, "doom_echo") as Array).size() == 1, "파멸의 메아리: 저주 5 → 가장 약한 적에게 3 (%d · %d)" % [de.st(1, "doom"), de.st(2, "doom")])
	# 끊기지 않는 흐름: 턴이 바뀌어도 연격 절반
	var fk: P2Battle = tk.call("combo", ["guard"], ["flow_keep"])
	fk.combo = 5
	fk.begin_round_resolution()
	fk.finish_round_resolution()
	var fk0: P2Battle = tk.call("combo", ["guard"], [])
	fk0.combo = 5
	fk0.begin_round_resolution()
	fk0.finish_round_resolution()
	check(fk.combo == 2 and fk0.combo == 0, "끊기지 않는 흐름: 연격 5 → %d (없으면 %d)" % [fk.combo, fk0.combo])
	# 연격 폭주: 연격 최대(6)에서 공격 카드 → 모든 적 연격 × 3
	var cb: P2Battle = tk.call("combo", ["jab"], ["combo_burst"])
	cb.combo = P2Catalog.COMBO_MAX
	var cb1 := cb.monsters[1].hp
	cb.play_card(tcard.call(cb, "jab"), 0)
	check((tev.call(cb, "combo_burst_cast") as Array).size() == 1 and cb1 - cb.monsters[1].hp == P2Catalog.COMBO_MAX * 3 and cb.combo == 0, "연격 폭주: 옆 적 %d · 연격 %d" % [cb1 - cb.monsters[1].hp, cb.combo])
	# 무결: 적 차례에 하나도 안 맞으면 다음 턴 마나 최대 +1 · 1장 더
	var fl: P2Battle = tk.call("warden", ["guard", "guard", "guard", "guard", "guard", "guard", "guard", "guard"], ["flawless"])
	fl._pending_defense = 200
	fl.end_turn()
	check(fl.extra_mana_turn == 1 and fl.mana_now() == fl.max_mana + 1 and (tev.call(fl, "flawless") as Array).size() == 1, "무결: 마나 %d / 최대 %d" % [fl.mana_now(), fl.max_mana])
	var fl2: P2Battle = tk.call("warden", ["guard"], ["flawless"])
	fl2._pending_defense = 0
	fl2.end_turn()
	check(fl2.extra_mana_turn == 0 and fl2.mana_now() == fl2.max_mana, "무결: 맞으면 없음")
	GameState.set_flag("player_hp", 40)
	# 받아치기: 완벽 막기 → 그 공격 절반(올림)을 되돌림, 적 차례마다 15까지
	var rb: P2Battle = tk.call("warden", ["guard"], ["riposte_beat"])
	rb.begin_round_resolution()
	var rb0 := rb.monsters[0].hp
	rb._enemy_hit(0, 0, 9, "perfect", -1.0)
	check(rb0 - rb.monsters[0].hp == 5 + P2Catalog.WARDEN_PARRY_DAMAGE and (tev.call(rb, "riposte_beat") as Array).size() == 1, "받아치기: 9의 절반 5 (+수호기사 반격) = %d" % (rb0 - rb.monsters[0].hp))
	for k in range(5):
		rb._enemy_hit(0, 0, 9, "perfect", -1.0)
	check(rb.riposte_sum == P2Catalog.RIPOSTE_CAP, "받아치기 합계 상한 %d" % rb.riposte_sum)
	GameState.set_flag("player_hp", 40)
	# 두 겹 필살: 200까지, 100마다 한 번
	var ud: P2Battle = tk.call("rune_caster", ["guard"], ["ult_double"])
	ud._ult_add(170, "test")
	var ud_ok := ud.use_ultimate(0)
	var ud0: P2Battle = tk.call("rune_caster", ["guard"], [])
	ud0._ult_add(170, "test")
	check(ud_ok and ud.ult == 70 and ud0.ult == 100, "두 겹 필살: 170 → 쓰고 %d (없으면 %d에서 멈춤)" % [ud.ult, ud0.ult])
	# 필살 여운: 쓴 턴 손패 비용 −1, 다음 턴 되돌림
	var ua: P2Battle = tk.call("rune_caster", ["fireball", "ice_coffin", "guard"], ["ult_after"])
	ua.ult = 100
	ua.use_ultimate(0)
	var uac: Card = tcard.call(ua, "ice_coffin")
	var ua_cost := uac.mana_cost
	var ua_ev := (tev.call(ua, "ult_after") as Array).size()
	ua.end_turn()
	check(ua_cost == 1 and uac.mana_cost == 2 and ua_ev == 1, "필살 여운: 빙결의 관 2 → %d → 다음 턴 %d" % [ua_cost, uac.mana_cost])
	GameState.set_flag("player_hp", 40)
	# 넓은 배낭 · 수집가 · 얇은 덱 · 무기고
	check(P2Catalog.relic_capacity({"traits": ["wide_pack"]}) == 6 and P2Catalog.relic_capacity({"traits": []}) == 5, "넓은 배낭: 유물 칸 6")
	var col: P2Battle = tk.call("warden", ["guard"], ["collector"], 2, ["arc", "thorn"])
	check(col.get_pending_defense() == 2 and (col.relics as Array).size() == 2, "수집가: 유물 2개 → 전투 시작 방어 %d" % col.get_pending_defense())
	var crun := {"relics": ["arc", "thorn", "bandage"], "max_hp": 40, "hp": 30}
	RunModel.gain_trait(crun, "collector")
	check(int(crun.max_hp) == 46 and int(crun.hp) == 36, "수집가: 얻을 때 유물 3개 → 최대 체력 %d · 체력 %d" % [int(crun.max_hp), int(crun.hp)])
	var thin_cards: Array[Card] = []
	for k in range(12):
		thin_cards.append(P2Catalog.build_card("slash", "thin%d" % k))
	var th := P2Battle.new({"enemies": ["breaker"], "offsets": [0]}, thin_cards, [] as Array[String], 11, {"class_id": "warden", "crit_mode": "off", "prep_enabled": false, "traits": ["thin_deck"]})
	th.start()
	var th0 := P2Battle.new({"enemies": ["breaker"], "offsets": [0]}, thin_cards.duplicate(), [] as Array[String], 11, {"class_id": "warden", "crit_mode": "off", "prep_enabled": false, "traits": []})
	th0.start()
	check(th.hand.cards.size() == th0.hand.cards.size() + 1, "얇은 덱: 12장 덱 → 손패 %d (없으면 %d)" % [th.hand.cards.size(), th0.hand.cards.size()])
	var arm_cards: Array[Card] = []
	for k in range(21):
		arm_cards.append(P2Catalog.build_card("slash", "arm%d" % k))
	var ar := P2Battle.new({"enemies": ["breaker"], "offsets": [0]}, arm_cards, [] as Array[String], 11, {"class_id": "warden", "crit_mode": "off", "prep_enabled": false, "traits": ["armory"]})
	ar.start()
	var arp := ar.first_hit_bonus(ar.hand.cards[0])
	check(int(arp.get("armory", 0)) == 4, "무기고: 덱 21장 → 첫 공격 +%d" % int(arp.get("armory", 0)))
	# 피의 값: 절반 이하 +2 · 30% 이하 +4
	var bp: P2Battle = tk.call("warden", ["slash", "slash"], ["blood_price"])
	GameState.set_flag("player_hp", 30)
	var bp_full := bp.blood_bonus()
	GameState.set_flag("player_hp", 20)
	var bp_half := bp.blood_bonus()
	var bph := bp.monsters[0].hp
	bp.play_card(tcard.call(bp, "slash"), 0)
	var bp_dmg := bph - bp.monsters[0].hp
	GameState.set_flag("player_hp", 12)
	var bp_low := bp.blood_bonus()
	check(bp_full == 0 and bp_half == 2 and bp_low == 4 and bp_dmg >= 5 + 2, "피의 값: 75%% %d · 50%% %d · 30%% %d · 베기 %d" % [bp_full, bp_half, bp_low, bp_dmg])
	# 질긴 목숨: 쓰러질 피해 → 체력 1 (원정마다 한 번)
	var ls: P2Battle = tk.call("warden", ["guard"], ["last_stand"])
	GameState.set_flag("player_hp", 6)
	ls.begin_round_resolution()
	ls._enemy_hit(0, 0, 20, "", -1.0)
	var ls_hp := ls.player_hp()
	check(ls_hp == 1 and ls.last_stand_spent and not ls.battle_over and (tev.call(ls, "last_stand") as Array).size() == 1, "질긴 목숨: 체력 6에 20 → %d" % ls_hp)
	var ls_snap := P2Battle.from_dict(ls.to_dict(), {}, true)
	check(ls_snap.last_stand_spent, "질긴 목숨: 이어하기 저장에도 '씀'")
	var ls2: P2Battle = tk.call("warden", ["guard"], ["last_stand"], 2, [], {"trait_spent": ["last_stand"]})
	check(ls2.last_stand_spent, "질긴 목숨: 이미 쓴 원정이면 없음")
	GameState.set_flag("player_hp", 40)
	# 특성 후보 조건: 연격 특성은 콤보술사만, 저주 특성은 주술사(저주 카드)만, 원소 특성은 원소 두 가지 이상 덱
	var rr := {"traits": [], "class_id": "warden", "deck": [{"kind": "slash"}, {"kind": "guard"}], "relics": []}
	check(not RunModel.trait_eligible("combo_burst", rr) and not RunModel.trait_eligible("doom_echo", rr) and not RunModel.trait_eligible("chain_react", rr) and RunModel.trait_eligible("flawless", rr),
		"수호기사 기본 덱: 연격·저주·원소 특성은 후보에 없음")
	rr.class_id = "rune_caster"
	rr.deck = [{"kind": "fireball"}, {"kind": "frost_lance"}]
	check(RunModel.trait_eligible("chain_react", rr) and RunModel.trait_eligible("elem_cycle", rr), "원소술사 불 · 얼음 덱: 원소 특성 후보")
	await flush_snaps()


func _st_put(v: P2BattleView, kinds: Array) -> void:
	var list: Array[Card] = []
	for k in kinds:
		list.append(P2Catalog.build_card(String(k), "st_" + String(k) + str(list.size())))
	v.battle.hand.cards = list
	v._build_hand(false)
	v.battle._set_mana(v.battle.max_mana)
	v._sync_shown_from_battle()
	v._render_all()
	v._refresh_card_states()


func _st_play(v: P2BattleView, kind: String, tgt: int, name: String, n: int) -> void:
	var c: Card = null
	for cc in v.battle.hand.cards:
		if P2Catalog.kind_of(cc) == kind:
			c = cc
	v.play_card(c, tgt)
	if P2Catalog.is_attack(c):
		var gp := await fe_pad(v)
		if gp != null:
			await fe_glyph(gp, 0.4)
	snap_burst(name, n, 0.08)
	await fe_idle(v)
	await secs(0.3)


# 특성 발동 화면: 연쇄 반응 · 원소 순환 · 두 겹 필살 · 피의 값 (원소술사), 파멸의 메아리 · 저주 이자 (주술사), 연격 폭주 (콤보술사), 무결 · 질긴 목숨 (수호기사)
func run_show_traits(rune_only := false) -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	# 원소술사
	var v1 := await show_start("rune_caster", 371)
	var b1 := v1.battle
	b1.traits.assign(["chain_react", "elem_cycle", "ult_double", "blood_price"])
	GameState.set_flag("player_hp", maxi(1, int(GameState.get_flag("player_max_hp")) / 4))
	for m in b1.alive_monsters():
		b1._st_add(m.index, "burn", 3)
	v1._show.rebuild_enemies()
	_st_put(v1, ["frost_lance", "poison_cloud"])
	await secs(0.5)
	await snap("tr_blood_dots")
	await _st_play(v1, "frost_lance", 0, "tr_chain", 22)
	check(b1.chain_n == 1, "연쇄 반응 화면: 연쇄 %d번" % b1.chain_n)
	await _st_play(v1, "poison_cloud", -1, "tr_elem", 16)
	check(b1.trait_used.has("elem_cycle"), "원소 순환 화면")
	b1.ult = 160
	v1._render_all()
	await secs(1.2)
	await snap("tr_ult_double")
	if rune_only:
		P2BattleView.feel_force = CLASSIC
		await flush_snaps()
		return
	# 주술사
	var v2 := await show_start("shaman", 372)
	var b2 := v2.battle
	b2.traits.assign(["doom_echo", "doom_interest"])
	b2.monsters[0].hp = 6
	b2._st_add(0, "doom", 4)
	b2._st_set(0, "doom_t", 1)
	b2._st_add(1, "doom", 2)
	v2._sync_shown_from_battle()
	v2._render_all()
	_st_put(v2, ["guard"])
	snap_burst("tr_doom", 26, 0.12)
	await v2.end_turn()
	await wait_until(func(): return v2.current_state() == "PLAYER" or b2.battle_over, 25.0)
	check(not b2.monsters[0].is_alive() and b2.st(1, "doom") >= 3, "파멸의 메아리 화면: 옆 적 저주 %d" % b2.st(1, "doom"))
	# 콤보술사
	var v3 := await show_start("combo", 373)
	var b3 := v3.battle
	b3.traits.assign(["combo_burst"])
	_st_put(v3, ["jab"])
	b3.combo = P2Catalog.COMBO_MAX
	v3._sync_shown_from_battle()
	v3._render_all()
	await _st_play(v3, "jab", 0, "tr_combo", 20)
	check(b3.trait_used.has("combo_burst"), "연격 폭주 화면")
	# 수호기사: 다 막은 턴 → 무결, 다음 적 차례 체력 1에서 버팀
	var v4 := await show_start("warden", 374)
	var b4 := v4.battle
	b4.traits.assign(["flawless", "last_stand", "collector"])
	_st_put(v4, ["guard"])
	b4._pending_defense = 300
	v4._sync_shown_from_battle()
	v4._render_all()
	await v4.end_turn()
	snap_burst("tr_flawless", 14, 0.1)
	await wait_until(func(): return v4.current_state() == "PLAYER", 25.0)
	check(b4.extra_mana_turn == 1, "무결 화면: 마나 %d" % b4.mana_now())
	await secs(1.2)
	GameState.set_flag("player_hp", 2)
	b4._pending_defense = 5
	v4._sync_shown_from_battle()
	v4._render_all()
	snap_burst("tr_last", 40, 0.12)
	await v4.end_turn()
	await wait_until(func(): return v4.current_state() == "PLAYER" or b4.battle_over, 25.0)
	check(b4.last_stand_spent and b4.player_hp() >= 1, "질긴 목숨 화면: 체력 %d" % b4.player_hp())
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


func run_rework() -> void:
	await new_profile(350)
	var mk := func(cid: String, kinds: Array, ups := {}) -> P2Battle:
		var cards: Array[Card] = []
		for k in kinds:
			cards.append(P2Catalog.build_card(String(k), "rw_" + String(k), String(ups.get(k, ""))))
		var bb := P2Battle.new({"enemies": ["breaker", "breaker"], "offsets": [0, 0]}, cards, [] as Array[String], 7, {"class_id": cid, "crit_mode": "off", "prep_enabled": false})
		bb.start()
		for m in bb.monsters:
			m.max_hp = 200
			m.hp = 200
		bb.hand.cards = cards.duplicate()
		bb._set_mana(bb.max_mana)
		return bb
	var lost := func(bb: P2Battle, c: Card, t: int) -> Array:
		var pv := bb.preview(c, t)
		return (pv.monsters as Array).map(func(m): return int(m.hp_before) - int(m.hp))
	# 수호기사: 방패 내려찍기 · 대지 붕괴 · 완벽 막기 반격
	var w: P2Battle = mk.call("warden", ["slam", "guard"])
	w._pending_defense = 10
	var sl: Array = lost.call(w, w.hand.cards[0], 0)
	check(sl[0] == 4 + 10 * 2 - int(w.armor[0]) and sl[1] == 5 - int(w.armor[1]), "방패 내려찍기: 방어 10 → 대상 %d · 옆 적 %d (기대 24 · 5, 갑옷 %s)" % [sl[0], sl[1], str(w.armor)])
	w.play_card(w.hand.cards[0], 0)
	check(w._pending_defense == 10, "방패 내려찍기 뒤에도 방어 10 그대로 (%d)" % w._pending_defense)
	var w2: P2Battle = mk.call("warden", ["slam"], {"slam": "earthshaker"})
	w2._pending_defense = 8
	var es: Array = lost.call(w2, w2.hand.cards[0], 0)
	check(es[0] == 6 + 8 * 3 - int(w2.armor[0]), "대지 붕괴: 6 + 방어 8 × 3 = %d" % es[0])
	var w3: P2Battle = mk.call("warden", ["guard"])
	var hp0 := w3.monsters[0].hp
	var counters := 0
	for i in range(8):
		w3.events.clear()
		w3._enemy_hit(0, i, 3, "perfect", -1.0)
		counters += w3.events.filter(func(e): return String(e.kind) == "shield_counter").size()
	check(counters == P2Catalog.WARDEN_PARRY_MAX and hp0 - w3.monsters[0].hp == P2Catalog.WARDEN_PARRY_DAMAGE * P2Catalog.WARDEN_PARRY_MAX - int(w3.armor[0]) * counters,
		"수호기사 완벽 막기 8번 → 반격 %d번 (최대 6) · 적 체력 −%d" % [counters, hp0 - w3.monsters[0].hp])
	var h0: P2Battle = mk.call("hunter", ["slash"])
	var r0: P2Battle = mk.call("rune_caster", ["slash"])
	r0.events.clear()
	h0.events.clear()
	check(h0._crit_mult_now(0) > r0._crit_mult_now(0) + 0.49, "사냥꾼 치명 배율 %.2f > 다른 직업 %.2f" % [h0._crit_mult_now(0), r0._crit_mult_now(0)])
	# 사냥꾼: 화살비 모든 적 2 × 5
	var hn: P2Battle = mk.call("hunter", ["arrow_rain"])
	var ar: Array = lost.call(hn, hn.hand.cards[0], -1)
	check(ar[0] == 5 * maxi(0, 2 - int(hn.armor[0])) and ar[1] == ar[0], "화살비: 적마다 %s (기대 2 × 5)" % str(ar))
	# 룬술사: 표식 5개까지 · 연쇄 폭발
	var rn: P2Battle = mk.call("rune_caster", ["bolt", "chain_blast"])
	rn._set_marks(0, 4)
	rn.play_card(rn.hand.cards[0], 0)
	check(rn.mark_count(0) == 5, "룬술사 표식 4 → 마력탄 → 5 (%d)" % rn.mark_count(0))
	var wd: P2Battle = mk.call("warden", ["bolt"])
	wd._set_marks(0, 3)
	wd.play_card(wd.hand.cards[0], 0)
	check(wd.mark_count(0) == 3, "다른 직업은 표식 3에서 멈춤 (%d)" % wd.mark_count(0))
	var rc: P2Battle = mk.call("rune_caster", ["chain_blast"])
	rc._set_marks(0, 4)
	rc._set_marks(1, 1)
	var ch: Array = lost.call(rc, rc.hand.cards[0], -1)
	var a0 := maxi(0, 2 - int(rc.armor[0]))
	var a1 := maxi(0, 2 - int(rc.armor[1]))
	check(ch[0] == a0 + 4 * 4 and ch[1] == a1 + 4 + maxi(0, P2Catalog.CHAIN_SPLASH - int(rc.armor[1])), "연쇄 폭발: 표식 4 → %d, 표식 1 + 연쇄 3 → %d" % [ch[0], ch[1]])
	rc.play_card(rc.hand.cards[0], -1)
	check(rc.mark_count(0) == 0 and rc.mark_count(1) == 0 and rc.events.any(func(e): return String(e.kind) == "chain"), "연쇄 폭발 뒤 표식 모두 0 · 연쇄 사건")
	# 콤보술사 강화 사본
	check(P2Catalog.hits_of(P2Catalog.build_card("storm", "u1", "tempest")) == 7 and P2Catalog.hits_of(P2Catalog.build_card("flurry", "u2", "gale_flurry")) == 4, "폭풍 난무 7타 · 질풍 연타 4타")
	var cb: P2Battle = mk.call("combo", ["finisher"], {"finisher": "final_blow"})
	cb.combo = 4
	cb.combo_target = 0
	var fb: Array = lost.call(cb, cb.hand.cards[0], 0)
	check(fb[0] == 8 + 4 * 3 + 4 - int(cb.armor[0]), "끝장 일격: 8 + 연격 4 × 3 + 연격 4 = %d" % fb[0])
	var cs: P2Battle = mk.call("combo", ["parry_stance"], {"parry_stance": "counter_stance"})
	cs.play_card(cs.hand.cards[0], -1)
	check(cs.combo == 3 and cs._pending_defense >= 6, "받아치기 자세: 방어 6 · 연격 +3 (%d · %d)" % [cs._pending_defense, cs.combo])
	var deck_combo: Array = P2Catalog.class_deck("combo").map(func(k): return {"kind": k, "uid": "d_" + String(k) + str(randi())})
	var offer: Array = RunModel.upgrade_offer(RandomNumberGenerator.new(), {"deck": deck_combo, "class_id": "combo"})
	check(offer.any(func(u): return String(P2Catalog.UPGRADE_KINDS[u].from) in ["jab", "flurry", "finisher", "flow"]), "콤보술사 강화 후보에 자기 카드 강화 %s" % str(offer))
	var faces := []
	for up in ["tempest", "final_blow", "earthshaker", "arrow_storm", "grand_chain", "dominate"]:
		var c := P2Catalog.build_card(String(P2Catalog.UPGRADE_KINDS[up].from), "f_" + up, up)
		faces.append(P2Catalog.face(c, "combo")[0])
	check(faces.all(func(f): return String(f) != "" and not String(f).contains("%")), "강화 앞면 글 %s" % str(faces))
	# 실제 손맛 전투에서 새 카드 연출
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var spec := [["warden", "slam", "quake"], ["hunter", "arrow_rain", "rain"], ["rune_caster", "chain_blast", "chain"]]
	for si in range(spec.size()):
		var cid := String(spec[si][0])
		var kind := String(spec[si][1])
		var sig := String(spec[si][2])
		await new_profile(351 + si)
		check(await RunService.commit_profile("class fixture", func(c, _r, _f):
			c.combat.class_id = cid
			P5Campaign.refresh_vitals(c)
			return true), "고정값: " + cid)
		check(Flow.start_expedition(), cid + " 원정")
		check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
		var h := host()
		await secs(0.6)
		h.dismiss_notices()
		h._on_engage("n1")
		check(await h.engage_confirm("n1"), "N1 전투")
		check(await battle_ready(h), "차례")
		var v: P2BattleView = h.battle_view
		var b := v.battle
		Engine.time_scale = 1.0
		av1_tough(v, 200)
		var card := P2Catalog.build_card(kind, "rv_" + kind)
		var list: Array[Card] = [card, P2Catalog.build_card("guard", "rv_g1"), P2Catalog.build_card("guard", "rv_g2")]
		b.hand.cards = list.duplicate()
		v._build_hand(false)
		await secs(0.4)
		if kind == "slam":
			b._pending_defense = 10
		if kind == "chain_blast":
			b._set_marks(0, 4)
			b._set_marks(1, 2)
		b._set_mana(b.max_mana)
		v._sync_shown_from_battle()
		v._render_all()
		v._refresh_card_states()
		v.skill_log.clear()
		var hp_before: Array = b.monsters.map(func(m): return m.hp)
		v.play_card(card, fe_target(b) if P2Catalog.is_targeted(card) else -1)
		var pad := await fe_pad(v)
		if pad != null:
			await fe_glyph(pad, 0.45)
		if await wait_until(func(): return v.skill_log.any(func(e): return String(e.fx) == sig), 5.0):
			await frames(4)
			await snap("rework_%02d_%s" % [si + 1, kind])
			await secs(0.12)
			await snap("rework_%02db_%s" % [si + 1, kind])
		await fe_idle(v)
		var hurt: Array = []
		for i in range(b.monsters.size()):
			hurt.append(int(hp_before[i]) - b.monsters[i].hp)
		check(v.skill_log.any(func(e): return String(e.fx) == sig) and hurt.all(func(x): return x > 0), "%s %s: 연출 %s · 적마다 피해 %s" % [cid, kind, sig, str(hurt)])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 적 공격 악보가 뜨기 전 붉은 예고 틀: 고리(가운데 위)와 아래 무대 장르 모두, 틀이 떠 있는 동안 악보는 숨고 멈춤, 틀 자리 = 악보 자리
# 고정값(공개): 새 프로필(시드 349), 첫 전투 N1, 적 체력 300, 두 번째 적 차례는 북 장단으로 고정
func run_zone_cue() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(349)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	av1_tough(v, 300)
	for round_i in range(2):
		P2BattleView.genre_force = "" if round_i == 0 else "drum"
		var n0 := v.cue_log.size()
		v.end_turn()
		var got := await wait_until(func(): return v.cue_log.size() > n0, 12.0)
		var hidden_ok := false
		var shot_name := "zone_cue_%02d" % (round_i + 1)
		if got:
			await frames(2)
			var charts: Array = v._ui.get_children().filter(func(c): return c is P2NoteChart)
			hidden_ok = not charts.is_empty() and charts.all(func(c): return not (c as P2NoteChart).visible and (c as P2NoteChart)._t == 0.0)
			await snap(shot_name)
		var rec: Dictionary = v.cue_log[n0] if got else {}
		var shown := await wait_until(func(): return v._ui.get_children().any(func(c): return c is P2NoteChart and (c as P2NoteChart).visible and (c as P2NoteChart)._t > 0.05), 3.0)
		var match_ok := false
		if shown and got:
			for c in v._ui.get_children():
				if c is P2NoteChart and (c as P2NoteChart).visible:
					match_ok = (rec.rect as Rect2).grow(-6.0).is_equal_approx((c as P2NoteChart).cue_rect())
		check(got and hidden_ok and shown and match_ok, "%s: 예고 틀 %s → 그동안 악보 숨김·멈춤 %s → 틀 자리 = 악보 자리 %s (%s)" % [
			"고리" if round_i == 0 else "북 장단", str(got), str(hidden_ok), str(match_ok), str(rec.get("rect", ""))])
		check(round_i == 0 or ((rec.rect as Rect2).position.y > 400.0), "북 장단 틀은 화면 아래 무대")
		await secs(0.2)
		await wait_until(func(): return v.current_state() == "PLAYER", 25.0)
		await fe_idle(v)
	P2BattleView.genre_force = ""
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 적 예고 위 작은 표에 실제 포인터를 올리면 무엇이 뜨는지
func run_pips_hover() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(348)
	var v: P2BattleView = h.battle_view
	await secs(0.6)
	var p: Dictionary = v._enemy_panels[0]
	var intent: Control = p.intent
	var pips: Control = intent.get_meta("pips") if intent.has_meta("pips") else null
	check(pips != null and pips.visible, "작은 표 있음")
	if pips != null:
		var at := pips.get_global_rect().get_center()
		note("작은 표 자리 %s · 크기 %s · 글 %s" % [str(at), str(pips.size), pips.tooltip_text.replace("\n", " / ")])
		ptr_move(at)
		await secs(0.1)
		ptr_move(at + Vector2(1, 0))
		await secs(1.4)
		var hov := get_viewport().gui_get_hovered_control()
		note("올린 곳의 컨트롤: %s" % (str(hov.get_path()) if hov != null else "없음"))
		await snap("pips_hover_01")
		ptr_move(intent.get_global_rect().get_center())
		await secs(1.4)
		hov = get_viewport().gui_get_hovered_control()
		note("예고 칸 컨트롤: %s · 글 %s" % [str(hov.get_path()) if hov != null else "없음", hov.tooltip_text.replace("\n", " / ") if hov != null else ""])
		await snap("pips_hover_02")
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 콤보술사 방어·도구 카드를 쓰고 나면 내 차례로 돌아오는지(멈춤 재현). 카드 순서 여럿 + 적 차례를 끼워서.
# 고정값(공개): 새 프로필(시드 347), 콤보술사, 첫 전투 N1, 적 체력 300
func run_combo_def() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	await new_profile(347)
	check(await RunService.commit_profile("combo fixture", func(c, _r, _f):
		c.combat.class_id = "combo"
		P5Campaign.refresh_vitals(c)
		return true), "고정값: 콤보술사")
	check(Flow.start_expedition(), "콤보술사로 원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	h._on_engage("n1")
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	av1_tough(v, 300)
	var seqs := [["parry_stance"], ["jab", "parry_stance"], ["jab", "flow"], ["jab", "guard"], ["flurry", "breather", "parry_stance"], ["jab", "focus"], ["flow", "jab"], ["end"], ["parry_stance", "flow"], ["end"], ["jab", "parry_stance", "finisher"]]
	for si in range(seqs.size()):
		var seq: Array = seqs[si]
		if String(seq[0]) == "end":
			await v.end_turn()
			var turned := await wait_until(func(): return v.current_state() == "PLAYER", 25.0)
			check(turned, "적 차례 뒤 내 차례 (%s)" % v.current_state())
			await fe_idle(v)
			continue
		var list: Array[Card] = []
		for k in seq:
			list.append(P2Catalog.build_card(String(k), "cd%d_%s" % [si, k]))
		b.hand.cards = list.duplicate()
		v._build_hand(false)
		await secs(0.4)
		for c in list:
			b._set_mana(5)
			v._render_all()
			v._refresh_card_states()
			var k := P2Catalog.kind_of(c)
			var tgt := fe_target(b) if P2Catalog.is_targeted(c) else -1
			var t0 := Time.get_ticks_msec()
			v.play_card(c, tgt)
			if P2Catalog.is_attack(c):
				var pad := await fe_pad(v)
				if pad != null:
					await fe_glyph(pad, 0.35)
			var back := await wait_until(func(): return v.current_state() == "PLAYER", 8.0)
			check(back, "%s 중 %s: 내 차례로 돌아옴 (%s · %dms · 연격 %d)" % [str(seq), k, v.current_state(), Time.get_ticks_msec() - t0, b.combo])
			if not back:
				await snap("combo_def_stuck_%d_%s" % [si, k])
				note("멈춤 상태: anim %s · busy %s · gate %s" % [v._player.animation, str(v._state), str(v.gate != null and v.gate.is_open())])
				break
			await fe_idle(v)
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 카드마다 고유 긋기 문양: 공격 카드 문양 이름이 서로 다르고(기본 종류는 그대로), 판을 띄워 모양을 찍는다. 카드 앞면 직업 문장도 함께.
# 고정값(공개): 새 프로필(시드 335), 첫 전투 N1
func run_glyphs() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(335)
	var v: P2BattleView = h.battle_view
	Engine.time_scale = 1.0
	var kinds := ["slash", "bash", "pierce", "twin_slash", "bolt", "suppress", "sigil_burst", "torrent", "jab", "flurry", "storm", "finisher", "palm", "focus_strike",
		"shield_throw", "volley", "weak_point", "mark_amp", "ember", "beat_slash", "heal_sigil"]
	var names := {}
	var counts := {}
	for k in kinds:
		var g := String(P2BattleView.CARD_GLYPH[k][0])
		names[g] = int(names.get(g, 0)) + 1
		var spec: Dictionary = v._slash_points(P2Catalog.build_card(k, "g_" + k), 0)
		counts[k] = (spec.points as Array).size()
	check(names.size() == kinds.size(), "공격 카드 문양이 모두 다름 %s" % str(names))
	check(int(counts.bolt) == 4 and int(counts.sigil_burst) == 6 and int(counts.twin_slash) == 3 and int(counts.storm) == 6 and int(counts.torrent) == 7, "점 수 %s" % str(counts))
	var shots := ["finisher", "storm", "torrent", "flurry", "suppress", "focus_strike"]
	for k in shots:
		var spec: Dictionary = v._slash_points(P2Catalog.build_card(k, "g_" + k), 0)
		var pad := P2SlashPad.new()
		pad.setup(spec.points, float(spec.radius), float(spec.limit), bool(spec.ordered), bool(spec.rune), spec.opts)
		v._ui.add_child(pad)
		await secs(0.45)
		await snap("glyph_%s" % k)
		pad.queue_free()
		await secs(0.15)
	var hand: Array[Card] = []
	for k in ["finisher", "storm", "bolt", "bash", "quickshot"]:
		hand.append(P2Catalog.build_card(k, "h_" + k))
	v.battle.hand.cards = hand
	v._build_hand(false)
	await secs(0.5)
	await snap("glyph_cards")
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 카드 고유 연출: 긋는 동안 힘 모으기 → 끝나면 터짐, 마무리 일격 = 공간베기(세 줄이 갈라졌다 붙는 순간에야 체력이 줄어듦),
# 폭풍 연타 = 타격마다 난무, 반동 장타 = 충격파, 겨눈 일격 = 바늘, 각인 파열 = 마법진, 마력 폭류 = 소용돌이. 맞은 몸은 그은 방향으로 밀림.
# 고정값(공개): 새 프로필(시드 336), 첫 전투 N1, 적 체력 200
func run_skillfx() -> void:
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(336)
	var v: P2BattleView = h.battle_view
	var b := v.battle
	Engine.time_scale = 1.0
	av1_tough(v, 200)
	var hand: Array[Card] = []
	for k in ["finisher", "storm", "palm", "focus_strike", "sigil_burst", "torrent"]:
		hand.append(P2Catalog.build_card(k, "s_" + k))
	b.hand.cards = hand.duplicate()
	v._build_hand(false)
	await secs(0.5)
	var fx_of := func(kind: String) -> int:
		return v._fxp.get_children().filter(func(c): return c is P2SkillFx and (c as P2SkillFx).kind == kind).size()
	# 1) 마무리 일격
	b._set_mana(5)
	v._render_all()
	v._refresh_card_states()
	v.skill_log.clear()
	var hp_txt := v.enemy_hp_text(0)
	v.play_card(hand[0], 0)
	var pad := await fe_pad(v)
	var charged: bool = fx_of.call("charge") == 1
	fe_glyph(pad, 0.45)
	if await wait_until(func(): return v._fxp.get_children().any(func(c): return c is P2SkillFx and (c as P2SkillFx).kind == "charge" and (c as P2SkillFx).level > 0.4), 2.0):
		await snap("skill_01_charge")
	await wait_until(func(): return pad.grade != "", 3.0)
	var burst := await wait_until(func(): return fx_of.call("burst") == 1 and fx_of.call("charge") == 0, 0.3)
	note("모으기 뒤: 터짐 %d · 모으기 %d · 꺼짐 %d · 긋기 %s" % [fx_of.call("burst"), fx_of.call("charge"), fx_of.call("fade"), str(v.slash_log.back() if not v.slash_log.is_empty() else {})])
	var split := await wait_until(func(): return v._cut_rect != null and v._cut_rect.visible and float(v._cut_mat.get_shader_parameter("gap")) > 5.0, 4.0)
	var held := v.enemy_hp_text(0) == hp_txt
	if split:
		await snap("skill_02_cut")
		note("공간베기 값: %s" % str(["count", "line0", "line1", "line2", "reveal", "gap", "slide"].map(func(k): return v._cut_mat.get_shader_parameter(k))))
	await fe_idle(v)
	await secs(0.4)
	check(charged and burst, "긋는 동안 힘 모으기 1개 → 완벽이라 터짐 (모으기 %s · 터짐 %s)" % [str(charged), str(burst)])
	check(split and held and v.enemy_hp_text(0) != hp_txt and not v._cut_rect.visible and v.skill_log.any(func(e): return String(e.fx) == "cut"),
		"공간베기: 갈라짐 %s · 갈라진 동안 체력 그대로 %s · 붙은 뒤 체력 %s → %s · 끝나면 숨김" % [str(split), str(held), hp_txt, v.enemy_hp_text(0)])
	# 2) 나머지 물리: 고유 연출이 타격마다
	for pair in [[1, "slash", 5, "skill_03_storm"], [2, "shock", 1, "skill_04_palm"], [3, "needle", 1, "skill_05_needle"]]:
		var card: Card = hand[int(pair[0])]
		b._set_mana(5)
		v._render_all()
		v._refresh_card_states()
		v.skill_log.clear()
		v.play_card(card, fe_target(b))
		pad = await fe_pad(v)
		await fe_glyph(pad, 0.3)
		if await wait_until(func(): return fx_of.call(String(pair[1])) > 0, 4.0):
			await frames(2)
			await snap(String(pair[3]))
		await fe_idle(v)
		var got := v.skill_log.filter(func(e): return String(e.fx) == String(pair[1])).size()
		check(got == int(pair[2]), "%s: %s 연출 %d번 (기대 %d)" % [P2Catalog.kind_of(card), String(pair[1]), got, int(pair[2])])
	# 3) 마법
	for pair in [[4, "sigil", "skill_06_sigil"], [5, "vortex", "skill_07_vortex"]]:
		var card: Card = hand[int(pair[0])]
		b._set_mana(3)
		v._render_all()
		v._refresh_card_states()
		v.skill_log.clear()
		v.play_card(card, fe_target(b) if P2Catalog.is_targeted(card) else -1)
		pad = await fe_pad(v)
		await fe_glyph(pad, 0.5)
		if await wait_until(func(): return fx_of.call(String(pair[1])) > 0, 4.0):
			await secs(0.12)
			await snap(String(pair[2]))
		await fe_idle(v)
		check(v.skill_log.any(func(e): return String(e.fx) == String(pair[1])), "%s: %s 연출" % [P2Catalog.kind_of(card), String(pair[1])])
	# 4) 그은 방향으로 밀림: 위로 그으면 떠올랐다 내려옴
	v._slash_trace = {"rel": PackedVector2Array([Vector2(0, 40), Vector2(60, -40)])}
	var es: AnimatedSprite2D = v._enemy_sprites[fe_target(b)]
	await secs(0.5)
	var y0 := es.position.y
	var x0 := float(es.get_meta("home_x", es.position.x))
	note("밀림 전 x %.1f · 제자리 %.1f" % [es.position.x, x0])
	v._victim_react(es, "heavy", v._stroke_dir(), false)
	var top := y0
	var far := x0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await get_tree().process_frame
		top = minf(top, es.position.y)
		far = maxf(far, es.position.x)
	v._slash_trace = {}
	check(y0 - top > 10.0 and far - x0 > 30.0 and absf(es.position.y - y0) < 0.5 and absf(es.position.x - x0) < 0.5,
		"위로 그은 강타: %.0fpx 떠오르고 %.0fpx 밀렸다 제자리" % [y0 - top, far - x0])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 석판(옆 칸 단계) · 규칙을 바꾸는 유물 · 문양·리듬 유물: 단계 계산, 전투 규칙, 긋기 판(거꾸로 · 가시 삼키기), 배치 창 끌기, 위 띠 단계 표.
# 고정값(공개): 파괴자 + 사수 · 치명 끔, 새 프로필(시드 346)
func run_slabs() -> void:
	var L := func(ids: Array) -> Dictionary: return P2Catalog.relic_levels(ids)
	var a: Dictionary = L.call(["mirror_slab", "blade_rhythm"])
	check(int(a.blade_rhythm) == 2, "거울: 오른쪽 2단계 %s" % str(a))
	a = L.call(["blade_rhythm", "wedge_slab", "absorb"])
	check(int(a.blade_rhythm) == 0 and int(a.absorb) == 3, "쐐기: 왼쪽 잠듦 · 오른쪽 3단계 %s" % str(a))
	a = L.call(["arc", "bridge_slab", "absorb"])
	check(int(a.arc) == 2 and int(a.absorb) == 2, "다리: 양옆 2단계 %s" % str(a))
	a = L.call(["mirror_slab", "bridge_slab", "absorb"])
	check(int(a.bridge_slab) == 1 and int(a.absorb) == 2, "석판끼리는 단계 안 줌 %s" % str(a))
	a = L.call(["mirror_slab", "arc", "bridge_slab"])
	check(int(a.arc) == 3, "거울 + 다리 = 3단계 %s" % str(a))
	a = L.call(["arc", "wedge_slab", "seal_slab", "absorb"])
	check(int(a.arc) == 1 and int(a.wedge_slab) == 0 and int(a.absorb) == 0, "봉인에 잠든 쐐기는 왼쪽을 재우지 않음 %s" % str(a))
	a = L.call(["arc", "seal_slab", "absorb"])
	var st := P2Catalog.stats_with_relics({}, ["arc", "seal_slab", "absorb"])
	check(int(a.arc) == 0 and int(a.absorb) == 0 and int(st.str) == 3 and int(st.def) == 3, "봉인: 양옆 잠듦 · 힘·수비 +3 %s %s" % [str(a), str(st)])
	check(int(P2Catalog.stats_with_relics({}, ["mirror_slab", "whetstone"]).str) == 4, "능력치 유물도 단계만큼 (숫돌 2단계 = 힘 +4)")
	var mk := func(relics: Array, lv: Dictionary) -> P2Battle:
		var cards: Array[Card] = []
		for k in ["slash", "slash", "guard", "bash", "focus"]:
			cards.append(P2Catalog.build_card(k, "s%d_%s" % [cards.size(), k]))
		var rl: Array[String] = []
		rl.assign(relics)
		var bb := P2Battle.new({"enemies": ["breaker", "archer"], "offsets": [0, 0]}, cards, rl, 9, {"class_id": "warden", "crit_mode": "off", "prep_enabled": false, "relic_lv": lv})
		bb.start()
		return bb
	var slash_of := func(bb: P2Battle) -> Card:
		for c in bb.deck.draw_pile + bb.hand.cards:
			if P2Catalog.kind_of(c) == "slash":
				return c
		return null
	var dmg := func(bb: P2Battle, c: Card, t: int) -> int:
		var pv := bb.preview(c, t)
		return int(pv.monsters[t].hp_before) - int(pv.monsters[t].hp)
	await new_profile(346)
	var b: P2Battle = mk.call(["reserve_seal", "mirror_slab", "thorn"], {"reserve_seal": 2, "thorn": 0})
	b._set_mana(2)
	check(b.end_turn_seal_preview() == 8 and b.rl("thorn") == 0 and not b.relics.has("thorn") and b.relic_order.size() == 3, "전투: 비축 인장 2단계 = 방어 8 · 잠든 가시 버클은 꺼짐 (칸 순서는 셋 그대로)")
	var b2: P2Battle = mk.call(["glass_cannon"], {})
	var raw0: int = int(b2.intent(0)[0]) if not b2.intent(0).is_empty() else 0
	check(dmg.call(b2, slash_of.call(b2), 0) == 8 and int(b2.effective_intent(0)[0]) == ceili(b2.scaled(raw0) * 1.5), "유리 대포: 베기 5 → 8, 적 공격도 ×1.5 (%s)" % str(b2.effective_intent(0)))
	var b3: P2Battle = mk.call(["mad_drum", "arrow_quiver", "drum_echo"], {})
	var hp1: int = b3.monsters[0].hp
	b3._enemy_hit(0, 0, 3, "perfect", -1.0)
	b3._enemy_hit(1, 0, 3, "perfect", -1.0)
	b3._enemy_hit(1, 1, 3, "perfect", -1.0)
	check(b3.perfect_phase == 6, "광기의 북: 완벽 3번 = 6번으로 셈 (%d)" % b3.perfect_phase)
	var warden_hit := P2Catalog.WARDEN_PARRY_DAMAGE if b3.class_id == "warden" else 0
	check(b3.monsters[0].hp == hp1 - 1 - warden_hit and b3.quiver == 2, "되치는 북: 북 적(파괴자)에게 1 (+ 수호기사 완벽 막기 %d) · 화살 줍기: 사수 화살 2발 (%d)" % [warden_hit, b3.quiver])
	b3._start_turn()
	check(dmg.call(b3, slash_of.call(b3), 0) == 5 + 2, "화살 줍기: 다음 턴 첫 공격 +2")
	var b4: P2Battle = mk.call(["reverse_brush", "thorn_eater"], {})
	var sl: Card = slash_of.call(b4)
	b4.hand.cards = [sl]
	b4._set_mana(3)
	var ehp: int = b4.monsters[0].hp
	b4.strike_grade = "hit"
	b4.strike_reverse = true
	var blk0: int = b4._pending_defense
	check(b4.play_card(sl, 0) and b4.monsters[0].hp == ehp and b4._pending_defense == blk0 + 5, "거꾸로 붓: 베기를 거꾸로 = 방어 5 · 적 체력 그대로")
	b4.strike_reverse = false
	b4.strike_grade = ""
	var b5: P2Battle = mk.call(["thorn_eater"], {})
	var sl2: Card = slash_of.call(b5)
	b5.hand.cards = [sl2]
	b5._set_mana(3)
	b5.strike_grade = "hit"
	b5.strike_thorns = 2
	GameState.set_flag("player_hp", 20)
	var mhp: int = b5.monsters[0].hp
	b5.play_card(sl2, 0)
	check(mhp - b5.monsters[0].hp == 5 + 6 and int(GameState.get_flag("player_hp")) == 18, "가시 삼키기: 가시 2 → 피해 %d (5 + 6) · 체력 −2 (%d)" % [mhp - b5.monsters[0].hp, int(GameState.get_flag("player_hp"))])
	# 긋기 판: 거꾸로 · 가시
	var pts: Array[Vector2] = [Vector2(400, 300), Vector2(560, 260), Vector2(720, 300)]
	var pad := P2SlashPad.new()
	pad.setup(pts, 24.0, 2.0, true, false, {"reverse": true, "eat_thorns": true, "thorns": [Vector2(640, 280)]})
	get_tree().root.add_child(pad)
	await frames(2)
	var res := [{}]
	pad.finished.connect(func(r): res[0] = r)
	for q in [Vector2(760, 310), Vector2(720, 300), Vector2(640, 280), Vector2(560, 260), Vector2(480, 280), Vector2(400, 300), Vector2(360, 310)]:
		pad.add_point(q)
		await frames(1)
	pad.release()
	await frames(2)
	check(bool((res[0] as Dictionary).get("reversed", false)) and int((res[0] as Dictionary).get("thorns_eaten", 0)) == 1 and String((res[0] as Dictionary).get("grade", "")) in ["hit", "perfect"],
		"긋기 판: 마지막 점부터 = 거꾸로, 가시 삼킴 1, 끊기지 않음 %s" % str([(res[0] as Dictionary).get("reversed"), (res[0] as Dictionary).get("thorns_eaten"), (res[0] as Dictionary).get("grade")]))
	pad.queue_free()
	# 원정: 교체는 그 자리 · 다리 석판 최대 체력 · 배치 창 끌기 · 위 띠 단계 표
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	var mh0 := int(RunService.run.max_hp)
	check(await RunService._tx("fixture", func(_c, r, _f):
		r.relics = ["arc", "absorb", "thorn", "bandage", "blade_rhythm"]
		return true), "고정값: 유물 다섯")
	check(await RunService._tx("fixture", func(_c, r, _f):
		return RunService._apply_relic(r, "bridge_slab", "thorn", ["bridge_slab"], false)), "다리 석판으로 가시 버클 교체")
	check(str(RunService.run.relics) == str(["arc", "absorb", "bridge_slab", "bandage", "blade_rhythm"]) and int(RunService.run.max_hp) == mh0 - P2Catalog.BRIDGE_HP, "교체는 그 자리(3번 칸) · 최대 체력 −%d %s" % [P2Catalog.BRIDGE_HP, str(RunService.run.relics)])
	h.dungeon.refresh()
	h.show_relics()
	await secs(0.5)
	check(h.current_modal() == "relics" and (h._arr.slots as Array).size() == 5, "유물 창: 칸 다섯")
	await snap("slabs_01_arrange")
	var s0: Control = h._arr.slots[0]
	var s4: Control = h._arr.slots[4]
	await ptr_drag(s0.get_global_rect().get_center(), s4.get_global_rect().get_center())
	await secs(0.5)
	check(str(RunService.run.relics) == str(["blade_rhythm", "absorb", "bridge_slab", "bandage", "arc"]) and h.current_modal() == "relics" and int(h._arr.sel) == 4, "끌어서 1번 ↔ 5번 %s · 옮긴 유물을 고른 채" % str(RunService.run.relics))
	await snap("slabs_02_swapped")
	h.close_modal()
	h.dungeon.set_locked(false)
	var lvs := P2Catalog.relic_levels(RunService.run.relics)
	check(int(lvs.absorb) == 2 and int(lvs.bandage) == 2, "다리 석판 양옆(흡수 문장 · 전투 붕대) 2단계 %s" % str(lvs))
	h._on_engage("n1")
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	var marks := 0
	for slot in v._hud_relics.get_children():
		for ch in slot.get_children():
			if ch is Label and (ch as Label).text == "Ⅱ":
				marks += 1
	check(v.battle.rl("absorb") == 2 and marks == 2, "전투 위 띠: 2단계 표 %d개 · 흡수 문장 %d단계" % [marks, v.battle.rl("absorb")])
	await snap("slabs_03_hud")
	# 손맛 전투에서 거꾸로 붓: 푸른 고리(마지막 점)부터 거꾸로 그으면 방어, 적 체력 그대로
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h2 := await e7_start(347)
	var v2: P2BattleView = h2.battle_view
	Engine.time_scale = 1.0
	v2.battle.relics.append("reverse_brush")
	await av7_hand(v2, ["slash", "guard", "bash"])
	v2._build_hand(false)
	await secs(0.4)
	var e0: int = v2.battle.monsters[0].hp
	var bl0 := v2.battle.get_pending_defense()
	v2.play_card(av7_card(v2, "slash"), 0)
	var pad2 := await fe_pad(v2)
	await snap("slabs_04_reverse_pad")
	var rev: Array = (pad2.points as Array).duplicate()
	rev.reverse()
	await fe_drag(pad2, rev, 0.25)
	await fe_idle(v2)
	check(v2.battle.monsters[0].hp == e0 and v2.battle.get_pending_defense() > bl0 and bool(v2.slash_log.back().get("card", "") == "slash"), "거꾸로 그은 베기: 적 체력 그대로 · 방어 %d → %d" % [bl0, v2.battle.get_pending_defense()])
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 빌드 넓히기 카드 8장 · 유물 8개: 실제 전투 규칙으로 수치·조건을 보고, 손맛 전투에서 새 문양을 실제로 그려(치유의 문양은 주인공 위) 연출을 찍는다.
# 고정값(공개): 파괴자 둘 · 치명 끔, 그다음 새 프로필(시드 345) 첫 전투 N1 · 적 체력 200
func run_cards2() -> void:
	var kinds := ["shield_throw", "iron_beat", "volley", "weak_point", "mark_amp", "ember", "beat_slash", "heal_sigil", "guard", "slash", "bolt"]
	var mk := func(relics: Array, opts: Dictionary) -> P2Battle:
		var cards: Array[Card] = []
		for k in kinds:
			cards.append(P2Catalog.build_card(k, "t_" + k))
		var rl: Array[String] = []
		rl.assign(relics)
		var o := {"class_id": "warden", "crit_mode": "off", "prep_enabled": false}
		o.merge(opts, true)
		var bb := P2Battle.new({"enemies": ["breaker", "breaker"], "offsets": [0, 0]}, cards, rl, 7, o)
		bb.start()
		return bb
	var card_of := func(bb: P2Battle, k: String) -> Card:
		for c in bb.deck.draw_pile + bb.hand.cards + bb.deck.discard_pile:
			if P2Catalog.kind_of(c) == k:
				return c
		return null
	var hand := func(bb: P2Battle, ks: Array) -> void:
		var list: Array[Card] = []
		for k in ks:
			list.append(card_of.call(bb, k))
		bb.hand.cards = list
		bb._set_mana(bb.max_mana)
	var dmg := func(bb: P2Battle, c: Card, t: int) -> int:
		var pv := bb.preview(c, t)
		return int(pv.monsters[t].hp_before) - int(pv.monsters[t].hp)
	await new_profile(345)
	var b: P2Battle = mk.call([], {})
	b._pending_defense = 10
	check(dmg.call(b, card_of.call(b, "shield_throw"), 0) == 2 + 5, "방패 투척: 2 + 방어 10의 절반 = %d" % dmg.call(b, card_of.call(b, "shield_throw"), 0))
	b._pending_defense = 0
	b.perfect_phase = 3
	check(dmg.call(b, card_of.call(b, "beat_slash"), 0) == 3 + 6, "박자 베기: 완벽 3번 → 3 + 6 = %d" % dmg.call(b, card_of.call(b, "beat_slash"), 0))
	b.perfect_phase = 9
	check(dmg.call(b, card_of.call(b, "beat_slash"), 0) == 3 + 10, "박자 베기: 완벽 9번이어도 +10까지")
	b.perfect_phase = 3
	check(int(b.preview(card_of.call(b, "iron_beat"), -1).block) - b._pending_defense == 5 + 3, "철벽 박자: 방어 5 + 완벽 3")
	check(b.hits_now(card_of.call(b, "volley")) == 3 and dmg.call(b, card_of.call(b, "volley"), 0) == 6, "연발 사격: 기본 치명 10%% → 3발 = %d" % dmg.call(b, card_of.call(b, "volley"), 0))
	b.stats = {"crit": 20}
	check(b.hits_now(card_of.call(b, "volley")) == 5, "연발 사격: 치명 +20 → 5발")
	b.stats = {}
	hand.call(b, ["weak_point", "ember", "mark_amp", "heal_sigil"])
	var ex0: int = (b.deck as P4Deck).exhausted.size()
	check(b.play_card(card_of.call(b, "weak_point"), 0) and b.events.any(func(e): return String(e.kind) == "crit" and bool(e.forced)), "급소 노리기: 치명 끔이어도 확정 치명")
	check((b.deck as P4Deck).exhausted.size() == ex0 + 1, "급소 노리기: 소진 (%d → %d)" % [ex0, (b.deck as P4Deck).exhausted.size()])
	check(dmg.call(b, card_of.call(b, "ember"), 1) == 2 + 2 * (ex0 + 1), "잔불: 2 + 소진 %d장 × 2 = %d" % [ex0 + 1, dmg.call(b, card_of.call(b, "ember"), 1)])
	b._set_marks(1, 0)
	check(b.play_card(card_of.call(b, "mark_amp"), 1) and b.mark_count(1) == 2, "표식 증폭: 마법 타격 표식 1 → 두 배 %d" % b.mark_count(1))
	GameState.set_flag("player_hp", 10)
	b.strike_grade = "perfect"
	check(b.play_card(card_of.call(b, "heal_sigil"), -1) and int(GameState.get_flag("player_hp")) == 10 + 4 + 3, "치유의 문양: 완벽 → 체력 +7 (%d)" % int(GameState.get_flag("player_hp")))
	b.strike_grade = ""
	var stw := P2Catalog.stats_with_relics({"str": 1}, ["whetstone", "silver_quill", "red_sun"])
	check(int(stw.str) == 3 and int(stw.focus) == 10 and int(stw.cdmg) == 30, "능력치 유물: 숫돌 힘 +2 · 은빛 깃펜 집중 +10 · 붉은 태양 치명 피해 +30 %s" % str(stw))
	var b2: P2Battle = mk.call(["shield_spur", "ember_jar", "tuning_fork", "steady_brush"], {})
	hand.call(b2, ["guard", "iron_beat", "slash", "weak_point", "ember", "heal_sigil"])
	b2.play_card(card_of.call(b2, "guard"), -1)
	b2.play_card(card_of.call(b2, "iron_beat"), -1)
	check(b2.spur == 4 and dmg.call(b2, card_of.call(b2, "slash"), 0) == 5 + 4, "방패 박차: 방어 카드 둘 → 다음 물리 +4 (%d)" % dmg.call(b2, card_of.call(b2, "slash"), 0))
	b2.play_card(card_of.call(b2, "slash"), 0)
	check(b2.spur == 0, "방패 박차: 쓰면 0")
	var blk0 := b2._pending_defense
	b2._set_mana(b2.max_mana)
	b2.play_card(card_of.call(b2, "weak_point"), 0)
	b2.play_card(card_of.call(b2, "ember"), 0)
	b2._set_mana(b2.max_mana)
	b2.play_card(card_of.call(b2, "heal_sigil"), -1)
	check(b2._pending_defense == blk0 + 4 and b2.ember_jar_n == 2, "잿불 단지: 소진 셋 → 방어 +4까지 (%d → %d)" % [blk0, b2._pending_defense])
	b2.perfect_phase = 3
	b2._start_turn()
	for i in range(b2.monsters.size()):
		b2.monsters[i].hp = b2.monsters[i].max_hp
		b2._set_marks(i, 0)
	hand.call(b2, ["slash"])
	check(b2.fork_ready and dmg.call(b2, card_of.call(b2, "slash"), 0) == 5 + 4, "소리굽쇠: 완벽 3번 → 첫 공격 +4 (%s · %d)" % [str(b2.fork_ready), dmg.call(b2, card_of.call(b2, "slash"), 0)])
	b2.strike_grade = "perfect"
	b2.strike_power = 1.5
	check(is_equal_approx(b2._crit_mult_now(0), 1.7), "흔들림 없는 붓: 완벽 긋기 배율 1.5 → %.2f" % b2._crit_mult_now(0))
	b2.strike_grade = ""
	var b3: P2Battle = mk.call(["combo_glove"], {"class_id": "combo"})
	b3.perfect_phase = 0
	b3._start_turn()
	check(b3.combo == 1, "연격 장갑: 턴 시작 연격 1 (%d)" % b3.combo)
	var warden_glove := false
	var combo_glove := false
	for sd in range(1, 80):
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		if RunModel.relic_offer(rng, {"relics": [], "deck": [], "class_id": "warden"}, false).has("combo_glove"):
			warden_glove = true
		rng.seed = sd
		if RunModel.relic_offer(rng, {"relics": [], "deck": [], "class_id": "combo"}, false).has("combo_glove"):
			combo_glove = true
	check(not warden_glove and combo_glove, "연격 장갑은 콤보술사에게만 후보")
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	var h := await e7_start(345)
	var v: P2BattleView = h.battle_view
	var vb := v.battle
	Engine.time_scale = 1.0
	av1_tough(v, 200)
	var list: Array[Card] = []
	for k in ["heal_sigil", "shield_throw", "volley", "weak_point", "mark_amp", "ember", "beat_slash"]:
		list.append(P2Catalog.build_card(k, "f_" + k))
	vb.hand.cards = list.duplicate()
	v._build_hand(false)
	await secs(0.5)
	GameState.set_flag("player_hp", 20)
	vb._set_mana(vb.max_mana)
	v._sync_shown_from_battle()
	v._render_all()
	v._refresh_card_states()
	v.skill_log.clear()
	v.play_card(list[0], -1)
	var pad := await fe_pad(v)
	var near := pad != null and (pad.points as Array).all(func(q): return (q as Vector2).x < 640.0)
	await snap("cards2_01_heart")
	await fe_glyph(pad, 0.5)
	await fe_idle(v)
	await secs(0.3)
	check(near and int(GameState.get_flag("player_hp")) >= 24 and v.skill_log.any(func(e): return String(e.fx) == "heal"), "치유의 문양: 주인공 위 하트 %s → 체력 %d" % [str(near), int(GameState.get_flag("player_hp"))])
	var shots := {"shield_throw": "shock", "volley": "needle", "weak_point": "target", "mark_amp": "sigil", "ember": "flame", "beat_slash": "notes"}
	var bit_want := {"shield_throw": "chunk", "volley": "shard", "weak_point": "shard", "mark_amp": "rune", "ember": "ember", "beat_slash": "note"}
	var bits_now := func() -> Array:
		return v._fxp.get_children().filter(func(c): return c is P2HitBits)
	var n := 2
	for k in shots:
		var card: Card = null
		for c in vb.hand.cards:
			if P2Catalog.kind_of(c) == k:
				card = c
		if card == null:
			check(false, "%s 손패에 없음" % k)
			continue
		vb._set_mana(vb.max_mana)
		v._render_all()
		v._refresh_card_states()
		v.skill_log.clear()
		v.play_card(card, fe_target(vb))
		pad = await fe_pad(v)
		if n == 2:
			await snap("cards2_02_glyph_%s" % k)
		await fe_glyph(pad, 0.4)
		var fxk := String(shots[k])
		if await wait_until(func(): return v.skill_log.any(func(e): return String(e.fx) == fxk), 4.0):
			await frames(3)
			await snap("cards2_%02d_%s" % [n + 1, k])
		var bshape := ""
		var bcount := 0
		if await wait_until(func(): return not bits_now.call().is_empty(), 3.0):
			var bb: P2HitBits = bits_now.call()[0]
			bshape = bb.shape
			bcount = bb._p.size()
			await frames(5)
			await snap("cards2_bits_%s" % k)
		await fe_idle(v)
		check(v.skill_log.any(func(e): return String(e.fx) == fxk), "%s: %s 연출" % [k, fxk])
		check(bshape == String(bit_want[k]) and bcount >= 10, "%s: 맞는 순간 조각 %s %d개 (기대 %s)" % [k, bshape, bcount, String(bit_want[k])])
		n += 1
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 사건(지도 ? 칸): 시드마다 다르고 한 원정 세 구간은 서로 다름. 여섯 사건의 선택지를 하나씩 실제로 고른다.
# 고정값(공개): 새 프로필(시드 344), 사건마다 선택 초기화 · 체력 30/40 · 미확정 금화 5
func run_events() -> void:
	var seen := {}
	var distinct := true
	for sd in range(1, 41):
		var r := {"seed": sd, "layout": {"encounters": {"elite": {}}}}
		var evs: Array = []
		for sec in ["normal", "hard", "extreme"]:
			r.sector = sec
			evs.append(RunModel.event_of(r))
			seen[evs.back()] = true
		if evs[0] == evs[1] or evs[1] == evs[2] or evs[0] == evs[2]:
			distinct = false
	check(seen.size() == P2Catalog.EVENT_ORDER.size() and distinct, "시드 40개: 사건 %d종 · 한 원정 세 구간은 서로 다름 %s" % [seen.size(), str(distinct)])
	check(RunModel.event_of({"seed": 7, "sector": "normal", "layout": {"encounters": {}}}) != "challenge" and RunModel.event_of({"seed": 7, "sector": "hard", "layout": {"encounters": {}}}) != "challenge", "선택 전투가 없으면 도전장 안 나옴")
	await new_profile(344)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	var reset := func() -> void:
		await RunService._tx("fixture", func(_c, r, _f):
			r.choice = {"picked": ""}
			r.hp = 30
			r.max_hp = 40
			r.gold = 5
			return true)
		h.dungeon.refresh()
	var open := func(ev: String) -> void:
		RunModel.event_force = ev
		await reset.call()
		h.show_choice()
		await secs(0.5)
	# 보급품: 물약 상자
	await open.call("supply")
	check(h.current_modal() == "choice" and h._tiles.size() == 2, "보급품: 선택지 둘")
	await snap("event_supply")
	var pot0 := (RunService.run.potions as Array).size()
	await h._choose_event("chest_potion", {})
	check((RunService.run.potions as Array).size() == pot0 + 1 and String(RunService.run.choice.picked) == "chest_potion" and h.current_modal() == "", "물약 상자: 회복약 +1 · 한 번")
	check(RunService.choice_block("chest_gold") != "", "고른 뒤 다른 선택지는 막힘")
	# 대장간: 금화로 강화
	await open.call("forge")
	await snap("event_forge")
	var copies := RunModel.upgradable_copies(RunService.run.deck)
	var uid := String(copies.keys()[0])
	var up := String(copies[uid][0])
	await h._choose_event("forge_gold", {"upgrade": up, "copy": uid})
	var got := (RunService.run.deck as Array).filter(func(c): return String(c.uid) == uid and String(c.upgrade) == up).size()
	check(int(RunService.run.gold) == 5 - P2Catalog.FORGE_GOLD and got == 1, "대장장이: 금화 −%d · 사본 %s 강화 %s" % [P2Catalog.FORGE_GOLD, uid, up])
	# 도전장: 찢기
	await open.call("challenge")
	await snap("event_challenge")
	await h._choose_event("tear", {})
	check(int(RunService.run.gold) == 5 + P2Catalog.TEAR_GOLD, "도전장 찢기: 금화 +%d" % P2Catalog.TEAR_GOLD)
	# 제단: 피를 바쳐 유물 (건너뛰기 없음)
	await open.call("altar")
	await snap("event_altar")
	var rel0 := (RunService.run.relics as Array).size()
	await h._choose_event("altar_relic", {})
	await secs(0.5)
	var part := RunService.current_part()
	check(int(RunService.run.max_hp) == 40 - P2Catalog.ALTAR_MAXHP and h.current_modal() == "reward" and String(part.get("type", "")) == "relic" and h._skip_button == null,
		"제단: 최대 체력 −%d → 유물 보상 창, 건너뛰기 없음" % P2Catalog.ALTAR_MAXHP)
	check(not RunService.choose_reward({"skip": true}), "필수 유물은 건너뛰기 거절")
	await snap("event_altar_reward")
	await h.confirm_reward({"relic": String(part.relics[0])})
	await secs(0.4)
	check((RunService.run.relics as Array).size() == rel0 + 1 and String(RunService.run.phase) == "explore", "유물 하나 받고 탐험으로")
	# 서고: 태우기 · 필사
	await open.call("library")
	await snap("event_library")
	var deck0 := (RunService.run.deck as Array).size()
	await h._choose_event("burn_card", {"copy": String(RunService.run.deck[0].uid)})
	check((RunService.run.deck as Array).size() == deck0 - 1, "버릇 태우기: 덱 %d → %d" % [deck0, (RunService.run.deck as Array).size()])
	await open.call("library")
	await h._choose_event("copy_card", {})
	await secs(0.5)
	check(h.current_modal() == "reward" and String(RunService.current_part().get("type", "")) == "card", "기술 필사: 카드 보상 창")
	await h.confirm_reward({"skip": true})
	await secs(0.4)
	# 메아리: 능력치 한 번 더
	await open.call("echo")
	await snap("event_echo")
	var pend0 := RunService.stat_pending()
	await h._choose_event("echo_stat", {})
	await secs(0.5)
	check(int(RunService.run.hp) == 30 - P2Catalog.ECHO_HP and RunService.stat_pending() == pend0 + 1 and h.current_modal() == "level", "몸을 맡기기: 체력 −%d · 능력치 고르기 창" % P2Catalog.ECHO_HP)
	await h.confirm_level(String(RunService.run.lv_picks[0][0].stat))
	await secs(0.9)
	RunModel.event_force = ""
	await flush_snaps()


# 유물 끼우기: 보상 후보를 끌어 빈 유물 칸에 놓으면 그 칸에 미리 끼워지고(확정 전), 다른 후보를 같은 칸에 놓으면 바뀜.
# 칸 밖에 놓으면 돌아감. 누르기만 해도 빈 칸으로 날아 들어감. 고정값(공개): 새 프로필(시드 342), 유물 1개, N1·N2 처치 → N3 보상
func run_relic_drag() -> void:
	await new_profile(342)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	check(fixture(func(_c, r, _f):
		r.defeated.append_array(["n1", "n2"])
		r.relics = ["arc"]), "고정값: N1·N2 처치 · 유물 1개")
	h.dungeon.refresh()
	h._on_engage("n3")
	check(await h.engage_confirm("n3"), "N3 전투")
	check(await battle_ready(h), "N3 차례")
	for m in h.battle_view.battle.monsters:
		m.hp = 1
	await finish_battle(h)
	check(await wait_until(func(): return h.current_modal() == "reward", 20.0), "N3 보상")
	await secs(0.3)
	for _k in range(3):
		if String(RunService.current_part().get("type", "")) == "relic":
			break
		await ptr_click(h.reward_skip_rect().get_center())
		await ptr_click(h.reward_confirm_rect().get_center())
		await secs(0.5)
	check(String(RunService.current_part().get("type", "")) == "relic", "유물 부분")
	await secs(0.4)
	var cands: Array = h.reward_tiles()
	var slots: Array = h._relic.slots
	var empty: Control = null
	for sl in slots:
		if String(sl.held) == "":
			empty = sl.node
			break
	check(cands.size() >= 2 and empty != null, "후보 %d개 · 빈 칸 있음" % cands.size())
	await snap("relic_01_before")
	var c0: Control = cands[0]
	ptr_move(c0.get_global_rect().get_center())
	await frames(2)
	ptr_button(c0.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, true)
	await frames(1)
	var to := empty.get_global_rect().get_center()
	for k in range(1, 9):
		ptr_move(c0.get_global_rect().get_center().lerp(to, k / 8.0), MOUSE_BUTTON_MASK_LEFT)
		await frames(1)
	await frames(4)
	var live := bool(h._relic_drag.get("live", false))
	await snap("relic_02_drag")
	ptr_button(to, MOUSE_BUTTON_LEFT, false)
	await secs(0.3)
	var id0 := String(c0.get_meta("id"))
	var pend: Control = h._relic.get("pending")
	check(live and String(h._sel.get("relic", "")) == id0 and pend != null and is_instance_valid(pend) and pend.get_parent() == empty and not (h.reward_confirm() as Button).disabled,
		"끌어 놓기: 끄는 중 %s · 고름 %s · 빈 칸에 미리 끼움 · 확정 가능" % [str(live), String(h._sel.get("relic", ""))])
	await snap("relic_03_dropped")
	var c1: Control = cands[1]
	await ptr_drag(c1.get_global_rect().get_center(), Vector2(640, 90))
	await secs(0.3)
	check(String(h._sel.get("relic", "")) == id0 and is_instance_valid(pend), "칸 밖에 놓으면 그대로 (%s)" % String(h._sel.get("relic", "")))
	await ptr_drag(c1.get_global_rect().get_center(), to)
	await secs(0.3)
	var id1 := String(c1.get_meta("id"))
	var pend2: Control = h._relic.get("pending")
	check(String(h._sel.get("relic", "")) == id1 and pend2 != null and is_instance_valid(pend2) and not is_instance_valid(pend), "같은 칸에 다른 후보 → 바뀜 (%s)" % id1)
	await ptr_click(h.reward_confirm_rect().get_center())
	check(await wait_until(func(): return h.current_modal() != "reward" or String(RunService.current_part().get("type", "")) != "relic", 10.0), "확정")
	check((RunService.run.relics as Array).has(id1) and not (RunService.run.relics as Array).has(id0), "받은 유물 %s" % str(RunService.run.relics))
	await flush_snaps()


# 직업 고르기 무대: 바꾸면 빛 기둥이 미끄러지고 고른 인물이 깡충, 설명 카드가 밀려 들어옴, 이름 아래 직업 문장, 성장 경향
func run_prep_juice() -> void:
	await new_profile(343)
	var pp := P5PrepPanel.open_in(get_tree())
	await secs(0.8)
	await snap("prep_01")
	var order: Array = P2Catalog.CLASS_ORDER
	var cur := String(GameState.combat.get("class_id", "warden"))
	var nxt := String(order[(order.find(cur) + 1) % order.size()])
	await pp._set_class(nxt)
	await frames(2)
	var hop := pp._hop_t >= 0.0
	var lx := pp._light_x
	await snap("prep_02_switch")
	await secs(0.6)
	check(hop and absf(pp._light_x - pp._slot_x(order.find(nxt))) < 1.0 and lx != pp._light_x, "바꾸기: 깡충 %s · 빛 %.0f → %.0f" % [str(hop), lx, pp._light_x])
	var fig: TextureRect = pp._figs[nxt]
	check(absf(fig.position.y - float(fig.get_meta("base_y"))) < 0.5 and fig.modulate == Color.WHITE, "깡충 끝나면 제자리 · 밝기")
	await snap("prep_03_settled")
	pp.queue_free()
	await flush_snaps()


# 준비 창에 지금 떠 있는 난이도 카드(열림 여부)·모드 칸·직업 무대 자리
func prep_tiles(panel: P5PrepPanel) -> Dictionary:
	var tiles := {}
	var stack: Array = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n.is_queued_for_deletion():
			continue
		stack.append_array(n.get_children())
		if n is Button and (n as Button).has_meta("diff"):
			tiles[String(n.get_meta("diff"))] = not (n as Button).disabled
		if n is Button and (n as Button).has_meta("mod"):
			tiles["mod:" + String(n.get_meta("mod"))] = true
		if n is Button and (n as Button).has_meta("class"):
			tiles["class:" + String(n.get_meta("class"))] = n
		if n is Button and (n as Button).has_meta("step"):
			tiles["step:%d" % int(n.get_meta("step"))] = n
	return tiles


# 준비 창 단계: 직업(무대·좌우 키) → 난이도(잠긴 카드) → 출발(모드·요약) · Esc 앞 단계 · 단계 칸 바로 가기 · 출발.
# 고정값(공개): 새 프로필(시드 301), 노멀만 정복 안 함(처음 상태). 입력은 스크립트(키 이벤트·단추 신호)
func run_prep() -> void:
	await new_profile(301)
	check(await RunService.commit_profile("prep fixture", func(c, _r, _f):
		c.combat["class_id"] = "warden"
		c.combat["mods_pick"] = []
		c.combat["diff_pick"] = "normal"
		return true), "고정값: 수호기사 · 노멀 · 모드 없음")
	var panel := P5PrepPanel.open_in(get_tree())
	await secs(0.7)
	var t := prep_tiles(panel)
	check(panel.step == 0 and t.has("class:warden") and t.has("class:hunter") and t.has("class:rune_caster") and t.has("step:2") and not t.has("step:3") and not t.has("easy"),
		"처음엔 1단계(직업 무대)만, 단계는 셋, 난이도 칸은 아직 없음")
	check(panel._figs.size() == P2Catalog.CLASS_ORDER.size() and String(panel._anim.id) == "warden", "무대: 직업 수만큼 인물, 고른 수호기사만 대기 그림이 돈다")
	await snap("prep_01_class")
	await key_tap(KEY_RIGHT)
	await secs(0.5)
	check(String(GameState.combat.class_id) == "hunter" and panel.step == 0, "→ 키 = 다음 직업 (사냥꾼)")
	(prep_tiles(panel)["class:rune_caster"] as Button).pressed.emit()
	await secs(0.5)
	check(String(GameState.combat.class_id) == "rune_caster" and String(panel._anim.id) == "rune_caster", "무대 인물 누르기 = 그 직업 (룬술사)")
	await snap("prep_01b_class_rune")
	panel._next.pressed.emit()
	await secs(0.4)
	check(panel.step == 1, "다음 → 2단계 난이도")
	t = prep_tiles(panel)
	check(bool(t.get("normal", false)) and t.has("extreme") and not bool(t.extreme) and not bool(t.get("hard", true)), "처음엔 하드·익스트림 잠김")
	await key_tap(KEY_LEFT)
	await secs(0.5)
	check(String(GameState.combat.diff_pick) == "easy", "← 키 = 이지")
	await snap("prep_02_diff")
	await key_tap(KEY_ENTER)
	await secs(0.4)
	t = prep_tiles(panel)
	check(panel.step == 2 and t.has("mod:hd") and panel._next.text == "출발" and not panel._next.disabled, "Enter → 3단계 출발: 모드 칸 · 출발 단추")
	for n in panel._body.get_children():
		if n is Button and String(n.get_meta("mod", "")) == "hd":
			(n as Button).pressed.emit()
	await secs(0.5)
	check((GameState.combat.mods_pick as Array) == ["hd"], "모드 HD 켬")
	await snap("prep_03_go")
	await key_tap(KEY_ESCAPE)
	await secs(0.4)
	check(panel.step == 1 and is_instance_valid(panel), "Esc = 앞 단계 (창은 그대로)")
	(prep_tiles(panel)["step:0"] as Button).pressed.emit()
	await secs(0.4)
	check(panel.step == 0, "단계 칸 1 → 바로 직업")
	panel.go(2)
	await secs(0.3)
	panel._next.pressed.emit()
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "출발 → 원정")
	var run := RunService.run
	check(String(run.class_id) == "rune_caster" and String(run.diff) == "easy" and (run.mods as Array) == ["hd"], "원정: 룬술사 · 이지 · HD (%s %s %s)" % [run.class_id, run.diff, str(run.mods)])
	await secs(0.6)
	await flush_snaps()


# 원정 난이도·모드·점수: 여는 규칙 · 배지 · 점수 랭크 · 준비 창 칸 · 하드+히든+미러 원정(적 체력·공격 +15% · 판정 −15% · 노트 빠르게 · 노트 하나 더 · 금화 +20%)
func run_diff() -> void:
	var c0 := {"combat": {}}
	check(P2Catalog.diff_unlocked({}, "easy") and P2Catalog.diff_unlocked({}, "normal") and not P2Catalog.diff_unlocked({}, "hard") and not P2Catalog.diff_unlocked({}, "extreme"),
		"처음엔 이지·노멀만 열림")
	var res := RunModel.diff_clear(c0, {"diff": "normal"})
	var res2 := RunModel.diff_clear(c0, {"diff": "normal"})
	check(String(res.badge) == "normal" and String(res.opened) == "hard" and String(res2.badge) == "" and P2Catalog.diff_unlocked(c0.combat.diff_clear, "hard") and not P2Catalog.diff_unlocked(c0.combat.diff_clear, "extreme"),
		"노멀 정복 → 노멀 배지 · 하드 열림, 다시 깨면 배지 없음")
	var ce := {"combat": {}}
	check(String(RunModel.diff_clear(ce, {"diff": "easy"}).opened) == "" and not P2Catalog.diff_unlocked(ce.combat.diff_clear, "hard"), "이지를 깨도 하드는 안 열림")
	check(RunModel.boss_key("boss", "normal") == "boss" and RunModel.boss_key("boss", "hard") == "boss@hard", "보스 기록은 난이도마다 따로")
	var sc_s := RunModel.run_score({"diff": "hard", "mods": ["hd"], "hp": 30, "banked": {"normal": {}, "hard": {}, "extreme": {}}, "rhythm": [{"acc": 97, "best": 40}, {"acc": 95, "best": 22}]}, "clear")
	var sc_d := RunModel.run_score({"diff": "normal", "mods": [], "hp": 0, "banked": {}, "rhythm": [{"acc": 60, "best": 5}]}, "lost")
	check(String(sc_s.rank) == "S" and String(sc_d.rank) == "D" and int(sc_s.score) > int(sc_d.score), "점수·랭크: 하드 정복 정확도 96 = S %d · 구간 I에서 쓰러짐 = D %d" % [int(sc_s.score), int(sc_d.score)])
	await new_profile(297)
	check(await RunService.commit_profile("difficulty fixture", func(c, _r, _f):
		c.combat["diff_clear"] = {"normal": true}
		c.combat["diff_pick"] = "hard"
		c.combat["mods_pick"] = ["hd", "mr"]
		return true), "고정값: 노멀 정복(하드 열림) · 하드 고름 · 히든·미러 켬")
	var panel := P5PrepPanel.open_in(get_tree())
	await secs(0.6)
	panel.go(1)
	await secs(0.3)
	var tiles := prep_tiles(panel)
	await snap("diff_01_prep")
	panel.go(2)
	await secs(0.3)
	tiles.merge(prep_tiles(panel))
	check(bool(tiles.get("easy", false)) and bool(tiles.get("normal", false)) and bool(tiles.get("hard", false)) and tiles.has("extreme") and not bool(tiles.extreme) and tiles.has("mod:dt"),
		"준비 창: 이지·노멀·하드 열림, 익스트림 잠김, 모드 넷 %s" % str(tiles))
	panel.close()
	await secs(0.3)
	check(Flow.start_expedition(), "원정 출발")
	check(await wait_until(func(): return host() != null and host().dungeon != null, 30.0), "원정 화면")
	var h := host()
	await secs(0.6)
	h.dismiss_notices()
	var run := RunService.run
	check(String(run.diff) == "hard" and (run.mods as Array).has("hd") and (run.mods as Array).has("mr") and RunModel.mod_gold(run, 10) == 12, "하드 + 히든·미러 원정 · 금화 10 → 12")
	await snap("diff_02_map")
	h._on_engage("n1")
	await secs(0.4)
	await snap("diff_03_engage")
	P2BattleView.feel_force = {"parry": true, "slash": true, "juice": true}
	_fe_skill = {"perfect": 1.0, "good": 0.0}
	_fe_auto = true
	fe_autoloop()
	check(await h.engage_confirm("n1"), "N1 전투")
	check(await battle_ready(h), "차례")
	var v: P2BattleView = h.battle_view
	var b := v.battle
	check(b.monsters[0].max_hp == roundi(14 * 1.15 * float(P2Catalog.DIFF.hard.rank_hp.normal)) and absf(b.hit_mult - 1.15) < 0.001 and b.scaled(5) == 6 and absf(b.judge_mult - 0.85) < 0.001 and b.pattern_level == 1,
		"하드 전투: 척후병 체력 %d · 공격 5 → %d · 판정 ×%.2f · 패턴 +%d" % [b.monsters[0].max_hp, b.scaled(5), b.judge_mult, b.pattern_level])
	v.end_turn()
	var chart: P2NoteChart = null
	var deadline := Time.get_ticks_msec() + 20000
	while chart == null and Time.get_ticks_msec() < deadline:
		for c in v._ui.get_children():
			if c is P2NoteChart and c.has_meta("enemy"):
				chart = c
		await get_tree().process_frame
	await secs(0.25)
	await snap("diff_04_hidden_chart")
	var pat := v._parry_pattern(0, [5])
	check(chart != null and absf(chart.perfect_early - P2NoteChart.PERFECT[0] * 0.85) < 0.0005 and absf(chart.good_early - P2NoteChart.GOOD_EARLY * 0.85) < 0.0005 and chart.hidden_mod,
		"악보: 판정 창 −15%% (완벽 %.4f · 막음 %.3f) · 히든 켜짐" % [chart.perfect_early if chart != null else -1.0, chart.good_early if chart != null else -1.0])
	check((pat[0].kinds as Array).size() >= 2, "하드 패턴: 노트 하나 더 %s" % str(pat[0].kinds))
	await wait_until(func(): return v.current_state() == "PLAYER" and b.turn_number > 1, 30.0)
	_fe_auto = false
	P2BattleView.feel_force = CLASSIC
	await flush_snaps()


# 설정 저장 안전: 파일을 못 읽는 순간(다른 프로그램이 잡고 있음 · 깨짐)에 저장해도 다른 설정(언어·판정 보정)을 지우지 않고,
# 바꾼 값은 이번 실행 동안 유지했다가 다시 읽힐 때 함께 기록한다
func run_settings() -> void:
	var path := P2Ui.SETTINGS
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "language", "ko")
	cfg.set_value("rhythm", "offset_ms", 17)
	cfg.set_value("audio", "volume", 80.0)
	cfg.save(path)
	P2Ui._set_mem.clear()
	P2Ui._set_dirty.clear()
	check(int(P2Ui.load_rhythm().offset_ms) == 17, "파일의 판정 보정 17ms를 읽음")
	# 바꾼 값은 파일 상태와 상관없이 이번 실행 동안 유지
	P2Ui.save_settings({"reduce_motion": false, "battle_fx": true, "volume": 50.0})
	var mid := ConfigFile.new()
	check(mid.load(path) == OK and String(mid.get_value("locale", "language", "")) == "ko" and int(mid.get_value("rhythm", "offset_ms", 0)) == 17
		and absf(float(mid.get_value("audio", "volume", 0.0)) - 50.0) < 0.01, "저장: 바꾼 칸(음량 50)만 얹고 언어·판정 보정은 그대로")
	# 내용이 깨진 파일: .bad로 남기고 이번 실행이 아는 값으로 새로 씀
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("[[[ 깨진 설정")
	bad.close()
	P2Ui.save_rhythm({"approach": 1.2})
	var after := ConfigFile.new()
	check(FileAccess.file_exists(path + ".bad") and after.load(path) == OK and int(after.get_value("rhythm", "offset_ms", 0)) == 17
		and absf(float(after.get_value("audio", "volume", 0.0)) - 50.0) < 0.01 and absf(float(after.get_value("rhythm", "approach", 0.0)) - 1.2) < 0.01,
		"깨진 설정 파일: .bad로 남기고 보정 17 · 음량 50 · 노트 속도 1.2로 새로 씀")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bad"))
	P2Ui.save_rhythm({"offset_ms": 0, "approach": 1.0})
	P2Ui.save_settings({"reduce_motion": false, "battle_fx": true, "volume": 80.0})
