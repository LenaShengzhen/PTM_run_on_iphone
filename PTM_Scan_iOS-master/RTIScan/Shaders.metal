//
//  Shaders.metal
//  RTIScan
//
//  Created by yang yuan on 3/9/19.
//  Copyright © 2019 Yuan Yang. All rights reserved.
//

#include <metal_stdlib>
#include <metal_geometric>
using namespace metal;

typedef struct {
    float4 renderedCoordinate [[position]];
    float2 textureCoordinate;
} TextureMappingVertex;

typedef struct {
    float2 lightPos;
} Uniforms;

vertex TextureMappingVertex mapTexture(unsigned int vertex_id [[ vertex_id ]]) {
    float4x4 renderedCoordinates = float4x4(float4( -1.0, -1.0, 0.0, 1.0 ),      /// (x, y, depth, W)
                                            float4(  1.0, -1.0, 0.0, 1.0 ),
                                            float4( -1.0,  1.0, 0.0, 1.0 ),
                                            float4(  1.0,  1.0, 0.0, 1.0 ));
    
    float4x2 textureCoordinates = float4x2(float2( 0.0, 1.0 ), /// (x, y)
                                           float2( 1.0, 1.0 ),
                                           float2( 0.0, 0.0 ),
                                           float2( 1.0, 0.0 ));
    TextureMappingVertex outVertex;
    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];
    outVertex.textureCoordinate = textureCoordinates[vertex_id];
    
    return outVertex;
}

fragment float4 displayTexture(TextureMappingVertex mappingVertex [[ stage_in ]],
                              texture2d<float, access::sample> texture [[ texture(0) ]],
                              texture2d<float, access::sample> texture2 [[ texture(1) ]],
                              texture2d<float, access::sample> texture3 [[ texture(2) ]],
                              texture2d<float, access::sample> texture4 [[ texture(3) ]],
                              texture2d<float, access::sample> texture5 [[ texture(4) ]],
                              texture2d<float, access::sample> texture6 [[ texture(5) ]],
                              texture2d<float, access::sample> texture_cb [[ texture(6) ]],
                              texture2d<float, access::sample> texture_cr [[ texture(7) ]],
                              constant Uniforms &uniforms [[ buffer( 1 ) ]]
                              ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float co1 = float4(texture.sample(s, mappingVertex.textureCoordinate)).r;
    float co2 = float4(texture2.sample(s, mappingVertex.textureCoordinate)).r;
    float co3 = float4(texture3.sample(s, mappingVertex.textureCoordinate)).r;
    float co4 = float4(texture4.sample(s, mappingVertex.textureCoordinate)).r;
    float co5 = float4(texture5.sample(s, mappingVertex.textureCoordinate)).r;
    float co6 = float4(texture6.sample(s, mappingVertex.textureCoordinate)).r;
    float cb = float4(texture_cb.sample(s, mappingVertex.textureCoordinate)).r;
    float cr = float4(texture_cr.sample(s, mappingVertex.textureCoordinate)).r;
    
    float luminance = (
    uniforms.lightPos.x * uniforms.lightPos.x * (co1)
    + uniforms.lightPos.y * uniforms.lightPos.y * (co2)
    + uniforms.lightPos.x * uniforms.lightPos.y * (co3)
    + uniforms.lightPos.x * (co4)
    + uniforms.lightPos.y * (co5)
    + (co6));
 
    float r = cr  + luminance;
    float b = cb  + luminance;
    float g = (luminance - 0.2126 * r - 0.0722 * b) / 0.7152;
    return float4(r, g, b, 1);
}


fragment float4 displayTextureSpecular(TextureMappingVertex mappingVertex [[ stage_in ]],
                               texture2d<float, access::sample> texture [[ texture(0) ]],
                               texture2d<float, access::sample> texture2 [[ texture(1) ]],
                               texture2d<float, access::sample> texture3 [[ texture(2) ]],
                               texture2d<float, access::sample> texture4 [[ texture(3) ]],
                               texture2d<float, access::sample> texture5 [[ texture(4) ]],
                               texture2d<float, access::sample> texture6 [[ texture(5) ]],
                               texture2d<float, access::sample> texture_cb [[ texture(6) ]],
                               texture2d<float, access::sample> texture_cr [[ texture(7) ]],
                               constant Uniforms &uniforms [[ buffer( 1 ) ]]
                               ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float co1 = float4(texture.sample(s, mappingVertex.textureCoordinate)).r;
    float co2 = float4(texture2.sample(s, mappingVertex.textureCoordinate)).r;
    float co3 = float4(texture3.sample(s, mappingVertex.textureCoordinate)).r;
    float co4 = float4(texture4.sample(s, mappingVertex.textureCoordinate)).r;
    float co5 = float4(texture5.sample(s, mappingVertex.textureCoordinate)).r;
    float co6 = float4(texture6.sample(s, mappingVertex.textureCoordinate)).r;
    float cr = float4(texture_cr.sample(s, mappingVertex.textureCoordinate)).r;
    float cb = float4(texture_cb.sample(s, mappingVertex.textureCoordinate)).r;
    
    float lu = (co3 * co5 - 2 * co2 * co4) / (4 * co1 * co2 - co3 * co3);
    float lz = (co3 * co4 - 2 * co1 * co5) / (4 * co1 * co2 - co3 * co3);
    
    
    float luminance = 0.5 * (
                             uniforms.lightPos.x * uniforms.lightPos.x * (co1)
                             + uniforms.lightPos.y * uniforms.lightPos.y * (co2)
                             + uniforms.lightPos.x * uniforms.lightPos.y * (co3)
                             + uniforms.lightPos.x * (co4)
                             + uniforms.lightPos.y * (co5)
                             + (co6))
    + 0.5 * pow(clamp(
                      dot(
                          float3(lu, lz, sqrt(1 - lu * lu - lz * lz)),
                          reflect(float3(-uniforms.lightPos.x, -uniforms.lightPos.y, -sqrt(1 - uniforms.lightPos.x * uniforms.lightPos.x - uniforms.lightPos.y * uniforms.lightPos.y)), float3(0, 0, 1))
                          ), 0.0, 1.0), 5);
    
    float r = cr + luminance;
    float b = cb + luminance;
    float g = (luminance - 0.2126 * r - 0.0722 * b) / 0.7152;
    return float4(r, g, b, 1);
}
