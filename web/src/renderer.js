import { compileGraph } from './graph.js';
import { ShaderLibrary } from './shader-library.js';
import { createFeedbackTargets, deleteFeedbackTargets } from './feedback-targets.js';

const vertexSource = `#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`;
const afterPaint = () => new Promise(resolve => requestAnimationFrame(() => setTimeout(resolve, 0)));
const interrupted = () => new DOMException('Shader compilation interrupted.', 'AbortError');

export class Renderer {
  constructor(canvas, library, onError, onRestore) {
    this.canvas = canvas;
    this.library = new ShaderLibrary(library);
    this.entries = [];
    this.graphs = [];
    this.revision = 0;
    this.frameNumber = 0;
    this.feedbackDebug = false;
    this.gl = canvas.getContext('webgl2', { alpha: false, antialias: false, depth: false, stencil: false });
    if (!this.gl) throw new Error('WebGL 2 is unavailable. Try a browser with hardware acceleration enabled.');
    this.lost = false;
    this.initialize();
    canvas.addEventListener('webglcontextlost', event => {
      event.preventDefault();
      this.lost = true;
      this.revision++;
      onError(new Error('The graphics context was interrupted. Waiting for it to recover…'));
    });
    canvas.addEventListener('webglcontextrestored', async () => {
      this.lost = false;
      this.entries = [];
      try {
        this.initialize();
        await this.setGraphsProgressively(this.graphs, this.onProgress);
        onRestore();
      } catch (error) { if (error.name !== 'AbortError') onError(error); }
    });
  }
  initialize() {
    const gl = this.gl;
    this.parallel = gl.getExtension('KHR_parallel_shader_compile');
    this.maxSize = Math.min(2400, gl.getParameter(gl.MAX_RENDERBUFFER_SIZE));
    this.vertex = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(this.vertex, vertexSource);
    gl.compileShader(this.vertex);
    if (!gl.getShaderParameter(this.vertex, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(this.vertex) || 'Vertex shader compilation failed.');
  }
  fragmentSource(graph) {
    const code = compileGraph(graph);
    return `#version 300 es
precision highp float;
precision highp int;
out vec4 outColor;
${this.library.forGraph(code)}
vec3 evaluateGraph() {
${code}
}
void main() {
  vec3 color = vec3(0.0);
  for (int y = 0; y < 4; y++) {
    if (y >= u_aa) break;
    for (int x = 0; x < 4; x++) {
      if (x >= u_aa) break;
      sampleOffset = (vec2(float(x), float(y)) + 0.5) / float(u_aa) - 0.5;
      vec3 sampleColor = evaluateGraph();
      if (any(isnan(sampleColor)) || any(isinf(sampleColor))) sampleColor = vec3(0.0);
      color += sampleColor;
    }
  }
  outColor = vec4(color / float(u_aa * u_aa), 1.0);
}`;
  }
  startCompile(graph) {
    if (this.lost) throw interrupted();
    const source = this.fragmentSource(graph), gl = this.gl;
    const shader = gl.createShader(gl.FRAGMENT_SHADER), program = gl.createProgram();
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    gl.attachShader(program, this.vertex);
    gl.attachShader(program, shader);
    gl.linkProgram(program);
    return { graph, shader, program };
  }
  finishCompile(pending) {
    const gl = this.gl;
    try {
      if (!gl.getProgramParameter(pending.program, gl.LINK_STATUS)) {
        throw new Error(gl.getShaderInfoLog(pending.shader) || gl.getProgramInfoLog(pending.program) || 'Shader compilation failed.');
      }
      return { graph: pending.graph, program: pending.program, uniforms: Object.fromEntries(
        ['u_resolution', 'u_origin', 'u_off', 'u_scale', 'u_time', 'u_aa', 'u_previous', 'u_feedbackDebug'].map(name => [name, gl.getUniformLocation(pending.program, name)])
      ) };
    } catch (error) {
      gl.deleteProgram(pending.program);
      throw error;
    } finally {
      gl.deleteShader(pending.shader);
    }
  }
  compile(graph) { return this.finishCompile(this.startCompile(graph)); }
  setGraph(graph) { this.setGraphs([graph]); }
  setGraphs(graphs) {
    if (this.lost) throw interrupted();
    const previous = this.entries.filter(Boolean);
    const cache = new Map(previous.map(entry => [entry.graph, entry]));
    const created = [];
    let next;
    try {
      next = graphs.map(graph => {
        if (cache.has(graph)) return cache.get(graph);
        const entry = this.compile(graph);
        created.push(entry); cache.set(graph, entry);
        return entry;
      });
    } catch (error) {
      created.forEach(entry => this.disposeEntry(entry));
      throw error;
    }
    this.revision++;
    this.graphs = graphs;
    this.entries = next;
    const retained = new Set(next);
    previous.forEach(entry => { if (!retained.has(entry)) this.disposeEntry(entry); });
  }
  async setGraphsProgressively(graphs, onReady = () => {}) {
    if (this.lost) throw interrupted();
    // A source may be a ready graph or a deferred generator for a pending cell.
    // Keep resolved graphs for context recovery without regenerating their values.
    graphs = graphs.slice();
    const revision = ++this.revision;
    const started = performance.now();
    const pending = new Map(), errors = [];
    const capacity = this.parallel ? 8 : 1;
    performance.clearMeasures('Pixy: shader ready (elapsed)');
    performance.clearMeasures('Pixy: population ready');
    this.compiling = true;
    try {
      const previous = this.entries.filter(Boolean);
      const cache = new Map(previous.map(entry => [entry.graph, entry]));
      this.graphs = graphs;
      this.onProgress = onReady;
      this.entries = graphs.map(graph => cache.get(graph) ?? null);
      const retained = new Set(this.entries);
      previous.forEach(entry => { if (!retained.has(entry)) this.disposeEntry(entry); });
      onReady(-1);
      let index = 0;
      do {
        if (this.lost || revision !== this.revision) throw interrupted();
        // Keep submission work short, but do not wait for one shader before
        // starting the next. The driver decides whether to compile in parallel.
        const deadline = performance.now() + 4;
        let submitted = false;
        while (index < graphs.length && pending.size < capacity && performance.now() < deadline) {
          const current = index++;
          if (this.entries[current]) continue;
          try {
            if (typeof graphs[current] === 'function') graphs[current] = graphs[current]();
            const start = performance.now();
            pending.set(current, { ...this.startCompile(graphs[current]), start });
            submitted = true;
          } catch (error) {
            if (error.name === 'AbortError') throw error;
            errors.push(`Image ${current + 1}: ${error.message}`);
          }
        }
        if (submitted) this.gl.flush();
        // A slow image must not hold up another image that is already ready.
        for (const [current, shader] of pending) {
          if (this.lost || revision !== this.revision) throw interrupted();
          if (this.parallel && !this.gl.getProgramParameter(shader.program, this.parallel.COMPLETION_STATUS_KHR)) continue;
          pending.delete(current);
          try {
            this.entries[current] = this.finishCompile(shader);
            performance.measure('Pixy: shader ready (elapsed)', {
              start: shader.start, end: performance.now(), detail: { image: current + 1 },
            });
            onReady(current);
          } catch (error) {
            if (error.name === 'AbortError') throw error;
            errors.push(`Image ${current + 1}: ${error.message}`);
          }
        }
        // One paint opportunity per batch/poll, not an extra frame per image.
        await afterPaint();
      } while (index < graphs.length || pending.size);
      if (this.lost || revision !== this.revision) throw interrupted();
      if (errors.length) throw new Error(errors.join('\n'));
    } finally {
      for (const shader of pending.values()) {
        this.gl.deleteShader(shader.shader);
        this.gl.deleteProgram(shader.program);
      }
      if (revision === this.revision) {
        performance.measure('Pixy: population ready', { start: started, end: performance.now() });
        this.compiling = false;
        onReady(-2);
      }
    }
  }

  disposeEntry(entry) {
    deleteFeedbackTargets(this.gl, entry.history);
    this.gl.deleteProgram(entry.program);
  }
  resetFeedback(index = null) {
    for (const entry of index === null ? this.entries : [this.entries[index]]) {
      if (!entry) continue;
      deleteFeedbackTargets(this.gl, entry.history);
      entry.history = null;
    }
  }
  beginFrame({ advanceFeedback = true, feedbackDebug = false } = {}) {
    if (this.lost) return;
    if (feedbackDebug !== this.feedbackDebug) {
      this.feedbackDebug = feedbackDebug;
      this.resetFeedback();
    }
    this.frameNumber++;
    this.advanceFeedback = advanceFeedback;
    const gl = this.gl, rect = this.canvas.getBoundingClientRect();
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    const ratio = Math.min(window.devicePixelRatio || 1, 2, this.maxSize / Math.max(1, rect.width, rect.height));
    const width = Math.max(1, Math.round(rect.width * ratio));
    const height = Math.max(1, Math.round(rect.height * ratio));
    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width; this.canvas.height = height;
    }
    this.bounds = rect;
    gl.disable(gl.SCISSOR_TEST);
    gl.clearColor(17 / 255, 17 / 255, 17 / 255, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
  }
  drawViewport(index, { offset, scale, phase, aa }, rect) {
    const entry = this.entries[index];
    if (this.lost || !entry || rect.width <= 0 || rect.height <= 0) return;
    const gl = this.gl, bounds = this.bounds;
    const ratioX = this.canvas.width / Math.max(1, bounds.width);
    const ratioY = this.canvas.height / Math.max(1, bounds.height);
    const x = Math.round(rect.x * ratioX), y = Math.round((bounds.height - rect.y - rect.height) * ratioY);
    const width = Math.max(1, Math.round(rect.width * ratioX)), height = Math.max(1, Math.round(rect.height * ratioY));
    if (entry.uniforms.u_previous !== null) {
      // The first viewport sets this frame's feedback resolution. The app draws
      // the preview first, then its grid cell reuses that result without stepping twice.
      let history = entry.history;
      const viewKey = JSON.stringify([offset, scale, aa]);
      if (history?.frame !== this.frameNumber) {
        if (!history || history.width !== width || history.height !== height || history.viewKey !== viewKey) {
          deleteFeedbackTargets(gl, history);
          entry.history = history = createFeedbackTargets(gl, width, height);
          history.viewKey = viewKey;
        }
        if (!history.initialized || this.advanceFeedback) {
          const write = 1 - history.read;
          gl.bindFramebuffer(gl.FRAMEBUFFER, history.targets[write].framebuffer);
          gl.disable(gl.SCISSOR_TEST);
          gl.activeTexture(gl.TEXTURE0);
          gl.bindTexture(gl.TEXTURE_2D, history.targets[history.read].texture);
          this.renderProgram(entry, { offset, scale, phase, aa }, 0, 0, width, height);
          gl.bindTexture(gl.TEXTURE_2D, null);
          history.read = write;
          history.initialized = true;
        }
        history.frame = this.frameNumber;
      }
      gl.bindFramebuffer(gl.READ_FRAMEBUFFER, history.targets[history.read].framebuffer);
      gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, null);
      gl.enable(gl.SCISSOR_TEST);
      gl.scissor(x, y, width, height);
      gl.blitFramebuffer(0, 0, history.width, history.height, x, y, x + width, y + height, gl.COLOR_BUFFER_BIT, gl.LINEAR);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    } else {
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.enable(gl.SCISSOR_TEST);
      gl.scissor(x, y, width, height);
      this.renderProgram(entry, { offset, scale, phase, aa }, x, y, width, height);
    }
  }
  renderProgram(entry, { offset, scale, phase, aa }, x, y, width, height) {
    const gl = this.gl;
    gl.viewport(x, y, width, height);
    gl.useProgram(entry.program);
    gl.uniform2f(entry.uniforms.u_resolution, width, height);
    gl.uniform2f(entry.uniforms.u_origin, x, y);
    gl.uniform2fv(entry.uniforms.u_off, offset);
    gl.uniform1f(entry.uniforms.u_scale, scale);
    gl.uniform1f(entry.uniforms.u_time, phase);
    gl.uniform1i(entry.uniforms.u_aa, aa);
    gl.uniform1i(entry.uniforms.u_previous, 0);
    gl.uniform1i(entry.uniforms.u_feedbackDebug, this.feedbackDebug ? 1 : 0);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  draw(view) {
    if (this.lost) return;
    this.beginFrame();
    this.drawViewport(0, view, { x: 0, y: 0, width: this.bounds.width, height: this.bounds.height });
  }
}
