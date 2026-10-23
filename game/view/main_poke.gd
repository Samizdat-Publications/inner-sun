class_name MainPoke
extends RefCounted
## Dev only (--poke=a,b,c, with --scenario and --shots): puts a state on screen for a still by pushing
## ordinary commands at the start, the way --fight does. Never used in normal play, a capture or a replay.
##   close:<link id>    shut a door or hatch          purge:<room id>   open a room's purge vent
##   ignite:<room id>   light a fire there            env:<id>          put an environment in force
##   manual             crew automation off           box               show a selection box over the bridge crew

static func apply(m: Main, list: PackedStringArray) -> void:
	var s: Sim = m.run.sim
	for token: String in list:
		var parts: PackedStringArray = token.split(":")
		var arg: String = parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"close":
				s.push({"type": "door", "link": arg, "open": false})
			"purge":
				s.push({"type": "purge", "room": arg, "open": true})
			"ignite":
				s.push({"type": "ignite", "room": arg, "level": 0.8})
			"env":
				s.push({"type": "set_env", "env": arg})
			"manual":
				for c: CrewMember in s.ship.crew:
					s.push({"type": "auto", "crew": c.id, "on": false})
			"box":
				var bridge: Room = s.ship.rooms[s.ship.room_index("bridge")]
				var box := Rect2(bridge.rect.position * Main.PPM + Vector2(30.0, 40.0), Vector2(bridge.rect.size.x * Main.PPM - 60.0, bridge.rect.size.y * Main.PPM - 30.0))
				ShipPick.of(m).demo_box(box)
