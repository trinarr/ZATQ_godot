extends Button
# Original Flash arrows use their visible silhouette as the hit region.
var hit_image: Image
func _has_point(point: Vector2) -> bool:
 if hit_image == null or size.x <= 0 or size.y <= 0:return false
 var pixel: Vector2i = Vector2i(point / size * Vector2(hit_image.get_size()))
 if pixel.x < 0 or pixel.y < 0 or pixel.x >= hit_image.get_width() or pixel.y >= hit_image.get_height():return false
 return hit_image.get_pixelv(pixel).a > 0.03
