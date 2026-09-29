// Processing's macOS reshape callback can call back into the native window
// while holding the GL context. Title-bar zoom can then deadlock AppKit,
// which needs that context to finish its window animation.
@Override
protected PGraphics createPrimaryGraphics() {
  if (platform != MACOSX) return super.createPrimaryGraphics();

  PGraphics graphics = new MacResizeGraphics();
  graphics.setParent(this);
  graphics.setPrimary(true);
  if (sketchOutputPath() != null) graphics.setPath(savePath(sketchOutputPath()));
  graphics.setSize(sketchWidth(), sketchHeight());
  return graphics;
}

// ControlP5 inspects the renderer's canonical class name during startup.
// An anonymous renderer has no canonical name and makes its init() throw.
class MacResizeGraphics extends processing.opengl.PGraphics2D {
  @Override
  public PSurface createSurface() {
    surface = new MacResizeSurface(this);
    return surface;
  }
}

class MacResizeSurface extends processing.opengl.PSurfaceJOGL {
  final ThreadLocal<Boolean> nativeReshape = new ThreadLocal<Boolean>();

  MacResizeSurface(PGraphics graphics) {
    super(graphics);
  }

  @Override
  protected void initListeners() {
    super.initListeners();
    // Replace only the GL listener before animation starts. Keep Processing's
    // drawing, initialization, synchronization, and input listeners intact.
    for (int i = window.getGLEventListenerCount()-1; i >= 0; i--) {
      com.jogamp.opengl.GLEventListener listener = window.getGLEventListener(i);
      if (listener instanceof DrawListener) window.removeGLEventListener(listener);
    }
    window.addGLEventListener(new DrawListener() {
      @Override
      public void reshape(com.jogamp.opengl.GLAutoDrawable drawable,
                          int x, int y, int w, int h) {
        nativeReshape.set(true);
        try {
          super.reshape(drawable, x, y, w, h);
        } finally {
          nativeReshape.remove();
        }
      }
    });
  }

  @Override
  public void setSize(int wide, int high) {
    if (!Boolean.TRUE.equals(nativeReshape.get())) {
      super.setSize(wide, high);
      return;
    }
    if (pgl.presentMode()) return;

    // Acknowledge the native resize in the sketch and framebuffer only.
    // Sending another window.setSize() here creates the GL/AppKit lock cycle.
    sketchWidth = Math.max(1, wide);
    sketchHeight = Math.max(1, high);
    sketch.setSize(sketchWidth, sketchHeight);
    graphics.setSize(sketchWidth, sketchHeight);
  }
}
