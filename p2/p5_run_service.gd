class_name RunModel
extends Node
# 원정(run)과 연습 한 판(field) 상태. 오토로드 이름은 RunService.
# 모든 변경은 SaveManager.transact(reason, fn(c, r, f)) 한 통로로 커밋한다 (c = 프로필 사본, r = 원정 사본, f = 연습 사본).
# 원정 = 구간 I(N1~N4 + 보스) → [여기서 마치기 | 계속: 특성] → 구간 II → [마치기 | 계속] → 구간 III(최종 보스)

signal changed
signal save_failed(reason: String)

var run: Dictionary = {}
var field: Dictionary = {}
var battle: P2Battle = null
# 모든 화면이 함께 쓰는 저장 실패 창 (저장이 실패하는 즉시 뜬다)
var gate: P2Ui.SaveGate

var pending: Dictionary:
	get:
		return SaveManager.pending
var last_error: String:
	get:
		return SaveManager.last_error


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	gate = P2Ui.SaveGate.new(self)
	layer.add_child(gate)
	SaveManager.save_failed.connect(func(reason: String) -> void:
		save_failed.emit(reason)
		gate.run())
	SaveManager.committed.connect(func(_reason: String) -> void: changed.emit())
	# 실행본 점검 드라이버는 --p5-smoke 인자가 있을 때만 붙는다
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--p5-smoke") and ResourceLoader.exists("res://p2/p5_smoke_driver.gd"):
			add_child.call_deferred((load("res://p2/p5_smoke_driver.gd") as GDScript).new())
			break


func clear_all() -> void:
	run = {}
	field = {}
	battle = null


func has_pending() -> bool:
	return SaveManager.has_pending()


func retry_pending() -> bool:
	return SaveManager.retry_pending()


# 원정 밖 거래 (새 원정 준비 · 설정): 쓰기가 실패하면 공용 저장 창이 뜨고, 다시 저장이 성공해야 true
func commit_profile(reason: String, fn: Callable) -> bool:
	SaveManager.last_error = ""
	var ok := SaveManager.transact(reason, fn)
	if not ok and SaveManager.has_pending():
		ok = await gate.run()
	return ok


func _tx(reason: String, fn: Callable) -> bool:
	SaveManager.last_error = ""
	var ok := SaveManager.transact(reason, fn)
	if not ok and SaveManager.last_error == "":
		SaveManager.last_error = "rejected: " + reason
	return ok


func active() -> bool:
	return not run.is_empty()


func field_active() -> bool:
	return not field.is_empty()


# ── 검증 (SaveManager.validate_data가 게시 전에 부른다) ──────────────────────────────

static func _t(d: Dictionary, key: String, type: int) -> bool:
	return d.has(key) and typeof(d[key]) == type


static func deck_shape_errors(deck: Array) -> Array:
	var errors: Array = []
	var uids := {}
	for c in deck:
		if not (c is Dictionary) or not (c.get("kind") is String) or not (c.get("uid") is String) or not (c.get("upgrade", "") is String):
			errors.append("card shape")
			continue
		if not P2Catalog.CARDS.has(String(c.kind)):
			errors.append("card kind " + String(c.kind))
		if uids.has(c.uid):
			errors.append("duplicate uid")
		uids[c.uid] = true
		var up := String(c.get("upgrade", ""))
		if up != "" and (not P2Catalog.UPGRADE_KINDS.has(up) or P2Catalog.UPGRADE_KINDS[up].from != c.kind):
			errors.append("bad upgrade")
	if errors.is_empty():
		errors.append_array(P2Catalog.deck_errors(deck))
	return errors


static func _pile_errors(snap: Dictionary, deck: Array) -> Array:
	var errors: Array = P2Battle.snapshot_errors(snap)
	if not errors.is_empty():
		return errors
	var uids := {}
	for c in deck:
		uids[String(c.uid)] = true
	var piles := {}
	for key in ["hand", "draw", "discard", "exhausted"]:
		for u in snap[key]:
			piles[String(u)] = true
	if piles.size() != uids.size():
		errors.append("battle piles do not match deck")
	for u in piles:
		if not uids.has(u):
			errors.append("battle pile uid not in deck")
	return errors


func validate_run(r: Dictionary) -> Array:
	var errors: Array = []
	for key in ["seed", "hp", "max_hp", "next_uid", "gold", "xp", "spent", "battles", "removals"]:
		if not (r.get(key) is int):
			errors.append("run.%s not int" % key)
	for key in ["deck", "relics", "traits", "defeated", "potions", "log", "trait_offer"]:
		if not _t(r, key, TYPE_ARRAY):
			errors.append("run.%s not array" % key)
	for key in ["loadout", "layout", "battle", "reward", "banked", "kills", "service", "choice", "past"]:
		if not _t(r, key, TYPE_DICTIONARY):
			errors.append("run.%s not dict" % key)
	for key in ["id", "phase", "sector", "route", "encounter", "class_id", "room"]:
		if not _t(r, key, TYPE_STRING):
			errors.append("run.%s not string" % key)
	if not errors.is_empty():
		return errors
	if not P2Catalog.CLASSES.has(String(r.class_id)):
		errors.append("run class")
	var si := P2Catalog.SECTORS.find(String(r.sector))
	if si < 0:
		errors.append("sector")
	if (r.traits as Array).size() < maxi(si, 0) or (r.traits as Array).size() > maxi(si, 0) * 2 + 1:
		errors.append("trait count does not match sector")
	var tseen := {}
	for t in r.traits:
		if not P2Catalog.TRAITS.has(String(t)) or tseen.has(t):
			errors.append("trait")
		tseen[t] = true
	if not (String(r.route) in ["", "a", "b"]):
		errors.append("route")
	if int(r.max_hp) <= 0 or int(r.hp) < 0 or int(r.hp) > int(r.max_hp):
		errors.append("run hp out of range")
	if int(r.gold) < 0 or int(r.xp) < 0 or int(r.spent) < 0:
		errors.append("negative ledger")
	if (r.relics as Array).size() > P2Catalog.relic_capacity(r):
		errors.append("too many relics")
	if not (r.get("stats", {}) is Dictionary) or not (r.get("lv_picks", []) is Array) or int(r.get("lv", 1)) < 1:
		errors.append("run level shape")
	else:
		for k in r.get("stats", {}):
			if not P2Catalog.STATS.has(String(k)):
				errors.append("stat " + String(k))
	var relic_seen := {}
	for id in r.relics:
		if not P2Catalog.RELICS.has(String(id)) or relic_seen.has(id):
			errors.append("relic")
		relic_seen[id] = true
	if (r.potions as Array).size() > P2Catalog.POTION_CAP:
		errors.append("too many potions")
	for p in r.potions:
		if not (p is Dictionary) or not (String(p.get("item", "")) in ["hp_potion", "mana_potion"]) or not (String(p.get("src", "")) in ["supply", "personal", "found"]):
			errors.append("potion shape")
	errors.append_array(deck_shape_errors(r.deck))
	if (r.deck as Array).size() < 1:
		errors.append("empty deck")
	if not (String(r.phase) in ["explore", "battle", "reward", "sector_choice", "portal"]):
		errors.append("phase")
	if String(r.phase) == "battle" and errors.is_empty():
		errors.append_array(_pile_errors(r.battle, r.deck))
	if String(r.phase) == "reward" and ((r.reward as Dictionary).is_empty() or not (r.reward.get("parts") is Array)):
		errors.append("reward phase without offers")
	if String(r.phase) == "sector_choice" and si >= 2:
		errors.append("sector choice after final sector")
	if not (r.layout.get("rooms") is Dictionary) or not (r.layout.get("encounters") is Dictionary):
		errors.append("layout shape")
	return errors


func validate_field(f: Dictionary) -> Array:
	var errors: Array = []
	for key in ["id", "group", "phase", "diff", "sector"]:
		if not _t(f, key, TYPE_STRING):
			errors.append("practice.%s not string" % key)
	for key in ["deck", "log"]:
		if not _t(f, key, TYPE_ARRAY):
			errors.append("practice.%s not array" % key)
	for key in ["battle", "loadout"]:
		if not _t(f, key, TYPE_DICTIONARY):
			errors.append("practice.%s not dict" % key)
	if not (f.get("hp") is int):
		errors.append("practice.hp")
	if not errors.is_empty():
		return errors
	if P2Catalog.practice_sector(String(f.group)) == "" or not P2Catalog.DIFF.has(String(f.diff)):
		errors.append("practice group")
	if String(f.phase) != "battle":
		errors.append("practice phase")
	errors.append_array(deck_shape_errors(f.deck))
	if errors.is_empty():
		errors.append_array(_pile_errors(f.battle, f.deck))
	return errors


# ── 공통: 카드·전투 준비 ─────────────────────────────────────────────────────────

static func cards_of(deck: Array) -> Dictionary:
	var out := {}
	for c in deck:
		out[String(c.uid)] = P2Catalog.make_card(c)
	return out


static func start_deck(class_id: String) -> Array:
	var deck: Array = []
	for k in P2Catalog.class_deck(class_id):
		deck.append({"uid": "c%d" % deck.size(), "kind": k, "upgrade": ""})
	return deck


# 전투용 체력/마나를 GameState flags에 올린다 (전투 범위가 캠페인 값을 붙잡아 둔 뒤에만)
static func _battle_vitals(max_hp: int, hp: int, max_mana: int) -> void:
	GameState.begin_combat_scope()
	GameState.set_flag("player_base_max_hp", max_hp)
	GameState.set_flag("player_max_hp", max_hp)
	GameState.set_flag("player_hp", clampi(hp, 0, max_hp))
	GameState.set_flag("player_max_mana", max_mana)


func battle_hp() -> int:
	return int(GameState.get_flag("player_hp"))


# ── 원정: 입장 ─────────────────────────────────────────────────────────────────

func entry_errors() -> Array:
	var errors: Array = []
	if not run.is_empty():
		errors.append("이미 진행 중인 원정이 있습니다")
	if not field.is_empty():
		errors.append("진행 중인 연습이 있습니다")
	if not P2Catalog.CLASSES.has(String(GameState.combat.get("class_id", ""))):
		errors.append("직업을 고르세요")
	if SaveManager.current_slot <= 0:
		errors.append("프로필이 정해지지 않았습니다")
	return errors


static var today_override := ""


static func today() -> String:
	return today_override if today_override != "" else Time.get_date_string_from_system()


# 오늘의 원정: 날짜로 정해지는 시드 · 직업 · 모드(난이도는 노멀). 몇 번이든 하고 그날 최고 점수를 남긴다
static func daily_spec(date: String) -> Dictionary:
	var h := absi(hash("orsia-daily:" + date))
	var mods: Array = [[], ["hd"], ["dt"], ["mr"], ["hr"], ["hd", "mr"]]
	return {"date": date, "seed": h % 2147483647, "class_id": String(P2Catalog.CLASS_ORDER[h % P2Catalog.CLASS_ORDER.size()]), "diff": "normal",
		"mods": (mods[(h >> 3) % mods.size()] as Array).duplicate()}


# over: 오늘의 원정처럼 직업 · 난이도 · 모드 · 시드를 이번 원정만 바꾼다(고른 값은 그대로 둠). date가 있으면 그날 기록으로
func begin_expedition(seed_value: int = -1, over: Dictionary = {}) -> bool:
	if not entry_errors().is_empty():
		SaveManager.last_error = str(entry_errors())
		return false
	var sd := int(over.seed) if over.has("seed") else (seed_value if seed_value >= 0 else randi() % 2147483647)
	var layout := P2DungeonGen.generate_sector("normal", sd)
	return _tx("enter", func(c, r, _f):
		var src: Dictionary = c
		if over.has("class_id"):
			src = c.duplicate(true)
			src.combat.class_id = String(over.class_id)
		var lo := P5Campaign.build_entry_loadout(src)
		var cid := String(lo.class_id)
		var cb: Dictionary = c.combat
		cb.run_counter = int(cb.run_counter) + 1
		cb.stats.expeditions = int(cb.stats.get("expeditions", 0)) + 1
		lo["potion_heal"] = P5Campaign.potion_heal()
		lo["catalog"] = P2Catalog.CATALOG_VERSION
		var deck := start_deck(cid)
		var cleared: Dictionary = cb.get("diff_clear", {})
		var diff := String(cb.get("diff_pick", "normal"))
		if not P2Catalog.DIFF.has(diff) or not P2Catalog.diff_unlocked(cleared, diff):
			diff = "normal"
		var mods: Array = (cb.get("mods_pick", []) as Array).filter(func(m): return P2Catalog.MOD.has(String(m)))
		if over.has("diff"):
			diff = String(over.diff)
		if over.has("mods"):
			mods = (over.mods as Array).duplicate()
		r.clear()
		r.merge({
			"id": "exp-%d-%d" % [int(cb.run_counter), sd],
			"seed": sd, "class_id": cid, "sector": "normal", "loadout": lo, "layout": layout, "past": {},
			"hp": int(lo.max_hp), "max_hp": int(lo.max_hp), "diff": diff, "mods": mods,
			"deck": deck, "next_uid": deck.size(), "relics": [], "traits": [], "trait_offer": [],
			"potions": [{"item": "hp_potion", "src": "supply"}],
			"gold": 0, "xp": 0, "spent": 0, "removals": 0, "banked": {}, "kills": {},
			"lv": 1, "lv_xp": 0, "stats": {}, "lv_picks": [],
			"defeated": [], "service": _new_service(layout, sd, "normal", cid, deck), "choice": {"picked": ""},
			"route": "", "battles": 0,
			"phase": "explore", "encounter": "", "battle": {}, "reward": {},
			"pos": [], "room": "ent",
			"log": ["원정 시작: %s (시드 %d, 배치 %s%s%s)" % [P2Catalog.CLASSES[cid].name, sd, layout.signature, ", 대체 배치" if layout.fallback else "", ", %s%s" % [P2Catalog.diff_of(diff).name, " + " + "·".join(PackedStringArray(mods.map(func(m): return String(P2Catalog.MOD[m].short)))) if not mods.is_empty() else ""]]],
		})
		if over.has("date"):
			r["daily"] = String(over.date)
		return true)


static func _new_service(_layout: Dictionary, sd: int, sector: String, class_id: String, deck: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%d:%s:shop" % [sd, sector]))
	var offer := card_offer(rng, class_id, deck, false)
	return {"card": String(offer[0]) if not offer.is_empty() else "", "used": []}


# ── 탐험 행동 ──────────────────────────────────────────────────────────────────

func record_position(pos: Vector2, room: String) -> bool:
	if run.is_empty() or String(run.phase) not in ["explore", "portal", "sector_choice"]:
		return false
	return _tx("position", func(_c, r, _f):
		r.pos = [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1)]
		r.room = room
		return true)


func potion_count(item: String = "hp_potion") -> int:
	var src: Array = run.get("potions", [])
	return src.filter(func(p): return String(p.item) == item).size()


# 쓸 물약 순서: 원정에서 얻은 것 → 보급 → 개인 (개인 물약은 남으면 돌려받으므로 맨 나중)
static func _potion_index(potions: Array, item: String) -> int:
	for src in ["found", "supply", "personal"]:
		for i in range(potions.size()):
			if String(potions[i].item) == item and String(potions[i].src) == src:
				return i
	return -1


# 탐색 중 회복약 (마나 물약은 탐색 중 쓸 수 없음). 체력이 가득이면 쓰지 않는다
func use_heal_charge() -> bool:
	if run.is_empty() or String(run.phase) != "explore":
		return false
	return _tx("potion", func(_c, r, _f):
		var i := _potion_index(r.potions, "hp_potion")
		if i < 0 or int(r.hp) >= int(r.max_hp):
			return false
		var before := int(r.hp)
		r.hp = mini(int(r.max_hp), int(r.hp) + int(r.loadout.potion_heal))
		r.potions.remove_at(i)
		r.log.append("회복약 +%d" % (int(r.hp) - before))
		return true)


func requirements_met(req: Array) -> bool:
	for id in req:
		if not (run.defeated as Array).has(id):
			return false
	return true


# 하드 구간 갈림길: 한쪽 통로를 고르면 다른 쪽은 이 원정 동안 봉인된다
func commit_route(route: String) -> bool:
	if run.is_empty() or String(run.sector) != "hard" or String(run.phase) != "explore" or String(run.route) != "":
		return false
	if not (route in ["a", "b"]):
		return false
	return _tx("route", func(_c, r, _f):
		r.route = route
		r.log.append("하드 구간 경로 확정: %s" % P2Catalog.GROUPS["h1" + route].name)
		return true)


func open_bar() -> bool:
	if run.is_empty() or String(run.phase) != "explore" or (run.get("opened", []) as Array).has("bar"):
		return false
	if not requirements_met(["elite"]):
		return false
	return _tx("bar", func(_c, r, _f):
		var opened: Array = r.get("opened", [])
		opened.append("bar")
		r["opened"] = opened
		return true)


# ── 상인 (서비스 지점) ──────────────────────────────────────────────────────────

func service_unlocked() -> bool:
	if run.is_empty():
		return false
	var need := String(P2Catalog.SERVICE_AFTER.get(String(run.sector), ""))
	if need == "h1":
		return (run.defeated as Array).has("h1a") or (run.defeated as Array).has("h1b")
	return (run.defeated as Array).has(need)


func service_used(what: String) -> bool:
	return (run.get("service", {}).get("used", []) as Array).has(what)


func removal_price() -> int:
	return P2Catalog.SHOP_REMOVE + P2Catalog.SHOP_REMOVE_STEP * int(run.get("removals", 0))


func heal_amount_shop() -> int:
	return int(ceil(float(run.max_hp) * P2Catalog.SHOP_HEAL_FRACTION))


# 각 서비스가 지금 막힌 이유 (빈 문자열이면 가능)
func service_block(what: String) -> String:
	if run.is_empty() or String(run.phase) != "explore":
		return "지금은 이용할 수 없습니다"
	if not service_unlocked():
		return "앞 전투를 이겨야 열립니다"
	if service_used(what):
		return "이미 이용했습니다"
	var price: int = {"card": P2Catalog.SHOP_CARD, "upgrade": P2Catalog.SHOP_UPGRADE, "heal": P2Catalog.SHOP_HEAL, "remove": removal_price()}[what]
	if int(run.gold) < price:
		return "이번 구간 금화 부족 (%d 필요, %d 보유)" % [price, int(run.gold)]
	match what:
		"card":
			var k := String(run.service.get("card", ""))
			if k == "" or not card_eligible(k, run.deck):
				return "진열된 카드가 지금 덱 규칙(사본 수)에 맞지 않습니다"
		"upgrade":
			if upgradable_copies(run.deck).is_empty():
				return "강화할 수 있는 사본이 없습니다"
		"heal":
			if int(run.hp) >= int(run.max_hp):
				return "체력이 가득합니다"
		"remove":
			if (run.deck as Array).size() <= P2Catalog.MIN_DECK:
				return "덱이 %d장 이하면 제거할 수 없습니다" % P2Catalog.MIN_DECK
	return ""


func shop_buy(what: String, sel: Dictionary = {}) -> bool:
	if service_block(what) != "":
		return false
	return _tx("shop", func(_c, r, _f):
		var price: int = {"card": P2Catalog.SHOP_CARD, "upgrade": P2Catalog.SHOP_UPGRADE, "heal": P2Catalog.SHOP_HEAL,
			"remove": P2Catalog.SHOP_REMOVE + P2Catalog.SHOP_REMOVE_STEP * int(r.removals)}[what]
		match what:
			"card":
				if not _add_card(r, String(r.service.card)):
					return false
			"upgrade":
				if not _apply_upgrade(r, String(sel.get("upgrade", "")), String(sel.get("copy", "")), []):
					return false
			"heal":
				var before := int(r.hp)
				r.hp = mini(int(r.max_hp), int(r.hp) + int(ceil(float(r.max_hp) * P2Catalog.SHOP_HEAL_FRACTION)))
				r.log.append("상인 회복 +%d" % (int(r.hp) - before))
			"remove":
				var uid := String(sel.get("copy", ""))
				var idx := -1
				for i in range((r.deck as Array).size()):
					if String(r.deck[i].uid) == uid:
						idx = i
				if idx < 0 or (r.deck as Array).size() <= P2Catalog.MIN_DECK:
					return false
				r.log.append("카드 제거: %s" % P2Catalog.card_name(String(r.deck[idx].kind), String(r.deck[idx].upgrade)))
				r.deck.remove_at(idx)
				r.removals = int(r.removals) + 1
		r.gold = int(r.gold) - price
		r.spent = int(r.spent) + price
		r.service.used.append(what)
		return true)


# ── 선택 지점 ─────────────────────────────────────────────────────────────────

# 이번 구간의 사건: 원정 시드로 여섯을 섞어 구간 순서대로 하나씩(겹치지 않음). 선택 전투가 없는 구간이면 도전장은 건너뜀
static var event_force := ""


static func event_of(r: Dictionary) -> String:
	if event_force != "":
		return event_force
	var order: Array = P2Catalog.EVENT_ORDER.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%d:events" % int(r.get("seed", 0))))
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = order[i]
		order[i] = order[j]
		order[j] = t
	var si := maxi(0, ["normal", "hard", "extreme"].find(String(r.get("sector", "normal"))))
	var elite := (r.get("layout", {}).get("encounters", {}) as Dictionary).has("elite")
	for k in range(order.size()):
		var ev := String(order[(si + k) % order.size()])
		if ev != "challenge" or elite:
			return ev
	return "supply"


func choice_block(what: String) -> String:
	if run.is_empty() or String(run.phase) != "explore":
		return "지금은 고를 수 없습니다"
	if String(run.choice.get("picked", "")) != "":
		return "이미 골랐습니다"
	if not (P2Catalog.EVENTS[event_of(run)].opts as Array).has(what):
		return "이 사건에는 없는 선택입니다"
	match what:
		"chest_potion":
			if (run.potions as Array).size() >= P2Catalog.POTION_CAP:
				return "물약이 가득합니다 (최대 %d개)" % P2Catalog.POTION_CAP
		"sacrifice":
			if int(run.hp) <= P2Catalog.SACRIFICE_HP:
				return "체력이 %d보다 많아야 합니다" % P2Catalog.SACRIFICE_HP
			if upgradable_copies(run.deck).is_empty():
				return "강화할 수 있는 사본이 없습니다"
		"risk":
			if not run.layout.encounters.has("elite") or (run.defeated as Array).has("elite"):
				return "이 구간의 선택 전투가 이미 끝났습니다"
		"forge_gold":
			if int(run.gold) < P2Catalog.FORGE_GOLD:
				return "미확정 금화가 %d 있어야 합니다" % P2Catalog.FORGE_GOLD
			if upgradable_copies(run.deck).is_empty():
				return "강화할 수 있는 사본이 없습니다"
		"altar_relic":
			if int(run.max_hp) <= P2Catalog.ALTAR_MAXHP + 12:
				return "최대 체력이 너무 낮습니다"
		"altar_pray":
			if int(run.hp) >= int(run.max_hp):
				return "체력이 가득합니다"
		"burn_card":
			if (run.deck as Array).size() <= P2Catalog.MIN_DECK:
				return "덱이 최소 장수입니다"
		"echo_stat":
			if int(run.hp) <= P2Catalog.ECHO_HP:
				return "체력이 %d보다 많아야 합니다" % P2Catalog.ECHO_HP
	return ""


func choose_event(what: String, sel: Dictionary = {}) -> bool:
	if choice_block(what) != "":
		return false
	return _tx("choice", func(_c, r, _f):
		match what:
			"chest_gold":
				r.gold = int(r.gold) + P2Catalog.CHEST_GOLD
				r.log.append("상자: 금화 %d (미정산)" % P2Catalog.CHEST_GOLD)
			"chest_potion":
				r.potions.append({"item": "hp_potion", "src": "found"})
				r.log.append("상자: 회복약 1")
			"sacrifice":
				if not _apply_upgrade(r, String(sel.get("upgrade", "")), String(sel.get("copy", "")), []):
					return false
				r.hp = int(r.hp) - P2Catalog.SACRIFICE_HP
				r.log.append("체력 %d를 내고 강화" % P2Catalog.SACRIFICE_HP)
			"risk":
				r.layout.encounters.elite["risk"] = true
				r.log.append("선택 전투 강화: 적 공격 +%d, 보상에 유물 보장" % P2Catalog.RISK_ATTACK)
			"forge_gold":
				if not _apply_upgrade(r, String(sel.get("upgrade", "")), String(sel.get("copy", "")), []):
					return false
				r.gold = int(r.gold) - P2Catalog.FORGE_GOLD
				r.spent = int(r.spent) + P2Catalog.FORGE_GOLD
				r.log.append("금화 %d를 내고 강화" % P2Catalog.FORGE_GOLD)
			"tear":
				r.gold = int(r.gold) + P2Catalog.TEAR_GOLD
				r.log.append("도전장을 찢음: 금화 %d (미정산)" % P2Catalog.TEAR_GOLD)
			"altar_relic":
				var offer := relic_offer(_reward_rng(r, "event", "relic"), r, false)
				if offer.is_empty():
					return false
				r.max_hp = int(r.max_hp) - P2Catalog.ALTAR_MAXHP
				r.hp = mini(int(r.hp), int(r.max_hp))
				r.reward = {"id": "event", "parts": [{"type": "relic", "relics": offer, "required": true}], "index": 0, "after": "explore"}
				r.phase = "reward"
				r.log.append("제단: 최대 체력 −%d → 유물 고르기" % P2Catalog.ALTAR_MAXHP)
			"altar_pray":
				var before := int(r.hp)
				r.hp = mini(int(r.max_hp), int(r.hp) + P2Catalog.ALTAR_HEAL)
				r.log.append("제단 기도: 체력 +%d" % (int(r.hp) - before))
			"burn_card":
				var idx := -1
				for k in range((r.deck as Array).size()):
					if String(r.deck[k].uid) == String(sel.get("copy", "")):
						idx = k
				if idx < 0 or (r.deck as Array).size() <= P2Catalog.MIN_DECK:
					return false
				r.log.append("서고에서 카드를 태움: %s" % P2Catalog.card_name(String(r.deck[idx].kind), String(r.deck[idx].upgrade)))
				r.deck.remove_at(idx)
			"copy_card":
				var cards := card_offer(_reward_rng(r, "event", "card"), String(r.class_id), r.deck, false)
				if cards.is_empty():
					return false
				r.reward = {"id": "event", "parts": [{"type": "card", "cards": cards}], "index": 0, "after": "explore"}
				r.phase = "reward"
				r.log.append("서고: 카드 필사 → 고르기")
			"echo_stat":
				r.hp = int(r.hp) - P2Catalog.ECHO_HP
				var picks: Array = r.get("lv_picks", [])
				picks.append(stat_offer(r, 100 + int(r.get("lv", 1)) + picks.size()))
				r["lv_picks"] = picks
				r.log.append("메아리: 체력 −%d → 능력치 한 번 더" % P2Catalog.ECHO_HP)
			"echo_xp":
				gain_run_xp(r, P2Catalog.ECHO_XP)
				r.log.append("메아리: 경험치 +%d" % P2Catalog.ECHO_XP)
		r.choice.picked = what
		return true)


# ── 전투 (원정) ────────────────────────────────────────────────────────────────

func encounter_requires(id: String) -> Array:
	return run.layout.encounters[id].get("requires", [])


func can_start_encounter(id: String) -> bool:
	if run.is_empty() or String(run.phase) != "explore":
		return false
	if not run.layout.encounters.has(id) or (run.defeated as Array).has(id):
		return false
	if id in ["h1a", "h1b"] and String(run.route) != id.substr(2):
		return false
	if id == "h2" and (String(run.route) == "" or not (run.defeated as Array).has("h1" + String(run.route))):
		return false
	return requirements_met(encounter_requires(id))


func encounter_seed(id: String) -> int:
	return abs(hash("%d:%s:%s:battle" % [int(run.seed), String(run.sector), id])) % 2147483647


func onboarding_anchors(id: String) -> Array:
	var cid := String(run.class_id)
	if id != "n1" or String(run.sector) != "normal" or bool(GameState.combat.get("onboarded", {}).get(cid, false)):
		return []
	return (P2Catalog.CLASSES[cid].anchors as Array).duplicate()


func run_max_mana(r: Dictionary = run) -> int:
	return P2Catalog.run_max_mana(String(r.class_id), r.relics)


func _run_opts(r: Dictionary, id: String) -> Dictionary:
	var lo: Dictionary = r.loadout
	var e: Dictionary = r.layout.encounters.get(id, {})
	var dm := P2Catalog.diff_of(String(r.get("diff", "normal")))
	var mods: Array = r.get("mods", [])
	var st: Dictionary = P2Catalog.stats_with_relics(r.get("stats", {}), r.get("relics", []))
	var lv := P2Catalog.relic_levels(r.get("relics", []))
	return {"class_id": String(r.class_id), "stats": st, "relic_lv": lv, "traits": r.traits,
		"source": "expedition", "max_mana": run_max_mana(r), "encounter_id": id,
		"attack_bonus": P2Catalog.RISK_ATTACK if bool(e.get("risk", false)) else 0,
		"hit_mult": float(P2Catalog.SECTOR_HIT_MULT.get(String(r.sector), 1.0)) * float(dm.hit),
		"hp_mult": diff_hp_mult(r), "rank_hp": P2Catalog.diff_of(String(r.get("diff", "normal"))).get("rank_hp", {}), "ult": int(r.get("ult", 0)), "trait_spent": (r.get("trait_spent", []) as Array).duplicate(), "judge_mult": float(dm.judge) * (0.8 if mods.has("hr") else 1.0) * (1.0 + int(st.get("focus", 0)) / 100.0),
		"approach_mult": float(dm.approach), "pattern_level": int(dm.pattern) + (1 if int(lv.get("mad_drum", 0)) > 0 else 0), "mods": mods.duplicate(),
		"affixes": encounter_affixes(r, id), "heal_cap": int(dm.get("heal_cap", P2Battle.COMBO_HEAL_CAP))}


# 적 성향: 원정 시드 · 구간 · 전투로 정해져 다시 불러와도 같다. 적 자리마다 "" 또는 성향 하나
static func encounter_affixes(r: Dictionary, id: String) -> Array:
	var level := int(P2Catalog.diff_of(String(r.get("diff", "normal"))).get("affix", 0))
	var gid := String((r.layout.encounters.get(id, {}) as Dictionary).get("group", ""))
	var enemies: Array = (P2Catalog.GROUPS.get(gid, {}) as Dictionary).get("enemies", [])
	var out: Array = []
	out.resize(enemies.size())
	out.fill("")
	var regular := gid in P2Catalog.REGULAR_GROUPS
	if level <= 0 or enemies.is_empty() or not (regular or (gid in P2Catalog.ELITE_GROUPS and level >= 2)):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%d:%s:%s:affix" % [int(r.seed), String(r.sector), id]))
	var pool: Array = P2Catalog.AFFIXES
	if regular and level >= 2:
		for i in range(out.size()):
			out[i] = pool[rng.randi() % pool.size()]
	else:
		out[rng.randi() % out.size()] = pool[rng.randi() % pool.size()]
	return out


# 난이도의 적 체력 배율
static func diff_hp_mult(r: Dictionary) -> float:
	return float(P2Catalog.diff_of(String(r.get("diff", "normal"))).hp)


# 켠 모드마다 금화 +10%
static func mod_gold(r: Dictionary, g: int) -> int:
	return roundi(g * (1.0 + P2Catalog.MOD_GOLD * (r.get("mods", []) as Array).size()))


# 최종 보스를 잡으면 그 난이도 배지. 처음 깼으면 그 난이도, 그로써 새로 열린 난이도를 돌려준다
static func diff_clear(c: Dictionary, r: Dictionary) -> Dictionary:
	var diff := String(r.get("diff", "normal"))
	var cleared: Dictionary = c.combat.get("diff_clear", {})
	var first := not bool(cleared.get(diff, false))
	cleared[diff] = true
	c.combat["diff_clear"] = cleared
	var opened := ""
	for k in P2Catalog.DIFF_NEEDS:
		if String(P2Catalog.DIFF_NEEDS[k]) == diff and first:
			opened = String(k)
	return {"badge": diff if first else "", "opened": opened}


# 원정 점수·랭크: 전투 정확도 · 최고 연속 · 정복한 구간 · 남은 체력 × 난이도 · 모드. 랭크는 진행과 정확도로
static func run_score(r: Dictionary, reason: String) -> Dictionary:
	var rl: Array = r.get("rhythm", [])
	var acc := 0.0
	var best := 0
	for e in rl:
		acc += float(e.get("acc", 0))
		best = maxi(best, int(e.get("best", 0)))
	var avg := acc / rl.size() if not rl.is_empty() else 0.0
	var cleared := (r.get("banked", {}) as Dictionary).size()
	var hp := int(r.get("hp", 0)) if reason in ["clear", "return"] else 0
	var base := roundi(avg * 10.0) * rl.size() + best * 20 + cleared * 1500 + hp * 25
	var mult := float(P2Catalog.diff_of(String(r.get("diff", "normal"))).score) * (1.0 + P2Catalog.MOD_GOLD * (r.get("mods", []) as Array).size())
	var rank := "D"
	if cleared >= 3 and avg >= 95.0:
		rank = "S"
	elif (cleared >= 3 and avg >= 85.0) or (cleared >= 2 and avg >= 95.0):
		rank = "A"
	elif (cleared >= 2 and avg >= 75.0) or (cleared >= 1 and avg >= 90.0):
		rank = "B"
	elif cleared >= 1:
		rank = "C"
	return {"score": roundi(base * mult), "rank": rank, "acc": roundi(avg), "best": best, "cleared": cleared, "fights": rl.size()}


# 보스 기록은 난이도마다 따로 (노멀은 예전처럼 적 이름만)
static func boss_key(enc: String, diff: String) -> String:
	return enc if diff == "normal" or diff == "" else "%s@%s" % [enc, diff]


func start_encounter(id: String) -> bool:
	if not can_start_encounter(id):
		SaveManager.last_error = "encounter not allowed: " + id
		return false
	var e: Dictionary = run.layout.encounters[id]
	var group: Dictionary = P2Catalog.GROUPS[e.group]
	var cards_by_uid := cards_of(run.deck)
	var cards: Array[Card] = []
	for c in run.deck:
		cards.append(cards_by_uid[String(c.uid)])
	var opts := _run_opts(run, id)
	opts["anchors"] = onboarding_anchors(id)
	_battle_vitals(int(run.max_hp), int(run.hp), int(opts.max_mana))
	var b := P2Battle.new({"enemies": group.enemies, "offsets": group.offsets}, cards,
		Array(run.relics, TYPE_STRING, "", null), encounter_seed(id), opts)
	b.start()
	var snap := b.to_dict()
	var anchored := not (opts.anchors as Array).is_empty()
	var cid := String(run.class_id)
	battle = b
	var gid := String(e.group)
	return _tx("start battle", func(c, r, _f):
		var seen: Array = c.combat.get("seen_groups", [])
		if not seen.has(gid):
			seen.append(gid)
			c.combat["seen_groups"] = seen
		var met: Array = c.combat.get("seen_enemies", [])
		for role in group.enemies:
			if not met.has(String(role)):
				met.append(String(role))
		c.combat["seen_enemies"] = met
		r["battle_hp0"] = int(r.hp)
		r.phase = "battle"
		r.encounter = id
		r.battles = int(r.battles) + 1
		r.battle = snap
		if anchored:
			c.combat.onboarded[cid] = true
		r.log.append("전투 시작: %s (%s)%s" % [id, group.name, " · 직업 핵심 카드 첫 손패" if anchored else ""])
		return true)


# 다시 켰을 때: 저장된 스냅숏으로 전투 객체를 다시 만든다 (시작 효과를 다시 적용하지 않는다)
func restore_battle() -> P2Battle:
	if not field.is_empty() and String(field.phase) == "battle":
		var lo: Dictionary = field.loadout
		_battle_vitals(int(lo.max_hp), int(field.battle.hp), int(field.battle.max_mana))
		battle = P2Battle.from_dict(field.battle, cards_of(field.deck))
		return battle
	if run.is_empty() or String(run.phase) != "battle":
		return null
	_battle_vitals(int(run.max_hp), int(run.battle.hp), int(run.battle.max_mana))
	battle = P2Battle.from_dict(run.battle, cards_of(run.deck))
	return battle


# 행동 하나(카드 한 장, 적 하나의 행동, 라운드 마감, 물약)가 끝날 때마다 부른다
func commit_battle(reason: String = "battle action") -> bool:
	if battle == null:
		return false
	if not field.is_empty():
		return _commit_field(reason)
	if run.is_empty() or String(run.phase) != "battle":
		return false
	var b := battle
	var snap := b.to_dict()
	var over := b.battle_over
	var hp := battle_hp()
	var won := over and hp > 0
	var casualties := b.casualties()
	return _tx(reason, func(c, r, _f):
		r.battle = snap
		r.hp = mini(hp, int(r.max_hp))
		if not over:
			return true
		if won:
			r["ult"] = b.ult
			if b.last_stand_spent and not (r.get("trait_spent", []) as Array).has("last_stand"):
				r["trait_spent"] = (r.get("trait_spent", []) as Array) + ["last_stand"]
			_on_victory(c, r, casualties)
		else:
			r.log.append("%s 패배" % String(r.encounter))
			_end_expedition(c, r, "lost")
		return true)


func battle_finished_committed() -> bool:
	if not field.is_empty():
		return false
	return run.is_empty() or String(run.phase) != "battle"


# 전투 중 물약 (자기 턴에 턴당 하나, 마나 비용 없음). 연습에서는 쓰지 않는다
func can_use_battle_potion(item: String) -> String:
	if battle == null or battle.battle_over or battle._resolving:
		return "지금은 쓸 수 없습니다"
	if battle.potion_turn == battle.turn_number:
		return "이번 턴에 이미 물약을 썼습니다"
	if not field.is_empty():
		return "연습에서는 물약을 쓰지 않습니다"
	if _potion_index(run.get("potions", []), item) < 0:
		return "가진 물약이 없습니다"
	if item == "hp_potion" and battle.player_hp() >= int(GameState.get_flag("player_max_hp")) and battle.poison_ticks <= 0 and not battle.hex_active and not battle.hex_next:
		return "체력이 가득하고 해제할 상태도 없습니다"
	if item == "mana_potion" and battle.mana_now() >= battle.max_mana:
		return "마나가 가득합니다"
	return ""


func use_battle_potion(item: String) -> bool:
	if can_use_battle_potion(item) != "":
		return false
	if item == "hp_potion":
		battle.use_potion(int(run.loadout.get("potion_heal", P5Campaign.potion_heal())))
	else:
		battle.use_mana_potion(P5Campaign.MANA_POTION_AMOUNT)
	battle.potion_turn = battle.turn_number
	var snap := battle.to_dict()
	var hp := battle_hp()
	return _tx("potion", func(_c, r, _f):
		var i := _potion_index(r.potions, item)
		if i < 0:
			return false
		r.potions.remove_at(i)
		r.battle = snap
		r.hp = hp
		return true)


# ── 승리·정산 ──────────────────────────────────────────────────────────────────

static func _reward_key(id: String) -> String:
	return "opt" if id == "elite" else id


static func is_boss(id: String) -> bool:
	return id in ["boss", "hboss", "xboss"]


static func pay_for(sector: String, id: String) -> Array:
	if id == "elite":
		return [P2Catalog.OPT_GOLD, P2Catalog.OPT_XP]
	return P2Catalog.PAY[sector]["boss" if is_boss(id) else "fight"]


func _on_victory(c: Dictionary, r: Dictionary, casualties: Dictionary) -> void:
	var id := String(r.encounter)
	var sector := String(r.sector)
	r.defeated.append(id)
	r.battle = {}
	r.encounter = ""
	for fam in casualties:
		r.kills[fam] = int(r.kills.get(fam, 0)) + int(casualties[fam])
	var pay := pay_for(sector, id)
	r.gold = int(r.gold) + mod_gold(r, int(pay[0]))
	r.xp = int(r.xp) + int(pay[1])
	if not (is_boss(id) and sector == "extreme"):
		gain_run_xp(r, run_xp_for(id))
	if is_boss(id):
		_bank_sector(c, r, sector)
		var ev: Array = []
		if int(r.hp) >= int(r.get("battle_hp0", 0)):
			ev.append("no_hit_boss")
		if sector == "normal":
			var cls: Array = c.combat.get("boss_classes", [])
			if not cls.has(String(r.class_id)):
				cls.append(String(r.class_id))
			c.combat["boss_classes"] = cls
		_note_achievements(c, r, unlock_achievements(c, ev))
		if sector == "extreme":
			r["diff_result"] = diff_clear(c, r)
			_end_expedition(c, r, "clear", true)
			r.phase = "portal"
			r.log.append("최종 보스 격파 → 최종 정산 완료")
			return
		r.trait_offer = trait_offer(r)
		var parts: Array = build_parts(r, id)
		if parts.is_empty():
			r.phase = "sector_choice"
		else:
			r.reward = {"id": id, "parts": parts, "index": 0, "after": "sector_choice"}
			r.phase = "reward"
		r.log.append("%s 보스 격파 → 정산 완료" % P2Catalog.SECTOR_NAMES[sector])
		return
	r.reward = {"id": id, "parts": build_parts(r, id), "index": 0, "after": "explore"}
	r.phase = "reward"
	r.log.append("%s 승리 → 보상 대기 (체력 %d)" % [id, int(r.hp)])


static func run_xp_for(id: String) -> int:
	return int(P2Catalog.RUN_XP["boss" if is_boss(id) else ("opt" if id == "elite" else "fight")])


# 원정 레벨: 오른 레벨마다 능력치 후보 셋을 쌓는다(고르기는 choose_stat, 미뤄도 됨)
static func gain_run_xp(r: Dictionary, n: int) -> int:
	var lv := int(r.get("lv", 1))
	var xp := int(r.get("lv_xp", 0)) + n
	var picks: Array = r.get("lv_picks", [])
	var gained := 0
	while xp >= P2Catalog.lv_need(lv):
		xp -= P2Catalog.lv_need(lv)
		lv += 1
		gained += 1
		picks.append(stat_offer(r, lv))
	r["lv"] = lv
	r["lv_xp"] = xp
	r["lv_picks"] = picks
	if gained > 0:
		r.log.append("원정 레벨 %d (경험치 +%d)" % [lv, n])
	return gained


static func stat_offer(r: Dictionary, lv: int) -> Array:
	var rng := _reward_rng(r, "lv%d" % lv, "stat")
	var st: Dictionary = r.get("stats", {})
	var weights: Dictionary = P2Catalog.CLASS_STAT_WEIGHT.get(String(r.class_id), {})
	var pool: Array = P2Catalog.STAT_ORDER.filter(func(k): return int(st.get(k, 0)) < int(P2Catalog.STAT_CAP.get(k, 999)))
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var total := 0
		for k in pool:
			total += int(weights.get(k, 1))
		var roll := rng.randi_range(1, total)
		for k in pool:
			roll -= int(weights.get(k, 1))
			if roll <= 0:
				var rare := rng.randi_range(1, 100) <= P2Catalog.STAT_RARE_CHANCE
				out.append({"stat": String(k), "amount": int(P2Catalog.STATS[k].step) * (2 if rare else 1), "rare": rare})
				pool.erase(k)
				break
	return out


func stat_pending() -> int:
	return (run.get("lv_picks", []) as Array).size() if not run.is_empty() else 0


func choose_stat(id: String) -> bool:
	if run.is_empty() or String(run.phase) == "battle" or stat_pending() == 0:
		return false
	return _tx("stat", func(_c, r, _f):
		var picks: Array = r.lv_picks
		for o in picks[0]:
			if String(o.stat) != id:
				continue
			var st: Dictionary = r.stats
			var amount := int(o.amount)
			st[id] = int(st.get(id, 0)) + amount
			if id == "vit":
				r.max_hp = int(r.max_hp) + amount
				r.hp = int(r.hp) + amount
			picks.pop_front()
			r.log.append("능력치: %s +%d" % [P2Catalog.STATS[id].name, amount])
			return true
		return false)


# 구간 보스를 이기면 그 구간 기록을 한 번 남긴다 (결과 화면이 보여 줌)
func _bank_sector(c: Dictionary, r: Dictionary, sector: String) -> void:
	var key := "%s:%s" % [String(r.id), sector]
	if not P5Campaign.record_event(c, key):
		return
	var stat: String = {"normal": "normal_clears", "hard": "hard_clears", "extreme": "extreme_clears"}[sector]
	c.combat.stats[stat] = int(c.combat.stats.get(stat, 0)) + 1
	r.banked[sector] = {"sector": sector, "gold": int(r.gold), "xp": int(r.xp), "spent": int(r.spent)}
	r.gold = 0
	r.xp = 0
	r.spent = 0
	r.kills = {}


func _end_expedition(c: Dictionary, r: Dictionary, reason: String, keep_run := false) -> void:
	var key := "%s:end" % String(r.id)
	if P5Campaign.record_event(c, key):
		var hp := 0 if reason == "lost" else int(r.hp)
		var stat: String = {"lost": "lost", "abandon": "abandoned", "return": "returned", "clear": "returned"}.get(reason, "")
		# 원정 점수: 난이도마다 최고 점수를 남긴다
		var sc := run_score(r, reason)
		var diff := String(r.get("diff", "normal"))
		var daily := String(r.get("daily", ""))
		# 오늘의 원정은 그날 기록에만(난이도 최고 점수와 따로)
		var bs: Dictionary = c.combat.get("daily", {}) if daily != "" else c.combat.get("best_score", {})
		var bkey := daily if daily != "" else diff
		var prev := int((bs.get(bkey, {}) as Dictionary).get("score", 0))
		sc["prev_best"] = prev
		sc["new_best"] = not bs.has(bkey) or int(sc.score) > prev
		if bool(sc.new_best):
			bs[bkey] = {"score": int(sc.score), "rank": String(sc.rank), "class_id": String(r.class_id), "mods": (r.get("mods", []) as Array).duplicate()}
			if daily != "":
				var days: Array = bs.keys()
				days.sort()
				while days.size() > 14:
					bs.erase(days.pop_front())
			c.combat["daily" if daily != "" else "best_score"] = bs
		if stat != "":
			c.combat.stats[stat] = int(c.combat.stats.get(stat, 0)) + 1
		var summary := {"run_id": String(r.id), "result": reason, "sector": String(r.sector),
			"banked": (r.banked as Dictionary).duplicate(true),
			"forfeit": {"gold": int(r.gold), "xp": int(r.xp), "kills": (r.kills as Dictionary).duplicate()} if reason in ["lost", "abandon"] else {},
			"hp": hp, "build": build_summary(r), "class_id": String(r.class_id),
			"traits": (r.traits as Array).duplicate(), "seed": int(r.seed), "level": int(r.get("lv", 1)),
			"diff": String(r.get("diff", "normal")), "mods": (r.get("mods", []) as Array).duplicate(),
			"diff_result": (r.get("diff_result", {}) as Dictionary).duplicate(), "score": sc,
			"rhythm": (r.get("rhythm", []) as Array).duplicate(true), "date": today(), "daily": daily}
		var hist: Array = c.combat.history
		hist.append(summary)
		while hist.size() > 12:
			hist.pop_front()
		_note_achievements(c, r, unlock_achievements(c, ["mods_clear"] if reason == "clear" and not (r.get("mods", []) as Array).is_empty() else []))
		summary["achv"] = (r.get("achv", []) as Array).duplicate()
		c.combat.last_result = summary
		r["settlement"] = summary
	if not keep_run:
		r.clear()


# 전투 성적 한 줄(등급·정확도·최대 연속·연속 회복)을 원정 기록에 남긴다. 원정 끝 결과 화면이 모아 보여 준다
func record_rhythm(entry: Dictionary) -> bool:
	if not active():
		return practice_ended() and _record_practice(entry)
	return _record_run_rhythm(entry)


func _record_run_rhythm(entry: Dictionary) -> bool:
	return _tx("rhythm", func(c, r, _f):
		var rl: Array = r.get("rhythm", [])
		rl.append(entry.duplicate())
		r["rhythm"] = rl
		_note_achievements(c, r, unlock_achievements(c, ["combo_50"] if int(entry.get("best", 0)) >= 50 else []))
		# 보스는 캠페인에 최고 기록(등급 → 정확도 순)을 남긴다
		if is_boss(String(entry.get("enc", ""))):
			var bb: Dictionary = c.combat.get("boss_best", {})
			var key := boss_key(String(entry.enc), String(r.get("diff", "normal")))
			var old: Dictionary = bb.get(key, {})
			if rhythm_better(entry, old):
				bb[key] = {"grade": String(entry.grade), "acc": int(entry.acc), "best": maxi(int(entry.best), int(old.get("best", 0)))}
			elif int(entry.best) > int(old.get("best", 0)):
				old["best"] = int(entry.best)
				bb[key] = old
			c.combat["boss_best"] = bb
			_note_achievements(c, r, unlock_achievements(c))
		return true)


# ── 도전과제 ────────────────────────────────────────────────────────────────────

# 저장된 기록으로 볼 수 있는 것은 여기서 다시 보고(놓쳐도 다음에 열림), 순간 사건(무피해 보스 · 연속 50 · 모드 정복)은 events로. 새로 연 것을 돌려준다
static func unlock_achievements(c: Dictionary, events: Array = []) -> Array:
	var cb: Dictionary = c.combat
	var got: Dictionary = cb.get("achievements", {})
	var hist: Array = cb.get("history", [])
	var cleared: Dictionary = cb.get("diff_clear", {})
	var daily: Dictionary = cb.get("daily", {})
	var classes: Array = cb.get("boss_classes", [])
	var s_of := func(d: Dictionary) -> bool: return d.values().any(func(b): return String((b as Dictionary).get("grade", "")) == "S")
	var have := {
		"first_run": not hist.is_empty(),
		"sector1": not classes.is_empty() or hist.any(func(h): return (h.get("banked", {}) as Dictionary).has("normal")),
		"clear_normal": bool(cleared.get("normal", false)), "clear_hard": bool(cleared.get("hard", false)), "clear_extreme": bool(cleared.get("extreme", false)),
		"rank_s": hist.any(func(h): return String((h.get("score", {}) as Dictionary).get("rank", "")) == "S"),
		"boss_s": s_of.call(cb.get("boss_best", {})), "practice_s": s_of.call(cb.get("practice_best", {})),
		"all_classes": classes.size() >= P2Catalog.CLASS_ORDER.size(),
		"daily_first": not daily.is_empty(), "daily_week": daily.size() >= 7,
	}
	for e in events:
		have[String(e)] = true
	var fresh: Array = []
	for a in P2Catalog.ACHIEVEMENTS:
		var id := String(a[0])
		if bool(have.get(id, false)) and not got.has(id):
			got[id] = today()
			fresh.append(id)
	cb["achievements"] = got
	return fresh


# 원정 중에 연 도전과제는 원정 기록(결과 화면)에도
static func _note_achievements(c: Dictionary, r: Dictionary, fresh: Array) -> void:
	if fresh.is_empty() or r.is_empty():
		return
	var list: Array = r.get("achv", [])
	list.append_array(fresh)
	r["achv"] = list
	var lr: Dictionary = c.combat.get("last_result", {})
	if String(lr.get("run_id", "")) == String(r.get("id", "")) and lr.has("achv"):
		(lr.achv as Array).append_array(fresh)


# ── 연습실 ──────────────────────────────────────────────────────────────────────

# 원정에서 만난 무리만(예전 저장은 보스 기록으로도)
static func practice_open(cb: Dictionary, gid: String) -> bool:
	if P2Catalog.dev_open() or (cb.get("seen_groups", []) as Array).has(gid):
		return true
	for k in (cb.get("boss_best", {}) as Dictionary):
		if String(k).get_slice("@", 0) == gid:
			return true
	return false


static func practice_key(gid: String, diff: String) -> String:
	return "%s@%s" % [gid, diff]


# 연습 한 판: 원정과 같은 무대 · 구간 배율 · 난이도로 저장 · 이어하기 · 그만두기가 되는 한 판. 체력은 가득, 성적만 남는다
func begin_practice(gid: String, diff: String) -> bool:
	var sector := P2Catalog.practice_sector(gid)
	if not run.is_empty() or not field.is_empty() or sector == "" or not practice_open(GameState.combat, gid) \
			or not P2Catalog.diff_unlocked(GameState.combat.get("diff_clear", {}), diff):
		SaveManager.last_error = "practice not allowed"
		return false
	var group: Dictionary = P2Catalog.GROUPS[gid]
	var lo := P5Campaign.build_entry_loadout(SaveManager.capture_profile())
	lo["potion_heal"] = P5Campaign.potion_heal()
	var deck := start_deck(String(lo.class_id))
	var cards_by_uid := cards_of(deck)
	var cards: Array[Card] = []
	for c in deck:
		cards.append(cards_by_uid[String(c.uid)])
	var counter := int(GameState.combat.get("run_counter", 0)) + 1
	var fid := "practice-%d-%s" % [counter, gid]
	var sd: int = absi(hash(fid + ":%d" % Time.get_ticks_usec())) % 2147483647
	var dm := P2Catalog.diff_of(diff)
	var opts := {"class_id": String(lo.class_id), "traits": [],
		"source": "expedition", "max_mana": int(lo.max_mana), "encounter_id": gid,
		"hit_mult": float(P2Catalog.SECTOR_HIT_MULT.get(sector, 1.0)) * float(dm.hit), "hp_mult": float(dm.hp),
		"judge_mult": float(dm.judge), "approach_mult": float(dm.approach), "pattern_level": int(dm.pattern),
		"heal_cap": int(dm.get("heal_cap", P2Battle.COMBO_HEAL_CAP))}
	_battle_vitals(int(lo.max_hp), int(lo.max_hp), int(lo.max_mana))
	var b := P2Battle.new({"enemies": group.enemies, "offsets": group.offsets}, cards, [] as Array[String], sd, opts)
	b.start()
	var snap := b.to_dict()
	battle = b
	return _tx("start practice", func(c, _r, f):
		c.combat.run_counter = counter
		f.clear()
		f.merge({"id": fid, "practice": true, "diff": diff, "sector": sector, "encounter_id": gid, "group": gid, "loadout": lo, "deck": deck,
			"hp": int(lo.max_hp), "phase": "battle", "battle": snap, "log": ["연습 시작: %s (%s)" % [group.name, dm.name]]})
		return true)


# 연습 결과: 연습 횟수와 요약만. 성적(등급)은 결과 판이 record_rhythm으로 이어서 남긴다
func _apply_practice_result(c: Dictionary, f: Dictionary, outcome: Dictionary) -> void:
	if not P5Campaign.record_event(c, String(f.id)):
		f.clear()
		return
	var st: Dictionary = c.combat.stats
	st["practice"] = int(st.get("practice", 0)) + 1
	c.combat.last_result = {"kind": "practice", "result": String(outcome.result), "group": String(f.group), "diff": String(f.diff),
		"event_id": String(f.id), "graded": false}
	f.clear()


func practice_ended() -> bool:
	var lr: Dictionary = GameState.combat.get("last_result", {})
	return run.is_empty() and field.is_empty() and String(lr.get("kind", "")) == "practice" and not bool(lr.get("graded", false))


func _record_practice(entry: Dictionary) -> bool:
	return _tx("practice rhythm", func(c, _r, _f):
		var lr: Dictionary = c.combat.last_result
		var key := practice_key(String(lr.group), String(lr.diff))
		var pb: Dictionary = c.combat.get("practice_best", {})
		var old: Dictionary = pb.get(key, {})
		lr["grade"] = String(entry.grade)
		lr["acc"] = int(entry.acc)
		lr["best"] = int(entry.best)
		lr["prev"] = old.duplicate()
		lr["new_best"] = rhythm_better(entry, old)
		lr["graded"] = true
		if bool(lr.new_best):
			pb[key] = {"grade": String(entry.grade), "acc": int(entry.acc), "best": maxi(int(entry.best), int(old.get("best", 0)))}
			c.combat["practice_best"] = pb
		lr["achv"] = unlock_achievements(c, ["combo_50"] if int(entry.get("best", 0)) >= 50 else [])
		return true)


const GRADE_RANK := {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1}


static func rhythm_better(a: Dictionary, old: Dictionary) -> bool:
	if old.is_empty():
		return true
	var ra := int(GRADE_RANK.get(String(a.get("grade", "D")), 0))
	var rb := int(GRADE_RANK.get(String(old.get("grade", "D")), 0))
	return ra > rb or (ra == rb and int(a.get("acc", 0)) > int(old.get("acc", 0)))


func last_result() -> Dictionary:
	return GameState.combat.get("last_result", {})


# ── 보상 ───────────────────────────────────────────────────────────────────────

static func _shuffled(rng: RandomNumberGenerator, pool: Array) -> Array:
	var list := pool.duplicate()
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
	return list


static func _reward_rng(r: Dictionary, id: String, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%d:%s:%s:%s" % [int(r.seed), String(r.get("sector", "normal")), id, salt]))
	return rng


# 덱에 한 장 더 넣어도 사본 규칙(기본 3·그 외 2·연료화 1·보존 2)을 넘지 않는가
static func card_eligible(kind: String, deck: Array) -> bool:
	var trial: Array = deck.duplicate(true)
	trial.append({"uid": "_new", "kind": kind, "upgrade": ""})
	return P2Catalog.deck_errors(trial).is_empty()


static func bridge_ok(kind: String, deck: Array) -> bool:
	match String(P2Catalog.BRIDGE_PREREQ.get(kind, "")):
		"mark":
			return P2Catalog.has_mark_source(deck)
		"defense":
			return P2Catalog.has_defense_source(deck)
	return true


# 카드 후보 3장 (서로 다른 종류): 직업 1 + 다리(전제 충족한 다른 직업 종류) 1 + 공용 1, 모자라면 가능한 종류로 채움.
# 첫 후보는 기능 역할(공격/방어/도구)이 2가지 이상이 되게 한다
static func card_offer(rng: RandomNumberGenerator, class_id: String, deck: Array, first: bool) -> Array:
	var own: Array = P2Catalog.CLASS_CARD_POOL.get(class_id, [])
	var common: Array = P2Catalog.COMMON_CARD_POOL
	var bridges: Array = []
	for cid in P2Catalog.CLASS_ORDER:
		if cid == class_id:
			continue
		for k in P2Catalog.CLASS_CARD_POOL[cid]:
			if not own.has(k) and not common.has(k) and not bridges.has(k) and bridge_ok(String(k), deck):
				bridges.append(k)
	var out: Array = []
	var pick := func(pool: Array) -> void:
		for k in _shuffled(rng, pool):
			if not out.has(k) and card_eligible(String(k), deck):
				out.append(k)
				return
	pick.call(own)
	pick.call(own)
	pick.call(bridges)
	pick.call(common)
	var every: Array = own + bridges + common
	while out.size() < P2Catalog.REWARD_COUNT:
		var before := out.size()
		pick.call(every)
		if out.size() == before:
			break
	if first and out.size() >= 2:
		var roles := {}
		for k in out:
			roles[P2Catalog.CARD_ROLES.get(k, "attack")] = true
		if roles.size() < 2:
			var have := String(P2Catalog.CARD_ROLES.get(out[0], "attack"))
			for k in _shuffled(rng, every):
				if not out.has(k) and String(P2Catalog.CARD_ROLES.get(k, "attack")) != have and card_eligible(String(k), deck):
					out[out.size() - 1] = k
					break
	return out


static func eligible_upgrades(deck: Array) -> Array:
	var out: Array = []
	for up in P2Catalog.UPGRADE_ORDER:
		if not upgrade_candidates(deck, up).is_empty():
			out.append(up)
	return out


static func upgrade_candidates(deck: Array, up: String) -> Array:
	var out: Array = []
	for c in deck:
		if String(c.kind) == String(P2Catalog.UPGRADE_KINDS[up].from) and String(c.get("upgrade", "")) == "":
			var trial: Array = deck.duplicate(true)
			for t in trial:
				if String(t.uid) == String(c.uid):
					t.upgrade = up
			if P2Catalog.deck_errors(trial).is_empty():
				out.append(String(c.uid))
	return out


# 강화할 수 있는 사본 (UID → 가능한 강화 목록). 상인·체력 지불은 사본을 먼저 고르고 맞는 강화를 고른다
static func upgradable_copies(deck: Array) -> Dictionary:
	var out := {}
	for up in P2Catalog.UPGRADE_ORDER:
		for uid in upgrade_candidates(deck, up):
			if not out.has(uid):
				out[uid] = []
			out[uid].append(up)
	return out


static func upgrade_offer(rng: RandomNumberGenerator, r: Dictionary) -> Array:
	var eligible := eligible_upgrades(r.deck)
	var cid := String(r.get("class_id", ""))
	var out: Array = []
	var class_pref: Array = P2Catalog.CLASS_UPGRADE_PREF.get(cid, [])
	for up in _shuffled(rng, class_pref):
		if out.size() >= 2:
			break
		if eligible.has(up) and not out.has(up):
			out.append(up)
	for up in _shuffled(rng, eligible):
		if out.size() >= 3:
			break
		if not out.has(up):
			out.append(up)
	return out


# 가지고 있는 동안 최대 체력을 깎는 유물 (얻을 때 깎고, 버리면 돌려줌)
const RELIC_HP := {"rift_heart": P2Catalog.RIFT_HP, "bridge_slab": P2Catalog.BRIDGE_HP}


# 유물 칸 순서 바꾸기(두 칸 맞바꿈): 석판 배치를 지도·보상 사이에 고친다
func move_relic(from: int, to: int) -> bool:
	if run.is_empty() or not (String(run.phase) in ["explore", "reward"]):
		return false
	var held: Array = run.relics
	if from == to or from < 0 or to < 0 or from >= held.size() or to >= held.size():
		return false
	return _tx("relic_order", func(_c, r, _f):
		var h: Array = r.relics
		var t: Variant = h[from]
		h[from] = h[to]
		h[to] = t
		r.log.append("유물 자리 바꿈: %s ↔ %s" % [String(h[to]), String(h[from])])
		return true)


static func relic_prereq_ok(id: String, deck: Array) -> bool:
	match id:
		"patient_glove":
			return deck.any(func(c): return P2Catalog.retains_entry(c))
		"furnace_seal", "ember_jar":
			return deck.any(func(c): return String(c.kind) in P2Catalog.EXHAUST_KINDS)
	return true


static func relic_offer(rng: RandomNumberGenerator, r: Dictionary, first: bool, count := 3) -> Array:
	var pool: Array = []
	for id in P2Catalog.RELIC_ORDER:
		if not (r.relics as Array).has(id) and relic_prereq_ok(id, r.deck) and (id != "combo_glove" or String(r.get("class_id", "")) == "combo") 				and (not P2Catalog.SLABS.has(id) or (r.relics as Array).any(func(x): return not P2Catalog.SLABS.has(String(x)))):
			pool.append(id)
	var out: Array = []
	var links: Array = (P2Catalog.CLASS_RELIC_LINK.get(String(r.get("class_id", "")), []) as Array).filter(func(x): return pool.has(x))
	for id in _shuffled(rng, links):
		out.append(id)
		break
	if first:
		for id in _shuffled(rng, P2Catalog.BRIDGE_RELICS.filter(func(x): return pool.has(x) and not out.has(x))):
			out.append(id)
			break
	for id in _shuffled(rng, pool):
		if out.size() >= count:
			break
		if not out.has(id):
			out.append(id)
	return out


# 특성을 얻는 순간 한 번: 수집가는 이미 가진 유물만큼 최대 체력(과 체력)을 올린다
static func gain_trait(r: Dictionary, id: String) -> void:
	if id == "collector":
		var add := P2Catalog.COLLECTOR_HP * (r.relics as Array).size()
		r.max_hp = int(r.max_hp) + add
		r.hp = int(r.hp) + add


static func trait_eligible(id: String, r: Dictionary) -> bool:
	if (r.traits as Array).has(id):
		return false
	match String(P2Catalog.TRAITS[id].needs):
		"mark":
			return P2Catalog.has_mark_source(r.deck)
		"retain":
			return (r.deck as Array).any(func(c): return P2Catalog.retains_entry(c))
		"exhaust":
			return (r.deck as Array).any(func(c): return String(c.kind) in P2Catalog.EXHAUST_KINDS)
		"doom":
			return String(r.class_id) == "shaman" or (r.deck as Array).any(func(c): return (P2Catalog.CARD_STATUS.get(String(c.kind), {}) as Dictionary).has("doom"))
		"combo":
			return String(r.class_id) == "combo"
		"elem":
			var keys := {}
			for c in r.deck:
				for k in (P2Catalog.CARD_STATUS.get(String(c.kind), {}) as Dictionary):
					if String(k) in ["burn", "chill", "poison", "lumen", "umbra"]:
						keys[k] = true
			return keys.size() >= 2
	return true


# 특성 후보 3개: 조건을 갖춘 것만, 공용 후보 최소 하나
static func trait_offer(r: Dictionary, tag := "") -> Array:
	var rng := _reward_rng(r, String(r.sector) if tag == "" else tag, "trait")
	var pool: Array = P2Catalog.TRAIT_ORDER.filter(func(t): return trait_eligible(String(t), r))
	var out: Array = []
	for t in _shuffled(rng, pool.filter(func(t): return bool(P2Catalog.TRAITS[t].common))):
		out.append(t)
		break
	for t in _shuffled(rng, pool):
		if out.size() >= 3:
			break
		if not out.has(t):
			out.append(t)
	return out


# 승리와 같은 거래 안에서 한 번 만든다. 다시 열거나 다시 불러와도 굴리지 않는다
static func build_parts(r: Dictionary, id: String) -> Array:
	var parts: Array = []
	var key := _reward_key(id)
	var e: Dictionary = r.layout.encounters.get(id, {})
	if not is_boss(id):
		var first := id == "n1" and String(r.sector) == "normal"
		parts.append({"type": "card", "cards": card_offer(_reward_rng(r, id, "card"), String(r.class_id), r.deck, first)})
	var plan: Array = P2Catalog.REWARD_PLAN.get(key, [])
	for t in plan:
		var part := {"type": String(t)}
		if String(t) in ["upgrade", "upgrade_or_heal", "upgrade_or_relic"]:
			part["upgrades"] = upgrade_offer(_reward_rng(r, id, "upgrade"), r)
		if String(t) in ["relic", "upgrade_or_relic"]:
			part["relics"] = relic_offer(_reward_rng(r, id, "relic"), r, id == "n3")
		if String(t) == "upgrade_or_heal":
			part["heal"] = P2Catalog.FINAL_HEAL
		if String(t) == "upgrade_or_relic" and bool(e.get("risk", false)):
			part["relic_guaranteed"] = true
		parts.append(part)
	if id == "elite":
		var tro := trait_offer(r, "elite")
		if not tro.is_empty():
			parts.append({"type": "trait", "traits": tro})
	return parts


func current_part() -> Dictionary:
	if run.is_empty() or String(run.phase) != "reward":
		return {}
	var parts: Array = run.reward.parts
	var i := int(run.reward.index)
	return parts[i] if i < parts.size() else {}


# sel: card: {"card": kind} | {"skip": true}; upgrade: {"upgrade", "copy"}; relic: {"relic", "replace"} | {"skip": true};
# 두 범주 중 하나: {"category": "upgrade"|"heal"|"relic", ...}. 한 부분씩 커밋한다
func choose_reward(sel: Dictionary) -> bool:
	if run.is_empty() or String(run.phase) != "reward":
		return false
	return _tx("reward", func(_c, r, _f):
		var parts: Array = r.reward.parts
		var i := int(r.reward.index)
		if i >= parts.size():
			return false
		if not _apply_part(r, parts[i], sel):
			return false
		r.log.append("보상 %s/%s: %s" % [String(r.reward.id), String(parts[i].type), JSON.stringify(sel)])
		r.reward.index = i + 1
		if int(r.reward.index) >= parts.size():
			r.phase = String(r.reward.after)
			r.reward = {}
		return true)


func _apply_part(r: Dictionary, part: Dictionary, sel: Dictionary) -> bool:
	var t := String(part.type)
	match t:
		"trait":
			if (part.traits as Array).is_empty():
				return true
			var tid := String(sel.get("trait", ""))
			if not (part.traits as Array).has(tid) or (r.traits as Array).has(tid):
				return false
			r.traits.append(tid)
			gain_trait(r, tid)
			r.log.append("특성: " + tid)
			return true
		"card":
			if bool(sel.get("skip", false)):
				r.log.append("새 카드 건너뜀")
				return true
			var k := String(sel.get("card", ""))
			return (part.cards as Array).has(k) and _add_card(r, k)
		"upgrade":
			if (part.upgrades as Array).is_empty():
				return _substitute(r)
			return _apply_upgrade(r, String(sel.get("upgrade", "")), String(sel.get("copy", "")), part.upgrades)
		"relic":
			if bool(part.get("required", false)) and bool(sel.get("skip", false)):
				return false
			return _apply_relic(r, String(sel.get("relic", "")), String(sel.get("replace", "")), part.relics, bool(sel.get("skip", false)))
		"upgrade_or_heal", "upgrade_or_relic":
			var cat := String(sel.get("category", ""))
			match cat:
				"upgrade":
					return not (part.upgrades as Array).is_empty() and _apply_upgrade(r, String(sel.get("upgrade", "")), String(sel.get("copy", "")), part.upgrades)
				"heal":
					if t != "upgrade_or_heal":
						return false
					var before := int(r.hp)
					r.hp = mini(int(r.max_hp), int(r.hp) + int(part.heal))
					r.log.append("회복 +%d" % (int(r.hp) - before))
					return true
				"relic":
					return t == "upgrade_or_relic" and _apply_relic(r, String(sel.get("relic", "")), String(sel.get("replace", "")), part.relics, bool(sel.get("skip", false)))
				"gold":
					if not (part.upgrades as Array).is_empty() or (t == "upgrade_or_relic" and not (part.get("relics", []) as Array).is_empty()):
						return false
					return _substitute(r)
	return false


func _substitute(r: Dictionary) -> bool:
	if int(r.hp) < int(r.max_hp):
		var before := int(r.hp)
		r.hp = mini(int(r.max_hp), int(r.hp) + P2Catalog.FINAL_HEAL)
		r.log.append("대체 보상: 회복 +%d" % (int(r.hp) - before))
	else:
		r.gold = int(r.gold) + 2
		r.log.append("대체 보상: 금화 2 (미정산)")
	return true


func _add_card(r: Dictionary, kind: String) -> bool:
	if not card_eligible(kind, r.deck):
		return false
	r.deck.append({"uid": "c%d" % int(r.next_uid), "kind": kind, "upgrade": ""})
	r.next_uid = int(r.next_uid) + 1
	r.log.append("카드 추가: " + kind)
	return true


# 사본 하나에 강화 하나 (강화되지 않은 사본만). offered가 비어 있으면 그 사본에 맞는 모든 강화 허용 (상인·체력 지불)
func _apply_upgrade(r: Dictionary, up: String, uid: String, offered: Array) -> bool:
	if not P2Catalog.UPGRADE_KINDS.has(up):
		return false
	if not offered.is_empty() and not offered.has(up):
		return false
	if not upgrade_candidates(r.deck, up).has(uid):
		return false
	for c in r.deck:
		if String(c.uid) == uid:
			c.upgrade = up
			r.log.append("강화: %s → %s" % [uid, P2Catalog.card_name(String(c.kind), up)])
			return true
	return false


func _apply_relic(r: Dictionary, relic: String, replace: String, offered: Array, skip: bool) -> bool:
	var held: Array = r.relics
	var cap := P2Catalog.relic_capacity(r)
	if skip:
		r.log.append("유물 건너뜀")
		return true
	if not offered.has(relic) or held.has(relic):
		return false
	var at := held.size()
	if held.size() >= cap:
		if replace == "" or not held.has(replace):
			return false
		at = held.find(replace)
		held.remove_at(at)
		r.max_hp = int(r.max_hp) + int(RELIC_HP.get(replace, 0))
		r.log.append("유물 교체: %s → %s" % [replace, relic])
	held.insert(at, relic)
	if replace == "" and (r.traits as Array).has("collector"):
		r.max_hp = int(r.max_hp) + P2Catalog.COLLECTOR_HP
		r.hp = int(r.hp) + P2Catalog.COLLECTOR_HP
	if RELIC_HP.has(relic):
		r.max_hp = int(r.max_hp) - int(RELIC_HP[relic])
		r.hp = mini(int(r.hp), int(r.max_hp))
	r.log.append("유물: " + relic)
	return true


# ── 구간 보스 뒤: 마치기 또는 계속 ────────────────────────────────────────────────

func choose_return() -> bool:
	if run.is_empty() or String(run.phase) != "sector_choice":
		return false
	return _tx("return", func(c, r, _f):
		_end_expedition(c, r, "return", true)
		r.phase = "portal"
		r.log.append("여기서 마침")
		return true)


func next_sector(sector: String) -> String:
	var i := P2Catalog.SECTORS.find(sector)
	return P2Catalog.SECTORS[i + 1] if i >= 0 and i + 1 < P2Catalog.SECTORS.size() else ""


# 계속: 회복 +6 · 특성 · 다음 구간 배치를 한 거래로
func choose_continue(trait_id: String) -> bool:
	if run.is_empty() or String(run.phase) != "sector_choice":
		return false
	var nxt := next_sector(String(run.sector))
	if nxt == "" or not (run.trait_offer as Array).has(trait_id):
		return false
	var layout := P2DungeonGen.generate_sector(nxt, int(run.seed))
	return _tx("continue", func(_c, r, _f):
		var before := int(r.hp)
		r.hp = mini(int(r.max_hp), int(r.hp) + P2Catalog.CONTINUE_HEAL)
		r.traits.append(trait_id)
		gain_trait(r, trait_id)
		r.trait_offer = []
		r.past[String(r.sector)] = {"signature": String(r.layout.get("signature", "")), "defeated": r.defeated.duplicate()}
		r.sector = nxt
		r.layout = layout
		r.defeated = []
		r["opened"] = []
		r.route = ""
		r.reward = {}
		r.service = _new_service(layout, int(r.seed), nxt, String(r.class_id), r.deck)
		r.choice = {"picked": ""}
		r.pos = []
		r.room = "ent"
		r.phase = "explore"
		r.log.append("%s 진입: 특성 %s, 체력 %d → %d (배치 %s)" % [P2Catalog.SECTOR_NAMES[nxt], P2Catalog.TRAITS[trait_id].name, before, int(r.hp), layout.signature])
		return true)


# 포탈: 이미 정산·기록된 원정을 비운다 (메뉴로 돌아가는 화면 전환은 호스트가)
func enter_portal() -> bool:
	if run.is_empty() or String(run.phase) != "portal":
		return false
	return _tx("portal", func(c, r, _f):
		if not (c.combat.settled as Array).has("%s:end" % String(r.id)):
			return false
		r.clear()
		return true)


# 원정 포기 (전투 중 후퇴 포함): 완료 구간 정산은 지켜지고 이번 구간 미정산분만 잃는다
func abandon() -> bool:
	if run.is_empty() or String(run.phase) in ["portal", "sector_choice"]:
		return false
	var ok := _tx("abandon", func(c, r, _f):
		r.log.append("원정 포기")
		_end_expedition(c, r, "abandon")
		return true)
	if ok:
		battle = null
	return ok


# end_expedition(reason) 공개 인터페이스: 포탈(마침/완료) 또는 포기
func end_expedition(reason: String) -> bool:
	if reason == "abandon":
		return abandon()
	return enter_portal()


func at_risk_summary() -> Dictionary:
	if run.is_empty():
		return {}
	var banked_gold := 0
	var banked_xp := 0
	for s in run.banked:
		banked_gold += int(run.banked[s].gold)
		banked_xp += int(run.banked[s].xp)
	return {"banked_gold": banked_gold, "banked_xp": banked_xp, "pending_gold": int(run.gold), "pending_xp": int(run.xp),
		"spent": int(run.spent), "kills": (run.kills as Dictionary).duplicate(), "sector": String(run.sector)}


static func build_summary(r: Dictionary) -> String:
	if r.is_empty():
		return ""
	var parts: Array[String] = []
	if P2Catalog.CLASSES.has(String(r.get("class_id", ""))):
		parts.append(String(P2Catalog.CLASSES[r.class_id].name))
	for c in r.deck:
		if String(c.get("upgrade", "")) != "":
			parts.append(P2Catalog.card_name(String(c.kind), String(c.upgrade)))
	var counted := {}
	for k in P2Catalog.class_deck(String(r.class_id)) if P2Catalog.CLASSES.has(String(r.class_id)) else []:
		counted[k] = int(counted.get(k, 0)) + 1
	for c in r.deck:
		if String(c.get("upgrade", "")) != "":
			continue
		var k := String(c.kind)
		if int(counted.get(k, 0)) > 0:
			counted[k] = int(counted[k]) - 1
		else:
			parts.append(P2Catalog.card_name(k))
	for id in r.relics:
		parts.append(String(P2Catalog.RELICS[id].name))
	for t in r.get("traits", []):
		parts.append("특성 " + String(P2Catalog.TRAITS[t].name))
	return " + ".join(parts) if not parts.is_empty() else "기본 덱"


# 전투 화면이 시작할 때 보관하는 값 (패배 확정 순간 원정 상태가 비워져도 화면은 이 값을 쓴다)
func battle_info() -> Dictionary:
	if not field.is_empty():
		return {"max_hp": int(field.loadout.max_hp), "deck": (field.deck as Array).size(), "group": String(field.group),
			"sector": String(field.sector), "boss": is_boss(String(field.group)), "potion_heal": int(field.loadout.potion_heal), "practice": true}
	var id := String(run.get("encounter", ""))
	return {"max_hp": int(run.max_hp), "deck": (run.deck as Array).size(), "group": String(run.layout.encounters[id].group),
		"sector": String(run.sector), "boss": is_boss(id), "potion_heal": int(run.loadout.potion_heal)}


func battle_active() -> bool:
	return (not run.is_empty() and String(run.phase) == "battle") or (not field.is_empty() and String(field.phase) == "battle")



func _commit_field(reason: String) -> bool:
	var b := battle
	var snap := b.to_dict()
	var over := b.battle_over
	var hp := battle_hp()
	var won := over and hp > 0
	return _tx(reason, func(c, _r, f):
		f.battle = snap
		f.hp = hp
		if over:
			_apply_practice_result(c, f, {"result": "won" if won else "lost"})
		return true)


# 연습 그만두기: 기록 없이 결과만
func field_retreat() -> bool:
	if field.is_empty() or battle == null or battle.battle_over:
		return false
	return _tx("retreat", func(c, _r, f):
		_apply_practice_result(c, f, {"result": "retreat"})
		return true)


