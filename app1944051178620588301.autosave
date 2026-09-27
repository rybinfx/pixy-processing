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

	int lastSel = -1;
	
	int popRow;
	int popSize;
	int genSize;

	boolean goSingle = false;

	NodeDisplay nd = new NodeDisplay();

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

	color grayNormal = color(212);
	color grayNormalOver = color(240);
	color grayNormalDown = color(117);
	color grayDark = color(66);

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
	Textlabel tExpSize;
	Slider sExpSize;

	PVector[] mainRect;
	Button bMainEvolve;
	Button bMainAgain;
	Button bMainNew;
	Button bBack;

	ArrayList<Button> selButs = new ArrayList<Button>();

	PFont font = createFont("font.ttf", uiblock+2);
	PFont fontbig = createFont("font.ttf", (uiblock*2+2));

	App() {
		pop = new Pop(this);
		setPopSize(5);
		controls();
	}

	void run() {
		keyIsPressed();
		mouseIsPressed();
		updateLayout();
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
		
		renderer = createGraphics(expSize,expSize,P2D);

		appTime = 0;
		renderFrameCount = 0;
		renderID = (int) random(99999);
		isRender = true;
		actionTimePlay();
	}




	void setPopSize(int n) {
		popRow = n;
		popSize = n*n;
		pop.setPopSize(n);
	}

	void randomPop() {
		pop.randomPop();
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

	void updateLayout() {

		if (goSingle) {
			view = "GRID";
			goSingle = false;
		}

    separatorLimitMin = (float) 200/width;
    separatorLimitMax = 1-(float) 360/width;;


		cp5time.setGraphics(sketchRef,0,0);
		cp5gen.setGraphics(sketchRef,0,0);
		cp5main.setGraphics(sketchRef,0,0);
		cp5back.setGraphics(sketchRef,0,0);

		selectButtons.setGraphics(sketchRef,0,0);


		displaySize = new PVector(separator*width, height);
		uiPos = new PVector(separator*width + separatorWidth + generalMargin, generalMargin);
		uiSize = new PVector(width-uiPos.x-generalMargin, height-generalMargin*2);
		countGrid();
		updateControls();
		displayUI();
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
	}

	void displayUI() {
		displaySeparator();
		displayGeneral();

		if (view == "SINGLE") {
			cp5back.show();
		} else {
			cp5back.hide();
		}

		if (view == "SINGLE") {
			nd.display(pop.arts.get(focusedId).dna, uiPos.x, uiPos.y, uiSize.x, uiSize.x);

      pushStyle();
      noStroke();
      fill(17,17,17,255);
      rect(uiPos.x, uiPos.y+uiSize.y-uiblock*25, uiSize.x, 512);
      popStyle();

			pushStyle();
			stroke(grayNormal);
			noFill();
			rect(uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*23);
			popStyle();



		} else if (isFocused) {
			pop.display(focusedId, uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*23);
			pushStyle();
			stroke(grayNormal);
			noFill();
			rect(uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*23);
			popStyle();
		} else if (lastSel != -1) {
			pop.display(lastSel, uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*23);
			pushStyle();
			stroke(grayNormal);
			noFill();
			rect(uiPos.x, uiPos.y, uiSize.x, uiPos.y+uiSize.y-uiblock*23);
			popStyle();
		} else {
			pushStyle();
			fill(240);
			textFont(font);
			text(textGreet,uiPos.x, uiPos.y, uiSize.x-uiblock*4, uiSize.x);
			popStyle();
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
		stroke(grayNormal);
		rect(timeRect[0].x,timeRect[0].y,timeRect[1].x,timeRect[1].y);
		popStyle();

		sTimePos.setValue(appTime);
		tTime.setText("time "+(float) round(timeFreq*10)/10+"s");
	}

	void displayMainBlock() {
		pushStyle();
		noFill();
		stroke(grayNormal);
		rect(mainRect[0].x,mainRect[0].y,mainRect[1].x,mainRect[1].y);
		popStyle();
	}

	void displayGeneBlock() {
		pushStyle();
		noFill();
		stroke(grayNormal);
		rect(genRect[0].x,genRect[0].y,genRect[1].x,genRect[1].y);
		popStyle();

		tPopSize.setText("NUM: "+popSize);
		tGenNum.setText("AA: "+aa);
		tExpSize.setText("RES: "+expSize+"px");
	}

	void displayButtons() {

		if (selButs.size() < popSize) {
			for (int i = selButs.size(); i < popSize; i++) {
				selButs.add(addBut(i));
			}
		} else if (selButs.size() > popSize) {
			for (int i = 0; i < selButs.size() - popSize; i++) {
				selButs.remove(selButs.size()-1);
			}
		}



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
				lastSel = i;
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
		popRow++;
		setPopSize(popRow);

		bGenMinus
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver);

	}

	void decreasePop() {
		if (popRow > 1) {
			popRow--;
			setPopSize(popRow);		
		} 
		if (popRow <= 1){
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
		for (int i = 0; i < popSize; i++) {
			if (mouseOver(gridPos[i].x-gridMargin/2-1, gridPos[i].y-gridMargin/2-1, gridScale.x+gridMargin+2, gridScale.y+gridMargin+2)) {
				isFocused = true;
				focusedId = i;
			}
		}
	}

	// UI display






	// Global UI Events

	void mousePressed() {
		if (mouseOver(separator*width,0, separatorWidth, height)) separatorIsMoving = true;
		if (isFocused && !selButs.get(focusedId).isMouseOver()) {
			lastIdPressed = focusedId;
			lastSel = focusedId;
		}
	}

	void mouseIsPressed() {
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
		if (lastIdPressed == focusedId && view != "SINGLE") {
			view = "SINGLE";
		}
		lastIdPressed = -1;

		if (separatorIsMoving) separatorIsMoving = false;
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

		sExpSize.setPosition((int) uiPos.x + uiblock*27, (int) uiPos.y+uiSize.y-uiblock*13+uiblock*1)
			.setSize((int) uiSize.x - uiblock*28, (int) uiblock*1);

		tPopSize.setPosition((int) uiPos.x + uiblock -3, (int) uiPos.y+uiSize.y-uiblock*13+uiblock-4);
		tGenNum.setPosition((int) uiPos.x + uiblock*9 -3, (int) uiPos.y+uiSize.y-uiblock*13+uiblock-4);
		tExpSize.setPosition((int) uiPos.x + uiblock*17 -3, (int) uiPos.y+uiSize.y-uiblock*13+uiblock-4);
	}

	void updateMainBlock() {
		mainRect = new PVector[] {
			new PVector((int) uiPos.x, (int) uiPos.y+uiSize.y-uiblock*20),
			new PVector((int) uiSize.x, (int) uiblock*6)
		};

		int mid = (int) (uiSize.x - uiblock*4)/3;

		bMainEvolve.setPosition(int(uiPos.x + uiblock), (int) uiPos.y+uiSize.y-uiblock*19)
			.setSize(mid, uiblock*4);
		bMainAgain.setPosition(int(uiPos.x + uiSize.x/2 - mid/2), (int) uiPos.y+uiSize.y-uiblock*19)
			.setSize(mid, uiblock*4);
		bMainNew.setPosition(int(uiPos.x + uiSize.x - mid - uiblock), (int) uiPos.y+uiSize.y-uiblock*19)
			.setSize(mid, uiblock*4);

		bBack.setPosition(int(uiPos.x), (int) uiPos.y+uiSize.y-uiblock*25)
			.setSize((int) uiSize.x, uiblock*4);




		if (pop.lastPool.size() > 0) {
			bMainAgain
				.setColorBackground(grayNormal)
				.setColorActive(grayNormalDown) 
				.setColorForeground(grayNormalOver)
				.getCaptionLabel()
				.setColor(color(255))
				.setFont(fontbig);	
		} else {
			bMainAgain
				.setColorBackground(grayDark)
				.setColorActive(grayDark) 
				.setColorForeground(grayDark)
					.getCaptionLabel()
					.setColor(grayNormalDown);
		}
		
	}

	void updateSelButs() {
		for (int i = 0; i < selButs.size(); i++) {
			if (i < popSize) {
				selButs.get(i).setPosition((int) gridPos[i].x + uiblock, (int) gridPos[i].y + gridScale.y - uiblock*3);
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
			.setFont(font);

		bTimePause = cp5time.addButton("actionTimePause");
		bTimePause.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
		.setLabel("||")
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);
		bTimePause.setLabelVisible(true);

		bTimeStop = cp5time.addButton("actionTimeStop");
		bTimeStop.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
		.setLabel("x")
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);
		bTimeStop.setLabelVisible(true);

		sTimeFreq = cp5time.addSlider("timeFreq")
		.plugTo(this)
		.setRange(0.5,60)
		.setValue(5)
		.setLabelVisible(false)
		.setColorActive(grayNormalOver)
		.setColorBackground(grayDark)
		.setColorForeground(grayNormal);
		sTimePos = cp5time.addSlider("appTime")
		.plugTo(this)
		.setLabelVisible(false)
		.setRange(0,1)
		.setValue(0)
		.setColorActive(grayNormal)
		.setColorBackground(grayDark)
		.setColorForeground(grayNormalDown);

		tTime = cp5time.addTextlabel("timelabel").setFont(font).setColor(grayNormal);




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
			.setFont(font);
		bGenMinus = cp5time.addButton("actionGenMinus");
		bGenMinus.setLabelVisible(true)
		.setLabel("-")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);
		bGenBack = cp5time.addButton("actionAAm");
		bGenBack.setLabelVisible(true)
		.setLabel("-")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);		
		bGenFov = cp5time.addButton("actionAAp");
		bGenFov.setLabelVisible(true)
		.setLabel("+")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);
		bGenExp = cp5time.addButton("actionExp");
		bGenExp.setLabelVisible(true)
		.setLabel("SAVE IMAGE")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);		
		bGenRen = cp5time.addButton("actionRen");
		bGenRen.setLabelVisible(true)
		.setLabel("SAVE VIDEO")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(grayDark)
			.setFont(font);

		sExpSize = cp5time.addSlider("expSize")
		.plugTo(this)
		.setRange(500,4000)
		.setValue(expSize)
		.setLabelVisible(false)
		.setColorActive(grayNormalOver)
		.setColorBackground(grayDark)
		.setColorForeground(grayNormal);

		tGenNum = cp5time.addTextlabel("genenum").setFont(font).setColor(grayNormal);
		tPopSize = cp5time.addTextlabel("genepopsize").setFont(font).setColor(grayNormal);
		tExpSize = cp5time.addTextlabel("genemutrate").setFont(font).setColor(grayNormal);



		cp5main = new ControlP5(sketchRef);

		bMainEvolve = cp5time.addButton("actionMainEvolve");
		bMainEvolve.setLabelVisible(true)
		.setLabel("develop")
		.plugTo(this)
		.setColorBackground(grayDark)
		.setColorActive(grayDark) 
		.setColorForeground(grayDark)
			.getCaptionLabel()
			.setColor(grayNormalDown)
			.setFont(fontbig);
		bMainAgain = cp5time.addButton("actionMainAgain");
		bMainAgain.setLabelVisible(true)
		.setLabel("repeat")
		.plugTo(this)
		.setColorBackground(grayDark)
		.setColorActive(grayDark) 
		.setColorForeground(grayDark)
			.getCaptionLabel()
			.setColor(grayNormalDown)
			.setFont(fontbig);
		bMainNew = cp5time.addButton("actionMainNew");
		bMainNew.setLabelVisible(true)
		.setLabel("new")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(color(255))
			.setFont(fontbig);		



		bBack = cp5back.addButton("actionBack");
		bBack.setLabelVisible(true)
		.setLabel("back")
		.plugTo(this)
		.setColorBackground(grayNormal)
		.setColorActive(grayNormalDown) 
		.setColorForeground(grayNormalOver)
			.getCaptionLabel()
			.setColor(color(255))
			.setFont(fontbig);		

	}



	/////////// ACTIONS

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
		}
    lastSel = -1;
	}

	void actionMainAgain() {
		pop.evolveAgain();
	}



}

void controlEvent(ControlEvent theEvent) {
  if (theEvent.isController()) {
    if (theEvent.controller().getName().startsWith("baton")) {
      int id = theEvent.controller().getId();

        app.selButAction(id);
 
    }
  }
}

boolean mouseOver(float x, float y, float w, float h) {
	return(mouseX > x && mouseX < x+w && mouseY > y && mouseY < y+h);
}
