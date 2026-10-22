extends TestCase
## Parity round 1, economy rows (docs/research/behavior-ledger.md: L-UPG-01, L-UPG-02, L-UPG-04,
## L-RWD-01 to L-RWD-04; spec docs/plans/specs/m2p_economy.md). Each test measures the row's Target
## with a judge function that returns "" for a pass or the reason it fails, then applies the row's
## Wrong value in memory and asserts the same judge now fails. Measured values print as LEDGER lines.

const LIGHT: String = "light_drill"
## Today's flat upgrade prices (the anchor of L-UPG-01's first purchasable step).
const ANCHOR: Dictionary = {"helm": 120, "bracing": 140, "weapons": 160, "drill": 150, "coolant": 120}
const SYSTEMS: Array[String] = ["helm", "bracing", "weapons", "drill", "coolant"]


## The light drill's starting bars per system.
func _start_bars(d: DataDB) -> Dictionary:
	var out: Dictionary = {}
	for rd: Variant in (d.ships[LIGHT] as Dictionary)["rooms"]:
		out[str((rd as Dictionary)["system"])] = int((rd as Dictionary)["bars"])
	return out


func _ladder(d: DataDB, sys: String) -> Array:
	return (d.table("systems")[sys] as Dictionary)["bar_prices"]


# L-UPG-01 ----------------------------------------------------------------------------------------

func _judge_upg_01(d: DataDB) -> String:
	var start: Dictionary = _start_bars(d)
	for sys: String in SYSTEMS:
		var lad: Array = _ladder(d, sys)
		for i: int in range(1, lad.size()):
			if int(lad[i]) <= int(lad[i - 1]):
				return "%s ladder does not rise at bar %d" % [sys, i + 1]
		var s0: int = int(start[sys])
		if lad.size() - s0 < 2:
			return "%s: only %d bars to buy past %d" % [sys, lad.size() - s0, s0]
		var first: float = float(lad[s0])
		var anchor: float = first / float(ANCHOR[sys])
		print("LEDGER L-UPG-01 %s first %d (%.2f x today's %d)" % [sys, int(first), anchor, int(ANCHOR[sys])])
		if anchor < 0.5 or anchor > 1.0:
			return "%s first purchasable step %.0f is %.2f x today's price" % [sys, first, anchor]
		for i: int in range(s0 + 1, lad.size()):
			var step: float = float(int(lad[i]) - int(lad[i - 1])) / first
			print("LEDGER L-UPG-01 %s bar %d adds %.2f x the first step" % [sys, i + 1, step])
			if step < 0.4 or step > 0.9:
				return "%s bar %d adds %.2f x the first step" % [sys, i + 1, step]
	return ""


func test_l_upg_01() -> void:
	var d: DataDB = db()
	var why: String = _judge_upg_01(d)
	check(why.is_empty(), "L-UPG-01 target: " + why)
	for sys: String in SYSTEMS:  # Wrong value: a flat ladder.
		var lad: Array = _ladder(d, sys)
		for i: int in range(lad.size()):
			lad[i] = 100
	check(not _judge_upg_01(d).is_empty(), "L-UPG-01 wrong value (flat ladders) must fail")


# L-UPG-02 ----------------------------------------------------------------------------------------

func _judge_upg_02(d: DataDB) -> String:
	var start: Dictionary = _start_bars(d)
	var lad: Array = _ladder(d, "reactor")
	var s0: int = int(start["reactor"])
	if lad.size() - s0 < 6:
		return "the light drill can buy only %d reactor bars" % (lad.size() - s0)
	if lad.size() % 2 != 0:
		return "the reactor ladder is not whole pairs"
	for k: int in range(0, lad.size(), 2):
		if int(lad[k]) != int(lad[k + 1]):
			return "reactor bars %d and %d differ" % [k + 1, k + 2]
		if k > 0:
			var rise: float = float(lad[k]) / float(lad[k - 2])
			print("LEDGER L-UPG-02 pair %d costs %.2f x the pair before" % [k / 2 + 1, rise])
			if rise < 1.2 or rise > 1.5:
				return "reactor pair %d costs %.2f x the pair before" % [k / 2 + 1, rise]
	var others: float = 0.0
	for sys: String in SYSTEMS:
		others += float(_ladder(d, sys)[int(start[sys])])
	others /= float(SYSTEMS.size())
	var ratio: float = float(lad[s0]) / others
	print("LEDGER L-UPG-02 first reactor bar %d = %.2f x the mean first system step %.1f" % [int(lad[s0]), ratio, others])
	if ratio < 0.4 or ratio > 0.8:
		return "the first reactor bar is %.2f x the other systems' first step" % ratio
	return ""


func test_l_upg_02() -> void:
	var d: DataDB = db()
	var why: String = _judge_upg_02(d)
	check(why.is_empty(), "L-UPG-02 target: " + why)
	var lad: Array = _ladder(d, "reactor")  # Wrong value: every reactor bar at one price.
	for i: int in range(lad.size()):
		lad[i] = 60
	check(not _judge_upg_02(d).is_empty(), "L-UPG-02 wrong value (one reactor price) must fail")


# L-UPG-04 ----------------------------------------------------------------------------------------

## Judges one multi-bar purchase: what was paid for n bars from `start`, the price the line showed
## afterwards, and the refusal at the top.
func _judge_upg_04(paid: int, lad: Array, start: int, n: int, shown_after: int, top_why: String) -> String:
	var want: int = 0
	for i: int in range(start, start + n):
		want += int(lad[i])
	if paid != want:
		return "paid %d for %d bars, the ladder says %d" % [paid, n, want]
	var next: int = int(lad[start + n]) if start + n < lad.size() else 0
	if shown_after != next:
		return "the line shows %d after the purchase, the next bar costs %d" % [shown_after, next]
	if not top_why.contains("top"):
		return "a system at its top is not refused with a reason (\"%s\")" % top_why
	return ""


func test_l_upg_04() -> void:
	var d: DataDB = db()
	var st: Dictionary = d.table("stores")["crust_trader"]
	st["sections_shown"] = [1, 1]
	(st["sections"] as Array).resize(1)  # Systems only, every system offered.
	((st["sections"] as Array)[0] as Dictionary)["offers"] = [6, 6]
	var s := Sim.new(d, 5, LIGHT, {"mode": "run"})
	s.run.add(s, "ore", 5000)
	s.encounter.open_store(s, "crust_trader")
	var li: int = -1
	for i: int in range(s.encounter.visit.size()):
		if str(s.encounter.visit[i]["system"]) == "bracing":
			li = i
	check(li >= 0, "the bracing line is offered")
	var line: Dictionary = s.encounter.visit[li]
	check(not line.has("limit") and int(line["stock"]) == -1, "an offered system line has no per-visit limit")
	var ore0: int = s.run.get_res("ore")
	var lad: Array = _ladder(d, "bracing")
	s.push({"type": "buy", "item": li, "qty": 3})
	s.step()
	var paid: int = ore0 - s.run.get_res("ore")
	var shown: int = int(s.encounter.visit[li]["price"])
	s.push({"type": "buy", "item": li, "qty": 1})
	s.step()
	s.push({"type": "buy", "item": li, "qty": 1})
	s.step()
	var top_why: String = EncounterStore.refusal(s, s.encounter, li, 1)
	print("LEDGER L-UPG-04 three bracing bars from 2: paid %d, next shown %d, at the top: \"%s\"" % [paid, shown, top_why])
	var why: String = _judge_upg_04(paid, lad, 2, 3, shown, top_why)
	check(why.is_empty(), "L-UPG-04 target: " + why)
	check_eq(room(s, "bracing").sys_max, 6, "bracing climbed to its top")
	# Wrong value: n x the first price for n bars (a code rule, so it is fed to the same judge).
	check(not _judge_upg_04(3 * int(lad[2]), lad, 2, 3, shown, top_why).is_empty(), "L-UPG-04 wrong value (n x the first price) must fail")


# L-RWD-01 and L-RWD-03 -------------------------------------------------------------------------

## Mean medium-tier haul value (ore + gems x economy.gem_ore_value) of `n` won fights per row, for
## rows 1..`last` (index = row).
func _hauls(d: DataDB, n: int, last: int = 13) -> PackedFloat64Array:
	var s := Sim.new(d, 11, LIGHT, {"mode": "run"})
	var gem: float = d.tune("economy.gem_ore_value")
	var out := PackedFloat64Array()
	out.resize(14)
	for row: int in range(1, last + 1):
		var total: float = 0.0
		for i: int in range(n):
			var got: Dictionary = CombatLoot.roll(s, d, false, row)
			total += float(int(got["ore"])) + float(int(got["gems"])) * gem
		s.events.clear()
		out[row] = total / float(n)
	return out


func _judge_rwd_01(m: PackedFloat64Array) -> String:
	var ratio: float = m[13] / m[1]
	print("LEDGER L-RWD-01 mean haul row 1 %.1f, row 13 %.1f, ratio %.2f" % [m[1], m[13], ratio])
	if ratio < 3.0 or ratio > 5.0:
		return "row 13 pays %.2f x row 1" % ratio
	var last: float = -1.0
	for b: int in range(4):
		var band: float = (m[1 + 3 * b] + m[2 + 3 * b] + m[3 + 3 * b]) / 3.0
		print("LEDGER L-RWD-01 rows %d-%d mean %.1f" % [1 + 3 * b, 3 + 3 * b, band])
		if band <= last:
			return "rows %d-%d do not pay more than the band before" % [1 + 3 * b, 3 + 3 * b]
		last = band
	if m[13] <= last:
		return "row 13 does not pay more than rows 10-12"
	return ""


func test_l_rwd_01() -> void:
	var why: String = _judge_rwd_01(_hauls(db(), 2000))
	check(why.is_empty(), "L-RWD-01 target: " + why)
	var flat: DataDB = db({"economy.reward_ore_per_row": 0.0, "economy.reward_gems_per_row": 0.0})
	check(not _judge_rwd_01(_hauls(flat, 2000)).is_empty(), "L-RWD-01 wrong value (no growth per row) must fail")


func _judge_rwd_03(m: PackedFloat64Array) -> String:
	print("LEDGER L-RWD-03 mean medium haul at row 1: %.1f" % m[1])
	if m[1] < 45.0 or m[1] > 70.0:
		return "row 1 pays %.1f" % m[1]
	return ""


func test_l_rwd_03() -> void:
	var why: String = _judge_rwd_03(_hauls(db(), 2000, 1))
	check(why.is_empty(), "L-RWD-03 target: " + why)
	var half: DataDB = db({"economy.reward_ore_row1": 10.0, "economy.reward_gems_row1": 3.0})
	check(not _judge_rwd_03(_hauls(half, 2000, 1)).is_empty(), "L-RWD-03 wrong value (row-1 base halved) must fail")


# L-RWD-02 ----------------------------------------------------------------------------------------

func _judge_rwd_02(d: DataDB) -> String:
	var s := Sim.new(d, 13, LIGHT, {"mode": "run"})
	var row: int = 7
	var base: float = Rewards.base(d, "ore", row)
	var bands: Dictionary = {"low": Vector2(0.6, 0.75), "medium": Vector2(0.95, 1.05), "high": Vector2(1.35, 1.6)}
	for tier: String in Rewards.TIERS:
		var total: float = 0.0
		for i: int in range(10000):
			total += float(Rewards.roll(s, "ore", tier, row))
		var mean: float = total / 10000.0 / base
		print("LEDGER L-RWD-02 %s mean %.3f of the row base" % [tier, mean])
		var band: Vector2 = bands[tier]
		if mean < band.x or mean > band.y:
			return "%s mean %.3f of the base" % [tier, mean]
	if Rewards.spread(d, "low").y < Rewards.spread(d, "medium").x or Rewards.spread(d, "medium").y < Rewards.spread(d, "high").x:
		return "the tiers do not overlap"
	return ""


func test_l_rwd_02() -> void:
	var why: String = _judge_rwd_02(db())
	check(why.is_empty(), "L-RWD-02 target: " + why)
	var one: DataDB = db({"economy.tier_low_min": 0.8, "economy.tier_low_max": 1.2, "economy.tier_high_min": 0.8,
		"economy.tier_high_max": 1.2})
	check(not _judge_rwd_02(one).is_empty(), "L-RWD-02 wrong value (one spread for all tiers) must fail")


# L-RWD-04 ----------------------------------------------------------------------------------------

## Supplies from the same seeded fight at rows 1 and 13: [[cells1, charges1, cells13, charges13]].
func _supply_pairs(d: DataDB) -> Array:
	var out: Array = []
	for sd: int in range(1, 201):
		var a := Sim.new(d, sd, LIGHT, {"mode": "run"})
		var b := Sim.new(d, sd, LIGHT, {"mode": "run"})
		var la: Dictionary = CombatLoot.roll(a, d, false, 1)
		var lb: Dictionary = CombatLoot.roll(b, d, false, 13)
		out.append([int(la["cells"]), int(la["charges"]), int(lb["cells"]), int(lb["charges"]), int(la["ore"]), int(lb["ore"])])
	return out


func _judge_rwd_04_loot(pairs: Array) -> String:
	var more_ore: int = 0
	for p: Variant in pairs:
		var q: Array = p
		if int(q[0]) != int(q[2]) or int(q[1]) != int(q[3]):
			return "supplies differ between rows 1 and 13 (%s)" % str(q)
		if int(q[5]) > int(q[4]):
			more_ore += 1
	if more_ore != pairs.size():
		return "ore did not scale in %d fights" % (pairs.size() - more_ore)
	return ""


func _lint_rejects_fixed_payouts(d: DataDB) -> bool:
	return " ".join(d.lint()).contains("use a reward tier")


func test_l_rwd_04() -> void:
	var d: DataDB = db()
	check(not _lint_rejects_fixed_payouts(d), "the real events carry no fixed ore or gems payout")
	var errs: PackedStringArray = d.lint()
	check(errs.is_empty(), "the real data lints clean: " + " | ".join(errs))
	var pairs: Array = _supply_pairs(d)
	var why: String = _judge_rwd_04_loot(pairs)
	print("LEDGER L-RWD-04 %d seeded fights: supplies equal at rows 1 and 13, ore scales" % pairs.size())
	check(why.is_empty(), "L-RWD-04 loot target: " + why)
	# Wrong value 1: a fixed ore payout left in an event must fail the lint.
	var bad: DataDB = db()
	var pages: Dictionary = (bad.table("events")["kola_tapes"] as Dictionary)["pages"]
	var opt: Dictionary = ((pages["intro"] as Dictionary)["options"] as Array)[1]
	(((opt["outcomes"] as Array)[0] as Dictionary)["effects"] as Array).append({"type": "res", "res": "ore", "amount": 5})
	check(_lint_rejects_fixed_payouts(bad), "L-RWD-04 wrong value (a fixed ore payout) must fail the lint")
	# Wrong value 2: cells scaled by row (the row-13 cells grown by the ore base's ratio) must fail.
	var k: float = Rewards.base(d, "ore", 13) / Rewards.base(d, "ore", 1)
	var scaled: Array = []
	for p: Variant in pairs:
		var q: Array = (p as Array).duplicate()
		q[2] = roundi(float(int(q[2])) * k)
		scaled.append(q)
	check(not _judge_rwd_04_loot(scaled).is_empty(), "L-RWD-04 wrong value (cells scaled by row) must fail the loot check")


## The event reward effect pays by tier at the ship's row, drawing once from the "reward" stream.
func test_reward_effect_pays_by_tier() -> void:
	var d: DataDB = db()
	var s := Sim.new(d, 3, LIGHT, {"mode": "run"})
	var ore0: int = s.run.get_res("ore")
	var rng_state: int = s.rng.get_stream("reward").state
	EventEffects.apply(s, s.encounter, {"type": "reward", "res": "ore", "tier": "high"})
	var got: int = s.run.get_res("ore") - ore0
	var sp: Vector2 = Rewards.spread(d, "high")
	var base: float = Rewards.base(d, "ore", s.run.current_row())
	check(got >= roundi(base * sp.x) and got <= roundi(base * sp.y), "a high ore reward lands in the high spread (%d)" % got)
	var r := RandomNumberGenerator.new()
	r.state = rng_state
	r.randf()
	check_eq(s.rng.get_stream("reward").state, r.state, "exactly one draw from the reward stream")
