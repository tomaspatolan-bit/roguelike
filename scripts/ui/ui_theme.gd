extends RefCounted
## Oathline UI look "Royal Court Enamel" (light, Figma file Oathline UI): palette, fonts, styleboxes, theme.
## Only static helpers; battle_ui.gd, run_main.gd and map_view.gd build their screens with them.
## Colours are the Figma variables (collection "Oathline UI"), names in the comments.

# surfaces
const CANVAS := Color("#F5F0E4")     # surface/canvas
const PANEL := Color("#FFFCF4")      # surface/panel
const INSET := Color("#EAE1CC")      # surface/inset
const RAISED := Color("#FFFFFF")     # surface/raised
const BATTLE := Color("#FBF7ED")     # surface/battle (HUD over the battlefield)
const INK_BG := Color("#121418")     # surface/ink
const IRON := Color("#2A2F36")       # surface/iron
# text
const TEXT := Color("#242830")       # text/primary
const TEXT_2 := Color("#4F5660")     # text/secondary
const TEXT_MUTED := Color("#626B75") # text/muted
const ON_DARK := Color("#FFFCF4")    # text/on-dark
# borders
const BORDER := Color("#B8AE98")     # border/default
const BORDER_STRONG := Color("#806B46")  # border/strong
const OUTLINE := Color("#121418")    # border/outline
# accents and states
const OATH := Color("#A72D27")       # accent/oath
const GLORY := Color("#8A641F")      # accent/glory
const GILT := Color("#D4A23F")       # accent/gilt
const HOUSE := Color("#4A6684")      # accent/house
const GOOD := Color("#426B3B")       # state/good
const BAD := Color("#A72D27")        # state/bad
const WARNING := Color("#8A641F")    # state/warning
const INFO := Color("#4A6684")       # state/info
const BOND := [Color("#737F8B"), Color("#8A641F"), Color("#704D83")]   # bond/level-1..3

const RADIUS := 6

static var _fonts := {}


## Font by role: "ui" (Inter), "title" (Cinzel, ceremonial caps), "lore" (EB Garamond), "lore_i" (italic).
## Variable fonts get their weight through FontVariation. Without the font file a system font is used.
static func font(role: String = "ui", weight: int = 400) -> Font:
	var key := "%s:%d" % [role, weight]
	if _fonts.has(key):
		return _fonts[key]
	var file := {"ui": "Inter", "title": "Cinzel", "lore": "EBGaramond", "lore_i": "EBGaramond-Italic"}.get(role, "Inter") as String
	var path := "res://art/fonts/%s.ttf" % file
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path) as Font
	if base == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			base = ff
	if base == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans", "Arial"]) if role == "ui" else PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif", "serif"])
		sf.font_weight = weight
		sf.font_italic = role == "lore_i"
		base = sf
	var out: Font = base
	if base is FontFile and weight != 400:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {"wght": weight}
		out = fv
	_fonts[key] = out
	return out


## A flat enamel box: background, rounded corners, content padding, optional border and a hard drop shadow.
static func box(bg: Color, radius: int = RADIUS, pad: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(OUTLINE, 0.22)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, shadow)
	return s


## Panel: light enamel plate with the dark outline (the main frame of every block).
static func panel_box(pad: int = 14, bg: Color = PANEL) -> StyleBoxFlat:
	return box(bg, RADIUS, pad, OUTLINE, 2, 3)


## Inset block inside a panel (sections, lists).
static func inset_box(pad: int = 10, accent: Color = BORDER) -> StyleBoxFlat:
	return box(INSET, 4, pad, accent, 1)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("ui", 400)
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box(16))
	t.set_stylebox("panel", "Panel", panel_box(0))
	# secondary button: white enamel, strong border; primary buttons are set per button (primary())
	t.set_stylebox("normal", "Button", box(RAISED, RADIUS, 8, BORDER_STRONG, 2, 2))
	t.set_stylebox("hover", "Button", box(Color("#FFF6DF"), RADIUS, 8, GLORY, 2, 2))
	t.set_stylebox("pressed", "Button", box(INSET, RADIUS, 8, OUTLINE, 2))
	t.set_stylebox("disabled", "Button", box(INSET, RADIUS, 8, BORDER, 1))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), RADIUS, 8, HOUSE, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(TEXT_MUTED, 0.7))
	t.set_font("font", "Button", font("ui", 600))
	for cls: String in ["MenuButton", "OptionButton"]:
		t.set_stylebox("normal", cls, box(RAISED, RADIUS, 8, BORDER_STRONG, 2))
		t.set_stylebox("hover", cls, box(Color("#FFF6DF"), RADIUS, 8, GLORY, 2))
		t.set_stylebox("pressed", cls, box(INSET, RADIUS, 8, OUTLINE, 2))
		t.set_stylebox("disabled", cls, box(INSET, RADIUS, 8, BORDER, 1))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, Color(TEXT_MUTED, 0.7))
	# popups and tooltips: light plates
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 4, 6, OUTLINE, 2))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_stylebox("hover", "PopupMenu", box(Color("#F3E6C4"), 3, 4))
	t.set_stylebox("panel", "TooltipPanel", box(INK_BG, 4, 8, GILT, 1))
	t.set_color("font_color", "TooltipLabel", ON_DARK)
	t.set_font_size("font_size", "TooltipLabel", 13)
	# scrollbars
	t.set_stylebox("scroll", "VScrollBar", box(INSET, 4, 0))
	t.set_stylebox("grabber", "VScrollBar", box(BORDER_STRONG, 4, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GLORY, 4, 0))
	return t


static func label(text: String, size: int = 15, color: Color = TEXT, wrap: bool = false, role: String = "ui", weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if role != "ui" or weight != 400:
		l.add_theme_font_override("font", font(role, weight))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Ceremonial title: Cinzel caps.
static func title(text: String, size: int = 28, color: Color = TEXT) -> Label:
	return label(text.to_upper(), size, color, false, "title", 700)


## Small caps section header ("ABILITY", "OATH"…): Inter semibold, letter-spaced feel via caps.
static func eyebrow(text: String, color: Color = TEXT_MUTED, size: int = 11) -> Label:
	return label(text.to_upper(), size, color, false, "ui", 700)


## Primary button: filled colour (oath red by default) with the dark outline and light text.
static func primary(b: Button, col: Color = OATH, size: int = 16) -> Button:
	b.add_theme_stylebox_override("normal", box(col, RADIUS, 10, OUTLINE, 2, 3))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.12), RADIUS, 10, OUTLINE, 2, 3))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.15), RADIUS, 10, OUTLINE, 2))
	b.add_theme_stylebox_override("disabled", box(Color(col.darkened(0.1), 0.45), RADIUS, 10, Color(OUTLINE, 0.4), 2))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, ON_DARK)
	b.add_theme_color_override("font_disabled_color", Color(ON_DARK, 0.75))
	b.add_theme_font_override("font", font("ui", 700))
	b.add_theme_font_size_override("font_size", size)
	return b


## Health or progress bar: dark backplate, coloured fill.
static func bar(fill: Color, h: int = 6) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	var bg := box(IRON, 2, 0, OUTLINE, 1)
	p.add_theme_stylebox_override("background", bg)
	var fs := box(fill, 2, 0)
	fs.set_expand_margin_all(-1)
	p.add_theme_stylebox_override("fill", fs)
	return p


## Readable variant of a hero's colour on light backgrounds (names, frames).
static func on_light(c: Color) -> Color:
	return c.darkened(0.35) if c.get_luminance() > 0.35 else c


## Light canvas with a faint vignette (run screens).
static func canvas_rect() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = CANVAS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg
