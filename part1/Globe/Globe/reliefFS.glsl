//View-Space directional light
//A unit vector
uniform vec3 u_CameraSpaceDirLight;

//Diffuse texture map for the day
uniform sampler2D u_DayDiffuse;
//Ambient texture map for the night side
uniform sampler2D u_Night;
//Color map for the clouds
uniform sampler2D u_Cloud;
//Transparency map for the clouds.  Note that light areas are where clouds are NOT
//Dark areas are were clouds are present
uniform sampler2D u_CloudTrans;
//Mask of which areas of the earth have specularity
//Oceans are specular, landmasses are not
uniform sampler2D u_EarthSpec;
//Bump map
uniform sampler2D u_Bump;

uniform float u_time;
uniform float u_toon;
uniform mat4 u_InvTrans;

varying vec3 v_Normal;              // surface normal in camera coordinates
varying vec2 v_Texcoord;
varying vec3 v_Position;            // position in camera coordinates
varying vec3 v_viewMC;
varying vec3 v_positionMC;          // position in model coordinates

mat3 eastNorthUpToEyeCoordinates(vec3 positionMC, vec3 normalEC);

void main(void)
{
    vec3 normal = normalize(v_Normal);            // surface normal - normalized after rasterization
    vec3 eyeToPosition = normalize(v_Position);   // normalized eye-to-position vector in camera coordinates
	
	float rim = max(0, dot( normal, v_Position )+1);
	vec4 rimlight = vec4(rim/4, rim/3, rim/2, 0.0);

	vec2 cloudTexcoord = v_Texcoord + vec2( u_time, 0.0 );
	float cloudAlpha = texture2D(u_CloudTrans,cloudTexcoord);

	float sealevel = u_toon;
	float height = sealevel + (1-sealevel)*texture2D( u_Bump, v_Texcoord );
	
	bool escaped = false;
	vec3 rpos = v_positionMC;
	vec3 viewing = normalize(v_viewMC);
	float r = length( rpos );
	vec2 last = v_Texcoord;
	float lastHeight = height;
	float lastR = r;

	while( height < r )
	{
		lastR = r;
		last = v_Texcoord;
		lastHeight = height;
		rpos += 0.01*viewing;
		r = length( rpos );
		float theta = acos( rpos.z / r ) / 3.14159;
		float phi = ( atan2( rpos.x, rpos.y ) / 6.28318 );
		v_Texcoord = vec2(-phi, theta);
		height = sealevel + (1-sealevel)*texture2D( u_Bump, v_Texcoord );
		if( r > 1 )
		{
			escaped = true;
			break;
		}
	}
	float t = (lastHeight - lastR) / ((r-lastR)-(height-lastHeight));
	v_Texcoord = last*(1-t) + t*v_Texcoord;

	if( !escaped )
	{

		float top = texture2D( u_Bump, v_Texcoord + vec2(0.0, 1.0/500.0) );
		float center = texture2D( u_Bump, v_Texcoord );
		float right = texture2D( u_Bump, v_Texcoord + vec2(1.0/1000.0, 0.0) );

		vec3 bnorm = normalize(eastNorthUpToEyeCoordinates(v_positionMC, normal) * normalize(vec3(center - right, center - top, 0.2)));

		float diffuse = max(dot(u_CameraSpaceDirLight, bnorm), 0.0);
		
		vec3 toReflectedLight = reflect(-u_CameraSpaceDirLight, normal);
		float specular = max(dot(toReflectedLight, -eyeToPosition), 0.0);
		specular = pow(specular, 20.0) * texture2D(u_EarthSpec, v_Texcoord);
		float gammaCorrect = 1/1.2; //gamma correct by 1/1.8

		vec4 dayColor = ((0.6 * diffuse) + (0.6 * specular)) * texture2D(u_DayDiffuse, v_Texcoord);

		diffuse = max(dot(u_CameraSpaceDirLight, normal), 0.0);
	
		dayColor = mix( (0.6 * diffuse)*texture2D(u_Cloud,cloudTexcoord), dayColor, cloudAlpha );

		vec4 nightColor = pow(texture2D(u_Night, v_Texcoord),gammaCorrect);    //apply gamma correction to nighttime texture
		nightColor = mix( vec4( 0.0 ), nightColor, cloudAlpha );

		gl_FragColor = rimlight + mix( dayColor, nightColor, pow(1.0 - diffuse, 8.0) );
	}
	else
	{
		float diffuse = max(dot(u_CameraSpaceDirLight, normal), 0.0);
		vec4 dayColor = mix( (0.6 * diffuse)*texture2D(u_Cloud,cloudTexcoord), vec4(0), cloudAlpha );

		gl_FragColor = rimlight + dayColor;
	}
}

mat3 eastNorthUpToEyeCoordinates(vec3 positionMC, vec3 normalEC)
{
    vec3 tangentMC = normalize(vec3(-positionMC.y, positionMC.x, 0.0));  // normalized surface tangent in model coordinates
    vec3 tangentEC = normalize(mat3(u_InvTrans) * tangentMC);            // normalized surface tangent in eye coordiantes
    vec3 bitangentEC = normalize(cross(normalEC, tangentEC));            // normalized surface bitangent in eye coordinates

    return mat3(
        tangentEC.x,   tangentEC.y,   tangentEC.z,
        bitangentEC.x, bitangentEC.y, bitangentEC.z,
        normalEC.x,    normalEC.y,    normalEC.z);
}