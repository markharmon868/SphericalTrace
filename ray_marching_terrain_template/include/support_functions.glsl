#define PI 3.14159
#define PI2 6.28318
#define HFPI 1.57079
#define EPSILON 1e-10


// Quintic fade (C2 smooth)
// https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/perlin-noise-part-2/improved-perlin-noise.html
vec2 quinticInterpolation(vec2 t) 
{
    return t*t*t*(t*(t*6.0 - 15.0) + 10.0);
}

// random hash
vec2 hash2(vec2 p) 
{
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// 2D Perlin (gradient) 
float perlinNoise(vec2 P) 
{
    // Lattice coordinates and local position
    vec2 Pi = floor(P);
    vec2 Pf = P - Pi;

    // Gradients at cell corners (unit-ish)
    vec2 g00 = normalize(hash2(Pi + vec2(0.0, 0.0)));
    vec2 g10 = normalize(hash2(Pi + vec2(1.0, 0.0)));
    vec2 g01 = normalize(hash2(Pi + vec2(0.0, 1.0)));
    vec2 g11 = normalize(hash2(Pi + vec2(1.0, 1.0)));

    // Dot products with corner-to-point offset vectors
    float n00 = dot(g00, Pf - vec2(0.0, 0.0));
    float n10 = dot(g10, Pf - vec2(1.0, 0.0));
    float n01 = dot(g01, Pf - vec2(0.0, 1.0));
    float n11 = dot(g11, Pf - vec2(1.0, 1.0));

    // Interpolate using quintic fade
    vec2 u = quinticInterpolation(Pf);
    float nx0 = mix(n00, n10, u.x);
    float nx1 = mix(n01, n11, u.x);
    float nxy = mix(nx0, nx1, u.y);

    return nxy*0.5+0.5; 
}

// Fractional Brownian Motion
float fbm(in vec2 uv, in int level)
{
    float value = 0.;
    float amplitude = 1.6;
    float freq = 1.0;
    
    for (int i = 0; i < level; i++)
    {
        value += perlinNoise(uv * freq) * amplitude;
        
        amplitude *= 0.4;
        
        freq *= 2.0;
    }
    
    return value;
}

float terrainHeightMap(in vec3 uv, in float maxDistance)
{
    float distance = length(uv.xz); 
    int fbmLevel = min(8, int(9.0 - 8.0*(distance / maxDistance)));
    float height = fbm(uv.xz*0.5, fbmLevel);
    return height;
}

float determineK (in vec3 uv, float maxDistance) {
    float distance = length(uv.xz); 
    int fbmLevel = min(8, int(9.0 - 8.0*(distance / maxDistance)));
    float G = 1.2;
    float a0 = 1.6;
    float f0 = 1.0;
    float ai = 0.4;
    float fi = 2.0;
    float K = G * a0 * f0 * (1.0 - pow(ai * fi, float(fbmLevel))) / (1.0 - ai * fi);
    return K;
}



vec3 stepCountCostColor(float bias)
{
    vec3 offset = vec3(0.938, 0.328, 0.718);
    vec3 amplitude = vec3(0.902, 0.4235, 0.1843);
    vec3 frequency = vec3(0.7098, 0.7098, 0.0824);
    vec3 phase = vec3(2.538, 2.478, 0.168);

    return offset + amplitude*cos( PI2*(frequency*bias+phase));
}

vec3 getNormal(vec3 rayTerrainIntersection, float t, float maxDistance)
{
    vec3 eps = vec3(.001 * t, .0, .0);
    vec3 n =vec3(terrainHeightMap(rayTerrainIntersection - eps.xyy, maxDistance) - terrainHeightMap(rayTerrainIntersection + eps.xyy, maxDistance),
                2. * eps.x,
                terrainHeightMap(rayTerrainIntersection - eps.yyx, maxDistance) - terrainHeightMap(rayTerrainIntersection + eps.yyx, maxDistance));
  
    return normalize(n);
}


mat3 computeLookAtMatrix(vec3 cameraOrigin, vec3 target, float roll)
{
    vec3 rr = vec3(sin(roll), cos(roll), 0.0);
    vec3 ww = normalize(target - cameraOrigin);
    vec3 uu = normalize(cross(ww, rr));
    vec3 vv = normalize(cross(uu, ww));

    return mat3(uu, vv, ww);
}

vec3 toLinear(vec3 inputColor)
{    
    inputColor.x = pow(inputColor.x, 2.2f);
    inputColor.y = pow(inputColor.y, 2.2f);
    inputColor.z = pow(inputColor.z, 2.2f);
    return inputColor;
}

vec3 tosRGB(vec3 inputColor)
{    
    inputColor.x = pow(inputColor.x, 1.0f/2.2f);
    inputColor.y = pow(inputColor.y, 1.0f/2.2f);
    inputColor.z = pow(inputColor.z, 1.0f/2.2f);
    return inputColor;
}


// Residual: positive when the ray point is ABOVE the terrain surface.
float residual(in vec3 rayOrigin, in vec3 rayDirection, float t, float tMax) {
    vec3 p = rayOrigin + rayDirection * t;
    return p.y - terrainHeightMap(p, tMax);
}

// 3-iteration Illinois refinement on a bracket [a,b] with h(a)>0, h(b)<=0
float refineIllinois(in vec3 rayOrigin, in vec3 rayDirection,
                     float a, float b, float tMax)
{
    float fa = residual(rayOrigin, rayDirection, a, tMax);
    float fb = residual(rayOrigin, rayDirection, b, tMax); // expected <= 0
    int kept = 0; // +1 if 'a' kept last step, -1 if 'b' kept

    // Do a few iterations—after sphere tracing, 3 is plenty
    for (int k = 0; k < 3; ++k) {
        float denom = (fb - fa);
        // Secant (false-position) step, clamped to the bracket
        float m  = b - fb * (b - a) / (abs(denom) > 1e-12 ? denom : (sign(denom)*1e-12));
        m = clamp(m, min(a,b), max(a,b));
        float fm = residual(rayOrigin, rayDirection, m, tMax);
        if (abs(fm) < 1e-5) return m;

        if (fm * fb < 0.0) { // root in [m, b]
            a = b;  fa = fb;
            b = m;  fb = fm;
            if (kept == -1) fb *= 0.5; // Illinois damping on sticky side
            kept = -1;
        } else {             // root in [a, m]
            b = m;  fb = fm;
            if (kept == +1) fa *= 0.5;
            kept = +1;
        }
    }
    return 0.5 * (a + b);
}
bool tryRefine(vec3 ro, vec3 rd, float tNear, float tFar,
               float tPrev, float rPrev,
               inout float t, float tMax, float surf_eps)
{
    float r = residual(ro, rd, t, tMax);

    // 1) Best case: sign flip -> bracket [tPrev, t]
    if (rPrev > 0.0 && r <= 0.0) {
        float thit = refineIllinois(ro, rd, tPrev, t, tMax);
        t = thit;
        return true;
    }

    // 2) Try to synthesize a micro-bracket around t
    float beta = max(1e-3, 0.02 * t);
    float a = clamp(t - beta, tNear, tFar);
    float b = clamp(t + beta, tNear, tFar);
    float ha = residual(ro, rd, a, tMax);
    float hb = residual(ro, rd, b, tMax);

    if (ha > 0.0 && hb <= 0.0) {
        float thit = refineIllinois(ro, rd, a, b, tMax);
        t = thit;
        return true;
    }

    // 3) Still no bracket: do a guarded secant jump forward (peak skim case)
    // Use the local secant between (a,ha) and (b,hb)
    float denom = max(abs(hb - ha), 1e-6);
    float d_sec = hb * (b - a) / denom;   // distance from 'b' to estimated root
    // We want to move forward from t by a conservative amount; base it on local slope
    d_sec = clamp(d_sec, 2.0*surf_eps, 10.0*surf_eps);

    t = min(t + d_sec, tFar);
    return false; // not a final hit; continue marching
}