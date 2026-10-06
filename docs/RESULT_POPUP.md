# Original-style result popup

Apply zombie_result_popup.patch after zombie_modal_input_text_shadow_fix.patch.

Results are now a standalone ResultPopup, with the same MetalPopup base as
ItemPopup. The base reuses the existing item metal texture and the existing
header manifest; no raster assets or text-in-image layers are added.

The result metal body is bounded inside the authored 800x480 stage, behind the
existing red outcome band and translucent narrative panel. It no longer fills
the viewport. The header, story, loss/endings counter and restart/menu/next
buttons retain their existing Flash coordinates. Narrative fitting measures
both available dimensions and font size consistently in the 2x UI space.
All captions keep ShaderText's corrected shader shadow.

Main preserves the current scene below a 90% shade, hides its pause tab and
tracks the result as a modal. The graph can set background_art to override the
backdrop. Quest's compatible popup_origin save field also records results;
loading a result reconstructs the previous scene. Rendering does not change
statistics or award an ending again.

ResultPopup.configure takes result data, statistics, ending count and whether
another episode exists. It emits restart_requested, menu_requested and
next_episode_requested; Main owns routing. Next episode is available only for
successful outcomes with a following episode.

Validation: result_ui_test covers all Episode I outcomes at three viewport
sizes and safe insets; result_popup_test checks standalone rendering, shared
resources, preserved backdrop, saved origin and routing. Existing item, modal
input, shared-menu and Episode II route tests cover surrounding behavior.
