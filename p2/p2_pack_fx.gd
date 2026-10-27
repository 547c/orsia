class_name P2PackFx
extends Node2D

# 손으로 그린 픽셀 효과 묶음(assets/vfx/Free, 64px 칸 · 9색 줄)의 한 줄을 정수배로 키워 그대로 튼다(최근접 확대라 픽셀 그대로).
# 색 줄: 0 주황(불) · 1 분홍보라 · 2 파랑(얼음) · 3 초록(독) · 4 흙 · 5 흰(빛) · 6 잿빛 · 7 진홍 · 8 진보라(어둠)
# loop면 직접 지울 때까지 돈다(상태 모습), 아니면 한 번 돌고 사라진다(터짐)

const CELL := 64
const SHEETS := {
	"23": "Part 1/23.png", "71": "Part 2/71.png", "116": "Part 3/116.png", "136": "Part 3/136.png", "174": "Part 4/174.png",
	"220": "Part 5/220.png", "464": "Part 10/464.png", "519": "Part 11/519.png", "528": "Part 11/528.png", "529": "Part 11/529.png",
	"569": "Part 12/569.png", "633": "Part 13/633.png", "652": "Part 14/652.png",
}
const ROW := {"fire": 0, "magenta": 1, "ice": 2, "poison": 3, "earth": 4, "light": 5, "ash": 6, "blood": 7, "dark": 8}

static var _tex := {}

var sheet := ""
var row := 0
var fps := 18.0
var loop := false
var frames := 1
var flip := false
var phase := 0.0
var _t := 0.0
var _texture: Texture2D


static func tex_of(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = load("res://assets/vfx/Free/" + String(SHEETS[id]))
	return _tex[id]


# 한 번 터짐(또는 loop). scale은 정수배를 권장(1 = 64px, 2 = 128px)
static func spawn(parent: Node, id: String, color: String, at: Vector2, scale_ := 2.0, opts := {}) -> P2PackFx:
	var f := P2PackFx.new()
	f.sheet = id
	f.row = int(ROW.get(color, 0))
	f.fps = float(opts.get("fps", 18.0))
	f.loop = bool(opts.get("loop", false))
	f.flip = bool(opts.get("flip", false))
	f.phase = float(opts.get("phase", 0.0))
	f.position = at
	f.scale = Vector2.ONE * scale_
	f.rotation = float(opts.get("rot", 0.0))
	f.z_index = int(opts.get("z", 0))
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	f._texture = tex_of(id)
	f.frames = maxi(1, int(f._texture.get_width()) / CELL)
	if opts.has("modulate"):
		f.modulate = opts.modulate
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_t += delta
	if not loop and _t * fps >= frames:
		queue_free()
		return
	queue_redraw()


func frame_now() -> int:
	var k := int((_t + phase) * fps)
	return k % frames if loop else mini(k, frames - 1)


func _draw() -> void:
	var src := Rect2(frame_now() * CELL, row * CELL, CELL, CELL)
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(_texture, Rect2(Vector2(-CELL / 2.0, -CELL / 2.0), Vector2(CELL, CELL)), src)
