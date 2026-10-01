import { NODES, TYPES, minimumDepth, nodeDepth, terminals, branches, normalizeSettings, clamp } from './nodes.js';

let nextId = 1;
const randomPick = (items, rng) => items[Math.floor(rng() * items.length)];
const output = node => node.name === 'link' ? node.valueType : NODES[node.name].output;
export { output };
export function walk(root) {
  const result = [];
  function visit(node, depth, parent, index) {
    result.push({ node, depth, parent, index });
    node.children.forEach((child, i) => visit(child, depth + 1, node, i));
  }
  visit(root, 1, null, 0);
  return result;
}
export function weightedPick(names, settings, rng) {
  const weight = name => settings.probabilities[name] ** settings.probabilityExponent;
  const total = names.reduce((sum, name) => sum + weight(name), 0);
  if (total <= 0) return null;
  let remaining = rng() * total;
  for (const name of names) {
    remaining -= weight(name);
    if (remaining < 0) return name;
  }
  return names.findLast(name => weight(name) > 0);
}
function makeNode(name, rng, valueType) {
  const node = { id: nextId++, name, children: [] };
  if (name === 'link') Object.assign(node, { valueType, target: null });
  if (name === 'circle') node.radius = .5;
  if (name === 'prnd') node.value = [rng() - .5, rng() - .5];
  if (name === 'rrnd' || name === 'crnd') node.value = [rng()];
  if (name === 'colrnd') node.value = [rng(), rng(), rng()];
  if (name === 'rimg') node.channel = Math.floor(rng() * 3);
  return node;
}
function terminal(type, settings, rng) {
  const name = weightedPick(terminals(type), settings, rng) ?? terminals(type)[0];
  const node = makeNode(name, rng);
  node.children = NODES[name].inputs.map(t => terminal(t, settings, rng));
  return node;
}
function reserve(type, depth, widths, delta) {
  widths[depth] = (widths[depth] || 0) + delta;
  if (type === 'sdf') reserve('pxy', depth + 1, widths, delta);
  if (type === 'img') ['sdf', 'col', 'ramp'].forEach(t => reserve(t, depth + 1, widths, delta));
}
function reserveInputs(node, depth, widths) {
  // A link reserves space for a minimal branch if its target disappears.
  if (node.name === 'link') return;
  reserve(output(node), depth, widths, -1);
  widths[depth]++;
  NODES[node.name].inputs.forEach(t => reserve(t, depth + 1, widths, 1));
}
function fits(node, depth, widths, settings) {
  const needed = node.name === 'link' ? minimumDepth(output(node)) : nodeDepth(node.name);
  if (needed > settings.depth - depth + 1) return false;
  const proposed = widths.slice();
  reserveInputs(node, depth, proposed);
  return proposed.every((width, i) => width <= settings.width && (i <= settings.depth || width === 0));
}
function choose(type, leaf, remaining, existing, settings, rng, links = true) {
  let pool = leaf ? terminals(type) : branches(type);
  pool = pool.filter(name => nodeDepth(name) <= remaining);
  if (links && remaining >= minimumDepth(type) && existing.some(n => output(n) === type)) pool.push('link');
  const name = weightedPick(pool, settings, rng);
  return name ? makeNode(name, rng, type) : makeNode(weightedPick(terminals(type), settings, rng) ?? terminals(type)[0], rng);
}
export function createGraph(rawSettings, rng = Math.random) {
  const settings = normalizeSettings(rawSettings);
  const widths = Array(settings.depth + 3).fill(0);
  const existing = [];
  reserve('img', 1, widths, 1);
  function build(type, depth) {
    const functionChance = 1 - Math.max((depth - 1) / (settings.depth - 1), clamp(widths[depth + 1] / settings.width, 0, 1));
    let node = choose(type, rng() >= functionChance, settings.depth - depth + 1, existing, settings, rng);
    if (!fits(node, depth, widths, settings)) node = makeNode(weightedPick(terminals(type), settings, rng) ?? terminals(type)[0], rng);
    reserveInputs(node, depth, widths);
    existing.push(node);
    node.children = NODES[node.name].inputs.map(t => build(t, depth + 1));
    return node;
  }
  const root = build('img', 1);
  repairLinks(root, settings, rng);
  validateWithSettings(root, settings);
  return root;
}
function dependsOn(node, id, nodes, visited = new Set()) {
  if (node.id === id) return true;
  if (visited.has(node.id)) return false;
  visited.add(node.id);
  const dependencies = node.name === 'link' ? [nodes.get(node.target)].filter(Boolean) : node.children;
  return dependencies.some(child => dependsOn(child, id, nodes, visited));
}
function hasCycle(root) {
  const nodes = new Map(walk(root).map(({ node }) => [node.id, node]));
  const visiting = new Set(), visited = new Set();
  function visit(node) {
    if (visiting.has(node.id)) return true;
    if (visited.has(node.id)) return false;
    visiting.add(node.id);
    const dependencies = node.name === 'link' ? [nodes.get(node.target)].filter(Boolean) : node.children;
    if (dependencies.some(visit)) return true;
    visiting.delete(node.id);
    visited.add(node.id);
    return false;
  }
  return [...nodes.values()].some(visit);
}
function repairLinks(root, settings, rng) {
  // Each pass resolves one link or materializes a complete, non-link fallback.
  for (;;) {
    const nodes = new Map(walk(root).map(({ node }) => [node.id, node]));
    const link = [...nodes.values()].find(node => node.name === 'link' &&
      (!nodes.has(node.target) || output(nodes.get(node.target)) !== output(node)));
    if (!link) break;
    const candidates = [...nodes.values()].filter(node => output(node) === output(link) &&
      !(node.name === 'link' && !nodes.has(node.target)) && !dependsOn(node, link.id, nodes));
    if (candidates.length) link.target = randomPick(candidates, rng).id;
    else {
      const fallback = terminal(output(link), settings, rng);
      const id = link.id;
      for (const key of Object.keys(link)) delete link[key];
      Object.assign(link, fallback, { id });
    }
  }
}
function enforceLimits(root, settings, rng) {
  const widths = Array(settings.depth + 3).fill(0);
  reserve('img', 1, widths, 1);
  function cap(node, depth) {
    if (!fits(node, depth, widths, settings)) node = terminal(output(node), settings, rng);
    reserveInputs(node, depth, widths);
    node.children = node.children.map(child => cap(child, depth + 1));
    return node;
  }
  return cap(root, 1);
}
export function validateGraph(root, rawSettings) {
  return validateWithSettings(root, normalizeSettings(rawSettings));
}
function validateWithSettings(root, settings) {
  if (output(root) !== 'img') throw new Error('Graph output must be an image.');
  const entries = walk(root), nodes = new Map(), widths = [];
  for (const { node, depth } of entries) {
    if (!NODES[node.name]) throw new Error(`Unknown node: ${node.name}`);
    if (nodes.has(node.id)) throw new Error('Duplicate node identity.');
    nodes.set(node.id, node);
    widths[depth] = (widths[depth] || 0) + 1;
    if (depth > settings.depth || widths[depth] > settings.width) throw new Error('Graph exceeds depth or width limit.');
    const inputs = NODES[node.name].inputs;
    if (inputs.length !== node.children.length) throw new Error('Incorrect number of inputs.');
    inputs.forEach((type, i) => {
      if (output(node.children[i]) !== type) throw new Error(`Incorrect input type for ${node.name}.`);
    });
    if (node.value && !node.value.every(Number.isFinite)) throw new Error('Non-finite parameter.');
    if (node.name === 'rimg' && ![0, 1, 2].includes(node.channel)) throw new Error('Invalid image channel.');
  }
  for (const { node } of entries) {
    if (node.name === 'link' && (!nodes.has(node.target) || output(nodes.get(node.target)) !== output(node))) throw new Error('Invalid link.');
  }
  if (hasCycle(root)) throw new Error('Cyclic graph.');
  return { nodes: entries.length, depth: widths.length - 1, width: Math.max(...widths.filter(Number.isFinite)), links: entries.filter(e => e.node.name === 'link').length };
}
function gaussian(rng) {
  return Math.sqrt(-2 * Math.log(Math.max(Number.EPSILON, rng()))) * Math.cos(2 * Math.PI * rng());
}
function copyBranch(node) {
  const copy = structuredClone(node), ids = new Map();
  for (const entry of walk(copy)) {
    ids.set(entry.node.id, nextId);
    entry.node.id = nextId++;
  }
  for (const { node: n } of walk(copy)) if (n.name === 'link' && ids.has(n.target)) n.target = ids.get(n.target);
  return copy;
}
function structuralMutation(root, settings, rng) {
  const entries = walk(root), a = randomPick(entries, rng), b = randomPick(entries, rng);
  const type = output(a.node), act = Math.floor(rng() * 6);
  const replace = (entry, node) => {
    if (entry.parent) entry.parent.children[entry.index] = node;
    else root = node;
  };
  if (act === 0) {
    const compatible = a.node.children.filter(n => output(n) === type);
    if (compatible.length) replace(a, randomPick(compatible, rng));
  } else if (act === 1 || act === 5) {
    const wrapper = choose(type, false, settings.depth - a.depth + 1, entries.map(e => e.node), settings, rng);
    if (wrapper.name === 'link') {
      if (a.node.name !== 'link') replace(a, wrapper);
    } else {
      const slot = NODES[wrapper.name].inputs.lastIndexOf(type);
      if (slot >= 0) {
        wrapper.children = NODES[wrapper.name].inputs.map((t, i) => i === slot ? a.node : terminal(t, settings, rng));
        replace(a, wrapper);
      }
    }
  } else if (act === 2 && a.node.name !== 'link') {
    const node = choose(type, a.node.children.length === 0, settings.depth - a.depth + 1, entries.map(e => e.node), settings, rng);
    node.children = NODES[node.name].inputs.map((t, i) => a.node.children[i] && output(a.node.children[i]) === t ? a.node.children[i] : terminal(t, settings, rng));
    replace(a, node);
  } else if (act === 3 && type === output(b.node)) {
    const contains = (parent, child) => walk(parent).some(e => e.node.id === child.id);
    if (!contains(a.node, b.node) && !contains(b.node, a.node)) {
      replace(a, b.node);
      replace(b, a.node);
    }
  } else if (act === 4 && a.node.id !== b.node.id && type === output(b.node)) {
    replace(b, copyBranch(a.node));
  }
  return root;
}
export function evolveGraph(current, rawSettings, rng = Math.random) {
  const settings = normalizeSettings(rawSettings);
  let root = enforceLimits(structuredClone(current), settings, rng);
  repairLinks(root, settings, rng);
  if (settings.mutation > 0) {
    const values = walk(root).map(e => e.node).filter(n => n.value);
    // Keep the original Gaussian argument drift; scale it with the mutation control.
    for (let i = 0, count = Math.ceil(rng() * values.length); i < count; i++) {
      const node = randomPick(values, rng);
      node.value = node.value.map(v => v + gaussian(rng) * .1 * Math.sqrt(settings.mutation / 100));
    }
    const attempts = Math.ceil(walk(root).length * settings.mutation / 100 * .05);
    for (let i = 0; i < attempts; i++) {
      let candidate = structuralMutation(structuredClone(root), settings, rng);
      candidate = enforceLimits(candidate, settings, rng);
      if (hasCycle(candidate)) continue;
      repairLinks(candidate, settings, rng);
      validateWithSettings(candidate, settings);
      root = candidate;
    }
  }
  validateWithSettings(root, settings);
  return root;
}
const glslFloat = value => {
  if (!Number.isFinite(value)) throw new Error('Cannot compile a non-finite value.');
  const text = value.toPrecision(9);
  return /[.eE]/.test(text) ? text : `${text}.0`;
};
export function compileGraph(root) {
  const nodes = new Map(walk(root).map(({ node }) => [node.id, node]));
  const expressions = new Map(), visiting = new Set(), statements = [];
  function emit(node) {
    if (expressions.has(node.id)) return expressions.get(node.id);
    if (visiting.has(node.id)) throw new Error('Cyclic graph.');
    visiting.add(node.id);
    let expression;
    if (node.name === 'link') {
      const target = nodes.get(node.target);
      if (!target) throw new Error('Unresolved link.');
      expression = emit(target);
    } else {
      const args = node.children.map(emit);
      const type = TYPES[output(node)].glsl;
      expression = `node${node.id}`;
      let value;
      if (node.name === 'rimg') {
        if (![0, 1, 2].includes(node.channel)) throw new Error('Invalid image channel.');
        value = `${args[0]}.${'rgb'[node.channel]}`;
      } else if (node.value) {
        const values = node.name === 'prnd' ? node.value.map(v => clamp(v, -.5, .5)) : node.value;
        value = type === 'float' ? glslFloat(values[0]) : `${type}(${values.map(glslFloat).join(', ')})`;
      } else {
        if (node.name === 'circle') args.push(glslFloat(node.radius));
        value = `g_${node.name}(${args.join(', ')})`;
      }
      statements.push(`${type} ${expression} = ${value};`);
    }
    expressions.set(node.id, expression);
    visiting.delete(node.id);
    return expression;
  }
  const result = emit(root);
  return `${statements.join('\n')}\nreturn ${result};`;
}
