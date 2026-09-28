float probability_exponent = 2;
int depth_max = 6;
int width_max = 6;
// u_args in fragment.glsl contains 512 floats; each random value uses three.
final int geneArgumentLimit = 512 / 3;

// Semantic graph types: vec3/col/img use vec3, pxy/pnt use vec2, sdf/ramp/cycle use float.
// Ramp conventionally oscillates in 0..1; cycle progresses through the 1/0 seam.
// Both are semantic conventions: their values are deliberately unrestricted.
enum GeneValueType { VEC3, COL, IMG, PXY, PNT, SDF, RAMP, CYCLE }

// Display order follows the flow from coordinates and parameters to images.
GeneValueType[] visibleGeneTypes = { GeneValueType.PXY, GeneValueType.PNT, GeneValueType.RAMP, GeneValueType.CYCLE, GeneValueType.SDF, GeneValueType.COL, GeneValueType.IMG };

color geneTypeColor(GeneValueType valueType) {
	if (valueType == GeneValueType.PXY) return color(87, 199, 227);
	if (valueType == GeneValueType.PNT) return color(127, 167, 255);
	if (valueType == GeneValueType.RAMP) return color(230, 184, 92);
	if (valueType == GeneValueType.CYCLE) return color(240, 128, 146);
	if (valueType == GeneValueType.SDF) return color(115, 213, 165);
	if (valueType == GeneValueType.COL) return color(189, 145, 237);
	if (valueType == GeneValueType.IMG) return color(240, 159, 92);
	return color(144, 153, 168);
}

boolean geneEnabled(String name) {
	// anycol requires the disabled vec3 branch, so hide it along with that type.
	return geneOutputType(name) != GeneValueType.VEC3 && !name.equals("anycol");
}

GeneValueType geneOutputType(String name) {
	if (name.equals("anycol") || name.equals("colrnd") || name.equals("colhsv")) return GeneValueType.COL;
	if (name.equals("sdfimg") || isImageBlend(name)) return GeneValueType.IMG;
	if (name.equals("pxy") || name.equals("pxaddp") || name.equals("pxsubp") || name.equals("pxaddpx") || name.equals("pxsubpx") || name.equals("pxscale") || name.equals("pxrot") || isPositionTile(name)) return GeneValueType.PXY;
	if (name.equals("prnd")) return GeneValueType.PNT;
	if (isSDFShape(name) || isSDFComposite(name)) return GeneValueType.SDF;
	if (name.equals("rrnd") || name.equals("rsdfsin") || name.equals("rcsin") || name.equals("ravg") || name.equals("rmix")) return GeneValueType.RAMP;
	if (name.equals("ctime") || name.equals("crnd") || name.equals("cdfcyc")) return GeneValueType.CYCLE;
	return GeneValueType.VEC3;
}

boolean isImageBlend(String name) {
	return name.equals("imgscreen") || name.equals("imgadd") || name.equals("imgmult") || name.equals("imgsub") || name.equals("imgoverlay") || name.equals("imgdiff") || name.equals("imgdarken") || name.equals("imglighten");
}

boolean isPositionTile(String name) {
	return name.equals("tilex") || name.equals("tiley") || name.equals("tilexy") || name.equals("tilerot");
}

boolean isSDFShape(String name) {
	return name.equals("circle") || name.equals("box") || name.equals("roundbox") || name.equals("triangle") || name.equals("hexagon") || name.equals("capsule") || name.equals("ring") || name.equals("point") || name.equals("linex") || name.equals("liney") || name.equals("segment");
}

boolean isSmoothSDFComposite(String name) {
	return name.equals("smunion") || name.equals("sminter") || name.equals("smsub");
}

boolean isSDFComposite(String name) {
	return name.equals("sunion") || name.equals("sinter") || name.equals("ssub") || isSmoothSDFComposite(name);
}

String[] genesReturning(String[] names, GeneValueType requiredType) {
	ArrayList<String> matches = new ArrayList<String>();
	for (String name : names) {
		if (geneEnabled(name) && geneOutputType(name) == requiredType) matches.add(name);
	}
	return matches.toArray(new String[0]);
}

// Raw slider positions, keyed by gene rather than by UI group.
HashMap<String, Float> geneSliderValues = new HashMap<String, Float>();

float geneSliderValue(String name) {
	if (!geneEnabled(name)) return 0;
	Float value = geneSliderValues.get(name);
	if (value != null) return value;
	if (name.equals("prnd")) return 0.5;
	if (name.equals("pxaddp")) return 0.4;
	if (name.equals("pxsubp")) return 0.5;
	if (name.equals("sunion") || name.equals("smunion")) return 0.7;
	if (name.equals("sinter") || name.equals("sminter")) return 0.35;
	if (name.equals("ssub") || name.equals("smsub")) return 0.5;
	return 1;
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
	"xy",
	"pxy",
	"prnd",
	"rrnd",
	"ctime",
	"crnd",
	"colrnd",
	"u",
	"v",
	"uv",
	"mx",
	"my",
	"mxy",
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
	"length",
	"norm",
	"rot",
	"hsb2rgb",
	"combine",
	"setH",
	"setS",
	"setV"
	//"noise2"
};


String[] genesColor = new String[] { "anycol", "colhsv" };
String[] genesImage = new String[] { "sdfimg", "imgscreen", "imgadd", "imgmult", "imgsub", "imgoverlay", "imgdiff", "imgdarken", "imglighten" };
String[] genesSDF = new String[] { "circle", "box", "roundbox", "triangle", "hexagon", "capsule", "ring", "point", "linex", "liney", "segment", "sunion", "sinter", "ssub", "smunion", "sminter", "smsub" };
String[] genesPosition = new String[] { "pxaddp", "pxsubp", "pxaddpx", "pxsubpx", "pxscale", "pxrot", "tilex", "tiley", "tilexy", "tilerot" };
String[] genesCycle = new String[] { "cdfcyc" };
String[] genesRamp = new String[] { "rsdfsin", "rcsin", "ravg", "rmix" };

String[][] genesMethods = new String[][] {
	genesBasicMath,
	genesExponential,
	genesRound,
	genesTrig,
	genesConstrain,
	genesMix,
	genesLogic,
	genesElse,
	genesColor,
	genesSDF,
	genesPosition,
	genesCycle,
	genesRamp,
	genesImage
};


// Selection filters this pool by output type; values are selected at branch ends.
// The groups above only determine card layout.
String[] geneFunctionPool = createGeneFunctionPool();

int geneMinimumDepth(String name) {
	for (String value : genesValues) if (value.equals(name)) return 1;
	// Each blend input must contain a complete sdfimg(shape(pxy), col, ramp).
	if (isImageBlend(name)) return 4;
	// SDF inputs need complete shape(pxy) branches below them.
	return name.equals("sdfimg") || name.equals("cdfcyc") || name.equals("rsdfsin") || isSDFComposite(name) ? 3 : 2;
}

String[] geneTerminalCandidates(GeneValueType valueType) {
	String[] values = genesReturning(genesValues, valueType);
	if (values.length > 0) return values;
	String[] functions = genesReturning(geneFunctionPool, valueType);
	int shortest = Integer.MAX_VALUE;
	for (String name : functions) shortest = min(shortest, geneMinimumDepth(name));
	ArrayList<String> terminals = new ArrayList<String>();
	for (String name : functions) {
		if (geneMinimumDepth(name) == shortest) terminals.add(name);
	}
	return terminals.toArray(new String[0]);
}

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
	if (n == 8) return "Color";
	if (n == 9) return "SDF";
	if (n == 10) return "Position";
	if (n == 11) return "Cycle";
	if (n == 12) return "Ramp";
	if (n == 13) return "Image";
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
	float radius = 0.5; // Circle parameter; its only graph input is a position.

	Gene(DNA p_, String type_) {
		this(p_, type_, true);
	}

	Gene(DNA p_, String type_, boolean initialize) {
		p = p_;
		type = type_;
		if (!initialize) return;

		if (type == "x") nodes = 0;
		if (type == "y") nodes = 0;
		if (type == "xy") nodes = 0;
		if (type == "pxy") nodes = 0;
		if (type == "u") nodes = 0;
		if (type == "v") nodes = 0;
		if (type == "uv") nodes = 0;
		if (type == "mx") nodes = 0;
		if (type == "my") nodes = 0;
		if (type == "mxy") nodes = 0;
		if (type == "time") nodes = 0;
		if (type == "ctime") nodes = 0;
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

		if (type == "length") nodes = 1;
		if (type == "norm") nodes = 1;
		if (type == "rot") nodes = 2;
		if (type == "hsb2rgb") nodes = 1;
		if (type == "combine") nodes = 3;
		if (type == "setH") nodes = 2;
		if (type == "setS") nodes = 2;
		if (type == "setV") nodes = 2;
		if (type == "noise2") nodes = 2;
		if (type == "anycol") nodes = 1;
		if (type.equals("sdfimg")) nodes = 3;
		if (type.equals("colhsv")) nodes = 3;
		if (isImageBlend(type)) nodes = 2;
		if (isSDFShape(type)) nodes = 1;
		if (type.equals("cdfcyc") || type.equals("rsdfsin") || type.equals("rcsin")) nodes = 1;
		if (type.equals("ravg")) nodes = 2;
		if (type.equals("rmix")) nodes = 3;
		if (isSDFComposite(type)) nodes = isSmoothSDFComposite(type) ? 3 : 2;
		if (type.equals("pxaddp") || type.equals("pxsubp") || type.equals("pxaddpx") || type.equals("pxsubpx") || type.equals("pxscale") || type.equals("pxrot")) nodes = 2;
		if (isPositionTile(type)) nodes = type.equals("tilexy") ? 3 : 2;

		if (type == "prnd") {
			nodes = 0;
			if (p.args.size() >= geneArgumentLimit) {
				argsBinder = geneArgumentLimit-1;
			} else {
				argsBinder = p.args.size();
				p.args.add(new PVector(random(-0.5, 0.5), random(-0.5, 0.5), 0));
			}
		}

		if (type == "rndm" || type == "rrnd" || type == "crnd") {
			nodes = 0;
			if (p.args.size() >= geneArgumentLimit) {
				argsBinder = geneArgumentLimit-1;
			} else {
				argsBinder = p.args.size();
				float temp = random(1);
				p.args.add(new PVector(temp,temp,temp));
			}
		}

		if (type.equals("colrnd")) {
			nodes = 0;
			if (p.args.size() >= geneArgumentLimit) {
				argsBinder = geneArgumentLimit-1;
			} else {
				argsBinder = p.args.size();
				p.args.add(new PVector(random(1), random(1), random(1)));
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

	GeneValueType outputType() {
		return geneOutputType(type);
	}

	GeneValueType inputType(int index) {
		if (index < 0 || index >= nodes) throw new IllegalArgumentException("Invalid gene input");
		if (type.equals("pxscale") || isPositionTile(type)) return index == 0 ? GeneValueType.PXY : GeneValueType.RAMP;
		if (type.equals("pxrot")) return index == 0 ? GeneValueType.PXY : GeneValueType.CYCLE;
		if (type.equals("pxaddp") || type.equals("pxsubp")) return index == 0 ? GeneValueType.PXY : GeneValueType.PNT;
		if (type.equals("pxaddpx") || type.equals("pxsubpx") || isSDFShape(type)) return GeneValueType.PXY;
		if (type.equals("cdfcyc") || type.equals("rsdfsin")) return GeneValueType.SDF;
		if (type.equals("rcsin")) return GeneValueType.CYCLE;
		if (type.equals("ravg") || type.equals("rmix")) return GeneValueType.RAMP;
		if (type.equals("colhsv")) return index == 0 ? GeneValueType.CYCLE : GeneValueType.RAMP;
		if (isImageBlend(type)) return GeneValueType.IMG;
		if (type.equals("sdfimg")) {
			if (index == 0) return GeneValueType.SDF;
			return index == 1 ? GeneValueType.COL : GeneValueType.RAMP;
		}
		if (isSDFComposite(type)) return index < 2 ? GeneValueType.SDF : GeneValueType.RAMP;
		// Existing operations and anycol all accept only vec3 inputs.
		return GeneValueType.VEC3;
	}

	boolean usesArguments() {
		return type.equals("rndm") || type.equals("rndm3") || type.equals("prnd") || type.equals("rrnd") || type.equals("crnd") || type.equals("colrnd");
	}

	String get() {
		if (type == "sintime") return "g_sintime(" + Float.toString(phaseOffset) + ")";

		String temp = "";

		if (usesArguments()) {
			temp = type.equals("prnd") ? "g_prnd(" : "g_arg(";
			if (type.equals("rrnd")) temp = "g_rrnd(";
			if (type.equals("crnd")) temp = "g_crnd(";
			if (type.equals("colrnd")) temp = "g_colrnd(";
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
		if (type.equals("circle")) temp += "," + Float.toString(radius);
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
		temp.radius = radius;
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
