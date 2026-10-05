extends RefCounted

const FALLBACK_DISPLAY_FONT: Font = preload("res://fonts/RobotoFlex-Variable.ttf")
const ROBOTO_FLEX_PATH: String = "res://" + "fonts/RobotoFlex-Variable.ttf"

# Headings.
const ROBOTO_FLEX_DISPLAY_WEIGHT: float = 780.0
const ROBOTO_FLEX_DISPLAY_WIDTH: float = 35.0
const ROBOTO_FLEX_DISPLAY_MIN_WIDTH: float = 25.0
const ROBOTO_FLEX_DISPLAY_GRADE: float = -10.0
const ROBOTO_FLEX_DISPLAY_THIN_STROKE: float = 90.0

# Buttons: preserve the current tuning from the supplied ui_fonts.gd.
const ROBOTO_FLEX_BUTTON_WEIGHT: float = 680.0
const ROBOTO_FLEX_BUTTON_WIDTH: float = 25.0
const ROBOTO_FLEX_BUTTON_MIN_WIDTH: float = 25.0
const ROBOTO_FLEX_BUTTON_GRADE: float = -30.0
const ROBOTO_FLEX_BUTTON_THIN_STROKE: float = 80.0

# Regular text: resource counters and other compact informational UI.
const ROBOTO_FLEX_REGULAR_WEIGHT: float = 650.0
const ROBOTO_FLEX_REGULAR_WIDTH: float = 75.0
const ROBOTO_FLEX_REGULAR_GRADE: float = 0.0
const ROBOTO_FLEX_REGULAR_THIN_STROKE: float = 80.0

# Hangman answer letters. Keep the authored font size fixed and use only the
# variable-font width axis to make long answers fit their narrower slots.
const ROBOTO_FLEX_GAME_WORD_WEIGHT: float = 500.0
const ROBOTO_FLEX_GAME_WORD_WIDTH: float = 100.0
const ROBOTO_FLEX_GAME_WORD_MIN_WIDTH: float = 25.0
const ROBOTO_FLEX_GAME_WORD_GRADE: float = 0.0
const ROBOTO_FLEX_GAME_WORD_THIN_STROKE: float = 80.0

# Long-form copy shared by the quiz question and word-comment popup. Keep the
# Regular axes, but use the lighter authored weight requested for this pair.
const ROBOTO_FLEX_QUESTION_COMMENT_WEIGHT: float = 580.0

# Shared Roboto Flex axes.
const ROBOTO_FLEX_THICK_STROKE: float = 80.0

# Subway-style buttons devote more of their height to the caption. Keep this
# separate from heading sizing so page/popup titles are not enlarged.
const DISPLAY_BUTTON_FONT_SCALE: float = 1.25

# A font profile is immutable at runtime. All labels/buttons using the same
# axes can share one variation instead of creating one for every new widget.
static var _variations: Dictionary = {}

static func display_button_font_size(font_size: int) -> int:
	return maxi(1, int(round(float(font_size) * DISPLAY_BUTTON_FONT_SCALE)))

static func _roboto_flex_font(
	weight: float,
	width: float,
	grade: float,
	thin_stroke: float
) -> Font:
	var profile := Vector4(weight, width, grade, thin_stroke)
	if _variations.has(profile):
		return _variations[profile] as Font
	if !ResourceLoader.exists(ROBOTO_FLEX_PATH):
		return FALLBACK_DISPLAY_FONT
	var loaded_resource: Resource = ResourceLoader.load(ROBOTO_FLEX_PATH)
	var base_font: Font = loaded_resource as Font
	if base_font == null:
		return FALLBACK_DISPLAY_FONT
	var variation := FontVariation.new()
	variation.base_font = base_font
	var text_server := TextServerManager.get_primary_interface()
	variation.variation_opentype = {
		text_server.name_to_tag("wght"): weight,
		text_server.name_to_tag("wdth"): width,
		text_server.name_to_tag("GRAD"): grade,
		text_server.name_to_tag("XOPQ"): ROBOTO_FLEX_THICK_STROKE,
		text_server.name_to_tag("YOPQ"): thin_stroke,
	}
	_variations[profile] = variation
	return variation

static func display_font() -> Font:
	return display_font_with_width(ROBOTO_FLEX_DISPLAY_WIDTH)

static func display_font_with_width(width: float = ROBOTO_FLEX_DISPLAY_WIDTH) -> Font:
	var resolved_width: float = clampf(
		roundf(width),
		ROBOTO_FLEX_DISPLAY_MIN_WIDTH,
		ROBOTO_FLEX_DISPLAY_WIDTH
	)
	return _roboto_flex_font(
		ROBOTO_FLEX_DISPLAY_WEIGHT,
		resolved_width,
		ROBOTO_FLEX_DISPLAY_GRADE,
		ROBOTO_FLEX_DISPLAY_THIN_STROKE
	)

static func button_font() -> Font:
	return button_font_with_width(ROBOTO_FLEX_BUTTON_WIDTH)

static func button_font_with_width(width: float = ROBOTO_FLEX_BUTTON_WIDTH) -> Font:
	var resolved_width: float = clampf(
		roundf(width),
		ROBOTO_FLEX_BUTTON_MIN_WIDTH,
		ROBOTO_FLEX_BUTTON_WIDTH
	)
	return _roboto_flex_font(
		ROBOTO_FLEX_BUTTON_WEIGHT,
		resolved_width,
		ROBOTO_FLEX_BUTTON_GRADE,
		ROBOTO_FLEX_BUTTON_THIN_STROKE
	)

static func regular_font() -> Font:
	return _roboto_flex_font(
		ROBOTO_FLEX_REGULAR_WEIGHT,
		ROBOTO_FLEX_REGULAR_WIDTH,
		ROBOTO_FLEX_REGULAR_GRADE,
		ROBOTO_FLEX_REGULAR_THIN_STROKE
	)

static func gameplay_word_font(width: float = ROBOTO_FLEX_GAME_WORD_WIDTH) -> Font:
	# Integer width steps keep the shared FontVariation cache bounded while still
	# making the continuous Roboto Flex axis visually smooth at gameplay sizes.
	var resolved_width: float = clampf(
		roundf(width),
		ROBOTO_FLEX_GAME_WORD_MIN_WIDTH,
		ROBOTO_FLEX_GAME_WORD_WIDTH
	)
	return _roboto_flex_font(
		ROBOTO_FLEX_GAME_WORD_WEIGHT,
		resolved_width,
		ROBOTO_FLEX_GAME_WORD_GRADE,
		ROBOTO_FLEX_GAME_WORD_THIN_STROKE
	)

static func question_comment_font() -> Font:
	return _roboto_flex_font(
		ROBOTO_FLEX_QUESTION_COMMENT_WEIGHT,
		ROBOTO_FLEX_REGULAR_WIDTH,
		ROBOTO_FLEX_REGULAR_GRADE,
		ROBOTO_FLEX_REGULAR_THIN_STROKE
	)
