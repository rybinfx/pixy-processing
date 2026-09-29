class Artwork {
	Pop p;
	int id;

	float x;
	float y;
	float w;
	float h;

	float resolution;
	float g_scale;
	PVector g_offset;

	PShader shader;
	String[] shaderCode = fragmentShader.clone();

	ArrayList<PVector> animatedArgs;

	boolean isSelected = false;
	
	DNA dna;


	Artwork(Pop p_) {
		p = p_;
		id = p.arts.size()-1;

		x = 0;
		y = 0;
		w = 0;
		h = 0;

		shader = loadShader("data/fragment.glsl");
	}

	// GENERAL

	void randomDNA() {
		dna = new DNA("RANDOM");
		compileShader();
	}

	void assignDNA(DNA d) {
		dna = d;
		compileShader();
	}

	// RENDERING

	void display(float x_, float y_, float w_, float h_) {
		update(x_,y_,w_,h_);
		setShader(g);
		shader(shader);
		rect(x_,y_,w,h);
		resetShader();
	}

	void compileShader() {
		shaderCode[shaderCode.length - 14] = dna.code;
		saveStrings("data/temp/shader"+id, shaderCode);
		shader = loadShader("data/temp/shader"+id);

	}

	void setShader(PGraphics target) {
		shader.set("u_g_off", g_offset.x, g_offset.y);
		// gl_FragCoord uses framebuffer pixels; layout and mouse input use points.
		float pixelScale = (float) target.pixelWidth / target.width;
		shader.set("u_g_scale", g_scale / pixelScale);
		shader.set("u_off", dna.offset.x, dna.offset.y);
		shader.set("u_scale", dna.scale);
		shader.set("u_hoff", dna.hueOffset);
		shader.set("u_args", argsToFloat(animateArgs()));

		shader.set("u_aa",app.aa);
	}

	void update(float x_, float y_, float w_, float h_) {
		update(x_, y_, w_, h_, height);
	}

	void update(float x_, float y_, float w_, float h_, float dh_) {
		if (x_!=x || y_!=y || w_!=w || h_!=h || dh_ != height) {
			w = w_;
			h = h_;
			x = x_;
			y =  y_;

			g_scale = 1/w * 4;
			g_offset = new PVector(-x/w - 0.5, -(dh_ - y - h - (w-h)/2)/w - 0.5);
			g_offset.mult(4);
		}
	}

	ArrayList<PVector> animateArgs() {
		animatedArgs = new ArrayList<PVector>();
		for (PVector a : dna.args) {
			float addTime = sin((app.appTime) * 2 * PI);
			PVector addTimeV = new PVector(addTime,addTime,addTime);
			animatedArgs.add(PVector.add(a,addTimeV));
		}
		return animatedArgs;
	}

	// CONTROLS

	void addScale(float amount) {
		dna.scale *= amount;
		dna.offset.div(amount);
	}

	void addOffset(float x, float y) {
		dna.offset.add(x,y);
	}

	void mouseMove() {
		PVector relMouse = new PVector((float(mouseX)-x)*g_scale,1-(float(mouseY)-y)*g_scale);
		PVector relPMouse = new PVector((float(pmouseX)-x)*g_scale,1-(float(pmouseY)-y)*g_scale);
		dna.offset.add(PVector.sub(relPMouse,relMouse));
	}

	// SERVICE

	float[] argsToFloat(ArrayList<PVector> args) {
		float[] temp = new float[args.size()*3];
		for (int i = 0; i < args.size(); i++) {
			temp[i*3] = args.get(i).x;
			temp[i*3+1] = args.get(i).y;
			temp[i*3+2] = args.get(i).z;
		}
		return temp;
	}

	// EXPORTING

	boolean render(String path) {
		update(0,0,renderer.width,renderer.height,renderer.height);

		setShader(renderer);

		renderer.beginDraw();
		renderer.shader(shader);
		renderer.rect(0,0,renderer.width,renderer.height);
		renderer.endDraw();
		resetShader();
		// PGraphics.save() may be asynchronous; encoding needs complete files.
		return renderer.get().save(path);
	}

	boolean export(String path) {
		PGraphics export = createExportGraphics(app.expSize);
		update(0,0,app.expSize,app.expSize,app.expSize);

		setShader(export);

		export.beginDraw();
		export.shader(shader);
		export.rect(0,0,app.expSize,app.expSize);
		export.endDraw();
		resetShader();
		return export.get().save(path);
	}

	void export() {
		java.nio.file.Path output = null;
		boolean saved = false;
		try {
			output = reserveOutput(false);
			saved = export(output.toString());
			if (saved) println("Image saved: " + output);
			else println("Could not save image: " + output);
		} catch (Exception error) {
			println("Image export failed: " + error.getMessage());
		} finally {
			if (!saved && output != null) {
				try {
					java.nio.file.Files.deleteIfExists(output);
				} catch (IOException error) {
					println("Could not remove incomplete image: " + output);
				}
			}
		}
	}
}
