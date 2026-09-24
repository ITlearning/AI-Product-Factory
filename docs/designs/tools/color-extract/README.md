# 사진 1장 → 상징색 1개 · 추출 방식 비교 도구

2026-09-22 실측에 쓴 도구. Core Image + Vision만 쓰므로 iOS 앱에 그대로 이식된다.

```bash
swiftc -O -o extract extract.swift && ./extract ~/Downloads/*.HEIC   # 8개 방식 비교 + compare.html
swiftc -O -o clusters clusters.swift && ./clusters <이미지>           # k-means 클러스터를 hue/채도와 함께 덤프
swiftc -O -o hue hue.swift && ./hue <이미지들>                        # hue 대역 묶기 + 채도 증폭 실험
```

`measured-2026-09-22.json` 은 Tabber 사진 11장의 측정 결과 스냅샷이다.
결론과 기각된 방식은 [`../../color-moments.md`](../../color-moments.md) 「색 추출 실측」 참조.
