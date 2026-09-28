// The probability page: grouped sliders and a Save button at the end.
final int geneControlRowHeight = 40;

class GeneControls {
  App owner;
  ArrayList<GeneControlGroup> groups = new ArrayList<GeneControlGroup>();
  ArrayList<GeneControl> controls = new ArrayList<GeneControl>();
  float x, y, w, h, scroll, contentHeight;
  boolean visible;
  Button saveButton;
  String saveLabel = "save";
  int saveFeedbackUntil;
  ControlFont probabilityFont;

  GeneControls(App owner_) {
    owner = owner_;
    probabilityFont = new ControlFont(owner.font, owner.uiblock);
    for (GeneValueType valueType : visibleGeneTypes) addGroup(valueType);
    saveButton = cp5time.addButton("saveProbabilityDefaults");
    saveButton.setLabel("save")
      .setColorBackground(owner.grayNormal)
      .setColorForeground(owner.grayNormalOver)
      .setColorActive(owner.grayNormalDown);
    saveButton.getCaptionLabel().setFont(owner.controlFont).setColor(color(255))
      .align(ControlP5.CENTER, ControlP5.CENTER);
    saveButton.hide();
  }

  void addGroup(GeneValueType valueType) {
    GeneControlGroup group = new GeneControlGroup(valueType);
    String[] values = genesReturning(genesValues, valueType);
    String[] functions = genesReturning(geneFunctionPool, valueType);
    group.valueCount = values.length;
    group.functionCount = functions.length;
    addControls(group, values, true);
    addControls(group, functions, false);
    if (!group.controls.isEmpty()) groups.add(group);
  }

  void addControls(GeneControlGroup group, String[] names, boolean valueFamily) {
    for (int i = 0; i < names.length; i++) {
      int id = controls.size();
      Slider slider = cp5time.addSlider("geneProbability"+id);
      slider.setBroadcast(false);
      slider.setId(id).setRange(0, 1).setValue(geneSliderValue(names[i]))
        .setScrollSensitivity(0)
        .setLabel(names[i])
        .setLabelVisible(true);
      owner.styleSlider(slider);
      slider.getCaptionLabel().setFont(owner.controlFont)
        .align(ControlP5.LEFT, ControlP5.CENTER).setPadding(5, 0);
      slider.getValueLabel().setFont(probabilityFont)
        .align(ControlP5.RIGHT, ControlP5.CENTER).setPadding(9, 0).setVisible(true);
      slider.hide();
      slider.setBroadcast(true);
      GeneControl control = new GeneControl(names[i], slider, valueFamily, i);
      controls.add(control);
      group.controls.add(control);
    }
  }

  void layout(boolean show, float px, float py, float pw, float ph) {
    visible = show;
    x = px; y = py; w = pw; h = ph;
    contentHeight = 0;
    for (GeneControlGroup group : groups) contentHeight += group.height()+10;
    contentHeight += 32; // Final group gap, Save button, and bottom padding.
    scroll = constrain(scroll, 0, max(0, contentHeight-h));
    float top = y-scroll;
    float columnWidth = (w-50)/4;
    for (GeneControlGroup group : groups) {
      group.top = top;
      for (GeneControl control : group.controls) {
        int i = control.familyIndex;
        control.x = x+10+(i%4)*(columnWidth+10);
        float familyOffset = control.valueFamily ? 0 : group.valueRows()*geneControlRowHeight+group.dividerHeight();
        control.y = top+26+familyOffset+(i/4)*geneControlRowHeight;
        control.visible = visible && control.y >= y && control.y+30 <= y+h;
        control.slider.setPosition(control.x, control.y+10)
          .setSize(max(1, int(columnWidth)), 20);
        // setSize recreates the native slider view and resets its caption
        // to RIGHT_OUTSIDE. Apply the inside alignment after sizing.
        control.slider.getCaptionLabel()
          .align(ControlP5.LEFT, ControlP5.CENTER).setPadding(5, 0);
        control.slider.getValueLabel().setFont(probabilityFont)
          .align(ControlP5.RIGHT, ControlP5.CENTER).setPadding(9, 0).setVisible(true);
        if (control.visible) control.slider.show();
        else control.slider.hide();
        owner.styleSlider(control.slider);
      }
      top += group.height()+10;
    }
    saveButton.setPosition(x+10, top).setSize(max(1, int(w-20)), 22);
    if (visible && top >= y && top+22 <= y+h) saveButton.show();
    else saveButton.hide();
    if (millis() >= saveFeedbackUntil) saveLabel = "save";
    saveButton.setLabel(saveLabel);
    updatePercentages();
  }

  void saveDefaults() {
    saveLabel = saveProbabilityDefaults(owner) ? "saved" : "save failed";
    saveFeedbackUntil = millis()+2000;
    saveButton.setLabel(saveLabel);
  }

  void updatePercentages() {
    for (GeneControl control : controls) {
      float total = geneWeightTotal(genesReturning(
        control.valueFamily ? genesValues : geneFunctionPool, geneOutputType(control.name)));
      float percent = total > 0 ? 100 * geneProbability(control.name) / total : 0;
      control.slider.getValueLabel().setText(nf(percent, 1, 1)+"%");
    }
  }

  void display() {
    pushStyle();
    textFont(owner.font);
    textAlign(LEFT, BASELINE);
    rectMode(CORNER);
    ellipseMode(CENTER);
    clip(x, y, w, h);
    for (GeneControlGroup group : groups) {
      noFill();
      stroke(geneTypeColor(group.valueType));
      // Keep the full stroke inside the panel's clipping bounds.
      rect(x+1, group.top+1, max(0, w-2), group.height()-2);
      fill(geneTypeColor(group.valueType));
      text(group.title, x+10, group.top+17);
      if (group.dividerHeight() > 0) {
        float dividerY = group.top+26+group.valueRows()*geneControlRowHeight+2;
        stroke(geneTypeColor(group.valueType), 120);
        line(x+10, dividerY, x+w-10, dividerY);
      }
      for (GeneControl control : group.controls) {
        if (!control.visible) continue;
        noStroke();
        for (int i = 0; i < control.inputTypes.length; i++) {
          fill(geneTypeColor(control.inputTypes[i]));
          ellipse(control.x+5+i*9, control.y+4, 5, 5);
        }
      }
    }
    noClip();
    popStyle();
  }

  void change(int id, float value) {
    if (id < 0 || id >= controls.size()) return;
    GeneControl control = controls.get(id);
    float previous = geneSliderValue(control.name);
    geneSliderValues.put(control.name, constrain(value, 0, 1));
    boolean missingValueType = false;
    for (GeneValueType valueType : GeneValueType.values()) {
      String[] values = geneTerminalCandidates(valueType);
      if (values.length > 0 && geneWeightTotal(values) == 0) missingValueType = true;
    }
    if (missingValueType) {
      geneSliderValues.put(control.name, previous);
      control.slider.setBroadcast(false);
      control.slider.setValue(previous);
      control.slider.setBroadcast(true);
    }
    // Native slider updates replace the value label before broadcasting.
    // Restore weighted percentages immediately, including during dragging.
    updatePercentages();
  }

  void wheel(float amount) {
    if (visible && mouseOver(x, y, w, h)) {
      scroll = constrain(scroll+amount*1.0, 0, max(0, contentHeight-h));
    }
  }
}

class GeneControlGroup {
  String title;
  GeneValueType valueType;
  int valueCount, functionCount;
  float top;
  ArrayList<GeneControl> controls = new ArrayList<GeneControl>();

  GeneControlGroup(GeneValueType valueType_) {
    valueType = valueType_;
    title = valueType.toString().toLowerCase();
  }
  int valueRows() { return (valueCount+3)/4; }
  int functionRows() { return (functionCount+3)/4; }
  float dividerHeight() { return valueCount > 0 && functionCount > 0 ? 12 : 0; }
  float height() { return 28+(valueRows()+functionRows())*geneControlRowHeight+dividerHeight(); }
}

class GeneControl {
  String name;
  Slider slider;
  boolean valueFamily;
  int familyIndex;
  float x, y;
  boolean visible;
  GeneValueType[] inputTypes = new GeneValueType[0];

  GeneControl(String name_, Slider slider_, boolean valueFamily_, int familyIndex_) {
    name = name_; slider = slider_;
    valueFamily = valueFamily_;
    familyIndex = familyIndex_;
    if (!valueFamily) {
      // Function signatures need no DNA owner or random argument allocation.
      Gene signature = new Gene(null, name);
      inputTypes = new GeneValueType[signature.nodes];
      for (int i = 0; i < signature.nodes; i++) inputTypes[i] = signature.inputType(i);
    }
  }
}
