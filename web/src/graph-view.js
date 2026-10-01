import { TYPES, NODES } from './nodes.js';
import { walk, output } from './graph.js';
const NS = 'http://www.w3.org/2000/svg';
function element(tag, attributes, text) {
  const el = document.createElementNS(NS, tag);
  for (const [name, value] of Object.entries(attributes)) el.setAttribute(name, value);
  if (text != null) el.textContent = text;
  return el;
}
export function renderGraph(svg, root) {
  const entries = walk(root), levels = [], positions = new Map();
  for (const entry of entries) (levels[entry.depth - 1] ??= []).push(entry);
  const width = Math.max(500, ...levels.map(level => level.length * 106 + 48));
  const height = levels.length * 68 + 44;
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  const compact = levels.length <= 8 && levels.every(level => level.length <= 8);
  svg.style.minWidth = compact ? '0' : `${Math.min(width, 1800)}px`;
  svg.style.height = compact ? '100%' : `${Math.max(220, height)}px`;
  svg.replaceChildren(element('title', {}, 'Current graph. Inputs flow down to the image output. Dashed lines reuse a node.'));
  for (let depth = 0; depth < levels.length; depth++) {
    const level = levels[depth];
    level.forEach(({ node }, i) => positions.set(node.id, {
      x: width / 2 + (i - (level.length - 1) / 2) * 106,
      y: (levels.length - depth - 1) * 68 + 30,
    }));
  }
  const edge = (from, to, color, dashed = false) => {
    svg.append(element('path', { d: `M ${from.x} ${from.y + 16} L ${to.x} ${to.y - 16}`, fill: 'none', stroke: color, 'stroke-opacity': dashed ? .65 : .6, 'stroke-width': 1, ...(dashed ? { 'stroke-dasharray': '4 5' } : {}) }));
  };
  for (const { node, parent } of entries) {
    const type = node.name === 'link' ? 'link' : output(node);
    if (parent) edge(positions.get(node.id), positions.get(parent.id), TYPES[type].color);
    if (node.name === 'link') edge(positions.get(node.target), positions.get(node.id), TYPES.link.color, true);
  }
  for (const { node } of entries) {
    const { x, y } = positions.get(node.id), type = node.name === 'link' ? 'link' : output(node);
    const group = element('g', {});
    const details = node.name === 'rimg' ? `: ${'RGB'[node.channel]}` : node.value ? `: ${node.value.map(v => v.toFixed(3)).join(', ')}` : '';
    group.append(element('title', {}, `${node.name}${details} → ${output(node)}. ${NODES[node.name].description}`));
    group.append(element('rect', { x: x - 46, y: y - 15, width: 92, height: 30, fill: '#191919', stroke: TYPES[type].color }));
    group.append(element('text', { x, y: y + 4, fill: '#ccc', 'font-size': 12, 'text-anchor': 'middle', 'font-family': 'Pixy, monospace' }, node.name === 'link' ? 'LNK' : node.name === 'rimg' ? `RIMG.${'RGB'[node.channel]}` : node.name.toUpperCase()));
    svg.append(group);
  }
  const rootPosition = positions.get(root.id);
  svg.append(element('path', { d: `M ${rootPosition.x} ${rootPosition.y + 15} v 10`, stroke: TYPES.img.color }));
}
