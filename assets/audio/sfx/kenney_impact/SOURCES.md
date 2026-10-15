# Kenney Impact Sounds 1.0

Source: https://kenney.nl/assets/impact-sounds

Original download: https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip

License: Creative Commons Zero (CC0 1.0). Original LICENSE.txt retained.

Footsteps use five variants each for grass, wood, concrete, carpet and snow.
Soft impacts provide a separate dirt/soil profile. Running uses faster cadence
and slightly firmer playback. Sounds require actual movement, so pushing into
a wall produces no steps.

Tool tiers use ten different CC0 material recordings as accents over the
original action feedback: wood, tin, light metal, bell, light plate, heavy
metal, light glass, soft impact, medium glass and heavy plate. Collecting an
upgrade adds a tier-dependent bell chord.

A String TileSet custom-data field `footstep_surface` overrides classification
with grass/dirt/wood/concrete/carpet/snow. Named floor overlays take priority;
atlas tile color and texture type distinguish mixed ground sheets. Results
are cached per texture and atlas coordinate.
