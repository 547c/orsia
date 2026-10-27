extends Node

# 모든 마우스 올림 도움말: 픽셀 글꼴 20 · 어두운 돌 틀 · 넓으면 줄바꿈 (엔진 기본은 12px 한 줄이라 읽기 어려움)

const MAX_W := 460.0


func _ready() -> void:
	var th := ThemeDB.get_project_theme()
	if th == null:
		return
	th.set_font("font", "TooltipLabel", P2Ui.pixel_font(P2Ui.T_BODY))
	th.set_font_size("font_size", "TooltipLabel", P2Ui.T_BODY)
	th.set_color("font_color", "TooltipLabel", P2Ui.C_TEXT)
	th.set_constant("line_spacing", "TooltipLabel", 3)
	var sb := (P2Ui.style("leaf") as StyleBoxTexture).duplicate() as StyleBoxTexture
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	th.set_stylebox("panel", "TooltipPanel", sb)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Label and (n as Label).theme_type_variation == &"TooltipLabel":
		var l := n as Label
		l.text = wrap_text(l.atr(l.text), P2Ui.pixel_font(P2Ui.T_BODY), P2Ui.T_BODY, MAX_W)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


static func wrap_text(s: String, font: Font, size: int, max_w: float) -> String:
	var out := PackedStringArray()
	for line in s.split("\n"):
		var cur := ""
		for word in line.split(" "):
			var cand := word if cur == "" else cur + " " + word
			if cur != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
				out.append(cur)
				cur = word
			else:
				cur = cand
		out.append(cur)
	return "\n".join(out)
