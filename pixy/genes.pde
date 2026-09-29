String[] genesValues = new String[] {
	"x",
	"y",
	"rndm",
	"rndm3"
};
float[] genesValuesRate = new float[] {1, 1, 0.5, 0.5, 0.5};


String[] genesBasicMath = new String[] {
	"add",
	"sub",
	"mult",
	"div"
};
float[] genesBasicMathRate = new float[] {1, 1, 1, 1};

String[] genesExponential = new String[] {
	"pow2",
	"sqrt",
	"powOf",
	"logOf",
	"2pow",
	"2log"
};
float[] genesExponentialRate = new float[] {1, 1, 0.3, 0.3, 0.3, 0.3};


String[] genesRound = new String[] {
	"mod",
	"fract",
	"floor",
	"ceil",
	"round"
};
float[] genesRoundRate = new float[] {0.5, 1, 1, 1, 1, 1};

String[] genesTrig = new String[] {
	"sin",
	"cos",
	"tan",
	"asin",
	"acos",
	"atan"
};
float[] genesTrigRate = new float[] {1, 1, 0.1, 0.1, 0.1, 0.5};


String[] genesConstrain = new String[] {
	"min",
	"max",
	"clamp",
	"abs"
};
float[] genesConstrainRate = new float[] {1, 1, 0.5, 1};


String[] genesMix = new String[] {
	"mix"
};
float[] genesMixRate = new float[] {1};

String[] genesLogic = new String[] {
	"if",
	"and",
	"or",
	"xor"
};
float[] genesLogicRate = new float[] {1,1,1,1};


String[] genesElse = new String[] {
	"hsb2rgb",
	"combine",
	"setH",
	"setS",
	"setV",
	"noise2"
};
float[] genesElseRate = new float[] {1, 1, 1, 1, 1, 1, 1};


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
float[] genesMethodsGroupRate = new float[] {1, 0.01, 0.1, 0.1, 0.1, 0.1, 0.1, 0.05};

float[][] genesMethodsRate = new float[][] {
	genesBasicMathRate,
	genesExponentialRate,
	genesRoundRate,
	genesTrigRate,
	genesConstrainRate,
	genesMixRate,
	genesLogicRate,
	genesElseRate
};

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

	Gene(DNA p_, String type_) {
		p = p_;
		type = type_;

		if (type == "x") nodes = 0;
		if (type == "y") nodes = 0;

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
			if (p.args.size() >= 511) {
				argsBinder = 511;
			} else {
				argsBinder = p.args.size();
				float temp = random(1);
				p.args.add(new PVector(temp,temp,temp));
			}
		}

		if (type == "rndm3") {
			nodes = 0;
			if (p.args.size() >= 511) {
				argsBinder = 511;
			} else {
				argsBinder = p.args.size();
				float temp = random(1);
				p.args.add(new PVector(temp+randomGaussian()*0.2,temp+randomGaussian()*0.2,temp+randomGaussian()*0.2));
			}

		}
	}

	String get() {

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
		Gene temp = new Gene(p_, type);
		temp.adress = new ArrayList<Integer>(adress);
		temp.depth = depth;
		temp.nodes = nodes;
		temp.argsBinder = argsBinder;
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