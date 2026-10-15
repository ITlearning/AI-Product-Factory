#include <metal_stdlib>
using namespace metal;

// 서리 — 유리창 귀퉁이에서 안쪽으로 자란 고사리 서리(사진 결정 결) + 뿌연 얼음막 + 결정 끝 반짝임.
// SkyShader.metal 의 SkyU 와 배치가 같아야 한다(float4 × 20) — SkyU 에 필드를 넣으면 여기도.
struct FrostU {
    float4 res, view, light, quality, tone, parallax, rays, moon, meteor0, meteor1, blend, sun, caps, extra, textBig, win;
    float4 text[4];
};

struct VOut { float4 pos [[position]]; float2 uv; };

static float3 rlin(float3 c) { return pow(c, float3(2.2)); }

static float rh12(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float rnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(rh12(i), rh12(i + float2(1, 0)), w.x), mix(rh12(i + float2(0, 1)), rh12(i + float2(1, 1)), w.x), w.y);
}

static float rfbm(float2 p) {
    return 0.55 * rnoise(p) + 0.3 * rnoise(p * 2.1 + 5.3) + 0.15 * rnoise(p * 4.3 + 1.7);
}

static float rTextMask(constant FrostU& u, float2 pt, float feather) {
    float m = 0.0;
    int n = int(u.parallax.z);
    for (int i = 0; i < n; i++) {
        float4 r = u.text[i];
        float2 d = max(r.xy - pt, pt - r.zw);
        float sd = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
        m = max(m, 1.0 - smoothstep(-2.0, feather, sd));
    }
    return m;
}

// 귀퉁이 하나 — 결정 결을 귀퉁이에서 화면 가운데 쪽으로 자라게 돌려 읽는다.
// x 결 그대로, y 굵은 밉(깃털 덩어리) — 자라는 앞머리는 덩어리로 끊어 점점이 흩어지지 않게 한다.
static float2 crystalAt(texture2d<float> tex, float2 pt, float2 corner, float2 inward, float texPt, float2 ofs, float lodBias) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::mirrored_repeat);
    float2 q = pt - corner;
    float2 side = float2(-inward.y, inward.x);
    float2 uv = float2(dot(q, side), -dot(q, inward)) / texPt * float2(1.0, 1.6) + ofs;
    return float2(tex.sample(s, uv, bias(lodBias)).r, tex.sample(s, uv, bias(lodBias + 3.5)).r);
}

fragment float4 skyFrostOverlay(VOut in [[stage_in]], constant FrostU& u [[buffer(0)]],
                                texture2d<float> tex [[texture(0)]]) {
    float W = u.view.x, H = u.view.y;
    float2 pt = in.uv * u.view.xy;
    float m = min(W, H);
    float t = u.view.z;
    float pxPerPt = u.res.x / W;
    float tm = rTextMask(u, pt, 8.0 + 0.12 * m);
    if (tm >= 0.999) return float4(0.0);

    float2 warp = (float2(rfbm(pt / (0.22 * m)), rfbm(pt / (0.22 * m) + 7.1)) - 0.5) * 0.35 * m;
    float2 wp = pt + warp;
    // 넓은 카드는 네 귀퉁이가 글자 자리 — 가운데 칸의 위아래 가장자리에서 자란다.
    float2 corners[4] = { float2(W, H), float2(W, 0), float2(0, H), float2(0, 0) };
    float weights[4] = { 1.0, 0.8, 0.5, 0.42 };
    if (W > 1.8 * H) {
        corners[0] = float2(0.66 * W, H); corners[1] = float2(0.56 * W, 0.0);
        weights[0] = 1.0; weights[1] = 0.75; weights[2] = 0.3; weights[3] = 0.3;
    }
    float2 ofs[4] = { float2(0.71, 0.33), float2(0.57, 0.08), float2(0.31, 0.77), float2(0.82, 0.55) };
    float2 mid = float2(W, H) * 0.5;
    bool wide = W > 1.8 * H;
    float reach = (wide ? 0.95 : 0.6) * m;
    float texPt = (wide ? 1.7 : 1.35) * m;
    float lodBias = 0.3;

    float crys = 0.0, potential = 0.0, bright = 0.0;
    for (int i = 0; i < 4; i++) {
        float2 c = corners[i];
        float R = reach * weights[i];
        float P = 1.0 - length((wp - c) * float2(1.0, wide ? 1.5 : 1.0)) / R;
        if (P <= -0.15) continue;
        potential = max(potential, P);
        float2 inward = normalize(mid - c + float2(0.0, 0.001));
        float2 v = crystalAt(tex, pt, c, inward, texPt, ofs[i], lodBias);
        // 귀퉁이 가까이는 결 전부, 멀어질수록 결이 빽빽한 깃털 덩어리만 남는다.
        float thr = mix(0.05, 0.5, saturate(1.0 - P));
        float clump = smoothstep(thr, thr + 0.2, v.y);
        float a = smoothstep(0.16, 0.55, v.x) * clump * smoothstep(0.0, 0.25, P);
        if (a > crys) { crys = a; bright = v.x; }
    }
    float e = min(min(pt.x, W - pt.x), min(pt.y, H - pt.y));
    float band = 1.0 - (e + warp.x * 0.25) / (0.035 * m + 4.0);
    if (band > -0.1) {
        float2 inward = pt.x < e + 0.5 ? float2(1, 0) : (W - pt.x < e + 0.5 ? float2(-1, 0) : (pt.y < e + 0.5 ? float2(0, 1) : float2(0, -1)));
        float2 c = inward.x != 0.0 ? float2(inward.x > 0.0 ? 0.0 : W, 0.0) : float2(0.0, inward.y > 0.0 ? 0.0 : H);
        float2 v = crystalAt(tex, pt, c, inward, texPt * 0.8, float2(0.4, 0.2), lodBias);
        float thr = mix(0.08, 0.5, saturate(1.0 - band));
        float a = smoothstep(0.16, 0.55, v.x) * smoothstep(thr, thr + 0.2, v.y) * smoothstep(-0.1, 0.2, band) * 0.85;
        if (a > crys) { crys = a; bright = v.x; }
        potential = max(potential, band * 0.8);
    }
    float haze = pow(saturate(potential), 1.5) * 0.5 + saturate(band) * 0.12;

    float2 lp = u.light.xy;
    float sunK = exp(-distance(pt, lp) / (0.7 * m));
    float3 ice = rlin(float3(0.88, 0.94, 1.0));
    float3 cc = ice * (0.62 + 0.55 * bright) * (1.0 + 0.5 * sunK);
    float3 hc = rlin(float3(0.8, 0.86, 0.93)) * (0.85 + 0.3 * sunK);

    // 결정 끝 반짝임 — 해 쪽이 더 많고 밝다(EDR 살짝).
    float2 cell = floor(pt / 4.0);
    float2 h = float2(rh12(cell + 41.0), rh12(cell + 77.3));
    float2 dv = pt - (cell + 0.2 + 0.6 * h) * 4.0;
    float glint = 0.0;
    if (rh12(cell + 9.4) < 0.1 + 0.25 * sunK && crys > 0.55) {
        float tw = 0.55 + 0.45 * sin(t * (1.1 + 1.8 * h.x) + h.y * 40.0);
        float sg = max(0.4, 0.6 / pxPerPt);
        glint = exp(-dot(dv, dv) / (sg * sg)) * tw * tw * (0.5 + 1.6 * sunK) * crys;
    }

    float keep = 1.0 - tm;
    float ca = crys * 0.88 * keep;
    float ha = haze * keep;
    float a = ca + ha * (1.0 - ca);
    float3 col = cc * ca + hc * ha * (1.0 - ca) + rlin(float3(1.0, 0.98, 0.94)) * glint * keep * 1.3;
    return float4(col, a);
}
