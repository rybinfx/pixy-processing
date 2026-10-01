# Pixy for the web

A standalone WebGL 2 port of the active Processing project, with its original dark layout, bundled font, rectangular controls, and purple accents. A 5×5 population previews images on hover and develops the clicked image as the sole parent. No mixing, crossover, keyboard shortcuts, or image/animation export.

## Run

From the repository root:

```sh
npm start --prefix web
```

Open http://localhost:5173. No installation or build step is needed. Requires Node.js 20+ for the local server/tests and a browser with WebGL 2. Use `PORT=8080 npm start --prefix web` to choose another port.

For static hosting, serve `web/` directly. JavaScript modules and the shader file must be served over HTTP; opening `index.html` as a local file will not work. The application has no runtime dependencies or CDN requests.

## Controls

- **Hover** an image to preview it on the right. Keyboard focus previews it too. Hovering does not select a parent or change the population; the preview remains available when you move to the controls.
- **Click** an image to develop it immediately: keep that parent in its cell and fill the other cells with independently mutated offspring. Offspring inherit its pan and scale. Click the retained parent again for another batch, or click an offspring to develop that image instead. There are no separate Develop or Repeat buttons.
- **New:** generate a fresh population and clear the parent.
- **NUM:** choose a square grid from 2×2 to 8×8. The displayed value is the image count; the grid updates when the slider is released. Surviving cells are preserved. **AA:** 1–4 samples per axis.
- **Scale:** adjust all images. Drag or scroll the preview to pan or zoom that image individually. Drag the divider to resize the two panels.
- **Depth / width / mut:** control new graphs and offspring. The retained parent is unchanged. Zero mutation produces exact copies (unless lower graph limits require pruning).
- **Image / graph / probabilities:** switch the right panel. Hovering updates the graph when its tab is active, or opens the image preview otherwise. Probabilities list the 57 original active nodes plus `feedback`, `rimg`, and `imgmix`, grouped by semantic output type, using squared weights as in Processing. Default raw weights are one quarter of the original values after two 50% reductions; saved weights are migrated once per reduction. Scaling every weight equally preserves relative selection percentages. At least one terminal for each type stays available.
- **Save:** store probabilities and evolution settings as this browser's startup defaults. **Randomize:** randomize probabilities and create a new population. Artworks are not persisted.
- **Loop:** animation loop length. **Play / stop:** toggle playback; stopping resets phase to zero. Playback starts stopped. Graphs containing `ctime` or `feedback` update while playing. Stop resets feedback history and phase. There are no phase or pause controls.

Random graphs can produce dark or uniform images, just as in Processing.

## Port details

The active `pxy`, `pnt`, `ramp`, `cycle`, `sdf`, `col`, `img`, and `link` nodes are included. Legacy generic-vector nodes and `anycol` are absent. Image-composition and ramp-interpolation nodes remain part of a single graph; there is no mixing of separate graphs.

The original shader formulas are retained, including unrestricted ramps/cycles, ten-cycle HSV hue, tiling, signed-distance operations, and negative edge softness. Random parameters become shader constants instead of occupying a fixed uniform array. Links retain identities, reject cycles, remap inside copied branches, and repair deleted targets; shared expressions are emitted once. The graph remains bounded by per-level width and structural depth, up to 32 each.

The grid and hover preview share one WebGL 2 context, with a separate viewport and scissor for each image. Each new graph compiles once; retained parents reuse their programs and hovering never compiles. Only the shader functions called by a graph, including their helper dependencies, are included. One shared vertex shader serves all images.

New images are generated and submitted in short batches, with up to eight shader compilations in flight. Each image is displayed when its own program is ready, without waiting for earlier images. Graph generation uses cached catalog metadata. Settings are captured when a generation starts, so later edits apply to the next generation. The renderer polls asynchronous completion once per frame where supported and yields between batches so the browser can paint. Without that extension, compilation falls back to one image per batch. The Performance panel’s Timings track includes population completion and per-image elapsed shader readiness; these include waiting and are not GPU execution timings. Pending cells start empty while the retained parent stays visible. A failed image does not prevent the remaining images from finishing. Lost graphics contexts are restored automatically.

Each image uses a fullscreen triangle. Supersampling is centered within each pixel. Non-finite final sample colors become black. The shared canvas follows the visible viewport, up to 2× display density and a 2400-pixel maximum backing dimension.

Small web-specific behavior changes: mutation strength also scales argument drift, zero mutation leaves parameters unchanged, animation uses elapsed time rather than frame count, and antialiasing is capped at 16 samples per pixel. Neither the Processing implementation nor its defaults file is modified by the web app.

## Image mix

`imgmix(img, img, ramp) → img` blends two images using a per-pixel ramp. Zero selects the first image, one selects the second, and 0.5 gives an equal blend. The ramp and input colors are clamped to 0…1, consistent with the other image operations. Its default weight is 0.25.

## Image channel to ramp

`rimg(img) → ramp` extracts one RGB channel from an image. Each new node picks R, G, or B with equal probability and keeps that choice during playback and when copied into offspring. Replacing the node can pick a new channel. The graph inspector shows `RIMG.R`, `RIMG.G`, or `RIMG.B`. The output is the channel value without extra clamping, usable anywhere a ramp is accepted, including coordinate transforms, color controls, and feedback graphs. Its default weight is 0.25. Compilation emits a direct component lookup with no additional shader function.

## Feedback

The **feedback debug** toggle replaces every feedback sample with solid green, including while stopped. The rest of each graph still processes that value, so composition or channel extraction may change or hide the green. Toggling resets feedback history without recompiling shaders; ordinary images are unaffected.

`feedback(pxy) → img` samples the same graph’s previous rendered frame. Its position is explicitly converted with `uv = position * 0.5 + 0.5`: `(-1, -1)` is the bottom-left corner, `(0, 0)` the center, and `(1, 1)` the top-right corner. Sampling is linear and clamps outside the texture edges. The position can come from the existing coordinate transforms, tiles, or typed links.

Each graph containing active feedback gets two RGBA8 texture/FBO targets at its preview render size when hovered, or its grid render size otherwise. One is sampled while the other receives the new image, then they swap. The hover preview renders first at full preview resolution, then its grid cell downscales that result; feedback steps only once per frame and hovering never recompiles the shader. Other population images have independent histories. Ordinary graphs still render directly without allocating these targets.

History begins black, so combine feedback with an image source (for example `imgscreen(sdfimg(...), feedback(pxscale(pxy, rrnd)))`) to seed a visible trail. Feedback is offered as an image operation with default weight 0.0875; it is not used as an obligatory terminal fallback. Press Play to advance it even when there is no `ctime` node. Stop clears history. New/mutated graphs, context recovery, render-size changes, and pan/scale/AA changes start fresh; a retained parent keeps its history. Removing a graph frees both targets. Switching to another preview resets that image’s history, including while stopped. Resizing its targets also resets history; the preview keeps full resolution on subsequent frames.

## Tests

```sh
npm test --prefix web
```

Tests compare the enabled catalog/defaults with Processing, exercise 3,000 mutation steps, enforce type/depth/width invariants, check parent immutability and zero mutation, and cover linked dependencies, cycles, terminal fallbacks, and maximum limits. Population tests verify single-parent offspring, parent retention, changing parents, and resizing.

With the server running, open http://localhost:5173/tests/browser.html for GPU checks. Feedback checks cover XY-to-UV mapping, frame swaps, black initialization, edge clamping, independent image histories, preview reuse, stop/reset, resize, and resource cleanup. The suite also compiles/renders every active node, checks actual pixels for shapes, time, pan, zoom and antialiasing, verifies canvas resizing and shared links, and renders 60 random evolved graphs. It also checks independent population viewports, program reuse, and rollback after failed compilation. It also verifies progressive completion, one compilation per new graph, previews without compilation, the synchronous fallback, and recovery after an individual image fails.

## Files

- `src/nodes.js`: enabled typed catalog and settings.
- `src/graph.js`: generation, mutation, links, validation, and GLSL emission.
- `src/nodes.glsl`: active shader formulas from the original project.
- `src/population.js`: single-parent generations and grid resizing.
- `src/shader-library.js`: includes only reachable GLSL functions and helpers.
- `src/feedback-targets.js`: per-image ping-pong framebuffer allocation and cleanup.
- `src/renderer.js`: WebGL program reuse, viewports, supersampling, and rendering.
- `src/graph-view.js`: SVG graph inspector.
- `src/app.js`: controls, playback, view, and browser defaults.
- `index.html`, `styles.css`, `assets/font.ttf`: original-style responsive interface and the original font.
- `server.js`: local static server, bound to loopback.

The repository's MIT license applies to this port.
