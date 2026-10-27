class_name P2Bot
extends RefCounted
# 검증·보정용 자동 정책(사람 플레이 증거가 아님).
#   choose()  : 미리보기 점수 정책 (greedy). 치명타는 확률 가중 기대값, 확정 치명타는 그 갈래만 본다
#   simple()  : 단순 정책 — 큰 공격이 오면 방어 1장, 아니면 가장 약한 적에게 가장 센 공격 (초보 기준 참고용)
#   random_legal(): 낼 수 있는 카드 중 무작위 (맥락용 하한)
# 보상 방향: 직업마다 d1/d2 두 가지 (첫 보상의 두 방향을 따라간다). A/B/C/M은 P3 시험 호환용

const PREF := {
	"A": {"upgrades": ["split", "double_inscription", "cleave_slash", "counter"], "relics": ["arc", "hunter_lens", "absorb", "blade_rhythm", "satchel", "bandage", "reserve_seal", "thorn"],
		"cards": ["wave", "suppress", "focus", "pierce", "twin_slash", "bash"], "trait": "echo"},
	"B": {"upgrades": ["counter", "cleave_slash", "split", "double_inscription"], "relics": ["thorn", "reserve_seal", "bandage", "blade_rhythm", "absorb", "satchel", "arc", "hunter_lens"],
		"cards": ["bash", "suppress", "pierce", "twin_slash", "focus", "wave"], "trait": "reprisal"},
	"C": {"upgrades": ["cleave_slash", "split", "counter", "double_inscription"], "relics": ["blade_rhythm", "satchel", "hunter_lens", "absorb", "reserve_seal", "arc", "bandage", "thorn"],
		"cards": ["twin_slash", "focus", "pierce", "suppress", "bash", "wave"], "trait": "echo"},
	"M": {"upgrades": [], "relics": [], "cards": [], "trait": "reprisal"},
}

const CLASS_PREF := {
	"rune_caster": {
		"d1": {"upgrades": ["split", "double_inscription", "transfer_burst", "reflux_burst", "counter", "carry_guard"],
			"relics": ["arc", "hunter_lens", "rift_heart", "satchel", "absorb", "reserve_seal", "bandage", "furnace_seal"],
			"cards": ["wave", "torrent", "sigil_burst", "mana_veil", "focus", "suppress"], "trait": "echo"},
		"d2": {"upgrades": ["reflux_burst", "transfer_burst", "split", "carry_guard", "double_inscription", "counter"],
			"relics": ["rift_heart", "furnace_seal", "arc", "reserve_seal", "bandage", "satchel", "hunter_lens"],
			"cards": ["torrent", "mana_veil", "sigil_burst", "wave", "focus", "suppress"], "trait": "echo"},
	},
	"warden": {
		"d1": {"upgrades": ["counter", "fierce_riposte", "layered_riposte", "cleave_slash", "carry_guard", "pursuit_slash"],
			"relics": ["thorn", "reserve_seal", "absorb", "bandage", "furnace_seal", "blade_rhythm"],
			"cards": ["riposte", "bash", "suppress", "fortify", "pierce", "slash"], "trait": "reprisal"},
		"d2": {"upgrades": ["carry_guard", "cleave_slash", "pursuit_slash", "layered_riposte", "fierce_riposte", "counter"],
			"relics": ["absorb", "blade_rhythm", "reserve_seal", "furnace_seal", "thorn", "bandage"],
			"cards": ["bash", "sweep", "fortify", "twin_slash", "riposte", "suppress"], "trait": "reprisal"},
	},
	"hunter": {
		"d1": {"upgrades": ["instant_aim", "pursuit_slash", "carry_guard", "counter", "cleave_slash"],
			"relics": ["crit_capacitor", "echo_string", "obsidian_lens", "hunter_lens", "blade_rhythm", "satchel"],
			"cards": ["quickshot", "twin_slash", "pierce", "focus", "slash", "suppress"], "trait": "reprisal"},
		"d2": {"upgrades": ["full_aim", "carry_guard", "pursuit_slash", "counter", "cleave_slash"],
			"relics": ["patient_glove", "obsidian_lens", "crit_capacitor", "echo_string", "hunter_lens", "reserve_seal"],
			"cards": ["aimed_shot", "quickshot", "focus", "pierce", "twin_slash", "suppress"], "trait": "reprisal"},
	},
}


static func pref_for(class_id: String, path: String) -> Dictionary:
	var base: Dictionary = CLASS_PREF.get(class_id, {}).get(path, PREF.get(path, PREF.M))
	var out := base.duplicate(true)
	# 목록에 없는 유물도 순서를 갖게 (교체할 때 가장 덜 원하는 것을 고르기 위해)
	for id in P2Catalog.RELIC_ORDER:
		if not (out.relics as Array).has(id) and not (base.relics as Array).is_empty():
			out.relics.append(id)
	return out


static func incoming(battle: P2Battle, dead := {}) -> int:
	var total := 0
	for m in battle.alive_monsters():
		if dead.has(m.index):
			continue
		for h in battle.effective_intent(m.index):
			total += int(h)
	return total


static func _score(battle: P2Battle, card: Card, p: Dictionary, block: int) -> float:
	var score := 0.0
	var dead := {}
	for i in range(p.monsters.size()):
		var m: Dictionary = p.monsters[i]
		score += float(m.hp_before - m.hp)
		if m.dead:
			dead[i] = true
			var threat := 0
			for h in battle.effective_intent(i):
				threat += int(h)
			score += 6.0 + threat * 1.4
		elif battle.get_monster(i).is_alive():
			score += (int(m.marks) - int(m.marks_before)) * 2.2
			score += (int(m.shield_before) - int(m.shield)) * 0.7
			score += _status_value(battle, i, m.st_before, m.st)
			if int(m.suppression) > battle.suppression[i]:
				var hits := battle.effective_intent(i)
				score += 2.0 * hits.size() if P2Battle._is_damaging(hits) else 0.5
	var danger := incoming(battle, dead)
	score += (mini(int(p.block), danger) - mini(block, danger)) * 1.3
	if int(p.counter) > battle.counter_charges and danger > 0:
		score += 3.0
	score += 2.2 * (int(p.draw) + int(p.satchel))
	for i in range(battle.monsters.size()):
		var c := battle.charge_info(i)
		if not c.is_empty() and battle.charge_window_open(i) and battle.boss_tally < int(c.threshold) and int(p.boss_tally) >= int(c.threshold):
			score += (int(c.full) - int(c.weak)) * 1.3
	# 돌려받은 마나는 다음 카드 한 장 값어치
	var spent := int(p.x) if P2Catalog.is_x_cost(card) else card.get_mana_cost()
	var refund := int(p.mana_after) - (battle.mana_now() - spent)
	score += refund * 1.5
	score -= (spent - 1) * 1.5
	# 보존되는 조준 사격은 충전 전이면 아껴 둔다 (적을 쓰러뜨리지 못할 때)
	if P2Catalog.retains(card) and not battle.aim_charged.has(P2Catalog.uid_of(card)) and dead.is_empty():
		score -= 4.0
	# 사냥꾼 준비: 이번 카드로 준비가 쌓이면 다음 공격의 확정 치명타 값어치
	if int(p.prep_after) > battle.hunter_prep and int(p.prep_after) >= P2Catalog.HUNTER_PREP_NEEDED:
		score += 4.0
	return score


# 상태이상 값어치(턴 안에 피해로 안 잡히는 것): 지속 피해는 앞으로 들어올 양, 얼림·약화는 막는 피해, 취약은 다음 공격 몫
static func _status_value(battle: P2Battle, i: int, a: Dictionary, b: Dictionary) -> float:
	var d := func(k: String) -> int:
		return int(b.get(k, 0)) - int(a.get(k, 0))
	var threat := 0
	for h in battle.effective_intent(i):
		threat += int(h)
	var v := 0.0
	v += d.call("burn") * 1.7
	v += d.call("poison") * 2.2
	v += d.call("doom") * battle.doom_mult() * 0.8
	v += d.call("bleed") * 1.4
	v += d.call("chill") * 1.2
	v += maxi(0, d.call("frozen")) * (threat * 1.3 + 2.0)
	v += maxi(0, d.call("vuln")) * 3.0
	v += maxi(0, d.call("weak")) * threat * 0.3
	v += maxi(0, d.call("trap")) * 1.2
	v += maxi(0, d.call("air")) * 3.0
	v += maxi(0, d.call("link")) * 3.0
	v += maxi(0, d.call("umbra")) * 2.0 + maxi(0, d.call("lumen")) * 2.0 + maxi(0, d.call("pcrys")) * 2.5
	return v


# 자신 강화: 손에 남은 공격으로 얻을 몫
static func _buff_value(battle: P2Battle, card: Card) -> float:
	var kind := P2Catalog.kind_of(card)
	var hits := 0
	var dmg := 0
	var mana := battle.mana_now() - card.get_mana_cost()
	for c in battle.hand.cards:
		if c == card or not P2Catalog.is_attack(c) or c.get_mana_cost() > mana:
			continue
		hits += P2Catalog.hits_of(c)
		dmg += c.value * P2Catalog.hits_of(c)
	match kind:
		"blood_pact":
			return dmg * 0.5 - card.value * 0.8
		"war_shout":
			return hits * card.value * 0.8
		"poison_coat":
			return mini(hits, P2Catalog.COAT_HITS) * card.value * 1.5
		"smoke_bomb":
			var big := 0
			for m in battle.alive_monsters():
				for h in battle.effective_intent(m.index):
					big = maxi(big, int(h))
			return big * 1.1 - 1.0
	return 0.0


static func _evaluate(battle: P2Battle, card: Card, t: int, block: int, extra := {}) -> float:
	if P2Catalog.is_buff(card):
		return _buff_value(battle, card) - (card.get_mana_cost() - 1) * 1.5
	var p := battle.preview_ex(card, t, extra)
	var s := _score(battle, card, p, block)
	var crit: Dictionary = p.get("crit", {})
	if not crit.is_empty():
		var c := float(p.crit_chance) / 100.0
		s = (1.0 - c) * s + c * _score(battle, card, crit, block)
	return s


# 연료화: 소진할 카드 하나(가장 덜 필요한 것)를 고르고, 마나 +2로 새로 낼 수 있게 되는 카드가 있을 때만 가치
static func _fuel_choice(battle: P2Battle, fuel: Card) -> Array:
	var mana := battle.mana_now()
	var danger := incoming(battle)
	var worst: Card = null
	var worst_keep := 99.0
	for c in battle.hand.cards:
		if c == fuel:
			continue
		var keep := 2.0 + c.get_mana_cost()
		if c.effect == Card.EffectType.DEFEND:
			keep = 0.5 if danger <= battle.get_pending_defense() else 3.0
		if P2Catalog.retains(c):
			keep = 6.0
		if keep < worst_keep:
			worst_keep = keep
			worst = c
	if worst == null:
		return []
	var enabled := 0
	for c in battle.hand.cards:
		if c == fuel or c == worst:
			continue
		var cost := c.get_mana_cost()
		if P2Catalog.is_x_cost(c) and mana >= 1:
			enabled += 1
		elif cost > mana and cost <= mana + P2Catalog.FUEL_MANA:
			enabled += 1
	if enabled == 0:
		return []
	var score := 2.0 + 2.5 * enabled - worst_keep
	if battle.relics.has("furnace_seal") and not battle.furnace_used:
		score += 3.0
	return [score, {"fuel_uid": P2Catalog.uid_of(worst)}]


static func choose(battle: P2Battle) -> Array:
	var best: Array = []
	var best_score := 0.9
	var block := battle.get_pending_defense()
	for card in battle.hand.cards:
		if not battle.can_play_card(card):
			continue
		if P2Catalog.is_fuel(card):
			var f := _fuel_choice(battle, card)
			if not f.is_empty() and float(f[0]) > best_score:
				best_score = float(f[0])
				best = [card, -1, f[1]]
			continue
		var targets: Array = [-1]
		if P2Catalog.is_targeted(card):
			targets = battle.alive_monsters().map(func(m): return m.index)
		for t in targets:
			var score := _evaluate(battle, card, t, block)
			if score > best_score:
				best_score = score
				best = [card, t]
	return best


static func simple(battle: P2Battle) -> Array:
	var danger := incoming(battle)
	var playable: Array = battle.hand.cards.filter(func(c): return battle.can_play_card(c) and not P2Catalog.is_fuel(c))
	if playable.is_empty():
		return []
	if danger >= 8 and battle.get_pending_defense() < danger:
		for c in playable:
			if c.effect == Card.EffectType.DEFEND:
				return [c, -1]
	var target := -1
	for m in battle.alive_monsters():
		if target < 0 or m.hp < battle.get_monster(target).hp:
			target = m.index
	var best: Card = null
	for c in playable:
		if c.effect != Card.EffectType.DAMAGE:
			continue
		if best == null or battle.card_base_value(c) * P2Catalog.hits_of(c) > battle.card_base_value(best) * P2Catalog.hits_of(best):
			best = c
	if best == null:
		for c in playable:
			if P2Catalog.is_draw(c) and battle.hand.cards.size() < P2Battle.HAND_MAX:
				return [c, -1]
		return []
	return [best, target if P2Catalog.is_targeted(best) else -1]


static func random_legal(battle: P2Battle, rng: RandomNumberGenerator) -> Array:
	var playable: Array = battle.hand.cards.filter(func(c): return battle.can_play_card(c))
	if playable.is_empty() or rng.randf() < 0.15:
		return []
	var c: Card = playable[rng.randi() % playable.size()]
	if P2Catalog.is_fuel(c):
		var others: Array = battle.hand.cards.filter(func(o): return o != c)
		return [c, -1, {"fuel_uid": P2Catalog.uid_of(others[rng.randi() % others.size()])}]
	var t := -1
	if P2Catalog.is_targeted(c):
		var alive := battle.alive_monsters()
		t = alive[rng.randi() % alive.size()].index
	return [c, t]


static func pick(battle: P2Battle, policy: String, rng: RandomNumberGenerator = null) -> Array:
	match policy:
		"simple":
			return simple(battle)
		"random":
			return random_legal(battle, rng)
	return choose(battle)


static func apply_choice(battle: P2Battle, choice: Array) -> bool:
	return battle.play_card_ex(choice[0], choice[1], choice[2] if choice.size() > 2 else {})


# 규칙만으로 전투 하나를 끝까지 (행동마다 저장 훅을 부를 수 있게 콜백을 받는다)
static func play_battle(battle: P2Battle, after_action: Callable = Callable(), max_turns := 40, policy := "greedy", rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 99
	while not battle.battle_over and battle.turn_number <= max_turns:
		var choice := pick(battle, policy, rng)
		if not choice.is_empty():
			if not apply_choice(battle, choice):
				push_error("bot choice rejected: " + P2Catalog.kind_of(choice[0]))
				choice = []
			else:
				if after_action.is_valid():
					after_action.call("card")
				continue
		if not battle.begin_round_resolution():
			break
		if after_action.is_valid():
			after_action.call("begin")
		while bool(battle.take_next_monster_action().get("acted", false)):
			if after_action.is_valid():
				after_action.call("enemy")
			if battle.battle_over:
				break
		if not battle.battle_over:
			battle.finish_round_resolution()
			if after_action.is_valid():
				after_action.call("finish")


static func _first_pref(pref: Array, offered: Array) -> String:
	for x in pref:
		if offered.has(x):
			return x
	return String(offered[0]) if not offered.is_empty() else ""


# 보상 한 부분 선택 (저장된 후보 안에서만)
static func reward_choice(run: Dictionary, path: String) -> Dictionary:
	var parts: Array = run.reward.parts
	var part: Dictionary = parts[int(run.reward.index)]
	var pref := pref_for(String(run.get("class_id", "")), path)
	var sel := {}
	var pick_up := func() -> bool:
		var up := _first_pref(pref.upgrades, part.get("upgrades", []))
		if up == "":
			return false
		sel.upgrade = up
		sel.copy = RunModel.upgrade_candidates(run.deck, up)[0]
		return true
	var pick_relic := func() -> bool:
		var id := _first_pref(pref.relics, part.get("relics", []))
		if id == "":
			return false
		sel.relic = id
		if (run.relics as Array).size() >= P2Catalog.relic_capacity(run):
			sel.replace = _worst_relic(run.relics, pref.relics)
		return true
	match String(part.type):
		"trait":
			if not (part.traits as Array).is_empty():
				sel.trait = String(part.traits[0])
		"card":
			var k := _first_pref(pref.cards, part.cards)
			if k == "" or not RunModel.card_eligible(k, run.deck):
				sel.skip = true
			else:
				sel.card = k
		"upgrade":
			pick_up.call()
		"relic":
			if not pick_relic.call():
				sel.skip = true
		"upgrade_or_heal":
			if int(run.hp) <= int(run.max_hp) / 2 or not pick_up.call():
				sel.clear()
				sel.category = "heal"
			else:
				sel.category = "upgrade"
		"upgrade_or_relic":
			if pick_up.call():
				sel.category = "upgrade"
			elif pick_relic.call():
				sel.category = "relic"
			else:
				sel.category = "gold"
	return sel


static func _worst_relic(held: Array, pref: Array) -> String:
	var worst := String(held[0])
	for id in held:
		var rank := pref.find(id)
		var wrank := pref.find(worst)
		if (rank < 0 and wrank >= 0) or (rank >= 0 and wrank >= 0 and rank > wrank):
			worst = String(id)
	return worst


static func _weakest_copy(deck: Array) -> String:
	for kind in ["guard", "sweep", "bolt", "slash", "focus"]:
		var copies: Array = deck.filter(func(c): return String(c.kind) == kind and String(c.get("upgrade", "")) == "")
		if copies.size() > 0:
			return String(copies[0].uid)
	return String(deck[0].uid)
