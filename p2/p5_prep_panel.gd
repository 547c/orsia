class_name P5PrepPanel
extends CanvasLayer
# 새 원정 창 (메인 메뉴 '새 원정'): 1 직업 → 2 난이도 → 3 출발(모드 · 원정 요약).
# 위 단계 칸을 누르면 그 단계로 바로, Enter는 다음, Esc는 앞 단계(첫 단계에서는 닫기). 고른 값은 프로필에 저장

signal closed

const W := 1080.0
const H := 624.0
const TOP := 76.0
const BODY_H := 470.0
const STEPS := ["직업", "난이도", "출발"]
const DIFF_COL := {"easy": Color("#8be08b"), "normal": Color("#f3ead7"), "hard": Color("#ff9a6a"), "extreme": Color("#ff5a5a")}
# 직업 무대: 고른 인물은 조명 아래 숨 쉬고, 나머지는 어둡게. 인물 그림은 전투에서 보이는 그대로(수호기사 SD · 나머지는 기존 그림)
const FIG_H := 200.0
const FOOT_Y := 340.0

var step := 0
var _root: Control
var _panel: Panel
var _head: Control
var _body: Control
var _foot: Control
var _msg: Label
var _next: Button
var gate: P2Ui.SaveGate
var _figs := {}
var _anim := {"id": "", "frames": [], "ms": [], "i": 0, "t": 0.0}
var _stage_pen: P2Pixel
var _slide := 0
var _clock := 0.0
var _shown_class := ""
var _light_x := -1.0
var _hop_t := -1.0
static var _used := {}


static func open_in(tree: SceneTree) -> P5PrepPanel:
	for n in tree.get_nodes_in_group("expedition_prep_layer"):
		(n as P5PrepPanel).refresh()
		return n
	var p := P5PrepPanel.new()
	tree.root.add_child(p)
	return p


func _ready() -> void:
	layer = 105
	add_to_group("expedition_prep_layer")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_to_group("expedition_prep")
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_panel = Panel.new()
	_panel.size = Vector2(W, H)
	_panel.position = (_root.get_viewport_rect().size - _panel.size) / 2.0
	_panel.add_theme_stylebox_override("panel", P2Ui.style("leaf"))
	_root.add_child(_panel)
	gate = RunService.gate
	if not bool(GameState.combat.get("notices", {}).get("prep_intro", false)):
		_tx("prep intro", func(c, _r, _f):
			c.combat.notices.prep_intro = true
			return true)
	refresh()
	P2Ui.pop_in(_panel, dim)


func _unhandled_input(event: InputEvent) -> void:
	if gate.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if step > 0:
			go(step - 1)
		else:
			close()


# 직업·난이도 단계에서는 좌우 방향키로 고른 것을 옮긴다(포커스는 늘 '다음'에 둔다)
func _input(event: InputEvent) -> void:
	if gate.is_open() or not (step == 0 or step == 1):
		return
	var d := -1 if event.is_action_pressed("ui_left") else (1 if event.is_action_pressed("ui_right") else 0)
	if d == 0:
		return
	get_viewport().set_input_as_handled()
	var cb: Dictionary = GameState.combat
	if step == 0:
		var order: Array = P2Catalog.CLASS_ORDER
		var i := order.find(String(cb.get("class_id", P5Campaign.DEFAULT_CLASS)))
		_set_class(String(order[posmod(i + d, order.size())]))
	else:
		var cleared: Dictionary = cb.get("diff_clear", {})
		var open: Array = P2Catalog.DIFFS.filter(func(id): return P2Catalog.diff_unlocked(cleared, id))
		var j := open.find(_diff_pick(cb))
		_set_diff(String(open[clampi(j + d, 0, open.size() - 1)]))


func _process(delta: float) -> void:
	_clock += delta
	var fig: TextureRect = _figs.get(String(_anim.id))
	if fig == null or not is_instance_valid(fig):
		return
	var frames: Array = _anim.frames
	if frames.size() > 1:
		_anim.t = float(_anim.t) + delta * 1000.0
		var ms: Array = _anim.ms
		if float(_anim.t) >= float(ms[int(_anim.i) % ms.size()]):
			_anim.t = 0.0
			_anim.i = (int(_anim.i) + 1) % frames.size()
			fig.texture = load(String(frames[int(_anim.i)]))
	var base := float(fig.get_meta("scale"))
	var sx := 1.0
	var sy := 1.0 + 0.012 * sin(_clock * 2.4)
	var lift := 0.0
	if _hop_t >= 0.0:
		_hop_t += delta
		var k := _hop_t / 0.42
		if k >= 1.0:
			_hop_t = -1.0
		else:
			lift = sin(minf(1.0, k / 0.8) * PI) * 18.0
			var sq := 0.14 * sin(k * TAU * 1.5) * (1.0 - k)
			sy -= sq
			sx += sq
	fig.scale = Vector2(base * sx, base * sy)
	fig.position.y = float(fig.get_meta("base_y", fig.position.y)) - lift


func close() -> void:
	closed.emit()
	queue_free()


func go(i: int) -> void:
	i = clampi(i, 0, STEPS.size() - 1)
	if i == step:
		return
	_slide = 1 if i > step else -1
	step = i
	refresh()


func _tx(reason: String, fn: Callable) -> bool:
	var ok: bool = await RunService.commit_profile(reason, fn)
	if not ok and _msg != null:
		_msg.text = "바꾸지 못했습니다: " + (SaveManager.last_error if SaveManager.last_error != "" else "조건이 맞지 않음")
	return ok


func refresh() -> void:
	for n in [_head, _body, _foot]:
		if n != null:
			n.queue_free()
	_figs.clear()
	_head = _layer()
	_body = _layer()
	_foot = _layer()
	_build_head()
	match step:
		0:
			_build_class()
		1:
			_build_diff()
		_:
			_build_go()
	_build_foot()
	if _slide != 0:
		_body.position.x = 28.0 * _slide
		_body.modulate.a = 0.0
		var tw := _body.create_tween().set_parallel()
		tw.tween_property(_body, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body, "modulate:a", 1.0, 0.12)
		_slide = 0
	_next.grab_focus.call_deferred()


func _layer() -> Control:
	var c := Control.new()
	c.size = _panel.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(c)
	return c


func _diff_pick(cb: Dictionary) -> String:
	var pick := String(cb.get("diff_pick", "normal"))
	return pick if P2Catalog.diff_unlocked(cb.get("diff_clear", {}), pick) else "normal"


func _add_text(parent: Control, t: String, pos: Vector2, size: int, col: Color, w := 0.0, outline := 0, clip := 0.0) -> Label:
	var l := P2Ui.text(t, size, col, w)
	if clip > 0.0:
		l.clip_text = true
		l.size = Vector2(clip, size + 6)
	if outline > 0:
		P2Ui.outlined(l, outline)
	l.position = pos
	parent.add_child(l)
	return l


# ── 제목 · 단계 띠 · 아래 단추 ─────────────────────────────────────────────

func _build_head() -> void:
	var cb: Dictionary = GameState.combat
	_add_text(_head, "새 원정", Vector2(24, 12), P2Ui.T_BIG, P2Ui.C_GOLD, 0.0, 4)
	var x := 300.0
	for i in range(STEPS.size()):
		if i > 0:
			var ln := ColorRect.new()
			ln.color = Color(P2Ui.C_GOLD if i <= step else P2Ui.C_EDGE, 0.8)
			ln.position = Vector2(x - 14, 35)
			ln.size = Vector2(14, 2)
			ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_head.add_child(ln)
		var b := P2Ui.button("", Vector2(x, 10), Vector2(176, 52))
		b.set_meta("skin", "tile")
		b.set_meta("step", i)
		P2Ui.mark(b, i == step)
		_add_text(b, str(i + 1), Vector2(12, 11), P2Ui.T_HEAD, P2Ui.C_GOLD if i <= step else P2Ui.C_DIM, 0.0, 3)
		_add_text(b, STEPS[i], Vector2(38, 4), P2Ui.T_BODY, P2Ui.C_TEXT if i == step else P2Ui.C_DIM)
		_add_text(b, _step_value(i, cb), Vector2(38, 30), P2Ui.T_SMALL, P2Ui.C_GOLD if i == step else P2Ui.C_DIM, 0.0, 0, 130.0)
		var si := i
		b.pressed.connect(func() -> void: go(si))
		_head.add_child(b)
		x += 190.0
	P2Ui.rule(_head, Vector2(24, 68), W - 48, Color(P2Ui.C_GOLD, 0.45))


func _step_value(i: int, cb: Dictionary) -> String:
	match i:
		0:
			return String(P2Catalog.CLASSES[String(cb.get("class_id", P5Campaign.DEFAULT_CLASS))].name)
		1:
			var d := _diff_pick(cb)
			return String(P2Catalog.DIFF[d].name) + (" ★" if bool((cb.get("diff_clear", {}) as Dictionary).get(d, false)) else "")
		_:
			var on: Array = cb.get("mods_pick", [])
			return "모드 없음" if on.is_empty() else " ".join(PackedStringArray(on.map(func(m): return String(P2Catalog.MOD[m].short))))


func _build_foot() -> void:
	var shut := P2Ui.crisp(P2Ui.button("닫기", Vector2(24, H - 60), Vector2(128, 44)), P2Ui.T_HEAD) as Button
	shut.pressed.connect(close)
	_foot.add_child(shut)
	var rec := P2Ui.crisp(P2Ui.button("기록실", Vector2(160, H - 60), Vector2(128, 44)), P2Ui.T_HEAD) as Button
	rec.tooltip_text = "정복 배지 · 오늘의 원정 · 보스 연습 · 최근 원정"
	rec.pressed.connect(func() -> void: P5RecordsPanel.open_in(get_tree()))
	_foot.add_child(rec)
	_msg = P2Ui.text("", P2Ui.T_BODY, P2Ui.C_WARN)
	_msg.position = Vector2(300, H - 50)
	_msg.size = Vector2(W - 300 - 412, 26)
	_msg.clip_text = true
	_foot.add_child(_msg)
	if step == 0:
		_quick_button()
	if step > 0:
		var back := P2Ui.crisp(P2Ui.button("← 이전", Vector2(W - 396, H - 60), Vector2(180, 44)), P2Ui.T_HEAD) as Button
		back.tooltip_text = "Esc"
		back.pressed.connect(func() -> void: go(step - 1))
		_foot.add_child(back)
	var last := step == STEPS.size() - 1
	_next = P2Ui.primary(P2Ui.crisp(P2Ui.button("출발" if last else "다음 →", Vector2(W - 204, H - 60), Vector2(180, 44)), P2Ui.T_HEAD) as Button)
	_next.set_meta("next", true)
	_foot.add_child(_next)
	if not last:
		_next.tooltip_text = "Enter"
		_next.pressed.connect(func() -> void: go(step + 1))
		return
	var errs := RunService.entry_errors()
	_next.disabled = not errs.is_empty()
	_next.tooltip_text = "\n".join(PackedStringArray(errs))
	_next.pressed.connect(_depart)
	if not errs.is_empty():
		_msg.text = "출발할 수 없음: " + "; ".join(PackedStringArray(errs))


# 바로 출발(첫 단계): 지난번 고른 직업 · 난이도 · 모드 그대로. 한 번이라도 출발한 뒤에만 보인다
func _quick_button() -> void:
	var cb: Dictionary = GameState.combat
	if (cb.get("history", []) as Array).is_empty():
		return
	var errs := RunService.entry_errors()
	var quick := P2Ui.crisp(P2Ui.button("바로 출발", Vector2(W - 396, H - 60), Vector2(180, 44)), P2Ui.T_HEAD) as Button
	quick.set_meta("quick", true)
	quick.disabled = not errs.is_empty()
	var line := "%s · %s · %s" % [_step_value(0, cb), _step_value(1, cb), _step_value(2, cb)]
	quick.tooltip_text = ("지난번 그대로: " + line) if errs.is_empty() else "\n".join(PackedStringArray(errs))
	quick.pressed.connect(_depart)
	_foot.add_child(quick)
	if errs.is_empty():
		_msg.add_theme_color_override("font_color", P2Ui.C_DIM)
		_msg.text = "바로 출발: " + line


# ── 1 직업: 무대 위 세 인물 + 오른쪽 설명 카드 ───────────────────────────────

func _build_class() -> void:
	var cb: Dictionary = GameState.combat
	var cid := String(cb.get("class_id", P5Campaign.DEFAULT_CLASS))
	var stage := Panel.new()
	stage.position = Vector2(16, TOP)
	stage.size = Vector2(624, BODY_H)
	stage.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_EDGE, 0.97))
	stage.clip_contents = true
	_body.add_child(stage)
	var ground := ColorRect.new()
	ground.color = Color(P2Ui.C_DEEP, 0.95)
	ground.position = Vector2(2, FOOT_Y - 8)
	ground.size = Vector2(620, BODY_H - FOOT_Y + 6)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(ground)
	var lights := Control.new()
	lights.size = stage.size
	lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(lights)
	var sel_i := P2Catalog.CLASS_ORDER.find(cid)
	var changed := _shown_class != "" and _shown_class != cid and P2Catalog.CLASS_ORDER.has(_shown_class)
	var from_x := _slot_x(P2Catalog.CLASS_ORDER.find(_shown_class)) if changed else _slot_x(sel_i)
	_shown_class = cid
	_light_x = from_x
	_stage_pen = P2Pixel.attach(lights, _paint_stage.bind(sel_i))
	_stage_pen.redraw()
	if changed:
		var pen := _stage_pen
		var sweep := lights.create_tween()
		sweep.tween_method(func(v: float) -> void:
			_light_x = v
			if is_instance_valid(pen):
				pen.redraw(), from_x, _slot_x(sel_i), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hop_t = 0.0
	var locked := not RunService.run.is_empty()
	for i in range(P2Catalog.CLASS_ORDER.size()):
		var id := String(P2Catalog.CLASS_ORDER[i])
		var foot := Vector2(_slot_x(i), FOOT_Y)
		var on := id == cid
		var fig := _figure(id, foot, on)
		fig.set_meta("base_y", fig.position.y)
		stage.add_child(fig)
		var ccol: Color = P2Catalog.CLASS_COLOR.get(id, P2Ui.C_GOLD)
		if on and changed:
			fig.modulate = Color(1.7, 1.6, 1.4)
			fig.create_tween().tween_property(fig, "modulate", Color.WHITE, 0.3)
		var nm := _add_text(stage, String(P2Catalog.CLASSES[id].name), Vector2(foot.x - 100, FOOT_Y + 22), P2Ui.T_HEAD, ccol.lerp(Color.WHITE, 0.25) if on else P2Ui.C_DIM, 0.0, 3)
		nm.size = Vector2(200, 30)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge := P2Ui.class_badge(id, 11)
		badge.position = Vector2(foot.x - 11, FOOT_Y + 58)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.modulate = Color.WHITE if on else Color(0.6, 0.6, 0.66, 0.8)
		stage.add_child(badge)
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(foot.x - 100, 40)
		hit.size = Vector2(200, FOOT_Y + 20)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.set_meta("class", id)
		hit.tooltip_text = "%s — %s" % [P2Catalog.CLASSES[id].motto, P2Catalog.CLASSES[id].passive]
		hit.disabled = locked
		if not on:
			var by := float(fig.get_meta("base_y"))
			hit.mouse_entered.connect(func() -> void:
				fig.modulate = Color(0.85, 0.85, 0.92)
				fig.create_tween().tween_property(fig, "position:y", by - 8.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				P2Ui.ui_sound("hover"))
			hit.mouse_exited.connect(func() -> void:
				fig.modulate = Color(0.42, 0.42, 0.52)
				fig.create_tween().tween_property(fig, "position:y", by, 0.12))
			hit.pressed.connect(func() -> void:
				P2Ui.ui_sound("click")
				_set_class(id))
		stage.add_child(hit)
	var tip := _add_text(stage, "← → 로 바꾸기" if not locked else "원정 중에는 직업을 바꿀 수 없습니다", Vector2(16, BODY_H - 34), P2Ui.T_SMALL, P2Ui.C_DIM)
	tip.size = Vector2(592, 16)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_card(cid, changed)


func _slot_x(i: int) -> float:
	return 2.0 + 620.0 * (i + 0.5) / P2Catalog.CLASS_ORDER.size()


# 조명: 고른 자리에 위에서 내려오는 빛 기둥(점 무늬로 옅게)과 발밑 금빛 원, 모든 자리에 그림자
func _paint_stage(sel: int) -> void:
	var c := _stage_pen
	var lc: Color = Color(1.0, 0.86, 0.55).lerp(P2Catalog.CLASS_COLOR.get(String(P2Catalog.CLASS_ORDER[sel]) if sel >= 0 else "", P2Ui.C_GOLD), 0.45)
	var lf := Vector2(_light_x if _light_x >= 0.0 else _slot_x(sel), FOOT_Y)
	c.draw_colored_polygon(PackedVector2Array([lf + Vector2(-40, -FOOT_Y), lf + Vector2(40, -FOOT_Y), lf + Vector2(92, 0), lf + Vector2(-92, 0)]), Color(lc, 0.22))
	c.draw_colored_polygon(PackedVector2Array([lf + Vector2(-20, -FOOT_Y), lf + Vector2(20, -FOOT_Y), lf + Vector2(54, 0), lf + Vector2(-54, 0)]), Color(lc.lerp(Color.WHITE, 0.4), 0.18))
	for i in range(P2Catalog.CLASS_ORDER.size()):
		var f := Vector2(_slot_x(i), FOOT_Y)
		c.draw_colored_polygon(_ellipse(f, 64.0, 13.0), Color(0, 0, 0, 0.55))
		if i == sel:
			c.draw_colored_polygon(_ellipse(f, 72.0, 16.0), Color(P2Ui.C_GOLD, 0.22))
			var ring := _ellipse(f, 72.0, 16.0)
			ring.append(ring[0])
			c.draw_polyline(ring, P2Ui.C_GOLD, P2Pixel.w(2.0))


static func _ellipse(at: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(32):
		var a := TAU * k / 32.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# 인물 그림: 발 기준점을 무대 발자리에 맞추고 몸 높이를 FIG_H로. 고른 인물만 대기 그림이 돈다
func _figure(id: String, foot: Vector2, on: bool) -> TextureRect:
	var art := figure_art(String(P2Catalog.CLASSES[id].get("art", id)))
	var frames: Array = art.frames
	var fig := TextureRect.new()
	fig.texture = load(String(frames[0]))
	fig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.size = fig.texture.get_size()
	var s := FIG_H / float(art.body)
	fig.set_meta("scale", s)
	fig.scale = Vector2(s, s)
	fig.pivot_offset = art.foot
	# 그림이 실제로 차지하는 가로 가운데를 자리 가운데에 (발 기준점은 뒷발 쪽이라 그대로 두면 한쪽으로 쏠림)
	var used := _used_rect(String(frames[0]), fig.texture)
	var shift := (used.get_center().x - (art.foot as Vector2).x) * s
	fig.position = foot - (art.foot as Vector2) - Vector2(shift, 0)
	fig.modulate = Color.WHITE if on else Color(0.42, 0.42, 0.52)
	if P2Catalog.CLASSES[id].has("art"):
		fig.self_modulate = Color(0.92, 0.66, 1.3) if id == "shaman" else Color(1.0, 0.8, 1.18)
	_figs[id] = fig
	if on and String(_anim.id) != id:
		_anim = {"id": id, "frames": frames, "ms": art.ms, "i": 0, "t": 0.0}
	return fig


static func _used_rect(path: String, tex: Texture2D) -> Rect2:
	if not _used.has(path):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		_used[path] = Rect2(img.get_used_rect())
	return _used[path]


static func figure_art(id: String) -> Dictionary:
	var m := P2BattleView._sd_manifest(id)
	if not m.is_empty():
		var ms: Array = m.anims.idle.ms
		var frames: Array = []
		for i in range(ms.size()):
			frames.append(P2BattleView.SD_DIR + id + "/idle/idle_%02d.png" % i)
		return {"frames": frames, "ms": ms, "foot": Vector2(float(m.foot[0]), float(m.foot[1])), "body": float(m.body)}
	var a: Dictionary = P2BattleView.ACTOR_ART[id]
	var idle: Array = a.anims.idle
	var times: Array = idle[0]
	var dir := String(idle[2]) if idle.size() > 2 else String(a.dir)
	var list: Array = []
	for i in range(times.size()):
		list.append(dir + "idle/idle_%02d.png" % i)
	return {"frames": list, "ms": times, "foot": a.foot, "body": -float(a.head_y)}


func _class_card(cid: String, changed := false) -> void:
	var d: Dictionary = P2Catalog.CLASSES[cid]
	var base: Dictionary = P5Campaign.CLASS_BASE[cid]
	var ccol: Color = P2Catalog.CLASS_COLOR.get(cid, P2Ui.C_GOLD)
	var card := Panel.new()
	card.position = Vector2(656, TOP)
	card.size = Vector2(408, BODY_H)
	card.add_theme_stylebox_override("panel", P2Ui.calm_box(ccol.lerp(P2Ui.C_EDGE, 0.5), 0.97))
	_body.add_child(card)
	if changed:
		card.position.x += 36.0
		card.modulate.a = 0.0
		var tw := card.create_tween().set_parallel()
		tw.tween_property(card, "position:x", 656.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.14)
	var badge := P2Ui.class_badge(cid, 16)
	badge.position = Vector2(360, 14)
	card.add_child(badge)
	_add_text(card, String(d.name), Vector2(20, 10), P2Ui.T_BIG, ccol.lerp(P2Ui.C_GOLD, 0.35), 0.0, 4)
	_add_text(card, String(d.motto), Vector2(20, 58), P2Ui.T_BODY, P2Ui.C_DIM, 368)
	P2Ui.chip_row(card, Vector2(20, 96), [[P2Ui.kit_tex("hud_heart", 1), "체력 %d" % int(base.hp)], [P2Ui.kit_tex("cost_drop", 1), "마나 %d" % int(base.mana), P2Ui.C_BLOCK]], 8.0, 34.0)
	_add_text(card, "특성", Vector2(20, 148), P2Ui.T_BODY, P2Ui.C_GOLD, 0.0, 3)
	var ps := _add_text(card, String(d.passive), Vector2(20, 176), P2Ui.T_BODY, P2Ui.C_TEXT, 368)
	ps.max_lines_visible = 3
	_add_text(card, "출발 덱", Vector2(20, 262), P2Ui.T_BODY, P2Ui.C_GOLD, 0.0, 3)
	var counts := {}
	var order: Array = []
	for k in P2Catalog.class_deck(cid):
		if not counts.has(k):
			order.append(k)
		counts[k] = int(counts.get(k, 0)) + 1
	var at := Vector2(20, 290)
	for k in order:
		var c := P2Ui.chip(P2Ui.card_tex(String(k)), P2Catalog.card_name(String(k)) + (" ×%d" % int(counts[k]) if int(counts[k]) > 1 else ""), P2Ui.C_TEXT, 28.0)
		if at.x + c.size.x > 388.0:
			at = Vector2(20, at.y + 31)
		c.position = at
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.tooltip_text = P2Catalog.long_text(String(k))
		card.add_child(c)
		at.x += c.size.x + 6.0
	var wt: Dictionary = P2Catalog.CLASS_STAT_WEIGHT.get(cid, {})
	if not wt.is_empty():
		var keys: Array = wt.keys()
		keys.sort_custom(func(a, b): return int(wt[a]) > int(wt[b]))
		var parts: Array = keys.map(func(k): return "%s %s" % [String(P2Catalog.STATS[k].name), "▲".repeat(int(wt[k]))])
		var gl := _add_text(card, "성장 경향: " + " · ".join(PackedStringArray(parts)), Vector2(20, maxf(at.y + 34.0, BODY_H - 62)), P2Ui.T_SMALL + 4, P2Ui.C_DIM, 368)
		gl.mouse_filter = Control.MOUSE_FILTER_STOP
		gl.tooltip_text = "레벨업 때 ▲가 많은 능력치 후보가 더 자주 나옵니다"


func _box(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", P2Ui.calm_box(P2Ui.C_EDGE, 0.97))
	_body.add_child(p)
	return p


# ── 3 난이도: 네 장의 카드(판정 · 노트 · 패턴 · 적 · 점수 배수 · 최고 기록), 잠긴 것은 여는 조건 ──────────────

func _build_diff() -> void:
	var cb: Dictionary = GameState.combat
	var cleared: Dictionary = cb.get("diff_clear", {})
	var pick := _diff_pick(cb)
	var bests: Dictionary = cb.get("best_score", {})
	for i in range(P2Catalog.DIFFS.size()):
		var id := String(P2Catalog.DIFFS[i])
		var d: Dictionary = P2Catalog.DIFF[id]
		var open := P2Catalog.diff_unlocked(cleared, id)
		var b := P2Ui.button("", Vector2(20 + i * 264, TOP), Vector2(248, 400))
		b.set_meta("skin", "tile")
		b.set_meta("diff", id)
		b.focus_mode = Control.FOCUS_NONE
		P2Ui.mark(b, id == pick)
		b.disabled = not open
		var did := id
		b.pressed.connect(func() -> void: _set_diff(did))
		_body.add_child(b)
		var nm := _add_text(b, String(d.name), Vector2(0, 14), P2Ui.T_BIG, DIFF_COL[id] if open else P2Ui.C_DIM, 0.0, 4)
		nm.size = Vector2(248, 44)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if bool(cleared.get(id, false)):
			var star := P2Ui.chip(null, "★ 정복", P2Ui.C_GOLD, 28.0)
			star.position = Vector2((248 - star.size.x) / 2.0, 62)
			b.add_child(star)
		var y := 96.0
		for row in _diff_rows(d):
			_add_text(b, String(row[0]), Vector2(14, y), P2Ui.T_BODY, P2Ui.C_DIM)
			var v := _add_text(b, String(row[1]), Vector2(92, y), P2Ui.T_BODY, (row[2] as Color) if open else P2Ui.C_DIM)
			v.size = Vector2(142, 26)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			y += 28.0
		var best: Dictionary = bests.get(id, {})
		if not open:
			var need := String(P2Catalog.DIFF[P2Catalog.DIFF_NEEDS[id]].name)
			var lk := _add_text(b, "잠김\n%s을(를) 끝까지\n깨면 열립니다" % need, Vector2(0, 324), P2Ui.T_BODY, P2Ui.C_WARN)
			lk.size = Vector2(248, 74)
			lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			_add_text(b, "최고 기록", Vector2(16, 346), P2Ui.T_BODY, P2Ui.C_DIM)
			var bv := _add_text(b, "없음" if best.is_empty() else "%s  %d" % [String(best.rank), int(best.score)], Vector2(100, 346), P2Ui.T_BODY, P2Ui.C_GOLD if not best.is_empty() else P2Ui.C_DIM)
			bv.size = Vector2(132, 26)
			bv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := _add_text(_body, "노멀을 끝까지(최종 보스) 깨면 하드, 하드를 깨면 익스트림이 열립니다 · 정복하면 ★  ·  ← → 로 바꾸기", Vector2(20, TOP + 412), P2Ui.T_BODY, P2Ui.C_DIM)
	hint.size = Vector2(1040, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# 난이도 카드 줄: [이름, 값, 색] — 쉬워지면 초록, 어려워지면 주황
static func _diff_rows(d: Dictionary) -> Array:
	var easy := P2Ui.C_GOOD
	var hard := P2Ui.C_WARN
	var judge := float(d.judge)
	var app := float(d.approach)
	var pat := int(d.pattern)
	var hp := float(d.hp)
	var hit := float(d.hit)
	return [
		["판정 창", "기본" if is_equal_approx(judge, 1.0) else ("넓게 +%d%%" % roundi((judge - 1.0) * 100.0) if judge > 1.0 else "좁게 −%d%%" % roundi((1.0 - judge) * 100.0)),
			P2Ui.C_TEXT if is_equal_approx(judge, 1.0) else (easy if judge > 1.0 else hard)],
		["노트", "기본 속도" if is_equal_approx(app, 1.0) else ("느리게" if app > 1.0 else ("더 빠르게" if app < 0.8 else "빠르게")),
			P2Ui.C_TEXT if is_equal_approx(app, 1.0) else (easy if app > 1.0 else hard)],
		["패턴", ["쉽게", "기본", "엇박 +1", "노트 +2 · 두 번"][clampi(pat + 1, 0, 3)], P2Ui.C_TEXT if pat == 0 else (easy if pat < 0 else hard)],
		["적 체력", "기본" if is_equal_approx(hp, 1.0) else "%+d%%" % roundi((hp - 1.0) * 100.0), P2Ui.C_TEXT if is_equal_approx(hp, 1.0) else (easy if hp < 1.0 else hard)],
		["적 피해", "기본" if is_equal_approx(hit, 1.0) else "%+d%%" % roundi((hit - 1.0) * 100.0), P2Ui.C_TEXT if is_equal_approx(hit, 1.0) else (easy if hit < 1.0 else hard)],
		["적 성향", ["없음", "일반 적 하나", "일반 모두·정예"][clampi(int(d.get("affix", 0)), 0, 2)], P2Ui.C_TEXT if int(d.get("affix", 0)) == 0 else hard],
		["연속 회복", "최대 %d" % int(d.get("heal_cap", 5)), P2Ui.C_TEXT if int(d.get("heal_cap", 5)) >= 5 else hard],
		["점수", "×%s" % str(snappedf(float(d.score), 0.1)), P2Ui.C_GOLD],
	]


# ── 4 출발: 왼쪽 모드 넷(켜고 끔) · 오른쪽 원정 요약 ────────────────────────────

func _build_go() -> void:
	var cb: Dictionary = GameState.combat
	var on: Array = cb.get("mods_pick", [])
	_add_text(_body, "모드", Vector2(24, TOP + 4), P2Ui.T_HEAD, P2Ui.C_GOLD, 0.0, 3)
	_add_text(_body, "골라도 되고 안 골라도 됨 · 하나마다 금화·점수 +10%", Vector2(90, TOP + 8), P2Ui.T_BODY, P2Ui.C_DIM, 0.0, 0, 540.0)
	for i in range(P2Catalog.MODS.size()):
		var mid := String(P2Catalog.MODS[i])
		var md: Dictionary = P2Catalog.MOD[mid]
		var lit := on.has(mid)
		var b := P2Ui.button("", Vector2(16 + (i % 2) * 316, TOP + 46 + floori(i / 2.0) * 166), Vector2(304, 152))
		b.set_meta("skin", "tile")
		b.set_meta("mod", mid)
		b.focus_mode = Control.FOCUS_NONE
		P2Ui.mark(b, lit)
		var m2 := mid
		b.pressed.connect(func() -> void: _toggle_mod(m2))
		_body.add_child(b)
		_add_text(b, String(md.short), Vector2(18, 12), P2Ui.T_BIG, P2Ui.C_GOLD if lit else P2Ui.C_TEXT, 0.0, 4)
		_add_text(b, String(md.name), Vector2(92, 20), P2Ui.T_HEAD, P2Ui.C_TEXT if lit else P2Ui.C_DIM, 0.0, 3)
		var rl := _add_text(b, String(md.rule), Vector2(18, 68), P2Ui.T_BODY, P2Ui.C_TEXT if lit else P2Ui.C_DIM, 268)
		rl.max_lines_visible = 2
		var st := P2Ui.chip(null, "켬" if lit else "꺼짐", P2Ui.C_GOLD if lit else P2Ui.C_DIM, 28.0)
		st.position = Vector2(304 - st.size.x - 12, 14)
		b.add_child(st)
	var bonus := roundi(P2Catalog.MOD_GOLD * 100.0 * on.size())
	_add_text(_body, "모드 없이 출발합니다" if on.is_empty() else "금화 +%d%% · 점수 +%d%%" % [bonus, bonus], Vector2(24, TOP + 384), P2Ui.T_BODY, P2Ui.C_DIM if on.is_empty() else P2Ui.C_GOLD)
	_summary(cb, on)


# 원정 패: 지금까지 고른 것을 한눈에(누르면 그 단계로)
func _summary(cb: Dictionary, on: Array) -> void:
	var cid := String(cb.get("class_id", P5Campaign.DEFAULT_CLASS))
	var card := _box(Vector2(656, TOP), Vector2(408, BODY_H))
	_add_text(card, "원정 패", Vector2(20, 10), P2Ui.T_HEAD, P2Ui.C_GOLD, 0.0, 3)
	var face := "res://assets/orsia_generated/char6_baseline/%s/portrait.png" % cid
	if ResourceLoader.exists(face):
		var pt := P2Ui.tex_icon(load(face), 96)
		pt.position = Vector2(20, 48)
		card.add_child(pt)
	_add_text(card, String(P2Catalog.CLASSES[cid].name), Vector2(132, 52), P2Ui.T_HEAD, P2Ui.C_TEXT, 0.0, 3)
	var dv := P5Campaign.derived(GameState.campaign_view())
	P2Ui.chip_row(card, Vector2(132, 90), [[P2Ui.kit_tex("hud_heart", 1), str(int(dv.max_hp))], [P2Ui.kit_tex("cost_drop", 1), str(int(dv.max_mana)), P2Ui.C_BLOCK]], 6.0, 32.0)
	var d := _diff_pick(cb)
	var best: Dictionary = (cb.get("best_score", {}) as Dictionary).get(d, {})
	var rows := [
		["난이도", String(P2Catalog.DIFF[d].name) + (" ★" if bool((cb.get("diff_clear", {}) as Dictionary).get(d, false)) else ""), DIFF_COL[d], 1],
		["모드", "없음" if on.is_empty() else " ".join(PackedStringArray(on.map(func(m): return String(P2Catalog.MOD[m].short)))), P2Ui.C_GOLD if not on.is_empty() else P2Ui.C_DIM, 2],
		["금화", "+%d%%" % roundi(P2Catalog.MOD_GOLD * 100.0 * on.size()) if not on.is_empty() else "기본", P2Ui.C_GOLD if not on.is_empty() else P2Ui.C_DIM, 2],
		["최고 기록", "없음" if best.is_empty() else "%s  %d" % [String(best.rank), int(best.score)], P2Ui.C_GOLD if not best.is_empty() else P2Ui.C_DIM, 1],
	]
	var y := 166.0
	for r in rows:
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(12, y - 4)
		row.size = Vector2(384, 34)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var to := int(r[3])
		row.pressed.connect(func() -> void: go(to))
		card.add_child(row)
		_add_text(card, String(r[0]), Vector2(20, y), P2Ui.T_BODY, P2Ui.C_DIM)
		_add_text(card, String(r[1]), Vector2(140, y), P2Ui.T_BODY, r[2], 0.0, 0, 248.0)
		y += 40.0
	_add_text(card, "카드·유물은 이번 원정에서만 · 전투는 주인공 혼자", Vector2(20, BODY_H - 64), P2Ui.T_BODY, P2Ui.C_DIM, 368)


# ── 바꾸기 (모두 한 거래씩) ─────────────────────────────────────────────

func _set_diff(id: String) -> void:
	await _tx("difficulty", func(c, r, f):
		if not r.is_empty() or not f.is_empty() or not P2Catalog.diff_unlocked(c.combat.get("diff_clear", {}), id):
			return false
		c.combat["diff_pick"] = id
		return true)
	refresh()


func _toggle_mod(id: String) -> void:
	await _tx("mods", func(c, r, f):
		if not r.is_empty() or not f.is_empty():
			return false
		var on: Array = (c.combat.get("mods_pick", []) as Array).duplicate()
		if on.has(id):
			on.erase(id)
		else:
			on.append(id)
		c.combat["mods_pick"] = on
		return true)
	refresh()


static func deck_line(class_id: String) -> String:
	var counts := {}
	var order: Array = []
	for k in P2Catalog.class_deck(class_id):
		if not counts.has(k):
			order.append(k)
		counts[k] = int(counts.get(k, 0)) + 1
	return " · ".join(PackedStringArray(order.map(func(k): return P2Catalog.card_name(k) + (" ×%d" % int(counts[k]) if int(counts[k]) > 1 else ""))))


func _set_class(cid: String) -> void:
	if not RunService.run.is_empty():
		return
	await _tx("class", func(c, r, f):
		if not r.is_empty() or not f.is_empty():
			return false
		c.combat.class_id = cid
		P5Campaign.refresh_vitals(c)
		return true)
	refresh()


func _depart() -> void:
	if Flow.start_expedition():
		close()
	else:
		_msg.text = "출발하지 못했습니다: " + SaveManager.last_error
