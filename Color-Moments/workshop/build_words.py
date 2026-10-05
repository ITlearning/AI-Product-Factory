"""words.json v6 — 기존 170개(그대로) + 공방에서 고른 새 단어. id 는 한 번 만들면 고정한다."""
import json
import os
import re
import subprocess
import sys

LAB = os.path.expanduser("~/mongdol-word-lab")
HERE = os.path.dirname(os.path.abspath(__file__))
WORDS_IN_REPO = "Color-Moments/Shared/Word/words.json"
CHO = "g kk n d tt r m b pp s ss  j jj ch k t p h".split(" ")
JUNG = "a ae ya yae eo e yeo ye o wa wae oe yo u wo we wi yu eu ui i".split(" ")
JONG = ["", "k", "k", "ks", "n", "nj", "nh", "t", "l", "lk", "lm", "lb", "ls", "lt", "lp", "lh", "m", "p", "ps",
        "t", "t", "ng", "t", "t", "k", "t", "p", "t"]
FIELDS = ["times", "hours", "sunMin", "sunMax", "needs", "weathers", "conditions", "seasons", "months",
          "minCelsius", "maxCelsius", "moonAges", "lunar", "solar"]

# PhotoEnrichment.look 이 아는 WeatherKit 이름 — 모르는 이름은 앱에서 날씨를 못 맞춰 그 단어가 영영 안 나온다.
APP_CONDITIONS = {"clear", "mostlyClear", "hot", "partlyCloudy", "mostlyCloudy", "cloudy", "drizzle", "rain", "heavyRain",
                  "sunShowers", "freezingRain", "freezingDrizzle", "sleet", "wintryMix", "snow", "flurries", "heavySnow",
                  "sunFlurries", "blowingSnow", "blizzard", "foggy", "haze", "smoky", "windy", "breezy", "thunderstorms",
                  "isolatedThunderstorms", "scatteredThunderstorms", "strongStorms"}


def app_conditions(cond):
    out = dict(cond)
    if "conditions" in out:
        out["conditions"] = [c for c in out["conditions"] if c in APP_CONDITIONS]
        if not out["conditions"]:
            sys.exit(f"앱이 아는 날씨 이름이 하나도 없다: {cond.get('word')} — 지우면 넓어진다")
    return out


def romanize(word):
    out = []
    for ch in word:
        n = ord(ch) - 0xAC00
        if not 0 <= n < 11172:
            continue
        out.append(CHO[n // 588] + JUNG[(n % 588) // 28] + JONG[n % 28])
    return "".join(out)


def new_id(word, taken):
    base = romanize(word)
    cand, suffix = base, iter("bcdefghijklmnopqrstuvwxyz")
    while cand in taken:
        cand = base + next(suffix)
    return cand


def clean(meaning):
    m = re.sub(r"[‘’]", "", meaning)
    m = re.sub(r"(?<=[가-힣])\d+", "", m)
    m = re.sub(r"「\d+」", "", m)
    return re.split(r"(?<=[다음함임말것])\. ", m.strip().rstrip("."))[0].rstrip(".")


def points_elsewhere(meaning):
    return bool(re.search(r"(준말|본말|높임말|낮춤말|잘못|방언)$", clean(meaning)))


def needs_rewrite(meaning):
    return len(meaning) > 40 or points_elsewhere(meaning) or bool(re.search(r"[0-9‘’「」]", meaning))


def history_ids(path=WORDS_IN_REPO):
    root = subprocess.run(["git", "-C", HERE, "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True, check=True).stdout.strip()
    shas = subprocess.run(["git", "-C", root, "log", "--format=%H", "--", path],
                          capture_output=True, text=True).stdout.split()
    ids = set()
    for h in shas:
        try:
            old = json.loads(subprocess.run(["git", "-C", root, "show", f"{h}:{path}"],
                                            capture_output=True, text=True).stdout)
        except json.JSONDecodeError:
            continue
        ids |= {w["id"] for w in old["words"]} | set(old.get("retired", []))
    return ids


def main(words_path):
    cur = json.load(open(words_path))
    taken = history_ids() | {w["id"] for w in cur["words"]} | set(cur.get("retired", []))
    rest_old = {t for l in open(os.path.join(HERE, "plain_words.txt")) if not l.startswith("#") for t in l.split()} | \
        {"어둑발", "짬", "보금자리", "꼬마", "주전부리", "새참", "적바림", "글월", "모꼬지"}
    groups = json.load(open(f"{LAB}/old-groups.json"))
    rewrites = {**json.load(open(f"{LAB}/meanings-rewritten.json")), **json.load(open(f"{LAB}/meanings-rewrite-v6.json"))}
    conds = json.load(open(f"{LAB}/word-conditions.json"))
    vocab = [w for w in json.load(open(f"{LAB}/words-expanded-v5.json")) if w["new"]]
    out = []
    for w in cur["words"]:
        w = dict(w)
        w["group"] = groups[w["word"]]
        if w["word"] in rest_old:
            w["rest"] = True
        out.append(w)
    for v in vocab:
        meaning = rewrites.get(v["word"]) or clean(v.get("meaning_dict", v["meaning"]))
        if needs_rewrite(meaning):
            sys.exit(f"새로 쓸 뜻풀이가 빠졌다: {v['word']} — meanings-rewrite-v6.json")
        e = {"id": new_id(v["word"], taken), "word": v["word"], "meaning": meaning,
             "times": [], "weathers": [], "seasons": [], "subjects": [], "group": v["cat"]}
        taken.add(e["id"])
        e.update({k: x for k, x in app_conditions(conds.get(v["word"], {})).items() if k in FIELDS})
        if v.get("rest"):
            e["rest"] = True
        out.append(e)
    cur["version"], cur["words"] = 6, out
    json.dump(cur, open(words_path, "w"), ensure_ascii=False, indent=1)
    print(len(out), "개")


if __name__ == "__main__":
    main(sys.argv[1])
