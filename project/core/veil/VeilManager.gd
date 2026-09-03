extends Node3D
class_name VeilManager
## Owns the world's reality state. Subjects register here; fields (the player's
## aimed field plus any pinned ones) are evaluated against them every time
## something moves, and subjects are told which state they should be in.
##
## Also answers `state_at(point)`, which the world environment, weather,
## ambience and guardian AI use so that every system agrees on what reality the
## player is currently standing in.

signal base_state_changed(state: int)
signal local_state_changed(state: int)
signal subject_shifted(subject: VeilSubject, state: int)
signal field_activity(active: bool)

@export var base_state: int = Veil.State.RUIN

var subjects: Array[VeilSubject] = []
var fields: Array[VeilField] = []
var _local_state: int = Veil.State.RUIN
var _dirty := true
var _last_centers: Array = []
var _player: Node3D = null

func _ready() -> void:
	add_to_group("veil_manager")
	_local_state = base_state

func set_player(p: Node3D) -> void:
	_player = p

func register(s: VeilSubject) -> void:
	if s in subjects:
		return
	subjects.append(s)
	s.apply_state(state_for(s), true)

func unregister(s: VeilSubject) -> void:
	subjects.erase(s)

func add_field(f: VeilField) -> void:
	if f in fields:
		return
	fields.append(f)
	_dirty = true
	field_activity.emit(true)

func remove_field(f: VeilField) -> void:
	if not (f in fields):
		return
	fields.erase(f)
	_dirty = true
	if fields.is_empty():
		field_activity.emit(false)

func mark_dirty() -> void:
	_dirty = true

func set_base_state(s: int, animate: bool = true) -> void:
	s = clampi(s, 0, 2)
	if s == base_state:
		return
	base_state = s
	_dirty = true
	base_state_changed.emit(s)

## Which state applies at an arbitrary world point.
func state_at(point: Vector3) -> int:
	var best := base_state
	var best_d := INF
	for f in fields:
		if f == null or not f.active or not is_instance_valid(f):
			continue
		var d := f.global_position.distance_to(point)
		if d <= f.radius and d < best_d:
			best_d = d
			best = f.target_state
	return best

func state_for(s: VeilSubject) -> int:
	if s.locked:
		return s.current_state
	var best := base_state
	var best_d := INF
	for f in fields:
		if f == null or not is_instance_valid(f) or not f.active:
			continue
		var d := f.global_position.distance_to(s.global_position)
		if d <= f.radius + s.influence_radius and d < best_d:
			best_d = d
			best = f.target_state
	return best

func _physics_process(_dt: float) -> void:
	# Re-evaluate when a field moved, was added/removed, or the base changed.
	if not _dirty:
		var centers: Array = []
		for f in fields:
			if is_instance_valid(f):
				centers.append([f.global_position, f.radius, f.target_state, f.active])
		if centers != _last_centers:
			_dirty = true
			_last_centers = centers
	if not _dirty:
		return
	_dirty = false
	var centers2: Array = []
	for f in fields:
		if is_instance_valid(f):
			centers2.append([f.global_position, f.radius, f.target_state, f.active])
	_last_centers = centers2

	for s in subjects:
		if not is_instance_valid(s):
			continue
		var want := state_for(s)
		if want != s.current_state:
			s.apply_state(want)
			subject_shifted.emit(s, want)

	if _player != null and is_instance_valid(_player):
		var ls := state_at(_player.global_position)
		if ls != _local_state:
			_local_state = ls
			local_state_changed.emit(ls)

func local_state() -> int:
	return _local_state

## Permanently fix a subject in its current state (used when a puzzle result
## should survive the field moving away).
func lock_subject(id: String, state: int = -1) -> void:
	for s in subjects:
		if s.subject_id == id:
			if state >= 0:
				s.locked = false
				s.apply_state(state)
			s.locked = true

func unlock_subject(id: String) -> void:
	for s in subjects:
		if s.subject_id == id:
			s.locked = false
	_dirty = true

func find_subject(id: String) -> VeilSubject:
	for s in subjects:
		if s.subject_id == id:
			return s
	return null

func subject_count() -> int:
	return subjects.size()

func cleanup() -> void:
	subjects.clear()
	fields.clear()
