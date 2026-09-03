extends Node3D
class_name PuzzleBase
## Shared behaviour for every puzzle: solve bookkeeping, XP award, hint lines,
## a "perfect" flag (solved without a failed attempt or a directed hint), and an
## optional reset so a puzzle can be re-attempted after a mistake.

signal solved(perfect: bool)
signal failed()
signal progress(fraction: float)

@export var puzzle_id: String = ""
@export var title: String = "Mechanism"
@export var hint_subtle: String = "Something here responds to the field."
@export var hint_guided: String = "Try shifting this area to a different state."
@export var hint_directed: String = "Place the field over the mechanism and shift."
@export var award_on_solve: bool = true

var is_solved := false
var mistakes := 0
var hinted := false
var _registered := false

func _ready() -> void:
	add_to_group("puzzle")
	if puzzle_id == "":
		puzzle_id = name

func register_hints() -> void:
	if _registered:
		return
	_registered = true
	Hints.push_context(puzzle_id, [hint_subtle, hint_guided, hint_directed], 1)

func unregister_hints() -> void:
	if not _registered:
		return
	_registered = false
	Hints.pop_context(puzzle_id)

func note_mistake() -> void:
	mistakes += 1
	failed.emit()
	AudioDirector.play("ui_deny", -10.0)

func mark_solved() -> void:
	if is_solved:
		return
	is_solved = true
	var perfect := mistakes == 0 and not hinted
	unregister_hints()
	AudioDirector.play("puzzle_solved", -5.0)
	if award_on_solve:
		GameState.note_puzzle(perfect)
	Hints.note_progress()
	Log.info("Puzzle solved: %s (perfect=%s)" % [puzzle_id, perfect])
	solved.emit(perfect)

func reset_puzzle() -> void:
	is_solved = false
	mistakes = 0

## Player entered the puzzle's area of interest.
func focus_on() -> void:
	if not is_solved:
		register_hints()

func focus_off() -> void:
	unregister_hints()
