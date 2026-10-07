# Episode I television controls

Apply zombie_tv_controls.patch after zombie_opening_door_hit.patch.

The television-off hotspot now uses layout_controls_tv's /Symbol2819
highlight record. Its 50x52.5 Flash-pixel rect and vector contour are shared
with the glow; the old 44x40 rect missed the lower and right portions.

The native channel caption moves from (218,290) to (218,66), inside the
television picture rather than over the foreground remote. It remains in
the same world coordinate space as the picture and keeps its localized
CH format, digital font and green color. No new art or masks are added.

TV controls tests exercise all seven channels at standard and wide viewport
sizes with safe insets, caption containment/visibility, actual lower-remote
clicks, television-off routing and channel-change caption updates.
