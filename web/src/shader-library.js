// Index the local GLSL library once, then include only reachable functions.
// The library uses single, non-overloaded float/vecN function definitions.
export class ShaderLibrary {
  constructor(source) {
    source = source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
    this.functions = new Map();
    const signature = /\b(?:float|vec[234])\s+(\w+)\s*\([^)]*\)\s*\{/g;
    let match, first = source.length;
    while ((match = signature.exec(source))) {
      first = Math.min(first, match.index);
      let end = signature.lastIndex, depth = 1;
      while (depth && end < source.length) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
        end++;
      }
      if (depth) throw new Error(`Unclosed shader function: ${match[1]}`);
      if (this.functions.has(match[1])) throw new Error(`Duplicate shader function: ${match[1]}`);
      this.functions.set(match[1], source.slice(match.index, end));
      signature.lastIndex = end;
    }
    this.header = source.slice(0, first).trim();
  }
  forGraph(code) {
    const used = new Set();
    const visit = text => {
      for (const match of text.matchAll(/\b([A-Za-z_]\w*)\s*\(/g)) {
        const name = match[1];
        if (!this.functions.has(name) || used.has(name)) continue;
        used.add(name);
        visit(this.functions.get(name));
      }
    };
    visit(code);
    // Preserve definition order; dependencies precede callers in nodes.glsl.
    return [this.header, ...[...this.functions].filter(([name]) => used.has(name)).map(([, body]) => body)].join('\n\n');
  }
}
