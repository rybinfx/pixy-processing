class NodeDisplay {
  float xmar = 5;
  float ymar = 20;
  float nxsize = 35;
  float nysize = 25;
  float margin = 20;

  void display(DNA dna, float x, float y, float w, float h) {
    if (w <= margin*2 || h <= margin*2 || dna.genes.isEmpty()) return;

    pushStyle();
    pushMatrix();
    textFont(app.font);
    textSize(15);
    textAlign(CENTER, CENTER);

    int depth = 0;
    float nodeWidth = nxsize;
    float nodeHeight = max(nysize, textAscent()+textDescent()+4);
    for (Gene gene : dna.genes) {
      depth = max(depth, gene.depth);
      nodeWidth = max(nodeWidth, textWidth(gene.type.toUpperCase())+8);
    }

    ArrayList<ArrayList<Gene>> layers = new ArrayList<ArrayList<Gene>>();
    for (int i = 0; i < depth; i++) layers.add(new ArrayList<Gene>());
    for (Gene gene : dna.genes) layers.get(gene.depth-1).add(gene);

    int widestLayer = 1;
    for (ArrayList<Gene> layer : layers) widestLayer = max(widestLayer, layer.size());
    float treeWidth = widestLayer*nodeWidth+(widestLayer-1)*xmar;
    float treeHeight = depth*nodeHeight+(depth-1)*ymar;
    float fit = min(1, min((w-margin*2)/treeWidth, (h-margin*2)/treeHeight));

    // Preserve proportions and natural size; shrink only when needed.
    translate(x+w/2, y+(h-treeHeight*fit)/2);
    scale(fit);
    strokeWeight(1);

    for (int row = 0; row < layers.size(); row++) {
      ArrayList<Gene> layer = layers.get(row);
      float nodeY = nodeHeight/2+row*(nodeHeight+ymar);
      for (int i = 0; i < layer.size(); i++) {
        Gene gene = layer.get(i);
        float nodeX = (i-(layer.size()-1)/2.0f)*(nodeWidth+xmar);
        if (row > 0) {
          ArrayList<Integer> parentAddress = new ArrayList<Integer>(gene.adress);
          parentAddress.remove(parentAddress.size()-1);
          ArrayList<Gene> parents = layers.get(row-1);
          for (int j = 0; j < parents.size(); j++) {
            if (parentAddress.equals(parents.get(j).adress)) {
              float parentX = (j-(parents.size()-1)/2.0f)*(nodeWidth+xmar);
              stroke(app.outlineColor(color(255)));
              line(parentX, nodeY-nodeHeight/2-ymar, nodeX, nodeY-nodeHeight/2);
              break;
            }
          }
        }
        fill(255);
        noStroke();
        text(gene.type.toUpperCase(), nodeX, nodeY);
      }
    }
    popMatrix();
    popStyle();
  }
}
