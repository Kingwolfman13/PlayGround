extends Node
class_name WorldData

# A condensed, fictionalized Petersburg-inspired city. The core is a detailed
# Old Towne / Appomattox riverfront block; outer districts suggest the wider city.
const WORLD_HALF := 150.0
const RIVER_EDGE := -58.0
const MAIN_HALF_WIDTH := 7.0
const MARKET_HALF_WIDTH := 6.0
const MARKET_Z := 8.0

const SPAWN_POINT := Vector3(0.0, 1.0, 34.0)
const SPAWN_YAW := 0.0
const KIOSK_POS := Vector3(-8.6, 0.0, 29.0)

const MISSIONS := [
	{
		"title": "First Run",
		"client": "Mara",
		"pickup": Vector3(-24.0, 0.2, -24.0),
		"drop": Vector3(0.0, 0.2, -49.0),
		"time": 150.0,
		"reward": 240,
		"pickup_hint": "Warehouse courtyard off Main Street",
		"drop_hint": "Appomattox Riverwalk",
		"brief": "A sealed parcel needs to reach the riverwalk before the afternoon rush."
	},
	{
		"title": "Bellweather Run",
		"client": "Nia",
		"pickup": Vector3(-22.0, 0.2, 24.0),
		"drop": Vector3(28.0, 0.2, 0.0),
		"time": 160.0,
		"reward": 300,
		"pickup_hint": "Bellweather Apothecary, Market Street",
		"drop_hint": "North Bank Cafe, east Market",
		"brief": "Medicine for the cafe crew. Keep the bottles upright and the clock honest."
	},
	{
		"title": "Foundry Parts",
		"client": "Owen",
		"pickup": Vector3(24.0, 0.2, -26.0),
		"drop": Vector3(-28.0, 0.2, 0.0),
		"time": 145.0,
		"reward": 360,
		"pickup_hint": "Old Foundry loading yard",
		"drop_hint": "Market Street repair shop",
		"brief": "A crate of brass fittings is waiting at the foundry. The repair shop closes early."
	},
	{
		"title": "Last Light",
		"client": "June",
		"pickup": Vector3(26.0, 0.2, 32.0),
		"drop": Vector3(-38.0, 0.2, -49.0),
		"time": 185.0,
		"reward": 520,
		"pickup_hint": "Southside Studio, Market Street",
		"drop_hint": "West riverwalk dock",
		"brief": "June's last canvas is headed for the river dock. Do not let the light beat you."
	}
]

const PARKED_CARS := [
	{"name": "River City Pickup", "pos": Vector3(4.6, 0.9, 27.0), "yaw": 0.0, "color": Color("#3f7f93")},
	{"name": "Market Coupe", "pos": Vector3(-4.6, 0.9, 20.0), "yaw": PI, "color": Color("#c67a43")},
	{"name": "Foundry Wagon", "pos": Vector3(4.6, 0.9, -12.0), "yaw": 0.0, "color": Color("#64765e")},
	{"name": "Blandford Sedan", "pos": Vector3(-4.6, 0.9, -34.0), "yaw": PI, "color": Color("#8c6f9e")},
	{"name": "Riverwalk Taxi", "pos": Vector3(4.6, 0.9, -44.0), "yaw": 0.0, "color": Color("#d4a73c")}
]

const PEDESTRIANS := [
	{"name": "Mara", "pos": Vector3(-8.8, 0.0, 31.0), "shirt": Color("#2f7d88"), "pants": Color("#2a3038"), "skin": Color("#8d5d43"), "hat": Color("#d9b15d")},
	{"name": "Nia", "pos": Vector3(-8.8, 0.0, 22.0), "shirt": Color("#b4534d"), "pants": Color("#3b4b57"), "skin": Color("#6f4632"), "hat": Color("#e8d6b8")},
	{"name": "Owen", "pos": Vector3(8.8, 0.0, -8.0), "shirt": Color("#5e7258"), "pants": Color("#343b40"), "skin": Color("#c08a68"), "hat": Color("#3e4b51")},
	{"name": "June", "pos": Vector3(8.8, 0.0, -30.0), "shirt": Color("#d7a34d"), "pants": Color("#4a3f4d"), "skin": Color("#a16d4f"), "hat": Color("#8e4b3f")},
	{"name": "Riverside Walker", "pos": Vector3(-8.8, 0.0, -44.0), "shirt": Color("#557c9a"), "pants": Color("#2f3539"), "skin": Color("#d0a17e"), "hat": Color("#e6ddca")},
	{"name": "Market Shopper", "pos": Vector3(8.8, 0.0, 40.0), "shirt": Color("#9d5f86"), "pants": Color("#313841"), "skin": Color("#7a4b35"), "hat": Color("#c6b28d")},
	{"name": "Corner Regular", "pos": Vector3(-8.8, 0.0, 6.0), "shirt": Color("#6d7b4d"), "pants": Color("#3b3b42"), "skin": Color("#b98561"), "hat": Color("#4b5960")},
	{"name": "Dock Worker", "pos": Vector3(24.0, 0.0, -48.0), "shirt": Color("#c4793f"), "pants": Color("#2c3540"), "skin": Color("#6d4532"), "hat": Color("#e2c26f")},
	{"name": "Student", "pos": Vector3(-32.0, 0.0, 8.0), "shirt": Color("#3f6d9c"), "pants": Color("#44404a"), "skin": Color("#d5a482"), "hat": Color("#e8e1d2")}
]

const TRAFFIC := [
	{
		"name": "Main Street Loop",
		"path": [Vector3(3.6, 0.0, 54.0), Vector3(3.6, 0.0, -42.0), Vector3(-3.6, 0.0, -42.0), Vector3(-3.6, 0.0, 54.0)],
		"color": Color("#7f8d96"), "speed": 6.2
	},
	{
		"name": "Market Street Loop",
		"path": [Vector3(-62.0, 0.0, 11.0), Vector3(62.0, 0.0, 11.0), Vector3(62.0, 0.0, 5.0), Vector3(-62.0, 0.0, 5.0)],
		"color": Color("#a26d5f"), "speed": 5.6
	},
	{
		"name": "South Main Loop",
		"path": [Vector3(-3.6, 0.0, -42.0), Vector3(-3.6, 0.0, 54.0), Vector3(3.6, 0.0, 54.0), Vector3(3.6, 0.0, -42.0)],
		"color": Color("#5f7f71"), "speed": 5.9
	}
]

const POLICE_SPAWNS := [
	Vector3(0.0, 0.9, -20.0), Vector3(0.0, 0.9, 44.0), Vector3(-42.0, 0.9, 8.0),
	Vector3(42.0, 0.9, 8.0), Vector3(0.0, 0.9, 8.0), Vector3(-24.0, 0.9, 8.0),
	Vector3(24.0, 0.9, 8.0), Vector3(0.0, 0.9, 70.0)
]

# Footprints kept clear so mission pickups and alleys are always reachable.
const RESERVED_RECTS := [
	Rect2(-34.0, -34.0, 20.0, 20.0),   # warehouse courtyard
	Rect2(-34.0, 20.0, 14.0, 10.0),    # apothecary plaza
	Rect2(18.0, -32.0, 14.0, 12.0),    # foundry yard
	Rect2(20.0, 27.0, 14.0, 11.0),     # studio plaza
	Rect2(-26.0, -27.0, 16.0, 8.0),    # west alley to warehouse
	Rect2(-26.0, 22.0, 16.0, 6.0),     # west alley to apothecary
	Rect2(10.0, -27.0, 16.0, 6.0),     # east alley to foundry
	Rect2(10.0, 29.0, 16.0, 6.0),      # east alley to studio
	Rect2(-14.0, 25.0, 8.0, 12.0),     # Mara kiosk / spawn plaza
	Rect2(-8.0, 24.0, 16.0, 16.0)      # spawn clear zone
]

const DISTRICTS := [
	{"name": "OLD TOWNE", "pos": Vector3(0.0, 0.0, 8.0)},
	{"name": "RIVERWALK", "pos": Vector3(0.0, 0.0, -50.0)},
	{"name": "WALNUT HILL", "pos": Vector3(-105.0, 0.0, 62.0)},
	{"name": "BLANDFORD", "pos": Vector3(108.0, 0.0, -22.0)},
	{"name": "HALIFAX", "pos": Vector3(-104.0, 0.0, -18.0)},
	{"name": "SOUTHSIDE", "pos": Vector3(100.0, 0.0, 90.0)}
]

static func district_at(pos: Vector3) -> String:
	if pos.z < -44.0:
		return "RIVERWALK"
	if pos.x < -70.0 and pos.z < 30.0:
		return "HALIFAX"
	if pos.x < -70.0:
		return "WALNUT HILL"
	if pos.x > 70.0 and pos.z < 30.0:
		return "BLANDFORD"
	if pos.x > 70.0:
		return "SOUTHSIDE"
	return "OLD TOWNE"

static func mission_count() -> int:
	return MISSIONS.size()
