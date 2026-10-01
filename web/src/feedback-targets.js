// Two independent RGBA8 targets: sample the last frame while drawing the next.
export function createFeedbackTargets(gl, width, height) {
  const targets = [];
  try {
    gl.disable(gl.SCISSOR_TEST);
    for (let i = 0; i < 2; i++) {
      const texture = gl.createTexture(), framebuffer = gl.createFramebuffer();
      targets.push({ texture, framebuffer });
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
      if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) throw new Error('Could not create feedback framebuffer.');
      gl.clearColor(0, 0, 0, 1);
      gl.clear(gl.COLOR_BUFFER_BIT);
    }
    return { targets, width, height, read: 0, initialized: false, frame: -1, viewKey: '' };
  } catch (error) {
    deleteFeedbackTargets(gl, { targets });
    throw error;
  } finally {
    gl.bindTexture(gl.TEXTURE_2D, null);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  }
}
export function deleteFeedbackTargets(gl, history) {
  if (!history) return;
  for (const { texture, framebuffer } of history.targets) {
    gl.deleteFramebuffer(framebuffer);
    gl.deleteTexture(texture);
  }
}
