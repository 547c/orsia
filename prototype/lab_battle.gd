class_name LabBattle
extends BattleTurnManager
# 전투 규칙 바탕. 기본 실행기(Deck/Hand/MonsterState/StatusEffects)를 타고 마나 · 표식 · 갑옷 · 방어/반격 순서 · 유물 · 의도 패턴만 덮어쓴다.
# 상태이상 틱은 끈다(표식은 소비되거나 전투가 끝날 때까지 남는다).

const UniformDeck = preload("res://prototype/lab_deck.gd")
const LabWeapon = preload("res://prototype/lab_weapon.gd")

const MAX_HP := 36
const TURN_MANA := 3
const MARK_CAP := 3
const MARK_BONUS := 3
const BASH_MAX_SPEND := 6
const COUNTER_DAMAGE := 4
const THORN_DAMAGE := 3
const ARC_DAMAGE := 2
const ABSORB_BLOCK := 3
const BANDAGE_HEAL := 2

var spec: Dictionary
var relics: Array[String] = []
var roles: Array[String] = []
var armor: Array[int] = []
var offsets: Array[int] = []
# 마지막 행동(카드 한 장 또는 적 하나의 행동)이 만든 결과 묶음. 화면은 이 자료만 보고 숫자를 띄운다
var events: Array[Dictionary] = []

var counter_charges := 0
var magic_hits := 0
var arc_used := false
var absorb_used := false
var thorn_used := false
var victory_heal := 0

var _arc_pending := false
var _arc_origin := -1
var _absorb_pending := false


# 기반 생성자는 스테이지 편성과 덱 셔플에 전역 난수를 쓴다. 단독형 적(RUINS_BOSS)에 변종을 직접 넘기면
# 편성이 난수 없이 한 스테이지로 끝나고, 빈 덱의 셔플도 난수를 소비하지 않는다. 실제 덱은 시드가 있는
# UniformDeck으로 곧바로 바꾼다 — 그래서 미리보기용 복제본을 만들어도 전역 난수가 움직이지 않는다
func _init(spec_: Dictionary, cards: Array[Card], items: Array[String], seed_value: int) -> void:
	spec = spec_.duplicate(true)
	relics = items.duplicate()
	super("RUINS_BOSS", [{"p1": true}], [] as Array[Card])
	monster_type = "P1"
	deck = UniformDeck.new(cards, seed_value)
	weapon = LabWeapon.new()


func _spawn_stage(_index: int) -> void:
	stage_index = 0
	monsters.clear()
	roles.clear()
	armor.clear()
	offsets.clear()
	var variants: Array = []
	var elites: Array = []
	var enemy_roles: Array = spec.get("enemies", [])
	var enemy_offsets: Array = spec.get("offsets", [])
	for i in range(enemy_roles.size()):
		var role: String = enemy_roles[i]
		var d: Dictionary = LabCatalog.ENEMIES[role]
		var variant := LabCatalog.variant_for(role)
		var monster := MonsterState.new(i, d.type, variant)
		monster.max_hp = int(spec.get("hp_override", {}).get(i, d.hp))
		monster.hp = monster.max_hp
		monster.display_name = d.name
		monsters.append(monster)
		roles.append(role)
		armor.append(int(spec.get("armor_override", {}).get(i, d.armor)))
		offsets.append(int(enemy_offsets[i]) if i < enemy_offsets.size() else 0)
		variants.append(variant)
		elites.append(false)
	stages = [{"variants": variants, "elites": elites}]


func start() -> void:
	_start_turn()


func _start_turn() -> void:
	GameState.set_flag("player_mana", TURN_MANA)
	magic_hits = 0
	arc_used = false
	absorb_used = false
	super()


func _tick_status_rounds() -> void:
	pass


func begin_round_resolution() -> bool:
	if not super():
		return false
	thorn_used = false
	events.clear()
	return true


# 남은 방어(기반이 0으로)와 반격 준비는 적 단계 전체가 끝난 뒤 한 번만 사라진다
func finish_round_resolution() -> void:
	if _round_open and (_resolving or stage_pending or battle_over):
		counter_charges = 0
	super()


func mark_count(index: int) -> int:
	var m := get_monster(index)
	return 0 if m == null else m.status.get_magnitude(StatusEffects.Kind.MARK)


func _set_marks(index: int, count: int) -> void:
	var m := get_monster(index)
	m.status.remove(StatusEffects.Kind.MARK)
	if count > 0:
		m.status.apply(StatusEffects.Kind.MARK, count, 999)


func intent(index: int) -> Array:
	if index < 0 or index >= roles.size():
		return []
	var moves: Array = spec.get("moves_override", {}).get(index, LabCatalog.ENEMIES[roles[index]].moves)
	return (moves[(maxi(0, turn_number - 1) + offsets[index]) % moves.size()] as Array).duplicate()


func intent_text(index: int) -> String:
	return LabCatalog.move_text(intent(index))


func player_hp() -> int:
	return int(GameState.get_flag("player_hp"))


# ── 카드 효과 ───────────────────────────────────────────────────────────────

func _apply_card_effect(card: Card, target_index: int) -> int:
	events.clear()
	last_hit_damage.clear()
	_arc_pending = false
	_arc_origin = -1
	_absorb_pending = false

	if card.effect == Card.EffectType.DEFEND:
		_apply_card_effect_to_target(card, -1) # 원래 DEFEND 실행기: _pending_defense += value
		var counter := LabCatalog.upgrade_of(card) == "counter"
		if counter:
			counter_charges += 1
		events.append({"kind": "guard", "amount": card.value, "block": _pending_defense,
			"counter_added": counter, "counter": counter_charges})
		return 0

	var spent := 0
	if LabCatalog.kind_of(card) == "bash":
		spent = mini(BASH_MAX_SPEND, _pending_defense)
		_pending_defense -= spent
		events.append({"kind": "spend_block", "amount": spent, "block": _pending_defense})

	var base := card.value + spent * 2
	var total := 0
	for index in resolve_target_indices(card, target_index):
		for h in range(LabCatalog.hits_of(card)):
			var target := get_monster(index)
			if target == null or not target.is_alive():
				break # 죽은 대상의 남은 타격은 취소하고 다른 적으로 옮기지 않는다
			total += _direct_hit(card, index, base, h)

	# 직접 타격 묶음이 전부 끝난 뒤에만 후속 효과를 처리한다
	if _arc_pending:
		var arc_target := _arc_target(_arc_origin)
		if arc_target >= 0:
			total += _secondary_hit(arc_target, ARC_DAMAGE, "arc", _arc_origin)
		else:
			events.append({"kind": "arc_skip", "origin": _arc_origin})
	if _absorb_pending:
		_pending_defense += ABSORB_BLOCK
		events.append({"kind": "absorb", "amount": ABSORB_BLOCK, "block": _pending_defense})
	return total


func _direct_hit(card: Card, index: int, base: int, hit_index: int) -> int:
	var m := get_monster(index)
	var magic := LabCatalog.is_magic(card)
	var consumed := 0
	if not magic:
		consumed = mark_count(index)
		if consumed > 0:
			_set_marks(index, 0)
	var direct := maxi(0, base - armor[index])
	var bonus := consumed * MARK_BONUS # 표식 추가 피해는 갑옷을 무시한다
	var actual := m.take_damage(direct + bonus) # 기본 피해와 표식 피해를 한 번에 확정하고 사망 판정
	var mark_added := false
	if magic and actual > 0:
		magic_hits += 1
		if m.is_alive():
			_set_marks(index, mini(MARK_CAP, mark_count(index) + 1))
			mark_added = true
		if magic_hits == 2 and relics.has("arc") and not arc_used:
			arc_used = true
			_arc_pending = true
			_arc_origin = index
	if consumed > 0 and relics.has("absorb") and not absorb_used:
		absorb_used = true
		_absorb_pending = true
	last_hit_damage[index] = int(last_hit_damage.get(index, 0)) + actual
	events.append({"kind": "hit", "index": index, "hit_index": hit_index, "magic": magic,
		"card_kind": LabCatalog.kind_of(card), "damage": actual, "base": direct,
		"armor": armor[index], "consumed": consumed, "detonation": bonus,
		"mark_added": mark_added, "marks": mark_count(index), "hp": m.hp,
		"dead": not m.is_alive()})
	if not m.is_alive():
		monster_defeated.emit(index)
	return actual


# 방전 대상: 원래 대상 외에 살아 있는 적 중 체력이 가장 낮은 적(같으면 앞 슬롯). 없으면 원래 대상이
# 살아 있을 때 그 대상. 그것도 없으면 발동하지 않는다
func _arc_target(origin: int) -> int:
	var best := -1
	for m in alive_monsters():
		if m.index == origin:
			continue
		if best < 0 or m.hp < get_monster(best).hp:
			best = m.index
	if best >= 0:
		return best
	var o := get_monster(origin)
	if o != null and o.is_alive():
		return origin
	return -1


# 후속 피해(방전/반격/가시)는 갑옷을 받고, 표식을 만들거나 소비하지 않으며, 다른 유물을 다시 부르지 않는다
func _secondary_hit(index: int, amount: int, source: String, origin: int = -1) -> int:
	var m := get_monster(index)
	if m == null or not m.is_alive():
		return 0
	var actual := m.take_damage(maxi(0, amount - armor[index]))
	events.append({"kind": source, "index": index, "origin": origin, "raw": amount,
		"armor": armor[index], "damage": actual, "hp": m.hp, "marks": mark_count(index),
		"dead": not m.is_alive()})
	if not m.is_alive():
		monster_defeated.emit(index)
	return actual


# ── 적 단계: 살아 있는 적이 각자 예고한 행동을 한 번씩 ─────────────────────────
# 타격마다: 방어 흡수 → 체력 피해 → 생존 확인 → (방어를 실제로 썼으면) 반격 준비 1회 소비 → 가시.
# 반격으로 공격자가 쓰러지면 그 공격자의 남은 타격과 가시는 생략한다. 패배/승리 즉시 멈춘다
func take_next_monster_action() -> Dictionary:
	events.clear()
	if not _resolving or battle_over or stage_pending:
		return {"acted": false, "index": -1}
	while _enemy_cursor < _enemy_order.size():
		var index: int = _enemy_order[_enemy_cursor]
		_enemy_cursor += 1
		var actor := get_monster(index)
		if actor == null or not actor.is_alive():
			continue
		var hits := intent(index)
		if hits.is_empty():
			events.append({"kind": "prepare", "index": index})
		for h in range(hits.size()):
			if not actor.is_alive():
				events.append({"kind": "hit_cancelled", "index": index, "remaining": hits.size() - h})
				break
			var raw := int(hits[h])
			var absorbed := mini(_pending_defense, raw)
			_pending_defense -= absorbed
			var taken := 0
			if raw - absorbed > 0:
				taken = party[0].take_damage(raw - absorbed)
			events.append({"kind": "enemy_hit", "index": index, "hit_index": h, "raw": raw,
				"absorbed": absorbed, "damage": taken, "hp": player_hp(), "block": _pending_defense})
			if _is_party_wiped():
				_finish_battle(true)
				return {"acted": true, "index": index}
			if absorbed > 0:
				if counter_charges > 0:
					counter_charges -= 1
					_secondary_hit(index, COUNTER_DAMAGE, "counter")
				if relics.has("thorn") and not thorn_used:
					thorn_used = true
					if actor.is_alive():
						_secondary_hit(index, THORN_DAMAGE, "thorn")
					else:
						events.append({"kind": "thorn_skip", "index": index})
			if all_monsters_defeated():
				_on_stage_wiped()
				return {"acted": true, "index": index}
		return {"acted": true, "index": index}
	return {"acted": false, "index": -1}


func _finish_battle(player_lost: bool) -> void:
	if battle_over:
		return
	if not player_lost and relics.has("bandage"):
		victory_heal = _bandage_heal(BANDAGE_HEAL)
	super(player_lost)


func _bandage_heal(amount: int) -> int:
	var before := player_hp()
	GameState.heal_player(amount)
	return player_hp() - before


# ── 단일 카드 미리보기 ─────────────────────────────────────────────────────
# 같은 규칙 코드(_apply_card_effect)를 현재 상태를 복사한 일회용 복제본에 돌린다. 화면용 공식을 따로
# 두지 않는다. 복제본은 GameState·손패·덱·실제 몬스터를 건드리지 않는다 (tests/p1_rules_test 참고)
func preview(card: Card, target_index: int) -> Dictionary:
	var clone := LabBattle.new(spec, [] as Array[Card], relics, 0)
	clone.turn_number = turn_number
	clone._pending_defense = _pending_defense
	clone.counter_charges = counter_charges
	clone.magic_hits = magic_hits
	clone.arc_used = arc_used
	clone.absorb_used = absorb_used
	clone.thorn_used = thorn_used
	for i in range(monsters.size()):
		clone.monsters[i].max_hp = monsters[i].max_hp
		clone.monsters[i].hp = monsters[i].hp
		clone.armor[i] = armor[i]
		clone._set_marks(i, mark_count(i))
	clone._apply_card_effect(card, target_index)
	var result := {"events": clone.events.duplicate(true), "block": clone._pending_defense,
		"counter": clone.counter_charges, "monsters": []}
	for i in range(monsters.size()):
		result.monsters.append({"hp_before": monsters[i].hp, "hp": clone.monsters[i].hp,
			"marks_before": mark_count(i), "marks": clone.mark_count(i),
			"dead": monsters[i].is_alive() and not clone.monsters[i].is_alive()})
	return result
