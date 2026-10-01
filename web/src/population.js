import { createGraph, evolveGraph } from './graph.js';
import { normalizeSettings } from './nodes.js';

const artwork = () => ({ graph: null, offset: [0, 0], scale: .5 });
// Allocate the cells and their views immediately, but build each graph on demand.
// Snapshot settings so edits during compilation apply to the next generation.
function plan(population, generate) {
  return {
    population,
    graphAt(index) {
      const item = population.items[index];
      return item.graph ??= generate();
    },
  };
}
export function planPopulation(rows, settings, rng = Math.random) {
  const snapshot = normalizeSettings(settings);
  return plan({ rows, items: Array.from({ length: rows * rows }, artwork), selected: -1 },
    () => createGraph(snapshot, rng));
}
export function planDevelopment(population, settings, rng = Math.random) {
  const parent = population.items[population.selected];
  if (!parent) return plan(population);
  const snapshot = normalizeSettings(settings);
  const items = population.items.map((_, index) => index === population.selected ? parent : {
    graph: null, offset: [...parent.offset], scale: parent.scale,
  });
  return plan({ ...population, items }, () => evolveGraph(parent.graph, snapshot, rng));
}
export function planResize(population, rows, settings, rng = Math.random) {
  const snapshot = normalizeSettings(settings);
  const items = population.items.slice(0, rows * rows);
  while (items.length < rows * rows) items.push(artwork());
  return plan({ ...population, rows, items, selected: population.selected < items.length ? population.selected : -1 },
    () => createGraph(snapshot, rng));
}
function complete(plan) {
  plan.population.items.forEach((_, index) => plan.graphAt(index));
  return plan.population;
}
export function createPopulation(rows, settings, rng = Math.random) {
  return complete(planPopulation(rows, settings, rng));
}
export function developPopulation(population, settings, rng = Math.random) {
  return complete(planDevelopment(population, settings, rng));
}
export function resizePopulation(population, rows, settings, rng = Math.random) {
  return complete(planResize(population, rows, settings, rng));
}
