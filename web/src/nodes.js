// Enabled Processing nodes plus temporal feedback and image-channel extraction.
export const TYPES = {
  pxy: { label: 'Position', color: '#57c7e3', glsl: 'vec2' },
  pnt: { label: 'Point', color: '#7fa7ff', glsl: 'vec2' },
  ramp: { label: 'Ramp', color: '#e6b85c', glsl: 'float' },
  cycle: { label: 'Cycle', color: '#f08092', glsl: 'float' },
  sdf: { label: 'Distance', color: '#73d5a5', glsl: 'float' },
  col: { label: 'Color', color: '#bd91ed', glsl: 'vec3' },
  img: { label: 'Image', color: '#f09f5c', glsl: 'vec3' },
  link: { label: 'Link', color: '#cdd6e4' },
};

export const NODES = {};
function define(names, output, inputs = [], description = '') {
  for (const name of names.split(' ')) NODES[name] = { name, output, inputs, description };
}
define('pxy', 'pxy', [], 'Panned and scaled pixel coordinates');
define('prnd', 'pnt', [], 'A random point in −0.5…0.5');
define('rrnd', 'ramp', [], 'A mutable random scalar, initially 0…1');
define('ctime', 'cycle', [], 'The animation phase');
define('crnd', 'cycle', [], 'A mutable random phase');
define('colrnd', 'col', [], 'A random RGB color');
define('pxaddp pxsubp', 'pxy', ['pxy', 'pnt'], 'Translate coordinates by a point');
define('pxaddpx pxsubpx', 'pxy', ['pxy', 'pxy'], 'Add or subtract coordinate fields');
define('pxscale', 'pxy', ['pxy', 'ramp'], 'Scale visible shapes by the ramp');
define('pxscaled', 'pxy', ['pxy', 'cycle', 'ramp'], 'Scale along the cycle’s axis');
define('pxrot', 'pxy', ['pxy', 'cycle'], 'Rotate coordinates in turns');
define('tilex tiley tilerot', 'pxy', ['pxy', 'ramp'], 'Repeat on an axis or around the origin, 1…6 times');
define('tilexy', 'pxy', ['pxy', 'ramp', 'ramp'], 'Repeat both axes with independent counts');
define('circle box roundbox triangle hexagon capsule ring point linex liney segment', 'sdf', ['pxy'], 'A primitive distance field');
define('sunion sinter ssub', 'sdf', ['sdf', 'sdf'], 'Union, intersection, or subtraction of distance fields');
define('smunion sminter smsub', 'sdf', ['sdf', 'sdf', 'ramp'], 'Smooth distance-field composition');
define('edge', 'sdf', ['sdf', 'ramp', 'ramp'], 'Outline a field with width and smoothness');
define('cdfcyc', 'cycle', ['sdf'], 'Interpret signed distance as phase');
define('cadd csub cmul', 'cycle', ['cycle', 'ramp'], 'Offset or multiply a cycle');
define('rsdfsin', 'ramp', ['sdf'], 'Sine wave over distance');
define('rcsin rsq rtri rup', 'ramp', ['cycle'], 'Sine, square, triangle, or rising wave');
define('ravg', 'ramp', ['ramp', 'ramp'], 'Average two ramps');
define('rmix', 'ramp', ['ramp', 'ramp', 'ramp'], 'Interpolate two ramps by a clamped amount');
define('rimg', 'ramp', ['img'], 'Extract one RGB channel, chosen randomly when this node is created');
define('colhsv', 'col', ['cycle', 'ramp', 'ramp'], 'Hue, saturation, value; ten cycles per hue revolution');
define('sdfimg', 'img', ['sdf', 'col', 'ramp'], 'Fill a distance field with color and edge softness');
define('imgscreen imgadd imgmult imgsub imgoverlay imgdiff imgdarken imglighten', 'img', ['img', 'img'], 'Compose two image branches, channel by channel');
define('imgmix', 'img', ['img', 'img', 'ramp'], 'Blend two images: ramp 0 selects the first, 1 selects the second');
define('feedback', 'img', ['pxy'], 'Sample this image’s previous frame; position −1…1 maps to UV 0…1');
define('link', 'link', [], 'Reuse a compatible node’s output without evaluating it twice');

export const minimumDepth = type => type === 'img' ? 3 : type === 'sdf' ? 2 : 1;
// The catalog is fixed. Index it once instead of scanning it for each graph node.
const depths = Object.fromEntries(Object.values(NODES).map(node =>
  [node.name, 1 + Math.max(0, ...node.inputs.map(minimumDepth))]));
export const nodeDepth = name => depths[name];
const terminalPools = {}, branchPools = {};
for (const type of Object.keys(TYPES)) {
  // Feedback cannot seed an image from empty history; keep ordinary terminal fallbacks.
  const pool = Object.values(NODES).filter(node => node.output === type && node.name !== 'feedback');
  const shortest = Math.min(...pool.map(node => depths[node.name]));
  terminalPools[type] = Object.freeze(pool.filter(node => depths[node.name] === shortest).map(node => node.name));
  branchPools[type] = Object.freeze(Object.values(NODES).filter(node => node.output === type && node.inputs.length).map(node => node.name));
}
export const terminals = type => terminalPools[type];
export const branches = type => branchPools[type];
const customWeights = { feedback: .35, link: .5, prnd: .5, pxaddp: .4, pxsubp: .5, sunion: .7, sinter: .35, ssub: .5, smunion: .7, sminter: .35, smsub: .5 };
export const DEFAULTS = {
  depth: 6, width: 6, mutation: 100, probabilityExponent: 2,
  probabilities: Object.fromEntries(Object.keys(NODES).map(name => [name, (customWeights[name] ?? 1) * .25])),
};
export const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
export function normalizeSettings(raw = {}) {
  const number = (v, fallback, min, max) => Number.isFinite(v) ? clamp(v, min, max) : fallback;
  const settings = {
    depth: Math.round(number(raw.depth, 6, 3, 32)),
    width: Math.round(number(raw.width, 6, 3, 32)),
    mutation: number(raw.mutation, 100, 0, 2000),
    probabilityExponent: number(raw.probabilityExponent, 2, .1, 8),
    probabilities: Object.fromEntries(Object.keys(NODES).map(name => [name,
      number(raw.probabilities?.[name], DEFAULTS.probabilities[name], 0, 1)])),
  };
  // Always retain a terminating producer for every type.
  for (const type of Object.keys(TYPES)) {
    if (type === 'link') continue;
    const leaves = terminals(type);
    if (!leaves.some(name => settings.probabilities[name] > 0)) settings.probabilities[leaves[0]] = DEFAULTS.probabilities[leaves[0]];
  }
  return settings;
}
