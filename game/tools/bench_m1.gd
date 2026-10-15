class_name BenchM1
extends RefCounted
## A synthetic load shaped like an M1 run, to decide GDScript versus Rust with numbers: the 6-room
## tower with 3 crew and hazards running, plus a rock grid that the drill bites every tick (the
## drilling segment's hot loop) and two dozen projectiles moving and hit-testing (combat).
## Reports ticks per second and microseconds per tick for each part.

const GRID_W: int = 256
const GRID_H: int = 1024
const BITE_R: int = 6
const PROJECTILES: int = 24


static func run(db: DataDB, ticks: int) -> Dictionary:
	var sim := Sim.new(db, 99, "light_drill")
	sim.push({"type": "ignite", "room": "drill", "level": 0.3})
	sim.push({"type": "ignite", "room": "quarters", "level": 0.2})
	sim.push({"type": "breach", "room": "weapons", "size_m2": 0.02})
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var grid := PackedByteArray()
	grid.resize(GRID_W * GRID_H)
	for i: int in range(grid.size()):
		grid[i] = 1 + rng.randi_range(0, 4)
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	for i: int in range(PROJECTILES):
		pos.append(Vector2(rng.randf_range(10.0, GRID_W - 10.0), rng.randf_range(10.0, 200.0)))
		vel.append(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
	var drill := Vector2(GRID_W * 0.5, 20.0)
	var removed: int = 0
	var hits: int = 0
	var t_sim: int = 0
	var t_grid: int = 0
	var t_proj: int = 0
	var r2: int = BITE_R * BITE_R
	var start: int = Time.get_ticks_usec()
	for t: int in range(ticks):
		var a: int = Time.get_ticks_usec()
		sim.step()
		if t % 1800 == 900:
			sim.push({"type": "ignite", "room": "reactor", "level": 0.2})
		var b: int = Time.get_ticks_usec()
		drill.y = minf(float(GRID_H - BITE_R - 2), drill.y + 0.25)
		drill.x = GRID_W * 0.5 + sin(float(t) * 0.01) * 60.0
		var cx: int = int(drill.x)
		var cy: int = int(drill.y)
		for dy: int in range(-BITE_R, BITE_R + 1):
			var row: int = (cy + dy) * GRID_W + cx
			for dx: int in range(-BITE_R, BITE_R + 1):
				if dx * dx + dy * dy <= r2:
					var m: int = grid[row + dx]
					if m != 0:
						removed += m
						grid[row + dx] = 0
		var c: int = Time.get_ticks_usec()
		for i: int in range(PROJECTILES):
			var p: Vector2 = pos[i] + vel[i]
			var gx: int = clampi(int(p.x), 0, GRID_W - 1)
			var gy: int = clampi(int(p.y), 0, GRID_H - 1)
			if grid[gy * GRID_W + gx] != 0 or p.x < 1.0 or p.x > GRID_W - 1.0 or p.y < 1.0 or p.y > GRID_H - 1.0:
				vel[i] = -vel[i]
				hits += 1
			else:
				pos[i] = p
			for room: Room in sim.ship.rooms:
				if room.rect.has_point(p * 0.05):
					hits += 1
		t_sim += b - a
		t_grid += c - b
		t_proj += Time.get_ticks_usec() - c
	var secs: float = float(Time.get_ticks_usec() - start) / 1_000_000.0
	return {
		"ticks": ticks,
		"secs": snappedf(secs, 0.001),
		"ticks_per_sec": roundi(float(ticks) / maxf(secs, 0.000001)),
		"us_per_tick_sim": snappedf(float(t_sim) / float(ticks), 0.01),
		"us_per_tick_terrain": snappedf(float(t_grid) / float(ticks), 0.01),
		"us_per_tick_projectiles": snappedf(float(t_proj) / float(ticks), 0.01),
		"removed": removed,
		"hits": hits,
		"final_hash": sim.state_hash(),
	}
