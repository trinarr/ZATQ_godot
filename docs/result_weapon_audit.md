# Result text and Episode II weapon visibility

Baseline: `fa74574bc479cb9770c71a457b9e5aa2bf00d51e`.

## Results

Compared all 113 result nodes from Episodes I–V with `ResultBad.as` in the
original `air.zombieapocalypsethequest-1006002.zip` archive. Flash uses
`ResultArr[iType - 1]`, including for surviving endings in `Summer()`.
There is no ID offset. The text beginning “Доброе утро, дивный новый мир”
belongs to result 96 in Flash, the first surviving ending of Episode IV.
It is an original epilogue, not text accidentally loaded from Episode V.
Result IDs, texts, ending aliases and statistics are retained.

`tools/result_ids_test.py` independently splits the source AS array at
top-level commas. Dynamic test-result expressions retain their array slots,
so results after those expressions are also checked without shifting IDs.

## Weapon

The evacuation-door display list included the unnamed `Symbol 2169`
hand/pistol layer regardless of weapon ownership. Added an unarmed variant
selected through the existing graph conditions when `BulletsNumber == -1`.
It applies to the door scene, both choice popups and the locked-door followup.
An owned pistol remains visible at zero ammunition. Shooting choices retain
their existing ammunition checks.

The unarmed variant uses the existing sharp door texture rather than the
preblurred background behind the gun. It preserves animation timing and caption
tracks. Export plans include variant artwork, omit the gun symbol and replace
Flash's `Bitmap 2165.png` with its sharp counterpart `Bitmap 2160.png`.
The armed scene, including an empty magazine, retains the original blurred art.
No new textures are needed; rebuilding from Flash preserves the fix.

## Validation

- 113 result IDs/texts match the original Flash array.
- Weapon visibility, background focus, animation and save/resume checks pass.
- 1419 Episode II route/UI checks pass, including all 17 results.
- 12003 Episode II/III animation checks pass.
- 19 shared result-popup checks pass.
- 5083 translation entries and references pass the locale audit.
- Sharp background rendered from the original XFL `Bitmap 2160.png`.

Tests ran with Godot 4.6.1 in headless mode. Device rendering was not tested.
The legacy `story_graph_test.gd` has 42 archive-versus-current-graph mismatches
on both the baseline and this patch. Its editor block-count assertions now
use the actual source graph size to accommodate the added conditions.

Apply the accompanying patch at the repository root:

```sh
git apply --check zombie_result_weapon_fix.patch
git apply zombie_result_weapon_fix.patch
```
