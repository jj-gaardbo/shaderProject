﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
Shader "Custom/myCel" {
    Properties {
        _MainTex ("Main texture", 2D) = "white" {}
        _BumpMap ("Bump Map", 2D) = "bump" {}
        _BumpMapDepth ("Bump Map Depth", Range(-1.0 ,15.0)) = 1

        _Color ("Color", Color) = (1.0,1.0,1.0,1.0)

        //Ambient Properties
        [Toggle(USE_AMBIENT)] _UseAmbient("Ambient ON/OFF", Float) = 0
        _AmbientAmount ("- Ambient Amount", Range( 0,6.7 )) = 5

        // Diffuse Properties
        [Toggle(USE_DIFFUSE)] _UseDiffuse("Diffuse ON/OFF", Float) = 0
        _DiffuseThreshold ("- Diffuse Threshold", Range( 0,1 )) = 0
        _DiffuseDetail ("- Diffuse Detail", Range(0,3)) = 1
        _DiffuseDifference ("- Diffuse Unlit Difference", Range( 0,1 )) = 0

        // Specular Properties
        [Toggle(USE_SPECULAR)] _UseSpecular("Specular ON/OFF", Float) = 0
        _SpecColor ("- Specular Color", Color) = (1,1,1,1)
        _SpecDetail ("- Specular Detail", Range(0,3)) = 1
        _Shininess ("- Shininess", Range(0, 20)) = 10

        // Outline Properties
        [Toggle(USE_OUTLINE)] _UseOutline("Outline ON/OFF", Float) = 0
        _OutlineColor("- Outline Color", Color) = (0,0,0,0)
	    _OutlineThickness("- Outline Thickness", Range(0,1)) = 0.1
    }
    SubShader { 
        
        Pass {
            TAGS {"RenderType"="Opaque" "LightMode" = "ForwardBase"}
            CGPROGRAM 

            #pragma vertex vert  
            #pragma fragment frag
            
            //Toggles
            #pragma shader_feature USE_AMBIENT
            #pragma shader_feature USE_DIFFUSE
            #pragma shader_feature USE_SPECULAR
            #pragma shader_feature USE_OUTLINE
            #pragma shader_feature USE_DISPLACEMENT
            
            uniform float4 _LightColor0; 

            sampler2D _MainTex, _BumpMap;
            float4 _MainTex_ST, _BumpMap_ST;
            float4 _Color, _SpecColor, _OutlineColor;
            float _BumpMapDepth, _AmbientAmount, _DiffuseThreshold, _DiffuseDetail, _DiffuseDifference, _SpecDetail, _Shininess, _OutlineThickness;
    
            struct vertexInput {
                float4 pos : POSITION;
                float4 texCoords : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            struct vertexOutput {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangent : TEXCOORD2;
                float3 worldBinormal : TEXCOORD3;
                float4 worldPos : TEXCOORD4;
                float4 lightPos : TEXCOORD5;
                float3 viewDir : TEXCOORD6;
            };
    
            vertexOutput vert(vertexInput input)
            {
                vertexOutput output;

                float4x4 ModelMatrix = unity_ObjectToWorld;
                float4x4 ModelMatrixInverse = unity_WorldToObject;

                output.worldPos = normalize( mul( ModelMatrix, input.pos ) );
                output.worldNormal = normalize( mul( input.normal, ModelMatrixInverse).xyz );
                output.worldTangent = normalize( mul( unity_ObjectToWorld, input.tangent ).xyz );
                output.worldBinormal = normalize( cross( output.worldNormal, output.worldTangent ) * input.tangent.w );

                output.viewDir = normalize(_WorldSpaceCameraPos - mul(ModelMatrix, input.pos).xyz);

                output.lightPos = normalize( _WorldSpaceLightPos0 );
                output.uv = input.texCoords;

                // Translates all the vertecies onto camera space so we can see them from our cameras point of view (Camera coordinates)
                output.pos =  UnityObjectToClipPos(input.pos);                  
                return output;
            }
    
            fixed4 frag(vertexOutput input) : COLOR 
            {
                float4 mainTex = tex2D(_MainTex, (input.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw) );
                float4 bumpMap = tex2D(_BumpMap, input.uv.xy * _BumpMap_ST.xy + _BumpMap_ST.zw);

                //unpackNormal function
                float3 localCoords = float3( 2.0 * bumpMap.ag - float2( 1.0, 1.0 ), 0.0 );
                localCoords.z = _BumpMapDepth;

                //normal transpose matrix
                float3x3 local2WorldTranspose = float3x3(
                    input.worldTangent,
                    input.worldBinormal,
                    input.worldNormal
                );

                float3 normalDirection = normalize( mul( localCoords, local2WorldTranspose ) );

                float4 passLightColor = _LightColor0;
                float3 lightDirection = normalize( input.lightPos - input.worldPos.xyz );
 
                float3 outputColor = _Color;
                float nDotL = max(0.0, dot(normalDirection, lightDirection));

                #ifdef USE_AMBIENT
                outputColor = (UNITY_LIGHTMODEL_AMBIENT.rgb * outputColor.rgb) * _AmbientAmount;
                #endif

                #ifdef USE_DIFFUSE
                //Sharp Diffuse
                if(_DiffuseDetail > 2 && _DiffuseDetail <= 3){
                    if (nDotL >= _DiffuseThreshold * 0.75){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 3));
                    } else if (nDotL >= _DiffuseThreshold * 0.50){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2.5));
                    } else if (nDotL >= _DiffuseThreshold * 0.25){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2));
                    } else {
                        outputColor *= passLightColor.rgb * outputColor.rgb; 
                    }
                } else if(_DiffuseDetail > 1 && _DiffuseDetail <= 2){
                    if (nDotL >= _DiffuseThreshold * 0.50){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 3));
                    } else if (nDotL >= _DiffuseThreshold * 0.25){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2));
                    } else {
                        outputColor *= passLightColor.rgb * outputColor.rgb; 
                    }
                } else if(_DiffuseDetail >= 0 && _DiffuseDetail <= 1){
                    if (nDotL >= _DiffuseThreshold * 0.25){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2));
                    } else {
                        outputColor *= passLightColor.rgb * outputColor.rgb; 
                    }
                }
                #endif

                #ifdef USE_SPECULAR
                float attenuation;
                if (0.0 == _WorldSpaceLightPos0.w){
                // directional light?
                    attenuation = 1.0; // no attenuation
                    lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                } else {
                // point or spot light
                    float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - input.viewDir;
                    float distance = length(vertexToLightSource);
                    attenuation = 1.0 / distance;
                    lightDirection = normalize(vertexToLightSource);
                }
                float specCalculation = attenuation *  pow(max(0.0, dot(reflect(-lightDirection, input.worldNormal), input.viewDir)), _Shininess);
                if(_SpecDetail > 2 && _SpecDetail <= 3){
                    if (nDotL > 0.0 && specCalculation > 0.25 && nDotL > 0.0 && specCalculation <= 0.50) {
                        outputColor = _SpecColor.a * passLightColor.rgb * (_SpecColor.rgb * (outputColor + 0.25)) + (1.0 - _SpecColor.a) * outputColor;
                    } else if (nDotL > 0.0 && specCalculation > 0.50 && nDotL > 0.0 && specCalculation <= 0.75) {
                        outputColor = _SpecColor.a * passLightColor.rgb * (_SpecColor.rgb * (outputColor + 0.50)) + (1.0 - _SpecColor.a) * outputColor;
                    } else if (nDotL > 0.0 && specCalculation > 0.75) {
                        outputColor = _SpecColor.a * passLightColor.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * outputColor;
                    }
                } else if(_SpecDetail > 1 && _SpecDetail <= 2){
                    if (nDotL > 0.0 && specCalculation > 0.25 && nDotL > 0.0 && specCalculation <= 0.50) {
                        outputColor = _SpecColor.a * passLightColor.rgb * (_SpecColor.rgb * (outputColor + 0.25)) + (1.0 - _SpecColor.a) * outputColor;
                    } else if (nDotL > 0.0 && specCalculation > 0.25) {
                        outputColor = _SpecColor.a * passLightColor.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * outputColor;
                    }
                    
                } else if(_SpecDetail >= 0 && _SpecDetail <= 1){
                    if (nDotL > 0.0 && specCalculation > 0.25) {
                        outputColor = _SpecColor.a * passLightColor.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * outputColor;
                    }
                }           
                #endif

                #ifdef USE_OUTLINE
                float outlineStrength = saturate( (dot(input.worldNormal, input.viewDir ) - _OutlineThickness));
                if(outlineStrength < 0.01){
                    outputColor *= outlineStrength;
                    outputColor += _OutlineColor;
                }
                #endif
                
                fixed4 combinedOutput = float4( mainTex * outputColor, 0.0 );

                return combinedOutput;
                
            }
    
            ENDCG  
        }

        Pass {
            TAGS {"RenderType"="Opaque" "LightMode" = "ShadowCaster"}
            CGPROGRAM 

            #pragma vertex vert  
            #pragma fragment frag
            
            //Toggles
            #pragma shader_feature USE_AMBIENT
            #pragma shader_feature USE_DIFFUSE
            #pragma shader_feature USE_SPECULAR
            #pragma shader_feature USE_OUTLINE
            #pragma shader_feature USE_DISPLACEMENT
            
            uniform float4 _LightColor0; 

            sampler2D _MainTex, _BumpMap;
            float4 _MainTex_ST, _BumpMap_ST;
            float4 _Color, _SpecColor, _OutlineColor;
            float _BumpMapDepth, _AmbientAmount, _DiffuseThreshold, _DiffuseDetail, _DiffuseDifference, _SpecDetail, _Shininess, _OutlineThickness;
    
            struct vertexInput {
                float4 pos : POSITION;
                float4 texCoords : TEXCOORD0;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            struct vertexOutput {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangent : TEXCOORD2;
                float3 worldBinormal : TEXCOORD3;
                float4 worldPos : TEXCOORD4;
                float4 lightPos : TEXCOORD5;
                float3 viewDir : TEXCOORD6;
            };
    
            vertexOutput vert(vertexInput input)
            {
                vertexOutput output;

                float4x4 ModelMatrix = unity_ObjectToWorld;
                float4x4 ModelMatrixInverse = unity_WorldToObject;

                output.worldPos = normalize( mul( ModelMatrix, input.pos ) );
                output.worldNormal = normalize( mul( input.normal, ModelMatrixInverse).xyz );
                output.worldTangent = normalize( mul( unity_ObjectToWorld, input.tangent ).xyz );
                output.worldBinormal = normalize( cross( output.worldNormal, output.worldTangent ) * input.tangent.w );

                output.viewDir = normalize(_WorldSpaceCameraPos - mul(ModelMatrix, input.pos).xyz);

                output.lightPos = normalize( _WorldSpaceLightPos0 );
                output.uv = input.texCoords;

                // Translates all the vertecies onto camera space so we can see them from our cameras point of view (Camera coordinates)
                output.pos =  UnityObjectToClipPos(input.pos);                  
                return output;
            }
    
            fixed4 frag(vertexOutput input) : COLOR 
            {
                float4 mainTex = tex2D(_MainTex, (input.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw) );
                float4 bumpMap = tex2D(_BumpMap, input.uv.xy * _BumpMap_ST.xy + _BumpMap_ST.zw);

                //unpackNormal function
                float3 localCoords = float3( 2.0 * bumpMap.ag - float2( 1.0, 1.0 ), 0.0 );
                localCoords.z = _BumpMapDepth;

                //normal transpose matrix
                float3x3 local2WorldTranspose = float3x3(
                    input.worldTangent,
                    input.worldBinormal,
                    input.worldNormal
                );

                float3 normalDirection = normalize( mul( localCoords, local2WorldTranspose ) );

                float4 passLightColor = _LightColor0;
                float3 lightDirection = normalize( input.lightPos - input.worldPos.xyz );
 
                float3 outputColor = _Color;
                float nDotL = max(0.0, dot(normalDirection, lightDirection));

                #ifdef USE_AMBIENT
                outputColor = (UNITY_LIGHTMODEL_AMBIENT.rgb * outputColor.rgb) * _AmbientAmount;
                #endif

                #ifdef USE_DIFFUSE
                //Sharp Diffuse
                if(_DiffuseDetail > 2 && _DiffuseDetail <= 3){
                    if (nDotL >= _DiffuseThreshold * 0.75){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 3));
                    } else if (nDotL >= _DiffuseThreshold * 0.50){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2.5));
                    } else if (nDotL >= _DiffuseThreshold * 0.25){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2));
                    } else {
                        outputColor *= passLightColor.rgb * outputColor.rgb; 
                    }
                } else if(_DiffuseDetail > 1 && _DiffuseDetail <= 2){
                    if (nDotL >= _DiffuseThreshold * 0.50){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 3));
                    } else if (nDotL >= _DiffuseThreshold * 0.25){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2));
                    } else {
                        outputColor *= passLightColor.rgb * outputColor.rgb; 
                    }
                } else if(_DiffuseDetail >= 0 && _DiffuseDetail <= 1){
                    if (nDotL >= _DiffuseThreshold * 0.25){
                        outputColor *= passLightColor.rgb * (outputColor.rgb - (_DiffuseDifference / 2));
                    } else {
                        outputColor *= passLightColor.rgb * outputColor.rgb; 
                    }
                }
                #endif

                #ifdef USE_SPECULAR
                float attenuation;
                if (0.0 == _WorldSpaceLightPos0.w){
                // directional light?
                    attenuation = 1.0; // no attenuation
                    lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                } else {
                // point or spot light
                    float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - input.viewDir;
                    float distance = length(vertexToLightSource);
                    attenuation = 1.0 / distance;
                    lightDirection = normalize(vertexToLightSource);
                }
                float specCalculation = attenuation *  pow(max(0.0, dot(reflect(-lightDirection, input.worldNormal), input.viewDir)), _Shininess);
                if(_SpecDetail > 2 && _SpecDetail <= 3){
                    if (nDotL > 0.0 && specCalculation > 0.25 && nDotL > 0.0 && specCalculation <= 0.50) {
                        outputColor = _SpecColor.a * passLightColor.rgb * (_SpecColor.rgb * (outputColor + 0.25)) + (1.0 - _SpecColor.a) * outputColor;
                    } else if (nDotL > 0.0 && specCalculation > 0.50 && nDotL > 0.0 && specCalculation <= 0.75) {
                        outputColor = _SpecColor.a * passLightColor.rgb * (_SpecColor.rgb * (outputColor + 0.50)) + (1.0 - _SpecColor.a) * outputColor;
                    } else if (nDotL > 0.0 && specCalculation > 0.75) {
                        outputColor = _SpecColor.a * passLightColor.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * outputColor;
                    }
                } else if(_SpecDetail > 1 && _SpecDetail <= 2){
                    if (nDotL > 0.0 && specCalculation > 0.25 && nDotL > 0.0 && specCalculation <= 0.50) {
                        outputColor = _SpecColor.a * passLightColor.rgb * (_SpecColor.rgb * (outputColor + 0.25)) + (1.0 - _SpecColor.a) * outputColor;
                    } else if (nDotL > 0.0 && specCalculation > 0.25) {
                        outputColor = _SpecColor.a * passLightColor.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * outputColor;
                    }
                    
                } else if(_SpecDetail >= 0 && _SpecDetail <= 1){
                    if (nDotL > 0.0 && specCalculation > 0.25) {
                        outputColor = _SpecColor.a * passLightColor.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * outputColor;
                    }
                }           
                #endif

                #ifdef USE_OUTLINE
                float outlineStrength = saturate( (dot(input.worldNormal, input.viewDir ) - _OutlineThickness));
                if(outlineStrength < 0.01){
                    outputColor *= outlineStrength;
                    outputColor += _OutlineColor;
                }
                #endif
                
                fixed4 combinedOutput = float4( mainTex * outputColor, 0.0 );

                return combinedOutput;
                
            }
    
            ENDCG  
        }

    }
}