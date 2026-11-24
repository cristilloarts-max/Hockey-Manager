class_name Team
extends RefCounted

var id: String = ""
var city: String = ""
var name: String = ""
var conference: String = ""
var division: String = ""
var primary := Color("#3a4a6b")
var secondary := Color("#c8d0e0")
var depth_chart: Dictionary = {}   ## real current-season lines (Lineup.from_dict format)


static func from_dict(d: Dictionary) -> Team:
	var t := Team.new()
	t.id = d["id"]
	t.city = d["city"]
	t.name = d["name"]
	t.conference = d["conference"]
	t.division = d["division"]
	var colors: Dictionary = d.get("colors", {})
	if colors.has("primary"):
		t.primary = Color.html(colors["primary"])
	if colors.has("secondary"):
		t.secondary = Color.html(colors["secondary"])
	t.depth_chart = d.get("depth_chart", {})
	return t


func to_dict() -> Dictionary:
	return {"id": id, "city": city, "name": name, "conference": conference, "division": division,
		"colors": {"primary": "#" + primary.to_html(false), "secondary": "#" + secondary.to_html(false)},
		"depth_chart": depth_chart}


func full_name() -> String:
	return "%s %s" % [city, name]


## A team color that reads well on the dark UI: the primary unless it's very
## dark, then the secondary (or a lightened primary).
func accent() -> Color:
	if primary.get_luminance() >= 0.18:
		return primary
	if secondary.get_luminance() >= 0.18 and secondary.s > 0.35:
		return secondary
	if primary.s < 0.25:
		return secondary   # black/grey primaries: use the (light) secondary
	return primary.lightened(0.45)


## Text color to draw on top of the primary color.
func on_primary() -> Color:
	return Color(0.08, 0.08, 0.1) if primary.get_luminance() > 0.6 else Color.WHITE
