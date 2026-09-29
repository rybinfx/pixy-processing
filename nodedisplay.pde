class NodeDisplay {
	PGraphics canvas = createGraphics(512, 512, P2D);
	float xmar = 5;
	float ymar = 20;
	float nxsize = 35;
	float nysize = 25;
	float margin = 20;
	color nodeTextColor = color(200);

	NodeDisplay() {
		canvas.smooth(2);
	}

	void display(DNA dna, float x_, float y_, float w_, float h_) {
		int canvasWidth = max(1, ceil(w_));
		int canvasHeight = max(1, ceil(h_));
		if (canvas.width != canvasWidth || canvas.height != canvasHeight) {
			canvas.setSize(canvasWidth, canvasHeight);
		}
		process(dna);
		pushStyle();
		imageMode(CORNER);
		image(canvas, x_, y_, w_, h_);
		popStyle();
	}

	void process(DNA dna) {
		canvas.beginDraw();
		canvas.clear();
		canvas.textFont(app.font);
		canvas.textSize(14);
		canvas.rectMode(CENTER);
		canvas.textAlign(CENTER, CENTER);

		ArrayList<ArrayList<PreviewNode>> layers = new ArrayList<ArrayList<PreviewNode>>();
		HashMap<ArrayList<Integer>, PreviewNode> nodesByAddress = new HashMap<ArrayList<Integer>, PreviewNode>();
		HashMap<Long, PreviewNode> nodesById = new HashMap<Long, PreviewNode>();
		for (Gene gene : dna.genes) {
			while (layers.size() < gene.depth) layers.add(new ArrayList<PreviewNode>());
			PreviewNode node = new PreviewNode(gene);
			node.w = max(nxsize, canvas.textWidth(node.label)+12);
			layers.get(gene.depth-1).add(node);
			nodesByAddress.put(gene.adress, node);
			nodesById.put(gene.id, node);
		}

		float graphWidth = nxsize;
		float graphHeight = nysize+max(0, layers.size()-1)*(nysize+ymar);
		for (int level = 0; level < layers.size(); level++) {
			ArrayList<PreviewNode> layer = layers.get(level);
			float rowWidth = max(0, layer.size()-1)*xmar;
			for (PreviewNode node : layer) rowWidth += node.w;
			graphWidth = max(graphWidth, rowWidth);
			float left = -rowWidth/2;
			for (PreviewNode node : layer) {
				node.x = left+node.w/2;
				node.y = graphHeight/2-nysize/2-level*(nysize+ymar);
				left += node.w+xmar;
			}
		}

		// Shrink the whole graph, including text and boxes; never enlarge it.
		float fitScale = min(1, min(max(1, canvas.width-2*margin)/graphWidth,
			max(1, canvas.height-2*margin)/graphHeight));
		canvas.pushMatrix();
		canvas.translate(canvas.width/2.0, canvas.height/2.0);
		canvas.scale(fitScale);
		canvas.strokeWeight(1);
		for (ArrayList<PreviewNode> layer : layers) {
			for (PreviewNode node : layer) {
				if (node.gene.depth <= 1) continue;
				ArrayList<Integer> parentAddress = new ArrayList<Integer>(node.gene.adress);
				parentAddress.remove(parentAddress.size()-1);
				PreviewNode parent = nodesByAddress.get(parentAddress);
				if (parent != null) {
					canvas.stroke(geneTypeColor(node.gene.isLink() ? GeneValueType.LINK : node.gene.outputType()));
					canvas.line(parent.x, parent.y-nysize/2, node.x, node.y+nysize/2);
				}
			}
		}
		for (ArrayList<PreviewNode> layer : layers) {
			for (PreviewNode node : layer) {
				if (!node.gene.isLink()) continue;
				PreviewNode target = nodesById.get(node.gene.linkTargetId);
				if (target != null) drawLink(target, node);
			}
		}
		for (ArrayList<PreviewNode> layer : layers) {
			for (PreviewNode node : layer) {
				color typeColor = geneTypeColor(node.gene.isLink() ? GeneValueType.LINK : node.gene.outputType());
				// Opaque tinted boxes mask every connection drawn underneath them.
				canvas.fill(lerpColor(color(17), typeColor, 22.0/255.0));
				canvas.stroke(typeColor);
				canvas.rect(node.x, node.y, node.w, nysize);
				if (node.gene.depth == 1) {
					canvas.line(node.x, node.y+nysize/2, node.x, node.y+nysize/2+10);
				}
				canvas.fill(nodeTextColor);
				canvas.text(node.label, node.x, node.y);
			}
		}
		canvas.popMatrix();
		canvas.endDraw();
	}

	void drawDashedLine(float startX, float startY, float endX, float endY) {
		float length = dist(startX, startY, endX, endY);
		if (length <= 0) return;
		for (float offset = 0; offset < length; offset += 9) {
			float from = offset/length, to = min(offset+5, length)/length;
			canvas.line(lerp(startX, endX, from), lerp(startY, endY, from),
				lerp(startX, endX, to), lerp(startY, endY, to));
		}
	}

	void drawLink(PreviewNode target, PreviewNode link) {
		float startX = target.x, startY = target.y+nysize/2;
		float endX = link.x, endY = link.y-nysize/2;
		float length = dist(startX, startY, endX, endY);
		if (length <= 0) return;
		canvas.stroke(geneTypeColor(GeneValueType.LINK), 180);
		drawDashedLine(startX, startY, endX, endY);
		float dx = (endX-startX)/length, dy = (endY-startY)/length;
		canvas.line(endX, endY, endX-6*dx+3*dy, endY-6*dy-3*dx);
		canvas.line(endX, endY, endX-6*dx-3*dy, endY-6*dy+3*dx);
	}
}

class PreviewNode {
	Gene gene;
	String label;
	float x, y, w;

	PreviewNode(Gene gene_) {
		gene = gene_;
		label = gene.isLink() ? "LNK" : gene.type.toUpperCase();
	}
}
