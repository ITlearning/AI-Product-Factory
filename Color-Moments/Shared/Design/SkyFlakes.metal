#include <metal_stdlib>
using namespace metal;

// 꽃잎·낙엽 — 입자 상태를 정점 셰이더에서 시간 t 로 바로 계산한다(버퍼 없음, 같은 t 같은 자리).
// SkyShader.metal 의 SkyU 와 배치가 같아야 한다(float4 × 20) — SkyU 에 필드를 넣으면 여기도.
struct FlakeU {
    float4 res, view, light, quality, tone, parallax, rays, moon, meteor0, meteor1, blend, sun, caps, extra, textBig, win;
    float4 text[4];
};

#define FS_PETALS 10
#define FS_LEAVES 11

static float3 flin(float3 c) { return pow(c, float3(2.2)); }
static float flum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

static float fh(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

static float fTextDistance(constant FlakeU& u, float2 pt) {
    float m = 1e4;
    int n = int(u.parallax.z);
    for (int i = 0; i < n; i++) {
        float4 r = u.text[i];
        float2 d = max(r.xy - pt, pt - r.zw);
        m = min(m, length(max(d, 0.0)) + min(max(d.x, d.y), 0.0));
    }
    return m;
}

static float3x3 axisAngle(float3 a, float th) {
    float c = cos(th), s = sin(th), k = 1.0 - c;
    return float3x3(float3(c + a.x * a.x * k, a.y * a.x * k + a.z * s, a.z * a.x * k - a.y * s),
                    float3(a.x * a.y * k - a.z * s, c + a.y * a.y * k, a.z * a.y * k + a.x * s),
                    float3(a.x * a.z * k + a.y * s, a.y * a.z * k - a.x * s, c + a.z * a.z * k));
}

// 돌풍 — 슬롯(P 초)마다 한 번, 한 방향으로 쓸어 간다. n + 진행(0~1) 이라 끊김 없이 쌓인다.
static float gustAt(float t, float P, float dur, thread float& bump) {
    float n = floor(t / P);
    float st = n * P + P * (0.12 + 0.4 * fh(n * 3.1 + 1.7));
    float s = saturate((t - st) / dur);
    bump = sin(M_PI_F * s);
    return n + s * s * (3.0 - 2.0 * s);
}

struct Leaf {
    float2 pos;
    float3x3 R;
    float size;
    int layer;
    float alpha, lod, haze;
};

static Leaf leafAt(constant FlakeU& u, uint i, float t) {
    bool petal = int(u.view.w) == FS_PETALS;
    float W = u.view.x, H = u.view.y;
    float fi = float(i);
    float r0 = fh(fi * 1.31 + 0.7);
    float h1 = fh(fi * 2.9 + 0.3), h2 = fh(fi * 5.7 + 1.1), h3 = fh(fi * 7.7 + 2.3);
    float h4 = fh(fi * 3.3 + 4.1), h5 = fh(fi * 9.1 + 0.9), h6 = fh(fi * 4.4 + 6.6), h7 = fh(fi * 6.1 + 3.2);
    Leaf o;
    o.layer = r0 < 0.5 ? 0 : (r0 < 0.84 ? 1 : 2);
    float L = float(o.layer);
    float size, vy, vx, swayA, swayW, spin, gustA, lift;
    if (petal) {
        size = o.layer == 0 ? 2.3 + 0.8 * h1 : (o.layer == 1 ? 3.9 + 1.3 * h1 : 7.5 + 3.0 * h1);
        vy = (o.layer == 0 ? 10.0 : (o.layer == 1 ? 17.0 : 30.0)) * (0.7 + 0.6 * h2);
        vx = (o.layer == 0 ? 13.0 : (o.layer == 1 ? 22.0 : 40.0)) * (0.7 + 0.6 * h3);
        swayA = (o.layer == 0 ? 6.0 : (o.layer == 1 ? 11.0 : 20.0)) * (0.6 + 0.8 * h4);
        swayW = 1.5 + 1.2 * h5;
        spin = (2.0 + 2.6 * h6) * (h7 < 0.5 ? -1.0 : 1.0);
        gustA = 120.0 * (0.55 + 0.25 * L);
        lift = 26.0 * (0.5 + 0.4 * L);
    } else {
        size = o.layer == 0 ? 3.6 + 1.4 * h1 : (o.layer == 1 ? 6.2 + 2.4 * h1 : 12.0 + 5.0 * h1);
        vy = (o.layer == 0 ? 15.0 : (o.layer == 1 ? 27.0 : 48.0)) * (0.75 + 0.5 * h2);
        vx = (o.layer == 0 ? 5.0 : (o.layer == 1 ? 9.0 : 16.0)) * (0.5 + h3);
        swayA = (o.layer == 0 ? 8.0 : (o.layer == 1 ? 15.0 : 28.0)) * (0.6 + 0.8 * h4);
        swayW = 0.8 + 0.7 * h5;
        spin = (0.7 + 1.1 * h6) * (h7 < 0.5 ? -1.0 : 1.0);
        gustA = 95.0 * (0.55 + 0.25 * L);
        lift = 10.0 * (0.5 + 0.4 * L);
    }
    float m = 30.0 + size * 2.0;
    float spanX = W + 2.0 * m, spanY = H + 2.0 * m;
    float xb = fract((h4 * spanX + vx * t) / spanX) * spanX;
    // 돌풍 앞머리가 왼쪽에서 오른쪽으로 지나간다 — 왼쪽 잎부터 쓸린다.
    float bump;
    float g = gustAt(t - xb / 300.0, petal ? 8.0 : 10.0, petal ? 3.2 : 2.6, bump);
    float ph = t * swayW + h5 * 6.2832;
    float swing = sin(ph);
    float glide = 0.15 * swayA * sin(2.0 * ph);
    float sp = t * (0.5 + 0.5 * h3) + h2 * 6.2832;
    float spiral = (petal ? 3.0 : 5.0) * (0.5 + L) * h6;
    float x = fract((h4 * spanX + vx * t + gustA * g) / spanX) * spanX - m + swayA * swing + spiral * cos(sp);
    float y = fract((h1 * spanY + vy * t + glide) / spanY) * spanY - m - lift * bump * (0.6 + 0.8 * h2);
    o.pos = float2(x, y) + u.parallax.xy * (0.3 + 0.45 * L);
    o.size = size * (1.0 + 0.06 * sin(sp));

    float a = h6 * 6.2832;
    float3 axis = normalize(float3(cos(a), sin(a), (h3 - 0.5) * 0.7));
    float tumble = h1 * 6.2832 + spin * t + (petal ? 3.0 : 2.0) * g * (h7 < 0.5 ? -1.0 : 1.0);
    float roll = h2 * 6.2832 + (petal ? 0.5 : 0.75) * cos(ph);
    o.R = axisAngle(float3(0, 0, 1), roll) * axisAngle(axis, tumble);
    o.alpha = o.layer == 0 ? 0.8 : (o.layer == 1 ? 0.97 : 0.9);
    o.lod = o.layer == 2 ? (petal ? 1.0 : 1.4) + 0.6 * h4 : 0.0;
    o.haze = o.layer == 0 ? 0.24 : (o.layer == 1 ? 0.1 : 0.0);
    return o;
}

struct LeafOut {
    float4 pos [[position]];
    float2 local;
    float2 smear [[flat]];
    float3 T [[flat]];
    float3 B [[flat]];
    float3 N [[flat]];
    float2 center [[flat]];
    float4 look [[flat]];   // 알파, 흐림(밉 단계), 하늘 섞기, 종류(잎 칸 0~7 / 꽃잎 색 0~1)
};

vertex LeafOut skyLeafVertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant FlakeU& u [[buffer(0)]]) {
    float t = u.view.z;
    Leaf f = leafAt(u, iid, t);
    float dt = 1.0 / 60.0;
    Leaf p = leafAt(u, iid, t - dt);
    float2 v = (f.pos - p.pos) / dt;
    if (length(v) > 1500.0) v = float2(0.0);
    float pxPerPt = u.res.x / u.view.x;
    float size = max(f.size, 1.0 / pxPerPt);
    float3 T = f.R[0], B = f.R[1];
    float2x2 M = float2x2(T.xy * size, B.xy * size);
    float det = determinant(M);
    float2 blur = v * (1.0 / 45.0);
    float bl = length(blur);
    if (bl > size * 0.9) blur *= size * 0.9 / bl;
    float2 dl = float2(0.0);
    if (abs(det) > 0.12 * size * size && length(blur) > 0.6) {
        float2x2 inv = float2x2(float2(M[1][1], -M[0][1]), float2(-M[1][0], M[0][0])) / det;
        dl = inv * blur;
        dl = clamp(dl, -1.2, 1.2);
    }
    float pad = 1.0 + (f.layer == 2 ? 0.25 : 0.04);
    float2 corner = float2((vid & 1) ? 1.0 : -1.0, (vid & 2) ? 1.0 : -1.0);
    float2 lc = corner * pad + sign(corner) * abs(dl) * 0.5;
    float2 q = M * lc;
    float2 pt = f.pos + q;
    LeafOut o;
    o.pos = float4(pt.x / u.view.x * 2.0 - 1.0, 1.0 - pt.y / u.view.y * 2.0, 0.0, 1.0);
    o.local = lc;
    o.smear = dl;
    o.T = T; o.B = B; o.N = f.R[2];
    o.center = f.pos;
    float kind = int(u.view.w) == FS_PETALS ? fh(float(iid) * 8.3 + 0.4) : floor(fh(float(iid) * 8.3 + 0.4) * 7.999);
    // 글자 자리 앞에서 잎마다 통째로 옅어진다 — 조각을 자리 경계에서 자르면 글자 상자 모양이 드러난다.
    float reach = size * 2.6;
    float keep = smoothstep(reach, reach + 28.0, fTextDistance(u, f.pos));
    o.look = float4(f.alpha * (size > f.size ? f.size / size : 1.0) * keep, f.lod, f.haze, kind);
    return o;
}

// 벚꽃잎 — 끝이 패인 거꿀달걀꼴, 밑동 진분홍 → 끝 흰빛, 부채꼴 잎맥, 오목한 면.
static float4 petalSample(float2 l, float aa, float hue, thread float3& nT) {
    float s = -l.y;
    float xs = l.x / (0.34 + 0.66 * smoothstep(-1.05, 0.15, s));
    float ang = atan2(l.x, s + 1.25);
    float sd = length(float2(xs / 0.74, (s - 0.12) / 0.9)) - 1.0;
    sd += 0.025 * sin(ang * 11.0 + hue * 20.0) * smoothstep(0.2, 0.9, s);
    float notch = length(float2(l.x * 1.7, s - 0.98)) - 0.2;
    float a = (1.0 - smoothstep(-aa, aa, sd)) * smoothstep(-aa, aa, notch);
    if (a <= 0.0) return float4(0.0);
    float3 base = mix(flin(float3(0.9, 0.42, 0.58)), flin(float3(0.93, 0.55, 0.68)), hue);
    float3 mid = mix(flin(float3(0.98, 0.74, 0.82)), flin(float3(0.99, 0.84, 0.89)), hue);
    float3 tip = flin(float3(1.0, 0.93, 0.95));
    float3 c = s < 0.0 ? mix(base, mid, smoothstep(-1.0, 0.0, s)) : mix(mid, tip, smoothstep(0.0, 0.9, s));
    float vein = 0.5 + 0.5 * cos(ang * 44.0 + 2.5 * sin(ang * 6.0 + hue * 9.0));
    c *= 1.0 - 0.07 * vein * smoothstep(-0.8, 0.5, s);
    c *= 1.0 - 0.16 * smoothstep(-0.22, 0.0, sd);
    float rim = smoothstep(-0.35, 0.0, sd);
    nT = normalize(float3(-l.x * 0.6 - sign(l.x) * rim * 0.5, -(s - 0.1) * 0.25, 1.0));
    return float4(c, a);
}

fragment float4 skyLeafFragment(LeafOut in [[stage_in]], constant FlakeU& u [[buffer(0)]],
                                texture2d<float> colTex [[texture(0)]], texture2d<float> nrmTex [[texture(1)]]) {
    bool petal = int(u.view.w) == FS_PETALS;
    // 아틀라스 칸 여백이 12px — 더 굵은 밉은 옆 칸 잎이 번져 사각 테가 보인다.
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge, lod_clamp(0.0f, 3.0f));
    float lod = in.look.y;
    int taps = length(in.smear) > 0.05 ? 4 : 1;
    float4 acc = float4(0.0);
    float3 nAcc = float3(0.0);
    float2 cell = float2(fmod(in.look.w, 4.0), floor(in.look.w / 4.0));
    float aa = max(length(fwidth(in.local)) * 0.9, 0.02) + lod * 0.09;
    for (int k = 0; k < taps; k++) {
        float2 l = in.local + in.smear * (taps > 1 ? (float(k) / float(taps - 1) - 0.5) : 0.0);
        if (petal) {
            float3 nt = float3(0.0, 0.0, 1.0);
            float4 c = petalSample(l, aa, in.look.w, nt);
            acc += float4(c.rgb * c.a, c.a);
            nAcc += nt * c.a;
        } else {
            if (any(abs(l) > 1.0)) continue;
            float2 uv = (cell + l * 0.5 + 0.5) * float2(0.25, 0.5);
            float3 c = colTex.sample(s, uv, bias(lod)).rgb;
            float3 na = nrmTex.sample(s, uv, bias(lod)).xyz;
            float2 n = na.xy * 2.0 - 1.0;
            float al = na.z * smoothstep(1.0, 0.93, max(abs(l.x), abs(l.y)));
            acc += float4(c * al, al);
            nAcc += float3(n.x, -n.y, sqrt(saturate(1.0 - dot(n, n)))) * al;
        }
    }
    acc /= float(taps);
    float a = acc.a;
    if (a <= 0.002) discard_fragment();
    float3 alb = acc.rgb / a;
    float3 nt = normalize(nAcc + float3(0, 0, 1e-4));
    bool back = in.N.z < 0.0;
    float sgn = back ? -1.0 : 1.0;
    float3 Nw = normalize(in.T * nt.x + in.B * nt.y + in.N * nt.z) * sgn;
    float3 Ng = in.N * sgn;
    if (back) alb = mix(alb, float3(flum(alb)) * float3(1.04, 1.0, 0.9), petal ? 0.15 : 0.35) * (petal ? 1.05 : 1.12);

    float2 toSun = u.light.xy - in.center;
    float dSun = length(toSun);
    float3 S = normalize(float3(toSun / max(dSun, 1.0) * 0.75, -0.66));
    float nearSun = 0.4 + 0.9 * exp(-dSun / (0.55 * max(u.view.x, u.view.y)));
    float3 Lf = normalize(float3(-0.35, -0.7, 0.62));
    float3 sunC = petal ? flin(float3(1.0, 0.96, 0.92)) : flin(float3(1.0, 0.84, 0.6));
    float3 amb = petal ? flin(float3(0.8, 0.82, 0.92)) : flin(float3(0.86, 0.78, 0.72));
    float dif = saturate(dot(Nw, Lf));
    float3 col = alb * (amb * (0.55 + 0.25 * Nw.z) + sunC * dif * 0.55);
    float trans = saturate(dot(-Ng, S)) * nearSun;
    float3 thru = petal ? alb * flin(float3(1.0, 0.86, 0.9)) : alb * alb * 1.5;
    col += thru * sunC * trans * (petal ? 0.35 : 0.4) * (back ? 0.8 : 1.0);
    if (!petal) {
        float3 Rf = reflect(-Lf, Nw);
        col += sunC * pow(saturate(Rf.z), 28.0) * 0.06 * (back ? 0.3 : 1.0);
    }
    float3 hazeC = petal ? flin(float3(0.78, 0.8, 0.9)) : flin(float3(0.7, 0.62, 0.58));
    col = mix(col, hazeC, in.look.z);
    // 해를 등진 잎이 뒤집힐 때 흰색을 넘으면 EDR·블룸으로 반짝인다 — 무릎 위는 부드럽게 눌러 0.82 아래로.
    float mc = max(col.r, max(col.g, col.b));
    if (mc > 0.62) col *= (0.62 + 0.2 * (1.0 - exp(-(mc - 0.62) / 0.2))) / mc;
    a *= in.look.x;
    return float4(col * a, a);
}
