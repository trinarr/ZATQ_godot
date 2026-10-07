# Episode I blur cache

`blur_texture_cache.gd` prepares each sharp texture / sigma / angle combination
once using a separate SubViewport and `flash_blur_bake.gdshader`. Only one job
is rendered per frame. `episode_timeline.gd` queues the episode's eight variants
when the first scene is configured, so later reveals normally use ready targets.
Static components use the same cache.

Targets have half the source width and height (one quarter of the pixels).
Sharp textures keep their original resolution. After baking, the SubViewport
uses UPDATE_DISABLED and CLEAR_MODE_NEVER; its input TextureRect and material
are freed. The retained ViewportTexture holds the cached pixels. No GPU readback,
CPU blur or new PNG is required at runtime. Ready entries are reused until the
SceneTree exits. A pending entry uses the sharp source as a safe fallback.

`flash_color_transform.gdshader` only mixes the original and cached textures
with premultiplied alpha, then applies Flash tint/opacity. Nonblurred parts use
a single texture sample. Blur fading changes the mixture, not the blur radius.
The continuous wall reveal fade and pause/resume behaviour are preserved.

Tests:

- `episode1_blur_fade_test.gd`: 57 timing, pause, endpoint and sampler checks.
- `episode1_blur_cache_test.gd`: 18 graphics checks: one-shot completion,
  deduplication, cached pixels, released bake inputs, disabled updates, alpha
  fade and exact sharp endpoint. Run with a graphics renderer; dummy headless
  mode skips pixel checks and uses a sharp fallback.

Validated in Godot 4.6.1 Compatibility/OpenGL using Mesa software rendering.
Android frame times and device memory pressure have not been measured.
