class Pop {
	App p;

	ArrayList<Artwork> arts = new ArrayList<Artwork>();
	ArrayList<DNA> lastPool = new ArrayList<DNA>();
	int lastParentIndex = -1;

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
		int parentIndex = -1;
		for (int i = 0; i < arts.size(); i++) {
			Artwork a = arts.get(i);
			if (a.isSelected) {
				pool.add(a.dna);
				parentIndex = i;
			}
		}
		if (pool.isEmpty()) return;
		developPool(pool, parentIndex);
		lastPool = pool;
	}

	void developPool(ArrayList<DNA> pool, int parentIndex) {
		for (Artwork a : arts) a.isSelected = false;
		if (pool.size() == 1) {
			lastParentIndex = constrain(parentIndex, 0, arts.size()-1);
			for (int i = 0; i < arts.size(); i++) {
				if (i == lastParentIndex) {
					// Preserve the parent and its shader in the original grid cell.
					if (arts.get(i).dna != pool.get(0)) arts.get(i).assignDNA(pool.get(0));
					arts.get(i).isSelected = true;
					continue;
				}
				DNA newDNA = pool.get(0).copy();
				newDNA.mutate();
				arts.get(i).assignDNA(newDNA);
			}
		}
		if (pool.size() > 1) {
			lastParentIndex = -1;
			for (Artwork a : arts) {
				// Crossover is disabled while the typed graph system is introduced.
				DNA newDNA = pool.get((int)random(pool.size())).copy();
				newDNA.mutate();
				a.assignDNA(newDNA);
			}
		}
	}

	void evolveAgain() {
		ArrayList<DNA> pool = new ArrayList<DNA>(lastPool);
		int parentIndex = lastParentIndex;
		for (int i = 0; i < arts.size(); i++) {
			Artwork a = arts.get(i);
			// The retained parent is already in the repeat pool.
			if (a.isSelected && !pool.contains(a.dna)) {
				pool.add(a.dna);
				parentIndex = i;
			}
		}
		if (pool.isEmpty()) return;
		developPool(pool, parentIndex);
		lastPool = pool;
	}

	void randomPop() {
		for (Artwork a : arts) {
			a.randomDNA();
			a.isSelected = false;
		}	
		lastPool = new ArrayList<DNA>();	
		lastParentIndex = -1;
	}

	void display(int num, float x, float y, float w, float h) {
		arts.get(num).display(x,y,w,h);
	}
}
