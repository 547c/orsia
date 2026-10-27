extends Node2D
# 원정 화면: 두 흐름을 한 화면 관리자가 맡는다.
#   field      — 연습 한 판: 전투 → 결과 → 메인 메뉴
#   expedition — 원정: 지도 → 전투 → 보상 → … → 구간 보스 → [마치기 | 계속] → 결과 → 메인 메뉴
# 상태는 RunService(원정 · 연습)와 GameState/SaveManager(프로필)에 있고, 이 노드는 화면 전환과 창만 맡는다.
# 저장이 실패하면 저장 창(SaveGate)이 뜨고 다시 저장이 성공해야 이어진다. 앱을 다시 켜면 저장된 단계에서 이어간다.

const FADE := 0.22
const DIVE := 0.34
const DESIGN_SIZE := Vector2i(1280, 720)

var model: RunModel
var mode := "expedition"
var dungeon: P2MapView
var battle_view: P2BattleView
var gate: P2Ui.SaveGate
var settings := {}
var _layer: CanvasLayer
var _overlay: Control
var _fade: ColorRect
var _fade_mat: ShaderMaterial
var _fade_p := 0.0
var _sel := {}
var _modal := ""
var _level_board: P5StatBoard
var _prev_size := Vector2i.ZERO
var _prev_aspect := 0
var _prev_window := Vector2i.ZERO
var _leaving := false
var _tiles: Array = []
var _replace_tiles: Array = []
var _relic := {}
var _relic_drag := {}
var _arr := {}
var _arr_drag := {}
var _skip_button: Button
var _confirm_button: Button
var _peek: Control


func _ready() -> void:
	add_to_group("run_host")
	var root := get_tree().root
	_prev_size = root.content_scale_size
	_prev_aspect = root.content_scale_aspect
	root.content_scale_size = DESIGN_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_fit_window()
	root.size_changed.connect(_on_window_resized)
	_on_window_resized()
	settings = P2Ui.load_settings()
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_overlay)
	var fl := CanvasLayer.new()
	fl.layer = 60
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_mat = ShaderMaterial.new()
	_fade_mat.shader = load("res://p2/p2_dissolve.gdshader")
	_fade.material = _fade_mat
	fl.add_child(_fade)
	model = RunService
	gate = RunService.gate
	model.save_failed.connect(_on_save_failed)
	var req: Dictionary = Flow.host_request
	mode = String(req.get("mode", "expedition"))
	await get_tree().process_frame
	await resume(bool(req.get("resumed", false)))


func _exit_tree() -> void:
	P2Catalog.view_stats = {}
	var root := get_tree().root
	if _prev_size != Vector2i.ZERO:
		root.content_scale_size = _prev_size
		root.content_scale_aspect = _prev_aspect
	if root.size_changed.is_connected(_on_window_resized):
		root.size_changed.disconnect(_on_window_resized)
	if _prev_window != Vector2i.ZERO and root.mode == Window.MODE_WINDOWED and root.size == DESIGN_SIZE:
		root.size = _prev_window
	P2Ui.fit_fonts_to_scale(1.0)


# 기본 창(1152×648)에서는 1280×720 화면이 0.9배로 줄어 AA를 끈 픽셀 글자의 획이 빠진다(한글이 깨져 보임).
# 창 모드이고 화면이 넉넉하면 이 호스트 동안만 창을 1280×720으로 키우고, 나갈 때 원래 크기로 되돌린다
func _fit_window() -> void:
	var win := get_tree().root
	if win.mode != Window.MODE_WINDOWED or (win.size.x >= DESIGN_SIZE.x and win.size.y >= DESIGN_SIZE.y):
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	if usable.size.x < DESIGN_SIZE.x or usable.size.y < DESIGN_SIZE.y + 32:
		return
	_prev_window = win.size
	win.size = DESIGN_SIZE
	win.position = usable.position + (usable.size - DESIGN_SIZE) / 2


func _on_window_resized() -> void:
	var sz := get_tree().root.size
	P2Ui.fit_fonts_to_scale(minf(sz.x / float(DESIGN_SIZE.x), sz.y / float(DESIGN_SIZE.y)))


func _on_save_failed(_reason: String) -> void:
	if dungeon != null and is_instance_valid(dungeon):
		dungeon.set_locked(true)
	await gate.run()
	if dungeon != null and is_instance_valid(dungeon) and not model.run.is_empty():
		dungeon.refresh()
		if _modal == "" and battle_view == null:
			dungeon.set_locked(false)


func _saved(ok: bool) -> bool:
	if ok:
		return true
	if model.has_pending():
		return await gate.run()
	return false


# 저장된 단계로 들어간다
func resume(resumed: bool) -> void:
	if model.has_pending():
		await gate.run()
	if mode == "field":
		var b := model.battle if model.battle != null and not resumed else model.restore_battle()
		if b == null:
			_leave("field_retreat")
			return
		await show_battle(b, resumed)
		return
	if model.run.is_empty():
		_leave("expedition")
		return
	show_dungeon()
	match String(model.run.phase):
		"battle":
			var b := model.restore_battle()
			await show_battle(b, true)
		"reward":
			show_reward()
		"sector_choice":
			show_sector_choice()
		"portal":
			dungeon.show_message("기록이 남았습니다. 보스의 방에 열린 포탈(◎)로 나가면 결과를 봅니다.")
		_:
			if not resumed:
				_notice("원정 시작", "%s 입장 — 필수 전투를 이기며 나아가고, 구간 보스를 이기면 그 구간 기록이 남습니다.\n상인(상)과 선택 지점(?)은 지도에 표시됩니다. 선택 전투(★ 또는 ?!)는 건너뛰어도 됩니다." % P2Catalog.SECTOR_NAMES[String(model.run.sector)])


# 전환: 점 무늬 검은 막이 가장자리부터 at 쪽으로 덮이고(나갈 때), at부터 열린다(들어올 때)
func _fade_out(at := Vector2(640, 360), dur := FADE) -> void:
	await _fade_to(1.0, at, dur)


func _fade_in(at := Vector2(640, 360), dur := FADE) -> void:
	await _fade_to(0.0, at, dur)


func _fade_to(p: float, at: Vector2, dur: float) -> void:
	_fade_mat.set_shader_parameter("center", at)
	var t := create_tween()
	t.tween_method(_set_fade, _fade_p, p, dur)
	await t.finished


func _set_fade(p: float) -> void:
	_fade_p = p
	_fade_mat.set_shader_parameter("progress", p)


func _clear_views() -> void:
	for v in [dungeon, battle_view]:
		if v != null and is_instance_valid(v):
			v.queue_free()
	dungeon = null
	battle_view = null
	close_modal()


func show_dungeon() -> void:
	_clear_views()
	dungeon = P2MapView.new()
	add_child(dungeon)
	dungeon.setup(model)
	dungeon.engage_requested.connect(_on_engage)
	dungeon.portal_requested.connect(_on_portal)
	dungeon.menu_requested.connect(_dungeon_menu)
	dungeon.deck_requested.connect(_deck_view)
	dungeon.route_requested.connect(_on_route)
	dungeon.service_requested.connect(show_service)
	dungeon.choice_requested.connect(show_choice)
	dungeon.relics_requested.connect(func() -> void: show_relics())
	dungeon.level_requested.connect(func() -> void:
		if model.stat_pending() > 0:
			show_level()
		else:
			show_stats())
	_sync_view_stats()


func _sync_view_stats() -> void:
	P2Catalog.view_stats = P2Catalog.stats_with_relics(model.run.get("stats", {}), model.run.get("relics", [])) if not model.run.is_empty() else {}


# ── 교전 확인 (미믹은 조사 창) ─────────────────────────────────────────────────

func _enc_tag(id: String) -> String:
	var e: Dictionary = model.run.layout.encounters[id]
	match id:
		"elite":
			var risk := " · 위험 강화됨: 적 공격 타격마다 +%d, 보상에 유물 보장" % P2Catalog.RISK_ATTACK if bool(e.get("risk", false)) else ""
			if String(e.get("kind", "")) == "mimic":
				return "수상한 상자를 살펴봤다 — 뚜껑이 들썩이고 이빨 자국이 있다. 미믹입니다 (선택 전투, 지나쳐도 됩니다)%s" % risk
			return "선택 정예 — 건너뛰어도 됩니다%s" % risk
		"boss", "hboss":
			return "구간 보스 — 이기면 이번 구간 금화가 확정되고, 여기서 마칠지 더 깊이 갈지 고릅니다"
		"xboss":
			return "최종 보스 — 이기면 최종 정산 후 원정을 마칩니다"
		"h1a", "h1b":
			return "하드 경로 %s — 이기면 돌파의 방으로 가는 창살이 열립니다" % id.substr(2).to_upper()
	return "필수 전투 %s — 통로를 지킵니다" % id.to_upper()


func _enc_reward(id: String) -> String:
	var parts: Array[String] = []
	if not RunModel.is_boss(id):
		parts.append(P2Catalog.REWARD_TEXT.card)
	for t in P2Catalog.REWARD_PLAN.get(RunModel._reward_key(id), []):
		parts.append(String(P2Catalog.REWARD_TEXT[t]))
	if RunModel.is_boss(id):
		parts.push_front(P2Catalog.REWARD_TEXT.settle)
	var pay := RunModel.pay_for(String(model.run.sector), id)
	parts.append("금화 +%d · 경험치 +%d (미확정)" % [int(pay[0]), int(pay[1])])
	return " · ".join(parts)


func _on_engage(id: String) -> void:
	if _modal_busy():
		return
	dismiss_notices()
	if not model.can_start_encounter(id):
		var req: Array = model.encounter_requires(id)
		dungeon.show_message("아직 싸울 수 없는 적입니다%s" % (" (먼저: %s)" % ", ".join(PackedStringArray(req)) if not req.is_empty() else ""))
		return
	dungeon.set_locked(true)
	_modal = "engage"
	var e: Dictionary = model.run.layout.encounters[id]
	var g: Dictionary = P2Catalog.GROUPS[e.group]
	var boss := RunModel.is_boss(id)
	var acc := P2Ui.C_MARK if boss else P2Ui.C_GOLD
	var diff := String(model.run.get("diff", "normal"))
	var mult := float(P2Catalog.SECTOR_HIT_MULT.get(String(model.run.sector), 1.0)) * float(P2Catalog.diff_of(diff).hit)
	var affixes := RunModel.encounter_affixes(model.run, id)
	var affixed := affixes.filter(func(a): return String(a) != "")
	var notes := (1 if g.has("teach") else 0) + (2 if g.has("pressure") else 0) + (1 if absf(mult - 1.0) > 0.001 else 0) + (1 if boss else 0) + (1 if not affixed.is_empty() else 0)
	var hgt := 296.0 + notes * 40.0 + 176.0
	var p := _win(Vector2(150, 360.0 - hgt / 2.0), Vector2(980, hgt), String(g.name), acc)
	var tags := _enc_tags(id)
	for m in model.run.get("mods", []):
		tags.push_front([null, String(P2Catalog.MOD[m].short), P2Ui.C_BLOCK])
	if diff != "normal":
		tags.push_front([P2Ui.kit_tex("status_crit", 1), String(P2Catalog.diff_of(diff).name), DIFF_COL.get(diff, P2Ui.C_TEXT)])
	P2Ui.chip_row(p, Vector2(24, 70), tags)
	_enemy_row(p, String(e.group), Vector2(24, 118), 916.0, mult, 164.0, RunModel.diff_hp_mult(model.run), affixes)
	var y := 296.0
	if g.has("teach"):
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("status_mark", 1), String(g.teach), P2Ui.C_TEXT)
	if g.has("pressure"):
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("intent_attack", 1), String(g.pressure), P2Ui.C_WARN)
	if absf(mult - 1.0) > 0.001:
		var who := tr("이 구간·난이도의 적은") if diff != "normal" else tr("이 구간의 적은")
		var how := (tr(" 공격이 %d%% 셉니다") % roundi((mult - 1.0) * 100.0)) if mult > 1.0 else (tr(" 공격이 %d%% 약합니다") % roundi((1.0 - mult) * 100.0))
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("intent_heavy", 1), who + how + tr(" (위 숫자는 이미 반영)"), P2Ui.C_WARN if mult > 1.0 else P2Ui.C_GOOD)
	if boss:
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("status_crit", 1), boss_record_line(id), P2Ui.C_GOLD)
	if not affixed.is_empty():
		var seen := {}
		var parts: Array = []
		for a in affixed:
			if not seen.has(a):
				seen[a] = true
				parts.append("%s(%s)" % [P2Catalog.AFFIX[a].name, P2Catalog.AFFIX[a].rule])
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("status_mark", 1), tr("적 성향: ") + " · ".join(PackedStringArray(parts)), P2Ui.C_WARN)
	y += 8.0
	var rl := _tx_label(tr("이기면"), 20, P2Ui.C_DIM)
	rl.position = Vector2(24, y + 6)
	p.add_child(rl)
	P2Ui.chip_row(p, Vector2(104, y), _enc_reward_chips(id))
	var by := hgt - 24.0 - 74.0
	P2Ui.chip_row(p, Vector2(24, by + 8), [[P2Ui.kit_tex("hud_heart", 1), "%d / %d" % [int(model.run.hp), int(model.run.max_hp)]]])
	var warn := _tx_label(tr("시작하면 되돌릴 수 없음"), 12, P2Ui.C_DIM)
	warn.position = Vector2(170, by + 18)
	p.add_child(warn)
	var back := _tx_button(tr("지나가기") if id == "elite" else tr("물러나기"), Vector2(552, by), Vector2(180, 50), 20)
	back.pressed.connect(func() -> void:
		close_modal()
		dungeon.set_locked(false))
	p.add_child(back)
	var go := P2Ui.primary(_tx_button(tr("교전 시작"), Vector2(746, by), Vector2(194, 50), 24))
	go.pressed.connect(func() -> void: engage_confirm(id))
	p.add_child(go)


# 원정 창 하나: 돌 틀 + 큰 제목 + 맥 줄. 내용 판을 돌려준다
func _win(pos: Vector2, size: Vector2, title: String, accent := P2Ui.C_GOLD, dim := true) -> Panel:
	var p := P2Ui.panel(_overlay, pos, size, dim, accent)
	var t := P2Ui.outlined(_tx_label(title, 36 if title.length() <= 16 else 24, accent), 4)
	t.position = Vector2(24, 8 if title.length() <= 16 else 16)
	p.add_child(t)
	P2Ui.rule(p, Vector2(24, 58), size.x - 64, Color(accent, 0.45))
	return p


# 아이콘 + 한 줄(넘치면 줄바꿈) 설명. 다음 줄 y를 돌려준다
func _note_line(p: Control, pos: Vector2, icon: Texture2D, text: String, col: Color, w := 900.0) -> float:
	var ic := P2Ui.tex_icon(icon, 26)
	ic.position = pos + Vector2(0, 1)
	p.add_child(ic)
	var l := _tx_label(text, 20, col, w - 40)
	l.position = pos + Vector2(38, 0)
	p.add_child(l)
	return pos.y + maxf(30.0, l.get_minimum_size().y) + 8.0


# 적 한 줄: 적마다 칸 하나(이름 · 체력 · 갑옷 · 첫 턴 행동 아이콘 · 성향). 구간 배율은 숫자에 이미 반영
func _enemy_row(p: Control, group: String, pos: Vector2, w: float, mult := 1.0, h := 164.0, hpm := 1.0, affixes: Array = []) -> void:
	var g: Dictionary = P2Catalog.GROUPS[group]
	var list: Array = []
	for i in range(g.enemies.size()):
		var role := String(g.enemies[i])
		if bool(P2Catalog.ENEMIES[role].get("summon_slot", false)) and i != g.enemies.find(role):
			continue
		list.append([i, role])
	var gap := 12.0
	var bw := minf(300.0, (w - gap * (list.size() - 1)) / list.size())
	for k in range(list.size()):
		var i := int(list[k][0])
		var d: Dictionary = P2Catalog.ENEMIES[String(list[k][1])]
		var ax := String(affixes[i]) if i < affixes.size() else ""
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_EDGE, 0.96))
		box.position = pos + Vector2(k * (bw + gap), 0)
		box.size = Vector2(bw, h)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.tooltip_text = "%s — %s" % [String(d.name), String(d.role)] + ("\n%s: %s" % [P2Catalog.AFFIX[ax].name, P2Catalog.AFFIX[ax].rule] if ax != "" else "")
		p.add_child(box)
		var nm := P2Ui.outlined(_tx_label((String(P2Catalog.AFFIX[ax].name) + " " if ax != "" else "") + String(d.name), 24, (P2Catalog.AFFIX[ax].col as Color) if ax != "" else P2Ui.C_TEXT), 3)
		nm.position = Vector2(12, 8)
		nm.size = Vector2(bw - 24, 30)
		nm.clip_text = true
		box.add_child(nm)
		var chips: Array = [[P2Ui.kit_tex("hud_heart", 1), str(maxi(1, roundi(int(d.hp) * hpm * (P2Catalog.AFFIX_TOUGH if ax == "tough" else 1.0))))]]
		if int(d.get("armor", 0)) > 0:
			chips.append([P2Ui.kit_tex("status_armor", 1), str(int(d.armor))])
		if bool(d.get("summon_slot", false)):
			chips.append([P2Ui.kit_tex("intent_summon", 1), tr("소환으로 등장"), P2Ui.C_DIM])
		else:
			var mv = d.moves[int(g.offsets[i]) % d.moves.size()]
			chips.append(_move_chip(mv, mult, 1 if ax == "fierce" else 0))
		P2Ui.chip_row(box, Vector2(10, 44), chips, 6.0, 32.0)
		var role := _tx_label(String(d.role), 20, P2Ui.C_DIM, bw - 24)
		role.position = Vector2(12, 86)
		role.max_lines_visible = 3 if h > 150.0 else 2
		box.add_child(role)


# 첫 턴 행동 = 전투 예고 칸과 같은 아이콘 + 짧은 글
func _move_chip(mv, mult: float, add := 0) -> Array:
	if mv is Dictionary:
		var icon: String = {"hex": "intent_hex", "poison": "intent_poison", "summon": "intent_summon", "rebuild": "intent_rebuild", "wait": "intent_prepare"}.get(String(mv.get("act", "")), "intent_unknown")
		return [P2Ui.kit_tex(icon, 1), tr("첫 턴 ") + P2Catalog.move_text(mv).get_slice(" (", 0), P2Ui.C_TEXT]
	if (mv as Array).is_empty():
		return [P2Ui.kit_tex("intent_prepare", 1), tr("첫 턴 준비"), P2Ui.C_DIM]
	var v := roundi(float(mv[0]) * mult) + add
	if mv.size() > 1:
		return [P2Ui.kit_tex("intent_multi", 1), tr("첫 턴 %d × %d") % [v, mv.size()], P2Ui.C_WARN]
	return [P2Ui.kit_tex("intent_attack", 1), tr("첫 턴 %d") % v, P2Ui.C_WARN]


func _enc_tags(id: String) -> Array:
	var e: Dictionary = model.run.layout.encounters[id]
	var risk := bool(e.get("risk", false))
	var out: Array = []
	match id:
		"elite":
			if String(e.get("kind", "")) == "mimic":
				out.append([P2Ui.kit_tex("intent_unknown", 1), tr("수상한 상자 — 미믹"), P2Ui.C_WARN])
			else:
				out.append([P2Ui.kit_tex("status_crit", 1), tr("선택 정예"), P2Ui.C_GOLD])
			out.append([null, tr("지나쳐도 됨"), P2Ui.C_DIM])
			if risk:
				out.append([P2Ui.kit_tex("intent_heavy", 1), tr("위험: 타격마다 +%d · 유물 보장") % P2Catalog.RISK_ATTACK, P2Ui.C_WARN])
		"boss", "hboss":
			out.append([P2Ui.kit_tex("status_crit", 1), tr("구간 보스"), P2Ui.C_MARK])
			out.append([null, tr("이기면 이번 구간 보상 확정 → 마치기 또는 계속"), P2Ui.C_DIM])
		"xboss":
			out.append([P2Ui.kit_tex("status_crit", 1), tr("최종 보스"), P2Ui.C_MARK])
			out.append([null, tr("이기면 최종 정산 후 원정 끝"), P2Ui.C_DIM])
		"h1a", "h1b":
			out.append([P2Ui.kit_tex("intent_attack", 1), tr("경로 %s") % id.substr(2).to_upper(), P2Ui.C_GOLD])
		_:
			out.append([P2Ui.kit_tex("intent_attack", 1), tr("필수 전투 %s") % id.to_upper(), P2Ui.C_TEXT])
			out.append([null, tr("통로를 지킴 — 이겨야 앞으로"), P2Ui.C_DIM])
	return out


func _enc_reward_chips(id: String) -> Array:
	var out: Array = []
	if RunModel.is_boss(id):
		out.append([P2Ui.kit_tex("hud_coin", 1), tr("구간 정산"), P2Ui.C_SAFE])
	else:
		out.append([P2Ui.kit_tex("pile_draw", 1), tr("카드 1장 고르기")])
	for t in P2Catalog.REWARD_PLAN.get(RunModel._reward_key(id), []):
		match String(t):
			"upgrade":
				out.append([P2Ui.kit_tex("status_crit", 1), tr("사본 강화")])
			"relic":
				out.append([P2Ui.relic_tex("rift_heart"), tr("유물")])
			"upgrade_or_heal":
				out.append([P2Ui.kit_tex("status_crit", 1), tr("강화 또는 회복")])
			"upgrade_or_relic":
				out.append([P2Ui.kit_tex("status_crit", 1), tr("강화 또는 유물")])
	if id == "elite":
		out.append([P2Catalog.icon_tex("flawless"), tr("특성 1"), P2Ui.C_MARK])
	var pay := RunModel.pay_for(String(model.run.sector), id)
	out.append([P2Ui.kit_tex("hud_coin", 1), "+%d" % RunModel.mod_gold(model.run, int(pay[0])), P2Ui.C_GOLD])
	out.append([P2Ui.kit_tex("status_resonance", 1), tr("경험치 +%d") % int(pay[1]), P2Ui.C_BLOCK])
	out.append([null, tr("미확정"), P2Ui.C_DIM])
	return out


# 보스 교전 창의 기록 한 줄: 최고 등급 · 정확도 · 최고 연속(이 캠페인 전체)
func boss_record_line(id: String) -> String:
	var r: Dictionary = (GameState.combat.get("boss_best", {}) as Dictionary).get(RunModel.boss_key(id, String(model.run.get("diff", "normal"))), {})
	if r.is_empty():
		return tr("기록: 아직 없음 (처음 도전)")
	return tr("기록: 최고 %s · 정확도 %d%% · 최고 연속 %d") % [String(r.grade), int(r.acc), int(r.get("best", 0))]


func engage_confirm(id: String) -> bool:
	if _modal != "engage":
		return false
	close_modal()
	var ok := model.start_encounter(id)
	if not ok and model.has_pending():
		ok = await gate.run()
	if not ok:
		dungeon.set_locked(false)
		dungeon.show_message("전투를 시작할 수 없습니다: " + model.last_error)
		return false
	# 고른 곳으로 빨려 들어가듯: 지도가 그 자리로 줌되는 동안 점 무늬 막이 그쪽으로 좁혀 든다
	var at := dungeon.dive(id, DIVE)
	await show_battle(model.battle, false, at)
	return true


func show_battle(b: P2Battle, resumed: bool, at := Vector2(640, 360)) -> void:
	dismiss_notices()
	await _fade_out(at, DIVE if at != Vector2(640, 360) else FADE)
	if dungeon != null:
		dungeon.set_locked(true)
		dungeon.set_suspended(true)
	battle_view = P2BattleView.new()
	add_child(battle_view)
	battle_view.setup(model, b, gate)
	battle_view.finished.connect(_on_battle_finished)
	await _fade_in()
	battle_view.begin(resumed)


func _on_battle_finished(result: String) -> void:
	await _fade_out()
	if battle_view != null:
		battle_view.queue_free()
		battle_view = null
	if mode == "field":
		show_field_result(result)
		await _fade_in()
		return
	match result:
		"won":
			dungeon.set_suspended(false)
			dungeon.refresh()
			MusicManager.play("Frozen Abyss")
			await _fade_in()
			_announce_achievements()
			match String(model.run.phase):
				"reward":
					show_reward()
				"sector_choice":
					show_sector_choice()
				"portal":
					dungeon.set_locked(false)
					dungeon.show_message("최종 보스 격파! 포탈이 열렸습니다.")
				_:
					dungeon.set_locked(false)
		_:
			show_result(model.last_result())
			await _fade_in()


# 원정 중에 새로 연 도전과제를 지도 아래 글로 한 번
var _achv_seen := -1


func _announce_achievements() -> void:
	var list: Array = model.run.get("achv", [])
	if _achv_seen < 0:
		_achv_seen = 0
	if list.size() <= _achv_seen or dungeon == null:
		_achv_seen = list.size()
		return
	var names: Array = []
	for a in P2Catalog.ACHIEVEMENTS:
		if list.slice(_achv_seen).has(a[0]):
			names.append(String(a[1]))
	_achv_seen = list.size()
	dungeon.show_message(tr("도전과제 달성: ") + " · ".join(PackedStringArray(names)))


# ── 연습 결과 ──────────────────────────────────────────────────────────────

func show_field_result(_result: String) -> void:
	_clear_views()
	_modal = "field_result"
	var bg := ColorRect.new()
	bg.color = Color("#10121a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	_practice_result(model.last_result())


# 연습 결과: 성적(등급 · 정확도 · 최대 연속)과 그 무리 · 난이도의 연습 최고 기록
func _practice_result(r: Dictionary) -> void:
	var gid := String(r.get("group", ""))
	var diff := String(r.get("diff", "normal"))
	var result := String(r.get("result", ""))
	var title: String = {"won": tr("연습 승리"), "lost": tr("연습 — 쓰러짐")}.get(result, tr("연습 그만둠"))
	var p := _win(Vector2(240, 150), Vector2(800, 420), title, P2Ui.C_GOLD if result == "won" else P2Ui.C_DIM, false)
	var y := 80.0
	var gname := String((P2Catalog.GROUPS.get(gid, {}) as Dictionary).get("name", gid))
	y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("status_crit", 1), "%s · %s" % [gname, P2Catalog.diff_of(diff).name], DIFF_COL.get(diff, P2Ui.C_TEXT), 740.0)
	if bool(r.get("graded", false)):
		var chips: Array = [[null, tr("등급 %s") % String(r.grade), RANK_COL.get(String(r.grade), P2Ui.C_TEXT)], [null, tr("정확도 %d") % int(r.acc)], [null, tr("최대 연속 %d") % int(r.best)]]
		if bool(r.get("new_best", false)):
			chips.append([null, tr("새 기록!") if not (r.get("prev", {}) as Dictionary).is_empty() else tr("첫 기록"), P2Ui.C_GOLD])
		y = _result_row(p, y, tr("성적"), P2Ui.C_GOLD, chips)
	else:
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("intent_unknown", 1), tr("성적 없음 — 끝까지 치러야 남습니다"), P2Ui.C_DIM, 740.0)
	var best: Dictionary = (GameState.combat.get("practice_best", {}) as Dictionary).get(RunModel.practice_key(gid, diff), {})
	if not best.is_empty():
		y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("status_resonance", 1), tr("이 난이도 연습 최고: %s · 정확도 %d · 연속 %d") % [String(best.grade), int(best.acc), int(best.best)], P2Ui.C_TEXT, 740.0)
	y = _note_line(p, Vector2(24, y), P2Ui.kit_tex("hud_heart", 1), tr("연습 성적은 원정 기록과 따로 남습니다"), P2Ui.C_DIM, 740.0)
	var frame := p.get_parent() as Control
	frame.size.y = y + 110.0
	p.size.y = frame.size.y - 24.0
	frame.position.y = 360.0 - frame.size.y / 2.0
	var back := P2Ui.primary(P2Ui.button(tr("돌아가기 [Enter]"), Vector2(520, y + 20), Vector2(240, 50), 24))
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(func() -> void: _leave("practice"))
	p.add_child(back)
	back.grab_focus.call_deferred()


func _leave(kind: String) -> void:
	if _leaving:
		return
	_leaving = true
	close_modal()
	Flow.leave_run_host(kind)


# ── 구간 보스 뒤: 정산 확인 + 마치기 / 계속 ────────────────────────────────────────────

# 구간 보스 뒤: 이미 확정된 보상(지켜짐)은 칩 한 줄로, 두 길(마치기 · 더 깊이)은 큰 칸 두 개로
func show_sector_choice() -> void:
	close_modal()
	if dungeon != null:
		dungeon.set_locked(true)
	_modal = "sector_choice"
	var run := model.run
	var sector := String(run.sector)
	var banked: Dictionary = run.banked.get(sector, {})
	var p := _win(Vector2(40, 24), Vector2(1200, 672), tr("%s 정복!") % P2Catalog.SECTOR_NAMES[sector], P2Ui.C_SAFE)
	var kept: Array = [[P2Ui.kit_tex("hud_coin", 1), "+%d" % int(banked.get("gold", 0)), P2Ui.C_GOLD], [P2Ui.kit_tex("status_resonance", 1), tr("경험치 +%d") % int(banked.get("xp", 0)), P2Ui.C_BLOCK]]
	if int(banked.get("spent", 0)) > 0:
		kept.append([null, tr("상인에 쓴 %d 제외") % int(banked.spent), P2Ui.C_DIM])
	var kl := _tx_label(tr("지켜짐"), 20, P2Ui.C_SAFE)
	kl.position = Vector2(24, 76)
	p.add_child(kl)
	P2Ui.chip_row(p, Vector2(108, 70), kept)
	var stat := Control.new()
	stat.mouse_filter = Control.MOUSE_FILTER_STOP
	stat.tooltip_text = tr("빌드: ") + RunModel.build_summary(run)
	stat.position = Vector2(108, 114)
	p.add_child(stat)
	P2Ui.chip_row(stat, Vector2.ZERO, [[P2Ui.kit_tex("hud_heart", 1), "%d / %d" % [int(run.hp), int(run.max_hp)]], [P2Ui.kit_tex("pile_draw", 1), tr("덱 %d") % (run.deck as Array).size()],
		[P2Ui.relic_tex("rift_heart"), "%d/%d" % [(run.relics as Array).size(), P2Catalog.relic_capacity(run)]]])
	stat.size = Vector2(420, 34)
	var nl := _tx_label(tr("지금"), 20, P2Ui.C_DIM)
	nl.position = Vector2(24, 120)
	p.add_child(nl)
	var ret := _big_choice(p, Vector2(24, 170), Vector2(556, 380), load(P2Catalog.ITEM_DIR + "hp_potion.png"), tr("여기서 마치기"), P2Ui.C_SAFE,
		[[P2Ui.kit_tex("status_crit", 1), tr("지금까지의 점수 · 기록이 남음"), P2Ui.C_TEXT], [P2Ui.kit_tex("pile_exhaust", 1), tr("원정 덱 · 유물 · 특성은 사라짐"), P2Ui.C_DIM]])
	ret.pressed.connect(func() -> void: choose_return())
	var nxt := model.next_sector(sector)
	var heal_to := mini(int(run.max_hp), int(run.hp) + P2Catalog.CONTINUE_HEAL)
	var pay_f: Array = P2Catalog.PAY[nxt].fight
	var pay_b: Array = P2Catalog.PAY[nxt].boss
	var cont := _big_choice(p, Vector2(596, 170), Vector2(568, 380), P2Catalog.icon_tex("mark_chain"), tr("더 깊이 — ") + String(P2Catalog.SECTOR_NAMES[nxt]), P2Ui.C_MARK,
		[[P2Ui.kit_tex("hud_heart", 1), tr("체력 +%d → %d (한 번)") % [P2Catalog.CONTINUE_HEAL, heal_to], P2Ui.C_TEXT],
		[P2Ui.kit_tex("status_crit", 1), tr("계속 특성 하나 (후보 3)"), P2Ui.C_TEXT],
		[P2Ui.kit_tex("hud_coin", 1), tr("전투마다 +%d · 보스 +%d") % [int(pay_f[0]), int(pay_b[0])], P2Ui.C_GOLD],
		[P2Ui.kit_tex("intent_heavy", 1), tr("지면 그 구간 미확정분만 잃음"), P2Ui.C_WARN]])
	cont.pressed.connect(func() -> void: show_trait_choice())
	var hint := _tx_label(tr("보상은 이미 저장됨 · 지금 꺼도 이 화면에서 다시 시작"), 20, P2Ui.C_DIM)
	hint.position = Vector2(24, 580)
	p.add_child(hint)


# 큰 고르기 칸: 아이콘 · 제목 · 칩 줄(아이콘 + 짧은 글)
func _big_choice(p: Control, pos: Vector2, size: Vector2, icon: Texture2D, title: String, accent: Color, lines: Array) -> Button:
	var b := P2Ui.button("", pos, size)
	b.set_meta("skin", "tile")
	P2Ui.mark(b, false)
	b.focus_mode = Control.FOCUS_ALL
	p.add_child(b)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.position = Vector2(3, 3)
	stripe.size = Vector2(size.x - 6, 4)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(stripe)
	var ic := P2Ui.tex_icon(icon, 64)
	ic.position = Vector2(20, 22)
	b.add_child(ic)
	var t := P2Ui.outlined(_tx_label(title, 24, accent), 3)
	t.position = Vector2(100, 40)
	t.size = Vector2(size.x - 120, 30)
	t.clip_text = true
	b.add_child(t)
	var y := 112.0
	for ln in lines:
		y = _note_line(b, Vector2(24, y), ln[0], String(ln[1]), ln[2], size.x - 40.0)
	return b


func choose_return() -> bool:
	if _modal != "sector_choice":
		return false
	var ok := await _saved(model.choose_return())
	if not ok:
		return false
	close_modal()
	dungeon.refresh()
	dungeon.set_locked(false)
	dungeon.show_message("여기서 마치기로 했다. 보스의 방에 열린 포탈(◎)로 가세요.")
	return true


func show_trait_choice() -> void:
	close_modal()
	_modal = "trait"
	var p := P2Ui.panel(_overlay, Vector2(40, 60), Vector2(1200, 600), true, P2Ui.C_MARK)
	var t := _tx_label(tr("더 깊이 도전 — 계속 특성 하나 고르기"), 36, P2Ui.C_MARK)
	t.position = Vector2(24, 10)
	p.add_child(t)
	var s := _tx_label(tr("유물 칸을 쓰지 않음 · 원정 끝까지 유지 · 고르면 못 바꿈"), 20, P2Ui.C_DIM, 1130)
	s.position = Vector2(24, 60)
	p.add_child(s)
	var x := 24.0
	var row: Array[Button] = []
	_sel = {}
	for id in model.run.trait_offer:
		var d: Dictionary = P2Catalog.TRAITS[id]
		var b := P2Ui.option_tile(String(d.name) + (tr(" · 공용") if bool(d.common) else ""), String(d.text), P2Catalog.icon_tex(String(id)), Vector2(370, 330))
		b.position = Vector2(x, 118)
		b.set_meta("id", id)
		row.append(b)
		var tid: String = id
		b.pressed.connect(func() -> void:
			_sel.trait_id = tid
			for o in row:
				P2Ui.mark(o, o.get_meta("id") == tid)
			(p.get_meta("confirm") as Button).disabled = false)
		p.add_child(b)
		x += 382
	var confirm := P2Ui.primary(_tx_button(tr("이 특성으로 계속"), Vector2(24, 500), Vector2(320, 52), 24))
	confirm.disabled = true
	confirm.pressed.connect(func() -> void: choose_continue(String(_sel.get("trait_id", ""))))
	p.add_child(confirm)
	p.set_meta("confirm", confirm)
	var back := _tx_button(tr("뒤로"), Vector2(364, 500), Vector2(200, 52), 20)
	back.pressed.connect(func() -> void: show_sector_choice())
	p.add_child(back)


func choose_continue(trait_id: String) -> bool:
	if _modal != "trait" or trait_id == "":
		return false
	var hp_before := int(model.run.hp)
	var ok := await _saved(model.choose_continue(trait_id))
	if not ok:
		return false
	close_modal()
	# 지도에서 안쪽 고리로 빨려 들어간 뒤(구간 이동이 느껴지게) 새 구간 지도가 가까이서 물러나며 열린다
	dungeon.set_locked(true)
	await dungeon.zoom_inward(0.9)
	await _fade_out(Vector2(640, 308), 0.25)
	show_dungeon()
	dungeon.set_locked(true)
	dungeon.show_message("%s 진입 — 특성 %s · 체력 %d → %d" % [P2Catalog.SECTOR_NAMES[String(model.run.sector)], P2Catalog.TRAITS[trait_id].name, hp_before, int(model.run.hp)])
	dungeon.arrive(1.1)
	await _fade_in(Vector2(640, 308), 0.35)
	await get_tree().create_timer(0.8).timeout
	dungeon.set_locked(false)
	return true


# ── 하드 구간 경로 확정 ──────────────────────────────────────────────────────────

func _on_route(route: String) -> void:
	if _modal_busy() or String(model.run.get("route", "")) != "":
		return
	dungeon.set_locked(true)
	_modal = "route"
	var other := "b" if route == "a" else "a"
	var p := _win(Vector2(110, 70), Vector2(1060, 580), tr("경로 %s로 정할까요?") % route.to_upper(), Color("#e2c080"))
	P2Ui.chip_row(p, Vector2(24, 70), [[P2Ui.kit_tex("intent_seal", 1), tr("반대 경로 %s는 이번 원정 동안 봉인") % other.to_upper(), P2Ui.C_WARN],
		[null, tr("두 길은 포격 진지에서 만남"), P2Ui.C_DIM]])
	var mult := float(P2Catalog.SECTOR_HIT_MULT.get(String(model.run.sector), 1.0)) * float(P2Catalog.diff_of(String(model.run.get("diff", "normal"))).hit)
	var x := 24.0
	for r in [route, other]:
		var g: Dictionary = P2Catalog.GROUPS["h1" + r]
		var box := Panel.new()
		box.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_GOLD if r == route else P2Ui.C_EDGE, 0.96 if r == route else 0.7))
		box.position = Vector2(x, 118)
		box.size = Vector2(492, 352)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(box)
		var nm := P2Ui.outlined(_tx_label(tr("경로 %s · %s") % [r.to_upper(), g.name] + (tr("  (고름)") if r == route else ""), 24, P2Ui.C_GOLD if r == route else P2Ui.C_DIM), 3)
		nm.position = Vector2(14, 10)
		box.add_child(nm)
		_enemy_row(box, "h1" + r, Vector2(12, 50), 468.0, mult, 168.0, RunModel.diff_hp_mult(model.run))
		var y := 230.0
		y = _note_line(box, Vector2(14, y), P2Ui.kit_tex("intent_attack", 1), String(g.pressure), P2Ui.C_WARN, 470.0)
		_note_line(box, Vector2(14, y), P2Ui.kit_tex("pile_draw", 1), tr("보상: ") + String(g.reward), P2Ui.C_TEXT, 470.0)
		if r != route:
			box.modulate = Color(0.75, 0.75, 0.8)
		x += 508
	var no := _tx_button(tr("다시 생각하기"), Vector2(560, 494), Vector2(200, 50), 20)
	no.pressed.connect(func() -> void:
		close_modal()
		dungeon.set_locked(false))
	p.add_child(no)
	var yes := P2Ui.primary(_tx_button(tr("경로 %s로 확정") % route.to_upper(), Vector2(774, 494), Vector2(244, 50), 24))
	yes.pressed.connect(func() -> void: confirm_route(route))
	p.add_child(yes)


func confirm_route(route: String) -> bool:
	if _modal != "route":
		return false
	var ok := await _saved(model.commit_route(route))
	if not ok:
		return false
	close_modal()
	dungeon.refresh()
	dungeon.set_locked(false)
	dungeon.show_message("경로 %s 확정 — %s 문이 열리고 반대 길은 봉인되었다." % [route.to_upper(), P2Catalog.GROUPS["h1" + route].name])
	return true


# ── 보상 (한 부분씩: 카드 → 강화/유물/회복) ─────────────────────────────────────────

const CATEGORY_NAMES := {"upgrade": "사본 강화", "relic": "유물", "heal": "회복", "gold": "대체 보상"}


func show_reward() -> void:
	close_modal()
	if dungeon != null:
		dungeon.set_locked(true)
	_modal = "reward"
	_tiles.clear()
	_replace_tiles.clear()
	_relic = {}
	_relic_drag = {}
	_skip_button = null
	_sync_view_stats()
	var run := model.run
	var rw: Dictionary = run.reward
	var part := model.current_part()
	var hard := String(run.sector) != "normal"
	var total := (rw.parts as Array).size()
	var p := _win(Vector2(40, 24), Vector2(1200, 672), "%s %d/%d · %s" % [tr("보상"), int(rw.index) + 1, total, tr(String(P2Catalog.PART_TITLES.get(String(part.type), "보상")))],
		Color(0.55, 0.72, 0.95) if hard else P2Ui.C_GOLD)
	var stat := Control.new()
	stat.mouse_filter = Control.MOUSE_FILTER_STOP
	stat.tooltip_text = tr("이번 원정의 덱 %d장: %s") % [(run.deck as Array).size(), P2Ui.deck_summary(run.deck)]
	p.add_child(stat)
	var end_x := P2Ui.chip_row(stat, Vector2.ZERO, [[P2Ui.kit_tex("pile_draw", 1), tr("덱 %d") % (run.deck as Array).size()],
		[P2Ui.kit_tex("hud_heart", 1), "%d / %d" % [int(run.hp), int(run.max_hp)]], [P2Ui.relic_tex("rift_heart"), "%d/%d" % [(run.relics as Array).size(), P2Catalog.relic_capacity(run)]],
		[P2Ui.kit_tex("status_crit", 1), "Lv %d" % int(run.get("lv", 1)), P2Ui.C_GOLD if model.stat_pending() > 0 else P2Ui.C_TEXT]])
	stat.tooltip_text += "\n" + P2Ui.stat_tooltip(run)
	stat.size = Vector2(end_x, 34)
	stat.position = Vector2(1160 - end_x, 14)
	p.set_meta("deck_chip", stat)
	var confirm := P2Ui.primary(_tx_button(tr("선택 확정"), Vector2(944, 584), Vector2(220, 50), 24))
	confirm.pressed.connect(func() -> void: confirm_reward(_sel.duplicate()))
	p.add_child(confirm)
	p.set_meta("confirm", confirm)
	_confirm_button = confirm
	var summary := _tx_label("", 16, P2Ui.C_TEXT, 620)
	summary.position = Vector2(296, 568)
	summary.size = Vector2(632, 70)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(summary)
	p.set_meta("summary", summary)
	_sel = {}
	match String(part.type):
		"trait":
			_reward_traits(p, p, part, 76.0)
		"card":
			_reward_cards(p, p, part, 76.0)
		"upgrade":
			if (part.upgrades as Array).is_empty():
				_section(p, tr("강화할 수 있는 사본이 없어 대신 %s을(를) 받습니다.") % _substitute_text(), 90.0)
				_sel = {"category": "gold"}
			else:
				_reward_upgrades(p, p, part, 76.0)
		"relic":
			_reward_relics(p, p, part, 76.0, bool(part.get("required", false)))
		"upgrade_or_heal", "upgrade_or_relic":
			_reward_categories(p, part)
	_next_threat(p, Vector2(24, 548))
	_update_confirm(p)


func _substitute_text() -> String:
	return "체력 +%d" % P2Catalog.FINAL_HEAL if int(model.run.hp) < int(model.run.max_hp) else "금화 2 (미확정)"


func _section(parent: Control, text: String, y: float) -> float:
	var l := _tx_label(text, 16, P2Ui.C_DIM, 1130)
	l.position = Vector2(24, y)
	parent.add_child(l)
	return y + 28


# 원정 창 글자: 픽셀 글꼴을 정수 배율로 (P2Ui.text)
func _tx_label(text: String, size: int, color: Color, wrap := 0.0) -> Label:
	return P2Ui.text(text, size, color, wrap)


func _tx_button(text: String, pos: Vector2, size: Vector2, font_size := 16) -> Button:
	var b := P2Ui.crisp(P2Ui.button(text, pos, size), font_size) as Button
	b.focus_mode = Control.FOCUS_ALL
	return b


# 창이 떠 있고 아무것도 초점이 없을 때 방향키·Tab을 누르면 창의 첫 칸(고를 수 있는 것)에 금빛 초점. 그다음은 Godot 기본 이동
func _unhandled_input(event: InputEvent) -> void:
	if _modal == "" or not (event is InputEventKey) or not event.pressed or get_viewport().gui_get_focus_owner() != null:
		return
	for a in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_focus_next"]:
		if event.is_action_pressed(a):
			var b := _first_focusable(_overlay)
			if b != null:
				b.grab_focus()
				get_viewport().set_input_as_handled()
			return


func _first_focusable(root: Node) -> Button:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Button and (n as Button).focus_mode == Control.FOCUS_ALL and not (n as Button).disabled and (n as Button).is_visible_in_tree():
			return n
		stack.append_array(n.get_children())
	return null


# 고르는 칸 하나 (선택만, 받기는 [선택 확정]). 같은 줄의 칸끼리 금색 테두리로 고른 것을 표시
func _pick_tile(parent: Control, pos: Vector2, size: Vector2, row: Array, id: String, on_pick: Callable) -> Button:
	var b := P2Ui.button("", pos, size)
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("skin", "tile")
	P2Ui.mark(b, false)
	b.set_meta("id", id)
	row.append(b)
	b.pressed.connect(func() -> void:
		on_pick.call()
		for o in row:
			P2Ui.mark(o, String(o.get_meta("id")) == id))
	parent.add_child(b)
	return b


# 정예 보상 특성: 후보 3개 중 하나 (구간 보스 뒤 계속 특성과 같은 칸)
func _reward_traits(p: Panel, parent: Control, part: Dictionary, y: float) -> float:
	y = _section(parent, tr("정예를 이긴 보상 — 특성 하나 · 원정 끝까지 유지 · 유물 칸을 쓰지 않음"), y)
	var row: Array = []
	var x := 24.0
	for id in part.get("traits", []):
		var d: Dictionary = P2Catalog.TRAITS[id]
		var tid: String = id
		var b := P2Ui.option_tile(String(d.name) + (tr(" · 공용") if bool(d.common) else ""), String(d.text), P2Catalog.icon_tex(tid), Vector2(370, 330))
		b.position = Vector2(x, y + 8)
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta("id", tid)
		row.append(b)
		b.pressed.connect(func() -> void:
			_sel = {"trait": tid}
			for o in row:
				P2Ui.mark(o, String(o.get_meta("id")) == tid)
			_update_confirm(p))
		parent.add_child(b)
		x += 382
	return y + 346


# 사본 강화: 위에 고를 수 있는 강화 줄, 아래에 지금 고른 강화 하나의 강화 전 → 강화 후 (전투와 같은 카드 그림)
func _reward_upgrades(p: Panel, parent: Control, part: Dictionary, y: float) -> float:
	y = _section(parent, tr("강화 하나를 고르면 아래에서 전·후 비교 · 사본 한 장만 바뀜"), y)
	var row: Array = []
	var cid := String(model.run.class_id)
	var compare := Control.new()
	compare.position = Vector2(0, y + 70)
	compare.size = Vector2(1180, 360)
	compare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(compare)
	var empty := _tx_label(tr("← 위에서 강화를 고르면 여기에 강화 전 · 강화 후가 나옵니다"), 16, P2Ui.C_DIM)
	empty.position = Vector2(24, 40)
	compare.add_child(empty)
	var x := 24.0
	for up in part.upgrades:
		var cands := RunModel.upgrade_candidates(model.run.deck, up)
		var from := String(P2Catalog.UPGRADE_KINDS[up].from)
		var u: String = up
		var pref := (P2Catalog.CLASS_UPGRADE_PREF.get(cid, []) as Array).has(up)
		var b := _pick_tile(parent, Vector2(x, y), Vector2(360, 64), row, u, func() -> void:
			_sel.upgrade = u
			_sel.copy = cands[0]
			for ch in compare.get_children():
				ch.queue_free()
			_upgrade_compare(compare, from, u, cands.size())
			_update_confirm(p))
		b.tooltip_text = String(P2Catalog.UPGRADES[up].text)
		var ic := P2Ui.tex_icon(P2Ui.card_tex(from, up), 32)
		ic.position = Vector2(14, 16)
		b.add_child(ic)
		var nm := _tx_label("%s → %s" % [P2Catalog.card_name(from), P2Catalog.UPGRADES[up].name], 16, P2Ui.C_GOLD)
		nm.position = Vector2(56, 8)
		nm.size = Vector2(296, 24)
		nm.clip_text = true
		b.add_child(nm)
		var info := _tx_label(tr("가진 %s %d장 중 1장%s") % [P2Catalog.card_name(from), cands.size(), tr(" · 직업 강화") if pref else ""], 12, P2Ui.C_DIM)
		info.position = Vector2(56, 38)
		b.add_child(info)
		_tiles.append(b)
		x += 372
	return y + 440


# 강화 전 → 강화 후 한 쌍 (같은 카드 그림) + 바뀌는 점만 강조. 한 장만 바뀌고 나머지 사본은 그대로
func _upgrade_compare(parent: Control, from: String, up: String, copies: int) -> void:
	var cid := String(model.run.class_id)
	var before := P2Catalog.build_card(from, "preview")
	var after := P2Catalog.build_card(from, "preview", up)
	var lb := _tx_label(tr("강화 전"), 24, P2Ui.C_DIM)
	lb.position = Vector2(24, 0)
	parent.add_child(lb)
	var fb := P2Ui.card_art(before, cid, 3, "", true)
	fb.position = Vector2(24, 30)
	parent.add_child(fb)
	var arrow := P2Ui.outlined(_tx_label("→", 36, P2Ui.C_GOLD), 4)
	arrow.position = Vector2(240, 170)
	parent.add_child(arrow)
	var la := _tx_label(tr("강화 후"), 24, P2Ui.C_GOLD)
	la.position = Vector2(290, 0)
	parent.add_child(la)
	var fa := P2Ui.card_art(after, cid, 3, "", true)
	fa.position = Vector2(290, 30)
	(fa.get_meta("glow") as Panel).visible = true
	parent.add_child(fa)
	var b0 := P2Catalog.face(before, cid)
	var b1 := P2Catalog.face(after, cid)
	var lines: Array[String] = []
	lines.append("%s → %s" % [before.card_name, after.card_name])
	if before.mana_cost != after.mana_cost:
		lines.append(tr("비용 %d → %d") % [before.mana_cost, after.mana_cost])
	if String(b0[0]) != String(b1[0]):
		lines.append(tr("핵심: %s → %s") % [b0[0], b1[0]])
	if String(b0[1]) != String(b1[1]):
		lines.append(tr("전: %s") % b0[1])
		lines.append(tr("후: %s") % b1[1])
	var head := _tx_label(tr("바뀌는 점"), 24, P2Ui.C_GOLD)
	head.position = Vector2(536, 30)
	parent.add_child(head)
	var facts := _tx_label("\n".join(lines), 16, P2Ui.C_TEXT, 600)
	facts.position = Vector2(536, 64)
	parent.add_child(facts)
	var once := _tx_label(tr("이 강화는 %s 한 장에만 적용됩니다 (가진 %d장 중 1장, 나머지 %d장은 그대로)") % [before.card_name, copies, maxi(0, copies - 1)], 16, P2Ui.C_SAFE, 600)
	once.position = Vector2(536, 270)
	parent.add_child(once)
	parent.set_meta("shown", up)


# 유물: 받을 수 있는 유물 칸 + 지금 가진 유물 줄(따로). 칸이 가득이면 버릴 유물을 골라야 확정할 수 있고,
# 새 유물과 버릴 유물, 버릴 때의 결과(균열 심장의 최대 체력·마나)를 아래 요약에 그대로 보인다
func _reward_relics(p: Panel, parent: Control, part: Dictionary, y: float, required: bool) -> float:
	var held: Array = model.run.relics
	var cap := P2Catalog.relic_capacity(model.run)
	var full := held.size() >= cap
	y = _section(parent, tr("유물 하나 — 자동 발동 · 이번 원정 동안") + (tr(" · 칸이 가득: 버릴 유물도 고르기") if full else ""), y)
	var x := 24.0
	var row: Array = []
	var rrow: Array = []
	_relic = {"p": p, "full": full, "slots": [], "cand": row, "held": rrow, "pending": null}
	for id in part.get("relics", []):
		var d: Dictionary = P2Catalog.RELICS[id]
		var rid: String = id
		var b := _pick_tile(parent, Vector2(x, y), Vector2(372, 150), row, rid, func() -> void:
			_sel.relic = rid
			_sel.erase("skip")
			if _skip_button != null:
				P2Ui.mark(_skip_button, false)
			_relic_auto(rid)
			_update_confirm(p))
		b.set_meta("relic", true)
		b.tooltip_text = String(d.text) + "\n" + tr("끌어서 아래 유물 칸에 넣기")
		var ic := P2Ui.tex_icon(P2Ui.relic_tex(rid), 48)
		ic.position = Vector2(14, 14)
		b.add_child(ic)
		var nm := P2Ui.outlined(_tx_label(String(d.name), 24, P2Ui.C_GOLD), 3)
		nm.position = Vector2(72, 16)
		b.add_child(nm)
		var rhythm := bool(d.get("rhythm", false))
		var own := _tx_label(tr("리듬 유물 · 이번 원정만") if rhythm else tr("새 유물 · 이번 원정만"), 12, P2Ui.C_BLOCK if rhythm else P2Ui.C_DIM)
		own.position = Vector2(72, 46)
		b.add_child(own)
		var body := _tx_label(String(d.text), 16, P2Ui.C_TEXT, 340)
		body.position = Vector2(14, 70)
		body.max_lines_visible = 3
		b.add_child(body)
		_tiles.append(b)
		x += 382
	y += 162
	var hl := _tx_label(tr("지금 가진 유물 %d/%d") % [held.size(), cap] + (tr(" — 하나를 버리고 바꿉니다") if full else ""), 16, P2Ui.C_WARN if full else P2Ui.C_DIM)
	hl.position = Vector2(24, y)
	parent.add_child(hl)
	y += 28
	var rx := 24.0
	for k in range(cap):
		if k >= held.size():
			var empty := Panel.new()
			empty.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_EDGE, 0.6))
			empty.position = Vector2(rx, y)
			empty.size = Vector2(220, 56)
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(empty)
			var el := _tx_label(tr("빈 칸"), 20, Color(P2Ui.C_DIM, 0.6))
			el.position = Vector2(16, 14)
			empty.add_child(el)
			(_relic.slots as Array).append({"node": empty, "held": ""})
			rx += 228
			continue
		var hid: String = held[k]
		var tile: Button
		if full:
			tile = _pick_tile(parent, Vector2(rx, y), Vector2(220, 56), rrow, hid, func() -> void:
				_sel.replace = hid
				if _sel.has("relic"):
					_relic_place(String(_sel.relic), hid, _relic_cand_center(String(_sel.relic)))
				_update_confirm(p))
			_replace_tiles.append(tile)
		else:
			tile = P2Ui.button("", Vector2(rx, y), Vector2(220, 56))
			tile.set_meta("skin", "tile")
			P2Ui.mark(tile, false)
			tile.disabled = true
			parent.add_child(tile)
		var hlv := int(P2Catalog.relic_levels(held).get(hid, 1))
		tile.tooltip_text = String(P2Catalog.RELICS[hid].text) + P2Ui.relic_level_text(hlv) + "\n" + _relic_drop_text(hid)
		var ic2 := P2Ui.tex_icon(P2Ui.relic_tex(hid), 32)
		ic2.position = Vector2(12, 12)
		tile.add_child(ic2)
		var nm2 := _tx_label(String(P2Catalog.RELICS[hid].name), 16, P2Ui.C_TEXT)
		nm2.position = Vector2(52, 16)
		nm2.size = Vector2(160, 24)
		nm2.clip_text = true
		tile.add_child(nm2)
		P2Ui.relic_level_mark(tile, hlv, 44.0)
		(_relic.slots as Array).append({"node": tile, "held": hid})
		rx += 228
	y += 64
	if not required:
		var skip := _tx_button(tr("건너뛰기 (유물 그대로)"), Vector2(24, 584), Vector2(250, 50), 16)
		skip.set_meta("skin", "btn")
		skip.pressed.connect(func() -> void:
			_sel.erase("relic")
			_sel.erase("replace")
			_sel.skip = true
			_relic_clear_pending()
			for o in row:
				P2Ui.mark(o, false)
			for o in rrow:
				P2Ui.mark(o, false)
			P2Ui.mark(skip, true)
			_update_confirm(p))
		p.add_child(skip)
		_skip_button = skip
	return y


# ── 유물 칸에 끼우기: 후보를 끌어 칸에 놓거나(가득이면 버릴 유물 위에), 누르면 빈 칸으로 날아 들어감. 확정 전까지는 미리 끼운 모습 ──

func _relic_cand_center(id: String) -> Vector2:
	for t in _relic.get("cand", []):
		if is_instance_valid(t) and String(t.get_meta("id")) == id:
			return (t as Control).get_global_rect().get_center()
	return Vector2(640, 300)


func _relic_slot_of(held: String) -> Control:
	for sl in _relic.get("slots", []):
		if String(sl.held) == held and is_instance_valid(sl.node):
			return sl.node
	return null


# 누름: 빈 칸이 있으면 첫 빈 칸으로, 가득이면 이미 고른 버릴 칸으로(없으면 버릴 칸들이 깜빡여 알려 줌)
func _relic_auto(id: String) -> void:
	var at := _relic_cand_center(id)
	if not bool(_relic.get("full", false)):
		_relic_place(id, "", at)
	elif _sel.has("replace"):
		_relic_place(id, String(_sel.replace), at)
	else:
		for t in _relic.get("held", []):
			if is_instance_valid(t):
				var tw := (t as Control).create_tween()
				tw.tween_property(t, "modulate", Color(1.5, 1.3, 0.8), 0.1)
				tw.tween_property(t, "modulate", Color.WHITE, 0.25)


func _relic_clear_pending() -> void:
	var pend: Control = _relic.get("pending")
	if pend != null and is_instance_valid(pend):
		var host: Control = pend.get_meta("slot")
		if is_instance_valid(host):
			for ch in host.get_children():
				if ch != pend and ch is CanvasItem:
					(ch as CanvasItem).modulate = Color.WHITE
		pend.queue_free()
	_relic.pending = null


# 새 유물이 칸에 쏙: 아이콘이 from(화면 자리)에서 칸으로 날아가 커졌다 자리 잡고, 버릴 유물은 붉게 가라앉으며 '버림'
func _relic_place(id: String, held: String, from: Vector2) -> void:
	var slot: Control = null
	if held != "":
		slot = _relic_slot_of(held)
	else:
		for sl in _relic.get("slots", []):
			if String(sl.held) == "" and is_instance_valid(sl.node):
				slot = sl.node
				break
	if slot == null:
		return
	_relic_clear_pending()
	var fly := P2Ui.tex_icon(P2Ui.relic_tex(id), 48)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.position = from - Vector2(24, 24)
	fly.pivot_offset = Vector2(24, 24)
	_overlay.add_child(fly)
	var to := slot.get_global_rect().position + Vector2(12, 4)
	var t := fly.create_tween()
	t.tween_property(fly, "position", to, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(fly, "scale", Vector2.ONE * 0.67, 0.2)
	t.tween_callback(func() -> void:
		fly.queue_free()
		if is_instance_valid(slot) and _modal == "reward":
			_relic_pending_at(slot, id, held != ""))


func _relic_pending_at(slot: Control, id: String, replacing: bool) -> void:
	_relic_clear_pending()
	for ch in slot.get_children():
		if ch is CanvasItem:
			(ch as CanvasItem).modulate = Color(0.55, 0.3, 0.3, 0.5) if replacing else Color(1, 1, 1, 0)
	var pend := Panel.new()
	pend.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_GOLD, 0.96))
	pend.size = slot.size
	pend.pivot_offset = slot.size / 2.0
	pend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pend.set_meta("slot", slot)
	slot.add_child(pend)
	var ic := P2Ui.tex_icon(P2Ui.relic_tex(id), 32)
	ic.position = Vector2(12, 12)
	pend.add_child(ic)
	var nm := _tx_label(String(P2Catalog.RELICS[id].name), 16, P2Ui.C_GOLD)
	nm.position = Vector2(52, 6)
	nm.size = Vector2(160, 22)
	nm.clip_text = true
	pend.add_child(nm)
	var tag := _tx_label(tr("새 유물 · 버림: %s") % String(P2Catalog.RELICS[String(_sel.get("replace", ""))].name) if replacing and _sel.has("replace") else tr("새 유물"), 12, P2Ui.C_WARN if replacing else P2Ui.C_GOOD)
	tag.position = Vector2(52, 30)
	tag.size = Vector2(164, 18)
	tag.clip_text = true
	pend.add_child(tag)
	pend.scale = Vector2.ONE * 1.25
	var t := pend.create_tween()
	t.tween_property(pend, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", P2Ui.box(Color(0, 0, 0, 0), P2Ui.C_GOLD, 3))
	ring.size = slot.size
	ring.pivot_offset = slot.size / 2.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pend.add_child(ring)
	var rt := ring.create_tween().set_parallel()
	rt.tween_property(ring, "scale", Vector2(1.25, 1.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.3)
	rt.chain().tween_callback(ring.queue_free)
	_relic.pending = pend
	P2Ui.ui_sound("click")


func _input(event: InputEvent) -> void:
	if _modal == "relics" and not _arr.is_empty() and is_instance_valid(_arr.get("p")):
		_arr_input(event)
		return
	if _modal != "reward" or _relic.is_empty() or not is_instance_valid(_relic.get("p")):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_relic_drag = {}
			for t in _relic.cand:
				if is_instance_valid(t) and (t as Control).get_global_rect().has_point(mb.position):
					_relic_drag = {"from": t, "id": String(t.get_meta("id")), "start": mb.position, "at": mb.position, "live": false}
		elif not _relic_drag.is_empty():
			if bool(_relic_drag.live):
				_relic_drop(mb.position)
			else:
				_relic_drag = {}
	elif event is InputEventMouseMotion and not _relic_drag.is_empty():
		var at := (event as InputEventMouseMotion).position
		_relic_drag.at = at
		if not bool(_relic_drag.live) and at.distance_to(_relic_drag.start) > 10.0:
			_relic_drag_begin()


func _relic_valid_slots() -> Array:
	var full := bool(_relic.get("full", false))
	return (_relic.get("slots", []) as Array).filter(func(sl): return is_instance_valid(sl.node) and ((String(sl.held) != "") == full))


func _relic_drag_begin() -> void:
	_relic_drag.live = true
	var src: Control = _relic_drag.from
	src.modulate = Color(1, 1, 1, 0.45)
	var tok := Panel.new()
	tok.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_GOLD, 0.97))
	tok.size = Vector2(72, 72)
	tok.pivot_offset = Vector2(36, 36)
	tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := P2Ui.tex_icon(P2Ui.relic_tex(String(_relic_drag.id)), 56)
	ic.position = Vector2(8, 8)
	tok.add_child(ic)
	tok.position = (_relic_drag.at as Vector2) - Vector2(36, 36)
	tok.scale = Vector2.ONE * 0.6
	tok.create_tween().tween_property(tok, "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_overlay.add_child(tok)
	_relic_drag.tok = tok
	_relic_drag.vel = Vector2.ZERO
	var pulses: Array = []
	for sl in _relic_valid_slots():
		var n: Control = sl.node
		n.pivot_offset = n.size / 2.0
		var tw := n.create_tween().set_loops()
		tw.tween_property(n, "modulate", Color(1.35, 1.25, 0.9), 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)
		pulses.append([n, tw])
	_relic_drag.pulses = pulses
	P2Ui.ui_sound("hover")


func _relic_hover_slot(at: Vector2) -> Dictionary:
	for sl in _relic_valid_slots():
		if (sl.node as Control).get_global_rect().grow(18.0).has_point(at):
			return sl
	return {}


func _process(delta: float) -> void:
	if _relic_drag.is_empty() or not bool(_relic_drag.live):
		return
	var tok: Control = _relic_drag.tok
	if not is_instance_valid(tok):
		_relic_drag = {}
		return
	var goal: Vector2 = _relic_drag.at
	var sl := _relic_hover_slot(goal)
	for pv in _relic_drag.pulses:
		var n: Control = pv[0]
		if is_instance_valid(n):
			n.scale = n.scale.lerp(Vector2.ONE * (1.07 if not sl.is_empty() and sl.node == n else 1.0), 1.0 - exp(-delta * 20.0))
	if not sl.is_empty():
		goal = goal.lerp((sl.node as Control).get_global_rect().get_center(), 0.45)
	var cur := tok.position + Vector2(36, 36)
	var nxt := cur.lerp(goal, 1.0 - exp(-delta * 22.0))
	var v := (nxt - cur) / maxf(delta, 0.001)
	_relic_drag.vel = (_relic_drag.vel as Vector2).lerp(v, 0.3)
	tok.position = nxt - Vector2(36, 36)
	tok.rotation = clampf((_relic_drag.vel as Vector2).x * 0.0006, -0.35, 0.35)


func _relic_drop(at: Vector2) -> void:
	var d := _relic_drag
	_relic_drag = {}
	for pv in d.get("pulses", []):
		var n: Control = pv[0]
		(pv[1] as Tween).kill()
		if is_instance_valid(n):
			n.modulate = Color.WHITE
			n.scale = Vector2.ONE
	var src: Control = d.from
	if is_instance_valid(src):
		src.modulate = Color.WHITE
	var tok: Control = d.tok
	var sl := _relic_hover_slot(at)
	if sl.is_empty():
		if is_instance_valid(tok) and is_instance_valid(src):
			var back := tok.create_tween().set_parallel()
			back.tween_property(tok, "position", src.get_global_rect().get_center() - Vector2(36, 36), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			back.tween_property(tok, "modulate:a", 0.0, 0.18)
			back.chain().tween_callback(tok.queue_free)
		return
	if is_instance_valid(tok):
		tok.queue_free()
	var id := String(d.id)
	_sel.relic = id
	_sel.erase("skip")
	if _skip_button != null:
		P2Ui.mark(_skip_button, false)
	for o in _relic.cand:
		if is_instance_valid(o):
			P2Ui.mark(o, String(o.get_meta("id")) == id)
	var held := String(sl.held)
	if held != "":
		_sel.replace = held
		for o in _relic.held:
			if is_instance_valid(o):
				P2Ui.mark(o, String(o.get_meta("id")) == held)
	_relic_pending_at(sl.node, id, held != "")
	_update_confirm(_relic.p)


func _relic_drop_text(id: String) -> String:
	if id == "rift_heart":
		return tr("버리면: 최대 체력 +%d (현재 체력 그대로) · 최대 마나 +1 사라짐") % P2Catalog.RIFT_HP
	if id == "bridge_slab":
		return tr("버리면: 최대 체력 +%d 돌아옴 · 양옆 단계 사라짐") % P2Catalog.BRIDGE_HP
	return tr("버리면: 이 유물의 효과가 이번 원정에서 사라짐")


# 유물 창: 칸 다섯(왼쪽 → 오른쪽 순서)을 크게, 칸 사이 틈에 석판이 주는 영향(▶ +1 금색 · ◀ 잠 회색), 아래에 고른 유물 설명.
# 끌어서 맞바꾸고, 올리거나 누르면 아래 설명이 그 유물로
func show_relics(sel := -1, focus_id := "") -> void:
	if model.run.is_empty() or _modal_busy():
		return
	close_modal()
	if dungeon != null:
		dungeon.set_locked(true)
	_modal = "relics"
	var held: Array = model.run.relics
	if focus_id != "":
		sel = held.find(focus_id)
	if sel < 0 or sel >= held.size():
		sel = 0
	var lv := P2Catalog.relic_levels(held)
	var links := _slab_links(held, lv)
	var p := _win(Vector2(240, 96), Vector2(800, 528), tr("유물"), P2Ui.C_GOLD)
	var cap := P2Catalog.relic_capacity(model.run)
	var tag := P2Ui.chip(null, tr("%d / %d칸") % [held.size(), cap], P2Ui.C_DIM, 36.0)
	tag.position = Vector2(760 - tag.size.x, 14)
	p.add_child(tag)
	var sub := _tx_label(tr("끌어서 자리 바꾸기 · 화살표 = 석판 영향 · Ⅱ·Ⅲ = 수치 ×2·×3 · zz = 잠듦"), 16, P2Ui.C_DIM, 760)
	sub.position = Vector2(24, 70)
	p.add_child(sub)
	_arr = {"p": p, "slots": [], "sel": sel}
	var sw := 112.0
	var gap := 36.0
	var x0 := (784.0 - (cap * sw + (cap - 1) * gap)) / 2.0
	var detail := Control.new()
	detail.position = Vector2(0, 254)
	detail.size = Vector2(784, 170)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(detail)
	for k in range(cap):
		var slot := Panel.new()
		var on := k == sel and k < held.size()
		slot.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_GOLD if on else P2Ui.C_EDGE, 0.97))
		slot.position = Vector2(x0 + k * (sw + gap), 108)
		slot.size = Vector2(sw, sw)
		slot.pivot_offset = slot.size / 2.0
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(slot)
		(_arr.slots as Array).append(slot)
		var no := _tx_label(str(k + 1), 12, Color(P2Ui.C_DIM, 0.7))
		no.position = Vector2(6, 2)
		no.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(no)
		if k >= held.size():
			var em := _tx_label(tr("빈 칸"), 16, Color(P2Ui.C_DIM, 0.55))
			em.position = Vector2(0, 44)
			em.size = Vector2(sw, 24)
			em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			em.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(em)
			continue
		var id := String(held[k])
		var n := int(lv.get(id, 1))
		var ic := P2Ui.tex_icon(P2Ui.relic_tex(id), 64)
		ic.position = Vector2((sw - 64.0) / 2.0, 12)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ic)
		var nm := _tx_label(String(P2Catalog.RELICS[id].name), 12, P2Ui.C_GOLD if on else P2Ui.C_TEXT)
		nm.position = Vector2(4, 82)
		nm.size = Vector2(sw - 8, 20)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(nm)
		if n <= 0:
			ic.modulate = Color(0.42, 0.42, 0.5, 0.8)
			var z := P2Ui.outlined(_tx_label("zz", 20, P2Ui.C_DIM), 3)
			z.position = Vector2(sw - 34, 4)
			z.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(z)
		elif n >= 2:
			var med := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#3a2a10")
			sb.border_color = P2Ui.C_GOLD
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(14)
			med.add_theme_stylebox_override("panel", sb)
			med.position = Vector2(sw - 34, 6)
			med.size = Vector2(28, 28)
			med.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(med)
			var ml := _tx_label(["", "", "Ⅱ", "Ⅲ"][clampi(n, 0, 3)], 16, P2Ui.C_GOLD)
			ml.size = Vector2(28, 28)
			ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			med.add_child(ml)
		var kk := k
		slot.mouse_entered.connect(func() -> void: _relic_detail(detail, kk, links, lv))
		slot.mouse_exited.connect(func() -> void: _relic_detail(detail, int(_arr.get("sel", 0)), links, lv))
	# 칸 사이 틈: 위 = 왼쪽 칸이 오른쪽에, 아래 = 오른쪽 칸이 왼쪽에
	for e in links:
		var a := int(e[0])
		var b := int(e[1])
		var gx := x0 + mini(a, b) * (sw + gap) + sw
		var right := b > a
		var up := String(e[2]) == "up"
		var arrow := P2Ui.outlined(_tx_label("▶" if right else "◀", 24, P2Ui.C_GOLD if up else Color("#8a8fa8")), 3)
		arrow.position = Vector2(gx, 108 + (22.0 if right else 58.0))
		arrow.size = Vector2(gap, 28)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(arrow)
		var amt := _tx_label("+%d" % int(e[3]) if up else tr("잠"), 12, P2Ui.C_GOLD if up else Color("#8a8fa8"))
		amt.position = Vector2(gx, 108 + (46.0 if right else 82.0))
		amt.size = Vector2(gap, 16)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(amt)
	P2Ui.rule(p, Vector2(24, 244), 736.0, Color(P2Ui.C_GOLD, 0.3))
	_relic_detail(detail, sel, links, lv)
	var done := _tx_button(tr("닫기"), Vector2(312, 446), Vector2(160, 50), 20)
	done.pressed.connect(func() -> void:
		close_modal()
		if dungeon != null:
			dungeon.set_locked(false))
	p.add_child(done)
	_confirm_button = done


# 석판이 실제로 영향을 주는 쌍: [석판 칸, 대상 칸, "up"(올림)|"sleep"(재움), 올린 단계]. 효과 없는 쌍(석판·마나 유물 올림, 이미 잠든 것)은 빼고
func _slab_links(held: Array, lv: Dictionary) -> Array:
	var out: Array = []
	for i in range(held.size()):
		var id := String(held[i])
		if int(lv.get(id, 1)) <= 0:
			continue
		var raw: Array = {"mirror_slab": [[1, "up", 1]], "wedge_slab": [[1, "up", 2], [-1, "sleep", 0]], "bridge_slab": [[-1, "up", 1], [1, "up", 1]],
			"seal_slab": [[-1, "sleep", 0], [1, "sleep", 0]]}.get(id, [])
		for r in raw:
			var j := i + int(r[0])
			if j < 0 or j >= held.size():
				continue
			var t := String(held[j])
			if String(r[1]) == "up" and (P2Catalog.SLABS.has(t) or P2Catalog.NO_LEVEL.has(t) or int(lv.get(t, 1)) <= 0):
				continue
			out.append([i, j, String(r[1]), int(r[2])])
	return out


# 아래 설명: 아이콘 · 이름 · 효과 · 단계(누가 올렸는지/재웠는지)
func _relic_detail(box: Control, k: int, links: Array, lv: Dictionary) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var held: Array = model.run.relics
	if k < 0 or k >= held.size():
		var none := _tx_label(tr("아직 유물이 없습니다 — 보상에서 고르면 여기 칸에 끼워집니다"), 20, P2Ui.C_DIM, 700)
		none.position = Vector2(40, 30)
		box.add_child(none)
		return
	var id := String(held[k])
	var ic := P2Ui.tex_icon(P2Ui.relic_tex(id), 64)
	ic.position = Vector2(40, 8)
	box.add_child(ic)
	var nm := P2Ui.outlined(_tx_label(String(P2Catalog.RELICS[id].name), 24, P2Ui.C_GOLD), 3)
	nm.position = Vector2(124, 4)
	box.add_child(nm)
	var tx := _tx_label(String(P2Catalog.RELICS[id].text), 20, P2Ui.C_TEXT, 620)
	tx.position = Vector2(124, 40)
	box.add_child(tx)
	var why: Array[String] = []
	for e in links:
		if int(e[1]) == k:
			var from := String(held[int(e[0])])
			why.append(tr("%d번 칸 %s이(가) %s") % [int(e[0]) + 1, String(P2Catalog.RELICS[from].name), (tr("+%d단계") % int(e[3])) if String(e[2]) == "up" else tr("재움")])
	var n := int(lv.get(id, 1))
	var line := ""
	if P2Catalog.SLABS.has(id):
		line = tr("석판 — 옆 칸에만 영향 (석판끼리는 단계를 주고받지 않음)")
	elif n <= 0:
		line = tr("잠듦 — 꺼져 있음 · ") + ", ".join(PackedStringArray(why))
	elif n >= 2:
		line = tr("%d단계 — 수치 ×%d · ") % [n, n] + ", ".join(PackedStringArray(why))
	elif P2Catalog.NO_LEVEL.has(id):
		line = tr("단계가 없는 유물")
	else:
		line = tr("1단계 — 옆에 거울·쐐기·다리 석판을 두면 올라감")
	var ll := _tx_label(line, 16, P2Ui.C_GOOD if n >= 2 else (Color("#8a8fa8") if n <= 0 else P2Ui.C_DIM), 620)
	ll.position = Vector2(124, 120)
	box.add_child(ll)


func _arr_slot_at(pos: Vector2) -> int:
	for k in range((_arr.get("slots", []) as Array).size()):
		var s: Control = _arr.slots[k]
		if is_instance_valid(s) and s.get_global_rect().grow(6.0).has_point(pos):
			return k
	return -1


func _arr_input(event: InputEvent) -> void:
	var held: Array = model.run.relics
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var k := _arr_slot_at(mb.position)
			_arr_drag = {"from": k, "start": mb.position, "at": mb.position, "live": false} if k >= 0 and k < held.size() else {}
		elif not _arr_drag.is_empty():
			var d := _arr_drag
			_arr_drag = {}
			if is_instance_valid(d.get("tok")):
				(d.tok as Control).queue_free()
			if not bool(d.live):
				return
			var to := _arr_slot_at(mb.position)
			if to >= held.size():
				to = held.size() - 1
			if to < 0 or to == int(d.from):
				var src: Control = _arr.slots[int(d.from)]
				src.modulate = Color.WHITE
				return
			var a := int(d.from)
			var moved := String(held[a])
			if await _saved(model.move_relic(a, to)):
				P2Ui.ui_sound("click")
				show_relics(to, moved)
				for j in [a, to]:
					var s: Control = _arr.slots[j]
					s.scale = Vector2.ONE * 1.25
					s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif event is InputEventMouseMotion and not _arr_drag.is_empty():
		var at := (event as InputEventMouseMotion).position
		_arr_drag.at = at
		if not bool(_arr_drag.live) and at.distance_to(_arr_drag.start) > 8.0:
			_arr_drag.live = true
			var src: Control = _arr.slots[int(_arr_drag.from)]
			src.modulate = Color(1, 1, 1, 0.4)
			var tok := P2Ui.tex_icon(P2Ui.relic_tex(String(held[int(_arr_drag.from)])), 56)
			tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tok.pivot_offset = Vector2(28, 28)
			_overlay.add_child(tok)
			_arr_drag.tok = tok
			P2Ui.ui_sound("hover")
		if bool(_arr_drag.live) and is_instance_valid(_arr_drag.get("tok")):
			var tok: Control = _arr_drag.tok
			tok.position = at - Vector2(28, 28)
			var over := _arr_slot_at(at)
			for k in range((_arr.slots as Array).size()):
				var s: Control = _arr.slots[k]
				s.scale = Vector2.ONE * (1.08 if k == over and k != int(_arr_drag.from) else 1.0)


# 카드 보상: 실제 후보를 전투와 같은 카드 그림으로 한 줄 (고르기와 받기는 따로). 카드마다 덱 보유 수 한 줄만
func _reward_cards(p: Panel, parent: Control, part: Dictionary, y: float) -> float:
	var deck: Array = model.run.deck
	var cid := String(model.run.class_id)
	y = _section(parent, tr("한 장을 고르고 [선택 확정] · 건너뛰어도 됨"), y)
	var row: Array = []
	var own: Array = P2Catalog.CLASS_CARD_POOL.get(cid, [])
	var n := (part.cards as Array).size()
	var x := 592.0 - (n * 252.0 - 24.0) / 2.0
	for kind in part.cards:
		var k: String = kind
		var sample := P2Catalog.build_card(k, "preview")
		var b := _pick_tile(parent, Vector2(x, y), Vector2(228, 404), row, k, func() -> void:
			_sel.card = k
			_sel.erase("skip")
			if _skip_button != null:
				P2Ui.mark(_skip_button, false)
			_update_confirm(p))
		b.tooltip_text = P2Catalog.long_text(k)
		var face := P2Ui.card_art(sample, cid, 3, "", true)
		face.position = Vector2(12, 12)
		b.add_child(face)
		var have := deck.filter(func(e): return String(e.kind) == k).size()
		var pool := tr("직업") if own.has(k) else (tr("공용") if P2Catalog.COMMON_CARD_POOL.has(k) else tr("다른 직업"))
		var ok := RunModel.card_eligible(k, deck)
		var info := _tx_label(pool + "\n" + tr("덱에 %d장 / 최대 %d") % [have, P2Catalog.copy_cap(k)] if ok else tr("사본 한도라 고를 수 없음"), 16, P2Ui.C_DIM if ok else P2Ui.C_WARN)
		info.position = Vector2(8, 346)
		info.size = Vector2(212, 48)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(info)
		b.disabled = not ok
		_tiles.append(b)
		var by := y
		b.pivot_offset = b.size / 2.0
		b.position.y = by + 60.0
		b.modulate.a = 0.0
		var deal := b.create_tween().set_parallel()
		deal.tween_property(b, "position:y", by, 0.26).set_delay(0.06 * (_tiles.size() - 1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal.tween_property(b, "modulate:a", 1.0, 0.14).set_delay(0.06 * (_tiles.size() - 1))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				b.create_tween().tween_property(b, "position:y", by - 10.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "position:y", by, 0.12))
		x += 252
	var skip := _tx_button(tr("건너뛰기 (덱을 그대로)"), Vector2(24, 584), Vector2(250, 50), 16)
	skip.pressed.connect(func() -> void:
		_sel.erase("card")
		_sel.skip = true
		for o in row:
			P2Ui.mark(o, false)
		P2Ui.mark(skip, true)
		_update_confirm(p))
	p.add_child(skip)
	_skip_button = skip
	return y + 412


func _reward_card_fly(kind: String) -> void:
	var tile: Control = null
	var chip: Control = null
	for t in reward_tiles():
		if String((t as Node).get_meta("id", "")) == kind:
			tile = t
		else:
			(t as Control).create_tween().tween_property(t, "modulate:a", 0.0, 0.12)
	if tile == null or not tile.is_inside_tree():
		return
	var win := tile.get_parent()
	while win != null and not win.has_meta("deck_chip"):
		win = win.get_parent()
	if win != null:
		chip = win.get_meta("deck_chip")
	var to := chip.get_global_rect().position + Vector2(18, 17) if chip != null and is_instance_valid(chip) else Vector2(1200, 40)
	if _confirm_button != null:
		_confirm_button.disabled = true
	tile.z_index = 10
	tile.pivot_offset = tile.size / 2.0
	var t := tile.create_tween()
	t.tween_property(tile, "scale", Vector2.ONE * 1.08, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tile, "global_position", to - tile.size / 2.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(tile, "scale", Vector2.ONE * 0.1, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(tile, "rotation", 0.6, 0.26)
	P2Ui.ui_sound("open")
	await t.finished
	if chip != null and is_instance_valid(chip):
		chip.pivot_offset = chip.size / 2.0
		var pop := chip.create_tween()
		pop.tween_property(chip, "scale", Vector2.ONE * 1.25, 0.06)
		pop.tween_property(chip, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		P2Ui.ui_sound("click")
		await pop.finished


func _reward_categories(p: Panel, part: Dictionary) -> void:
	var cats: Array = ["upgrade", "heal"] if String(part.type) == "upgrade_or_heal" else ["upgrade", "relic"]
	var x := 24.0
	var tabs: Array[Button] = []
	var area := Control.new()
	area.position = Vector2(0, 126)
	area.size = Vector2(1184, 450)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(area)
	var note := tr("둘 중 하나만 받습니다") + (tr(" · 위험 전투라 유물 후보 보장") if bool(part.get("relic_guaranteed", false)) else "")
	_section(area, note, 0.0)
	var usable := {"upgrade": not (part.get("upgrades", []) as Array).is_empty(), "heal": int(model.run.hp) < int(model.run.max_hp),
		"relic": not (part.get("relics", []) as Array).is_empty()}
	var any := false
	for cat in cats:
		any = any or bool(usable[cat])
	if not any:
		cats.append("gold")
		usable["gold"] = true
	for cat in cats:
		var label := tr(String(CATEGORY_NAMES[cat]))
		if cat == "heal":
			label = tr("회복 +%d") % int(part.get("heal", P2Catalog.FINAL_HEAL)) if bool(usable.heal) else tr("회복 (체력 가득)")
		elif cat == "gold":
			label = _substitute_text()
		elif not bool(usable[cat]):
			label += tr(" (후보 없음)")
		var b := _tx_button(label, Vector2(x, 76), Vector2(240, 44), 16)
		b.disabled = not bool(usable[cat])
		b.set_meta("id", cat)
		tabs.append(b)
		var c: String = cat
		b.pressed.connect(func() -> void:
			_sel = {"category": c}
			_tiles.clear()
			_replace_tiles.clear()
			_skip_button = null
			for o in tabs:
				P2Ui.mark(o, o.get_meta("id") == c)
			for ch in area.get_children():
				ch.queue_free()
			match c:
				"upgrade":
					_reward_upgrades(p, area, part, 0.0)
				"relic":
					_reward_relics(p, area, part, 0.0, true)
				"heal":
					_section(area, tr("체력 %d → %d") % [int(model.run.hp), mini(int(model.run.max_hp), int(model.run.hp) + int(part.get("heal", P2Catalog.FINAL_HEAL)))], 0.0)
				"gold":
					_section(area, tr("고를 수 있는 것이 없어 대신 %s을(를) 받습니다.") % _substitute_text(), 0.0)
			_update_confirm(p))
		p.add_child(b)
		x += 250
	# 더 고를 것이 있는 칸(강화 · 유물)이 쓸 수 있으면 처음부터 펼쳐 둔다(받기는 여전히 [선택 확정])
	for b in tabs:
		if not b.disabled and String(b.get_meta("id")) in ["upgrade", "relic"]:
			b.pressed.emit()
			break


# 다음 위협: 아래 확정 단추 위에 칩 하나, 자세한 행동은 도움말
func _next_threat(p: Panel, _pos: Vector2) -> void:
	var sector := String(model.run.sector)
	var order: Array = []
	match sector:
		"normal":
			order = ["n1", "n2", "n3", "n4", "boss"]
		"hard":
			var route := String(model.run.get("route", ""))
			order = (["h1" + route] if route != "" else []) + ["h2", "hboss"]
		"extreme":
			order = ["x1", "x2", "xboss"]
	var next := ""
	for id in order:
		if not (model.run.defeated as Array).has(id) and model.run.layout.encounters.has(id):
			next = id
			break
	if next == "":
		return
	var g := String(model.run.layout.encounters[next].group)
	var c := P2Ui.chip(P2Ui.kit_tex("intent_attack", 1), tr("다음: %s") % P2Catalog.GROUPS[g].name, P2Ui.C_DIM)
	c.position = Vector2(1164 - c.size.x, 540)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.tooltip_text = " / ".join(PackedStringArray(P2Catalog.group_lines(g)))
	p.add_child(c)


func _reward_valid() -> bool:
	var part := model.current_part()
	if part.is_empty():
		return false
	var full := (model.run.relics as Array).size() >= P2Catalog.relic_capacity(model.run)
	var relic_ok := func(required: bool) -> bool:
		if bool(_sel.get("skip", false)):
			return not required
		if String(_sel.get("relic", "")) == "":
			return false
		return not full or _sel.has("replace")
	match String(part.type):
		"trait":
			return (part.get("traits", []) as Array).is_empty() or _sel.has("trait")
		"card":
			return bool(_sel.get("skip", false)) or (_sel.has("card") and RunModel.card_eligible(String(_sel.card), model.run.deck))
		"upgrade":
			return (part.upgrades as Array).is_empty() or _sel.has("upgrade")
		"relic":
			return relic_ok.call(false)
		"upgrade_or_heal", "upgrade_or_relic":
			match String(_sel.get("category", "")):
				"upgrade":
					return _sel.has("upgrade")
				"relic":
					return relic_ok.call(true)
				"heal", "gold":
					return true
	return false


func _update_confirm(p: Panel) -> void:
	(p.get_meta("confirm") as Button).disabled = not _reward_valid()
	if p.has_meta("summary"):
		(p.get_meta("summary") as Label).text = _reward_summary()


# 아래 요약: 지금 고른 것(받기 전) — 고르기와 받기를 구분해 보인다
func _reward_summary() -> String:
	var part := model.current_part()
	if part.is_empty():
		return ""
	if bool(_sel.get("skip", false)):
		return tr("건너뛰기를 골랐습니다 — 확정하면 이번 보상은 받지 않습니다")
	var kind := String(part.type)
	if kind in ["upgrade_or_heal", "upgrade_or_relic"]:
		kind = String(_sel.get("category", ""))
		if kind == "":
			return tr("받을 것 하나를 위에서 고르세요")
	match kind:
		"trait":
			if _sel.has("trait"):
				var td: Dictionary = P2Catalog.TRAITS[String(_sel.trait)]
				return tr("고른 특성: %s — %s") % [td.name, td.text]
			return tr("특성을 하나 고르세요 (원정 끝까지 유지)")
		"card":
			if _sel.has("card"):
				var c := P2Catalog.build_card(String(_sel.card), "preview")
				return tr("고른 카드: %s — %s (확정하면 덱에 1장 추가)") % [c.card_name, String(P2Catalog.face(c, String(model.run.class_id))[0])]
			return tr("카드를 하나 고르거나 건너뛰세요")
		"upgrade":
			if _sel.has("upgrade"):
				var up := String(_sel.upgrade)
				return tr("고른 강화: %s → %s (사본 한 장)") % [P2Catalog.card_name(String(P2Catalog.UPGRADE_KINDS[up].from)), P2Catalog.UPGRADES[up].name]
			if (part.get("upgrades", []) as Array).is_empty():
				return tr("대신 %s을(를) 받습니다") % _substitute_text()
			return tr("강화를 하나 고르세요")
		"relic":
			var full := (model.run.relics as Array).size() >= P2Catalog.relic_capacity(model.run)
			if not _sel.has("relic"):
				return tr("유물을 하나 고르세요")
			var s := tr("새 유물: %s") % P2Catalog.RELICS[String(_sel.relic)].name
			if full:
				if _sel.has("replace"):
					s += "  ↔  " + tr("버릴 유물: %s") % P2Catalog.RELICS[String(_sel.replace)].name + "\n" + _relic_drop_text(String(_sel.replace))
				else:
					s += "  ·  " + tr("칸이 가득: 버릴 유물을 고르세요")
			return s
		"heal":
			return tr("회복: 체력 %d → %d") % [int(model.run.hp), mini(int(model.run.max_hp), int(model.run.hp) + int(part.get("heal", P2Catalog.FINAL_HEAL)))]
		"gold":
			return tr("대신 %s을(를) 받습니다") % _substitute_text()
	return ""


func confirm_reward(sel: Dictionary) -> bool:
	if _modal != "reward":
		return false
	var ok := model.choose_reward(sel)
	if not ok and model.has_pending():
		ok = await gate.run()
	if not ok:
		return false
	if sel.has("card"):
		await _reward_card_fly(String(sel.card))
	var slab := P2Catalog.SLABS.has(String(sel.get("relic", "")))
	close_modal()
	dungeon.refresh()
	if slab and String(model.run.phase) == "explore":
		dungeon.set_locked(false)
		show_relics(-1, String(sel.get("relic", "")))
		dungeon.show_message(tr("석판은 자리가 중요합니다 — 끌어서 옆 칸을 고르세요"))
		return true
	match String(model.run.phase):
		"reward":
			show_reward()
		"sector_choice":
			show_sector_choice()
		_:
			dungeon.set_locked(false)
			dungeon.show_message("선택 완료 — 이번 원정: " + RunModel.build_summary(model.run))
			if model.stat_pending() > 0:
				show_level()
	return true


# ── 레벨 업: 능력치 셋 중 하나 (미뤄도 됨, 지도 위 띠의 레벨 칩으로 다시 연다) ─────────────────────

func show_level() -> void:
	if model.run.is_empty() or model.stat_pending() == 0 or String(model.run.phase) == "battle":
		return
	close_modal()
	if dungeon != null:
		dungeon.set_locked(true)
	_modal = "level"
	_sel = {}
	_tiles.clear()
	var run := model.run
	var picks: Array = run.lv_picks
	var lv := int(run.lv) - picks.size() + 1
	var p := _win(Vector2(110, 70), Vector2(1060, 580), tr("레벨 업 · 원정 레벨 %d") % lv, P2Ui.C_GOLD)
	var y := _section(p, tr("능력치 하나를 고르세요 · 이번 원정 동안 유지") + (tr(" · 남은 고르기 %d번") % picks.size() if picks.size() > 1 else ""), 76.0)
	var board := P5StatBoard.make(run, 300.0)
	board.position = Vector2(24, y)
	p.add_child(board)
	_level_board = board
	var st: Dictionary = P2Catalog.stats_with_relics(run.get("stats", {}), run.get("relics", []))
	var row: Array = []
	var x := 340.0
	var th := board.size.y
	var n := 0
	for o in picks[0]:
		var id := String(o.stat)
		var amount := int(o.amount)
		var rare := bool(o.get("rare", false))
		var d: Dictionary = P2Catalog.STATS[id]
		var b := _pick_tile(p, Vector2(x, y), Vector2(226, th), row, id, func() -> void:
			_sel = {"stat": id}
			board.preview(id, amount)
			(p.get_meta("confirm") as Button).disabled = false)
		b.set_meta("amount", amount)
		b.pivot_offset = Vector2(113, th / 2.0)
		var ic := P2Ui.tex_icon(P2Ui.kit_tex(String(d.icon), 1), 64)
		ic.position = Vector2(81, 28)
		b.add_child(ic)
		var nm := P2Ui.outlined(_tx_label("%s +%d" % [String(d.name), amount], 32, P2Ui.C_GOLD if rare else P2Ui.C_TEXT), 3)
		nm.position = Vector2(0, 108)
		nm.size = Vector2(226, 44)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(nm)
		if rare:
			var tag := _tx_label(tr("희귀 · 두 배"), 16, P2Ui.C_MARK)
			tag.position = Vector2(0, 152)
			tag.size = Vector2(226, 24)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.pivot_offset = Vector2(113, 12)
			b.add_child(tag)
			var shine := tag.create_tween().set_loops()
			shine.tween_property(tag, "scale", Vector2.ONE * 1.12, 0.4).set_trans(Tween.TRANS_SINE)
			shine.tween_property(tag, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
		var body := _tx_label(P2Catalog.stat_text(id, amount), 16, P2Ui.C_TEXT, 196)
		body.position = Vector2(15, 186)
		body.size = Vector2(196, 110)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(body)
		var now := int(st.get(id, 0))
		var after := _tx_label(tr("지금 %s → %s") % [P5StatBoard.value_text(id, now), P5StatBoard.value_text(id, now + amount)], 16, P2Ui.C_DIM)
		after.position = Vector2(0, th - 40)
		after.size = Vector2(226, 24)
		after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(after)
		b.mouse_entered.connect(func() -> void:
			board.preview(id, amount)
			if not b.disabled:
				b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.03, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		b.mouse_exited.connect(func() -> void:
			var cur := String(_sel.get("stat", ""))
			var amt := 0
			for t in _tiles:
				if is_instance_valid(t) and String(t.get_meta("id")) == cur:
					amt = int(t.get_meta("amount"))
			board.preview(cur, amt)
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
		b.modulate.a = 0.0
		b.scale = Vector2.ONE * 0.86
		var pop := b.create_tween().set_parallel()
		pop.tween_property(b, "modulate:a", 1.0, 0.12).set_delay(0.05 + 0.07 * n)
		pop.tween_property(b, "scale", Vector2.ONE, 0.22).set_delay(0.05 + 0.07 * n).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tiles.append(b)
		x += 238
		n += 1
	var later := _tx_button(tr("나중에 고르기"), Vector2(24, 504), Vector2(220, 50), 16)
	later.pressed.connect(func() -> void:
		close_modal()
		if dungeon != null:
			dungeon.set_locked(false)
			dungeon.refresh())
	p.add_child(later)
	var confirm := P2Ui.primary(_tx_button(tr("고르기"), Vector2(816, 504), Vector2(220, 50), 24))
	confirm.disabled = true
	confirm.pressed.connect(func() -> void: confirm_level(String(_sel.get("stat", ""))))
	p.add_child(confirm)
	p.set_meta("confirm", confirm)
	_confirm_button = confirm


# 고를 것이 없을 때 레벨 칩: 능력치 판만 (닫기)
func show_stats() -> void:
	if model.run.is_empty() or _modal_busy():
		return
	close_modal()
	if dungeon != null:
		dungeon.set_locked(true)
	_modal = "stats"
	var board := P5StatBoard.make(model.run, 320.0, false)
	var p := _win(Vector2(470, 640 - board.size.y - 160), Vector2(340, board.size.y + 150), tr("능력치"), P2Ui.C_GOLD)
	board.position = Vector2(10, 70)
	p.add_child(board)
	var done := _tx_button(tr("닫기"), Vector2(90, board.size.y + 82), Vector2(160, 50), 20)
	done.pressed.connect(func() -> void:
		close_modal()
		if dungeon != null:
			dungeon.set_locked(false))
	p.add_child(done)
	_confirm_button = done


func confirm_level(id: String) -> bool:
	if _modal != "level" or id == "":
		return false
	var amount := 0
	var first: Array = (model.run.lv_picks as Array)[0] if not (model.run.lv_picks as Array).is_empty() else []
	for o in first:
		if String(o.stat) == id:
			amount = int(o.amount)
	var ok := model.choose_stat(id)
	if not ok and model.has_pending():
		ok = await gate.run()
	if not ok:
		return false
	if _level_board != null and is_instance_valid(_level_board):
		if _confirm_button != null:
			_confirm_button.disabled = true
		for t in _tiles:
			if not is_instance_valid(t):
				continue
			var mine := String(t.get_meta("id")) == id
			(t as Button).disabled = true
			var tw := (t as Control).create_tween()
			if mine:
				tw.tween_property(t, "scale", Vector2.ONE * 1.08, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(t, "scale", Vector2.ONE, 0.18)
			else:
				tw.tween_property(t, "modulate:a", 0.3, 0.15)
		_level_board.bump(id, amount)
		P2Ui.ui_sound("click")
		await get_tree().create_timer(0.55).timeout
		if _modal != "level":
			return true
	_level_board = null
	close_modal()
	_sync_view_stats()
	if dungeon != null:
		dungeon.refresh()
	if model.stat_pending() > 0:
		show_level()
	elif dungeon != null:
		dungeon.set_locked(false)
		dungeon.show_message(tr("능력치: ") + " · ".join(PackedStringArray(P2Ui.stat_chips(model.run).map(func(c): return String(c[1])))))
	return true


# ── 상인 (서비스 지점) ────────────────────────────────────────────────────────────

# 상인: 이번 구간 미확정 금화로만 거래. 서비스 넷을 그림 칸으로(진열 카드는 실제 카드 그림), 값은 금화 칩
func show_service() -> void:
	if _modal_busy():
		return
	close_modal()
	dungeon.set_locked(true)
	_modal = "service"
	_sel = {}
	var run := model.run
	var p := _win(Vector2(60, 30), Vector2(1160, 660), tr("상인"), P2Ui.C_GOLD)
	var wallet := P2Ui.chip(P2Ui.kit_tex("hud_coin", 1), tr("미확정 금화 %d") % int(run.gold), P2Ui.C_GOLD, 40.0)
	wallet.position = Vector2(1100 - wallet.size.x, 12)
	p.add_child(wallet)
	var s := _tx_label(tr("이번 구간에서 번 금화로만 거래 · 쓴 만큼 보스 정산에서 빠짐 · 서비스마다 한 번"), 20, P2Ui.C_DIM)
	s.position = Vector2(24, 70)
	p.add_child(s)
	var card_kind := String(run.service.card)
	var entries := [
		["card", tr("카드 사기"), P2Catalog.SHOP_CARD, tr("진열 카드 한 장을 덱에") if card_kind != "" else tr("진열된 카드 없음"), null],
		["upgrade", tr("사본 강화"), P2Catalog.SHOP_UPGRADE, tr("사본 한 장 강화\n(고른 뒤 전·후 비교)"), P2Ui.kit_tex("status_crit", 1)],
		["heal", tr("치료"), P2Catalog.SHOP_HEAL, tr("체력 +%d") % model.heal_amount_shop() + "\n" + tr("(%d → %d)") % [int(run.hp), mini(int(run.max_hp), int(run.hp) + model.heal_amount_shop())], P2Ui.kit_tex("potion_health", 1)],
		["remove", tr("카드 제거"), model.removal_price(), tr("덱에서 한 장 빼기\n(할 때마다 +%d금화)") % P2Catalog.SHOP_REMOVE_STEP, P2Ui.kit_tex("pile_exhaust", 1)],
	]
	for k in range(entries.size()):
		var e: Array = entries[k]
		var what := String(e[0])
		var why := model.service_block(what)
		var b := _shop_tile(p, Vector2(24 + k * 276, 112), Vector2(262, 452), e, why)
		match what:
			"card", "heal":
				b.pressed.connect(func() -> void: _shop(what, {}))
			"upgrade":
				b.pressed.connect(func() -> void: _pick_copy_then_upgrade(func(sel: Dictionary) -> void: _shop("upgrade", sel), tr("사본 강화 (%d금화)") % P2Catalog.SHOP_UPGRADE))
			"remove":
				b.pressed.connect(func() -> void: _pick_copy_to_remove())
	var close := _tx_button(tr("떠나기"), Vector2(24, 580), Vector2(200, 50), 20)
	close.pressed.connect(func() -> void:
		close_modal()
		dungeon.refresh()
		dungeon.set_locked(false))
	p.add_child(close)


# 상인 칸 하나: 위에 그림(진열 카드는 실제 카드), 이름, 짧은 효과, 아래 값 칩. 막혔으면 이유를 값 대신
func _shop_tile(p: Control, pos: Vector2, size: Vector2, e: Array, why: String) -> Button:
	var b := P2Ui.button("", pos, size)
	b.set_meta("skin", "tile")
	P2Ui.mark(b, false)
	b.disabled = why != ""
	b.focus_mode = Control.FOCUS_ALL
	p.add_child(b)
	if String(e[0]) == "card" and String(model.run.service.card) != "":
		var c := P2Catalog.build_card(String(model.run.service.card), "preview")
		var face := P2Ui.card_art(c, String(model.run.class_id), 2, "", true)
		face.position = Vector2(size.x / 2.0 - 68.0, 10)
		b.add_child(face)
		b.tooltip_text = P2Catalog.long_text(String(model.run.service.card))
	elif e[4] != null:
		var ic := P2Ui.tex_icon(e[4], 96)
		ic.position = Vector2(size.x / 2.0 - 48.0, 70)
		b.add_child(ic)
	var nm := P2Ui.outlined(_tx_label(String(e[1]), 24, P2Ui.C_GOLD if why == "" else P2Ui.C_DIM), 3)
	nm.position = Vector2(0, 236)
	nm.size = Vector2(size.x, 30)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(nm)
	var fx := _tx_label(String(e[3]), 20, P2Ui.C_TEXT if why == "" else P2Ui.C_DIM)
	fx.position = Vector2(10, 276)
	fx.size = Vector2(size.x - 20, 60)
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(fx)
	if why == "":
		var price := P2Ui.chip(P2Ui.kit_tex("hud_coin", 1), str(int(e[2])), P2Ui.C_GOLD, 40.0)
		price.position = Vector2(size.x / 2.0 - price.size.x / 2.0, size.y - 64)
		b.add_child(price)
	else:
		var no := _tx_label(why, 20, P2Ui.C_WARN, size.x - 24)
		no.position = Vector2(12, size.y - 92)
		no.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(no)
	return b


func _shop(what: String, sel: Dictionary) -> void:
	var ok := await _saved(model.shop_buy(what, sel))
	close_modal()
	dungeon.refresh()
	show_service()
	if ok:
		dungeon.show_message("거래 완료 — 이번 구간 금화 %d 남음" % int(model.run.gold))


# 사본을 먼저 고르고(카드 그림), 그 카드에 맞는 강화를 강화 전·후로 비교해 고른다 (숨은 자동 대상 없음)
func _pick_copy_then_upgrade(done: Callable, title: String) -> void:
	close_modal()
	_modal = "pick_copy"
	var p := P2Ui.panel(_overlay, Vector2(40, 24), Vector2(1200, 672), true, P2Ui.C_GOLD)
	var t := _tx_label(title + tr(" — 강화할 사본 고르기"), 24, P2Ui.C_GOLD)
	t.position = Vector2(24, 12)
	p.add_child(t)
	var copies := RunModel.upgradable_copies(model.run.deck)
	var cid := String(model.run.class_id)
	var area := Control.new()
	area.position = Vector2(0, 286)
	area.size = Vector2(1184, 300)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(area)
	var x := 24.0
	var row: Array = []
	for c in model.run.deck:
		if not copies.has(String(c.uid)):
			continue
		var uid := String(c.uid)
		var kind := String(c.kind)
		var b := _pick_tile(p, Vector2(x, 50), Vector2(144, 226), row, uid, func() -> void:
			for ch in area.get_children():
				ch.queue_free()
			var ux := 24.0
			for up in copies[uid]:
				var u := String(up)
				var ob := _tx_button("%s → %s" % [P2Catalog.card_name(kind), P2Catalog.UPGRADES[u].name], Vector2(ux, 0), Vector2(300, 44), 16)
				ob.tooltip_text = String(P2Catalog.UPGRADES[u].text)
				ob.pressed.connect(func() -> void: done.call({"upgrade": u, "copy": uid}))
				area.add_child(ob)
				var after_face := P2Ui.card_art(P2Catalog.build_card(kind, "preview", u), cid, 2)
				after_face.position = Vector2(ux + 82, 52)
				area.add_child(after_face)
				ux += 320
			var note := _tx_label(tr("강화 이름을 누르면 바로 거래합니다 (사본 한 장만 바뀜). 오른쪽 카드는 강화 뒤 모습."), 16, P2Ui.C_DIM, 1100)
			note.position = Vector2(24, 276)
			area.add_child(note))
		var face := P2Ui.card_art(P2Catalog.make_card(c), cid, 2)
		face.position = Vector2(4, 4)
		b.add_child(face)
		_hover_card(b, P2Catalog.make_card(c))
		x += 152
		if x > 1060:
			break
	var back := _tx_button(tr("뒤로"), Vector2(24, 590), Vector2(180, 48), 16)
	back.pressed.connect(func() -> void:
		close_modal()
		if _modal_from_choice(title):
			show_choice()
		else:
			show_service())
	p.add_child(back)


func _modal_from_choice(title: String) -> bool:
	return String(model.run.choice.get("picked", "")) == "" and (title.begins_with(tr("체력")) and model.choice_block("sacrifice") == "" or title.begins_with(tr("체력 대신")))


func _pick_copy_to_remove() -> void:
	close_modal()
	_modal = "pick_copy"
	var p := P2Ui.panel(_overlay, Vector2(40, 24), Vector2(1200, 672), true, P2Ui.C_WARN)
	var t := _tx_label(tr("카드 제거 (%d금화) — 뺄 카드 고르기 (누르면 바로 거래)") % model.removal_price(), 24, P2Ui.C_WARN)
	t.position = Vector2(24, 12)
	p.add_child(t)
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 52)
	sc.size = Vector2(1144, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	var cid := String(model.run.class_id)
	for c in model.run.deck:
		var uid := String(c.uid)
		var b := P2Ui.button("", Vector2.ZERO, Vector2(146, 228))
		b.set_meta("skin", "tile")
		P2Ui.mark(b, false)
		b.tooltip_text = P2Catalog.long_text(String(c.kind), String(c.upgrade))
		b.add_child(P2Ui.card_art(P2Catalog.make_card(c), cid, 2))
		(b.get_child(b.get_child_count() - 1) as Control).position = Vector2(5, 5)
		_hover_card(b, P2Catalog.make_card(c))
		b.pressed.connect(func() -> void: _shop("remove", {"copy": uid}))
		grid.add_child(b)
	var back := _tx_button(tr("뒤로"), Vector2(24, 590), Vector2(180, 48), 16)
	back.pressed.connect(func() -> void:
		close_modal()
		show_service())
	p.add_child(back)


# ── 선택 지점 ─────────────────────────────────────────────────────────────────────


func show_choice() -> void:
	if _modal_busy() and _modal != "pick_copy":
		return
	close_modal()
	dungeon.set_locked(true)
	_modal = "choice"
	_tiles.clear()
	var ev := RunModel.event_of(model.run)
	var d: Dictionary = P2Catalog.EVENTS[ev]
	var col: Color = d.col
	var p := _win(Vector2(190, 92), Vector2(900, 540), tr(String(d.name)), col)
	var tag := P2Ui.chip(null, tr("사건 · 하나만 · 한 번"), P2Ui.C_DIM, 40.0)
	tag.position = Vector2(844 - tag.size.x, 12)
	p.add_child(tag)
	var flavor := _tx_label(tr(String(d.text)), 20, P2Ui.C_TEXT, 836)
	flavor.position = Vector2(24, 72)
	p.add_child(flavor)
	var opts: Array = d.opts
	for k in range(opts.size()):
		var what := String(opts[k])
		var why := model.choice_block(what)
		var b := _choice_tile(p, Vector2(24 + k * 432, 130), Vector2(416, 300), _event_entry(what), why)
		b.set_meta("id", what)
		_tiles.append(b)
		match what:
			"sacrifice":
				b.pressed.connect(func() -> void: _pick_copy_then_upgrade(func(sel: Dictionary) -> void: _choose_event("sacrifice", sel), tr("체력 %d 지불 강화") % P2Catalog.SACRIFICE_HP))
			"forge_gold":
				b.pressed.connect(func() -> void: _pick_copy_then_upgrade(func(sel: Dictionary) -> void: _choose_event("forge_gold", sel), tr("체력 대신 금화 %d 강화") % P2Catalog.FORGE_GOLD))
			"burn_card":
				b.pressed.connect(_pick_copy_to_burn)
			_:
				b.pressed.connect(func() -> void: _choose_event(what, {}))
		b.pivot_offset = b.size / 2.0
		b.modulate.a = 0.0
		b.scale = Vector2.ONE * 0.9
		var pop := b.create_tween().set_parallel()
		pop.tween_property(b, "modulate:a", 1.0, 0.14).set_delay(0.08 + 0.08 * k)
		pop.tween_property(b, "scale", Vector2.ONE, 0.22).set_delay(0.08 + 0.08 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pass_b := _tx_button(tr("지나가기 (나중에 와도 됨)"), Vector2(24, 444), Vector2(330, 50), 20)
	pass_b.pressed.connect(func() -> void:
		close_modal()
		dungeon.set_locked(false))
	p.add_child(pass_b)


# 사건 선택지 칸 내용: [id, 이름, 효과 두 줄, 아이콘]
func _event_entry(what: String) -> Array:
	var opt: Dictionary = model.run.layout.encounters.get("elite", {})
	var opt_name := tr("미믹") if String(opt.get("kind", "")) == "mimic" else tr("정예")
	match what:
		"chest_gold":
			return [what, tr("금화 상자"), tr("금화 +%d") % P2Catalog.CHEST_GOLD + "\n" + tr("(이번 구간 미확정)"), P2Ui.kit_tex("hud_coin", 1)]
		"chest_potion":
			return [what, tr("물약 상자"), tr("회복약 1개") + "\n" + tr("(원정 물약 %d/%d)") % [(model.run.potions as Array).size(), P2Catalog.POTION_CAP], P2Ui.kit_tex("potion_health", 1)]
		"sacrifice":
			return [what, tr("피의 강화"), tr("체력 −%d") % P2Catalog.SACRIFICE_HP + "\n" + tr("→ 사본 한 장 강화"), P2Ui.kit_tex("hud_heart", 1)]
		"forge_gold":
			return [what, tr("대장장이에게 맡기기"), tr("미확정 금화 −%d") % P2Catalog.FORGE_GOLD + "\n" + tr("→ 사본 한 장 강화"), P2Ui.kit_tex("hud_coin", 1)]
		"risk":
			return [what, tr("도전 받기"), tr("선택 전투(%s) 공격 +%d") % [opt_name, P2Catalog.RISK_ATTACK] + "\n" + tr("→ 보상에 유물 보장"), P2Ui.kit_tex("intent_heavy", 1)]
		"tear":
			return [what, tr("찢어 버리기"), tr("도전장 뒤 금화 +%d") % P2Catalog.TEAR_GOLD + "\n" + tr("(이번 구간 미확정)"), P2Ui.kit_tex("pile_exhaust", 1)]
		"altar_relic":
			return [what, tr("피를 바치기"), tr("최대 체력 −%d") % P2Catalog.ALTAR_MAXHP + "\n" + tr("→ 유물 셋 중 하나"), P2Ui.relic_tex("rift_heart")]
		"altar_pray":
			return [what, tr("기도"), tr("체력 +%d") % P2Catalog.ALTAR_HEAL + "\n" + tr("(최대 체력까지)"), P2Ui.kit_tex("hud_heart", 1)]
		"burn_card":
			return [what, tr("버릇 태우기"), tr("덱에서 카드 한 장 빼기") + "\n" + tr("(무료)"), P2Ui.kit_tex("pile_exhaust", 1)]
		"copy_card":
			return [what, tr("기술 필사"), tr("카드 셋 중 한 장") + "\n" + tr("(건너뛰어도 됨)"), P2Ui.kit_tex("pile_draw", 1)]
		"echo_stat":
			return [what, tr("몸을 맡기기"), tr("체력 −%d") % P2Catalog.ECHO_HP + "\n" + tr("→ 능력치 한 번 더 고르기"), P2Ui.kit_tex("status_crit", 1)]
		"echo_xp":
			return [what, tr("귀 기울이기"), tr("원정 경험치 +%d") % P2Catalog.ECHO_XP, P2Ui.kit_tex("status_resonance", 1)]
	return [what, what, "", P2Ui.kit_tex("intent_unknown", 1)]


# 서고: 태울 카드 고르기 (누르면 바로)
func _pick_copy_to_burn() -> void:
	close_modal()
	_modal = "pick_copy"
	var p := P2Ui.panel(_overlay, Vector2(40, 24), Vector2(1200, 672), true, P2Ui.C_WARN)
	var t := _tx_label(tr("버릇 태우기 — 뺄 카드 고르기 (누르면 바로)"), 24, P2Ui.C_WARN)
	t.position = Vector2(24, 12)
	p.add_child(t)
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 52)
	sc.size = Vector2(1144, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	var cid := String(model.run.class_id)
	for c in model.run.deck:
		var uid := String(c.uid)
		var b := P2Ui.button("", Vector2.ZERO, Vector2(146, 228))
		b.set_meta("skin", "tile")
		b.set_meta("id", uid)
		P2Ui.mark(b, false)
		b.tooltip_text = P2Catalog.long_text(String(c.kind), String(c.upgrade))
		b.add_child(P2Ui.card_art(P2Catalog.make_card(c), cid, 2))
		(b.get_child(b.get_child_count() - 1) as Control).position = Vector2(5, 5)
		_hover_card(b, P2Catalog.make_card(c))
		b.pressed.connect(func() -> void: _choose_event("burn_card", {"copy": uid}))
		grid.add_child(b)
	var back := _tx_button(tr("뒤로"), Vector2(24, 590), Vector2(180, 48), 16)
	back.pressed.connect(func() -> void:
		close_modal()
		show_choice())
	p.add_child(back)


func _choice_tile(p: Control, pos: Vector2, size: Vector2, e: Array, why: String) -> Button:
	var b := P2Ui.button("", pos, size)
	b.set_meta("skin", "tile")
	P2Ui.mark(b, false)
	b.disabled = why != ""
	b.focus_mode = Control.FOCUS_ALL
	p.add_child(b)
	var ic := P2Ui.tex_icon(e[3], 96)
	ic.position = Vector2(size.x / 2.0 - 48.0, 26)
	if why != "":
		ic.modulate = Color(0.55, 0.55, 0.6)
	b.add_child(ic)
	if String(e[0]) == "sacrifice":
		var up := P2Ui.kit_icon("status_crit", 48)
		up.position = Vector2(size.x / 2.0 + 20.0, 30)
		b.add_child(up)
	var nm := P2Ui.outlined(_tx_label(String(e[1]), 24, P2Ui.C_GOLD if why == "" else P2Ui.C_DIM), 3)
	nm.position = Vector2(0, 140)
	nm.size = Vector2(size.x, 30)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(nm)
	var fx := _tx_label(String(e[2]), 20, P2Ui.C_TEXT if why == "" else P2Ui.C_DIM)
	fx.position = Vector2(8, 182)
	fx.size = Vector2(size.x - 16, 60)
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(fx)
	if why != "":
		var no := _tx_label(why, 20, P2Ui.C_WARN, size.x - 24)
		no.position = Vector2(12, 250)
		no.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(no)
	return b


func _choose_event(what: String, sel: Dictionary) -> void:
	var ok := await _saved(model.choose_event(what, sel))
	close_modal()
	dungeon.refresh()
	if ok and String(model.run.phase) == "reward":
		show_reward()
		return
	dungeon.set_locked(false)
	if ok:
		dungeon.show_message(String({"chest_gold": "금화 %d를 챙겼다 (미확정)." % P2Catalog.CHEST_GOLD, "chest_potion": "회복약을 챙겼다.",
			"sacrifice": "체력 %d를 내고 강화했다." % P2Catalog.SACRIFICE_HP, "risk": "선택 전투가 위험해졌다. 이기면 유물 후보가 보장된다.",
			"forge_gold": "금화 %d를 내고 강화했다." % P2Catalog.FORGE_GOLD, "tear": "도전장을 찢었다. 뒤에 붙어 있던 금화 %d (미확정)." % P2Catalog.TEAR_GOLD,
			"altar_pray": "기도를 올렸다. 몸이 가벼워졌다.", "burn_card": "낡은 버릇 하나를 태웠다.",
			"echo_stat": "메아리가 몸에 스몄다. 능력치를 하나 더 고른다.", "echo_xp": "메아리에 귀 기울였다. 원정 경험치 +%d." % P2Catalog.ECHO_XP}.get(what, "")))
		if model.stat_pending() > 0:
			show_level()


# ── 포탈 · 결과 ──────────────────────────────────────────────────────────────────

func _on_portal() -> void:
	if _modal_busy():
		return
	var summary: Dictionary = model.run.get("settlement", {})
	var ok := await _saved(model.enter_portal())
	if not ok:
		return
	dungeon.set_locked(true)
	await _fade_out()
	show_result(summary if not summary.is_empty() else model.last_result())
	await _fade_in()


const DIFF_COL := {"easy": Color("#8be08b"), "normal": Color("#f3ead7"), "hard": Color("#ff9a6a"), "extreme": Color("#ff5a5a")}
const RANK_COL := {"S": Color("#ffe04a"), "A": Color("#8fe08b"), "B": Color("#8fc3e8"), "C": Color("#f3ead7"), "D": Color("#e0533a")}
const RESULT_HEADINGS := {
	"clear": ["세 구간을 모두 정복했습니다", "gold"],
	"return": ["원정을 마쳤습니다", "gold"],
	"lost": ["원정에서 쓰러졌습니다 — 확정된 구간 보상은 지켜졌습니다", "hp"],
	"abandon": ["원정을 포기했습니다", "warn"],
}


func show_result(summary: Dictionary) -> void:
	_clear_views()
	_modal = "result"
	var bg := ColorRect.new()
	bg.color = Color("#10121a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var result := String(summary.get("result", ""))
	var head: Array = RESULT_HEADINGS.get(result, ["원정 종료", "hp"])
	var col: Color = {"gold": P2Ui.C_GOLD, "hp": P2Ui.C_HP, "warn": P2Ui.C_WARN}[head[1]]
	var p := _win(Vector2(120, 30), Vector2(1040, 660), String(head[0]), col, false)
	var y := 76.0
	# 원정 점수·랭크 · 난이도 · 배지
	var sc: Dictionary = summary.get("score", {})
	var diff := String(summary.get("diff", "normal"))
	if not sc.is_empty():
		var rank := String(sc.get("rank", "D"))
		var rk := P2Ui.outlined(_tx_label(rank, 36, RANK_COL.get(rank, P2Ui.C_TEXT)), 4)
		rk.position = Vector2(930, 6)
		p.add_child(rk)
		var schips: Array = [[null, tr("점수 %d") % int(sc.score), P2Ui.C_GOLD], [null, String(P2Catalog.diff_of(diff).name), DIFF_COL.get(diff, P2Ui.C_TEXT)]]
		for m in summary.get("mods", []):
			schips.append([null, String(P2Catalog.MOD[m].short), P2Ui.C_BLOCK])
		if int(sc.get("fights", 0)) > 0:
			schips.append([P2Ui.kit_tex("status_mark", 1), tr("정확도 %d%%") % int(sc.get("acc", 0))])
		schips.append([null, tr("새 최고 기록!") if bool(sc.get("new_best", false)) else tr("최고 %d") % int(sc.get("prev_best", 0)), P2Ui.C_GOLD if bool(sc.get("new_best", false)) else P2Ui.C_DIM])
		y = _result_row(p, y, tr("원정 점수"), P2Ui.C_GOLD, schips)
	var dres: Dictionary = summary.get("diff_result", {})
	var achv: Array = summary.get("achv", [])
	if String(dres.get("badge", "")) != "" or String(dres.get("opened", "")) != "" or not achv.is_empty():
		var bchips: Array = []
		for a in P2Catalog.ACHIEVEMENTS:
			if achv.has(a[0]):
				bchips.append([P2Ui.kit_tex(String(a[3]), 1), String(a[1]), P2Ui.C_GOLD])
		if String(dres.get("badge", "")) != "":
			bchips.append([P2Ui.kit_tex("status_crit", 1), tr("%s 정복 배지!") % String(P2Catalog.diff_of(String(dres.badge)).name), P2Ui.C_GOLD])
		if String(dres.get("opened", "")) != "":
			bchips.append([null, tr("%s 난이도가 열렸습니다") % String(P2Catalog.diff_of(String(dres.opened)).name), DIFF_COL.get(String(dres.opened), P2Ui.C_TEXT)])
		y = _result_row(p, y, tr("도전과제"), P2Ui.C_GOLD, bchips)
	var banked: Dictionary = summary.get("banked", {})
	for sector in P2Catalog.SECTORS:
		if not banked.has(sector):
			continue
		var b: Dictionary = banked[sector]
		var chips: Array = [[P2Ui.kit_tex("hud_coin", 1), "+%d" % int(b.gold), P2Ui.C_GOLD], [P2Ui.kit_tex("status_resonance", 1), tr("경험치 +%d") % int(b.xp), P2Ui.C_BLOCK]]
		y = _result_row(p, y, String(P2Catalog.SECTOR_NAMES[sector]), P2Ui.C_SAFE, chips)
	if banked.is_empty():
		y = _result_row(p, y, tr("확정"), P2Ui.C_DIM, [[null, tr("확정된 보상 없음"), P2Ui.C_DIM]])
	var forfeit: Dictionary = summary.get("forfeit", {})
	if int(forfeit.get("gold", 0)) > 0 or int(forfeit.get("xp", 0)) > 0:
		y = _result_row(p, y, tr("잃음"), P2Ui.C_HP, [[P2Ui.kit_tex("hud_coin", 1), "-%d" % int(forfeit.get("gold", 0)), P2Ui.C_HP], [P2Ui.kit_tex("status_resonance", 1), tr("경험치 -%d") % int(forfeit.get("xp", 0)), P2Ui.C_HP]])
	var rl: Array = summary.get("rhythm", [])
	if not rl.is_empty():
		var by := {}
		var acc := 0
		var best := 0
		var heal := 0
		for e in rl:
			by[String(e.grade)] = int(by.get(String(e.grade), 0)) + 1
			acc += int(e.acc)
			best = maxi(best, int(e.best))
			heal += int(e.get("heal", 0))
		var chips: Array = [[null, tr("%d전") % rl.size(), P2Ui.C_DIM]]
		for g in ["S", "A", "B", "C", "D"]:
			if by.has(g):
				chips.append([null, "%s × %d" % [g, int(by[g])], P2Ui.C_GOLD if g in ["S", "A"] else P2Ui.C_TEXT])
		chips.append([P2Ui.kit_tex("status_mark", 1), tr("정확도 %d%%") % (acc / rl.size())])
		chips.append([null, tr("최고 연속 %d") % best])
		if heal > 0:
			chips.append([P2Ui.kit_tex("hud_heart", 1), "+%d" % heal, P2Ui.C_GOOD])
		y = _result_row(p, y, tr("전투 성적"), P2Ui.C_TEXT, chips)
	var extra: Array = []
	var traits: Array = summary.get("traits", [])
	for t in traits:
		extra.append([P2Catalog.icon_tex(String(t)), String(P2Catalog.TRAITS[t].name), P2Ui.C_MARK])
	if not extra.is_empty():
		y = _result_row(p, y, tr("그 밖"), P2Ui.C_DIM, extra)
	var build := _tx_label(tr("이번 원정의 빌드 (원정이 끝나면 사라짐): ") + String(summary.get("build", "")), 20, P2Ui.C_DIM, 980)
	build.position = Vector2(24, y + 6)
	p.add_child(build)
	P2Ui.rule(p, Vector2(24, 490), 976, Color(P2Ui.C_EDGE, 0.8))
	var back := P2Ui.primary(P2Ui.button(tr("메인 메뉴로 [Enter]"), Vector2(780, 560), Vector2(220, 50), 24))
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(func() -> void: _leave("expedition"))
	p.add_child(back)
	back.grab_focus.call_deferred()


func _result_row(p: Control, y: float, title: String, col: Color, chips: Array) -> float:
	var t := _tx_label(title, 20, col)
	t.position = Vector2(24, y + 6)
	t.size = Vector2(150, 26)
	t.clip_text = true
	p.add_child(t)
	P2Ui.chip_row(p, Vector2(180, y), chips)
	return y + 46.0


# ── 메뉴 · 설정 · 덱 보기 · 안내 ─────────────────────────────────────────────────

# 레벨업 창은 미뤄도 되는 창: 다른 창을 열면 닫고(고르기는 남아 지도 칩에서 다시 연다) 그 창을 연다
func _modal_busy() -> bool:
	if _modal in ["level", "stats", "relics"]:
		close_modal()
	return _modal != ""


func close_modal() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_peek = null
	_modal = ""


# 작은 카드 칸에 올리면 옆에 크게(3배 · 조건까지) 띄운다. 손패에 올렸을 때처럼 읽기 쉽게
func _hover_card(ctrl: Control, c: Card) -> void:
	ctrl.mouse_entered.connect(func() -> void:
		_drop_card_peek()
		var face := P2Ui.card_art(c, String(model.run.class_id), 3, "", true)
		_ignore_mouse(face)
		var r := ctrl.get_global_rect()
		var pos := Vector2(r.end.x + 10.0, r.position.y - 50.0)
		if pos.x + 210.0 > 1272.0:
			pos.x = r.position.x - 214.0
		pos.y = clampf(pos.y, 8.0, 720.0 - 336.0)
		face.position = pos
		_overlay.add_child(face)
		_peek = face)
	ctrl.mouse_exited.connect(_drop_card_peek)


func _drop_card_peek() -> void:
	if _peek != null and is_instance_valid(_peek):
		_peek.queue_free()
	_peek = null


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore_mouse(ch)


func _dungeon_menu() -> void:
	if _modal_busy():
		return
	dungeon.set_locked(true)
	_modal = "menu"
	var can_abandon := not (String(model.run.phase) in ["portal", "sector_choice"])
	var p := _win(Vector2(420, 130), Vector2(440, 440), tr("메뉴"))
	var y := 76.0
	var cont := P2Ui.primary(_tx_button(tr("계속"), Vector2(40, y), Vector2(360, 48), 20))
	cont.pressed.connect(func() -> void:
		close_modal()
		dungeon.set_locked(false))
	p.add_child(cont)
	y += 60
	var deck := _tx_button(tr("덱·유물 보기"), Vector2(40, y), Vector2(360, 48), 20)
	deck.pressed.connect(func() -> void:
		close_modal()
		_deck_view())
	p.add_child(deck)
	y += 60
	var sets := _tx_button(tr("설정 (음량)"), Vector2(40, y), Vector2(360, 48), 20)
	sets.pressed.connect(func() -> void: _settings_panel(func() -> void: dungeon.set_locked(false)))
	p.add_child(sets)
	y += 60
	var give_up := _tx_button(tr("원정 포기") if can_abandon else tr("원정 포기 (지금은 불가)"), Vector2(40, y), Vector2(360, 48), 20)
	give_up.disabled = not can_abandon
	give_up.pressed.connect(func() -> void:
		close_modal()
		_confirm_abandon())
	p.add_child(give_up)
	y += 60
	var quit := _tx_button(tr("게임 종료 (자동 저장됨)"), Vector2(40, y), Vector2(360, 48), 20)
	quit.pressed.connect(func() -> void:
		if not model.has_pending():
			get_tree().quit())
	p.add_child(quit)


func _settings_panel(on_close: Callable) -> void:
	close_modal()
	_modal = "settings"
	var p := _win(Vector2(390, 180), Vector2(500, 330), tr("설정"))
	var vl := _tx_label("음량 %d" % int(settings.volume), 20, P2Ui.C_TEXT)
	vl.position = Vector2(24, 130)
	p.add_child(vl)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(settings.volume)
	slider.position = Vector2(24, 160)
	slider.size = Vector2(440, 28)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void:
		settings.volume = v
		vl.text = "음량 %d" % int(v)
		P2Ui.apply_volume(v)
		P2Ui.save_settings(settings))
	p.add_child(slider)
	var close := _tx_button(tr("닫기"), Vector2(24, 230), Vector2(160, 48), 20)
	close.pressed.connect(func() -> void:
		close_modal()
		on_close.call())
	p.add_child(close)


func _confirm_abandon() -> void:
	_modal = "abandon"
	var p := _win(Vector2(250, 170), Vector2(780, 380), tr("원정을 포기할까요?"), P2Ui.C_HP)
	var risk := model.at_risk_summary()
	var kl := _tx_label(tr("지켜짐"), 20, P2Ui.C_SAFE)
	kl.position = Vector2(24, 82)
	p.add_child(kl)
	P2Ui.chip_row(p, Vector2(110, 76), [[P2Ui.kit_tex("status_crit", 1), tr("지금까지의 점수 · 기록"), P2Ui.C_TEXT]] + ([[P2Ui.kit_tex("hud_coin", 1), "+%d" % int(risk.banked_gold), P2Ui.C_GOLD]] if int(risk.banked_gold) > 0 else []))
	var ll := _tx_label(tr("잃음"), 20, P2Ui.C_HP)
	ll.position = Vector2(24, 132)
	p.add_child(ll)
	P2Ui.chip_row(p, Vector2(110, 126), [[P2Ui.kit_tex("hud_coin", 1), "-%d" % int(risk.pending_gold), P2Ui.C_HP], [P2Ui.kit_tex("pile_exhaust", 1), tr("원정 덱 · 유물 · 특성"), P2Ui.C_HP]])
	var note := _tx_label(tr("창을 닫는 것은 포기가 아님 (다시 켜면 이어짐) · 포기는 되돌릴 수 없음"), 20, P2Ui.C_DIM, 720)
	note.position = Vector2(24, 186)
	p.add_child(note)
	var no := P2Ui.primary(_tx_button(tr("계속하기"), Vector2(24, 270), Vector2(220, 50), 24))
	no.pressed.connect(func() -> void:
		close_modal()
		dungeon.set_locked(false))
	p.add_child(no)
	var yes := _tx_button(tr("원정 포기"), Vector2(520, 270), Vector2(220, 50), 20)
	yes.add_theme_color_override("font_color", P2Ui.C_HP)
	yes.pressed.connect(func() -> void:
		close_modal()
		if await _saved(model.abandon()):
			show_result(model.last_result())
		else:
			dungeon.set_locked(false))
	p.add_child(yes)


func _deck_view() -> void:
	if _modal_busy() and _modal != "menu":
		return
	close_modal()
	dungeon.set_locked(true)
	_modal = "deck"
	var run := model.run
	var p := P2Ui.panel(_overlay, Vector2(40, 24), Vector2(1200, 672))
	var t := _tx_label(tr("이번 원정의 덱과 유물 — %s · %d장 · 유물 %d/%d") % [P2Catalog.CLASSES[run.class_id].name, (run.deck as Array).size(), (run.relics as Array).size(), P2Catalog.relic_capacity(run)], 24, P2Ui.C_GOLD)
	t.position = Vector2(24, 12)
	p.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 50)
	scroll.size = Vector2(1144, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for c in run.deck:
		var card := P2Catalog.make_card(c)
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(136, 218)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = P2Catalog.long_text(String(c.kind), String(c.upgrade))
		cell.add_child(P2Ui.card_art(card, String(run.class_id), 2))
		_hover_card(cell, card)
		grid.add_child(cell)
	var lines: Array[String] = []
	for id in run.relics:
		lines.append(tr("유물 %s — %s") % [P2Catalog.RELICS[id].name, P2Catalog.RELICS[id].text])
	for tr_id in run.get("traits", []):
		lines.append(tr("계속 특성 %s — %s") % [P2Catalog.TRAITS[tr_id].name, P2Catalog.TRAITS[tr_id].text])
	lines.append(tr("최대 체력 %d") % int(run.max_hp))
	var sc2 := ScrollContainer.new()
	sc2.position = Vector2(20, 420)
	sc2.size = Vector2(960, 200)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc2)
	var info := _tx_label("\n".join(lines), 16, P2Ui.C_TEXT, 930)
	sc2.add_child(info)
	var close := _tx_button(tr("닫기"), Vector2(1000, 580), Vector2(160, 48), 16)
	close.pressed.connect(func() -> void:
		close_modal()
		dungeon.set_locked(false))
	p.add_child(close)


func _notice(title: String, text: String) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(holder)
	var p := P2Ui.panel(holder, Vector2(290, 220), Vector2(700, 280), false)
	var t := P2Ui.label(title, 24, P2Ui.C_GOLD)
	t.position = Vector2(24, 16)
	p.add_child(t)
	var body := P2Ui.label(text, 16, P2Ui.C_TEXT, 650)
	body.position = Vector2(24, 60)
	p.add_child(body)
	var ok := P2Ui.button("확인 [Enter]", Vector2(24, 216), Vector2(180, 44))
	ok.focus_mode = Control.FOCUS_ALL
	ok.pressed.connect(holder.queue_free)
	p.add_child(ok)
	holder.add_to_group("p3_notice")
	ok.grab_focus.call_deferred()


func dismiss_notices() -> void:
	for n in get_tree().get_nodes_in_group("p3_notice"):
		n.queue_free()


func current_modal() -> String:
	return _modal


# ── 점검용: 보상 칸 위치 (1280×720 설계 좌표) ──────────────────────────────

func reward_tiles() -> Array:
	return _tiles.filter(func(t): return is_instance_valid(t) and not (t as Node).is_queued_for_deletion())


func reward_replace_tiles() -> Array:
	return _replace_tiles.filter(func(t): return is_instance_valid(t) and not (t as Node).is_queued_for_deletion())


func reward_confirm() -> Button:
	return _confirm_button


func reward_confirm_rect() -> Rect2:
	return _confirm_button.get_global_rect()


func reward_skip_rect() -> Rect2:
	return _skip_button.get_global_rect() if _skip_button != null else Rect2()
