class_name WeaponDef
extends RefCounted
## One weapon type, read once from game/data/weapons/<id>.json into typed fields so the combat hot
## path never touches a Dictionary. Kinds: "projectile" (flies, stopped by a bracing layer), "beam"
## (instant sweep down the target ship; each room takes damage minus the bracing layers, layers are
## not spent) and "charge" (flies, spends one unit of its ammo resource, ignores bracing).

const KINDS: Array[String] = ["projectile", "beam", "charge"]

var id: String = ""
var name: String = ""
var kind: String = "projectile"
var power: int = 1  ## Weapon-system bars it needs.
var charge_s: float = 10.0  ## Seconds of powered charging per volley (before the manned bonus).
var shots: int = 1  ## Rounds per volley (projectiles and charges).
var damage: int = 1  ## Hull per hit (per room for beams).
var sys_damage: float = 1.0  ## System bars per hit.
var crew_damage: float = 0.0  ## Hit points to everyone in the room.
var fire_chance: float = 0.0
var breach_chance: float = 0.0
var breach_m2: float = 0.0
var heat_j: int = 0  ## Heat put into the room per hit, in whole joules (data: heat_kj).
var speed_m_s: float = 1.0
var beam_len_m: float = 0.0
var ammo: String = ""  ## Run resource spent per volley ("" = none).
var pierces_bracing: bool = false


static func from_def(d: Dictionary) -> WeaponDef:
	var w := WeaponDef.new()
	w.id = str(d.get("id", ""))
	w.name = str(d.get("name", w.id))
	w.kind = str(d.get("kind", "projectile"))
	w.power = maxi(0, int(d.get("power", 1)))
	w.charge_s = maxf(Sim.DT, float(d.get("charge_s", 10.0)))
	w.shots = maxi(1, int(d.get("shots", 1)))
	w.damage = maxi(0, int(d.get("damage", 1)))
	w.sys_damage = maxf(0.0, float(d.get("sys_damage", 0.0)))
	w.crew_damage = maxf(0.0, float(d.get("crew_damage", 0.0)))
	w.fire_chance = clampf(float(d.get("fire_chance", 0.0)), 0.0, 1.0)
	w.breach_chance = clampf(float(d.get("breach_chance", 0.0)), 0.0, 1.0)
	w.breach_m2 = maxf(0.0, float(d.get("breach_m2", 0.0)))
	w.heat_j = maxi(0, roundi(float(d.get("heat_kj", 0.0)) * 1000.0))
	w.speed_m_s = maxf(0.1, float(d.get("speed_m_s", 1.0)))
	w.beam_len_m = maxf(0.0, float(d.get("beam_len_m", 0.0)))
	w.ammo = str(d.get("ammo", ""))
	w.pierces_bracing = bool(d.get("pierces_bracing", false))
	if w.kind == "beam":
		w.shots = 1
	return w


func is_beam() -> bool:
	return kind == "beam"
