class_name P2Battle
extends LabBattle
# 카드 전투 규칙. 기본 실행기(Deck/Hand/MonsterState/적 단계 가드)를 그대로 쓰고, 카드 효과와 적 행동은 이 파일 한 곳에서 처리한다.
#
# 공격 한 타격의 계산 순서:
#   기본 피해(+방패 강타 소비×2, +첫 타격 보정: 무력/지혜/무기 등급/막고 치기) → ×치명(카드당 판정 1번) → 내림 →
#   갑옷(관통 제외) → +표식×3(+표식 검 2, 치명 미적용) → 남은 '한 장 방패' → 체력.
# 방패병의 방패 8은 카드 한 장 전체의 합계를 막고 그 카드가 끝나면 사라진다(한 번뿐). 반격·가시 같은 추가 피해는
# 방패를 무시하고 소비하지 않는다. 표식은 피해가 모두 막혀도 소비되고, '피해를 주면' 발동하는 효과는 실제 체력 피해가 있어야 한다.
# 기수: 살아 있는 동안 다른 적의 공격 타격당 +2 (적 행동마다 다시 계산, 기수가 죽으면 예고도 즉시 준다).
# 주술: 다음 플레이어 턴 방어 카드 −2 (그 턴이 끝나면 풀림, 중복은 갱신). 독: 다음 두 번의 턴 종료에 방어 무시 2,
# 적 행동보다 먼저. 독으로 쓰러지면 그 적 단계는 멈춘다. 마지막 적을 쓰러뜨리면 남은 독은 틱하지 않는다.
# 장치: 파괴 가능. '본체'가 있는 전투는 본체만 쓰러뜨리면 승리. 적 단계의 행동 명단은 단계 시작 때 정해지고,
# 그 단계에 다시 세운 장치는 다음 단계부터 움직인다. 본체가 죽으면 남은 장치 행동은 취소된다.
# 추가 피해는 치명·특성·표식을 다시 부르지 않는다(재귀 없음). 미리보기는 복제본에 돌리며 난수·일회성 보정을 쓰지 않는다.

const SNAPSHOT_VERSION := 5
const HAND_MAX := 7
const SUPPRESS_AMOUNT := 2
const LENS_DAMAGE := 3
const BLADE_BLOCK := 3
const CLEAVE_DAMAGE := 2
const SEAL_PER_MANA := 2
const SEAL_MAX := 4
const TRAIT_CHAIN_DAMAGE := 4
const TRAIT_BLOCK_STRIKE_NEED := 6
const TRAIT_BLOCK_STRIKE_BONUS := 4
const TRAIT_MANA_CYCLE_NEED := 3
const TRAIT_BURN_BLOCK := 3
# 소환사: 두 마리씩 최대 두 번(총 4), 살아 있는 소환수 최대 2
const SUMMON_MAX_CASTS := 2
const SUMMON_COUNT := 2
const SPAWN_LIVING_MAX := 2
const SPAWN_STATES := ["", "inactive", "active", "consumed"]

var class_id := ""
var max_mana := 3
var stats := {}
var traits: Array[String] = []
var source := "expedition"
var opening_block := 0
var opening_applied := false
var mulligan_allowed := false
var mulligan_used := false
var encounter_id := ""
var seed_used := 0
# 치명타: normal = 확률 판정 / off = 끔(검사·기준 비교용) / force = 항상(검사용)
var crit_mode := "normal"
var prep_enabled := true
var hunter_prep := 0
var crit_rng := RandomNumberGenerator.new()
# 턴 한정
var cards_played_this_turn := 0
var paid_cards_turn := 0
var phys_hits_turn := 0
var blade_used := false
var lens_used := false
var attacks_played_turn := 0
var carry_cap_turn := 0
var pursuit_used := false
var reflux_used := false
var capacitor_used := false
var echo_string_used := false
var furnace_used := false
var glove_used := false
var trait_used := {}
# 특성 상태: 출발 덱 장수(얇은 덱 · 무기고) · 이번 턴 연쇄 반응 수 · 이번 턴 묻힌 원소(비트) · 이번 적 차례 받아치기 합 ·
# 이번 적 차례 공격 수와 받은 피해(무결) · 이번 턴 최대를 넘는 마나 · 질긴 목숨 씀 · 필살 여운 할인 [카드, 원래 비용]
var deck_size0 := 0
var chain_n := 0
var elem_mask := 0
var riposte_sum := 0
var phase_hits := 0
var phase_taken := 0
var extra_mana_turn := 0
var flawless_next := false
var last_stand_spent := false
var ult_turn := false
var ult_disc: Array = []
var _chaining := false
# 라운드 한정
var seal_used := false
var absorbed_phase := 0
# 전투 한정 (일회성 보정: 확정된 카드에서만 소비)
var satchel_used := false
var cards_played_battle := 0
var block_strike_ready := false
# 반격 기회: 얻은 순서대로 기본 피해를 쌓는다 (막아 낸 타격 하나마다 앞에서부터 하나)
var counter_queue: Array[int] = []
# 조준 사격 충전: 손에 남은 채 턴 경계를 넘긴 사본 uid
var aim_charged := {}
var suppression: Array[int] = []
var shields: Array[int] = []
var instance_ids: Array[String] = []
var rebuilds: Array[int] = []
var families: Array[String] = []
# 소환수 자리: ""(소환 자리가 아님) / inactive(아직 비어 있음) / active(소환됨 — 체력 0이면 처치됨) / consumed(폭발 뒤 소멸)
var spawn_state: Array[String] = []
var spawn_birth: Array[int] = []
var spawn_due: Array[int] = []
# 소환사 전투의 적 단계 번호(시작한 적 단계 수), 쓴 소환 횟수, 새 개체 번호
var summon_phase := 0
var summon_casts := 0
var summon_serial := 0
var boss_tally := 0
var boss_locked := {}
# 거완 힘 풀기(적마다): 강타 직전 내 차례에 센 카드 직접 타격 수, 턴 종료 때 굳힌 강타 값(-1 = 없음). boss_tally와 따로 쓴다
var unwind_count: Array[int] = []
var unwind_lock: Array[int] = []
# 맥 귀족(전투에 하나): 공명 단계, 턴 종료 때 굳힌 물창, 실제 행동 수, 봉인 시전 수·예약, 봉인된 손패 UID와 그 차례.
# 유물 '비축 인장'(reserve_seal·seal_used)과 다른 것이다
var noble_res := 0
var noble_lock := -1
var noble_acts := 0
var noble_casts := 0
var noble_pending := false
var noble_seal_uid := ""
var noble_seal_turn := -1
var _noble_released := ""
var _card_res_mult := 1.0
var _card_noble_hit := false
# 플레이어 상태 (주술/독)
var hex_active := false
var hex_next := false
var poison_amount := 0
var poison_ticks := 0
# 선택 위험 사건: 이 조우의 적 직접 공격 타격당 +2
var attack_bonus := 0
var hit_mult := 1.0
var hp_mult := 1.0
# 난이도별 등급 체력 배율(normal · elite · boss, 나머지는 normal)
var rank_hp := {}
var judge_mult := 1.0
var approach_mult := 1.0
var pattern_level := 0
var mods: Array = []
var affixes: Array = []
var heal_cap := COMBO_HEAL_CAP
# 전투 중 물약: 자기 턴에 턴당 하나 (이 턴 번호에 이미 썼으면 막는다)
var potion_turn := 0
var chain_met := false
var counter_kill_met := false

var _queue := {}
var _pending_card_draw := 0
var _draw_sources: Array[String] = []
var _x_value := 0
var _paid_now := 0
var _fuel_uid := ""
var _card_crit := false
var _card_forced := false
var _card_positive := false
var _card_kill := false
var _card_first_bonus := 0
var _card_shield_touched := {}
var _anchors: Array = []
var anchor_uids: Array = []
# 미리보기 복제본: 실제 GameState 대신 이 값으로 마나·체력을 다루고, 치명타는 정해진 갈래를 쓴다
var _is_clone := false
var _clone_mana := 0
var _clone_hp := 0
var _crit_override := -1
# 손맛 시험판(--feel-proto). 화면이 입력 결과를 넘긴다. 둘 다 꺼져 있으면 기존 규칙 그대로
# parry_mode: 적 행동의 타격을 하나씩 resolve_parry_hit(판정)으로 처리. strike_grade: 다음 공격 카드 한 장의 긋기 결과
# (perfect 치명 · hit 기본 · part 0.75 · graze 0.5), strike_power: 완벽일 때 치명 배율 대신 쓰는 문양 배율
var parry_mode := false
var strike_grade := ""
var strike_power := 1.0
var _parry_act := {}
const COMBO_HEAL_CAP := 5
# 리듬 유물: 공명 추(완벽 3번마다 다음 턴 1장 더, 최대 2) · 메아리 칼끝(완벽마다 공격자에게 2, 단계마다 3번) ·
# 강철 박자(막음 이상마다 방어 1, 단계마다 4) · 리듬 심장(연속 회복 한도 +3)
const PENDULUM_PER := 3
const PENDULUM_MAX := 2
const ECHO_EDGE_DAMAGE := 2
const ECHO_EDGE_MAX := 3
const IRON_TEMPO_MAX := 4
const RHYTHM_HEART_EXTRA := 3
var combo_heals := 0
# 연격(콤보술사 카드·직업 효과): 같은 적을 이어 때린 타격 수와 그 적, 이번 턴이 끝나도 유지할지
var combo := 0
var combo_target := -1
var combo_keep := false
var perfect_phase := 0
var spur := 0
var ember_jar_n := 0
var fork_ready := false
# 유물 칸 순서 그대로(잠든 것 포함)와 단계. relics에는 깨어 있는 것만 남긴다
var relic_order: Array[String] = []
var relic_lv := {}
var strike_reverse := false
var strike_thorns := 0
var quiver := 0
var quiver_next := 0
var drum_echo_n := 0
var echo_edge_n := 0
var iron_tempo_n := 0
var pendulum_drawn := 0
var warden_parry_n := 0
# 상태이상(적마다 한 칸): burn 화상 · poison 독 · chill 냉기 · frozen 얼어붙음 · bleed 출혈 · vuln 취약(턴) · weak 약화(턴) ·
# doom 저주 · doom_t 저주 남은 턴 · trap 덫 · link 고통 연결 상대(번호+1) · air 공중(이번 턴)
var est: Array = []
var ult := 0
var ult_last := ""
var rage := 0
var rage_mult := 1.0
var coat := 0
var smoke := 0
var coat_amt := 2
var wall := 0
var parry_bonus := 0
var forced_next := false
# 화면이 넘기는 입력 결과(다음 카드 한 장): 폭풍 연사 클릭 수 · 집중 사격/기공파 차징 배율
var mash_hits := 0
var charge_power := 0.0
var _in_ult := false


func _init(spec_: Dictionary, cards: Array[Card], items: Array[String], seed_value: int, opts: Dictionary = {}) -> void:
	class_id = String(opts.get("class_id", "warden"))
	stats = (opts.get("stats", {}) as Dictionary).duplicate()
	relic_lv = (opts.get("relic_lv", {}) as Dictionary).duplicate()
	traits.assign(opts.get("traits", []))
	deck_size0 = cards.size()
	last_stand_spent = (opts.get("trait_spent", []) as Array).has("last_stand")
	source = String(opts.get("source", "expedition"))
	max_mana = int(opts.get("max_mana", P2Catalog.run_max_mana(class_id, items)))
	opening_block = int(opts.get("opening_block", 0))
	mulligan_allowed = bool(opts.get("mulligan", false))
	encounter_id = String(opts.get("encounter_id", ""))
	crit_mode = String(opts.get("crit_mode", "normal"))
	prep_enabled = bool(opts.get("prep_enabled", true))
	attack_bonus = int(opts.get("attack_bonus", spec_.get("attack_bonus", 0)))
	hit_mult = float(opts.get("hit_mult", 1.0))
	hp_mult = float(opts.get("hp_mult", 1.0))
	rank_hp = (opts.get("rank_hp", {}) as Dictionary).duplicate()
	ult = clampi(int(opts.get("ult", 0)), 0, ult_cap())
	judge_mult = float(opts.get("judge_mult", 1.0))
	approach_mult = float(opts.get("approach_mult", 1.0))
	pattern_level = int(opts.get("pattern_level", 0))
	mods = (opts.get("mods", []) as Array).duplicate()
	affixes = (opts.get("affixes", []) as Array).duplicate()
	heal_cap = int(opts.get("heal_cap", COMBO_HEAL_CAP))
	_anchors = (opts.get("anchors", []) as Array).duplicate()
	seed_used = seed_value
	super(spec_, cards, items, seed_value)
	relic_order.assign(items)
	for id in relic_lv:
		if int(relic_lv[id]) <= 0:
			relics.erase(String(id))
	deck = P4Deck.new(cards, seed_value)
	crit_rng.seed = abs(seed_value * 7919 + 104729)
	monster_type = "P5"


func _spawn_stage(_index: int) -> void:
	stage_index = 0
	est.clear()
	monsters.clear()
	roles.clear()
	armor.clear()
	offsets.clear()
	suppression.clear()
	shields.clear()
	instance_ids.clear()
	rebuilds.clear()
	families.clear()
	spawn_state.clear()
	spawn_birth.clear()
	spawn_due.clear()
	unwind_count.clear()
	unwind_lock.clear()
	var variants: Array = []
	var elites: Array = []
	var enemy_roles: Array = spec.get("enemies", [])
	var enemy_offsets: Array = spec.get("offsets", [])
	# 야외 조우: 원본 몬스터 종류의 모습(변종 번호)을 그대로 쓰고, 처치 종족도 그 종류로 센다
	var visual_type := String(spec.get("visual_type", ""))
	var visual: Array = spec.get("visual", [])
	var names := {}
	for role in enemy_roles:
		names[role] = int(names.get(role, 0)) + 1
	var seen := {}
	for i in range(enemy_roles.size()):
		var role: String = enemy_roles[i]
		var d: Dictionary = P2Catalog.ENEMIES[role]
		var rank := String(d.get("rank", "normal"))
		var own_look := visual_type == "" or rank in ["device", "mimic"] or (rank == "boss" and visual_type != "RUINS_BOSS")
		var vtype := String(d.type) if own_look else visual_type
		var variant := P2Catalog.variant_for(role) if own_look else P2Catalog.variant_for(role, visual_type, int(visual[i]) if i < visual.size() else -1)
		var monster := MonsterState.new(i, vtype, variant)
		var rmul := float(rank_hp.get(rank if rank in ["elite", "boss"] else "normal", 1.0))
		monster.max_hp = maxi(1, roundi(int(d.hp) * hp_mult * rmul * (P2Catalog.AFFIX_TOUGH if affix(i) == "tough" else 1.0)))
		monster.hp = monster.max_hp
		seen[role] = int(seen.get(role, 0)) + 1
		var nm := String(d.name)
		monster.display_name = nm if int(names[role]) == 1 else "%s %d" % [nm, int(seen[role])]
		monsters.append(monster)
		roles.append(role)
		armor.append(int(d.armor))
		offsets.append(int(enemy_offsets[i]) if i < enemy_offsets.size() else 0)
		suppression.append(0)
		shields.append(int(d.get("shield", 0)))
		instance_ids.append("%s#%d" % [role, i])
		rebuilds.append(0)
		families.append(vtype if rank in ["normal", "elite"] and vtype in ["ORC", "SKELETON", "MUMMY"] else "")
		var slot := bool(d.get("summon_slot", false))
		spawn_state.append("inactive" if slot else "")
		spawn_birth.append(-1)
		spawn_due.append(-1)
		unwind_count.append(0)
		unwind_lock.append(-1)
		est.append({})
		if slot:
			monster.hp = 0
		variants.append(variant)
		elites.append(false)
	stages = [{"variants": variants, "elites": elites}]


# 처치한 적의 종족 수. 보스·장치·미믹은 세지 않는다
func casualties() -> Dictionary:
	var out := {}
	for i in range(monsters.size()):
		if i < families.size() and families[i] != "" and not monsters[i].is_alive():
			out[families[i]] = int(out.get(families[i], 0)) + 1
	return out


func _bandage_heal(amount: int) -> int:
	return _heal_player(amount * rl("bandage"), "bandage")


# 유물 단계: 없거나 잠들면 0, 아니면 1~3 (석판이 올린 만큼)
func vuln_mult() -> float:
	return P2Catalog.VULN_MULT + (0.5 * rl("cruel_eye") if relics.has("cruel_eye") else 0.0)


func doom_mult() -> int:
	return P2Catalog.DOOM_MULT + rl("doom_skull")


func rl(id: String) -> int:
	if not relics.has(id):
		return 0
	return maxi(1, int(relic_lv.get(id, 1)))


func mark_cap() -> int:
	return P2Catalog.RUNE_MARK_CAP if class_id == "rune_caster" else MARK_CAP


# 스스로 깎는 체력(가시 삼키기): 쓰러지지는 않는다(최소 1)
func _lose_hp(n: int, src: String) -> void:
	var before := player_hp()
	var after := maxi(1, before - n)
	if _is_clone:
		_clone_hp = after
	else:
		GameState.set_flag("player_hp", after)
	events.append({"kind": "self_hurt", "source": src, "amount": before - after, "hp": after})
	if relics.has("blood_chalice") and before > after:
		var cb := P2Catalog.CHALICE_BLOCK * rl("blood_chalice")
		_pending_defense += cb
		events.append({"kind": "chalice", "amount": cb, "block": _pending_defense})


func _glass(v: int) -> int:
	return ceili(v * P2Catalog.GLASS_MULT) if v > 0 and relics.has("glass_cannon") else v


# opts.anchors: 직업 첫 원정 첫 전투의 첫 손패에 넣을 두 종류 (공개된 시작 규칙, 비밀 손패 조작이 아님)
func start() -> void:
	if not _is_clone:
		GameState.set_flag("player_max_mana", max_mana)
	_start_turn()
	if not _anchors.is_empty():
		_apply_anchors(_anchors)
	events.clear()
	if not opening_applied:
		opening_applied = true
		if opening_block > 0:
			_pending_defense += opening_block
			events.append({"kind": "opening_block", "amount": opening_block, "block": _pending_defense})
		if traits.has("collector") and not relics.is_empty():
			var cb := P2Catalog.COLLECTOR_BLOCK * relics.size()
			_pending_defense += cb
			events.append({"kind": "collector", "amount": cb, "block": _pending_defense})
	_turn_trait_events(false)
	for i in range(monsters.size()):
		if shields[i] > 0:
			events.append({"kind": "shield_up", "index": i, "amount": shields[i]})


# 섞인 순서(손패 → 뽑을 더미 위부터)에서 핵심 카드 사본을 앞에 두고 나머지는 같은 순서로 채운다. 중복·분실 없음
func _apply_anchors(kinds: Array) -> void:
	var seq: Array[Card] = []
	seq.append_array(hand.cards)
	for i in range(deck.draw_pile.size() - 1, -1, -1):
		seq.append(deck.draw_pile[i])
	var picked: Array[Card] = []
	for k in kinds:
		for c in seq:
			if P2Catalog.kind_of(c) == String(k) and not picked.has(c):
				picked.append(c)
				break
	var size := hand.cards.size()
	var new_hand: Array[Card] = picked.duplicate()
	for c in seq:
		if new_hand.size() >= size:
			break
		if not new_hand.has(c):
			new_hand.append(c)
	var rest: Array[Card] = []
	for c in seq:
		if not new_hand.has(c):
			rest.append(c)
	rest.reverse()
	hand.cards = new_hand
	deck.draw_pile = rest
	anchor_uids = _uids(picked)
	events.append({"kind": "anchors", "uids": anchor_uids.duplicate()})


# 턴 시작: 턴 한정 기록 초기화 → 마나를 최대치로 → 보존하지 않는 손패는 버리고, 손에 남은 조준 사격은 충전 →
# 손패가 5장이 될 때까지 뽑기 (보존 카드도 5장에 포함, 새로 뽑은 카드는 이번 경계에서 충전되지 않는다)
func _start_turn() -> void:
	cards_played_this_turn = 0
	paid_cards_turn = 0
	phys_hits_turn = 0
	blade_used = false
	lens_used = false
	attacks_played_turn = 0
	carry_cap_turn = 0
	pursuit_used = false
	reflux_used = false
	capacitor_used = false
	echo_string_used = false
	furnace_used = false
	glove_used = false
	trait_used = {}
	chain_n = 0
	elem_mask = 0
	for k in range(ult_disc.size() - 1, -1, -1):
		(ult_disc[k][0] as Card).mana_cost = int(ult_disc[k][1])
	ult_disc.clear()
	ult_turn = false
	boss_tally = 0
	unwind_count.fill(0)
	magic_hits = 0
	arc_used = false
	absorb_used = false
	_set_mana(max_mana + extra_mana_turn)
	_round_open = true
	turn_number += 1
	weapon.reset_turn()
	_free_next_card = false
	_pending_retaliator = -1
	hex_active = hex_next
	hex_next = false
	noble_res = 0
	var kept: Array[Card] = []
	var gone: Array[Card] = []
	for c in hand.cards:
		if P2Catalog.retains(c) or (noble_seal_uid != "" and P2Catalog.uid_of(c) == noble_seal_uid):
			kept.append(c)
		else:
			gone.append(c)
	if not gone.is_empty():
		deck.discard(gone)
	for c in kept:
		if P2Catalog.retains(c):
			aim_charged[P2Catalog.uid_of(c)] = true
	if noble_seal_uid != "":
		_noble_released = noble_seal_uid
		noble_seal_uid = ""
	hand.cards = kept
	# 연격: 턴이 바뀌면 0(흐름 유지면 그대로). 콤보술사는 지난 적 차례 완벽 2번마다 +1(최대 3), 마지막으로 친 적 기준
	if not combo_keep:
		combo = combo / 2 if traits.has("flow_keep") else 0
	combo_keep = false
	if class_id == "combo":
		combo = mini(P2Catalog.COMBO_MAX, combo + mini(P2Catalog.COMBO_CARRY_MAX, perfect_phase / 2))
		if relics.has("combo_glove"):
			combo = mini(P2Catalog.COMBO_MAX, combo + rl("combo_glove"))
	ember_jar_n = 0
	rage = 0
	rage_mult = 1.0
	wall = 0
	parry_bonus = 0
	smoke = 0
	fork_ready = relics.has("tuning_fork") and perfect_phase >= P2Catalog.FORK_NEED
	quiver_next = quiver
	quiver = 0
	if combo_target >= 0 and (combo_target >= monsters.size() or not get_monster(combo_target).is_alive()):
		combo_target = -1
	# 공명 추: 지난 적 단계의 완벽 패링 3번마다 1장 더 (최대 2장, 손패 최대까지)
	pendulum_drawn = mini(PENDULUM_MAX * rl("beat_pendulum"), (perfect_phase / PENDULUM_PER) * rl("beat_pendulum")) if relics.has("beat_pendulum") else 0
	var target := mini(HAND_MAX, HAND_SIZE + pendulum_drawn + (1 if thin_deck_on() else 0) + (1 if flawless_next else 0))
	flawless_next = false
	while hand.cards.size() < target:
		var c := deck.draw_one()
		if c == null:
			break
		hand.cards.append(c)
	turn_started.emit(turn_number)


# ── 마나·체력 (복제본은 GameState를 건드리지 않는다) ─────────────────────────────

func mana_now() -> int:
	return _clone_mana if _is_clone else int(GameState.get_flag("player_mana"))


func _set_mana(v: int) -> void:
	v = clampi(v, 0, max_mana + extra_mana_turn)
	if _is_clone:
		_clone_mana = v
	else:
		GameState.set_flag("player_mana", v)


func _gain_mana(n: int, src: String) -> int:
	var before := mana_now()
	_set_mana(before + n)
	var got := mana_now() - before
	events.append({"kind": "mana_refund", "source": src, "amount": got, "requested": n, "mana": mana_now()})
	return got


func player_hp() -> int:
	return _clone_hp if _is_clone else int(GameState.get_flag("player_hp"))


# 연속 회복: 화면이 연속 5마다 부른다. 체력 1, 한 전투 최대 COMBO_HEAL_CAP. 가득 차 있으면 세지 않는다.
# 사건 목록에는 넣지 않는다(행동 도중에 불려 다른 사건과 섞이지 않게, 화면이 바로 반영)
func combo_heal() -> int:
	if _is_clone or battle_over or combo_heals >= combo_heal_cap():
		return 0
	var before := player_hp()
	if before <= 0 or before >= int(GameState.get_flag("player_max_hp")):
		return 0
	GameState.set_flag("player_hp", before + 1)
	combo_heals += 1
	return 1


func combo_heal_cap() -> int:
	return heal_cap + RHYTHM_HEART_EXTRA * rl("rhythm_heart")


func _heal_player(n: int, src: String) -> int:
	var mx := int(GameState.get_flag("player_max_hp"))
	var before := player_hp()
	var after := mini(mx, before + n)
	if _is_clone:
		_clone_hp = after
	else:
		GameState.set_flag("player_hp", after)
	events.append({"kind": "heal", "source": src, "amount": after - before, "hp": after})
	return after - before


# ── 치명타 ────────────────────────────────────────────────────────────────

func stat(id: String) -> int:
	return int(stats.get(id, 0))


# 이 카드가 이 대상에게 쓰일 때의 치명 확률. 미리보기와 실제가 같은 함수를 쓴다
func crit_chance_for(_card: Card, _target: int) -> int:
	return crit_chance()


func crit_chance() -> int:
	return clampi(P2Catalog.CRIT_BASE_CHANCE + stat("crit") + P2Catalog.OBSIDIAN_CHANCE * rl("obsidian_lens"), 0, P2Catalog.CRIT_CHANCE_CAP)


func crit_mult_for(_target: int) -> float:
	var m := P2Catalog.CRIT_BASE_MULT + stat("cdmg") / 100.0 + (P2Catalog.OBSIDIAN_MULT if relics.has("obsidian_lens") else 0.0)
	return minf(m + _hunter_crit(), P2Catalog.CRIT_MULT_CAP)


# 긋기 완벽은 치명 배율 대신 문양 배율
func _crit_mult_now(target: int) -> float:
	if strike_grade in ["perfect", "hit"]:
		return strike_power + stat("cdmg") / 100.0 + (P2Catalog.BRUSH_POWER * rl("steady_brush") if strike_grade == "perfect" else 0.0) + _hunter_crit()
	return crit_mult_for(target)


func _hunter_crit() -> float:
	return P2Catalog.HUNTER_CRIT_BONUS if class_id == "hunter" else 0.0


func crit_mult() -> float:
	return crit_mult_for(-1)


func hunter_prepared() -> bool:
	return class_id == "hunter" and prep_enabled and hunter_prep >= P2Catalog.HUNTER_PREP_NEEDED


# 주 대상: 지정 카드는 그 대상, 전체 카드는 살아 있는 첫 적 (안정된 순서)
func _primary_target(card: Card, target: int) -> int:
	if P2Catalog.is_targeted(card):
		return target if target >= 0 and target < monsters.size() and get_monster(target).is_alive() else -1
	for m in alive_monsters():
		return m.index
	return -1


# 이 공격 카드가 치명타일 수 있는지와 그 확률 (미리보기·화면용). 확정이면 100
func crit_outlook(card: Card, target := -1) -> Dictionary:
	if P2Catalog.is_attack(card) and forced_next:
		return {"chance": 100, "forced": true}
	if not P2Catalog.is_attack(card) or crit_mode == "off":
		return {"chance": 0, "forced": false}
	if hunter_prepared() or crit_mode == "force":
		return {"chance": 100, "forced": true}
	return {"chance": crit_chance_for(card, target), "forced": false}


# 유효한 공격 카드를 확정할 때만 한 번 판정한다 (취소·무효는 난수를 쓰지 않는다)
func _decide_crit(card: Card, target: int) -> void:
	_card_crit = false
	_card_forced = false
	if not P2Catalog.is_attack(card):
		return
	if P2Catalog.kind_of(card) == "weak_point" or forced_next:
		_card_crit = true
		_card_forced = true
		return
	if _crit_override >= 0:
		_card_crit = _crit_override == 1
		_card_forced = _card_crit and (hunter_prepared() or crit_mode == "force")
		return
	if crit_mode == "off":
		return
	if hunter_prepared() or crit_mode == "force":
		_card_crit = true
		_card_forced = true
		return
	# 긋기는 완벽이면 치명. '맞힘'은 능력치 치명 확률만큼 치명(긋기 배율), 기본 10%는 긋기에 쓰지 않는다
	if strike_grade != "":
		_card_crit = strike_grade == "perfect" or (strike_grade == "hit" and stat("crit") > 0 and crit_rng.randi_range(1, 100) <= stat("crit"))
		return
	var chance := crit_chance_for(card, target)
	if chance <= 0:
		return
	_card_crit = crit_rng.randi_range(1, 100) <= chance


# ── 의도 (보스 강타 창·억제·기수 지원·선택 위험 포함) ─────────────────────────────

func _moves(index: int) -> Array:
	return spec.get("moves_override", {}).get(index, P2Catalog.ENEMIES[roles[index]].moves)


func cycle_index(index: int) -> int:
	var moves := _moves(index)
	return (maxi(0, turn_number - 1) + offsets[index]) % moves.size()


func charge_info(index: int) -> Dictionary:
	if index < 0 or index >= roles.size():
		return {}
	return P2Catalog.ENEMIES[roles[index]].get("charge", {})


func charge_window_open(index: int) -> bool:
	var c := charge_info(index)
	return not c.is_empty() and cycle_index(index) == int(c.round) and not _resolving and not battle_over


func unwind_info(index: int) -> Dictionary:
	if index < 0 or index >= roles.size():
		return {}
	return P2Catalog.ENEMIES[roles[index]].get("unwind", {})


func unwind_full(index: int) -> int:
	var u := unwind_info(index)
	return int((_moves(index)[int(u.strike)] as Array)[0]) if not u.is_empty() else 0


func noble_index() -> int:
	for i in range(roles.size()):
		if P2Catalog.ENEMIES[roles[i]].has("noble"):
			return i
	return -1


func noble_info() -> Dictionary:
	var i := noble_index()
	return P2Catalog.ENEMIES[roles[i]].noble if i >= 0 else {}


# 다가올 귀족 행동이 봉인을 거는 차례인지 (예고용)
func noble_seal_due() -> bool:
	var n := noble_info()
	return not n.is_empty() and noble_casts < 2 and (n.seal_acts as Array).has(noble_acts + (0 if _resolving else 1))


func is_noble_sealed(card: Card) -> bool:
	return noble_seal_uid != "" and card != null and P2Catalog.uid_of(card) == noble_seal_uid


# 힘 풀기 창: 강타 준비 뒤의 내 차례(이번 적 단계에 강타할 차례) 동안만 열린다
func unwind_window_open(index: int) -> bool:
	var u := unwind_info(index)
	return not u.is_empty() and cycle_index(index) == int(u.strike) and not _resolving and not battle_over


# 이번 턴 이 적이 하는 특수 행동 (주술/독/재가동/대기). 공격·준비면 빈 사전
func intent_action(index: int) -> Dictionary:
	if index < 0 or index >= roles.size():
		return {}
	if is_summoner(index):
		return {"act": "summon", "count": SUMMON_COUNT} if _summon_due(upcoming_phase()) else {}
	if is_spawn_slot(index):
		return {}
	var mv = _moves(index)[cycle_index(index)]
	return (mv as Dictionary).duplicate() if mv is Dictionary else {}


func intent(index: int) -> Array:
	if index < 0 or index >= roles.size():
		return []
	if is_summoner(index):
		var p := upcoming_phase()
		if _summon_due(p):
			return []
		# 2·5 → 5, 3·6 → 10, 7부터 5·10 번갈아 (7 → 5, 8 → 10 …)
		if p <= 6:
			return [10] if p % 3 == 0 else [5]
		return [10] if p % 2 == 0 else [5]
	if is_spawn_slot(index):
		var m := get_monster(index)
		return [6] if m != null and m.is_alive() and spawn_state[index] == "active" and spawn_due[index] == upcoming_phase() else []
	var mv = _moves(index)[cycle_index(index)]
	var hits: Array = (mv as Array).duplicate() if mv is Array else []
	var c := charge_info(index)
	if not c.is_empty() and cycle_index(index) == int(c.round):
		if boss_locked.has(index):
			return [int(boss_locked[index])]
		return [int(c.weak) if boss_tally >= int(c.threshold) else int(c.full)]
	var u := unwind_info(index)
	if not u.is_empty() and cycle_index(index) == int(u.strike):
		if unwind_lock[index] >= 0:
			return [unwind_lock[index]]
		return [int(u.weak) if unwind_count[index] >= int(u.need) else unwind_full(index)]
	var nb: Dictionary = P2Catalog.ENEMIES[roles[index]].get("noble", {})
	if not nb.is_empty():
		return [noble_lock] if noble_lock >= 0 else [int(nb.lance[noble_res])]
	return hits


# 살아 있는 다른 기수의 지원 (타격당)
func aura_for(index: int) -> int:
	var total := 0
	for m in alive_monsters():
		if m.index != index:
			total += int(P2Catalog.ENEMIES[roles[m.index]].get("aura", 0))
	return total


# 실제로 들어올 타격: 기본 → 선택 위험 +2 → 기수 지원 → 억제 (0 아래로는 안 내려감)
func effective_intent(index: int) -> Array:
	var hits := intent(index)
	if not _is_damaging(hits):
		return hits
	var add := attack_bonus + aura_for(index) + affix_add(index)
	var supp: int = suppression[index] if index < suppression.size() else 0
	var wk := P2Catalog.WEAK_MULT if st(index, "weak") > 0 else 1.0
	return hits.map(func(h): return _glass(maxi(0, floori((scaled(int(h)) + add - supp) * wk))))


func affix(index: int) -> String:
	return String(affixes[index]) if index >= 0 and index < affixes.size() else ""


# 사나운 적: 타격마다 +1
func affix_add(index: int) -> int:
	return 1 if affix(index) == "fierce" else 0


# 구간 배율을 곱한 기본 타격(0은 0)
func scaled(h: int) -> int:
	return roundi(h * hit_mult) if h > 0 else h


static func _is_damaging(hits: Array) -> bool:
	for h in hits:
		if int(h) > 0:
			return true
	return false


func is_summoner(index: int) -> bool:
	return index >= 0 and index < roles.size() and bool(P2Catalog.ENEMIES[roles[index]].get("summoner", false))


func is_spawn_slot(index: int) -> bool:
	return index >= 0 and index < spawn_state.size() and spawn_state[index] != ""


func has_summoner() -> bool:
	for i in range(roles.size()):
		if is_summoner(i):
			return true
	return false


# 다가올(또는 지금 진행 중인) 적 단계 번호. 내 차례에는 다음 단계, 적 단계 중에는 그 단계
func upcoming_phase() -> int:
	return summon_phase + (0 if _resolving else 1)


# 소환 차례: 적 단계 1·4, 소환 두 번까지 (그 뒤로는 소환하지 않는다)
func _summon_due(p: int) -> bool:
	return (p == 1 or p == 4) and summon_casts < SUMMON_MAX_CASTS


func living_spawns() -> int:
	var n := 0
	for i in range(spawn_state.size()):
		if spawn_state[i] != "" and monsters[i].is_alive():
			n += 1
	return n


func role_text(index: int) -> String:
	return String(P2Catalog.ENEMIES[roles[index]].role)


func is_main(index: int) -> bool:
	return bool(P2Catalog.ENEMIES[roles[index]].get("main", false))


func is_device(index: int) -> bool:
	return String(P2Catalog.ENEMIES[roles[index]].get("rank", "")) == "device"


# 본체가 있는 전투는 본체만 쓰러뜨리면 승리 (장치는 무시하고 몰아쳐도 된다)
func all_monsters_defeated() -> bool:
	var has_main := false
	for i in range(monsters.size()):
		if i < roles.size() and is_main(i):
			has_main = true
			if monsters[i].is_alive():
				return false
	if has_main:
		return true
	return super()


# 조준 사격의 현재 기본 피해 (충전 AIM_CHARGED / 완전 조준 FULL_AIM_CHARGED). 그 외 카드는 카드 수치
# 연발 사격은 치명 확률 10%p마다 한 발(최대 6). 그 밖에는 카드의 타격 수
func hits_now(card: Card) -> int:
	if P2Catalog.kind_of(card) == "barrage":
		return clampi(mash_hits, 1, P2Catalog.BARRAGE_MAX) if mash_hits > 0 else P2Catalog.BARRAGE_DEFAULT
	if P2Catalog.kind_of(card) == "light_rain":
		var sun := 4 if P2Catalog.upgrade_of(card) == "sun_rain" else 0
		return (P2Catalog.RAIN_SPEARS_PERFECT if strike_grade == "perfect" else P2Catalog.RAIN_SPEARS) + sun
	if P2Catalog.kind_of(card) == "volley":
		var extra := P2Catalog.STORM_VOLLEY_EXTRA if P2Catalog.upgrade_of(card) == "storm_volley" else 0
		return clampi(2 + extra + crit_chance() / 10, 2, P2Catalog.VOLLEY_MAX + extra)
	return P2Catalog.hits_of(card)


func card_base_value(card: Card) -> int:
	if P2Catalog.kind_of(card) == "aimed_shot" and P2Catalog.upgrade_of(card) != "instant_aim":
		if aim_charged.has(P2Catalog.uid_of(card)):
			return P2Catalog.FULL_AIM_CHARGED if P2Catalog.upgrade_of(card) == "full_aim" else P2Catalog.AIM_CHARGED
	return card.value


# 이 카드의 첫 타격에 붙는 정수 보정. 소비는 확정 때만
func first_hit_bonus(card: Card) -> Dictionary:
	var parts := {}
	if not P2Catalog.is_attack(card):
		return parts
	if block_strike_ready and attacks_played_turn == 0:
		parts["block_strike"] = TRAIT_BLOCK_STRIKE_BONUS
	if spur > 0 and P2Catalog.is_physical(card):
		parts["spur"] = spur
	if fork_ready and attacks_played_turn == 0:
		parts["fork"] = P2Catalog.FORK_BONUS * rl("tuning_fork")
	if quiver_next > 0 and attacks_played_turn == 0:
		parts["quiver"] = quiver_next * rl("arrow_quiver")
	if traits.has("armory") and attacks_played_turn == 0 and deck_size0 >= P2Catalog.ARMORY_PER:
		parts["armory"] = P2Catalog.ARMORY_BONUS * (deck_size0 / P2Catalog.ARMORY_PER)
	return parts


func _consume_first_hit(card: Card) -> void:
	fork_ready = false
	if attacks_played_turn == 0:
		quiver_next = 0
	if P2Catalog.is_physical(card):
		spur = 0
	if attacks_played_turn == 0:
		block_strike_ready = false


# ── 카드 실행 ────────────────────────────────────────────────────────────────

func can_play_card(card: Card) -> bool:
	if card != null and P2Catalog.is_fuel(card) and hand.cards.size() < 2:
		return false
	if is_noble_sealed(card):
		return false
	return super(card)


func play_card(card: Card, target_index: int = -1) -> bool:
	return play_card_ex(card, target_index, {})


# extra.fuel_uid: 연료화로 함께 소진할 손패의 다른 카드. 모든 선택이 유효할 때만 변경을 시작한다
func play_card_ex(card: Card, target_index: int, extra: Dictionary) -> bool:
	if card != null and P2Catalog.is_fuel(card):
		var uid := String(extra.get("fuel_uid", ""))
		if uid == "" or uid == P2Catalog.uid_of(card) or not _hand_has_uid(uid):
			return false
	if not reserve_card(card, target_index):
		return false
	var entry: Dictionary = reserved.pop_back()
	entry.merge(extra)
	return bool(_execute_card(entry).get("played", false))


func _hand_has_uid(uid: String) -> bool:
	for c in hand.cards:
		if P2Catalog.uid_of(c) == uid:
			return true
	return false


func _execute_card(entry: Dictionary) -> Dictionary:
	var card: Card = entry.card
	_pending_card_draw = 0
	_draw_sources.clear()
	_fuel_uid = String(entry.get("fuel_uid", ""))
	_x_value = maxi(1, mana_now()) if P2Catalog.is_x_cost(card) else 0
	_paid_now = 0 if P2Catalog.is_fuel(card) else (_x_value if P2Catalog.is_x_cost(card) else card.get_mana_cost())
	var result := super(entry)
	if bool(result.get("played", false)):
		cards_played_this_turn += 1
		cards_played_battle += 1
		aim_charged.erase(P2Catalog.uid_of(card))
		if not battle_over and _pending_card_draw > 0:
			_draw_cards(_pending_card_draw, _draw_sources[0] if not _draw_sources.is_empty() else ("focus" if P2Catalog.is_draw(card) else "quickshot"))
		if not battle_over and relics.has("satchel") and not satchel_used and cards_played_battle == 1:
			satchel_used = true
			_draw_cards(rl("satchel"), "satchel")
	_pending_card_draw = 0
	return result


func _draw_cards(count: int, src: String) -> void:
	var room := maxi(0, HAND_MAX - hand.cards.size())
	var drawn: Array = []
	for i in range(mini(count, room)):
		var c := deck.draw_one()
		if c == null:
			break
		hand.cards.append(c)
		if ult_turn:
			_disc_card(c)
		drawn.append(P2Catalog.uid_of(c))
	events.append({"kind": "draw", "source": src, "requested": count, "count": drawn.size(), "uids": drawn,
		"hand": hand.cards.size()})


func _queue_draw(n: int, src: String) -> void:
	_pending_card_draw += n
	_draw_sources.append(src)


# 카드 비용을 실제로 낸 장수 (마나 순환 특성)
func _after_paid_card() -> void:
	if _paid_now > 0:
		paid_cards_turn += 1
		if traits.has("mana_cycle") and paid_cards_turn >= TRAIT_MANA_CYCLE_NEED and not trait_used.has("mana_cycle") and not battle_over:
			trait_used["mana_cycle"] = true
			_gain_mana(1, "mana_cycle")


func _apply_card_effect(card: Card, target_index: int) -> int:
	events.clear()
	last_hit_damage.clear()
	_queue = {"arc": -1, "lens": false, "absorb": false, "blade": false, "chain": -1}
	_card_crit = false
	_card_forced = false
	_card_positive = false
	_card_kill = false
	_card_first_bonus = 0
	_card_shield_touched = {}
	var kind := P2Catalog.kind_of(card)
	var up := P2Catalog.upgrade_of(card)
	_queue.shards = []
	_queue.links = []
	if not P2Catalog.is_ult(card):
		if kind != ult_last:
			_ult_add(int(P2Catalog.ULT_GAIN.vary), "vary")
		ult_last = kind
		if strike_grade == "perfect":
			_ult_add(int(P2Catalog.ULT_GAIN.perfect_glyph), "perfect_glyph")

	# 연격은 콤보술사만 센다(다른 직업이 잽을 들어도 연격 글·칩이 끼지 않게)
	var fx: Dictionary = {}
	if class_id == "combo":
		fx = (P2Catalog.CARD_FX.get(kind, {}) as Dictionary).duplicate()
		fx.merge(P2Catalog.UPGRADE_FX.get(up, {}), true)
	var combo0 := combo
	if card.effect == Card.EffectType.DEFEND:
		if bool(fx.get("keep", false)):
			combo_keep = true
		if int(fx.get("combo", 0)) > 0:
			_add_combo(int(fx.combo))
		if kind == "rampart":
			wall = mini(P2Catalog.RAMPART_MAX * 2, wall + card.value + stat("def"))
			events.append({"kind": "wall", "amount": wall})
			_after_paid_card()
			return 0
		if kind == "iron_counter":
			parry_bonus = P2Catalog.IRON_COUNTER_DAMAGE
			events.append({"kind": "iron_counter", "amount": parry_bonus})
		var amount := card.value + stat("def")
		if kind == "mana_veil":
			amount += mini(P2Catalog.VEIL_BONUS_CAP, 2 * mana_now())
		if kind == "iron_beat":
			amount += mini(P2Catalog.STEEL_BEAT_CAP, perfect_phase * P2Catalog.STEEL_BEAT_PER) if up == "steel_beat" else mini(P2Catalog.IRON_BEAT_CAP, perfect_phase)
		if relics.has("shield_spur"):
			spur = mini(P2Catalog.SPUR_CAP * rl("shield_spur"), spur + P2Catalog.SPUR_STEP * rl("shield_spur"))
		var hexed := 0
		if hex_active:
			hexed = mini(P2Catalog.HEX_AMOUNT, amount)
			amount -= hexed
		_pending_defense += amount
		var cv := P2Catalog.counter_value(card)
		if cv > 0:
			counter_queue.append(cv)
			counter_charges = counter_queue.size()
		events.append({"kind": "guard", "amount": amount, "block": _pending_defense, "counter_added": cv > 0,
			"counter_value": cv + (P2Catalog.WARDEN_COUNTER_BONUS if cv > 0 and class_id == "warden" else 0),
			"counter": counter_charges, "veil": kind == "mana_veil", "hexed": hexed})
		if up == "carry_guard":
			carry_cap_turn = maxi(carry_cap_turn, P2Catalog.CARRY_GUARD_CAP)
		if P2Catalog.exhausts(card):
			_exhaust_self(card)
			events.append({"kind": "exhaust", "uids": [P2Catalog.uid_of(card)], "names": [card.card_name]})
			_on_exhaust()
		_after_paid_card()
		return 0

	if card.effect == Card.EffectType.STATUS_PACKAGE:
		_play_debuff(card, kind, target_index)
		_after_paid_card()
		return 0

	if card.effect == Card.EffectType.BUFF_ATTACK_SELF:
		_play_buff(card, kind)
		_after_paid_card()
		return 0

	if card.effect == Card.EffectType.HEAL_HP:
		_heal_player(card.value + (P2Catalog.HEAL_SIGIL_PERFECT if strike_grade == "perfect" and kind == "heal_sigil" else 0), kind)
		if P2Catalog.exhausts(card):
			_exhaust_self(card)
			events.append({"kind": "exhaust", "uids": [P2Catalog.uid_of(card)], "names": [card.card_name]})
			_on_exhaust()
		_after_paid_card()
		return 0

	if P2Catalog.is_fuel(card):
		var other: Card = null
		for c in hand.cards:
			if P2Catalog.uid_of(c) == _fuel_uid:
				other = c
		if other != null:
			hand.cards.erase(other)
			aim_charged.erase(P2Catalog.uid_of(other))
			(deck as P4Deck).exhaust(other)
			if is_noble_sealed(other):
				noble_seal_uid = ""
				events.append({"kind": "noble_unseal", "uid": P2Catalog.uid_of(other), "why": "exhaust"})
		_exhaust_self(card)
		events.append({"kind": "exhaust", "uids": [P2Catalog.uid_of(card)] + ([P2Catalog.uid_of(other)] if other != null else []),
			"names": [card.card_name] + ([other.card_name] if other != null else [])})
		_gain_mana(P2Catalog.SHIFT_MANA if up == "mana_shift" else P2Catalog.FUEL_MANA, "fuel")
		_on_exhaust()
		return 0

	if P2Catalog.is_draw(card):
		_queue_draw(card.value, "focus")
		events.append({"kind": "focus", "draw": card.value})
		if int(fx.get("cost", 0)) > 0 and combo >= int(fx.cost):
			_set_combo(combo - int(fx.cost))
			_gain_mana(int(fx.get("mana", 0)), kind)
		_after_paid_card()
		return 0

	if strike_reverse and relics.has("reverse_brush") and P2Catalog.is_attack(card):
		var per := card_base_value(card) + P2Catalog.stat_add(card, stats)
		var amt := int(per * hits_now(card) * {"perfect": 1.3, "hit": 1.0, "part": 0.75, "graze": 0.5}.get(strike_grade, 1.0)) * rl("reverse_brush")
		_pending_defense += amt
		events.append({"kind": "guard", "amount": amt, "block": _pending_defense, "counter_added": false, "counter_value": 0,
			"counter": counter_charges, "veil": false, "hexed": 0, "reverse": true})
		if P2Catalog.exhausts(card):
			_exhaust_self(card)
			events.append({"kind": "exhaust", "uids": [P2Catalog.uid_of(card)], "names": [card.card_name]})
			_on_exhaust()
		_after_paid_card()
		return 0

	# 공격 카드: 치명타 판정은 여기서 한 번 (첫 공격 보정은 판정 전에 읽는다)
	var primary := _primary_target(card, target_index)
	_decide_crit(card, target_index)
	var bonus_parts := first_hit_bonus(card)
	for k in bonus_parts:
		_card_first_bonus += int(bonus_parts[k])
	_consume_first_hit(card)
	var charged_shot := kind == "aimed_shot" and aim_charged.has(P2Catalog.uid_of(card))
	var spent := 0
	if kind == "bash":
		spent = mini(P2Catalog.BASH_MAX_SPEND, _pending_defense)
		_pending_defense -= spent
		events.append({"kind": "spend_block", "amount": spent, "block": _pending_defense})
	var slam_block := _pending_defense if kind == "slam" else 0
	var base := card_base_value(card) + spent * 2 + slam_block * (P2Catalog.EARTH_MULT if up == "earthshaker" else P2Catalog.SLAM_MULT) + combo * int(fx.get("per_combo", 0))
	var charge := charge_power if charge_power > 0.0 else P2Catalog.CHARGE_DEFAULT
	match kind:
		"focus_shot", "ki_blast":
			base = roundi(card_base_value(card) * minf(charge, P2Catalog.CHARGE_MAX))
		"ult_warden":
			base += 2 * _pending_defense
		"ult_combo":
			base += 6 * combo
	if rage > 0 and P2Catalog.is_attack(card):
		base += P2Catalog.flat_share(rage, hits_now(card))
	if P2Catalog.is_attack(card) and blood_bonus() > 0:
		base += P2Catalog.flat_share(blood_bonus(), hits_now(card))
	if kind == "armor_break" and target_index >= 0 and get_monster(target_index) != null and get_monster(target_index).is_alive():
		armor[target_index] = 0
		shields[target_index] = 0
		events.append({"kind": "armor_break", "index": target_index})
	match kind:
		"shield_throw":
			base += _pending_defense / 2
		"beat_slash":
			base += mini(P2Catalog.BEAT_SLASH_CAP, P2Catalog.BEAT_SLASH_PER * perfect_phase)
		"ember":
			base += (P2Catalog.EMBER_BURST_PER if up == "ember_burst" else P2Catalog.EMBER_PER) * (deck as P4Deck).exhausted.size()
	if strike_thorns > 0 and relics.has("thorn_eater"):
		base += P2Catalog.THORN_EAT_DAMAGE * strike_thorns * rl("thorn_eater")
		_lose_hp(strike_thorns, "thorn_eat")
	if kind == "torrent":
		var extra_pay := maxi(0, _x_value - 1)
		if extra_pay > 0:
			_set_mana(mana_now() - extra_pay)
		base = card.value * _x_value
		events.append({"kind": "x_paid", "x": _x_value, "mana": mana_now()})
	if _card_first_bonus > 0:
		events.append({"kind": "first_bonus", "amount": _card_first_bonus, "parts": bonus_parts})
	if _card_crit:
		events.append({"kind": "crit", "forced": _card_forced, "mult": _crit_mult_now(primary)})

	var nb := noble_info()
	_card_res_mult = float(nb.mult[noble_res]) if not nb.is_empty() else 1.0
	if strike_grade == "graze":
		_card_res_mult *= 0.5
	elif strike_grade == "part":
		_card_res_mult *= 0.75
	_card_noble_hit = false
	var total := 0
	var hit_order: Array[int] = []
	var consumed_total := 0
	var per_hit := P2Catalog.stat_add(card, stats)
	var targets := resolve_target_indices(card, target_index)
	var first_hit_done := false
	var chain_src: Array[int] = []
	var burning_before := {}
	var poisoned_before := {}
	var pre_st := {}
	for t0 in targets:
		burning_before[t0] = st(t0, "burn") > 0
		poisoned_before[t0] = st(t0, "poison")
		pre_st[t0] = (est[t0] as Dictionary).duplicate() if t0 < est.size() else {}
	var order_n := 0
	var drained := 0
	var doom0 := st(primary, "doom") if up == "hex_chain" and primary >= 0 else 0
	# 빛의 창: 창마다 살아 있는 적에게 고루 (대상 순서대로 돌아가며)
	var spears: Array = []
	if kind == "light_rain":
		for s in range(hits_now(card)):
			spears.append(targets[s % targets.size()] if not targets.is_empty() else -1)
	var loop_targets: Array = []
	if kind != "light_rain" and kind != "ult_rune_caster":
		loop_targets.assign(targets)
	if kind == "ult_rune_caster":
		total += _ult_beams(card, base + per_hit, hit_order)
	for index in loop_targets:
		var per_target := 0
		if kind == "shield_boomerang":
			per_target = _pending_defense / 2 + 2 * order_n
		if kind == "soul_drain" and st(index, "doom") > 0:
			per_target = P2Catalog.DRAIN_BONUS
		order_n += 1
		for h in range(hits_now(card)):
			var target := get_monster(index)
			if target == null or not target.is_alive():
				break # 대상이 쓰러지면 남은 타격은 취소하고 다른 적으로 옮기지 않는다
			var before_marks := mark_count(index)
			var extra := 0
			if not first_hit_done and index == primary:
				extra = _card_first_bonus
			first_hit_done = first_hit_done or index == primary
			var chain := 0
			if not card.is_aoe and class_id == "combo":
				if combo_target >= 0 and combo_target != index:
					combo = 0
				combo_target = index
				chain = combo if kind != "hundred_fists" else (combo * 2 if up == "thousand_fists" and h == hits_now(card) - 1 else 0)
			var air := P2Catalog.flat_share(P2Catalog.AIR_BONUS, hits_now(card)) if st(index, "air") > 0 else 0
			var got := _p5_hit(card, index, base + extra + per_hit + chain + per_target + air, h, hit_order)
			total += got
			if kind == "soul_drain" and per_target > 0:
				drained += got
			_on_hit_status(card, kind, index, h, got)
			if not card.is_aoe and class_id == "combo":
				combo = mini(P2Catalog.COMBO_MAX, combo + 1)
			if kind == "sigil_burst":
				consumed_total += before_marks
			if kind == "chain_blast" and h == 0 and before_marks >= P2Catalog.CHAIN_NEED:
				chain_src.append(index)
			if battle_over:
				break
		if battle_over:
			break
	for si in range(spears.size()):
		var sidx: int = spears[si]
		if battle_over or sidx < 0:
			break
		if not get_monster(sidx).is_alive():
			var alive := alive_monsters()
			if alive.is_empty():
				break
			sidx = alive[si % alive.size()].index
		total += _p5_hit(card, sidx, base + per_hit + (P2Catalog.flat_share(P2Catalog.AIR_BONUS, hits_now(card)) if st(sidx, "air") > 0 else 0), si, hit_order)
	if up == "pyre_burst" and not battle_over:
		for t in targets:
			var pb := st(int(t), "burn")
			if pb > 0 and get_monster(int(t)).is_alive() and not battle_over:
				_st_set(int(t), "burn", 0)
				var parts := clampi(pb / 2, 2, 4)
				events.append({"kind": "pyre", "index": int(t), "amount": pb * 2, "parts": parts})
				for q in range(parts):
					if get_monster(int(t)).is_alive() and not battle_over:
						_dot_hit(int(t), pb * 2 / parts + (pb * 2 % parts if q == parts - 1 else 0), "burn")
				burning_before[t] = false
	# 맞은 뒤 상태(살아 있는 대상마다) · 반응 · 원소 확산
	if not battle_over:
		_after_hits_status(card, kind, up, targets, burning_before, pre_st)
	if kind == "soul_drain" and drained > 0:
		_heal_player(mini(P2Catalog.DRAIN_HEAL_CAP, drained), "soul_drain")
	if kind == "ult_combo":
		_set_combo(0)
	if P2Catalog.is_attack(card) and forced_next:
		forced_next = false
		events.append({"kind": "forced_used"})
	# 한 장 방패: 이 카드가 닿은 방패는 카드가 끝나면 남은 양이 사라진다
	for i in _card_shield_touched:
		if shields[i] > 0:
			events.append({"kind": "shield_expire", "index": i, "left": shields[i]})
		shields[i] = 0

	# 데이터 효과(연격): 한 번 더 · 다 쓰기 · 조건 뽑기
	if not fx.is_empty() and not card.is_aoe:
		if int(fx.get("combo", 0)) > 0 and not battle_over:
			combo = mini(P2Catalog.COMBO_MAX, combo + int(fx.combo))
		if bool(fx.get("spend", false)):
			combo = 0
		if int(fx.get("need", 0)) > 0 and combo0 >= int(fx.need) and not battle_over:
			_queue_draw(int(fx.get("draw", 0)), kind)
	if combo != combo0:
		events.append({"kind": "combo", "before": combo0, "after": combo, "target": combo_target})
	# 카드 후속 효과
	if not battle_over:
		if up == "fire_bounce" and not targets.is_empty():
			var ob := _other_lowest(int(targets[0]))
			if ob >= 0:
				total += _secondary_hit(ob, P2Catalog.FIRE_BOUNCE, "bounce", int(targets[0]))
				_st_add(ob, "burn", P2Catalog.FIRE_BOUNCE, kind)
		if up == "hex_chain" and doom0 > 0 and primary >= 0:
			var to: Array = alive_monsters().filter(func(m): return m.index != primary).map(func(m): return m.index)
			if not to.is_empty():
				events.append({"kind": "hex_spread", "index": primary, "to": to})
				for o in to:
					_st_add(int(o), "doom", 1, kind)
		if kind == "slam" and slam_block / 2 > 0 and not targets.is_empty():
			for m in alive_monsters():
				if m.index != targets[0]:
					total += _secondary_hit(m.index, slam_block / 2 * (2 if up == "earthshaker" else 1), "slam_splash", targets[0])
		for src in chain_src:
			for m in alive_monsters():
				if m.index != src and not battle_over:
					total += _secondary_hit(m.index, P2Catalog.CHAIN_SPLASH, "chain", src)
		if up == "cleave_slash" and not targets.is_empty():
			for m in alive_monsters():
				if m.index != targets[0]:
					total += _secondary_hit(m.index, CLEAVE_DAMAGE, "cleave", targets[0])
		if up == "transfer_burst" and consumed_total > 0 and not targets.is_empty():
			for m in alive_monsters():
				if m.index != targets[0]:
					total += _secondary_hit(m.index, 2 * consumed_total, "transfer", targets[0])
		if up == "double_inscription":
			for index in hit_order:
				if get_monster(index).is_alive() and mark_count(index) < mark_cap():
					_set_marks(index, mark_count(index) + 1)
					events.append({"kind": "inscribe", "index": index, "marks": mark_count(index)})
		if kind == "mark_amp" and not targets.is_empty():
			var mt := targets[0]
			var add := mini(P2Catalog.MARK_SURGE_CAP if up == "mark_surge" else P2Catalog.MARK_AMP_CAP, mark_count(mt))
			if get_monster(mt).is_alive() and add > 0 and mark_count(mt) < mark_cap():
				_set_marks(mt, mini(mark_cap(), mark_count(mt) + add))
				events.append({"kind": "inscribe", "index": mt, "marks": mark_count(mt)})
		if kind == "suppress" and not targets.is_empty():
			for t in (targets if up == "dominate" else [targets[0]]):
				if get_monster(t).is_alive():
					suppression[t] = maxi(suppression[t], SUPPRESS_AMOUNT)
					events.append({"kind": "suppress", "index": t, "amount": suppression[t], "intent": effective_intent(t)})

	if not battle_over:
		if int(_queue.arc) >= 0:
			var origin := int(_queue.arc)
			var arc_to := _arc_target(origin)
			if arc_to >= 0:
				total += _secondary_hit(arc_to, ARC_DAMAGE * rl("arc"), "arc", origin)
			else:
				events.append({"kind": "arc_skip", "origin": origin})
		if bool(_queue.lens):
			var lens_to := _lowest_living()
			if lens_to >= 0:
				total += _secondary_hit(lens_to, LENS_DAMAGE * rl("hunter_lens"), "lens")
		# 표식 연쇄: 한 번에 표식 2개 이상 소비 → 다른 적(없으면 원래 대상)에게 4
		if int(_queue.chain) >= 0:
			var ch_to := _other_lowest(int(_queue.chain))
			if ch_to >= 0:
				total += _secondary_hit(ch_to, TRAIT_CHAIN_DAMAGE, "mark_chain", int(_queue.chain))

	# 치명타 연계 유물 (피해를 준 치명타 공격 카드, 턴마다 한 번)
	var crit_hit := _card_crit and _card_positive
	if crit_hit and relics.has("echo_string") and not echo_string_used and not targets.is_empty() and not battle_over:
		echo_string_used = true
		var es_to := _other_lowest(targets[0])
		if es_to >= 0:
			total += _secondary_hit(es_to, P2Catalog.ECHO_STRING_DAMAGE * rl("echo_string"), "echo_string", targets[0])
		else:
			events.append({"kind": "echo_string_skip"})

	if bool(_queue.absorb):
		_pending_defense += ABSORB_BLOCK * rl("absorb")
		events.append({"kind": "absorb", "amount": ABSORB_BLOCK * rl("absorb"), "block": _pending_defense})
	if bool(_queue.blade):
		_pending_defense += BLADE_BLOCK * rl("blade_rhythm")
		events.append({"kind": "blade", "amount": BLADE_BLOCK * rl("blade_rhythm"), "block": _pending_defense})

	# 이름 있는 회복·뽑기 (각 효과 턴/전투마다 한 번, 전투가 끝났으면 다시 열지 않는다)
	if not battle_over:
		if up == "reflux_burst" and consumed_total >= 2 and not reflux_used:
			reflux_used = true
			_gain_mana(1, "reflux_burst")
		if up == "pursuit_slash" and _card_kill and not pursuit_used:
			pursuit_used = true
			_gain_mana(1, "pursuit_slash")
		if crit_hit and relics.has("crit_capacitor") and not capacitor_used:
			capacitor_used = true
			_gain_mana(rl("crit_capacitor"), "crit_capacitor")
		if _card_kill and traits.has("chain_kill") and not trait_used.has("chain_kill"):
			trait_used["chain_kill"] = true
			_gain_mana(1, "chain_kill")
			_queue_draw(1, "chain_kill")
		if traits.has("combo_burst") and combo >= P2Catalog.COMBO_MAX and not trait_used.has("combo_burst") and not battle_over:
			trait_used["combo_burst"] = true
			var cbv := combo * P2Catalog.COMBO_BURST_MULT
			_set_combo(0)
			events.append({"kind": "combo_burst_cast", "amount": cbv})
			for cbm in alive_monsters():
				if not battle_over:
					total += _secondary_hit(cbm.index, cbv, "combo_burst")
		if charged_shot and traits.has("waited_shot") and not trait_used.has("waited_shot"):
			trait_used["waited_shot"] = true
			_gain_mana(1, "waited_shot")

	# 사냥꾼 준비: 치명타면 0, 피해를 준 비치명 공격 카드면 +1 (카드당 한 번)
	if class_id == "hunter" and prep_enabled:
		var before := hunter_prep
		if _card_crit:
			hunter_prep = 0
		elif _card_positive:
			hunter_prep = mini(P2Catalog.HUNTER_PREP_NEEDED, hunter_prep + 1)
		if hunter_prep != before:
			events.append({"kind": "prep", "before": before, "after": hunter_prep})

	if _card_noble_hit and not battle_over and noble_res < 2:
		noble_res += 1
		events.append({"kind": "resonance", "level": noble_res, "mult": float(nb.mult[noble_res]), "lance": int(nb.lance[noble_res])})
		if noble_res >= 2 and noble_seal_uid != "":
			events.append({"kind": "noble_unseal", "uid": noble_seal_uid, "why": "resonance"})
			noble_seal_uid = ""
	_card_res_mult = 1.0
	_card_noble_hit = false

	# 속사: 이번 턴 첫 공격 카드였으면 효과가 끝난 뒤 1장
	if kind == "quickshot" and attacks_played_turn == 0 and not battle_over:
		_queue_draw(1, "quickshot")
	if P2Catalog.exhausts(card):
		_exhaust_self(card)
		events.append({"kind": "exhaust", "uids": [P2Catalog.uid_of(card)], "names": [card.card_name]})
		_on_exhaust()
	attacks_played_turn += 1
	_after_paid_card()
	return total


func _add_combo(n: int) -> void:
	_set_combo(mini(P2Catalog.COMBO_MAX, combo + n))


func _set_combo(v: int) -> void:
	if v == combo:
		return
	events.append({"kind": "combo", "before": combo, "after": v, "target": combo_target})
	combo = v


func _exhaust_self(card: Card) -> void:
	(deck as P4Deck).exhaust_next[P2Catalog.uid_of(card)] = true


# 첫 소진: 소각로 문장 추가 4 / 태워서 버티기 방어 3 + 1장 (연료화가 두 장을 태워도 한 번)
func _on_exhaust() -> void:
	if relics.has("ember_jar") and ember_jar_n < P2Catalog.EMBER_JAR_MAX and not battle_over:
		ember_jar_n += 1
		_pending_defense += P2Catalog.EMBER_JAR_BLOCK * rl("ember_jar")
		events.append({"kind": "ember_jar", "amount": P2Catalog.EMBER_JAR_BLOCK * rl("ember_jar"), "block": _pending_defense})
	if relics.has("furnace_seal") and not furnace_used:
		furnace_used = true
		var to := _lowest_living()
		if to >= 0:
			_secondary_hit(to, P2Catalog.FURNACE_DAMAGE * rl("furnace_seal"), "furnace")
	if traits.has("burn_endure") and not trait_used.has("burn_endure") and not battle_over:
		trait_used["burn_endure"] = true
		_pending_defense += TRAIT_BURN_BLOCK
		events.append({"kind": "burn_endure", "amount": TRAIT_BURN_BLOCK, "block": _pending_defense})
		_queue_draw(1, "burn_endure")


func _p5_hit(card: Card, index: int, base: int, hit_index: int, hit_order: Array[int]) -> int:
	var m := get_monster(index)
	var magic := P2Catalog.is_magic(card)
	var physical := P2Catalog.is_physical(card)
	var kind := P2Catalog.kind_of(card)
	var burst := kind in ["sigil_burst", "chain_blast", "dark_rift", "ult_rune_caster"]
	var consumed := 0
	if physical or burst:
		consumed = mark_count(index)
		if consumed > 0:
			_set_marks(index, 0)
	var raw := floori(base * _card_res_mult) if _card_res_mult != 1.0 else base
	if _card_crit:
		var cm := _crit_mult_now(index)
		if hits_now(card) >= P2Catalog.RAPID_HITS:
			cm = 1.0 + (cm - 1.0) / 3.0
		raw = floori(raw * cm)
	if rage_mult != 1.0:
		raw = floori(raw * rage_mult)
	raw = _glass(raw)
	var armor_applied := 0 if kind in ["pierce", "focus_shot"] else armor[index]
	var direct := maxi(0, raw - armor_applied)
	var per_mark := MARK_BONUS
	if kind == "chain_blast":
		per_mark = P2Catalog.GRAND_CHAIN_PER if P2Catalog.upgrade_of(card) == "grand_chain" else P2Catalog.CHAIN_PER
	elif kind in ["dark_rift", "ult_rune_caster"]:
		per_mark = P2Catalog.CHAIN_PER
	var bonus := consumed * per_mark # 표식 추가 피해는 갑옷을 무시하고 치명타로 곱하지 않는다
	if consumed >= 2:
		chain_met = true
		if traits.has("mark_chain") and not trait_used.has("mark_chain"):
			trait_used["mark_chain"] = true
			_queue.chain = index
	var dealt := direct + bonus
	# 반응: 얼어 있는 적을 물리로 치면 쇄빙, 불로 치면 녹아내림 (피해 ×2, 얼음 풀림)
	var react := ""
	if st(index, "frozen") > 0 and physical:
		react = "shatter"
		dealt *= 2
		_st_set(index, "frozen", 0)
	if st(index, "vuln") > 0:
		dealt = floori(dealt * vuln_mult())
	var shield_block := 0
	if shields[index] > 0 and dealt > 0:
		shield_block = mini(shields[index], dealt)
		shields[index] -= shield_block
		dealt -= shield_block
	if shields[index] > 0 or shield_block > 0:
		_card_shield_touched[index] = true
	var actual := m.take_damage(dealt)
	_record_boss_damage(index, actual)
	if react != "":
		_reaction(index, react, actual)
		_chain_react(index, react, actual)
	var lk := st(index, "link") - 1
	if actual >= 2 and lk >= 0 and lk != index and lk < monsters.size():
		(_queue.links as Array).append([index, lk, actual / 2])
	if actual > 0:
		_card_positive = true
		if P2Catalog.ENEMIES[roles[index]].has("noble"):
			_card_noble_hit = true
	if not m.is_alive():
		_card_kill = true
	var mark_added := false
	if magic and actual > 0:
		magic_hits += 1
		if m.is_alive() and not burst:
			_set_marks(index, mini(mark_cap(), mark_count(index) + 1))
			mark_added = true
		if magic_hits == 2 and relics.has("arc") and not arc_used:
			arc_used = true
			_queue.arc = index
	if physical and actual > 0:
		phys_hits_turn += 1
		if phys_hits_turn == 2 and relics.has("blade_rhythm") and not blade_used:
			blade_used = true
			_queue.blade = true
	if physical and consumed > 0 and relics.has("absorb") and not absorb_used:
		absorb_used = true
		_queue.absorb = true
	if not m.is_alive() and relics.has("hunter_lens") and not lens_used:
		lens_used = true
		_queue.lens = true
	if actual > 0 and not hit_order.has(index):
		hit_order.append(index)
	last_hit_damage[index] = int(last_hit_damage.get(index, 0)) + actual
	var uw := unwind_info(index)
	var uw_before := unwind_count[index]
	if actual > 0 and unwind_window_open(index):
		unwind_count[index] = mini(int(uw.need), uw_before + 1)
	events.append({"kind": "hit", "index": index, "hit_index": hit_index, "magic": magic,
		"card_kind": kind, "damage": actual, "base": direct, "raw": raw, "armor": armor_applied, "pierce": kind == "pierce",
		"consumed": consumed, "detonation": bonus, "shield_block": shield_block,
		"shield_left": shields[index], "crit": _card_crit, "forced": _card_forced,
		"mark_added": mark_added, "marks": mark_count(index), "hp": m.hp, "dead": not m.is_alive()})
	if not uw.is_empty():
		events.back()["unwind"] = unwind_count[index]
		# 조건 달성은 한 번만, 살아 있을 때만 (치명적인 세 번째 타격이면 쓰러짐이 우선)
		if uw_before < int(uw.need) and unwind_count[index] >= int(uw.need) and m.is_alive():
			events.append({"kind": "unwind", "index": index, "count": unwind_count[index], "hit": int(uw.weak)})
	if not m.is_alive():
		_fan_spread(index)
		monster_defeated.emit(index)
		if all_monsters_defeated():
			_finish_battle(false)
	return actual


func _secondary_hit(index: int, amount: int, src: String, origin: int = -1) -> int:
	var m := get_monster(index)
	if m == null or not m.is_alive() or battle_over:
		return 0
	amount = _glass(amount)
	var after_armor := maxi(0, amount - armor[index])
	if st(index, "vuln") > 0:
		after_armor = floori(after_armor * vuln_mult())
	var actual := m.take_damage(after_armor)
	if not _resolving:
		_record_boss_damage(index, actual)
	events.append({"kind": src, "index": index, "origin": origin, "raw": amount,
		"armor": armor[index], "damage": actual, "hp": m.hp, "marks": mark_count(index),
		"dead": not m.is_alive()})
	if src == "counter" and not m.is_alive():
		counter_kill_met = true
	if not m.is_alive():
		_fan_spread(index)
		monster_defeated.emit(index)
		if all_monsters_defeated() and not _resolving:
			_finish_battle(false)
	return actual


func _lowest_living() -> int:
	var best := -1
	for m in alive_monsters():
		if best < 0 or m.hp < get_monster(best).hp:
			best = m.index
	return best


# 다른 살아 있는 적 중 체력이 가장 낮은 적 (같으면 앞 슬롯), 없으면 원래 대상이 살아 있을 때 원래 대상
func _other_lowest(origin: int) -> int:
	var best := -1
	for m in alive_monsters():
		if m.index == origin:
			continue
		if best < 0 or m.hp < get_monster(best).hp:
			best = m.index
	if best >= 0:
		return best
	var o := get_monster(origin)
	return origin if o != null and o.is_alive() else -1


func _record_boss_damage(index: int, actual: int) -> void:
	if actual <= 0 or not charge_window_open(index):
		return
	var c := charge_info(index)
	var before := boss_tally
	boss_tally += actual
	if before < int(c.threshold) and boss_tally >= int(c.threshold):
		events.append({"kind": "boss_weakened", "index": index, "tally": boss_tally, "hit": int(c.weak)})


# ── 상태이상 · 반응 · 필살 ─────────────────────────────────────────────────────

func st(i: int, key: String) -> int:
	return int((est[i] as Dictionary).get(key, 0)) if i >= 0 and i < est.size() else 0


func _st_set(i: int, key: String, v: int) -> void:
	if i < 0 or i >= est.size():
		return
	var before := st(i, key)
	if v <= 0:
		(est[i] as Dictionary).erase(key)
	else:
		est[i][key] = v
	if before != maxi(0, v):
		events.append({"kind": "status", "index": i, "key": key, "before": before, "after": maxi(0, v)})


# 상태 더하기: 냉기는 3이 되면 얼어붙음(냉기 0), 저주는 처음 걸릴 때 남은 턴을 정한다. 얼어 있는 적에게는 냉기가 더 붙지 않는다
func _st_add(i: int, key: String, n: int, _src := "") -> void:
	var m := get_monster(i)
	if n <= 0 or m == null or not m.is_alive():
		return
	_touch_elem(key)
	match key:
		"chill":
			if st(i, "frozen") > 0:
				return
			var c := st(i, "chill") + n
			if c >= P2Catalog.CHILL_FREEZE:
				_st_set(i, "chill", 0)
				_st_set(i, "frozen", 1 + rl("frost_crown"))
				events.append({"kind": "freeze", "index": i})
			else:
				_st_set(i, "chill", c)
		"doom":
			if st(i, "doom") <= 0:
				_st_set(i, "doom_t", P2Catalog.DOOM_TURNS)
			_st_set(i, "doom", st(i, "doom") + n)
		"trap", "air":
			_st_set(i, key, maxi(st(i, key), n))
		_:
			_st_set(i, key, st(i, key) + n)


func _ult_add(n: int, why: String) -> void:
	if n <= 0 or ult >= ult_cap() or _in_ult:
		return
	var before := ult
	ult = mini(ult_cap(), ult + n)
	events.append({"kind": "ult", "before": before, "after": ult, "why": why})


# 필살 게이지 상한(두 겹 필살이면 200)
func ult_cap() -> int:
	return P2Catalog.ULT_MAX * (2 if traits.has("ult_double") else 1)


func thin_deck_on() -> bool:
	return traits.has("thin_deck") and deck_size0 > 0 and deck_size0 <= P2Catalog.THIN_DECK_MAX


# 피의 값: 체력 절반 이하 +2, 30% 이하 +4 (공격 타격마다)
func blood_bonus() -> int:
	if not traits.has("blood_price"):
		return 0
	var mx := maxi(1, int(GameState.get_flag("player_max_hp")))
	var hp := player_hp()
	if hp * 10 <= mx * 3:
		return P2Catalog.BLOOD_LOW
	if hp * 2 <= mx:
		return P2Catalog.BLOOD_HALF
	return 0


# 질긴 목숨: 이번 피해로 쓰러지면 체력 1이 남게 줄인다(원정마다 한 번)
func _last_stand_cap(dmg: int) -> int:
	if dmg <= 0 or not traits.has("last_stand") or last_stand_spent or _is_clone or dmg < player_hp():
		return dmg
	last_stand_spent = true
	return maxi(0, player_hp() - 1)


func _disc_card(c: Card) -> bool:
	if c == null or c.mana_cost <= 0 or P2Catalog.is_x_cost(c):
		return false
	ult_disc.append([c, c.mana_cost])
	c.mana_cost -= 1
	return true


const ELEM_BIT := {"burn": 1, "chill": 2, "frozen": 2, "poison": 4, "lumen": 8, "umbra": 16}


# 원소 순환: 이번 턴 묻힌 원소를 비트로 모아 서로 다른 원소 3가지면 마나 1 + 1장
func _touch_elem(key: String) -> void:
	if not traits.has("elem_cycle") or _resolving or not ELEM_BIT.has(key):
		return
	elem_mask |= int(ELEM_BIT[key])
	var n := 0
	for b in [1, 2, 4, 8, 16]:
		if elem_mask & b:
			n += 1
	if n >= P2Catalog.ELEM_CYCLE_NEED and not trait_used.has("elem_cycle") and not battle_over:
		trait_used["elem_cycle"] = true
		events.append({"kind": "elem_cycle", "mask": elem_mask})
		_gain_mana(1, "elem_cycle")
		_queue_draw(1, "elem_cycle")


# 연쇄 반응: 가장 가까운(자리 순서) 다른 적에게 같은 반응 절반 한 번 더 (턴마다 두 번, 연쇄는 다시 연쇄하지 않음)
func _chain_react(index: int, name: String, amount: int) -> void:
	if not traits.has("chain_react") or _chaining or chain_n >= P2Catalog.CHAIN_REACT_MAX or battle_over or name == "spread":
		return
	var to := -1
	var best := 99
	for m in alive_monsters():
		if m.index != index and absi(m.index - index) < best:
			best = absi(m.index - index)
			to = m.index
	if to < 0:
		return
	chain_n += 1
	_chaining = true
	var half := (amount + 1) / 2
	events.append({"kind": "react", "index": to, "name": name, "label": String(P2Catalog.REACTION_NAME.get(name, name)), "amount": half, "chain_from": index})
	if name == "pcrys":
		_st_set(to, "pcrys", P2Catalog.PCRYS_TURNS)
	elif half > 0:
		_dot_hit(to, half, name)
	_chaining = false


# 턴 시작 특성 표시(얇은 덱 · 무결은 이미 손패에 반영됨)
func _turn_trait_events(_closing: bool) -> void:
	if thin_deck_on():
		events.append({"kind": "thin_draw"})


func ult_ready() -> bool:
	return ult >= P2Catalog.ULT_MAX and not battle_over and not _resolving and P2Catalog.ULT_KINDS.has(class_id)


# 필살: 게이지가 가득일 때 직업 필살 카드를 덱 밖에서 0마나로 바로 (손패·더미와 무관)
func use_ultimate(target_index: int) -> bool:
	if not ult_ready():
		return false
	var card := P2Catalog.build_card(String(P2Catalog.ULT_KINDS[class_id]), "ult_" + class_id)
	if P2Catalog.is_targeted(card) and (target_index < 0 or target_index >= monsters.size() or not get_monster(target_index).is_alive()):
		var alive := alive_monsters()
		if alive.is_empty():
			return false
		target_index = alive[0].index
	ult -= P2Catalog.ULT_MAX
	_x_value = 0
	_paid_now = 0
	_pending_card_draw = 0
	_draw_sources.clear()
	_in_ult = true
	_apply_card_effect(card, target_index)
	_in_ult = false
	if not battle_over and _pending_card_draw > 0:
		_draw_cards(_pending_card_draw, _draw_sources[0] if not _draw_sources.is_empty() else "ult")
	_pending_card_draw = 0
	if traits.has("ult_after") and not battle_over:
		ult_turn = true
		var dn := 0
		for c in hand.cards:
			if _disc_card(c):
				dn += 1
		events.append({"kind": "ult_after", "count": dn})
	events.push_front({"kind": "ult_used", "card": P2Catalog.kind_of(card), "class": class_id, "target": target_index})
	return true


func _reaction(index: int, name: String, amount: int) -> void:
	events.append({"kind": "react", "index": index, "name": name, "label": String(P2Catalog.REACTION_NAME.get(name, name)), "amount": amount})
	_ult_add(int(P2Catalog.ULT_GAIN.reaction) + (P2Catalog.ECLIPSE_ULT * rl("eclipse_ring") if relics.has("eclipse_ring") else 0), "reaction")
	if name == "shatter" and amount >= 2:
		(_queue.shards as Array).append([index, amount / 2])


# 타격마다 붙는 상태: 출혈 화살·필살 화살비 = 출혈 1 · 폭풍 연사 5발마다 출혈 1 · 독 바르기
func _on_hit_status(card: Card, kind: String, index: int, h: int, got: int) -> void:
	var m := get_monster(index)
	if m == null or not m.is_alive():
		return
	if kind in ["bleed_arrows", "ult_hunter"] and got >= 0:
		_st_add(index, "bleed", 1)
	if kind == "barrage" and (h + 1) % P2Catalog.BARRAGE_BLEED_EVERY == 0:
		_st_add(index, "bleed", 1)
	if coat > 0 and P2Catalog.is_physical(card):
		coat -= 1
		_st_add(index, "poison", coat_amt, "coat")


func _after_hits_status(card: Card, kind: String, _up: String, targets: Array, burning_before: Dictionary, pre_st: Dictionary) -> void:
	# 쇄빙 파편 · 고통 연결 (추가 피해는 다시 반응하지 않는다)
	for sh in (_queue.shards as Array):
		for m in alive_monsters():
			if m.index != int(sh[0]) and not battle_over:
				_secondary_hit(m.index, int(sh[1]), "shard", int(sh[0]))
	for lk in (_queue.links as Array):
		if not battle_over and get_monster(int(lk[1])).is_alive():
			_secondary_hit(int(lk[1]), int(lk[2]), "link", int(lk[0]))
	var elem := P2Catalog.elem_of(card)
	var add: Dictionary = P2Catalog.status_of(card)
	for t in targets:
		var i := int(t)
		var m := get_monster(i)
		if m == null or not m.is_alive() or battle_over:
			continue
		var adds := add.duplicate()
		if kind == "fire_wall" and adds.has("burn") and bool(burning_before.get(i, false)):
			adds["burn"] = int(adds.burn) * 2
		_elem_touch(i, elem, pre_st.get(i, {}), adds, kind)
		if not m.is_alive() or battle_over:
			continue
		if kind == "launcher":
			_st_add(i, "air", 1)
	# 돌풍: 날려 버리고(다음 공격 타격 −3) 대상의 화상·독·냉기를 다른 적 모두에게
	if kind == "gust" and not targets.is_empty():
		var g := int(targets[0])
		for kt in (targets if card.is_aoe else [g]):
			var ki := int(kt)
			if get_monster(ki).is_alive():
				suppression[ki] = maxi(suppression[ki], P2Catalog.GUST_SUPP)
				events.append({"kind": "knockback", "index": ki, "amount": suppression[ki], "intent": effective_intent(ki)})
		var spread := {}
		for key in ["burn", "poison", "chill"]:
			if st(g, key) > 0:
				spread[key] = st(g, key)
		if not spread.is_empty():
			_reaction(g, "spread", 0)
			for m in alive_monsters():
				if m.index != g:
					for key in spread:
						_st_add(m.index, String(key), int(spread[key]), "spread")
	match kind:
		"ult_warden":
			for m in alive_monsters():
				if armor[m.index] > 0 or shields[m.index] > 0:
					armor[m.index] = 0
					shields[m.index] = 0
					events.append({"kind": "armor_break", "index": m.index})
		"ult_shaman":
			for m in alive_monsters():
				if st(m.index, "doom") > 0 and not battle_over:
					_doom_burst(m.index, 2)
			for m in alive_monsters():
				_st_add(m.index, "doom", 3)


# 원소가 적에게 닿을 때: 그 적에 이미 묻어 있던 원소(pre = 맞기 전 상태)와 반응하고, 남은 상태를 붙인다. 순서가 바뀌어도 같은 반응
#   불 ↔ 냉기·얼음 = 증기 폭발 · 불 ↔ 독 = 유독 폭발 · 얼음 ↔ 독 = 독 결정 · 어둠 ↔ 빛 = 일식
func _elem_touch(i: int, elem: String, pre: Dictionary, adds: Dictionary, src: String) -> void:
	var m := get_monster(i)
	if m == null or not m.is_alive() or battle_over:
		return
	_touch_elem(String({"fire": "burn", "ice": "chill", "poison": "poison", "light": "lumen", "dark": "umbra"}.get(elem, "")))
	var iced := int(pre.get("chill", 0)) + (P2Catalog.CHILL_FREEZE if int(pre.get("frozen", 0)) > 0 else 0)
	var after_toxic := false
	match elem:
		"fire":
			if iced > 0 and (st(i, "chill") > 0 or st(i, "frozen") > 0):
				adds.erase("burn")
				_steam(i, st(i, "chill") + (P2Catalog.CHILL_FREEZE if st(i, "frozen") > 0 else 0))
			elif int(pre.get("poison", 0)) > 0 and st(i, "poison") > 0:
				_toxic(i)
		"ice":
			if int(pre.get("burn", 0)) > 0 and st(i, "burn") > 0:
				adds.erase("chill")
				_steam(i, st(i, "burn"))
			elif int(pre.get("poison", 0)) > 0 and st(i, "poison") > 0:
				_pcrys(i)
		"poison":
			if int(pre.get("burn", 0)) > 0 and st(i, "burn") > 0:
				after_toxic = true
			elif iced > 0:
				_pcrys(i)
		"dark":
			if int(pre.get("lumen", 0)) > 0 and st(i, "lumen") > 0:
				adds.erase("umbra")
				_st_set(i, "lumen", 0)
				_eclipse(i)
		"light":
			if int(pre.get("umbra", 0)) > 0 and st(i, "umbra") > 0:
				adds.erase("lumen")
				_st_set(i, "umbra", 0)
				_eclipse(i)
	if not m.is_alive() or battle_over:
		return
	for key in adds:
		_st_add(i, String(key), int(adds[key]), src)
	if after_toxic and m.is_alive() and not battle_over:
		_toxic(i)


func _steam(i: int, consumed: int) -> void:
	var amt := maxi(P2Catalog.STEAM_MULT, consumed * P2Catalog.STEAM_MULT)
	for key in ["chill", "frozen", "burn"]:
		if st(i, key) > 0:
			_st_set(i, key, 0)
	_reaction(i, "steam", amt)
	_dot_hit(i, amt, "steam")
	_chain_react(i, "steam", amt)
	for o in alive_monsters():
		if o.index != i and not battle_over:
			_secondary_hit(o.index, amt / 2, "steam_splash", i)


func _toxic(i: int) -> void:
	var pd := st(i, "poison") * 2
	_st_set(i, "poison", 0)
	_reaction(i, "toxic", pd)
	_dot_hit(i, pd, "toxic")
	_chain_react(i, "toxic", pd)


func _pcrys(i: int) -> void:
	_st_set(i, "pcrys", P2Catalog.PCRYS_TURNS)
	_reaction(i, "pcrys", 0)
	_chain_react(i, "pcrys", 0)


func _eclipse(i: int) -> void:
	_reaction(i, "eclipse", P2Catalog.ECLIPSE_DAMAGE)
	_dot_hit(i, P2Catalog.ECLIPSE_DAMAGE, "eclipse")
	_chain_react(i, "eclipse", P2Catalog.ECLIPSE_DAMAGE)
	for o in alive_monsters():
		_st_add(o.index, "vuln", P2Catalog.ECLIPSE_VULN, "eclipse")


# 원소술사 필살: 빔마다 모든 적에게 피해 → 그 원소를 묻힘(앞 빔이 남긴 원소와 반응)
func _ult_beams(card: Card, dmg: int, hit_order: Array[int]) -> int:
	var total := 0
	for k in range(P2Catalog.ULT_BEAMS.size()):
		var beam: Array = P2Catalog.ULT_BEAMS[k]
		events.append({"kind": "beam", "elem": String(beam[0]), "n": k})
		var pre := {}
		for m in alive_monsters():
			pre[m.index] = (est[m.index] as Dictionary).duplicate()
		for m in alive_monsters():
			if battle_over:
				break
			total += _p5_hit(card, m.index, dmg, k, hit_order)
		for m in alive_monsters():
			if battle_over:
				break
			_elem_touch(m.index, String(beam[0]), pre.get(m.index, {}), (beam[1] as Dictionary).duplicate(), "ult_rune_caster")
		if battle_over:
			break
	return total


func _play_debuff(card: Card, kind: String, target_index: int) -> void:
	var targets: Array = []
	if card.is_aoe:
		targets = alive_monsters().map(func(m): return m.index)
	elif target_index >= 0 and target_index < monsters.size() and get_monster(target_index).is_alive():
		targets = [target_index]
	events.append({"kind": "debuff_cast", "card": kind, "targets": targets.duplicate()})
	var add: Dictionary = P2Catalog.status_of(card)
	for i in targets:
		for key in add:
			_st_add(int(i), String(key), int(add[key]), kind)
	if P2Catalog.upgrade_of(card) == "swift_doom":
		for i in targets:
			if st(int(i), "doom") > 0:
				_st_set(int(i), "doom_t", 1)
	match kind:
		"mark_target":
			forced_next = true
			events.append({"kind": "forced_ready"})
		"soul_link":
			if not targets.is_empty():
				var a := int(targets[0])
				var best := -1
				for m in alive_monsters():
					if m.index != a and (best < 0 or m.hp > get_monster(best).hp):
						best = m.index
				if best >= 0:
					_st_set(a, "link", best + 1)
					_st_set(best, "link", a + 1)
					events.append({"kind": "linked", "index": a, "other": best})
	if P2Catalog.exhausts(card):
		_exhaust_self(card)
		events.append({"kind": "exhaust", "uids": [P2Catalog.uid_of(card)], "names": [card.card_name]})
		_on_exhaust()


func _play_buff(card: Card, kind: String) -> void:
	match kind:
		"blood_pact":
			_lose_hp(card.value, "blood_pact")
			rage_mult = P2Catalog.BLOOD_PACT_MULT
		"war_shout":
			rage += card.value
		"poison_coat":
			coat = P2Catalog.COAT_HITS
			coat_amt = card.value
		"smoke_bomb":
			smoke = 2 if P2Catalog.upgrade_of(card) == "smoke_screen" else 1
	events.append({"kind": "buff", "card": kind, "rage": rage, "rage_mult": rage_mult, "coat": coat, "smoke": smoke})


# 지속 피해: 갑옷 무시, 취약이면 +50%. 처치되면 전투 종료 판단까지
func _dot_hit(index: int, amount: int, key: String) -> int:
	var m := get_monster(index)
	if m == null or not m.is_alive() or amount <= 0 or battle_over:
		return 0
	var dmg := floori(amount * vuln_mult()) if st(index, "vuln") > 0 else amount
	var actual := m.take_damage(dmg)
	events.append({"kind": "dot", "index": index, "key": key, "raw": amount, "damage": actual, "hp": m.hp, "marks": mark_count(index), "dead": not m.is_alive()})
	if not m.is_alive():
		_fan_spread(index)
		monster_defeated.emit(index)
		if all_monsters_defeated():
			_finish_battle(false)
	return actual


# 확산의 부채: 쓰러진 적의 화상·독·저주가 살아 있는 다른 적 모두에게
func _fan_spread(index: int) -> void:
	if not relics.has("spread_fan") or battle_over:
		return
	var carry := {}
	for key in ["burn", "poison", "doom"]:
		if st(index, key) > 0:
			carry[key] = st(index, key)
	if carry.is_empty():
		return
	var others := alive_monsters().filter(func(m): return m.index != index)
	if others.is_empty():
		return
	_reaction(index, "spread", 0)
	for m in others:
		for key in carry:
			_st_add(m.index, String(key), int(carry[key]), "fan")


func _doom_burst(index: int, mult := 1) -> void:
	var n := st(index, "doom")
	if n <= 0:
		return
	_st_set(index, "doom", 0)
	_st_set(index, "doom_t", 0)
	_reaction(index, "doom", n * doom_mult() * mult)
	_dot_hit(index, n * doom_mult() * mult, "doom")
	_chain_react(index, "doom", n * doom_mult() * mult)
	if traits.has("doom_echo") and not get_monster(index).is_alive() and not battle_over:
		var de_to := _lowest_living()
		if de_to >= 0:
			var dk := (n * mult + 1) / 2
			events.append({"kind": "doom_echo", "from": index, "index": de_to, "amount": dk})
			_st_add(de_to, "doom", dk, "doom_echo")
	if class_id == "shaman":
		_heal_player(1, "doom_heal")


# 턴을 끝낼 때(적 행동 전): 화상(그 뒤 절반) · 독(그 뒤 −1) · 저주 남은 턴 −1(0이면 폭발) · 공중이던 적 착지
func _tick_statuses() -> void:
	for i in range(est.size()):
		var m := get_monster(i)
		if m == null or not m.is_alive() or battle_over:
			continue
		if st(i, "air") > 0:
			_st_set(i, "air", 0)
		var b := st(i, "burn")
		if b > 0:
			_st_set(i, "burn", b - 1 if relics.has("ember_heart") else floori(b * P2Catalog.BURN_TICK_KEEP))
			_dot_hit(i, b, "burn")
		var p := st(i, "poison")
		if p > 0 and m.is_alive() and not battle_over:
			if st(i, "pcrys") > 0:
				_st_set(i, "pcrys", st(i, "pcrys") - 1)
			else:
				_st_set(i, "poison", p - 1)
			_dot_hit(i, p, "poison")
		if st(i, "doom") > 0 and m.is_alive() and not battle_over:
			var t := st(i, "doom_t") - 1
			if t <= 0:
				_doom_burst(i)
			else:
				_st_set(i, "doom_t", t)
				if traits.has("doom_interest"):
					events.append({"kind": "doom_interest", "index": i})
					_st_add(i, "doom", 1, "doom_interest")


# ── 적 단계 ───────────────────────────────────────────────────────────────────

func begin_round_resolution() -> bool:
	if battle_over or stage_pending or _resolving or not reserved.is_empty():
		return false
	var mana := mana_now()
	if not super():
		return false
	if has_summoner():
		summon_phase += 1
	hex_active = false
	absorbed_phase = 0
	perfect_phase = 0
	echo_edge_n = 0
	iron_tempo_n = 0
	drum_echo_n = 0
	warden_parry_n = 0
	riposte_sum = 0
	phase_hits = 0
	phase_taken = 0
	_tick_statuses()
	if battle_over:
		return true
	if relics.has("reserve_seal") and not seal_used:
		seal_used = true
		var gain := mini(SEAL_MAX, SEAL_PER_MANA * mana) * rl("reserve_seal")
		if gain > 0:
			_pending_defense += gain
		events.append({"kind": "seal", "amount": gain, "mana": mana, "block": _pending_defense})
	for i in range(roles.size()):
		var c := charge_info(i)
		if not c.is_empty() and get_monster(i).is_alive() and cycle_index(i) == int(c.round):
			boss_locked[i] = int(c.weak) if boss_tally >= int(c.threshold) else int(c.full)
			events.append({"kind": "boss_lock", "index": i, "hit": boss_locked[i], "tally": boss_tally})
	var ni := noble_index()
	if ni >= 0 and get_monster(ni).is_alive():
		noble_lock = int(noble_info().lance[noble_res])
		events.append({"kind": "noble_lock", "index": ni, "hit": noble_lock, "level": noble_res})
	noble_res = 0
	# 거완: 턴 종료가 확정되면 이번 강타(14 또는 6)를 굳히고 세기 창을 닫는다. 억제·지원은 그 뒤 기존 순서대로
	for i in range(roles.size()):
		var u := unwind_info(i)
		if not u.is_empty() and get_monster(i).is_alive() and cycle_index(i) == int(u.strike):
			unwind_lock[i] = int(u.weak) if unwind_count[i] >= int(u.need) else unwind_full(i)
			events.append({"kind": "unwind_lock", "index": i, "hit": unwind_lock[i], "count": unwind_count[i]})
	# 독: 턴 종료마다 적 행동보다 먼저, 방어 무시. 쓰러지면 이 적 단계는 멈춘다
	if poison_ticks > 0:
		poison_ticks -= 1
		var pa := poison_amount
		var held := _last_stand_cap(pa)
		var taken: int = party[0].take_damage(held)
		events.append({"kind": "poison_tick", "amount": poison_amount, "damage": taken, "hp": player_hp(), "left": poison_ticks})
		if held < pa:
			events.append({"kind": "last_stand", "index": -1, "hp": player_hp()})
		if poison_ticks <= 0:
			poison_amount = 0
		if _is_party_wiped():
			_finish_battle(true)
	return true


func end_turn_seal_preview() -> int:
	if not relics.has("reserve_seal") or seal_used:
		return 0
	return mini(SEAL_MAX, SEAL_PER_MANA * mana_now()) * rl("reserve_seal")


# 적 하나의 행동. 막아 낸 타격 하나마다 먼저 얻은 반격 기회 하나를 쓴다 (수호기사 +1). 억제로만 줄어든 것은 막음이 아니다
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
		var act := intent_action(index)
		if not act.is_empty():
			_special_action(index, act)
			return {"acted": true, "index": index}
		var base_hits := intent(index)
		if st(index, "frozen") > 0:
			_st_set(index, "frozen", st(index, "frozen") - 1)
			events.append({"kind": "frozen_skip", "index": index})
			return {"acted": true, "index": index}
		if base_hits.is_empty():
			events.append({"kind": "prepare", "index": index})
			return {"acted": true, "index": index}
		var hits := effective_intent(index)
		if _is_damaging(hits):
			if st(index, "trap") > 0:
				var td := st(index, "trap")
				var again := relics.has("trapper_jaw") and st(index, "trap_re") == 0
				_st_set(index, "trap", td if again else 0)
				_st_set(index, "trap_re", 1 if again else 0)
				_secondary_hit(index, td, "trap_snap")
				if actor.is_alive():
					_st_add(index, "bleed", P2Catalog.TRAP_BLEED, "trap")
					if hits.size() > 1:
						hits.pop_front()
					else:
						events.append({"kind": "trap_stop", "index": index})
						return {"acted": true, "index": index}
			if actor.is_alive() and st(index, "bleed") > 0:
				var bd := st(index, "bleed")
				_st_set(index, "bleed", bd - 1)
				_dot_hit(index, bd, "bleed")
			if not actor.is_alive() or battle_over:
				return {"acted": true, "index": index}
		if suppression[index] > 0 and _is_damaging(base_hits):
			events.append({"kind": "suppressed", "index": index, "amount": suppression[index], "hits": hits.duplicate()})
			suppression[index] = 0
		var aura := aura_for(index)
		if aura > 0:
			events.append({"kind": "aura", "index": index, "amount": aura})
		if parry_mode and not hits.is_empty():
			_parry_act = {"index": index, "hits": hits.duplicate(), "h": 0}
			events.append({"kind": "enemy_hits_pending", "index": index, "hits": hits.duplicate()})
			return {"acted": true, "index": index, "pending": true}
		for h in range(hits.size()):
			if not actor.is_alive():
				events.append({"kind": "hit_cancelled", "index": index, "remaining": hits.size() - h})
				break
			if _enemy_hit(index, h, int(hits[h]), "", -1.0) != "":
				return {"acted": true, "index": index}
		_after_enemy_hits(index, hits)
		return {"acted": true, "index": index}
	return {"acted": false, "index": -1}


# 적 타격 하나. grade는 패링 판정: perfect 피해 0·방어도 그대로(막아 낸 것으로 쳐서 준비한 반격·가시가 나감) ·
# good 줄임(frac가 있으면 그 비율, 없으면 4분의 1) · miss/빈 값 그대로. 전투가 끝나면 "end"
func _enemy_hit(index: int, h: int, raw: int, grade: String, frac: float) -> String:
	var actor := get_monster(index)
	var raw0 := raw
	if smoke > 0 and raw > 0:
		smoke -= 1
		events.append({"kind": "smoke_miss", "index": index, "raw": raw})
		raw = 0
	var parried := 0
	if grade == "perfect":
		parried = raw
	elif grade == "good":
		if frac >= 0.0:
			parried = maxi(1, floori(raw * frac)) if raw > 0 else 0
		else:
			parried = raw / 4 if raw >= 4 else mini(raw, 1)
	raw -= parried
	if wall > 0 and raw > 0:
		var soak := mini(wall, raw)
		wall -= soak
		raw -= soak
		events.append({"kind": "wall_soak", "index": index, "amount": soak, "left": wall})
		if actor.is_alive():
			_secondary_hit(index, soak, "wall_reflect")
	if grade == "perfect":
		_ult_add(int(P2Catalog.ULT_GAIN.perfect_parry), "perfect_parry")
		perfect_phase += 2 if relics.has("mad_drum") else 1
		var genre := P2Catalog.genre_for(String(roles[index]), turn_number)
		if genre == "arrow" and relics.has("arrow_quiver"):
			quiver = mini(P2Catalog.QUIVER_MAX, quiver + 1)
		if genre == "drum" and relics.has("drum_echo") and drum_echo_n < P2Catalog.DRUM_ECHO_MAX and actor.is_alive():
			drum_echo_n += 1
			_secondary_hit(index, rl("drum_echo"), "drum_echo")
	var absorbed := mini(_pending_defense, raw)
	_pending_defense -= absorbed
	absorbed_phase += absorbed
	var taken := 0
	var dmg_in := _last_stand_cap(raw - absorbed)
	if dmg_in > 0:
		taken = int(party[0].take_damage(dmg_in))
	if raw0 > 0:
		phase_hits += 1
		phase_taken += taken
	events.append({"kind": "enemy_hit", "index": index, "hit_index": h, "raw": raw,
		"absorbed": absorbed, "damage": taken, "hp": player_hp(), "block": _pending_defense})
	if grade != "":
		events.back().parry = grade
		events.back().parried = parried
	if dmg_in < raw - absorbed:
		events.append({"kind": "last_stand", "index": index, "hp": player_hp()})
	if _is_party_wiped():
		_finish_battle(true)
		return "end"
	if (grade == "perfect" or grade == "good") and relics.has("iron_tempo") and iron_tempo_n < IRON_TEMPO_MAX:
		iron_tempo_n += 1
		_pending_defense += rl("iron_tempo")
		events.append({"kind": "iron_tempo", "amount": rl("iron_tempo"), "block": _pending_defense})
	if grade == "perfect" and relics.has("echo_edge") and echo_edge_n < ECHO_EDGE_MAX and actor.is_alive():
		echo_edge_n += 1
		_secondary_hit(index, ECHO_EDGE_DAMAGE * rl("echo_edge"), "echo_edge")
	if grade == "perfect" and traits.has("riposte_beat") and riposte_sum < P2Catalog.RIPOSTE_CAP and parried > 0 and actor.is_alive():
		var rv := mini((parried + 1) / 2, P2Catalog.RIPOSTE_CAP - riposte_sum)
		riposte_sum += rv
		_secondary_hit(index, rv, "riposte_beat")
	if grade == "perfect" and (class_id == "warden" or parry_bonus > 0) and warden_parry_n < P2Catalog.WARDEN_PARRY_MAX and actor.is_alive():
		warden_parry_n += 1
		_secondary_hit(index, maxi(P2Catalog.WARDEN_PARRY_DAMAGE if class_id == "warden" else 0, parry_bonus), "shield_counter")
	if absorbed > 0 or grade == "perfect":
		if not counter_queue.is_empty():
			var cv: int = counter_queue.pop_front()
			counter_charges = counter_queue.size()
			var dmg := cv + (P2Catalog.WARDEN_COUNTER_BONUS if class_id == "warden" else 0)
			_secondary_hit(index, dmg, "counter")
		if relics.has("thorn") and not thorn_used:
			thorn_used = true
			if actor.is_alive():
				_secondary_hit(index, THORN_DAMAGE * rl("thorn"), "thorn")
			else:
				events.append({"kind": "thorn_skip", "index": index})
	if all_monsters_defeated():
		_on_stage_wiped()
		return "end"
	return ""


func _after_enemy_hits(index: int, hits: Array) -> void:
	var actor := get_monster(index)
	if is_spawn_slot(index) and actor.is_alive() and not hits.is_empty():
		_consume_spawn(index)
	var nb: Dictionary = P2Catalog.ENEMIES[roles[index]].get("noble", {})
	if not nb.is_empty() and actor.is_alive():
		noble_acts += 1
		if noble_casts < 2 and (nb.seal_acts as Array).has(noble_acts):
			noble_casts += 1
			noble_pending = true
			events.append({"kind": "noble_seal_cast", "index": index, "casts": noble_casts})


func parry_pending() -> bool:
	return not _parry_act.is_empty()


# 보류 중인 남은 타격(이어하기·화면용)
func pending_hits_event() -> Dictionary:
	var hits: Array = (_parry_act.hits as Array).slice(int(_parry_act.h))
	return {"kind": "enemy_hits_pending", "index": int(_parry_act.index), "hits": hits.map(func(x): return int(x))}


# 손맛 시험판: 보류한 적 행동의 다음 타격 하나를 판정과 함께 처리한다. frac는 여러 노트 중 일부만 막았을 때 줄이는 비율. 사건은 events에. 행동이 끝나면 done
func resolve_parry_hit(grade: String, frac := -1.0) -> Dictionary:
	events.clear()
	if _parry_act.is_empty():
		return {"done": true}
	var index := int(_parry_act.index)
	var hits: Array = _parry_act.hits
	var h := int(_parry_act.h)
	_parry_act.h = h + 1
	if _enemy_hit(index, h, int(hits[h]), grade, frac) != "":
		_parry_act = {}
		return {"done": true}
	var actor := get_monster(index)
	if h + 1 < hits.size() and not actor.is_alive():
		events.append({"kind": "hit_cancelled", "index": index, "remaining": hits.size() - h - 1})
	if h + 1 >= hits.size() or not actor.is_alive():
		_after_enemy_hits(index, hits)
		_parry_act = {}
		return {"done": true}
	return {"done": false}


# 폭발한 소환수는 사라진다(처치가 아님: 처치 보상·특성과 무관). 화면은 이 사건으로 물보라·소멸을 보인다
func _consume_spawn(index: int) -> void:
	monsters[index].hp = 0
	spawn_state[index] = "consumed"
	suppression[index] = 0
	est[index] = {}
	events.append({"kind": "spawn_consumed", "index": index, "iid": instance_ids[index]})


# 빈(처음·처치·소멸) 소환 자리에 새 개체: 새 고유 번호, 깨끗한 체력·표식·억제·방패. 이번 단계에는 행동하지 않고 다음 단계가 기한
func _summon(index: int, count: int) -> void:
	if summon_casts >= SUMMON_MAX_CASTS:
		events.append({"kind": "prepare", "index": index})
		return
	var room := SPAWN_LIVING_MAX - living_spawns()
	var spawned: Array = []
	for i in range(spawn_state.size()):
		if spawned.size() >= mini(count, room):
			break
		if spawn_state[i] == "" or monsters[i].is_alive():
			continue
		monsters[i].hp = monsters[i].max_hp
		monsters[i].status.clear()
		_set_marks(i, 0)
		suppression[i] = 0
		shields[i] = 0
		est[i] = {}
		summon_serial += 1
		instance_ids[i] = "%s#%d.s%d" % [roles[i], i, summon_serial]
		spawn_state[i] = "active"
		spawn_birth[i] = summon_phase
		spawn_due[i] = summon_phase + 1
		spawned.append({"index": i, "iid": instance_ids[i], "hp": monsters[i].hp, "max": monsters[i].max_hp, "due": spawn_due[i]})
	summon_casts += 1
	events.append({"kind": "summon", "index": index, "spawned": spawned, "casts": summon_casts, "phase": summon_phase})


func _special_action(index: int, act: Dictionary) -> void:
	match String(act.get("act", "")):
		"hex":
			hex_next = true
			events.append({"kind": "hex", "index": index, "amount": P2Catalog.HEX_AMOUNT})
		"poison":
			poison_amount = int(act.get("amount", 2))
			poison_ticks = int(act.get("ticks", 2))
			events.append({"kind": "poison", "index": index, "amount": poison_amount, "ticks": poison_ticks})
		"rebuild":
			var rebuilt: Array = []
			for i in range(monsters.size()):
				if is_device(i) and not monsters[i].is_alive():
					monsters[i].hp = monsters[i].max_hp
					rebuilds[i] += 1
					instance_ids[i] = "%s#%d.%d" % [roles[i], i, rebuilds[i]]
					_set_marks(i, 0)
					suppression[i] = 0
					est[i] = {}
					rebuilt.append(i)
			events.append({"kind": "rebuild", "index": index, "devices": rebuilt})
		"summon":
			_summon(index, int(act.get("count", SUMMON_COUNT)))
		_:
			events.append({"kind": "prepare", "index": index})


# 라운드 정리: 이월 방어(잔류 방패 2 / 남겨둔 방패 3 중 큰 상한)는 쓰지 않은 방어에서 계산 →
# 기존 정리(반격 기회 만료, 방어 0) → 새 턴(마나·보존 충전·손패 5) → 이월 방어 → 막고 치기 준비 → 인내 장갑
func finish_round_resolution() -> void:
	var closing := _round_open and (_resolving or stage_pending or battle_over)
	var carry := 0
	var strike := false
	if closing:
		carry = mini(carry_cap_turn, _pending_defense)
		strike = traits.has("block_strike") and absorbed_phase >= TRAIT_BLOCK_STRIKE_NEED
		counter_queue.clear()
		var flaw := traits.has("flawless") and phase_hits > 0 and phase_taken == 0 and not battle_over
		extra_mana_turn = 1 if flaw else 0
		flawless_next = flaw
	var turn_before := turn_number
	super()
	if not closing:
		return
	counter_charges = 0
	seal_used = false
	for i in range(est.size()):
		for key in ["vuln", "weak", "umbra", "lumen"]:
			if st(i, key) > 0:
				_st_set(i, key, st(i, key) - 1)
	boss_locked.clear()
	unwind_lock.fill(-1)
	noble_lock = -1
	if battle_over or turn_number == turn_before:
		return
	events.clear()
	if _noble_released != "":
		events.append({"kind": "noble_unseal", "uid": _noble_released, "why": "turn"})
		_noble_released = ""
	# 봉인 추첨은 정상 손패 갱신이 끝난 이 경계에서 한 번, 전투 난수로 손패 실제 카드 중 균등하게. 빈 손이면 이번 예약은 끝
	if noble_pending:
		noble_pending = false
		if hand.cards.is_empty():
			events.append({"kind": "noble_seal_skip"})
		else:
			var pick: Card = hand.cards[(deck as Object).rng.randi_range(0, hand.cards.size() - 1)]
			noble_seal_uid = P2Catalog.uid_of(pick)
			noble_seal_turn = turn_number
			events.append({"kind": "noble_seal", "uid": noble_seal_uid, "name": pick.card_name})
	if carry > 0:
		_pending_defense += carry
		events.append({"kind": "carry", "amount": carry, "block": _pending_defense})
	if strike:
		block_strike_ready = true
		events.append({"kind": "block_strike_ready", "amount": TRAIT_BLOCK_STRIKE_BONUS})
	if extra_mana_turn > 0:
		events.append({"kind": "flawless", "mana": mana_now()})
	_turn_trait_events(true)
	if hex_active:
		events.append({"kind": "hex_active", "amount": P2Catalog.HEX_AMOUNT})
	if relics.has("patient_glove") and not glove_used:
		for c in hand.cards:
			if aim_charged.has(P2Catalog.uid_of(c)):
				glove_used = true
				_pending_defense += P2Catalog.PATIENT_BLOCK * rl("patient_glove")
				events.append({"kind": "glove", "amount": P2Catalog.PATIENT_BLOCK * rl("patient_glove"), "block": _pending_defense})
				break


func _finish_battle(player_lost: bool) -> void:
	if battle_over:
		return
	for i in range(suppression.size()):
		suppression[i] = 0
	noble_seal_uid = ""
	noble_pending = false
	noble_res = 0
	counter_queue.clear()
	poison_ticks = 0
	poison_amount = 0
	hex_active = false
	hex_next = false
	super(player_lost)


# 전투 중 회복약: 체력 회복 + 독·주술 해제 (자기 턴에 턴당 하나, 마나 비용 없음)
func use_potion(amount: int) -> Dictionary:
	events.clear()
	var got := _heal_player(amount, "potion")
	var cleansed := poison_ticks > 0 or hex_active or hex_next
	poison_ticks = 0
	poison_amount = 0
	hex_active = false
	hex_next = false
	events.append({"kind": "potion", "amount": got, "cleansed": cleansed, "hp": player_hp()})
	return {"healed": got, "cleansed": cleansed}


func use_mana_potion(amount: int) -> int:
	events.clear()
	return _gain_mana(amount, "mana_potion")


# ── 첫 손패 교체 (지금은 켜는 경로가 없다: 옛 선택 II 훈련 제거) ──────────────────────

func can_mulligan() -> bool:
	return mulligan_allowed and not mulligan_used and turn_number == 1 and cards_played_this_turn == 0 \
		and not _resolving and not battle_over


func mulligan(uids: Array) -> bool:
	if not can_mulligan() or uids.is_empty() or uids.size() > 2:
		return false
	var chosen: Array[Card] = []
	for c in hand.cards:
		if uids.has(P2Catalog.uid_of(c)):
			chosen.append(c)
	if chosen.size() != uids.size():
		return false
	var replacements: Array[Card] = []
	for i in range(chosen.size()):
		if deck.draw_pile.is_empty():
			break
		replacements.append(deck.draw_pile.pop_back())
	for i in range(replacements.size()):
		var slot := hand.cards.find(chosen[i])
		hand.cards[slot] = replacements[i]
	for i in range(replacements.size()):
		deck.draw_pile.insert(0, chosen[i])
	mulligan_used = true
	events.clear()
	events.append({"kind": "mulligan", "count": replacements.size()})
	return true


# ── 미리보기: 같은 규칙 코드를 복제본에 돌린다 (난수·더미·실제 마나·체력·일회성 보정 불변) ─────────

func _cards_by_uid() -> Dictionary:
	var out := {}
	for c in hand.cards + deck.draw_pile + deck.discard_pile + (deck as P4Deck).exhausted:
		out[P2Catalog.uid_of(c)] = c
	return out


func _clone_for_preview() -> P2Battle:
	var clone := P2Battle.from_dict(to_dict(), _cards_by_uid(), true)
	clone.hand.cards = hand.cards.duplicate()
	return clone


# 결과의 맨 위 칸은 일반(또는 확정 치명타) 갈래. crit_chance > 0이고 확정이 아니면 crit 칸에 치명타 갈래를 따로 싣는다
func preview(card: Card, target_index: int) -> Dictionary:
	return preview_ex(card, target_index, {})


func preview_ex(card: Card, target_index: int, extra: Dictionary) -> Dictionary:
	var look := crit_outlook(card, target_index)
	var result := _preview_branch(card, target_index, extra, 1 if bool(look.forced) else 0)
	result["crit_chance"] = int(look.chance)
	result["forced"] = bool(look.forced)
	result["crit"] = {}
	if not bool(look.forced) and int(look.chance) > 0:
		result["crit"] = _preview_branch(card, target_index, extra, 1)
	return result


func _preview_branch(card: Card, target_index: int, extra: Dictionary, crit: int) -> Dictionary:
	var clone := _clone_for_preview()
	clone._crit_override = crit
	var cost := 0 if P2Catalog.is_fuel(card) else card.get_mana_cost()
	clone._x_value = maxi(1, mana_now()) if P2Catalog.is_x_cost(card) else 0
	clone._paid_now = 0 if P2Catalog.is_fuel(card) else (clone._x_value if P2Catalog.is_x_cost(card) else cost)
	clone._clone_mana = maxi(0, mana_now() - cost)
	clone._fuel_uid = String(extra.get("fuel_uid", ""))
	var twin: Card = null
	for c in clone.hand.cards:
		if c == card:
			twin = c
	clone.hand.cards.erase(card)
	clone._pending_card_draw = 0
	clone._apply_card_effect(card, target_index)
	var draws := 0
	var room := HAND_MAX - (hand.cards.size() - 1 - (1 if P2Catalog.is_fuel(card) and clone._fuel_uid != "" else 0))
	var available := deck.draw_pile.size() + deck.discard_pile.size() + 1
	if clone._pending_card_draw > 0:
		draws += mini(clone._pending_card_draw, mini(room, available))
	var satchel := 0
	if relics.has("satchel") and not satchel_used and cards_played_battle == 0:
		satchel = mini(rl("satchel"), maxi(0, mini(room - draws, available - draws)))
	var out := {"events": clone.events.duplicate(true), "block": clone._pending_defense,
		"counter": clone.counter_charges, "counter_queue": clone.counter_queue.duplicate(), "draw": draws, "satchel": satchel,
		"boss_tally": clone.boss_tally, "mana_after": clone._clone_mana, "hp_after": clone._clone_hp,
		"noble_res_before": noble_res, "noble_res": clone.noble_res, "noble_unseal": noble_seal_uid != "" and clone.noble_seal_uid == "",
		"x": clone._x_value, "prep_after": clone.hunter_prep, "is_crit": clone._card_crit, "first_bonus": clone._card_first_bonus,
		"battle_over": clone.battle_over, "monsters": []}
	for i in range(monsters.size()):
		out.monsters.append({"hp_before": monsters[i].hp, "hp": clone.monsters[i].hp,
			"marks_before": mark_count(i), "marks": clone.mark_count(i),
			"suppression": clone.suppression[i], "shield_before": shields[i], "shield": clone.shields[i],
			"unwind_before": unwind_count[i], "unwind": clone.unwind_count[i],
			"st_before": (est[i] as Dictionary).duplicate() if i < est.size() else {}, "st": (clone.est[i] as Dictionary).duplicate() if i < clone.est.size() else {},
			"dead": monsters[i].is_alive() and not clone.monsters[i].is_alive()})
	return out


# ── 저장/복원 (행동이 끝난 경계에서만 부른다) ──────────────────────────────────

func to_dict() -> Dictionary:
	var ms: Array = []
	var summoner := has_summoner()
	for i in range(monsters.size()):
		ms.append({"hp": monsters[i].hp, "max_hp": monsters[i].max_hp, "marks": mark_count(i), "suppression": suppression[i],
			"shield": shields[i], "iid": instance_ids[i], "rebuilds": rebuilds[i]})
		if i < est.size() and not (est[i] as Dictionary).is_empty():
			ms[i]["st"] = (est[i] as Dictionary).duplicate()
		if armor[i] != int(P2Catalog.ENEMIES[roles[i]].armor):
			ms[i]["armor"] = armor[i]
		if summoner:
			ms[i]["spawn"] = {"state": spawn_state[i], "birth": spawn_birth[i], "due": spawn_due[i]}
		if not unwind_info(i).is_empty():
			ms[i]["unwind"] = {"count": unwind_count[i], "lock": unwind_lock[i]}
	var d := deck as Object
	var locked := {}
	for k in boss_locked:
		locked[str(k)] = boss_locked[k]
	var charged: Array = aim_charged.keys()
	charged.sort()
	var tu: Array = trait_used.keys()
	tu.sort()
	var out := {
		"v": SNAPSHOT_VERSION,
		"encounter_id": encounter_id,
		"source": source,
		"spec": spec.duplicate(true),
		"relics": relics.duplicate(),
		"traits": traits.duplicate(),
		"stats": stats.duplicate(),
		"relic_lv": relic_lv.duplicate(), "relic_order": relic_order.duplicate(),
		"seed": seed_used,
		"rng_seed": str(d.rng.seed),
		"rng_state": str(d.rng.state),
		"crit_seed": str(crit_rng.seed),
		"crit_state": str(crit_rng.state),
		"crit_mode": crit_mode, "prep_enabled": prep_enabled,
		"class_id": class_id, "max_mana": max_mana, "hunter_prep": hunter_prep, "attack_bonus": attack_bonus, "hit_mult": hit_mult,
		"hp_mult": hp_mult, "rank_hp": rank_hp.duplicate(), "judge_mult": judge_mult, "approach_mult": approach_mult, "pattern_level": pattern_level, "mods": mods.duplicate(),
		"affixes": affixes.duplicate(), "heal_cap": heal_cap,
		"opening_block": opening_block,
		"opening_applied": opening_applied,
		"turn": turn_number,
		"mana": mana_now(),
		"hp": player_hp(),
		"block": _pending_defense,
		"counter_queue": counter_queue.duplicate(),
		"flags": {
			"magic_hits": magic_hits, "arc_used": arc_used, "absorb_used": absorb_used, "thorn_used": thorn_used,
			"cards_played": cards_played_this_turn,
			"paid_cards_turn": paid_cards_turn, "cards_played_battle": cards_played_battle, "phys_hits_turn": phys_hits_turn,
			"blade_used": blade_used, "lens_used": lens_used, "attacks_played_turn": attacks_played_turn,
			"carry_cap_turn": carry_cap_turn, "pursuit_used": pursuit_used, "reflux_used": reflux_used,
			"capacitor_used": capacitor_used, "echo_string_used": echo_string_used, "furnace_used": furnace_used,
			"glove_used": glove_used, "seal_used": seal_used, "absorbed_phase": absorbed_phase, "satchel_used": satchel_used,
			"block_strike_ready": block_strike_ready,
			"hex_active": hex_active, "hex_next": hex_next, "poison_amount": poison_amount, "poison_ticks": poison_ticks,
			"mulligan_allowed": mulligan_allowed, "mulligan_used": mulligan_used, "chain_met": chain_met,
			"counter_kill_met": counter_kill_met, "victory_heal": victory_heal, "potion_turn": potion_turn,
			"perfect_phase": perfect_phase, "echo_edge_n": echo_edge_n, "iron_tempo_n": iron_tempo_n, "spur": spur, "ember_jar_n": ember_jar_n, "fork_ready": fork_ready, "quiver": quiver, "quiver_next": quiver_next, "drum_echo_n": drum_echo_n, "warden_parry_n": warden_parry_n,
			"ult": ult, "deck_size0": deck_size0, "chain_n": chain_n, "elem_mask": elem_mask, "riposte_sum": riposte_sum, "phase_hits": phase_hits, "phase_taken": phase_taken, "extra_mana_turn": extra_mana_turn, "last_stand_spent": last_stand_spent, "flawless_next": flawless_next, "rage": rage, "coat": coat, "coat_amt": coat_amt, "wall": wall, "parry_bonus": parry_bonus, "smoke": smoke, "forced_next": forced_next,
			"combo": combo, "combo_target": combo_target, "combo_keep": combo_keep,
		},
		"trait_used": tu,
		"boss_tally": boss_tally,
		"boss_locked": locked,
		"round_open": _round_open,
		"resolving": _resolving,
		"enemy_order": _enemy_order.duplicate(),
		"enemy_cursor": _enemy_cursor,
		"parry_act": _parry_act.duplicate(true),
		"combo_heals": combo_heals,
		"rage_mult": rage_mult, "ult_last": ult_last,
		"battle_over": battle_over,
		"monsters": ms,
		"aim_charged": charged,
		"hand": _uids(hand.cards),
		"draw": _uids(deck.draw_pile),
		"discard": _uids(deck.discard_pile),
		"exhausted": _uids((deck as P4Deck).exhausted),
	}
	# 소환사 전투에만 붙는 칸 (다른 전투의 저장본 모양은 그대로)
	if summoner:
		out["summon"] = {"phase": summon_phase, "casts": summon_casts, "serial": summon_serial}
	if noble_index() >= 0:
		out["noble"] = {"res": noble_res, "lock": noble_lock, "acts": noble_acts, "casts": noble_casts, "pending": noble_pending,
			"seal_uid": noble_seal_uid, "seal_turn": noble_seal_turn}
	return out


static func _uids(cards: Array[Card]) -> Array:
	var out: Array = []
	for c in cards:
		out.append(P2Catalog.uid_of(c))
	return out


# 저장본 모양 검사: 복원 전에 부르며, 빠지거나 형이 틀리거나 범위를 벗어난 칸이 있으면 이유를 돌려준다
static func snapshot_errors(snap) -> Array:
	var errors: Array = []
	if not (snap is Dictionary):
		return ["battle snapshot is not a dictionary"]
	for key in ["spec", "hand", "draw", "discard", "exhausted", "monsters", "enemy_order", "counter_queue", "aim_charged", "relics", "traits", "trait_used"]:
		if not (snap.get(key) is Array or snap.get(key) is Dictionary):
			errors.append("battle.%s missing" % key)
	for key in ["flags", "boss_locked"]:
		if not (snap.get(key) is Dictionary):
			errors.append("battle.%s missing" % key)
	for key in ["turn", "mana", "hp", "block", "enemy_cursor", "seed", "max_mana", "hunter_prep", "attack_bonus", "opening_block", "boss_tally"]:
		if not (snap.get(key) is int):
			errors.append("battle.%s not int" % key)
	for key in ["rng_seed", "rng_state", "crit_seed", "crit_state", "encounter_id", "class_id", "crit_mode", "source"]:
		if not (snap.get(key) is String):
			errors.append("battle.%s not string" % key)
	if int(snap.get("v", 0)) != SNAPSHOT_VERSION:
		errors.append("battle snapshot version")
	if not errors.is_empty():
		return errors
	if not P2Catalog.CLASSES.has(String(snap.class_id)):
		errors.append("battle class")
	if int(snap.max_mana) < 1 or int(snap.max_mana) > 6 or int(snap.mana) < 0 or int(snap.mana) > int(snap.max_mana):
		errors.append("battle mana out of range")
	if int(snap.hunter_prep) < 0 or int(snap.hunter_prep) > P2Catalog.HUNTER_PREP_NEEDED:
		errors.append("battle hunter_prep out of range")
	if int(snap.block) < 0 or int(snap.hp) < 0:
		errors.append("battle negative block/hp")
	for v in snap.counter_queue:
		if not (v is int) or int(v) < 0:
			errors.append("battle counter_queue value")
	if not (String(snap.crit_mode) in ["normal", "off", "force"]):
		errors.append("battle crit_mode")
	for r in (snap.spec as Dictionary).get("enemies", []):
		if not P2Catalog.ENEMIES.has(String(r)):
			errors.append("battle enemy role")
	for t in snap.traits:
		if not P2Catalog.TRAITS.has(String(t)):
			errors.append("battle trait")
	for m in snap.monsters:
		if not (m is Dictionary) or not (m.get("hp") is int) or int(m.hp) < 0 or int(m.get("shield", 0)) < 0:
			errors.append("battle monster")
	var seen := {}
	for key in ["hand", "draw", "discard", "exhausted"]:
		for u in snap[key]:
			if not (u is String):
				errors.append("battle.%s uid type" % key)
			elif seen.has(u):
				errors.append("battle uid %s in two piles" % u)
			seen[u] = true
	if (snap.hand as Array).size() > HAND_MAX:
		errors.append("battle hand over max")
	errors.append_array(_summon_errors(snap))
	errors.append_array(_unwind_errors(snap))
	errors.append_array(_noble_errors(snap))
	return errors


# 귀족 저장본: 귀족 역할이 있을 때만 있어야 하고 형·범위·시점이 맞아야 한다 (빠지거나 틀리면 거부, 옛 hard_boss 저장본은 칸이 없다)
static func _noble_errors(snap: Dictionary) -> Array:
	var nb: Dictionary = {}
	for r in (snap.spec as Dictionary).get("enemies", []):
		nb = (P2Catalog.ENEMIES.get(String(r), {}) as Dictionary).get("noble", nb)
	var n = snap.get("noble")
	if nb.is_empty():
		return [] if n == null else ["battle noble on other battle"]
	if not (n is Dictionary) or not (n.get("res") is int) or not (n.get("lock") is int) or not (n.get("acts") is int) or not (n.get("casts") is int) \
			or not (n.get("pending") is bool) or not (n.get("seal_uid") is String) or not (n.get("seal_turn") is int):
		return ["battle noble missing"]
	var errors: Array = []
	var resolving := bool(snap.get("resolving", false))
	var uid := String(n.seal_uid)
	if int(n.res) < 0 or int(n.res) > 2 or (resolving and int(n.res) != 0):
		errors.append("battle noble res")
	if not (int(n.lock) == -1 or (nb.lance as Array).has(int(n.lock))) or (int(n.lock) >= 0 and not resolving):
		errors.append("battle noble lock")
	if int(n.acts) < 0 or int(n.casts) < 0 or int(n.casts) > 2:
		errors.append("battle noble acts")
	if bool(snap.get("battle_over", false)):
		return errors
	var due := 0
	for a in nb.seal_acts:
		if int(n.acts) >= int(a):
			due += 1
	if int(n.casts) != mini(2, due) or (bool(n.pending) and (not resolving or int(n.casts) == 0)):
		errors.append("battle noble casts")
	if uid != "" and (not (snap.hand as Array).has(uid) or int(n.seal_turn) != int(snap.turn) or int(n.casts) == 0 or (not resolving and int(n.res) >= 2)):
		errors.append("battle noble seal uid")
	return errors


# 거완 저장본 검사: unwind 역할 칸에만 있어야 하고, 형·범위·창/잠금 시점이 서로 맞아야 한다 (빠지면 기본값으로 메우지 않고 거부)
static func _unwind_errors(snap: Dictionary) -> Array:
	var errors: Array = []
	var spec_s: Dictionary = snap.spec
	var roles_s: Array = spec_s.get("enemies", [])
	var offs: Array = spec_s.get("offsets", [])
	var ms: Array = snap.monsters
	for i in range(ms.size()):
		var m = ms[i]
		if not (m is Dictionary):
			continue
		var d: Dictionary = P2Catalog.ENEMIES.get(String(roles_s[i]) if i < roles_s.size() else "", {})
		var u: Dictionary = d.get("unwind", {})
		var su = m.get("unwind")
		if u.is_empty():
			if su != null:
				errors.append("battle unwind on other role")
			continue
		if not (su is Dictionary) or not (su.get("count") is int) or not (su.get("lock") is int):
			errors.append("battle unwind missing")
			continue
		var moves: Array = d.moves
		var full := int((moves[int(u.strike)] as Array)[0])
		var c := int(su.count)
		var l := int(su.lock)
		if c < 0 or c > int(u.need):
			errors.append("battle unwind count")
		if not (l in [-1, full, int(u.weak)]):
			errors.append("battle unwind lock")
		if bool(snap.get("battle_over", false)):
			continue
		var off := int(offs[i]) if i < offs.size() else 0
		var window := (maxi(0, int(snap.turn) - 1) + off) % moves.size() == int(u.strike)
		var resolving := bool(snap.get("resolving", false))
		if not window and (c != 0 or l != -1):
			errors.append("battle unwind outside window")
		if window and not resolving and l != -1:
			errors.append("battle unwind lock before end turn")
		if window and resolving and int(m.hp) > 0 and l == -1:
			errors.append("battle unwind lock missing")
		if l >= 0 and l != (int(u.weak) if c >= int(u.need) else full):
			errors.append("battle unwind lock mismatch")
	return errors


# 소환사 전투 저장본 검사: 새 역할이 있을 때만. 칸 모양·범위·자리 수·고유 번호·기한이 서로 맞아야 한다(없으면 추측하지 않고 거부)
static func _summon_errors(snap: Dictionary) -> Array:
	var errors: Array = []
	var roles_s: Array = (snap.spec as Dictionary).get("enemies", [])
	var has_new := false
	for r in roles_s:
		var d: Dictionary = P2Catalog.ENEMIES.get(String(r), {})
		if bool(d.get("summoner", false)) or bool(d.get("summon_slot", false)):
			has_new = true
	if not has_new:
		return errors
	var sm = snap.get("summon")
	if not (sm is Dictionary) or not (sm.get("phase") is int) or not (sm.get("casts") is int) or not (sm.get("serial") is int):
		return ["battle summon missing"]
	if int(sm.phase) < 0 or int(sm.phase) > 999 or int(sm.casts) < 0 or int(sm.casts) > SUMMON_MAX_CASTS or int(sm.serial) < 0 or int(sm.serial) > SUMMON_MAX_CASTS * SUMMON_COUNT:
		errors.append("battle summon out of range")
	var ms: Array = snap.monsters
	if ms.size() != roles_s.size():
		return errors + ["battle summon monster count"]
	for o in snap.enemy_order:
		if not (o is int) or int(o) < 0 or int(o) >= ms.size():
			errors.append("battle enemy_order index")
	var living := 0
	var iids := {}
	for i in range(ms.size()):
		var m: Dictionary = ms[i]
		var slot := bool((P2Catalog.ENEMIES[String(roles_s[i])] as Dictionary).get("summon_slot", false))
		var sp = m.get("spawn")
		if not (sp is Dictionary) or not (sp.get("state") is String) or not (sp.get("birth") is int) or not (sp.get("due") is int):
			errors.append("battle spawn missing")
			continue
		var st := String(sp.state)
		if not (st in SPAWN_STATES) or (st == "") == slot:
			errors.append("battle spawn state")
			continue
		if not (m.get("iid") is String) or iids.has(String(m.iid)):
			errors.append("battle instance id")
		iids[String(m.get("iid", ""))] = true
		if slot:
			if (st == "inactive" or st == "consumed") and int(m.hp) != 0:
				errors.append("battle spawn hp")
			if st == "active":
				if int(sp.due) != int(sp.birth) + 1 or int(sp.birth) < 1 or int(sp.birth) > int(sm.phase):
					errors.append("battle spawn due")
				if int(m.hp) > 0:
					living += 1
			if int(m.hp) > int(m.get("max_hp", 0)):
				errors.append("battle spawn hp")
	if living > SPAWN_LIVING_MAX:
		errors.append("battle spawn living")
	return errors


# cards_by_uid: 원정 덱에서 만든 카드 사본. 저장본의 더미 순서대로 다시 배치한다 (섞지 않는다).
# clone=true면 미리보기 복제본: GameState를 건드리지 않고 마나·체력을 자체 값으로 든다
static func from_dict(snap: Dictionary, cards_by_uid: Dictionary, clone := false) -> P2Battle:
	var b := P2Battle.new(snap.spec, [] as Array[Card], Array(snap.relics, TYPE_STRING, "", null), int(snap.seed),
		{"class_id": snap.class_id, "max_mana": snap.max_mana, "stats": snap.get("stats", {}), "relic_lv": snap.get("relic_lv", {}),
		"traits": snap.traits, "source": snap.source, "opening_block": snap.opening_block,
		"encounter_id": snap.encounter_id, "crit_mode": snap.crit_mode, "prep_enabled": snap.get("prep_enabled", true),
		"attack_bonus": snap.attack_bonus, "hit_mult": float(snap.get("hit_mult", 1.0)), "hp_mult": float(snap.get("hp_mult", 1.0)), "rank_hp": snap.get("rank_hp", {}),
		"judge_mult": float(snap.get("judge_mult", 1.0)), "approach_mult": float(snap.get("approach_mult", 1.0)),
		"pattern_level": int(snap.get("pattern_level", 0)), "mods": snap.get("mods", []),
		"affixes": snap.get("affixes", []), "heal_cap": int(snap.get("heal_cap", COMBO_HEAL_CAP))})
	b._is_clone = clone
	b.relic_order.assign(snap.get("relic_order", snap.relics))
	var d := b.deck as Object
	d.rng.seed = int(String(snap.rng_seed))
	d.rng.state = int(String(snap.rng_state))
	b.crit_rng.seed = int(String(snap.crit_seed))
	b.crit_rng.state = int(String(snap.crit_state))
	b.deck.draw_pile = _cards(snap.draw, cards_by_uid)
	b.deck.discard_pile = _cards(snap.discard, cards_by_uid)
	(b.deck as P4Deck).exhausted = _cards(snap.exhausted, cards_by_uid)
	b.hand.cards = _cards(snap.hand, cards_by_uid)
	b.opening_applied = bool(snap.opening_applied)
	b.turn_number = int(snap.turn)
	if clone:
		b._clone_mana = int(snap.mana)
		b._clone_hp = int(snap.hp)
	else:
		GameState.set_flag("player_max_mana", int(snap.max_mana))
		GameState.set_flag("player_mana", int(snap.mana))
		GameState.set_flag("player_hp", int(snap.hp))
	b.hunter_prep = int(snap.hunter_prep)
	b._pending_defense = int(snap.block)
	b.counter_queue.clear()
	for v in snap.counter_queue:
		b.counter_queue.append(int(v))
	b.counter_charges = b.counter_queue.size()
	var f: Dictionary = snap.flags
	for k in f:
		match String(k):
			"cards_played":
				b.cards_played_this_turn = int(f[k])
			"victory_heal", "magic_hits", "paid_cards_turn", "cards_played_battle", "phys_hits_turn", "attacks_played_turn", \
					"carry_cap_turn", "absorbed_phase", "poison_amount", "poison_ticks", "potion_turn", "perfect_phase", "echo_edge_n", "iron_tempo_n", "combo", "combo_target", "spur", "ember_jar_n", "quiver", "quiver_next", "drum_echo_n", "warden_parry_n", "ult", "rage", "coat", "wall", "parry_bonus", "smoke", "coat_amt", "deck_size0", "chain_n", "elem_mask", "riposte_sum", "phase_hits", "phase_taken", "extra_mana_turn":
				b.set(String(k), int(f[k]))
			_:
				b.set(String(k), bool(f[k]))
	b.trait_used = {}
	for t in snap.trait_used:
		b.trait_used[String(t)] = true
	b.boss_tally = int(snap.boss_tally)
	b.boss_locked.clear()
	for k in (snap.boss_locked as Dictionary):
		b.boss_locked[int(k)] = int(snap.boss_locked[k])
	b.aim_charged.clear()
	for u in snap.aim_charged:
		b.aim_charged[String(u)] = true
	b._round_open = bool(snap.round_open)
	b._resolving = bool(snap.resolving)
	b._enemy_order.clear()
	for i in snap.enemy_order:
		b._enemy_order.append(int(i))
	b._enemy_cursor = int(snap.enemy_cursor)
	b._parry_act = (snap.get("parry_act", {}) as Dictionary).duplicate(true)
	b.combo_heals = int(snap.get("combo_heals", 0))
	b.rage_mult = float(snap.get("rage_mult", 1.0))
	b.ult_last = String(snap.get("ult_last", ""))
	b.battle_over = bool(snap.battle_over)
	for i in range(mini(b.monsters.size(), (snap.monsters as Array).size())):
		var m: Dictionary = snap.monsters[i]
		b.monsters[i].max_hp = int(m.max_hp)
		b.monsters[i].hp = int(m.hp)
		b._set_marks(i, int(m.marks))
		b.suppression[i] = int(m.get("suppression", 0))
		b.shields[i] = int(m.get("shield", 0))
		b.instance_ids[i] = String(m.get("iid", b.instance_ids[i]))
		b.rebuilds[i] = int(m.get("rebuilds", 0))
		if i < b.est.size():
			var sd = m.get("st", {})
			var clean := {}
			if sd is Dictionary:
				for k in sd:
					clean[String(k)] = int(sd[k])
			b.est[i] = clean
		if m.has("armor"):
			b.armor[i] = int(m.armor)
		var uw = m.get("unwind")
		if uw is Dictionary and i < b.unwind_count.size():
			b.unwind_count[i] = int(uw.get("count", 0))
			b.unwind_lock[i] = int(uw.get("lock", -1))
		var sp = m.get("spawn")
		if sp is Dictionary and i < b.spawn_state.size():
			b.spawn_state[i] = String(sp.get("state", b.spawn_state[i]))
			b.spawn_birth[i] = int(sp.get("birth", -1))
			b.spawn_due[i] = int(sp.get("due", -1))
	var nb = snap.get("noble")
	if nb is Dictionary:
		b.noble_res = int(nb.res)
		b.noble_lock = int(nb.lock)
		b.noble_acts = int(nb.acts)
		b.noble_casts = int(nb.casts)
		b.noble_pending = bool(nb.pending)
		b.noble_seal_uid = String(nb.seal_uid)
		b.noble_seal_turn = int(nb.seal_turn)
	var sm = snap.get("summon")
	if sm is Dictionary:
		b.summon_phase = int(sm.get("phase", 0))
		b.summon_casts = int(sm.get("casts", 0))
		b.summon_serial = int(sm.get("serial", 0))
	return b


static func _cards(uids: Array, cards_by_uid: Dictionary) -> Array[Card]:
	var out: Array[Card] = []
	for u in uids:
		if cards_by_uid.has(String(u)):
			out.append(cards_by_uid[String(u)])
	return out
