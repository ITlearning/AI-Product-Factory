# 나눔명조 서브셋

`DESIGN.md` §2.2 — 명조는 **조약돌 이름 19개 + 워드마크 「몽돌」에만** 쓴다.
날짜·안내·버튼은 전부 SF다.

| | |
|---|---|
| 원본 | Nanum Myeongjo Regular (Google Fonts) |
| 라이선스 | SIL Open Font License 1.1 — [`NanumMyeongjo-OFL.txt`](NanumMyeongjo-OFL.txt) |
| 서브셋 | 37자 (`subset-chars.txt`) |
| 크기 | 2,987KB → **13.2KB** |

## 다시 만들 때

`PebbleName.swift` 의 이름이 바뀌면 **글리프가 빠져 그 이름만 SF로 떨어진다.**
`FontSubsetTests` 가 그걸 잡지만, 잡히면 아래로 다시 굽는다.

```bash
pip install fonttools
python3 - <<'PY'   # 필요한 글자 뽑기
import re, pathlib
src = pathlib.Path("Shared/Day/PebbleName.swift").read_text()
chars = set("".join(re.findall(r'name: "([^"]+)"', src))) | set("몽돌")
pathlib.Path("Shared/Design/Fonts/subset-chars.txt").write_text("".join(sorted(chars)))
PY

curl -L -o /tmp/nm.ttf https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Regular.ttf
pyftsubset /tmp/nm.ttf --text-file=Shared/Design/Fonts/subset-chars.txt \
  --output-file=Shared/Design/Fonts/NanumMyeongjo-Subset.ttf \
  --layout-features='' --no-hinting --desubroutinize \
  --name-IDs='0,1,2,3,4,5,6,13,14' --drop-tables+=DSIG
```

**전체 한글(2MB+)을 넣지 말 것.** 명조로 찍히는 글자는 40자 미만이다.
