extends RefCounted
class_name UITheme
## Shared visual language for every menu and overlay: colours, spacing and
## factory helpers so the interface reads as one designed product.

const BG          := Color(0.028, 0.034, 0.044, 0.96)
const BG_SOLID    := Color(0.020, 0.024, 0.031, 1.0)
const PANEL       := Color(0.055, 0.065, 0.082, 0.92)
const PANEL_HI    := Color(0.085, 0.100, 0.125, 0.96)
const LINE        := Color(0.20, 0.26, 0.32, 0.85)
const TEXT        := Color(0.88, 0.91, 0.95)
const TEXT_DIM    := Color(0.52, 0.58, 0.66)
const TEXT_FAINT  := Color(0.34, 0.39, 0.46)
const ACCENT      := Color(0.42, 0.78, 0.98)
const ACCENT_WARM := Color(1.00, 0.68, 0.30)
const GOOD        := Color(0.42, 0.92, 0.58)
const BAD         := Color(0.98, 0.42, 0.38)
const GOLD        := Color(1.00, 0.82, 0.38)

## The engine's default font, for the few places that draw text directly onto a
## canvas rather than through a Label.
static func font() -> Font:
	return ThemeDB.fallback_font

static func s(v: float) -> float:
	return v * Settings.ui_scale

static func panel(color: Color = PANEL, radius: float = 6.0,
		border: float = 1.0, border_col: Color = LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)
	sb.border_width_left = int(border)
	sb.border_width_right = int(border)
	sb.border_width_top = int(border)
	sb.border_width_bottom = int(border)
	sb.border_color = border_col
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func label(text: String, size: int = 18, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(s(size)))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l

static func title(text: String, size: int = 44) -> Label:
	var l := label(text, size, TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 3)
	return l

static func button(text: String, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", int(s(size)))
	b.custom_minimum_size = Vector2(0, s(46))
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", panel(Color(0.07, 0.085, 0.11, 0.85), 4, 1, LINE))
	b.add_theme_stylebox_override("hover", panel(Color(0.13, 0.20, 0.27, 0.95), 4, 1, ACCENT))
	b.add_theme_stylebox_override("pressed", panel(Color(0.18, 0.30, 0.40, 1.0), 4, 1, ACCENT))
	b.add_theme_stylebox_override("focus", panel(Color(0.11, 0.17, 0.24, 0.9), 4, 2, ACCENT))
	b.add_theme_stylebox_override("disabled", panel(Color(0.05, 0.06, 0.07, 0.7), 4, 1, TEXT_FAINT))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	b.mouse_entered.connect(func() -> void: AudioDirector.play_ui("ui_hover", -20.0))
	b.pressed.connect(func() -> void: AudioDirector.play_ui("ui_click", -12.0))
	return b

static func hsep(height: int = 1, color: Color = LINE) -> Control:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	return r

static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, s(h))
	return c

static func bar(color: Color, height: float = 10.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, s(height))
	p.max_value = 1.0
	p.step = 0.0001
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.85)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.corner_radius_top_left = 3
	fg.corner_radius_top_right = 3
	fg.corner_radius_bottom_left = 3
	fg.corner_radius_bottom_right = 3
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p

static func slider(minv: float, maxv: float, step: float, value: float) -> HSlider:
	var h := HSlider.new()
	h.min_value = minv
	h.max_value = maxv
	h.step = step
	h.value = value
	h.custom_minimum_size = Vector2(s(260), s(24))
	h.focus_mode = Control.FOCUS_ALL
	return h

static func option(items: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(String(items[i]), i)
	o.selected = clampi(selected, 0, maxi(0, items.size() - 1))
	o.add_theme_font_size_override("font_size", int(s(18)))
	o.custom_minimum_size = Vector2(s(260), s(36))
	o.focus_mode = Control.FOCUS_ALL
	o.item_selected.connect(func(_i: int) -> void: AudioDirector.play_ui("ui_click", -14.0))
	return o

static func check(pressed: bool) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = pressed
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(_v: bool) -> void: AudioDirector.play_ui("ui_click", -16.0))
	return c

## A labelled settings row: description on the left, control on the right.
static func row(text: String, control: Control, tip: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(s(18)))
	var l := label(text, 18, TEXT)
	l.custom_minimum_size = Vector2(s(300), 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tip != "":
		l.tooltip_text = tip
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h

static func state_chip(state: int, size: int = 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var g := label(Veil.state_glyph(state), size, Settings.state_color(state))
	h.add_child(g)
	h.add_child(label(Veil.state_name(state), size, Settings.state_color(state)))
	return h
