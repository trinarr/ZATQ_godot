# Opening door hit region

The transport screen drew a 182x349 red door highlight at (22,20), but Main
used a 92x99 rectangular hotspot at (20,18). Most of the highlighted door
was therefore not clickable. The world/background transform was already shared;
the remaining defect was local hotspot geometry.

The door now derives both rect and mask from its existing component record
But1/Symbol2853. InteractiveHighlight accepts region IDs as masks as well as
legacy mask aliases, so no extra bitmap or duplicate contour is added.
The same geometry works before and after collecting the keys.

opening_door_hit_test checks real clicks at the top, middle and bottom of the
silhouette, both key states, wide and standard viewports and safe insets.
Apply zombie_opening_door_hit.patch after zombie_result_popup.patch.
