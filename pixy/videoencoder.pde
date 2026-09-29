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
