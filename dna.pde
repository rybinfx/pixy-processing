class DNA {
	ArrayList<Gene> genes;
	float scale = 0.5;
	PVector offset = new PVector();
	float hueOffset;
	ArrayList<PVector> args = new ArrayList<PVector>();

	String code;

	int depthLimit = 3;
	int widthLimit = 1;

	DNA() {
	}	

	DNA(String s) {
		if (s == "RANDOM") {
			randomDNA();
		}
	}

	// MAIN METHODS

	void construct() {
		enforceGraphLimits();
		validateTypes();
		code = "vec3 col = " + genes.get(0).get() + ";";
	}

	void validateTypes() {
		if (genes.get(0).outputType() != GeneValueType.IMG) {
			throw new IllegalStateException("Graph output must be img");
		}
		for (Gene gene : genes) {
			ArrayList<Gene> children = gene.getChildren();
			for (int i = 0; i < children.size(); i++) {
				if (children.get(i).outputType() != gene.inputType(i)) {
					throw new IllegalStateException("Wrong input type for " + gene.type + " at " + i);
				}
			}
		}
	}

	void updateGraphLimits() {
		// Keep enough depth available for sdfimg(circle(pxy()), colrnd(), rrnd()).
		depthLimit = max(3, depth_max);
		// Even the smallest image needs SDF, color and ramp on its next level.
		widthLimit = max(3, width_max);
	}

	void randomDNA() {
		args = new ArrayList<PVector>();
		updateGraphLimits();
		hueOffset = random(1);
		genes = new ArrayList<Gene>();
		addGene();
		construct();
	}

	// SEX

	DNA sex(DNA d1, DNA d2) {
		DNA p1 = d1.copy();
		DNA p2 = d2.copy();
		p1.updateGraphLimits();
		p1.enforceGraphLimits();

		for (int i = 0; i < 5+app.mutationRate/10; i++) {
			sSwap(p1, p1.genes.get( (int) random(p1.genes.size()) ), p2, p2.genes.get( (int) random(p2.genes.size()) ) );
		}
		p1.mutate();
		p1.construct();
		return p1;
	}

	void sSwap(DNA p1, Gene g1, DNA p2, Gene g2) {
		ArrayList<Gene> b1 = p1.grabBranch(p2, g1);
		ArrayList<Gene> b2 = p2.grabBranch(p1, g2);

		for (Gene g : b2) {
			if (g.usesArguments()) {
				p1.args.add(p2.args.get(g.argsBinder).get());
				g.argsBinder = p1.args.size()-1;
			}
		}

		for (Gene g : b1) {
			if (g.usesArguments()) {
				p2.args.add(p1.args.get(g.argsBinder).get());
				g.argsBinder = p2.args.size()-1;
			}
		}

		int ind = p1.geneIndex(g1);
		p1.deleteBranch(g1);
		p1.injectBranch(ind, b2);
		p1.genes.get(ind).setAdress(g1.adress);
		p1.updAd(p1.genes.get(ind));

		p1.sortArgs();

		ind = p2.geneIndex(g2);
		p2.deleteBranch(g2);
		p2.injectBranch(ind, b1);
		p2.genes.get(ind).setAdress(g2.adress);
		p2.updAd(p2.genes.get(ind));

		p2.sortArgs();
		p1.enforceGraphLimits();
		p2.enforceGraphLimits();
	}

	// MUTATION

	void mutate() {
		updateGraphLimits();
		enforceGraphLimits();
		mutateArgs();
		mutateParameters();
		for (int i = 0; i < genes.size()*(app.mutationRate/100*0.05); i++) {
			Gene g = genes.get((int) random(genes.size()));
			Gene g2 = genes.get((int) random(genes.size()));
			int act = (int) random(6);
			if (act == 0) mRemoveNode(g);
			if (act == 1) mInsert(g);
      if (act == 5) mInsert(g);
			if (act == 2) changeGene(g);
			if (act == 3) mSwap(g,g2);
			if (act == 4) mCopy(g,g2);
			enforceGraphLimits();

		}
		sortArgs();

		construct();
	}

	void sortArgs() {
		ArrayList<PVector> sorted = new ArrayList<PVector>();
		for (Gene g : genes) {
			if (g.usesArguments()) {
				if (sorted.size() < geneArgumentLimit) {
					sorted.add( args.get(g.argsBinder) );
					g.argsBinder = sorted.size()-1;
				} else {
					g.argsBinder = geneArgumentLimit-1;
				}
			}
		}
		args = sorted;
	}

	void mCopy(Gene g1, Gene g2) {
		if (g1.outputType() != g2.outputType()) return;
		ArrayList<Gene> b1 = grabBranch(g1);

		int ind = geneIndex(g2);
		deleteBranch(g2);
		injectBranch(ind, b1);
		genes.get(ind).setAdress(g2.adress);
		updAd(genes.get(ind));


	}

	void mSwap(Gene g1, Gene g2) {
		if (g1.outputType() != g2.outputType()) return;
		// Swapping a branch with itself or one of its descendants removes the
		// second target during the first replacement. Only swap disjoint branches.
		if (containsBranch(g1, g2) || containsBranch(g2, g1)) return;
		ArrayList<Gene> b1 = grabBranch(g1);
		ArrayList<Gene> b2 = grabBranch(g2);

		int ind = geneIndex(g1);
		deleteBranch(g1);
		injectBranch(ind, b2);
		genes.get(ind).setAdress(g1.adress);
		updAd(genes.get(ind));

		ind = geneIndex(g2);
		deleteBranch(g2);
		injectBranch(ind, b1);
		genes.get(ind).setAdress(g2.adress);
		updAd(genes.get(ind));

	}

	boolean containsBranch(Gene root, Gene node) {
		return root.adress.size() <= node.adress.size() &&
			node.adress.subList(0, root.adress.size()).equals(root.adress);
	}

	void mChange(Gene g) {
		boolean newIsValue;
		if (isValue(g)) newIsValue = random(1) > 0.2;
		else newIsValue = random(1) < 0.2;
		replaceGene(g, getGene(newIsValue, g.outputType(), depthLimit-g.depth+1));
	}

	void mRemoveNode(Gene g) {
		ArrayList<Gene> compatible = new ArrayList<Gene>();
		for (Gene child : g.getChildren()) {
			if (child.outputType() == g.outputType()) compatible.add(child);
		}
		if (compatible.isEmpty()) return;
		Gene child = compatible.get((int) random(compatible.size()));
		ArrayList<Gene> replacement = grabBranch(child);
		int index = geneIndex(g);
		deleteBranch(g);
		injectBranch(index, replacement);
		genes.get(index).setAdress(new ArrayList<Integer>(g.adress));
		updAd(genes.get(index));
	}

	void mInsert(Gene g) {
		int index = geneIndex(g);
		Gene newGene = getGene(false, g.outputType(), depthLimit-g.depth+1);
		if (newGene.nodes == 0) return; // A value/time leaf cannot wrap an existing branch.
		// Preserve the branch in a matching slot (pxscale takes pxy first).
		int input = -1;
		for (int i = 0; i < newGene.nodes; i++) {
			if (newGene.inputType(i) == g.outputType()) input = i;
		}
		if (input < 0) return;
		newGene.setAdress(new ArrayList<Integer>(g.adress));
		ArrayList<Gene> replacement = new ArrayList<Gene>();
		replacement.add(newGene);
		for (int i = 0; i < newGene.nodes; i++) {
			if (i == input) replacement.addAll(grabBranch(g));
			else {
				ArrayList<Integer> address = new ArrayList<Integer>(g.adress);
				address.add(i);
				appendTerminalBranch(newGene.inputType(i), address, replacement, null);
			}
		}
		deleteBranch(g);
		injectBranch(index, replacement);
		updAd(newGene);
	}

	void updNode(Gene g, int n) {
		if (n > 0) {
			fillNode(g, n);
		} else if (n < 0) {
			clearNode(g, abs(n));
		}
		updAd(g);

	}

	void fillNode(Gene g, int n) {
		int index = geneIndex(g);
		if (n > 0) {
			for (int i = 0; i < n; i++) {
				Gene newGene = getGene(true, g.inputType(n-1-i));
				genes.add(index+1,newGene);
			}
		}
	}	

	void clearNode(Gene g, int n) {
		int index = geneIndex(g);
		ArrayList<Integer> deleted = new ArrayList<Integer>();
		if (n > 0) {
			for (int i = 0; i < n; i++) {
				ArrayList<Integer> newAdress = new ArrayList<Integer>(g.adress);
				boolean setdelnode = false;
				int delnode = 0;
				while (!setdelnode) {
					delnode = (int) random(g.nodes);
					setdelnode = true;
					for (Integer nd : deleted) {
						if (delnode == nd) setdelnode = false;
					}
				}
				newAdress.add(delnode);
				deleted.add(delnode);
				Gene delGene = getGeneByAdress(newAdress);
				deleteBranch(delGene);
			}
		}
	}

	int updAdInd;
	void updAd(Gene g) {
		updAdInd = geneIndex(g) + 1;
		if (updAdInd < genes.size()) {
			for (int i = 0; i < g.nodes; i++) {
				updAd(updAdInd,i,g.adress);
			}
		}
	}

	void updAd(int index, int n, ArrayList<Integer> a) {
		Gene g = genes.get(updAdInd);
		ArrayList<Integer> newAd = new ArrayList<Integer>(a);
		newAd.add(n);
		g.setAdress(newAd);
		updAdInd++;
		for (int i = 0; i < g.nodes; i++) {
			if (updAdInd < genes.size()) updAd(updAdInd, i, newAd);
		}
	}

	// PICK GENES

	// Draw directly from relative weights. Zero-weight entries are never picked.
	int pickWeighted(String[] names) {
		float total = geneWeightTotal(names);
		if (total <= 0) return -1;
		float pick = random(total);
		int last = -1;
		for (int i = 0; i < names.length; i++) {
			float weight = geneProbability(names[i]);
			if (weight <= 0) continue;
			last = i;
			pick -= weight;
			if (pick < 0) return i;
		}
		return last;
	}

	Gene getGene(boolean isVal, GeneValueType requiredType) {
		return getGene(isVal, requiredType, depthLimit);
	}

	Gene getGene(boolean isVal, GeneValueType requiredType, int remainingDepth) {
		if (requiredType == GeneValueType.VEC3) throw new IllegalStateException("vec3 generation is disabled");
		// SDF ends in a primitive; img ends in sdfimg with complete typed inputs.
		String[] pool = isVal ? geneTerminalCandidates(requiredType) : genesReturning(geneFunctionPool, requiredType);
		ArrayList<String> fitting = new ArrayList<String>();
		for (String name : pool) {
			if (geneMinimumDepth(name) <= remainingDepth) fitting.add(name);
		}
		String[] candidates = fitting.toArray(new String[0]);
		int index = pickWeighted(candidates);
		if (index >= 0) return new Gene(this, candidates[index]);
		int minimumDepth = requiredType == GeneValueType.IMG ? 3 : requiredType == GeneValueType.SDF ? 2 : 1;
		if (remainingDepth < minimumDepth) {
			throw new IllegalStateException("Insufficient depth for " + requiredType);
		}
		if (requiredType == GeneValueType.COL) return new Gene(this, "colrnd");
		if (requiredType == GeneValueType.IMG) return new Gene(this, "sdfimg");
		if (requiredType == GeneValueType.SDF) return new Gene(this, "circle");
		if (!isVal) return getGene(true, requiredType, remainingDepth);
		if (requiredType == GeneValueType.PXY) return new Gene(this, "pxy");
		if (requiredType == GeneValueType.PNT) return new Gene(this, "prnd");
		if (requiredType == GeneValueType.RAMP) return new Gene(this, "rrnd");
		if (requiredType == GeneValueType.CYCLE) return new Gene(this, "ctime");
		throw new IllegalStateException("No generator for " + requiredType);
	}

	boolean chooseValue(int depth, int nextLevelWidth) {
		if (depthLimit <= 1 || depth >= depthLimit) return true;
		// Both ramps are linear. Width counts all children already committed
		// to the next level, including siblings not yet visited by recursion.
		float depthProgress = constrain((float)(depth-1)/(depthLimit-1), 0, 1);
		float widthProgress = constrain((float)nextLevelWidth/widthLimit, 0, 1);
		float functionChance = 1-max(depthProgress, widthProgress);
		return random(1) >= functionChance;
	}

  // Reserve complete minimal branches, including the three inputs of sdfimg.
	void reserveMinimum(GeneValueType type, int depth, int[] widths, int delta) {
		widths[depth] += delta;
		if (type == GeneValueType.SDF) reserveMinimum(GeneValueType.PXY, depth+1, widths, delta);
		if (type == GeneValueType.IMG) {
			reserveMinimum(GeneValueType.SDF, depth+1, widths, delta);
			reserveMinimum(GeneValueType.COL, depth+1, widths, delta);
			reserveMinimum(GeneValueType.RAMP, depth+1, widths, delta);
		}
	}

	void reserveInputs(Gene node, int depth, int[] widths) {
		reserveMinimum(node.outputType(), depth, widths, -1);
		widths[depth]++;
		for (int i = 0; i < node.nodes; i++) reserveMinimum(node.inputType(i), depth+1, widths, 1);
	}

	boolean inputsFit(Gene node, int depth, int[] widths) {
		if (geneMinimumDepth(node.type) > depthLimit-depth+1) return false;
		int[] proposed = widths.clone();
		reserveInputs(node, depth, proposed);
		for (int i = 1; i <= depthLimit; i++) {
			if (proposed[i] > widthLimit) return false;
		}
		return true;
	}

	// End branches that would exceed depth or the number of nodes in a level.
	void enforceGraphLimits() {
		ArrayList<Gene> capped = new ArrayList<Gene>();
		int[] levelWidths = new int[depthLimit+2];
		reserveMinimum(GeneValueType.IMG, 1, levelWidths, 1);
		appendCapped(genes.get(0), capped, levelWidths);
		genes = capped;
		sortArgs();
	}

	void appendCapped(Gene source, ArrayList<Gene> capped, int[] levelWidths) {
		if (!inputsFit(source, source.depth, levelWidths)) {
			appendTerminalBranch(source.outputType(), source.adress, capped, levelWidths);
			return;
		}
		capped.add(source);
		reserveInputs(source, source.depth, levelWidths);
		ArrayList<Gene> children = source.getChildren();
		for (int i = 0; i < children.size(); i++) {
			appendCapped(children.get(i), capped, levelWidths);
		}
	}

	void appendTerminalBranch(GeneValueType requiredType, ArrayList<Integer> address, ArrayList<Gene> target, int[] levelWidths) {
		Gene node = getGene(true, requiredType, depthLimit-address.size()+1);
		node.setAdress(new ArrayList<Integer>(address));
		target.add(node);
		if (levelWidths != null) reserveInputs(node, node.depth, levelWidths);
		for (int i = 0; i < node.nodes; i++) {
			ArrayList<Integer> childAddress = new ArrayList<Integer>(address);
			childAddress.add(i);
			appendTerminalBranch(node.inputType(i), childAddress, target, levelWidths);
		}
	}

	// GENERAL METHODS

	Gene getGeneByAdress(ArrayList<Integer> a) {
		for (Gene g : genes) {
			if (g.adress.equals(a)) return g;
		}

		throw new IllegalStateException("Missing gene at " + a);
	}

	int geneIndex(Gene g) {
		for (int i = 0; i < genes.size(); i++) {
			if (genes.get(i) == g) return i;
		}
		println("geneIndex Error");
		return -1;
	}

	int[] branchIndex(Gene g) {
		int first = geneIndex(g);
		for (int i = first+1; i < genes.size(); i++) {
			Gene test = genes.get(i);
			if (test.depth <= g.depth) {
				return new int[] {first, i-1};
			}
		}
		return new int[] {first, genes.size()-1};
	}

	boolean isValue(Gene g) {
		return g.nodes == 0;
	}


	// CONSTRUCTION METHODS

	void addGene() {
		int[] levelWidths = new int[depthLimit+2];
		reserveMinimum(GeneValueType.IMG, 1, levelWidths, 1);
		addGene(0, new ArrayList<Integer>(), levelWidths, GeneValueType.IMG);
	}

	void addGene(int n, ArrayList<Integer> a, int[] levelWidths, GeneValueType requiredType) {

		int depth = a.size()+1;
		Gene lastGene = getGene(chooseValue(depth, levelWidths[depth+1]), requiredType, depthLimit-depth+1);
		if (!inputsFit(lastGene, depth, levelWidths)) lastGene = getGene(true, requiredType, depthLimit-depth+1);
		reserveInputs(lastGene, depth, levelWidths);
		genes.add(lastGene);
		ArrayList<Integer> newAdress = new ArrayList<Integer>(a);
		newAdress.add(n);
		lastGene.setAdress(newAdress);

		for (int i = 0; i < lastGene.nodes; i++) addGene(i,lastGene.adress,levelWidths,lastGene.inputType(i));
	}

	// GENE MANIPULATION

	void mutateParameters() {
		hueOffset += randomGaussian()*0.1;
	}

	void mutateArgs() {
		for (int i = 0; i < random(args.size()); i++) {
			int num = (int) random(args.size());
			PVector a = args.get(num);
			if (a.x == a.y && a.y == a.z) {
				float temp = randomGaussian()*0.1;
				a.add(temp,temp,temp);
			} else {
				a.add(randomGaussian()*0.1,randomGaussian()*0.1,randomGaussian()*0.1);
			}
		}
		// prnd bounds its output in GLSL. Keep shared argument storage unbounded
		// so rrnd remains unrestricted even when slots are reused at capacity.
	}

	void changeGene(Gene g) {
		replaceGene(g, getGene(isValue(g), g.outputType(), depthLimit-g.depth+1));
	}

	void replaceGene(Gene g, Gene newGene) {
		if (g.outputType() != newGene.outputType()) return;
		int index = geneIndex(g);
		newGene.setAdress(new ArrayList<Integer>(g.adress));
		ArrayList<Gene> children = g.getChildren();
		ArrayList<Gene> replacement = new ArrayList<Gene>();
		replacement.add(newGene);
		for (int i = 0; i < newGene.nodes; i++) {
			if (i < children.size() && children.get(i).outputType() == newGene.inputType(i)) {
				replacement.addAll(grabBranch(children.get(i)));
			} else {
				ArrayList<Integer> address = new ArrayList<Integer>(g.adress);
				address.add(i);
				appendTerminalBranch(newGene.inputType(i), address, replacement, null);
			}
		}
		deleteBranch(g);
		injectBranch(index, replacement);
		updAd(newGene);
	}

	void changeValToMeth(Gene g) {
		if (isValue(g)) mInsert(g);
	}

	void deleteBranch(Gene g) {
		int[] branch = branchIndex(g);
		for (int i = branch[0]; i <= branch[1]; i++) {
			genes.remove(branch[0]);
		}
	}

	ArrayList<Gene> grabBranch(Gene g) {
		return grabBranch(this, g);
	}

	ArrayList<Gene> grabBranch(DNA p, Gene g) {
		ArrayList<Gene> branch = new ArrayList<Gene>();
		int[] bInd = branchIndex(g);
		for (int i = bInd[0]; i <= bInd[1]; i++) {
			branch.add(genes.get(i).copy(p));
		}
		return branch;
	}

	void injectBranch(int index, ArrayList<Gene> branch) {
		for (int i = branch.size()-1; i >= 0; i--) {
			genes.add(index, branch.get(i));
		}
	}

	//	COPY

	ArrayList<Gene> copyGenes(DNA p) {
		ArrayList<Gene> temp = new ArrayList<Gene>();
		for (Gene g : genes) {
			temp.add(g.copy(p));
		}
		return temp;
	}

	ArrayList<PVector> copyArgs() {
		ArrayList<PVector> copy = new ArrayList<PVector>();
		for (PVector p : args) {
			copy.add(p.get());
		}
		return copy;
	}

	DNA copy() {

		DNA temp = new DNA();
		temp.depthLimit = depthLimit;
		temp.widthLimit = widthLimit;
		temp.genes = copyGenes(temp);
		temp.code = code;
		temp.scale = scale;
		temp.offset = offset.get();
		temp.hueOffset = hueOffset;
		temp.args = copyArgs();
		return temp;
	}

}
