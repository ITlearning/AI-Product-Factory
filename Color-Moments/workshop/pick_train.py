"""학습용 사진 3,000장 — 평가 사진과 다른 날, 하루 15장까지. 해외 사진도 넣는다(extract 가 앱처럼 현지 시각으로 판정). 결과: ~/mongdol-word-lab/train-ids.txt"""
import collections
import json
import os
import random

LAB = os.path.expanduser("~/mongdol-word-lab")
N = 3000
rows = [json.loads(l) for l in open(f"{LAB}/survey.jsonl")]
eval_days = {p["local"][:10] for p in json.load(open(f"{LAB}/eval-extra.json"))}
SKIP = {"screenshot", "document", "printed_page", "receipt", "passport", "chart", "diagram"}
pool = [r for r in rows if r["local"][:10] not in eval_days
        and not {l for l, _ in r["labels"]} & SKIP]
random.seed(20261004)
random.shuffle(pool)
per_day, picked = collections.Counter(), []
for r in pool:
    if len(picked) == N:
        break
    if per_day[r["local"][:10]] < 15:
        per_day[r["local"][:10]] += 1
        picked.append(r["id"])
open(f"{LAB}/train-ids.txt", "w").write("\n".join(picked) + "\n")
print(f"후보 {len(pool)}장 → {len(picked)}장, {len(per_day)}일")
