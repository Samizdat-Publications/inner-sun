class_name CrewMember
extends RefCounted
## One crew member: where they are, how healthy, what they were told to do and what they are doing.

var id: String = ""
var index: int = 0
var name: String = ""
var pos: Vector2 = Vector2.ZERO  ## Feet position, meters, ship space.
var room: int = 0
var start_room: int = 0
const MAX_HP: float = 100.0

var hp: float = MAX_HP
var alive: bool = true
var cause_of_death: String = ""
var auto: bool = true  ## Handle emergencies on their own when not ordered.
var order_room: int = -1  ## Player order: stay in this room and work there (-1 = none).
var skill_fire: float = 1.0
var skill_repair: float = 1.0
var skill_station: float = 1.0  ## How well they run a station they man (Systems.skill_scale).
var job_kind: String = ""  ## "", "extinguish", "patch", "repair", "go" or "sortie" (boarding for the away miner).
var away: bool = false  ## Outside the ship as the away miner (DrillMiner): mans nothing, takes no job or room harm; room stays valid.
var job_room: int = -1
var path: PackedVector2Array = PackedVector2Array()
var path_i: int = 0
var climbing: bool = false
