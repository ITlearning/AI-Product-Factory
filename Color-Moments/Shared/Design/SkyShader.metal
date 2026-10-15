#include <metal_stdlib>
using namespace metal;

// SkyView.swift 의 SkyUniforms 와 같은 순서·크기(float4 × 11). 하나를 고치면 둘 다 고친다.
struct SkyU {
    float4 res;       // 그리는 대상 px w, h, 1/w, 1/h
    float4 view;      // pt w, h, 시간 t, 장면
    float4 light;     // 해·달 pt x, y, 원판 반지름 pt, 화면에 그림(1)/안 그림(0)
    float4 quality;   // 구름 걸음, 빛 걸음, 잔결(0/1), 먼 층 걸음
    float4 tone;      // EDR 여유, 글자 자리 최대 밝기, 그레인, 블룸 세기
    float4 parallax;  // 기울기 pt x, y, 글자 자리 수, 글자 자리 번짐 pt
    float4 rays;      // 빛줄기 걸음, 빛줄기 세기, 프레임 번호, 빗방울 수
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

static float textMask(constant SkyU& u, float2 pt, float spread = 1.0) {
    float m = 0.0;
    int n = int(u.parallax.z);
    float f = max(u.parallax.w * spread, 1.0);
    for (int i = 0; i < n; i++) {
        float4 r = u.text[i];
        float2 d = max(r.xy - pt, pt - r.zw);
        float sd = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
        m = max(m, 1.0 - smoothstep(0.0, f, sd));
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

static float3 skyColor(int scene, float2 uv, float2 pt, constant SkyU& u) {
    float y = saturate(uv.y);
    float d = distance(pt, u.light.xy) / WORLD;
    float shade = 1.0 - 0.85 * textMask(u, pt, 2.5);
    if (scene == 0) {
        float3 c = mix(lin(float3(0.085, 0.09, 0.17)), lin(float3(0.19, 0.205, 0.33)), smoothstep(-0.1, 1.1, y));
        c += lin(float3(0.62, 0.66, 0.85)) * (0.10 * exp(-d * 2.2) + 0.03 * exp(-d * 0.6)) * shade;
        return c;
    }
    if (scene == 1) {
        float3 c = mix(lin(float3(0.06, 0.20, 0.47)), lin(float3(0.16, 0.38, 0.68)), pow(y, 1.3));
        c += lin(float3(1.0, 0.96, 0.88)) * (0.35 * exp(-d * 6.0) + 0.06 * exp(-d * 1.6)) * shade;
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

fragment float4 skyClouds(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
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
    float3 S = nearL.rgb + nearL.a * farL.rgb;
    float T = nearL.a * farL.a;
    return float4(S, T);
}

// MARK: - 별

static float3 starField(float2 pt, float t, float pxPerPt, float2 tilt) {
    float3 acc = float3(0.0);
    for (int l = 0; l < 3; l++) {
        float cell = l == 0 ? 7.0 : (l == 1 ? 17.0 : 52.0);
        float prob = l == 0 ? 0.2 : (l == 1 ? 0.3 : 0.5);
        float sizePt = l == 0 ? 0.32 : (l == 1 ? 0.48 : 0.75);
        float bright = l == 0 ? 0.35 : (l == 1 ? 0.9 : 2.6);
        float2 p = pt + tilt * (0.15 + 0.35 * float(l)) + float2(t * (0.25 + 0.35 * float(l)), 0.0);
        float2 cid = floor(p / cell);
        float2 h = hash22(cid + 17.0 * float(l));
        float pick = hash12(cid * 1.7 + 31.0 * float(l));
        if (pick > prob) continue;
        float2 c = (cid + 0.18 + 0.64 * h) * cell;
        float2 dv = p - c;
        float sz = max(sizePt, 0.7 / pxPerPt);
        float b = bright * (0.45 + 0.55 * hash12(cid + 5.3)) * (sizePt / sz);
        float freq = 0.8 + 3.2 * hash12(cid + 9.1);
        float tw = 0.65 + 0.35 * sin(t * freq * (1.0 + float(l) * 0.4) + h.x * 40.0);
        float s = exp(-dot(dv, dv) / (sz * sz)) * b * tw;
        if (l == 2 && pick < prob * 0.14) {
            float2 a = abs(dv);
            float spike = exp(-a.y / 0.18) * exp(-a.x / 4.5) + exp(-a.x / 0.18) * exp(-a.y / 4.5);
            s += spike * 0.22 * b * tw;
        }
        float3 tint = mix(float3(1.0, 0.86, 0.70), float3(0.74, 0.84, 1.0), hash12(cid + 2.2));
        acc += s * mix(float3(1.0), tint, 0.55);
    }
    return acc;
}

// MARK: - 하늘 합성 (전체 해상도)

fragment float4 skyCompose(VOut in [[stage_in]], constant SkyU& u [[buffer(0)]],
                           texture2d<float> clouds [[texture(0)]]) {
    constexpr sampler cs(filter::linear, address::clamp_to_edge);
    int scene = int(u.view.w);
    float2 pt = in.uv * u.view.xy;
    float t = u.view.z;
    float pxPerPt = u.res.x / u.view.x;
    float mask = textMask(u, pt);
    float shade = 1.0 - 0.85 * textMask(u, pt, 2.5);
    float3 c = skyColor(scene, in.uv, pt, u);
    float2 ct = 0.6 / float2(clouds.get_width(), clouds.get_height());
    float4 cl = (clouds.sample(cs, in.uv + ct * float2(-1, -1)) + clouds.sample(cs, in.uv + ct * float2(1, -1))
               + clouds.sample(cs, in.uv + ct * float2(-1, 1)) + clouds.sample(cs, in.uv + ct * float2(1, 1))) * 0.25;
    float T = cl.a;
    float2 lp = u.light.xy + u.parallax.xy * 0.1;
    float d = distance(pt, lp);
    float r = u.light.z;

    if (scene == 0) {
        c += starField(pt, t, pxPerPt, u.parallax.xy) * T * (1.0 - 0.9 * mask);
        if (u.light.w > 0.5) {
            float2 q = (pt - lp) / r;
            float disk = 1.0 - smoothstep(1.0 - 1.2 / (r * pxPerPt), 1.0, length(q));
            float maria = fbm2(q * 2.3 + 4.0, 4);
            float limb = sqrt(saturate(1.0 - dot(q, q)));
            float3 moon = lin(float3(0.98, 0.96, 0.90)) * (0.72 + 0.28 * limb) * (1.0 - 0.32 * smoothstep(0.45, 0.75, maria));
            c = mix(c, moon * 3.2, disk);
        }
    } else if (scene == 1) {
        if (u.light.w > 0.5) {
            float core = exp(-pow(d / r, 4.0));
            c += lin(float3(1.0, 0.97, 0.9)) * core * 6.0;
            float ang = atan2(pt.y - lp.y, pt.x - lp.x);
            float burst = pow(abs(cos(ang * 3.0 + 0.3)), 60.0) + 0.6 * pow(abs(cos(ang * 4.0 + 1.1)), 90.0);
            c += lin(float3(1.0, 0.95, 0.85)) * burst * exp(-d / (r * 4.0)) * 0.55 * shade;
            float halo = WORLD * 0.42;
            float ring = (d - halo) / (WORLD * 0.022);
            float3 hc = float3(exp(-pow(ring + 0.6, 2.0)), exp(-ring * ring), exp(-pow(ring - 0.6, 2.0)));
            c += hc * 0.045 * smoothstep(WORLD * 0.9, WORLD * 0.2, d) * shade;
        }
    }

    c = c * T + cl.rgb;

    if (scene == 1) {
        float2 q = (pt + u.parallax.xy * 0.3) / WORLD * float2(0.8, 2.6) + float2(t * 0.012, 0.0);
        float2 warp = float2(fbm2(q * 1.3 + 1.7, 4), fbm2(q * 1.3 + 9.2, 4)) - 0.5;
        float body = fbm2(q + warp * 1.4, 5);
        float fiber = fbm2(float2(q.x * 0.7, q.y * 7.0) + warp * 3.0 + 4.1, 5);
        float a = smoothstep(0.48, 0.8, body) * (0.35 + 0.65 * smoothstep(0.3, 0.75, fiber));
        float lit = 0.28 + 1.1 * exp(-d / (WORLD * 0.45)) * shade;
        c = mix(c, lin(float3(0.86, 0.9, 0.97)) * lit, a * 0.55);
    }

    if (scene == 0 && u.light.w > 0.5) {
        float thin = saturate((1.0 - T) * T * 4.0);
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
                        texture2d<float> clouds [[texture(0)]]) {
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
        float T = clouds.sample(cs, s).a;
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
    float shade = 1.0 - 0.85 * textMask(u, pt, 2.5);
    c += (bloom.sample(s, in.uv).rgb * u.tone.w + rays.sample(s, in.uv).rgb) * shade;

    if (scene == 1 && u.light.w > 0.5) {
        float2 lp = u.light.xy;
        float2 center = u.view.xy * 0.5;
        float ks[3] = { 0.55, 1.35, 1.75 };
        float rs[3] = { 0.06, 0.035, 0.11 };
        float3 tints[3] = { float3(0.6, 0.8, 1.0), float3(1.0, 0.8, 0.6), float3(0.7, 1.0, 0.85) };
        for (int i = 0; i < 3; i++) {
            float2 g = lp + (center - lp) * ks[i];
            float gr = rs[i] * WORLD;
            float dd = distance(pt, g) / gr;
            c += lin(tints[i]) * 0.025 * smoothstep(1.0, 0.7, dd) * (0.6 + 0.4 * dd) * shade;
        }
    }

    float m = textMask(u, pt);
    float L = lum(c);
    float cap = u.tone.y, knee = cap * 0.75;
    float Lc = L < knee ? L : knee + (cap - knee) * (1.0 - exp(-(L - knee) / (cap - knee)));
    c *= mix(1.0, Lc / max(L, 1e-6), m);

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
