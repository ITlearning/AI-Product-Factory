"""넓어진 단어 목록(기존 170 + 사전에서 고른 말)으로 선생을 두 번 묻는다.
1) 사진의 장면 갈래 최대 3개 → 2) 그 갈래의 새 말 + judge 가 허락한 기존 말 중 한 단어.
새 말에는 아직 시각·날씨 조건이 없다 — 선생이 찍은 때를 보고 가린다.
실행: python teacher_expanded.py → answers/qwen35-expanded/<key>.json"""
import json
import os
import random
import re
import time

from mlx_vlm import apply_chat_template, generate, load
from mlx_vlm.utils import load_config

LAB = os.path.expanduser("~/mongdol-word-lab")
MODEL = "mlx-community/Qwen3.5-35B-A3B-4bit"
OUT = f"{LAB}/answers/qwen35-expanded"
os.makedirs(OUT, exist_ok=True)
rows = json.load(open(f"{LAB}/eval.json"))
vocab = json.load(open(f"{LAB}/words-expanded.json"))
old = {w["id"]: w for w in vocab if not w["new"]}
new_by_cat = {}
for w in vocab:
    if w["new"]:
        new_by_cat.setdefault(w["cat"], []).append(w)

CATS = {
    "빛·하늘": "빛, 그림자, 하늘, 구름, 해·달·별", "날씨": "비, 눈, 바람, 안개, 더위·추위", "계절": "계절의 기척",
    "때": "새벽·아침·낮·저녁·밤 같은 때", "물·땅": "바다, 강, 개울, 물결, 돌, 들판", "꽃·풀·나무": "꽃, 풀, 나무, 잎",
    "동물": "고양이, 개, 새, 벌레", "먹는 일": "밥, 간식, 술, 먹는 순간", "모임·사람": "여럿이 모인 자리, 사람, 아이",
    "집·살림": "집 안, 살림, 쉬는 자리", "길·마을": "길, 골목, 동네, 가게", "일·놀이": "일하거나 노는 순간",
    "마음·순간": "몸짓, 잠, 웃음 같은 순간의 결", "물건": "옷, 그릇, 물건",
}
SEASON = {"spring": "봄", "summer": "여름", "autumn": "가을", "winter": "겨울"}

STEP1 = """사진 일기 앱 「몽돌」이 이 사진에 붙일 순우리말을 찾으려 한다. 먼저 이 사진이 어떤 장면인지 아래 갈래 가운데 가장 잘 맞는 것을 1~3개 고른다.
{cats}

{when}
답은 JSON 한 줄로만: {{"see": "사진에 보이는 것 한 줄", "cats": ["갈래", ...]}}"""

STEP2 = """사진 일기 앱 「몽돌」이 사진 한 장에 붙일 순우리말 한 단어를 후보 가운데 하나 고른다.
몽돌의 단어는 사진을 설명하는 이름표가 아니라, 그 순간을 조용히 불러 주는 말이다.

고르는 순서:
1. 사진을 직접 보고, 이 사진의 주인공(무엇을 찍었나)과 그 순간(무엇을 하던 때인가)을 먼저 알아본다.
2. 주인공이나 순간을 가장 잘 불러 주는 단어를 고른다.
3. 그런 단어가 없을 때만 찍은 때·날씨·계절을 말하는 단어로 간다.
4. 사진에 보이지 않는 것, 찍은 때와 어긋나는 것(낮 사진에 밤 말, 여름 사진에 겨울 말)을 말하는 단어는 고르지 않는다. 후보에 없는 말은 답에 쓰지 않는다.

{when}
후보 {n}개:
{cands}

답은 JSON 한 줄로만: {{"see": "사진에 보이는 것 한 줄", "word": "후보 중 한 단어"}}"""


def when(r):
    s = f"찍은 때: {r['local']} ({r['partOfDay']}), {SEASON[r['season']]}"
    if r.get("weather"):
        s += f"\n날씨: {r['weather']}"
    return s


def ask(model, processor, config, text, image, tokens):
    prompt = apply_chat_template(processor, config, text, num_images=1, enable_thinking=False)
    out = generate(model, processor, prompt, image=[image], max_tokens=tokens, temperature=0.0)
    out = getattr(out, "text", out)
    found = re.search(r"\{.*\}", out, re.S)
    try:
        return json.loads(found.group(0)) if found else {}, out
    except json.JSONDecodeError:
        return {}, out


model, processor = load(MODEL)
config = load_config(MODEL)
cat_text = "\n".join(f"- {k}: {v}" for k, v in CATS.items())
for r in rows:
    path = f"{OUT}/{r['key']}.json"
    if os.path.exists(path):
        continue
    image = f"{LAB}/photos/{r['key']}.jpg"
    t = time.time()
    a1, raw1 = ask(model, processor, config, STEP1.format(cats=cat_text, when=when(r)), image, 150)
    cats = [c for c in a1.get("cats", []) if c in CATS][:3] or ["마음·순간"]
    cands = [old[i] for i in r["allowed"] if i in old] + [w for c in cats for w in new_by_cat.get(c, [])]
    random.Random(r["key"]).shuffle(cands)
    lines = "\n".join(f"- {w['word']}: {w['meaning']}" for w in cands)
    a2, raw2 = ask(model, processor, config, STEP2.format(when=when(r), n=len(cands), cands=lines), image, 200)
    word = a2.get("word", "").strip()
    hit = next((w for w in cands if w["word"] == word), None)
    json.dump({"word": word, "id": hit["id"] if hit else None, "new": bool(hit and hit["new"]), "cats": cats,
               "candidates": len(cands), "see": a2.get("see", a1.get("see", "")), "raw": raw2,
               "seconds": round(time.time() - t, 1)}, open(path, "w"), ensure_ascii=False)
    print(r["key"], cats, word, "(새 말)" if hit and hit["new"] else "", len(cands), round(time.time() - t, 1), flush=True)
