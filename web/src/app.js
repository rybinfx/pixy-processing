import { TYPES, NODES, DEFAULTS, normalizeSettings, clamp } from './nodes.js';
import { walk } from './graph.js';
import { planPopulation, planDevelopment, planResize } from './population.js';
import { Renderer } from './renderer.js';
import { renderGraph } from './graph-view.js';

const $ = id => document.getElementById(id);
const storageKey = 'pixy.web.defaults.v1';
let settings = normalizeSettings(DEFAULTS);
try {
  const saved = localStorage.getItem(storageKey);
  if (saved) {
    const raw = JSON.parse(saved);
    const migrateWeights = raw.weightScaleVersion !== 2;
    if (migrateWeights) {
      const factor = raw.weightScaleVersion === 1 ? .5 : .25;
      raw.probabilities = Object.fromEntries(Object.entries(raw.probabilities ?? {}).map(([name, value]) =>
        [name, Number.isFinite(value) ? clamp(value, 0, 1) * factor : value]));
    }
    settings = normalizeSettings(raw);
    if (migrateWeights) localStorage.setItem(storageKey, JSON.stringify({ ...settings, weightScaleVersion: 2 }));
  }
} catch { /* Storage is optional. */ }
let population, gridRenderer, busy = true, dirty = true, hasTime = false;
let mode = 'weights', phase = 0, duration = 5, playing = false, aa = 1;
let feedbackDebug = false;
let tiles = [], previewIndex = -1;
function showError(error) {
  console.error(error);
  $('error-text').textContent = error.message;
  $('error').hidden = false;
}
function paintRange(input) {
  const progress = (Number(input.value) - Number(input.min)) / (Number(input.max) - Number(input.min)) * 100;
  input.style.setProperty('--fill', `${progress}%`);
}
function updateSettingsControls() {
  for (const key of ['mutation', 'depth', 'width']) {
    $(key).value = settings[key];
    $(`${key}-value`).textContent = settings[key];
    paintRange($(key));
  }
}
function updateButtons() {
  const unavailable = busy || gridRenderer?.lost || gridRenderer?.compiling;
  $('new').disabled = $('num').disabled = $('randomize-weights').disabled = unavailable;
  $('image-tab').disabled = $('graph-tab').disabled = previewIndex < 0;
  tiles.forEach((tile, i) => {
    const pending = !gridRenderer?.entries[i];
    tile.disabled = unavailable || pending;
    tile.classList.toggle('pending', pending);
    tile.setAttribute('aria-busy', String(pending));
    tile.classList.toggle('parent', i === population.selected);
  });
}
function syncPopulationControl() {
  if (!population) return;
  $('num').value = population.rows;
  $('count').textContent = population.items.length;
  $('num').setAttribute('aria-valuetext', `${population.items.length} images, ${population.rows} by ${population.rows}`);
  paintRange($('num'));
}
function showPanel(nextMode) {
  mode = nextMode;
  for (const key of ['image', 'graph', 'weights']) {
    $(`${key}-panel`).hidden = key !== mode;
    $(`${key}-tab`).setAttribute('aria-pressed', String(key === mode));
  }
  dirty = true;
}
function updatePreview() {
  const item = population.items[previewIndex];
  if (!item) { showPanel('weights'); return; }
  if (gridRenderer.entries[previewIndex]?.graph !== item.graph) return;
  renderGraph($('graph'), item.graph);
  $('scale').value = Math.log2(item.scale / .5);
  $('scale-value').textContent = Number($('scale').value).toFixed(2);
  paintRange($('scale'));
  dirty = true;
}
function previewImage(index) {
  if (!gridRenderer.entries[index] || gridRenderer.lost) return;
  if (index !== previewIndex) {
    previewIndex = index;
    gridRenderer.resetFeedback(index);
    try { updatePreview(); } catch (error) { if (error.name !== 'AbortError') showError(error); }
  }
  if (mode === 'weights') showPanel('image');
  updateButtons();
}
async function installPopulation({ population: next, graphAt }) {
  if (next.selected >= 0) previewIndex = next.selected;
  else if (next.items[previewIndex] !== population?.items[previewIndex]) previewIndex = -1;
  population = next;
  hasTime = next.items.some(item => item.graph && walk(item.graph).some(({ node }) => (node.name === 'ctime' || node.name === 'feedback')));
  $('population').style.setProperty('--rows', next.rows);
  tiles = next.items.map((_, index) => {
    const tile = document.createElement('button');
    tile.className = 'variation';
    tile.setAttribute('aria-label', `Develop image ${index + 1}`);
    tile.addEventListener('pointerenter', () => previewImage(index));
    tile.addEventListener('focus', () => previewImage(index));
    tile.addEventListener('click', () => changePopulation(() => planDevelopment({ ...population, selected: index }, settings)));
    return tile;
  });
  $('population').replaceChildren(...tiles);
  syncPopulationControl();
  $('error').hidden = true;
  const sources = next.items.map((item, index) => item.graph ?? (() => {
    const graph = graphAt(index);
    if (walk(graph).some(({ node }) => (node.name === 'ctime' || node.name === 'feedback'))) hasTime = true;
    return graph;
  }));
  await gridRenderer.setGraphsProgressively(sources, index => {
    dirty = true;
    updateButtons();
    if (index === previewIndex || index === -1) updatePreview();
  });
}
async function changePopulation(action) {
  if (busy || !gridRenderer || gridRenderer.lost || gridRenderer.compiling) return;
  busy = true; updateButtons();
  $('stage').setAttribute('aria-busy', 'true');
  await new Promise(resolve => requestAnimationFrame(() => setTimeout(resolve, 0)));
  try { await installPopulation(action()); }
  catch (error) { if (error.name !== 'AbortError') showError(error); }
  finally {
    busy = false; updateButtons(); syncPopulationControl();
    $('stage').setAttribute('aria-busy', 'false');
  }
}
function freshPopulation() {
  const next = planPopulation(population?.rows ?? 5, settings);
  next.population.items.forEach(item => { item.scale = .5 * 2 ** Number($('scale').value); });
  return next;
}
const probabilityFamilies = [];
function buildProbabilities() {
  for (const [type, info] of Object.entries(TYPES)) {
    const group = document.createElement('section');
    group.className = 'weight-group';
    group.style.setProperty('--type', info.color);
    const title = document.createElement('h3');
    title.textContent = type;
    group.append(title);
    const pool = Object.values(NODES).filter(n => n.output === type);
    for (const leaf of [true, false]) {
      const nodes = pool.filter(n => (n.inputs.length === 0) === leaf);
      if (!nodes.length) continue;
      const family = document.createElement('div');
      family.className = 'weight-family';
      probabilityFamilies.push(nodes.map(n => n.name));
      for (const node of nodes) {
        const row = document.createElement('div');
        row.className = 'weight-row';
        row.title = `${node.description}. (${node.inputs.join(', ')}) → ${node.output}`;
        const label = document.createElement('label');
        label.htmlFor = `weight-${node.name}`;
        label.append(document.createTextNode(node.name));
        const out = document.createElement('output');
        out.id = `prob-${node.name}`;
        out.htmlFor = `weight-${node.name}`;
        label.append(out);
        const input = document.createElement('input');
        Object.assign(input, { type: 'range', min: 0, max: 1, step: .0025, id: `weight-${node.name}` });
        input.addEventListener('input', () => {
          settings.probabilities[node.name] = Number(input.value);
          settings = normalizeSettings(settings);
          updateProbabilities();
        });
        row.append(label, input);
        family.append(row);
      }
      group.append(family);
    }
    $('probabilities').append(group);
  }
  updateProbabilities();
}
function updateProbabilities() {
  for (const names of probabilityFamilies) {
    const sum = names.reduce((n, name) => n + settings.probabilities[name] ** settings.probabilityExponent, 0);
    for (const name of names) {
      const input = $(`weight-${name}`), weight = settings.probabilities[name];
      input.value = weight;
      paintRange(input);
      const percent = sum > 0 ? 100 * weight ** settings.probabilityExponent / sum : 0;
      $(`prob-${name}`).textContent = `${Math.round(percent)}%`;
      input.setAttribute('aria-valuetext', `Weight ${weight.toFixed(2)}, ${Math.round(percent)} percent of this family`);
    }
  }
}
for (const key of ['mutation', 'depth', 'width']) {
  $(key).addEventListener('input', () => { settings[key] = Number($(key).value); updateSettingsControls(); });
}
$('new').addEventListener('click', () => changePopulation(freshPopulation));
$('num').addEventListener('input', () => {
  const rows = Number($('num').value);
  $('count').textContent = rows * rows;
  $('num').setAttribute('aria-valuetext', `${rows * rows} images, ${rows} by ${rows}`);
  paintRange($('num'));
});
$('num').addEventListener('change', () => {
  const rows = Number($('num').value);
  if (rows === population?.rows) return;
  changePopulation(() => {
    const next = planResize(population, rows, settings);
    next.population.items.slice(population.items.length).forEach(item => { item.scale = .5 * 2 ** Number($('scale').value); });
    return next;
  });
});
$('save-defaults').addEventListener('click', () => {
  try {
    localStorage.setItem(storageKey, JSON.stringify({ ...settings, weightScaleVersion: 2 }));
    $('save-defaults').textContent = 'saved';
    setTimeout(() => { $('save-defaults').textContent = 'save'; }, 1400);
  } catch { showError(new Error('Could not save defaults in this browser.')); }
});
$('randomize-weights').addEventListener('click', () => changePopulation(() => {
  settings.probabilities = Object.fromEntries(Object.keys(NODES).map(name => [name, Math.round(Math.random() * 100) / 100]));
  settings = normalizeSettings(settings);
  updateProbabilities();
  return freshPopulation();
}));
for (const name of ['image', 'graph', 'weights']) $(`${name}-tab`).addEventListener('click', () => showPanel(name));
$('scale').addEventListener('input', () => {
  const value = Number($('scale').value);
  population?.items.forEach(item => { item.scale = .5 * 2 ** value; });
  $('scale-value').textContent = value.toFixed(2);
  paintRange($('scale')); dirty = true;
});
$('aa').addEventListener('input', () => {
  aa = Number($('aa').value);
  $('aa-value').textContent = aa;
  paintRange($('aa')); dirty = true;
});
$('play-stop').addEventListener('click', () => {
  playing = !playing;
  $('play-stop').textContent = playing ? 'stop' : 'play';
  $('play-stop').setAttribute('aria-label', playing ? 'Stop' : 'Play');
  $('play-stop').setAttribute('aria-pressed', String(playing));
  if (!playing) { phase = 0; gridRenderer?.resetFeedback(); dirty = true; }
});
$('duration').addEventListener('input', () => {
  duration = Number($('duration').value);
  $('duration-value').textContent = `${duration.toFixed(1)}s`;
  paintRange($('duration'));
});
$('feedback-debug').addEventListener('click', () => {
  feedbackDebug = !feedbackDebug;
  $('feedback-debug').setAttribute('aria-pressed', String(feedbackDebug));
  dirty = true;
});
$('dismiss-error').addEventListener('click', () => { $('error').hidden = true; });

const preview = $('preview');
let pointer = null;
preview.addEventListener('pointerdown', event => {
  if (event.button !== 0 || pointer || busy || previewIndex < 0) return;
  pointer = { id: event.pointerId, x: event.clientX, y: event.clientY };
  preview.setPointerCapture(event.pointerId); preview.classList.add('dragging');
});
preview.addEventListener('pointermove', event => {
  if (!pointer || pointer.id !== event.pointerId || busy) return;
  const item = population.items[previewIndex], scale = 4 / preview.clientWidth;
  item.offset[0] -= (event.clientX - pointer.x) * scale;
  item.offset[1] += (event.clientY - pointer.y) * scale;
  pointer.x = event.clientX; pointer.y = event.clientY; dirty = true;
});
const releasePointer = () => { pointer = null; preview.classList.remove('dragging'); };
for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) preview.addEventListener(event, releasePointer);
preview.addEventListener('wheel', event => {
  event.preventDefault();
  const item = population?.items[previewIndex];
  if (!item || busy) return;
  const pixels = event.deltaY * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? preview.clientHeight : 1);
  item.scale = .5 * 2 ** clamp(Math.log2(item.scale / .5) + pixels * .003, -5, 5);
  $('scale').value = Math.log2(item.scale / .5);
  $('scale-value').textContent = Number($('scale').value).toFixed(2);
  paintRange($('scale')); dirty = true;
}, { passive: false });
const divider = $('divider');
let draggingDivider = false;
divider.addEventListener('pointerdown', event => {
  draggingDivider = true; divider.setPointerCapture(event.pointerId);
});
divider.addEventListener('pointermove', event => {
  if (!draggingDivider) return;
  const width = $('workspace').clientWidth;
  const value = clamp(event.clientX, 220, width - 350);
  document.documentElement.style.setProperty('--split', `${value}px`);
  dirty = true;
});
for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) divider.addEventListener(event, () => { draggingDivider = false; });
const observer = new ResizeObserver(() => { dirty = true; });
observer.observe($('population-canvas')); observer.observe($('stage')); observer.observe(preview);
window.addEventListener('scroll', () => { dirty = true; }, { capture: true, passive: true });
let lastTime = null;
document.addEventListener('visibilitychange', () => { lastTime = null; dirty = true; });
function frame(now) {
  const delta = lastTime === null ? 0 : Math.min(.1, (now - lastTime) / 1000);
  lastTime = now;
  if (!document.hidden && population && !gridRenderer.lost) {
    if (playing) {
      phase = (phase + delta / duration) % 1;
      if (hasTime) dirty = true;
    }
    if (dirty) {
      gridRenderer.beginFrame({ advanceFeedback: playing, feedbackDebug });
      const bounds = gridRenderer.bounds;
      // Render the preview first so feedback runs at preview resolution. Its
      // grid cell below reuses the same frame, downscaled to the thumbnail.
      if (mode === 'image' && previewIndex >= 0) {
        const rect = preview.getBoundingClientRect();
        gridRenderer.drawViewport(previewIndex, { ...population.items[previewIndex], phase, aa }, {
          x: rect.left - bounds.left, y: rect.top - bounds.top, width: rect.width, height: rect.height,
        });
      }
      tiles.forEach((tile, i) => {
        const rect = tile.getBoundingClientRect();
        gridRenderer.drawViewport(i, { ...population.items[i], phase, aa }, {
          x: rect.left - bounds.left + 1, y: rect.top - bounds.top + 1,
          width: rect.width - 2, height: rect.height - 2,
        });
      });
      dirty = false;
    }
  }
  requestAnimationFrame(frame);
}
updateSettingsControls(); buildProbabilities();
document.querySelectorAll('input[type="range"]').forEach(paintRange);
try {
  const response = await fetch(new URL('./nodes.glsl', import.meta.url));
  if (!response.ok) throw new Error(`Could not load node shaders (${response.status}).`);
  const library = await response.text();
  const restored = () => { dirty = true; updateButtons(); $('error').hidden = true; };
  gridRenderer = new Renderer($('population-canvas'), library, showError, restored);
  requestAnimationFrame(frame);
  await installPopulation(freshPopulation());
} catch (error) { if (error.name !== 'AbortError') showError(error); }
finally { if (gridRenderer) { busy = false; updateButtons(); } }
