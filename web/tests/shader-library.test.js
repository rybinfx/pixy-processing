import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { ShaderLibrary } from '../src/shader-library.js';

const library = new ShaderLibrary(readFileSync(new URL('../src/nodes.glsl', import.meta.url), 'utf8'));
const included = code => [...new ShaderLibrary(library.forGraph(code)).functions.keys()];

test('simple images include only their called functions', () => {
  assert.deepEqual(included('g_sdfimg(g_circle(g_pxy(), 0.5), vec3(1.0), 0.2)'),
    ['g_pxy', 'g_circle', 'g_sdfimg']);
  assert.deepEqual(included('vec3(0.5)'), []);
});

test('nested helper dependencies are included once and before their callers', () => {
  assert.deepEqual(included('g_edge(0.1, 0.2, 0.3)'), ['g_smunion', 'g_sminter', 'g_edge']);
  assert.deepEqual(included('g_tilexy(g_tilex(g_pxy(), 0.2), 0.3, 0.4)'),
    ['g_pxy', 'tileCount', 'tileAxis', 'g_tilex', 'g_tilexy']);
  assert.deepEqual(included('g_triangle(vec2(0.0)) + g_hexagon(vec2(0.0))'),
    ['sdfRegularPolygon', 'g_triangle', 'g_hexagon']);
});

test('library indexing preserves nested bodies and ignores comments', () => {
  const source = new ShaderLibrary(`uniform float value;
    // float unused() { return 0.0; }
    float helper() { if (value > 0.0) { return value; } return 0.0; }
    /* vec3 ignored() { return vec3(0.0); } */
    float caller() { return helper(); }`);
  assert.equal(source.functions.size, 2);
  assert.match(source.forGraph('caller()'), /uniform float value/);
  assert.match(source.forGraph('caller()'), /if \(value > 0.0\) \{ return value; \} return 0.0;/);
});
