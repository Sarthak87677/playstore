extends Node
## Progression brain: XP, levels, upgrade tree, collectibles, chapter records,
## unlockables, New Game+ and the per-run scoreboard used by the results screen.
## All state lives in one dictionary that SaveSystem serialises verbatim.

signal xp_awarded(amount: int, reason: String, total: int)
signal level_up(new_level: int, points: int)
signal upgrade_bought(id: String, rank: int)
signal component_gained(total: int)
signal fragment_found(chapter: int, index: int)
signal unlock_earned(kind: String, id: String, label: String)
signal chain_changed(links: int, mult: float)
signal profile_loaded

# ---------------------------------------------------------------- upgrade tree
const UPGRADES := {
	# Resonance -------------------------------------------------------------
	"field_radius": {"branch": 0, "tier": 0, "max": 3, "cost": 1,
		"name": "Field Bloom", "desc": "Veil field radius +2.0 m per rank."},
	"field_range": {"branch": 0, "tier": 0, "max": 3, "cost": 1,
		"name": "Long Throw", "desc": "Field can be projected +5.0 m further per rank."},
	"shift_cost": {"branch": 0, "tier": 1, "max": 3, "cost": 1,
		"name": "Clean Phase", "desc": "Each reality shift costs 2.6 less energy per rank."},
	"pin_duration": {"branch": 0, "tier": 1, "max": 3, "cost": 1,
		"name": "Anchor Weave", "desc": "Pinned fields last +6 s per rank."},
	"record_slots": {"branch": 0, "tier": 2, "max": 2, "cost": 2,
		"name": "Deep Register", "desc": "Carry one more recorded property per rank."},
	# Mobility --------------------------------------------------------------
	"climb_stamina": {"branch": 1, "tier": 0, "max": 3, "cost": 1,
		"name": "Iron Grip", "desc": "Climbing stamina +45% per rank."},
	"air_control": {"branch": 1, "tier": 0, "max": 3, "cost": 1,
		"name": "Glide Trim", "desc": "Mid-air steering authority +30% per rank."},
	"sprint_speed": {"branch": 1, "tier": 1, "max": 3, "cost": 1,
		"name": "Long Stride", "desc": "Sprint speed +6% per rank."},
	"fall_recovery": {"branch": 1, "tier": 1, "max": 2, "cost": 2,
		"name": "Soft Landing", "desc": "Fall damage -40% and a wider roll window per rank."},
	"veil_jump": {"branch": 1, "tier": 2, "max": 1, "cost": 3,
		"name": "Phase Step", "desc": "Spend energy for a single mid-air second jump."},
	# Engineering -----------------------------------------------------------
	"emp_radius": {"branch": 2, "tier": 0, "max": 3, "cost": 1,
		"name": "Wide Discharge", "desc": "EMP radius +1.6 m per rank."},
	"emp_stun": {"branch": 2, "tier": 0, "max": 3, "cost": 1,
		"name": "Deep Discharge", "desc": "EMP stun lasts +1.4 s per rank."},
	"scan_speed": {"branch": 2, "tier": 1, "max": 3, "cost": 1,
		"name": "Fast Optics", "desc": "Scans complete 0.22 s sooner per rank."},
	"energy_regen": {"branch": 2, "tier": 1, "max": 3, "cost": 1,
		"name": "Cell Bloom", "desc": "Energy regeneration +4/s per rank."},
	"shield_capacity": {"branch": 2, "tier": 2, "max": 2, "cost": 2,
		"name": "Hard Shell", "desc": "Shield capacity +25 per rank."},
}
const TIER_COMPONENTS := [0, 2, 5]     # components needed to unlock each tier

const SUITS := {
	"field": {"name": "Field Standard", "desc": "Issued kit. Grey weave, orange trim.",
		"how": "Available from the start.", "primary": Color(0.42, 0.45, 0.50),
		"accent": Color(0.95, 0.55, 0.20)},
	"survey": {"name": "Survey Blue", "desc": "Deep-water rated shell from the harbour office.",
		"how": "Complete Nacre City.", "primary": Color(0.20, 0.34, 0.52),
		"accent": Color(0.55, 0.86, 0.95)},
	"deep": {"name": "Deep Crew", "desc": "Heat-shedding plate from the sink-shaft teams.",
		"how": "Complete The Buried Sun.", "primary": Color(0.36, 0.26, 0.16),
		"accent": Color(1.00, 0.72, 0.24)},
	"archivist": {"name": "Archivist", "desc": "Clean-room whites, no insignia.",
		"how": "Complete Archive Zero.", "primary": Color(0.82, 0.83, 0.85),
		"accent": Color(0.35, 0.55, 0.75)},
	"threefold": {"name": "Threefold", "desc": "It shifts colour with the veil field.",
		"how": "Finish the game.", "primary": Color(0.30, 0.32, 0.36),
		"accent": Color(0.60, 0.90, 0.80)},
	"prototype": {"name": "Prototype Weave", "desc": "The suit the first engineer never wore.",
		"how": "Collect all 24 Memory Fragments.", "primary": Color(0.14, 0.15, 0.18),
		"accent": Color(0.90, 0.35, 0.75)},
}

const MOTE_SKINS := {
	"standard": {"name": "MOTE", "how": "Available from the start.",
		"shell": Color(0.72, 0.74, 0.78), "light": Color(0.55, 0.85, 1.0)},
	"brass": {"name": "Brass Casing", "how": "Find 10 Memory Fragments.",
		"shell": Color(0.72, 0.56, 0.26), "light": Color(1.0, 0.82, 0.45)},
	"coral": {"name": "Coral Growth", "how": "Clear 4 bonus challenges.",
		"shell": Color(0.86, 0.44, 0.42), "light": Color(1.0, 0.62, 0.55)},
	"glassmote": {"name": "Glass Shell", "how": "Earn an S rank in 4 chapters.",
		"shell": Color(0.80, 0.88, 0.92), "light": Color(0.75, 0.95, 1.0)},
	"origin": {"name": "Origin Unit", "how": "Begin New Game+.",
		"shell": Color(0.22, 0.24, 0.28), "light": Color(0.95, 0.45, 0.85)},
}

# ---------------------------------------------------------------- state
var slot: int = -1
var data: Dictionary = {}
var run: Dictionary = {}
var chain_links: int = 0
var chain_timer: float = 0.0
var session_start_msec: int = 0
var _last_level: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = SaveSystem.new_profile(Settings.difficulty)
	reset_run(0)

func _process(dt: float) -> void:
	if chain_timer > 0.0:
		chain_timer = maxf(0.0, chain_timer - dt)
		if chain_timer <= 0.0 and chain_links > 0:
			chain_links = 0
			chain_changed.emit(0, 1.0)
	if slot >= 0 and not run.get("paused", false) and run.get("active", false):
		data.playtime = float(data.get("playtime", 0.0)) + dt
		run.time = float(run.get("time", 0.0)) + dt

# ================================================================ profile
func start_new_game(p_slot: int, difficulty: int) -> void:
	slot = clampi(p_slot, 0, SaveSystem.SLOTS - 1)
	data = SaveSystem.new_profile(difficulty)
	Settings.difficulty = difficulty
	Settings.save_settings()
	_last_level = 1
	reset_run(0)
	SaveSystem.write(slot, data)
	profile_loaded.emit()
	Log.info("New game: slot %d, difficulty %d" % [slot, difficulty])

func load_slot(p_slot: int) -> bool:
	var d := SaveSystem.read(p_slot)
	if d.is_empty():
		Log.warn("Slot %d empty or unreadable" % p_slot)
		return false
	slot = clampi(p_slot, 0, SaveSystem.SLOTS - 1)
	data = d
	Settings.difficulty = int(data.get("difficulty", 1))
	_last_level = level()
	profile_loaded.emit()
	Log.info("Loaded slot %d (level %d, %.0f s played)" % [slot, level(), data.playtime])
	return true

func save(force: bool = false) -> bool:
	if slot < 0:
		return false
	return SaveSystem.write(slot, data)

func has_profile() -> bool:
	return slot >= 0 and not data.is_empty()

# ================================================================ xp / level
func xp() -> int:
	return int(data.get("xp", 0))

func level() -> int:
	return Veil.level_for_xp(xp())

func xp_into_level() -> int:
	return xp() - Veil.xp_for_level(level())

func xp_needed_for_next() -> int:
	if level() >= Veil.MAX_LEVEL:
		return 0
	return Veil.xp_for_level(level() + 1) - Veil.xp_for_level(level())

func level_progress() -> float:
	var need := xp_needed_for_next()
	if need <= 0:
		return 1.0
	return clampf(float(xp_into_level()) / float(need), 0.0, 1.0)

func points_total() -> int:
	return maxi(0, level() - 1)

func points_spent() -> int:
	var t := 0
	for id in data.get("upgrades", {}).keys():
		if UPGRADES.has(id):
			t += int(UPGRADES[id].cost) * int(data.upgrades[id])
	return t

func points_free() -> int:
	return points_total() - points_spent()

## Award XP. `chain` extends the exploration multiplier used for discoveries.
func award(amount: int, reason: String, chain: bool = false) -> int:
	if amount <= 0:
		return 0
	var mult := 1.0
	if chain:
		chain_links = mini(chain_links + 1, 12)
		chain_timer = Tuning.CHAIN_WINDOW
		mult = chain_multiplier()
		chain_changed.emit(chain_links, mult)
	var gained := int(round(float(amount) * mult))
	data.xp = xp() + gained
	run.xp = int(run.get("xp", 0)) + gained
	xp_awarded.emit(gained, reason, xp())
	var lv := level()
	if lv > _last_level:
		for l in range(_last_level + 1, lv + 1):
			level_up.emit(l, points_free())
		_last_level = lv
		_check_unlocks()
	return gained

func chain_multiplier() -> float:
	return clampf(1.0 + float(chain_links) * Tuning.XP_CHAIN_STEP, 1.0, Tuning.XP_CHAIN_MAX)

func break_chain() -> void:
	if chain_links > 0:
		chain_links = 0
		chain_timer = 0.0
		chain_changed.emit(0, 1.0)

# ================================================================ upgrades
func rank(id: String) -> int:
	return int(data.get("upgrades", {}).get(id, 0))

func tier_unlocked(tier: int) -> bool:
	return components() >= TIER_COMPONENTS[clampi(tier, 0, 2)]

func can_buy(id: String) -> bool:
	if not UPGRADES.has(id):
		return false
	var u: Dictionary = UPGRADES[id]
	if rank(id) >= int(u.max):
		return false
	if not tier_unlocked(int(u.tier)):
		return false
	return points_free() >= int(u.cost)

func buy(id: String) -> bool:
	if not can_buy(id):
		AudioDirector.play_ui("ui_deny")
		return false
	if not (data.upgrades is Dictionary):
		data.upgrades = {}
	data.upgrades[id] = rank(id) + 1
	AudioDirector.play_ui("ui_confirm")
	upgrade_bought.emit(id, rank(id))
	save()
	return true

func respec() -> void:
	data.upgrades = {}
	save()

func components() -> int:
	return int(data.get("components", 0))

func add_component(chapter_idx: int) -> void:
	var rec := chapter_record(chapter_idx)
	if bool(rec.get("component", false)):
		return
	rec.component = true
	data.components = components() + 1
	run.component = true
	component_gained.emit(components())
	award(Tuning.XP_HIDDEN_AREA, "Upgrade component")
	_check_unlocks()

# ---------------------------------------------------------------- derived stats
func field_radius() -> float:
	return Tuning.FIELD_RADIUS_BASE + Tuning.FIELD_RADIUS_PER_UP * rank("field_radius")

func field_range() -> float:
	return Tuning.FIELD_RANGE_BASE + Tuning.FIELD_RANGE_PER_UP * rank("field_range")

func shift_cost() -> float:
	var c := Tuning.SHIFT_COST - Tuning.SHIFT_COST_REDUCTION_PER_UP * rank("shift_cost")
	return maxf(3.0, c) * Tuning.energy_scale(difficulty())

func pin_duration() -> float:
	return Tuning.PIN_DURATION_BASE + Tuning.PIN_DURATION_PER_UP * rank("pin_duration")

func record_slots() -> int:
	return Tuning.RECORD_SLOTS + rank("record_slots")

func climb_stamina() -> float:
	return Tuning.CLIMB_STAMINA * (1.0 + 0.45 * rank("climb_stamina"))

func air_control() -> float:
	return Tuning.AIR_CONTROL * (1.0 + 0.30 * rank("air_control"))

func sprint_speed() -> float:
	return Tuning.SPRINT_SPEED * (1.0 + 0.06 * rank("sprint_speed"))

func fall_damage_scale() -> float:
	return pow(0.6, rank("fall_recovery"))

func roll_window() -> float:
	return Tuning.ROLL_WINDOW * (1.0 + 0.35 * rank("fall_recovery"))

func has_veil_jump() -> bool:
	return rank("veil_jump") > 0

func emp_radius() -> float:
	return Tuning.EMP_RADIUS_BASE + Tuning.EMP_RADIUS_PER_UP * rank("emp_radius")

func emp_stun() -> float:
	return Tuning.EMP_STUN_BASE + Tuning.EMP_STUN_PER_UP * rank("emp_stun")

func scan_time() -> float:
	return maxf(0.35, Tuning.SCAN_TIME + Tuning.SCAN_TIME_PER_UP * rank("scan_speed"))

func energy_regen() -> float:
	return Tuning.ENERGY_REGEN + Tuning.ENERGY_REGEN_PER_UP * rank("energy_regen")

func shield_max() -> float:
	return Tuning.SHIELD_MAX + 25.0 * rank("shield_capacity")

func difficulty() -> int:
	return clampi(int(data.get("difficulty", 1)), 0, 2)

func ngplus() -> int:
	return int(data.get("ngplus", 0))

# ================================================================ chapters
func chapter_record(idx: int) -> Dictionary:
	var id: String = ChapterDB.get_chapter(idx).id
	if not (data.get("chapters") is Dictionary):
		data.chapters = {}
	if not data.chapters.has(id):
		data.chapters[id] = SaveSystem.new_profile(difficulty()).chapters[id]
	return data.chapters[id]

func unlocked_chapter() -> int:
	return clampi(int(data.get("unlocked_chapter", 0)), 0, ChapterDB.COUNT - 1)

func is_chapter_unlocked(idx: int) -> bool:
	if idx <= 0:
		return true
	return idx <= unlocked_chapter() or bool(chapter_record(idx).get("visited", false))

func is_chapter_complete(idx: int) -> bool:
	return bool(chapter_record(idx).get("completed", false))

func chapters_completed() -> int:
	var n := 0
	for i in ChapterDB.COUNT:
		if is_chapter_complete(i):
			n += 1
	return n

func total_fragments_found() -> int:
	var n := 0
	for i in ChapterDB.COUNT:
		for f in chapter_record(i).get("fragments", []):
			if bool(f):
				n += 1
	return n

func s_ranks() -> int:
	var n := 0
	for i in ChapterDB.COUNT:
		if int(chapter_record(i).get("rank", -1)) >= 3:
			n += 1
	return n

func challenges_done() -> int:
	var n := 0
	for i in ChapterDB.COUNT:
		if bool(chapter_record(i).get("challenge", false)):
			n += 1
	return n

# ================================================================ run tracking
func reset_run(chapter_idx: int) -> void:
	run = {
		"chapter": chapter_idx, "active": false, "paused": false,
		"time": 0.0, "xp": 0, "damage_taken": 0.0, "deaths": 0,
		"puzzles": 0, "puzzles_perfect": 0, "puzzle_total": int(ChapterDB.get_chapter(chapter_idx).puzzles),
		"scans": 0, "new_scans": 0, "fragments": 0, "hidden": 0,
		"wildlife": 0, "bypassed": 0, "spotted": 0, "shifts": 0,
		"challenge": false, "component": false, "no_damage": true,
		"checkpoint_id": "", "hint_uses": 0, "time_trial": false,
	}

func begin_run() -> void:
	run.active = true
	session_start_msec = Time.get_ticks_msec()

func end_run() -> void:
	run.active = false

func note_damage(amount: float) -> void:
	run.damage_taken = float(run.get("damage_taken", 0.0)) + amount
	if amount > 0.0:
		run.no_damage = false
		break_chain()

func note_death() -> void:
	run.deaths = int(run.get("deaths", 0)) + 1
	data.totals.deaths = int(data.totals.get("deaths", 0)) + 1
	run.no_damage = false

func note_puzzle(perfect: bool) -> void:
	run.puzzles = int(run.get("puzzles", 0)) + 1
	data.totals.puzzles = int(data.totals.get("puzzles", 0)) + 1
	award(Tuning.XP_PUZZLE, "Puzzle solved")
	if perfect:
		run.puzzles_perfect = int(run.get("puzzles_perfect", 0)) + 1
		award(Tuning.XP_PUZZLE_PERFECT, "Perfect solution")

func note_scan(object_id: String) -> void:
	run.scans = int(run.get("scans", 0)) + 1
	data.totals.scans = int(data.totals.get("scans", 0)) + 1
	var seen: Array = data.get("scanned", [])
	if not (object_id in seen):
		seen.append(object_id)
		data.scanned = seen
		run.new_scans = int(run.get("new_scans", 0)) + 1
		award(Tuning.XP_SCAN_NEW + Tuning.XP_FIRST_DISCOVERY, "New specimen: %s" % object_id, true)
	else:
		award(int(Tuning.XP_SCAN_NEW * 0.25), "Rescan")

func note_fragment(chapter_idx: int, index: int) -> bool:
	var rec := chapter_record(chapter_idx)
	var frags: Array = rec.fragments
	if index < 0 or index >= frags.size() or bool(frags[index]):
		return false
	frags[index] = true
	rec.fragments = frags
	run.fragments = int(run.get("fragments", 0)) + 1
	data.totals.fragments = int(data.totals.get("fragments", 0)) + 1
	award(Tuning.XP_FRAGMENT, "Memory Fragment", true)
	fragment_found.emit(chapter_idx, index)
	_check_unlocks()
	return true

func note_hidden_area() -> void:
	run.hidden = int(run.get("hidden", 0)) + 1
	data.totals.hidden = int(data.totals.get("hidden", 0)) + 1
	award(Tuning.XP_HIDDEN_AREA, "Hidden area", true)

func note_wildlife() -> void:
	run.wildlife = int(run.get("wildlife", 0)) + 1
	data.totals.wildlife = int(data.totals.get("wildlife", 0)) + 1
	award(Tuning.XP_WILDLIFE, "Wildlife rescued", true)

func note_bypass() -> void:
	run.bypassed = int(run.get("bypassed", 0)) + 1
	data.totals.bypassed = int(data.totals.get("bypassed", 0)) + 1
	award(Tuning.XP_GHOST_BONUS, "Guardian bypassed")

func note_spotted() -> void:
	run.spotted = int(run.get("spotted", 0)) + 1
	break_chain()

func note_shift() -> void:
	run.shifts = int(run.get("shifts", 0)) + 1

func complete_challenge() -> void:
	if bool(run.get("challenge", false)):
		return
	run.challenge = true
	award(Tuning.XP_CHALLENGE, "Bonus challenge")

# ================================================================ results
## Score model shared by the results screen, ranks and time trials.
func compute_results(chapter_idx: int) -> Dictionary:
	var ch := ChapterDB.get_chapter(chapter_idx)
	var rec := chapter_record(chapter_idx)
	var t: float = float(run.get("time", 0.0))
	var par: float = float(ch.target_time)

	var time_score := int(round(clampf(1.0 - (t - par * 0.55) / (par * 1.1), 0.0, 1.0) * 1600.0))
	var puzzle_score: int = int(run.get("puzzles", 0)) * 260 + int(run.get("puzzles_perfect", 0)) * 140
	var explore_score: int = int(run.get("new_scans", 0)) * 70 + int(run.get("fragments", 0)) * 420 \
		+ int(run.get("hidden", 0)) * 260 + int(run.get("wildlife", 0)) * 190
	var stealth_score: int = int(run.get("bypassed", 0)) * 110 - int(run.get("spotted", 0)) * 60
	var damage_pen: int = int(round(float(run.get("damage_taken", 0.0)) * 2.4)) \
		+ int(run.get("deaths", 0)) * 320

	var bonuses: Array = []
	var bonus_total := 0
	if bool(run.get("no_damage", true)) and int(run.get("deaths", 0)) == 0:
		bonuses.append({"label": "No Damage", "value": 900}); bonus_total += 900
	if bool(run.get("challenge", false)):
		bonuses.append({"label": "Bonus Challenge", "value": 800}); bonus_total += 800
	if int(run.get("fragments", 0)) >= 3:
		bonuses.append({"label": "All Fragments", "value": 700}); bonus_total += 700
	if bool(run.get("component", false)):
		bonuses.append({"label": "Upgrade Component", "value": 450}); bonus_total += 450
	if int(run.get("puzzles", 0)) >= int(ch.puzzles) and int(run.get("puzzles_perfect", 0)) >= int(ch.puzzles):
		bonuses.append({"label": "Perfect Puzzles", "value": 850}); bonus_total += 850
	if int(run.get("new_scans", 0)) >= int(ch.par_scans):
		bonuses.append({"label": "Full Survey", "value": 500}); bonus_total += 500
	if ngplus() > 0:
		var ng := 300 * ngplus()
		bonuses.append({"label": "New Game+ x%d" % ngplus(), "value": ng}); bonus_total += ng

	var total: int = maxi(0, time_score + puzzle_score + explore_score
		+ stealth_score + bonus_total - damage_pen)
	var rank_i := 0
	if total >= 6200: rank_i = 3
	elif total >= 4600: rank_i = 2
	elif total >= 3000: rank_i = 1

	var mastery: bool = bool(run.get("challenge", false)) \
		and int(run.get("fragments", 0)) >= 3 \
		and bool(run.get("component", false)) \
		and rank_i >= 2

	return {
		"chapter": chapter_idx, "title": ch.title,
		"time": t, "par": par,
		"time_score": time_score, "puzzle_score": puzzle_score,
		"explore_score": explore_score, "stealth_score": stealth_score,
		"damage_penalty": damage_pen, "bonuses": bonuses, "bonus_total": bonus_total,
		"total": total, "rank": rank_i, "rank_name": Veil.RANK_NAMES[rank_i],
		"mastery": mastery,
		"xp_gained": int(run.get("xp", 0)),
		"puzzles": int(run.get("puzzles", 0)), "puzzles_total": int(ch.puzzles),
		"fragments": int(run.get("fragments", 0)),
		"scans": int(run.get("new_scans", 0)), "scan_par": int(ch.par_scans),
		"hidden": int(run.get("hidden", 0)),
		"deaths": int(run.get("deaths", 0)),
		"no_damage": bool(run.get("no_damage", true)),
		"prev_best": int(rec.get("best_score", 0)),
		"prev_time": float(rec.get("best_time", 0.0)),
		"new_best": total > int(rec.get("best_score", 0)),
	}

## Commit a finished chapter: awards, records, unlocks, autosave.
func finish_chapter(chapter_idx: int) -> Dictionary:
	var res := compute_results(chapter_idx)
	var rec := chapter_record(chapter_idx)

	award(Tuning.XP_CHAPTER, "Chapter complete")
	if bool(run.get("no_damage", true)) and int(run.get("deaths", 0)) == 0:
		award(Tuning.XP_NO_DAMAGE, "No-damage chapter")
		rec.no_damage = true
	if bool(run.get("challenge", false)):
		rec.challenge = true
	res.xp_gained = int(run.get("xp", 0))

	rec.completed = true
	rec.visited = true
	rec.puzzles = maxi(int(rec.get("puzzles", 0)), int(run.get("puzzles", 0)))
	if int(res.total) > int(rec.get("best_score", 0)):
		rec.best_score = int(res.total)
	if float(rec.get("best_time", 0.0)) <= 0.0 or float(run.time) < float(rec.best_time):
		rec.best_time = float(run.time)
	if int(res.rank) > int(rec.get("rank", -1)):
		rec.rank = int(res.rank)
	if bool(res.mastery):
		rec.mastery = true
	rec.hidden = maxi(int(rec.get("hidden", 0)), int(run.get("hidden", 0)))

	if chapter_idx + 1 < ChapterDB.COUNT:
		data.unlocked_chapter = maxi(unlocked_chapter(), chapter_idx + 1)
	else:
		data.finished_game = true
	data.checkpoint = {}
	_check_unlocks()
	end_run()
	save()
	return res

func record_time_trial(chapter_idx: int, t: float) -> bool:
	var rec := chapter_record(chapter_idx)
	var prev := float(rec.get("time_trial_best", 0.0))
	if prev <= 0.0 or t < prev:
		rec.time_trial_best = t
		save()
		return true
	return false

# ================================================================ checkpoints
func store_checkpoint(chapter_idx: int, cp_id: String, extra: Dictionary) -> void:
	var cp := {
		"chapter": chapter_idx, "id": cp_id,
		"run": run.duplicate(true),
		"stamp": Time.get_unix_time_from_system(),
	}
	cp.merge(extra, true)
	data.checkpoint = cp
	chapter_record(chapter_idx).visited = true
	save()

func has_checkpoint() -> bool:
	return data.get("checkpoint", {}).has("chapter")

func checkpoint() -> Dictionary:
	return data.get("checkpoint", {})

func restore_run_from_checkpoint() -> void:
	var cp: Dictionary = checkpoint()
	if cp.has("run") and cp.run is Dictionary:
		run = (cp.run as Dictionary).duplicate(true)
		run.active = true
		run.paused = false

func clear_checkpoint() -> void:
	data.checkpoint = {}

# ================================================================ unlocks
func has_unlock(kind: String, id: String) -> bool:
	var key := "suits" if kind == "suit" else ("mote_skins" if kind == "mote" else "gallery")
	return id in data.get(key, [])

func _grant(kind: String, id: String, label: String) -> void:
	var key := "suits" if kind == "suit" else ("mote_skins" if kind == "mote" else "gallery")
	var arr: Array = data.get(key, [])
	if id in arr:
		return
	arr.append(id)
	data[key] = arr
	unlock_earned.emit(kind, id, label)
	Log.info("Unlocked %s: %s" % [kind, id])

func _check_unlocks() -> void:
	if is_chapter_complete(2): _grant("suit", "survey", SUITS.survey.name)
	if is_chapter_complete(4): _grant("suit", "deep", SUITS.deep.name)
	if is_chapter_complete(6): _grant("suit", "archivist", SUITS.archivist.name)
	if bool(data.get("finished_game", false)): _grant("suit", "threefold", SUITS.threefold.name)
	if total_fragments_found() >= 24: _grant("suit", "prototype", SUITS.prototype.name)
	if total_fragments_found() >= 10: _grant("mote", "brass", MOTE_SKINS.brass.name)
	if challenges_done() >= 4: _grant("mote", "coral", MOTE_SKINS.coral.name)
	if s_ranks() >= 4: _grant("mote", "glassmote", MOTE_SKINS.glassmote.name)
	if ngplus() > 0: _grant("mote", "origin", MOTE_SKINS.origin.name)
	# Gallery pieces track fragments and chapter completions.
	var pieces := total_fragments_found() + chapters_completed() * 2
	for i in mini(pieces, 24):
		_grant("gallery", "art_%02d" % (i + 1), "Concept %02d" % (i + 1))

func set_suit(id: String) -> void:
	if has_unlock("suit", id):
		data.current_suit = id
		save()

func set_mote_skin(id: String) -> void:
	if has_unlock("mote", id):
		data.current_mote_skin = id
		save()

func suit_colors() -> Dictionary:
	var id := String(data.get("current_suit", "field"))
	return SUITS.get(id, SUITS.field)

func mote_colors() -> Dictionary:
	var id := String(data.get("current_mote_skin", "standard"))
	return MOTE_SKINS.get(id, MOTE_SKINS.standard)

# ================================================================ new game +
func start_new_game_plus() -> void:
	data.ngplus = ngplus() + 1
	data.unlocked_chapter = 0
	data.checkpoint = {}
	data.finished_game = false
	for c in ChapterDB.CHAPTERS:
		var rec: Dictionary = data.chapters[c.id]
		rec.completed = false
		rec.visited = false
	_check_unlocks()
	reset_run(0)
	save()
	Log.info("New Game+ %d started" % ngplus())

func completion_percent() -> float:
	return SaveSystem.completion_percent(data)
