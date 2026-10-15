#include <metal_stdlib>
using namespace metal;

// SkyView.swift 의 SkyUniforms 와 같은 순서·크기(float4 × 18). 하나를 고치면 둘 다 고친다.
struct SkyU {
    float4 res;       // 그리는 대상 px w, h, 1/w, 1/h
    float4 view;      // pt w, h, 시간 t, 장면
    float4 light;     // 해·달 pt x, y, 원판 반지름 pt, 화면에 그림(1)/안 그림(0)
    float4 quality;   // 구름 걸음, 빛 걸음, 잔결(0/1), 먼 층 걸음
    float4 tone;      // EDR 여유, 글자 자리 최대 밝기, 그레인, 블룸 세기
    float4 parallax;  // 기울기 pt x, y, 글자 자리 수, 글자 자리 번짐 pt
    float4 rays;      // 빛줄기 걸음, 빛줄기 세기, 프레임 번호, 빗방울 수
    float4 moon;      // 달 나이(일), 명암 경계 기울기(rad), 지구조 세기, 텍스처 있음(1)
    float4 meteor0;   // 별똥별 머리 pt x, y, 나아가는 방향 x, y
    float4 meteor1;   // 꼬리 길이 pt, 세기(0 = 없음), 굵기 pt, 별 층 수(1~3)
    float4 blend;     // 구름 두 장 섞기 w, t - tA, tB - t, 구름 흐름 pt/초
    float4 sun;       // 햇무리 반지름 pt, 눈부심 길이 pt, 새털구름 옥타브, 햇무리 얼룩(1)
    float4 caps;      // 작은 글자 최대 밝기, 큰 말 최대 밝기, 작은 글자 번짐 pt, 큰 말 번짐 pt
    float4 textBig;   // 글자 자리마다 큰 말(1)/작은 글자(0)
    float4 text[4];   // 글자 자리 pt x0, y0, x1, y1
};

constant float WORLD = 320.0;   // pt — 같은 하늘이 카드 크기만큼 잘려 들어가게 모든 무늬를 pt 로 잰다
constant float SLAB = 0.55;     // 구름층 두께(월드 단위)

struct VOut { float4 pos [[position]]; float2 uv; };

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

// which: 0 전부, 1 작은 글자만, 2 큰 말만
// soft: 글자 자리를 높이 절반만큼 둥글게 부풀린 알약 + 가우시안 꼬리(맑은 낮 — 네모 테두리가 안 보이게)
static float textMask(constant SkyU& u, float2 pt, float spread = 1.0, int which = 0, float feather = 0.0, bool soft = false) {
    float m = 0.0;
    int n = int(u.parallax.z);
    float f = max((feather > 0.0 ? feather : u.parallax.w) * spread, 1.0);
    for (int i = 0; i < n; i++) {
        bool big = u.textBig[i] > 0.5;
        if ((which == 1 && big) || (which == 2 && !big)) continue;
        float4 r = u.text[i];
        float2 d = max(r.xy - pt, pt - r.zw);
        float sd = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
        if (soft) {
            sd -= 0.5 * (r.w - r.y);
            m = max(m, sd <= 0.0 ? 1.0 : exp(-sd * sd / (f * f)));
        } else {
            m = max(m, 1.0 - smoothstep(0.0, f, sd));
        }
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

kernel void skyBakeNoise(texture3d<float, access::write> out [[texture(0)]], uint3 gid [[thread_position_in_grid]]) {
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

static float3 skyColor(int scene, float2 uv, float2 pt, constant SkyU& u) {
    float y = saturate(uv.y);
    float d = distance(pt, u.light.xy) / WORLD;
    float shade = 1.0 - 0.85 * textMask(u, pt, 2.5);
    if (scene == 0 || scene == 3) {
        float k = pow(moonLitFraction(u), 1.5);
        float3 c = scene == 0
            ? mix(lin(float3(0.085, 0.09, 0.17)), lin(float3(0.19, 0.205, 0.33)), smoothstep(-0.1, 1.1, y))
            : mix(lin(float3(0.07, 0.08, 0.17)), lin(float3(0.23, 0.24, 0.42)), smoothstep(-0.15, 1.15, y));
        c += lin(float3(0.62, 0.66, 0.85)) * (0.10 * exp(-d * 2.2) + 0.03 * exp(-d * 0.6)) * shade * (0.15 + 0.85 * k);
        return c;
    }
    if (scene == 1) {
        float3 c = mix(lin(float3(0.33, 0.52, 0.76)), lin(float3(0.34, 0.53, 0.75)), smoothstep(0.0, 0.5, y));
        c = mix(c, lin(float3(0.52, 0.67, 0.84)), smoothstep(0.55, 1.1, y));
        return c;
    }
    return mix(lin(float3(0.14, 0.165, 0.195)), lin(float3(0.22, 0.255, 0.285)), y);
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
};

static Layer layerFor(int scene, int idx) {
    Layer L;
    L.offset = float2(0.0);
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
    } else if (scene == 1) {   // 높은 새털구름 — 옆으로 길게
        L.scale = float2(0.16, 1.1); L.zscale = 0.25; L.drift = float2(0.004, 0.0); L.evolve = 0.001;
        L.coverage = 0.36; L.extinct = 3.0; L.detail = 0.5;
        L.sun = lin(float3(1.0, 0.97, 0.92)) * 0.6; L.ambLo = lin(float3(0.55, 0.66, 0.82)); L.ambHi = lin(float3(0.75, 0.82, 0.92));
        L.lightZ = 1.2; L.g = 0.75; L.haze = 0.25; L.depth = 0.3;
        L.coverage = 0.0;
    } else if (scene == 3) {   // 맑은 밤 — 구름 없음
        L.scale = float2(0.5); L.zscale = 0.3; L.drift = float2(0.0); L.evolve = 0.0;
        L.coverage = 0.0; L.extinct = 1.0; L.detail = 0.0;
        L.sun = float3(0.0); L.ambLo = float3(0.0); L.ambHi = float3(0.0);
        L.lightZ = 1.0; L.g = 0.0; L.haze = 0.0; L.depth = 0.0;
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
    float d = saturate(remap(base, 1.0 - cov, 1.0, 0.0, 1.0));
    if (detail && d > 0.0 && d < 0.7) {
        float4 m = nz.sample(s, p * float3(5.5, 4.2, 3.1) + float3(0.31, 0.17, 0.53));
        float df = saturate(remap(m.g * 0.625 + m.b * 0.25 + m.a * 0.125, 0.32, 0.64, 0.0, 1.0));
        d = saturate(remap(d, df * L.detail, 1.0, 0.0, 1.0));
    }
    return d;
}

static float hg(float c, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5) * 0.0795775;
}

static float4 marchLayer(texture3d<float> nz, Layer L, float2 world, float2 lightWorld, float t, float2 tilt,
                         int steps, int lsteps, bool detail, float jitter, float shade) {
    if (L.coverage <= 0.0 || steps <= 0) return float4(0, 0, 0, 1);
    L.sun *= shade;
    float2 w = world + tilt * L.depth;
    float2 base = w * L.scale + L.drift * t + L.offset;
    float cov = saturate(L.coverage + (fbm2(w * 0.8 + L.offset * 7.0 + L.drift * t * 1.7, 3) - 0.5) * 1.1);
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
            float3 qp = float3(q.xy * L.scale + L.drift * t + L.offset, zz * L.zscale + L.evolve * t);
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

fragment CloudOut skyClouds(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                            texture3d<float> nz [[texture(0)]]) {
    int scene = int(u.view.w);
    float2 pt = in.uv * u.view.xy;
    float2 world = pt / WORLD;
    float2 lw = u.light.xy / WORLD;
    float t = u.view.z;
    float2 tilt = u.parallax.xy / WORLD;
    float jitter = ign(in.pos.xy);
    int steps = int(u.quality.x), lsteps = int(u.quality.y), farSteps = int(u.quality.w);
    bool detail = u.quality.z > 0.5;
    float3 sky = skyColor(scene, in.uv, pt, u);

    float shade = 1.0 - 0.8 * textMask(u, pt, 2.5);
    float4 nearL = marchLayer(nz, layerFor(scene, 1), world, lw, t, tilt, steps, lsteps, detail, jitter, shade);
    float4 farL = float4(0, 0, 0, 1);
    if (nearL.a > 0.02) {
        farL = marchLayer(nz, layerFor(scene, 0), world, lw, t, tilt, farSteps, max(lsteps - 1, 1), false, jitter, shade);
        farL.rgb = mix(farL.rgb, sky * (1.0 - farL.a), layerFor(scene, 0).haze);
    }
    CloudOut o;
    o.color = float4(nearL.rgb + nearL.a * farL.rgb, 1.0);
    o.trans = nearL.a * farL.a;
    return o;
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
        // 글자 둘레의 별은 흐리게가 아니라 통째로 뺀다 — 큰 별을 눌러 두면 흐린 얼룩이 된다.
        if (textMask(u, pt - dv, 0.3) > 0.1 + 0.85 * hash12(cid + 7.7 + fl)) continue;
        float rk = hash12(cid + 5.3 + 11.0 * fl);
        float mag = l == 0 ? 0.14 + 0.25 * rk : (l == 1 ? 0.4 + 1.4 * rk * rk * rk : 1.3 + 5.5 * pow(rk, 4.0));
        float sig = 0.38 + 0.4 * sqrt(mag);
        // 화면 픽셀보다 작게 그리면 흐를 때 픽셀 사이에서 깜빡인다 — 0.6px 아래로는 넓히고 그만큼 어둡게.
        float sg = max(sig, 0.6 * px);
        float r2 = dot(dv, dv);
        // 밝은 별은 더 밝게가 아니라 더 크게 — 1 을 넘기면 블룸이 별 둘레에 흐린 얼룩을 만든다.
        float s = min(mag, 0.95) * (sig * sig) / (sg * sg) * exp(-r2 / (sg * sg));
        if (mag > 0.9) s += min(mag, 3.0) * 0.04 * exp(-r2 / (sig * sig * 6.0));
        float ph = hash12(cid + 9.1 + 3.0 * fl);
        float x = t / (5.0 + 5.0 * ph) + ph * 37.0;
        float n = 0.55 * tnoise(x) + 0.3 * tnoise(x * 1.93 + 11.0) + 0.15 * tnoise(x * 3.7 + 5.0);
        float depth = l == 0 ? 0.7 : (l == 1 ? mix(0.6, 0.35, rk) : mix(0.35, 0.12, saturate(mag / 3.0)));
        s *= 1.0 - depth * smoothstep(0.3, 0.75, n);
        float3 tint = mix(float3(1.0, 0.9, 0.78), float3(0.8, 0.88, 1.0), hash12(cid + 2.2 + fl));
        acc += s * mix(float3(1.0), tint, 0.4);
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

fragment float4 skyCompose(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                           texture2d<float> colA [[texture(0)]], texture2d<float> trA [[texture(1)]],
                           texture2d<float> colB [[texture(2)]], texture2d<float> trB [[texture(3)]],
                           texture2d<float> moonTex [[texture(4)]]) {
    int scene = int(u.view.w);
    bool night = scene == 0 || scene == 3;
    float2 pt = in.uv * u.view.xy;
    float t = u.view.z;
    float pxPerPt = u.res.x / u.view.x;
    float mask = textMask(u, pt);
    float shade = 1.0 - 0.85 * textMask(u, pt, 2.5);
    float3 c = skyColor(scene, in.uv, pt, u);
    float flow = u.blend.w / u.view.x;
    float4 cl = mix(cloudTaps(colA, trA, in.uv - float2(flow * u.blend.y, 0.0)),
                    cloudTaps(colB, trB, in.uv + float2(flow * u.blend.z, 0.0)), u.blend.x);
    float T = cl.a;
    float2 lp = u.light.xy + u.parallax.xy * 0.1;
    float d = distance(pt, lp);
    float r = u.light.z;

    if (night) {
        float cover = 0.0;
        float3 moon = float3(0.0);
        if (u.light.w > 0.5) moon = moonLight((pt - lp) / r, r * pxPerPt, u, moonTex, cover);
        c += starField(u, pt, t, pxPerPt, u.parallax.xy, int(u.meteor1.w)) * (1.0 - cover);
        c += meteorLight(pt, u, pxPerPt) * (1.0 - 0.5 * mask) * (1.0 - cover);
        if (u.light.w > 0.5) {
            float e = d / r;
            float glow = pow(moonLitFraction(u), 1.2) * (0.13 * exp(-e * e * 0.12) + 0.035 * exp(-e * 0.15));
            c += lin(float3(0.95, 0.93, 0.88)) * glow * shade;
        }
        c += moon * cover;
    } else if (scene == 1 && u.light.w > 0.5) {
        float R = u.sun.x, G = u.sun.y;
        float patch = u.sun.w > 0.5 ? 0.45 + 0.9 * vnoise(pt / (R * 0.35) + 2.3) : 0.9;
        c *= 1.0 - 0.12 * smoothstep(R * 1.0, R * 0.55, d) * smoothstep(R * 0.12, R * 0.45, d);
        float x = (d - R) / (R * 0.07);
        float3 ofs = float3(0.0, 0.45, 0.95);
        float3 band = smoothstep(ofs - 0.7, ofs + 0.25, float3(x)) * exp(-max(float3(x) - ofs, 0.0) * float3(0.9, 0.75, 0.55));
        c += band * float3(0.075, 0.065, 0.07) * patch;
        float glow = 0.95 * exp(-d / (G * 0.035)) + 0.55 * exp(-d / (G * 0.1)) + 0.26 * exp(-d / (G * 0.26))
                   + 0.09 * exp(-d / (G * 0.65));
        float core = exp(-(d * d) / (r * r)) * 9.0 + exp(-d / (r * 1.3)) * 2.5;
        c += lin(float3(1.0, 0.975, 0.93)) * core + lin(float3(0.93, 0.96, 1.0)) * glow;
    }

    c = c * T + cl.rgb;

    if (scene == 1) {
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
        float lit = 0.62 + 1.6 * exp(-d / (u.sun.y * 0.16));
        c = mix(c, lin(float3(0.92, 0.95, 1.0)) * lit, a * 0.55);
    }

    if (night && u.light.w > 0.5) {
        float thin = saturate((1.0 - T) * T * 4.0) * moonLitFraction(u);
        float k = d / (r * 6.0);
        float3 corona = float3(0.5 + 0.5 * cos(k * 9.0 + float3(0.0, 0.8, 1.6))) * exp(-k * k * 1.5);
        c += (corona * thin * 0.12 + lin(float3(0.8, 0.84, 1.0)) * thin * exp(-d / (r * 3.0)) * 0.5) * shade;
    }
    if (scene == 2) {
        float2 fw = pt / WORLD;
        float mist = fbm2(fw * float2(1.2, 3.5) + float2(t * 0.06, 0.0), 5);
        float mist2 = fbm2(fw * float2(2.4, 6.0) - float2(t * 0.11, 0.0) + 7.0, 4);
        float band = smoothstep(0.35, 1.0, in.uv.y);
        float a = band * saturate(mist * 1.2 - 0.15) * 0.55 + band * band * 0.12 + mist2 * 0.06;
        c = mix(c, lin(float3(0.42, 0.46, 0.50)), saturate(a));
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
    if (layer == 2 && hash11(fi * 5.7) < 0.3) { width = 5.0; alpha = 0.035; len = 90.0; }
    speed *= 0.85 + 0.3 * hash11(fi * 2.9);
    float gust = 0.17 + 0.06 * sin(t * 0.37) + 0.03 * sin(t * 1.21 + 1.3);
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
    o.alpha = b.y * (b.x / w) * (1.0 - 0.92 * textMask(u, p));
    return o;
}

fragment float4 skyRainFragment(RainOut in [[stage_in]]) {
    float across = 1.0 - in.local.x * in.local.x;
    float along = smoothstep(0.0, 0.75, in.local.y) * smoothstep(1.0, 0.9, in.local.y);
    float a = across * across * along * in.alpha;
    return float4(lin(float3(0.78, 0.85, 0.92)) * a * 1.4, 0.0);
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
        float T = trans.sample(cs, s).r;
        float2 dd = (s - lu) * aspect;
        float src = exp(-dot(dd, dd) / (rad * rad));
        illum += T * src * decay;
        decay *= 0.965;
    }
    illum /= float(n);
    float3 col = int(u.view.w) == 1 ? lin(float3(1.0, 0.95, 0.85)) : lin(float3(0.75, 0.8, 1.0));
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
    float shade = 1.0 - 0.85 * textMask(u, pt, 2.5, scene == 1 ? 1 : 0);
    c += (bloom.sample(s, in.uv).rgb * u.tone.w + rays.sample(s, in.uv).rgb) * shade;

    if (scene == 1 && u.light.w > 0.5) {
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

    for (int k = 1; k <= 2; k++) {
        float m = textMask(u, pt, 1.0, k, k == 1 ? u.caps.z : u.caps.w, scene == 1);
        if (m <= 0.0) continue;
        float cap = k == 1 ? u.caps.x : u.caps.y, knee = cap * 0.75;
        float L = lum(c);
        float Lc = L < knee ? L : knee + (cap - knee) * (1.0 - exp(-(L - knee) / (cap - knee)));
        float ratio = mix(1.0, Lc / max(L, 1e-6), m);
        c *= ratio;
        // 낮은 누르면 회색으로 죽는다 — 눌린 만큼 채도를 올려 더 깊은 하늘색으로.
        if (scene == 1) c = max(lum(c) + (c - lum(c)) * (1.0 + 0.9 * (1.0 - ratio)), 0.0);
    }
    float L;

    float head = max(u.tone.x, 1.0);
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
