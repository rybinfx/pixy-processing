# Pixy

Evolutionary shaders in Processing from 2017.

Pixy is an application which uses a genetic algorithm to generate imagery and animation under the guidance of a user.

![Pixy screenshot — a grid of generated samples with the selection and animation controls](screenshot.png)

[Gallery on Behance](https://www.behance.net/gallery/69729037/Pixy)

## How it works

Pixy renders visuals based on mathematical equations with variables for the x and y locations of a pixel. Equations are generated via a node system, where each node represents a simple mathematical expression (`sin`, `mult`, `mix`, `fract`, logic ops, HSB/RGB conversions, …). Each equation is compiled into GLSL code and injected into a fragment shader, so every image is rendered entirely on the GPU.

In the beginning of the generative process, nodes are constructed randomly for each sample image. The user then chooses samples, whose nodes mutate and merge, producing new images. The process is repeated until appealing results are discovered:

- **New** — generates a grid of random samples.
- **Develop** — creates the next generation by mutating your selected image(s). With multiple selections, each offspring copies and mutates one randomly chosen parent. Crossover is currently disabled.
- **Repeat** — re-rolls the current generation if you don't like the offspring.

Images can be zoomed and panned, animated over a loop, and exported as high-resolution stills (`export/`) or animation frame sequences (`renders/`).

The active graph types are `pxy` and `pnt` (GLSL `vec2`), `ramp`, `cycle`, and `sdf` (GLSL `float`), and separate `col` and `img` types (both GLSL `vec3`). Legacy `vec3` nodes and their `anycol` conversion remain in the code but are disabled and hidden from the probability page, including when loading older defaults. The graph output must be `img`. Its smallest complete branch is `sdfimg(shape(pxy()), colrnd(), rrnd())`, which needs depth 3 and width 3. Image blends require depth 4 and width 6 for two complete shape branches; random colors cannot serve as images.

Probability controls are grouped by output type, with values first and functions below a divider when both are present. Type colors are shared by group outlines, graph node boxes, and outgoing connections: cyan for `pxy`, blue for `pnt`, amber for `ramp`, coral for `cycle`, green for `sdf`, purple for `col`, orange for `img`, and pale gray for the separate `lnk` category.

`link` reuses an existing node's output of the required type, with no child branch of its own. New links choose randomly from compatible targets after the graph is assembled, excluding any target whose dependencies would create a cycle. The graph labels link nodes `LNK`, with solid boxes and solid output connections. Only the reference connection is dashed. All connections are drawn beneath opaque node boxes. Shared targets are evaluated once in the generated shader.

Links remember node identities, so moving a target or mutating its parameters keeps the connection. Copies of a whole graph keep links within the copy; duplicated branches remap references to their own copied nodes. Structural mutations that would create cycles are rejected. After all mutations, links whose targets were deleted choose another compatible, cycle-free target; if none exists, they become a minimal ordinary branch of the same type. Depth/width budgeting reserves room for this fallback. Link has its own `lnk` probability group with one default weight of 0.5. It can carry any active value type; each connection still matches the type required by its consumer. Terminating primitives remain available independently of links.

- `pxy() → pxy` returns the current coordinates, including pan, scale, and antialiasing offsets.
- `prnd() → pnt` samples X/Y independently in `[-0.5, 0.5]`, constant across pixels and frames. Its output stays in that range during mutation.
- `pxaddp(pxy, pnt) → pxy` and `pxsubp(pxy, pnt) → pxy` add/subtract a point offset from a coordinate field. Their point input can use `prnd()`.
- `pxaddpx(pxy, pxy) → pxy` and `pxsubpx(pxy, pxy) → pxy` add/subtract two coordinate fields component-wise.
- `rrnd() → ramp` starts randomly in 0–1. Ramp is a semantic type; values can leave that range during mutation without clamping.
- `rsdfsin(sdf) → ramp` returns `0.5 + 0.5 * sin(sdf * 2π)`: one sine period per distance unit, with output in 0–1. The input is not clamped, so the wave repeats for negative distances and distances above 1. Its default probability weight is 1.
- `rcsin(cycle) → ramp` returns `0.5 + 0.5 * sin(cycle * 2π)`, mapping each cycle to a sine wave in 0–1. The input is not clamped; 0 and 1 both return 0.5. Its default probability weight is 1.
- `rsq(cycle) → ramp` is a square wave: 1 in the first half of each cycle, 0 in the second half.
- `rtri(cycle) → ramp` is a triangle wave: 0 at phase 0, 1 at phase 0.5, and back to 0 at phase 1.
- `rup(cycle) → ramp` is a rising sawtooth: `fract(cycle)`, rising from 0 toward 1 before resetting to 0. These three oscillators repeat for all cycle values, including negative values, and each has default probability weight 1.
- `ravg(ramp, ramp) → ramp` returns `(a + b) / 2`, without clamping. Its default probability weight is 1.
- `rmix(ramp, ramp, ramp) → ramp` blends the first two inputs using the third, clamped to 0–1: 0 selects the first input, 1 selects the second, and 0.5 averages them. The first two inputs and output are not clamped. Its default probability weight is 1.
- `pxscale(pxy, ramp) → pxy` returns `pxy / ramp`, so positive ramp values directly scale the visible shape size. No clamping or zero guard is applied.
- `pxscaled(pxy, cycle, ramp) → pxy` scales visible shapes along the axis at `cycle * 2π`, about the origin, leaving the perpendicular component unchanged. The ramp is clamped to 0–1 and mapped to scale 0–2: 0.5 leaves the shape unchanged and 1 stretches it 2×. Zero scale is approximated by 0.000001 to avoid division by zero. Cycle 0 selects the horizontal axis, 0.125 diagonal, and 0.25 vertical. Its default probability weight is 1.
- `tilex(pxy, ramp) → pxy` and `tiley(pxy, ramp) → pxy` repeat along one axis, leaving the other unchanged. At the default scale and pan, fullscreen coordinates span `[-1, 1]` in X and `[-height/width, height/width]` in Y. Tiling maps those bounds to 0–1 before multiplying by the count, then maps each cell back to the same centered coordinate range.
- `tilexy(pxy, rampX, rampY) → pxy` repeats both axes with independent counts. Counts specify tiles across the default fullscreen view, aligned to its left/bottom edges. Pan, zoom, and upstream position transforms still affect the pattern.
- `tilerot(pxy, ramp) → pxy` folds coordinates into a sector centered on the positive X axis, producing rotational repetition while preserving distance from the origin. Count 1 leaves coordinates unchanged.
- All four tile nodes convert each ramp to an integer count with `floor(1 + 5 * clamp(ramp, 0, 1) + 0.5)`: 0 gives 1, 0.5 gives 4, and 1 gives 6. Their default probability weights are 1.
- `ctime() → cycle` supplies the animation phase; `crnd() → cycle` supplies a random phase initially in 0–1, constant during playback and mutable during evolution. Cycle represents a phase progressing forward or backward across the 1/0 seam, while ramp conventionally oscillates between endpoints. Neither type clamps its values.
- `pxrot(pxy, cycle) → pxy` rotates coordinates about the origin by `cycle * 2π`: 0.25 is a quarter turn, and 0 and 1 are equivalent. For example, `sdfimg(circle(pxsubp(pxrot(pxy(), ctime()), prnd())), colrnd(), rrnd())` can animate an offset circle; rotating a centered circle alone leaves its appearance unchanged.
- `cdfcyc(sdf) → cycle` interprets signed distance directly as a cycle phase, without clamping or wrapping. Its default probability weight is 1.
- `cadd(cycle, ramp) → cycle`, `csub(cycle, ramp) → cycle`, and `cmul(cycle, ramp) → cycle` return `cycle + ramp`, `cycle - ramp`, and `cycle * ramp` respectively. Inputs and results are unrestricted, without clamping or wrapping. Each has default probability weight 1.
- `circle(pxy) → sdf` computes `length(position) - radius`, with radius defaulting to 0.5.
- `box(pxy) → sdf` is a square with half-size 0.5 (width and height 1).
- `roundbox(pxy) → sdf` has the same outer size as `box`, with corner radius 0.1.
- `triangle(pxy) → sdf` is an upward-pointing equilateral triangle centered at its centroid, with circumradius 0.5.
- `hexagon(pxy) → sdf` is a regular hexagon with circumradius 0.5 and vertical left/right edges.
- `capsule(pxy) → sdf` is horizontal, with segment endpoints at X = ±0.25 and radius 0.25 (total width 1, height 0.5).
- `ring(pxy) → sdf` is an annulus with inner radius 0.3 and outer radius 0.5.
- `point(pxy) → sdf` returns `length(position)`, the nonnegative distance from the origin, useful for radial cycles.
- `linex(pxy) → sdf` returns X: signed distance to the vertical line at X = 0, with negative values to the left and positive values to the right.
- `liney(pxy) → sdf` returns Y: signed distance to the horizontal line at Y = 0, with negative values below and positive values above.
- `segment(pxy) → sdf` returns the nonnegative distance to a horizontal segment from `(-0.5, 0)` to `(0.5, 0)`.

All shape nodes take only a position input. Filled shapes return signed distance, negative inside and positive outside; zero-width `point` and `segment` have no interior and return nonnegative distance. Sizes are in coordinate units; use `pxscale`, `pxrot`, and the position-offset nodes to transform shapes. All shape nodes have default probability weight 1.

Every SDF field can feed `cdfcyc` directly, with one unit of its output representing one cycle and no clamping or wrapping. For example, `rcsin(cdfcyc(linex(pxy())))` creates linear waves, and `rcsin(cdfcyc(point(pxy())))` creates radial waves. `rsdfsin` produces the same waves directly from the field.

- `sunion(sdf, sdf)`, `sinter(sdf, sdf)`, and `ssub(sdf, sdf)` return SDF union, intersection, and subtraction. `ssub(a, b)` removes the second shape from the first.
- `smunion(sdf, sdf, ramp)`, `sminter(sdf, sdf, ramp)`, and `smsub(sdf, sdf, ramp)` are polynomial smooth versions. The third input is the blend width in distance units; it is used directly, without a range clamp or zero guard.
- `edge(sdf, ramp, ramp) → sdf` creates an outline centered on the input's zero contour. The second input is total width, clamped to 0–1. With smoothness 0, it returns `abs(sdf) - width/2`; otherwise it smoothly intersects `sdf - width/2` and `-sdf - width/2` using the same unrestricted blend width as `sminter`. Positive smoothing rounds the distance field's central crease and can narrow or erase a thin band; rendered opacity softness remains controlled by `sdfimg`. Its default probability weight is 1.
- `colrnd() → col` samples red, green, and blue independently in 0–1, constant across pixels and frames. It uses the existing random-argument mutation system.
- `colhsv(cycle, ramp, ramp) → col` converts hue, saturation, and value to RGB. Hue is scaled by 0.1 before wrapping, so ten input cycles make one full hue revolution (0 and 10 are red); saturation and value are clamped to 0–1. Saturation 0 produces gray, and value 0 produces black. Its default probability weight is 1.
- Image blend nodes take `(img, img) → img` and operate per RGB channel. Inputs are clamped to 0–1, and results stay in 0–1. Each has default probability weight 1:
  - `imgscreen(a, b)` returns `1 - (1 - a) * (1 - b)`.
  - `imgadd(a, b)` adds the colors, capped at 1.
  - `imgmult(a, b)` multiplies the colors.
  - `imgsub(a, b)` subtracts the second color from the first, floored at 0.
  - `imgoverlay(a, b)` uses the first color as the base: `2*a*b` where its channel is below 0.5, otherwise `1 - 2*(1-a)*(1-b)`.
  - `imgdiff(a, b)` returns `abs(a - b)`.
  - `imgdarken(a, b)` selects the smaller value per channel.
  - `imglighten(a, b)` selects the larger value per channel.
- `sdfimg(sdf, col, ramp) → img` uses its third input, `smooth`, to control the edge: 0 gives a hard boundary; positive values smooth from `-smooth / 2` to `smooth / 2`, so 1 spans -0.5 to 0.5. The supplied color fills the inside and fades to black outside. The ramp is unrestricted; negative values reverse the mask.

Demo defaults use depth 6, width 6, and mutation 100. Raw probability slider weights are `pxy=1`, `prnd=0.5`, `rrnd=1`, `pxaddp=0.4`, `pxsubp=0.5`, `pxaddpx=1`, `pxsubpx=1`, `pxscale=1`, `pxrot=1`, `ctime=1`, `crnd=1`, `circle=1`, `sdfimg=1`, and `colrnd=1`. Compositing weights are `sunion=0.7`, `sinter=0.35`, `ssub=0.5`, `smunion=0.7`, `sminter=0.35`, and `smsub=0.5`. Displayed percentages normalize the squared weights within each type and value/function family. Generation reserves room for complete image and shape branches and falls back to `sdfimg` or SDF primitives at depth/width limits; at least one terminating primitive remains enabled.

Active `col` producers are `colrnd()` and `colhsv(cycle, ramp, ramp)`. Their output supplies the second (fill-color) input of `sdfimg`. All eight blend nodes operate exclusively on `img`; image branches end in `sdfimg`, never directly in a `col` node. The legacy `anycol` conversion remains disabled. Saved probability keys for `sdfcol` and the former `col…` blend names migrate to `sdfimg` and `img…`.

Scroll to the bottom of the probability page and click **Save** to store all node probabilities, depth, width, and mutation settings as startup defaults. Settings are saved in `data/probability-defaults.json` and loaded before the first population is generated.

Click **Randomize** beside **Save** to assign new random weights in 0–1 across every active category, including links, and immediately generate a new grid of images. Required terminal nodes remain available. Depth, width, and mutation settings stay unchanged; click **Save** to make the randomized weights your startup defaults.

## Running

### Web version

Run `npm start --prefix web` and open [localhost:5173](http://localhost:5173). The standalone [web port](web/README.md) displays a population of images: hover to preview, click to develop variations from that image alone. It uses the original interface design with compact, unified controls. The original active nodes and a `feedback(pxy)` image node are included; population mixing, crossover, shortcuts, and export are omitted. No dependencies or build step are required.

### Processing version

Open the sketch in [Processing](https://processing.org/) (written for Processing 3) and run `pixy.pde`. Requires the ControlP5 library.

## Files

- `pixy.pde` — entry point, window setup
- `app.pde` — UI and application state
- `dna.pde` — DNA: gene tree, mutation, crossover, GLSL code generation
- `genes.pde` — the gene pool: available operations and their probabilities
- `pop.pde` — population of artworks
- `artwork.pde` — a single image: shader compilation and rendering
- `nodedisplay.pde` — gene tree visualization
