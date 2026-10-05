extends RefCounted

# Same uniform 2x authoring conversion as Hangman: 480x800 -> 960x1600.
# Zombie's original landscape frame becomes 800x480 -> 1600x960.
const FLASH_SIZE := Vector2(800.0, 480.0)
const AUTHORING_SCALE: float = 2.0
const BASE_SIZE := Vector2(1600.0, 960.0)

static func scaled_rect(authored_rect: Rect2) -> Rect2:
	return Rect2(authored_rect.position * AUTHORING_SCALE, authored_rect.size * AUTHORING_SCALE)

static func scaled_font_size(authored_size: int) -> int:
	return maxi(1, int(round(authored_size * AUTHORING_SCALE)))

static func fit_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return minf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)

static func centered_offset(viewport_size: Vector2) -> Vector2:
	return (viewport_size - BASE_SIZE * fit_scale(viewport_size)) * 0.5
