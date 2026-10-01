// Open /tests/browser.html with the local server for real GPU checks.
import { NODES, DEFAULTS } from '../src/nodes.js';
import { createGraph, evolveGraph, validateGraph } from '../src/graph.js';
import { Renderer } from '../src/renderer.js';
import { checkFeedback } from './feedback-browser.js';
const result = document.getElementById('result');
const canvas = document.getElementById('canvas');
let checks = 0, id = 100000;
const assert = (condition, message) => { if (!condition) throw new Error(message); checks++; };
function node(name, children = []) {
  const n = { id: id++, name, children };
  if (name === 'circle') n.radius = .5;
  if (name === 'colrnd') n.value = [1, 0, 0];
  if (name === 'rrnd') n.value = [.2];
  if (name === 'crnd') n.value = [.25];
  if (name === 'prnd') n.value = [.15, -.2];
  if (name === 'rimg') n.channel = 0;
  return n;
}
function minimum(type) {
  if (type === 'img') return node('sdfimg', [minimum('sdf'), minimum('col'), minimum('ramp')]);
  if (type === 'sdf') return node('circle', [minimum('pxy')]);
  return node({ pxy: 'pxy', pnt: 'prnd', col: 'colrnd', ramp: 'rrnd', cycle: 'crnd' }[type]);
}
function imageFor(n, type) {
  if (type === 'img') return n;
  if (type === 'pnt') return imageFor(node('pxaddp', [minimum('pxy'), n]), 'pxy');
  if (type === 'cycle') return imageFor(node('pxrot', [minimum('pxy'), n]), 'pxy');
  if (type === 'pxy') return imageFor(node('circle', [n]), 'sdf');
  return node('sdfimg', ['sdf', 'col', 'ramp'].map(t => t === type ? n : minimum(t)));
}
try {
  const response = await fetch('../src/nodes.glsl');
  const renderer = new Renderer(canvas, await response.text(), error => { throw error; }, () => {});
  const gl = renderer.gl;
  const view = { offset: [0, 0], scale: .5, phase: 0, aa: 1 };
  const pixel = (x, y) => {
    const data = new Uint8Array(4);
    gl.readPixels(Math.floor(canvas.width * x), Math.floor(canvas.height * y), 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, data);
    return [...data];
  };
  renderer.setGraph(minimum('img'));
  renderer.draw(view);
  assert(pixel(.5, .5)[0] === 255, 'Filled circle center is red');
  assert(pixel(.05, .05)[0] === 0, 'Outside the circle is black');
  const animated = node('sdfimg', [minimum('sdf'), node('colhsv', [node('ctime'), minimum('ramp'), minimum('ramp')]), minimum('ramp')]);
  renderer.setGraph(animated);
  renderer.draw(view);
  const before = pixel(.5, .5);
  renderer.draw({ ...view, phase: .8 });
  assert(JSON.stringify(pixel(.5, .5)) !== JSON.stringify(before), 'Time changes a time-dependent color');
  renderer.setGraph(minimum('img'));
  renderer.draw({ ...view, offset: [4, 0] });
  assert(pixel(.5, .5)[0] === 0, 'Panning moves the shape out of the center');
  renderer.draw({ ...view, scale: .1, aa: 4 });
  assert(pixel(.05, .05)[0] === 255, 'Zoom and 16-sample antialiasing render');
  checkFeedback(renderer, view, pixel, assert);
  for (const amount of [-1, 0, .25, .5, 1, 2]) {
    const a = minimum('img'), b = minimum('img'), ramp = minimum('ramp');
    b.children[1].value = [0, 0, 1];
    ramp.value = [amount];
    renderer.setGraph(node('imgmix', [a, b, ramp]));
    renderer.draw(view);
    const t = Math.min(1, Math.max(0, amount));
    const expected = [255 * (1 - t), 0, 255 * t];
    assert(pixel(.5, .5).slice(0, 3).every((value, i) => Math.abs(value - expected[i]) < 2),
      `Image mix blends red and blue correctly at ramp ${amount}`);
  }
  for (let channel = 0; channel < 3; channel++) {
    const source = minimum('img');
    source.children[1].value = [.2, .5, .8];
    const ramp = node('rimg', [source]);
    ramp.channel = channel;
    const saturation = minimum('ramp');
    saturation.value = [0];
    const gray = node('colhsv', [minimum('cycle'), saturation, ramp]);
    renderer.setGraph(imageFor(gray, 'col'));
    renderer.draw(view);
    const expected = [.2, .5, .8][channel] * 255;
    assert(pixel(.5, .5).slice(0, 3).every(value => Math.abs(value - expected) < 2),
      `Image-to-ramp extracts ${'RGB'[channel]} into a usable scalar`);
    renderer.draw({ ...view, phase: .7 });
    assert(pixel(.5, .5).slice(0, 3).every(value => Math.abs(value - expected) < 2),
      'The selected channel stays fixed during playback');
  }
  canvas.style.width = '160px';
  canvas.style.height = '80px';
  renderer.draw(view);
  assert(canvas.width === canvas.height * 2, 'Canvas resizing preserves the viewport aspect ratio');
  for (const definition of Object.values(NODES)) {
    if (definition.name === 'link') continue;
    const root = imageFor(node(definition.name, definition.inputs.map(minimum)), definition.output);
    renderer.setGraph(root);
    renderer.draw(view);
    assert(gl.getError() === gl.NO_ERROR, `${definition.name} compiles and renders`);
  }
  const shared = minimum('img');
  const link = { id: id++, name: 'link', valueType: 'img', target: shared.id, children: [] };
  renderer.setGraph(node('imgscreen', [shared, link]));
  renderer.draw(view);
  assert(gl.getError() === gl.NO_ERROR, 'Shared image links render');
  const red = minimum('img'), green = minimum('img');
  green.children[1].value = [0, 1, 0];
  renderer.setGraphs([red, green]);
  renderer.beginFrame();
  renderer.drawViewport(0, view, { x: 0, y: 0, width: 80, height: 80 });
  renderer.drawViewport(1, view, { x: 80, y: 0, width: 80, height: 80 });
  assert(pixel(.25, .5)[0] === 255, 'First population viewport renders at its own origin');
  assert(pixel(.75, .5)[1] === 255, 'Second population viewport renders at its own origin');
  assert(pixel(.51, .01)[0] === 0 && pixel(.51, .01)[1] === 0, 'Scissor prevents image overlap');
  const retainedProgram = renderer.entries[0].program;
  renderer.setGraphs([red, minimum('img')]);
  assert(renderer.entries[0].program === retainedProgram, 'Retained parents reuse compiled programs');
  const previousEntries = renderer.entries;
  let failed = false;
  try { renderer.setGraphs([minimum('img'), node('invalid')]); } catch { failed = true; }
  assert(failed && renderer.entries === previousEntries && gl.isProgram(retainedProgram), 'Failed compilation preserves the previous population');
  let compilations = 0;
  const startCompile = renderer.startCompile.bind(renderer);
  renderer.startCompile = graph => { compilations++; return startCompile(graph); };
  const ready = [], readyCounts = [], pixels = [];
  await renderer.setGraphsProgressively([red, green, minimum('img')], index => {
    if (index < 0) return;
    ready.push(index);
    readyCounts.push(renderer.entries.filter(Boolean).length);
    renderer.beginFrame();
    renderer.drawViewport(index, view, { x: 0, y: 0, width: 80, height: 80 });
    pixels[index] = pixel(.25, .5);
  });
  assert(compilations === 2, 'Each new image compiles once; the retained parent does not compile');
  assert(renderer.entries[0].program === retainedProgram, 'Progressive updates retain the parent program');
  assert(ready.length === 2 && ready.includes(1) && ready.includes(2) && JSON.stringify(readyCounts) === '[2,3]', 'Images become ready individually');
  assert(pixels[1][1] === 255 && pixels[2][0] === 255, 'Each completed image can render before the batch completes');
  for (let i = 0; i < 12; i++) {
    renderer.beginFrame();
    renderer.drawViewport(i % 3, view, { x: 0, y: 0, width: 40, height: 40 });
    renderer.drawViewport(i % 3, view, { x: 80, y: 0, width: 80, height: 80 });
  }
  assert(compilations === 2 && gl.getError() === gl.NO_ERROR, 'Switching grid and preview viewports never recompiles');
  const extension = renderer.parallel;
  renderer.parallel = null;
  const fallbackReady = [];
  await renderer.setGraphsProgressively([minimum('img'), minimum('img')], index => {
    if (index >= 0) fallbackReady.push(renderer.entries.filter(Boolean).length);
  });
  assert(JSON.stringify(fallbackReady) === '[1,2]' && !renderer.compiling, 'Without the parallel extension, images still appear individually');
  renderer.parallel = extension;
  failed = false;
  try { await renderer.setGraphsProgressively([minimum('img'), node('invalid'), minimum('img')]); }
  catch { failed = true; }
  assert(failed && renderer.entries[0] && !renderer.entries[1] && renderer.entries[2] && !renderer.compiling,
    'A failed image does not prevent later images from compiling');
  const pipelineEvents = [];
  const deferred = [0, 1, 2].map(index => () => {
    pipelineEvents.push(`generate ${index}`);
    return minimum('img');
  });
  await renderer.setGraphsProgressively(deferred, index => {
    if (index >= 0) pipelineEvents.push(`ready ${index}`);
  });
  assert([0, 1, 2].every(index => pipelineEvents.indexOf(`generate ${index}`) < pipelineEvents.indexOf(`ready ${index}`)),
    'Each deferred graph is generated before publishing its compiled image');
  assert(renderer.graphs.every(graph => typeof graph !== 'function'), 'Resolved graphs are kept for context recovery');
  for (let i = 0; i < 60; i++) {
    const settings = { ...DEFAULTS, depth: 3 + i % 14, width: 3 + i % 14, mutation: 1000 };
    const graph = evolveGraph(createGraph(settings), settings);
    validateGraph(graph, settings);
    renderer.setGraph(graph);
    renderer.draw({ ...view, phase: .4, aa: 1 + i % 4 });
    assert(gl.getError() === gl.NO_ERROR, `Random evolved graph ${i} renders`);
    if (i % 10 === 0) { result.textContent = `${checks} checks passed…`; await new Promise(requestAnimationFrame); }
  }
  result.textContent = `PASS: ${checks} checks. Every enabled node compiled and rendered. Pixel checks, animation, pan, zoom, antialiasing, resize, links, population viewports, progressive compilation, preview reuse, compilation failure recovery, and 60 randomized evolutions passed.`;
  document.title = 'PASS — Pixy renderer tests';
} catch (error) {
  result.textContent = `FAIL after ${checks} checks: ${error.stack}`;
  document.title = 'FAIL — Pixy renderer tests';
  console.error(error);
}
