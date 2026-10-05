"""기기(iPhone) 학생 계산과 맥 계산 맞춰 보기 + 기기 시간 — Task 10.
기기(Debug 빌드): 실험 화면 → 「학생 모델 재기」 → 표·그림 보내기 → 맥의 한 폴더에(probe.tsv + m-*.png).
실행: embed/.build/embed ~/mongdol-word-lab/WordEncoder-8m.mlpackage probe <폴더> && ~/.venvs/mongdol-word-lab/bin/python parity.py <폴더>
1) 계산 일치: 기기가 모델에 넣은 224px 그림을 맥 Core ML 에 그대로 넣고, 앱 고르기 층(fp16)·기기 후보로 1등 — 기기 1등과 같은가(기준 ≥ 95%, 미달이면 fp16 인코더).
2) 실제 입력: 기기 1등이 맥 학생(1024px 사진) 1등과 같은가 — 참고. 사진 앱 썸네일이 맥 내보내기와 달라 여기선 낮게 나온다.
3) 시간: 한 장(라벨+인코더+층) ≤ 200ms, 첫 사진 따로.
기기 단어는 answers/.device-iphone/ 에 써서 judge.py --arms 로 판정할 수 있다."""
import csv
import json
import os
import statistics
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
LAB = os.path.expanduser(os.environ.get("MONGDOL_LAB", "~/mongdol-word-lab"))
MAC = ".student-coreml-8m-v6-p0.5"
folder = sys.argv[1]
rows = list(csv.DictReader(open(f"{folder}/probe.tsv", encoding="utf-8"), delimiter="\t"))

head = json.load(open(f"{HERE}/../ColorMoments/App/WordHead.json"))
W = np.fromfile(f"{HERE}/../ColorMoments/App/WordHead.bin", dtype=np.float16).astype(np.float32).reshape(len(head["ids"]), head["dim"])
mean, std, bias = (np.array(head[k], np.float32) for k in ("mean", "std", "bias"))
pos = {i: n for n, i in enumerate(head["ids"])}
word_of = {w["id"]: w["word"] for w in json.load(open(f"{HERE}/../Shared/Word/words.json"))["words"]}
emb = json.load(open(f"{LAB}/emb-coreml-probe.json"))
E = dict(zip(emb["keys"], np.array(emb["x"], np.float32)))


def mac_top(x, pool):
    idx = [pos[i] for i in pool if bias[pos[i]] > -1e3]
    if not idx:
        return "없음", 0.0
    s = W[idx] @ ((x - mean) / std) + bias[idx]
    order = np.argsort(-s)
    return word_of[head["ids"][idx[order[0]]]], float(s[order[0]] - s[order[1]]) if len(order) > 1 else 9.0


same, diff = 0, []
for r in rows:
    if r["key"] not in E:
        continue
    w, gap = mac_top(E[r["key"]], [i for i in r["pool"].split(",") if i])
    if w == r["word"]:
        same += 1
    else:
        diff.append((r["key"], r["word"], w, gap))
n = same + len(diff)
print(f"1) 계산 일치(같은 224px 그림·같은 후보) {same}/{n} = {same / max(n, 1):.1%} {'✓' if n and same / n >= 0.95 else '✗'} (기준 ≥ 95%)")
for key, phone, mac, gap in diff:
    print(f"   {key}  기기 {phone} · 맥 {mac} (맥 1·2등 차 {gap:.3f})")

out = f"{LAB}/answers/.device-iphone"
os.makedirs(out, exist_ok=True)
both = agree = 0
for r in rows:
    json.dump({"word": r["word"]}, open(f"{out}/{r['key']}.json", "w"), ensure_ascii=False)
    p = f"{LAB}/answers/{MAC}/{r['key']}.json"
    if os.path.exists(p):
        both += 1
        agree += json.load(open(p)).get("word") == r["word"]
print(f"2) 실제 입력: 기기 1등 = 맥 학생(1024px) 1등 {agree}/{both} (참고) · 기기 단어 → {out}")

ms = [int(r["label_ms"]) + int(r["score_ms"]) for r in rows]
if len(ms) > 1:
    q = sorted(ms[1:])
    p90 = q[min(len(q) - 1, int(len(q) * 0.9))]
    print(f"3) 첫 사진 {ms[0]}ms · 나머지 {len(q)}장 중앙값 {statistics.median(q):.0f}ms · 90% {p90}ms · 가장 느림 {q[-1]}ms "
          f"{'✓' if p90 <= 200 else '✗'} (기준 ≤ 200ms)")
    for col, name in (("label_ms", "라벨"), ("score_ms", "인코더+층"), ("thumb_ms", "썸네일(따로)")):
        print(f"   {name} 중앙값 {statistics.median(int(r[col]) for r in rows[1:]):.0f}ms")
