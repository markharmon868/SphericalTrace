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
float fbm(in vec2 uv)
{
    float value = 0.;
    float amplitude = 1.6;
    float freq = 1.0;
    
    for (int i = 0; i < 8; i++)
    {
        value += perlinNoise(uv * freq) * amplitude;
        
        amplitude *= 0.4;
        
        freq *= 2.0;
    }
    
    return value;
}

float terrainHeightMap(in vec3 uv)
{
    float height = fbm(uv.xz*0.5);
    return height;
}



vec3 stepCountCostColor(float bias)
{
    vec3 offset = vec3(0.938, 0.328, 0.718);
    vec3 amplitude = vec3(0.902, 0.4235, 0.1843);
    vec3 frequency = vec3(0.7098, 0.7098, 0.0824);
    vec3 phase = vec3(2.538, 2.478, 0.168);

    return offset + amplitude*cos( PI2*(frequency*bias+phase));
}

vec3 getNormal(vec3 rayTerrainIntersection, float t)
{
    vec3 eps = vec3(.001 * t, .0, .0);
    vec3 n =vec3(terrainHeightMap(rayTerrainIntersection - eps.xyy) - terrainHeightMap(rayTerrainIntersection + eps.xyy),
                2. * eps.x,
                terrainHeightMap(rayTerrainIntersection - eps.yyx) - terrainHeightMap(rayTerrainIntersection + eps.yyx));
  
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