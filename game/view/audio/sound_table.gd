class_name SoundTable
extends RefCounted
## Data for the audio director: which file plays for which sim event, and the continuous loops.
## Adding a sound for a new event is one line in EVENTS. Levels are in dB at the player, chosen from the
## measured RMS of each file (pipeline/manifests/audio.json) so loops sit near -24 dBFS RMS before the
## bus gains, and one-shots land near -18 dBFS RMS. Nothing here is rules; the sim never reads it.

const DIR: String = "res://assets/audio/"

## Event key -> {"sound": file stem, "db": volume, "jitter": +/- pitch fraction, "bus": bus name}.
## The key is the event kind, except: "resource" with res "hull" and a negative amount is
## "resource_hull_loss", "phase" is "phase_<to>", "weapon_fired" is "weapon_fired_<weapon>".
## Unknown kinds are silent.
const EVENTS: Dictionary = {
	"pocket_burst": {"sound": "pocket_burst", "db": -2.0, "jitter": 0.05, "bus": "SFX"},
	"bit_change_started": {"sound": "bit_change", "db": 6.0, "jitter": 0.0, "bus": "SFX"},
	"bit_broken": {"sound": "hull_groan", "db": -2.0, "jitter": 0.04, "bus": "SFX"},
	"power_cut": {"sound": "power_click", "db": 2.0, "jitter": 0.08, "bus": "SFX"},
	"system_damaged": {"sound": "hull_hit", "db": -4.0, "jitter": 0.06, "bus": "SFX"},
	"crew_died": {"sound": "crew_hurt", "db": -2.0, "jitter": 0.03, "bus": "SFX"},
	"crew_hurt": {"sound": "crew_hurt", "db": -6.0, "jitter": 0.08, "bus": "SFX"},
	"breach": {"sound": "hull_groan", "db": -4.0, "jitter": 0.06, "bus": "SFX"},
	"resource_hull_loss": {"sound": "hull_hit", "db": -2.0, "jitter": 0.06, "bus": "SFX"},
	"pursuer_strike": {"sound": "hull_hit", "db": 0.0, "jitter": 0.04, "bus": "SFX"},
	"pursuer_caught": {"sound": "hull_groan", "db": 0.0, "jitter": 0.0, "bus": "SFX"},
	"bracing_absorbed": {"sound": "bracing_absorb", "db": -2.0, "jitter": 0.05, "bus": "SFX"},
	"fight_start": {"sound": "radio_squelch", "db": 0.0, "jitter": 0.0, "bus": "Radio"},
	"event_started": {"sound": "radio_squelch", "db": -3.0, "jitter": 0.04, "bus": "Radio"},
	# M1c dig verbs: existing sounds (nothing fits better yet).
	"blast_fired": {"sound": "charge_fire", "db": -3.0, "jitter": 0.05, "bus": "SFX"},
	"blast": {"sound": "charge_explosion", "db": -1.0, "jitter": 0.05, "bus": "SFX"},
	"rockfall_warn": {"sound": "hull_groan", "db": -6.0, "jitter": 0.08, "bus": "SFX"},
	"rockfall": {"sound": "charge_explosion", "db": -5.0, "jitter": 0.1, "bus": "SFX"},
	"doused": {"sound": "pocket_burst", "db": -7.0, "jitter": 0.08, "bus": "SFX"},
	"mined": {"sound": "ui_click", "db": -13.0, "jitter": 0.18, "bus": "SFX"},  # A soft tick per pickup.
	"store_opened": {"sound": "ui_click", "db": 0.0, "jitter": 0.0, "bus": "SFX"},
	"phase_dead": {"sound": "hull_groan", "db": 2.0, "jitter": 0.0, "bus": "SFX"},
	# Combat: names the combat sim is expected to emit. Harmless until it does.
	"weapon_fired_borer": {"sound": "borer_fire", "db": -2.0, "jitter": 0.05, "bus": "SFX"},
	"weapon_fired_charge": {"sound": "charge_fire", "db": -2.0, "jitter": 0.05, "bus": "SFX"},
	"charge_explosion": {"sound": "charge_explosion", "db": -2.0, "jitter": 0.05, "bus": "SFX"},
	"projectile_hit": {"sound": "hull_hit", "db": -2.0, "jitter": 0.08, "bus": "SFX"},
}

## Loop name -> {"sound": file stem, "db": base volume at full intensity, "bus": bus name}.
const LOOPS: Dictionary = {
	"motor": {"sound": "drill_motor_loop", "db": -12.0, "bus": "SFX"},
	"grind_soft": {"sound": "grind_soft_loop", "db": -3.0, "bus": "SFX"},
	"grind_hard": {"sound": "grind_hard_loop", "db": 0.0, "bus": "SFX"},
	"grind_squeal": {"sound": "grind_squeal_loop", "db": -4.0, "bus": "SFX"},
	"fire": {"sound": "fire_crackle_loop", "db": 8.0, "bus": "Ambience"},
	"water": {"sound": "water_rush_loop", "db": -8.0, "bus": "Ambience"},
	"alarm": {"sound": "alarm_klaxon_loop", "db": -10.0, "bus": "SFX"},
	"pursuer": {"sound": "pursuer_rumble_loop", "db": -9.0, "bus": "Ambience"},
	"static": {"sound": "radio_static_loop", "db": -6.0, "bus": "Radio"},
}

## One-shots that are not events (drill start and stop).
const SPIN_UP: Dictionary = {"sound": "drill_spin_up", "db": -4.0, "jitter": 0.0, "bus": "SFX"}
const SPIN_DOWN: Dictionary = {"sound": "drill_spin_down", "db": -4.0, "jitter": 0.0, "bus": "SFX"}

const BUSES: Array[String] = ["SFX", "Ambience", "Radio"]
const BUS_DB: Dictionary = {"Master": 0.0, "SFX": -3.0, "Ambience": -3.0, "Radio": -2.0}


static func key_for(e: Dictionary) -> String:
	var kind: String = str(e.get("kind", ""))
	if kind == "resource":
		if str(e.get("res", "")) == "hull" and int(e.get("amount", 0)) < 0:
			return "resource_hull_loss"
		return ""
	if kind == "phase":
		return "phase_" + str(e.get("to", ""))
	if kind == "weapon_fired":
		return "weapon_fired_" + str(e.get("weapon", ""))
	return kind


static func path_of(stem: String) -> String:
	return DIR + stem + ".ogg"


static func all_stems() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in EVENTS.keys():
		out.append(str((EVENTS[k] as Dictionary)["sound"]))
	for k: String in LOOPS.keys():
		out.append(str((LOOPS[k] as Dictionary)["sound"]))
	out.append(str(SPIN_UP["sound"]))
	out.append(str(SPIN_DOWN["sound"]))
	return out
