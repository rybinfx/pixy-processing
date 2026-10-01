import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { NODES, DEFAULTS, normalizeSettings, terminals } from '../src/nodes.js';
import { createGraph, evolveGraph, compileGraph, validateGraph, walk, weightedPick } from '../src/graph.js';
function seeded(seed) {
  return () => {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
test('catalog matches Processing and default weights are quartered', () => {
  const original = JSON.parse(readFileSync(new URL('../../data/probability-defaults.json', import.meta.url)));
  const active = Object.entries(original.probabilities).filter(([, value]) => value > 0).map(([name]) => name).sort();
  assert.deepEqual(Object.keys(NODES).filter(name => !['feedback', 'rimg', 'imgmix'].includes(name)).sort(), active);
  for (const name of active) assert.equal(DEFAULTS.probabilities[name], original.probabilities[name] * .25);
});
test('random graphs and repeated mutations preserve types, limits, links, and parents', () => {
  for (let seed = 1; seed <= 100; seed++) {
    const rng = seeded(seed);
    let settings = normalizeSettings({ depth: 3 + seed % 14, width: 3 + seed % 11, mutation: seed % 3 === 0 ? 2000 : 100 });
    let root = createGraph(settings, rng);
    for (let generation = 0; generation < 25; generation++) {
      const before = JSON.stringify(root);
      const next = evolveGraph(root, settings, rng);
      assert.equal(JSON.stringify(root), before, 'mutation must not alter its input');
      validateGraph(next, settings);
      assert.match(compileGraph(next), /return node\d+;/);
      root = next;
      if (generation === 12) settings = normalizeSettings({ ...settings, depth: 3, width: 3 });
    }
  }
});
test('zero mutation keeps a graph unchanged when limits are unchanged', () => {
  const root = createGraph(DEFAULTS, seeded(8));
  assert.deepEqual(evolveGraph(root, { ...DEFAULTS, mutation: 0 }, seeded(9)), root);
});
test('all-zero and malformed settings recover to safe terminal producers', () => {
  const settings = normalizeSettings({ depth: NaN, width: -10, mutation: Infinity, probabilities: Object.fromEntries(Object.keys(NODES).map(n => [n, 0])) });
  assert.equal(settings.depth, 6);
  assert.equal(settings.width, 3);
  assert.equal(settings.mutation, 100);
  for (const type of ['pxy', 'pnt', 'ramp', 'cycle', 'sdf', 'col', 'img']) assert.ok(terminals(type).some(name => settings.probabilities[name] > 0));
  for (let i = 0; i < 100; i++) validateGraph(createGraph(settings, seeded(i)), settings);
});
test('zero-weight nodes are never chosen by weighted sampling', () => {
  const settings = normalizeSettings({ probabilities: { circle: 0, box: 1, ring: 0 } });
  const rng = seeded(1);
  for (let i = 0; i < 100; i++) assert.equal(weightedPick(['circle', 'box', 'ring'], settings, rng), 'box');
});
test('links compile their shared target once and reject cycles', () => {
  const root = { id: 1, name: 'imgscreen', children: [
    { id: 2, name: 'sdfimg', children: [
      { id: 3, name: 'circle', radius: .5, children: [{ id: 4, name: 'pxy', children: [] }] },
      { id: 5, name: 'colrnd', value: [1, .5, .2], children: [] },
      { id: 6, name: 'rrnd', value: [.2], children: [] },
    ] },
    { id: 7, name: 'link', valueType: 'img', target: 2, children: [] },
  ] };
  validateGraph(root, DEFAULTS);
  const code = compileGraph(root);
  assert.equal(code.match(/g_sdfimg\(/g).length, 1);
  assert.match(code, /g_imgscreen\(node2, node2\)/);
  root.children[1].target = 1;
  assert.throws(() => validateGraph(root, DEFAULTS), /Cyclic/);
  assert.throws(() => compileGraph(root), /Cyclic/);
});
test('long evolution with heavy link reuse survives deleted and copied targets', () => {
  const settings = normalizeSettings({ depth: 12, width: 12, mutation: 800, probabilities: { link: 1 } });
  const rng = seeded(998);
  let root = createGraph(settings, rng), links = 0;
  for (let i = 0; i < 500; i++) {
    root = evolveGraph(root, settings, rng);
    links += validateGraph(root, settings).links;
    compileGraph(root);
  }
  assert.ok(links > 100, 'exercise actual linked graphs');
});
test('point parameters are clamped while ramp and cycle values stay unrestricted', () => {
  const point = { id: 1, name: 'prnd', value: [-4, 7], children: [] };
  assert.match(compileGraph(point), /vec2\(-0\.500000000, 0\.500000000\)/);
  const ramp = { id: 2, name: 'rrnd', value: [-3.5], children: [] };
  assert.match(compileGraph(ramp), /-3\.50000000/);
});
test('maximum depth and width generate bounded compilable graphs', () => {
  for (let i = 0; i < 20; i++) {
    const settings = normalizeSettings({ depth: 32, width: 32 });
    const root = createGraph(settings, seeded(i));
    assert.ok(walk(root).length <= 1024);
    validateGraph(root, settings);
    compileGraph(root);
  }
});

test('feedback accepts coordinates and participates in generation without replacing image fallbacks', () => {
  assert.deepEqual(NODES.feedback.inputs, ['pxy']);
  assert.equal(NODES.feedback.output, 'img');
  assert.deepEqual(terminals('img'), ['sdfimg']);
  const graph = { id: 1, name: 'feedback', children: [{ id: 2, name: 'pxy', children: [] }] };
  validateGraph(graph, DEFAULTS);
  assert.match(compileGraph(graph), /g_feedback\(node2\)/);
  let found = false;
  const settings = normalizeSettings({ depth: 10, width: 10, probabilities: { feedback: 1 } });
  for (let seed = 0; seed < 100; seed++) {
    if (walk(createGraph(settings, seeded(seed))).some(({ node }) => node.name === 'feedback')) found = true;
  }
  assert.ok(found, 'feedback is available to the image branch selector');
});

test('image-to-ramp generates all RGB choices and preserves the channel in copies', () => {
  assert.deepEqual(NODES.rimg.inputs, ['img']);
  assert.equal(NODES.rimg.output, 'ramp');
  const settings = normalizeSettings({ depth: 14, width: 14, mutation: 0, probabilities: { rimg: 1 } });
  const channels = new Set();
  for (let seed = 0; seed < 100; seed++) {
    const root = createGraph(settings, seeded(seed));
    for (const { node } of walk(root)) if (node.name === 'rimg') {
      channels.add(node.channel);
      assert.match(compileGraph(root), new RegExp(`node${node.id} = node\\d+\\.${"rgb"[node.channel]};`));
    }
    assert.deepEqual(evolveGraph(root, settings, seeded(seed + 100)), root);
  }
  assert.deepEqual([...channels].sort(), [0, 1, 2]);
  assert.throws(() => compileGraph({ id: 1, name: 'rimg', channel: 3, children: [
    { id: 2, name: 'colrnd', value: [1, 0, 0], children: [] },
  ] }), /Invalid image channel/);
});
