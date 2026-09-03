extends Node
## Three-slot local save system. Plain JSON under user://saves/.
##
## Every write is atomic (temp file -> rename) and keeps a .bak of the previous
## good save, so a crash mid-write can never destroy a profile. Loading a
## missing, truncated or hand-mangled file degrades to the backup and then to a
## clean profile rather than throwing.

signal slot_written(slot: int)
signal save_failed(slot: int, reason: String)

const DIR := "user://saves"
const SLOTS := 3
const VERSION := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_dir()

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		var e := DirAccess.make_dir_recursive_absolute(DIR)
		if e != OK:
			Log.err("Cannot create save directory (%d)" % e)

func path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, clampi(slot, 0, SLOTS - 1)]

func bak_path(slot: int) -> String:
	return "%s/slot_%d.bak" % [DIR, clampi(slot, 0, SLOTS - 1)]

func tmp_path(slot: int) -> String:
	return "%s/slot_%d.tmp" % [DIR, clampi(slot, 0, SLOTS - 1)]

func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(bak_path(slot))

# ================================================================ default data
func new_profile(difficulty: int) -> Dictionary:
	var chapters := {}
	for c in ChapterDB.CHAPTERS:
		chapters[c.id] = {
			"completed": false, "best_time": 0.0, "best_score": 0, "rank": -1,
			"fragments": [false, false, false], "component": false,
			"challenge": false, "no_damage": false, "mastery": false,
			"hidden": 0, "puzzles": 0, "time_trial_best": 0.0, "visited": false,
		}
	return {
		"version": VERSION,
		"created": Time.get_unix_time_from_system(),
		"updated": Time.get_unix_time_from_system(),
		"playtime": 0.0,
		"difficulty": clampi(difficulty, 0, 2),
		"ngplus": 0,
		"xp": 0,
		"components": 0,
		"upgrades": {},
		"chapters": chapters,
		"unlocked_chapter": 0,
		"suits": ["field"],
		"current_suit": "field",
		"mote_skins": ["standard"],
		"current_mote_skin": "standard",
		"gallery": [],
		"codex": [],
		"scanned": [],
		"checkpoint": {},
		"totals": {"puzzles": 0, "scans": 0, "deaths": 0, "wildlife": 0,
			"fragments": 0, "hidden": 0, "bypassed": 0},
		"finished_game": false,
	}

# ================================================================ write
func write(slot: int, data: Dictionary) -> bool:
	_ensure_dir()
	slot = clampi(slot, 0, SLOTS - 1)
	var d := data.duplicate(true)
	d["version"] = VERSION
	d["updated"] = Time.get_unix_time_from_system()
	var text := JSON.stringify(d, "  ")

	var f := FileAccess.open(tmp_path(slot), FileAccess.WRITE)
	if f == null:
		var reason := "open temp failed (%d)" % FileAccess.get_open_error()
		Log.err("Save slot %d: %s" % [slot, reason])
		save_failed.emit(slot, reason)
		return false
	f.store_string(text)
	f.flush()
	f.close()

	# Verify the temp file parses before it is allowed to replace anything.
	var verify := FileAccess.open(tmp_path(slot), FileAccess.READ)
	if verify == null or JSON.parse_string(verify.get_as_text()) == null:
		if verify: verify.close()
		Log.err("Save slot %d: temp file failed verification" % slot)
		save_failed.emit(slot, "verification failed")
		return false
	verify.close()

	var dir := DirAccess.open(DIR)
	if dir == null:
		save_failed.emit(slot, "cannot open save directory")
		return false
	if FileAccess.file_exists(path(slot)):
		if FileAccess.file_exists(bak_path(slot)):
			dir.remove(bak_path(slot).get_file())
		dir.rename(path(slot).get_file(), bak_path(slot).get_file())
	var e := dir.rename(tmp_path(slot).get_file(), path(slot).get_file())
	if e != OK:
		Log.err("Save slot %d: rename failed (%d)" % [slot, e])
		save_failed.emit(slot, "rename failed (%d)" % e)
		return false
	Log.info("Saved slot %d (%d bytes)" % [slot, text.length()])
	slot_written.emit(slot)
	return true

# ================================================================ read
func read(slot: int) -> Dictionary:
	slot = clampi(slot, 0, SLOTS - 1)
	var d := _read_file(path(slot))
	if d.is_empty():
		d = _read_file(bak_path(slot))
		if not d.is_empty():
			Log.warn("Slot %d: primary save unreadable, recovered from backup." % slot)
	if d.is_empty():
		return {}
	return _migrate(_sanitise(d))

func _read_file(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		Log.warn("Cannot open %s (%d)" % [p, FileAccess.get_open_error()])
		return {}
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	Log.warn("Save file %s is not valid JSON; ignoring." % p)
	return {}

## Fill in anything a hand-edited or older file is missing, and force types.
func _sanitise(d: Dictionary) -> Dictionary:
	var base := new_profile(int(d.get("difficulty", 1)))
	for k in base.keys():
		if not d.has(k):
			d[k] = base[k]
	# Chapter records must all exist with the right shape.
	var chs: Dictionary = d.get("chapters", {})
	if not (chs is Dictionary):
		chs = {}
	for c in ChapterDB.CHAPTERS:
		var rec: Variant = chs.get(c.id, null)
		if not (rec is Dictionary):
			chs[c.id] = base.chapters[c.id]
			continue
		for rk in base.chapters[c.id].keys():
			if not (rec as Dictionary).has(rk):
				rec[rk] = base.chapters[c.id][rk]
		var frags: Variant = rec.get("fragments", [])
		if not (frags is Array) or (frags as Array).size() != 3:
			rec["fragments"] = [false, false, false]
	d["chapters"] = chs
	d["xp"] = maxi(0, int(d.get("xp", 0)))
	d["components"] = maxi(0, int(d.get("components", 0)))
	d["playtime"] = maxf(0.0, float(d.get("playtime", 0.0)))
	d["difficulty"] = clampi(int(d.get("difficulty", 1)), 0, 2)
	d["ngplus"] = maxi(0, int(d.get("ngplus", 0)))
	d["unlocked_chapter"] = clampi(int(d.get("unlocked_chapter", 0)), 0, ChapterDB.COUNT - 1)
	for arr_key in ["suits", "mote_skins", "gallery", "codex", "scanned"]:
		if not (d.get(arr_key) is Array):
			d[arr_key] = base[arr_key]
	if not (d.get("upgrades") is Dictionary):
		d["upgrades"] = {}
	if not (d.get("checkpoint") is Dictionary):
		d["checkpoint"] = {}
	if not (d.get("totals") is Dictionary):
		d["totals"] = base.totals
	else:
		for tk in base.totals.keys():
			if not d.totals.has(tk):
				d.totals[tk] = 0
	return d

func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v == VERSION:
		return d
	if v < 1:
		d["version"] = 1
	Log.info("Migrated save from version %d to %d" % [v, VERSION])
	return d

# ================================================================ slot headers
## Lightweight summary for the slot-select UI; never touches game state.
func header(slot: int) -> Dictionary:
	var d := read(slot)
	if d.is_empty():
		return {"empty": true, "slot": slot}
	var completed := 0
	var frags := 0
	for c in ChapterDB.CHAPTERS:
		var rec: Dictionary = d.chapters.get(c.id, {})
		if bool(rec.get("completed", false)):
			completed += 1
		for f in rec.get("fragments", []):
			if bool(f):
				frags += 1
	var cur := int(d.get("unlocked_chapter", 0))
	var cp: Dictionary = d.get("checkpoint", {})
	if cp.has("chapter"):
		cur = clampi(int(cp.chapter), 0, ChapterDB.COUNT - 1)
	return {
		"empty": false, "slot": slot,
		"chapter_index": cur,
		"chapter_title": ChapterDB.title(cur),
		"level": Veil.level_for_xp(int(d.get("xp", 0))),
		"xp": int(d.get("xp", 0)),
		"playtime": float(d.get("playtime", 0.0)),
		"updated": int(d.get("updated", 0)),
		"difficulty": int(d.get("difficulty", 1)),
		"ngplus": int(d.get("ngplus", 0)),
		"chapters_done": completed,
		"fragments": frags,
		"finished": bool(d.get("finished_game", false)),
		"completion": completion_percent(d),
	}

func completion_percent(d: Dictionary) -> float:
	var total := 0.0
	var got := 0.0
	for c in ChapterDB.CHAPTERS:
		var rec: Dictionary = d.chapters.get(c.id, {})
		total += 1.0 + 3.0 + 1.0 + 1.0 + 1.0    # complete, 3 frags, component, challenge, no-damage
		if bool(rec.get("completed", false)): got += 1.0
		for f in rec.get("fragments", []):
			if bool(f): got += 1.0
		if bool(rec.get("component", false)): got += 1.0
		if bool(rec.get("challenge", false)): got += 1.0
		if bool(rec.get("no_damage", false)): got += 1.0
	return 100.0 * got / maxf(total, 1.0)

func erase(slot: int) -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for p in [path(slot), bak_path(slot), tmp_path(slot)]:
		if FileAccess.file_exists(p):
			dir.remove(p.get_file())
	Log.info("Erased slot %d" % slot)

func any_save_exists() -> bool:
	for i in SLOTS:
		if exists(i):
			return true
	return false

func newest_slot() -> int:
	var best := -1
	var best_t := -1.0
	for i in SLOTS:
		var h := header(i)
		if h.get("empty", true):
			continue
		if float(h.updated) > best_t:
			best_t = float(h.updated)
			best = i
	return best
