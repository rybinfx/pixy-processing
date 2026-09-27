// The original home-text area, containing only grouped probability sliders.
class GeneControls {
  App owner;
  ArrayList<GeneControlGroup> groups = new ArrayList<GeneControlGroup>();
  ArrayList<GeneControl> controls = new ArrayList<GeneControl>();
  float x, y, w, h, scroll, contentHeight;
  boolean visible;

  GeneControls(App owner_) {
    owner = owner_;
    addGroup("Values", genesValues);
    for (int i = 0; i < genesMethods.length; i++) {
      addGroup(getMethodGroupName(i), genesMethods[i]);
    }
  }

  void addGroup(String title, String[] names) {
    GeneControlGroup group = new GeneControlGroup(title);
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
      slider.getValueLabel().setFont(owner.controlFont)
        .align(ControlP5.RIGHT, ControlP5.CENTER).setPadding(9, 0).setVisible(true);
      slider.hide();
      slider.setBroadcast(true);
      GeneControl control = new GeneControl(names[i], slider, names == genesValues);
      controls.add(control);
      group.controls.add(control);
    }
    groups.add(group);
  }

  void layout(boolean show, float px, float py, float pw, float ph) {
    visible = show;
    x = px; y = py; w = pw; h = ph;
    contentHeight = 0;
    for (GeneControlGroup group : groups) contentHeight += group.height()+10;
    contentHeight = max(0, contentHeight-10);
    scroll = constrain(scroll, 0, max(0, contentHeight-h));
    float top = y-scroll;
    float columnWidth = (w-50)/4;
    for (GeneControlGroup group : groups) {
      group.top = top;
      for (int i = 0; i < group.controls.size(); i++) {
        GeneControl control = group.controls.get(i);
        control.x = x+10+(i%4)*(columnWidth+10);
        control.y = top+26+(i/4)*30;
        boolean rowVisible = visible && control.y >= y && control.y+22 <= y+h;
        control.slider.setPosition(control.x, control.y)
          .setSize(max(1, int(columnWidth)), 22);
        // setSize recreates the native slider view and resets its caption
        // to RIGHT_OUTSIDE. Apply the inside alignment after sizing.
        control.slider.getCaptionLabel()
          .align(ControlP5.LEFT, ControlP5.CENTER).setPadding(5, 0);
        control.slider.getValueLabel()
          .align(ControlP5.RIGHT, ControlP5.CENTER).setPadding(9, 0).setVisible(true);
        if (rowVisible) control.slider.show();
        else control.slider.hide();
        owner.styleSlider(control.slider);
      }
      top += group.height()+10;
    }
    updatePercentages();
  }

  void updatePercentages() {
    float valuesTotal = geneWeightTotal(genesValues);
    float functionsTotal = geneWeightTotal(geneFunctionPool);
    for (GeneControl control : controls) {
      float total = control.valueFamily ? valuesTotal : functionsTotal;
      float percent = total > 0 ? 100 * geneProbability(control.name) / total : 0;
      control.slider.getValueLabel().setText(nf(percent, 1, 1)+"%");
    }
  }

  void display() {
    pushStyle();
    textFont(owner.font);
    textAlign(LEFT, BASELINE);
    rectMode(CORNER);
    clip(x, y, w, h);
    for (GeneControlGroup group : groups) {
      noFill();
      stroke(owner.uiGroupBorderColor);
      // Keep the full stroke inside the panel's clipping bounds.
      rect(x+1, group.top+1, max(0, w-2), group.height()-2);
      fill(owner.grayNormal);
      text(group.title, x+10, group.top+17);
    }
    noClip();
    popStyle();
  }

  void change(int id, float value) {
    if (id < 0 || id >= controls.size()) return;
    GeneControl control = controls.get(id);
    float previous = geneSliderValue(control.name);
    geneSliderValues.put(control.name, constrain(value, 0, 1));
    if (geneWeightTotal(genesValues) == 0) {
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
      scroll = constrain(scroll+amount*26, 0, max(0, contentHeight-h));
    }
  }
}

class GeneControlGroup {
  String title;
  float top;
  ArrayList<GeneControl> controls = new ArrayList<GeneControl>();

  GeneControlGroup(String title_) { title = title_; }
  float height() { return 28+((controls.size()+3)/4)*30; }
}

class GeneControl {
  String name;
  Slider slider;
  boolean valueFamily;
  float x, y;

  GeneControl(String name_, Slider slider_, boolean valueFamily_) {
    name = name_; slider = slider_;
    valueFamily = valueFamily_;
  }
}
