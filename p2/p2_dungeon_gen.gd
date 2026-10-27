class_name P2DungeonGen
extends RefCounted
# 작은 던전 한 층: 방 원형(모듈) 5종을 격자 칸에 배치하고 문으로 잇는다. 입장할 때 한 번 만들어 도전 상태에
# 저장하고, 화면(타일/충돌)과 검증은 같은 타일 격자(tiles())를 쓴다.
#
# 구조 틀 두 가지(갈림길 위치가 다름) × 칸 배치(무작위 보행) × 방 모듈 × 편성 후보:
#  T1: 입구 → A(N1) → 갈림길 → C(N2) → D(휴식·N3) → F(N4) → 보스.  우회: 갈림길 → 정예실 → 보물실 → C
#  T2: 입구 → A(N1) → C(N2) → 갈림길(휴식) → D(N3) → F(N4) → 보스.  우회: 갈림길 → 정예실 → 보물실 → D
# 각 필수 일반전은 자기 방의 다음 방 문(창살)을 지킨다. 우회로는 수호자가 없는 한 연결만 건너뛰므로
# 필수 전투를 피할 수 없다. 보물실 → 합류 방 문은 안쪽 빗장이라 합류 방 쪽에서는 열 수 없다.

const CELL_W := 15
const CELL_H := 11
const TILE := 32
const DOOR_HALF := 1 # 문 폭 3칸
const MAX_ATTEMPTS := 24

const WALL := 0
const FLOOR := 1

const MODULES := {
	"hall": [
		"###############",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"###############",
	],
	"pillars": [
		"###############",
		"#.............#",
		"#..##.....##..#",
		"#..##.....##..#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#..##.....##..#",
		"#..##.....##..#",
		"#.............#",
		"###############",
	],
	"cross": [
		"###############",
		"####.......####",
		"####.......####",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"####.......####",
		"####.......####",
		"###############",
	],
	"ring": [
		"###############",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.....###.....#",
		"#.....###.....#",
		"#.....###.....#",
		"#.............#",
		"#.............#",
		"#.............#",
		"###############",
	],
	"alcove": [
		"###############",
		"#.............#",
		"#.............#",
		"#.............#",
		"#...#.....#...#",
		"#.............#",
		"#...#.....#...#",
		"#.............#",
		"#.............#",
		"#.............#",
		"###############",
	],
	"atrium": [
		"###############",
		"#.............#",
		"#.#..#...#..#.#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.#..#...#..#.#",
		"#.............#",
		"###############",
	],
	"crossroads": [
		"###############",
		"###.........###",
		"##...........##",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"##...........##",
		"###.........###",
		"###############",
	],
	"arena": [
		"###############",
		"#.............#",
		"#.##.......##.#",
		"#.#.........#.#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.#.........#.#",
		"#.##.......##.#",
		"#.............#",
		"###############",
	],
	"sanctum": [
		"###############",
		"#.............#",
		"#..#.......#..#",
		"#.............#",
		"#....#...#....#",
		"#.............#",
		"#....#...#....#",
		"#.............#",
		"#..#.......#..#",
		"#.............#",
		"###############",
	],
}
const ROLE_MODULES := {
	"entrance": ["atrium"],
	"normal": ["hall", "pillars", "cross", "ring", "alcove"],
	"fork": ["crossroads"],
	"elite": ["pillars", "hall", "alcove"],
	"vault": ["cross", "ring"],
	"boss": ["arena"],
	"h_entrance": ["atrium", "crossroads"],
	"h1a": ["pillars", "alcove"],
	"h1b": ["hall", "ring"],
	"h2": ["cross", "pillars"],
	"h_boss": ["sanctum"],
}

const TEMPLATES := {
	"T1": {"main": ["ent", "a", "fork", "c", "d", "f", "boss"],
		"guards": {"a": "n1", "c": "n2", "d": "n3", "f": "n4"}, "rest": "d", "fork": "fork", "merge": "c"},
	"T2": {"main": ["ent", "a", "c", "fork", "d", "f", "boss"],
		"guards": {"a": "n1", "c": "n2", "d": "n3", "f": "n4"}, "rest": "fork", "fork": "fork", "merge": "d"},
}
const ORDER := ["n1", "n2", "n3", "n4"]
const DIRS := {"E": Vector2i(1, 0), "W": Vector2i(-1, 0), "N": Vector2i(0, -1), "S": Vector2i(0, 1)}
const ROOM_NAMES := {"ent": "입구", "a": "첫 방", "fork": "갈림길", "c": "둘째 방", "d": "셋째 방",
	"f": "넷째 방", "boss": "보스의 방", "elite": "정예실", "vault": "보물실"}
const HARD_NAMES := {"ent": "심층 입구", "fork": "심층 갈림길", "h1a": "철갑 통로", "h1b": "추격 통로",
	"h2": "돌파의 방", "boss": "파수자의 방"}


static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt in range(MAX_ATTEMPTS):
		var layout := _try(rng, seed_value)
		if layout.is_empty():
			continue
		if validate(layout).is_empty():
			layout["attempts"] = attempt + 1
			layout["fallback"] = false
			return layout
	var fb := fallback(seed_value)
	fb["attempts"] = MAX_ATTEMPTS
	fb["fallback"] = true
	return fb


# 시험된 고정 배치: 동쪽으로 곧게 이어지고 우회로는 남쪽 (시드와 무관하게 연결이 보장된다)
static func fallback(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {"ent": Vector2i(0, 0), "a": Vector2i(1, 0), "fork": Vector2i(2, 0), "c": Vector2i(3, 0),
		"d": Vector2i(4, 0), "f": Vector2i(5, 0), "boss": Vector2i(6, 0), "elite": Vector2i(2, 1), "vault": Vector2i(3, 1)}
	var modules := {"ent": "atrium", "a": "hall", "fork": "crossroads", "c": "hall", "d": "ring", "f": "hall",
		"boss": "arena", "elite": "hall", "vault": "cross"}
	return _assemble("T1", cells, modules, rng, "fallback")


static func _try(rng: RandomNumberGenerator, _seed_value: int) -> Dictionary:
	var template := "T1" if rng.randi() % 2 == 0 else "T2"
	var t: Dictionary = TEMPLATES[template]
	var main: Array = t.main
	var cells := {}
	var used := {}
	var pos := Vector2i.ZERO
	cells[main[0]] = pos
	used[pos] = true
	var path := ""
	for i in range(1, main.size()):
		var options: Array = []
		for key in ["E", "E", "N", "S", "W"]:
			var next: Vector2i = pos + DIRS[key]
			if used.has(next):
				continue
			if key == "W" and i < 2:
				continue
			if main[i] == t.merge:
				var o_ok := false
				for perp in _perpendicular(key):
					var e_cell: Vector2i = pos + DIRS[perp]
					var v_cell: Vector2i = next + DIRS[perp]
					if not used.has(e_cell) and not used.has(v_cell) and e_cell != next and v_cell != next:
						o_ok = true
				if not o_ok:
					continue
			options.append(key)
		if options.is_empty():
			return {}
		var pick: String = options[rng.randi() % options.size()]
		var next_pos: Vector2i = pos + DIRS[pick]
		if main[i] == t.merge:
			var perps: Array = _perpendicular(pick)
			if rng.randi() % 2 == 1:
				perps.reverse()
			var placed := false
			for perp in perps:
				var e_cell: Vector2i = pos + DIRS[perp]
				var v_cell: Vector2i = next_pos + DIRS[perp]
				if not used.has(e_cell) and not used.has(v_cell):
					cells["elite"] = e_cell
					cells["vault"] = v_cell
					used[e_cell] = true
					used[v_cell] = true
					path += "(" + perp + ")"
					placed = true
					break
			if not placed:
				return {}
		cells[main[i]] = next_pos
		used[next_pos] = true
		pos = next_pos
		path += pick
	var modules := {}
	for id in cells:
		modules[id] = _pick_module(rng, _role_of(id, template))
	return _assemble(template, cells, modules, rng, template + ":" + path)


static func _perpendicular(key: String) -> Array:
	return ["N", "S"] if key in ["E", "W"] else ["E", "W"]


static func _role_of(id: String, template: String) -> String:
	match id:
		"ent":
			return "entrance"
		"boss":
			return "boss"
		"elite":
			return "elite"
		"vault":
			return "vault"
		"fork":
			return "fork" if template == "T1" else "normal"
	return "normal"


static func _pick_module(rng: RandomNumberGenerator, role: String) -> String:
	var list: Array = ROLE_MODULES[role]
	return list[rng.randi() % list.size()]


static func _dir_between(a: Vector2i, b: Vector2i) -> String:
	for key in DIRS:
		if a + DIRS[key] == b:
			return key
	return ""


# 칸 배치가 정해진 뒤: 연결(문 종류/수호자), 편성, 위치를 채운다
static func _assemble(template: String, cells: Dictionary, modules: Dictionary, rng: RandomNumberGenerator, signature: String) -> Dictionary:
	var t: Dictionary = TEMPLATES[template]
	var main: Array = t.main
	var links: Array = []
	for i in range(main.size() - 1):
		var a: String = main[i]
		var b: String = main[i + 1]
		var guard: String = t.guards.get(a, "")
		links.append({"a": a, "b": b, "dir": _dir_between(cells[a], cells[b]), "kind": "gate" if guard != "" else "open", "guard": guard})
	links.append({"a": t.fork, "b": "elite", "dir": _dir_between(cells[t.fork], cells.elite), "kind": "open", "guard": ""})
	links.append({"a": "elite", "b": "vault", "dir": _dir_between(cells.elite, cells.vault), "kind": "gate", "guard": "elite"})
	links.append({"a": "vault", "b": t.merge, "dir": _dir_between(cells.vault, cells[t.merge]), "kind": "bar", "guard": ""})

	# P5: 일반 구간 필수 전투는 새 규칙을 하나씩 가르치는 고정 편성 (배치·연결만 무작위)
	var groups := {"n1": "n1", "n2": "n2", "n3": "n3", "n4": "n4", "elite": "elite", "boss": "boss"}

	var rooms := {}
	for id in cells:
		rooms[id] = {"cell": [cells[id].x, cells[id].y], "module": modules[id], "name": ROOM_NAMES[id]}
	var layout := {
		"version": 2, "sector": "normal", "template": template, "signature": signature,
		"cell_size": [CELL_W, CELL_H], "tile": TILE,
		"rooms": rooms, "links": links, "groups": groups,
		"encounters": {}, "service": {}, "choice": {}, "spawn": [], "portal": [], "bar": {},
	}
	var grid := tiles(layout)
	var encounters := {}
	for link in links:
		if link.guard == "":
			continue
		var spot := _front_of_door(layout, grid, link.a, link.dir)
		encounters[link.guard] = {"group": groups[link.guard], "room": link.a, "pos": [spot.x, spot.y],
			"guards": "passage" if link.guard != "elite" else "shortcut", "door": [link.a, link.b]}
	var boss_center := _center_floor(layout, grid, "boss")
	encounters["boss"] = {"group": "boss", "room": "boss", "pos": [boss_center.x, boss_center.y], "guards": "exit", "door": []}
	var req := {"n1": [], "n2": ["n1"], "n3": ["n1", "n2"], "n4": ["n1", "n2", "n3"], "boss": ["n1", "n2", "n3", "n4"]}
	req["elite"] = ["n1"] if template == "T1" else ["n1", "n2"]
	for id in encounters:
		encounters[id]["requires"] = req[id]
	layout.encounters = encounters
	# P5: 휴식 자리는 상인(서비스 지점, N2 이후), 갈림길 쪽 방에는 선택 지점(N1 이후). 보물실 상자는 없앴다
	var rest_spot := _free_spot(layout, grid, t.rest, [encounters.get(t.guards.get(t.rest, ""), {}).get("pos", [])])
	layout["service"] = {"room": t.rest, "pos": [rest_spot.x, rest_spot.y], "requires": ["n1", "n2"]}
	var choice_room: String = main[2]
	var avoid: Array = [encounters.get(t.guards.get(choice_room, ""), {}).get("pos", [])]
	if choice_room == t.rest:
		avoid.append(layout.service.pos)
	var choice_spot := _free_spot(layout, grid, choice_room, avoid)
	layout["choice"] = {"room": choice_room, "pos": [choice_spot.x, choice_spot.y], "requires": ["n1"]}
	_set_opt(layout, rng, "normal")
	var spawn := _center_floor(layout, grid, "ent")
	layout.spawn = [spawn.x, spawn.y]
	layout.portal = [boss_center.x, boss_center.y]
	var bar_link: Dictionary = links[-1]
	var inside := _front_of_door(layout, grid, "vault", bar_link.dir)
	layout.bar = {"room": "vault", "to": t.merge, "lever": [inside.x, inside.y]}
	return layout


# ── 타일 격자 ───────────────────────────────────────────────────────────────

static func bounds(layout: Dictionary) -> Rect2i:
	var minc := Vector2i(1 << 20, 1 << 20)
	var maxc := Vector2i(-(1 << 20), -(1 << 20))
	for id in layout.rooms:
		var c := _cell(layout, id)
		minc = Vector2i(mini(minc.x, c.x), mini(minc.y, c.y))
		maxc = Vector2i(maxi(maxc.x, c.x), maxi(maxc.y, c.y))
	return Rect2i(minc.x * CELL_W, minc.y * CELL_H, (maxc.x - minc.x + 1) * CELL_W, (maxc.y - minc.y + 1) * CELL_H)


static func _cell(layout: Dictionary, id: String) -> Vector2i:
	var c: Array = layout.rooms[id].cell
	return Vector2i(int(c[0]), int(c[1]))


static func room_origin(layout: Dictionary, id: String) -> Vector2i:
	var c := _cell(layout, id)
	return Vector2i(c.x * CELL_W, c.y * CELL_H)


static func room_rect(layout: Dictionary, id: String) -> Rect2i:
	return Rect2i(room_origin(layout, id), Vector2i(CELL_W, CELL_H))


# 전체 타일: Dictionary[Vector2i] = FLOOR (없으면 벽). 문은 두 방 벽을 뚫고, 방 안쪽 첫 바닥까지 잇는다
static func tiles(layout: Dictionary) -> Dictionary:
	var grid := {}
	for id in layout.rooms:
		var o := room_origin(layout, id)
		var rows: Array = MODULES[layout.rooms[id].module]
		for y in range(CELL_H):
			var row: String = rows[y]
			for x in range(CELL_W):
				if row[x] == ".":
					grid[o + Vector2i(x, y)] = FLOOR
	for link in layout.links:
		for p in door_tiles(layout, link):
			grid[p] = FLOOR
	return grid


# 한 연결의 문 타일 전부(양쪽 방 벽 두께 + 안쪽 바닥까지 이어 붙인 통로)
static func door_tiles(layout: Dictionary, link: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d: Vector2i = DIRS[link.dir]
	for id in [link.a, link.b]:
		var o := room_origin(layout, id)
		var rows: Array = MODULES[layout.rooms[id].module]
		var toward: Vector2i = d if id == link.a else -d
		for k in range(-DOOR_HALF, DOOR_HALF + 1):
			var start: Vector2i
			if toward.x != 0:
				start = Vector2i(CELL_W - 1 if toward.x > 0 else 0, CELL_H / 2 + k)
			else:
				start = Vector2i(CELL_W / 2 + k, CELL_H - 1 if toward.y > 0 else 0)
			var p := start
			while p.x >= 0 and p.x < CELL_W and p.y >= 0 and p.y < CELL_H:
				out.append(o + p)
				p -= toward
				if p.x < 0 or p.x >= CELL_W or p.y < 0 or p.y >= CELL_H or String(rows[p.y])[p.x] == ".":
					break
	return out


# 수호자/빗장 문을 막는 칸: 지키는 쪽 방의 벽 두께 한 줄(문 폭 3칸)
static func gate_tiles(layout: Dictionary, link: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d: Vector2i = DIRS[link.dir]
	var o := room_origin(layout, link.a)
	for k in range(-DOOR_HALF, DOOR_HALF + 1):
		var p: Vector2i
		if d.x != 0:
			p = Vector2i(CELL_W - 1 if d.x > 0 else 0, CELL_H / 2 + k)
		else:
			p = Vector2i(CELL_W / 2 + k, CELL_H - 1 if d.y > 0 else 0)
		out.append(o + p)
	return out


static func _front_of_door(layout: Dictionary, grid: Dictionary, room: String, dir: String) -> Vector2i:
	var d: Vector2i = DIRS[dir]
	var o := room_origin(layout, room)
	var edge: Vector2i
	if d.x != 0:
		edge = Vector2i(CELL_W - 1 if d.x > 0 else 0, CELL_H / 2)
	else:
		edge = Vector2i(CELL_W / 2, CELL_H - 1 if d.y > 0 else 0)
	var p := o + edge
	var steps := 0
	while steps < 12:
		p -= d
		steps += 1
		if grid.has(p) and steps >= 3:
			return p
	return _center_floor(layout, grid, room)


static func _center_floor(layout: Dictionary, grid: Dictionary, room: String) -> Vector2i:
	var o := room_origin(layout, room)
	var center := o + Vector2i(CELL_W / 2, CELL_H / 2)
	if grid.has(center):
		return center
	var best := center
	var best_d := 1 << 30
	var r := room_rect(layout, room)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if grid.has(p):
				var dd := (p - center).length_squared()
				if dd < best_d:
					best_d = dd
					best = p
	return best


# 문 통로(가운데 3줄/3칸)와 다른 물건을 피한, 방 중앙에 가까운 바닥 칸
static func _free_spot(layout: Dictionary, grid: Dictionary, room: String, avoid: Array) -> Vector2i:
	var o := room_origin(layout, room)
	var center := o + Vector2i(CELL_W / 2, CELL_H / 2)
	var best := center
	var best_d := 1 << 30
	var r := room_rect(layout, room)
	for y in range(r.position.y + 2, r.end.y - 2):
		for x in range(r.position.x + 2, r.end.x - 2):
			var p := Vector2i(x, y)
			var lp := p - o
			if not grid.has(p) or abs(lp.x - CELL_W / 2) <= 1 or abs(lp.y - CELL_H / 2) <= 1:
				continue
			var blocked := false
			for a in avoid:
				if a is Array and a.size() == 2 and (p - Vector2i(int(a[0]), int(a[1]))).length_squared() <= 4:
					blocked = true
			if blocked:
				continue
			var dd := (p - center).length_squared()
			if dd < best_d:
				best_d = dd
				best = p
	return best


# ── 검증: 실제 타일 격자로 도달 가능성/관문/우회 불가를 확인한다 ────────────────

# defeated: 처치한 편성 id, bar_open: 보물실 빗장을 안에서 열었는지
static func reachable(layout: Dictionary, grid: Dictionary, defeated: Array, bar_open: bool, route: String = "") -> Dictionary:
	var blocked := {}
	var one_way := {}
	for link in layout.links:
		if link.kind == "gate" and not defeated.has(link.guard):
			for p in gate_tiles(layout, link):
				blocked[p] = true
		elif link.kind == "route" and String(link.route) != route:
			for p in gate_tiles(layout, link):
				blocked[p] = true
		elif link.kind == "bar" and not bar_open:
			for p in gate_tiles(layout, link):
				one_way[p] = link
	var start_arr: Array = layout.spawn
	var start := Vector2i(int(start_arr[0]), int(start_arr[1]))
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var vault := room_rect(layout, "vault") if layout.rooms.has("vault") else Rect2i()
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if seen.has(q) or not grid.has(q) or blocked.has(q):
				continue
			if one_way.has(q) and not vault.has_point(p):
				continue # 빗장 문은 보물실 안쪽에서만 지나갈 수 있다(여는 동작)
			seen[q] = true
			queue.append(q)
	return seen


static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var grid := tiles(layout)
	# 문 겹침: 같은 칸을 두 연결이 쓰면 안 된다
	var used_doors := {}
	for link in layout.links:
		for p in gate_tiles(layout, link):
			if used_doors.has(p):
				errors.append("overlapping door at %s" % p)
			used_doors[p] = true
	for id in ["n1", "n2", "n3", "n4", "elite", "boss"]:
		if not layout.encounters.has(id):
			errors.append("missing encounter " + id)
	if not errors.is_empty():
		return errors
	var enc: Dictionary = layout.encounters
	var pos_of := func(e: Dictionary) -> Vector2i:
		return Vector2i(int(e.pos[0]), int(e.pos[1]))
	# 아무것도 안 잡았을 때: N1까지만 닿고, 보스·보물실·정예실 너머는 막혀 있다
	var r0 := reachable(layout, grid, [], false)
	if not r0.has(pos_of.call(enc.n1)):
		errors.append("n1 unreachable from spawn")
	if r0.has(pos_of.call(enc.boss)):
		errors.append("boss reachable without fights")
	# 순서대로 잡을 때 각 수호자가 닿는다 (정예는 한 번도 잡지 않는다 = 선택 경로 생략 가능)
	var got: Array = []
	for id in ORDER:
		var r := reachable(layout, grid, got, false)
		if not r.has(pos_of.call(enc[id])):
			errors.append("%s unreachable after %s" % [id, str(got)])
		got.append(id)
	var r_all := reachable(layout, grid, got, false)
	if not r_all.has(pos_of.call(enc.boss)):
		errors.append("boss unreachable after n1-n4 (elite skipped)")
	var service_p := Vector2i(int(layout.service.pos[0]), int(layout.service.pos[1]))
	if not reachable(layout, grid, ["n1", "n2"], false).has(service_p):
		errors.append("service unreachable after n1,n2")
	if reachable(layout, grid, ["n1"], false).has(service_p):
		errors.append("service reachable before n2")
	var choice_p := Vector2i(int(layout.choice.pos[0]), int(layout.choice.pos[1]))
	if not reachable(layout, grid, ["n1"], false).has(choice_p):
		errors.append("choice unreachable after n1")
	var elite_req: Array = enc.elite.requires
	if not reachable(layout, grid, elite_req, false).has(pos_of.call(enc.elite)):
		errors.append("elite unreachable after requirements")
	var cache_p := _center_floor(layout, grid, "vault")
	if reachable(layout, grid, elite_req, false).has(cache_p):
		errors.append("vault reachable without elite")
	# 우회로로도 보스를 건너뛸 수 없다: 필수 하나만 빼고 나머지+정예+빗장을 다 열어도 보스 불가
	for skip in ORDER:
		var others: Array = ["elite"]
		for id in ORDER:
			if id != skip:
				others.append(id)
		for bar in [false, true]:
			if reachable(layout, grid, others, bar).has(pos_of.call(enc.boss)):
				errors.append("boss bypass without %s (bar %s)" % [skip, bar])
	# 빗장은 합류 방 쪽에서 열리지 않는다: 정예를 안 잡았으면 보물실에 못 들어간다
	var r_skip := reachable(layout, grid, got, false)
	if r_skip.has(cache_p):
		errors.append("vault enterable from merge side")
	return errors



# ── 하드층: 입구 → (갈림길) → 철갑 통로 H1A 또는 추격 통로 H1B 중 하나 → 돌파의 방 H2 → 파수자의 방 ─────────────
# HT1: 입구와 갈림길이 따로 / HT2: 입구가 곧 갈림길. 두 통로 방은 갈림길을 사이에 둔 직각 두 칸이고, H2는 그 대각선 칸에서
# 두 통로와 모두 맞닿는다(짧게 다시 합류). 고르지 않은 통로는 갈림길 쪽 문과 H2 쪽 창살이 모두 닫혀 있어 들어갈 수 없다.

static func generate_hard(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	for attempt in range(MAX_ATTEMPTS):
		var layout := _try_hard(rng)
		if layout.is_empty():
			continue
		if validate_hard(layout).is_empty():
			layout["attempts"] = attempt + 1
			layout["fallback"] = false
			return layout
	var fb := fallback_hard(seed_value)
	fb["attempts"] = MAX_ATTEMPTS
	fb["fallback"] = true
	return fb


static func fallback_hard(_seed_value: int) -> Dictionary:
	var cells := {"ent": Vector2i(0, 0), "fork": Vector2i(1, 0), "h1a": Vector2i(1, -1), "h1b": Vector2i(2, 0),
		"h2": Vector2i(2, -1), "boss": Vector2i(3, -1)}
	var modules := {"ent": "atrium", "fork": "crossroads", "h1a": "pillars", "h1b": "hall", "h2": "cross", "boss": "sanctum"}
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value * 31 + 11
	return _assemble_hard("HT1", cells, modules, "fallback", rng)


static func _try_hard(rng: RandomNumberGenerator) -> Dictionary:
	var template := "HT1" if rng.randi() % 2 == 0 else "HT2"
	var keys := ["E", "W", "N", "S"]
	var cells := {"ent": Vector2i.ZERO}
	var fork := Vector2i.ZERO
	var back := ""
	var path := ""
	if template == "HT1":
		var d0: String = keys[rng.randi() % 4]
		fork = DIRS[d0]
		cells["fork"] = fork
		back = _opposite(d0)
		path += d0
	var pairs: Array = []
	for a in keys:
		for b in keys:
			if a < b and _perpendicular(a).has(b) and a != back and b != back:
				pairs.append([a, b])
	var pair: Array = (pairs[rng.randi() % pairs.size()] as Array).duplicate()
	if rng.randi() % 2 == 1:
		pair.reverse()
	var u: String = pair[0]
	var v: String = pair[1]
	cells["h1a"] = fork + DIRS[u]
	cells["h1b"] = fork + DIRS[v]
	cells["h2"] = fork + DIRS[u] + DIRS[v]
	var w: String = u if rng.randi() % 2 == 0 else v
	cells["boss"] = (cells.h2 as Vector2i) + DIRS[w]
	path += "(%s|%s)%s" % [u, v, w]
	var used := {}
	for k in cells:
		if used.has(cells[k]):
			return {}
		used[cells[k]] = true
	var modules := {}
	for id in cells:
		var role: String = {"ent": "h_entrance", "fork": "fork", "h1a": "h1a", "h1b": "h1b", "h2": "h2", "boss": "h_boss"}[id]
		if template == "HT2" and id == "ent":
			role = "fork"
		modules[id] = _pick_module(rng, role)
	return _assemble_hard(template, cells, modules, template + ":" + path, rng)


static func _opposite(key: String) -> String:
	return {"E": "W", "W": "E", "N": "S", "S": "N"}[key]


static func _assemble_hard(template: String, cells: Dictionary, modules: Dictionary, signature: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var fork_id := "fork" if cells.has("fork") else "ent"
	var links: Array = []
	if cells.has("fork"):
		links.append({"a": "ent", "b": "fork", "dir": _dir_between(cells.ent, cells.fork), "kind": "open", "guard": ""})
	links.append({"a": fork_id, "b": "h1a", "dir": _dir_between(cells[fork_id], cells.h1a), "kind": "route", "route": "a", "guard": ""})
	links.append({"a": fork_id, "b": "h1b", "dir": _dir_between(cells[fork_id], cells.h1b), "kind": "route", "route": "b", "guard": ""})
	links.append({"a": "h1a", "b": "h2", "dir": _dir_between(cells.h1a, cells.h2), "kind": "gate", "guard": "h1a"})
	links.append({"a": "h1b", "b": "h2", "dir": _dir_between(cells.h1b, cells.h2), "kind": "gate", "guard": "h1b"})
	links.append({"a": "h2", "b": "boss", "dir": _dir_between(cells.h2, cells.boss), "kind": "gate", "guard": "h2"})
	var rooms := {}
	for id in cells:
		rooms[id] = {"cell": [cells[id].x, cells[id].y], "module": modules[id], "name": HARD_NAMES[id]}
	var layout := {
		"version": 1, "sector": "hard", "template": template, "signature": signature,
		"cell_size": [CELL_W, CELL_H], "tile": TILE, "fork_room": fork_id,
		"rooms": rooms, "links": links, "groups": {"h1a": "h1a", "h1b": "h1b", "h2": "h2", "hboss": "hboss"},
		"encounters": {}, "service": {}, "choice": {}, "spawn": [], "portal": [], "bar": {}, "route_signs": {},
	}
	var grid := tiles(layout)
	var enc := {}
	for link in links:
		if link.kind == "gate":
			var spot := _front_of_door(layout, grid, link.a, link.dir)
			enc[link.guard] = {"group": link.guard, "room": link.a, "pos": [spot.x, spot.y], "guards": "passage", "door": [link.a, link.b]}
		elif link.kind == "route":
			var sign := _front_of_door(layout, grid, link.a, link.dir)
			layout.route_signs[link.route] = {"pos": [sign.x, sign.y], "room": link.a, "door": [link.a, link.b]}
	var boss_center := _center_floor(layout, grid, "boss")
	enc["hboss"] = {"group": "hboss", "room": "boss", "pos": [boss_center.x, boss_center.y], "guards": "exit", "door": []}
	enc.h1a["requires"] = []
	enc.h1b["requires"] = []
	enc.h2["requires"] = []
	enc.hboss["requires"] = ["h2"]
	layout.encounters = enc
	var spawn := _free_spot(layout, grid, "ent", []) if fork_id == "ent" else _center_floor(layout, grid, "ent")
	layout.spawn = [spawn.x, spawn.y]
	layout.portal = [boss_center.x, boss_center.y]
	# P5: 상인은 돌파의 방(H1을 이긴 뒤), 선택 지점은 갈림길 방, 선택 전투는 입구 방에 따로 선다 (어느 문도 지키지 않음)
	var sign_pos: Array = []
	for r in layout.route_signs:
		sign_pos.append(layout.route_signs[r].pos)
	var service_spot := _free_spot(layout, grid, "h2", [enc.h2.pos])
	layout["service"] = {"room": "h2", "pos": [service_spot.x, service_spot.y], "requires": []}
	var opt_spot := _free_spot(layout, grid, "ent", sign_pos + [layout.spawn])
	enc["elite"] = {"group": "", "room": "ent", "pos": [opt_spot.x, opt_spot.y], "guards": "none", "door": [], "requires": []}
	var choice_spot := _free_spot(layout, grid, fork_id, sign_pos + [layout.spawn, enc.elite.pos])
	layout["choice"] = {"room": fork_id, "pos": [choice_spot.x, choice_spot.y], "requires": []}
	var r2 := rng if rng != null else RandomNumberGenerator.new()
	_set_opt(layout, r2, "hard")
	return layout


static func validate_hard(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var grid := tiles(layout)
	var used_doors := {}
	for link in layout.links:
		for p in gate_tiles(layout, link):
			if used_doors.has(p):
				errors.append("overlapping door at %s" % p)
			used_doors[p] = true
	var enc: Dictionary = layout.encounters
	for id in ["h1a", "h1b", "h2", "hboss", "elite"]:
		if not enc.has(id):
			errors.append("missing " + id)
	if not errors.is_empty():
		return errors
	var r0 := reachable(layout, grid, [], false, "")
	for id in ["h1a", "h1b", "h2", "boss"]:
		if _room_reached(layout, r0, id):
			errors.append("%s reachable before route commitment" % id)
	for route in ["a", "b"]:
		var other: String = "b" if route == "a" else "a"
		var mine: String = "h1" + route
		var r1 := reachable(layout, grid, [], false, route)
		if not r1.has(_enc_pos(enc, mine)):
			errors.append("%s guardian unreachable after choosing %s" % [mine, route])
		if _room_reached(layout, r1, "h1" + other) or _room_reached(layout, r1, "h2"):
			errors.append("route %s leaks before its fight" % route)
		var r2 := reachable(layout, grid, [mine], false, route)
		if not r2.has(_enc_pos(enc, "h2")):
			errors.append("h2 unreachable after %s" % mine)
		if _room_reached(layout, r2, "h1" + other):
			errors.append("unchosen route %s reachable through h2 (route %s)" % [other, route])
		if _room_reached(layout, r2, "boss"):
			errors.append("boss reachable before h2 (route %s)" % route)
		var r3 := reachable(layout, grid, [mine, "h2"], false, route)
		if not r3.has(_enc_pos(enc, "hboss")):
			errors.append("boss unreachable after h2 (route %s)" % route)
		if _room_reached(layout, r3, "h1" + other):
			errors.append("unchosen route %s reachable at the end (route %s)" % [other, route])
		if r1.has(_v2(layout.service.pos)):
			errors.append("service reachable before %s (route %s)" % [mine, route])
		if not r2.has(_v2(layout.service.pos)):
			errors.append("service unreachable after %s" % mine)
	if not r0.has(_enc_pos(enc, "elite")):
		errors.append("optional fight unreachable at start")
	if not r0.has(_v2(layout.choice.pos)):
		errors.append("choice unreachable at start")
	return errors


static func _v2(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _enc_pos(enc: Dictionary, id: String) -> Vector2i:
	return Vector2i(int(enc[id].pos[0]), int(enc[id].pos[1]))


# 방 안쪽(벽 한 칸 안) 바닥에 하나라도 닿았는지
static func _room_reached(layout: Dictionary, reach: Dictionary, room: String) -> bool:
	var rr := room_rect(layout, room).grow(-1)
	for p in reach:
		if rr.has_point(p):
			return true
	return false


# ── P5 공통: 구간 생성 진입점 · 선택 전투 칸 (정예 또는 미믹, 구간마다 최대 하나) ───────────────

static func generate_sector(sector: String, seed_value: int) -> Dictionary:
	match sector:
		"hard":
			return generate_hard(seed_value)
		"extreme":
			return generate_extreme(seed_value)
	return generate(seed_value)


static func _set_opt(layout: Dictionary, rng: RandomNumberGenerator, sector: String) -> void:
	var kind := "elite" if rng.randi() % 2 == 0 else "mimic"
	var group := String(P2Catalog.OPT_GROUPS[sector][kind])
	layout.encounters.elite["group"] = group
	layout.encounters.elite["kind"] = kind
	layout.groups["elite"] = group


# ── 익스트림 구간: 입구 → 독의 방(X1) → 사격대의 방(X2) → 균열의 핵. 상인은 X1 뒤, 선택 지점은 X1 방, 선택 전투는 입구 ──

const EXTREME_NAMES := {"ent": "균열 입구", "a": "독의 방", "b": "사격대의 방", "boss": "균열의 핵"}


static func generate_extreme(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 53 + 17
	for attempt in range(MAX_ATTEMPTS):
		var layout := _try_extreme(rng)
		if layout.is_empty():
			continue
		if validate_extreme(layout).is_empty():
			layout["attempts"] = attempt + 1
			layout["fallback"] = false
			return layout
	var cells := {"ent": Vector2i(0, 0), "a": Vector2i(1, 0), "b": Vector2i(2, 0), "boss": Vector2i(3, 0)}
	var modules := {"ent": "atrium", "a": "hall", "b": "pillars", "boss": "sanctum"}
	var fb := _assemble_extreme(cells, modules, "fallback", rng)
	fb["attempts"] = MAX_ATTEMPTS
	fb["fallback"] = true
	return fb


static func _try_extreme(rng: RandomNumberGenerator) -> Dictionary:
	var order := ["ent", "a", "b", "boss"]
	var cells := {"ent": Vector2i.ZERO}
	var used := {Vector2i.ZERO: true}
	var pos := Vector2i.ZERO
	var path := ""
	for i in range(1, order.size()):
		var options: Array = []
		for key in ["E", "E", "N", "S", "W"]:
			var next: Vector2i = pos + DIRS[key]
			if used.has(next) or (key == "W" and i < 2):
				continue
			options.append(key)
		if options.is_empty():
			return {}
		var pick: String = options[rng.randi() % options.size()]
		pos += DIRS[pick]
		cells[order[i]] = pos
		used[pos] = true
		path += pick
	var modules := {"ent": _pick_module(rng, "entrance"), "a": _pick_module(rng, "normal"), "b": _pick_module(rng, "normal"),
		"boss": _pick_module(rng, "h_boss")}
	return _assemble_extreme(cells, modules, "XT:" + path, rng)


static func _assemble_extreme(cells: Dictionary, modules: Dictionary, signature: String, rng: RandomNumberGenerator) -> Dictionary:
	var links: Array = [
		{"a": "ent", "b": "a", "dir": _dir_between(cells.ent, cells.a), "kind": "open", "guard": ""},
		{"a": "a", "b": "b", "dir": _dir_between(cells.a, cells.b), "kind": "gate", "guard": "x1"},
		{"a": "b", "b": "boss", "dir": _dir_between(cells.b, cells.boss), "kind": "gate", "guard": "x2"},
	]
	var rooms := {}
	for id in cells:
		rooms[id] = {"cell": [cells[id].x, cells[id].y], "module": modules[id], "name": EXTREME_NAMES[id]}
	var layout := {
		"version": 2, "sector": "extreme", "template": "XT", "signature": signature,
		"cell_size": [CELL_W, CELL_H], "tile": TILE,
		"rooms": rooms, "links": links, "groups": {"x1": "x1", "x2": "x2", "xboss": "xboss"},
		"encounters": {}, "service": {}, "choice": {}, "spawn": [], "portal": [], "bar": {},
	}
	var grid := tiles(layout)
	var enc := {}
	for link in links:
		if link.kind == "gate":
			var spot := _front_of_door(layout, grid, link.a, link.dir)
			enc[link.guard] = {"group": link.guard, "room": link.a, "pos": [spot.x, spot.y], "guards": "passage", "door": [link.a, link.b], "requires": []}
	enc.x2.requires = ["x1"]
	var boss_center := _center_floor(layout, grid, "boss")
	enc["xboss"] = {"group": "xboss", "room": "boss", "pos": [boss_center.x, boss_center.y], "guards": "exit", "door": [], "requires": ["x1", "x2"]}
	var spawn := _center_floor(layout, grid, "ent")
	layout.spawn = [spawn.x, spawn.y]
	layout.portal = [boss_center.x, boss_center.y]
	var opt_spot := _free_spot(layout, grid, "ent", [layout.spawn])
	enc["elite"] = {"group": "", "room": "ent", "pos": [opt_spot.x, opt_spot.y], "guards": "none", "door": [], "requires": []}
	var choice_spot := _free_spot(layout, grid, "a", [enc.x1.pos])
	layout.choice = {"room": "a", "pos": [choice_spot.x, choice_spot.y], "requires": []}
	var service_spot := _free_spot(layout, grid, "b", [enc.x2.pos])
	layout.service = {"room": "b", "pos": [service_spot.x, service_spot.y], "requires": ["x1"]}
	layout.encounters = enc
	_set_opt(layout, rng, "extreme")
	return layout


static func validate_extreme(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var grid := tiles(layout)
	var used_doors := {}
	for link in layout.links:
		for p in gate_tiles(layout, link):
			if used_doors.has(p):
				errors.append("overlapping door at %s" % p)
			used_doors[p] = true
	var enc: Dictionary = layout.encounters
	for id in ["x1", "x2", "xboss", "elite"]:
		if not enc.has(id):
			errors.append("missing " + id)
	if not errors.is_empty():
		return errors
	var r0 := reachable(layout, grid, [], false)
	if not r0.has(_enc_pos(enc, "x1")) or not r0.has(_enc_pos(enc, "elite")) or not r0.has(_v2(layout.choice.pos)):
		errors.append("x1/optional/choice unreachable at start")
	if r0.has(_v2(layout.service.pos)) or r0.has(_enc_pos(enc, "xboss")):
		errors.append("service or boss reachable before x1")
	var r1 := reachable(layout, grid, ["x1"], false)
	if not r1.has(_enc_pos(enc, "x2")) or not r1.has(_v2(layout.service.pos)):
		errors.append("x2/service unreachable after x1")
	if r1.has(_enc_pos(enc, "xboss")):
		errors.append("boss reachable before x2")
	if not reachable(layout, grid, ["x1", "x2"], false).has(_enc_pos(enc, "xboss")):
		errors.append("boss unreachable after x1,x2")
	return errors
