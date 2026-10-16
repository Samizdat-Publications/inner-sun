class_name RequisitionsLint
extends RefCounted
## Checks data/requisitions: ids, costs, orders, the effects (resource names, gear ids, crew pools).
## Em dashes in the text are rejected by the data loader for every table.


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var table: Dictionary = db.table("requisitions")
	var orders: Dictionary = {}
	for id: String in table.keys():
		var d: Dictionary = table[id]
		var file: String = db.source_of("requisitions", id)
		if str(d.get("name", "")).is_empty() or str(d.get("blurb", "")).is_empty():
			errs.append("%s: a requisition needs a name and a blurb" % file)
		if not _whole(d.get("cost")) or int(d["cost"]) < 1:
			errs.append("%s: cost must be a whole number of 1 or more" % file)
		if not _whole(d.get("order")):
			errs.append("%s: order must be a whole number" % file)
		elif orders.has(int(d["order"])):
			errs.append("%s: order %d is also used by %s" % [file, int(d["order"]), str(orders[int(d["order"])])])
		else:
			orders[int(d["order"])] = id
		var eff: Variant = d.get("effects", null)
		if not (eff is Dictionary) or (eff as Dictionary).is_empty():
			errs.append("%s: effects must be a non-empty object" % file)
			continue
		_lint_effects(db, eff, file, errs)


static func _lint_effects(db: DataDB, eff: Dictionary, file: String, errs: PackedStringArray) -> void:
	for k: Variant in eff.keys():
		var key: String = str(k)
		var v: Variant = eff[k]
		match key:
			"start_resources":
				if not (v is Dictionary) or (v as Dictionary).is_empty():
					errs.append("%s: start_resources must be a non-empty object" % file)
					continue
				var sr: Dictionary = v
				for res: Variant in sr.keys():
					var r: String = str(res)
					if not RunState.RESOURCES.has(r) or r == "hull":
						errs.append("%s: start_resources: \"%s\" is not a resource (use max_hull for the hull)" % [file, r])
					elif not _whole(sr[res]) or int(sr[res]) < 1:
						errs.append("%s: start_resources.%s must be a whole number of 1 or more" % [file, r])
			"max_hull":
				if not _whole(v) or int(v) < 1:
					errs.append("%s: max_hull must be a whole number of 1 or more" % file)
			"gear":
				if not (v is Array) or (v as Array).is_empty():
					errs.append("%s: gear must be a non-empty list of gear ids" % file)
					continue
				for g: Variant in (v as Array):
					if not db.table("gear").has(str(g)):
						errs.append("%s: gear \"%s\" does not exist in data/gear" % [file, str(g)])
			"crew":
				if not _whole(v) or int(v) < 1:
					errs.append("%s: crew must be a whole number of 1 or more" % file)
				elif not db.table("crew").has(Requisitions.CREW_POOL):
					errs.append("%s: crew needs the \"%s\" pool in data/crew" % [file, Requisitions.CREW_POOL])
			_:
				errs.append("%s: unknown effect \"%s\" (known: %s)" % [file, key, ", ".join(Requisitions.EFFECTS)])


static func _whole(v: Variant) -> bool:
	return (v is float or v is int) and float(v) == floorf(float(v))
