"""선생(로컬 모델·Claude)이 똑같이 받을 물음을 사진마다 만든다. 결과: ~/mongdol-word-lab/prompts/<key>.txt
후보는 judge 가 허락한 단어 전부, 순서는 사진마다 고정 시드로 섞는다(앞 후보를 고르는 버릇을 흩뜨린다)."""
import json
import os
import random
import sys

LAB = os.path.expanduser("~/mongdol-word-lab")
TRAIN = "--train" in sys.argv
rows = json.load(open(f"{LAB}/{'train' if TRAIN else 'eval'}.json"))
words = {w["id"]: w for w in json.load(open(f"{LAB}/words.json"))}
# --color: 색채 없는 말(plain_words.txt)을 뒤 묶음으로 따로 보인다.
COLOR = "--color" in sys.argv or "--balance" in sys.argv
# --balance: 맞는 말이 먼저, 둘 다 맞을 때만 결 있는 말. 보금자리가 「포근한 아무 곳」으로 둘러대는 말이 되지 않게 뜻을 좁힌다.
BALANCE = "--balance" in sys.argv
OUT = f"{LAB}/prompts-train" if TRAIN else f"{LAB}/prompts-balance" if BALANCE else f"{LAB}/prompts-color" if COLOR else f"{LAB}/prompts"
NARROW = {"보금자리": "사람이 살며 쉬는 집 안이나 잠자리 (카페·가게·바깥은 아니다)"}
here = os.path.dirname(os.path.abspath(__file__))
PLAIN = {t for l in open(f"{here}/plain_words.txt") if not l.startswith("#") for t in l.split()}
os.makedirs(OUT, exist_ok=True)

SEASON = {"spring": "봄", "summer": "여름", "autumn": "가을", "winter": "겨울"}

INSTRUCTIONS = """사진 일기 앱 「몽돌」이 사진 한 장에 붙일 순우리말 한 단어를 후보 가운데 하나 고른다.
몽돌의 단어는 사진을 설명하는 이름표가 아니라, 그 순간을 조용히 불러 주는 말이다.

고르는 순서:
1. 사진을 직접 보고, 이 사진의 주인공(무엇을 찍었나)과 그 순간(무엇을 하던 때인가)을 먼저 알아본다.
2. 주인공이나 순간을 가장 잘 불러 주는 단어를 고른다.
3. 그런 단어가 없을 때만 찍은 때·날씨·계절을 말하는 단어로 간다.
COLOR_RULE4. 사진에 보이지 않는 것을 말하는 단어는 고르지 않는다. 후보에 없는 말은 답에 쓰지 않는다.

후보에는 없지만 이 사진에 훨씬 잘 맞는 순우리말이 떠오르면 따로 하나 적는다(없으면 비운다).

답은 JSON 한 줄로만:
{"see": "사진에 보이는 것 한 줄", "word": "후보 중 한 단어", "outside": "목록 밖 단어 또는 빈 문자열"}"""


def meaning(i):
    return NARROW.get(words[i]["word"], words[i]["meaning"]) if BALANCE else words[i]["meaning"]


def prompt(r):
    lines = [f"찍은 때: {r['local']} ({r['partOfDay']}), {SEASON[r['season']]}"]
    if r.get("weather"):
        c = r.get("celsius")
        lines.append(f"날씨: {r['weather']}" + (f" {round(c)}°" if c is not None else ""))
    if r.get("place"):
        lines.append(f"곳: {r['place']}")
    ids = list(r["allowed"])
    random.Random(r["key"]).shuffle(ids)
    if COLOR:
        vivid = [i for i in ids if words[i]["word"] not in PLAIN]
        plain = [i for i in ids if words[i]["word"] in PLAIN]
        lines.append(f"후보 — 결이 있는 말 {len(vivid)}개:")
        lines += [f"- {words[i]['word']}: {meaning(i)}" for i in vivid]
        lines.append((f"후보 — 이름표 같은 말 {len(plain)}개:" if BALANCE else f"후보 — 이름표 같은 말 {len(plain)}개 (위 묶음에 맞는 말이 없을 때만):"))
        lines += [f"- {words[i]['word']}: {meaning(i)}" for i in plain]
    else:
        lines.append(f"후보 {len(ids)}개:")
        lines += [f"- {words[i]['word']}: {meaning(i)}" for i in ids]
    if BALANCE:
        rule4 = ("사진에 맞는 말인지가 먼저다. 결 있는 말이 사진과 조금이라도 어긋나면, 맞는 이름표 같은 말을 고른다.\n"
                 "   둘 다 사진에 꼭 맞을 때만 이름표 같은 말보다 빛·움직임·마음결이 담긴 말을 고른다.\n")
    else:
        rule4 = ("사물이나 때의 이름을 그대로 부르는 말(이름표 같은 말)보다, 빛·움직임·마음결이 담긴 말을 먼저 고른다.\n"
                 "   사진에 맞는 결 있는 말이 없을 때만 이름표 같은 말로 간다.\n")
    return INSTRUCTIONS.replace("COLOR_RULE4.", ("4. " + rule4 + "5.") if COLOR else "4.") + "\n\n" + "\n".join(lines)


for r in rows:
    open(f"{OUT}/{r['key']}.txt", "w").write(prompt(r))
print(len(rows), "개")
print(prompt(rows[0])[:1800])
