class_name BirdMods
extends RefCounted

const MAX_LEVEL = 3
const MAX_TOTAL = 18

const DEFS = [
	{"id": "bounce", "name": "BOUNCE BACK", "short": "BOUNCE", "desc": "ONE FREE BOUNCE OFF ANY HIT"},
	{"id": "bones", "name": "LIGHT BONES", "short": "BONES", "desc": "GRAVITY 6% LOWER"},
	{"id": "wings", "name": "POWER WINGS", "short": "WINGS", "desc": "FLAP 5% STRONGER"},
	{"id": "frame", "name": "TINY FRAME", "short": "FRAME", "desc": "HITBOX 8% SMALLER"},
	{"id": "gates", "name": "WIDE GATES", "short": "GATES", "desc": "PIPE GAPS 6% WIDER"},
	{"id": "tailwind", "name": "TAILWIND", "short": "TAIL", "desc": "PIPES 5% SLOWER"},
]

var levels = {}
var rotation = 0


func get_level(id):
	return int(levels.get(id, 0))


func total_levels():
	var total = 0
	for def in DEFS:
		total = total + get_level(def["id"])
	return total


func is_maxed():
	if total_levels() >= MAX_TOTAL:
		return true
	return false


func bounces():
	return get_level("bounce")


func gravity_scale():
	return 1 - 0.06 * get_level("bones")


func flap_scale():
	return 1 + 0.05 * get_level("wings")


func hitbox_scale():
	return 1 - 0.08 * get_level("frame")


func gap_scale():
	return 1 + 0.06 * get_level("gates")


func speed_scale():
	return 1 - 0.05 * get_level("tailwind")


func summary():
	var parts = []
	for def in DEFS:
		var level = get_level(def["id"])
		if level > 0:
			parts.append("%s %d" % [def["short"], level])
	if parts.is_empty():
		return "NO MODS YET · DIE TO GROW"
	if parts.size() > 3:
		return "%d MODS · POWER %d/%d" % [parts.size(), total_levels(), MAX_TOTAL]
	return " · ".join(parts)


func grant():
	var pick = -1
	var pick_level = MAX_LEVEL + 1
	for i in range(DEFS.size()):
		var index = (i + rotation) % DEFS.size()
		var level = get_level(DEFS[index]["id"])
		if level < pick_level and level < MAX_LEVEL:
			pick = index
			pick_level = level
	if pick < 0:
		return {}

	rotation = (pick + 1) % DEFS.size()
	var def = DEFS[pick]
	levels[def["id"]] = pick_level + 1
	return {
		"id": def["id"],
		"name": def["name"],
		"short": def["short"],
		"desc": def["desc"],
		"level": pick_level + 1,
	}


func reset():
	levels.clear()
	rotation = 0


func to_dict():
	var saved = {}
	for def in DEFS:
		saved[def["id"]] = get_level(def["id"])
	return {"levels": saved, "rotation": rotation}


func from_dict(data):
	levels.clear()
	rotation = 0
	if typeof(data) != TYPE_DICTIONARY:
		return

	var saved = data.get("levels", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for def in DEFS:
			var id = def["id"]
			levels[id] = clamp(int(saved.get(id, 0)), 0, MAX_LEVEL)

	rotation = int(data.get("rotation", 0)) % DEFS.size()
