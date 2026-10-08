# Dynamic story highlights

Episode II: the stairs/lift arrows in `e2_main_1_controls`, the roof/hospital arrows
in `e2_hospital_16_controls`, and all four alpha hit masks share vector contours.
Original graph mask IDs and hit rectangles remain unchanged.

Episode III: `e3_opening_8`, `e3_opening_11`, `e3_john_6`, `e3_john_18`,
`e3_john_23`, `e3_john_28`, and `e3_kill_6` use the same InteractiveHighlight
component as Episode I and John. The twelve animated primitives and their
static fallback snapshots no longer require red PNGs. Native timeline matrices,
visibility, QTE windows and alpha tracks remain intact. Baked PNG peak opacity
is multiplied by timeline alpha; shader pulsing is disabled for authored tracks.
Contours rasterize once on first use and retain padding for soft edges.

The Episode I lift indicator also follows its original timeline using a contour.
Episode V's five Symbol 373 QTE instances share SoftVignette, a smooth capsule
gradient shader with no texture sampling or full-screen PNG. The gradient was
fitted to the source alpha (mean absolute alpha error <0.01); its old quantization
steps are intentionally smoothed. Authored position, tint and alpha still come
from EpisodeTimeline.

Run `python3 tools/build_episode23_highlights.py` and
`python3 tools/build_story_indicators.py` to migrate existing exports. Component
and animation builders call the relevant migration automatically. Both tools
are idempotent; PNGs and import sidecars are deleted only after checking references
in all episode component/animation manifests.

UI button plates, the pause tab and item popup decorations are outside this migration.
Episode IV's story highlights were already vector based. Episode VI was not present
in the audited checkout.

Validation: Episode I animation tests; Episode II/III component and animation tests;
Episode V tests; `tools/episode23_highlights_test.gd` covers original alpha, padding,
cache reuse, all four physical Episode II arrow clicks, and all five procedural QTE
instances. GPU captures cover both Episode II scenes and representative Episode III/V
QTEs using the Compatibility renderer.
