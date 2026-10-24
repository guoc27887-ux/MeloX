#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

constant float2 compactMeshPoints[360] = {
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.6f, 0.0f),
    float2(0.8f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 0.2f), float2(-0.0933f, 0.4f),
    float2(0.4f, 0.2f), float2(0.6f, 0.2f), float2(0.3653f, 0.1335f), float2(1.0f, 0.2f),
    float2(0.0f, 0.4f), float2(0.4232f, 0.359f), float2(0.3429f, 0.5349f), float2(0.6f, 0.4f),
    float2(0.832f, 0.4148f), float2(1.0f, 0.4f), float2(0.0f, 0.6f), float2(0.2f, 0.6f),
    float2(0.2293f, 0.7775f), float2(0.7829f, 0.5595f), float2(0.6514f, 0.7302f), float2(1.0f, 0.6f),
    float2(0.0f, 0.8f), float2(0.2f, 0.8f), float2(0.28f, 0.9195f), float2(0.4773f, 0.8f),
    float2(0.8f, 0.8f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.6514f, 1.1073f),
    float2(0.4f, 1.0f), float2(1.0f, 1.0317f), float2(1.0f, 1.1302f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.6f, 0.0f),
    float2(0.8f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 0.2f), float2(-0.0933f, 0.4f),
    float2(0.4f, 0.2f), float2(0.6f, 0.2f), float2(0.8587f, 0.2234f), float2(1.0f, 0.2f),
    float2(0.0f, 0.4f), float2(0.4526f, 0.6053f), float2(0.3429f, 0.5349f), float2(0.6f, 0.4f),
    float2(0.832f, 0.4148f), float2(1.0f, 0.4f), float2(0.0f, 0.6f), float2(0.2f, 0.6f),
    float2(0.2293f, 0.7775f), float2(0.7829f, 0.5595f), float2(0.6514f, 0.7302f), float2(1.0f, 0.6f),
    float2(0.0f, 0.8f), float2(0.2f, 0.8f), float2(0.28f, 0.9195f), float2(0.4773f, 0.8f),
    float2(0.8f, 0.8f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.6514f, 1.1073f),
    float2(0.4f, 1.0f), float2(1.0f, 1.0317f), float2(1.0f, 1.1302f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.6f, 0.0f),
    float2(0.8f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 0.2f), float2(0.3265f, 0.3839f),
    float2(0.4f, 0.2f), float2(0.462f, 0.3424f), float2(0.683f, 0.2797f), float2(1.0f, 0.2f),
    float2(0.0f, 0.4f), float2(0.2f, 0.4f), float2(0.4f, 0.4f), float2(0.6f, 0.4903f),
    float2(0.6574f, 0.4903f), float2(1.1357f, 0.4f), float2(-0.1173f, 0.4597f), float2(0.3771f, 0.4384f),
    float2(0.6415f, 0.5947f), float2(0.8254f, 0.6935f), float2(0.9334f, 0.5862f), float2(1.0f, 0.6f),
    float2(-0.0437f, 0.6533f), float2(0.2f, 0.6618f), float2(0.683f, 0.7362f), float2(0.8139f, 0.833f),
    float2(0.9104f, 0.8085f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.2f, 1.0f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.6f, 0.0f),
    float2(0.8f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 0.2f), float2(0.2437f, 0.4392f),
    float2(0.4f, 0.2f), float2(0.462f, 0.3424f), float2(0.683f, 0.2797f), float2(1.0f, 0.2f),
    float2(0.0f, 0.4f), float2(0.1494f, 0.4787f), float2(0.4f, 0.5063f), float2(0.6966f, 0.516f),
    float2(0.8139f, 0.4478f), float2(1.1357f, 0.4f), float2(-0.1173f, 0.4597f), float2(0.2437f, 0.6085f),
    float2(0.6414f, 0.5756f), float2(0.8254f, 0.6935f), float2(0.9334f, 0.5862f), float2(1.0f, 0.6f),
    float2(-0.0437f, 0.6533f), float2(0.2f, 0.6618f), float2(0.683f, 0.7362f), float2(0.8139f, 0.833f),
    float2(0.9104f, 0.8085f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.2f, 1.0f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.7465f, -0.0935f),
    float2(0.9702f, -0.0872f), float2(1.5935f, -0.0308f), float2(-0.1675f, 0.2878f), float2(0.7185f, 0.3087f),
    float2(0.5952f, 0.0728f), float2(0.7823f, 0.0815f), float2(0.9318f, 0.301f), float2(1.1369f, 0.3756f),
    float2(0.0f, 0.4f), float2(0.3295f, 0.4607f), float2(0.7823f, 0.3087f), float2(0.7465f, 0.365f),
    float2(0.9514f, 0.4305f), float2(1.1514f, 0.4424f), float2(0.0f, 0.6f), float2(0.2f, 0.6f),
    float2(0.3295f, 0.4424f), float2(0.5703f, 0.5f), float2(0.7887f, 0.4847f), float2(1.0f, 0.6f),
    float2(0.0f, 0.8f), float2(0.2414f, 0.7926f), float2(0.0418f, 0.7303f), float2(0.5952f, 0.4688f),
    float2(0.9433f, 0.6929f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.2f, 1.0f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.7465f, -0.0935f),
    float2(0.9702f, -0.0872f), float2(1.5935f, -0.0308f), float2(-0.1675f, 0.2878f), float2(0.5414f, 0.2825f),
    float2(0.5952f, 0.0728f), float2(0.7823f, 0.0815f), float2(0.9318f, 0.301f), float2(1.1369f, 0.3756f),
    float2(0.0f, 0.4f), float2(0.2881f, 0.4479f), float2(0.7823f, 0.3087f), float2(0.8363f, 0.3661f),
    float2(0.9514f, 0.4305f), float2(1.1514f, 0.4424f), float2(0.0f, 0.6f), float2(0.177f, 0.6f),
    float2(0.4f, 0.4775f), float2(0.5703f, 0.5f), float2(0.7887f, 0.4847f), float2(1.0f, 0.6f),
    float2(0.0f, 0.8f), float2(0.2414f, 0.7926f), float2(0.1499f, 0.7324f), float2(0.5952f, 0.5623f),
    float2(0.9433f, 0.6929f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.2f, 1.0f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.7465f, -0.0935f),
    float2(0.9702f, -0.0872f), float2(1.5935f, -0.0308f), float2(-0.1675f, 0.2878f), float2(0.7185f, 0.3087f),
    float2(0.5952f, 0.0728f), float2(0.7823f, 0.0815f), float2(0.9318f, 0.301f), float2(1.1369f, 0.3756f),
    float2(0.0f, 0.4f), float2(0.3295f, 0.4607f), float2(0.7823f, 0.3087f), float2(0.7465f, 0.365f),
    float2(0.9514f, 0.4305f), float2(1.1514f, 0.4424f), float2(0.0f, 0.6f), float2(0.2f, 0.6f),
    float2(0.3295f, 0.4424f), float2(0.5703f, 0.5f), float2(0.7887f, 0.4847f), float2(1.0f, 0.6f),
    float2(0.0f, 0.8f), float2(0.2414f, 0.7926f), float2(0.0418f, 0.7303f), float2(0.5952f, 0.4688f),
    float2(0.9433f, 0.6929f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.2f, 1.0f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.0f, 1.0f),
    float2(0.0f, 0.0f), float2(0.2f, 0.0f), float2(0.4f, 0.0f), float2(0.7465f, -0.0935f),
    float2(0.9702f, -0.0872f), float2(1.5935f, -0.0308f), float2(-0.1675f, 0.2878f), float2(0.5414f, 0.2825f),
    float2(0.5952f, 0.0728f), float2(0.7823f, 0.0815f), float2(0.9318f, 0.301f), float2(1.1369f, 0.3756f),
    float2(0.0f, 0.4f), float2(0.2881f, 0.4479f), float2(0.7823f, 0.3087f), float2(0.8363f, 0.3661f),
    float2(0.9514f, 0.4305f), float2(1.1514f, 0.4424f), float2(0.0f, 0.6f), float2(0.177f, 0.6f),
    float2(0.4f, 0.4775f), float2(0.5703f, 0.5f), float2(0.7887f, 0.4847f), float2(1.0f, 0.6f),
    float2(0.0f, 0.8f), float2(0.2414f, 0.7926f), float2(0.1499f, 0.7324f), float2(0.5952f, 0.5623f),
    float2(0.9433f, 0.6929f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.2f, 1.0f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.0f, 1.0f),
    float2(-0.2351f, -0.0967f), float2(0.2135f, -0.1414f), float2(0.9221f, -0.0908f), float2(0.9221f, -0.0685f),
    float2(1.3027f, 0.0253f), float2(1.2351f, 0.1786f), float2(-0.3768f, 0.1851f), float2(0.2f, 0.2f),
    float2(0.6615f, 0.3146f), float2(0.9543f, 0.0f), float2(0.6969f, 0.1911f), float2(1.0f, 0.2f),
    float2(0.0f, 0.4f), float2(0.2f, 0.4f), float2(0.0776f, 0.2318f), float2(0.6f, 0.4f),
    float2(0.6615f, 0.3851f), float2(1.0f, 0.4f), float2(0.0f, 0.6f), float2(0.1291f, 0.6f),
    float2(0.4f, 0.6f), float2(0.4f, 0.4304f), float2(0.4264f, 0.5792f), float2(1.2029f, 0.8188f),
    float2(-0.1192f, 1.0f), float2(0.6f, 0.8f), float2(0.4264f, 0.8104f), float2(0.6f, 0.8f),
    float2(0.8f, 0.8f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.0776f, 1.0283f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.1868f, 1.0283f),
    float2(-0.2351f, -0.0967f), float2(0.2135f, -0.1414f), float2(0.9221f, -0.0908f), float2(0.9221f, -0.0685f),
    float2(1.3027f, 0.0253f), float2(1.2351f, 0.1786f), float2(-0.3768f, 0.1851f), float2(0.1839f, 0.2f),
    float2(0.7034f, 0.2952f), float2(0.9543f, 0.0f), float2(0.7775f, 0.3339f), float2(1.0f, 0.2f),
    float2(0.0f, 0.4f), float2(0.0357f, 0.5369f), float2(0.0776f, 0.2318f), float2(0.6f, 0.4f),
    float2(0.6615f, 0.3851f), float2(1.0f, 0.4f), float2(0.0f, 0.6f), float2(0.2f, 0.6878f),
    float2(0.4f, 0.6f), float2(0.5f, 0.5896f), float2(0.6454f, 0.6878f), float2(1.2029f, 0.8188f),
    float2(-0.1192f, 1.0f), float2(0.6193f, 0.9027f), float2(0.4264f, 0.8104f), float2(0.6f, 0.8f),
    float2(0.8f, 0.8f), float2(1.0f, 0.8f), float2(0.0f, 1.0f), float2(0.0776f, 1.0283f),
    float2(0.4f, 1.0f), float2(0.6f, 1.0f), float2(0.8f, 1.0f), float2(1.1868f, 1.0283f),
};

constant float2 wideMeshPoints[810] = {
    float2(0.0f, 0.0f), float2(0.13f, 0.0f), float2(0.25f, 0.0f), float2(0.38f, 0.0f),
    float2(0.5f, 0.0f), float2(0.63f, 0.0f), float2(0.75f, 0.0f), float2(0.88f, 0.0f),
    float2(1.0f, 0.0f), float2(0.0f, 0.13f), float2(0.13f, 0.13f), float2(0.25f, 0.13f),
    float2(0.38f, 0.13f), float2(0.5f, 0.13f), float2(0.63f, 0.13f), float2(0.75f, 0.13f),
    float2(0.88f, 0.13f), float2(1.0f, 0.13f), float2(0.0f, 0.25f), float2(0.13f, 0.25f),
    float2(0.25f, 0.25f), float2(0.38f, 0.25f), float2(0.5f, 0.25f), float2(0.63f, 0.25f),
    float2(0.75f, 0.25f), float2(0.88f, 0.25f), float2(1.0f, 0.25f), float2(0.0f, 0.38f),
    float2(0.13f, 0.38f), float2(0.25f, 0.38f), float2(0.38f, 0.38f), float2(0.5f, 0.38f),
    float2(0.63f, 0.38f), float2(0.75f, 0.38f), float2(0.88f, 0.38f), float2(1.0f, 0.38f),
    float2(0.0f, 0.5f), float2(0.13f, 0.5f), float2(0.25f, 0.5f), float2(0.38f, 0.5f),
    float2(0.5f, 0.5f), float2(0.63f, 0.5f), float2(0.75f, 0.5f), float2(0.88f, 0.5f),
    float2(1.0f, 0.5f), float2(0.0f, 0.63f), float2(0.13f, 0.63f), float2(0.25f, 0.63f),
    float2(0.38f, 0.63f), float2(0.5f, 0.63f), float2(0.63f, 0.63f), float2(0.75f, 0.63f),
    float2(0.88f, 0.63f), float2(1.0f, 0.63f), float2(0.0f, 0.75f), float2(0.13f, 0.75f),
    float2(0.25f, 0.75f), float2(0.38f, 0.75f), float2(0.5f, 0.75f), float2(0.63f, 0.75f),
    float2(0.75f, 0.75f), float2(0.88f, 0.75f), float2(1.0f, 0.75f), float2(0.0f, 0.88f),
    float2(0.13f, 0.88f), float2(0.25f, 0.88f), float2(0.38f, 0.88f), float2(0.5f, 0.88f),
    float2(0.63f, 0.88f), float2(0.75f, 0.88f), float2(0.88f, 0.88f), float2(1.0f, 0.88f),
    float2(0.0f, 1.0f), float2(0.13f, 1.0f), float2(0.25f, 1.0f), float2(0.38f, 1.0f),
    float2(0.5f, 1.0f), float2(0.63f, 1.0f), float2(0.75f, 1.0f), float2(0.88f, 1.0f),
    float2(1.0f, 1.0f), float2(-0.2292f, -0.0529f), float2(-0.0402f, -0.127f), float2(0.1116f, -0.3122f),
    float2(0.0923f, -0.336f), float2(1.1205f, -0.164f), float2(1.0089f, -0.0635f), float2(1.1205f, -0.0529f),
    float2(1.1116f, -0.0899f), float2(1.1979f, -0.0741f), float2(-0.2202f, 0.2685f), float2(0.0238f, 0.1435f),
    float2(0.0997f, 0.0933f), float2(0.0774f, 0.1091f), float2(0.75f, 0.0933f), float2(0.7738f, 0.1091f),
    float2(0.7991f, 0.1435f), float2(1.2798f, 0.088f), float2(1.1801f, 0.1435f), float2(-0.1667f, 0.3611f),
    float2(0.0432f, 0.25f), float2(0.1116f, 0.25f), float2(0.0923f, 0.2791f), float2(0.5387f, 0.2791f),
    float2(0.5908f, 0.3161f), float2(0.625f, 0.3161f), float2(0.9896f, 0.2791f), float2(1.0893f, 0.2341f),
    float2(-0.1176f, 0.4544f), float2(0.0625f, 0.3909f), float2(0.1503f, 0.4418f), float2(0.1637f, 0.4306f),
    float2(0.4836f, 0.3909f), float2(0.6161f, 0.4544f), float2(0.6458f, 0.4544f), float2(0.7411f, 0.3909f),
    float2(1.064f, 0.338f), float2(-0.0625f, 0.5344f), float2(0.0997f, 0.5159f), float2(0.2664f, 0.5721f),
    float2(0.2589f, 0.5721f), float2(0.4836f, 0.5344f), float2(0.7113f, 0.5344f), float2(0.7411f, 0.5344f),
    float2(0.7991f, 0.5159f), float2(1.0461f, 0.5f), float2(-0.0402f, 0.6574f), float2(0.375f, 0.713f),
    float2(0.3929f, 0.6574f), float2(0.375f, 0.625f), float2(0.5f, 0.6038f), float2(0.7991f, 0.5721f),
    float2(0.808f, 0.625f), float2(0.875f, 0.625f), float2(1.0461f, 0.6435f), float2(-0.0298f, 0.7685f),
    float2(0.3586f, 0.9041f), float2(0.4063f, 0.8003f), float2(0.4568f, 0.75f), float2(0.625f, 0.6574f),
    float2(0.8616f, 0.67f), float2(0.8408f, 0.713f), float2(0.8943f, 0.7288f), float2(1.1265f, 0.8214f),
    float2(-0.0402f, 0.9041f), float2(0.2589f, 1.0152f), float2(0.4747f, 0.9676f), float2(0.4568f, 0.8882f),
    float2(0.7411f, 0.8538f), float2(0.8616f, 0.8538f), float2(0.8408f, 0.875f), float2(0.9211f, 0.9438f),
    float2(1.1116f, 0.9676f), float2(-0.0625f, 1.0979f), float2(0.0238f, 1.2196f), float2(0.3304f, 1.0688f),
    float2(0.375f, 1.0f), float2(0.7887f, 1.0556f), float2(0.8408f, 1.0556f), float2(0.875f, 1.0688f),
    float2(0.9435f, 1.0688f), float2(1.0893f, 1.2196f), float2(0.0f, 0.0f), float2(0.13f, 0.0f),
    float2(0.25f, 0.0f), float2(0.38f, 0.0f), float2(0.5f, 0.0f), float2(0.63f, 0.0f),
    float2(0.75f, 0.0f), float2(0.88f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 0.13f),
    float2(0.13f, 0.13f), float2(0.25f, 0.13f), float2(0.38f, 0.13f), float2(0.5f, 0.13f),
    float2(0.63f, 0.13f), float2(0.75f, 0.13f), float2(0.88f, 0.13f), float2(1.0f, 0.13f),
    float2(0.0f, 0.25f), float2(0.13f, 0.25f), float2(0.25f, 0.25f), float2(0.38f, 0.25f),
    float2(0.5f, 0.25f), float2(0.63f, 0.25f), float2(0.75f, 0.25f), float2(0.88f, 0.25f),
    float2(1.0f, 0.25f), float2(0.0f, 0.38f), float2(0.13f, 0.38f), float2(0.25f, 0.38f),
    float2(0.38f, 0.38f), float2(0.5f, 0.38f), float2(0.63f, 0.38f), float2(0.75f, 0.38f),
    float2(0.88f, 0.38f), float2(1.0f, 0.38f), float2(0.0f, 0.5f), float2(0.13f, 0.5f),
    float2(0.25f, 0.5f), float2(0.38f, 0.5f), float2(0.5f, 0.5f), float2(0.63f, 0.5f),
    float2(0.75f, 0.5f), float2(0.88f, 0.5f), float2(1.0f, 0.5f), float2(0.0f, 0.63f),
    float2(0.13f, 0.63f), float2(0.25f, 0.63f), float2(0.38f, 0.63f), float2(0.5f, 0.63f),
    float2(0.63f, 0.63f), float2(0.75f, 0.63f), float2(0.88f, 0.63f), float2(1.0f, 0.63f),
    float2(0.0f, 0.75f), float2(0.13f, 0.75f), float2(0.25f, 0.75f), float2(0.38f, 0.75f),
    float2(0.5f, 0.75f), float2(0.63f, 0.75f), float2(0.75f, 0.75f), float2(0.88f, 0.75f),
    float2(1.0f, 0.75f), float2(0.0f, 0.88f), float2(0.13f, 0.88f), float2(0.25f, 0.88f),
    float2(0.38f, 0.88f), float2(0.5f, 0.88f), float2(0.63f, 0.88f), float2(0.75f, 0.88f),
    float2(0.88f, 0.88f), float2(1.0f, 0.88f), float2(0.0f, 1.0f), float2(0.13f, 1.0f),
    float2(0.25f, 1.0f), float2(0.38f, 1.0f), float2(0.5f, 1.0f), float2(0.63f, 1.0f),
    float2(0.75f, 1.0f), float2(0.88f, 1.0f), float2(1.0f, 1.0f), float2(-0.1726f, -0.1984f),
    float2(0.0551f, -0.2593f), float2(0.2158f, -0.2593f), float2(0.3839f, -0.1984f), float2(0.5119f, -0.1984f),
    float2(0.6473f, -0.1243f), float2(0.744f, -0.2698f), float2(1.0179f, -0.4259f), float2(1.2515f, -0.2698f),
    float2(0.0f, 0.0562f), float2(0.125f, 0.1971f), float2(0.2381f, 0.2679f), float2(0.375f, 0.2917f),
    float2(0.5f, 0.2202f), float2(0.625f, 0.125f), float2(0.8467f, -0.1111f), float2(1.0f, -0.1528f),
    float2(1.1042f, 0.0146f), float2(-0.0193f, 0.0357f), float2(0.125f, 0.1766f), float2(0.25f, 0.25f),
    float2(0.375f, 0.3082f), float2(0.5f, 0.25f), float2(0.625f, 0.1766f), float2(0.7887f, 0.0146f),
    float2(0.9598f, -0.0648f), float2(1.0551f, -0.0172f), float2(0.0f, 0.3353f), float2(0.125f, 0.3896f),
    float2(0.2167f, 0.3444f), float2(0.375f, 0.3231f), float2(0.5119f, 0.3772f), float2(0.625f, 0.3353f),
    float2(0.7768f, 0.1025f), float2(0.9464f, 0.0562f), float2(1.0685f, 0.1647f), float2(-0.0521f, 0.5192f),
    float2(0.125f, 0.4471f), float2(0.2229f, 0.3824f), float2(0.375f, 0.3444f), float2(0.5119f, 0.3933f),
    float2(0.6577f, 0.4353f), float2(0.75f, 0.4677f), float2(0.8601f, 0.4353f), float2(1.1473f, 0.2345f),
    float2(-0.0402f, 0.6442f), float2(0.125f, 0.5192f), float2(0.2277f, 0.4f), float2(0.375f, 0.3664f),
    float2(0.5119f, 0.4074f), float2(0.6577f, 0.4677f), float2(0.75f, 0.5f), float2(0.8527f, 0.4471f),
    float2(1.128f, 0.2345f), float2(-0.0253f, 0.7718f), float2(0.1116f, 0.5675f), float2(0.2339f, 0.4353f),
    float2(0.3708f, 0.4219f), float2(0.5148f, 0.4353f), float2(0.6726f, 0.5f), float2(0.7649f, 0.578f),
    float2(0.8601f, 0.5357f), float2(1.1622f, 0.3082f), float2(-0.0253f, 0.9041f), float2(0.0982f, 0.7718f),
    float2(0.2381f, 0.6872f), float2(0.375f, 0.6442f), float2(0.5119f, 0.6442f), float2(0.6577f, 0.6872f),
    float2(0.8229f, 0.7348f), float2(0.875f, 0.875f), float2(1.2411f, 1.1343f), float2(-0.0521f, 1.1005f),
    float2(0.0982f, 1.0556f), float2(0.2277f, 1.0556f), float2(0.3557f, 1.0556f), float2(0.5f, 1.1587f),
    float2(0.625f, 1.1799f), float2(0.7649f, 1.3677f), float2(0.8958f, 1.4841f), float2(1.0685f, 1.3519f),
    float2(0.0f, 0.0f), float2(0.13f, 0.0f), float2(0.25f, 0.0f), float2(0.38f, 0.0f),
    float2(0.5f, 0.0f), float2(0.63f, 0.0f), float2(0.75f, 0.0f), float2(0.88f, 0.0f),
    float2(1.0f, 0.0f), float2(0.0f, 0.13f), float2(0.13f, 0.13f), float2(0.25f, 0.13f),
    float2(0.38f, 0.13f), float2(0.5f, 0.13f), float2(0.63f, 0.13f), float2(0.75f, 0.13f),
    float2(0.88f, 0.13f), float2(1.0f, 0.13f), float2(0.0f, 0.25f), float2(0.13f, 0.25f),
    float2(0.25f, 0.25f), float2(0.38f, 0.25f), float2(0.5f, 0.25f), float2(0.63f, 0.25f),
    float2(0.75f, 0.25f), float2(0.88f, 0.25f), float2(1.0f, 0.25f), float2(0.0f, 0.38f),
    float2(0.13f, 0.38f), float2(0.25f, 0.38f), float2(0.38f, 0.38f), float2(0.5f, 0.38f),
    float2(0.63f, 0.38f), float2(0.75f, 0.38f), float2(0.88f, 0.38f), float2(1.0f, 0.38f),
    float2(0.0f, 0.5f), float2(0.13f, 0.5f), float2(0.25f, 0.5f), float2(0.38f, 0.5f),
    float2(0.5f, 0.5f), float2(0.63f, 0.5f), float2(0.75f, 0.5f), float2(0.88f, 0.5f),
    float2(1.0f, 0.5f), float2(0.0f, 0.63f), float2(0.13f, 0.63f), float2(0.25f, 0.63f),
    float2(0.38f, 0.63f), float2(0.5f, 0.63f), float2(0.63f, 0.63f), float2(0.75f, 0.63f),
    float2(0.88f, 0.63f), float2(1.0f, 0.63f), float2(0.0f, 0.75f), float2(0.13f, 0.75f),
    float2(0.25f, 0.75f), float2(0.38f, 0.75f), float2(0.5f, 0.75f), float2(0.63f, 0.75f),
    float2(0.75f, 0.75f), float2(0.88f, 0.75f), float2(1.0f, 0.75f), float2(0.0f, 0.88f),
    float2(0.13f, 0.88f), float2(0.25f, 0.88f), float2(0.38f, 0.88f), float2(0.5f, 0.88f),
    float2(0.63f, 0.88f), float2(0.75f, 0.88f), float2(0.88f, 0.88f), float2(1.0f, 0.88f),
    float2(0.0f, 1.0f), float2(0.13f, 1.0f), float2(0.25f, 1.0f), float2(0.38f, 1.0f),
    float2(0.5f, 1.0f), float2(0.63f, 1.0f), float2(0.75f, 1.0f), float2(0.88f, 1.0f),
    float2(1.0f, 1.0f), float2(-0.064f, -0.1323f), float2(0.0893f, -0.1614f), float2(0.25f, -0.0608f),
    float2(0.5729f, -0.1614f), float2(0.6771f, -0.1614f), float2(0.7292f, -0.1614f), float2(0.7634f, -0.1217f),
    float2(0.875f, -0.0608f), float2(1.0164f, -0.0423f), float2(-0.0714f, 0.1091f), float2(0.2054f, 0.0985f),
    float2(0.2292f, 0.1091f), float2(0.375f, 0.125f), float2(0.5357f, 0.2077f), float2(0.6131f, 0.25f),
    float2(0.6458f, 0.125f), float2(0.75f, -0.0284f), float2(1.0164f, 0.1091f), float2(-0.0565f, 0.25f),
    float2(0.1696f, 0.2077f), float2(0.1771f, 0.2262f), float2(0.2143f, 0.2262f), float2(0.375f, 0.1759f),
    float2(0.625f, 0.2937f), float2(0.6369f, 0.3161f), float2(0.6652f, 0.2262f), float2(1.0104f, 0.2262f),
    float2(-0.0565f, 0.375f), float2(0.0997f, 0.375f), float2(0.125f, 0.375f), float2(0.1771f, 0.3882f),
    float2(0.3616f, 0.2077f), float2(0.6131f, 0.3406f), float2(0.6548f, 0.3406f), float2(0.7068f, 0.375f),
    float2(1.0313f, 0.3538f), float2(-0.1429f, 0.6058f), float2(0.1414f, 0.5f), float2(0.1563f, 0.5f),
    float2(0.1949f, 0.5f), float2(0.5193f, 0.2937f), float2(0.6964f, 0.4517f), float2(0.7158f, 0.4517f),
    float2(0.7902f, 0.4841f), float2(1.0461f, 0.4841f), float2(-0.0714f, 0.6753f), float2(0.2054f, 0.625f),
    float2(0.2054f, 0.625f), float2(0.2292f, 0.625f), float2(0.6131f, 0.375f), float2(0.7158f, 0.5298f),
    float2(0.7634f, 0.5456f), float2(0.8557f, 0.625f), float2(1.0789f, 0.625f), float2(-0.0565f, 0.8108f),
    float2(0.2143f, 0.75f), float2(0.2292f, 0.75f), float2(0.25f, 0.7315f), float2(0.6652f, 0.6865f),
    float2(0.7634f, 0.6462f), float2(0.8095f, 0.7077f), float2(0.8914f, 0.75f), float2(1.0923f, 0.75f),
    float2(-0.0565f, 0.9306f), float2(0.2054f, 0.9067f), float2(0.2054f, 0.9306f), float2(0.2292f, 0.9411f),
    float2(0.625f, 0.875f), float2(0.7634f, 0.7718f), float2(0.8557f, 0.8108f), float2(0.939f, 0.8538f),
    float2(1.0789f, 0.9306f), float2(0.0f, 1.0f), float2(-0.0714f, 1.2169f), float2(0.125f, 1.4021f),
    float2(0.25f, 1.0794f), float2(0.625f, 1.0794f), float2(0.7902f, 1.0794f), float2(0.875f, 1.0794f),
    float2(0.9509f, 1.0582f), float2(1.0104f, 1.0794f), float2(0.0f, 0.0f), float2(0.13f, 0.0f),
    float2(0.25f, 0.0f), float2(0.38f, 0.0f), float2(0.5f, 0.0f), float2(0.63f, 0.0f),
    float2(0.75f, 0.0f), float2(0.88f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 0.13f),
    float2(0.13f, 0.13f), float2(0.25f, 0.13f), float2(0.38f, 0.13f), float2(0.5f, 0.13f),
    float2(0.63f, 0.13f), float2(0.75f, 0.13f), float2(0.88f, 0.13f), float2(1.0f, 0.13f),
    float2(0.0f, 0.25f), float2(0.13f, 0.25f), float2(0.25f, 0.25f), float2(0.38f, 0.25f),
    float2(0.5f, 0.25f), float2(0.63f, 0.25f), float2(0.75f, 0.25f), float2(0.88f, 0.25f),
    float2(1.0f, 0.25f), float2(0.0f, 0.38f), float2(0.13f, 0.38f), float2(0.25f, 0.38f),
    float2(0.38f, 0.38f), float2(0.5f, 0.38f), float2(0.63f, 0.38f), float2(0.75f, 0.38f),
    float2(0.88f, 0.38f), float2(1.0f, 0.38f), float2(0.0f, 0.5f), float2(0.13f, 0.5f),
    float2(0.25f, 0.5f), float2(0.38f, 0.5f), float2(0.5f, 0.5f), float2(0.63f, 0.5f),
    float2(0.75f, 0.5f), float2(0.88f, 0.5f), float2(1.0f, 0.5f), float2(0.0f, 0.63f),
    float2(0.13f, 0.63f), float2(0.25f, 0.63f), float2(0.38f, 0.63f), float2(0.5f, 0.63f),
    float2(0.63f, 0.63f), float2(0.75f, 0.63f), float2(0.88f, 0.63f), float2(1.0f, 0.63f),
    float2(0.0f, 0.75f), float2(0.13f, 0.75f), float2(0.25f, 0.75f), float2(0.38f, 0.75f),
    float2(0.5f, 0.75f), float2(0.63f, 0.75f), float2(0.75f, 0.75f), float2(0.88f, 0.75f),
    float2(1.0f, 0.75f), float2(0.0f, 0.88f), float2(0.13f, 0.88f), float2(0.25f, 0.88f),
    float2(0.38f, 0.88f), float2(0.5f, 0.88f), float2(0.63f, 0.88f), float2(0.75f, 0.88f),
    float2(0.88f, 0.88f), float2(1.0f, 0.88f), float2(0.0f, 1.0f), float2(0.13f, 1.0f),
    float2(0.25f, 1.0f), float2(0.38f, 1.0f), float2(0.5f, 1.0f), float2(0.63f, 1.0f),
    float2(0.75f, 1.0f), float2(0.88f, 1.0f), float2(1.0f, 1.0f), float2(-0.2292f, -0.3968f),
    float2(0.0699f, -0.3439f), float2(0.2217f, -0.1799f), float2(0.3512f, -0.1376f), float2(0.6533f, -0.2407f),
    float2(0.6845f, -0.164f), float2(0.7753f, -0.3148f), float2(0.9494f, -0.3677f), float2(1.381f, -0.5476f),
    float2(-0.1711f, 0.0827f), float2(-0.0387f, -0.1263f), float2(0.25f, 0.125f), float2(0.2887f, 0.125f),
    float2(0.5f, 0.125f), float2(0.5565f, 0.125f), float2(0.7827f, -0.0787f), float2(0.9182f, -0.1799f),
    float2(1.2039f, -0.0628f), float2(-0.1057f, 0.2209f), float2(0.0268f, 0.1918f), float2(0.25f, 0.25f),
    float2(0.2679f, 0.2844f), float2(0.2887f, 0.2685f), float2(0.3958f, 0.2844f), float2(0.6771f, 0.125f),
    float2(0.9702f, 0.0542f), float2(1.2113f, 0.1091f), float2(-0.1176f, 0.2983f), float2(0.1101f, 0.33f),
    float2(0.25f, 0.42f), float2(0.317f, 0.42f), float2(0.3571f, 0.42f), float2(0.3958f, 0.42f),
    float2(0.6369f, 0.2983f), float2(0.9107f, 0.2844f), float2(1.2113f, 0.33f), float2(-0.1533f, 0.375f),
    float2(0.1533f, 0.375f), float2(0.2292f, 0.42f), float2(0.375f, 0.5f), float2(0.4301f, 0.5377f),
    float2(0.4583f, 0.5377f), float2(0.6845f, 0.4735f), float2(0.811f, 0.4735f), float2(1.1369f, 0.463f),
    float2(-0.0938f, 0.5728f), float2(0.1533f, 0.4054f), float2(0.3363f, 0.5f), float2(0.4167f, 0.5377f),
    float2(0.5f, 0.625f), float2(0.5476f, 0.6991f), float2(0.7887f, 0.6118f), float2(0.8378f, 0.588f),
    float2(1.1563f, 0.5608f), float2(-0.0789f, 0.75f), float2(0.25f, 0.5608f), float2(0.3958f, 0.5608f),
    float2(0.4732f, 0.625f), float2(0.5402f, 0.75f), float2(0.5967f, 0.7976f), float2(0.8839f, 0.7361f),
    float2(0.8839f, 0.7811f), float2(1.1563f, 0.6389f), float2(-0.1057f, 0.9226f), float2(0.125f, 0.875f),
    float2(0.2976f, 0.875f), float2(0.4464f, 0.8882f), float2(0.5908f, 0.9041f), float2(0.625f, 0.875f),
    float2(0.9702f, 0.9041f), float2(1.0268f, 1.0f), float2(1.1726f, 1.0443f), float2(-0.0387f, 1.1138f),
    float2(0.0878f, 1.1349f), float2(0.2292f, 1.1138f), float2(0.4301f, 1.1852f), float2(0.625f, 1.2804f),
    float2(0.625f, 1.3254f), float2(1.0372f, 1.2328f), float2(0.9568f, 1.2328f), float2(1.0938f, 1.2328f),
    float2(0.0f, 0.0f), float2(0.13f, 0.0f), float2(0.25f, 0.0f), float2(0.38f, 0.0f),
    float2(0.5f, 0.0f), float2(0.63f, 0.0f), float2(0.75f, 0.0f), float2(0.88f, 0.0f),
    float2(1.0f, 0.0f), float2(0.0f, 0.13f), float2(0.13f, 0.13f), float2(0.25f, 0.13f),
    float2(0.38f, 0.13f), float2(0.5f, 0.13f), float2(0.63f, 0.13f), float2(0.75f, 0.13f),
    float2(0.88f, 0.13f), float2(1.0f, 0.13f), float2(0.0f, 0.25f), float2(0.13f, 0.25f),
    float2(0.25f, 0.25f), float2(0.38f, 0.25f), float2(0.5f, 0.25f), float2(0.63f, 0.25f),
    float2(0.75f, 0.25f), float2(0.88f, 0.25f), float2(1.0f, 0.25f), float2(0.0f, 0.38f),
    float2(0.13f, 0.38f), float2(0.25f, 0.38f), float2(0.38f, 0.38f), float2(0.5f, 0.38f),
    float2(0.63f, 0.38f), float2(0.75f, 0.38f), float2(0.88f, 0.38f), float2(1.0f, 0.38f),
    float2(0.0f, 0.5f), float2(0.13f, 0.5f), float2(0.25f, 0.5f), float2(0.38f, 0.5f),
    float2(0.5f, 0.5f), float2(0.63f, 0.5f), float2(0.75f, 0.5f), float2(0.88f, 0.5f),
    float2(1.0f, 0.5f), float2(0.0f, 0.63f), float2(0.13f, 0.63f), float2(0.25f, 0.63f),
    float2(0.38f, 0.63f), float2(0.5f, 0.63f), float2(0.63f, 0.63f), float2(0.75f, 0.63f),
    float2(0.88f, 0.63f), float2(1.0f, 0.63f), float2(0.0f, 0.75f), float2(0.13f, 0.75f),
    float2(0.25f, 0.75f), float2(0.38f, 0.75f), float2(0.5f, 0.75f), float2(0.63f, 0.75f),
    float2(0.75f, 0.75f), float2(0.88f, 0.75f), float2(1.0f, 0.75f), float2(0.0f, 0.88f),
    float2(0.13f, 0.88f), float2(0.25f, 0.88f), float2(0.38f, 0.88f), float2(0.5f, 0.88f),
    float2(0.63f, 0.88f), float2(0.75f, 0.88f), float2(0.88f, 0.88f), float2(1.0f, 0.88f),
    float2(0.0f, 1.0f), float2(0.13f, 1.0f), float2(0.25f, 1.0f), float2(0.38f, 1.0f),
    float2(0.5f, 1.0f), float2(0.63f, 1.0f), float2(0.75f, 1.0f), float2(0.88f, 1.0f),
    float2(1.0f, 1.0f), float2(-0.0952f, -0.1561f), float2(0.0997f, -0.1561f), float2(0.2396f, -0.0847f),
    float2(0.3586f, -0.0608f), float2(0.4926f, -0.0608f), float2(0.6086f, -0.1561f), float2(0.7426f, -0.1772f),
    float2(0.8616f, -0.1561f), float2(1.064f, -0.2275f), float2(-0.0521f, 0.0933f), float2(-0.0521f, 0.3062f),
    float2(0.2708f, 0.375f), float2(0.375f, 0.3485f), float2(0.4926f, 0.3062f), float2(0.625f, 0.2335f),
    float2(0.75f, 0.125f), float2(0.875f, -0.0337f), float2(1.064f, -0.1772f), float2(-0.125f, 0.3611f),
    float2(0.0789f, 0.5f), float2(0.2827f, 0.4147f), float2(0.3824f, 0.375f), float2(0.4926f, 0.33f),
    float2(0.625f, 0.25f), float2(0.75f, 0.1812f), float2(0.8988f, 0.0146f), float2(1.0804f, -0.123f),
    float2(-0.0952f, 0.5119f), float2(0.1518f, 0.5344f), float2(0.2827f, 0.4683f), float2(0.3824f, 0.4147f),
    float2(0.4926f, 0.375f), float2(0.625f, 0.2851f), float2(0.7589f, 0.2163f), float2(0.8988f, 0.2335f),
    float2(1.119f, 0.4147f), float2(-0.0521f, 0.625f), float2(0.2827f, 0.5344f), float2(0.2961f, 0.5985f),
    float2(0.3646f, 0.5119f), float2(0.4926f, 0.3995f), float2(0.6324f, 0.3062f), float2(0.7589f, 0.2619f),
    float2(0.9286f, 0.3062f), float2(1.1071f, 0.4683f), float2(-0.1399f, 0.6938f), float2(0.2902f, 0.5721f),
    float2(0.2604f, 0.6759f), float2(0.3586f, 0.5344f), float2(0.5f, 0.4286f), float2(0.6414f, 0.33f),
    float2(0.8006f, 0.3062f), float2(0.9673f, 0.375f), float2(1.119f, 0.5985f), float2(-0.0521f, 0.7897f),
    float2(0.192f, 0.8294f), float2(0.25f, 0.75f), float2(0.2708f, 0.6759f), float2(0.5f, 0.5119f),
    float2(0.7738f, 0.5589f), float2(0.8988f, 0.7315f), float2(0.9286f, 0.713f), float2(1.119f, 0.75f),
    float2(-0.0685f, 0.9438f), float2(0.1518f, 0.9438f), float2(0.1979f, 0.875f), float2(0.25f, 0.957f),
    float2(0.5f, 0.7718f), float2(0.7738f, 0.7315f), float2(0.936f, 0.9755f), float2(1.0f, 1.0205f),
    float2(1.1726f, 0.957f), float2(-0.0283f, 1.0873f), float2(0.0997f, 1.1561f), float2(0.125f, 1.1799f),
    float2(0.2604f, 1.1243f), float2(0.4926f, 1.0688f), float2(0.8006f, 1.0873f), float2(0.9167f, 1.1376f),
    float2(1.0313f, 1.2698f), float2(1.1548f, 1.3228f),
};


static float2 rotateAroundOrigin(float2 point, float angle) {
    float sine = sin(angle);
    float cosine = cos(angle);
    return float2(
        cosine * point.x - sine * point.y,
        sine * point.x + cosine * point.y
    );
}

static bool sourceCoordinates(
    float2 destination,
    float2 size,
    float time,
    float4 spectrum,
    float motionIntensity,
    int instance,
    thread float2 &source
) {
    float2 point = destination / size;
    point = float2(point.x * 2.0f - 1.0f, 1.0f - point.y * 2.0f);

    if (size.y > size.x) {
        point.x /= size.y / size.x;
    } else {
        point.y /= size.x / size.y;
    }

    float effectiveTime = time * max(motionIntensity, 0.0f);
    if (instance == 2) {
        point = rotateAroundOrigin(
            point,
            -effectiveTime * (2.0f * M_PI_F / 120.0f)
        );
    }

    float audioScale =
        1.0f
        + pow(mix(spectrum.x, spectrum.y, 0.1f), 2.0f)
            * 0.33f;
    point /= audioScale;

    float modelScale;
    float2 translation;
    float timeScale;
    if (instance == 0) {
        modelScale = 1.4f;
        translation = float2(0.0f);
        timeScale = 120.0f;
    } else if (instance == 1) {
        modelScale = 0.7f;
        translation = float2(-0.175f, 0.105f);
        timeScale = 70.0f;
    } else {
        modelScale = 0.7f;
        translation = float2(0.49f, 0.49f);
        timeScale = 90.0f;
    }

    point = (point - translation) / modelScale;
    point = rotateAroundOrigin(
        point,
        -effectiveTime * (2.0f * M_PI_F / timeScale)
    );

    source = float2(
        point.x * 0.5f + 0.5f,
        0.5f - point.y * 0.5f
    ) * size;
    float2 unitSource = source / size;
    return all(unitSource >= 0.0f) && all(unitSource <= 1.0f);
}

[[ stitchable ]]
half4 appleMusicBackdropRotation(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float4 spectrum,
    float saturation,
    float blackScrimAlpha,
    float motionIntensity
) {
    half3 color = half3(0.3h);
    int selectedInstance = 0;

    for (int instance = 2; instance >= 0; --instance) {
        float2 source;
        if (sourceCoordinates(
            position,
            size,
            time,
            spectrum,
            motionIntensity,
            instance,
            source
        )) {
            color = layer.sample(source).rgb;
            selectedInstance = instance;
            break;
        }
    }

    float blackMix = clamp(
        blackScrimAlpha + float(selectedInstance) * 0.0075f,
        0.0f,
        1.0f
    );
    color = mix(color, half3(0.0h), half(blackMix));

    float contrast =
        1.0f
        + spectrum.x * 0.076f;
    color = (color - half3(0.5h)) * half(contrast) + half3(0.5h);

    float effectiveSaturation =
        saturation
        + spectrum.z * 0.166f;
    half luminance = dot(
        color,
        half3(0.2126h, 0.7152h, 0.0722h)
    );
    color = mix(
        half3(luminance),
        color,
        half(effectiveSaturation)
    );
    return half4(color, 1.0h);
}

static float2 meshPoint(
    bool usesWideMesh,
    uint meshPair,
    bool usesSecondCoordinates,
    uint x,
    uint y
) {
    uint dimension = usesWideMesh ? 9u : 6u;
    uint pointCount = dimension * dimension;
    uint mesh = meshPair * 2u + (usesSecondCoordinates ? 1u : 0u);
    uint index = mesh * pointCount + y * dimension + x;
    return usesWideMesh
        ? wideMeshPoints[index]
        : compactMeshPoints[index];
}

static float2 meshTextureCoordinates(
    float2 destination,
    bool usesWideMesh,
    uint meshPair,
    bool usesSecondCoordinates
) {
    // The source renderer evaluates each extracted pair over a regular
    // triangle grid. Keeping the output grid regular makes the mapping
    // single-valued and continuous across every shared edge.
    uint dimension = usesWideMesh ? 9u : 6u;
    uint cellCount = dimension - 1u;
    float2 scaled = clamp(destination, 0.0f, 1.0f) * float(cellCount);
    uint2 cell = min(
        uint2(floor(scaled)),
        uint2(cellCount - 1u)
    );
    float2 local = scaled - float2(cell);

    float2 coordinates00 = meshPoint(
        usesWideMesh,
        meshPair,
        usesSecondCoordinates,
        cell.x,
        cell.y
    );
    float2 coordinates10 = meshPoint(
        usesWideMesh,
        meshPair,
        usesSecondCoordinates,
        cell.x + 1u,
        cell.y
    );
    float2 coordinates01 = meshPoint(
        usesWideMesh,
        meshPair,
        usesSecondCoordinates,
        cell.x,
        cell.y + 1u
    );

    if (local.x + local.y <= 1.0f) {
        return coordinates00
            + local.x * (coordinates10 - coordinates00)
            + local.y * (coordinates01 - coordinates00);
    }

    float2 coordinates11 = meshPoint(
        usesWideMesh,
        meshPair,
        usesSecondCoordinates,
        cell.x + 1u,
        cell.y + 1u
    );
    return coordinates11
        + (1.0f - local.y) * (coordinates10 - coordinates11)
        + (1.0f - local.x) * (coordinates01 - coordinates11);
}

[[ stitchable ]]
half4 appleMusicBackdropPinch(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float pinchMix,
    float meshIndex
) {
    float2 destination = position / size;
    bool usesWideMesh = size.x > size.y;
    uint meshPair = min(uint(max(meshIndex, 0.0f)), 4u);
    float2 firstCoordinates = meshTextureCoordinates(
        destination,
        usesWideMesh,
        meshPair,
        false
    );
    float2 secondCoordinates = meshTextureCoordinates(
        destination,
        usesWideMesh,
        meshPair,
        true
    );
    float warpMix = (sin(time / 3.5f) + 1.0f) * 0.5f;
    float2 pinchedSource = mix(
        firstCoordinates,
        secondCoordinates,
        warpMix
    );
    float2 source = mix(
        destination,
        pinchedSource,
        clamp(pinchMix, 0.0f, 1.0f)
    );
    return layer.sample(clamp(source, 0.0f, 1.0f) * size);
}
