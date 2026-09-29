#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// docs/designs/tools/soft-pebble-reference.py 와 같은 그림. 윤곽 식을 바꾸면 SoftPebbleShape.rho 도 같이 바꾼다.
// 색 표(table)는 CPU 가 미리 채운다: 3줄 × LUT_N 칸 × RGB — 0 띠 색, 1 후광 색, 2 테두리 빛 색.

constant int LUT_N = 128;

static half3 lut(device const float *table, int row, float t) {
    float x = clamp(t, 0.0f, 1.0f) * float(LUT_N - 1);
    int i0 = min(int(x), LUT_N - 2);
    float f = x - float(i0);
    int k = (row * LUT_N + i0) * 3;
    float3 a = float3(table[k], table[k + 1], table[k + 2]);
    float3 b = float3(table[k + 3], table[k + 4], table[k + 5]);
    return half3(mix(a, b, f));
}

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// frame = (cos 기울기, sin 기울기, 달걀꼴, 돌 반지름 pt)
// wob23 = (cos φ2, sin φ2, cos φ3, sin φ3), wob5 = (cos φ5, sin φ5, 바닥 x, 바닥 y)
// look = (후광 세기, 바닥 번짐 세기, 픽셀 배율, 접지 그림자 세기)
// sheen = (반짝임 띠 중심, 반짝임 세기, -, -) — 증정 세리머니에서만 움직인다
[[ stitchable ]] half4 softPebble(float2 position, half4 color, float2 size,
                                  float4 frame, float4 wob23, float4 wob5, float4 look, float4 sheen,
                                  device const float *table, int count) {
    float2 fromCenter = (position - size * 0.5) / (size * 0.5);
    float window = 1.0 - smoothstep(0.72, 1.0, length(fromCenter));
    if (window <= 0.0) return half4(0.0h);

    float ct = frame.x, st = frame.y, egg = frame.z, radius = frame.w;
    float haloK = look.x, floorK = look.y, px = look.z;
    float2 X = (position - size * 0.5) / radius;

    // 윤곽 — 각도 배수는 삼각함수 없이 배각 공식으로
    float u = X.x * ct + X.y * st;
    float v = -X.x * st + X.y * ct;
    float den = 1.0 + egg * u;
    float vs = v / den;
    float ue = u / 1.04;
    float r0 = sqrt(ue * ue + vs * vs);
    float ra = sqrt(u * u + vs * vs) + 1e-6;
    float c1 = u / ra, s1 = vs / ra;
    float c2 = c1 * c1 - s1 * s1, s2 = 2.0 * s1 * c1;
    float c3 = c1 * (4.0 * c1 * c1 - 3.0), s3 = s1 * (3.0 - 4.0 * s1 * s1);
    float c5 = c2 * c3 - s2 * s3, s5 = s2 * c3 + c2 * s3;
    float wob = 1.0 + 0.012 * (c3 * wob23.z - s3 * wob23.w)
                    + 0.006 * (c5 * wob5.x - s5 * wob5.y)
                    + 0.012 * (c2 * wob23.x - s2 * wob23.y);
    float rho = r0 / wob;

    float alpha = clamp((1.0 - rho) * radius * px / 1.5, 0.0, 1.0);
    float2 pix = floor(position * px);

    half3 rgb = half3(0.0h);
    float a = 0.0;

    // 바깥(후광·바닥 번짐·접지 그림자) — 돌이 다 덮는 픽셀은 건너뛴다
    if (alpha < 1.0) {
        float d = max(rho - 1.0, 0.0);
        float halo = (0.34 * exp(-d * 5.0) + 0.30 * exp(-d * 1.7)) * haloK * window;
        float fx = X.x - wob5.z, fy = X.y - wob5.w;
        float fyn = fy / 0.22;
        float floorGlow = exp(-(fx * fx + fyn * fyn)) * 0.32 * floorK * window;
        float cx = fx / 0.55, cy = (fy + 0.02) / 0.07;
        float contact = exp(-(cx * cx + cy * cy)) * 0.85 * look.w;
        half3 glow = lut(table, 1, X.y * 0.45 + 0.5) * half(halo) + lut(table, 0, 1.0) * half(floorGlow);
        rgb = glow * half(1.0 - contact) * half(1.0 - alpha);
        a = contact * (1.0 - alpha);
    }

    // 돌 — 바깥 픽셀은 조명 계산을 하지 않는다
    if (alpha > 0.0) {
        float rp = pow(max(rho, 1e-4), 1.2);
        float z = sqrt(max(1.0 - rp * rho, 0.0));

        // 높이의 기울기를 해석적으로(울퉁불퉁의 미분은 무시 — 진폭이 작아 보이지 않는다)
        float dvs_du = -v * egg / (den * den);
        float inv = 1.0 / (r0 * wob + 1e-6);
        float dr_du = (ue / 1.04 + vs * dvs_du) * inv;
        float dr_dv = (vs / den) * inv;
        float dz_dr = -1.1 * rp / max(z, 1e-3);
        float gx = clamp(dz_dr * (dr_du * ct - dr_dv * st), -3.0, 3.0);
        float gy = clamp(dz_dr * (dr_du * st + dr_dv * ct), -3.0, 3.0);
        float3 n = normalize(float3(-gx, -gy, 1.0));
        const float3 L = float3(0.35221, -0.55347, 0.75473);
        float wrap = clamp((dot(n, L) + 0.45) / 1.45, 0.0, 1.0);

        const float sb = 0.309017, cb = 0.951057;   // 띠 방향 18°
        float along = X.x * sb + X.y * cb;
        half3 col = lut(table, 0, along * 0.5 + 0.5 - 0.07 * (z - 0.7));

        float lowY = clamp((X.y - 0.1) / 0.9, 0.0, 1.0);
        col *= half((0.70 + 0.38 * wrap) * (1.0 - 0.20 * lowY * lowY));

        float om = 1.0 - n.z;
        float fres = om * om * sqrt(om);
        col += lut(table, 2, X.y * 0.45 + 0.5) * half(fres * clamp(wrap * 1.4 - 0.2, 0.0, 1.0) * 0.26);
        col *= half(1.0 + (hash21(pix) - 0.5) * 0.055);

        if (sheen.y > 0.0) {
            float dq = X.x * 0.93969 + X.y * 0.34202 - sheen.x;   // 20° 기운 띠
            col += half((0.30 * exp(-dq * dq / 0.0324) + 0.07 * exp(-dq * dq / 0.25)) * sheen.y);
        }

        rgb += col * half(alpha);
        a += alpha;
    }

    rgb += half((hash21(pix + 17.0) - 0.5) * (1.5 / 255.0));
    return half4(max(rgb, 0.0h), half(a));
}
