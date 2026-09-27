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
