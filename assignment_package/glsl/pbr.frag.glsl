#version 330 core

uniform vec3 u_CamPos;

// PBR material attributes
uniform vec3 u_Albedo;
uniform float u_Metallic;
uniform float u_Roughness;
uniform float u_AmbientOcclusion;
// Texture maps for controlling some of the attribs above, plus normal mapping
uniform sampler2D u_AlbedoMap;
uniform sampler2D u_MetallicMap;
uniform sampler2D u_RoughnessMap;
uniform sampler2D u_AOMap;
uniform sampler2D u_NormalMap;
// If true, use the textures listed above instead of the GUI slider values
uniform bool u_UseAlbedoMap;
uniform bool u_UseMetallicMap;
uniform bool u_UseRoughnessMap;
uniform bool u_UseAOMap;
uniform bool u_UseNormalMap;

// Image-based lighting
uniform samplerCube u_DiffuseIrradianceMap;
uniform samplerCube u_GlossyIrradianceMap;
uniform sampler2D u_BRDFLookupTexture;

// Varyings
in vec3 fs_Pos;
in vec3 fs_Nor; // Surface normal
in vec3 fs_Tan; // Surface tangent
in vec3 fs_Bit; // Surface bitangent
in vec2 fs_UV;
out vec4 out_Col;

const float PI = 3.14159f;
const float MAX_REFLECTION_LOD = 4.;

// Set the input material attributes to texture-sampled values
// if the indicated booleans are TRUE
void handleMaterialMaps(inout vec3 albedo, inout float metallic,
                        inout float roughness, inout float ambientOcclusion,
                        inout vec3 normal) {
    if(u_UseAlbedoMap) {
        albedo = pow(texture(u_AlbedoMap, fs_UV).rgb, vec3(2.2));
    }
    if(u_UseMetallicMap) {
        metallic = texture(u_MetallicMap, fs_UV).r;
    }
    if(u_UseRoughnessMap) {
        roughness = texture(u_RoughnessMap, fs_UV).r;
    }
    if(u_UseAOMap) {
        ambientOcclusion = texture(u_AOMap, fs_UV).r;
    }
    if(u_UseNormalMap) {
        // TODO: Apply normal mapping
        normal = texture(u_NormalMap, fs_UV).rgb;
        normal *= 2.;
        normal = mat3(fs_Tan, fs_Bit, fs_Nor) * (normal - vec3(1.f));
    }
}

vec3 fresnel(float cosTheta, vec3 R, float roughness) {
    return R + (max(vec3(1. - roughness), R) - R) * pow(clamp(1. - cosTheta, 0., 1.), 5.);
}

void main()
{
    vec3  N                = fs_Nor;
    vec3  albedo           = u_Albedo;
    float metallic         = u_Metallic;
    float roughness        = u_Roughness;
    float ambientOcclusion = u_AmbientOcclusion;

    // The ray traveling from the point being shaded to the camera
    vec3 wo = normalize(u_CamPos - fs_Pos);
    // The microfacet surface normal one would use to reflect wo in the direction of wi.
    vec3 wh = N;
    // The ray traveling from the point being shaded to the source of irradiance
    vec3 wi = reflect(-wo, wh);
    // The innate material color used in the Fresnel reflectance function
    vec3 R = mix(vec3(0.04f), albedo, metallic);

    handleMaterialMaps(albedo, metallic, roughness, ambientOcclusion, N);

    vec3 F = fresnel(max(dot(wh, wo), 0.), R, roughness);
    vec3 ks = F;
    vec3 kd = (vec3(1.) - ks) * (1. - metallic);

    vec3 irradiance = texture(u_DiffuseIrradianceMap, N).rgb;
    vec3 diffuse = irradiance * albedo ;

    vec3 prefilteredColor = textureLod(u_GlossyIrradianceMap, wi, roughness * MAX_REFLECTION_LOD).rgb;
    vec2 brdf = texture(u_BRDFLookupTexture, vec2(max(dot(wh, wo), 0.), roughness)).rg;
    vec3 specular = prefilteredColor * (R * brdf.x + brdf.y);

    vec3 Lo = vec3(0.);
    vec3 ambient = (kd * diffuse + specular) * u_AmbientOcclusion;
    vec3 color = ambient + Lo;

    color = color / (color + vec3(1.));
    color = pow(color, vec3(1. / 2.2f));
    out_Col = vec4(color, 1.);
}
