# Pixy
Processing, 2017

Pixy is an evolutionary generative system for exploring visual space of mathematical functions through guided selection.

Pixy builds graphs of mathematical expressions with image **xy** coordinates as inputs, and **rgb** color as output. Initial graphs are constructed randomly, and mutated and combined through user selection.

## Functions and probabilities

The current setup in [genes.pde](pixy/genes.pde) chooses a function group first, then a function within that group. The rates are relative weights: the percentages below are normalized and rounded. Function percentages are conditional on choosing their group, not percentages of all nodes.

| Group | Group weight | Group probability | Functions and probability within the group |
| --- | ---: | ---: | --- |
| Basic Math | 1 | 64.10% | `add`, `sub`, `mult`, `div`: 25% each |
| Exponential | 0.01 | 0.64% | `pow2`, `sqrt`: 31.25% each; `powOf`, `logOf`, `2pow`, `2log`: 9.38% each |
| Round | 0.1 | 6.41% | `mod`: 11.11%; `fract`, `floor`, `ceil`, `round`: 22.22% each |
| Trigonometry | 0.1 | 6.41% | `sin`, `cos`: 35.71% each; `tan`, `asin`, `acos`: 3.57% each; `atan`: 17.86% |
| Constrain | 0.1 | 6.41% | `min`, `max`, `abs`: 28.57% each; `clamp`: 14.29% |
| Mix | 0.1 | 6.41% | `mix` (linear interpolation): 100% |
| Logic | 0.1 | 6.41% | `if`, `and`, `or`, `xor` (comparison-based branches): 25% each |
| Else: color and noise | 0.05 | 3.21% | `hsb2rgb`, `combine`, `setH`, `setS`, `setV`, `noise2`: 16.67% each |

Functions work on three-channel values. The color group converts HSB to RGB, combines three inputs into RGB channels, replaces hue/saturation/value, or generates 2D noise. In the archived shader, `pow2` squares its input, `sqrt` takes the square root of its absolute value, `powOf(a,b)` computes `a^abs(b)`, `logOf(a,b)` computes `log(a)/log(b)`, `2pow(a)` computes `2^a`, and `2log(a)` computes `log(2)/log(a)`.

Leaf values are selected separately:

| Value | Meaning | Weight | Probability among leaves |
| --- | --- | ---: | ---: |
| `x` | Horizontal image coordinate | 1 | 33.33% |
| `y` | Vertical image coordinate | 1 | 33.33% |
| `rndm` | One random value shared by all three channels | 0.5 | 16.67% |
| `rndm3` | A shared random base with independent Gaussian variation per channel | 0.5 | 16.67% |

The choice between a function and a leaf depends on tree depth and DNA complexity, so these tables do not predict the final node distribution after evolution. For example, `add` has a 64.10% × 25% ≈ 16.03% chance when selecting a function. The picker retries up to 100 times at each stage, then falls back to `rndm`; these negligible fallback probabilities are omitted. Unused trailing entries in the rate arrays are also excluded.

![Pixy interface with generated images and controls](screenshot.png)

[Gallery on Behance](https://www.behance.net/gallery/69729037/Pixy)

## Run

Open `pixy/pixy.pde` in Processing's Java mode and click **Run**. ControlP5 2.2.6 is bundled in `pixy/code/`; no separate library installation is needed.

Originally written for Processing 3. The current sketch has been checked with Processing 4.5.6 on macOS.

## Usage

- Click **New** to generate a new random population.
- Click on an image to open it. Drag or use the arrow keys to pan; use **a / z** to zoom. The graph view shows current expression. Click **Back** to return to the grid.
- To control population size, use **+ / −** under **Num**.
- To adjust image smoothness, use **+ / −** under **AA**.
- Open the image you want to save, set the output size with **RES**, then click **Save Image**. JPEGs use unique names such as `pixy123456.jpg`, preserving existing images.
- Use the bottom playback controls to animate; the upper time slider sets the loop duration. **Save Video** renders one loop at 60 fps. If FFmpeg is available, it creates an H.264 MOV such as `pixy123456.mov` and removes the intermediate JPEG frames after successful encoding. Otherwise, or if encoding fails, the frames stay in the matching `pixy123456/` folder as `frame00000.jpg`, `frame00001.jpg`, etc. Stopping a render also keeps its frames.

FFmpeg is optional and is detected on `PATH` or in standard Homebrew/MacPorts locations on macOS. Export progress and output paths are printed in Processing's console. Odd output dimensions are padded by one pixel for H.264 compatibility.

All exports go into `../outputs/` relative to the sketch folder: `outputs/` beside `pixy/` in this repository. Images, movies, and retained frame folders share this directory; each export reserves an unused six-digit `pixyXXXXXX` name.

## Source

`pixy.pde` starts the sketch; `app.pde` handles the interface. `dna.pde` and `genes.pde` define expressions and evolution, `pop.pde` manages the population, `artwork.pde` renders images, and `nodedisplay.pde` displays expression trees. Shaders and assets are in `data/`.

## License

Pixy: [MIT](LICENSE). Bundled ControlP5: [LGPL 2.1 or later](pixy/third-party/controlP5/LICENSE.md), by Andreas Schlegel. Its [source archive and attribution](pixy/third-party/controlP5/README.md) are included.
