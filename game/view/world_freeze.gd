class_name WorldFreeze
extends RefCounted
## The visible pause (view only, never the sim). A frozen world view node runs its update with a zero
## frame time, so every animation clock stands still, and its CPUParticles2D get speed_scale 0. The
## particles' own speed scale is kept in node meta and restored when the world thaws. Nodes call
## apply(self, true) again after their own per-frame writes (some set speed_scale every frame).

const META: StringName = &"prefreeze_speed_scale"


## Freeze (on) or thaw (off) every CPUParticles2D at or below `root`. Idempotent.
static func apply(root: Node, on: bool) -> void:
	var p: CPUParticles2D = root as CPUParticles2D
	if p != null:
		if on:
			if not p.has_meta(META):
				p.set_meta(META, p.speed_scale)
			p.speed_scale = 0.0
		elif p.has_meta(META):
			p.speed_scale = float(p.get_meta(META))
			p.remove_meta(META)
	for c: Node in root.get_children():
		apply(c, on)


## What a frozen node does at the top of its _process: no time passes.
static func dt(frozen: bool, delta: float) -> float:
	return 0.0 if frozen else delta
