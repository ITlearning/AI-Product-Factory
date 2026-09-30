# 번들 글꼴 — 나눔명조 서브셋 · 고운돋움 · 버튼 세미볼드

`DESIGN.md` §2.2 — 명조는 **조약돌 이름 98개 + 워드마크 「몽돌」 + 사진 한 단어(`Shared/Word/words.json`)에만** 쓴다.
날짜·안내·캡션은 고운돋움, **버튼만 IBM Plex Sans KR SemiBold**다(아래).

| | |
|---|---|
| 원본 | Nanum Myeongjo Regular (Google Fonts) |
| 라이선스 | SIL Open Font License 1.1 — [`NanumMyeongjo-OFL.txt`](NanumMyeongjo-OFL.txt) |
| 서브셋 | 168자 (`subset-chars.txt`) |
| 크기 | 2,987KB → **56.4KB** (상한 100KB, `FontSubsetTests.testSubsetStaysSmall`) |

## 다시 만들 때

`PebbleName.swift` 의 이름이 바뀌면 또는 `words.json` 에 단어가 늘면, **글리프가 빠져 그 글자만 SF로 떨어진다.**
`FontSubsetTests` 가 그걸 잡지만, 잡히면 아래로 다시 굽는다.

```bash
pip install fonttools   # pyftsubset 셔뱅이 깨져 있으면 /usr/bin/python3 -m fontTools.subset
python3 - <<'PY'   # 필요한 글자 뽑기 — 조약돌 이름 + 워드마크 + 사진 한 단어
import re, json, pathlib
src = pathlib.Path("Shared/Day/PebbleName.swift").read_text()
words = json.loads(pathlib.Path("Shared/Word/words.json").read_text())["words"]
chars = set("".join(re.findall(r'name: "([^"]+)"', src))) | set("몽돌") | set("".join(w["word"] for w in words))
pathlib.Path("Shared/Design/Fonts/subset-chars.txt").write_text("".join(sorted(chars)))
PY

curl -L -o /tmp/nm.ttf https://github.com/google/fonts/raw/main/ofl/nanummyeongjo/NanumMyeongjo-Regular.ttf
pyftsubset /tmp/nm.ttf --text-file=Shared/Design/Fonts/subset-chars.txt \
  --output-file=Shared/Design/Fonts/NanumMyeongjo-Subset.ttf \
  --layout-features='' --no-hinting --desubroutinize \
  --name-IDs='0,1,2,3,4,5,6,13,14' --drop-tables+=DSIG
```

**전체 한글(2MB+)을 넣지 말 것.** 명조로 찍히는 글자는 200자 미만이다.

## 고운돋움 (본문)

| | 파일 | 담긴 것 | 크기 | 들어가는 타깃 |
|---|---|---|---|---|
| 원본 | Gowun Dodum Regular (Google Fonts) | | 7,229KB(7.2MB) | |
| 라이선스 | SIL OFL 1.1 — [`GowunDodum-OFL.txt`](GowunDodum-OFL.txt) | | | 모두 |
| 앱 | `GowunDodum-Hangul.ttf` | 한글 KS X 1001 2,350자(`gowun-ksx1001.txt`) + 호환 자모 + 라틴·숫자·구두점·기호 | 1,201KB | ColorMoments |
| 확장 | `GowunDodum-Mini.ttf` | 확장 소스에 나오는 한글(`gowun-mini-chars.txt`) + ASCII | 68KB | Capture·Control |

전체 11,172자는 6.8MB 라 2,350자만 담는다(2026-09-28 Tabber). 목록에 없는 드문 글자(똠·뷁 등)는 iOS 가 **그 글자만** 시스템 서체로 대신 그린다 — 깨지지 않는다. 앱 소스·`words.json` 의 한글은 전부 목록 안에 있다(새 문구에 드문 글자를 쓰면 확인).
둘은 PostScript 이름(`GowunDodum-Regular`)이 같다 — `Face` 는 타깃에 있는 쪽을 등록한다. 어느 타깃에 무엇이 가는지는 `project.yml` 의 `excludes`.

**`tnum`·`kern` 을 layout-features 에서 빼지 말 것** — `monospacedDigit()` 가 tnum 으로 간다.
캡처·위젯 화면(`CaptureScreen`·`ShotViewer`·`CaptureEngine`·`PebbleWidget`·`WidgetSnapshot`)에 한글 문구를 더하면 확장용 판을 다시 굽는다.
`FontSubsetTests.testExtensionSansCoversExtensionText` 가 빠진 글자를 잡는다.

```bash
curl -L -o /tmp/gd.ttf https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf
# pyftsubset 셸뱅이 깨져 있으면 python3 -m fontTools.subset 으로
python3 - <<'PY'   # KS X 1001 한글 2,350자 = EUC-KR 2바이트로 인코딩되는 음절
out = [chr(c) for c in range(0xAC00, 0xD7A4) if len(chr(c).encode('euc-kr', 'ignore')) == 2]
open("Shared/Design/Fonts/gowun-ksx1001.txt", "w").write("".join(out))
PY
python3 -m fontTools.subset /tmp/gd.ttf --text-file=Shared/Design/Fonts/gowun-ksx1001.txt \
  --unicodes="U+0020-007E,U+00A0-00FF,U+2010-206F,U+20A9,U+2190-2199,U+2460-2473,U+25A0-25FF,U+2600-26FF,U+3000-303F,U+3131-318E,U+FF01-FF5E" \
  --layout-features='kern,tnum,pnum,ccmp,locl,mark,mkmk' --no-hinting --desubroutinize \
  --name-IDs='0,1,2,3,4,5,6,13,14' --drop-tables+=DSIG,vhea,vmtx \
  --output-file=Shared/Design/Fonts/GowunDodum-Hangul.ttf

python3 - <<'PY'   # 확장 소스의 한글만
import re, pathlib
files = ["Shared/Capture/CaptureScreen.swift", "Shared/Capture/ShotViewer.swift", "Shared/Capture/CaptureEngine.swift",
         "ColorMomentsControl/PebbleWidget.swift", "Shared/Widget/WidgetSnapshot.swift", "ColorMomentsCapture/ViewFinder.swift"]
chars = set()
for f in files: chars |= set(re.findall(r'[가-힣]', pathlib.Path(f).read_text()))
pathlib.Path("Shared/Design/Fonts/gowun-mini-chars.txt").write_text("".join(sorted(chars)))
PY
python3 -m fontTools.subset /tmp/gd.ttf --text-file=Shared/Design/Fonts/gowun-mini-chars.txt \
  --unicodes="U+0020-007E,U+00B7,U+2013,U+2014,U+2026" --layout-features='kern,tnum,pnum' \
  --no-hinting --desubroutinize --name-IDs='0,1,2,3,4,5,6,13,14' --drop-tables+=DSIG,vhea,vmtx \
  --output-file=Shared/Design/Fonts/GowunDodum-Mini.ttf
```

## 버튼 세미볼드 (IBM Plex Sans KR SemiBold)

고운돋움은 굵기가 Regular 하나뿐이라 버튼(`Face.action`·온보딩 `PrimaryAction`/`SecondaryAction`)만 다른 글꼴을 쓴다.
IBM Plex Sans KR SemiBold(Google Fonts, SIL OFL)를 골랐다 — 고운돋움과 결이 맞으면서 「너무 쎈 볼드」는 아니다(2026-09-28 Tabber).
후보로 Gothic A1 SemiBold도 받아 봤으나 더 딱딱해 채택하지 않았다.

| | 파일 | 담긴 것 | 크기 | 들어가는 타깃 |
|---|---|---|---|---|
| 원본 | IBM Plex Sans KR SemiBold (Google Fonts) | | 2,787KB(2.7MB) | |
| 라이선스 | SIL OFL 1.1 — [`IBMPlexSansKR-OFL.txt`](IBMPlexSansKR-OFL.txt) | | | ColorMoments |
| 앱 | `IBMPlexSansKR-SemiBold-Subset.ttf` | 버튼 문구 글자만(`button-chars.txt`, 숫자·라틴·기본 구두점 포함) | 16KB | ColorMoments |

**버튼 문구는 소스에 고정돼 있다** — 새 버튼을 추가하거나 문구를 바꾸면 `button-chars.txt`를 다시 뽑고 서브셋을 다시 굽는다.
빠뜨리면 그 버튼만 SF로 떨어진다. `FontSubsetTests.testActionBoldCoversOnboardingButtonText`(온보딩 `PrimaryAction`/`SecondaryAction`/`CloudStep(actionTitle:)`를 소스에서 정적으로 추출)와
`testActionBoldCoversFixedActionLabels`(문자열 보간이 있는 「닫기」「설정 열기」「담기 N」)이 빠진 글자를 잡는다.
위젯·캡처 확장엔 버튼이 없어 `project.yml` excludes로 앱 타깃에만 넣는다.

```bash
python3 - <<'PY'   # 버튼 스타일(Face.action·PrimaryAction·SecondaryAction·CloudStep actionTitle)에 쓰는 문자열을 grep 해 채운다
strings = [
    "닫기", "담기 ", "설정 열기", "다음", "사진 보기", "이 사진으로 받기",
    "직접 고르기", "알려 주세요", "적어 주세요", "괜찮아요", "이어서 보기", "지금 한 장 남겨보기", "시작하기",
    "내 조약돌 보러 가기",
]
chars = set()
for s in strings: chars |= set(s)
chars |= set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
chars |= set(" .,!?~·-()")
open("Shared/Design/Fonts/button-chars.txt", "w").write("".join(sorted(chars)))
PY

curl -L -o /tmp/ibmplex.ttf https://github.com/google/fonts/raw/main/ofl/ibmplexsanskr/IBMPlexSansKR-SemiBold.ttf
python3 -m fontTools.subset /tmp/ibmplex.ttf --text-file=Shared/Design/Fonts/button-chars.txt \
  --layout-features='kern,tnum,pnum,ccmp,locl,mark,mkmk' --no-hinting --desubroutinize \
  --name-IDs='0,1,2,3,4,5,6,13,14' --drop-tables+=DSIG \
  --output-file=Shared/Design/Fonts/IBMPlexSansKR-SemiBold-Subset.ttf
```
