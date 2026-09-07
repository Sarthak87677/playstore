extends CanvasLayer
class_name PostFX
## The finishing pass, sitting under the HUD and over the world.
##
## Strength follows the graphics preset and the accessibility settings: reduced
## flashing turns the grain down, because animated noise is exactly the kind of
## thing that setting exists for.

var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	Settings.video_changed.connect(apply_settings)
	Settings.accessibility_changed.connect(apply_settings)
	apply_settings()

func _process(dt: float) -> void:
	# The grain has to move, or it reads as dirt on the screen rather than as
	# sensor noise. One new seed per frame is enough.
	_t += dt
	if _mat != null and visible:
		_mat.set_shader_parameter("time_seed", _t * 60.0)

func apply_settings() -> void:
	if _mat == null:
		return
	var d := Settings.preset_data()
	var q := float(d.get("post_quality", 1.0))
	visible = q > 0.001
	var quiet := 0.45 if Settings.reduce_flashing else 1.0
	_mat.set_shader_parameter("grain", 0.030 * q * quiet)
	_mat.set_shader_parameter("vignette", 0.30 * q)
	_mat.set_shader_parameter("aberration", 0.70 * q)
	_mat.set_shader_parameter("sharpen", 0.42 * clampf(q, 0.0, 1.2))
