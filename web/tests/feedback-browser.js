let id = 200000;
const n = (name, ...children) => ({ id: id++, name, children });
const scalar = value => ({ ...n('rrnd'), value: [value] });
const source = color => n('sdfimg', { ...n('circle', n('pxy')), radius: .5 }, { ...n('colrnd'), value: color }, scalar(0));
const accumulated = color => n('imgadd', source(color), n('feedback', n('pxy')));
const near = (a, b, tolerance = 2) => Math.abs(a - b) <= tolerance;
export function checkFeedback(renderer, view, pixel, assert) {
  const gl = renderer.gl;
  const sampler = n('feedback', n('pxy'));
  renderer.setGraph(sampler);
  renderer.draw(view);
  assert(pixel(.5, .5)[0] === 0 && pixel(.5, .5)[1] === 0, 'Feedback starts with a black previous frame');
  let history = renderer.entries[0].history;
  assert(history.targets.length === 2 && history.targets[0].texture !== history.targets[1].texture,
    'Feedback has separate read/write textures and framebuffers');
  // Seed a two-dimensional coordinate ramp in the previous texture to test UVs
  // independently of the same coordinate formula in the generated shader.
  const pixels = new Uint8Array(history.width * history.height * 4);
  for (let y = 0; y < history.height; y++) for (let x = 0; x < history.width; x++) {
    const i = (y * history.width + x) * 4;
    pixels[i] = Math.round(255 * x / (history.width - 1));
    pixels[i + 1] = Math.round(255 * y / (history.height - 1));
    pixels[i + 3] = 255;
  }
  gl.bindTexture(gl.TEXTURE_2D, history.targets[history.read].texture);
  gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, history.width, history.height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
  gl.bindTexture(gl.TEXTURE_2D, null);
  const initialRead = history.read;
  renderer.draw(view);
  assert(history.read !== initialRead, 'Feedback swaps the read/write framebuffer after drawing');
  for (const [x, y] of [[.1, .1], [.5, .5], [.9, .9], [.1, .9]]) {
    const sample = pixel(x, y);
    const expectedX = 255 * Math.floor(history.width * x) / (history.width - 1);
    const expectedY = 255 * Math.floor(history.height * y) / (history.height - 1);
    assert(near(sample[0], expectedX) && near(sample[1], expectedY), 'Position −1…1 maps to UV 0…1 without flipping Y');
  }
  // Doubling the coordinate scale samples beyond both edges and must clamp.
  renderer.entries[0].history.viewKey = JSON.stringify([view.offset, view.scale * 2, view.aa]);
  renderer.draw({ ...view, scale: view.scale * 2 });
  assert(pixel(.05, .05)[0] === 0 && pixel(.95, .95)[0] === 255, 'Out-of-range feedback UVs clamp to texture edges');

  const red = accumulated([.2, 0, 0]), green = accumulated([0, .3, 0]);
  renderer.setGraphs([red, green]);
  const width = renderer.canvas.getBoundingClientRect().width, height = renderer.canvas.getBoundingClientRect().height;
  const left = { x: 0, y: 0, width: width / 2, height }, right = { ...left, x: width / 2 };
  renderer.beginFrame();
  renderer.drawViewport(0, view, left);
  const redHistory = renderer.entries[0].history;
  renderer.drawViewport(0, view, { ...right, y: height / 4, height: height / 2 });
  assert(renderer.entries[0].history === redHistory && redHistory.height === renderer.canvas.height,
    'A differently sized preview reuses the grid targets without resizing or clearing history');
  assert(near(pixel(.25, .5)[0], 51) && near(pixel(.75, .5)[0], 51), 'Grid and preview display one feedback step, not two');
  renderer.beginFrame(); renderer.drawViewport(0, view, left); renderer.drawViewport(1, view, right);
  assert(near(pixel(.25, .5)[0], 102) && near(pixel(.75, .5)[1], 77) && pixel(.75, .5)[0] === 0,
    'Each image accumulates only its own previous frame');
  renderer.beginFrame({ advanceFeedback: false }); renderer.drawViewport(0, view, left);
  assert(near(pixel(.25, .5)[0], 102), 'Stopped redraws do not advance feedback');
  const parentProgram = renderer.entries[0].program;
  renderer.setGraphs([red, accumulated([0, 0, .1])]);
  assert(renderer.entries[0].history === redHistory && renderer.entries[0].program === parentProgram,
    'Retained parents preserve their feedback history and program');
  assert(!renderer.entries[1].history, 'New offspring start with independent empty history');
  renderer.beginFrame({ advanceFeedback: false }); renderer.drawViewport(0, view, { x: 0, y: 0, width, height });
  assert(near(pixel(.5, .5)[0], 51), 'Changing render-target size clears previous history');
  const oldTargets = renderer.entries[0].history.targets;
  renderer.resetFeedback();
  assert(oldTargets.every(target => !gl.isTexture(target.texture) && !gl.isFramebuffer(target.framebuffer)),
    'Reset frees both feedback targets');
  renderer.beginFrame({ advanceFeedback: false }); renderer.drawViewport(0, view, { x: 0, y: 0, width, height });
  assert(near(pixel(.5, .5)[0], 51), 'Reset restarts accumulation from black');
  const removedTargets = renderer.entries[0].history.targets;
  renderer.setGraph(source([1, 0, 0])); renderer.draw(view);
  assert(!renderer.entries[0].history && removedTargets.every(target => !gl.isTexture(target.texture)),
    'Replacing a graph frees its feedback textures; ordinary graphs allocate none');
  assert(gl.getError() === gl.NO_ERROR, 'Feedback sampling, swaps, and blits have no WebGL errors');
  renderer.setGraphs([sampler, source([1, 0, 0])]);
  const debugProgram = renderer.entries[0].program;
  renderer.beginFrame({ advanceFeedback: false, feedbackDebug: true });
  renderer.drawViewport(0, view, left);
  renderer.drawViewport(1, view, right);
  assert(pixel(.25, .5).slice(0, 3).join() === '0,255,0', 'Debug feedback is solid green even when stopped');
  assert(pixel(.75, .5).slice(0, 3).join() === '255,0,0', 'Debug leaves ordinary images unchanged');
  renderer.beginFrame({ advanceFeedback: false, feedbackDebug: false });
  renderer.drawViewport(0, view, left);
  assert(pixel(.25, .5).slice(0, 3).join() === '0,0,0', 'Disabling debug clears green history and restores normal sampling');
  assert(renderer.entries[0].program === debugProgram, 'Debug toggles reuse the compiled shader');
  const shiftedFeedback = n('feedback', n('pxsubp', n('pxy'), { ...n('prnd'), value: [.2, 0] }));
  renderer.setGraph(n('imgmix', source([.8, 0, 0]), shiftedFeedback, scalar(.5)));
  renderer.draw(view);
  assert(near(pixel(.5, .5)[0], 102) && pixel(.8, .5)[0] === 0,
    'Image mix seeds feedback from the source on the first frame');
  renderer.draw(view);
  assert(near(pixel(.5, .5)[0], 153) && near(pixel(.8, .5)[0], 51),
    'Image mix accumulates history and produces a translated trail outside the source');
  renderer.setGraphs([accumulated([.2, 0, 0]), accumulated([0, .3, 0])]);
  const thumbnail = { x: 0, y: height / 4, width: width / 4, height: height / 2 };
  renderer.beginFrame();
  renderer.drawViewport(0, view, right);
  const previewHistory = renderer.entries[0].history;
  renderer.drawViewport(0, view, thumbnail);
  assert(previewHistory.width === Math.round(renderer.canvas.width / 2) && previewHistory.height === renderer.canvas.height,
    'Feedback renders at the full preview resolution, not the thumbnail resolution');
  assert(near(pixel(.75, .5)[0], 51) && near(pixel(.125, .5)[0], 51),
    'Thumbnail downscales the preview without advancing feedback twice');
  renderer.beginFrame();
  renderer.drawViewport(0, view, right);
  renderer.drawViewport(0, view, thumbnail);
  renderer.drawViewport(1, view, { ...thumbnail, y: 0, height: height / 4 });
  const otherHistory = renderer.entries[1].history, previewProgram = renderer.entries[0].program;
  assert(renderer.entries[0].history === previewHistory && near(pixel(.75, .5)[0], 102),
    'Preview history keeps its resolution and accumulates across frames');
  renderer.resetFeedback(0);
  assert(renderer.entries[1].history === otherHistory && previewHistory.targets.every(target => !gl.isTexture(target.texture)),
    'Switching preview resets only the hovered image and releases its old targets');
  renderer.beginFrame({ advanceFeedback: false });
  renderer.drawViewport(0, view, right);
  renderer.drawViewport(0, view, thumbnail);
  assert(near(pixel(.75, .5)[0], 51) && renderer.entries[0].history.width === previewHistory.width && renderer.entries[0].program === previewProgram,
    'Preview resets immediately while stopped, at high resolution without recompiling');
}
