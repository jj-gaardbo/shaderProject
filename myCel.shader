// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
Shader "Custom/myCel" {
    Properties {
        _MainTex ("Main texture", 2D) = "white" {}
        _Color ("Color", Color) = (1.0,1.0,1.0,1.0)

        //Ambient Properties
        [Toggle(USE_AMBIENT)] _UseAmbient("Ambient ON/OFF", Float) = 0
        _AmbientAmount ("- Ambient Amount", Range( 0,10 )) = 5

        // Diffuse Properties
        [Toggle(USE_DIFFUSE)] _UseDiffuse("Diffuse ON/OFF", Float) = 0
        _DiffuseThreshold ("- Diffuse Threshold", Range( 0,1 )) = 0
        _DiffuseDetail ("- Diffuse Detail", Range(0,3)) = 1
        _DiffuseDifference ("- Diffuse Unlit Difference", Range( 0,1 )) = 0
    }
    SubShader {
        Pass {
            TAGS {"LightMode" = "ForwardBase"}
            CGPROGRAM 

            #pragma vertex vert  
            #pragma fragment frag
            
            //Toggles
            #pragma shader_feature USE_AMBIENT
            #pragma shader_feature USE_DIFFUSE

            uniform float4 _LightColor0; 

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _AmbientAmount, _DiffuseThreshold, _DiffuseDetail, _DiffuseDifference;
    
            struct vertexInput {
                float4 pos : POSITION;
                float4 texCoords : TEXCOORD0;
                float4 normal : NORMAL;
            };
            struct vertexOutput {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
                float4 lightPos : TEXCOORD3;
            };
    
            vertexOutput vert(vertexInput input)
            {
                vertexOutput output;

                float4x4 ModelMatrix = unity_ObjectToWorld;
                float4x4 ModelMatrixInverse = unity_WorldToObject;

                output.worldPos = normalize( mul( ModelMatrix, input.pos ) );
                output.worldNormal = normalize( mul( input.normal, ModelMatrixInverse).xyz );


                output.lightPos = normalize( _WorldSpaceLightPos0 );
                output.uv = input.texCoords;

                // Translates all the vertecies onto camera space so we can see them from our cameras point of view (Camera coordinates)
                output.pos =  UnityObjectToClipPos(input.pos);                        
                return output;
            }
    
            fixed4 frag(vertexOutput input) : COLOR 
            {
                float4 passLightColor = _LightColor0;
                float3 lightDirection = normalize( input.lightPos - input.worldPos.xyz );
 
                float3 outputColor = _Color;

                #ifdef USE_AMBIENT
                outputColor = (UNITY_LIGHTMODEL_AMBIENT.rgb * outputColor.rgb) * _AmbientAmount;
                #endif

                #ifdef USE_DIFFUSE
                //Sharp Diffuse
                float nDotL = max(0.0, dot(input.worldNormal, lightDirection));
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

                fixed4 combinedOutput = float4( ( tex2D(_MainTex, input.uv) * outputColor ), 0.0 );

                return combinedOutput;
                
            }
    
            ENDCG  
        }

    }
}