import numpy as np
import cv2
from PIL import Image

S = 1024


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255


def ramp(stops, t):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), np.float32)
    xs = [s[0] for s in stops]
    cs = [hexrgb(s[1]) for s in stops]
    out[:] = cs[0]
    for i in range(len(stops) - 1):
        m = (t >= xs[i]) & (t <= xs[i + 1])
        u = (t[m] - xs[i]) / max(1e-6, xs[i + 1] - xs[i])
        u = u * u * (3 - 2 * u)
        out[m] = cs[i] * (1 - u[:, None]) + cs[i + 1] * u[:, None]
    return out


def lighten(c, k):
    return c + (1 - c) * k


def even(hexes):
    return [(i / (len(hexes) - 1), h) for i, h in enumerate(hexes)]


# Gemini 아이콘에서 띠에 수직으로 샘플한 색
GEMINI = [(0.00, "#8e9ab0"), (0.22, "#8fa9c2"), (0.40, "#a9c6d8"), (0.48, "#bcd0dc"),
          (0.55, "#f2e6d2"), (0.60, "#f0d6bb"), (0.66, "#efc0a2"), (0.80, "#eea08c"), (1.00, "#b86a6c")]


def render(stops, *, tilt_deg=32, egg=0.22, wobble=(0.3, 0.6, 0.4), size=0.54,
           light=(0.35, -0.55, 0.75), band_deg=18, sag=-0.07,
           halo_k=1.0, floor_k=1.0, seed=3, bg_hex="#0a0b10", S=S):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    cx, cy = S * 0.5, S * 0.5
    half = S * size / 2
    X, Y = (xx - cx) / half, (yy - cy) / half

    # 윤곽: 기울어진 달걀꼴(+u 쪽이 넓다) + 약간의 울퉁불퉁
    a = np.deg2rad(tilt_deg)
    u = X * np.cos(a) + Y * np.sin(a)
    v = -X * np.sin(a) + Y * np.cos(a)
    vs = v / (1 + egg * u)
    th = np.arctan2(vs, u)
    wa, wb, wc = wobble
    wob = (1 + 0.012 * np.cos(3 * th + wa * 6.3) + 0.006 * np.cos(5 * th + wb * 6.3)
           + 0.012 * np.cos(2 * th + wc * 6.3))
    rho = np.sqrt((u / 1.04) ** 2 + vs ** 2) / wob
    inside = rho < 1
    z = np.sqrt(np.clip(1 - rho ** 2.2, 0, 1))

    # 돔의 법선
    zs = cv2.GaussianBlur(z, (0, 0), 2)
    gy, gx = np.gradient(zs)
    gx = np.clip(gx * half, -3, 3)
    gy = np.clip(gy * half, -3, 3)
    n = np.sqrt(gx ** 2 + gy ** 2 + 1)
    nx, ny, nz = -gx / n, -gy / n, 1 / n
    L = np.array(light, np.float32)
    L /= np.linalg.norm(L)
    ndl = nx * L[0] + ny * L[1] + nz * L[2]
    wrap = np.clip((ndl + 0.45) / 1.45, 0, 1)        # 부드럽게 감싸는 빛

    # 하루 색 띠: 오른쪽으로 오르며 곡면을 따라 가운데가 살짝 처진다
    b = np.deg2rad(band_deg)
    along = X * np.sin(b) + Y * np.cos(b)
    t = along * 0.50 + 0.50 + sag * (z - 0.7)
    base = ramp(stops, t)

    shade = 0.70 + 0.38 * wrap
    ao = 1 - 0.20 * np.clip((Y - 0.1) / 0.9, 0, 1) ** 2
    col = base * (shade * ao)[..., None]

    # 테두리: 어둡게가 아니라 주변 빛(후광 색)이 감싸며 밝아진다
    env = lighten(ramp(stops, np.clip(Y * 0.45 + 0.5, 0, 1)), 0.35)
    fres = (1 - nz) ** 2.5
    col = col + env * (fres * np.clip(wrap * 1.4 - 0.2, 0, 1) * 0.26)[..., None]

    # 고운 입자 + 윗부분에 드문 연한 점
    grain = cv2.GaussianBlur(rng.standard_normal((S, S)).astype(np.float32), (0, 0), 0.7) * 0.04
    col = col * (1 + grain)[..., None]
    fl = (rng.random((S, S)) > 0.9994).astype(np.float32)
    fl = cv2.GaussianBlur(fl, (0, 0), 1.3) * 6 * np.clip(-Y + 0.3, 0, 1)
    col = col + fl[..., None] * 0.12

    # 배경: 돌 색 그대로의 후광(가장자리에서 바로 시작) + 바닥 번짐 + 좁고 진한 접지 그림자
    bg = np.zeros((S, S, 3), np.float32) + hexrgb(bg_hex)
    d = np.clip(rho - 1, 0, None)
    halo = (0.34 * np.exp(-d * 5.0) + 0.30 * np.exp(-d * 1.7)) * halo_k
    hcol = cv2.GaussianBlur(lighten(ramp(stops, np.clip(Y * 0.45 + 0.5, 0, 1)), 0.10), (0, 0), half * 0.45)
    bg = bg + hcol * halo[..., None]
    ys, xs = np.nonzero(inside)
    bot, xm = ys.max(), xs.mean()
    floor = np.exp(-(((xx - xm) / half) ** 2 + ((yy - bot) / (half * 0.22)) ** 2))
    bg = bg + hexrgb(stops[-1][1]) * (floor * 0.32 * floor_k)[..., None]
    contact = np.exp(-(((xx - xm) / (half * 0.55)) ** 2 + ((yy - bot + half * 0.02) / (half * 0.07)) ** 2))
    bg = bg * (1 - 0.85 * contact)[..., None]

    alpha = np.clip((1 - rho) * half / 1.5, 0, 1)[..., None]
    img = col * alpha + bg * (1 - alpha)
    img += (rng.random(img.shape) - 0.5) / 255 * 1.5
    return np.clip(img, 0, 1)


def save(a, p):
    Image.fromarray((a * 255 + 0.5).astype(np.uint8)).save(p)


if __name__ == "__main__":
    g = np.array(Image.open("/Users/tabber/Downloads/Gemini_Generated_Image_4pt27m4pt27m4pt2-clean.png")
                 .convert("RGB").resize((S, S), Image.LANCZOS)).astype(np.float32) / 255
    save(np.concatenate([g, render(GEMINI)], 1), "out/soft-vs-gemini.png")

    days = [
        even(["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"]),
        even(["#7FB0DC", "#8CB8DE", "#6795BC", "#3C6A9B"]),
        even(["#5B7F5B", "#8FA36B", "#A79C87"]),
    ]
    shapes = [dict(tilt_deg=-20, egg=0.15, wobble=(0.1, 0.8, 0.2)),
              dict(tilt_deg=10, egg=0.26, wobble=(0.7, 0.3, 0.9)),
              dict(tilt_deg=48, egg=0.20, wobble=(0.5, 0.6, 0.4))]
    save(np.concatenate([render(d, **s) for d, s in zip(days, shapes)], 1), "out/soft-days.png")

    # 격자 크기(84pt ≈ 252px @3x)에서 — 후광 약하게 / 없이
    grid_days = [GEMINI] + days + [even(["#6B6261", "#887F7E", "#9D917C"])]
    grid_shapes = [dict(tilt_deg=32, egg=0.22)] + shapes + [dict(tilt_deg=-5, egg=0.18, wobble=(0.9, 0.2, 0.6))]
    rows = []
    for hk, fk in [(0.35, 0.6)]:
        rows.append(np.concatenate(
            [render(d, S=252, size=0.66, halo_k=hk, floor_k=fk, **s) for d, s in zip(grid_days, grid_shapes)], 1))
    save(np.concatenate(rows, 0), "out/soft-grid.png")
    print("ok")
