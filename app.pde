import controlP5.*;
ControlP5 cp5time;
ControlP5 cp5gen;
ControlP5 cp5main;
ControlP5 cp5back;

ControlP5 selectButtons;

class App {
	Pop pop;
	int aa = 1;
	int expSize = 1000;
	float initialScale = 0;

	int lastSel = -1;
	
	int popRow;
	int popSize;
	int requestedPopRow = -1;
	int genSize;

	boolean goSingle = false;
	int inputWidth = -1;
	int inputHeight = -1;
	boolean inputFocused = true;
	PGraphics inputGraphics;
	int inputGraphicsWidth = -1;
	int inputGraphicsHeight = -1;
	boolean pointerGestureActive = false;
	boolean resizeInputPending = false;
	int lastResizeInputTime;

	NodeDisplay nd = new NodeDisplay();
	GeneControls geneControls;

	float mutationRate = 100;

	// TIME

	float appTime = 0;
	float timeFreq = 60;
	boolean timeRun = false;

	// RENDERING

	boolean isRender;
	int renderFrameCount = 0;
	int renderID;

	// general

	String view = "GRID";
	String uiview = "GENERAL";

	int focusedId;
	boolean isFocused = false;

	int lastIdPressed = -1;
	
	// // GridView

	PVector[] gridPos;
	PVector gridScale;

	// LAYOUT

	float generalMargin = 20;
	float gridMargin = 10;

	float separatorWidth = 10;
	float separator = (float) height/width;
	boolean separatorIsMoving = false;
	float separatorLimitMin = 0.2;
	float separatorLimitMax = 0.8;

	PVector displaySize;
	PVector uiPos;
	PVector uiSize;

	int uiblock = 10;


	color mainColor = color(155,0,255);
	color mainColorOver = color(187,77,255);
	color mainColorDown = color(93,0,158);

	color grayNormal = color(120);
	color grayNormalOver = color(150);
	color grayNormalDown = color(100);
	color grayDark = color(33);

	// Slider fill color, independent of button colors (grayscale or RGB).
	color sliderColor = color(66);
	color sliderTextColor = color(255);
	color sliderBackgroundColor = color(33);
	color sliderBackgroundHoverColor = color(44);
	color sliderForegroundHoverColor = color(88);

	// Border color for all UI group boxes (grayscale or RGB).
	color uiGroupBorderColor = color(33);

	// BUTTONS UI

	PVector[] timeRect;
	Button bTimePlay;
	Button bTimePause;
	Button bTimeStop;
	Slider sTimeFreq;
	Slider sTimePos;
	Textlabel tTime;

	PVector[] genRect;
	Button bGenPlus;
	Button bGenMinus;
	Button bGenBack;
	Button bGenFov;
	Button bGenExp;
	Button bGenRen;
	Textlabel tPopSize;
	Textlabel tGenNum;
	PVector[] genMutRect;
	Slider sExpSize;
	Slider sInitialScale;
	Slider sDepthMax;
	Slider sWidthMax;
	Slider sMutationRate;

	PVector[] mainRect;
	Button bMainEvolve;
	Button bMainAgain;
	Button bMainNew;
	Button bShaderView;
	Button bBack;

	ArrayList<Button> selButs = new ArrayList<Button>();

	PFont font = createFont("font.ttf", uiblock+2);
	PFont fontbig = createFont("font.ttf", (uiblock*2+2));
	// ControlP5 must use logical text sizes, not the Retina glyph texture size.
	ControlFont controlFont = new ControlFont(font, uiblock+2);
	ControlFont controlFontBig = new ControlFont(fontbig, uiblock*2+2);

	App() {
		loadProbabilityDefaults(this);
		pop = new Pop(this);
		setPopSize(5);
		controls();
		geneControls = new GeneControls(this);
	}

	void run() {
		if (requestedPopRow != -1) {
			int nextRow = requestedPopRow;
			requestedPopRow = -1;
			setPopSize(nextRow);
			lastIdPressed = -1;
			isFocused = false;
			focusedId = min(focusedId, popSize-1);
			if (lastSel >= popSize) {
				lastSel = -1;
				isRender = false;
			}
		}
		refreshWindowInput();
		updateLayout();
		keyIsPressed();
		mouseIsPressed();
		if (view == "GRID") checkArtsFocus();
		displayUI();
		displayPop();
		runTime();
		if (isRender) render();
	}


	void runTime() {
		if (timeRun) {
			appTime += (float) 1 / timeFreq / 60;
			sTimePos.setValue(appTime);
			if (appTime >= 1) {
				appTime = 0;
				sTimePos.setValue(appTime);
				if (isRender) {
					isRender = false;
					actionTimeStop();
				}
			}
		}
	}

	void render() {
		pop.arts.get(lastSel).render("renders/render"+renderID+"/frame"+renderFrameCount+".jpg");
		renderFrameCount++;
	}

	void beginRender() {
		
		renderer = createExportGraphics(expSize);

		appTime = 0;
		renderFrameCount = 0;
		renderID = (int) random(99999);
		isRender = true;
		actionTimePlay();
	}




	void setPopSize(int n) {
		pop.setPopSize(n);
		popRow = n;
		popSize = n*n;
	}

	void randomPop() {
		pop.randomPop();
	}

	float shaderScaleValue() {
		return pow(2, initialScale) * 0.5;
	}

	void updateShaderScale(float value) {
		float nextScale = constrain(value, -5, 5);
		// ControlP5 can rebroadcast a value during layout; only apply changes.
		if (nextScale == initialScale) return;
		initialScale = nextScale;
		for (Artwork artwork : pop.arts) {
			artwork.dna.scale = shaderScaleValue();
		}
	}

	// DISPLAY POP

	void displayPop() {
		if (view == "SINGLE") displaySingleView();
		if (view == "GRID") displayGridView();
	}

	void displaySingleView() {
		pop.display(focusedId, 0, 0, displaySize.x, displaySize.y);
	}

	void displayGridView() {
		for (int i = 0; i < pop.arts.size(); i++) {
			pop.display(i, gridPos[i].x, gridPos[i].y, gridScale.x, gridScale.y);
		}
		displayStroke();
	}

	void displayStroke() {
		pushStyle();
		noFill();
		for (int i = 0; i < popSize; i++) {
			if (pop.arts.get(i).isSelected) {
				if (i == focusedId) stroke(mainColorOver);
				else stroke(mainColor);
				strokeWeight(3);
			} else if (isFocused && i == focusedId) {
				stroke(150);
				strokeWeight(3);

			} else {
				strokeWeight(1);
				stroke(77);
			}
			rect(gridPos[i].x, gridPos[i].y, gridScale.x, gridScale.y);
		}
		popStyle();
	}

	// UPDATE LAYOUT

	void windowResized() {
		// A title-bar zoom can finish after Processing updates width/height.
		// Refresh the UI bounds again once the resize events have settled.
		resizeInputPending = true;
		lastResizeInputTime = millis();
	}

	void refreshWindowInput() {
		boolean resized = inputWidth != width || inputHeight != height;
		boolean graphicsChanged = inputGraphics != g || inputGraphicsWidth != g.width || inputGraphicsHeight != g.height;
		boolean focusChanged = inputFocused != focused;
		inputFocused = focused;
		if (resized || graphicsChanged) windowResized();
		boolean resizeSettled = resizeInputPending && millis()-lastResizeInputTime >= 150 && !pointerGestureActive;
		if (resizeSettled) {
			resizeInputPending = false;
		}
		boolean recoverInput = resized || graphicsChanged || focusChanged || resizeSettled;

		inputWidth = width;
		inputHeight = height;
		inputGraphics = g;
		inputGraphicsWidth = g.width;
		inputGraphicsHeight = g.height;
		if (recoverInput) {
			separatorIsMoving = false;
			lastIdPressed = -1;
			isFocused = false;
			pointerGestureActive = false;
		}

		ControlP5[] windows = {cp5time, cp5gen, cp5main, cp5back, selectButtons};
		for (ControlP5 controls : windows) {
			// The OpenGL surface and sketch dimensions can update on different
			// frames. Refresh ControlP5's hit bounds when either changes.
			if (resized || graphicsChanged || resizeSettled) controls.setGraphics(sketchRef, 0, 0);
			if (recoverInput) {
				// Cancel stale input only when the window changes. Releasing on
				// idle frames interferes with ControlP5's normal button clicks.
				boolean wasVisible = controls.isVisible();
				controls.setBroadcast(false);
				try {
					controls.show();
					controls.getPointer().set(-1, -1).released();
					controls.getWindow().resetMouseOver();
				} finally {
					controls.setVisible(wasVisible);
					controls.setBroadcast(true);
				}
			}
			// Keep hover coordinates current independently of CP5's event cache.
			controls.getPointer().set(mouseX, mouseY);
		}
	}

	void updateLayout() {

		if (goSingle) {
			view = "GRID";
			goSingle = false;
		}

    separatorLimitMin = (float) 200/width;
    separatorLimitMax = 1-(float) 360/width;;


		displaySize = new PVector(separator*width, height);
		uiPos = new PVector(separator*width + separatorWidth + generalMargin, generalMargin);
		uiSize = new PVector(width-uiPos.x-generalMargin, height-generalMargin*2);
		countGrid();
		syncSelectionButtons();
		updateControls();
	}

	void countGrid() {
		gridPos = new PVector[popSize];
		gridScale = new PVector((displaySize.x-generalMargin*2+gridMargin)/popRow - gridMargin, (displaySize.y-generalMargin*2+gridMargin)/popRow - gridMargin);
		int count = 0;
		for (int iy = 0; iy < popRow; iy++) {
			for (int ix = 0; ix < popRow; ix++) {

				gridPos[count] = new PVector( (generalMargin) + ix*(gridScale.x+gridMargin), (generalMargin) + iy*(gridScale.y+gridMargin));
				count++;

			}
		}
	}

	void updateControls() {
		updateTimeBlock();
		updateGenBlock();
		updateMainBlock();
		updateSelButs();
		for (Slider slider : new Slider[] {sTimeFreq, sTimePos, sExpSize, sInitialScale}) {
			styleSlider(slider);
		}
	}

	void styleSlider(Slider slider) {
		boolean hovered = slider.isMouseOver();
		slider.setColorBackground(hovered ? sliderBackgroundHoverColor : sliderBackgroundColor)
			.setColorForeground(hovered ? sliderForegroundHoverColor : sliderColor)
			.setColorActive(sliderForegroundHoverColor);
		slider.getCaptionLabel().setColor(sliderTextColor);
		slider.getValueLabel().setColor(sliderTextColor);
	}

	void displayUI() {
    geneControls.layout(view == "GRID" && !isFocused && lastSel == -1,
      uiPos.x, uiPos.y, uiSize.x, max(1, uiSize.y-uiblock*25));
		displaySeparator();
		displayGeneral();

		if (view == "SINGLE") {
			cp5back.show();
		} else {
			cp5back.hide();
		}

		if (view == "SINGLE") {
			float graphHeight = max(1, uiSize.y-uiblock*30);
			nd.display(pop.arts.get(focusedId).dna, uiPos.x, uiPos.y, uiSize.x, graphHeight);

			pushStyle();
			stroke(uiGroupBorderColor);
			noFill();
			rect(uiPos.x, uiPos.y, uiSize.x, graphHeight);
			popStyle();



		} else if (isFocused) {
			pop.display(focusedId, uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*27);
			pushStyle();
			stroke(uiGroupBorderColor);
			noFill();
			rect(uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*27);
			popStyle();
		} else if (lastSel != -1) {
			pop.display(lastSel, uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*27);
			pushStyle();
			stroke(uiGroupBorderColor);
			noFill();
			rect(uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*27);
			popStyle();
		} else {
			geneControls.display();
		}
	}

	void displaySeparator() {
		pushStyle();
		if (mouseOver(separator,0,separatorWidth,height)) fill(55);
		else fill(44);
		noStroke();
		rect(separator*width,0,separatorWidth,height);
		popStyle();
	}

	void displayGeneral() {
		displayTime();
		displayGeneBlock();
		displayMainBlock();
		displayButtons();
	}

	void displayTime() {
		pushStyle();
		noFill();
		stroke(uiGroupBorderColor);
		rect(timeRect[0].x,timeRect[0].y,timeRect[1].x,timeRect[1].y);
		popStyle();

		sTimePos.setValue(appTime);
		tTime.setText("time "+(float) round(timeFreq*10)/10+"s");
	}

	void displayMainBlock() {
		pushStyle();
		noFill();
		stroke(uiGroupBorderColor);
		rect(mainRect[0].x,mainRect[0].y,mainRect[1].x,mainRect[1].y);
		popStyle();
	}

	void displayGeneBlock() {
		pushStyle();
		noFill();
		stroke(uiGroupBorderColor);
		rect(genRect[0].x,genRect[0].y,genRect[1].x,genRect[1].y);
		popStyle();

		tPopSize.setText("NUM: "+popSize);
		tGenNum.setText("AA: "+aa);
		sExpSize.setLabel("res "+expSize);
		sInitialScale.setLabel("scale "+nf(initialScale, 1, 1));
	}

	void syncSelectionButtons() {
		while (selButs.size() < popSize) {
			selButs.add(addBut(selButs.size()));
		}
		while (selButs.size() > popSize) {
			selButs.remove(selButs.size()-1).remove();
		}
	}

	void displayButtons() {
		for (int i = 0; i < popSize; i++) {
			if (isFocused && focusedId == i && view == "GRID") {
				selButs.get(i).show();
			} else {
				selButs.get(i).hide();	
			}
		}
	}








	boolean isAnySelected() {
		for (int i = 0; i < pop.arts.size(); i++) {
			Artwork a = pop.arts.get(i);
			if (a.isSelected) {
				return true;
			}
		}
		return false;
	}

	// Population control


	Button addBut(int n) {
		Button temp = selectButtons.addButton("baton"+n);
		temp.setSize(uiblock*2,uiblock*2);

		temp.plugTo(this)
		.setId(n)
		.setLabelVisible(false)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver);
		return temp;
	}

	void selButAction(int n) {
		if (!pop.arts.get(n).isSelected) {
			selButs.get(n).setColorBackground(mainColor)
			.setColorActive(mainColorDown) 
			.setColorForeground(mainColorOver);
			pop.arts.get(n).isSelected = true;

			lastSel = n;

		} else {
			selButs.get(n).setColorBackground(grayNormal)
			.setColorActive(grayNormalDown) 
			.setColorForeground(grayNormalOver);
			pop.arts.get(n).isSelected = false;

			lastSel = -1;
		}

		if (view == "SINGLE") {
			lastSel = focusedId;
		}

		if (isAnySelected()) {
			bMainEvolve
				.setColorBackground(mainColor)
				.setColorActive(mainColorOver) 
				.setColorForeground(mainColorDown)
					.getCaptionLabel()
					.setColor(color(255));
		} else {
			bMainEvolve
				.setColorBackground(grayDark)
				.setColorActive(grayDark) 
				.setColorForeground(grayDark)
					.getCaptionLabel()
					.setColor(grayNormalDown);
		}
	}



	void increasePop() {
		// Keep the current grid intact until the next draw begins.
		requestedPopRow = (requestedPopRow == -1 ? popRow : requestedPopRow)+1;

		bGenMinus
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver);

	}

	void decreasePop() {
		requestedPopRow = max(1, (requestedPopRow == -1 ? popRow : requestedPopRow)-1);
		if (requestedPopRow <= 1){
			bGenMinus
			.setColorBackground(grayDark)
			.setColorActive(grayDark)
			.setColorForeground(grayDark);

		}
	}

	// Population Display







	// // Population Display Layout


	void separatorMove() {
		separator = (mouseX-separatorWidth/2)/width;
		if (separator < separatorLimitMin) separator = separatorLimitMin;
		if (separator > separatorLimitMax) separator = separatorLimitMax;
	}



	// Population Grid UI

	void checkArtsFocus() {
		isFocused = false;
		if (!focused || gridPos == null) return;
		int count = min(pop.arts.size(), min(gridPos.length, selButs.size()));
		for (int i = 0; i < count; i++) {
			if (mouseOver(gridPos[i].x-gridMargin/2-1, gridPos[i].y-gridMargin/2-1, gridScale.x+gridMargin+2, gridScale.y+gridMargin+2)) {
				isFocused = true;
				focusedId = i;
			}
		}
	}

	// UI display






	// Global UI Events

	void mousePressed() {
		pointerGestureActive = true;
		lastIdPressed = -1;
		if (view == "GRID") checkArtsFocus();
		if (mouseOver(separator*width,0, separatorWidth, height)) separatorIsMoving = true;
		if (view == "GRID" && isFocused && !selButs.get(focusedId).isMouseOver()) {
			lastIdPressed = focusedId;
			lastSel = focusedId;
		}
	}

	void mouseIsPressed() {
		if (!pointerGestureActive || !mousePressed) {
			separatorIsMoving = false;
			return;
		}
		if (mousePressed) {
			if (view == "SINGLE" && mouseOver (0,0,displaySize.x,displaySize.y)) {
				pop.arts.get(focusedId).mouseMove();
			}

			if (separatorIsMoving) separatorMove();

			if (view == "GRID") {
				checkArtsFocus();
			}
		}
	}

	void mouseReleased() {
		pointerGestureActive = false;
		if (view == "GRID") checkArtsFocus();
		if (view == "GRID" && isFocused && lastIdPressed == focusedId &&
			!selButs.get(focusedId).isMouseOver()) {
			developImage(focusedId);
		}
		lastIdPressed = -1;

		if (separatorIsMoving) separatorIsMoving = false;
	}

	void developImage(int index) {
		for (int i = 0; i < pop.arts.size(); i++) {
			pop.arts.get(i).isSelected = i == index;
		}
		pop.evolve();
		lastSel = index;
		focusedId = index;
	}

	void mouseMoved() {
		if (view == "GRID") {
			checkArtsFocus();
		}
	}

	void keyPressed() {
		if (key == ' ') {
			pop.randomPop();
		}

		if (key == BACKSPACE) {
			view = "GRID";
		}

		if (key == 's') {
			pop.arts.get(focusedId).export();
		}

		if (key == 'r') {

		}

		if (key == 'm') {
		}

		if (key == 'n') {
		}

		if (key == 'c') {
			pop.arts.get(focusedId).isSelected = !pop.arts.get(focusedId).isSelected;
		}

		if (key == 'x') {
			pop.evolve();
		}

		if (key == 't') {
			appTime = 0;
			timeRun = !timeRun;
		}

		if (key == '1') aa = 1;
		if (key == '2') aa = 2;
		if (key == '3') aa = 3;
		if (key == '4') aa = 4;
		if (key == '5') aa = 5;
		if (key == '6') aa = 6;

	}
		
	void keyReleased() {

	}

	void keyIsPressed() {
		if (keyPressed) {

		if (key == CODED && keyCode == UP) {
			pop.arts.get(focusedId).addOffset(0,0.05);
		}
		
		if (key == CODED && keyCode == DOWN) {
			pop.arts.get(focusedId).addOffset(0,-0.05);
		}
		
		if (key == CODED && keyCode == LEFT) {
			pop.arts.get(focusedId).addOffset(-0.05,0);
		}
		
		if (key == CODED && keyCode == RIGHT) {
			pop.arts.get(focusedId).addOffset(0.05,0);
		}

		if (keyPressed && key == 'z') {
			pop.arts.get(focusedId).addScale(1.05);
		}

		if (keyPressed && key == 'a') {
			pop.arts.get(focusedId).addScale(0.95);
		}

		}
	}










	void updateTimeBlock() {
		timeRect = new PVector[] {
			new PVector((int) uiPos.x, (int) uiPos.y+uiSize.y-uiblock*6),
			new PVector((int) uiSize.x, (int) uiblock*6)
		};

		bTimePlay.setPosition((int) uiPos.x + uiblock*1, (int) uiPos.y+uiSize.y-uiblock-uiblock*2)
			.setSize(uiblock*2,uiblock*2);
		bTimePause.setPosition((int) uiPos.x + uiblock*4, (int) uiPos.y+uiSize.y-uiblock-uiblock*2)
			.setSize(uiblock*2,uiblock*2);
		bTimeStop.setPosition((int) uiPos.x + uiblock*7, (int) uiPos.y+uiSize.y-uiblock-uiblock*2)
			.setSize(uiblock*2,uiblock*2);

		sTimeFreq.setPosition((int) uiPos.x + uiblock*10, (int) uiPos.y+uiSize.y-uiblock-uiblock*4)
			.setSize((int) uiSize.x-uiblock-uiblock*10, (int) uiblock*1);
		sTimePos.setPosition((int) uiPos.x + uiblock*10, (int) uiPos.y+uiSize.y-uiblock-uiblock*2)
			.setSize((int) uiSize.x-uiblock-uiblock*10, (int) uiblock*2);


		tTime.setPosition((int) uiPos.x + uiblock*1 - 3, (int) uiPos.y+uiSize.y-uiblock-uiblock*4 - 4);
	}

	void updateGenBlock() {
		genRect = new PVector[] {
			new PVector((int) uiPos.x, (int) uiPos.y+uiSize.y-uiblock*13),
			new PVector((int) uiSize.x, (int) uiblock*6)
		};

		bGenMinus.setPosition((int) uiPos.x + uiblock, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*3)
			.setSize(uiblock*3,uiblock*2);
		bGenPlus.setPosition((int) uiPos.x + uiblock*5, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*3)
			.setSize(uiblock*3,uiblock*2);
		bGenBack.setPosition((int) uiPos.x + uiblock*9, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*3)
			.setSize(uiblock*3,uiblock*2);
		bGenFov.setPosition((int) uiPos.x + uiblock*13, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*3)
			.setSize(uiblock*3,uiblock*2);
		bGenExp.setPosition((int) uiPos.x + uiblock*17, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*3)
			.setSize((int) abs(uiSize.x-(uiblock*18))/2-uiblock/2,uiblock*2);
		bGenRen.setPosition((int) uiPos.x + uiblock*17 + abs(uiSize.x-(uiblock*18))/2+uiblock/2, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*3)
			.setSize((int) abs(uiSize.x-( uiblock*18))/2-uiblock/2,uiblock*2);

		float settingsX = uiPos.x + uiblock*17;
		float settingsY = uiPos.y + uiSize.y-uiblock*13;
		int settingsWidth = max(1, int((uiSize.x-uiblock*18)/2));
		sExpSize.setPosition(settingsX, settingsY+4)
			.setSize(max(1, settingsWidth-uiblock), 22);
		sInitialScale.setPosition(settingsX+settingsWidth, settingsY+4)
			.setSize(max(1, settingsWidth-uiblock), 22);
		// Native slider sizing resets caption alignment; restore it afterward.
		for (Slider slider : new Slider[] {sExpSize, sInitialScale}) {
			slider.getCaptionLabel().align(ControlP5.CENTER, ControlP5.CENTER).setPadding(0, 0);
			slider.getValueLabel().setVisible(false);
		}

		tPopSize.setPosition((int) uiPos.x + uiblock -3, (int) uiPos.y+uiSize.y-uiblock*13+uiblock-4);
		tGenNum.setPosition((int) uiPos.x + uiblock*9 -3, (int) uiPos.y+uiSize.y-uiblock*13+uiblock-4);
	}

	void updateMainBlock() {
		mainRect = new PVector[] {
			new PVector((int) uiPos.x, (int) uiPos.y+uiSize.y-uiblock*24),
			new PVector((int) uiSize.x, (int) uiblock*10)
		};
		Slider[] limitSliders = {sDepthMax, sWidthMax, sMutationRate};
		int limitWidth = max(1, int((uiSize.x-50)/4));
		for (int i = 0; i < limitSliders.length; i++) {
			Slider slider = limitSliders[i];
			slider.setPosition(uiPos.x+10+i*(limitWidth+10), uiPos.y+uiSize.y-230)
				.setSize(limitWidth, 22);
			slider.getCaptionLabel().align(ControlP5.LEFT, ControlP5.CENTER).setPadding(5, 0);
			slider.getValueLabel().align(ControlP5.RIGHT, ControlP5.CENTER).setPadding(9, 0).setVisible(true);
			styleSlider(slider);
		}
		updateLimitLabels();
		bShaderView.setPosition(uiPos.x+10+3*(limitWidth+10), uiPos.y+uiSize.y-230)
			.setSize(limitWidth, 22);
		boolean canView = view == "SINGLE" || (lastSel >= 0 && lastSel < pop.arts.size());
		bShaderView.setLock(!canView)
			.setColorBackground(view == "SINGLE" ? grayNormalDown : (canView ? grayNormal : grayDark))
			.setColorActive(canView ? grayNormalDown : grayDark)
			.setColorForeground(canView ? grayNormalOver : grayDark);
		bShaderView.getCaptionLabel().setColor(canView ? color(255) : grayNormalDown);

		boolean selected = isAnySelected();
		bMainEvolve.setColorBackground(selected ? mainColor : grayDark)
			.setColorActive(selected ? mainColorOver : grayDark)
			.setColorForeground(selected ? mainColorDown : grayDark);
		bMainEvolve.getCaptionLabel().setColor(selected ? color(255) : grayNormalDown);

		int mid = (int) (uiSize.x - uiblock*4)/3;

		bMainEvolve.setPosition(int(uiPos.x + uiblock), (int) uiPos.y+uiSize.y-uiblock*19)
			.setSize(mid, uiblock*4);
		bMainAgain.setPosition(int(uiPos.x + uiSize.x/2 - mid/2), (int) uiPos.y+uiSize.y-uiblock*19)
			.setSize(mid, uiblock*4);
		bMainNew.setPosition(int(uiPos.x + uiSize.x - mid - uiblock), (int) uiPos.y+uiSize.y-uiblock*19)
			.setSize(mid, uiblock*4);

		bBack.setPosition(int(uiPos.x), (int) uiPos.y+uiSize.y-uiblock*29)
			.setSize((int) uiSize.x, uiblock*4);




		if (pop.lastPool.size() > 0) {
			bMainAgain
				.setColorBackground(grayNormal)
				.setColorActive(grayNormalDown) 
				.setColorForeground(grayNormalOver)
				.getCaptionLabel()
				.setColor(color(255))
				.setFont(controlFontBig);	
		} else {
			bMainAgain
				.setColorBackground(grayDark)
				.setColorActive(grayDark) 
				.setColorForeground(grayDark)
					.getCaptionLabel()
					.setColor(grayNormalDown);
		}
		
	}

	Slider addLimitSlider(String name, String label, float low, float high, float value) {
		Slider slider = cp5time.addSlider(name);
		slider.setBroadcast(false);
		slider.setRange(low, high).setValue(value).setScrollSensitivity(0).setLabel(label);
		slider.getCaptionLabel().setFont(controlFont);
		slider.getValueLabel().setFont(controlFont);
		styleSlider(slider);
		slider.setBroadcast(true);
		return slider;
	}

	void updateLimitLabels() {
		sDepthMax.getValueLabel().setText(str(depth_max));
		sWidthMax.getValueLabel().setText(str(width_max));
		sMutationRate.getValueLabel().setText(str(round(mutationRate)));
	}

	void changeLimit(String name, float value) {
		if (name.equals("limit_depth_max")) depth_max = max(3, round(value));
		if (name.equals("limit_width_max")) {
			width_max = max(3, round(value));
		}
		updateLimitLabels();
	}

	void updateSelButs() {
		for (int i = 0; i < selButs.size(); i++) {
			if (i < popSize) {
				selButs.get(i).setPosition((int) gridPos[i].x + uiblock, (int) gridPos[i].y + gridScale.y - uiblock*3);
				boolean selected = pop.arts.get(i).isSelected;
				selButs.get(i).setColorBackground(selected ? mainColor : grayNormal)
					.setColorActive(selected ? mainColorDown : grayNormalDown)
					.setColorForeground(selected ? mainColorOver : grayNormalOver);
			}
		}
	}















	void controls() {

		cp5time = new ControlP5(sketchRef);

		bTimePlay = cp5time.addButton("actionTimePlay");
		bTimePlay.setLabelVisible(true)
		.setLabel(">")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);

		bTimePause = cp5time.addButton("actionTimePause");
		bTimePause.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
		.setLabel("||")
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);
		bTimePause.setLabelVisible(true);

		bTimeStop = cp5time.addButton("actionTimeStop");
		bTimeStop.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
		.setLabel("x")
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);
		bTimeStop.setLabelVisible(true);

		sTimeFreq = cp5time.addSlider("timeFreq")
		.setScrollSensitivity(0)
		.plugTo(this)
		.setRange(0.5,60)
		.setValue(5)
		.setLabelVisible(false)
		.setColorActive(sliderColor)
		.setColorBackground(grayDark)
		.setColorForeground(sliderColor);
		sTimePos = cp5time.addSlider("appTime")
		.setScrollSensitivity(0)
		.plugTo(this)
		.setLabelVisible(false)
		.setRange(0,1)
		.setValue(0)
		.setColorActive(sliderColor)
		.setColorBackground(grayDark)
		.setColorForeground(sliderColor);

		tTime = cp5time.addTextlabel("timelabel").setFont(controlFont).setColor(grayNormal);




		selectButtons = new ControlP5(sketchRef);

		cp5gen = new ControlP5(sketchRef);
		cp5back = new ControlP5(sketchRef);

		bGenPlus = cp5time.addButton("actionGenPlus");
		bGenPlus.setLabelVisible(true)
		.setLabel("+")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);
		bGenMinus = cp5time.addButton("actionGenMinus");
		bGenMinus.setLabelVisible(true)
		.setLabel("-")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);
		bGenBack = cp5time.addButton("actionAAm");
		bGenBack.setLabelVisible(true)
		.setLabel("-")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);		
		bGenFov = cp5time.addButton("actionAAp");
		bGenFov.setLabelVisible(true)
		.setLabel("+")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);
		bGenExp = cp5time.addButton("actionExp");
		bGenExp.setLabelVisible(true)
		.setLabel("SAVE IMAGE")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);		
		bGenRen = cp5time.addButton("actionRen");
		bGenRen.setLabelVisible(true)
		.setLabel("SAVE VIDEO")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(controlFont);

		sExpSize = cp5time.addSlider("expSize")
		.setScrollSensitivity(0)
		.plugTo(this)
		.setRange(500,4000)
		.setValue(expSize)
		.setLabel("res")
		.setLabelVisible(true)
		.setColorActive(sliderColor)
		.setColorBackground(grayDark)
		.setColorForeground(sliderColor);

		sInitialScale = cp5time.addSlider("initialScale")
		.setScrollSensitivity(0)
		.setRange(-5,5)
		.setValue(initialScale)
		.setLabel("scale")
		.setLabelVisible(true)
		.setColorActive(sliderColor)
		.setColorBackground(grayDark)
		.setColorForeground(sliderColor);

		sExpSize.getCaptionLabel().setFont(controlFont);
		sInitialScale.getCaptionLabel().setFont(controlFont);
		sDepthMax = addLimitSlider("limit_depth_max", "depth", 3, 32, depth_max);
		sWidthMax = addLimitSlider("limit_width_max", "width", 3, 32, width_max);
		sMutationRate = addLimitSlider("mutationRate", "mut", 0, 2000, mutationRate);
		sMutationRate.plugTo(this);

		tGenNum = cp5time.addTextlabel("genenum").setFont(controlFont).setColor(grayNormal);
		tPopSize = cp5time.addTextlabel("genepopsize").setFont(controlFont).setColor(grayNormal);



		cp5main = new ControlP5(sketchRef);
		bShaderView = cp5time.addButton("actionShaderView");
		bShaderView.setLabelVisible(true)
			.setLabel("graph")
			.plugTo(this)
			.setColorBackground(grayNormal)
			.setColorActive(grayNormalDown)
			.setColorForeground(grayNormalOver);
		bShaderView.getCaptionLabel().setColor(color(255)).setFont(controlFont)
			.align(ControlP5.CENTER, ControlP5.CENTER);

		bMainEvolve = cp5time.addButton("actionMainEvolve");
		bMainEvolve.setLabelVisible(true)
		.setLabel("develop")
		.plugTo(this)
		.setColorBackground(grayDark)
		.setColorActive(grayDark) 
		.setColorForeground(grayDark)
			.getCaptionLabel()
			.setColor(grayNormalDown)
			.setFont(controlFontBig);
		bMainAgain = cp5time.addButton("actionMainAgain");
		bMainAgain.setLabelVisible(true)
		.setLabel("repeat")
		.plugTo(this)
		.setColorBackground(grayDark)
		.setColorActive(grayDark) 
		.setColorForeground(grayDark)
			.getCaptionLabel()
			.setColor(grayNormalDown)
			.setFont(controlFontBig);
		bMainNew = cp5time.addButton("actionMainNew");
		bMainNew.setLabelVisible(true)
		.setLabel("new")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(color(255))
			.setFont(controlFontBig);		



		bBack = cp5back.addButton("actionBack");
		bBack.setLabelVisible(true)
		.setLabel("back")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(color(255))
			.setFont(controlFontBig);		

	}



	/////////// ACTIONS

	void actionShaderView() {
		goSingle = false;
		lastIdPressed = -1;
		if (view == "SINGLE") {
			view = "GRID";
		} else if (lastSel >= 0 && lastSel < pop.arts.size()) {
			focusedId = lastSel;
			isFocused = false;
			view = "SINGLE";
		}
	}

	void actionBack() {
		goSingle = true;
	}

	void actionTimePlay() {
		timeRun = true;
		bTimePlay.setColorBackground(mainColor)
		.setColorActive(mainColorDown) 
		.setColorForeground(mainColorOver)
		.getCaptionLabel()
			.setColor(grayNormalOver);

	}

	void actionTimePause() {
		timeRun = false;
		bTimePlay.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
		.getCaptionLabel()
			.setColor(grayDark);
	}

	void actionTimeStop() {
		timeRun = false;
		appTime = 0;
		bTimePlay.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
		.getCaptionLabel()
			.setColor(grayDark);
	}

	void actionGenPlus() {
		increasePop();
	}

	void actionGenMinus() {
		decreasePop();
	}

	void actionAAm() {
		if (aa > 1) aa--;
	}	

	void actionAAp() {
		if (aa < 16) aa++;
	}

	void actionExp() {
		if (lastSel >= 0) {
			pop.arts.get(lastSel).export();
		}
	}

	void actionRen() {
			if (isRender || lastSel == -1) isRender = false;
			else beginRender();
	}

	void actionMainNew() {
		randomPop();

    lastSel = -1;

		bMainEvolve
			.setColorBackground(grayDark)
			.setColorActive(grayDark) 
			.setColorForeground(grayDark)
				.getCaptionLabel()
				.setColor(grayNormalDown);



	}

	void actionMainEvolve() {
		if (isAnySelected()) {
			pop.evolve();
			lastSel = pop.lastParentIndex;
		}
	}

	void actionMainAgain() {
		pop.evolveAgain();
		lastSel = pop.lastParentIndex;
	}



}

void controlEvent(ControlEvent theEvent) {
  if (theEvent.isController()) {
    if (theEvent.controller().getName().equals("saveProbabilityDefaults")) {
      if (app != null && app.geneControls != null) app.geneControls.saveDefaults();
      return;
    }
    if (theEvent.controller().getName().startsWith("limit_")) {
      if (app != null) app.changeLimit(theEvent.controller().getName(), theEvent.controller().getValue());
      return;
    }
    if (theEvent.controller().getName().equals("initialScale")) {
      if (app != null) app.updateShaderScale(theEvent.controller().getValue());
      return;
    }
    if (theEvent.controller().getName().startsWith("geneProbability")) {
      if (app != null && app.geneControls != null) {
        app.geneControls.change(theEvent.controller().getId(), theEvent.controller().getValue());
      }
      return;
    }
    if (theEvent.controller().getName().startsWith("baton")) {
      int id = theEvent.controller().getId();

        app.selButAction(id);
 
    }
  }
}

boolean mouseOver(float x, float y, float w, float h) {
	return(mouseX > x && mouseX < x+w && mouseY > y && mouseY < y+h);
}
