class_name LabCatalog
extends RefCounted

# P1 카드는 기존 Card 리소스를 복제한 로컬 사본이다. 캠페인 .tres는 절대 수정하지 않는다.
# [kind] = [이름, 원본 .tres, 마나, 수치, 색(0 물리/1 마법/2 공용), 광역]
const DEFINITIONS := {
	"slash": ["베기", "wooden_sword_slash", 1, 6, 0, false],
	"bolt": ["마력탄", "magic_bolt", 1, 4, 1, false],
	"guard": ["수호", "guard", 1, 7, 2, false],
	"sweep": ["휩쓸기", "spin_slash", 2, 4, 0, true],
	"bash": ["방패 강타", "wooden_sword_slash", 1, 4, 0, false],
	"wave": ["마력 파동", "magic_bolt", 2, 5, 1, true],
}
const STARTER := ["slash", "slash", "bolt", "bolt", "guard", "guard", "guard", "sweep"]
const MAX_DECK := 10

const RAVEN_SHEET := "res://assets/items/Free - Raven Fantasy Icons/Full Spritesheet/32x32.png"
const CARD_ICONS := {
	"slash": Rect2(448, 1312, 32, 32),
	"bolt": Rect2(160, 1536, 32, 32),
	"guard": Rect2(128, 1184, 32, 32),
	"sweep": Rect2(256, 1440, 32, 32),
	"bash": Rect2(384, 1216, 32, 32),
	"wave": Rect2(384, 1536, 32, 32),
	"split": Rect2(160, 1536, 32, 32),
	"counter": Rect2(256, 1312, 32, 32),
}

const UPGRADES := {
	"split": {"name": "분열 마력탄", "from": "bolt", "text": "선택한 마력탄 한 장: 마법 3 × 2, 적중마다 표식 1"},
	"counter": {"name": "반격 수호", "from": "guard", "text": "선택한 수호 한 장: 방어 7 + 막으면 공격자에게 반격 4 (이번 적 단계)"},
}

const RELICS := {
	"arc": {"name": "방전 고리", "icon": Rect2(0, 2048, 32, 32),
		"text": "턴마다 두 번째 마법 적중 뒤, 다른 적 중 체력이 가장 낮은 적에게 번개 2"},
	"absorb": {"name": "흡수 문장", "icon": Rect2(416, 1312, 32, 32),
		"text": "턴마다 처음 물리 공격으로 표식을 터뜨리면 방어 3"},
	"thorn": {"name": "가시 버클", "icon": Rect2(448, 1568, 32, 32),
		"text": "적 단계마다 처음으로 방어가 막아 낸 공격자에게 가시 3"},
	"bandage": {"name": "전투 붕대", "icon": Rect2(64, 1312, 32, 32),
		"text": "전투에서 이기면 체력 2 회복 (최대 36)"},
}
const RELIC_ORDER := ["arc", "absorb", "thorn", "bandage"]

# moves: 턴마다 순환하는 행동. [] = 준비(공격 없음), [n] = 공격 n, [n, n] = 연타
const ENEMIES := {
	"scout": {"name": "척후병", "hp": 14, "armor": 0, "type": "ORC", "variant": 1, "ranged": false,
		"moves": [[5]], "role": "매 턴 공격 5"},
	"archer": {"name": "사수", "hp": 18, "armor": 0, "type": "SKELETON", "variant": 2, "ranged": true,
		"moves": [[], [9]], "role": "준비 → 공격 9"},
	"breaker": {"name": "파괴자", "hp": 26, "armor": 0, "type": "ORC", "variant": 3, "ranged": false,
		"moves": [[8], [], [12]], "role": "공격 8 → 준비 → 공격 12"},
	"armor": {"name": "갑옷병", "hp": 24, "armor": 2, "type": "SKELETON", "variant": 3, "ranged": false,
		"moves": [[], [10]], "role": "준비 → 공격 10 · 갑옷 2"},
}

const ENCOUNTERS := [
	{"title": "전투 1 / 3 · 숲의 입구", "hint": "마력탄으로 표식을 남기고, 베기로 터뜨리세요.",
		"enemies": ["scout", "scout"], "offsets": [0, 0]},
	{"title": "전투 2 / 3 · 길목의 파괴자", "hint": "공격을 준비하는 적을 먼저 끊을까요, 방어를 남길까요?",
		"enemies": ["archer", "breaker"], "offsets": [0, 0]},
	{"title": "전투 3 / 3 · 무너진 성문", "hint": "갑옷은 작은 타격을 깎습니다. 준비하는 턴을 노리세요.",
		"enemies": ["armor", "archer"], "offsets": [0, 1]},
]


static func make_card(kind: String, uid: String, upgrade: String = "") -> Card:
	var d: Array = DEFINITIONS[kind]
	var c := (load("res://battle/cards/%s.tres" % d[1]) as Card).duplicate(true) as Card
	c.card_name = d[0]
	c.mana_cost = d[2]
	c.value = d[3]
	c.color = d[4]
	c.is_aoe = d[5]
	c.effect = Card.EffectType.DEFEND if kind == "guard" else Card.EffectType.DAMAGE
	c.damage_trait = ""
	c.status_package = ""
	c.hp_cost = 0
	c.switch_mark = 0
	c.on_use_set_gauge = 0
	c.secondary_value = 0
	c.tier = Card.CardTier.TIER_1
	c.set_meta("kind", kind)
	c.set_meta("uid", uid)
	c.set_meta("upgrade", upgrade)
	if upgrade == "split":
		c.card_name = UPGRADES.split.name
		c.value = 3
	elif upgrade == "counter":
		c.card_name = UPGRADES.counter.name
	return c


static func starter() -> Array[Card]:
	var result: Array[Card] = []
	for kind in STARTER:
		result.append(make_card(kind, "c%d" % result.size()))
	return result


static func kind_of(c: Card) -> String:
	return String(c.get_meta("kind", ""))


static func upgrade_of(c: Card) -> String:
	return String(c.get_meta("upgrade", ""))


static func uid_of(c: Card) -> String:
	return String(c.get_meta("uid", ""))


static func hits_of(c: Card) -> int:
	return 2 if upgrade_of(c) == "split" else 1


static func is_magic(c: Card) -> bool:
	return c.color == Card.CardColor.MAGIC


static func is_targeted(c: Card) -> bool:
	return c.effect == Card.EffectType.DAMAGE and not c.is_aoe


static func text(c: Card) -> String:
	match upgrade_of(c):
		"split":
			return "마법 3 × 2\n적중마다 표식 1"
		"counter":
			return "방어 7\n막아 내면 반격 4"
	match kind_of(c):
		"slash":
			return "물리 6\n표식 1개당 +3 (터뜨림)"
		"bolt":
			return "마법 4\n표식 1"
		"guard":
			return "방어 7\n적 단계가 끝나면 사라짐"
		"sweep":
			return "모든 적에게 물리 4\n적마다 표식 터뜨림"
		"bash":
			return "방어를 최대 6 써서\n물리 4 + 쓴 방어 × 2"
		"wave":
			return "모든 적에게 마법 5\n적마다 표식 1"
	return ""


static func icon_region(c: Card) -> Rect2:
	var upgrade := upgrade_of(c)
	if CARD_ICONS.has(upgrade):
		return CARD_ICONS[upgrade]
	return CARD_ICONS.get(kind_of(c), CARD_ICONS.slash)


static func tint(c: Card) -> Color:
	if c.color == Card.CardColor.MAGIC:
		return Color("#6f5bd6")
	if c.color == Card.CardColor.PHYSICAL:
		return Color("#c8683a")
	return Color("#4f8f6a")


static func type_label(c: Card) -> String:
	if c.color == Card.CardColor.MAGIC:
		return "마법"
	if c.color == Card.CardColor.PHYSICAL:
		return "검"
	return "방어"


# 필드용 시각 변종을 난수 없이 만든다 (BattleData.pick_variant는 randi를 써서 쓰지 않는다)
static func variant_for(role: String) -> Dictionary:
	var d: Dictionary = ENEMIES[role]
	var v: Dictionary = (BattleData.MONSTER_VARIANTS[d.type][d.variant] as Dictionary).duplicate(true)
	var base_path: String = v.get("base", BattleData.MOB_SHEET_BASE) + v["folder"] + "/"
	v["idle_path"] = base_path + "Idle/Idle-Sheet.png"
	v["run_path"] = base_path + "Run/Run-Sheet.png"
	v["death_path"] = base_path + "Death/Death-Sheet.png"
	v["idle_frame_size"] = v.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	v["idle_frame_count"] = v.get("idle_frame_count", BattleData.MOB_IDLE_FRAME_COUNT)
	v["run_frame_size"] = v.get("run_frame_size", BattleData.MOB_RUN_FRAME_SIZE)
	v["run_frame_count"] = v.get("run_frame_count", BattleData.MOB_RUN_FRAME_COUNT)
	return v


static func move_text(hits: Array) -> String:
	if hits.is_empty():
		return "준비"
	if hits.size() > 1:
		return "공격 %d × %d" % [int(hits[0]), hits.size()]
	return "공격 %d" % int(hits[0])


static func encounter_preview(index: int) -> String:
	if index < 0 or index >= ENCOUNTERS.size():
		return ""
	var lines: Array[String] = []
	for role in ENCOUNTERS[index].enemies:
		var d: Dictionary = ENEMIES[role]
		lines.append("%s  체력 %d · %s" % [d.name, int(d.hp), d.role])
	return "\n".join(lines)
