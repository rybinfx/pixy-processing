// Supporting code for the archive release.

// macOS native resize

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

// Animation recovery after resize

// JOGL pauses its animator during native macOS resizing. If the final resume
// is missed, resize repaints still draw frames, but ordinary animation and
// queued input stop. Recovery must run independently of the stopped draw loop.
public class ResizeAnimationRecovery extends com.jogamp.newt.event.WindowAdapter {
  final com.jogamp.newt.opengl.GLWindow window;
  final java.util.concurrent.ScheduledThreadPoolExecutor scheduler;
  java.util.concurrent.ScheduledFuture<?> pending;
  volatile boolean disposed;
  volatile long resizeSequence;

  ResizeAnimationRecovery(com.jogamp.newt.opengl.GLWindow nativeWindow) {
    window = nativeWindow;
    scheduler = new java.util.concurrent.ScheduledThreadPoolExecutor(1,
      new java.util.concurrent.ThreadFactory() {
        public Thread newThread(Runnable task) {
          Thread worker = new Thread(task, "Pixy resize recovery");
          worker.setDaemon(true);
          worker.setContextClassLoader(sketchRef.getClass().getClassLoader());
          return worker;
        }
      });
    scheduler.setRemoveOnCancelPolicy(true);
    window.addWindowListener(this);
    registerMethod("dispose", this);
  }

  @Override
  public synchronized void windowResized(com.jogamp.newt.event.WindowEvent event) {
    if (disposed) return;
    final long sequence = ++resizeSequence;
    if (pending != null) pending.cancel(false);
    pending = scheduler.schedule(new Runnable() {
      public void run() {
        resumeAfterResize(sequence);
      }
    }, 400, java.util.concurrent.TimeUnit.MILLISECONDS);
  }

  void resumeAfterResize(long sequence) {
    if (disposed || sequence != resizeSequence || sketchRef.finished ||
        !sketchRef.isLooping() || !window.isNativeValid() || !window.isVisible()) return;

    com.jogamp.opengl.GLAnimatorControl animator = window.getAnimator();
    if (animator == null || !animator.isStarted() || !animator.isPaused()) return;
    if (disposed || sequence != resizeSequence) return;

    // resume() can wait for the animation thread. Never call it from draw()
    // or the native resize callback, where render/window locks may be held.
    if (animator.resume()) {
      println("Resumed paused animation after window resize.");
    }
  }

  public synchronized void dispose() {
    disposed = true;
    if (pending != null) pending.cancel(false);
    scheduler.shutdown();
    window.removeWindowListener(this);
  }
}

// Unique output names

java.nio.file.Path reserveOutput(boolean frameFolder) throws IOException {
  java.nio.file.Path root = java.nio.file.Paths.get(sketchPath("../outputs")).normalize();
  java.nio.file.Files.createDirectories(root);
  for (int attempt = 0; attempt < 1000; attempt++) {
    String name = String.format(java.util.Locale.ROOT, "pixy%06d",
      java.util.concurrent.ThreadLocalRandom.current().nextInt(1000000));
    java.nio.file.Path folder = root.resolve(name);
    java.nio.file.Path image = root.resolve(name + ".jpg");
    java.nio.file.Path movie = root.resolve(name + ".mov");
    try {
      // Reserve the shared name across images, movies, and frame folders.
      java.nio.file.Files.createDirectory(folder);
    } catch (java.nio.file.FileAlreadyExistsException collision) {
      continue;
    }
    boolean keepFolder = false;
    try {
      if (java.nio.file.Files.exists(image) || java.nio.file.Files.exists(movie)) continue;
      if (frameFolder) {
        keepFolder = true;
        return folder;
      }
      return java.nio.file.Files.createFile(image);
    } catch (java.nio.file.FileAlreadyExistsException collision) {
      // Another writer claimed the image; try a different name.
    } finally {
      if (!keepFolder) java.nio.file.Files.delete(folder);
    }
  }
  throw new IOException("Could not reserve an unused output name in " + root);
}

File videoFrameFile(File directory, int index) {
  return new File(directory, String.format(java.util.Locale.ROOT, "frame%05d.jpg", index));
}

// Optional video encoding

// Optional FFmpeg conversion. Only a successfully finalized MOV permits cleanup.
public class VideoEncoder {
  volatile boolean busy;
  volatile boolean disposed;
  Process process;

  VideoEncoder() {
    registerMethod("dispose", this);
  }

  void encode(final File directory, final int count, final int fps) {
    if (busy || disposed) return;
    busy = true;
    Thread worker = new Thread(new Runnable() {
      public void run() {
        try {
          convert(directory, count, fps);
        } catch (Exception error) {
          println("Video encoding failed; frames kept in " + directory);
          println(error.getMessage());
        } finally {
          synchronized (VideoEncoder.this) {
            process = null;
          }
          busy = false;
        }
      }
    }, "Pixy video encoding");
    worker.setDaemon(true);
    worker.start();
  }

  String findFfmpeg() {
    String executable = platform == WINDOWS ? "ffmpeg.exe" : "ffmpeg";
    ArrayList<String> paths = new ArrayList<String>();
    String path = System.getenv("PATH");
    if (path != null) {
      for (String entry : path.split(java.util.regex.Pattern.quote(File.pathSeparator))) {
        if (!entry.isEmpty()) paths.add(entry.replace("\"", ""));
      }
    }
    // Apps launched from Finder may not inherit the shell's Homebrew PATH.
    if (platform == MACOSX) {
      paths.add("/opt/homebrew/bin");
      paths.add("/usr/local/bin");
      paths.add("/opt/local/bin");
    }
    for (String entry : paths) {
      File candidate = new File(entry, executable);
      if (candidate.isFile() && candidate.canExecute()) return candidate.getAbsolutePath();
    }
    return null;
  }

  void convert(File directory, int count, int fps) throws Exception {
    String ffmpeg = findFfmpeg();
    if (ffmpeg == null) {
      println("FFmpeg not found. Frames kept in " + directory);
      return;
    }
    if (count < 1) throw new IOException("No frames to encode.");
    for (int i = 0; i < count; i++) {
      File frame = videoFrameFile(directory, i);
      if (!frame.isFile() || frame.length() == 0) {
        throw new IOException("Missing or empty frame: " + frame.getName());
      }
    }

    File output = new File(directory.getParentFile(), directory.getName() + ".mov");
    File partial = new File(directory, "encoding.mov");
    File log = new File(directory, "encoding.log");
    if (output.exists()) throw new IOException("Output already exists: " + output);
    ProcessBuilder command = new ProcessBuilder(ffmpeg,
      "-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-xerror",
      "-framerate", Integer.toString(fps), "-start_number", "0",
      "-i", new File(directory, "frame%05d.jpg").getAbsolutePath(),
      "-frames:v", Integer.toString(count),
      "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
      "-c:v", "libx264", "-preset", "medium", "-crf", "18",
      "-pix_fmt", "yuv420p", "-movflags", "+faststart", partial.getAbsolutePath());
    command.redirectErrorStream(true);
    command.redirectOutput(log);
    Process encoding;
    synchronized (this) {
      if (disposed) return;
      process = command.start();
      encoding = process;
    }
    println("Encoding MOV: " + output);
    int result = encoding.waitFor();
    if (disposed || result != 0 || !partial.isFile() || partial.length() == 0) {
      throw new IOException("FFmpeg did not complete. Details: " + log);
    }
    java.nio.file.Files.move(partial.toPath(), output.toPath());
    // Delete only this job's expected frames, never arbitrary directory contents.
    boolean cleaned = true;
    for (int i = 0; i < count; i++) {
      if (!videoFrameFile(directory, i).delete()) cleaned = false;
    }
    if (cleaned) {
      log.delete();
      directory.delete(); // Succeeds only if no other files are present.
    }
    println("Video saved: " + output);
    if (!cleaned) println("Some frames could not be removed from " + directory);
  }

  public synchronized void dispose() {
    disposed = true;
    if (process != null) process.destroy();
  }
}

// Scrollable greeting

class GreetingDisplay {
  final float scrollSensitivity = 1;
  final float fontSize = 13;
  final float lineHeight = 15;
  ArrayList<String> lines = new ArrayList<String>();
  String wrappedText;
  float wrappedWidth = -1;
  float x, y, w, h, scroll, maxScroll;

  void display(float left, float top, float wide, float high) {
    x = left;
    y = top;
    w = wide;
    h = high;
    if (w <= 20 || h <= 0) return;

    pushStyle();
    textFont(app.font, fontSize);
    textAlign(LEFT, BASELINE);
    float textAreaWidth = w-20;
    if (wrappedWidth != textAreaWidth || !textGreet.equals(wrappedText)) {
      wrap(textAreaWidth);
      wrappedWidth = textAreaWidth;
      wrappedText = textGreet;
    }
    float contentHeight = textAscent()+textDescent() + max(0, lines.size()-1)*lineHeight;
    maxScroll = max(0, contentHeight-h);
    scroll = constrain(scroll, 0, maxScroll);

    // Keep greeting text above the controls, including partially visible lines.
    imageMode(CORNER);
    clip(x, y, w, h);
    fill(240);
    float baseline = y+textAscent()-scroll;
    for (String line : lines) {
      if (baseline+textDescent() >= y && baseline-textAscent() <= y+h) {
        text(line, x, baseline);
      }
      baseline += lineHeight;
    }
    noClip();

    if (maxScroll > 0) {
      float thumbHeight = min(h, max(12, h*h/contentHeight));
      float thumbY = y+(h-thumbHeight)*scroll/maxScroll;
      noStroke();
      rectMode(CORNER);
      fill(app.grayDark);
      rect(x+w-2, y, 2, h);
      fill(app.grayNormal);
      rect(x+w-2, thumbY, 2, thumbHeight);
    }
    popStyle();
  }

  void wrap(float availableWidth) {
    lines.clear();
    for (String paragraph : textGreet.split("\n", -1)) {
      String line = "";
      for (String word : paragraph.split(" ")) {
        String candidate = line.isEmpty() ? word : line+" "+word;
        if (!line.isEmpty() && renderedWidth(candidate) > availableWidth) {
          lines.add(line);
          line = "";
        }
        // Also wrap a single word if the preview becomes narrower than it.
        for (int i = 0; i < word.length(); i++) {
          String next = (i == 0 && !line.isEmpty() ? " " : "") + word.charAt(i);
          if (!line.isEmpty() && renderedWidth(line+next) > availableWidth) {
            lines.add(line);
            line = "";
          }
          line += next;
        }
      }
      lines.add(line);
    }
  }

  float renderedWidth(String line) {
    // P2D advances each character separately; native string metrics can be narrower.
    float width = 0;
    for (int i = 0; i < line.length(); i++) width += textWidth(line.charAt(i));
    return width;
  }

  void mouseWheel(processing.event.MouseEvent event) {
    if (maxScroll > 0 && event.getX() >= x && event.getX() < x+w &&
        event.getY() >= y && event.getY() < y+h) {
      scroll = constrain(scroll+event.getCount()*scrollSensitivity, 0, maxScroll);
    }
  }
}
