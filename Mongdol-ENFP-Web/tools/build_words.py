"""웹판 단어 목록을 앱의 words.json(v6)에서 뽑는다.

웹은 사진을 볼 모델이 없어서, 사진에 뭐가 찍혔든 날짜·시각만으로 참인 말만 쓴다.
  - 앱 규칙 경로의 「때」 단어(moment) 중 날씨·기온을 몰라도 판정되는 것
  - 날짜 사실 단어(DATE_WORDS) — 2026-10-06 Tabber 확정 73개. 웹에선 moment 로 표시한다
날씨·기온 조건이 붙은 말은 웹이 날씨를 모르니 뺀다(앱도 모르면 붙이지 않는다).

    python3 Mongdol-ENFP-Web/tools/build_words.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "Color-Moments/Shared/Word"
OUT = ROOT / "Mongdol-ENFP-Web/data"

DATE_WORDS = """
갓밝이 새벽 새벽녘 샐녘 늦새벽 어슴새벽 첫닭울이 새날 아침 새끼낮 새때 끼니때 보리저녁 저녁 저녁결 저녁녘 저녁때 다저녁때 저물녘 해름 햇덧 어스름 으스름 어스름밤 어둠 하룻밤 들마
설날 설맞이 설밑 작은설 까치설날 섣달 섣달그믐 한보름 수릿날 한가위 어린이날 어버이날 새해 새해맞이 장마철 보름 보름날 그믐
새봄 봄철 봄날 올봄 따지기 잔풀나기 꽃철 밭갈이철 배동바지 보리누름 여름 여름철 여름날 올여름 늦여름 긴긴날 가을 가을철 가을날 올가을 열매철 서릿가을 김장철 겨울 겨울날 올겨울 늦겨울 긴긴밤
""".split()

KEEP = ["id", "word", "meaning", "group", "moment", "rest", "fallback", "times", "hours", "seasons", "months",
        "weekdays", "lunar", "solar", "sunMin", "sunMax", "moonAges"]


def weathery(w):
    return w["weathers"] or w.get("needs") or w.get("conditions") or w.get("minCelsius") is not None \
        or w.get("maxCelsius") is not None


def main():
    src = json.loads((SRC / "words.json").read_text())
    by_word = {w["word"]: w for w in src["words"]}
    missing = [x for x in DATE_WORDS if x not in by_word]
    assert not missing, f"v6 에 없는 단어: {missing}"

    picked = {w["id"]: w for w in src["words"] if w.get("moment") and not weathery(w)}
    for x in DATE_WORDS:
        w = by_word[x]
        assert not weathery(w) and not w["subjects"], f"사진·날씨가 필요한 단어: {x}"
        picked[w["id"]] = {**w, "moment": True}

    words = [{k: w[k] for k in KEEP if w.get(k) not in (None, [], False)} for w in picked.values()]
    out = {"version": src["version"], "source": "Color-Moments/Shared/Word/words.json", "words": words}
    (OUT / "words.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n")

    lunar = json.loads((SRC / "lunar-days.json").read_text())
    used = {k for w in words for k in w.get("lunar", [])}
    days = {d: [k for k in ks if k in used] for d, ks in lunar["days"].items()}
    days = {d: ks for d, ks in days.items() if ks}
    (OUT / "lunar-days.json").write_text(json.dumps({"version": lunar["version"], "days": days}, separators=(",", ":")) + "\n")
    print(f"words {len(words)} (rest {sum(1 for w in words if w.get('rest'))}), lunar days {len(days)}")


if __name__ == "__main__":
    main()
