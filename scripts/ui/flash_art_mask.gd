extends RefCounted
# Map a texture's UV into the original mask's local rectangle. This handles
# the top ECG mask's rotation, parent animation and device fit without a viewport.
static func bind(paint: ShaderMaterial, visual: Control, mask_transform: Transform2D, rect: Rect2) -> void:
	paint.set_shader_parameter("art_mask_enabled",true)
	if rect.size.x<=0.0 or rect.size.y<=0.0 or absf(mask_transform.determinant())<0.000001:
		paint.set_shader_parameter("art_mask_x",Vector3(0,0,-1))
		paint.set_shader_parameter("art_mask_y",Vector3(0,0,-1))
		return
	var mapping: Transform2D=mask_transform.affine_inverse()*visual.get_global_transform()
	var origin: Vector2=mapping.origin-rect.position
	paint.set_shader_parameter("art_mask_x",Vector3(mapping.x.x*visual.size.x/rect.size.x,mapping.y.x*visual.size.y/rect.size.x,origin.x/rect.size.x))
	paint.set_shader_parameter("art_mask_y",Vector3(mapping.x.y*visual.size.x/rect.size.y,mapping.y.y*visual.size.y/rect.size.y,origin.y/rect.size.y))
