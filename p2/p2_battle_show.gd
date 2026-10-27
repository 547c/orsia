class_name P2BattleShow
extends Node

# 새 기술 연출 · 적 상태 모습과 아이콘 · 필살 게이지·컷인 (전투 화면 도우미). 화면의 연출 도우미(_enemy_hit_feedback, _shockwave 등)를 그대로 부른다.
# 표시 피해·상태는 사건(events)을 맞는 순간에 한 번만 반영한다(화면 = 실제)

const ORDER := ["frozen", "chill", "burn", "poison", "pcrys", "bleed", "doom", "vuln", "weak", "umbra", "lumen", "trap", "link", "air"]
const C_FIRE := Color("#ff7a2a")
const C_ICE := Color("#9fe6ff")
const C_DARK := Color("#b46aff")
const C_LIGHT := Color("#ffe27a")
const C_WIND := Color("#a8f0c8")
const C_POISON := Color("#8ae04a")
const C_BLOOD := Color("#e0303a")
const C_HEX := Color("#c890ff")
const ULT_KEY := KEY_R

var v
var auras: Array = []
var packs: Array = []
var rows: Array = []
var _grade: ColorRect
var _grade_mat: ShaderMaterial
var _rift: ColorRect
var _rift_mat: ShaderMaterial
var _ult: Control
var _ult_pen: P2Pixel
var _ult_level := 0.0
var _ult_ready := false
var _t := 0.0
var _font: Font
var _small: Font
var _wall_node: Node2D
var _labels: Node2D
var show_log: Array = []
var _held_orb: P2Vfx


func setup(view) -> void:
	v = view
	_font = P2Ui.bold_font(24)
	_small = P2Ui.pixel_font(P2Ui.T_SMALL)
	_grade = _screen_layer(8, "res://p2/p2_grade.gdshader")
	_grade_mat = _grade.material
	_rift = _screen_layer(9, "res://p2/p2_rift.gdshader")
	_rift_mat = _rift.material
	_build_ult()
	_wall_node = Node2D.new()
	_wall_node.draw.connect(_draw_wall)
	v._fxpa.add_child(_wall_node)
	_labels = Node2D.new()
	_labels.draw.connect(_draw_labels)
	v._fx.add_child(_labels)


func _screen_layer(n: int, shader: String) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = n
	add_child(layer)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bb)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.size = Vector2(1280, 720)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	r.material = m
	r.visible = false
	layer.add_child(r)
	return r


# ── 적 상태: 아이콘 줄 · 몸 모습 ──

func rebuild_enemies() -> void:
	for a in auras + packs:
		if is_instance_valid(a):
			a.queue_free()
	packs.clear()
	for r in rows:
		if is_instance_valid(r):
			(r as Node).queue_free()
	auras.clear()
	rows.clear()
	for i in range(v._enemy_panels.size()):
		var p: Dictionary = v._enemy_panels[i]
		var root: Control = p.root
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		row.position = Vector2(-20, P2BattleView.FEET_Y - root.position.y + 86.0)
		row.size = Vector2(root.size.x + 40.0, 24)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(row)
		rows.append(row)
		var aura := P2StatusAura.new()
		aura.z_index = 1
		v._fxp.add_child(aura)
		auras.append(aura)
		var pk := P2StatusPack.new()
		pk.z_index = 2
		v._fx.add_child(pk)
		packs.append(pk)
		render_status(i)


func render_status(i: int) -> void:
	if i < 0 or i >= rows.size() or not is_instance_valid(rows[i]):
		return
	var row: HBoxContainer = rows[i]
	for c in row.get_children():
		c.queue_free()
	var e: Dictionary = v._shown.enemies[i]
	var st: Dictionary = e.get("st", {})
	if not bool(e.get("alive", true)):
		return
	# 얼어 있으면 예고 칸 = 얼어붙음(다음 적 차례 공격 없음)
	if int(st.get("frozen", 0)) > 0 and i < v._enemy_panels.size():
		var p: Dictionary = v._enemy_panels[i]
		var il: Label = p.intent_label
		il.text = tr("얼음")
		il.add_theme_color_override("font_color", C_ICE)
		(p.intent as Control).tooltip_text = tr("얼어붙음: 다음 적 차례에 공격하지 못합니다 (물리로 치면 쇄빙 ×2 · 대신 얼음이 풀림)")
		var pips: Control = (p.intent as Control).get_meta("pips") if (p.intent as Control).has_meta("pips") else null
		if pips != null:
			pips.set_meta("kinds", [])
			pips.queue_redraw()
	for key in ORDER:
		var n := int(st.get(key, 0))
		if n <= 0:
			continue
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(36 if key not in ["frozen", "trap", "link", "air"] else 24, 24)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_HELP
		cell.tooltip_text = status_tip(key, n, st)
		var ic := P2Ui.tex_icon(P2Catalog.icon_tex("st_" + key), 20)
		ic.position = Vector2(2, 2)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ic)
		if cell.custom_minimum_size.x > 24:
			var shown: int = n * v.battle.doom_mult() if key == "doom" else n
			var l := P2Ui.outlined(P2Ui.text(str(shown), P2Ui.T_SMALL, status_color(key)), 3)
			l.position = Vector2(22, 4)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(l)
		row.add_child(cell)


static func status_color(key: String) -> Color:
	return {"burn": C_FIRE, "poison": C_POISON, "chill": C_ICE, "frozen": C_ICE, "bleed": C_BLOOD, "vuln": Color("#ffd2a0"),
		"weak": Color("#c8a0ff"), "doom": C_HEX, "trap": Color("#c9d2da"), "link": C_HEX, "air": C_WIND}.get(key, Color.WHITE)


func status_tip(key: String, n: int, st: Dictionary) -> String:
	match key:
		"burn":
			return TranslationServer.translate("화상 %d: 내가 턴을 끝낼 때 %d 피해, 그 뒤 %s") % [n, n, tr("1 줄어듦") if v.battle.relics.has("ember_heart") else tr("절반으로")]
		"poison":
			return TranslationServer.translate("독 %d: 내가 턴을 끝낼 때 %d 피해, 그 뒤 1 줄어듦 · 불이면 유독 폭발(독 × 2) · 얼음이면 독 결정") % [n, n]
		"chill":
			return TranslationServer.translate("냉기 %d / 3: 3이 되면 얼어붙어 다음 적 차례에 공격 못 함 · 불이면 증기 폭발 · 독이면 독 결정") % n
		"frozen":
			return TranslationServer.translate("얼어붙음: 앞으로 적 차례 %d번 공격 못 함 · 물리로 치면 쇄빙(피해 ×2, 파편), 불이면 증기 폭발 — 대신 얼음이 풀림") % maxi(1, n)
		"bleed":
			return TranslationServer.translate("출혈 %d: 이 적이 공격할 때마다 %d 피해, 그 뒤 1 줄어듦") % [n, n]
		"vuln":
			return TranslationServer.translate("취약 %d턴: 받는 피해 +%d%%") % [n, roundi((v.battle.vuln_mult() - 1.0) * 100.0)]
		"weak":
			return TranslationServer.translate("약화 %d턴: 이 적이 주는 피해 −25%%") % n
		"doom":
			return TranslationServer.translate("저주 %d: %d턴 뒤(턴을 끝낼 때) %d 피해로 터짐") % [n, int(st.get("doom_t", 0)), n * v.battle.doom_mult()]
		"trap":
			return TranslationServer.translate("덫: 이 적이 공격하러 오면 %d 피해 + 출혈 3, 그 공격의 첫 타격이 사라짐") % n
		"link":
			return TranslationServer.translate("고통 연결: 이 적이 받은 카드 피해의 절반이 사슬로 묶인 적에게도")
		"air":
			return TranslationServer.translate("공중: 이번 턴 이 적에게 들어가는 타격마다 +3")
		"umbra":
			return TranslationServer.translate("어둠 기운 %d턴: 빛이 닿으면 일식(이 적에게 8, 모든 적 취약 2)") % n
		"lumen":
			return TranslationServer.translate("빛 기운 %d턴: 어둠이 닿으면 일식(이 적에게 8, 모든 적 취약 2)") % n
		"pcrys":
			return TranslationServer.translate("독 결정 %d턴: 독이 줄지 않음") % n
	return key


func _process(delta: float) -> void:
	_t += delta
	if v == null or v.battle == null:
		return
	var shown_en: Array = v._shown.get("enemies", [])
	for i in range(auras.size()):
		var a: P2StatusAura = auras[i]
		if not is_instance_valid(a) or i >= v._enemy_sprites.size() or i >= shown_en.size():
			continue
		var sp: AnimatedSprite2D = v._enemy_sprites[i]
		var e: Dictionary = shown_en[i]
		a.alive = bool(e.get("alive", true)) and is_instance_valid(sp) and sp.visible
		if not a.alive:
			continue
		var vis: Vector2 = v._vis_cached(i)
		a.feet = sp.position + Vector2(0, float(sp.get_meta("air_y", 0.0)))
		a.body_h = vis.y
		a.body_w = vis.x
		a.st = e.get("st", {})
		a.doom_mult = v.battle.doom_mult()
		if i < packs.size() and is_instance_valid(packs[i]):
			var pk: P2StatusPack = packs[i]
			pk.alive = a.alive
			pk.feet = a.feet
			pk.body_h = a.body_h
			pk.body_w = a.body_w
			pk.st = a.st
		var lk := int(a.st.get("link", 0)) - 1
		a.link_to = (v._enemy_sprites[lk] as AnimatedSprite2D).position if lk > i and lk < v._enemy_sprites.size() else Vector2.INF
	_tick_trait_look()
	_tick_ult(delta)
	if _grade.visible:
		_grade_mat.set_shader_parameter("t", _t)
	_wall_node.queue_redraw()
	_labels.queue_redraw()


func _draw_wall() -> void:
	if v == null or v.battle == null or v.battle.wall <= 0:
		return
	var at: Vector2 = v._player_body() + Vector2(86, 50)
	var k: float = clampf(float(v.battle.wall) / P2Catalog.RAMPART_MAX, 0.35, 1.0)
	var pulse := 0.85 + 0.15 * sin(_t * 4.0)
	var cell := 22.0
	for r in range(7):
		for c in range(2):
			var hc := at + Vector2((c - 0.5) * cell * 1.75 + (cell * 0.87 if r % 2 == 1 else 0.0), -(r + 0.5) * cell * 1.5)
			var pts := PackedVector2Array()
			for j in range(7):
				var ang := PI / 6.0 + TAU * j / 6.0
				pts.append(hc + Vector2(cos(ang), sin(ang)) * cell * 0.92)
			_wall_node.draw_colored_polygon(pts.slice(0, 6), Color(1.0, 0.85, 0.45, 0.24 * k * pulse))
			_wall_node.draw_polyline(pts, Color(1.0, 0.95, 0.75, 0.9 * k * pulse), 2.5, false)


# 픽셀 그림판 위 글자(매끈한 층): 성벽 숫자 · 적 저주 피해와 남은 턴
func _draw_labels() -> void:
	if v == null or v.battle == null:
		return
	if v.battle.wall > 0:
		var at: Vector2 = v._player_body() + Vector2(76, -120)
		var txt := str(v.battle.wall)
		_labels.draw_string_outline(_font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0.05, 0.03, 0.02))
		_labels.draw_string(_font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ffe9a8"))
	for a in auras:
		if is_instance_valid(a) and a.alive and a.label != "":
			var p: Vector2 = a.position + a.label_at
			_labels.draw_string_outline(_small, p, a.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0.05, 0.02, 0.06))
			_labels.draw_string(_small, p, a.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.75, 1.0))


# ── 특성 상시 모습: 피의 값(체력이 낮으면 발밑 붉은 숨결) · 원소 순환(마나 위 이번 턴 묻힌 원소 점) ──

var _blood: Array = []
var _elem_dots: Control
var _elem_pen


func _tick_trait_look() -> void:
	var on: bool = v.battle.blood_bonus() > 0 and not v.battle.battle_over
	if on and _blood.is_empty():
		for k in range(2):
			var f := P2PackFx.spawn(v._fx_back, "464", "blood", Vector2.ZERO, 3.0, {"loop": true, "fps": 10.0, "phase": 0.4 * k, "flip": k == 1})
			f.modulate = Color(1, 1, 1, 0.85)
			_blood.append(f)
	elif not on and not _blood.is_empty():
		for f in _blood:
			if is_instance_valid(f):
				f.queue_free()
		_blood.clear()
	var low: bool = v.battle.blood_bonus() >= P2Catalog.BLOOD_LOW
	for k in range(_blood.size()):
		var f2: P2PackFx = _blood[k]
		if is_instance_valid(f2):
			f2.position = Vector2(v._player_body().x + (-56.0 if k == 0 else 70.0), v._player.position.y - 70.0)
			f2.scale = Vector2.ONE * (3.5 if low else 3.0)
	if v.battle.traits.has("elem_cycle"):
		if not is_instance_valid(_elem_dots):
			_elem_dots = Control.new()
			_elem_dots.position = P2BattleView.MANA_ORB + Vector2(118, -26)
			_elem_dots.size = Vector2(60, 20)
			_elem_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_elem_pen = P2Pixel.attach(_elem_dots, _draw_elem_dots, false, 3)
			v._ui.add_child(_elem_dots)
		_elem_pen.redraw()


func _draw_elem_dots() -> void:
	var cols := [Color("#ff7a2a"), Color("#7fd6ff"), Color("#8ae04a"), Color("#ffe27a"), Color("#b46aff")]
	var mask: int = v.battle.elem_mask
	var x := 6.0
	for k in range(5):
		if mask & (1 << k):
			_elem_pen.draw_circle(Vector2(x, 10), 6.0, Color(0.03, 0.02, 0.05))
			_elem_pen.draw_circle(Vector2(x, 10), 4.5, cols[k])
			x += 16.0


# ── 필살 게이지 · 단추 ──

func _build_ult() -> void:
	_ult = Control.new()
	_ult.position = Vector2(1146, 516)
	_ult.size = Vector2(110, 100)
	_ult.mouse_filter = Control.MOUSE_FILTER_STOP
	_ult.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ult_pen = P2Pixel.attach(_ult, _draw_ult, false, 3)
	_ult.gui_input.connect(_on_ult_input)
	v._ui.add_child(_ult)


# 메서드로 연결(람다는 이 도우미가 먼저 지워진 뒤 단추 신호가 오면 오류)
func _on_ult_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		use_ult()


func _tick_ult(delta: float) -> void:
	if not is_instance_valid(_ult):
		return
	var target := float(v.battle.ult) / P2Catalog.ULT_MAX
	_ult_level = move_toward(_ult_level, target, delta * 1.5)
	var ready: bool = v.battle.ult_ready() and v._state == P2BattleView.UI.PLAYER
	if ready and not _ult_ready:
		v._sfx("crit_ready", 1.25)
		v._float_number(tr("필살 준비!"), _ult.position + Vector2(55, -14), P2Catalog.CLASS_COLOR.get(v.battle.class_id, C_LIGHT), 24, 24.0, 1.0)
	_ult_ready = ready
	_ult.visible = v._rhythm_open <= 0
	var g: Dictionary = P2Catalog.ULT_GAIN
	_ult.tooltip_text = (tr("두 겹 필살: 200까지 차고 100마다 한 번. ") if v.battle.ult_cap() > P2Catalog.ULT_MAX else "") + tr("필살 게이지 %d / 100 — 다른 카드를 이어 쓰면 +%d · 완벽 문양 +%d · 완벽 막기 +%d · 원소 반응 +%d. 전투가 끝나도 원정 동안 남습니다. 가득 차면 눌러서(R) 필살: %s") % [int(v.battle.ult), int(g.vary), int(g.perfect_glyph), int(g.perfect_parry), int(g.reaction), P2Catalog.card_name(String(P2Catalog.ULT_KINDS.get(v.battle.class_id, "")))]
	_ult_pen.redraw()


func _draw_ult() -> void:
	var c := Vector2(55, 46)
	var col: Color = P2Catalog.CLASS_COLOR.get(v.battle.class_id, C_LIGHT)
	var r := 34.0
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	if _ult_ready:
		for k in range(4):
			_ult_pen.draw_circle(c, r + 16.0 + pulse * 8.0 - k * 5.0, Color(col, 0.08 + 0.05 * k))
	_ult_pen.draw_circle(c, r + 4.0, Color(0.05, 0.04, 0.07, 0.92))
	_ult_pen.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(col, 0.25), 7.0, false)
	if _ult_level > 0.0:
		_ult_pen.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * minf(_ult_level, 1.0), 48, Color(col.lightened(0.2 if _ult_ready else 0.0), 1.0), 7.0, false)
	if v.battle.ult_cap() > P2Catalog.ULT_MAX:
		_ult_pen.draw_arc(c, r - 9.0, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(col, 0.18), 4.0, false)
		if _ult_level > 1.0:
			_ult_pen.draw_arc(c, r - 9.0, -PI / 2.0, -PI / 2.0 + TAU * minf(_ult_level - 1.0, 1.0), 48, Color(1.0, 0.95, 0.7, 1.0), 4.0, false)
	var ic := P2Catalog.icon_tex(String(P2Catalog.ULT_KINDS.get(v.battle.class_id, "")))
	if ic != null:
		var s := 40.0 * (1.0 + 0.08 * pulse if _ult_ready else 1.0)
		_ult_pen.icon(ic, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), Color(1, 1, 1, 1.0 if _ult_ready else 0.45))
	var txt := tr("필살!") if _ult_ready else "%d%%" % int(v.battle.ult)
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_ult_pen.text(_font, Vector2(c.x - tw / 2.0, 98), txt, 20, col.lightened(0.3) if _ult_ready else Color(0.85, 0.82, 0.78), 6, Color(0.03, 0.02, 0.05))


func key_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == ULT_KEY:
		if _ult_ready:
			use_ult()
			return true
	return false


# 필살: 컷인 → 실제 결과(사건) → 직업마다 다른 화면 연출로 맞는 순간에 반영
func use_ult(target := -1) -> void:
	if not _ult_ready or v._state != P2BattleView.UI.PLAYER:
		return
	v._state = P2BattleView.UI.BUSY
	v._action_token += 1
	v._cancel_gesture("ult")
	v._clear_preview()
	if target < 0:
		target = v._target if v._target >= 0 and v.battle.get_monster(v._target) != null and v.battle.get_monster(v._target).is_alive() else -1
	var kind := String(P2Catalog.ULT_KINDS.get(v.battle.class_id, ""))
	if not v.battle.use_ultimate(target):
		v._state = P2BattleView.UI.PLAYER
		return
	var events: Array = v.battle.events.duplicate(true)
	show_log.append({"ult": kind, "ms": Time.get_ticks_msec()})
	await v._commit("ultimate")
	var tex: Texture2D = null
	var sf: SpriteFrames = v._player.sprite_frames
	if sf != null:
		tex = sf.get_frame_texture(v._player.animation, v._player.frame)
		for pose in ["strong_cast", "cast_strong", "aim", "bash", "slash"]:
			if sf.has_animation(pose) and v._art.get("sd", false) == false:
				tex = sf.get_frame_texture(pose, mini(v._contact(pose), sf.get_frame_count(pose) - 1))
				break
	var col: Color = P2Catalog.CLASS_COLOR.get(v.battle.class_id, C_LIGHT)
	if not v._reduce_motion:
		var ci := P2CutIn.play(self, P2Catalog.card_name(kind), col, tex, func(n: String, p: float) -> void: v._sfx(n, p))
		ci.art_tint = v._player.self_modulate
		await ci.finished
	var tgt := -1
	for ev in events:
		if String(ev.kind) == "ult_used":
			tgt = int(ev.target)
	await anim_card(P2Catalog.build_card(kind, "ult_show"), kind, tgt, events)
	await v._anim_followups(events)
	v._reconcile("ultimate")
	if v.battle.battle_over:
		await v._on_battle_over()
		return
	v._state = P2BattleView.UI.PLAYER
	v._render_hud()
	v._refresh_card_states()
	v._refresh_targeting()


# ── 입력: 차징 · 연타 ──

func charge_input(card: Card, kind: String) -> Dictionary:
	var hunter := kind == "focus_shot"
	var at_w: Vector2 = v._player.position + P2BattleView.HUNTER_BOW * v._ks if hunter and v._dressed and v._art_cid == "hunter" else v._player_body() + Vector2(40, -10)
	if hunter and v._dressed and v._art_cid == "hunter":
		v._actor_play("aim", 1)
		await v._await_frame("aim", maxi(1, v._contact("aim") - 1))
		v._player.pause()
	var col := C_LIGHT if hunter else Color("#7fd6ff")
	var orb := P2Vfx.spawn(v._fx, "charge_orb", at_w, {"color": col, "size": 1.0})
	var pad := P2ChargePad.new()
	pad.center = v._to_ui(at_w)
	pad.color = col
	v._ui.add_child(pad)
	v._set_prompt(tr("누른 채 버티다 금빛 구간에서 놓기"))
	_grade_on()
	_grade_mat.set_shader_parameter("tint_color", Color(1.0, 0.9, 0.6) if hunter else Color(0.6, 0.85, 1.0))
	v._slowmo(true, [v._player])
	v._sfx("charge", 0.8)
	var state := {"last": 0.0, "hot": false}
	pad.changed.connect(func(lv: float) -> void:
		if is_instance_valid(orb):
			orb.level = lv
		_grade_mat.set_shader_parameter("bars", lv * 1.5)
		_grade_mat.set_shader_parameter("vig", 0.85 * lv)
		_grade_mat.set_shader_parameter("desat", 0.55 * lv)
		_grade_mat.set_shader_parameter("tint", 0.25 * lv)
		if lv - float(state.last) > 0.2:
			state.last = lv
			v._sfx("charge", 0.8 + lv * 0.9, -4.0)
			v._camera_kick("light", Vector2.LEFT)
		if lv >= P2ChargePad.SWEET and not bool(state.hot):
			state.hot = true
			v._sfx("crit_ready", 1.5, -2.0)
			P2Vfx.spawn(v._fx, "flash", at_w, {"color": Color("#ffe27a"), "size": 1.2}))
	var res: Dictionary = await pad.finished
	v._set_prompt("")
	v._slowmo(false)
	v._sfx("whoosh", 1.6, -4.0)
	P2Vfx.spawn(v._fx, "flash", at_w, {"color": Color.WHITE, "size": 0.8 + float(res.level)})
	_held_orb = orb
	var wr: WeakRef = weakref(orb)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		var o: Object = wr.get_ref()
		if o != null:
			(o as Node).queue_free())
	show_log.append({"charge": res.duplicate(), "card": kind})
	if bool(res.perfect):
		v._sfx("crit_ready", 1.2)
	return res


func mash_input(card: Card) -> int:
	var target: int = v._target
	var hunter: bool = v._dressed and v._art_cid == "hunter"
	var pad := P2MashPad.new()
	pad.cap = P2Catalog.BARRAGE_MAX
	v._ui.add_child(pad)
	if hunter:
		v._actor_play("shot", 1)
		await v._await_frame("shot", maxi(1, v._contact("shot") - 1))
		v._player.pause()
	_grade_on()
	_grade_mat.set_shader_parameter("tint_color", Color(1.0, 0.82, 0.55))
	var from: Vector2 = v._player.position + P2BattleView.HUNTER_BOW * v._ks if hunter else v._player_body() + Vector2(40, -20)
	var base_off: Vector2 = (v._enemy_sprites[target] as AnimatedSprite2D).offset if target >= 0 else Vector2.ZERO
	pad.shot.connect(func(n: int) -> void:
		var to: Vector2 = v._enemy_torso(target) if target >= 0 else Vector2(900, 280)
		var heat := clampf(n / 30.0, 0.0, 1.0)
		P2Vfx.spawn(v._fx, "muzzle", from + Vector2(randf_range(-4, 4), randf_range(-6, 6)), {"color": C_LIGHT, "size": 1.0 + heat * 0.8})
		for k in range(4):
			var off := Vector2(randf_range(-34, 30), randf_range(-70, 50))
			P2Vfx.spawn(v._fx, "streak", from + Vector2(0, randf_range(-8, 8)), {"to": to + off, "color": Color("#ffe9a8").lerp(Color("#ff8a3a"), heat), "life": randf_range(0.11, 0.17)})
		v._sfx("bow", randf_range(1.3, 1.8), -5.0)
		v._sfx("arrow", randf_range(1.2, 1.6), -9.0)
		v._camera_kick("light", Vector2.RIGHT)
		_grade_mat.set_shader_parameter("vig", 0.25 + heat * 0.45)
		_grade_mat.set_shader_parameter("tint", heat * 0.3)
		if target >= 0:
			var sp: AnimatedSprite2D = v._enemy_sprites[target]
			v._sparks(to + Vector2(-20, randf_range(-40, 30)), Vector2.LEFT, 0.9, 5, [Color.WHITE, Color("#ffe9a8"), Color("#ff9a4a")], true, Vector2(160, 420))
			if n % 2 == 0:
				v._actor_flash(sp, Color(1, 0.95, 0.85), 0.45, 0.01, 0.04)
			sp.offset = base_off + Vector2(4.0 if n % 2 == 0 else -4.0, 0.0))
	var n: int = await pad.finished
	if target >= 0:
		(v._enemy_sprites[target] as AnimatedSprite2D).offset = base_off
	_grade_off(0.4)
	if hunter:
		v._player.play()
	show_log.append({"mash": n, "card": P2Catalog.kind_of(card)})
	return n


# ── 화면 색 손질 ──

# 화면 색 손질 층은 사건 동안만 켠다(값이 모두 0이 되면 끈다 → 평소엔 화면을 한 번 더 그리지 않음)
const EVENT_KEYS := ["chroma", "desat", "tint", "haze", "bars", "vig", "zoom"]


func _grade_on() -> void:
	for k in EVENT_KEYS:
		_grade_mat.set_shader_parameter(k, 0.0)
	_grade_mat.set_shader_parameter("vig_color", Color.BLACK)
	_grade.visible = true


func _grade_wake() -> void:
	if not _grade.visible:
		_grade_on()


func _grade_off(dur := 0.25) -> void:
	var t := create_tween().set_parallel()
	for k in EVENT_KEYS:
		var from: float = float(_grade_mat.get_shader_parameter(k))
		if from != 0.0:
			t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter(k, x), from, 0.0, dur)
	t.tween_interval(0.01)
	await t.finished
	_grade_idle()


func _grade_pulse(key: String, peak: float, dur: float) -> void:
	if not _grade.visible:
		_grade_on()
	var t := create_tween()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter(key, x), peak, 0.0, dur)
	t.tween_callback(_grade_idle)
	await t.finished


# ── 카드 연출 (처리했으면 true) ──

func anim_card(card: Card, kind: String, target: int, events: Array) -> bool:
	if v._reduce_motion and not kind.begins_with("ult_"):
		return false
	var up := P2Catalog.upgrade_of(card)
	match kind:
		"fireball":
			await _fireball(target, events, up)
		"frost_lance":
			if up == "frost_pierce":
				await _frost_pierce(events)
			else:
				await _frost_lance(target, events)
		"ice_coffin":
			await _ice_coffin(target, events)
		"dark_rift":
			await _dark_rift(target, events)
		"light_rain":
			await _light_rain(events)
		"focus_shot":
			await _focus_shot(events)
		"barrage":
			await _barrage(target, events)
		"gust":
			await _gust(target, events)
		"poison_cloud":
			await _poison_cloud(events)
		"fire_wall":
			await _fire_wall(events, up)
		"bear_trap":
			await _bear_trap(target)
		"mark_target":
			await _mark_target(target)
		"bleed_arrows":
			await _bleed_arrows(events)
		"shield_boomerang":
			await _shield_boomerang(events)
		"rampart":
			await _rampart(events)
		"war_cry":
			await _war_cry(events)
		"iron_counter":
			await _iron_counter(events)
		"launcher":
			await _launcher(target, events)
		"hundred_fists":
			await _hundred_fists(target, events, up)
		"ki_blast":
			await _ki_blast(target, events)
		"hex_bolt":
			await _hex_bolt(target, events, up)
		"doom_brand":
			await _doom_brand(target, up)
		"enfeeble":
			await _enfeeble(target)
		"armor_break":
			await _armor_break(target, events)
		"soul_link":
			await _soul_link(target, events)
		"blood_pact":
			await _blood_pact(events)
		"soul_drain":
			await _soul_drain(events)
		"plague":
			await _plague(events)
		"expose":
			await _expose(target)
		"disarm":
			await _disarm(target)
		"war_shout":
			await _war_shout()
		"poison_coat":
			await _poison_coat()
		"smoke_bomb":
			await _smoke_bomb()
		"ult_rune_caster":
			await _ult_elements(events)
		"ult_hunter":
			await _ult_arrows(events)
		"ult_warden":
			await _ult_shield(events)
		"ult_combo":
			await _ult_panels(target, events)
		"ult_shaman":
			await _ult_eye(events)
		_:
			return false
	v.skill_log.append({"card": kind, "fx": "show"})
	return true


# 흑백 임팩트: 행동마다 한 번만(맞는 순간 화면이 따로 부를 수도 있으니 같은 표식으로)
# 앞서 만든 움직임을 기다림: 그새 이미 끝났으면 바로 넘어감(끝난 뒤 finished를 기다리면 영영 안 옴)
func _tw_done(t: Tween) -> void:
	if t != null and t.is_valid() and t.is_running():
		await t.finished


func _impact(actors: Array, pos: Vector2) -> void:
	if v._av7_on() and v._av7_payoff_token != v._action_token:
		v._av7_payoff_token = v._action_token
		v._av7_payoff_beat(actors, pos)


func _hits(events: Array) -> Array:
	return events.filter(func(e): return String(e.kind) == "hit")


func _torso(i: int) -> Vector2:
	return v._enemy_torso(i)


func _feet(i: int) -> Vector2:
	return Vector2(_torso(i).x, P2BattleView.FEET_Y - 2.0)


# 마법 자세: 직업 그림의 cast 동작 발사 프레임까지 기다린 뒤 손(지팡이 끝) 자리
func _cast(major: bool) -> Vector2:
	var hand: Vector2 = v._player.position + Vector2(42, -60) * v._ks
	var rune: bool = v._dressed and v._art_cid == "rune_caster"
	var caster: bool = v._dressed and not rune and (v._art.anims as Dictionary).has("cast")
	if rune:
		var body := "strong_cast" if major else "cast"
		v._actor_play(body, 1)
		await v._await_frame(body, v._contact(body))
		hand = v._rune_socket(body)
	elif caster:
		var body2 := "cast_strong" if major and (v._art.anims as Dictionary).has("cast_strong") else "cast"
		v._actor_play(body2, 1)
		await v._await_frame(body2, v._contact(body2))
		hand = v._cast_socket()
	else:
		var lean := create_tween()
		lean.tween_property(v._player, "position:x", v._home_x + 10, 0.07)
		await v._wait(0.09)
	if v._art_cid == "rune_caster" and v._weapon != null:
		hand = v._player.position + Vector2(52, -104)
	return hand


func _fly(from: Vector2, to: Vector2, style: String, travel: float, arc := 0.0, size := 1.0) -> void:
	P2Vfx.spawn(v._fx, "missile", from, {"to": to, "style": style, "life": travel, "arc": arc, "size": size})
	await v._wait(travel)


func _fireball(target: int, events: Array, up := "") -> void:
	var hand := await _cast(false)
	v._sfx("fire", 1.15)
	var to := _torso(target)
	P2Vfx.spawn(v._fx, "flash", hand, {"color": C_FIRE, "size": 0.8})
	await _fly(hand, to, "fire", 0.22, 40.0, 1.1)
	P2Vfx.spawn(v._fx, "fire_burst", to, {"size": 1.05})
	P2SkillFx.spawn(v._fx_back, "scorch", _feet(target), Vector2.RIGHT, 1.3, C_FIRE)
	v._shockwave(to, 10.0, 900.0, 0.4)
	v._sfx("boom_m", 1.15)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, C_FIRE, "heavy")
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._hit_stop([v._player, v._enemy_sprites[target]] if target >= 0 else [v._player], 0.08)
	for ev in events:
		if String(ev.kind) == "bounce" and not bool(ev.get("_shown", false)):
			await _fire_bounce(to, ev)
	await v._wait(0.12)


# 튐: 불씨가 튀어 오르며 꼬리를 끌고, 떨어지는 자리에 작은 불기둥 + 폭발
func _fire_bounce(from: Vector2, ev: Dictionary) -> void:
	var i := int(ev.index)
	var to := _torso(i)
	P2Vfx.spawn(v._fx, "embers", from, {"size": 0.8})
	v._sfx("whoosh", 1.6, -4.0)
	v._sfx("fire", 1.5, -4.0)
	await _fly(from + Vector2(0, -20), to, "fire", 0.3, 130.0, 0.75)
	P2Vfx.spawn(v._fx, "fire_burst", to, {"size": 0.8})
	P2Vfx.spawn(v._fx_back, "fire_pillar", Vector2(to.x, P2BattleView.FEET_Y + 6.0), {"size": 0.7})
	P2SkillFx.spawn(v._fx_back, "scorch", _feet(i), Vector2.RIGHT, 1.0, C_FIRE)
	v._shockwave(to, 7.0, 800.0, 0.3)
	v._sfx("boom_m", 1.4, -2.0)
	v._enemy_hit_feedback(ev, C_FIRE, "heavy")
	v._camera_kick("light", Vector2.RIGHT)
	ev["_shown"] = true
	await v._wait(0.1)


func _frost_lance(target: int, events: Array) -> void:
	var hand := await _cast(false)
	var to := _torso(target)
	P2Vfx.spawn(v._fx, "ice_form", hand + Vector2(30, -20), {"dir": (to - hand).normalized(), "size": 1.0})
	v._sfx("glass", 1.4)
	await v._wait(0.26)
	v._sfx("whoosh", 1.5)
	await _fly(hand + Vector2(30, -20), to, "ice", 0.14, 0.0, 1.2)
	P2Vfx.spawn(v._fx, "frost_burst", to, {"size": 0.9})
	v._sfx("ice", 1.2)
	v._sfx("glass", 1.1, -4.0)
	v._shockwave(to, 7.0, 800.0, 0.3)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, C_ICE)
	await v._wait(0.14)


func _frost_pierce(events: Array) -> void:
	var hand := await _cast(true)
	var hits := _hits(events)
	var y := hand.y
	if not hits.is_empty():
		y = 0.0
		for ev in hits:
			y += _torso(int(ev.index)).y
		y /= hits.size()
	var start := hand + Vector2(40, -20)
	var end := Vector2(1380.0, y)
	P2Vfx.spawn(v._fx, "ice_form", start, {"dir": (end - start).normalized(), "size": 1.6})
	P2Vfx.spawn(v._fx, "charge_orb", start, {"color": C_ICE, "size": 0.6, "level": 0.7, "life": 0.4})
	v._sfx("glass", 1.2)
	v._sfx("charge", 1.3, -4.0)
	await v._wait(0.36)
	v._sfx("whoosh", 1.2)
	v._sfx("ice", 0.9)
	var travel := 0.32
	P2Vfx.spawn(v._fx, "missile", start, {"to": end, "style": "ice", "life": travel, "size": 2.0})
	P2Vfx.spawn(v._fx, "beam", start, {"to": end, "color": Color("#bfeeff"), "size": 0.5, "life": 0.5})
	var order := hits.duplicate()
	order.sort_custom(func(a, b): return _torso(int(a.index)).x < _torso(int(b.index)).x)
	var t0 := 0.0
	for ev in order:
		var i := int(ev.index)
		var at := (_torso(i).x - start.x) / maxf(1.0, end.x - start.x) * travel
		await v._wait(maxf(0.0, at - t0))
		t0 = maxf(t0, at)
		P2Vfx.spawn(v._fx, "frost_burst", _torso(i), {"size": 1.0})
		P2Vfx.spawn(v._fx, "freeze_form", _feet(i), {"size": 0.6})
		v._sfx("glass", randf_range(1.0, 1.4), -2.0)
		v._shockwave(_torso(i), 8.0, 800.0, 0.3)
		v._enemy_hit_feedback(ev, C_ICE, "heavy")
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._wait(0.2)


func _ice_coffin(target: int, events: Array) -> void:
	var hand := await _cast(true)
	var to := _torso(target)
	v._sfx("ice", 0.8)
	for k in range(5):
		var off := Vector2(randf_range(-20, 20), randf_range(-30, 30))
		P2Vfx.spawn(v._fx, "missile", hand + off, {"to": to + off * 1.5, "style": "ice", "life": 0.18 + k * 0.03, "arc": randf_range(-40.0, 60.0), "size": 0.7})
	await v._wait(0.22)
	P2Vfx.spawn(v._fx, "frost_burst", to, {"size": 1.3})
	P2Vfx.spawn(v._fx, "freeze_form", _feet(target), {"size": 1.0})
	v._sfx("glass", 0.9)
	v._sfx("crunch", 1.4, -6.0)
	v._shockwave(to, 9.0, 700.0, 0.35)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, C_ICE)
	await v._wait(0.3)


# 어둠의 균열: 화면이 대상만 남기고 닫힘 → 금 세 번(쩌적) → 정적 → 콰강(조각나 튕겨 나감 + 흑백 임팩트 + 보라 폭발) → 원래대로
func _dark_rift(target: int, events: Array) -> void:
	var to := _torso(target)
	var c: Vector2 = v._to_ui(to)
	await _cast(true)
	_rift_mat.set_shader_parameter("center", c)
	_rift_mat.set_shader_parameter("seed", randf() * 10.0)
	for k in ["dark", "crack", "shatter", "flash"]:
		_rift_mat.set_shader_parameter(k, 0.0)
	_rift.visible = true
	v._sfx("ghost", 0.9)
	v._sfx("static", 0.7)
	var t := create_tween()
	t.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("dark", x), 0.0, 1.0, 0.32).set_ease(Tween.EASE_OUT)
	await t.finished
	for step in range(3):
		var t2 := create_tween()
		t2.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("crack", x), step / 3.0, (step + 1) / 3.0, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		v._sfx("crack", 1.0 + step * 0.18)
		v._sfx("glass", 0.7 + step * 0.2, -6.0)
		v._camera_kick("light", Vector2.RIGHT)
		await v._wait(0.18)
	await v._wait(0.28)
	v._sfx("boom_l", 0.9)
	v._sfx("crunch", 0.8)
	v._sfx("glass", 0.6)
	var t3 := create_tween().set_parallel()
	t3.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("shatter", x), 0.0, 1.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t3.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("flash", x), 0.7, 0.0, 0.16)
	P2Vfx.spawn(v._fx, "rift_burst", to, {"size": 1.5})
	v._shockwave(to, 18.0, 1200.0, 0.5)
	_impact([v._player, v._enemy_sprites[target]], to)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, C_DARK, "heavy")
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._hit_stop([v._player, v._enemy_sprites[target]], 0.12)
	await v._wait(0.28)
	var t4 := create_tween().set_parallel()
	t4.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("shatter", x), 1.0, 0.0, 0.22).set_ease(Tween.EASE_IN)
	t4.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("dark", x), 1.0, 0.0, 0.36)
	t4.tween_method(func(x: float) -> void: _rift_mat.set_shader_parameter("crack", x), 1.0, 0.0, 0.3)
	await t4.finished
	_rift.visible = false


# 빛의 창: 지팡이를 들면 화면이 살짝 금빛 → 창마다 예고선 0.1초 뒤 꽂힘(후두두둑) → 마지막 창은 크게
func _light_rain(events: Array) -> void:
	await _cast(true)
	_grade_on()
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		_grade_mat.set_shader_parameter("tint_color", Color(1.0, 0.86, 0.5))
		_grade_mat.set_shader_parameter("tint", x), 0.0, 0.25, 0.2)
	v._sfx("power", 1.3)
	var hits := _hits(events)
	for k in range(hits.size()):
		var ev: Dictionary = hits[k]
		var i := int(ev.index)
		var at := _torso(i) + Vector2(randf_range(-34, 34), randf_range(-40, 30))
		P2Vfx.spawn(v._fx, "spear_tele", at, {"color": C_LIGHT, "size": 0.8})
		await v._wait(0.06)
		var last := k == hits.size() - 1
		P2Vfx.spawn(v._fx, "spear_hit", at, {"color": C_LIGHT, "size": 1.4 if last else 0.9})
		v._sfx("glass", randf_range(1.3, 1.7), -4.0)
		v._sfx("magic_hit", 1.4, -6.0)
		v._shockwave(at, 12.0 if last else 5.0, 800.0, 0.3)
		v._enemy_hit_feedback(ev, C_LIGHT, "heavy" if last else "secondary")
		if last:
			P2Vfx.spawn(v._fx, "light_pillar", _feet(i), {"color": C_LIGHT, "size": 1.3})
			v._camera_kick("heavy", Vector2.DOWN)
		await v._wait(0.05)
	await v._wait(0.15)
	_grade_off(0.3)


# 집중 사격: (차징은 입력에서) 놓는 순간 화살 끝에서 화면 끝까지 레일건 빛줄기 + 색 분리 + 모든 적 동시에
func _focus_shot(events: Array) -> void:
	var hunter: bool = v._dressed and v._art_cid == "hunter"
	var from: Vector2 = v._player.position + P2BattleView.HUNTER_BOW * v._ks if hunter else v._player_body() + Vector2(40, -20)
	if hunter:
		v._player.play()
		await v._await_frame("aim", v._contact("aim"))
	if is_instance_valid(_held_orb):
		_held_orb.queue_free()
	var hits := _hits(events)
	var far := from + Vector2(1400, 0)
	if not hits.is_empty():
		var y := 0.0
		for ev in hits:
			y += _torso(int(ev.index)).y
		y /= hits.size()
		far = from + (Vector2(1300, y) - from).normalized() * 1600.0
	v._sfx("boom_l", 1.3)
	v._sfx("bow", 0.6)
	P2Vfx.spawn(v._fx, "muzzle", from, {"color": Color.WHITE, "size": 2.2})
	P2Vfx.spawn(v._fx, "beam", from, {"to": far, "color": Color("#bfe8ff"), "size": 1.2})
	if not _grade.visible:
		_grade_on()
	_grade_mat.set_shader_parameter("chroma_c", v._to_ui(from))
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("chroma", x), 14.0, 0.0, 0.45)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("bars", x), float(_grade_mat.get_shader_parameter("bars")), 0.0, 0.4)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("vig", x), float(_grade_mat.get_shader_parameter("vig")), 0.0, 0.4)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("desat", x), float(_grade_mat.get_shader_parameter("desat")), 0.0, 0.3)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("tint", x), float(_grade_mat.get_shader_parameter("tint")), 0.0, 0.3)
	var held: Array = [v._player]
	for ev in hits:
		var i := int(ev.index)
		v._shockwave(_torso(i), 12.0, 1000.0, 0.4)
		P2Vfx.spawn(v._fx, "flash", _torso(i), {"color": Color("#e8fbff"), "size": 1.4})
		v._enemy_hit_feedback(ev, Color("#e8fbff"), "heavy")
		held.append(v._enemy_sprites[i])
	if not hits.is_empty():
		_impact(held, _torso(int(hits[0].index)))
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._hit_stop(held, 0.14)
	await _tw_done(t)
	await v._wait(0.12)


# 폭풍 연사: 누르는 동안 이미 쏜 화살이 맞는 순간들 — 타격 사건을 빠르게 차례로(숫자 작게) → 마지막 합계 크게
func _barrage(target: int, events: Array) -> void:
	var hits := _hits(events)
	var hunter: bool = v._dressed and v._art_cid == "hunter"
	var from: Vector2 = v._player.position + P2BattleView.HUNTER_BOW * v._ks if hunter else v._player_body() + Vector2(40, -20)
	var total := 0
	var per := clampf(0.5 / maxf(1.0, hits.size()), 0.018, 0.04)
	var counter: P2Vfx = null
	for k in range(hits.size()):
		var ev: Dictionary = hits[k]
		var i := int(ev.index)
		var last := k == hits.size() - 1
		var to := _torso(i) + Vector2(randf_range(-26, 26), randf_range(-50, 40))
		P2Vfx.spawn(v._fx, "streak", from, {"to": to, "color": Color("#ffe9a8"), "life": 0.12})
		if k % 3 == 0:
			P2Vfx.spawn(v._fx, "muzzle", from, {"color": C_LIGHT, "size": 0.8})
			v._sfx("arrow", randf_range(1.2, 1.5), -6.0)
		total += int(ev.damage)
		if counter == null or not is_instance_valid(counter):
			counter = P2Vfx.spawn(v._fx, "counter", _torso(i) + Vector2(-120, -40), {"color": Color("#ffd27a"), "life": -1.0})
		counter.bump(str(total))
		if last:
			await v._wait(0.08)
			var at := _torso(i)
			P2Vfx.spawn(v._fx, "flash", at, {"color": Color("#fff0c8"), "size": 1.3})
			v._shockwave(at, 12.0, 1000.0, 0.4)
			v._sfx("boom_m", 1.3)
			if total >= 20:
				_impact([v._player, v._enemy_sprites[i]], at)
			v._camera_kick("heavy", Vector2.RIGHT)
		quiet_hit(ev, Color("#ffd2a0"), last)
		await v._wait(per)
	if counter != null and is_instance_valid(counter):
		counter.bump(tr("합계 %d") % total)
		counter.end(1.1)
	await v._wait(0.3)


# ── 새 카드 연출 도우미 ──

# 사냥꾼은 활 쏘는 몸짓(접촉 프레임까지), 그 밖은 마법 자세. 돌려주는 값 = 쏘는 자리
func _shoot() -> Vector2:
	if v._dressed and v._art_cid == "hunter":
		v._actor_play("shot", 1)
		await v._await_frame("shot", v._contact("shot"))
		return v._player.position + P2BattleView.HUNTER_BOW * v._ks
	return await _cast(false)


# 그 직업 그림에 동작이 있으면 접촉 프레임까지, 없으면 앞으로 기울였다 돌아옴
func _swing(anim: String) -> void:
	if v._dressed and (v._art.anims as Dictionary).has(anim):
		v._actor_play(anim, 1)
		await v._await_frame(anim, v._contact(anim))
		return
	var lean := create_tween()
	lean.tween_property(v._player, "position:x", v._home_x + 14.0, 0.07)
	lean.tween_property(v._player, "position:x", v._home_x, 0.16)
	await v._wait(0.08)


# 대상 앞으로 붙기(근접 기술) · 제자리로
func _dash_to(target: int, gap := 110.0) -> void:
	var t := create_tween()
	t.tween_property(v._player, "position:x", maxf(v._home_x, _torso(target).x - gap), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	v._sfx("whoosh", 1.25, -4.0)
	await t.finished


func _dash_home() -> void:
	var t := create_tween()
	t.tween_property(v._player, "position:x", v._home_x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await t.finished


# 화면을 잠깐 한 색으로 물들임(다른 손질 값이 남아 있으면 화면 손질 층은 그대로 둔다)
func _tint_pulse(col: Color, peak: float, dur: float) -> void:
	if not _grade.visible:
		_grade_on()
	_grade_mat.set_shader_parameter("tint_color", col)
	var t := create_tween()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("tint", x), peak, 0.0, dur).set_ease(Tween.EASE_IN)
	t.tween_callback(_grade_idle)


func _grade_idle() -> void:
	for k in EVENT_KEYS:
		if absf(float(_grade_mat.get_shader_parameter(k))) > 0.001:
			return
	_grade.visible = false


# 시간이 느려짐: 채도가 빠지고 푸르게 · 가장자리가 어두워짐(놓으면 돌아옴)
func time_look(on: bool) -> void:
	if on:
		_grade_wake()
	elif not _grade.visible:
		return
	var t := create_tween().set_parallel()
	_grade_mat.set_shader_parameter("tint_color", Color(0.62, 0.8, 1.1))
	for pr in [["desat", 0.42], ["tint", 0.16], ["vig", 0.35]]:
		var key: String = pr[0]
		var to := float(pr[1]) if on else 0.0
		t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter(key, x), float(_grade_mat.get_shader_parameter(key)), to, 0.14 if on else 0.3)
	if not on:
		t.chain().tween_callback(_grade_idle)


# 큰 한 방: 맞은 자리에서 바깥으로 방사 흐림이 한 번 + 빛 번짐이 잠깐 세짐
func impact_look(at_w: Vector2, power: float) -> void:
	if v._reduce_motion:
		return
	_grade_wake()
	_grade_mat.set_shader_parameter("zoom_c", v._to_ui(at_w))
	var peak := clampf(power / 18.0, 0.25, 1.0)
	var t := create_tween()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("zoom", x), peak, 0.0, 0.16).set_ease(Tween.EASE_OUT)
	t.tween_callback(_grade_idle)


# 맞음: 가장자리가 붉게 번쩍 + 아주 짧은 색 분리
func hurt_look(dmg: int) -> void:
	if dmg <= 0:
		return
	var k := clampf(dmg / 12.0, 0.3, 1.0)
	_grade_wake()
	_grade_mat.set_shader_parameter("vig_color", Color(0.75, 0.05, 0.08))
	_grade_mat.set_shader_parameter("chroma_c", Vector2(640, 360))
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("vig", x), 0.55 * k, 0.0, 0.45)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("chroma", x), 5.0 * k, 0.0, 0.18)
	t.chain().tween_callback(func() -> void:
		_grade_mat.set_shader_parameter("vig_color", Color.BLACK)
		_grade_idle())


func _status_ev(events: Array, key: String, index := -1) -> Dictionary:
	for e in events:
		if String(e.kind) == "status" and String(e.key) == key and (index < 0 or int(e.index) == index):
			return e
	return {}


func _targets_of(events: Array, target: int) -> Array:
	for e in events:
		if String(e.kind) == "debuff_cast":
			return (e.targets as Array).duplicate()
	return [target] if target >= 0 else []


# 이 연출이 이미 보여 준 사건: 뒤따름에서 다시 그리지 않는다
func _show_now(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	followup(ev)
	ev["_shown"] = true


# ── 원소술사 ──

# 돌풍: 지팡이를 휘두르면 화면을 가로지르는 바람(속도선·나뭇잎)이 대상을 덮침 → 뒤로 밀려 휘청(밀림은 뒤따름)
func _gust(target: int, events: Array) -> void:
	var hand := await _cast(false)
	var hits := _hits(events)
	if target < 0 and not hits.is_empty():
		target = int(hits[0].index)
	var to := _torso(target)
	v._sfx("wind", 1.0)
	v._sfx("whoosh", 0.8)
	P2Vfx.spawn(v._fx, "wind", Vector2(to.x - 240.0, to.y), {"size": 1.2})
	P2Vfx.spawn(v._fx, "missile", hand, {"to": to, "style": "wind", "color": C_WIND, "life": 0.18, "arc": -30.0, "size": 1.4})
	await v._wait(0.18)
	for ev in hits:
		P2SkillFx.spawn(v._fx_back, "dust", _feet(int(ev.index)), Vector2.RIGHT, 1.6, Color("#b8ad9e"))
		v._enemy_hit_feedback(ev, C_WIND)
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._wait(0.14)


# 맹독 구름: 초록 방울을 적마다 포물선으로 던짐 → 발밑에서 구름이 피어오르고 거품 → 화면이 잠깐 초록빛
func _poison_cloud(events: Array) -> void:
	var hand := await _cast(false)
	v._sfx("gurgle", 0.9)
	var hits := _hits(events)
	for ev in hits:
		P2Vfx.spawn(v._fx, "missile", hand, {"to": _feet(int(ev.index)) + Vector2(0, -40), "style": "poison", "life": 0.32, "arc": 150.0, "size": 1.1})
	await v._wait(0.32)
	_tint_pulse(Color(0.55, 1.0, 0.45), 0.3, 0.7)
	v._sfx("splash", 0.8)
	v._sfx("gurgle", 1.2, -4.0)
	for ev in hits:
		var i := int(ev.index)
		P2Vfx.spawn(v._fx, "poison_puff", _feet(i), {"size": 1.6})
		P2HitBits.spawn(v._fxp, "drop", _feet(i) + Vector2(0, -20), Vector2.UP, 10, [C_POISON, Color("#b6ff7a"), Color("#3f7a2a")], 1.1)
		v._enemy_hit_feedback(ev, C_POISON, "secondary")
	await v._wait(0.4)


# 업화의 벽: 화면에 열 아지랑이 → 왼쪽부터 불기둥이 차례로 솟으며 적들을 훑음 → 지나간 적마다 불 폭발
func _fire_wall(events: Array, up := "") -> void:
	await _cast(true)
	v._sfx("fire", 0.8)
	v._sfx("power", 0.7)
	if not _grade.visible:
		_grade_on()
	_grade_mat.set_shader_parameter("tint_color", Color(1.0, 0.7, 0.45))
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("haze", x), 0.0, 1.0, 0.25)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("tint", x), 0.0, 0.22, 0.25)
	var hits := _hits(events)
	var lo := 9999.0
	var hi := 0.0
	for ev in hits:
		lo = minf(lo, _torso(int(ev.index)).x)
		hi = maxf(hi, _torso(int(ev.index)).x)
	if hits.is_empty():
		lo = 800.0
		hi = 1100.0
	var x := lo - 200.0
	var done := {}
	var n := 0
	while x <= hi + 150.0:
		P2Vfx.spawn(v._fx_back, "fire_pillar", Vector2(x + randf_range(-10, 10), P2BattleView.FEET_Y + 6.0), {"size": randf_range(0.9, 1.15)})
		if n % 2 == 0:
			v._sfx("fire", randf_range(1.0, 1.4), -8.0)
		for k in range(hits.size()):
			var ev: Dictionary = hits[k]
			var i := int(ev.index)
			if not done.has(k) and _torso(i).x <= x + 30.0:
				done[k] = true
				P2Vfx.spawn(v._fx, "fire_burst", _torso(i), {"size": 0.9})
				P2SkillFx.spawn(v._fx_back, "scorch", _feet(i), Vector2.RIGHT, 1.3, C_FIRE)
				v._sfx("boom_m", 1.2, -2.0)
				v._shockwave(_torso(i), 9.0, 900.0, 0.35)
				v._enemy_hit_feedback(ev, C_FIRE, "heavy")
		v._camera_kick("light", Vector2.RIGHT)
		n += 1
		x += 62.0
		await v._wait(0.045)
	if up == "pyre_burst":
		await _pyre_bursts(events)
	await v._wait(0.35)
	var t2 := create_tween().set_parallel()
	t2.tween_method(func(y: float) -> void: _grade_mat.set_shader_parameter("haze", y), 1.0, 0.0, 0.6)
	t2.tween_method(func(y: float) -> void: _grade_mat.set_shader_parameter("tint", y), 0.22, 0.0, 0.6)
	t2.chain().tween_callback(_grade_idle)


func _pyre_bursts(events: Array) -> void:
	var pyres := events.filter(func(e): return String(e.kind) == "pyre")
	if pyres.is_empty():
		return
	await v._wait(0.2)
	for pe in pyres:
		var i := int(pe.index)
		var base := Vector2(_torso(i).x, P2BattleView.FEET_Y + 6.0)
		P2Vfx.spawn(v._fx, "react_text", _torso(i) + Vector2(0, -190), {"text": tr("화상 폭발!"), "color": C_FIRE, "size": 0.9})
		var dots := events.filter(func(e): return String(e.kind) == "dot" and int(e.index) == i and String(e.key) == "burn" and not bool(e.get("_shown", false)))
		var n := dots.size()
		for q in range(n):
			var e: Dictionary = dots[q]
			var last := q == n - 1
			var off := Vector2(randf_range(-26, 26), 0)
			P2Vfx.spawn(v._fx_back, "fire_pillar", base + off, {"size": 1.1 + 0.25 * q + (0.5 if last else 0.0)})
			P2PackFx.spawn(v._fx, "569", "fire", base + off + Vector2(0, -60 - 14 * q), 2.0 + q * 0.5)
			P2PackFx.spawn(v._fx, "529", "fire", _torso(i) + Vector2(randf_range(-20, 20), -20), 2.0)
			v._shockwave(_torso(i), 10.0 + 4.0 * q, 1000.0, 0.4)
			v._sfx("fire", 1.2 - q * 0.1)
			v._sfx("boom_m" if not last else "boom_l", 1.1 - q * 0.05)
			v._camera_kick("heavy" if last else "light", Vector2.UP)
			_dot_feedback(e)
			e["_shown"] = true
			if last:
				P2Vfx.spawn(v._fx, "fire_burst", _torso(i), {"size": 1.5})
				P2HitBits.spawn(v._fxp, "ember", _torso(i), Vector2.UP, 22, [Color("#ffd25a"), Color("#ff6a1e"), Color("#fff0b0")], 1.6)
				if int(pe.amount) >= P2BattleView.BIG_IMPACT:
					_impact([v._player, v._enemy_sprites[i]], _torso(i))
			await v._wait(0.16 if not last else 0.1)
		pe["_shown"] = true
		await v._wait(0.12)


# ── 사냥꾼 ──

# 사냥용 덫: 쇠 덫이 빙글 돌며 날아가 대상 앞 바닥에 '철컥' 펼쳐짐 + 반짝(그 뒤엔 상태 모습의 덫이 남음)
func _bear_trap(target: int) -> void:
	var from := await _cast(false)
	var sp: AnimatedSprite2D = v._enemy_sprites[target]
	var spot := sp.position + Vector2(-v._vis_cached(target).x * 0.75, 2.0)
	P2Vfx.spawn(v._fx, "missile", from, {"to": spot + Vector2(0, -10), "style": "steel", "life": 0.34, "arc": 150.0, "size": 1.6})
	v._sfx("whoosh", 1.3)
	await v._wait(0.34)
	P2Vfx.spawn(v._fx_back, "trap_set", spot, {"size": 1.4})
	P2Vfx.spawn(v._fx, "flash", spot + Vector2(0, -10), {"color": Color("#e8eef4"), "size": 0.7})
	P2SkillFx.spawn(v._fx_back, "dust", spot, Vector2.RIGHT, 1.0, Color("#b8ad9e"))
	v._sfx("clang", 1.2)
	v._sfx("snap", 1.6, -6.0)
	await v._wait(0.35)


# 표적 지정: 붉은 조준선이 돌며 조여 고정 → 사냥꾼에게서 레이저 한 줄 → '찰칵' + 대상이 붉게 번쩍
func _mark_target(target: int) -> void:
	var hunter: bool = v._dressed and v._art_cid == "hunter"
	var from: Vector2 = v._player_body() + Vector2(40, -20)
	if hunter:
		v._actor_play("aim", 1)
		await v._await_frame("aim", v._contact("aim"))
		from = v._player.position + P2BattleView.HUNTER_BOW * v._ks
	P2Vfx.spawn(v._fx, "crosshair", _torso(target), {"to": from, "size": 1.1})
	v._sfx("lock", 1.0)
	_tint_pulse(Color(1.0, 0.55, 0.5), 0.2, 0.6)
	await v._wait(0.36)
	v._sfx("clang", 1.8, -6.0)
	v._actor_flash(v._enemy_sprites[target], Color("#ff3a3a"), 0.6, 0.02, 0.18)
	v._shockwave(_torso(target), 5.0, 600.0, 0.3)
	await v._wait(0.22)


# 출혈 화살: 붉은 꼬리 화살 세 발이 차례로 → 맞을 때마다 핏방울
func _bleed_arrows(events: Array) -> void:
	var from := await _shoot()
	var hits := _hits(events)
	for k in range(hits.size()):
		var ev: Dictionary = hits[k]
		var to := _torso(int(ev.index)) + Vector2(randf_range(-14, 14), randf_range(-34, 20))
		P2Vfx.spawn(v._fx, "missile", from, {"to": to, "style": "blood", "life": 0.1, "size": 1.3})
		v._sfx("bow", 1.15 + k * 0.1, -4.0)
		await v._wait(0.1)
		P2HitBits.spawn(v._fxp, "drop", to, Vector2.RIGHT, 9, [C_BLOOD, Color("#a01820"), Color("#ff6a6a")], 1.1)
		v._enemy_hit_feedback(ev, C_BLOOD, "heavy" if k == hits.size() - 1 else "secondary")
		await v._wait(0.07)
	await v._wait(0.12)


# ── 수호기사 ──

# 방패 부메랑: 금빛 방패가 적 사이를 지그재그로 튕기며(맞을 때마다 캉! 음이 높아짐) 돌아와 손에 탁
func _shield_boomerang(events: Array) -> void:
	await _swing("bash")
	var start: Vector2 = v._player_body() + Vector2(60, -30)
	var sh := P2Vfx.spawn(v._fx, "spin_shield", start, {"size": 0.8})
	v._sfx("whoosh", 1.1)
	var hits := _hits(events)
	for k in range(hits.size()):
		var ev: Dictionary = hits[k]
		var i := int(ev.index)
		var to := _torso(i) + Vector2(0, -26.0 if k % 2 == 0 else 22.0)
		var t := create_tween()
		t.tween_property(sh, "position", to, 0.14 if k == 0 else 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await t.finished
		v._sfx("clang", 1.0 + k * 0.2)
		v._sfx("bash", 1.1 + k * 0.1, -6.0)
		P2Vfx.spawn(v._fx, "flash", to, {"color": Color("#ffe9a8"), "size": 0.9})
		v._shockwave(to, 8.0, 900.0, 0.3)
		v._enemy_hit_feedback(ev, Color("#ffe9a8"), "heavy")
		v._camera_kick("heavy", Vector2.RIGHT)
		await v._hit_stop([v._enemy_sprites[i]], 0.05)
	var back := create_tween()
	back.tween_property(sh, "position", start + Vector2(0, -60), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	back.tween_property(sh, "position", start, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await back.finished
	sh.queue_free()
	v._sfx("block", 1.3)
	P2Vfx.spawn(v._fx, "flash", start, {"color": Color("#ffe9a8"), "size": 0.7})
	await v._wait(0.1)


# 성벽: 앞 땅이 갈라지며 반투명 육각 벽이 솟음 → 금빛 번쩍 (이번 적 차례 동안 남아 있다)
func _rampart(events: Array) -> void:
	await _swing("block")
	var at: Vector2 = v._player_body() + Vector2(86, 50)
	P2Vfx.spawn(v._fx, "wall_rise", at, {"size": 1.0})
	P2HitBits.spawn(v._fxp, "chunk", at, Vector2.UP, 12, [Color("#7a6a58"), Color("#b8ad9e"), Color("#e0ad4a")], 1.1)
	P2SkillFx.spawn(v._fx_back, "crack", at, Vector2.RIGHT, 1.4, Color("#e0ad4a"))
	v._sfx("power", 1.1)
	v._sfx("clang", 0.8)
	v._sfx("boom_m", 0.8, -6.0)
	v._shockwave(at, 6.0, 700.0, 0.35)
	_tint_pulse(Color(1.0, 0.9, 0.55), 0.25, 0.5)
	for e in events:
		if String(e.kind) == "guard":
			v._apply_event(e)
	v._float_number(tr("성벽 %d") % int(v.battle.wall), v._player_body() + Vector2(90, -180), Color("#ffe9a8"), 24, 26.0, 0.9)
	await v._wait(0.35)


# 위압의 함성: 주인공 둘레로 금빛 고리가 겹겹이 퍼짐 → 적들이 움찔 한 발 물러나고 보라 화살표가 내려앉음(약화)
func _war_cry(events: Array) -> void:
	await _swing("block")
	var at: Vector2 = v._player_body()
	P2Vfx.spawn(v._fx, "shout", at, {"color": Color("#ffd27a"), "size": 1.2})
	v._sfx("power", 0.6)
	v._sfx("boom_m", 0.7)
	v._camera_kick("heavy", Vector2.RIGHT)
	_grade_mat.set_shader_parameter("chroma_c", v._to_ui(at))
	_grade_pulse("chroma", 6.0, 0.3)
	v._shockwave(at, 14.0, 1100.0, 0.5)
	await v._wait(0.18)
	v._sfx("weaken", 1.0)
	for i in _targets_of(events, -1):
		_push(int(i))
		P2Vfx.spawn(v._fx, "down_arrows", _torso(int(i)) + Vector2(0, -40), {"color": C_HEX})
		v._actor_flash(v._enemy_sprites[int(i)], C_HEX, 0.5, 0.02, 0.15)
	await v._wait(0.35)
	_grade_idle()


# 철벽 반격: 평소 막기 + 방패 앞에 금빛이 모였다 번쩍(완벽 막기 반격이 세짐)
func _iron_counter(events: Array) -> void:
	await v._anim_guard(events)
	var at: Vector2 = v._player_body() + Vector2(46, -16)
	var orb := P2Vfx.spawn(v._fx, "charge_orb", at, {"color": Color("#ffd27a"), "size": 0.7})
	var t := create_tween()
	t.tween_property(orb, "level", 1.0, 0.35)
	v._sfx("charge", 1.2)
	await t.finished
	orb.queue_free()
	P2Vfx.spawn(v._fx, "flash", at, {"color": Color("#ffe9a8"), "size": 1.0})
	v._sfx("crit_ready", 1.3)
	v._float_number(tr("완벽 막기 반격 %d") % P2Catalog.IRON_COUNTER_DAMAGE, v._player_body() + Vector2(0, -120), Color("#ffd27a"), 22, 24.0, 1.0)
	await v._wait(0.15)


# ── 콤보술사 ──

# 올려 차기: 대상 앞으로 붙어 걷어 올림 → 대상이 솟구치고(이 자리에서 바로) 위로 솟는 속도선 · 화면이 위로 튐
func _launcher(target: int, events: Array) -> void:
	await _dash_to(target)
	await _swing("slash")
	P2Vfx.spawn(v._fx, "uplift", _feet(target), {"color": Color("#ffe9a8"), "size": 1.0})
	v._sfx("kick", 1.0)
	v._sfx("boom_m", 1.4, -4.0)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, Color("#ffd2a0"), "heavy")
	_show_now(_status_ev(events, "air", target))
	v._camera_kick("heavy", Vector2.UP)
	v._shockwave(_feet(target), 8.0, 800.0, 0.3)
	await v._wait(0.16)
	await _dash_home()


# 백열권: 대상 앞에 붙어 주먹 잔상 수십 개가 대상을 덮음(합계가 쌓임) → 마지막 한 방 크게 + 흑백
func _hundred_fists(target: int, events: Array, up := "") -> void:
	await _dash_to(target, 120.0)
	var hits := _hits(events)
	var total := 0
	var counter: P2Vfx = null
	var px: float = v._player.position.x
	for k in range(hits.size()):
		var ev: Dictionary = hits[k]
		var i := int(ev.index)
		var last := k == hits.size() - 1
		var to := _torso(i) + Vector2(randf_range(-40, 24), randf_range(-64, 40))
		var d := Vector2(1.0, randf_range(-0.5, 0.5)).normalized()
		P2Vfx.spawn(v._fx, "fist", to, {"dir": d, "color": Color("#ffd2a0"), "size": 2.0 if last else randf_range(0.7, 1.2)})
		if not last and k % 2 == 0:
			P2Vfx.spawn(v._fx, "fist", to + Vector2(randf_range(-30, 10), randf_range(-30, 30)), {"dir": d.rotated(0.3), "color": Color("#ffb070"), "size": 0.8})
		v._sfx("punch", randf_range(1.1, 1.6), -6.0)
		v._player.position.x = px + (6.0 if k % 2 == 0 else -2.0)
		total += int(ev.damage)
		if counter == null or not is_instance_valid(counter):
			counter = P2Vfx.spawn(v._fx, "counter", _torso(i) + Vector2(-130, -50), {"color": Color("#ffd27a"), "life": -1.0})
		counter.bump(str(total))
		if last and up == "thousand_fists":
			await _final_fist(i)
		if last:
			await v._wait(0.1)
			v._sfx("boom_l", 1.2)
			v._sfx("punch", 0.7)
			P2Vfx.spawn(v._fx, "flash", _torso(i), {"color": Color("#fff0c8"), "size": 1.4})
			v._shockwave(_torso(i), 14.0, 1100.0, 0.45)
			_impact([v._player, v._enemy_sprites[i]], _torso(i))
			v._camera_kick("heavy", Vector2.RIGHT)
		elif k % 3 == 0:
			v._camera_kick("light", Vector2.RIGHT)
		quiet_hit(ev, Color("#ffd2a0"), last)
		await v._wait(0.04)
	v._player.position.x = px
	if counter != null and is_instance_valid(counter):
		counter.bump(tr("합계 %d") % total)
		counter.end(1.1)
	await v._wait(0.2)
	await _dash_home()


# 기공파: (모으기는 입력에서) 두 손 앞 구슬 → 놓으면 하늘색 광선이 대상을 꿰뚫고 화면 끝까지 + 색 분리 + 흑백
func _ki_blast(target: int, events: Array) -> void:
	var from: Vector2 = v._player_body() + Vector2(40, -10)
	if is_instance_valid(_held_orb):
		_held_orb.queue_free()
	var to := _torso(target) if target >= 0 else from + Vector2(600, 0)
	var far := from + (to - from).normalized() * 1500.0
	v._sfx("boom_l", 1.1)
	v._sfx("power", 1.4)
	P2Vfx.spawn(v._fx, "muzzle", from, {"color": Color("#bff0ff"), "size": 2.4})
	P2Vfx.spawn(v._fx, "beam", from, {"to": far, "color": Color("#7fd6ff"), "size": 1.5})
	if not _grade.visible:
		_grade_on()
	_grade_mat.set_shader_parameter("chroma_c", v._to_ui(from))
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("chroma", x), 14.0, 0.0, 0.45)
	for k in ["bars", "vig", "desat", "tint"]:
		var key: String = k
		t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter(key, x), float(_grade_mat.get_shader_parameter(key)), 0.0, 0.4)
	var held: Array = [v._player]
	for ev in _hits(events):
		var i := int(ev.index)
		v._shockwave(_torso(i), 14.0, 1000.0, 0.45)
		P2Vfx.spawn(v._fx, "flash", _torso(i), {"color": Color("#e8fbff"), "size": 1.6})
		v._enemy_hit_feedback(ev, Color("#bff0ff"), "heavy")
		held.append(v._enemy_sprites[i])
		_impact(held, _torso(i))
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._hit_stop(held, 0.14)
	await _tw_done(t)
	await v._wait(0.12)


# 천열권 마지막 한 방: 잠깐 뒤로 당겼다가(연격 수만큼 금빛 고리가 모임) → 손으로 찍은 주먹 그림을 6배로 키워
# 잔상을 끌며 대상에 꽂음(최근접 확대라 픽셀 그대로)
const FIST_ICON := Rect2(192, 1312, 32, 32)


func _final_fist(i: int) -> void:
	var at := _torso(i)
	var n: int = maxi(1, v.battle.combo)
	var home: float = v._player.position.x
	var pull := create_tween()
	pull.tween_property(v._player, "position:x", home - 26.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	v._sfx("charge", 1.0)
	_grade_wake()
	_grade_mat.set_shader_parameter("chroma_c", v._to_ui(at))
	_grade_mat.set_shader_parameter("vig", 0.5)
	var hand: Vector2 = v._player_body() + Vector2(30, -10)
	for k in range(mini(n, 3)):
		P2Vfx.spawn(v._fx, "shout", hand, {"color": Color("#ffd27a"), "size": 0.28 + 0.1 * k, "life": 0.28})
		v._sfx("punch", 1.6 + k * 0.1, -8.0)
		await v._wait(0.06)
	await _tw_done(pull)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(P2Catalog.RAVEN)
	atlas.region = FIST_ICON
	var from := hand
	var to := at + Vector2(-30, 0)
	var fist := Sprite2D.new()
	fist.texture = atlas
	fist.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fist.rotation = PI / 2.0
	fist.scale = Vector2.ONE * 3.0
	fist.position = from
	fist.z_index = 5
	v._fx.add_child(fist)
	v._sfx("whoosh", 0.8)
	var go := create_tween()
	go.tween_property(v._player, "position:x", home + 30.0, 0.08)
	var fly := create_tween().set_parallel()
	fly.tween_property(fist, "position", to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(fist, "scale", Vector2.ONE * 6.0, 0.12)
	for k in range(4):
		await v._wait(0.03)
		var ghost := Sprite2D.new()
		ghost.texture = atlas
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.rotation = fist.rotation
		ghost.scale = fist.scale
		ghost.position = fist.position
		ghost.modulate = Color(1.0, 0.82, 0.45, 0.6)
		v._fx.add_child(ghost)
		var gt := create_tween()
		gt.tween_property(ghost, "modulate:a", 0.0, 0.2)
		gt.tween_callback(ghost.queue_free)
	await _tw_done(fly)
	P2Vfx.spawn(v._fx, "react_text", at + Vector2(0, -150), {"text": tr("연격 %d × 2") % n, "color": Color("#ffd27a"), "size": 1.1})
	_grade_pulse("chroma", 12.0, 0.3)
	_grade_mat.set_shader_parameter("vig", 0.0)
	var out := create_tween()
	out.tween_interval(0.12)
	out.tween_property(fist, "modulate:a", 0.0, 0.18)
	out.tween_callback(fist.queue_free)
	var back := create_tween()
	back.tween_interval(0.3)
	back.tween_property(v._player, "position:x", home, 0.2)


# ── 주술사 ──

# 저주탄: 해골 구슬이 흔들리며 날아가 박힘 → 보라 균열 + 금 고리
func _hex_bolt(target: int, events: Array, up := "") -> void:
	var hand := await _cast(false)
	var to := _torso(target)
	v._sfx("ghost", 1.3)
	await _fly(hand, to, "hex", 0.24, 36.0, 1.3)
	P2Vfx.spawn(v._fx, "rift_burst", to, {"size": 0.7})
	P2Vfx.spawn(v._fx, "crack_ring", to, {"color": C_HEX, "size": 1.1})
	v._sfx("spook", 1.2)
	v._sfx("magic_hit", 0.9, -4.0)
	v._shockwave(to, 7.0, 800.0, 0.3)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, C_HEX)
	await v._wait(0.16)
	for ev in events:
		if String(ev.kind) == "hex_spread":
			await _hex_spread(ev, events)


func _hex_spread(ev: Dictionary, events: Array) -> void:
	var from := _torso(int(ev.index))
	P2Vfx.spawn(v._fx, "skull", from + Vector2(0, -40), {"size": 0.6})
	v._sfx("spook", 1.1)
	await v._wait(0.15)
	for o in ev.to:
		P2Vfx.spawn(v._fx, "chain_line", from, {"to": _torso(int(o)), "color": C_HEX})
	v._sfx("clang", 0.9)
	v._sfx("ghost", 1.2, -4.0)
	await v._wait(0.32)
	for o in ev.to:
		var i := int(o)
		P2Vfx.spawn(v._fx, "hourglass", _torso(i) + Vector2(0, -60), {"size": 0.7, "life": 0.9})
		v._actor_flash(v._enemy_sprites[i], C_HEX, 0.6, 0.02, 0.18)
	for e in events:
		if String(e.kind) == "status" and String(e.key) == "doom" and int(e.index) != int(ev.index):
			_show_now(e)
	ev["_shown"] = true
	await v._wait(0.3)


# 파멸의 낙인: 대상 발밑에 보라 마법진 → 몸 위로 모래시계가 떠올라 뒤집히고 모래가 흐름 → 째깍
func _doom_brand(target: int, up := "") -> void:
	await _cast(true)
	P2SkillFx.spawn(v._fx_back, "sigil", _feet(target), Vector2.RIGHT, 1.4, C_HEX)
	if up == "swift_doom":
		await _swift_doom(target)
		return
	P2Vfx.spawn(v._fx, "hourglass", _torso(target) + Vector2(0, -60), {"size": 1.1})
	v._sfx("mystery", 0.8)
	v._sfx("ghost", 0.7)
	_tint_pulse(Color(0.75, 0.45, 1.0), 0.35, 0.9)
	await v._wait(0.45)
	v._sfx("clang", 0.6, -6.0)
	v._actor_flash(v._enemy_sprites[target], C_HEX, 0.6, 0.02, 0.2)
	await v._wait(0.4)


func _swift_doom(target: int) -> void:
	var at := _torso(target) + Vector2(0, -60)
	_tint_pulse(Color(0.8, 0.35, 1.0), 0.45, 1.0)
	v._sfx("mystery", 1.2)
	for k in range(4):
		P2Vfx.spawn(v._fx, "hourglass", at, {"size": 1.1 + k * 0.05, "life": 0.35})
		v._sfx("clang", 1.2 + k * 0.15, -6.0)
		await v._wait(0.12)
	P2Vfx.spawn(v._fx, "crack_ring", at, {"color": Color("#e0b0ff"), "size": 1.4})
	P2Vfx.spawn(v._fx, "skull", _torso(target), {"size": 0.9})
	v._sfx("glass", 0.9)
	v._sfx("spook", 0.8)
	v._shockwave(_torso(target), 8.0, 800.0, 0.35)
	v._world_number(tr("이번 턴 끝에 폭발!"), _torso(target) + Vector2(0, -170), C_HEX, 24, 24.0, 1.2)
	v._actor_flash(v._enemy_sprites[target], C_HEX, 0.7, 0.02, 0.25)
	await v._wait(0.4)


# 쇠약: 대상 몸에서 보랏빛 넋이 빨려 나와 주인공에게 흘러듦 → 보라 화살표가 내려앉음(약화·취약)
func _enfeeble(target: int) -> void:
	var hand := await _cast(false)
	var from := _torso(target)
	v._sfx("slurp", 0.9)
	v._sfx("ghost", 1.1, -4.0)
	v._actor_flash(v._enemy_sprites[target], Color("#3a1050"), 0.55, 0.05, 0.3)
	for k in range(6):
		P2Vfx.spawn(v._fx, "missile", from + Vector2(randf_range(-30, 30), randf_range(-50, 30)), {"to": hand + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "style": "soul", "color": C_HEX, "life": 0.36 + k * 0.04, "arc": randf_range(-60.0, 90.0), "size": 0.8})
		await v._wait(0.05)
	P2Vfx.spawn(v._fx, "down_arrows", from + Vector2(0, -30), {"color": C_HEX, "size": 1.1})
	v._sfx("weaken", 1.0)
	await v._wait(0.25)
	v._actor_flash(v._player, C_HEX, 0.4, 0.02, 0.2)
	await v._wait(0.15)


# 갑옷 부수기: 쇠사슬 셋이 몸을 감아 조이다 '쩡' 끊어짐(갑옷 파괴는 뒤따름) + 물리 타격
func _armor_break(target: int, events: Array) -> void:
	await _cast(false)
	var to := _torso(target)
	P2Vfx.spawn(v._fx, "chains", to, {"color": Color("#c9d2da"), "size": 1.0})
	v._sfx("clang", 0.7)
	v._sfx("lock", 0.8)
	await v._wait(0.42)
	v._sfx("glass", 0.8)
	v._sfx("clang", 1.4)
	v._sfx("crunch", 1.0)
	v._shockwave(to, 10.0, 900.0, 0.35)
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, Color("#c9d2da"), "heavy")
	v._camera_kick("heavy", Vector2.RIGHT)
	await v._wait(0.25)


# 고통 연결: 두 적 사이에 보라 사슬이 쭉 뻗어 묶임 → 사슬을 따라 번개 한 번
func _soul_link(target: int, events: Array) -> void:
	await _cast(false)
	var a := target
	var b := -1
	for e in events:
		if String(e.kind) == "linked":
			a = int(e.index)
			b = int(e.other)
	if a < 0:
		return
	if b < 0:
		v._actor_flash(v._enemy_sprites[a], C_HEX, 0.5, 0.02, 0.15)
		await v._wait(0.2)
		return
	P2Vfx.spawn(v._fx, "chain_line", _torso(a), {"to": _torso(b), "color": C_HEX})
	v._sfx("clang", 1.0)
	v._sfx("lock", 1.2)
	await v._wait(0.32)
	v._lightning(_torso(a), _torso(b))
	v._sfx("arc", 1.2)
	v._actor_flash(v._enemy_sprites[a], C_HEX, 0.6, 0.02, 0.15)
	v._actor_flash(v._enemy_sprites[b], C_HEX, 0.6, 0.02, 0.15)
	await v._wait(0.3)


# 피의 계약: 체력을 바쳐 핏방울이 솟고 몸에 붉은 기운 · 화면 가장자리가 붉게
func _blood_pact(events: Array) -> void:
	await _cast(false)
	var feet := Vector2(v._player_body().x, P2BattleView.FEET_Y)
	P2Vfx.spawn(v._fx_back, "aura", feet, {"color": C_BLOOD, "size": 1.0})
	P2HitBits.spawn(v._fxp, "drop", v._player_body(), Vector2.UP, 14, [C_BLOOD, Color("#a01820"), Color("#ff6a6a")], 1.2)
	v._sfx("slurp", 0.6)
	v._sfx("power", 0.8)
	v._sfx("hurt", 1.2, -6.0)
	if not _grade.visible:
		_grade_on()
	_grade_mat.set_shader_parameter("tint_color", Color(1.0, 0.4, 0.4))
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("vig", x), 0.7, 0.0, 0.9)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("tint", x), 0.3, 0.0, 0.9)
	t.chain().tween_callback(_grade_idle)
	v._float_number(tr("이번 턴 공격 ×%.1f") % P2Catalog.BLOOD_PACT_MULT, v._player_body() + Vector2(0, -130), C_BLOOD, 24, 26.0, 1.0)
	await v._wait(0.45)


# 영혼 흡수: 모든 적에게 보라 파열 → 맞은 적마다 넋이 빠져나와 주인공에게 흘러듦(저주받은 적은 크게)
func _soul_drain(events: Array) -> void:
	var hand := await _cast(true)
	v._sfx("ghost", 0.8)
	var hits := _hits(events)
	for ev in hits:
		var i := int(ev.index)
		P2Vfx.spawn(v._fx, "rift_burst", _torso(i), {"size": 0.6})
		v._enemy_hit_feedback(ev, C_HEX, "secondary")
	await v._wait(0.15)
	v._sfx("slurp", 0.8)
	for ev in hits:
		var i2 := int(ev.index)
		var big := int(ev.damage) >= P2Catalog.DRAIN_BONUS
		for k in range(4 if big else 2):
			P2Vfx.spawn(v._fx, "missile", _torso(i2) + Vector2(randf_range(-20, 20), randf_range(-40, 20)), {"to": hand + Vector2(randf_range(-16, 16), randf_range(-16, 16)), "style": "soul", "color": C_HEX if big else Color("#a8a0c8"), "life": 0.42 + k * 0.05, "arc": randf_range(40.0, 120.0), "size": 1.0 if big else 0.7})
	await v._wait(0.5)
	v._actor_flash(v._player, Color("#8be08b"), 0.5, 0.03, 0.2)


# 역병 전파: 모든 적 발밑에 보라 마법진 → 해골 연기가 피어오름
func _plague(events: Array) -> void:
	await _cast(true)
	v._sfx("ghost", 0.6)
	_tint_pulse(Color(0.75, 0.45, 1.0), 0.3, 0.8)
	for i in _targets_of(events, -1):
		P2SkillFx.spawn(v._fx_back, "sigil", _feet(int(i)), Vector2.RIGHT, 1.2, C_HEX)
	await v._wait(0.25)
	v._sfx("spook", 0.9)
	for i in _targets_of(events, -1):
		P2Vfx.spawn(v._fx, "skull", _torso(int(i)) + Vector2(0, -30), {"size": 0.7})
		v._actor_flash(v._enemy_sprites[int(i)], C_HEX, 0.5, 0.02, 0.2)
	await v._wait(0.45)


# ── 공용 ──

# 약점 폭로: 조준선이 조이고 대상 몸에 금이 쩍(받는 피해 증가)
func _expose(target: int) -> void:
	await _cast(false)
	var to := _torso(target)
	P2Vfx.spawn(v._fx, "crosshair", to, {"to": to, "size": 0.8})
	v._sfx("lock", 1.2)
	await v._wait(0.3)
	P2Vfx.spawn(v._fx, "crack_ring", to, {"color": Color("#ff9a7a"), "size": 1.6})
	v._sfx("crack", 1.2)
	v._sfx("glass", 1.5, -6.0)
	v._actor_flash(v._enemy_sprites[target], Color("#ff5a4a"), 0.5, 0.02, 0.15)
	await v._wait(0.25)


# 무력화: 보라 화살표가 내려앉고 대상이 움찔(주는 피해 감소)
func _disarm(target: int) -> void:
	await _cast(false)
	P2Vfx.spawn(v._fx, "down_arrows", _torso(target) + Vector2(0, -30), {"color": C_HEX, "size": 1.2})
	v._sfx("weaken", 1.0)
	v._sfx("clang", 0.8, -6.0)
	v._actor_flash(v._enemy_sprites[target], C_HEX, 0.5, 0.02, 0.15)
	_push(target)
	await v._wait(0.35)


# 전투 함성: 주인공 둘레 붉은 고리 + 몸에 붉은 기운(이번 턴 타격마다 +)
func _war_shout() -> void:
	await _swing("block")
	var at: Vector2 = v._player_body()
	P2Vfx.spawn(v._fx, "shout", at, {"color": Color("#ff7a4a"), "size": 0.9})
	P2Vfx.spawn(v._fx_back, "aura", Vector2(at.x, P2BattleView.FEET_Y), {"color": Color("#ff6a2a"), "size": 1.0})
	v._sfx("power", 0.9)
	v._sfx("boom_m", 0.9, -4.0)
	v._camera_kick("heavy", Vector2.RIGHT)
	v._float_number(tr("이번 턴 타격마다 +%d") % int(v.battle.rage), at + Vector2(0, -130), Color("#ff9a6a"), 22, 26.0, 1.0)
	await v._wait(0.4)


# 독 바르기: 손끝에서 초록 독이 흘러내림 + 초록 기운
func _poison_coat() -> void:
	var hand := await _cast(false)
	P2Vfx.spawn(v._fx_back, "aura", Vector2(v._player_body().x, P2BattleView.FEET_Y), {"color": C_POISON, "size": 0.8})
	P2HitBits.spawn(v._fxp, "drop", hand, Vector2.DOWN, 10, [C_POISON, Color("#b6ff7a"), Color("#3f7a2a")], 1.0)
	v._sfx("slurp", 1.2)
	v._sfx("gurgle", 1.3, -4.0)
	v._float_number(tr("물리 %d타에 독") % P2Catalog.COAT_HITS, v._player_body() + Vector2(0, -130), C_POISON, 22, 26.0, 1.0)
	await v._wait(0.4)


# 연막: 발밑에서 연막이 터져 회색 연기가 주인공을 감쌈
func _smoke_bomb() -> void:
	await _cast(false)
	var at: Vector2 = v._player_body() + Vector2(10, 30)
	P2Vfx.spawn(v._fx, "smoke", at, {"size": 1.1})
	v._sfx("whoosh", 0.7)
	v._sfx("static", 1.4, -8.0)
	v._float_number(tr("연막"), v._player_body() + Vector2(0, -130), Color("#c9d2da"), 24, 26.0, 1.0)
	await v._wait(0.45)


# 여러 번 맞는 기술의 한 타: 번쩍·움찔·체력만(숫자는 쌓이는 합계가 맡음). 쓰러지는 타격은 평소 처리
# 여러 적을 번갈아 맞히는 순서(적마다 묶인 사건을 하나씩 돌려 가며)
func _interleave(hits: Array) -> Array:
	var by := {}
	for ev in hits:
		var i := int(ev.index)
		if not by.has(i):
			by[i] = []
		(by[i] as Array).append(ev)
	var out: Array = []
	var k := 0
	while out.size() < hits.size():
		for i2 in by:
			var list: Array = by[i2]
			if k < list.size():
				out.append(list[k])
		k += 1
	return out


func quiet_hit(ev: Dictionary, color: Color, heavy := false) -> void:
	var i := int(ev.index)
	var sprite: AnimatedSprite2D = v._enemy_sprites[i]
	v._actor_flash(sprite, color.lerp(Color.WHITE, 0.6), 0.7 if heavy else 0.5, 0.01, 0.05)
	v._victim_react(sprite, "heavy" if heavy else "secondary", Vector2.RIGHT, bool(ev.dead))
	if int(ev.damage) > 0:
		v._art_hurt(sprite, bool(ev.dead), int(ev.get("shield_left", -1)))
	elif int(ev.get("shield_block", 0)) > 0:
		v._shield_absorb(sprite, int(ev.shield_left))
	var pos := _torso(i) + Vector2(randf_range(-20, 20), randf_range(-40, 30))
	v._sparks(pos, Vector2.RIGHT, 0.9, 6 if heavy else 3, [Color.WHITE, color], true, Vector2(160, 420))
	v._apply_event(ev)


# ── 필살 연출 ──

# 오원소 연사: 지팡이 앞에 다섯 원소 구슬이 차례로 맺힘(톡톡) → 한 발씩 파바바방 · 빔마다 색 · 맞는 적마다 그 원소 터짐 ·
# 빔 사이사이 묻힌 원소끼리 반응이 바로 터짐(사건 순서 그대로) → 마지막 어둠 빔에 흑백
const BEAM_COL := {"fire": Color("#ff7a2a"), "ice": Color("#7fd6ff"), "poison": Color("#8ae04a"), "light": Color("#ffe27a"), "dark": Color("#b46aff")}
const BEAM_HIT := {"fire": ["71", "fire"], "ice": ["116", "ice"], "poison": ["519", "poison"], "light": ["652", "light"], "dark": ["71", "dark"]}


func _ult_elements(events: Array) -> void:
	var hand := await _cast(true)
	_grade_on()
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("vig", x), 0.0, 0.55, 0.3)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("bars", x), 0.0, 0.6, 0.3)
	var beams := events.filter(func(e): return String(e.kind) == "beam")
	var orbs: Array = []
	for k in range(beams.size()):
		var e := String(beams[k].elem)
		var at := hand + Vector2(18 + 10 * k, -46 + 23 * k)
		var o := P2Vfx.spawn(v._fx, "charge_orb", at, {"color": BEAM_COL[e], "size": 0.5, "level": 0.3})
		orbs.append(o)
		P2PackFx.spawn(v._fx, "652", e, at, 1.0)
		v._sfx("charge", 1.1 + k * 0.12, -4.0)
		await v._wait(0.08)
	await v._wait(0.12)
	var cur := -1
	var held: Array = [v._player]
	for ev in events:
		match String(ev.kind):
			"beam":
				cur += 1
				var e2 := String(ev.elem)
				var from: Vector2 = (orbs[cur] as Node2D).position if cur < orbs.size() and is_instance_valid(orbs[cur]) else hand
				if cur < orbs.size() and is_instance_valid(orbs[cur]):
					(orbs[cur] as Node).queue_free()
				var col: Color = BEAM_COL[e2]
				P2Vfx.spawn(v._fx, "muzzle", from, {"color": col, "size": 1.8})
				P2Vfx.spawn(v._fx, "beam", from, {"to": from + Vector2(1500, randf_range(-20, 20)), "color": col, "size": 1.2, "life": 0.4})
				_grade_mat.set_shader_parameter("chroma_c", v._to_ui(from))
				_grade_pulse("chroma", 8.0, 0.15)
				v._sfx("boom_m", 1.3 - cur * 0.08)
				v._sfx({"fire": "fire", "ice": "ice", "poison": "gurgle", "light": "power", "dark": "ghost"}.get(e2, "power"), 1.1)
				v._camera_kick("heavy", Vector2.RIGHT)
				await v._wait(0.05)
			"hit":
				var i := int(ev.index)
				var e3: String = String(beams[maxi(cur, 0)].elem) if not beams.is_empty() else "light"
				var hp: Array = BEAM_HIT[e3]
				P2PackFx.spawn(v._fx, String(hp[0]), String(hp[1]), _torso(i) + Vector2(randf_range(-14, 14), randf_range(-20, 10)), 2.0)
				quiet_hit(ev, BEAM_COL[e3], cur == beams.size() - 1)
				v._damage_number(str(int(ev.damage)), _torso(i) + Vector2(randf_range(-30, 30), -60 - 14 * cur), "magic", 26)
				if not held.has(v._enemy_sprites[i]):
					held.append(v._enemy_sprites[i])
			"react", "dot", "status", "steam_splash":
				if followup(ev):
					ev["_shown"] = true
				if String(ev.kind) == "react":
					await v._wait(0.14)
		if String(ev.kind) == "beam":
			await v._wait(0.07)
	await v._wait(0.1)
	if held.size() > 1:
		_impact(held, _torso(v._enemy_sprites.find(held[1])) if v._enemy_sprites.find(held[1]) >= 0 else Vector2(900, 280))
	v._shockwave(Vector2(900, 280), 16.0, 1200.0, 0.5)
	await v._wait(0.4)
	_grade_off(0.3)


func _ult_arrows(events: Array) -> void:
	var home: Vector2 = v._player.position
	_grade_on()
	_grade_mat.set_shader_parameter("tint_color", Color(0.55, 0.62, 0.9))
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("vig", x), 0.0, 0.75, 0.35)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("tint", x), 0.0, 0.35, 0.35)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("desat", x), 0.0, 0.25, 0.35)
	# 높이 뛰어올라 화면 밖으로
	P2SkillFx.spawn(v._fx_back, "dust", Vector2(home.x, P2BattleView.FEET_Y), Vector2.RIGHT, 1.8, Color("#b8ad9e"))
	P2Vfx.spawn(v._fx, "uplift", Vector2(home.x, P2BattleView.FEET_Y), {"color": Color("#ffe9a8"), "size": 1.2})
	v._sfx("whoosh", 0.7)
	v._sfx("bow", 0.6)
	var up := create_tween()
	up.tween_property(v._player, "position:y", home.y - 560.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	v._camera_kick("heavy", Vector2.UP)
	await v._wait(0.32)
	# 하늘이 화살로 어두워지고 비처럼 쏟아짐 · 적마다 합계가 쌓임
	P2Vfx.spawn(v._fx, "arrow_sky", Vector2.ZERO, {"color": Color("#ffe9a8")})
	v._sfx("wind", 0.6)
	v._sfx("bow", 0.8, -2.0)
	await v._wait(0.42)
	var hits := _interleave(_hits(events))
	var per := 1.1 / maxf(1.0, hits.size())
	var counters := {}
	var totals := {}
	for k in range(hits.size()):
		var ev: Dictionary = hits[k]
		var i := int(ev.index)
		totals[i] = int(totals.get(i, 0)) + int(ev.damage)
		if not counters.has(i) or not is_instance_valid(counters[i]):
			counters[i] = P2Vfx.spawn(v._fx, "counter", _torso(i) + Vector2(-90, -40), {"color": Color("#ffd27a"), "life": -1.0})
		(counters[i] as P2Vfx).bump(str(totals[i]))
		quiet_hit(ev, Color("#ffd2a0"))
		if k % 3 == 0:
			v._sfx("arrow", randf_range(1.0, 1.5), -4.0)
		if k % 6 == 0:
			v._camera_kick("light", Vector2.DOWN)
		await v._wait(per)
	# 착지: 먼지 · 충격파 · 흑백
	var down := create_tween()
	down.tween_property(v._player, "position:y", home.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await down.finished
	v._sfx("bash", 0.8)
	v._sfx("boom_m", 0.9)
	P2SkillFx.spawn(v._fx_back, "dust", Vector2(home.x, P2BattleView.FEET_Y), Vector2.RIGHT, 2.0, Color("#b8ad9e"))
	v._shockwave(Vector2(home.x, P2BattleView.FEET_Y - 20.0), 12.0, 900.0, 0.4)
	v._camera_kick("heavy", Vector2.DOWN)
	var held: Array = [v._player]
	for i2 in counters:
		held.append(v._enemy_sprites[int(i2)])
		if is_instance_valid(counters[i2]):
			(counters[i2] as P2Vfx).bump(tr("합계 %d") % int(totals[i2]))
			(counters[i2] as P2Vfx).end(1.2)
	if held.size() > 1:
		_impact(held, _torso(int(counters.keys()[0])))
	await v._wait(0.5)
	_grade_off(0.4)



func _ult_shield(events: Array) -> void:
	var hits := _hits(events)
	var cx := 900.0
	if not hits.is_empty():
		cx = 0.0
		for ev in hits:
			cx += _torso(int(ev.index)).x
		cx /= hits.size()
	var ground := Vector2(cx, P2BattleView.FEET_Y)
	var home: Vector2 = v._player.position
	_grade_on()
	_grade_mat.set_shader_parameter("tint_color", Color(1.0, 0.86, 0.5))
	# 화면 밖으로 뛰어오름
	P2SkillFx.spawn(v._fx_back, "dust", Vector2(home.x, P2BattleView.FEET_Y), Vector2.RIGHT, 1.8, Color("#b8ad9e"))
	P2Vfx.spawn(v._fx, "uplift", Vector2(home.x, P2BattleView.FEET_Y), {"color": Color("#ffe9a8"), "size": 1.2})
	v._sfx("whoosh", 0.6)
	var up := create_tween()
	up.tween_property(v._player, "position:y", home.y - 580.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	v._camera_kick("heavy", Vector2.UP)
	await v._wait(0.26)
	# 하늘에서 거대한 빛의 방패: 땅의 그림자가 커지며 내려옴 · 화면이 금빛으로
	P2Vfx.spawn(v._fx, "giant_shield", ground, {"color": Color("#e0ad4a"), "size": 1.7, "life": 1.2})
	v._sfx("power", 0.6)
	v._sfx("charge", 0.6)
	var t := create_tween()
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("tint", x), 0.0, 0.35, 0.6)
	await v._wait(0.66)
	v._sfx("boom_l", 0.8)
	v._sfx("bash", 0.7)
	v._sfx("crunch", 0.7)
	for k in range(3):
		v._shockwave(ground + Vector2(0, -40), 22.0 - k * 4.0, 1300.0 - k * 220.0, 0.65)
	_grade_mat.set_shader_parameter("chroma_c", v._to_ui(ground))
	_grade_pulse("chroma", 12.0, 0.45)
	if not hits.is_empty():
		_impact([v._player] + hits.map(func(e): return v._enemy_sprites[int(e.index)]), ground + Vector2(0, -80))
	P2SkillFx.spawn(v._fx_back, "crack", ground, Vector2.RIGHT, 3.4, Color("#e0ad4a"))
	for ev in hits:
		var i := int(ev.index)
		P2SkillFx.spawn(v._fx_back, "quake", _feet(i), Vector2.RIGHT, 1.6, Color("#e0ad4a"))
		P2HitBits.spawn(v._fxp, "chunk", _feet(i) + Vector2(0, -10), Vector2.UP, 26, [Color("#7a6a58"), Color("#b8ad9e"), Color("#5a4c40"), Color("#e0ad4a")], 1.7)
		P2Vfx.spawn(v._fx, "light_pillar", _feet(i), {"color": Color("#ffe9a8"), "size": 1.3})
		v._enemy_hit_feedback(ev, Color("#ffe9a8"), "heavy")
	v._camera_kick("heavy", Vector2.DOWN)
	await v._wait(0.4)
	var down := create_tween()
	down.tween_property(v._player, "position:y", home.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await down.finished
	v._sfx("bash", 1.0, -4.0)
	P2SkillFx.spawn(v._fx_back, "dust", Vector2(home.x, P2BattleView.FEET_Y), Vector2.RIGHT, 1.6, Color("#b8ad9e"))
	await v._wait(0.3)
	_grade_off(0.35)



func _ult_panels(target: int, events: Array) -> void:
	var to := _torso(target) if target >= 0 else Vector2(900, 280)
	if target >= 0:
		await _dash_to(target, 120.0)
	await _swing("slash")
	P2SkillFx.spawn(v._fxp, "slash", to, Vector2.RIGHT.rotated(-0.4), 1.6, Color("#e2643c"))
	await RenderingServer.frame_post_draw
	var shot := ImageTexture.create_from_image(v.get_viewport().get_texture().get_image())
	P2Vfx.spawn(v._fx, "flash", to, {"color": Color("#ffd2a0"), "size": 1.2})
	v._sfx("punch", 0.8)
	var m := P2Manga.play(self, shot, v._to_ui(to) + Vector2(-50, 0), Color("#e2643c"))
	m.panel.connect(func(k: int) -> void:
		v._sfx("punch", 0.9 + k * 0.15)
		v._sfx("boom_m", 1.2 + k * 0.1, -6.0)
		if k == 3:
			v._sfx("boom_l", 1.0))
	await m.finished
	await v._space_cut(v._to_ui(to), Vector2.RIGHT.rotated(-0.3))
	for ev in _hits(events):
		v._enemy_hit_feedback(ev, Color("#ffd2a0"), "heavy")
	await v._wait(0.3)
	await _dash_home()



func _ult_eye(events: Array) -> void:
	_grade_on()
	var t := create_tween().set_parallel()
	t.tween_method(func(x: float) -> void:
		_grade_mat.set_shader_parameter("tint_color", Color(0.75, 0.35, 1.0))
		_grade_mat.set_shader_parameter("tint", x), 0.0, 0.6, 0.4)
	t.tween_method(func(x: float) -> void: _grade_mat.set_shader_parameter("desat", x), 0.0, 0.5, 0.4)
	v._sfx("mystery", 0.9)
	v._sfx("ghost", 0.7)
	P2Vfx.spawn(v._fx, "eye", Vector2(820, 90), {"size": 1.0})
	await v._wait(0.75)
	for ev in events:
		match String(ev.kind):
			"dot":
				var i := int(ev.index)
				P2Vfx.spawn(v._fx, "skull", _torso(i), {"size": 1.2})
				P2Vfx.spawn(v._fx, "rift_burst", _torso(i), {"size": 1.1})
				v._shockwave(_torso(i), 14.0, 1000.0, 0.45)
				v._camera_kick("heavy", Vector2.RIGHT)
				_impact([v._player, v._enemy_sprites[i]], _torso(i))
				v._sfx("spook", 0.9)
				_dot_feedback(ev)
				await v._wait(0.22)
			"hit":
				v._enemy_hit_feedback(ev, C_HEX, "secondary")
	await v._wait(0.6)
	_grade_off(0.4)


# ── 원래 카드 손질: 맞는 순간 · 막기 · 연료 · 집중 · 반격에 얹는 카드별 조각 ──

func garnish(ev: Dictionary, pos: Vector2, dir: Vector2) -> void:
	var kind: String = v._cur_kind
	var first := int(ev.get("hit_index", 0)) == 0
	match kind:
		"slash", "twin_slash", "beat_slash", "focus_strike":
			var d := dir.normalized() if dir.length() > 0.1 else Vector2.RIGHT
			P2Vfx.spawn(v._fx, "cut_line", pos, {"to": pos + d * 300.0, "color": Color("#bfe9ff"), "size": 1.0})
		"bash", "heavy_bash":
			P2Vfx.spawn(v._fx, "shield_pop", pos, {"size": 1.0})
			v._sfx("boom_m", 1.3, -4.0)
			if int(ev.damage) >= 10 or bool(ev.get("crit", false)):
				_impact([v._player, v._enemy_sprites[int(ev.index)]], pos)
		"sweep", "cleave_slash", "whirlwind":
			if first and not _did("sweep"):
				var c := Vector2.ZERO
				var n := 0
				for m in v.battle.alive_monsters():
					c += _torso(m.index)
					n += 1
				c = c / maxf(1.0, n) if n > 0 else pos
				P2Vfx.spawn(v._fx, "crescent", c + Vector2(-40, 30), {"color": Color("#bfe9ff"), "size": 1.1})
				P2Vfx.spawn(v._fx, "wind", c + Vector2(-260, 0), {"size": 0.9})
				v._sfx("wind", 1.3, -4.0)
		"pierce", "piercing_focus", "deep_point":
			P2Vfx.spawn(v._fx, "beam", pos, {"to": pos + Vector2(1400, 0), "color": Color("#e8fbff"), "size": 0.45})
			v._sparks(pos + Vector2(30, 0), Vector2.RIGHT, 0.35, 16, [Color.WHITE, Color("#bfe9ff")], true, Vector2(500, 1100))
		"quickshot", "rapid_fire":
			var bow: Vector2 = v._player.position + P2BattleView.HUNTER_BOW * v._ks if v._art_cid == "hunter" else v._player_body()
			for k in [-1.0, 1.0]:
				P2Vfx.spawn(v._fx, "streak", bow, {"to": pos + Vector2(0, 12.0 * k), "color": Color("#ffe9a8"), "life": 0.1})
		"aimed_shot", "instant_aim":
			P2Vfx.spawn(v._fx, "crosshair", pos, {"to": pos, "size": 0.6, "life": 0.4})
			P2Vfx.spawn(v._fx, "flash", pos, {"color": Color("#fff0c8"), "size": 1.1})
			v._shockwave(pos, 9.0, 900.0, 0.35)
		"bolt", "split":
			P2SkillFx.spawn(v._fx_back, "sigil", pos + Vector2(0, 40), Vector2.RIGHT, 0.6, P2BattleView.C_ARCANE)
			P2Vfx.spawn(v._fx, "crack_ring", pos, {"color": Color("#9fe6ff"), "size": 0.7})
		"sigil_burst", "transfer_burst", "reflux_burst":
			var n2 := int(ev.get("consumed", 0))
			if n2 > 0:
				_chain_pops(pos, n2)
		"torrent", "tidal_torrent":
			P2Vfx.spawn(v._fx, "light_pillar", _feet(int(ev.index)), {"color": Color("#4fb8e8"), "size": 1.4})
			P2HitBits.spawn(v._fxp, "drop", _feet(int(ev.index)) + Vector2(0, -20), Vector2.UP, 18, [Color("#9fe6ff"), Color("#4fb8e8"), Color("#e8fbff")], 1.4)
			P2SkillFx.spawn(v._fx_back, "ripple", _feet(int(ev.index)), Vector2.RIGHT, 1.4, Color("#4fb8e8"))
			v._sfx("splash", 0.9)
		"suppress":
			P2Vfx.spawn(v._fx, "chains", pos, {"color": Color("#9fe6ff"), "size": 0.9, "style": "hold"})
			v._sfx("lock", 1.1, -4.0)


# 한 행동 안에서 한 번만 하는 조각(쓸기 반원 등)
var _done_tok := {}
func _did(key: String) -> bool:
	var tok: int = v._action_token
	if int(_done_tok.get(key, -1)) == tok:
		return true
	_done_tok[key] = tok
	return false


func _chain_pops(pos: Vector2, n: int) -> void:
	for k in range(n):
		var at := pos + Vector2(randf_range(-30, 30), randf_range(-50, 30))
		P2Vfx.spawn(v._fx, "flash", at, {"color": Color("#7fe8d8"), "size": 0.55})
		P2Vfx.spawn(v._fx, "crack_ring", at, {"color": Color("#7fe8d8"), "size": 0.6})
		v._sfx("mark", 1.2 + k * 0.12, -6.0)
		await v._wait(0.05)


# 막기: 쌓인 방어만큼 막이 겹겹이 · 방어 숫자가 막에 새겨짐 · 결사 방어는 방패를 땅에 박아 금빛 기둥 · 마나 장막은 물결
func guard_garnish(kind: String, ev: Dictionary) -> void:
	var at: Vector2 = v._player_body() + Vector2(40, -6)
	var total := int(v._shown.get("block", int(ev.get("amount", 0))))
	var layers := clampi(total / 8, 1, 4)
	for k in range(1, layers):
		var lt := create_tween()
		lt.tween_interval(0.05 * k)
		lt.tween_callback(_ward_layer.bind(at, 1.0 + 0.18 * k))
	P2Vfx.spawn(v._fx, "react_text", at + Vector2(0, 10), {"text": str(total), "color": Color("#8fc3e8"), "size": 0.7})
	match kind:
		"fortify", "bastion":
			var feet := Vector2(v._player_body().x + 30.0, P2BattleView.FEET_Y)
			P2Vfx.spawn(v._fx, "light_pillar", feet, {"color": Color("#ffe9a8"), "size": 1.1})
			P2SkillFx.spawn(v._fx_back, "crack", feet, Vector2.RIGHT, 1.6, Color("#e0ad4a"))
			P2HitBits.spawn(v._fxp, "chunk", feet, Vector2.UP, 12, [Color("#7a6a58"), Color("#b8ad9e"), Color("#e0ad4a")], 1.2)
			v._sfx("bash", 0.7)
			v._sfx("boom_m", 0.8, -4.0)
			v._camera_kick("heavy", Vector2.DOWN)
		"mana_veil", "arcane_wall":
			for k in range(3):
				P2SkillFx.spawn(v._fx_back, "ripple", v._player_body() + Vector2(0, 30), Vector2.RIGHT, 1.0 + k * 0.4, Color("#7fd6ff"))
			v._sfx("splash", 1.4, -6.0)
		"riposte", "layered_riposte", "parry_stance":
			P2Vfx.spawn(v._fx, "flash", at, {"color": Color("#ffd27a"), "size": 0.8})
			v._sfx("clang", 1.6, -6.0)


# 연료화: 손에서 카드 한 장이 불타 재가 되고, 불티가 마나 구슬로 빨려 듦
func fuel_garnish() -> void:
	var hand: Vector2 = v._to_ui(v._player_body() + Vector2(30, -40))
	var orb := Vector2(90, 545)
	P2Vfx.spawn(v._ui, "card_burn", hand, {"size": 1.0})
	v._sfx("fire", 1.4, -4.0)
	await v._wait(0.3)
	for k in range(6):
		P2Vfx.spawn(v._ui, "missile", hand + Vector2(randf_range(-20, 20), randf_range(-30, 10)), {"to": orb + Vector2(randf_range(-10, 10), randf_range(-10, 10)), "style": "fire", "life": 0.3 + k * 0.03, "arc": randf_range(40.0, 120.0), "size": 0.45})
	await v._wait(0.32)
	P2Vfx.spawn(v._ui, "flash", orb, {"color": Color("#7fd6ff"), "size": 0.8})
	v._sfx("mana", 1.2)


# 집중: 눈에 번쩍 · 덱에서 카드가 날아와 손에 착
func focus_garnish() -> void:
	var eye: Vector2 = v._player.position + Vector2(0, -float(v._body_h) * 0.86)
	P2Vfx.spawn(v._fx, "flash", eye, {"color": Color("#e8fbff"), "size": 0.5})
	P2Vfx.spawn(v._fx, "crosshair", eye, {"to": eye, "size": 0.25, "life": 0.3})
	for k in range(2):
		var ft := create_tween()
		ft.tween_interval(0.08 * k + 0.01)
		ft.tween_callback(_fly_card.bind(k))


# 시간차 조각(이 도우미의 움직임에 묶어서, 전투 화면이 닫히면 같이 사라짐)
func _ward_layer(at: Vector2, size: float) -> void:
	P2SkillFx.spawn(v._fxp, "ward", at, Vector2.RIGHT, size, Color("#8fc3e8"))


func _fly_card(k: int) -> void:
	P2Vfx.spawn(v._ui, "card_fly", Vector2(45, 655), {"to": Vector2(640 + k * 40, 620), "color": Color("#4a6a9a")})
	v._sfx("draw", 1.1 + k * 0.1)


# 맞받아치기 반격: 금빛 반격 선 + 방패 번쩍 + 아주 짧게 색 분리
func counter_flash(pos: Vector2) -> void:
	var from: Vector2 = v._player_body() + Vector2(30, -10)
	P2Vfx.spawn(v._fx, "cut_line", (from + pos) / 2.0, {"to": pos + (pos - from) * 0.2, "color": Color("#ffd27a"), "size": 1.2})
	P2Vfx.spawn(v._fx, "flash", from, {"color": Color("#ffd27a"), "size": 0.9})
	_grade_mat.set_shader_parameter("chroma_c", v._to_ui(pos))
	_grade_pulse("chroma", 6.0, 0.18)


# 반응마다 손그림 묶음 큰 터짐(색 · 모양이 반응마다 다름) + 화면 손질
func _react_burst(i: int, name: String) -> void:
	var at := _torso(i)
	match name:
		"steam":
			P2PackFx.spawn(v._fx, "71", "light", at, 3.0)
			P2PackFx.spawn(v._fx, "528", "ice", at + Vector2(-30, 20), 2.5)
			P2PackFx.spawn(v._fx, "528", "light", at + Vector2(34, -10), 2.0, {"phase": 0.1})
			v._sfx("splash", 0.9)
			v._sfx("boom_m", 1.1)
			v._shockwave(at, 14.0, 1000.0, 0.45)
			_tint_pulse(Color(0.8, 0.95, 1.1), 0.3, 0.5)
		"toxic":
			P2PackFx.spawn(v._fx, "71", "poison", at, 3.0)
			P2PackFx.spawn(v._fx, "519", "poison", _feet(i) + Vector2(0, -40), 2.5)
			v._shockwave(at, 12.0, 900.0, 0.4)
		"pcrys":
			P2PackFx.spawn(v._fx, "116", "poison", at, 2.5)
			P2PackFx.spawn(v._fx, "23", "ice", at + Vector2(0, -30), 2.0)
			v._sfx("glass", 1.3)
			v._sfx("gurgle", 0.8, -4.0)
		"eclipse":
			P2PackFx.spawn(v._fx, "652", "dark", at, 3.5)
			P2PackFx.spawn(v._fx, "71", "light", at, 2.5, {"phase": 0.15})
			for m in v.battle.alive_monsters():
				if m.index != i:
					P2PackFx.spawn(v._fx, "652", "dark", _torso(m.index), 1.5)
			v._sfx("boom_l", 0.8)
			v._sfx("mystery", 1.0)
			v._shockwave(at, 18.0, 1200.0, 0.5)
			_tint_pulse(Color(0.55, 0.35, 0.9), 0.55, 0.7)
			_impact([v._player, v._enemy_sprites[i]], at)
		"shatter":
			P2PackFx.spawn(v._fx, "116", "ice", at, 3.0)
		"spread":
			P2PackFx.spawn(v._fx, "136", "poison", at, 2.5)
		"doom":
			P2PackFx.spawn(v._fx, "633", "dark", at, 2.5)


# ── 지속 피해·상태·반응 (카드 뒤따름 · 턴 끝 · 적 차례) ──

func _dot_feedback(ev: Dictionary) -> void:
	var i := int(ev.index)
	var key := String(ev.key)
	var col: Color = {"burn": C_FIRE, "poison": C_POISON, "doom": C_HEX, "bleed": C_BLOOD, "toxic": C_POISON, "steam": C_ICE, "eclipse": C_DARK, "shatter": C_ICE, "melt": C_FIRE}.get(key, Color.WHITE)
	var tone: String = {"burn": "fire", "poison": "poison", "toxic": "poison"}.get(key, "hurt" if key == "bleed" else "magic")
	var pos := _torso(i)
	var burst: Array = {"burn": ["529", "fire"], "poison": ["528", "poison"], "doom": ["633", "dark"], "bleed": ["519", "blood"]}.get(key, [])
	if not burst.is_empty():
		P2PackFx.spawn(v._fx, String(burst[0]), String(burst[1]), _feet(i) + Vector2(0, -40) if key != "doom" else pos, 2.0 if key != "doom" else 2.5)
	v._actor_flash(v._enemy_sprites[i], col, 0.6, 0.02, 0.12)
	v._victim_react(v._enemy_sprites[i], "secondary", Vector2.RIGHT, bool(ev.dead))
	v._damage_number(str(int(ev.damage)), pos + Vector2(30, -40), tone, 30)
	v._apply_event(ev)


# 화면의 카드 뒤따름·턴 끝·적 차례 사건 중 새 종류 (처리했으면 true)
func followup(ev: Dictionary, index := -1) -> bool:
	if bool(ev.get("_shown", false)):
		return true
	var kind := String(ev.kind)
	match kind:
		"status":
			v._apply_event(ev)
			var i := int(ev.index)
			var key := String(ev.key)
			var after := int(ev.after)
			if after > int(ev.before) and key not in ["doom_t", "link"]:
				var label: String = {"burn": "화상", "poison": "독", "chill": "냉기", "bleed": "출혈", "vuln": "취약", "weak": "약화", "doom": "저주", "trap": "덫", "air": "공중"}.get(key, "")
				if label != "":
					var shown: int = after * v.battle.doom_mult() if key == "doom" else after
					v._world_number("%s %d" % [tr(label), shown] if key not in ["trap", "air"] else tr(label), _torso(i) + Vector2(-50, -120), status_color(key), 20, 26.0, 0.8)
				if key == "air":
					_launch(i)
			elif key == "air" and after == 0:
				_land(i)
			return true
		"freeze":
			var i2 := int(ev.index)
			P2Vfx.spawn(v._fx, "freeze_form", _feet(i2), {"size": 1.1})
			v._sfx("ice", 0.9)
			v._sfx("glass", 1.2, -4.0)
			v._world_number(tr("얼어붙음!"), _torso(i2) + Vector2(0, -150), C_ICE, 26, 24.0, 1.0)
			return true
		"react":
			var i3 := int(ev.index)
			var name := String(ev.name)
			if ev.has("chain_from"):
				v._trait_pulse("chain_react")
				var cf := int(ev.chain_from)
				P2Vfx.spawn(v._fx, "missile", _torso(cf), {"to": _torso(i3), "style": "magic", "color": C_HEX, "life": 0.22, "arc": 60.0, "size": 1.0})
				P2PackFx.spawn(v._fx, "136", "magenta", _torso(cf), 1.5)
				v._sfx("arc", 1.3, -4.0)
			var col: Color = {"shatter": C_ICE, "melt": C_FIRE, "toxic": C_POISON, "spread": C_WIND, "doom": C_HEX, "steam": C_ICE, "pcrys": C_POISON, "eclipse": C_DARK}.get(name, Color.WHITE)
			P2Vfx.spawn(v._fx, "react_text", _torso(i3) + Vector2(0, -190), {"text": tr(String(ev.label)), "color": col, "size": 1.0})
			_react_burst(i3, name)
			if name == "shatter":
				P2Vfx.spawn(v._fx, "shatter_shards", _torso(i3), {"size": 1.2})
				P2Vfx.spawn(v._fx, "crack_ring", _torso(i3), {"color": Color(1, 1, 1), "size": 1.4})
				v._sfx("glass", 0.8)
				v._sfx("crunch", 1.1)
				v._shockwave(_torso(i3), 14.0, 1000.0, 0.4)
			elif name == "melt":
				P2Vfx.spawn(v._fx, "fire_burst", _torso(i3), {"size": 0.8})
				v._sfx("splash", 1.2)
			elif name == "toxic":
				P2Vfx.spawn(v._fx, "poison_puff", _feet(i3), {"size": 1.3})
				P2Vfx.spawn(v._fx, "fire_burst", _torso(i3), {"size": 1.0})
				v._sfx("boom_m", 1.3)
			elif name == "spread":
				v._sfx("wind", 1.2)
				for m in v.battle.alive_monsters():
					if m.index != i3:
						P2Vfx.spawn(v._fx, "missile", _torso(i3), {"to": _torso(m.index), "style": "wind", "color": C_WIND, "life": 0.3, "arc": 50.0, "size": 1.1})
			elif name == "doom":
				P2Vfx.spawn(v._fx, "skull", _torso(i3), {"size": 1.1})
				v._sfx("spook", 1.0)
			v._camera_kick("heavy", Vector2.RIGHT)
			return true
		"elem_cycle":
			v._trait_pulse("elem_cycle")
			var mo: Vector2 = P2BattleView.MANA_ORB + Vector2(83, 60)
			var ek := 0
			for el in [["fire", 1], ["ice", 2], ["poison", 4], ["light", 8], ["dark", 16]]:
				if int(ev.mask) & int(el[1]):
					P2PackFx.spawn(v._ui, "652", String(el[0]), mo + Vector2(-40 + 40 * ek, -84), 1.0)
					ek += 1
			v._float_number(tr("원소 순환!"), mo + Vector2(0, -120), C_LIGHT, 22, 24.0, 0.9)
			v._sfx("mana", 1.3)
			return true
		"doom_interest":
			var i11 := int(ev.index)
			P2PackFx.spawn(v._fx, "633", "dark", _torso(i11) + Vector2(0, -150), 1.5)
			v._trait_pulse("doom_interest")
			v._sfx("spook", 1.4, -4.0)
			return true
		"doom_echo":
			var fr := _torso(int(ev.from))
			var dto := _torso(int(ev.index))
			var sk := P2PackFx.spawn(v._fx, "633", "dark", fr, 2.0, {"loop": true})
			var dtw := sk.create_tween()
			dtw.tween_property(sk, "position", dto, 0.35).set_trans(Tween.TRANS_SINE)
			dtw.tween_callback(sk.queue_free)
			P2PackFx.spawn(v._fx, "633", "dark", dto, 2.5, {"phase": 0.35})
			v._trait_pulse("doom_echo")
			v._sfx("ghost", 0.9)
			v._world_number(tr("파멸의 메아리"), dto + Vector2(-70, -160), C_HEX, 20, 24.0, 0.9)
			return true
		"combo_burst_cast":
			v._trait_pulse("combo_burst")
			var pb0: Vector2 = v._player_body()
			P2Vfx.spawn(v._fx, "react_text", pb0 + Vector2(0, -170), {"text": tr("연격 폭주!"), "color": C_FIRE, "size": 1.0})
			P2PackFx.spawn(v._fx, "71", "fire", pb0 + Vector2(40, -10), 2.0)
			v._sfx("punch", 0.8)
			v._sfx("boom_m", 1.2)
			v._camera_kick("heavy", Vector2.RIGHT)
			return true
		"combo_burst":
			var i12 := int(ev.index)
			P2PackFx.spawn(v._fx, "71", "fire", _torso(i12), 2.5)
			P2HitBits.spawn(v._fxp, "ember", _torso(i12), Vector2.RIGHT, 10, [Color("#ffd25a"), Color("#ff6a1e")], 1.2)
			v._enemy_hit_feedback(ev, C_FIRE, "heavy")
			return true
		"riposte_beat":
			var i13 := int(ev.index)
			P2Vfx.spawn(v._fx, "beam", v._player_body() + Vector2(30, -10), {"to": _torso(i13), "color": C_LIGHT, "size": 0.35, "life": 0.18})
			P2PackFx.spawn(v._fx, "652", "light", _torso(i13), 1.5)
			v._enemy_hit_feedback(ev, C_LIGHT, "secondary")
			v._trait_pulse("riposte_beat")
			return true
		"flawless":
			var pb1: Vector2 = v._player_body()
			P2PackFx.spawn(v._fx, "652", "light", pb1, 3.0)
			P2Vfx.spawn(v._fx, "react_text", pb1 + Vector2(0, -170), {"text": tr("무결!"), "color": C_LIGHT, "size": 1.0})
			v._trait_pulse("flawless")
			v._sfx("crit_ready", 1.4)
			v._render_mana()
			return true
		"thin_draw":
			v._trait_pulse("thin_deck")
			v._float_number(tr("얇은 덱 +1장"), Vector2(640, P2BattleView.HAND_Y - 50), Color("#7fd7d0"), 20, 22.0, 0.8)
			return true
		"collector":
			v._apply_event(ev)
			v._trait_pulse("collector")
			for rid in v.battle.relics:
				v._relic_pulse(String(rid))
			v._world_number(tr("수집가: 방어 +%d") % int(ev.amount), v._player_body() + Vector2(0, -100), C_LIGHT, 20, 22.0, 0.8)
			return true
		"ult_after":
			v._trait_pulse("ult_after")
			v._build_hand(false)
			v._float_number(tr("필살 여운: 비용 −1"), Vector2(640, P2BattleView.HAND_Y - 50), C_LIGHT, 22, 24.0, 1.0)
			return true
		"last_stand":
			var pb2: Vector2 = v._player_body()
			P2PackFx.spawn(v._fx, "116", "light", pb2, 3.0)
			P2PackFx.spawn(v._fx, "652", "light", pb2, 2.5, {"phase": 0.1})
			P2Vfx.spawn(v._fx, "react_text", pb2 + Vector2(0, -180), {"text": tr("질긴 목숨!"), "color": C_LIGHT, "size": 1.1})
			v._trait_pulse("last_stand")
			v._sfx("glass", 0.9)
			v._sfx("crit_ready", 0.8)
			v._shockwave(pb2, 14.0, 1000.0, 0.45)
			_tint_pulse(Color(1.1, 1.05, 0.9), 0.4, 0.6)
			return true
		"steam_splash":
			var i10 := int(ev.index)
			P2PackFx.spawn(v._fx, "528", "light", _torso(i10), 2.0)
			v._enemy_hit_feedback(ev, C_ICE, "secondary")
			return true
		"shard":
			var i4 := int(ev.index)
			P2Vfx.spawn(v._fx, "frost_burst", _torso(i4), {"size": 0.6})
			v._enemy_hit_feedback(ev, C_ICE, "secondary")
			return true
		"link":
			var i5 := int(ev.index)
			v._lightning(_torso(int(ev.origin)), _torso(i5))
			v._sfx("arc", 1.6, -6.0)
			v._enemy_hit_feedback(ev, C_HEX, "secondary")
			return true
		"dot":
			_dot_feedback(ev)
			return true
		"trap_snap":
			var i6 := int(ev.index)
			P2Vfx.spawn(v._fx, "trap_snap", Vector2(_feet(i6).x - 50.0, P2BattleView.FEET_Y), {"size": 1.0})
			v._sfx("clang", 0.9)
			v._sfx("snap", 1.0)
			v._world_number(tr("덫!"), _torso(i6) + Vector2(-40, -140), Color("#c9d2da"), 26, 24.0, 0.9)
			v._enemy_hit_feedback(ev, C_BLOOD, "heavy")
			return true
		"wall_reflect":
			var i7 := int(ev.index)
			v._lightning(v._player_body() + Vector2(90, -40), _torso(i7))
			v._enemy_hit_feedback(ev, Color("#ffe9a8"), "secondary")
			return true
		"knockback":
			v._apply_event({"kind": "suppress", "index": ev.index, "amount": ev.amount, "intent": ev.intent})
			_push(int(ev.index))
			return true
		"armor_break":
			var i8 := int(ev.index)
			P2Vfx.spawn(v._fx, "crack_ring", _torso(i8), {"color": Color("#c9d2da"), "size": 1.3})
			v._sfx("clang", 0.7)
			v._world_number(tr("갑옷 파괴"), _torso(i8) + Vector2(0, -150), Color("#c9d2da"), 24, 24.0, 1.0)
			v._render_enemy(i8, false)
			return true
		"linked":
			v._sfx("clang", 1.4)
			v._world_number(tr("고통 연결"), (_torso(int(ev.index)) + _torso(int(ev.other))) / 2.0 + Vector2(0, -140), C_HEX, 24, 24.0, 1.0)
			return true
		"forced_ready":
			v._float_number(tr("다음 공격 확정 치명"), v._player_body() + Vector2(0, -120), P2BattleView.C_CRIT, 24, 24.0, 1.0)
			return true
		"wall_soak":
			v._world_number(tr("성벽 −%d") % int(ev.amount), v._player_body() + Vector2(90, -160), Color("#ffe9a8"), 22, 24.0, 0.8)
			v._sfx("block", 1.3)
			return true
		"smoke_miss":
			v._world_number(tr("빗나감!"), v._player_body() + Vector2(0, -120), Color("#c9d2da"), 26, 24.0, 0.9)
			v._sfx("whoosh", 1.4)
			return true
		"frozen_skip":
			var i9 := int(ev.index)
			v._world_number(tr("얼어서 움직이지 못함"), _torso(i9) + Vector2(0, -150), C_ICE, 24, 24.0, 1.1)
			v._sfx("ice", 1.3, -4.0)
			return true
		"trap_stop":
			v._world_number(tr("덫에 걸려 공격 실패"), _torso(int(ev.index)) + Vector2(0, -150), Color("#c9d2da"), 24, 24.0, 1.1)
			return true
		"bounce":
			_fire_bounce(_torso(int(ev.origin)), ev)
			return true
		"hex_spread":
			_hex_spread(ev, [])
			return true
		"ult", "ult_used", "debuff_cast", "forced_used", "buff", "wall", "iron_counter", "pyre":
			return true
	return false


func _launch(i: int) -> void:
	var sp: AnimatedSprite2D = v._enemy_sprites[i]
	var t := create_tween()
	t.tween_method(func(y: float) -> void:
		sp.set_meta("air_y", y)
		sp.offset.y = float(sp.get_meta("base_off_y", sp.offset.y)) + y / maxf(0.01, sp.scale.y), 0.0, -80.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not sp.has_meta("base_off_y"):
		sp.set_meta("base_off_y", sp.offset.y)


func _land(i: int) -> void:
	var sp: AnimatedSprite2D = v._enemy_sprites[i]
	if not sp.has_meta("base_off_y"):
		return
	var from := float(sp.get_meta("air_y", 0.0))
	var t := create_tween()
	t.tween_method(func(y: float) -> void:
		sp.set_meta("air_y", y)
		sp.offset.y = float(sp.get_meta("base_off_y")) + y / maxf(0.01, sp.scale.y), from, 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		sp.offset.y = float(sp.get_meta("base_off_y"))
		sp.remove_meta("base_off_y")
		sp.set_meta("air_y", 0.0)
		P2SkillFx.spawn(v._fx_back, "dust", _feet(i), Vector2.RIGHT, 1.4, Color("#b8ad9e"))
		v._sfx("bash", 1.3, -6.0))


func _push(i: int) -> void:
	var sp: AnimatedSprite2D = v._enemy_sprites[i]
	var home := sp.position
	var t := create_tween()
	t.tween_property(sp, "position:x", home.x + 70.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sp, "rotation", 0.12, 0.12)
	t.tween_interval(0.12)
	t.tween_property(sp, "position:x", home.x, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(sp, "rotation", 0.0, 0.4)
	P2SkillFx.spawn(v._fx_back, "dust", _feet(i), Vector2.RIGHT, 1.2, Color("#b8ad9e"))
