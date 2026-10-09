# Caption visibility and entrance alpha

Visibility and opacity are independent. Before its entrance, a Flash caption
is hidden, even if its current color transform has alpha 1. At the visibility
switch, alpha becomes zero; then the authored fade raises it to full opacity.

The previous patch incorrectly described this as an opaque prefix and replaced
its alpha with zero. All 78 affected tracks now retain prefix alpha 1 and
explicit `false` visibility. Caption records accept an optional fourth value:
`[text, matrix, color, visible]`. Three-value records remain visible by default.
The shared player applies visibility to the label and its narrative band;
the shadow inherits the label's visibility.

`normalize_caption_entrances.py` now marks only the hidden prefix, without
changing alpha. Both existing exporter hooks remain in place, so regeneration
preserves independent visibility. The helper is idempotent and leaves ordinary
fades, intentional flashes and QTE tracks unchanged.

The restoration covers Episode II 1, III 2, IV 15, V 33, VI 26 and John 1.
Episode I has no affected prefix. Authored fade frames, positions, colors,
anchors, outros, eye animations and John's character reveal stay unchanged.

Validation: five Python regressions and a catalog comparison across all 78
restored prefixes. 3153 isolated Godot runtime checks cover separate visibility and alpha,
showing at alpha zero, subsequent monotonic fading, and matching band visibility.
