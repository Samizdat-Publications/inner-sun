class_name CombatHits
extends RefCounted
## What a round or a beam does to the ship it strikes. Static functions; the struck ShipWorld, the
## Sim and the attacker's random stream are passed in. The order is fixed and every roll comes from
## the attacker's "combat" stream ("combat" or "enemy/combat"):
##   1. evasion: one roll against Systems.evasion(target); below it, a miss ("shot_missed");
##   2. bracing: a projectile spends a layer (Systems.absorb_hit) and stops; a beam loses one damage
##      per layer in every room it crosses and spends nothing; a charge ignores bracing;
##   3. per room struck, with damage left: system damage (Systems.damage_room), crew damage to
##      everyone in the room, then a fire roll and a breach roll;
##   4. heat: every room struck takes the weapon's heat through HazardSim.add_heat (exact joules;
##      a beam heats even through bracing).
## The functions return the hull damage; CombatSim takes it off the right hull.


## A projectile or charge arriving at room ri. Returns the hull damage it does.
static func projectile(sim: Sim, tw: ShipWorld, ri: int, w: WeaponDef, rng: RandomNumberGenerator, fire_level: float) -> int:
	var r: Room = tw.ship.rooms[ri]
	if rng.randf() < sim.systems.evasion(tw):
		tw.emit(sim, "shot_missed", {"room": r.id, "weapon": w.id})
		return 0
	if not w.pierces_bracing and sim.systems.absorb_hit(sim, tw):
		return 0
	_strike(sim, tw, ri, w, w.damage, rng, fire_level)
	return w.damage


## A beam fired at the rooms of its sweep (from beam_rooms). Returns the total hull damage.
static func beam(sim: Sim, tw: ShipWorld, rooms: PackedInt32Array, w: WeaponDef, rng: RandomNumberGenerator, fire_level: float) -> int:
	if rooms.is_empty():
		return 0
	if rng.randf() < sim.systems.evasion(tw):
		tw.emit(sim, "shot_missed", {"room": tw.ship.rooms[rooms[0]].id, "weapon": w.id})
		return 0
	var per_room: int = maxi(0, w.damage - sim.systems.bracing_layers(tw))
	var total: int = 0
	for ri: int in rooms:
		if per_room > 0:
			_strike(sim, tw, ri, w, per_room, rng, fire_level)
			total += per_room
		else:
			tw.hazards.add_heat(tw.ship.rooms[ri], w.heat_j)
			tw.emit(sim, "beam_blocked", {"room": tw.ship.rooms[ri].id, "weapon": w.id})
	return total


## The rooms a beam aimed at room ri crosses, in room order, and the sweep segment in ship space
## (written into seg: start, end). The sweep runs straight down from the target room's center for
## beam_len_m, shifted up if it would leave the bottom of the ship.
static func beam_rooms(ship: Ship, ri: int, length_m: float, seg: PackedVector2Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c: Vector2 = ship.rooms[ri].rect.get_center()
	var bottom: float = 0.0
	var top: float = INF
	for r: Room in ship.rooms:
		bottom = maxf(bottom, r.rect.end.y)
		top = minf(top, r.rect.position.y)
	var y0: float = c.y
	var y1: float = c.y + length_m
	if y1 > bottom:
		y0 = maxf(top, y0 - (y1 - bottom))
		y1 = bottom
	for r: Room in ship.rooms:
		if c.x < r.rect.position.x or c.x >= r.rect.end.x:
			continue
		if minf(r.rect.end.y, y1) - maxf(r.rect.position.y, y0) > 0.01 or r.index == ri:
			out.append(r.index)
	seg.resize(2)
	seg[0] = Vector2(c.x, y0)
	seg[1] = Vector2(c.x, y1)
	return out


## Everyone alive in room ri loses hp; the dead die of "combat".
static func harm_crew(sim: Sim, tw: ShipWorld, ri: int, hp: float) -> void:
	if hp <= 0.0:
		return
	for c: CrewMember in tw.ship.crew:
		if not c.alive or c.room != ri:
			continue
		c.hp -= hp
		tw.emit(sim, "crew_hit", {"crew": c.id, "hp": hp})
		if c.hp <= 0.0:
			c.hp = 0.0
			c.alive = false
			c.path = PackedVector2Array()
			c.cause_of_death = "combat"
			tw.emit(sim, "crew_died", {"crew": c.id, "cause": "combat"})


static func _strike(sim: Sim, tw: ShipWorld, ri: int, w: WeaponDef, dmg: int, rng: RandomNumberGenerator, fire_level: float) -> void:
	var r: Room = tw.ship.rooms[ri]
	tw.emit(sim, "room_hit", {"room": r.id, "weapon": w.id, "damage": dmg})
	sim.systems.damage_room(sim, tw, ri, w.sys_damage)
	harm_crew(sim, tw, ri, w.crew_damage)
	var fire_roll: float = rng.randf()
	var breach_roll: float = rng.randf()
	if fire_roll < w.fire_chance:
		tw.hazards.ignite(sim, tw, r, fire_level)
	if breach_roll < w.breach_chance and w.breach_m2 > 0.0:
		r.breach_m2 += w.breach_m2
		tw.emit(sim, "breach", {"room": r.id})
	tw.hazards.add_heat(r, w.heat_j)
