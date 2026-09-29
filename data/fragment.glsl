#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define M_PI 3.1415926535897932384626433832795

uniform vec2 u_g_off;
uniform float u_g_scale;
uniform vec2 u_off;
uniform float u_scale;
uniform float u_hoff;
uniform float u_args[512];
uniform float u_time;
uniform vec4 u_uv_rect;
uniform vec2 u_mouse;


vec3 precol[64];
uniform int u_aa;
int iterX = 0;
int iterY = 0;

// VALUES

vec3 g_x() {
	float scale = (u_g_scale * u_scale);
	float off = (u_g_off.x + u_off.x) * u_scale;
	float temp = off + gl_FragCoord.x * scale;
	temp = temp + (float(iterX)/float(u_aa)) * scale;
	return vec3(temp,temp,temp);
}

vec3 g_y() {
	float scale = u_g_scale * u_scale;
	float off = (u_g_off.y + u_off.y) * u_scale;
	float temp = off + (gl_FragCoord.y) * scale;
	temp = temp + (float(iterY)/float(u_aa)) * scale;
	return vec3(temp,temp,temp);
}

vec3 g_xy() {
	return vec3(g_x().x, g_y().x, 0.0);
}

// Position in the same panned/scaled coordinate space as x and y.
vec2 g_pxy() {
	return vec2(g_x().x, g_y().x);
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

// Ramp 0..1 sets visible directional scale 0..2 about the origin.
vec2 g_pxscaled(vec2 p, float cycle, float ramp) {
	float angle = cycle * 2.0 * M_PI;
	vec2 axis = vec2(cos(angle), sin(angle));
	float scale = 2.0 * clamp(ramp, 0.0, 1.0);
	// Approximate zero with a near-zero scale to keep coordinates finite.
	scale = max(scale, 0.000001);
	float parallel = dot(p, axis);
	return p + (parallel / scale - parallel) * axis;
}

// A cycle is measured in turns; 0 and 1 produce the same rotation.
vec2 g_pxrot(vec2 p, float cycle) {
	float angle = cycle * 2.0 * M_PI;
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}

// Ramp 0..1 maps to the nearest integer 1..6. Mutation can exceed 0..1.
float tileCount(float ramp) {
	return floor(1.0 + 5.0 * clamp(ramp, 0.0, 1.0) + 0.5);
}

// Default fullscreen coordinates span -1..1 in X; Y follows image aspect.
// Normalize to 0..1 before tiling, then restore the centered coordinate range.
float tileAxis(float position, float count, float halfExtent) {
	float uv = position / (2.0 * halfExtent) + 0.5;
	return (fract(uv * count) * 2.0 - 1.0) * halfExtent;
}

vec2 g_tilex(vec2 p, float ramp) {
	return vec2(tileAxis(p.x, tileCount(ramp), 1.0), p.y);
}

vec2 g_tiley(vec2 p, float ramp) {
	float halfHeight = u_uv_rect.w / u_uv_rect.z;
	return vec2(p.x, tileAxis(p.y, tileCount(ramp), halfHeight));
}

vec2 g_tilexy(vec2 p, float rampX, float rampY) {
	float halfHeight = u_uv_rect.w / u_uv_rect.z;
	return vec2(tileAxis(p.x, tileCount(rampX), 1.0),
		tileAxis(p.y, tileCount(rampY), halfHeight));
}

// Repeat a sector around the origin, preserving radial distance.
vec2 g_tilerot(vec2 p, float ramp) {
	float count = tileCount(ramp);
	float radial = length(p);
	if (count == 1.0 || radial == 0.0) return p;
	float sector = 2.0 * M_PI / count;
	float angle = mod(atan(p.y, p.x) + 0.5 * sector, sector) - 0.5 * sector;
	return radial * vec2(cos(angle), sin(angle));
}

// Signed distance: negative inside, zero on the edge, positive outside.
float g_circle(vec2 p, float radius) {
	return length(p) - radius;
}

// Zero-radius point at the origin: nonnegative radial distance.
float g_point(vec2 p) {
	return length(p);
}

// Signed linear distance fields; phase advances along the named axis.
float g_linex(vec2 p) {
	return p.x;
}

float g_liney(vec2 p) {
	return p.y;
}

// Distance to a zero-width horizontal segment from (-0.5, 0) to (0.5, 0).
float g_segment(vec2 p) {
	p.x -= clamp(p.x, -0.5, 0.5);
	return length(p);
}

// Fixed-size primitives; graph inputs contain only the position.
float g_box(vec2 p) {
	vec2 q = abs(p) - vec2(0.5);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

// Outer half-size 0.5, corner radius 0.1.
float g_roundbox(vec2 p) {
	vec2 q = abs(p) - vec2(0.4);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.1;
}

// Fold a regular polygon into the sector facing its rightmost edge, then
// measure distance to that finite edge. Circumradius is always 0.5.
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

// Horizontal capsule: segment endpoints +/-0.25, radius 0.25.
float g_capsule(vec2 p) {
	p.x -= clamp(p.x, -0.25, 0.25);
	return length(p) - 0.25;
}

// Annulus: inner radius 0.3, outer radius 0.5.
float g_ring(vec2 p) {
	return abs(length(p) - 0.4) - 0.1;
}

// SDF compositing. Subtraction consistently means first shape minus second.
float g_sunion(float a, float b) {
	return min(a, b);
}

float g_sinter(float a, float b) {
	return max(a, b);
}

float g_ssub(float a, float b) {
	return max(a, -b);
}

// Polynomial smooth minimum; k is the blend width in distance units.
// Only the interpolation weight is clamped; the ramp input remains raw.
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

// Outline centered on the input's zero contour; width is total thickness.
float g_edge(float distance, float width, float smoothness) {
	float halfWidth = 0.5 * clamp(width, 0.0, 1.0);
	if (smoothness == 0.0) return abs(distance) - halfWidth;
	return g_sminter(distance - halfWidth, -distance - halfWidth, smoothness);
}

// Image-local UVs: bottom-left (0, 0), top-right (1, 1).
vec3 g_uv() {
	vec2 sampleOffset = vec2(float(iterX), float(iterY)) / float(u_aa);
	vec2 uv = (gl_FragCoord.xy + sampleOffset - u_uv_rect.xy) / u_uv_rect.zw;
	return vec3(uv, 0.0);
}

vec3 g_u() {
	return vec3(g_uv().x);
}

vec3 g_v() {
	return vec3(g_uv().y);
}

vec3 g_mx() {
	return vec3(u_mouse.x);
}

vec3 g_my() {
	return vec3(u_mouse.y);
}

vec3 g_mxy() {
	return vec3(u_mouse, 0.0);
}

vec3 g_arg(int n) {
	return vec3(u_args[n*3], u_args[n*3+1], u_args[n*3+2]);
}

// One random RGB color per gene, shared by every pixel and frame.
vec3 g_colrnd(int n) {
	return g_arg(n);
}

// Ten input cycles make one hue revolution; saturation and value use 0..1.
vec3 g_colhsv(float hue, float saturation, float value) {
	vec3 phase = fract(fract(hue * 0.1) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0));
	vec3 rgb = clamp(abs(phase * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return clamp(value, 0.0, 1.0) * mix(vec3(1.0), rgb, clamp(saturation, 0.0, 1.0));
}

// Ramp is a semantic type; negative values and values above one are valid.
float g_rrnd(int n) {
	return g_arg(n).x;
}

// A random phase that remains constant during playback and can evolve.
float g_crnd(int n) {
	return g_arg(n).x;
}

// Interpret signed distance as a cycle phase without clamping or wrapping.
float g_cdfcyc(float distance) {
	return distance;
}

// Cycle arithmetic remains unrestricted; consumers interpret the phase.
float g_cadd(float cycle, float ramp) {
	return cycle + ramp;
}

float g_csub(float cycle, float ramp) {
	return cycle - ramp;
}

float g_cmul(float cycle, float ramp) {
	return cycle * ramp;
}

// One sine period per distance unit, remapped from -1..1 to 0..1.
float g_rsdfsin(float distance) {
	return 0.5 + 0.5 * sin(distance * 2.0 * M_PI);
}

// Cycle 0..1 covers one sine period; output is remapped to 0..1.
float g_rcsin(float cycle) {
	return 0.5 + 0.5 * sin(cycle * 2.0 * M_PI);
}

// Wrap all phases, including negative cycles, into one period.
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

// Third ramp is the blend amount: 0 selects a, 1 selects b.
float g_rmix(float a, float b, float amount) {
	return mix(a, b, clamp(amount, 0.0, 1.0));
}

// One constant random position per gene, shared by every pixel and frame.
vec2 g_prnd(int n) {
	// Argument slots can be shared at the uniform limit; keep position bounds.
	return clamp(g_arg(n).xy, vec2(-0.5), vec2(0.5));
}

// TIME

float g_ctime() {
	return u_time;
}

vec3 g_time() {
	return vec3(u_time);
}

vec3 g_sintime(float phaseOffset) {
	return vec3(sin(u_time * 2.0 * M_PI + phaseOffset));
}

// COLOR: explicit semantic conversion from vec3 to color.
vec3 g_anycol(vec3 value) {
	return value;
}

// Image blend modes use RGB channels in 0..1, including mutated colors.
vec3 blendImageInput(vec3 value) {
	return clamp(value, 0.0, 1.0);
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

// Subtract the second image from the first.
vec3 g_imgsub(vec3 a, vec3 b) {
	return max(blendImageInput(a) - blendImageInput(b), vec3(0.0));
}

// The first image is the base; its channels select multiply or screen.
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

// Input color inside the shape, black outside, with a smooth edge around zero.
vec3 g_sdfimg(float distance, vec3 shapeColor, float smoothAmount) {
	// Zero gives a hard edge; one spans -0.5 to 0.5 distance units.
	// Normalize distance so unrestricted negative ramps also have defined behavior.
	float shade;
	if (smoothAmount == 0.0) shade = 1.0 - step(0.0, distance);
	else shade = 1.0 - smoothstep(-0.5, 0.5, distance / smoothAmount);
	return shapeColor * shade;
}

// BASIC MATH

vec3 g_add(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = a.x + b.x;
	temp.y = a.y + b.y;
	temp.z = a.z + b.z;
	return temp;
}

vec3 g_sub(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = a.x - b.x;
	temp.y = a.y - b.y;
	temp.z = a.z - b.z;
	return temp;
}

vec3 g_mult(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = a.x * b.x;
	temp.y = a.y * b.y;
	temp.z = a.z * b.z;
	return temp;
}

vec3 g_div(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = a.x / b.x;
	temp.y = a.y / b.y;
	temp.z = a.z / b.z;
	return temp;
}

// EXPONENTIAL

vec3 g_pow2(vec3 a) {
	// GLSL pow() is undefined for negative bases, even with exponent 2.
	return a * a;
}

vec3 g_sqrt(vec3 a) {
	vec3 temp;
	temp.x = sqrt(abs(a.x));
	temp.y = sqrt(abs(a.y));
	temp.z = sqrt(abs(a.z));
	return temp;
}

vec3 g_powOf(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = pow(a.x, abs(b.x));
	temp.y = pow(a.y, abs(b.y));
	temp.z = pow(a.z, abs(b.z));
	return temp;
}

vec3 g_logOf(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = log(a.x)/log(b.x);
	temp.y = log(a.y)/log(b.y);
	temp.z = log(a.z)/log(b.z);
	return temp;
}

vec3 g_2pow(vec3 a) {
	vec3 temp;
	temp.x = pow(2.0, a.x);
	temp.y = pow(2.0, a.y);
	temp.z = pow(2.0, a.z);
	return temp;
}

vec3 g_2log(vec3 a) {
	vec3 temp;
	temp.x = log(2.0)/log(a.x);
	temp.y = log(2.0)/log(a.y);
	temp.z = log(2.0)/log(a.z);
	return temp;
}

// ROUND

vec3 g_mod(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = mod(a.x,b.x);
	temp.y = mod(a.y,b.y);
	temp.z = mod(a.z,b.z);
	return temp;
}

vec3 g_fract(vec3 a) {
	vec3 temp;
	temp.x = fract(a.x);
	temp.y = fract(a.y);
	temp.z = fract(a.z);
	return temp;
}

vec3 g_floor(vec3 a) {
	vec3 temp;
	temp.x = floor(a.x);
	temp.y = floor(a.y);
	temp.z = floor(a.z);
	return temp;
}

vec3 g_ceil(vec3 a) {
	vec3 temp;
	temp.x = ceil(a.x);
	temp.y = ceil(a.y);
	temp.z = ceil(a.z);
	return temp;
}

vec3 g_round(vec3 a) {
	vec3 temp;
	temp.x = floor(a.x+0.5);
	temp.y = floor(a.y+0.5);
	temp.z = floor(a.z+0.5);
	return temp;
}

// TRIG

vec3 g_sin(vec3 a) {
	vec3 temp;
	temp.x = sin(a.x*M_PI)/2+0.5;
	temp.y = sin(a.y*M_PI)/2+0.5;
	temp.z = sin(a.z*M_PI)/2+0.5;
	return temp;
}

vec3 g_cos(vec3 a) {
	vec3 temp;
	temp.x = cos(a.x*M_PI)/2+0.5;
	temp.y = cos(a.y*M_PI)/2+0.5;
	temp.z = cos(a.z*M_PI)/2+0.5;
	return temp;
}

vec3 g_tan(vec3 a) {
	vec3 temp;
	temp.x = tan(a.x*M_PI);
	temp.y = tan(a.y*M_PI);
	temp.z = tan(a.z*M_PI);
	return temp;
}

vec3 g_asin(vec3 a) {
	vec3 temp;
	temp.x = asin(clamp(a.x,-1,1))/M_PI+0.5;
	temp.y = asin(clamp(a.y,-1,1))/M_PI+0.5;
	temp.z = asin(clamp(a.z,-1,1))/M_PI+0.5;
	return temp;
}

vec3 g_acos(vec3 a) {
	vec3 temp;
	temp.x = acos(clamp(a.x,-1,1))/M_PI;
	temp.y = acos(clamp(a.y,-1,1))/M_PI;
	temp.z = acos(clamp(a.z,-1,1))/M_PI;
	return temp;
}

vec3 g_atan(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = atan(clamp(a.x,-1,1), clamp(b.x,-1,1))/M_PI;
	temp.y = atan(clamp(a.y,-1,1), clamp(b.y,-1,1))/M_PI;
	temp.z = atan(clamp(a.z,-1,1), clamp(b.z,-1,1))/M_PI;
	return temp;
}

// CONSTRAIN

vec3 g_max(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = max(a.x,b.x);
	temp.y = max(a.y,b.y);
	temp.z = max(a.z,b.z);
	return temp;
}

vec3 g_min(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = min(a.x,b.x);
	temp.y = min(a.y,b.y);
	temp.z = min(a.z,b.z);
	return temp;
}

vec3 g_clamp(vec3 a, vec3 b, vec3 c) {
	vec3 temp;
	temp.x = clamp(a.x,b.x,c.x);
	temp.y = clamp(a.y,b.y,c.y);
	temp.z = clamp(a.z,b.z,c.z);
	return temp;
}

vec3 g_abs(vec3 a) {
	vec3 temp;
	temp.x = abs(a.x);
	temp.y = abs(a.y);
	temp.z = abs(a.z);
	return temp;
}

// MIX

vec3 g_mix(vec3 a, vec3 b, vec3 c) {
	vec3 temp;
	temp.x = mix(a.x,b.x,c.x);
	temp.y = mix(a.y,b.y,c.y);
	temp.z = mix(a.z,b.z,c.z);
	return temp;
}

// LOGIC

vec3 g_if(vec3 a, vec3 b, vec3 c, vec3 d) {
	vec3 temp;

	if (a.x > b.x) {
		temp.x = c.x;
	} else {
		temp.x = d.x;
	}

	if (a.y > b.y) {
		temp.y = c.y;
	} else {
		temp.y = d.y;
	}

	if (a.z > b.z) {
		temp.z = c.z;
	} else {
		temp.z = d.z;
	}

	return temp;
}

vec3 g_or(vec3 a, vec3 b, vec3 a2, vec3 b2, vec3 c, vec3 d) {
	vec3 temp;

	if (a.x > b.x || a2.x > b2.x) {
		temp.x = c.x;
	} else {
		temp.x = d.x;
	}

	if (a.y > b.y || a2.y > b2.y) {
		temp.y = c.y;
	} else {
		temp.y = d.y;
	}

	if (a.z > b.z || a2.z > b2.z) {
		temp.z = c.z;
	} else {
		temp.z = d.z;
	}

	return temp;
}

vec3 g_and(vec3 a, vec3 b, vec3 a2, vec3 b2, vec3 c, vec3 d) {
	vec3 temp;

	if (a.x > b.x && a2.x > b2.x) {
		temp.x = c.x;
	} else {
		temp.x = d.x;
	}

	if (a.y > b.y && a2.y > b2.y) {
		temp.y = c.y;
	} else {
		temp.y = d.y;
	}

	if (a.z > b.z && a2.z > b2.z) {
		temp.z = c.z;
	} else {
		temp.z = d.z;
	}

	return temp;
}

vec3 g_xor(vec3 a, vec3 b, vec3 a2, vec3 b2, vec3 c, vec3 d) {
	vec3 temp;

	if (((a.x > b.x) && !(a2.x > b2.x)) || (!(a.x > b.x) && (a2.x > b2.x))) {
		temp.x = c.x;
	} else {
		temp.x = d.x;
	}
	if (((a.y > b.y) && !(a2.y > b2.y)) || (!(a.y > b.y) && (a2.y > b2.y))) {
		temp.y = c.y;
	} else {
		temp.y = d.y;
	}
	if (((a.z > b.z) && !(a2.z > b2.z)) || (!(a.z > b.z) && (a2.z > b2.z))) {
		temp.z = c.z;
	} else {
		temp.z = d.z;
	}

	return temp;
}

// ELSE
vec3 g_length(vec3 a) {
	return vec3(length(a));
}

vec3 g_norm(vec3 a) {
	float magnitude = length(a);
	if (magnitude == 0.0) return vec3(0.0);
	return a / magnitude;
}

vec3 g_rot(vec3 a, vec3 angle) {
	// The angle's first component is measured in turns: 1 = 360 degrees.
	float angleRadians = angle.x * 2.0 * M_PI;
	float c = cos(angleRadians);
	float s = sin(angleRadians);
	return vec3(c*a.x - s*a.y, s*a.x + c*a.y, a.z);
}

vec3 g_rgb2hsb( in vec3 c ){
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz),
                 vec4(c.gb, K.xy),
                 step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r),
                 vec4(c.r, p.yzx),
                 step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                d / (q.x + e),
                q.x);
}

vec3 g_hsb2rgb( in vec3 c ){
    vec3 rgb = clamp(abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),
                             6.0)-3.0)-1.0,
                     0.0,
                     1.0 );
    rgb = rgb*rgb*(3.0-2.0*rgb);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

// HMM

vec3 g_combine(vec3 a, vec3 b, vec3 c) {
	float a_ = (a.x + a.y + a.z)/3;
	float b_ = (b.x + b.y + b.z)/3;
	float c_ = (c.x + c.y + c.z)/3;
	return vec3(a_,b_,c_);
}

vec3 g_setH(vec3 a, vec3 b) {
	float b_ = (b.x + b.y + b.z)/3;
	a = g_rgb2hsb(a);
	a.x = b_;
	a = g_hsb2rgb(a);
	return a;
}

vec3 g_offsetH(vec3 a, vec3 b) {
	float b_ = (b.x + b.y + b.z)/3;
	a = g_rgb2hsb(a);
	a.x += b_;
	a = g_hsb2rgb(a);
	return a;
}

vec3 g_setS(vec3 a, vec3 b) {
	float b_ = (b.x + b.y + b.z)/3;
	a = g_rgb2hsb(a);
	a.y = b_;
	a = g_hsb2rgb(a);
	return a;
}
vec3 g_setV(vec3 a, vec3 b) {
	float b_ = (b.x + b.y + b.z)/3;
	a = g_rgb2hsb(a);
	a.z = b_;
	a = g_hsb2rgb(a);
	return a;
}

// NOISE ---------

float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))
                 * 43758.5453123);
}

float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smooth Interpolation

    // Cubic Hermine Curve.  Same as SmoothStep()
    vec2 u = f*f*(3.0-2.0*f);
    // u = smoothstep(0.,1.,f);

    // Mix 4 coorners porcentages
    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

vec3 g_noise2(vec3 a, vec3 b) {
	vec3 temp;
	temp.x = noise(vec2(a.x,b.x));
	temp.y = noise(vec2(a.x,b.x));
	temp.z = noise(vec2(a.x,b.x));
	return temp;
}

// ---------------

// PROCESSING

vec3 process(vec3 c) {
	// Keep graph colors unchanged; automatic hue offset is disabled.
	return c;
}

void main() {
	int iter = 0;
	vec3 col;
	for (int y_ = 0; y_ < u_aa; y_++) {
		iterY = y_;
		for (int x_ = 0; x_ < u_aa; x_ ++) {
			iterX = x_;
			col = vec3(0.0,0.0,0.0); // PIXY_GRAPH
			precol[iter] = col;

			iter ++;
		}
	}
	col = vec3(0.0,0.0,0.0);
	for (int i = 0; i < u_aa*u_aa; i++) {
		col = col + precol[i];
	}
	col = col / (u_aa * u_aa);
	col = process(col);
	gl_FragColor = vec4(col,1.0);
}
