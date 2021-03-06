// Reference : https://www.shadertoy.com/view/Xds3zN

#define MAX_DIS 100.0
#define MAX_STEPS 100
#define EPSILON 0.001

//Comment SHADOW_SCALE to remove shadow
//#define SHADOW_SCALE 30.0

//----------------------Color Modes----------------------
//Uncomment the coloring mode you want to view and comment the rest

//#define DEPTH_COLOR
//#define STEP_COUNT_COLOR
//#define NORMAL_COLOR
#define LAMBERT_COLOR
//-------------------------------------------------------



//------------------Ray Casting Modes--------------------
//#define NAIVE_RAY_CAST
#define SPHERICAL_RAY_CAST
//-------------------------------------------------------



//-------------------------------------------------------
//					Distance Estimators
//-------------------------------------------------------


//--------Distance functions for various objects---------
float sdPlane (vec3 p, float y)
{
	return p.y - y;
}

float sdSphere( vec3 p, float s )
{
    return length(p)-s;
}

float sdBox( vec3 p, vec3 b )
{
	vec3 d = abs(p) - b;
  	return min(max(d.x,max(d.y,d.z)),0.0) +
         length(max(d,0.0));
}

float sdTorus( vec3 p, vec2 t )
{
  return length( vec2(length(p.xz)-t.x,p.y) )-t.y;
}

float sdEllipsoid( in vec3 p, in vec3 r )
{
    return (length( p/r ) - 1.0) * min(min(r.x,r.y),r.z);
}

//for fractals
float sdCross( in vec3 p)
{
    float v = 1.5;
	float da = sdBox(p.xyz,vec3(1000.0, v, v));
  	float db = sdBox(p.yzx,vec3(v, 1000.0, v));
	float dc = sdBox(p.zxy,vec3(v, v, 1000.0));
  	return min(da,min(db,dc));
}

//--------------------CSG Operations---------------------
float opDifference( float d1, float d2 )
{
    return max(-d2,d1);
}

float opUnion( float d1, float d2 )
{
	return (d1<d2) ? d1 : d2;
}

float opIntersect( float d1, float d2 )
{
    return max(d2,d1);
}

float opBlend(float a, float b, float blendRadius) {
    float c = 1.0 * (0.5 + (b - a) * (0.5 / blendRadius));
    return ((c) * a + (1.0-c) * b) - blendRadius * c * (1.0 - c);
}

//Function to create the actual scene
float disEstimator(vec3 pt)
{
    float dis = sdBox(pt, vec3(1.0));
   	float s = 0.5;
    
    for( int m=0; m<3; m++ )
   	{
        vec3 a = mod( pt*s, 2.0 )-1.0;
      	s *= 5.0;
		vec3 r = 5.0 - 5.0*abs(a);
        float c = sdCross(r)/s;
      	dis = max(dis,-c);
   	}

    return dis;
}



//-------------------------------------------------------
//				Color calculation functions
//-------------------------------------------------------

//Function to calculate the normal
vec3 getNormal( in vec3 pos )
{
	vec3 eps = vec3( 0.001, 0.0, 0.0 );
	vec3 nor = vec3(
	    disEstimator(pos+eps.xyy) - disEstimator(pos-eps.xyy),
	    disEstimator(pos+eps.yxy) - disEstimator(pos-eps.yxy),
	    disEstimator(pos+eps.yyx) - disEstimator(pos-eps.yyx));
	return normalize(nor);
}

#ifdef SHADOW_SCALE
//Function to calculate the soft shadow
float getSoftShadow(vec3 pt, vec3 lightPos)
{
    float t = 2.0;
    float minT = 2.0;
    
    vec3 rd = normalize(lightPos - pt);
    vec3 ro = pt;
    float maxT = (lightPos.x - ro.x) / rd.x;
	float shadow = 1.0;
    
	for(int i=0; i<MAX_STEPS; ++i )
    {
		pt = ro + t * rd;

        float dt = disEstimator(pt);
        
        if(dt < EPSILON)
        {
			return 0.0;
        }

        t += dt;
        shadow = min(shadow, SHADOW_SCALE * (dt / t));		
        
        if(t > maxT)
        {
          	return shadow;
        }
    }
    
    return clamp(shadow, 0.0, 1.0);
}
#endif

//Function to calculate lambert color
vec3 getLambertColor(vec3 pt, vec3 ro)
{
 	vec3 lightPos = vec3(5.0,5.0,0.0);
    vec3 lightCol = vec3(1.0);
    vec3 lightVector = normalize(lightPos - pt);
    
    vec3 normal = getNormal(pt);
    
    #ifdef SHADOW_SCALE
		float shadow = getSoftShadow(pt, lightPos);
		return clamp(dot(normal, lightVector), 0.0, 1.0) * lightCol * (shadow) + 0.01;
    #else
	    return clamp(dot(normal, lightVector), 0.0, 1.0) * lightCol + 0.01;
    #endif
}

//Function to calculate color based on number of steps
vec3 getStepCountColor(vec2 steps)
{
    float t = (steps.y - steps.x) / steps.y;
	vec2 c = vec2(t, 0.0);
    return vec3(1.0-t, t, 0);
}

//Function to calculate colors
vec3 colorCalculation(vec3 pt, vec2 dis, vec3 ro, vec2 steps)
{
    #ifdef DEPTH_COLOR
		return vec3(abs((dis.y - dis.x) / dis.y));
    #endif
    
    #ifdef STEP_COUNT_COLOR
		return getStepCountColor(steps);
	#endif
    
    #ifdef NORMAL_COLOR
        return abs(getNormal(pt));
	#endif
    
    #ifdef LAMBERT_COLOR
        return getLambertColor(pt, ro);
	#endif
    
	return vec3(0.0);
}

//-------------------------------------------------------
//				Ray Cast Functions
//-------------------------------------------------------

vec3 naiveRayCast(in vec3 ro, in vec3 rd)
{
    vec3 pt = ro;
    float i = 0.0;
    int maxSteps = 500;
	for(float t = 0.00; t < MAX_DIS; t+=0.01)
	{
        ++i;
        pt = ro + rd * t;
        
        float dis = disEstimator(pt);
        
     	if(dis < EPSILON)
        {
            return colorCalculation(pt, vec2(t, MAX_DIS), ro, vec2(i, maxSteps));
        }
	}
    
    return vec3(0.0);
}

vec3 sphericalRayCast(in vec3 ro, in vec3 rd)
{
    vec3 pt = ro;
   	
//    float dt = disEstimator(pt);
	float t = 0.0;
    
    for(int i = 1; i<MAX_STEPS; i++)
	{
        pt = ro + t * rd;
        
        float dt = disEstimator(pt);
        
     	if(dt < EPSILON)
        {   
            return colorCalculation(pt, vec2(t, MAX_DIS), ro, vec2(float(i), MAX_STEPS));
        }
        
		t += dt;
        
        if(t > MAX_DIS)
  	    {
         	return vec3(0.0);
        }
	}
    
    return vec3(0.0);
}


//-------------------------------------------------------

vec3 render(in vec3 ro, in vec3 rd)
{
    #ifdef NAIVE_RAY_CAST
	    return naiveRayCast(ro, rd);
    #else 
        return sphericalRayCast(ro, rd);
    #endif
}

mat3 setCamera(in vec3 ro, in vec3 ta, float cr) {
    // Starter code from iq's Raymarching Primitives
    // https://www.shadertoy.com/view/Xds3zN

    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = normalize(cross(cu, cw));
    return mat3(cu, cv, cw);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Starter code from iq's Raymarching Primitives
    // https://www.shadertoy.com/view/Xds3zN

    vec2 q = fragCoord.xy / iResolution.xy;
    vec2 p = -1.0 + 2.0 * q;
    p.x *= iResolution.x / iResolution.y;
    vec2 mo = iMouse.xy / iResolution.xy;

    float time = 15.0 + iGlobalTime;

    // camera
    vec3 ro = vec3(
            -0.5 + 3.5 * cos(0.1 * time + 6.0 * mo.x),
            1.0 + 2.0 * mo.y,
            0.5 + 3.5 * sin(0.1 * time + 6.0 * mo.x));
    vec3 ta = vec3(-0.5, -0.4, 0.5);

    // camera-to-world transformation
    mat3 ca = setCamera(ro, ta, 0.0);

    // ray direction
    vec3 rd = ca * normalize(vec3(p.xy, 2.0));

    // render
    vec3 col = render(ro, rd);

    col = pow(col, vec3(0.4545));

    fragColor = vec4(col, 1.0);
}