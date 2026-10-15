class_name Link
extends RefCounted
## A door (between two rooms on the same deck) or a hatch with a ladder (from a room down into the
## room below). Water, heat, fire and crew all move through links.

enum Kind { DOOR, HATCH }

var id: String = ""
var index: int = 0
var kind: Kind = Kind.DOOR
var a: int = 0  ## Room index. For a hatch, the upper room.
var b: int = 0  ## Room index. For a hatch, the lower room.
var open: bool = true
var x: float = 0.0  ## Door: x of the shared wall. Hatch: center x of the opening.
var height_m: float = 2.0  ## Door opening height above the floor.
var span_m: float = 0.8  ## Hatch opening width along x.
var breadth_m: float = 1.0  ## Opening size into the screen.


func area_m2() -> float:
	return (height_m if kind == Kind.DOOR else span_m) * breadth_m
