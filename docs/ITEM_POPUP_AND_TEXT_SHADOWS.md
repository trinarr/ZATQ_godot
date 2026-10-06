# Item popup and shader text shadows

Apply `zombie_item_popup_text_shadows.patch` after `zombie_world_interaction_alignment.patch`.

Item and city_pickup scenes keep the existing screen and open the shared ItemPopup
as a tracked modal. The old dispatcher reset the screen and selected a city image
for Episode I keys. A nonempty `background_art` on the graph scene explicitly
selects a replacement backdrop. An omitted/empty field preserves the current view.
The obsolete assets/images/Fon1_1.png runtime fallback is removed; the opening
uses its existing exported component texture.

Quest saves `popup_origin` when entering a pickup. Resuming directly at a pickup
reconstructs that origin's backdrop. Old saves without the field remain valid;
for them the renderer finds an incoming scene edge. Existing Episode II/III
`background_art` settings retain priority.

Flash reference: AddItem / Symbol276, Symbol274, Symbol57 and TemnMov.as.
The missing static title is localized as `ui.item_popup.title`, with original
font, color and coordinates. The description uses the authored 593.95 x 27
bounds. TemnMov's shade is black at 0.9 opacity. The existing result-header face
is reused; only Bitmap56's missing 22-pixel shadow tail is exported separately.
`tools/build_item_popup_header.py LIBRARY` rebuilds the tail and header manifest.

All gameplay Labels are created as ShaderText, including button captions, QTE
and results. ShaderText renders a separate glyph pass behind the foreground
Label with `text_shadow.gdshader`. No baked text-shadow images are added.
The offset is one stage pixel on each axis. Glyph coverage is
softened by the shader; text, font, size, alignment, wrapping, justification,
language and opacity stay synchronized when changed. Ordinary theme shadows
are disabled. Editor/addon tooling labels remain outside the game UI.

Validation: item_popup_test covers the door background, persistence, old saves,
graph override, title, description, shader synchronization and acceptance.
shared_menus_test covers all pickup artwork across three episodes.
modal_buttons_test exercises mouse and touch blocking. world_alignment_test
and menu_animations_test cover the surrounding UI and world layout.
