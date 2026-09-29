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
