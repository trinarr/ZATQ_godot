# Modal input and text-shadow correction

Apply after zombie_item_popup_text_shadows.patch.

Decision dialogs now default to 90% black shade, matching ItemPopup.
A graph-provided shade_alpha still overrides this default.

ShaderText's shadow Label receives its font, wrapping, justification and text
before its final geometry. Previously the initial unwrapped measurement could
clamp the shadow width, causing different line breaks and a seemingly enormous
shadow offset. Both passes now use identical final bounds. The offset is reduced
to one stage pixel on each axis; the shadow still uses text_shadow.gdshader.

Pause shade still resumes the game. Dismissable dialogs use the same helper.
It consumes the complete press/release
sequence, and emits resume only via a deferred call after release. Pressing no
longer tears down the input blocker during event propagation. Repeated touch
and synthesized mouse events cannot schedule a second resume.

Shared hotspots additionally check the active modal before dispatching their
action. A button under a visible modal cannot run its callback, including a
queued press that was started before the modal appeared. Actions belonging to
the top modal remain enabled.

modal_shadow_regression_test exercises the real door/key scene with mouse and
touch emulation, pause dismissal, queued hotspot actions, decision opacity,
justified paragraph wrapping at several widths and translated text.
