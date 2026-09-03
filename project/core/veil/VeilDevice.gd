extends Node3D
class_name VeilDevice
## The Veilforge Device: energy cell, movable reality field, scanner, property
## register, imprinter and EMP. Attached to the player; drives every veil
## interaction the player has with the world.

signal energy_changed(value: float, maximum: float)
signal state_selected(state: int)
signal field_state(aiming: bool, pinned: bool)
signal scan_progress(fraction: float, target_name: String)
signal scan_complete(info: Dictionary)
signal record_changed(slots: Array, selected: int)
signal message(text: String, kind: String)
signal emp_fired(position: Vector3, radius: float)
signal shift_performed(state: int, position: Vector3)

const PROP_LIFETIME := 180.0

var player: CharacterBody3D
var camera: Camera3D
var manager: VeilManager

var energy: float = Tuning.ENERGY_MAX
var energy_max: float = Tuning.ENERGY_MAX
var selected_state: int = Veil.State.MEMORY
var aiming := false
var _aim_toggle := false
var _regen_delay := 0.0

var field: VeilField                 # the aimed field (follows the reticle)
var pinned_field: VeilField = null

var records: Array = []              # [{prop:int, source:String, t:float}]
var selected_record: int = 0

var _scan_target: Scannable = null
var _scan_t: float = 0.0
var _scanning := false
var _emp_cd := 0.0
var _last_hit_point: Vector3 = Vector3.ZERO
var _unlocked := {"field": false, "pin": false, "scan": false, "imprint": false, "emp": false}

func _ready() -> void:
	add_to_group("veil_device")
	field = VeilField.new()
	field.active = false
	field.visible = false
	add_child(field)
	# The aimed field lives in world space, not on the player.
	field.top_level = true
	energy_max = GameState.shield_max() * 0.0 + Tuning.ENERGY_MAX
	energy = energy_max
	set_physics_process(true)

func unlock(feature: String) -> void:
	if _unlocked.has(feature) and not _unlocked[feature]:
		_unlocked[feature] = true
		message.emit("Device module online: %s" % feature.capitalize(), "unlock")

func unlock_all() -> void:
	for k in _unlocked.keys():
		_unlocked[k] = true

func is_unlocked(f: String) -> bool:
	return bool(_unlocked.get(f, false))

# ================================================================ energy
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if energy < amount:
		AudioDirector.play("energy_low", -6.0)
		message.emit("Cell too low", "warn")
		return false
	energy -= amount
	_regen_delay = Tuning.ENERGY_REGEN_DELAY
	energy_changed.emit(energy, energy_max)
	return true

func refill(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, energy_max)
	energy_changed.emit(energy, energy_max)

func _physics_process(dt: float) -> void:
	if _regen_delay > 0.0:
		_regen_delay = maxf(0.0, _regen_delay - dt)
	elif energy < energy_max:
		energy = minf(energy_max, energy + GameState.energy_regen() * dt)
		energy_changed.emit(energy, energy_max)

	if _emp_cd > 0.0:
		_emp_cd = maxf(0.0, _emp_cd - dt)

	if aiming:
		_update_aim(dt)
		if not spend_continuous(Tuning.FIELD_HOLD_DRAIN * dt):
			set_aiming(false)

	if pinned_field != null and is_instance_valid(pinned_field):
		if pinned_field.life <= 0.0:
			_expire_pin()

	_update_scan(dt)
	_expire_records(dt)

func spend_continuous(amount: float) -> bool:
	if energy <= 0.0:
		return false
	energy = maxf(0.0, energy - amount)
	_regen_delay = Tuning.ENERGY_REGEN_DELAY
	energy_changed.emit(energy, energy_max)
	return energy > 0.0

# ================================================================ field
func set_aiming(on: bool) -> void:
	if on and not is_unlocked("field"):
		return
	if aiming == on:
		return
	aiming = on
	field.active = on
	field.visible = on
	field.radius = GameState.field_radius()
	if on:
		manager_add(field)
		AudioDirector.play("field_open", -8.0)
	else:
		manager_remove(field)
		AudioDirector.play("field_close", -10.0)
	field_state.emit(aiming, pinned_field != null)

func toggle_aim() -> void:
	_aim_toggle = not _aim_toggle
	set_aiming(_aim_toggle)

func manager_add(f: VeilField) -> void:
	if manager:
		manager.add_field(f)

func manager_remove(f: VeilField) -> void:
	if manager:
		manager.remove_field(f)

func _update_aim(dt: float) -> void:
	if camera == null:
		return
	field.radius = GameState.field_radius()
	field.target_state = selected_state
	var range_m := GameState.field_range()
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * range_m)
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [player.get_rid()] if player else []
	var hit := space.intersect_ray(q)
	var target: Vector3
	if hit.is_empty():
		target = from + dir * range_m
	else:
		target = (hit.position as Vector3) + (hit.normal as Vector3) * field.radius * 0.35
	_last_hit_point = target
	field.global_position = field.global_position.lerp(target, clampf(dt * 18.0, 0.0, 1.0))

## Commit the shift: everything inside the field becomes the selected state.
func perform_shift() -> bool:
	if not aiming or not is_unlocked("field"):
		return false
	var cost := GameState.shift_cost()
	if not spend(cost):
		return false
	if manager:
		manager.mark_dirty()
	GameState.note_shift()
	Hints.did("veil_shift")
	Hints.note_progress()
	AudioDirector.play(["shift_memory", "shift_ruin", "shift_bloom"][selected_state], -4.0)
	shift_performed.emit(selected_state, field.global_position)
	return true

func cycle_state(dir: int) -> void:
	selected_state = posmod(selected_state + dir, 3)
	field.target_state = selected_state
	AudioDirector.play("switch", -12.0, 1.0 + 0.06 * selected_state)
	Hints.did("veil_cycle")
	state_selected.emit(selected_state)
	if manager:
		manager.mark_dirty()

func set_state(s: int) -> void:
	selected_state = clampi(s, 0, 2)
	field.target_state = selected_state
	state_selected.emit(selected_state)
	if manager:
		manager.mark_dirty()

func pin_field() -> bool:
	if not is_unlocked("pin"):
		return false
	if pinned_field != null and is_instance_valid(pinned_field):
		_expire_pin()
		return true
	if not aiming:
		message.emit("Project the field first", "warn")
		return false
	if not spend(Tuning.PIN_COST * Tuning.energy_scale(GameState.difficulty())):
		return false
	var f := VeilField.new()
	f.pinned = true
	f.radius = field.radius
	f.target_state = selected_state
	f.life = GameState.pin_duration()
	get_tree().current_scene.add_child(f)
	f.global_position = field.global_position
	pinned_field = f
	manager_add(f)
	AudioDirector.play("field_pin", -5.0)
	Hints.did("veil_pin")
	field_state.emit(aiming, true)
	return true

func _expire_pin() -> void:
	if pinned_field == null:
		return
	manager_remove(pinned_field)
	if is_instance_valid(pinned_field):
		pinned_field.queue_free()
	pinned_field = null
	AudioDirector.play("field_close", -12.0)
	field_state.emit(aiming, false)

func clear_pin() -> void:
	_expire_pin()

# ================================================================ scanning
func begin_scan() -> void:
	if not is_unlocked("scan"):
		return
	_scanning = true

func end_scan() -> void:
	_scanning = false
	_scan_t = 0.0
	if _scan_target != null:
		scan_progress.emit(0.0, "")
	_scan_target = null

func _best_scan_target() -> Scannable:
	if camera == null:
		return null
	var best: Scannable = null
	var best_score := -1.0
	var cam_pos := camera.global_position
	var fwd := -camera.global_transform.basis.z
	for n in get_tree().get_nodes_in_group("scannable"):
		var s := n as Scannable
		if s == null or not s.is_inside_tree():
			continue
		var to := s.global_position - cam_pos
		var d := to.length()
		if d > Tuning.SCAN_RANGE or d < 0.2:
			continue
		var dot := fwd.dot(to / d)
		if dot < 0.86:
			continue
		var score := dot - d * 0.004
		if score > best_score:
			best_score = score
			best = s
	return best

func _update_scan(dt: float) -> void:
	if not _scanning:
		return
	var t := _best_scan_target()
	if t != _scan_target:
		_scan_target = t
		_scan_t = 0.0
		if t != null:
			AudioDirector.play("scan_start", -16.0)
	if _scan_target == null:
		scan_progress.emit(0.0, "")
		return
	_scan_t += dt
	var need := GameState.scan_time()
	scan_progress.emit(clampf(_scan_t / need, 0.0, 1.0), _scan_target.display_name)
	if _scan_t >= need:
		var info := _scan_target.perform_scan(player)
		AudioDirector.play("scan_done", -8.0)
		Hints.did("scan")
		Hints.note_progress()
		if int(info.property) != Veil.Prop.NONE:
			_store_record(int(info.property), String(info.name))
		scan_complete.emit(info)
		_scan_t = 0.0
		_scan_target = null
		scan_progress.emit(0.0, "")

# ================================================================ records
func _store_record(prop: int, source: String) -> void:
	for r in records:
		if int(r.prop) == prop:
			r.t = PROP_LIFETIME
			r.source = source
			record_changed.emit(records, selected_record)
			return
	records.append({"prop": prop, "source": source, "t": PROP_LIFETIME})
	while records.size() > GameState.record_slots():
		records.pop_front()
	selected_record = records.size() - 1
	message.emit("Recorded: %s" % Veil.prop_name(prop), "record")
	record_changed.emit(records, selected_record)

func _expire_records(dt: float) -> void:
	var changed := false
	for i in range(records.size() - 1, -1, -1):
		records[i].t = float(records[i].t) - dt
		if float(records[i].t) <= 0.0:
			records.remove_at(i)
			changed = true
	if changed:
		selected_record = clampi(selected_record, 0, maxi(0, records.size() - 1))
		record_changed.emit(records, selected_record)

func cycle_record(dir: int) -> void:
	if records.is_empty():
		return
	selected_record = posmod(selected_record + dir, records.size())
	record_changed.emit(records, selected_record)

func current_property() -> int:
	if records.is_empty():
		return Veil.Prop.NONE
	return int(records[clampi(selected_record, 0, records.size() - 1)].prop)

func has_property(p: int) -> bool:
	for r in records:
		if int(r.prop) == p:
			return true
	return false

func consume_property(p: int) -> void:
	for i in records.size():
		if int(records[i].prop) == p:
			records.remove_at(i)
			selected_record = clampi(selected_record, 0, maxi(0, records.size() - 1))
			record_changed.emit(records, selected_record)
			return

# ================================================================ imprinting
func nearest_imprintable(max_dist: float = 4.0) -> Imprintable:
	if player == null:
		return null
	var best: Imprintable = null
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("imprintable"):
		var im := n as Imprintable
		if im == null or not im.is_inside_tree():
			continue
		var d := im.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = im
	return best

func try_imprint() -> bool:
	if not is_unlocked("imprint"):
		return false
	var target := nearest_imprintable()
	if target == null:
		message.emit("Nothing receptive nearby", "warn")
		return false
	var prop := current_property()
	if prop == Veil.Prop.NONE:
		message.emit("No property recorded. Scan something first.", "warn")
		AudioDirector.play("imprint_fail", -8.0)
		return false
	if not target.accepts(prop):
		message.emit("%s will not hold %s" % [target.label, Veil.prop_name(prop)], "warn")
		AudioDirector.play("imprint_fail", -8.0)
		GameState.run["imprint_fails"] = int(GameState.run.get("imprint_fails", 0)) + 1
		return false
	if not spend(Tuning.IMPRINT_COST * Tuning.energy_scale(GameState.difficulty())):
		return false
	target.apply(prop)
	consume_property(prop)
	AudioDirector.play("imprint", -4.0)
	Hints.did("imprint")
	Hints.note_progress()
	message.emit("Imprinted %s onto %s" % [Veil.prop_name(prop), target.label], "good")
	return true

# ================================================================ emp
func fire_emp() -> bool:
	if not is_unlocked("emp") or _emp_cd > 0.0:
		return false
	if not spend(Tuning.EMP_COST * Tuning.energy_scale(GameState.difficulty())):
		return false
	_emp_cd = 1.2
	var r := GameState.emp_radius()
	var pos := player.global_position if player else global_position
	AudioDirector.play("emp", -3.0)
	Hints.did("emp")
	emp_fired.emit(pos, r)
	for n in get_tree().get_nodes_in_group("guardian"):
		if n.has_method("apply_emp") and (n as Node3D).global_position.distance_to(pos) <= r:
			n.apply_emp(GameState.emp_stun())
	for n in get_tree().get_nodes_in_group("emp_receiver"):
		if n.has_method("on_emp") and (n as Node3D).global_position.distance_to(pos) <= r:
			n.on_emp()
	return true

func aim_point() -> Vector3:
	return _last_hit_point

func energy_fraction() -> float:
	return clampf(energy / maxf(energy_max, 0.001), 0.0, 1.0)
