extends RefCounted
class_name ChapterDB
## Static description of the eight chapters: identity, pacing targets, palette,
## collectible names and bonus-challenge wording. The chapter builder scripts
## consume this so UI, saves and results screens never hardcode strings.

const CHAPTERS := [
	{
		"id": "ch01", "index": 0, "number": 1,
		"title": "Glass-Rain Valley",
		"subtitle": "Where the sky came down in sheets",
		"builder": "res://chapters/Chapter01.gd",
		"objective": "Recover the Veilforge Device and reach the valley relay.",
		"target_time": 780.0, "par_scans": 12, "puzzles": 6,
		"fragments": ["Rainfall Log 04", "Surveyor's Bootprint", "Unsent Letter"],
		"component": "Field Coil Alpha",
		"challenge": "Cross the valley without letting a single glass shard strike you.",
		"challenge_id": "no_shard_hits",
		"weather": "glass_rain", "biome": "valley",
		"sky_memory": Color(0.62, 0.76, 0.92), "sky_ruin": Color(0.42, 0.44, 0.50),
		"sky_bloom": Color(0.55, 0.78, 0.66),
	},
	{
		"id": "ch02", "index": 1, "number": 2,
		"title": "The Walking Forest",
		"subtitle": "The mill still moves; the trees learned to move with it",
		"builder": "res://chapters/Chapter02.gd",
		"objective": "Restart the timber mill's spine and climb to the canopy relay.",
		"target_time": 900.0, "par_scans": 9, "puzzles": 7,
		"fragments": ["Sawyer's Tally", "Root-Bound Ring", "Canopy Survey Pin"],
		"component": "Grip Servo",
		"challenge": "Reach the canopy without touching the forest floor after the second lift.",
		"challenge_id": "canopy_only",
		"weather": "drifting_pollen", "biome": "forest",
		"sky_memory": Color(0.74, 0.80, 0.66), "sky_ruin": Color(0.38, 0.40, 0.36),
		"sky_bloom": Color(0.50, 0.86, 0.52),
	},
	{
		"id": "ch03", "index": 2, "number": 3,
		"title": "Nacre City",
		"subtitle": "Nine floors of it are underwater and four of them still have power",
		"builder": "res://chapters/Chapter03.gd",
		"objective": "Route power and water to raise the Pearl Lift and reach the spire.",
		"target_time": 1020.0, "par_scans": 8, "puzzles": 7,
		"fragments": ["Tram Token", "Balcony Photograph", "Harbourmaster's Key"],
		"component": "Capacitor Lattice",
		"challenge": "Raise the Pearl Lift using only three veil shifts.",
		"challenge_id": "lift_three_shifts",
		"weather": "sea_mist", "biome": "city",
		"sky_memory": Color(0.80, 0.84, 0.90), "sky_ruin": Color(0.34, 0.38, 0.44),
		"sky_bloom": Color(0.48, 0.80, 0.78),
	},
	{
		"id": "ch04", "index": 3, "number": 4,
		"title": "White Signal Observatory",
		"subtitle": "It kept listening long after anyone was left to hear",
		"builder": "res://chapters/Chapter04.gd",
		"objective": "Realign the dish array and decode the White Signal.",
		"target_time": 960.0, "par_scans": 7, "puzzles": 6,
		"fragments": ["Frost-Split Lens", "Night Watch Rota", "Antenna Blueprint"],
		"component": "Thermal Regulator",
		"challenge": "Realign all three dishes before the storm front completes a full pass.",
		"challenge_id": "dish_before_storm",
		"weather": "blizzard", "biome": "mountain",
		"sky_memory": Color(0.86, 0.90, 0.96), "sky_ruin": Color(0.52, 0.56, 0.62),
		"sky_bloom": Color(0.70, 0.88, 0.80),
	},
	{
		"id": "ch05", "index": 4, "number": 5,
		"title": "The Buried Sun",
		"subtitle": "They dug down until they found something that was already warm",
		"builder": "res://chapters/Chapter05.gd",
		"objective": "Descend the sink-shaft and stabilise the buried reactor's first ring.",
		"target_time": 1080.0, "par_scans": 8, "puzzles": 5,
		"fragments": ["Drill Foreman's Badge", "Sand-Scoured Idol", "Coolant Manifest"],
		"component": "Discharge Prism",
		"challenge": "Stabilise the ring without ever letting core heat pass 70%.",
		"challenge_id": "cool_head",
		"weather": "sandstorm", "biome": "desert",
		"sky_memory": Color(0.94, 0.82, 0.60), "sky_ruin": Color(0.62, 0.46, 0.32),
		"sky_bloom": Color(0.78, 0.86, 0.50),
	},
	{
		"id": "ch06", "index": 5, "number": 6,
		"title": "Tempest Archipelago",
		"subtitle": "Every island is three islands, and only one of them is above water",
		"builder": "res://chapters/Chapter06.gd",
		"objective": "Chain four islands into a single crossing and reach the storm eye.",
		"target_time": 1140.0, "par_scans": 8, "puzzles": 6,
		"fragments": ["Lighthouse Ledger", "Salt-Glass Bead", "Migration Chart"],
		"component": "Stabiliser Gyro",
		"challenge": "Reach the storm eye without being struck by lightning once.",
		"challenge_id": "unstruck",
		"weather": "thunderstorm", "biome": "islands",
		"sky_memory": Color(0.70, 0.82, 0.94), "sky_ruin": Color(0.30, 0.34, 0.42),
		"sky_bloom": Color(0.46, 0.82, 0.72),
	},
	{
		"id": "ch07", "index": 6, "number": 7,
		"title": "Archive Zero",
		"subtitle": "The room where somebody decided this was worth trying",
		"builder": "res://chapters/Chapter07.gd",
		"objective": "Reconstruct the Fracture record and open the Convergence gate.",
		"target_time": 1200.0, "par_scans": 8, "puzzles": 6,
		"fragments": ["Founder's Annotation", "Rejected Proposal", "Last Shift Roster"],
		"component": "Phase Governor",
		"challenge": "Reconstruct the record without a single failed imprint.",
		"challenge_id": "clean_record",
		"weather": "still_air", "biome": "archive",
		"sky_memory": Color(0.88, 0.90, 0.94), "sky_ruin": Color(0.26, 0.28, 0.34),
		"sky_bloom": Color(0.52, 0.78, 0.66),
	},
	{
		"id": "ch08", "index": 7, "number": 8,
		"title": "Convergence Core",
		"subtitle": "Three worlds, one room, ninety seconds of overlap",
		"builder": "res://chapters/Chapter08.gd",
		"objective": "Repair the climate engine before the three realities collapse into one.",
		"target_time": 1260.0, "par_scans": 7, "puzzles": 6,
		"fragments": ["Engine Commissioning Plate", "MOTE Prototype Casing", "Your Own Field Note"],
		"component": "Threefold Core",
		"challenge": "Complete the final sequence without dropping below 25% shield.",
		"challenge_id": "unbroken",
		"weather": "convergence", "biome": "core",
		"sky_memory": Color(0.90, 0.86, 0.78), "sky_ruin": Color(0.38, 0.30, 0.30),
		"sky_bloom": Color(0.58, 0.92, 0.62),
	},
]

const COUNT := 8

static func get_chapter(idx: int) -> Dictionary:
	return CHAPTERS[clampi(idx, 0, COUNT - 1)]

static func index_of(id: String) -> int:
	for c in CHAPTERS:
		if c.id == id:
			return c.index
	return -1

static func title(idx: int) -> String:
	return get_chapter(idx).title

static func total_fragments() -> int:
	return COUNT * 3
