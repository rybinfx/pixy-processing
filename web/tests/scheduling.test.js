import test from 'node:test';
import assert from 'node:assert/strict';
import { Renderer } from '../src/renderer.js';

function harness(t) {
  let frame = 0;
  const previous = globalThis.requestAnimationFrame;
  globalThis.requestAnimationFrame = callback => setImmediate(() => { frame++; callback(performance.now()); });
  t.after(() => {
    if (previous) globalThis.requestAnimationFrame = previous;
    else delete globalThis.requestAnimationFrame;
  });
  const submitted = [], deleted = [], finished = [];
  const renderer = Object.assign(Object.create(Renderer.prototype), {
    entries: [], revision: 0, lost: false, parallel: { COMPLETION_STATUS_KHR: 1 },
    gl: {
      flush() {},
      getProgramParameter(program) { return frame >= program.readyAt; },
      deleteShader() {},
      deleteProgram(program) { deleted.push(program); },
    },
    startCompile(graph) {
      submitted.push(graph);
      return { graph, program: { readyAt: graph.readyAt }, shader: {} };
    },
    finishCompile(pending) { finished.push(pending.graph); return pending; },
  });
  return { renderer, submitted, deleted, finished };
}

test('slow shaders do not serialize submission or delay ready images', async t => {
  const { renderer, submitted, finished } = harness(t);
  const graphs = [{ readyAt: 3 }, { readyAt: 0 }, { readyAt: 0 }];
  const ready = [];
  await renderer.setGraphsProgressively(graphs, index => {
    if (index >= 0) ready.push(index);
  });
  assert.deepEqual(submitted, graphs, 'every graph is submitted exactly once');
  assert.deepEqual(ready, [1, 2, 0], 'ready images appear while the first shader is still compiling');
  assert.deepEqual(finished, [graphs[1], graphs[2], graphs[0]]);
  assert.equal(renderer.compiling, false);
});

test('interrupting a batch releases its unfinished programs', async t => {
  const { renderer, deleted, finished } = harness(t);
  await assert.rejects(renderer.setGraphsProgressively([{ readyAt: 3 }, { readyAt: 0 }, { readyAt: 3 }], index => {
    if (index === 1) renderer.revision++;
  }), { name: 'AbortError' });
  assert.equal(finished.length, 1);
  assert.equal(deleted.length, 2);
});
