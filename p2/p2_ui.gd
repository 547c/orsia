class_name P2Ui
extends RefCounted
# 허브·던전·전투·보상·결과 화면이 같이 쓰는 UI 조각. P3: 본문 16px 이상, 설정(흔들림·음량) 저장, 저장 실패 창

const C_TEXT := Color("#f3ead7")
const C_DIM := Color("#c2b59b")
const C_HP := Color("#d8483e")
const C_BLOCK := Color("#8fc3e8")
const C_MARK := Color("#b58cff")
const C_GOLD := Color("#f2c461")
const C_GOOD := Color("#8be08b")
const C_WARN := Color("#ff9a6a")
const C_SAFE := Color("#7fd7b0")
const C_PANEL := Color(0.08, 0.06, 0.05, 0.94)
const RAVEN := "res://assets/items/Free - Raven Fantasy Icons/Full Spritesheet/32x32.png"
const F_BODY := 16
const F_TITLE := 24
const F_BIG := 36
const SETTINGS := "user://settings.cfg"


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	return s


static func label(text: String, size: int, color: Color, wrap := 0.0) -> Label:
	var l := Label.new()
	if wrap > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap, 0)
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", pixel_font(size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outlined(l: Label, width := 4) -> Label:
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", width)
	return l


# ── 픽셀 틀: 원본 에셋(Franuka 틀·버튼, card_template 카드 틀)을 잘라 정수 배율로 키운다 ─────────
# 판넬은 잎 장식 버건디 틀, 안쪽은 불투명한 차분한 바탕(본문 글자용). 버튼은 버건디 버튼, 보상·선택 칸은 나무 틀.
const GUI2X := "res://assets/GUI/RPG UI Pack (Franuka)/Individual files/2x/"
const CARD_SHEET := "res://assets/GUI/card_template.png"
const C_CALM := Color8(40, 27, 33)
const CARD_FRONT := {"grey": Rect2(54, 33, 68, 109), "tan": Rect2(166, 33, 68, 109), "red": Rect2(54, 162, 68, 109),
	"blue": Rect2(166, 162, 68, 109), "green": Rect2(54, 290, 68, 109)}
const CARD_BANNER := {"grey": Rect2(276, 482, 70, 13), "tan": Rect2(276, 514, 70, 13), "red": Rect2(276, 546, 70, 13),
	"green": Rect2(276, 578, 70, 13), "blue": Rect2(276, 610, 70, 13)}
const CARD_CIRCLE := {"grey": Rect2(294, 647, 20, 20), "red": Rect2(294, 711, 20, 20), "blue": Rect2(294, 775, 20, 20), "green": Rect2(294, 743, 20, 20)}
const CARD_MANA_BADGE := Rect2(432, 768, 16, 16)
const CARD_TEXT_BOX := Rect2(276, 36, 56, 41)

static var _tex := {}
static var _styles := {}

# ── 돌 틀 키트: 전투 화면(assets/ui_battle)의 어두운 돌·맥 푸른 줄·금빛 강조를 원정 창에도 ─────────
const UIB := "res://assets/ui_battle/"
const C_SLATE := Color8(34, 36, 50)
const C_DEEP := Color8(25, 27, 43)
const C_EDGE := Color8(74, 77, 88)
const C_BEVEL := Color8(107, 111, 124)
const C_MAEK := Color8(29, 79, 158)
const C_CYAN := Color8(111, 208, 245)


static func kit_tex(id: String, k := 3) -> Texture2D:
	var key := "kit:%s@%d" % [id, k]
	if not _tex.has(key):
		var img := _image(UIB + id + ".png")
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


static func kit_icon(id: String, size: float) -> TextureRect:
	return tex_icon(kit_tex(id, 1), size)


# 아이콘 + 짧은 글 한 칸(숫자·보상·상태를 글 대신 칩으로). 폭은 글에 맞춘다
static func chip(icon: Texture2D, value: String, col := C_TEXT, h := 34.0) -> Panel:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", calm_box(C_EDGE, 0.95))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 8.0
	if icon != null:
		var ic := tex_icon(icon, h - 12.0)
		ic.position = Vector2(6, 6)
		c.add_child(ic)
		x = h - 2.0
	var l := outlined(text(value, T_BODY, col), 3)
	l.position = Vector2(x, h / 2.0 - 13.0)
	l.size = Vector2(pixel_font(T_BODY).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, T_BODY).x + 8.0, 26)
	c.add_child(l)
	c.size = Vector2(x + l.size.x + 8.0, h)
	return c


# 칩 여러 개를 한 줄로. items = [[아이콘, 글, 색], …]. 끝 x를 돌려준다
static func chip_row(parent: Control, pos: Vector2, items: Array, gap := 8.0, h := 34.0) -> float:
	var x := pos.x
	for it in items:
		var c := chip(it[0], String(it[1]), it[2] if (it as Array).size() > 2 else C_TEXT, h)
		c.position = Vector2(x, pos.y)
		parent.add_child(c)
		x += c.size.x + gap
	return x


# 제목 아래 맥 줄
static func rule(parent: Control, pos: Vector2, w: float, col := C_MAEK) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = Vector2(w, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


static func _image(path: String) -> Image:
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


# card_template의 한 칸을 잘라 정수 배율(최근접)로 키운 텍스처
static func sheet_tex(region: Rect2, scale := 2) -> Texture2D:
	var key := "%s|%d" % [str(region), scale]
	if not _tex.has(key):
		var img := _image(CARD_SHEET).get_region(Rect2i(region))
		img.resize(int(region.size.x) * scale, int(region.size.y) * scale, Image.INTERPOLATE_NEAREST)
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


# 틀 안쪽의 한 가지 바탕색만 차분한 어두운 색으로 바꾼 텍스처 (장식은 가장자리에 남음)
static func _calm_tex(file: String, fill: Color, inner: Rect2i) -> Texture2D:
	if not _tex.has(file):
		var img := _image(GUI2X + file)
		for y in range(inner.position.y, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				if img.get_pixel(x, y).is_equal_approx(fill):
					img.set_pixel(x, y, C_CALM)
		_tex[file] = ImageTexture.create_from_image(img)
	return _tex[file]


static func style(kind: String) -> StyleBox:
	if _styles.has(kind):
		return _styles[kind]
	var s := StyleBoxTexture.new()
	match kind:
		"leaf":
			# 전투 화면과 같은 어두운 돌 틀 (assets/ui_battle/tooltip_frame, 3배)
			s.texture = kit_tex("tooltip_frame")
			s.set_texture_margin_all(15)
			s.set_content_margin_all(18)
		"btn", "btn_hover", "btn_pressed", "btn_off":
			s.texture = kit_tex("prompt_frame")
			s.texture_margin_left = 12
			s.texture_margin_right = 12
			s.texture_margin_top = 9
			s.texture_margin_bottom = 9
			s.content_margin_left = 10
			s.content_margin_right = 10
			s.content_margin_top = 2
			s.content_margin_bottom = 4
			s.modulate_color = {"btn": Color.WHITE, "btn_hover": Color(1.35, 1.35, 1.45), "btn_pressed": Color(0.8, 0.8, 0.88), "btn_off": Color(0.7, 0.7, 0.72, 0.75)}[kind]
		"btn_on", "gold", "gold_hover", "gold_pressed", "gold_off":
			# 고른 단추·주 단추: 같은 돌 바탕에 금빛 테두리
			var f := StyleBoxFlat.new()
			f.bg_color = {"btn_on": Color(0.22, 0.18, 0.12), "gold": Color(0.24, 0.19, 0.1), "gold_hover": Color(0.34, 0.27, 0.13), "gold_pressed": Color(0.18, 0.14, 0.08), "gold_off": Color(0.14, 0.14, 0.17, 0.8)}[kind]
			f.border_color = C_GOLD if kind != "gold_off" else Color(0.42, 0.4, 0.38)
			f.border_color = Color("#ffe9a8") if kind == "gold_hover" else f.border_color
			f.set_border_width_all(3)
			f.content_margin_left = 10
			f.content_margin_right = 10
			f.content_margin_top = 2
			f.content_margin_bottom = 4
			_styles[kind] = f
			return f
	_styles[kind] = s
	return s


static func button(text: String, pos: Vector2, size: Vector2, font_size := F_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.set_meta("skin", "btn")
	_skin(b, false)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", C_GOLD)
	b.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.08))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_disabled_color", Color(0.62, 0.56, 0.52))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			ui_sound("hover"))
	b.pressed.connect(func() -> void: ui_sound("click"))
	return b


static func _skin(b: Button, on: bool) -> void:
	var k := String(b.get_meta("skin", "btn"))
	if k == "gold":
		b.add_theme_stylebox_override("normal", style("gold"))
		b.add_theme_stylebox_override("hover", style("gold_hover"))
		b.add_theme_stylebox_override("pressed", style("gold_pressed"))
		b.add_theme_stylebox_override("disabled", style("gold_off"))
	elif k == "btn":
		b.add_theme_stylebox_override("normal", style("btn_on" if on else "btn"))
		b.add_theme_stylebox_override("hover", style("btn_on" if on else "btn_hover"))
		b.add_theme_stylebox_override("pressed", style("btn_pressed"))
		b.add_theme_stylebox_override("disabled", style("btn_off"))
	else:
		b.add_theme_stylebox_override("normal", _tile(2 if on else 0))
		b.add_theme_stylebox_override("hover", _tile(2 if on else 1))
		b.add_theme_stylebox_override("pressed", _tile(2))
		b.add_theme_stylebox_override("disabled", _tile(3))
	b.add_theme_stylebox_override("focus", _focus_ring())


# 선택 칸: 0 보통 · 1 올림 · 2 고름(금색 테두리) · 3 막힘
static func _tile(state: int) -> StyleBoxFlat:
	var s := calm_box([C_EDGE, C_BEVEL.lightened(0.25), C_GOLD, C_EDGE.darkened(0.3)][state], 0.97 if state < 3 else 0.7)
	if state == 1:
		s.bg_color = C_SLATE.lightened(0.08)
	elif state == 2:
		s.bg_color = Color(0.2, 0.17, 0.12, 0.98)
		s.set_border_width_all(3)
	elif state == 3:
		s.bg_color = Color(C_SLATE.darkened(0.25), 0.8)
	return s


# 키보드로 고른 단추·칸: 바깥에 얇은 금빛 테두리
static func _focus_ring() -> StyleBoxFlat:
	if not _styles.has("focus_ring"):
		var f := StyleBoxFlat.new()
		f.draw_center = false
		f.border_color = Color(C_GOLD, 0.95)
		f.set_border_width_all(2)
		f.set_expand_margin_all(4)
		_styles["focus_ring"] = f
	return _styles["focus_ring"]


# 주 단추(교전 시작·확정·고르기): 금빛 테두리
static func primary(b: Button) -> Button:
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("skin", "gold")
	_skin(b, false)
	b.add_theme_color_override("font_color", C_GOLD)
	b.add_theme_color_override("font_hover_color", Color("#ffe9a8"))
	return b


static func mark(b: Button, on: bool) -> void:
	_skin(b, on)


# 잎 장식 틀 + 불투명한 차분한 안쪽. 돌려주는 것은 틀 안쪽 내용 판(틀 두께만큼 들여서 제목이 장식에 걸리지 않음)
static func panel(parent: Control, pos: Vector2, size: Vector2, dim := true, accent := Color(0.8, 0.65, 0.38)) -> Panel:
	var holder: Control = parent
	if dim:
		var d := ColorRect.new()
		d.color = Color(0, 0, 0, 0.6)
		d.set_anchors_preset(Control.PRESET_FULL_RECT)
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(d)
		holder = d
	var frame := Panel.new()
	frame.position = pos
	frame.size = size
	frame.add_theme_stylebox_override("panel", style("leaf"))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(frame)
	var line := ColorRect.new()
	line.color = Color(accent, 0.75)
	line.position = Vector2(12, 8)
	line.size = Vector2(size.x - 24, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(line)
	var p := Panel.new()
	p.position = Vector2(8, 12)
	p.size = size - Vector2(16, 24)
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(p)
	pop_in(frame, holder if dim else null)
	return p


# 창이 툭 나타나지 않게: 0.14초 동안 살짝 커지며 또렷해지고, 뒤 어둠도 같이 깔린다
static func pop_in(frame: Control, dim: Control = null) -> void:
	if not frame.is_inside_tree():
		return
	frame.pivot_offset = frame.size / 2.0
	frame.scale = Vector2.ONE * 0.94
	frame.modulate.a = 0.0
	var tw := frame.create_tween().set_parallel()
	tw.tween_property(frame, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame, "modulate:a", 1.0, 0.1)
	if dim != null:
		dim.modulate.a = 0.0
		tw.tween_property(dim, "modulate:a", 1.0, 0.12)
	ui_sound("open")


# 원정 창 소리: 올림(아주 작은 딸깍) · 누름 · 창 열림. 어디서든 같은 소리, 기본(Master) 음량을 따른다
const UI_SND := {"hover": ["UI/select_1.wav", -27.0, 1.6], "click": ["UI/click_double_on.wav", -16.0, 1.0], "open": ["Other/whoosh_2.wav", -24.0, 1.5]}
const SFX_DIR := "res://assets/sfx/400 Sounds pack/"
static var _ui_snd: Array = []
static var _ui_snd_i := 0
static var _ui_last := {}
static var ui_sound_log: Array = []


static func ui_sound(kind: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not UI_SND.has(kind):
		return
	var now := Time.get_ticks_msec()
	if now - int(_ui_last.get(kind, -1000)) < 60:
		return
	_ui_last[kind] = now
	_ui_snd = _ui_snd.filter(func(pl): return is_instance_valid(pl))
	if _ui_snd.is_empty():
		for i in range(3):
			var pl := AudioStreamPlayer.new()
			pl.process_mode = Node.PROCESS_MODE_ALWAYS
			tree.root.add_child.call_deferred(pl)
			_ui_snd.append(pl)
		return
	var pl: AudioStreamPlayer = _ui_snd[_ui_snd_i % _ui_snd.size()]
	_ui_snd_i += 1
	if not pl.is_inside_tree():
		return
	var spec: Array = UI_SND[kind]
	pl.stream = load(SFX_DIR + String(spec[0]))
	pl.volume_db = float(spec[1])
	pl.pitch_scale = float(spec[2])
	pl.play()
	ui_sound_log.append(kind)


# 작은 정보 칸 (차분한 바탕 + 얇은 나무색 테두리, 장식 없음)
static func calm_box(border := C_EDGE, alpha := 0.94) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_SLATE, alpha)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_content_margin_all(6)
	return s


# ── 글자: 픽셀 글꼴을 정수 배율에서만 쓴다 ───────────────────────────────────────────
# 본문 Mona10 20px(2배) · 제목 Mona12 24px(2배) · 큰 제목 36px(3배) · 작은 글 Mona12 12px(1배).
# 16·18·22px처럼 원래 격자와 안 맞는 크기는 획 굵기가 들쭉날쭉해져서 새로 그리는 전투·보상·원정 창에서는 쓰지 않는다
const FONT_BODY := "res://assets/fonts/Mona/01 Main/Mona10.ttf"
const FONT_HEAD := "res://assets/fonts/Mona/01 Main/Mona12.ttf"
const FONT_BOLD := "res://assets/fonts/Mona/01 Main/Mona12-Bold.ttf"
const T_SMALL := 12
const T_BODY := 20
const T_HEAD := 24
const T_BIG := 36
const C_INK := Color("#3d2936")

static var _fonts := {}
static var _bold := {}
static var _ui_scale := 1.0


# 크기마다 글꼴 하나. 픽셀 글꼴은 (크기 × 화면 배율)이 원래 격자(Mona10 = 10, Mona12 = 12)의 정수배일 때만 AA 없이 또렷하고,
# 16px·18px나 1.41배 같은 창에서는 AA 없이 그리면 획이 빠지거나 뭉쳐 한글이 깨져 보인다 → 그때는 회색 AA
static func pixel_font(size: int) -> Font:
	if not _fonts.has(size):
		var path := FONT_BODY if size == T_BODY else FONT_HEAD
		# duplicate()는 글리프 캐시를 원본(테마 글꼴 포함)과 얕게 공유해, 크기·AA가 다른 글꼴끼리 캐시를 덮어써 글자 윗줄이 빠지는 등 깨진다
		# → 글꼴 데이터만 받아 캐시가 따로인 새 FontFile을 만든다
		var f := FontFile.new()
		f.data = (load(path) as FontFile).data
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[size] = f
		_apply_aa(size, f)
	return _fonts[size]


# 피해 숫자용 굵은 글꼴 (12의 정수배 크기). 없는 글자는 같은 크기 보통 글꼴로
static func bold_font(size: int) -> Font:
	if not _bold.has(size):
		var f := FontFile.new()
		f.data = (load(FONT_BOLD) as FontFile).data
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.fallbacks = [pixel_font(size)]
		_bold[size] = f
		_apply_aa(size, f)
	return _bold[size]


static func _apply_aa(size: int, f: FontFile) -> void:
	var r := size * _ui_scale / (10.0 if size == T_BODY else 12.0)
	var crisp_grid := r >= 0.999 and absf(r - roundf(r)) < 0.01
	var aa := TextServer.FONT_ANTIALIASING_NONE if crisp_grid else TextServer.FONT_ANTIALIASING_GRAY
	if f.antialiasing != aa:
		f.antialiasing = aa


# 픽셀 크기로 맞춘 글자 (크기는 12·20·24·36 중 가까운 것으로). 줄바꿈 글은 띄어쓰기에서만 끊는다
static func text(t: String, size: int, color: Color, wrap := 0.0) -> Label:
	var s := snap_size(size)
	var l := label(keep_words(t) if wrap > 0.0 else t, s, color, wrap)
	l.add_theme_font_override("font", pixel_font(s))
	return l


# 엔진 줄바꿈(ICU)은 한글 음절 사이에서도 끊어 "공/격"처럼 단어가 갈라진다.
# 이어진 한글 음절 사이에 단어 결합 문자(U+2060, 폭 0)를 넣어 띄어쓰기에서만 줄이 바뀌게 한다
static func keep_words(t: String) -> String:
	var out := ""
	var prev_hangul := false
	for i in range(t.length()):
		var c := t.unicode_at(i)
		var hangul := c >= 0xAC00 and c <= 0xD7A3
		if hangul and prev_hangul:
			out += String.chr(0x2060)
		out += String.chr(c)
		prev_hangul = hangul
	return out


static func snap_size(size: int) -> int:
	if size <= 13:
		return T_SMALL
	if size <= 21:
		return T_BODY
	if size <= 30:
		return T_HEAD
	return T_BIG


static func crisp(c: Control, size: int) -> Control:
	var s := snap_size(size)
	c.add_theme_font_override("font", pixel_font(s))
	c.add_theme_font_size_override("font_size", s)
	return c


# 원본 2배 GUI 한 장을 나인패치로 (모서리·끝 장식은 원래 크기, 가운데만 늘림)
static func patch(file: String, size: Vector2, m: Array) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(GUI2X + file)
	n.patch_margin_left = int(m[0])
	n.patch_margin_top = int(m[1])
	n.patch_margin_right = int(m[2])
	n.patch_margin_bottom = int(m[3])
	n.size = size
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


# ── 카드 앞면: 전투 손패·올린 카드·보상·덱 보기가 함께 쓰는 하나의 그림 규칙 ─────────────────
# 원본 68×109 카드 틀을 정수 배율 s로 그린다 (2배 136×218 · 3배 204×327). 원본 좌표 기준 칸:
# 그림 창(6,4 · 56×37) · 이름 띠(−1,42 · 70×13) · 핵심 효과(56~68) · 조건(70~96, detail일 때) · 상태 띠.
# 수치·문구는 P2Catalog.face(카드, 직업)에서만 읽는다 (직업 보정 포함). 입력·실행은 여기서 다루지 않는다
static func card_art(c: Card, class_id: String, s: int, key := "", detail := false) -> Control:
	var col := P2Catalog.frame_color(c)
	var upgraded := P2Catalog.upgrade_of(c) != ""
	var big := s >= 3
	var root := Control.new()
	root.size = Vector2(68, 109) * s
	root.custom_minimum_size = root.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Panel.new()
	glow.position = Vector2(-5, -5)
	glow.size = root.size + Vector2(10, 10)
	var gs := StyleBoxFlat.new()
	gs.draw_center = false
	gs.border_color = C_GOLD
	gs.set_border_width_all(4)
	gs.set_corner_radius_all(6)
	glow.add_theme_stylebox_override("panel", gs)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	root.add_child(glow)
	root.add_child(_sheet_rect(CARD_FRONT[col], s, Vector2.ZERO))
	var art := NinePatchRect.new()
	art.texture = sheet_tex(CARD_TEXT_BOX, s)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		art.set_patch_margin(side, 4 * s)
	art.position = Vector2(6, 4) * s
	art.size = Vector2(56, 37) * s
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	var icon_size := 32.0 * s
	var ic := tex_icon(P2Catalog.icon_tex(P2Catalog.card_icon_key(c)), icon_size)
	ic.position = ((art.size - Vector2(icon_size, icon_size)) / 2.0).floor()
	art.add_child(ic)
	var owner := String(P2Catalog.CARD_CLASS.get(P2Catalog.kind_of(c), ""))
	if owner != "":
		var badge := class_badge(owner, 6.0 * s)
		badge.position = (art.position + Vector2(art.size.x - 6.0 * s * 1.6, -2.0 * s)).floor()
		root.add_child(badge)
	if key != "":
		var cap := keycap(key)
		cap.position = Vector2(root.size.x / 2.0 - cap.size.x / 2.0, -14)
		root.add_child(cap)
		root.set_meta("key", cap.get_child(0))
	var badge := _sheet_rect(CARD_MANA_BADGE, s, Vector2.ZERO)
	root.add_child(badge)
	var cost := text("X" if P2Catalog.is_x_cost(c) else str(c.mana_cost), T_HEAD, Color("#e2f1ff"))
	cost.add_theme_color_override("font_outline_color", Color("#16304f"))
	cost.add_theme_constant_override("outline_size", 4)
	cost.size = badge.size
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(cost)
	root.set_meta("cost", cost)
	root.set_meta("badge", badge)
	var banner := _sheet_rect(CARD_BANNER["tan" if upgraded else col], s, Vector2(-1, 42) * s)
	root.add_child(banner)
	var nm := text(c.card_name + (" ★" if upgraded and big else ""), T_HEAD if big else T_BODY, C_GOLD if upgraded else Color.WHITE)
	nm.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.07))
	nm.add_theme_constant_override("outline_size", 4)
	nm.size = banner.size - Vector2(0, s)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	banner.add_child(nm)
	var f := P2Catalog.face(c, class_id)
	var head := text(String(f[0]), T_HEAD if big else T_SMALL, C_GOOD if int(f[2]) > 0 else Color("#fff4df"))
	head.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.07, 0.85))
	head.add_theme_constant_override("outline_size", 3 if big else 2)
	head.position = Vector2(3, 56) * s
	head.size = Vector2(62, 13) * s
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.clip_text = true
	root.add_child(head)
	root.set_meta("head", head)
	var show_detail := detail or big
	if show_detail:
		var inset := ColorRect.new()
		inset.color = Color(0.05, 0.03, 0.05, 0.36)
		inset.position = Vector2(5, 70) * s
		inset.size = Vector2(58, 25) * s
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(inset)
		var body := text(String(f[1]), T_BODY if big else T_SMALL, Color(0.96, 0.92, 0.85), inset.size.x - 12)
		body.position = Vector2(6, 1)
		body.size = inset.size - Vector2(12, 2)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.add_theme_constant_override("line_spacing", 0)
		inset.add_child(body)
		root.set_meta("body", body)
	var tag_y := 96 if show_detail else 70
	var tag_bg := ColorRect.new()
	tag_bg.color = Color(0.06, 0.03, 0.05, 0.8)
	tag_bg.position = Vector2(5, tag_y) * s
	tag_bg.size = Vector2(58, 8 if show_detail else 11) * s
	tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_bg.visible = false
	root.add_child(tag_bg)
	var tag := text("", T_BODY if big else T_SMALL, C_GOLD)
	tag.position = tag_bg.position
	tag.size = tag_bg.size
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.clip_text = true
	root.add_child(tag)
	root.set_meta("tag", tag)
	root.set_meta("tag_bg", tag_bg)
	root.set_meta("glow", glow)
	root.set_meta("card", c)
	return root


# 손패 단축키: 마나 배지와 다른 모양(카드 윗변 가운데에 걸친 작은 어두운 키 [3]). 그림 안에 두 번째 숫자를 두지 않는다
static func keycap(key: String) -> Panel:
	var cap := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#241820")
	st.border_color = Color("#8a7a66")
	st.set_border_width_all(1)
	st.border_width_bottom = 3
	st.set_corner_radius_all(2)
	cap.add_theme_stylebox_override("panel", st)
	cap.size = Vector2(24, 20)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.tooltip_text = TranslationServer.translate("단축키 %s") % key
	var l := text(key, T_SMALL, Color("#d9cdb8"))
	l.size = Vector2(24, 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(l)
	cap.set_meta("keycap", true)
	return cap


# 화면 배율이 1보다 작으면(창이 1280×720보다 작음) AA를 끈 픽셀 글꼴의 획이 빠지거나 뭉친다 → 그때만 회색 AA로 그린다
static func fit_fonts_to_scale(scale: float) -> void:
	_ui_scale = scale
	for size in _fonts:
		_apply_aa(int(size), _fonts[size])
	for size in _bold:
		_apply_aa(int(size), _bold[size])


static func _sheet_rect(region: Rect2, s: int, pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = sheet_tex(region, s)
	t.position = pos
	t.size = region.size * s
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# 원정 창의 선택 칸 (제목 24px · 본문 20px · 아이콘). option_button의 원정 화면용 짝
static func option_tile(title: String, body: String, icon: Texture2D, size: Vector2, accent := Color(0, 0, 0, 0)) -> Button:
	var b := button("", Vector2.ZERO, size)
	b.clip_contents = true
	b.set_meta("skin", "tile")
	_skin(b, false)
	if accent.a > 0.0:
		var stripe := ColorRect.new()
		stripe.color = accent
		stripe.position = Vector2(2, 2)
		stripe.size = Vector2(6, size.y - 4)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(stripe)
	if icon != null:
		var ic := tex_icon(icon, 48)
		ic.position = Vector2(16, 12)
		b.add_child(ic)
	var t := outlined(text(title, T_HEAD, C_GOLD), 3)
	t.position = Vector2(76 if icon != null else 18, 22)
	t.size = Vector2(size.x - (90 if icon != null else 32), 28)
	t.clip_text = true
	b.add_child(t)
	var d := text(body, T_BODY, C_TEXT, size.x - 34)
	d.position = Vector2(18, 70)
	b.add_child(d)
	return b


static func tex_icon(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# 제목(24/16) + 본문(16) + 아이콘. 긴 본문은 버튼 폭에서 줄바꿈
static func option_button(title: String, body: String, icon: Texture2D, size: Vector2, accent := Color(0, 0, 0, 0)) -> Button:
	var b := button("", Vector2.ZERO, size)
	b.clip_contents = true
	b.set_meta("skin", "tile")
	_skin(b, false)
	if accent.a > 0.0:
		var stripe := ColorRect.new()
		stripe.color = accent
		stripe.position = Vector2(2, 2)
		stripe.size = Vector2(6, size.y - 4)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(stripe)
	if icon != null:
		var ic := tex_icon(icon, 44)
		ic.position = Vector2(12, 10)
		b.add_child(ic)
	var t := outlined(label(title, F_TITLE if title.length() <= 9 else F_BODY, C_GOLD), 3)
	t.position = Vector2(64 if icon != null else 14, 14)
	t.size = Vector2(size.x - (74 if icon != null else 24), 28)
	t.clip_text = true
	b.add_child(t)
	var d := label(body, F_BODY, C_TEXT, size.x - 26)
	d.position = Vector2(14, 60)
	b.add_child(d)
	return b


static func relic_tex(id: String) -> Texture2D:
	return P2Catalog.icon_tex(id)


static func card_tex(kind: String, upgrade := "") -> Texture2D:
	return P2Catalog.icon_tex(upgrade if upgrade != "" else kind)


static func deck_summary(deck: Array) -> String:
	var counts := {}
	var order: Array[String] = []
	for c in deck:
		var n := P2Catalog.card_name(String(c.kind), String(c.get("upgrade", "")))
		if not counts.has(n):
			order.append(n)
		counts[n] = int(counts.get(n, 0)) + 1
	return ", ".join(PackedStringArray(order.map(func(n): return "%s ×%d" % [n, counts[n]])))


static func kinds_summary(kinds: Array) -> String:
	var deck: Array = kinds.map(func(k): return {"kind": k, "upgrade": ""})
	return deck_summary(deck)


# ── 설정 (P3 전용 사용자 폴더에 저장: 흔들림 줄이기, 음량, 리듬, 처음 안내) ─────────────────────────
# 같은 파일을 언어 설정(LocaleManager)도 쓴다. 파일을 읽는 순간 다른 프로그램(동기화 등)이 잡고 있으면 읽기가 실패할 수 있는데,
# 그때 빈 설정으로 덮어쓰면 판정 보정 같은 다른 값이 지워진다. 그래서:
#  · 이번 실행 동안은 메모리 값이 우선(읽은 값·바꾼 값 모두 기억)
#  · 쓸 때는 파일을 새로 읽어 바뀐 칸만 얹고 저장. 읽기가 막히면 잠깐 뒤 다시, 끝내 못 읽으면 이번엔 쓰지 않고 다음 저장 때 같이 쓴다
static var _set_mem := {}
static var _set_dirty := {}


static func _setting(section: String, key: String, fallback: Variant) -> Variant:
	var k := section + "/" + key
	if _set_mem.has(k):
		return _set_mem[k]
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK and cfg.has_section_key(section, key):
		_set_mem[k] = cfg.get_value(section, key)
		return _set_mem[k]
	return fallback


static func _put_setting(section: String, key: String, value: Variant) -> void:
	_set_mem[section + "/" + key] = value
	_set_dirty[section + "/" + key] = value


static func _flush_settings() -> void:
	if _set_dirty.is_empty():
		return
	var err := OK
	for attempt in range(3):
		var cfg := ConfigFile.new()
		err = cfg.load(SETTINGS)
		if err != OK and FileAccess.file_exists(SETTINGS):
			OS.delay_msec(20)
			continue
		for k in _set_dirty:
			var parts := String(k).split("/")
			cfg.set_value(parts[0], parts[1], _set_dirty[k])
		if cfg.save(SETTINGS) == OK:
			_set_dirty.clear()
			return
		OS.delay_msec(20)
	# 잠긴 게 아니라 내용이 깨진 파일이면: 깨진 파일은 .bad로 남기고 이번 실행이 아는 값으로 새로 쓴다(잠김이면 다음 저장 때 다시)
	if err == ERR_PARSE_ERROR:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SETTINGS), ProjectSettings.globalize_path(SETTINGS + ".bad"))
		var fresh := ConfigFile.new()
		for k in _set_mem:
			var parts := String(k).split("/")
			fresh.set_value(parts[0], parts[1], _set_mem[k])
		if fresh.save(SETTINGS) == OK:
			_set_dirty.clear()


static func load_settings() -> Dictionary:
	return {"reduce_motion": bool(_setting("view", "reduce_motion", false)), "battle_fx": bool(_setting("view", "battle_fx", true)),
		"volume": float(_setting("audio", "volume", 80.0))}


static func save_settings(s: Dictionary) -> void:
	_put_setting("view", "reduce_motion", bool(s.get("reduce_motion", false)))
	_put_setting("view", "battle_fx", bool(s.get("battle_fx", true)))
	_put_setting("audio", "volume", float(s.get("volume", 80.0)))
	_flush_settings()


# 리듬 설정: 판정 보정 ms · 누르기 키(any 아무 키 / zx / 직접 정한 두 키) · 노트 속도(접근 시간 배수) · 반주 음량(0~1)
static func load_rhythm() -> Dictionary:
	return {"offset_ms": int(_setting("rhythm", "offset_ms", 0)), "keys": String(_setting("rhythm", "keys", "any")), "keys_custom": String(_setting("rhythm", "keys_custom", "")),
		"approach": float(_setting("rhythm", "approach", 1.0)), "beat": float(_setting("rhythm", "beat", 1.0)),
		"practiced": bool(_setting("rhythm", "practiced", false))}


# 누르기 키: "any" = 아무 키 · "zx" = Z·X · "custom:<키>,<키>" = 고른 두 키(물리 키 코드). 클릭은 늘 된다
static func hit_keys_of(keys: String) -> Array:
	if keys == "zx":
		return [KEY_Z, KEY_X]
	if keys.begins_with("custom:"):
		return Array(keys.substr(7).split(",")).map(func(k): return int(k)).filter(func(k): return int(k) > 0)
	return []


static func keys_label(keys: String) -> String:
	var ks := hit_keys_of(keys)
	if ks.is_empty():
		return "아무 키·클릭"
	return "·".join(PackedStringArray(ks.map(func(k): return OS.get_keycode_string(int(k))))) + "·클릭만"


static func save_rhythm(r: Dictionary) -> void:
	for k in ["offset_ms", "keys", "keys_custom", "approach", "beat", "practiced"]:
		if r.has(k):
			_put_setting("rhythm", k, r[k])
	_flush_settings()


# 처음 한 번만 뜨는 안내(지도 돌리기 · 소용돌이 등)를 봤는지. 세이브 슬롯과 따로
static func hint_seen(key: String) -> bool:
	return bool(_setting("hints", key, false))


static func set_hint(key: String, seen := true) -> void:
	_put_setting("hints", key, seen)
	_flush_settings()


static func apply_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, value <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, value / 100.0)))


# ── 저장 실패 창 ────────────────────────────────────────────────────────────
# 행동이 끝난 뒤 저장이 실패하면 진행을 멈추고 이 창을 띄운다. [다시 저장]은 붙잡아 둔 같은 결과만 다시 쓴다.
# [저장하지 않고 종료]는 그 결과를 버리고(남은 임시 파일도 지움) 마지막으로 저장된 지점에서 재개한다고 알린 뒤에만 끈다.
# 하나의 창(RunService.gate)을 메뉴·원정·전투가 함께 쓴다. 떠 있는 동안은 게임 트리를 멈춰 대화·이동·조우·다른 거래가
# 캠페인을 바꾸지 못하게 한다 (창 자신만 계속 동작).
class SaveGate extends Control:
	signal resolved
	signal opened
	var model: RunModel
	var active := false
	var _panel: Panel
	var _msg: Label
	var _confirm_quit := false
	var _was_paused := false

	func _init(m: RunModel) -> void:
		model = m
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false

	func is_open() -> bool:
		return active

	# 이미 열려 있으면 그 창이 끝날 때까지 기다린다. 저장이 성공했을 때만 true로 돌아온다
	func run() -> bool:
		if not model.has_pending():
			return true
		if active:
			await resolved
			return not model.has_pending()
		active = true
		_build()
		await resolved
		return not model.has_pending()

	func _build() -> void:
		for c in get_children():
			c.queue_free()
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		_was_paused = get_tree().paused
		get_tree().paused = true
		opened.emit()
		_panel = P2Ui.panel(self, Vector2(290, 190), Vector2(700, 330), true, P2Ui.C_WARN)
		var t := P2Ui.label("저장하지 못했습니다", P2Ui.F_TITLE, P2Ui.C_WARN)
		t.position = Vector2(24, 18)
		_panel.add_child(t)
		_msg = P2Ui.label("", P2Ui.F_BODY, P2Ui.C_TEXT, 650)
		_msg.position = Vector2(24, 64)
		_panel.add_child(_msg)
		_set_msg()
		var retry := P2Ui.button("다시 저장", Vector2(24, 252), Vector2(220, 46), P2Ui.F_TITLE)
		retry.pressed.connect(_on_retry)
		_panel.add_child(retry)
		var quit := P2Ui.button("저장하지 않고 종료", Vector2(264, 252), Vector2(260, 46))
		quit.pressed.connect(_on_quit)
		_panel.add_child(quit)

	func _set_msg(extra := "") -> void:
		var what := String(model.pending.get("reason", ""))
		_msg.text = "방금 행동(%s)의 결과를 아직 저장하지 못해 게임을 멈췄습니다. 이 행동은 취소되지 않았고 저장을 기다리는 중입니다. [다시 저장]은 같은 결과를 한 번 기록할 뿐 금액·피해·뽑기·보상을 다시 계산하지 않습니다.%s" % [_reason_text(what), extra]

	static func _reason_text(r: String) -> String:
		return {"card": "카드", "enemy action": "적 행동", "enemy phase": "턴 종료", "round end": "라운드 정리", "start battle": "전투 시작",
			"reward": "보상 선택", "continue": "하드층 진입", "return": "여기서 마침", "portal": "포탈", "enter": "원정 출발", "route": "경로 선택",
			"mulligan": "첫 손패 교체", "new profile": "새 프로필", "buy": "구매", "equip": "장착", "potion": "물약", "bounty accept": "의뢰 수락",
			"bounty refresh": "의뢰판 새로고침", "bounty claim": "의뢰 보상 받기", "new game": "새 게임 첫 저장", "class": "직업 변경",
			"prep intro": "안내 확인", "shop": "상인 거래", "choice": "선택 지점",
			"start field": "들판 전투 시작", "retreat": "후퇴", "abandon": "원정 포기", "position": "위치 기록"}.get(r, r)

	func _on_retry() -> void:
		if model.retry_pending():
			_close()
		else:
			_set_msg("\n\n다시 실패했습니다: " + model.last_error.substr(0, 90))

	func _on_quit() -> void:
		if not _confirm_quit:
			_confirm_quit = true
			_set_msg("\n\n한 번 더 누르면 이 행동을 버리고 종료합니다. 다음 실행은 마지막으로 저장된 지점에서 시작합니다.")
			return
		if not SaveManager.discard_pending():
			_set_msg("\n\n임시 저장 파일을 지우지 못했습니다. 이대로 끄면 다음에 불러올 때 이 행동이 반영된 상태로 열릴 수 있습니다. [다시 저장]을 권합니다.")
			return
		get_tree().quit()

	func _close() -> void:
		for c in get_children():
			c.queue_free()
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		active = false
		_confirm_quit = false
		get_tree().paused = _was_paused
		resolved.emit()


# ── 창 돌 틀 입히기 ─────────────────────────────────────────────────────────────
# 예전 GUI 팩(살구·분홍 그림 틀, 밝은 판) 창의 판 · 단추 · 막대 · 글자색을 전투·원정 창과 같은 돌 틀로 바꾼다.
# 창 _ready에서 한 번 부르면 나중에 코드로 붙는 줄(상점 품목 등)도 붙는 다음 프레임에 바꾼다. 아이콘·초상 그림은 그대로
static func stone_ui(root: Node) -> void:
	_stone_tree(root)
	if root.has_meta("stone_ui") or not root.is_inside_tree():
		return
	root.set_meta("stone_ui", true)
	var tree := root.get_tree()
	var cb := func(n: Node) -> void:
		if root.is_ancestor_of(n):
			_stone_node.call_deferred(n)
	tree.node_added.connect(cb)
	root.tree_exiting.connect(func() -> void:
		if tree.node_added.is_connected(cb):
			tree.node_added.disconnect(cb))


static func _stone_tree(n: Node) -> void:
	_stone_node(n)
	for c in n.get_children():
		_stone_tree(c)


# 예전 틀: GUI 팩 그림을 쓰는 틀, 또는 밝은 단색 판(살구·분홍)
static func _old_box(sb: StyleBox) -> bool:
	if sb is StyleBoxTexture:
		var tex := (sb as StyleBoxTexture).texture
		return tex != null and String(tex.resource_path).contains("assets/GUI/")
	if sb is StyleBoxFlat:
		var c := (sb as StyleBoxFlat).bg_color
		return c.a > 0.5 and c.get_luminance() > 0.42
	return false


static func _stone_node(n: Node) -> void:
	if not is_instance_valid(n) or n.has_meta("stone_skip"):
		return
	if (n is Label or n is Button or n is RichTextLabel) and not n.has_meta("town_font"):
		var up := n.get_parent()
		while up != null:
			if up.has_meta("town_window"):
				_town_fonts(n)
				break
			up = up.get_parent()
	if n is Button:
		var b := n as Button
		if _old_box(b.get_theme_stylebox("normal")):
			b.set_meta("skin", "btn")
			_skin(b, false)
			b.add_theme_color_override("font_color", C_TEXT)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			b.add_theme_color_override("font_pressed_color", C_GOLD)
			b.add_theme_color_override("font_focus_color", C_TEXT)
			b.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.08))
			b.add_theme_constant_override("outline_size", 3)
	elif n is ProgressBar:
		var pb := n as ProgressBar
		if _old_box(pb.get_theme_stylebox("fill")) or _old_box(pb.get_theme_stylebox("background")):
			var nm := String(pb.name).to_lower()
			var col := C_BLOCK if nm.contains("mana") or nm.contains("mp") else (C_GOLD if nm.contains("xp") or nm.contains("exp") else C_HP)
			var bg := calm_box(C_EDGE, 0.95)
			bg.set_content_margin_all(0)
			var fill := StyleBoxFlat.new()
			fill.bg_color = col
			fill.border_color = col.lightened(0.35)
			fill.border_width_top = 2
			pb.add_theme_stylebox_override("background", bg)
			pb.add_theme_stylebox_override("fill", fill)
	elif n is TextureRect and (n as TextureRect).texture != null and String((n as TextureRect).texture.resource_path).contains("Title banners/"):
		# 창 제목 리본(살구·분홍·금색 그림) → 같은 자리에 돌 단추 틀
		var tr_ := n as TextureRect
		var np := NinePatchRect.new()
		np.texture = kit_tex("prompt_frame")
		np.patch_margin_left = 12
		np.patch_margin_right = 12
		np.patch_margin_top = 9
		np.patch_margin_bottom = 9
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		np.set_meta("stone_skip", true)
		tr_.texture = null
		tr_.add_child(np)
		np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr_.move_child(np, 0)
		np.show_behind_parent = true
	elif n is NinePatchRect:
		var np := n as NinePatchRect
		if np.texture != null and String(np.texture.resource_path).contains("assets/GUI/"):
			np.texture = kit_tex("tooltip_frame")
			np.region_rect = Rect2()
			np.patch_margin_left = 15
			np.patch_margin_top = 15
			np.patch_margin_right = 15
			np.patch_margin_bottom = 15
	elif n is PanelContainer or n is Panel:
		var c := n as Control
		var sb := c.get_theme_stylebox("panel")
		if _old_box(sb):
			var stone: StyleBox = calm_box(C_EDGE, 0.96) if c.size.y > 0.0 and c.size.y < 70.0 else (style("leaf") as StyleBox).duplicate()
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				stone.set_content_margin(side, sb.get_content_margin(side))
			# 테두리만 그리던 틀(미니맵 테두리 등)은 돌 틀도 테두리만 — 아래 그림을 가리지 않게
			if sb is StyleBoxTexture and not (sb as StyleBoxTexture).draw_center:
				if stone is StyleBoxTexture:
					(stone as StyleBoxTexture).draw_center = false
				elif stone is StyleBoxFlat:
					(stone as StyleBoxFlat).draw_center = false
			c.add_theme_stylebox_override("panel", stone)
	if n is Label:
		var l := n as Label
		var ls := l.get_theme_stylebox("normal")
		if _old_box(ls):
			# 제목 리본 바탕의 글자칸 → 돌 단추 틀 + 금빛 글자
			var st := (style("btn") as StyleBox).duplicate()
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				st.set_content_margin(side, ls.get_content_margin(side))
			l.add_theme_stylebox_override("normal", st)
			l.add_theme_color_override("font_color", C_GOLD)
		elif l.get_theme_color("font_color").get_luminance() < 0.35:
			l.add_theme_color_override("font_color", C_TEXT)
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		if r.get_theme_color("default_color").get_luminance() < 0.35:
			r.add_theme_color_override("default_color", C_TEXT)


static func stat_tooltip(run: Dictionary) -> String:
	var lv := int(run.get("lv", 1))
	var lines: Array = [TranslationServer.translate("원정 레벨 %d · 경험치 %d/%d") % [lv, int(run.get("lv_xp", 0)), P2Catalog.lv_need(lv)]]
	var st: Dictionary = run.get("stats", {})
	for k in P2Catalog.STAT_ORDER:
		if int(st.get(k, 0)) > 0:
			lines.append("%s: %s" % [P2Catalog.STATS[k].name, P2Catalog.stat_text(k, int(st[k]))])
	if st.is_empty():
		lines.append(TranslationServer.translate("능력치 없음 — 레벨이 오르면 하나씩 고릅니다"))
	return "\n".join(PackedStringArray(lines))


static func stat_chips(run: Dictionary) -> Array:
	var out: Array = []
	var st: Dictionary = run.get("stats", {})
	for k in P2Catalog.STAT_ORDER:
		if int(st.get(k, 0)) > 0:
			var unit := "%" if k in ["cdmg", "focus"] else ("%p" if k == "crit" else "")
			out.append([kit_tex(String(P2Catalog.STATS[k].icon), 1), "%s +%d%s" % [P2Catalog.STATS[k].name, int(st[k]), unit]])
	return out


# 메뉴 창을 원정 창과 같은 모양으로: 돌 틀 + 위 금줄 + 왼쪽 위 큰 금빛 제목 + 가는 금줄, 본문은 픽셀 글꼴(20)로 또렷하게.
# panel = 가운데 고정 판(앵커 가운데), body = 판 안 내용 묶음(위 여백을 제목 아래로), title = 기존 제목 글자(제목 자리로 옮김, 글이 바뀌어도 그대로 따라감)
const TOWN_DY := 21.0


static func town_window(panel: Control, body: Control, title: Label, size := Vector2.ZERO, accent := C_GOLD) -> void:
	if panel == null or panel.has_meta("town_window"):
		return
	panel.set_meta("town_window", true)
	if size != Vector2.ZERO:
		panel.offset_left = -size.x / 2.0
		panel.offset_right = size.x / 2.0
		panel.offset_top = -size.y / 2.0 + TOWN_DY
		panel.offset_bottom = size.y / 2.0 + TOWN_DY
	var w := panel.offset_right - panel.offset_left
	if panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", style("leaf"))
	elif panel is NinePatchRect:
		var np := panel as NinePatchRect
		np.texture = kit_tex("tooltip_frame")
		np.region_rect = Rect2()
		for side in ["left", "top", "right", "bottom"]:
			np.set("patch_margin_" + side, 15)
	var line := ColorRect.new()
	line.color = Color(accent, 0.75)
	line.position = Vector2(12, 8)
	line.size = Vector2(w - 24, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_meta("stone_skip", true)
	panel.add_child(line)
	if title != null:
		var banner := title.get_parent()
		title.reparent(panel, false)
		if banner is NinePatchRect or (banner is Control and String(banner.name).contains("Banner")):
			(banner as CanvasItem).visible = false
		title.set_meta("stone_skip", true)
		title.set_meta("town_font", true)
		title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		title.add_theme_font_override("font", pixel_font(T_BIG))
		title.add_theme_font_size_override("font_size", T_BIG)
		title.add_theme_color_override("font_color", accent)
		title.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02))
		title.add_theme_constant_override("outline_size", 4)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.set_anchors_preset(Control.PRESET_TOP_LEFT)
		title.position = Vector2(28, 16)
		title.size = Vector2(w - 56, 44)
		title.custom_minimum_size = Vector2.ZERO
	rule(panel, Vector2(28, 64), w - 56, Color(accent, 0.45))
	if body != null:
		body.offset_top = maxf(body.offset_top, 82.0)
		if body is BoxContainer:
			(body as BoxContainer).add_theme_constant_override("separation", 12)
		_town_fonts(body)


# 본문 글자: 작은 글(13 이하) = 12, 그 밖 = 20, 큰 글(26 이상) = 24. 단추는 20
static func _town_fonts(n: Node) -> void:
	if n.has_meta("town_font"):
		return
	if n is Label or n is Button:
		var c := n as Control
		var cur := c.get_theme_font_size("font_size")
		var sz := T_HEAD if cur >= 26 else T_BODY
		c.add_theme_font_override("font", pixel_font(sz))
		c.add_theme_font_size_override("font_size", sz)
		c.set_meta("town_font", true)
	elif n is RichTextLabel:
		(n as RichTextLabel).add_theme_font_override("normal_font", pixel_font(T_BODY))
		(n as RichTextLabel).add_theme_font_size_override("normal_font_size", T_BODY)
	for ch in n.get_children():
		_town_fonts(ch)


# 유물 단계 표(칸 오른쪽 아래): Ⅱ·Ⅲ 금빛, 잠듦 = 아이콘을 흐리게 + 'zz'. 1단계는 표 없음
static func relic_level_mark(slot: Control, lv: int, w: float) -> void:
	if lv == 1:
		return
	if lv <= 0:
		for ch in slot.get_children():
			if ch is CanvasItem:
				(ch as CanvasItem).modulate = Color(0.45, 0.45, 0.55, 0.75)
		var z := outlined(text("zz", T_SMALL, C_DIM), 2)
		z.position = Vector2(w - 18.0, -2.0)
		z.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(z)
		return
	var b := outlined(text(["", "", "Ⅱ", "Ⅲ"][clampi(lv, 0, 3)], T_SMALL + 4, C_GOLD), 3)
	b.position = Vector2(w - 16.0, w - 22.0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(b)


static func relic_level_text(lv: int) -> String:
	if lv <= 0:
		return "\n" + TranslationServer.translate("잠듦: 석판 때문에 꺼져 있음")
	if lv >= 2:
		return "\n" + TranslationServer.translate("%d단계: 수치 ×%d (석판)") % [lv, lv]
	return ""


# 카드 주인 직업 문장: 직업 색 테를 두른 둥근 패에 직업 아이콘. 올리면 '○○ 카드'
static func class_badge(cls: String, r: float) -> Control:
	var col: Color = P2Catalog.CLASS_COLOR.get(cls, C_GOLD)
	var box := Panel.new()
	box.size = Vector2(r, r) * 2.0
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.62)
	sb.border_color = col
	sb.set_border_width_all(maxi(2, roundi(r / 5.0)))
	sb.set_corner_radius_all(roundi(r))
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 2
	box.add_theme_stylebox_override("panel", sb)
	var ic := tex_icon(P2Catalog.icon_tex(cls), r * 1.3)
	ic.position = (Vector2(r, r) - Vector2(r, r) * 0.65).floor()
	box.add_child(ic)
	box.tooltip_text = TranslationServer.translate("%s 카드") % String(P2Catalog.CLASSES.get(cls, {}).get("name", cls))
	return box
