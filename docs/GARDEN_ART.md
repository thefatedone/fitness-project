# Botanical garden art — production resources

The built-in **image_gen** tool generated the artwork for this redesign. These
are real bundled Flutter resources, not screenshots of a proposed interface.
No API keys or image-generation calls are required by the running application.

## Files consumed by the app

All resources are under `flutter_app/assets/garden/` and are registered in
`flutter_app/pubspec.yaml`:

- `seed.webp` — seed, stage 0;
- `root.webp` — first root, stage 1;
- `sprout.webp` — seedling, stage 2;
- `leaves.webp` — young plant, stage 3;
- `tree.webp` — mature tree, stage 4;
- `landscape.webp` — atmospheric mountain and lake background;
- `pot.webp` — weekly cosmetic reward artwork.

Original tool outputs remain in the Codex generated-images directory. Delivery
assets were encoded as WebP with Sharp (quality 88, alpha quality 100, effort 6),
preserving transparency. The production bundle is approximately 2.5 MB. Flutter
bounds decoded image sizes for the hero and thumbnails. The scene uses separate
background and plant layers, a theme-aware surface fade and subtle floating motion.
Reduce Motion freezes movement. The reward pot is shown in its own reward panel.

## Final generation prompt set

The five stage images used the following shared prompt, with the stage description
substituted as listed below:

> Use case: stylized-concept. Asset type: production botanical illustration PNG
> for a premium iOS nutrition app, NOT an app mockup. Single isolated
> three-dimensional miniature floating garden island with [STAGE DESCRIPTION].
> Art direction: exquisite believable botanical 3D rendering blended with high-end
> macro product photography, tactile organic materials, real leaf veins and warm
> moss, delicate white wildflowers, two small smooth stones, rounded chunk of earth
> with visible roots underneath, organic oval mound, no container or pot. The same
> scene in every series asset: camera front three-quarter at a slight downward
> angle, warm soft sunrise key light from upper right, neutral bounce, natural muted
> sage greens, warm brown soil. Island centered horizontally at 73% of the canvas
> height; island width approximately 62% of canvas; entire plant and complete island
> fully within frame with comfortable 8% margins; square composition 1024x1024.
> All five growth stages will be superimposed at exactly the same scale and island
> baseline; preserve the same moss island size regardless of plant height.
> Invisible ground, fully transparent background, clean alpha edges, no background
> scenery or ground plane, no typography, no labels, no UI, no borders, no watermarks.
> Premium polished cinematic detail, calm and sophisticated, never cartoonish,
> never flat vector. Stage name for internal identification only: [STAGE NAME].

Stage descriptions:

- **seed:** a single large avocado pit nestled in the center of the moss, partly
  buried, natural crack in its brown skin; no stem and no leaves
- **root:** a cracking avocado pit in the moss with a small fresh pale-green shoot
  emerging only 5 cm, no opened leaves, a delicate visible ivory root curling near
  the pit
- **sprout:** a small avocado seedling emerging from its visible pit, thin natural
  stem, exactly two pairs of glossy oval leaves, delicate dew drops
- **leaves:** a healthy young avocado plant growing from a visible pit, naturally
  branching stem, eight rich glossy leaves arranged organically with different
  angles, dew drops and translucency
- **tree:** a beautiful compact mature avocado tree with a woody trunk and clearly
  branched broad rounded canopy, many lush glossy leaves, two small avocados partly
  hidden among the foliage; tree substantially larger and fuller than a seedling

Landscape prompt:

> Use case: stylized-concept. Asset type: landscape background texture for a premium
> iOS botanical garden interface. Landscape 3:2 image, no UI or text. Calm cinematic
> photographic alpine garden valley in early morning: distant layered sage-blue
> mountain ridges, soft conifer forests and a tiny hint of still lake, creamy pale
> sky in upper half with gentle warm sunrise light from upper right, atmospheric
> haze, blurred very subtle foliage in extreme lower corners. Composition must
> leave the entire center empty for a floating avocado plant illustration to be
> composited later. Do NOT depict a plant, seed, tree in foreground, pot, island or
> central object. Low contrast premium tranquil natural colors, soft focus distance,
> realistic photographic lighting, muted sage green, ivory, pale sky blue and
> champagne gold. No human beings, no typography, no framing, no watermark, no
> buildings. Background should be beautiful but quiet enough for an interface,
> with a bright clean sky and soft organic scenery.

Pot prompt:

> Use case: product-mockup. Production transparent PNG game reward icon for a premium
> botanical iOS app. One small exquisite empty handmade warm ivory glazed ceramic
> flower pot, gently rounded bowl shape, wide rim with soft terracotta interior,
> tiny embossed leaf motif on its front, subtle beautiful ceramic texture, softly
> lit from upper right in warm morning light, realistic 3D product render matching
> photoreal miniature floating moss garden islands. Centered isolated object
> occupying 70% of square canvas, front three-quarter view from slightly above,
> no plant, no soil, no pedestal, no text, no background, no watermark. True
> transparent background and clean alpha edges.

## Integration and review

`AvocadoTree` renders the corresponding asset. `GardenScene` composes it with the
landscape; `GardenCard` provides the entry point. `GardenScreen` offers a clearly
labelled stage preview that never changes the server's earned progress. Selecting
a stage scrolls to the hero image. Returning to the actual plant clears preview.

The app must be fully stopped and launched again after pulling these changes,
because new assets were added to the bundle. A later code-only change can use
normal hot reload. Existing progress rules and backend data are unchanged.
