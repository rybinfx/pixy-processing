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
		dna.scale = p.p.initialScale;
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
		// gl_FragCoord uses physical pixels; layout and mouse coordinates do not.
		shader.set("u_g_scale", g_scale / target.pixelDensity);
		shader.set("u_off", dna.offset.x, dna.offset.y);
		shader.set("u_scale", dna.scale);
		shader.set("u_hoff", dna.hueOffset);
		if (!dna.args.isEmpty()) shader.set("u_args", argsToFloat(dna.args));
		if (dna.code.contains("g_time(") || dna.code.contains("g_sintime(")) {
			shader.set("u_time", app.appTime);
		}

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

	void render(String path) {
		update(0,0,app.expSize,app.expSize,app.expSize);

		renderer.beginDraw();
		setShader(renderer);
		renderer.shader(shader);
		renderer.rect(0,0,app.expSize,app.expSize);
		renderer.endDraw();
		renderer.save(path);
		resetShader();
	}

	void export(String path) {
		PGraphics export = createExportGraphics(app.expSize);
		update(0,0,app.expSize,app.expSize,app.expSize);

		export.beginDraw();
		setShader(export);
		export.shader(shader);
		export.rect(0,0,app.expSize,app.expSize);
		export.endDraw();
		export.save(path);
		resetShader();
	}

	void export() {
		export("export/image_"+int(random(999999))+".jpg");
	}
}
