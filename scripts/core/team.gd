class_name Team
extends RefCounted

var id: String = ""
var city: String = ""
var name: String = ""
var conference: String = ""
var division: String = ""


static func from_dict(d: Dictionary) -> Team:
	var t := Team.new()
	t.id = d["id"]
	t.city = d["city"]
	t.name = d["name"]
	t.conference = d["conference"]
	t.division = d["division"]
	return t


func to_dict() -> Dictionary:
	return {"id": id, "city": city, "name": name, "conference": conference, "division": division}


func full_name() -> String:
	return "%s %s" % [city, name]
