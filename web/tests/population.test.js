import test from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULTS } from '../src/nodes.js';
import { createPopulation, developPopulation, resizePopulation, planPopulation, planDevelopment, planResize } from '../src/population.js';

test('25 images start without a parent; developing requires choosing one', () => {
  const population = createPopulation(5, DEFAULTS);
  assert.equal(population.items.length, 25);
  assert.equal(population.selected, -1);
  assert.equal(developPopulation(population, DEFAULTS), population);
});
test('develop retains exactly the chosen parent and independently mutates its children', () => {
  const population = createPopulation(5, DEFAULTS);
  population.selected = 12;
  const parent = population.items[12];
  parent.offset = [.2, -.3]; parent.scale = .8;
  const before = structuredClone(population);
  const next = developPopulation(population, { ...DEFAULTS, mutation: 0 });
  assert.equal(next.items[12], parent);
  assert.equal(next.selected, 12);
  for (let i = 0; i < next.items.length; i++) {
    assert.deepEqual(next.items[i].graph, parent.graph, 'only the chosen parent supplies offspring');
    assert.deepEqual(next.items[i].offset, parent.offset);
    assert.equal(next.items[i].scale, parent.scale);
    if (i !== 12) {
      assert.notEqual(next.items[i].graph, parent.graph);
      assert.notEqual(next.items[i].offset, parent.offset);
    }
  }
  assert.deepEqual(population, before, 'the previous generation remains intact');
});
test('developing another image uses only that new parent', () => {
  let population = createPopulation(3, DEFAULTS);
  population.selected = 4;
  population = developPopulation(population, DEFAULTS);
  const parent = population.items[8];
  population.selected = 8;
  const next = developPopulation(population, { ...DEFAULTS, mutation: 0 });
  assert.equal(next.items[8], parent);
  assert.equal(next.selected, 8);
  assert.ok(next.items.every(item => JSON.stringify(item.graph) === JSON.stringify(parent.graph)));
});
test('resizing preserves surviving images and safely handles removed selection', () => {
  let population = createPopulation(5, DEFAULTS);
  population.selected = 24;
  population = developPopulation(population, DEFAULTS);
  const small = resizePopulation(population, 2, DEFAULTS);
  assert.equal(small.items.length, 4);
  assert.equal(small.selected, -1);
  small.items.forEach((item, i) => assert.equal(item, population.items[i]));
  const large = resizePopulation(small, 6, DEFAULTS);
  assert.equal(large.items.length, 36);
  assert.equal(large.items[3], population.items[3]);
});

test('deferred creation builds only the requested image and snapshots settings', () => {
  let calls = 0;
  const settings = { ...DEFAULTS, probabilities: { ...DEFAULTS.probabilities } };
  const plan = planPopulation(5, settings, () => { calls++; return .5; });
  assert.equal(calls, 0);
  assert.ok(plan.population.items.every(item => item.graph === null));
  settings.probabilities.colrnd = 0;
  settings.depth = 32;
  const graph = plan.graphAt(3);
  const afterFirst = calls;
  assert.equal(plan.population.items.filter(item => item.graph).length, 1);
  assert.equal(plan.graphAt(3), graph);
  assert.equal(calls, afterFirst, 'a ready graph is never regenerated');
  const reference = planPopulation(5, DEFAULTS, () => .5).graphAt(3);
  const omitIds = (key, value) => key === 'id' || key === 'target' ? undefined : value;
  assert.equal(JSON.stringify(graph, omitIds), JSON.stringify(reference, omitIds));
});

test('deferred development and resize keep retained graphs ready immediately', () => {
  const population = createPopulation(2, DEFAULTS);
  population.selected = 2;
  let calls = 0;
  const plan = planDevelopment(population, { ...DEFAULTS, mutation: 0 }, () => { calls++; return .5; });
  const parent = population.items[2];
  assert.equal(calls, 0);
  assert.equal(plan.population.items[2], parent);
  assert.equal(plan.graphAt(2), parent.graph);
  assert.equal(calls, 0);
  assert.equal(plan.population.items.filter(item => item.graph).length, 1);
  assert.deepEqual(plan.graphAt(0), parent.graph);
  assert.equal(plan.population.items[1].graph, null);
  const resized = planResize(population, 3, DEFAULTS, () => { calls++; return .5; });
  assert.equal(calls, 0);
  population.items.forEach((item, index) => assert.equal(resized.population.items[index], item));
  assert.equal(resized.population.items[4].graph, null);
  assert.ok(resized.graphAt(4));
  assert.equal(resized.population.items[5].graph, null);
});
