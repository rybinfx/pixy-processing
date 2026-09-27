PApplet sketchRef = this;

App app;
String[] vertexShader;
String[] fragmentShader;
CheckBox checkbox;

PImage logo;

PGraphics renderer;

boolean begin = true;


String textGreet = "Hello, my name is Pixy. And I am here to generate images with you!\nBegin with choosing an image you like. You can generate new images with *NEW* button, and adjust the grid with *+* and *-* buttons under *SIZE* label. By the way, *AA* parameter sets quality of my images!\nTo see an image in detail, press on it. You can navigate through the image by dragging, and zoom with keys *a* and *z*! (You can also use arrows to navigate)\nWhen you found one that you like, you can select it with small button on it, and then develop with *DEVELOP* button. If you don’t like the results, you can click *REPEAT* to generate more!\nIf you find several images that you like, you can merge them by selecting all of them. But be careful! This is experimental feature and results may look more different than you expect!\nWhen you are satisfied with the image, you can save it by selecting or opening and hitting *EXPORT* button! Don’t forget to set the size for your image! It will be saved in the folder ‘export’ with random name in the location of the app.\nYou can also animate images with controls in the bottom of the screen. Upper slider sets loop time! To save animation, press *RENDER*. It will be saved in the ‘renders’ folder as image sequence.\nGood luck!";
 
void settings() {
	size(1280,720,P2D);
  // Processing's non-AWT path reports displayDensity() as 1 on Retina.
  // pixelDensity(2) uses the same check and falls back to 1, so configure
  // the backing density directly before Processing creates the P2D surface.
  pixelDensity = 2;
	PJOGL.setIcon("data/logo.png");
}

void setup() {
	surface.setResizable(true);

	logo = loadImage("logo.png");


	pushStyle();
	background(17);

	imageMode(CENTER);
	image(logo, width/2, height/2, 200,200);
	popStyle();

	vertexShader = loadStrings("data/vertex.glsl");
	fragmentShader = loadStrings("data/fragment.glsl");

	renderer = createExportGraphics(800);

	app = new App();

}

void draw() {
	background(17);

		app.run();

}

void mousePressed() {
	app.mousePressed();
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
  app.geneControls.wheel(event.getCount());
}

PGraphics createExportGraphics(int size) {
  PGraphics target = createGraphics(size, size, P2D);
  // Offscreen graphics inherit the display density. Exports must instead
  // keep the exact pixel dimensions selected in the resolution control.
  if (target.pixelDensity != 1) {
    target.pixelDensity = 1;
    target.setSize(size, size);
  }
  return target;
}
