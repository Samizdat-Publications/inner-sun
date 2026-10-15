class_name Ship
extends RefCounted
## A ship built from its data definition: rooms, doors and hatches, the walls rooms share, the crew
## and the walking graph. Holds no reference back to the Sim (no reference cycles, so no leaks).

const EPS: float = 0.01

var id: String = ""
var name: String = ""
var rooms: Array[Room] = []
var links: Array[Link] = []
var walls: Array[WallPair] = []
var crew: Array[CrewMember] = []
var nav: NavGraph
var rock_temp_c: float = 40.0
var water_head_m: float = 20.0
var hull_max: int = 30  ## Hull integrity at full repair (the run keeps the current value).
var weapons: PackedStringArray = PackedStringArray()  ## Weapon ids mounted, in slot order.
var source_def: Dictionary = {}  ## The raw definition, for modules that read their own keys.
var _room_ids: Dictionary = {}
var _crew_ids: Dictionary = {}


static func from_def(def: Dictionary) -> Ship:
	var s := Ship.new()
	s.id = str(def.get("id", ""))
	s.name = str(def.get("name", s.id))
	s.rock_temp_c = float(def.get("rock_temp_c", 40.0))
	s.water_head_m = float(def.get("water_head_m", 20.0))
	s.hull_max = int(def.get("hull", 30))
	s.source_def = def
	for w: Variant in def.get("weapons", []):
		s.weapons.append(str(w))
	var depth: float = float(def.get("room_depth_m", 3.0))
	for rd: Dictionary in def.get("rooms", []):
		var r := Room.new()
		r.id = str(rd["id"])
		r.index = s.rooms.size()
		r.name = str(rd.get("name", r.id))
		r.rect = Rect2(float(rd["x"]), float(rd["y"]), float(rd["w"]), float(rd["h"]))
		r.depth_m = depth
		r.system = str(rd.get("system", "none"))
		r.has_pump = bool(rd.get("pump", false))
		r.start_temp_c = float(rd.get("temp_c", 22.0))
		r.sys_max = int(rd.get("bars", 0))
		r.sys_power = int(rd.get("power", r.sys_max))
		r.capacity_ml = roundi(r.capacity_m3() * Room.ML_PER_M3)
		s._room_ids[r.id] = r.index
		s.rooms.append(r)
	for ld: Dictionary in def.get("links", []):
		var l := Link.new()
		l.id = str(ld["id"])
		l.index = s.links.size()
		l.kind = Link.Kind.HATCH if str(ld.get("kind", "door")) == "hatch" else Link.Kind.DOOR
		l.a = s.room_index(str(ld["a"]))
		l.b = s.room_index(str(ld["b"]))
		l.x = float(ld["x"])
		l.height_m = float(ld.get("height_m", 2.0))
		l.span_m = float(ld.get("span_m", 0.8))
		l.breadth_m = float(ld.get("breadth_m", 1.0))
		l.open = bool(ld.get("open", true))
		if l.a < 0 or l.b < 0:
			# Never let a bad reference wrap around to another room (arrays accept index -1).
			push_error("ship \"%s\": link \"%s\" joins a room that does not exist; skipped (run the data lint)" % [s.id, l.id])
			continue
		s.links.append(l)
	s._find_walls()
	for cd: Dictionary in def.get("crew", []):
		s.add_crew(cd)
	s.nav = NavGraph.build(s)
	return s


## Add a crew member from a definition ({id, name, room, x?, skills?}). Used when the ship is built
## and when someone joins mid-run. Returns null (and adds nobody) if the id is taken or the room
## does not exist.
func add_crew(cd: Dictionary) -> CrewMember:
	var cid: String = str(cd.get("id", ""))
	var ri: int = room_index(str(cd.get("room", "")))
	if cid.is_empty() or _crew_ids.has(cid) or ri < 0:
		push_error("ship \"%s\": cannot add crew \"%s\" (duplicate id or unknown room)" % [id, cid])
		return null
	var c := CrewMember.new()
	c.id = cid
	c.index = crew.size()
	c.name = str(cd.get("name", c.id))
	c.room = ri
	c.start_room = ri
	var start_room: Room = rooms[ri]
	c.pos = Vector2(float(cd.get("x", start_room.center_floor().x)), start_room.floor_y())
	var skills: Dictionary = cd.get("skills", {})
	c.skill_fire = float(skills.get("fire", 1.0))
	c.skill_repair = float(skills.get("repair", 1.0))
	_crew_ids[c.id] = c.index
	crew.append(c)
	return c


func room_index(room_id: String) -> int:
	return int(_room_ids.get(room_id, -1))


func crew_by_id(crew_id: String) -> CrewMember:
	var i: int = int(_crew_ids.get(crew_id, -1))
	return crew[i] if i >= 0 else null


func room_with_system(system: String) -> int:
	for r: Room in rooms:
		if r.system == system:
			return r.index
	return -1


## The room containing a point, judged just above the floor line. Keeps `fallback` if none.
func room_at(p: Vector2, fallback: int) -> int:
	var probe := Vector2(p.x, p.y - 0.05)
	for r: Room in rooms:
		if r.rect.has_point(probe):
			return r.index
	return fallback


func total_water_ml() -> int:
	var sum: int = 0
	for r: Room in rooms:
		sum += r.water_ml
	return sum


func total_energy_j() -> int:
	var sum: int = 0
	for r: Room in rooms:
		sum += r.energy_j
	return sum


func _find_walls() -> void:
	var shared := PackedFloat64Array()
	shared.resize(rooms.size())
	for i: int in range(rooms.size()):
		for j: int in range(i + 1, rooms.size()):
			var ri: Rect2 = rooms[i].rect
			var rj: Rect2 = rooms[j].rect
			var w := WallPair.new()
			if absf(ri.end.x - rj.position.x) < EPS or absf(rj.end.x - ri.position.x) < EPS:
				w.length_m = minf(ri.end.y, rj.end.y) - maxf(ri.position.y, rj.position.y)
				w.vertical = true
				w.a = i
				w.b = j
			elif absf(ri.end.y - rj.position.y) < EPS or absf(rj.end.y - ri.position.y) < EPS:
				w.length_m = minf(ri.end.x, rj.end.x) - maxf(ri.position.x, rj.position.x)
				w.vertical = false
				var i_above: bool = ri.end.y <= rj.position.y + EPS
				w.a = i if i_above else j
				w.b = j if i_above else i
			if w.length_m > EPS:
				w.area_m2 = w.length_m * rooms[i].depth_m
				walls.append(w)
				shared[i] += w.length_m
				shared[j] += w.length_m
	for r: Room in rooms:
		var perimeter: float = 2.0 * (r.rect.size.x + r.rect.size.y)
		r.hull_area_m2 = maxf(0.0, perimeter - shared[r.index]) * r.depth_m
