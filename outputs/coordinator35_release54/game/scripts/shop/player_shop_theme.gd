extends RefCounted
## Visual language of the shop UI. The palette repeats the existing game HUD (dark
## navy panel, gold border and keycap) so the shop reads as part of the game
## instead of another application. Pure styling: no state, no owner references.
const PANEL_BG := "0a1118f2"
const PANEL_BORDER := "dfb968"
const MODAL_BG := "0a1118fc"
const SLOT_BG := "141c24"
const SLOT_BORDER := "3a4750"
const SLOT_HOVER_BG := "1d2831"
const SLOT_HOVER_BORDER := "b09a74"
const SLOT_OWNED_BG := "101820"
const SLOT_OWNED_BORDER := "4a5a4a"
const TEXT := "e0e7ec"
const DIM := "aabec8"
const GOLD := "ebc77f"
const GOOD := "9ad48a"
const BAD := "e08b84"
const MONEY := "ffd76b"
const KEY_BG := "f7dc9c"
const KEY_BORDER := "a27a35"
const DISABLED_BG := "1a2026"
const DISABLED_BORDER := "3a4249"
const DISABLED_TEXT := "6d777d"

static func panel_style(background: String, border: String, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

static func slot_style(background: String, border: String, width: int = 1, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

static func label(text: String, pixels: int, color: String = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", Color(color))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func margins(amount: int) -> MarginContainer:
	var result := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		result.add_theme_constant_override("margin_" + side, amount)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func picture(height: float) -> TextureRect:
	var result := TextureRect.new()
	result.custom_minimum_size = Vector2(0, height)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func keycap(text: String) -> PanelContainer:
	var result := PanelContainer.new()
	result.custom_minimum_size = Vector2(26, 26)
	result.add_theme_stylebox_override("panel", panel_style(KEY_BG, KEY_BORDER, 5))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := label(text, 14, "211d17")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_child(caption)
	return result

static func button(text: String, pixels: int = 13) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_ALL
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_size_override("font_size", pixels)
	result.add_theme_color_override("font_color", Color(TEXT))
	result.add_theme_color_override("font_hover_color", Color("ffffff"))
	result.add_theme_color_override("font_disabled_color", Color(DISABLED_TEXT))
	result.add_theme_stylebox_override("normal", slot_style(SLOT_BG, SLOT_BORDER))
	result.add_theme_stylebox_override("hover", slot_style(SLOT_HOVER_BG, SLOT_HOVER_BORDER))
	result.add_theme_stylebox_override("pressed", slot_style(SLOT_HOVER_BG, PANEL_BORDER))
	result.add_theme_stylebox_override("focus", slot_style(SLOT_HOVER_BG, PANEL_BORDER))
	result.add_theme_stylebox_override("disabled", slot_style(DISABLED_BG, DISABLED_BORDER))
	return result

## Primary action (buy / talk) uses the gold keycap colours of the HUD.
static func primary_style() -> StyleBoxFlat:
	return panel_style("9c8155", "bba783", 5)
