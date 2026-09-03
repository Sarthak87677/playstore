extends Control
class_name ConceptArt
## Procedurally drawn concept-art plate. Each piece is deterministic from its
## index, so the gallery is a real collection of distinct images rather than a
## placeholder grid.

var piece: int = 0
var unlocked: bool = false
var _rng := RandomNumberGenerator.new()

const SUBJECTS := [
	"Valley approach, first light", "Glass shelf, section study", "Rain shelter, detail",
	"Mill spine, elevation", "Root bridge, load test", "Canopy platform, sketch",
	"Nacre spire, silhouette", "Flooded concourse", "Pearl Lift mechanism",
	"Dish array, winter", "Signal room, interior", "Ice shelf approach",
	"Sink shaft, cross-section", "Reactor ring, first ignition", "Sand-buried gantry",
	"Archipelago, storm front", "Lighthouse, three states", "Tidal causeway",
	"Archive Zero, entry hall", "Record wall, close study", "Founder's desk",
	"Convergence Core, exterior", "Threefold overlap, study", "Engine restart, final",
]

func _ready() -> void:
	custom_minimum_size = Vector2(UITheme.s(300), UITheme.s(180))
	_rng.seed = 9000 + piece * 7717

func _draw() -> void:
	var w := size.x
	var h := size.y
	if not unlocked:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.055, 0.07, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.TEXT_FAINT.darkened(0.4), false, 1.0)
		return
	_rng.seed = 9000 + piece * 7717
	var state := piece % 3
	var accent: Color = Veil.STATE_COLORS[state]
	var sky_top := Color(0.06, 0.08, 0.12).lerp(accent.darkened(0.55), 0.6)
	var sky_bot := accent.darkened(0.15).lerp(Color(0.85, 0.86, 0.9), 0.35)

	# sky gradient
	var bands := 26
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, h * t, w, h / float(bands) + 1.0), sky_top.lerp(sky_bot, t))

	# sun / core
	var sun := Vector2(w * _rng.randf_range(0.2, 0.8), h * _rng.randf_range(0.18, 0.42))
	for r in range(10, 0, -1):
		draw_circle(sun, float(r) * 5.0,
			Color(accent.r, accent.g, accent.b, 0.030 * float(11 - r)))
	draw_circle(sun, 7.0, Color(1, 1, 1, 0.85))

	# layered ridgelines, far to near
	var layers := 4
	for l in layers:
		var base_y := h * (0.48 + 0.13 * float(l))
		var pts := PackedVector2Array()
		pts.append(Vector2(0, h))
		var seg := 26
		var amp := h * (0.16 - 0.028 * float(l))
		var ph := _rng.randf_range(0, TAU)
		for i in seg + 1:
			var x := w * float(i) / float(seg)
			var y := base_y - sin(float(i) * 0.7 + ph) * amp \
				- sin(float(i) * 1.9 + ph * 2.0) * amp * 0.35
			pts.append(Vector2(x, y))
		pts.append(Vector2(w, h))
		var shade := sky_top.lerp(Color(0.02, 0.025, 0.03), 0.25 + 0.2 * float(l))
		draw_colored_polygon(pts, shade)

	# structures
	var count := _rng.randi_range(2, 6)
	for i in count:
		var bx := _rng.randf_range(w * 0.08, w * 0.9)
		var bw := _rng.randf_range(w * 0.03, w * 0.11)
		var bh := _rng.randf_range(h * 0.12, h * 0.46)
		var by := h * 0.86 - bh
		draw_rect(Rect2(bx, by, bw, bh), Color(0.05, 0.055, 0.07, 0.94))
		draw_rect(Rect2(bx, by, bw, bh), accent.darkened(0.4), false, 1.0)
		var rows := int(bh / 9.0)
		for r in rows:
			if _rng.randf() < 0.42:
				draw_rect(Rect2(bx + 2.0, by + 4.0 + float(r) * 9.0,
					maxf(bw - 4.0, 1.0), 3.0), Color(accent.r, accent.g, accent.b, 0.6))

	# foreground silhouette
	var fg := PackedVector2Array()
	fg.append(Vector2(0, h))
	var fseg := 18
	var fph := _rng.randf_range(0, TAU)
	for i in fseg + 1:
		var x := w * float(i) / float(fseg)
		var y := h * 0.90 - sin(float(i) * 1.1 + fph) * h * 0.05
		fg.append(Vector2(x, y))
	fg.append(Vector2(w, h))
	draw_colored_polygon(fg, Color(0.015, 0.02, 0.025))

	# drifting motes
	for i in 22:
		var p := Vector2(_rng.randf_range(0, w), _rng.randf_range(h * 0.15, h * 0.9))
		draw_circle(p, _rng.randf_range(0.7, 1.9), Color(accent.r, accent.g, accent.b,
			_rng.randf_range(0.15, 0.6)))

	# plate border + caption strip
	draw_rect(Rect2(Vector2.ZERO, size), accent.darkened(0.5), false, 1.5)
	draw_rect(Rect2(0, h - 22.0, w, 22.0), Color(0, 0, 0, 0.6))

func subject() -> String:
	return SUBJECTS[clampi(piece, 0, SUBJECTS.size() - 1)]
