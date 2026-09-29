class DNA {
	ArrayList<Gene> genes;
	float scale = 4;
	PVector offset = new PVector();
	float hueOffset;
	ArrayList<PVector> args = new ArrayList<PVector>();

	String code;

	float complexity = 6;
	float mutationRate = 1;

	DNA() {
	}	

	DNA(String s) {
		if (s == "RANDOM") {
			randomDNA();
		}
	}

	// MAIN METHODS

	void construct() {
		code = "vec3 col = " + genes.get(0).get() + ";";
	}

	void randomDNA() {
		args = new ArrayList<PVector>();
		// scale = random(4,16);
		complexity = random(3,16);
		// complexity = random(4,16);
		hueOffset = random(1);
		genes = new ArrayList<Gene>();
		addGene();
		construct();
	}

	// SEX

	DNA sex(DNA d1, DNA d2) {
		DNA p1 = d1.copy();
		DNA p2 = d2.copy();

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
			if (g.type == "rndm" || g.type == "rndm3") {
				p1.args.add(p2.args.get(g.argsBinder).get());
				g.argsBinder = p1.args.size()-1;
			}
		}

		for (Gene g : b1) {
			if (g.type == "rndm" || g.type == "rndm3") {
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
	}

	// MUTATION

	void mutate() {
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

		}
		sortArgs();

		construct();
	}

	void sortArgs() {
		ArrayList<PVector> sorted = new ArrayList<PVector>();
		for (Gene g : genes) {
			if (g.type == "rndm" || g.type == "rndm3") {
				if (sorted.size() < 512) {
					sorted.add( args.get(g.argsBinder) );
					g.argsBinder = sorted.size()-1;
				} else {
					g.argsBinder = 511;
				}
			}
		}
		args = sorted;
	}

	void mCopy(Gene g1, Gene g2) {
		ArrayList<Gene> b1 = grabBranch(g1);

		int ind = geneIndex(g2);
		deleteBranch(g2);
		injectBranch(ind, b1);
		genes.get(ind).setAdress(g2.adress);
		updAd(genes.get(ind));


	}

	void mSwap(Gene g1, Gene g2) {
		ArrayList<Gene> b1 = grabBranch(g1);
		ArrayList<Gene> b2 = grabBranch(g2);

		int ind = geneIndex(g1);
		deleteBranch(g1);
		injectBranch(ind, b2);
		genes.get(ind).setAdress(g1.adress);
		updAd(genes.get(ind));

		ind = geneIndex(g2);
		if (ind >= 0) {
			deleteBranch(g2);
			injectBranch(ind, b1);
			genes.get(ind).setAdress(g2.adress);
			updAd(genes.get(ind));
		} else println("Its okay");

	}

	void mChange(Gene g) {
		int index = geneIndex(g);
		boolean newIsValue;
		if (isValue(g)) newIsValue = random(1) > 0.2;
		else newIsValue = random(1) < 0.2;
		Gene newGene = getGene(newIsValue);
		int toadd = newGene.nodes-g.nodes;
		newGene.setAdress(g.adress);
		genes.set(index,newGene);
		if (toadd > 0) {
			fillNode(newGene,toadd);
			updAd(newGene);
		} else if (toadd < 0) {
			clearNode(newGene, abs(toadd));
			updAd(newGene);
		}
	}

	void mRemoveNode(Gene g) {
		if (!isValue(g)) {
			int index = geneIndex(g);
			clearNode(g, g.nodes-1);
			genes.remove(index);
			genes.get(index).setAdress(g.adress);
			updAd(genes.get(index));
		}
	}

	void mInsert(Gene g) {
		int index = geneIndex(g);
		Gene newGene = getGene(false);
		newGene.setAdress(g.adress);
		genes.add(index,newGene);
		int toAdd = newGene.nodes - 1;
		updNode(newGene, toAdd);
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
				Gene newGene = getGene(true);
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

	String getVal() {
		for (int i = 0; i < 100; i++) {
			int rtest = int(random(genesValues.length));
			if (random(1) < genesValuesRate[rtest]) return genesValues[rtest];
		}

		println("Hard to find value");
		return "rndm";
	}

	String getMethod() {

		String[] methodGroup = new String[0];
		float[] methodGroupRate = new float[0];

		for (int i = 0; i < 100; i++) {
			int rtest = int(random(genesMethods.length));
			if (random(1) < genesMethodsGroupRate[rtest]) {
				methodGroup = genesMethods[rtest];
				methodGroupRate = genesMethodsRate[rtest];
				break;
			}
			if (i == 99) {
				println("Hard to find method");
				return "rndm";
			}
		}

		for (int i = 0; i < 100; i++) {
			int rtest = int(random(methodGroup.length));
			if (random(1) < methodGroupRate[rtest]) return methodGroup[rtest];
		}

		println("Hard to find method");
		return "rndm";
	}

	Gene getGene(boolean isVal) {
		if (isVal) {
			return new Gene(this, getVal());
		}
		return new Gene(this, getMethod());
	}

	// COMPLEXITY FORMULA

	boolean isValue(float depth) {
		float test = 1-((depth-2)/complexity);
		test = pow(test, 2);
		if (random(1) > test) return true;
		return false;
	}

	// GENERAL METHODS

	Gene getGeneByAdress(ArrayList<Integer> a) {
		for (Gene g : genes) {
			if (g.adress.equals(a)) return g;
		}

		println("Wrong gene adress:");
		println(a);
		println("All adresses:");
		for (Gene g : genes) {
			println("g.adress: "+g.adress);
		}
		return getGene(true);
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
		if (g.type == "x" || g.type == "y" || g.type == "rndm" || g.type == "rndm3") return true;
		return false;
	}


	// CONSTRUCTION METHODS

	void addGene() {
		addGene(0, new ArrayList<Integer>());
	}

	void addGene(int n, ArrayList<Integer> a) {

		genes.add(getGene(isValue(a.size()+1)));
		Gene lastGene = genes.get(genes.size()-1);
		ArrayList<Integer> newAdress = new ArrayList<Integer>(a);
		newAdress.add(n);
		lastGene.setAdress(newAdress);

		for (int i = 0; i < lastGene.nodes; i++) addGene(i,lastGene.adress);
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
	}

	void changeGene(Gene g) {
		int index = geneIndex(g);

		if (isValue(g)) {
			genes.set(index, getGene(true));
		} else {
			genes.set(index, getGene(false));
		}

		Gene newGene = genes.get(index);
		newGene.setAdress(new ArrayList<Integer>(g.adress));

		if (newGene.nodes < g.nodes) {
			int todelete = g.nodes - newGene.nodes;
			for (int i = todelete; i > 0; i--) {
				ArrayList<Integer> deladress = new ArrayList<Integer>(newGene.adress);
				deladress.add(g.nodes-i);
				deleteBranch(getGeneByAdress(deladress));
			}
		} else if (newGene.nodes > g.nodes) {
			int toadd = newGene.nodes - g.nodes;
			for (int i = toadd; i >= 1; i--) {
					genes.add(index+1,getGene(true));
					ArrayList<Integer> parentAdress = new ArrayList<Integer>(newGene.adress);
					parentAdress.add(g.nodes+i-1);
					genes.get(index+1).setAdress(parentAdress);
			}
		}
	}

	void changeValToMeth(Gene g) {
		if (isValue(g)) {
			int index = geneIndex(g);
			genes.set(index, getGene(false));
			Gene newGene = genes.get(index);
			newGene.setAdress(new ArrayList<Integer>(g.adress));

			for (int i = newGene.nodes; i >= 1; i--) {
					if (i == 1) {
						genes.add(index+1,g.copy(this));
					} else {
						genes.add(index+1,getGene(true));
					}
					ArrayList<Integer> parentAdress = new ArrayList<Integer>(newGene.adress);
					parentAdress.add(g.nodes+i-1);
					genes.get(index+1).setAdress(parentAdress);
			}

		} else {
			println("hey!((");
		}
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
		temp.genes = copyGenes(temp);
		temp.code = code;
		temp.scale = scale;
		temp.offset = offset.get();
		temp.hueOffset = hueOffset;
		temp.args = copyArgs();
		return temp;
	}

}
