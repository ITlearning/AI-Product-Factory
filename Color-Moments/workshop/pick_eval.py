"""survey.jsonl 에서 평가용 46장을 갈래별로 고른다. 결과: ~/mongdol-word-lab/eval-extra.json"""
import json
import os
import random

LAB = os.path.expanduser("~/mongdol-word-lab")
rows = [json.loads(l) for l in open(f"{LAB}/survey.jsonl")]
random.seed(20261003)
random.shuffle(rows)

PRIVATE = {"screenshot", "document", "passport", "receipt", "printed_page", "chart", "diagram",
           "map", "ticket", "atm", "wedding", "bride", "groom", "graduation", "illustrations", "art"}


def labels(r):
    return {l for l, c in r["labels"]}


def hour(r):
    return int(r["local"][11:13])


def month(r):
    return int(r["local"][5:7])


def night(r):
    return hour(r) >= 20 or hour(r) < 5


def usable(r):
    return (33 <= r["lat"] <= 39 and 124 <= r["lon"] <= 132 and r["labels"] and not labels(r) & PRIVATE and r["maxFace"] < 0.01
            and r["textChars"] < 30)


def has(*names, when=None):
    return lambda r: labels(r) & set(names) and (when is None or when(r))


BUCKETS = [
    ("대상", "꽃", 3, has("flower", "bouquet", "blossom", "flower_arrangement", "rose", "daisy", "decorative_plant")),
    ("대상", "동물", 2, has("cat", "dog", "canine", "feline", "bird", "animal")),
    ("대상", "장난감", 2, has("stuffed_animals", "toy", "blocks", "figurine", "origami")),
    ("대상", "꾸러미", 1, has("cardboard_box", "paper_bag", "gift", "carton")),
    ("대상", "글씨·책", 1, has("handwriting", "book", "pen", "office_supplies")),
    ("대상", "차림새", 1, has("scarf", "beanie", "hat", "footwear", "sneaker")),
    ("대상", "물건", 1, has("camera", "musical_instrument", "guitar", "timepiece", "headphones")),
    ("대상", "장식", 1, has("christmas_tree", "christmas_decoration", "balloon")),
    ("순간", "축하", 2, has("birthday_cake", "cake", "celebration")),
    ("순간", "술", 2, has("beer", "wine", "liquor", "red_wine", "wine_bottle", "soda", "drink")),
    ("순간", "밤참", 2, has("ramen", "fried_chicken", "food", "soup", "pizza", when=night)),
    ("순간", "주전부리", 2, has("dessert", "baked_goods", "ice_cream", "candy", "coffee", "fruit", "bread",
                             when=lambda r: 13 <= hour(r) < 18)),
    ("순간", "부엌", 2, has("cookware", "stove", "pot_cooking", "cutting_board", "pan")),
    ("순간", "보금자리", 1, has("living_room", "bedroom", "sofa", "bed", "bedding", "pillow", "interior_room")),
    ("순간", "공연", 1, has("concert", "performance", "stadium", "arena", "auditorium")),
    ("날씨", "눈", 2, has("snow", "blizzard", "snowman", "frozen")),
    ("날씨", "비", 1, has("umbrella", "storm")),
    ("날씨", "해넘이", 2, has("sunset_sunrise")),
    ("날씨", "밤거리", 3, has("street", "lamppost", "light", "storefront", "night_sky", "cityscape", "road",
                           when=night)),
    ("날씨", "물빛", 2, has("ocean", "lake", "water_body", "waterways", "river",
                          when=lambda r: "sky" in labels(r))),
    ("날씨", "계절꽃", 2, has("blossom", "maple_tree", "foliage", "tree",
                           when=lambda r: month(r) in (3, 4, 10, 11))),
    ("날씨", "불", 1, has("fire", "embers", "sparkler", "pyrotechnics")),
    ("날씨", "흐린 하늘", 1, has("cloudy", when=lambda r: "people" not in labels(r))),
    ("평범", "특징 없음", 8, lambda r: not labels(r) & {"people", "food", "tableware", "utensil"} and len(r["labels"]) <= 3),
]

# 앨범에서 Tabber 가 뺀 사진은 다시 고르지 않고, 남은 사진은 그대로 둔 채 빈자리만 같은 갈래에서 채운다.
previous = json.load(open(f"{LAB}/eval-extra.json")) if os.path.exists(f"{LAB}/album-now.txt") else []
in_album = set(open(f"{LAB}/album-now.txt").read().split()) if previous else set()
removed = {p["id"] for p in previous if p["id"] not in in_album}
picked = [p for p in previous if p["id"] in in_album]
days = {p["local"][:10] for p in previous}
for group, name, n, test in BUCKETS:
    got = sum(p["bucket"] == name for p in picked)
    for r in rows:
        if got == n:
            break
        if r["id"] in removed or r["id"] in {p["id"] for p in picked} or r["local"][:10] in days:
            continue
        if usable(r) and test(r):
            picked.append({**r, "group": group, "bucket": name})
            days.add(r["local"][:10])
            got += 1
    if got < n:
        print(f"모자람: {name} {got}/{n}")

print(len(picked), "장, 밤", sum(night(p) for p in picked))
json.dump(picked, open(f"{LAB}/eval-extra.json", "w"), ensure_ascii=False, indent=1)
for p in picked:
    print(p["group"], p["bucket"], p["local"], [l for l, _ in p["labels"][:4]])
