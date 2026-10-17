#include <metal_stdlib>
using namespace metal;

// SkyView.swift 의 SkyUniforms 와 같은 순서·크기(float4 × 20). 하나를 고치면 둘 다 고친다.
struct SkyU {
    float4 res;       // 그리는 대상 px w, h, 1/w, 1/h
    float4 view;      // pt w, h, 시간 t, 장면
    float4 light;     // 해·달 pt x, y, 원판 반지름 pt, 화면에 그림(1)/안 그림(0)
    float4 quality;   // 구름 걸음, 빛 걸음, 잔결(0/1), 먼 층 걸음
    float4 tone;      // EDR 여유, 글자 둘레 빛 누르기(0~1), 그레인, 블룸 세기
    float4 parallax;  // 기울기 pt x, y, 글자 자리 수, 글자 자리 번짐 pt
    float4 rays;      // 빛줄기 걸음, 빛줄기 세기, 프레임 번호, 빗방울 수
    float4 moon;      // 달 나이(일), 명암 경계 기울기(rad), 지구조 세기, 텍스처 있음(1)
    float4 meteor0;   // 별똥별 머리 pt x, y, 나아가는 방향 x, y
    float4 meteor1;   // 꼬리 길이 pt, 세기(0 = 없음), 굵기 pt, 별 층 수(1~3)
    float4 blend;     // 구름 두 장 섞기 w, t - tA, tB - t, 구름 흐름 pt/초 — 구운 구름이면 w, 구운 판 pt w, h, 흐름
    float4 sun;       // 햇무리 반지름 pt, 눈부심 길이 pt, 새털구름 옥타브, 햇무리 얼룩(1)
    float4 caps;      // 글자 쪽 최대 밝기(0 = 안 누름, 넓은 경사로 건다), 나머지는 안 씀
    float4 extra;     // 글자 쪽 구름 옅게(0~1), 별 층 수(새벽), 눈·꽃잎·잎 수, 덧그림 옥타브
    float4 textBig;   // 글자 자리마다 큰 말(1)/작은 글자(0)
    float4 win;       // 세계 창 pt x, y(구운 구름이면 판 안 자리), 구운 구름 불투명도, 구름 방식(0 실시간 · 1 구운 판 읽기 · 2 굽기)
    float4 text[4];   // 글자 자리 pt x0, y0, x1, y1
};

constant float WORLD = 320.0;   // pt — 같은 하늘이 카드 크기만큼 잘려 들어가게 모든 무늬를 pt 로 잰다
constant float SLAB = 0.55;     // 구름층 두께(월드 단위)

struct VOut { float4 pos [[position]]; float2 uv; };

// SkyScene.rawValue
#define S_CLOUDY 0
#define S_DAY 1
#define S_RAIN 2
#define S_NIGHT 3
#define S_DAWN 4
#define S_DUSK 5
#define S_DRIZZLE 6
#define S_SNOW 7
#define S_FOG 8
#define S_WIND 9
#define S_PETALS 10
#define S_LEAVES 11
#define S_FROST 12

static bool nightScene(int s) { return s == S_CLOUDY || s == S_NIGHT; }
static bool rainScene(int s) { return s == S_RAIN || s == S_DRIZZLE; }
// 해를 그리는 장면(원판이 화면 밖이어도 번짐은 그린다)
static bool sunScene(int s) { return s == S_DAY || s == S_DAWN || s == S_DUSK || s == S_FOG || s == S_WIND || s == S_PETALS || s == S_LEAVES || s == S_FROST; }

vertex VOut skyFullscreen(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VOut o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(p.x, 1.0 - p.y);
    return o;
}

// MARK: - 도움 함수

static float3 lin(float3 c) { return pow(c, float3(2.2)); }
static float lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float remap(float v, float a, float b, float c, float d) { return c + (v - a) / max(b - a, 1e-5) * (d - c); }

static float hash12(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

static float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

static float tnoise(float x) {
    float i = floor(x), f = fract(x);
    return mix(hash11(i), hash11(i + 1.0), f * f * (3.0 - 2.0 * f));
}

static float ign(float2 px) { return fract(52.9829189 * fract(dot(px, float2(0.06711056, 0.00583715)))); }

static float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i), b = hash12(i + float2(1, 0)), c = hash12(i + float2(0, 1)), d = hash12(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm2(float2 p, int oct) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < oct; i++) {
        s += a * vnoise(p);
        p = float2x2(1.6, 1.2, -1.2, 1.6) * p + 3.1;
        a *= 0.5;
    }
    return s;
}

// 글자 묶음 쪽으로 기우는 넓은 덮임 경사(0~1) — 자리마다 화면 크기의 절반 넘게 번진 혹을 부드럽게 겹친다(4제곱 합).
// 구름을 글자 모양으로 자르지 않고, 글자 쪽엔 애초에 옅게 생기게 한다.
// wide: 목록 카드에서도 짧은 변(96pt)이 아니라 긴 변의 절반까지 번진다 — 빛 덜기·밝기 상한·별·입자처럼 하늘 전체를 바꾸는 쪽.
static float textLean(constant SkyU& u, float2 pt, bool wide = false) {
    int n = int(u.parallax.z);
    float W = u.view.x, H = u.view.y;
    float F = min(wide ? 0.5 * max(W, H) : min(0.5 * max(W, H), min(W, H)), 200.0);
    float s = 0.0;
    for (int i = 0; i < n; i++) {
        float4 r = u.text[i];
        float2 d = max(r.xy - pt, pt - r.zw);
        float sd = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
        float x = saturate((sd + 0.15 * F) / (1.15 * F));
        float c = 1.0 - x * x * (3.0 - 2.0 * x);
        s += c * c * c * c;
    }
    float k = min(sqrt(sqrt(s)), 1.0);
    return k * k;
}

// 별이 글자 쪽에서 빠지는 정도(1 그림, 0 뺌) — 같은 넓은 경사에서. 글자 자리 위(경사 ≥ 0.9)는 0.
static float textKeep(constant SkyU& u, float2 pt) { return saturate(1.0 - textLean(u, pt, true) / 0.9); }

// 글자 자리까지 거리(pt, 안쪽은 음수) — 입자 하나하나가 글자에 닿기 전에 옅어지게. 하늘 전체를 바꾸는 데엔 쓰지 않는다.
static float textDistance(constant SkyU& u, float2 pt) {
    float m = 1e4;
    int n = int(u.parallax.z);
    for (int i = 0; i < n; i++) {
        float4 r = u.text[i];
        float2 d = max(r.xy - pt, pt - r.zw);
        m = min(m, length(max(d, 0.0)) + min(max(d.x, d.y), 0.0));
    }
    return m;
}

// MARK: - 3D 구름 노이즈 굽기 (한 번만)

static float3 hash33(float3 p) {
    uint3 q = uint3(int3(p)) * uint3(1597334673u, 3812015801u, 2798796415u);
    q = (q.x ^ q.y ^ q.z) * uint3(1597334673u, 3812015801u, 2798796415u);
    return float3(q) * (1.0 / 4294967295.0);
}

static float gradCorner(float3 i, float3 f, float3 c, float period) {
    float3 g = hash33(fmod(i + c, period)) * 2.0 - 1.0;
    return dot(g, f - c);
}

static float tilePerlin(float3 x, float period) {
    float3 i = floor(x), f = fract(x);
    float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float n000 = gradCorner(i, f, float3(0, 0, 0), period), n100 = gradCorner(i, f, float3(1, 0, 0), period);
    float n010 = gradCorner(i, f, float3(0, 1, 0), period), n110 = gradCorner(i, f, float3(1, 1, 0), period);
    float n001 = gradCorner(i, f, float3(0, 0, 1), period), n101 = gradCorner(i, f, float3(1, 0, 1), period);
    float n011 = gradCorner(i, f, float3(0, 1, 1), period), n111 = gradCorner(i, f, float3(1, 1, 1), period);
    return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
               mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

static float tileWorley(float3 x, float period) {
    float3 i = floor(x), f = fract(x);
    float md = 1.0;
    for (int z = -1; z <= 1; z++)
        for (int y = -1; y <= 1; y++)
            for (int k = -1; k <= 1; k++) {
                float3 o = float3(k, y, z);
                float3 cell = fmod(i + o + period, period);
                float3 d = o + hash33(cell) - f;
                md = min(md, dot(d, d));
            }
    return 1.0 - saturate(sqrt(md));
}

static float worleyFbm(float3 p, float f) {
    return tileWorley(p * f, f) * 0.625 + tileWorley(p * f * 2.0, f * 2.0) * 0.25 + tileWorley(p * f * 4.0, f * 4.0) * 0.125;
}

kernel void skyBakeNoise(texture3d<float, access::write> out [[texture(0)]], constant uint& z0 [[buffer(0)]],
                         uint3 tid [[thread_position_in_grid]]) {
    uint3 gid = uint3(tid.xy, tid.z + z0);
    uint n = out.get_width();
    if (gid.x >= n || gid.y >= n || gid.z >= n) return;
    float3 p = (float3(gid) + 0.5) / float(n);
    float perlin = 0.0, amp = 0.5, fr = 4.0;
    for (int o = 0; o < 5; o++) {
        perlin += amp * tilePerlin(p * fr, fr);
        amp *= 0.5;
        fr *= 2.0;
    }
    perlin = saturate(perlin * 1.1 + 0.5);
    float w4 = worleyFbm(p, 4.0);
    float pw = remap(perlin, 0.0, 1.0, w4, 1.0);
    out.write(float4(saturate(pw), w4, worleyFbm(p, 8.0), worleyFbm(p, 16.0)), gid);
}

// MARK: - 하늘색

static float moonLitFraction(constant SkyU& u) {
    return 0.5 - 0.5 * cos(u.moon.x * (2.0 * M_PI_F / 29.530589));
}

// 카드는 같은 하늘을 창으로 잘라 본다 — anchor 0 위쪽, 1 아래쪽(지평선).
static float skyY(constant SkyU& u, float2 pt, float anchor) {
    float S = max(u.view.y, 640.0);
    return saturate((pt.y + (S - u.view.y) * anchor) / S);
}

static float3 grad3(float3 top, float3 mid, float3 bot, float m, float y) {
    return y < m ? mix(lin(top), lin(mid), smoothstep(0.0, m, y)) : mix(lin(mid), lin(bot), smoothstep(m, 1.0, y));
}

static float3 skyColor(int scene, float2 uv, float2 pt, constant SkyU& u) {
    float y = saturate(uv.y);
    float d = distance(pt, u.light.xy) / WORLD;
    float shade = 1.0 - 0.85 * u.tone.y * textLean(u, pt, true);
    if (nightScene(scene)) {
        float k = pow(moonLitFraction(u), 1.5);
        float3 c;
        if (scene == S_CLOUDY) {
            c = mix(lin(float3(0.06, 0.07, 0.15)), lin(float3(0.17, 0.205, 0.33)), smoothstep(-0.1, 1.1, y));
        } else {
            c = mix(lin(float3(0.03, 0.035, 0.11)), lin(float3(0.115, 0.12, 0.215)), smoothstep(0.0, 0.5, y));
            c = mix(c, lin(float3(0.18, 0.25, 0.41)), smoothstep(0.4, 1.05, y));
        }
        c += lin(float3(0.62, 0.66, 0.85)) * (0.10 * exp(-d * 2.2) + 0.03 * exp(-d * 0.6)) * shade * (0.15 + 0.85 * k);
        return c;
    }
    switch (scene) {
    case S_DAY: {
        // 카드는 같은 하늘의 위쪽만 — 짧은 카드 아래가 밝은 지평선 색이 되면 글자가 묻힌다.
        y = skyY(u, pt, 0.0);
        float3 c = mix(lin(float3(0.25, 0.46, 0.73)), lin(float3(0.27, 0.48, 0.72)), smoothstep(0.0, 0.5, y));
        return mix(c, lin(float3(0.5, 0.66, 0.84)), smoothstep(0.55, 1.1, y));
    }
    case S_DAWN:
        return grad3(float3(0.07, 0.075, 0.2), float3(0.27, 0.22, 0.4), float3(0.78, 0.5, 0.52), 0.6, skyY(u, pt, 0.55));
    case S_DUSK:
        return grad3(float3(0.13, 0.11, 0.25), float3(0.42, 0.23, 0.36), float3(0.93, 0.5, 0.27), 0.58, skyY(u, pt, 0.55));
    case S_FROST:
        y = skyY(u, pt, 0.35);
        return mix(mix(lin(float3(0.13, 0.25, 0.47)), lin(float3(0.24, 0.39, 0.6)), smoothstep(0.0, 0.5, y)),
                   lin(float3(0.7, 0.79, 0.88)), smoothstep(0.5, 1.1, y));
    case S_PETALS:
        y = skyY(u, pt, 0.0);
        return mix(lin(float3(0.27, 0.46, 0.74)), lin(float3(0.82, 0.8, 0.88)), smoothstep(0.5, 1.2, y));
    case S_LEAVES:
        y = skyY(u, pt, 0.2);
        return grad3(float3(0.27, 0.38, 0.55), float3(0.56, 0.49, 0.45), float3(0.94, 0.71, 0.44), 0.6, y);
    case S_WIND:
        y = skyY(u, pt, 0.0);
        return mix(lin(float3(0.27, 0.41, 0.58)), lin(float3(0.6, 0.68, 0.77)), smoothstep(0.35, 1.15, y));
    case S_SNOW:
        return mix(lin(float3(0.27, 0.31, 0.39)), lin(float3(0.45, 0.49, 0.56)), smoothstep(-0.1, 1.1, y));
    case S_FOG:
        y = skyY(u, pt, 0.0);
        return mix(lin(float3(0.35, 0.39, 0.43)), lin(float3(0.74, 0.76, 0.78)), smoothstep(0.3, 1.1, y));
    case S_DRIZZLE:
        return mix(lin(float3(0.16, 0.19, 0.22)), lin(float3(0.25, 0.28, 0.31)), y);
    default:
        return mix(lin(float3(0.14, 0.165, 0.195)), lin(float3(0.22, 0.255, 0.285)), y);
    }
}

// MARK: - 부피 구름 (레이마칭)

struct Layer {
    float2 scale;     // 월드 → 노이즈 xy
    float zscale;     // 층 깊이 → 노이즈 z
    float2 drift;     // 노이즈 단위/초
    float evolve;     // z 로 흘러 모양이 바뀜
    float coverage;
    float extinct;    // 월드 단위당
    float detail;
    float3 sun;       // 직사광 색·세기
    float3 ambLo, ambHi;
    float lightZ;     // 광원이 층 뒤로 얼마나 깊이(층 두께 배수)
    float g;          // 앞쪽 산란 비대칭
    float haze;
    float depth;      // 시차 배수
    float2 offset;
    float ybias;      // 화면 아래로 갈수록 덮임을 더한다(안개)
    int kind;         // 덮임 지도 — 0 넓은 층 · 1 뭉게구름 무리 · 2 길게 늘어진 층운
};

static Layer layerFor(int scene, int idx) {
    Layer L;
    L.offset = float2(0.0);
    L.ybias = 0.0;
    L.kind = 0;
    if (scene == 0) {
        if (idx == 0) {   // 먼 층 — 작고 느리고 하늘색에 묻힘
            L.scale = float2(0.55, 0.9); L.zscale = 0.35; L.drift = float2(0.0035, 0.0); L.evolve = 0.0015;
            L.coverage = 0.48; L.extinct = 9.0; L.detail = 0.35;
            L.sun = lin(float3(0.80, 0.84, 1.0)) * 0.07; L.ambLo = lin(float3(0.10, 0.11, 0.19)); L.ambHi = lin(float3(0.24, 0.25, 0.38));
            L.lightZ = 2.5; L.g = 0.55; L.haze = 0.45; L.depth = 0.3; L.offset = float2(0.37, 0.11);
        } else {          // 가까운 층 — 크고 빠름
            L.scale = float2(0.32, 0.55); L.zscale = 0.3; L.drift = float2(0.0075, 0.0005); L.evolve = 0.002;
            L.coverage = 0.56; L.extinct = 16.0; L.detail = 0.7;
            L.sun = lin(float3(0.80, 0.84, 1.0)) * 0.11; L.ambLo = lin(float3(0.09, 0.095, 0.16)); L.ambHi = lin(float3(0.36, 0.37, 0.50));
            L.lightZ = 2.0; L.g = 0.6; L.haze = 0.12; L.depth = 1.0;
        }
    } else if (scene == 1) {   // 흩어진 작은 뭉게구름 몇 개(새털구름은 합성에서)
        L.kind = 1;
        L.scale = float2(0.85, 1.0); L.zscale = 0.3; L.drift = float2(0.0051, 0.0); L.evolve = 0.0015;
        L.coverage = idx == 1 ? 0.12 : 0.0; L.extinct = 14.0; L.detail = 0.65;
        L.sun = lin(float3(1.0, 0.98, 0.95)) * 0.42; L.ambLo = lin(float3(0.5, 0.6, 0.76)); L.ambHi = lin(float3(0.84, 0.88, 0.95));
        L.lightZ = 1.4; L.g = 0.6; L.haze = 0.25; L.depth = 1.0; L.ybias = -0.3; L.offset = float2(0.63, 0.29);
    } else if (scene == 3) {   // 맑은 밤 — 구름 없음
        L.scale = float2(0.5); L.zscale = 0.3; L.drift = float2(0.0); L.evolve = 0.0;
        L.coverage = 0.0; L.extinct = 1.0; L.detail = 0.0;
        L.sun = float3(0.0); L.ambLo = float3(0.0); L.ambHi = float3(0.0);
        L.lightZ = 1.0; L.g = 0.0; L.haze = 0.0; L.depth = 0.0;
    } else if (scene == S_FROST) {   // 아주 맑음
        L.scale = float2(0.5); L.zscale = 0.3; L.drift = float2(0.0); L.evolve = 0.0;
        L.coverage = 0.0; L.extinct = 1.0; L.detail = 0.0;
        L.sun = float3(0.0); L.ambLo = float3(0.0); L.ambHi = float3(0.0);
        L.lightZ = 1.0; L.g = 0.0; L.haze = 0.0; L.depth = 0.0;
    } else if (scene == S_DAWN || scene == S_DUSK) {
        bool dusk = scene == S_DUSK;
        L.kind = 2;
        if (idx == 0) {   // 먼 층 — 옆으로 긴 층구름
            L.scale = float2(0.2, 1.3); L.zscale = 0.25; L.drift = float2(0.0023, 0.0); L.evolve = 0.0012;
            L.coverage = dusk ? 0.46 : 0.36; L.extinct = 7.0; L.detail = 0.3;
            L.sun = (dusk ? lin(float3(1.0, 0.45, 0.28)) : lin(float3(1.0, 0.62, 0.62))) * 0.3;
            L.ambLo = dusk ? lin(float3(0.2, 0.11, 0.2)) : lin(float3(0.12, 0.11, 0.24));
            L.ambHi = dusk ? lin(float3(0.46, 0.25, 0.34)) : lin(float3(0.34, 0.27, 0.42));
            L.lightZ = 1.6; L.g = 0.6; L.haze = 0.4; L.depth = 0.3; L.offset = float2(0.41, 0.27); L.ybias = -0.45;
        } else {
            L.ybias = -0.6;
            L.scale = float2(0.3, 1.1); L.zscale = 0.3; L.drift = float2(0.005, 0.0); L.evolve = 0.0018;
            L.coverage = dusk ? 0.44 : 0.3; L.extinct = 12.0; L.detail = 0.65;
            L.sun = (dusk ? lin(float3(1.0, 0.5, 0.24)) : lin(float3(1.0, 0.64, 0.58))) * (dusk ? 0.55 : 0.38);
            L.ambLo = dusk ? lin(float3(0.15, 0.08, 0.15)) : lin(float3(0.11, 0.1, 0.21));
            L.ambHi = dusk ? lin(float3(0.5, 0.27, 0.34)) : lin(float3(0.4, 0.31, 0.46));
            L.lightZ = 1.3; L.g = 0.65; L.haze = 0.1; L.depth = 1.0;
        }
    } else if (scene == S_PETALS || scene == S_LEAVES) {   // 듬성한 뭉게구름 무리
        bool fall = scene == S_LEAVES;
        L.kind = 1;
        L.scale = float2(0.85, 1.0); L.zscale = 0.3; L.drift = float2(0.0128, 0.0); L.evolve = 0.0015;
        L.coverage = idx == 1 ? 0.36 : 0.0; L.extinct = 14.0; L.detail = 0.65; L.offset = float2(0.17, 0.83);
        L.sun = (fall ? lin(float3(1.0, 0.86, 0.62)) : lin(float3(1.0, 0.97, 0.94))) * 0.42;
        L.ambLo = fall ? lin(float3(0.62, 0.56, 0.54)) : lin(float3(0.64, 0.7, 0.84));
        L.ambHi = fall ? lin(float3(0.88, 0.8, 0.7)) : lin(float3(0.88, 0.89, 0.95));
        L.lightZ = 1.5; L.g = 0.6; L.haze = 0.2; L.depth = 1.0; L.ybias = -0.35;
    } else if (scene == S_WIND) {   // 빠르게 흐르는 구름
        if (idx == 0) {
            L.scale = float2(0.3, 1.0); L.zscale = 0.3; L.drift = float2(0.019, 0.0); L.evolve = 0.01;
            L.coverage = 0.42; L.extinct = 8.0; L.detail = 0.35;
            L.sun = lin(float3(1.0, 0.97, 0.93)) * 0.3; L.ambLo = lin(float3(0.48, 0.57, 0.69)); L.ambHi = lin(float3(0.7, 0.76, 0.85));
            L.lightZ = 1.6; L.g = 0.55; L.haze = 0.45; L.depth = 0.3; L.offset = float2(0.29, 0.71);
        } else {
            L.scale = float2(0.17, 0.62); L.zscale = 0.3; L.drift = float2(0.036, 0.002); L.evolve = 0.02;
            L.coverage = 0.42; L.extinct = 11.0; L.detail = 0.7;
            L.sun = lin(float3(1.0, 0.97, 0.92)) * 0.45; L.ambLo = lin(float3(0.44, 0.52, 0.63)); L.ambHi = lin(float3(0.76, 0.8, 0.87));
            L.lightZ = 1.5; L.g = 0.6; L.haze = 0.1; L.depth = 1.0;
        }
    } else if (scene == S_SNOW) {   // 눈구름 — 푸른 회색
        if (idx == 0) {
            L.scale = float2(0.5, 0.8); L.zscale = 0.3; L.drift = float2(0.004, 0.0); L.evolve = 0.002;
            L.coverage = 0.82; L.extinct = 7.0; L.detail = 0.3;
            L.sun = lin(float3(0.85, 0.88, 0.95)) * 0.2; L.ambLo = lin(float3(0.27, 0.3, 0.37)); L.ambHi = lin(float3(0.5, 0.53, 0.6));
            L.lightZ = 3.0; L.g = 0.2; L.haze = 0.5; L.depth = 0.3; L.offset = float2(0.13, 0.52);
        } else {
            L.scale = float2(0.34, 0.65); L.zscale = 0.35; L.drift = float2(0.006, 0.0); L.evolve = 0.002;
            L.coverage = 0.45; L.extinct = 10.0; L.detail = 0.45;
            L.sun = lin(float3(0.85, 0.88, 0.95)) * 0.25; L.ambLo = lin(float3(0.2, 0.23, 0.29)); L.ambHi = lin(float3(0.5, 0.53, 0.6));
            L.lightZ = 3.0; L.g = 0.2; L.haze = 0.1; L.depth = 1.0;
        }
    } else if (scene == S_FOG) {   // 낮게 깔린 안개 구름 — 아래로 갈수록 덮인다
        L.scale = idx == 1 ? float2(0.24, 0.9) : float2(0.4, 1.3); L.zscale = 0.25;
        L.drift = idx == 1 ? float2(0.0035, 0.0) : float2(0.002, 0.0); L.evolve = 0.0015;
        L.coverage = idx == 1 ? 0.5 : 0.6; L.extinct = idx == 1 ? 4.5 : 3.5; L.detail = 0.3;
        L.sun = lin(float3(0.95, 0.95, 0.93)) * 0.15; L.ambLo = lin(float3(0.44, 0.47, 0.5)); L.ambHi = lin(float3(0.74, 0.76, 0.78));
        L.lightZ = 2.0; L.g = 0.3; L.haze = 0.55; L.depth = idx == 1 ? 1.0 : 0.3; L.ybias = 0.9;
    } else if (scene == S_DRIZZLE) {   // 낮게 덮인 옅은 회색
        if (idx == 0) {
            L.scale = float2(0.5, 0.8); L.zscale = 0.3; L.drift = float2(0.005, 0.0); L.evolve = 0.0025;
            L.coverage = 0.85; L.extinct = 7.0; L.detail = 0.3;
            L.sun = lin(float3(0.75, 0.8, 0.85)) * 0.18; L.ambLo = lin(float3(0.17, 0.2, 0.23)); L.ambHi = lin(float3(0.36, 0.4, 0.43));
            L.lightZ = 3.0; L.g = 0.2; L.haze = 0.55; L.depth = 0.3; L.offset = float2(0.47, 0.19);
        } else {
            L.scale = float2(0.36, 0.7); L.zscale = 0.35; L.drift = float2(0.009, 0.0); L.evolve = 0.003;
            L.coverage = 0.5; L.extinct = 12.0; L.detail = 0.45;
            L.sun = lin(float3(0.7, 0.75, 0.8)) * 0.22; L.ambLo = lin(float3(0.09, 0.105, 0.12)); L.ambHi = lin(float3(0.3, 0.33, 0.36));
            L.lightZ = 3.0; L.g = 0.2; L.haze = 0.1; L.depth = 1.0;
        }
    } else {
        if (idx == 0) {   // 먼 층 — 거의 덮인 회색
            L.scale = float2(0.5, 0.8); L.zscale = 0.3; L.drift = float2(0.006, 0.0); L.evolve = 0.003;
            L.coverage = 0.8; L.extinct = 8.0; L.detail = 0.3;
            L.sun = lin(float3(0.75, 0.80, 0.85)) * 0.2; L.ambLo = lin(float3(0.16, 0.185, 0.21)); L.ambHi = lin(float3(0.36, 0.40, 0.44));
            L.lightZ = 3.0; L.g = 0.2; L.haze = 0.5; L.depth = 0.3; L.offset = float2(0.21, 0.63);
        } else {          // 낮고 무거운 비구름
            L.scale = float2(0.36, 0.7); L.zscale = 0.35; L.drift = float2(0.014, 0.0); L.evolve = 0.004;
            L.coverage = 0.62; L.extinct = 18.0; L.detail = 0.45;
            L.sun = lin(float3(0.70, 0.75, 0.80)) * 0.25; L.ambLo = lin(float3(0.075, 0.085, 0.10)); L.ambHi = lin(float3(0.30, 0.335, 0.37));
            L.lightZ = 3.0; L.g = 0.2; L.haze = 0.1; L.depth = 1.0;
        }
    }
    return L;
}

// 구운 노이즈는 분포가 좁다(R 5~95% ≈ 0.57~0.88, GBA ≈ 0.27~0.68) — 문턱은 이 분위수에 맞춘 값이다.
static float density(texture3d<float> nz, float3 p, float z, Layer L, float cov, bool detail) {
    constexpr sampler s(filter::linear, address::repeat);
    float4 n = nz.sample(s, p);
    float base = saturate(remap(n.r, 0.6, 0.9, 0.0, 1.0));
    float wf = saturate(remap(n.g * 0.625 + n.b * 0.25 + n.a * 0.125, 0.32, 0.64, 0.0, 1.0));
    base = saturate(remap(base, (1.0 - wf) * 0.4, 1.0, 0.0, 1.0));
    base *= smoothstep(0.0, 0.3, z) * smoothstep(1.0, 0.55, z);
    // 덮임이 옅은 곳은 문턱이 가팔라져 덮임 등고선을 따라 구름이 잘린다 — 옅은 만큼 묽게.
    float d = saturate(remap(base, 1.0 - cov, 1.0, 0.0, 1.0)) * smoothstep(0.0, 0.3, cov);
    if (detail && d > 0.0 && d < 0.7) {
        float4 m = nz.sample(s, p * float3(5.5, 4.2, 3.1) + float3(0.31, 0.17, 0.53));
        float df = saturate(remap(m.g * 0.625 + m.b * 0.25 + m.a * 0.125, 0.32, 0.64, 0.0, 1.0));
        // 진한 속으로 갈수록 덜 깎는다 — 0.7 에서 끊기면 구름이 칼로 자른 듯 잘린다.
        d = mix(saturate(remap(d, df * L.detail, 1.0, 0.0, 1.0)), d, smoothstep(0.3, 0.7, d));
    }
    return d;
}

static float hg(float c, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5) * 0.0795775;
}

// 덮임 지도 — 구름이 통째로 흐르게 노이즈와 같은 세계 좌표(wf)로 잰다.
static float coverageAt(Layer L, float2 wf, float yfrac) {
    float c;
    if (L.kind == 1) {
        float cluster = fbm2(wf * 0.55 + L.offset * 7.0, 3);
        float cell = fbm2(wf * 1.7 + L.offset * 3.0 + 5.3, 3);
        c = L.coverage + (cluster - 0.5) * 1.0 + (cell - 0.5) * 1.0;
    } else if (L.kind == 2) {
        float band = fbm2(float2(wf.x * 0.3, wf.y * 2.6) + L.offset * 7.0, 3);
        float brk = fbm2(wf * float2(1.1, 3.0) + L.offset * 3.0 + 2.1, 2);
        c = L.coverage + (band - 0.5) * 1.6 + (brk - 0.5) * 0.6;
    } else {
        c = L.coverage + (fbm2(wf * 0.8 + L.offset * 7.0, 3) - 0.5) * 1.1;
    }
    return saturate(c + L.ybias * (yfrac - 0.5));
}

// td 흐름 시각, te 모양 바뀜 시각 — 실시간은 둘이 같고, 굽기는 흐름 없이 모양만.
static float4 marchLayer(texture3d<float> nz, Layer L, float2 world, float2 lightWorld, float td, float te, float2 tilt,
                         int steps, int lsteps, bool detail, float jitter, float shade, float yfrac = 0.5, float clear = 0.0) {
    if (L.coverage <= 0.0 || steps <= 0) return float4(0, 0, 0, 1);
    L.sun *= shade;
    float2 w = world + tilt * L.depth;
    float2 move = L.drift / L.scale * td;
    float2 base = (w + move) * L.scale + L.offset;
    float cov = coverageAt(L, w + move, yfrac);
    float t = te;
    cov -= clear * (0.12 + 0.55 * cov);
    L.extinct *= 1.0 - 0.45 * clear;
    float dt = 1.0 / float(steps);
    float T = 1.0;
    float3 S = float3(0.0);
    for (int i = 0; i < steps; i++) {
        float z = (float(i) + jitter) * dt;
        float3 p = float3(base, z * L.zscale + L.evolve * t);
        float d = density(nz, p, z, L, cov, detail);
        if (d <= 0.002) continue;
        float sig = d * L.extinct;
        float3 toLight = float3(lightWorld - w, (L.lightZ - z) * SLAB);
        float3 ld = normalize(toLight);
        float ls = SLAB * 0.9 / float(max(lsteps, 1));
        float od = 0.0;
        for (int j = 1; j <= lsteps; j++) {
            float3 q = float3(w, z * SLAB) + ld * (ls * (float(j) - 0.5));
            float zz = q.z / SLAB;
            if (zz > 1.0) break;
            float3 qp = float3((q.xy + move) * L.scale + L.offset, zz * L.zscale + L.evolve * t);
            od += density(nz, qp, zz, L, cov, false) * L.extinct * ls;
        }
        float beer = max(exp(-od), exp(-od * 0.25) * 0.35);
        float powder = 1.0 - exp(-od * 2.0 - 0.1);
        float c = ld.z;
        float phase = mix(hg(c, L.g), hg(c, -0.25), 0.3);
        float3 Ls = L.sun * beer * mix(1.0, powder, 0.35) * phase * 12.566;
        float3 amb = mix(L.ambLo, L.ambHi, z) * (1.0 - 0.5 * d);
        float Tr = exp(-sig * dt * SLAB);
        S += T * (Ls + amb) * (1.0 - Tr);
        T *= Tr;
        if (T < 0.01) break;
    }
    return float4(S, T);
}

// 색(앞곱한 산란광)과 투과율을 따로 — MetalFX 업스케일러는 알파를 지키지 않는다.
struct CloudOut {
    float4 color [[color(0)]];
    float trans [[color(1)]];
};

// 구름 한 점(앞곱한 색, 투과율). 세계 좌표는 pt + 창(win.xy) — 카드는 큰 하늘의 한 조각을 본다.
static float4 cloudCore(constant SkyU& u, texture3d<float> nz, float2 uv, float2 pt, float jitter, float td, float te) {
    int scene = int(u.view.w);
    float2 world = (pt + u.win.xy) / WORLD;
    // 굽기는 판 어디서나 같은 방향의 빛(light.xy = 빛 쪽 pt 벡터) — 카드마다 창이 달라도 고르게 밝다.
    float2 lw = u.win.w > 1.5 ? world + u.light.xy / WORLD : (u.light.xy + u.win.xy) / WORLD;
    float2 tilt = u.parallax.xy / WORLD;
    int steps = int(u.quality.x), lsteps = int(u.quality.y), farSteps = int(u.quality.w);
    bool detail = u.quality.z > 0.5;
    float3 sky = skyColor(scene, uv, pt, u);
    float shade = 1.0 - 0.8 * u.tone.y * textLean(u, pt, true);
    float clear = u.extra.x * textLean(u, pt);
    float yfrac = uv.y;
    float4 nearL = marchLayer(nz, layerFor(scene, 1), world, lw, td, te, tilt, steps, lsteps, detail, jitter, shade, yfrac, clear);
    float4 farL = float4(0, 0, 0, 1);
    if (nearL.a > 0.02) {
        farL = marchLayer(nz, layerFor(scene, 0), world, lw, td, te, tilt, farSteps, max(lsteps - 1, 1), false, jitter, shade, yfrac, clear);
        farL.rgb = mix(farL.rgb, sky * (1.0 - farL.a), layerFor(scene, 0).haze);
    }
    return float4(nearL.rgb + nearL.a * farL.rgb, nearL.a * farL.a);
}

fragment CloudOut skyClouds(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                            texture3d<float> nz [[texture(0)]]) {
    float2 pt = in.uv * u.view.xy;
    float4 c = cloudCore(u, nz, in.uv, pt, ign(in.pos.xy), u.view.z, u.view.z);
    CloudOut o;
    o.color = float4(c.rgb, 1.0);
    o.trans = c.a;
    return o;
}

// 구운 판 — 세계 한 조각을 흐름 없이(모양 시각 view.z) 한 번 그린다. 오른쪽 끝은 왼쪽 끝으로 이어지게 섞어 가로로 끝없이 돈다.
// 걸음 사이 떨림은 같은 픽셀을 rays.z 번(단계별) 엇갈려 찍어 평균(구운 판에 떨림 무늬가 덜 남게).
fragment float4 skyCloudBake(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                             texture3d<float> nz [[texture(0)]]) {
    float2 pt = in.uv * u.view.xy;
    float W = u.view.x, margin = W * 0.22;
    float a = smoothstep(W - margin, W, pt.x);
    int taps = clamp(int(u.rays.z), 1, 4);
    float4 acc = float4(0.0);
    for (int k = 0; k < taps; k++) {
        float j = fract(ign(in.pos.xy) + float(k) / float(taps));
        float4 c = cloudCore(u, nz, in.uv, pt, j, 0.0, u.view.z);
        if (a > 0.001) c = mix(c, cloudCore(u, nz, in.uv, pt - float2(W, 0.0), j, 0.0, u.view.z), a);
        acc += c;
    }
    return acc / float(taps);
}

// MARK: - 별

static float3 starField(constant SkyU& u, float2 pt, float t, float pxPerPt, float2 tilt, int layers) {
    float3 acc = float3(0.0);
    float px = 1.0 / pxPerPt;
    for (int l = 3 - layers; l < 3; l++) {
        float fl = float(l);
        float cell = l == 0 ? 15.0 : (l == 1 ? 31.0 : 71.0);
        float prob = l == 0 ? 0.1 : (l == 1 ? 0.5 : 0.6);
        float speed = 1.15 + 0.15 * fl;
        float2 p = pt + tilt * (0.15 + 0.35 * fl) + float2(t * speed, 0.0);
        float dens = smoothstep(0.3, 0.72, fbm2(p / 190.0 + 3.7, 2));
        float2 cid = floor(p / cell);
        float pick = hash12(cid * 1.7 + 31.0 * fl);
        if (pick > prob * (0.2 + 1.6 * dens)) continue;
        float2 h = hash22(cid + 17.0 * fl);
        float2 dv = p - (cid + 0.12 + 0.76 * h) * cell;
        // 글자 쪽 별은 흐리게가 아니라 통째로 뺀다 — 넓은 경사를 따라 드문드문 줄어 상자 모양이 남지 않는다.
        if (textKeep(u, pt - dv) < 0.05 + 0.9 * hash12(cid + 7.7 + fl)) continue;
        float rk = hash12(cid + 5.3 + 11.0 * fl);
        float mag = l == 0 ? 0.14 + 0.25 * rk : (l == 1 ? 0.4 + 1.4 * rk * rk * rk : 1.3 + 5.5 * pow(rk, 4.0));
        float sig = 0.38 + 0.4 * sqrt(mag);
        // 화면 픽셀보다 작게 그리면 흐를 때 픽셀 사이에서 깜빡인다 — 0.6px 아래로는 넓히고 그만큼 어둡게.
        float sg = max(sig, 0.6 * px);
        float r2 = dot(dv, dv);
        // 밝은 별은 더 밝게가 아니라 더 크게 — 1 을 넘기면 블룸이 별 둘레에 흐린 얼룩을 만든다.
        float core = min(mag, 0.95) * (sig * sig) / (sg * sg) * exp(-r2 / (sg * sg));
        if (mag > 0.9) core += min(mag, 3.0) * 0.04 * exp(-r2 / (sig * sig * 6.0));
        float ph = hash12(cid + 9.1 + 3.0 * fl);
        float x = t / (5.0 + 5.0 * ph) + ph * 37.0;
        float n = 0.55 * tnoise(x) + 0.3 * tnoise(x * 1.93 + 11.0) + 0.15 * tnoise(x * 3.7 + 5.0);
        float depth = l == 0 ? 0.7 : (l == 1 ? mix(0.6, 0.35, rk) : mix(0.35, 0.12, saturate(mag / 3.0)));
        float tw = 1.0 - depth * smoothstep(0.3, 0.75, n);
        float hk = hash12(cid + 2.2 + fl);
        float3 tint = hk < 0.5 ? float3(1.0) : (hk < 0.75 ? float3(0.8, 0.88, 1.0)
                    : (hk < 0.88 ? float3(1.0, 0.92, 0.8) : float3(1.0, 0.86, 0.9)));
        acc += core * mix(float3(1.0), tint, 0.3) * tw;
    }
    return acc;
}

// MARK: - 별똥별

static float3 meteorLight(float2 pt, constant SkyU& u, float pxPerPt) {
    float a = u.meteor1.y;
    if (a <= 0.0) return float3(0.0);
    float2 d = pt - u.meteor0.xy;
    float2 dir = u.meteor0.zw;
    float L = u.meteor1.x;
    float behind = -dot(d, dir);
    if (behind < -6.0 || behind > L + 6.0) return float3(0.0);
    float across = abs(d.x * dir.y - d.y * dir.x);
    float w = max(u.meteor1.z, 0.75 / pxPerPt);
    float k = saturate(1.0 - behind / L);
    float wt = w * (0.55 + 0.45 * k);
    float tail = behind > 0.0 ? exp(-across * across / (wt * wt)) * k * k * k : 0.0;
    float r2 = dot(d, d);
    float head = exp(-r2 / (w * w * 2.2)) * 2.4 + exp(-r2 / (w * w * 40.0)) * 0.12;
    return lin(float3(0.90, 0.94, 1.0)) * (tail * 1.5 + head) * a * (u.meteor1.z / w);
}

// MARK: - 달 (구 + NASA LRO 앞면 지도 + Lommel–Seeliger + 지구조)

static float3 moonLight(float2 q, float edgePx, constant SkyU& u, texture2d<float> tex, thread float& cover) {
    float rr = length(q);
    cover = 1.0 - smoothstep(1.0 - 1.2 / edgePx, 1.0, rr);
    if (cover <= 0.0) return float3(0.0);
    float2 qq = q * min(1.0, 0.999 / max(rr, 1e-4));
    float3 N = float3(qq.x, -qq.y, sqrt(saturate(1.0 - dot(qq, qq))));
    float v;
    if (u.moon.w > 0.5) {
        constexpr sampler ms(filter::linear, mip_filter::linear, address::clamp_to_edge);
        float2 tuv = float2(0.5 + atan2(N.x, N.z) / M_PI_F, 0.5 - asin(clamp(N.y, -1.0, 1.0)) / M_PI_F);
        // 지도 바깥 가장자리는 극으로 갈수록 늘어나 흐려진다 — 한 단계 굵은 밉으로 고르게.
        v = tex.sample(ms, tuv, bias(0.5)).r;
    } else {
        float maria = fbm2(qq * 2.3 + 4.0, 4);
        v = 0.7 - 0.32 * smoothstep(0.45, 0.75, maria) + 0.06 * (vnoise(qq * 18.0) - 0.5);
    }
    v = mix(v, 0.66, smoothstep(0.78, 0.97, abs(N.y)));
    float albedo = 0.12 + 1.1 * pow(v, 1.5);
    float theta = u.moon.x * (2.0 * M_PI_F / 29.530589);
    float ct = cos(u.moon.y), st = sin(u.moon.y);
    float3 L = float3(sin(theta) * ct, sin(theta) * st, -cos(theta));
    float mu0 = dot(N, L), mu = N.z;
    float ls = mu0 > 0.0 ? 2.0 * mu0 / (mu0 + mu + 1e-3) : 0.0;
    float lit = pow(min(ls, 1.35), 0.65) * smoothstep(-0.015, 0.06, mu0);
    albedo = pow(albedo, 1.0 + 1.4 * (1.0 - smoothstep(0.0, 0.35, mu0)));
    float k = 0.5 - 0.5 * cos(theta);
    float3 warm = lin(float3(1.0, 0.95, 0.86));
    float3 day = warm * albedo * lit * mix(0.8, 1.0, k) * 0.95 * max(1.0, u.tone.x * 0.6);
    float es = u.moon.z * pow(0.5 + 0.5 * cos(theta), 2.0);
    float3 earth = lin(float3(0.42, 0.52, 0.72)) * albedo * es * (0.4 + 0.6 * mu) * (1.0 - smoothstep(0.0, 0.12, mu0)) * 0.035;
    return day + earth;
}

// MARK: - 하늘 합성 (전체 해상도)

static float4 cloudTaps(texture2d<float> col, texture2d<float> tr, float2 uv) {
    constexpr sampler cs(filter::linear, address::clamp_to_edge);
    float2 ct = 0.6 / float2(tr.get_width(), tr.get_height());
    float2 cc = 0.6 / float2(col.get_width(), col.get_height());
    float3 s = (col.sample(cs, uv + cc * float2(-1, -1)).rgb + col.sample(cs, uv + cc * float2(1, -1)).rgb
              + col.sample(cs, uv + cc * float2(-1, 1)).rgb + col.sample(cs, uv + cc * float2(1, 1)).rgb) * 0.25;
    float T = (tr.sample(cs, uv + ct * float2(-1, -1)).r + tr.sample(cs, uv + ct * float2(1, -1)).r
             + tr.sample(cs, uv + ct * float2(-1, 1)).r + tr.sample(cs, uv + ct * float2(1, 1)).r) * 0.25;
    return float4(s, T);
}

// 구운 판 읽기 — 판 안 자리(win.xy, 흐름은 이미 더해 옴)에서 가로로 끝없이. 아주 약하게 일렁인다.
static float4 bakedAt(constant SkyU& u, texture2d<float> A, texture2d<float> B, float2 pt) {
    // 다 구워지기 전(불투명도 0)엔 판을 읽지 않는다 — 덜 구운 판엔 쓰레기 값(NaN)이 있을 수 있다.
    if (u.win.z <= 0.0) return float4(0.0, 0.0, 0.0, 1.0);
    constexpr sampler rs(filter::linear, s_address::repeat, t_address::clamp_to_edge);
    float t = u.view.z;
    float2 bp = pt + u.win.xy;
    bp += float2(sin(bp.y * 0.031 + t * 0.09), sin(bp.x * 0.023 + t * 0.07)) * 1.6;
    float2 buv = bp / u.blend.yz;
    float4 c = mix(A.sample(rs, buv), B.sample(rs, buv), u.blend.x);
    // 글자 쪽은 얇은 데를 조금 걷고 나머지는 옅게 — 걷기만 하면 구름 속이 경사의 등고선(세로줄)을 따라 잘린다.
    float a = 1.0 - c.a;
    float m = u.extra.x * textLean(u, pt);
    float e = 0.4 * m;
    float a2 = saturate((a - e) / (1.0 - e)) * (1.0 - 0.9 * m) * u.win.z;
    float shade = 1.0 - 0.8 * u.tone.y * textLean(u, pt, true);
    return float4(c.rgb * (a2 / max(a, 1e-3)) * shade, 1.0 - a2);
}

static float4 cloudsAt(constant SkyU& u, texture2d<float> colA, texture2d<float> trA,
                       texture2d<float> colB, texture2d<float> trB, float2 uv) {
    if (u.win.w > 0.5) return bakedAt(u, colA, colB, uv * u.view.xy);
    float flow = u.blend.w / u.view.x;
    float2 uvA = uv - float2(flow * u.blend.y, 0.0), uvB = uv + float2(flow * u.blend.z, 0.0);
    return mix(cloudTaps(colA, trA, uvA), cloudTaps(colB, trB, uvB), u.blend.x);
}

// 해 — 장면마다 색·세기·번짐. 맑은 낮은 4차 값 그대로(햇무리 띠 포함).
static float3 sunLight(int scene, float2 pt, float d, float r, constant SkyU& u, float3 c) {
    float R = u.sun.x, G = u.sun.y;
    if (scene == S_DAY || scene == S_FROST) {
        bool frost = scene == S_FROST;
        float patch = u.sun.w > 0.5 ? 0.45 + 0.9 * vnoise(pt / (R * 0.35) + 2.3) : 0.9;
        float3 add = float3(0.0);
        if (!frost) c *= 1.0 - 0.12 * smoothstep(R * 1.0, R * 0.55, d) * smoothstep(R * 0.12, R * 0.45, d);
        float x = (d - R) / (R * 0.07);
        float3 ofs = float3(0.0, 0.45, 0.95);
        float3 band = smoothstep(ofs - 0.7, ofs + 0.25, float3(x)) * exp(-max(float3(x) - ofs, 0.0) * float3(0.9, 0.75, 0.55));
        add += band * float3(0.055, 0.048, 0.052) * patch * (frost ? 0.4 : 1.0);
        float glow = 0.6 * exp(-d / (G * 0.04)) + 0.4 * exp(-d / (G * 0.1)) + 0.2 * exp(-d / (G * 0.18))
                   + 0.05 * exp(-d / (G * 0.5));
        // 원판 가장자리를 부드럽게 — 가우시안을 넓히고 심지 세기는 낮춘다.
        float core = exp(-(d * d) / (r * r * 1.8)) * 3.4 + exp(-d / (r * 2.0)) * 1.1;
        float3 tintCore = frost ? lin(float3(1.0, 0.95, 0.86)) : lin(float3(1.0, 0.975, 0.93));
        float3 tintGlow = frost ? lin(float3(0.96, 0.92, 0.9)) : lin(float3(0.93, 0.96, 1.0));
        return c + add + tintCore * core * (frost ? 0.85 : 1.0) + tintGlow * glow * (frost ? 0.7 : 1.0);
    }
    float H = u.view.y, W = u.view.x;
    float2 lp = u.light.xy;
    if (scene == S_DAWN || scene == S_DUSK) {
        bool dusk = scene == S_DUSK;
        // 지평선 띠 — 화면 아래 가장자리를 따라, 해 쪽으로 갈수록 짙다.
        float below = max(H - pt.y, 0.0);
        float side = exp(-pow((pt.x - lp.x) / (W * (dusk ? 0.75 : 0.9)), 2.0));
        float band = exp(-below / (max(H, 400.0) * (dusk ? 0.16 : 0.2))) * (0.35 + 0.65 * side);
        float3 bc = dusk ? lin(float3(1.0, 0.5, 0.22)) : lin(float3(1.0, 0.62, 0.5));
        c += bc * band * (dusk ? 0.24 : 0.2);
        float glow = 0.5 * exp(-d / (G * 0.05)) + 0.28 * exp(-d / (G * 0.13)) + 0.08 * exp(-d / (G * 0.4));
        float core = exp(-(d * d) / (r * r * 1.6)) * 3.0 + exp(-d / (r * 1.8)) * 0.8;
        float3 cc = dusk ? lin(float3(1.0, 0.72, 0.42)) : lin(float3(1.0, 0.8, 0.66));
        float3 gc = dusk ? lin(float3(1.0, 0.52, 0.26)) : lin(float3(1.0, 0.6, 0.55));
        return c + cc * core + gc * glow * (dusk ? 1.0 : 0.7);
    }
    if (scene == S_FOG) {   // 안개 너머 하얀 원판 — 번짐 없이
        float core = 1.0 - smoothstep(r * 0.6, r * 1.5, d);
        float glow = 0.14 * exp(-d / (G * 0.07)) + 0.06 * exp(-d / (G * 0.22));
        return c + lin(float3(0.95, 0.94, 0.9)) * (core * 0.3 + glow);
    }
    float k = scene == S_WIND ? 0.75 : 1.0;
    float3 cc = scene == S_LEAVES ? lin(float3(1.0, 0.9, 0.7)) : lin(float3(1.0, 0.97, 0.92));
    float3 gc = scene == S_LEAVES ? lin(float3(1.0, 0.8, 0.52)) : (scene == S_PETALS ? lin(float3(1.0, 0.93, 0.9)) : lin(float3(0.93, 0.96, 1.0)));
    float glow = 0.5 * exp(-d / (G * 0.05)) + 0.3 * exp(-d / (G * 0.11)) + 0.1 * exp(-d / (G * 0.28));
    float core = exp(-(d * d) / (r * r * 1.8)) * 3.0 + exp(-d / (r * 2.0)) * 1.0;
    return c + (cc * core + gc * glow) * k;
}

// 비탈진 결 — 안개 띠·바람 결
static float bandNoise(float2 p, int oct) { return fbm2(p, oct); }

fragment float4 skyCompose(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                           texture2d<float> colA [[texture(0)]], texture2d<float> trA [[texture(1)]],
                           texture2d<float> colB [[texture(2)]], texture2d<float> trB [[texture(3)]],
                           texture2d<float> moonTex [[texture(4)]]) {
    int scene = int(u.view.w);
    bool night = nightScene(scene);
    float2 pt = in.uv * u.view.xy;
    float t = u.view.z;
    float pxPerPt = u.res.x / u.view.x;
    float lean = textLean(u, pt, true);
    float shade = 1.0 - 0.85 * u.tone.y * lean;
    float3 c = skyColor(scene, in.uv, pt, u);
    float4 cl = cloudsAt(u, colA, trA, colB, trB, in.uv);
    float T = cl.a;
    float2 lp = u.light.xy + u.parallax.xy * 0.1;
    float d = distance(pt, lp);
    float r = u.light.z;

    if (night) {
        float cover = 0.0;
        float3 moon = float3(0.0);
        if (u.light.w > 0.5) moon = moonLight((pt - lp) / r, r * pxPerPt, u, moonTex, cover);
        c += starField(u, pt, t, pxPerPt, u.parallax.xy, int(u.meteor1.w)) * (1.0 - cover);
        c += meteorLight(pt, u, pxPerPt) * (1.0 - 0.5 * lean) * (1.0 - cover);
        if (u.light.w > 0.5) {
            float e = d / r;
            float glow = pow(moonLitFraction(u), 1.2) * (0.13 * exp(-e * e * 0.12) + 0.035 * exp(-e * 0.15));
            c += lin(float3(0.95, 0.93, 0.88)) * glow * shade;
        }
        c += moon * cover;
    } else {
        if (scene == S_DAWN) {
            float hy = pt.y / max(u.view.y, 640.0);
            c += starField(u, pt, t, pxPerPt, u.parallax.xy, int(u.extra.y)) * (1.0 - smoothstep(0.05, 0.4, hy)) * 0.8;
        }
        if (sunScene(scene) && u.light.w > 0.5) c = sunLight(scene, pt, d, r, u, c);
    }

    c = c * T + cl.rgb;

    if (scene == S_DUSK || scene == S_DAWN) {
        // 구름 아랫면이 지평선 빛에 물든다 — 바로 아래가 더 비어 있는 곳.
        float2 dn = float2(0.0, 7.0 / u.view.y);
        float Tb = cloudsAt(u, colA, trA, colB, trB, in.uv + dn).a;
        float under = saturate((Tb - T) * 2.2) * (1.0 - T);
        float low = 0.35 + 0.65 * saturate(in.uv.y * 1.2);
        float3 wc = scene == S_DUSK ? lin(float3(1.0, 0.36, 0.16)) : lin(float3(1.0, 0.55, 0.55));
        c += wc * under * low * (scene == S_DUSK ? 0.55 : 0.3) * (1.0 - 0.8 * lean);
    }

    if (scene == S_DAY) {
        float2 dir = normalize(float2(1.0, -0.42));
        float2 pp = pt + u.parallax.xy * 0.3;
        float2 q = float2(dot(pp, dir), dot(pp, float2(-dir.y, dir.x))) / WORLD * float2(0.7, 2.9) + float2(t * 0.012, 0.0);
        int oc = int(u.sun.z);
        float2 warp = float2(fbm2(q * 1.3 + 1.7, oc - 1), fbm2(q * 1.3 + 9.2, oc - 1)) - 0.5;
        float body = fbm2(q * float2(1.0, 0.8) + warp * 1.2, oc);
        float fiber = fbm2(float2(q.x * 0.5, q.y * 9.0) + warp * 3.5 + 4.1, oc);
        float a = smoothstep(0.5, 0.78, body) * (0.3 + 0.7 * smoothstep(0.35, 0.75, fiber));
        a *= smoothstep(0.25, 0.6, vnoise(pp / (WORLD * 0.7) + float2(t * 0.004, 5.1)));
        a *= 0.5 + 0.5 * smoothstep(0.85, 0.25, in.uv.y);
        // 글자 쪽으로 새털구름만 옅어진다 — 하늘색은 그대로라 얼룩이 안 생긴다.
        a *= 1.0 - 0.85 * textLean(u, pt);
        float lit = 0.62 + 1.6 * exp(-d / (u.sun.y * 0.16));
        c = mix(c, lin(float3(0.92, 0.95, 1.0)) * lit, a * 0.55);
    }

    if (night && u.light.w > 0.5) {
        float thin = saturate((1.0 - T) * T * 4.0) * moonLitFraction(u);
        float k = d / (r * 6.0);
        float3 corona = float3(0.5 + 0.5 * cos(k * 9.0 + float3(0.0, 0.8, 1.6))) * exp(-k * k * 1.5);
        c += (corona * thin * 0.12 + lin(float3(0.8, 0.84, 1.0)) * thin * exp(-d / (r * 3.0)) * 0.5) * shade;
    }
    int oc = int(u.extra.w);
    if (rainScene(scene) || scene == S_SNOW) {
        float2 fw = pt / WORLD;
        float mist = fbm2(fw * float2(1.2, 3.5) + float2(t * 0.06, 0.0), oc);
        float mist2 = fbm2(fw * float2(2.4, 6.0) - float2(t * 0.11, 0.0) + 7.0, max(oc - 1, 2));
        float band = smoothstep(0.35, 1.0, in.uv.y);
        float k = scene == S_RAIN ? 1.0 : (scene == S_DRIZZLE ? 0.85 : 0.6);
        float a = (band * saturate(mist * 1.2 - 0.15) * 0.55 + band * band * 0.12 + mist2 * 0.06) * k;
        float3 mc = scene == S_SNOW ? lin(float3(0.6, 0.63, 0.68)) : (scene == S_DRIZZLE ? lin(float3(0.46, 0.5, 0.53)) : lin(float3(0.42, 0.46, 0.50)));
        if (scene != S_RAIN) a *= 1.0 - 0.85 * lean;
        c = mix(c, mc, saturate(a));
    }
    if (scene == S_FOG) {
        // 천천히 흐르는 안개 층 셋 — 아래로 갈수록 짙고 하얗다. 위 층은 느리고 얇다.
        float W = u.view.x;
        float y = in.uv.y;
        float clear = 1.0 - 0.97 * lean;
        float acc = 0.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float2 tl = u.parallax.xy * (0.2 + 0.4 * fi);
            float2 q = (pt + tl) / WORLD * float2(0.9 + 0.5 * fi, 4.0 + 2.0 * fi) + float2(t * (0.018 + 0.016 * fi) * (i == 1 ? -1.0 : 1.0), 3.7 * fi);
            float n = fbm2(q + float2(0.0, fbm2(q * 0.5 + 9.1 * fi, 2) * 0.8), oc);
            float centre = 0.5 + 0.2 * fi;
            float yb = exp(-pow((y - centre) / (0.16 + 0.04 * fi), 2.0));
            acc += smoothstep(0.38, 0.8, n) * yb * (0.32 + 0.12 * fi);
        }
        float ground = smoothstep(0.55, 1.0, y) * (0.55 + 0.25 * fbm2(pt / float2(W * 0.6, 60.0) + float2(t * 0.02, 0.0), max(oc - 2, 2)));
        float a = saturate(acc + ground) * clear;
        c = mix(c, lin(float3(0.84, 0.86, 0.87)), a);
    }
    if (scene == S_WIND) {
        // 가는 바람 결 — 두 층(먼 결은 가늘고 느리다)이 비스듬히 흘러간다.
        float2 dir = normalize(float2(1.0, 0.1));
        float clear = 1.0 - 0.9 * textLean(u, pt);
        float acc = 0.0;
        for (int i = 0; i < 2; i++) {
            float fi = float(i);
            float2 pp = pt + u.parallax.xy * (0.3 + 0.5 * fi);
            float2 q = float2(dot(pp, dir), dot(pp, float2(-dir.y, dir.x)));
            float lane = q.y / (i == 0 ? 2.6 : 4.2);
            float sp = i == 0 ? 120.0 : 240.0;
            float along = (q.x - t * sp) / (i == 0 ? 140.0 : 220.0);
            float wob = vnoise(float2(along * 0.6, lane * 0.07 + 3.0 * fi)) * 3.0;
            float n = vnoise(float2(along * 0.25, lane + wob));
            float thin = smoothstep(0.86, 0.97, n);
            float seg = smoothstep(0.45, 0.8, vnoise(float2(along * 1.4 + 11.0 * fi, floor(lane) * 0.37)));
            acc += thin * seg * (i == 0 ? 0.1 : 0.16);
        }
        c += lin(float3(0.95, 0.97, 1.0)) * acc * clear;
    }
    return float4(c, 1.0);
}

// MARK: - 비 (컴퓨트 입자 + 늘인 사각형)

kernel void skyRainUpdate(device float4* drops [[buffer(0)]], constant SkyU& u [[buffer(1)]],
                          uint i [[thread_position_in_grid]]) {
    uint n = uint(u.rays.w);
    if (i >= n) return;
    float t = u.view.z;
    float W = u.view.x, H = u.view.y;
    float fi = float(i);
    float r0 = hash11(fi * 1.31 + 0.7);
    int layer = r0 < 0.55 ? 0 : (r0 < 0.86 ? 1 : 2);
    float speed = layer == 0 ? 380.0 : (layer == 1 ? 720.0 : 1350.0);
    float len = layer == 0 ? 11.0 : (layer == 1 ? 24.0 : 64.0);
    float width = layer == 0 ? 0.35 : (layer == 1 ? 0.7 : 1.3);
    float alpha = layer == 0 ? 0.16 : (layer == 1 ? 0.22 : 0.26);
    bool drizzle = int(u.view.w) == S_DRIZZLE;
    if (drizzle) {
        speed *= 0.72; len *= 0.42; width *= 0.8; alpha *= 0.8;
    } else if (layer == 2 && hash11(fi * 5.7) < 0.3) { width = 5.0; alpha = 0.035; len = 90.0; }
    speed *= 0.85 + 0.3 * hash11(fi * 2.9);
    float gust = (drizzle ? 0.08 : 0.17) + 0.06 * sin(t * 0.37) + 0.03 * sin(t * 1.21 + 1.3);
    float slant = gust * (0.75 + 0.2 * float(layer));
    float span = H + len + 40.0;
    float ph = hash11(fi * 7.7) + t * speed / span;
    float cyc = floor(ph);
    float f = ph - cyc;
    float headY = f * span - 20.0;
    float x0 = hash12(float2(fi * 0.37, cyc * 1.73)) * (W + slant * span + 40.0) - slant * span - 20.0;
    float2 par = u.parallax.xy * (0.4 + 0.5 * float(layer));
    float2 head = float2(x0 + slant * headY, headY) + par;
    float2 dir = normalize(float2(slant, 1.0));
    float2 tail = head - dir * len;
    drops[i * 2] = float4(tail, head);
    drops[i * 2 + 1] = float4(width, alpha, float(layer), 0.0);
}

struct RainOut {
    float4 pos [[position]];
    float2 local;
    float alpha;
};

vertex RainOut skyRainVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                             const device float4* drops [[buffer(0)]], constant SkyU& u [[buffer(1)]]) {
    float4 a = drops[iid * 2];
    float4 b = drops[iid * 2 + 1];
    float pxPerPt = u.res.x / u.view.x;
    float2 p0 = a.xy, p1 = a.zw;
    float2 dir = p1 - p0;
    float len = max(length(dir), 1e-3);
    float2 tv = dir / len;
    float2 nv = float2(-tv.y, tv.x);
    float minW = 1.6 / pxPerPt;
    float w = max(b.x, minW);
    float side = (vid & 1) ? 1.0 : -1.0;
    float along = (vid & 2) ? 1.0 : 0.0;
    float2 p = mix(p0, p1, along) + nv * side * w * 0.5;
    RainOut o;
    o.pos = float4(p.x / u.view.x * 2.0 - 1.0, 1.0 - p.y / u.view.y * 2.0, 0.0, 1.0);
    o.local = float2(side, along);
    o.alpha = b.y * (b.x / w) * smoothstep(2.0, 36.0, textDistance(u, p));
    return o;
}

fragment float4 skyRainFragment(RainOut in [[stage_in]]) {
    float across = 1.0 - in.local.x * in.local.x;
    float along = smoothstep(0.0, 0.75, in.local.y) * smoothstep(1.0, 0.9, in.local.y);
    float a = across * across * along * in.alpha;
    return float4(lin(float3(0.78, 0.85, 0.92)) * a * 1.4, 0.0);
}


// MARK: - 눈·꽃잎·낙엽 (컴퓨트 입자 + 돌아가는 사각형) — 시간 t 만으로 정해진다

kernel void skyFlakeUpdate(device float4* flakes [[buffer(0)]], constant SkyU& u [[buffer(1)]],
                           uint i [[thread_position_in_grid]]) {
    uint n = uint(u.extra.z);
    if (i >= n) return;
    int scene = int(u.view.w);
    float t = u.view.z;
    float W = u.view.x, H = u.view.y;
    float fi = float(i);
    float r0 = hash11(fi * 1.31 + 0.7);
    float h1 = hash11(fi * 2.9 + 0.3), h2 = hash11(fi * 5.7 + 1.1), h3 = hash11(fi * 7.7 + 2.3);
    float h4 = hash11(fi * 3.3 + 4.1), h5 = hash11(fi * 9.1 + 0.9), h6 = hash11(fi * 4.4 + 6.6);
    int layer;
    float size, vy, vx, sway, sw, alpha, blur, angle, flip;
    if (scene == S_SNOW) {
        layer = r0 < 0.55 ? 0 : (r0 < 0.88 ? 1 : 2);
        size = layer == 0 ? 0.7 + 0.5 * h1 : (layer == 1 ? 1.3 + 0.9 * h1 : 3.0 + 3.0 * h1);
        vy = (layer == 0 ? 15.0 : (layer == 1 ? 28.0 : 52.0)) * (0.8 + 0.4 * h2);
        vx = 5.0 + 3.0 * float(layer);
        sway = (layer == 0 ? 3.0 : (layer == 1 ? 7.0 : 13.0)) * (0.6 + 0.8 * h3);
        sw = 0.35 + 0.6 * h4;
        alpha = layer == 0 ? 0.5 : (layer == 1 ? 0.75 : 0.42);
        blur = layer == 0 ? 0.45 : (layer == 1 ? 0.5 : 0.9);
        angle = 0.0; flip = 1.0;
    } else if (scene == S_PETALS) {
        layer = r0 < 0.45 ? 0 : (r0 < 0.82 ? 1 : 2);
        size = layer == 0 ? 2.0 + 0.8 * h1 : (layer == 1 ? 3.6 + 1.4 * h1 : 7.5 + 4.0 * h1);
        vy = (layer == 0 ? 13.0 : (layer == 1 ? 22.0 : 40.0)) * (0.7 + 0.6 * h2);
        vx = (layer == 0 ? 18.0 : (layer == 1 ? 32.0 : 62.0)) * (0.7 + 0.6 * h3);
        sway = (layer == 0 ? 6.0 : (layer == 1 ? 12.0 : 24.0)) * (0.6 + 0.8 * h4);
        sw = 0.6 + 0.9 * h5;
        alpha = layer == 0 ? 0.55 : (layer == 1 ? 0.85 : 0.8);
        blur = layer == 0 ? 0.12 : (layer == 1 ? 0.1 : 0.45);
        angle = h6 * 6.2832 + t * (h2 - 0.5) * 2.4 + 0.5 * sin(t * sw + h3 * 6.0);
        flip = cos(t * (1.4 + 2.2 * h1) + h5 * 6.2832);
    } else {
        layer = r0 < 0.45 ? 0 : (r0 < 0.82 ? 1 : 2);
        size = layer == 0 ? 2.6 + 1.0 * h1 : (layer == 1 ? 4.6 + 1.8 * h1 : 10.0 + 5.0 * h1);
        vy = (layer == 0 ? 20.0 : (layer == 1 ? 34.0 : 62.0)) * (0.75 + 0.5 * h2);
        vx = (layer == 0 ? 8.0 : (layer == 1 ? 14.0 : 26.0)) * (0.5 + h3);
        sway = (layer == 0 ? 8.0 : (layer == 1 ? 16.0 : 30.0)) * (0.6 + 0.8 * h4);
        sw = 0.7 + 0.8 * h5;
        alpha = layer == 0 ? 0.5 : (layer == 1 ? 0.85 : 0.9);
        blur = layer == 0 ? 0.1 : (layer == 1 ? 0.08 : 0.28);
        // 진자처럼 흔들리며 기울고, 뒤집힌다
        angle = h6 * 6.2832 + 0.8 * cos(t * sw + h3 * 6.0) + t * (h2 - 0.5) * 0.8;
        flip = cos(t * (0.9 + 1.6 * h1) + h5 * 6.2832);
    }
    float m = 40.0 + size * 2.0;
    float spanX = W + 2.0 * m, spanY = H + 2.0 * m;
    float gust = scene == S_SNOW ? 6.0 * sin(t * 0.13 + h1) : 14.0 * sin(t * 0.23 + 1.3) + 6.0 * sin(t * 0.61);
    float x = fract((h4 * spanX + vx * t + gust * (0.5 + 0.5 * float(layer))) / spanX) * spanX - m + sway * sin(t * sw + h5 * 6.2832);
    float y = fract((h1 * spanY + vy * t) / spanY) * spanY - m;
    float2 pos = float2(x, y) + u.parallax.xy * (0.3 + 0.45 * float(layer));
    flakes[i * 2] = float4(pos, size, angle);
    flakes[i * 2 + 1] = float4(alpha, blur, flip, float(layer) + 0.99 * h6);
}

struct FlakeOut {
    float4 pos [[position]];
    float2 local;
    float alpha;
    float blur;
    float flip;
    float tag;
};

vertex FlakeOut skyFlakeVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                               const device float4* flakes [[buffer(0)]], constant SkyU& u [[buffer(1)]]) {
    float4 a = flakes[iid * 2];
    float4 b = flakes[iid * 2 + 1];
    int scene = int(u.view.w);
    float pxPerPt = u.res.x / u.view.x;
    float2 corner = float2((vid & 1) ? 1.0 : -1.0, (vid & 2) ? 1.0 : -1.0);
    float size = max(a.z, 0.9 / pxPerPt);
    float pad = 1.0 + b.y + (scene == S_LEAVES ? 0.2 : 0.0);
    float2 lc = corner * pad;
    float fx = scene == S_SNOW ? 1.0 : max(abs(b.z), 0.14);
    float2 q = float2(lc.x * fx, lc.y) * size;
    float cs = cos(a.w), sn = sin(a.w);
    float2 p = a.xy + float2(cs * q.x - sn * q.y, sn * q.x + cs * q.y);
    FlakeOut o;
    o.pos = float4(p.x / u.view.x * 2.0 - 1.0, 1.0 - p.y / u.view.y * 2.0, 0.0, 1.0);
    o.local = lc;
    // 글자에 닿기 전에 사라진다 — 크기만큼 떨어진 곳부터 옅어진다.
    float reach = size * pad * 1.15;
    o.alpha = b.x * (a.z / size) * smoothstep(reach, reach + 14.0, textDistance(u, a.xy));
    o.blur = b.y;
    o.flip = b.z;
    o.tag = b.w + 8.0 * float(scene == S_PETALS) + 16.0 * float(scene == S_LEAVES);
    return o;
}

fragment float4 skyFlakeFragment(FlakeOut in [[stage_in]]) {
    float kind = floor(in.tag / 8.0);
    float hue = fract(in.tag);
    float2 l = in.local;
    float bl = max(in.blur, 0.06);
    if (kind < 0.5) {   // 눈 — 가까운 층은 초점 밖이라 둥글게 번진다
        float r = length(l);
        float a = 1.0 - smoothstep(1.0 - bl, 1.0 + bl * 0.6, r);
        if (in.blur > 0.7) a *= 0.7 + 0.3 * smoothstep(0.2, 0.95, r);
        a *= in.alpha;
        return float4(lin(float3(0.93, 0.95, 1.0)) * 1.05 * a, a);
    }
    float back = in.flip < 0.0 ? 1.0 : 0.0;
    float face = abs(in.flip);
    if (kind < 1.5) {   // 꽃잎 — 끝이 살짝 패인 벚꽃잎, 앞뒤 색이 다르고 휘어 보인다
        float y = l.y;
        float wdt = 0.6 * sqrt(max(1.0 - y * y, 0.0)) * (0.5 + 0.5 * saturate(y * 0.5 + 0.6));
        float sd = abs(l.x) - wdt;
        float notch = length((l - float2(0.0, 1.0)) * float2(1.0, 1.5)) - 0.26;
        float a = (1.0 - smoothstep(-bl * 0.5, bl, sd)) * smoothstep(-bl * 0.5, bl, notch);
        float3 tip = lin(float3(0.98, 0.84, 0.88)), base = lin(float3(0.92, 0.56, 0.68));
        float3 col = mix(base, tip, smoothstep(-1.0, 0.4, y));
        col = mix(col, lin(float3(1.0, 0.93, 0.95)), 0.35 * smoothstep(0.4, 0.0, abs(l.x)) * smoothstep(-0.6, 0.6, y));
        float curl = 0.82 + 0.18 * cos(l.x * 2.2) ;
        col *= (0.62 + 0.38 * face) * curl * (back > 0.5 ? 0.8 : 1.0);
        a *= in.alpha;
        return float4(col * a, a);
    }
    // 낙엽 — 뾰족한 잎, 잎맥·꼭지, 뒷면은 흐리고 밝다
    float y = l.y;
    float wdt = 0.56 * pow(max(1.0 - y * y, 0.0), 0.7) * (1.0 - 0.18 * y);
    float lobe = 0.05 * sin(y * 9.0 + hue * 6.0);
    float sd = abs(l.x) - (wdt + lobe * wdt);
    float a = 1.0 - smoothstep(-bl * 0.5, bl, sd);
    float stem = (1.0 - smoothstep(0.035, 0.035 + bl * 0.3, abs(l.x))) * step(-1.22, y) * step(y, -0.9);
    a = max(a, stem);
    float3 c0 = hue < 0.3 ? lin(float3(0.86, 0.45, 0.14)) : (hue < 0.55 ? lin(float3(0.62, 0.34, 0.15))
              : (hue < 0.8 ? lin(float3(0.8, 0.29, 0.12)) : lin(float3(0.9, 0.66, 0.2))));
    float rib = 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.04, abs(l.x)));
    float veins = 1.0 - 0.14 * (1.0 - smoothstep(0.0, 0.06, abs(fract((y - abs(l.x) * 0.9) * 4.5) - 0.5) - 0.38));
    float edge = 0.78 + 0.22 * smoothstep(0.0, -0.18, sd);
    float3 col = c0 * rib * veins * edge;
    if (back > 0.5) col = mix(col, float3(lum(col)), 0.3) * 0.92;
    col *= 0.55 + 0.45 * face;
    a *= in.alpha;
    return float4(col * a, a);
}

// MARK: - 빛줄기 (낮은 해상도)

fragment float4 skyRays(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                        texture2d<float> trans [[texture(0)]]) {
    constexpr sampler cs(filter::linear, address::clamp_to_edge);
    int n = int(u.rays.x);
    if (n <= 0 || u.rays.y <= 0.0) return float4(0.0);
    float2 lu = u.light.xy / u.view.xy;
    float2 aspect = float2(u.view.x / u.view.y, 1.0);
    float rad = u.light.z * 3.0 / u.view.y;
    float2 delta = (in.uv - lu) / float(n) * 0.85;
    float2 s = in.uv;
    float illum = 0.0, decay = 1.0;
    float j = ign(in.pos.xy);
    s -= delta * j;
    for (int i = 0; i < n; i++) {
        s -= delta;
        float T = u.win.w > 0.5 ? bakedAt(u, trans, trans, s * u.view.xy).a : trans.sample(cs, s).r;
        float2 dd = (s - lu) * aspect;
        float src = exp(-dot(dd, dd) / (rad * rad));
        illum += T * src * decay;
        decay *= 0.965;
    }
    illum /= float(n);
    int sc = int(u.view.w);
    float3 col = sc == S_DUSK ? lin(float3(1.0, 0.6, 0.32)) : (nightScene(sc) ? lin(float3(0.75, 0.8, 1.0)) : lin(float3(1.0, 0.95, 0.85)));
    return float4(col * illum * u.rays.y, 1.0);
}

// MARK: - 블룸 (다운샘플 13탭 · 텐트 업샘플)

static float3 down13(texture2d<float> src, float2 uv, float2 ts) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float3 a = src.sample(s, uv + ts * float2(-2, -2)).rgb;
    float3 b = src.sample(s, uv + ts * float2(0, -2)).rgb;
    float3 c = src.sample(s, uv + ts * float2(2, -2)).rgb;
    float3 d = src.sample(s, uv + ts * float2(-1, -1)).rgb;
    float3 e = src.sample(s, uv + ts * float2(1, -1)).rgb;
    float3 f = src.sample(s, uv + ts * float2(-2, 0)).rgb;
    float3 g = src.sample(s, uv).rgb;
    float3 h = src.sample(s, uv + ts * float2(2, 0)).rgb;
    float3 i = src.sample(s, uv + ts * float2(-1, 1)).rgb;
    float3 j = src.sample(s, uv + ts * float2(1, 1)).rgb;
    float3 k = src.sample(s, uv + ts * float2(-2, 2)).rgb;
    float3 l = src.sample(s, uv + ts * float2(0, 2)).rgb;
    float3 m = src.sample(s, uv + ts * float2(2, 2)).rgb;
    return (d + e + i + j) * 0.125 + (a + c + k + m) * 0.03125 + (b + f + h + l) * 0.0625 + g * 0.125;
}

kernel void skyBloomPrefilter(texture2d<float> src [[texture(0)]], texture2d<float, access::write> dst [[texture(1)]],
                              constant float4& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    float3 c = down13(src, uv, 1.0 / float2(src.get_width(), src.get_height()));
    c = min(c, float3(64.0));
    float br = max(c.r, max(c.g, c.b));
    float knee = p.y;
    float soft = clamp(br - p.x + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee + 1e-5);
    float w = max(soft, br - p.x) / max(br, 1e-5);
    dst.write(float4(c * w, 1.0), gid);
}

kernel void skyBloomDown(texture2d<float> src [[texture(0)]], texture2d<float, access::write> dst [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    dst.write(float4(down13(src, uv, 1.0 / float2(src.get_width(), src.get_height())), 1.0), gid);
}

kernel void skyBloomUp(texture2d<float> low [[texture(0)]], texture2d<float> cur [[texture(1)]],
                       texture2d<float, access::write> dst [[texture(2)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    float2 ts = 1.0 / float2(low.get_width(), low.get_height());
    float3 up = low.sample(s, uv).rgb * 4.0;
    up += (low.sample(s, uv + ts * float2(-1, 0)).rgb + low.sample(s, uv + ts * float2(1, 0)).rgb
         + low.sample(s, uv + ts * float2(0, -1)).rgb + low.sample(s, uv + ts * float2(0, 1)).rgb) * 2.0;
    up += low.sample(s, uv + ts * float2(-1, -1)).rgb + low.sample(s, uv + ts * float2(1, -1)).rgb
        + low.sample(s, uv + ts * float2(-1, 1)).rgb + low.sample(s, uv + ts * float2(1, 1)).rgb;
    dst.write(float4(cur.sample(s, uv).rgb + up / 16.0, 1.0), gid);
}

// MARK: - 마무리 (블룸·빛줄기·글자 자리·EDR 어깨·디더)

fragment float4 skyFinal(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                         texture2d<float> hdr [[texture(0)]], texture2d<float> bloom [[texture(1)]],
                         texture2d<float> rays [[texture(2)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    int scene = int(u.view.w);
    float2 pt = in.uv * u.view.xy;
    float3 c = hdr.sample(s, in.uv).rgb;
    float shade = 1.0 - 0.85 * u.tone.y * textLean(u, pt, true);
    c += (bloom.sample(s, in.uv).rgb * u.tone.w + rays.sample(s, in.uv).rgb) * shade;

    if (scene == S_DAY && u.light.w > 0.5) {
        float2 lp = u.light.xy;
        float2 center = u.view.xy * 0.5;
        float ks[3] = { 0.5, 0.82, 1.32 };
        float rs[3] = { 0.045, 0.08, 0.03 };
        float as[3] = { 0.022, 0.03, 0.02 };
        for (int i = 0; i < 3; i++) {
            float2 g = lp + (center - lp) * ks[i];
            float dd = distance(pt, g) / (rs[i] * u.sun.x);
            if (dd > 1.1) continue;
            float disk = smoothstep(1.0, 0.9, dd);
            float rim = exp(-pow((dd - 0.93) / 0.07, 2.0));
            float3 iri = 0.5 + 0.5 * cos(6.2831853 * (dd * 1.4 + float3(0.0, 0.33, 0.67)));
            c += (lin(float3(0.86, 0.92, 1.0)) * disk * (0.55 + 0.45 * dd * dd) + mix(float3(1.0), iri, 0.7) * rim * 0.9) * as[i];
        }
    }

    // 글자 쪽 밝기 상한 — 상자가 아니라 넓은 경사로 건다.
    if (u.caps.x > 0.0) {
        float m = textLean(u, pt, true);
        float cap = u.caps.x, knee = cap * 0.75;
        float L = lum(c);
        float Lc = L < knee ? L : knee + (cap - knee) * (1.0 - exp(-(L - knee) / (cap - knee)));
        c *= mix(1.0, Lc / max(L, 1e-6), m);
    }
    float L;

    float head = max(nightScene(scene) ? u.tone.x : 1.0 + (u.tone.x - 1.0) * 0.72, 1.0);
    float k = 0.8;
    L = lum(c);
    if (L > k) {
        float room = head - k + 0.25;
        float Ln = k + room * (1.0 - exp(-(L - k) / room));
        Ln = min(Ln, head);
        c *= Ln / L;
        c = mix(c, float3(Ln), saturate((Ln - 0.9) / max(head - 0.9, 0.1)) * 0.6);
    }
    c = min(c, float3(head));

    float3 g = pow(max(c, 0.0), float3(1.0 / 2.2));
    float n = ign(in.pos.xy + float2(u.rays.z * 5.588238)) - 0.5;
    g += n * (1.2 / 255.0 + u.tone.z);
    c = pow(max(g, 0.0), float3(2.2));
    return float4(c, 1.0);
}
