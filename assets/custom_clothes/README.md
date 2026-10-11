# Custom clothing source assets

Generated with the built-in image_gen tool. Transparent PNG source artwork;
each sheet contains front, back, right and left views.

The character catalog links this artwork through `design_source`. The runtime
adapts the designs to 32px pose masks in `CharacterClothingStyler`, rather than
resizing the large illustrations onto every animation frame. Select
"Kaus Garis Lengan" or "Tracktop Garis" under Baju and "Baggy Jeans" under
Celana. Clothing is composed before hair, accessories and tools. The original
animation frame counts, speeds and tool hit timing are retained. Sleep uses
the original unclothed sleep pose because the source pack has no sleep
clothing mask. Celana "Bawaan Baju" preserves old save behavior.

## Prompt set

- striped_shirt.png: Pixel art clothing only; white sports T-shirt, black round
  collar and sleeve cuffs, three parallel black shoulder and sleeve stripes.
  Four evenly spaced views; transparent background; no text or logo.
- striped_tracktop.png: Pixel art clothing only; black zip-up tracktop, high
  collar, ribbed cuffs and waistband, three white shoulder and sleeve stripes.
  Four evenly spaced views; transparent background; no text or logo.
- baggy_jeans.png: Pixel art clothing only; dark indigo washed baggy jeans,
  wide loose legs, pooled hems, belt loops, pockets, button and denim seams.
  Four evenly spaced views; transparent background; no shoes, text or logo.
