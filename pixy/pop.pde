class Pop {
	App p;

	ArrayList<Artwork> arts = new ArrayList<Artwork>();
	ArrayList<DNA> lastPool = new ArrayList<DNA>();

	Pop(App p_) {
		p = p_;
	}

	void setPopSize(int row) {
		int popSize = row*row;
		int prevPop = arts.size();
		if (popSize > prevPop) {
			for (int i = 0; i < popSize - prevPop; i++) {
				Artwork a = new Artwork(this);
				a.randomDNA();
				arts.add(a);
			}
		} else if (prevPop > popSize) {
			for (int i = 0; i < prevPop - popSize; i++) {
				arts.remove(arts.size()-1);
			}
		}
		println("row: "+row);
		println("arts.size(): "+arts.size());
	}

	void evolve() {
		ArrayList<DNA> pool = new ArrayList<DNA>();
		for (Artwork a : arts) {
			if (a.isSelected) pool.add(a.dna);
			a.isSelected = false;
		}
		if (pool.size() == 1) {
			arts.get(0).assignDNA(pool.get(0).copy());
			for (int i = 1; i < arts.size(); i++) {
				DNA newDNA = pool.get(0).copy();
				newDNA.mutate();
				arts.get(i).assignDNA(newDNA);
			}
		}
		if (pool.size() > 1) {
			for (Artwork a : arts) {
				DNA newDNA = pool.get((int)random(pool.size()));
				newDNA = newDNA.sex(newDNA, pool.get((int)random(pool.size())));
				a.assignDNA(newDNA);
			}
		}
		lastPool = pool;
	}

	void evolveAgain() {
		ArrayList<DNA> pool = lastPool;
		for (Artwork a : arts) {
			if (a.isSelected) pool.add(a.dna);
			a.isSelected = false;
		}
		if (pool.size() == 1) {
			arts.get(0).assignDNA(pool.get(0).copy());
			for (int i = 1; i < arts.size(); i++) {
				DNA newDNA = pool.get(0).copy();
				newDNA.mutate();
				arts.get(i).assignDNA(newDNA);
			}
		}
		if (pool.size() > 1) {
			for (Artwork a : arts) {
				DNA newDNA = pool.get((int)random(pool.size()));
				newDNA = newDNA.sex(newDNA, pool.get((int)random(pool.size())));
				a.assignDNA(newDNA);
			}
		}
	}

	void randomPop() {
		for (Artwork a : arts) {
			a.randomDNA();
			a.isSelected = false;
		}	
		lastPool = new ArrayList<DNA>();	
	}

	void display(int num, float x, float y, float w, float h) {
		arts.get(num).display(x,y,w,h);
	}
}
