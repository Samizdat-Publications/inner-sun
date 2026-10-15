class_name NavGraph
extends RefCounted
## The walking graph for crew: one point per room floor, one per door, and two per hatch (the top
## and bottom of its ladder). Godot's AStar2D works without the scene tree, so this runs headless.

enum PointKind { ROOM, DOOR, HATCH_TOP, HATCH_BOTTOM }

const CLIMB_WEIGHT: float = 2.0

var astar: AStar2D = AStar2D.new()
var room_point: PackedInt32Array = PackedInt32Array()
var point_kind: Dictionary = {}


static func build(ship: Ship) -> NavGraph:
	var g := NavGraph.new()
	for r: Room in ship.rooms:
		g.room_point.append(g._add(r.center_floor(), PointKind.ROOM))
	for l: Link in ship.links:
		if l.kind == Link.Kind.DOOR:
			var p: int = g._add(Vector2(l.x, ship.rooms[l.a].floor_y()), PointKind.DOOR)
			g.astar.connect_points(p, g.room_point[l.a])
			g.astar.connect_points(p, g.room_point[l.b])
		else:
			var top: int = g._add(Vector2(l.x, ship.rooms[l.a].floor_y()), PointKind.HATCH_TOP)
			var bottom: int = g._add(Vector2(l.x, ship.rooms[l.b].floor_y()), PointKind.HATCH_BOTTOM)
			g.astar.set_point_weight_scale(top, CLIMB_WEIGHT)
			g.astar.set_point_weight_scale(bottom, CLIMB_WEIGHT)
			g.astar.connect_points(top, g.room_point[l.a])
			g.astar.connect_points(top, bottom)
			g.astar.connect_points(bottom, g.room_point[l.b])
	return g


func _add(p: Vector2, kind: PointKind) -> int:
	var pid: int = astar.get_available_point_id()
	astar.add_point(pid, p)
	point_kind[pid] = kind
	return pid


## Waypoints from where a crew member stands to x on the floor of `to_room`. Room centers in the
## middle of a route are skipped (crew walk straight along a floor from door to door).
func route(ship: Ship, from_room: int, to_room: int, to_x: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if from_room != to_room:
		var ids: PackedInt64Array = astar.get_id_path(room_point[from_room], room_point[to_room])
		if ids.is_empty():
			return pts
		for pid: int in ids:
			if int(point_kind[pid]) != PointKind.ROOM:
				pts.append(astar.get_point_position(pid))
	pts.append(Vector2(to_x, ship.rooms[to_room].floor_y()))
	return pts


## Length in meters of a route from a position, split into walking and climbing.
static func route_lengths(from_pos: Vector2, pts: PackedVector2Array) -> Vector2:
	var walk: float = 0.0
	var climb: float = 0.0
	var prev: Vector2 = from_pos
	for p: Vector2 in pts:
		var d: Vector2 = p - prev
		if absf(d.x) < 0.001 and absf(d.y) > 0.001:
			climb += absf(d.y)
		else:
			walk += d.length()
		prev = p
	return Vector2(walk, climb)
