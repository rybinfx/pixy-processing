class GreetingDisplay {
  final float scrollSensitivity = 1;
  final float fontSize = 12;
  final float lineHeight = 14;
  ArrayList<String> lines = new ArrayList<String>();
  String wrappedText;
  float wrappedWidth = -1;
  float x, y, w, h, scroll, maxScroll;

  void display(float left, float top, float wide, float high) {
    x = left;
    y = top;
    w = wide;
    h = high;
    if (w <= 20 || h <= 0) return;

    pushStyle();
    textFont(app.font, fontSize);
    textAlign(LEFT, BASELINE);
    float textAreaWidth = w-20;
    if (wrappedWidth != textAreaWidth || !textGreet.equals(wrappedText)) {
      wrap(textAreaWidth);
      wrappedWidth = textAreaWidth;
      wrappedText = textGreet;
    }
    float contentHeight = textAscent()+textDescent() + max(0, lines.size()-1)*lineHeight;
    maxScroll = max(0, contentHeight-h);
    scroll = constrain(scroll, 0, maxScroll);

    // Keep greeting text above the controls, including partially visible lines.
    imageMode(CORNER);
    clip(x, y, w, h);
    fill(240);
    float baseline = y+textAscent()-scroll;
    for (String line : lines) {
      if (baseline+textDescent() >= y && baseline-textAscent() <= y+h) {
        text(line, x, baseline);
      }
      baseline += lineHeight;
    }
    noClip();

    if (maxScroll > 0) {
      float thumbHeight = min(h, max(12, h*h/contentHeight));
      float thumbY = y+(h-thumbHeight)*scroll/maxScroll;
      noStroke();
      rectMode(CORNER);
      fill(app.grayDark);
      rect(x+w-2, y, 2, h);
      fill(app.grayNormal);
      rect(x+w-2, thumbY, 2, thumbHeight);
    }
    popStyle();
  }

  void wrap(float availableWidth) {
    lines.clear();
    for (String paragraph : textGreet.split("\n", -1)) {
      String line = "";
      for (String word : paragraph.split(" ")) {
        String candidate = line.isEmpty() ? word : line+" "+word;
        if (!line.isEmpty() && renderedWidth(candidate) > availableWidth) {
          lines.add(line);
          line = "";
        }
        // Also wrap a single word if the preview becomes narrower than it.
        for (int i = 0; i < word.length(); i++) {
          String next = (i == 0 && !line.isEmpty() ? " " : "") + word.charAt(i);
          if (!line.isEmpty() && renderedWidth(line+next) > availableWidth) {
            lines.add(line);
            line = "";
          }
          line += next;
        }
      }
      lines.add(line);
    }
  }

  float renderedWidth(String line) {
    // P2D advances each character separately; native string metrics can be narrower.
    float width = 0;
    for (int i = 0; i < line.length(); i++) width += textWidth(line.charAt(i));
    return width;
  }

  void mouseWheel(processing.event.MouseEvent event) {
    if (maxScroll > 0 && event.getX() >= x && event.getX() < x+w &&
        event.getY() >= y && event.getY() < y+h) {
      scroll = constrain(scroll+event.getCount()*scrollSensitivity, 0, maxScroll);
    }
  }
}
