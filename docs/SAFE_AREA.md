# Adaptive landscape layout

The base viewport remains 1600 × 960. Flash coordinates remain 800 × 480
and are uniformly doubled by LandscapeStageLayout. Buttons, text, and
interaction regions keep the same uniform scale.

AdaptiveLandscapeCanvas fills the available safe rectangle with a background
using aspect cover. Menus use transparent foreground exports so an opaque
1600 × 960 frame does not create side bars on wider screens. City backgrounds
also fill the safe rectangle; controls retain their authored positions.
Background cropping is decorative and does not change the UI coordinate system.

The area outside the display safe rectangle is black. On Android and iOS the
physical safe rectangle is intersected with the current window, then mapped
into viewport coordinates. This avoids applying insets twice when the system
already restricts the window. Desktop uses the complete viewport. The root
window explicitly uses the expand stretch aspect at startup and uses a black
clear color, including projects with older local project.godot settings.

Tests: tools/safe_area_test.gd exercises safe rectangle mapping, aspect cover,
uniform UI scale, clipping, and four window sizes. Desktop captures additionally
exercise a 2048 × 920 window with simulated asymmetric safe insets. Actual
Android hardware was not available for this verification.

Rebuild transparent foreground assets with tools/build_adaptive_ui.py using
the original Flash ZIP. Generated assets are included, so rebuilding is optional.
