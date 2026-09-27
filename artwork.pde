class Artwork {
	Pop p;
	int id;

	float x;
	float y;
	float w;
	float h;

	float resolution;
	float g_scale;

	PShader shader;

	boolean isSelected = false;
	
	DNA dna;


	Artwork(Pop p_) {
		p = p_;
		id = p.arts.size()-1;

		x = 0;
		y = 0;
		w = 0;
		h = 0;

	}

	// GENERAL

	void randomDNA() {
		dna = new DNA("RANDOM");
		dna.scale = p.p.shaderScaleValue();
		compileShader();
	}

	void assignDNA(DNA d) {
		dna = d;
		compileShader();
	}

	// RENDERING

	void display(float x_, float y_, float w_, float h_) {
		update(x_,y_,w_,h_);
		setShader(g, x, y, w, h);
		shader(shader);
		rect(x_,y_,w,h);
		resetShader();
	}

	void compileShader() {
		String[] shaderCode = fragmentShader.clone();
		boolean inserted = false;
		for (int i = 0; i < shaderCode.length; i++) {
			if (shaderCode[i].contains("// PIXY_GRAPH")) {
				shaderCode[i] = dna.code;
				inserted = true;
			}
		}
		if (!inserted) throw new IllegalStateException("Missing PIXY_GRAPH shader marker");
		String path = "data/temp/shader"+id;
		saveStrings(path, shaderCode);
		shader = new GeneratedShader(path);
	}

	void setShader(PGraphics target, float drawX, float drawY, float drawWidth, float drawHeight) {
		float coordinateScale = 4 / drawWidth;
		// Convert the rectangle's center to OpenGL's bottom-left origin.
		shader.set("u_g_off", -(drawX+drawWidth/2)*coordinateScale,
			-(target.height-drawY-drawHeight/2)*coordinateScale);
		// Use the actual framebuffer dimensions, not just density metadata.
		float pixelScale = (float) target.pixelWidth / target.width;
		shader.set("u_g_scale", coordinateScale / pixelScale);
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
		w = w_;
		h = h_;
		x = x_;
		y = y_;
		g_scale = 4 / w;
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
		drawExport(renderer);
		renderer.save(path);
	}

	void export(String path) {
		PGraphics export = createExportGraphics(app.expSize);
		drawExport(export);
		export.save(path);
	}

	void drawExport(PGraphics target) {
		// Export coordinates stay independent of the on-screen rectangle used
		// for dragging. The target's size remains fixed for a frame sequence.
		target.beginDraw();
		target.pushStyle();
		target.rectMode(CORNER);
		target.noStroke();
		target.fill(255);
		setShader(target, 0, 0, target.width, target.height);
		target.shader(shader);
		target.rect(0, 0, target.width, target.height);
		target.resetShader();
		target.popStyle();
		target.endDraw();
	}

	void export() {
		export("export/image_"+int(random(999999))+".jpg");
	}
}

class GeneratedShader extends PShader {
	GeneratedShader(String fragmentPath) {
		// Keep Processing's file loader so it adapts GLSL to the active GL version.
		super(sketchRef, "data/vertex.glsl", fragmentPath);
	}

	@Override
	protected void consumeUniforms() {
		// A valid generated graph may not use coordinates, time, or arguments.
		// Check the linked shader, since optimization can remove these uniforms
		// even when their nodes appear in the generated source.
		if (uniformValues != null) {
			java.util.Iterator<String> names = uniformValues.keySet().iterator();
			while (names.hasNext()) {
				if (getUniformLoc(names.next()) < 0) names.remove();
			}
		}
		super.consumeUniforms();
	}
}
