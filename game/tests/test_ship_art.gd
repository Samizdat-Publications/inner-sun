extends TestCase
## The painted cutaway: every texture the view names exists, crew get a figure, the rock tiles map,
## and ShipView builds and runs for the player's ship and every enemy ship without errors.


func test_room_art_files_exist() -> void:
	for sys: String in RoomArt.WALL_ART.keys():
		check(ArtLib.lit("ship", str(RoomArt.WALL_ART[sys]) + "_wall") != null, "wall art for " + sys)
	for sys: String in RoomArt.PROPS.keys():
		for entry: Array in RoomArt.PROPS[sys]:
			check(ArtLib.lit("ship", str(entry[0])) != null, "prop art " + str(entry[0]))
	for n: String in ["door_closed", "door_open", "ladder", "hatch_rim", "floor_grating", "hull_top", "hull_left", "hull_right", "drill_crown"]:
		check(ArtLib.lit("ship", n) != null, "fitting " + n)
	check(ArtLib.lamp_texture() != null, "lamp texture")


func test_crew_art_mapping() -> void:
	var c := CrewMember.new()
	c.id = "vasquez"
	check_eq((CrewSprite.art_for(c, false))[0], "vasquez", "named crew keep their figure")
	c.id = "duarte"
	var a: Array = CrewSprite.art_for(c, false)
	check(["vasquez", "okafor", "lindqvist"].has(str(a[0])), "a recruit borrows a player figure")
	c.id = "rival_pilot"
	c.index = 1
	check_eq((CrewSprite.art_for(c, true))[0], "rival_b", "enemy crew use the rivals")


func test_rock_tiles_map() -> void:
	check_eq(RockTiles.slot_of("rock"), 1, "granite has its own slot (the dense tile, tinted)")
	check_eq(RockTiles.slot_of("dense_rock"), 2, "gneiss slot")
	check(RockTiles.FILES[RockTiles.slot_of("rock")] == "dense", "granite uses the dense tile, never rock_albedo")
	check(RockTiles.emission_image() != null, "gem emission tile loads")


func test_ship_view_builds_and_runs() -> void:
	var s := Sim.new(db(), 3, "light_drill")
	for ship_id: String in ["light_drill", "rival_light", "rival_raider", "rival_heavy"]:
		var world: ShipWorld = s.player if ship_id == "light_drill" else ShipWorld.new(s.db, s.db.ships[ship_id], "enemy")
		var v := ShipView.new()
		v.setup(s, world, 80.0)
		for i: int in range(4):
			v._process(0.016)
		for r: Room in world.ship.rooms:
			r.fire = 0.5
			r.water_ml = 400000
		v._process(0.016)
		check(v.ship_size_m().x > 0.0, "ship size for " + ship_id)
		v.free()


func test_label_avoids_ladders() -> void:
	var s := Sim.new(db(), 3, "light_drill")
	var ship: Ship = s.player.ship
	var reactor: Room = ship.rooms[ship.room_index("reactor")]
	check(RoomFx.label_on_right(ship, reactor, 80.0, 90.0), "the reactor label moves right of the ladder from the bridge")
	var bridge: Room = ship.rooms[ship.room_index("bridge")]
	check(not RoomFx.label_on_right(ship, bridge, 80.0, 90.0), "the bridge has no ladder from above")
