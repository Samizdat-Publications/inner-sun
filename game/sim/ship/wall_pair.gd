class_name WallPair
extends RefCounted
## Two rooms that share a wall, floor or ceiling, and how much of it they share.

var a: int = 0
var b: int = 0
var length_m: float = 0.0
var area_m2: float = 0.0
var vertical: bool = true  ## True for a side wall, false for a floor/ceiling (b is the lower room).
