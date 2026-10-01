// Enabled node formulas ported from data/fragment.glsl.
#define M_PI 3.1415926535897932384626433832795
uniform vec2 u_resolution;
uniform vec2 u_origin;
uniform vec2 u_off;
uniform float u_scale;
uniform float u_time;
uniform int u_aa;
uniform highp sampler2D u_previous;
uniform bool u_feedbackDebug;
vec2 sampleOffset;
vec2 g_pxy() {
  vec2 p = (gl_FragCoord.xy - u_origin + sampleOffset) * (4.0 / u_resolution.x);
  p -= vec2(2.0, 2.0 * u_resolution.y / u_resolution.x);
  return (p + u_off) * u_scale;
}
vec2 g_pxaddp(vec2 a, vec2 b) {
	return a + b;
}

vec2 g_pxsubp(vec2 a, vec2 b) {
	return a - b;
}

vec2 g_pxaddpx(vec2 a, vec2 b) {
	return a + b;
}

vec2 g_pxsubpx(vec2 a, vec2 b) {
	return a - b;
}

vec2 g_pxscale(vec2 p, float ramp) {
	return p / ramp;
}

vec2 g_pxscaled(vec2 p, float cycle, float ramp) {
	float angle = cycle * 2.0 * M_PI;
	vec2 axis = vec2(cos(angle), sin(angle));
	float scale = 2.0 * clamp(ramp, 0.0, 1.0);
	// Approximate zero with a near-zero scale to keep coordinates finite.
	scale = max(scale, 0.000001);
	float parallel = dot(p, axis);
	return p + (parallel / scale - parallel) * axis;
}

vec2 g_pxrot(vec2 p, float cycle) {
	float angle = cycle * 2.0 * M_PI;
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}

float tileCount(float ramp) {
	return floor(1.0 + 5.0 * clamp(ramp, 0.0, 1.0) + 0.5);
}

float tileAxis(float position, float count, float halfExtent) {
	float uv = position / (2.0 * halfExtent) + 0.5;
	return (fract(uv * count) * 2.0 - 1.0) * halfExtent;
}

vec2 g_tilex(vec2 p, float ramp) {
	return vec2(tileAxis(p.x, tileCount(ramp), 1.0), p.y);
}

vec2 g_tiley(vec2 p, float ramp) {
	float halfHeight = u_resolution.y / u_resolution.x;
	return vec2(p.x, tileAxis(p.y, tileCount(ramp), halfHeight));
}

vec2 g_tilexy(vec2 p, float rampX, float rampY) {
	float halfHeight = u_resolution.y / u_resolution.x;
	return vec2(tileAxis(p.x, tileCount(rampX), 1.0),
		tileAxis(p.y, tileCount(rampY), halfHeight));
}

vec2 g_tilerot(vec2 p, float ramp) {
	float count = tileCount(ramp);
	float radial = length(p);
	if (count == 1.0 || radial == 0.0) return p;
	float sector = 2.0 * M_PI / count;
	float angle = mod(atan(p.y, p.x) + 0.5 * sector, sector) - 0.5 * sector;
	return radial * vec2(cos(angle), sin(angle));
}

float g_circle(vec2 p, float radius) {
	return length(p) - radius;
}

float g_point(vec2 p) {
	return length(p);
}

float g_linex(vec2 p) {
	return p.x;
}

float g_liney(vec2 p) {
	return p.y;
}

float g_segment(vec2 p) {
	p.x -= clamp(p.x, -0.5, 0.5);
	return length(p);
}

float g_box(vec2 p) {
	vec2 q = abs(p) - vec2(0.5);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

float g_roundbox(vec2 p) {
	vec2 q = abs(p) - vec2(0.4);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.1;
}

float sdfRegularPolygon(vec2 p, float sides) {
	float halfAngle = M_PI / sides;
	float apothem = 0.5 * cos(halfAngle);
	float halfEdge = 0.5 * sin(halfAngle);
	float radial = length(p);
	if (radial == 0.0) return -apothem;
	float angle = mod(atan(p.y, p.x) + halfAngle, 2.0 * halfAngle) - halfAngle;
	vec2 q = radial * vec2(cos(angle), sin(angle));
	vec2 edgeOffset = q - vec2(apothem, clamp(q.y, -halfEdge, halfEdge));
	return length(edgeOffset) * sign(q.x - apothem);
}

float g_triangle(vec2 p) {
	// Point one vertex upward; the centroid stays at the origin.
	return sdfRegularPolygon(vec2(-p.y, p.x), 3.0);
}

float g_hexagon(vec2 p) {
	return sdfRegularPolygon(p, 6.0);
}

float g_capsule(vec2 p) {
	p.x -= clamp(p.x, -0.25, 0.25);
	return length(p) - 0.25;
}

float g_ring(vec2 p) {
	return abs(length(p) - 0.4) - 0.1;
}

float g_sunion(float a, float b) {
	return min(a, b);
}

float g_sinter(float a, float b) {
	return max(a, b);
}

float g_ssub(float a, float b) {
	return max(a, -b);
}

float g_smunion(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float g_sminter(float a, float b, float k) {
	return -g_smunion(-a, -b, k);
}

float g_smsub(float a, float b, float k) {
	return g_sminter(a, -b, k);
}

float g_edge(float distance, float width, float smoothness) {
	float halfWidth = 0.5 * clamp(width, 0.0, 1.0);
	if (smoothness == 0.0) return abs(distance) - halfWidth;
	return g_sminter(distance - halfWidth, -distance - halfWidth, smoothness);
}

vec3 g_colhsv(float hue, float saturation, float value) {
	vec3 phase = fract(fract(hue * 0.1) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0));
	vec3 rgb = clamp(abs(phase * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return clamp(value, 0.0, 1.0) * mix(vec3(1.0), rgb, clamp(saturation, 0.0, 1.0));
}

float g_cdfcyc(float distance) {
	return distance;
}

float g_cadd(float cycle, float ramp) {
	return cycle + ramp;
}

float g_csub(float cycle, float ramp) {
	return cycle - ramp;
}

float g_cmul(float cycle, float ramp) {
	return cycle * ramp;
}

float g_rsdfsin(float distance) {
	return 0.5 + 0.5 * sin(distance * 2.0 * M_PI);
}

float g_rcsin(float cycle) {
	return 0.5 + 0.5 * sin(cycle * 2.0 * M_PI);
}

float g_rsq(float cycle) {
	return 1.0 - step(0.5, fract(cycle));
}

float g_rtri(float cycle) {
	return 1.0 - abs(2.0 * fract(cycle) - 1.0);
}

float g_rup(float cycle) {
	return fract(cycle);
}

float g_ravg(float a, float b) {
	return (a + b) / 2.0;
}

float g_rmix(float a, float b, float amount) {
	return mix(a, b, clamp(amount, 0.0, 1.0));
}

float g_ctime() {
	return u_time;
}

vec3 blendImageInput(vec3 value) {
	return clamp(value, 0.0, 1.0);
}

vec3 g_imgmix(vec3 a, vec3 b, float amount) {
	return mix(blendImageInput(a), blendImageInput(b), clamp(amount, 0.0, 1.0));
}

vec3 g_imgscreen(vec3 a, vec3 b) {
	a = blendImageInput(a);
	b = blendImageInput(b);
	return vec3(1.0) - (vec3(1.0) - a) * (vec3(1.0) - b);
}

vec3 g_imgadd(vec3 a, vec3 b) {
	return min(blendImageInput(a) + blendImageInput(b), vec3(1.0));
}

vec3 g_imgmult(vec3 a, vec3 b) {
	return blendImageInput(a) * blendImageInput(b);
}

vec3 g_imgsub(vec3 a, vec3 b) {
	return max(blendImageInput(a) - blendImageInput(b), vec3(0.0));
}

vec3 g_imgoverlay(vec3 a, vec3 b) {
	a = blendImageInput(a);
	b = blendImageInput(b);
	vec3 dark = 2.0 * a * b;
	vec3 light = vec3(1.0) - 2.0 * (vec3(1.0) - a) * (vec3(1.0) - b);
	return mix(dark, light, step(vec3(0.5), a));
}

vec3 g_imgdiff(vec3 a, vec3 b) {
	return abs(blendImageInput(a) - blendImageInput(b));
}

vec3 g_imgdarken(vec3 a, vec3 b) {
	return min(blendImageInput(a), blendImageInput(b));
}

vec3 g_imglighten(vec3 a, vec3 b) {
	return max(blendImageInput(a), blendImageInput(b));
}

vec3 g_sdfimg(float distance, vec3 shapeColor, float smoothAmount) {
	// Zero gives a hard edge; one spans -0.5 to 0.5 distance units.
	// Normalize distance so unrestricted negative ramps also have defined behavior.
	float shade;
	if (smoothAmount == 0.0) shade = 1.0 - step(0.0, distance);
	else shade = 1.0 - smoothstep(-0.5, 0.5, distance / smoothAmount);
	return shapeColor * shade;
}

vec3 g_feedback(vec2 position) {
  if (u_feedbackDebug) return vec3(0.0, 1.0, 0.0);
  if (any(isnan(position)) || any(isinf(position))) return vec3(0.0);
  return texture(u_previous, position * 0.5 + 0.5).rgb;
}
