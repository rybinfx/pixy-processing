float probability_exponent = 2;
int depth_max = 8;
int width_max = 8;
// u_args in fragment.glsl contains 512 floats; each random value uses three.
final int geneArgumentLimit = 512 / 3;

// Raw slider positions, keyed by gene rather than by UI group.
HashMap<String, Float> geneSliderValues = new HashMap<String, Float>();

float geneSliderValue(String name) {
	Float value = geneSliderValues.get(name);
	return value != null ? value : (name.equals("x") || name.equals("y") ? 1 : 0);
}

float geneProbability(String name) {
	float value = geneSliderValue(name);
	return value <= 0 ? 0 : pow(value, probability_exponent);
}

float geneWeightTotal(String[] names) {
	float total = 0;
	for (String name : names) total += geneProbability(name);
	return total;
}

String[] genesValues = new String[] {
	"x",
	"y",
	"rndm",
  //"rndm2",
	"rndm3",
	"time",
	"sintime"
};


String[] genesBasicMath = new String[] {
	"add",
	"sub",
	"mult",
	"div"
};

String[] genesExponential = new String[] {
	"pow2",
	"sqrt",
	"powOf",
	"logOf",
	"2pow",
	"2log"
};


String[] genesRound = new String[] {
	"mod",
	"fract",
	"floor",
	"ceil",
	"round"
};

String[] genesTrig = new String[] {
	"sin",
	"cos",
	"tan",
	"asin",
	"acos",
	"atan"
};


String[] genesConstrain = new String[] {
	"min",
	"max",
	"clamp",
	"abs"
};


String[] genesMix = new String[] {
	"mix"
};

String[] genesLogic = new String[] {
	"if",
	"and",
	"or",
	"xor"
};


String[] genesElse = new String[] {
	"hsb2rgb",
	"combine",
	"setH",
	"setS",
	"setV"
	//"noise2"
};


String[][] genesMethods = new String[][] {
	genesBasicMath,
	genesExponential,
	genesRound,
	genesTrig,
	genesConstrain,
	genesMix,
	genesLogic,
	genesElse
};


// Functions share a flat pool; values are selected separately at branch ends.
// The groups above only determine card layout.
String[] geneFunctionPool = createGeneFunctionPool();

String[] createGeneFunctionPool() {
	ArrayList<String> names = new ArrayList<String>();
	for (String[] group : genesMethods) {
		for (String name : group) names.add(name);
	}
	return names.toArray(new String[0]);
}

String getMethodGroupName(int n) {
	if (n == 0) return "Basic Math";
	if (n == 1) return "Exponential";
	if (n == 2) return "Round";
	if (n == 3) return "Trigonometry";
	if (n == 4) return "Constrain";
	if (n == 5) return "Mix";
	if (n == 6) return "Logic";
	if (n == 7) return "Else";
	return "Oops";
}

class Gene {
	DNA p;
	String type;

	ArrayList<Integer> adress = new ArrayList<Integer>();
	int depth;
	int nodes = 0;

	int argsBinder;
	float phaseOffset;

	Gene(DNA p_, String type_) {
		this(p_, type_, true);
	}

	Gene(DNA p_, String type_, boolean initialize) {
		p = p_;
		type = type_;
		if (!initialize) return;

		if (type == "x") nodes = 0;
		if (type == "y") nodes = 0;
		if (type == "time") nodes = 0;
		if (type == "sintime") {
			nodes = 0;
			phaseOffset = random(TWO_PI);
		}

		if (type == "add") nodes = 2;
		if (type == "sub") nodes = 2;
		if (type == "mult")	nodes = 2;
		if (type == "div") nodes = 2;

		if (type == "pow2") nodes = 1;
		if (type == "sqrt") nodes = 1;
		if (type == "powOf") nodes = 2;
		if (type == "logOf") nodes = 2;
		if (type == "2pow") nodes = 1;
		if (type == "2log") nodes = 1;

		if (type == "mod") nodes = 2;
		if (type == "fract") nodes = 1;
		if (type == "floor") nodes = 1;
		if (type == "ceil") nodes = 1;
		if (type == "round") nodes = 1;

		if (type == "min") nodes = 2;
		if (type == "max") nodes = 2;
		if (type == "clamp") nodes = 3;
		if (type == "abs") nodes = 1;

		if (type == "sin") nodes = 1;
		if (type == "cos") nodes = 1;
		if (type == "tan") nodes = 1;
		if (type == "asin") nodes = 1;
		if (type == "acos") nodes = 1;
		if (type == "atan") nodes = 2;

		if (type == "mix") nodes = 3;

		if (type == "if") nodes = 4;
		if (type == "and") nodes = 6;
		if (type == "or") nodes = 6;
		if (type == "xor") nodes = 6;

		if (type == "hsb2rgb") nodes = 1;
		if (type == "combine") nodes = 3;
		if (type == "setH") nodes = 2;
		if (type == "setS") nodes = 2;
		if (type == "setV") nodes = 2;
		if (type == "noise2") nodes = 2;

		if (type == "rndm") {
			nodes = 0;
			if (p.args.size() >= geneArgumentLimit) {
				argsBinder = geneArgumentLimit-1;
			} else {
				argsBinder = p.args.size();
				float temp = random(1);
				p.args.add(new PVector(temp,temp,temp));
			}
		}

		if (type == "rndm3") {
			nodes = 0;
			if (p.args.size() >= geneArgumentLimit) {
				argsBinder = geneArgumentLimit-1;
			} else {
				argsBinder = p.args.size();
				float temp = random(1);
				p.args.add(new PVector(temp+randomGaussian()*0.2,temp+randomGaussian()*0.2,temp+randomGaussian()*0.2));
			}

		}
	}

	String get() {
		if (type == "sintime") return "g_sintime(" + Float.toString(phaseOffset) + ")";

		String temp = "";

		if (type == "rndm" || type == "rndm3") {
			temp = "g_arg(";
			temp += argsBinder;

		} else {

			temp = "g_" + type + "(";


			if (nodes > 0) {
				ArrayList<Gene> children = getChildren();
				for (int i = 0; i < children.size(); i++) {
					if (i > 0) temp += ",";

					temp += children.get(i).get();

				}
			}


		}
		temp += ")";

		return temp;

	}

	Gene copy(DNA p_) {
		// Copying a branch must not allocate unused random arguments in its owner.
		Gene temp = new Gene(p_, type, false);
		temp.adress = new ArrayList<Integer>(adress);
		temp.depth = depth;
		temp.nodes = nodes;
		temp.argsBinder = argsBinder;
		temp.phaseOffset = phaseOffset;
		return temp;
	}

	void setAdress(ArrayList<Integer> a) {
		adress = a;
		depth = a.size();
	}

	ArrayList<Gene> getChildren() {
		ArrayList<Gene> children = new ArrayList<Gene>();
		for (int i = 0; i < nodes; i++) {
			ArrayList<Integer> con = new ArrayList<Integer>(adress);
			con.add(i);
			Gene child = p.getGeneByAdress(con);
			children.add(child);
		}
		return children;
	}
}
