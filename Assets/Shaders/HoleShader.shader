Shader "Custom/HoleShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}

		[Space(10)]
		[Header(Hole)]
		[Space(10)]
		_HoleRadius ("Hole Radius", Float) = 1.0
		_HolePosition ("Hole Position", Vector) = (0.0, 0.0, 0.0, 0.0)
		[PowerSlider(10.0)] _HoleBlackFade ("Hole BlackFade", Range(0.1, 1.0)) = 0.18
		_HoleBlackFadeDepth ("Hole BlackFade Depth", Range(0.0, 10.0)) = 2.0
	}

	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float3 positionWS : TEXCOORD1;
			};

			sampler2D _MainTex;
			float _HoleRadius;
			float3 _HolePosition;
			float _HoleBlackFade;
			float _HoleBlackFadeDepth;

			Varyings vert (Attributes v)
			{
				Varyings o;
				o.positionCS = UnityObjectToClipPos(v.positionOS);
				o.positionWS = mul(unity_ObjectToWorld, v.positionOS);
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.uv = v.uv;
				return o;
			}

			float4 frag (Varyings i, out float outDepth : SV_Depth) : SV_Target
			{
				// Parameters
				float3 cameraPos = _WorldSpaceCameraPos;
				float3 cameraDir = normalize(i.positionWS - cameraPos);

				float3 origin = _HolePosition;
				float3 positionDir = i.positionWS - origin;
				float3 position2DDir = positionDir * float3(1,0,1);
				float3 incomingDir = -cameraDir;
				float3 incoming2DDir = normalize(incomingDir * float3(1,0,1));

				// TotalLength = positionDir・incomingDir + sqrt(radius^2 - |position×incoming|^2);
				float3 crossPosIncom = cross(position2DDir, incoming2DDir);
				float dotPosIncom = dot(position2DDir, incoming2DDir);
				float totalLength = dotPosIncom + sqrt(pow(_HoleRadius, 2.0) - pow(length(crossPosIncom), 2.0));

				// Depth = TotalLength * incomingY / incomingX
				float incomingX = sqrt(1.0 - pow(incomingDir.y, 2.0));
				float depth = totalLength * incomingDir.y / incomingX;
				float3 position = i.positionWS + cameraDir * length(float3(totalLength, depth, 0.0));

				// TextureMapping Ground
				float4 color = tex2D(_MainTex, i.uv);

				// TextureMapping Hole
				float2 positionDiff = position.xz - _HolePosition.xz;
				float2 holeUV = float2(
					-(atan2(positionDiff.y, positionDiff.x) + UNITY_PI) / (2.0 * UNITY_PI),
					frac(-depth / (2.0 * UNITY_PI * _HoleRadius)));
				float4 holeColor = tex2D(_MainTex, holeUV);

				// Lighting
				// Offset = Depth * lightDirX / lightDirY
				float3 lightDir = _WorldSpaceLightPos0.xyz;
				float lightDirX = sqrt(1.0 - pow(lightDir.y, 2.0));
				float offset = depth * lightDirX / abs(lightDir.y);
				float2 positionToLight = position.xz + lightDir.xz * offset;
				float holeAtten = smoothstep(-0.5, 0.5, _HoleRadius - distance(_HolePosition.xz, positionToLight)) * 0.5 + 0.5;

				// Half-Lambert
				float planeAtten = max(pow(dot(_WorldSpaceLightPos0.xyz, i.normal) * 0.5 + 0.5, 2.0), 0.25);
				float3 holeNormal = normalize(_HolePosition - float3(position.x, _HolePosition.y, position.z));
				holeAtten = min(holeAtten, max(pow(dot(_WorldSpaceLightPos0.xyz, holeNormal) * 0.5 + 0.5, 2.0), 0.25));
				holeAtten *= saturate(_HoleBlackFadeDepth - pow(depth, _HoleBlackFade));

				// Mask
				float mask = step(distance(i.positionWS, _HolePosition), _HoleRadius);
				color.rgb = lerp(color, holeColor, mask);
				color.rgb *= lerp(planeAtten, holeAtten, mask);
				return color;
			}
			
			float4 frag_tiled (Varyings i, out float outDepth : SV_Depth) : SV_Target
			{
				float3 tiledPositionWS = i.positionWS;
				tiledPositionWS.xz = frac(i.positionWS.xz) * 10.0 - 5.0;

				float3 cameraPos = _WorldSpaceCameraPos;
				float3 cameraDir = normalize(i.positionWS - cameraPos);

				float3 origin = _HolePosition;
				float3 positionDir = tiledPositionWS - origin;
				float3 position2DDir = positionDir * float3(1,0,1);
				float3 incomingDir = -cameraDir;
				float3 incoming2DDir = normalize(incomingDir * float3(1,0,1));

				// TotalLength = positionDir・incomingDir + sqrt(radius^2 - |position×incoming|^2);
				float3 crossPosIncom = cross(position2DDir, incoming2DDir);
				float dotPosIncom = dot(position2DDir, incoming2DDir);
				float totalLength = dotPosIncom + sqrt(pow(_HoleRadius, 2.0) - pow(length(crossPosIncom), 2.0));

				// Depth = TotalLength * incomingY / incomingX
				float incomingX = sqrt(1.0 - pow(incomingDir.y, 2.0));
				float depth = totalLength * incomingDir.y / incomingX;
				float3 position = tiledPositionWS + cameraDir * length(float3(totalLength, depth, 0.0));

				// TextureMapping Ground
				float4 color = tex2D(_MainTex, i.uv);

				// TextureMapping Hole
				float2 positionDiff = position.xz - _HolePosition.xz;
				float2 holeUV = float2(
					-(atan2(positionDiff.y, positionDiff.x) + UNITY_PI) / (2.0 * UNITY_PI),
					frac(-depth / (2.0 * UNITY_PI * _HoleRadius)));
				float4 holeColor = tex2D(_MainTex, holeUV);

				// Lighting
				// Offset = Depth * lightDirX / lightDirY
				float3 lightDir = _WorldSpaceLightPos0.xyz;
				float lightDirX = sqrt(1.0 - pow(lightDir.y, 2.0));
				float offset = depth * lightDirX / abs(lightDir.y);
				float2 positionToLight = position.xz + lightDir.xz * offset;
				float holeAtten = smoothstep(-0.5, 0.5, _HoleRadius - distance(_HolePosition.xz, positionToLight)) * 0.5 + 0.5;

				// Half-Lambert
				float planeAtten = max(pow(dot(_WorldSpaceLightPos0.xyz, i.normal) * 0.5 + 0.5, 2.0), 0.25);
				float3 holeNormal = normalize(_HolePosition - float3(position.x, _HolePosition.y, position.z));
				holeAtten = min(holeAtten, max(pow(dot(_WorldSpaceLightPos0.xyz, holeNormal) * 0.5 + 0.5, 2.0), 0.25));
				holeAtten *= saturate(_HoleBlackFadeDepth - pow(depth, _HoleBlackFade));

				// Mask
				float mask = step(distance(tiledPositionWS, _HolePosition), _HoleRadius);
				color.rgb = lerp(color, holeColor, mask);
				color.rgb *= lerp(planeAtten, holeAtten, mask);
				return color;
			}
			ENDCG
		}
	}
}
