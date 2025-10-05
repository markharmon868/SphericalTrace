
// Huawei Technologies Canada
// Vancouver Research Center
// Terrain ray marching template
// 2025-09-25


#include "include/support_functions.glsl"


// Exposed variables
#iUniform int u_max_steps = 500 in {0, 500}  
#iUniform float u_max_distance = 20.0 in {1.0, 20.0}  
#iUniform float u_fog = 1.0 in {0.0, 1.0}  
#iUniform float u_specular = 0.5 in {0.0, 1.0}  
#iUniform float u_light_e_w = 1.0 in {-1.0, 1.0}  
#iUniform float u_dolly = 0.0 in {0.0, 1.0}  
#define eps 0.01

bool intersectPlane (vec3 rayOrigin, vec3 rayDirection, float boxMax, float maxDistance)
{
    return rayOrigin.y + rayDirection.y * (maxDistance - length(rayOrigin)) > boxMax;
}



vec2 rayMarching(in vec3 rayOrigin, in vec3 rayDirection, in float minDistance, in float maxDistance, inout vec3 intPos)
{
    float intersectionDistance = minDistance;
    float finalStepCount = 1.0;
	for( int i = 0; i < u_max_steps; i++ )
	{
        vec3 pos = rayOrigin + intersectionDistance * rayDirection;
		float height = pos.y - terrainHeightMap(pos, maxDistance);
        bool hitPlane = intersectPlane(rayOrigin, rayDirection, 2.7, maxDistance);
		if(( abs(height) < (0.01 * intersectionDistance) || intersectionDistance > maxDistance ) || hitPlane){
            finalStepCount = float(i);
            if (!hitPlane) {
                intPos = pos;
            } else {
                intPos = rayDirection * maxDistance;
                intersectionDistance = maxDistance + 1.0;
            }
            
            break;
        }
		intersectionDistance += 0.2 * height;
	}

	return vec2(intersectionDistance, finalStepCount);
}

vec2 sphereTrace(in vec3 rayOrigin, in vec3 rayDirection, in float minDistance, in float maxDistance, inout vec3 intPos){
    float intersectionDistance = minDistance;
    float finalStepCount = 1.0;

    // Track Illinois variables:
    float tPrev   = intersectionDistance;
    float rPrev   = residual(rayOrigin, rayDirection, tPrev, maxDistance);
    bool  havePrev = false;


    for( int i = 0; i < u_max_steps; i++ )
    {
        vec3 pos = rayOrigin + intersectionDistance * rayDirection;
        float height = pos.y - terrainHeightMap(pos, maxDistance);
        float K = determineK(pos, maxDistance);
        float step = height / sqrt(1.0 + K*K);
        bool hitPlane = intersectPlane(rayOrigin, rayDirection, 2.7, maxDistance);
        float relDist = 0.5*intersectionDistance / maxDistance;
        // Overshot and approximate a fix
        if (height < 0.0) {
            finalStepCount = float(i);
            intPos = pos-(step/2.0)*rayDirection;
            break;
        }
        
        // Illinois method trigger
        float illTrigger = 0.1 * (relDist + eps);
        if (step < illTrigger|| height < illTrigger || height < 0.0)
        {
            // Try to synthesize a micro-bracket around current t
            float beta = max(1e-3, 0.02 * intersectionDistance);
            float a = clamp(intersectionDistance - beta, minDistance, maxDistance);
            float b = clamp(intersectionDistance + beta, minDistance, maxDistance);

            float ha = residual(rayOrigin, rayDirection, a, maxDistance);
            float hb = residual(rayOrigin, rayDirection, b, maxDistance);

            float surf_eps = relDist;
            if (!(ha > 0.0 && hb <= 0.0)) {
                    
                // Expand once
                float beta2 = 2.0 * beta;
                a = clamp(intersectionDistance - beta2, minDistance, maxDistance);
                b = clamp(intersectionDistance + beta2, minDistance, maxDistance);
                ha = residual(rayOrigin, rayDirection, a, maxDistance);
                hb = residual(rayOrigin, rayDirection, b, maxDistance);

                if (!(ha > 0.0 && hb <= 0.0)) {
                    // True peak skim: guarded secant jump forward, then continue marching
                    float denom = max(abs(hb - ha), 1e-6);
                    float d_sec = hb * (b - a) / denom; // distance from 'b' to zero of secant
                    // Clamp to stay local and avoid micro-steps grind
                    d_sec = clamp(d_sec, 2.0 * surf_eps, 10.0 * surf_eps);

                    tPrev   = intersectionDistance;
                    rPrev   = height;
                    havePrev = true;

                    intersectionDistance = min(intersectionDistance + d_sec, maxDistance);
                    if (intersectionDistance > maxDistance) break;
                    continue; // resume marching
                }
            }

            // We have a bracket [a,b] with h(a)>0, h(b)<=0  -> refine & return hit
            int illIters = 0;
            float thit = refineIllinois(rayOrigin, rayDirection, a, b, maxDistance, illIters);
            finalStepCount += float(illIters);
            intPos = rayOrigin + rayDirection * thit;
            return vec2(thit, finalStepCount);
        }

        // --- Miss / far cutoff
        if (intersectionDistance > maxDistance) {
            intPos = rayOrigin + rayDirection * maxDistance;
            break;
        }

        // Normal step of my sphere trace
        if (((abs(height) < relDist+eps) || (intersectionDistance > maxDistance))|| hitPlane)
        {
            finalStepCount = float(i);
            if (!hitPlane) {
                intPos = pos;
            } else {
                intPos = rayOrigin + rayDirection * maxDistance;
                intersectionDistance = maxDistance + 1.0;
            }
            break;

        }
        intersectionDistance += step;
    }

    return vec2(intersectionDistance, finalStepCount);
}

vec3 computeShading(vec3 terrainColor, vec3 lightColor, vec3 normal, vec3 lightDirection, vec3 viewDirection, vec3 skyColor, float terrainHeight)
{
    terrainColor = mix(terrainColor, vec3(1.0), terrainHeight);

    // dot products
    vec3 halfVector = normalize(lightDirection + viewDirection); 
    float NdH = max(dot(normal, halfVector), 0.0);
   	float NdL = max(dot(normal, lightDirection) , 0.0);

    //Diffuse lobe
    vec3 diffuse = (terrainColor/PI)*NdL;

    // Ambient lobe
    vec3 ambient = vec3(normal.y*0.1) * skyColor;
    
    // Basic Blinn–Phong specular
    float specularIntensity = mix(u_specular*0.2, u_specular, terrainHeight);
    vec3 specular = lightColor * pow(NdH, 10.0) * specularIntensity * NdL;

   	return (diffuse + ambient + specular);
}



void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 mousePos = vec2(iMouse.x/iResolution.x, iMouse.y/iResolution.y);
    // uv coordinates are centered and aspect ration safe
    vec2 uv = (fragCoord/iResolution.xy)*2.0-1.0;
    float screenRatio = iResolution.x/iResolution.y;
    uv.x *= screenRatio;
	
    
    float lightEastWestPos = -0.5 * u_light_e_w;
    vec3 ligthPosition = vec3(lightEastWestPos, 0.5, 0.0);


    vec3 lightDirection = normalize(ligthPosition);
    vec3 lightColor = toLinear(vec3(0.99, 0.84, 0.43));

    
    

    vec3 camPosition = vec3(0.0, 2.0, 0.0) ;

    camPosition.z += u_dolly;
    vec3 camTarget = vec3(0.0, 0.0, 25.0) ;

    mat3 lookAtMatrix = computeLookAtMatrix(camPosition, camTarget, 0.0);
    
    vec3 rayOrigin = camPosition;
    vec3 rayDirection = normalize(lookAtMatrix * vec3(uv.xy, 1.0));


    
    vec3 intPos;
    vec2 rayCollision = sphereTrace(rayOrigin, rayDirection, 0.1, u_max_distance, intPos);
    float intersectionDistance = rayCollision.x;

    float normalizedStepCost = rayCollision.y/float(u_max_steps);
    float normalizedDistance = intersectionDistance/u_max_distance;


    float terrainHeight = intPos.y/2.0;
    terrainHeight = smoothstep(0.7, 0.78, terrainHeight); // we can use the height to mask the heighest points to show snow

    vec3 albedo = toLinear(vec3(0.5, 0.39, 0.18)); // terrain color

    
    vec3 finalColor = vec3(0.);
    

    // sky color depending on light direction
    vec3 skyColor = mix(vec3(0.3098, 0.5608, 0.9137), vec3(0.9961, 0.9725, 0.9059), max(dot(rayDirection, lightDirection)*0.5+0.5, 0.0));
    skyColor = toLinear(skyColor);

    finalColor = skyColor;

    if (intersectionDistance < u_max_distance)
    {
        vec3 rayTerrainIntersection = rayOrigin + rayDirection * intersectionDistance;
        vec3 terrainNormal = getNormal(rayTerrainIntersection, intersectionDistance, u_max_distance);
        vec3 viewDirection = normalize(rayOrigin - rayTerrainIntersection);
        
        // lighting terrian
        vec3 terrainShading = computeShading(albedo, lightColor, terrainNormal, lightDirection, viewDirection, skyColor, terrainHeight);
        

        // simulate fog using the distance of mountains
        normalizedDistance = mix(0.0, pow(normalizedDistance, 0.9), u_fog);

        finalColor = mix(terrainShading, skyColor, normalizedDistance);

        
    }

    // use this to export the normalized step cost as an image
    // finalColor = vec3(normalizedStepCost);

    // You can also visualize it as a color gradient
    // finalColor = stepCountCostColor(normalizedStepCost);

    
    // convert back to sRGB (gamma correction)
    finalColor = tosRGB(finalColor);

    fragColor = vec4(finalColor, 1.0);
}
