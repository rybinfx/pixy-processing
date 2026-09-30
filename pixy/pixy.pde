PApplet sketchRef = this;

App app;
ResizeAnimationRecovery resizeAnimationRecovery;
String[] vertexShader;
String[] fragmentShader;
CheckBox checkbox;

PImage logo;

PGraphics renderer;

boolean begin = true;


String textGreet = "Hello, my name is Pixy. And I am here to generate images with you!\n\nBegin with choosing an image you like. You can generate new images with *NEW* button, and adjust the grid with *+* and *-* buttons under *SIZE* label. By the way, *AA* parameter sets quality of my images!\n\nTo see an image in detail, press on it. You can navigate through the image by dragging, and zoom with keys *a* and *z*! (You can also use arrows to navigate)\n\nWhen you found one that you like, you can select it with small button on it, and then develop with *DEVELOP* button. If you don’t like the results, you can click *REPEAT* to generate more!\n\nIf you find several images that you like, you can merge them by selecting all of them. But be careful! This is experimental feature and results may look more different than you expect!\n\nWhen you are satisfied with the image, you can save it by selecting or opening and hitting *EXPORT* button! Don’t forget to set the size for your image! It will be saved in ‘../outputs’ with a unique pixy[id].jpg name.\n\nYou can also animate images with controls in the bottom of the screen. Upper slider sets loop time! To save animation, press *SAVE VIDEO*. It will be saved in ‘../outputs’ as pixy[id].mov if FFmpeg is available; otherwise frames are kept in the matching pixy[id] folder.\n\nGood luck!";
 
void settings() {
	size(1280,720,P2D);
  // Processing's non-AWT macOS path reports density 1 even on Retina.
  // Configure the backing density directly, as in pixy2.
  pixelDensity = platform == MACOSX ? 2 : 1;
	PJOGL.setIcon(dataPath("logo.png"));
}

void setup() {
	surface.setResizable(true);

	logo = loadImage("logo.png");
	setSketchAppIcon(logo);


	pushStyle();
	background(17);

	imageMode(CENTER);
	image(logo, width/2, height/2, 200,200);
	popStyle();

	vertexShader = loadStrings("data/vertex.glsl");
	fragmentShader = loadStrings("data/fragment.glsl");

	renderer = createExportGraphics(800);

	app = new App();
	if (platform == MACOSX && surface.getNative() instanceof com.jogamp.newt.opengl.GLWindow) {
		resizeAnimationRecovery = new ResizeAnimationRecovery(
			(com.jogamp.newt.opengl.GLWindow) surface.getNative());
	}

}

void draw() {
	background(17);

		app.run();

}

void mousePressed(processing.event.MouseEvent event) {
	app.mousePressed(event);
}

void mouseReleased() {
	app.mouseReleased();
}

void keyPressed() {
	app.keyPressed();
}

void keyReleased() {
	app.keyReleased();
}

void mouseMoved() {
	app.mouseMoved();
}

void mouseWheel(processing.event.MouseEvent event) {
	app.mouseWheel(event);
}

PGraphics createExportGraphics(int size) {
  PGraphics target = new ExportGraphics();
  target.setParent(sketchRef);
  target.setPrimary(false);
  target.pixelDensity = 1;
  target.setSize(size, size);
  return target;
}

class ExportGraphics extends processing.opengl.PGraphics2D {
  @Override
  protected processing.opengl.PGL createPGL(processing.opengl.PGraphicsOpenGL graphics) {
    return new processing.opengl.PJOGL(graphics) {
      @Override
      protected float getPixelScale() {
        // Processing 4.5.6 normally takes this from the window, even for
        // offscreen graphics. Exports need a 1x viewport and framebuffer.
        return 1;
      }
    };
  }
}
