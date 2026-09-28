// Persist raw slider positions, so relative probabilities survive a restart.
String probabilityDefaultsPath() {
  return dataPath("probability-defaults.json");
}

float probabilitySetting(JSONObject settings, String key, float fallback, float low, float high) {
  float value = settings.getFloat(key, fallback);
  if (Float.isNaN(value) || Float.isInfinite(value)) return fallback;
  return constrain(value, low, high);
}

void loadProbabilityDefaults(App owner) {
  if (!new java.io.File(probabilityDefaultsPath()).isFile()) return;
  try {
    JSONObject settings = loadJSONObject(probabilityDefaultsPath());
    if (settings == null) return;
    JSONObject probabilities = settings.getJSONObject("probabilities");
    // Preserve defaults saved before the position constant was renamed to pxy.
    if (!probabilities.hasKey("pxy") && probabilities.hasKey("pos")) {
      probabilities.setFloat("pxy", probabilitySetting(probabilities, "pos", geneSliderValue("pxy"), 0, 1));
    }
    String[][] renamedFunctions = {
      {"pxadd", "pxaddp"}, {"pxsub", "pxsubp"},
      {"padd", "pxaddp"}, {"psub", "pxsubp"}, {"pscale", "pxscale"}, {"prot", "pxrot"},
      {"sdfcol", "sdfimg"},
      {"colscreen", "imgscreen"}, {"coladd", "imgadd"},
      {"colmult", "imgmult"}, {"colsub", "imgsub"},
      {"coloverlay", "imgoverlay"}, {"coldiff", "imgdiff"},
      {"coldarken", "imgdarken"}, {"collighten", "imglighten"}
    };
    for (String[] rename : renamedFunctions) {
      if (!probabilities.hasKey(rename[1]) && probabilities.hasKey(rename[0])) {
        probabilities.setFloat(rename[1], probabilitySetting(probabilities, rename[0], geneSliderValue(rename[1]), 0, 1));
      }
    }
    HashMap<String, Float> loaded = new HashMap<String, Float>();
    for (String[] names : new String[][] {genesValues, geneFunctionPool}) {
      for (String name : names) {
        loaded.put(name, geneEnabled(name) ? probabilitySetting(probabilities, name, geneSliderValue(name), 0, 1) : 0.0f);
      }
    }
    // Keep leaves available, or a function for types without leaves.
    for (GeneValueType valueType : GeneValueType.values()) {
      String[] values = geneTerminalCandidates(valueType);
      float valueTotal = 0;
      for (String name : values) valueTotal += loaded.get(name);
      if (values.length > 0 && valueTotal <= 0) loaded.put(values[0], 1.0f);
    }

    int savedDepth = round(probabilitySetting(settings, "depth", depth_max, 3, 32));
    int savedWidth = round(probabilitySetting(settings, "width", width_max, 3, 32));
    float savedMutation = probabilitySetting(settings, "mutation", owner.mutationRate, 0, 2000);
    float savedExponent = settings.getFloat("probabilityExponent", probability_exponent);
    if (Float.isNaN(savedExponent) || Float.isInfinite(savedExponent) || savedExponent <= 0) {
      savedExponent = probability_exponent;
    }

    // Apply only after the complete file has been read successfully.
    geneSliderValues.putAll(loaded);
    depth_max = savedDepth;
    width_max = savedWidth;
    owner.mutationRate = savedMutation;
    probability_exponent = savedExponent;
  } catch (Exception error) {
    println("Could not load probability defaults: " + error.getMessage());
  }
}

boolean saveProbabilityDefaults(App owner) {
  try {
    JSONObject probabilities = new JSONObject();
    for (String[] names : new String[][] {genesValues, geneFunctionPool}) {
      for (String name : names) probabilities.setFloat(name, geneSliderValue(name));
    }
    JSONObject settings = new JSONObject();
    settings.setJSONObject("probabilities", probabilities);
    settings.setInt("depth", depth_max);
    settings.setInt("width", width_max);
    settings.setFloat("mutation", owner.mutationRate);
    settings.setFloat("probabilityExponent", probability_exponent);
    return saveJSONObject(settings, probabilityDefaultsPath());
  } catch (Exception error) {
    println("Could not save probability defaults: " + error.getMessage());
    return false;
  }
}
