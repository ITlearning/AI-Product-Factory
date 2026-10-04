"""2단계 학생 — 인코더 사진 값 위의 층 하나로 앱 v6 단어(words.json) 중 고르기.
후보 = 행 allowed(앱 judge == .yes) 중 쉬지 않는 단어 — 앱 WordPicker.modelCandidates 와 같다. 학습·평가 모두 후보 밖은 가린다.
선생(Qwen) 답은 단어 글자로 v6 id 를 찾고, 못 찾거나 후보 밖이면 버린다. 학습에서 정답으로 못 본 단어는 bias -1e4 — 고르지 않는다.
실행: python student.py [선생 이름=qwen35-v4] --emb 인코더이름 [--export 폴더]
  --emb: embed.py 가 뽑은 값. coreml-<이름> 이면 embed/ 가 앱과 같은 전처리·Core ML 로 뽑은 값(emb-<이름>.json).
  --export: 전체 학습 고르기 층을 WordHead.json/.bin 으로(앱 words.json 의 id 순서).
자료: $MONGDOL_LAB(기본 ~/mongdol-word-lab)/v6/{train,eval,fresh}.json, answers/<선생>-train·<선생>/.
→ decay 고르기, 학습 곡선, 평가 94장 성적, eval+fresh 답을 answers/.student-<emb>-v6/ 에, 단어 쏠림 숫자."""
import json
import os
import shutil
import sys
from collections import Counter

import numpy as np
import torch

import export_head

LAB = os.path.expanduser(os.environ.get("MONGDOL_LAB", "~/mongdol-word-lab"))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
if "--emb" not in sys.argv:
    sys.exit("--emb 인코더이름 이 필요하다 (앱은 인코더 값만 쓴다)")
EMB = sys.argv[sys.argv.index("--emb") + 1]
EXPORT = sys.argv[sys.argv.index("--export") + 1] if "--export" in sys.argv else None
for v in (EMB, EXPORT):
    if v in args:
        args.remove(v)
TEACHER = args[0] if args else "qwen35-v4"
TAG = f"{EMB}-v6"


def load_emb(name):
    if name.startswith("coreml-"):
        e = json.load(open(f"{LAB}/emb-{name}.json"))
        return dict(zip(e["keys"], np.array(e["x"], np.float32)))
    e = np.load(f"{LAB}/emb-{name}.npz")
    return dict(zip(e["keys"], e["x"]))


APP_WORDS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../Shared/Word/words.json")))
words = APP_WORDS["words"]
index = {w["id"]: i for i, w in enumerate(words)}
by_word = {w["word"]: w["id"] for w in words}
resting = np.array([bool(w.get("rest")) for w in words])


def load(split, answers, embs):
    """행 → (값, 후보 마스크, 선생 답 행 번호 또는 -1, 키, 행). 사진 값이 없는 행은 건너뛴다."""
    rows = json.load(open(f"{LAB}/v6/{split}.json"))
    X, M, y, keys, kept = [], [], [], [], []
    dropped = {"v6 에 없는 글자": 0, "쉬는 단어": 0, "후보 밖": 0}
    for r in rows:
        if r["key"] not in embs:
            continue
        mask = np.zeros(len(words), bool)
        mask[[index[i] for i in r["allowed"] if i in index]] = True
        mask &= ~resting
        label = -1
        p = f"{LAB}/answers/{answers}/{r['key']}.json" if answers else None
        if p and os.path.exists(p):
            i = index.get(by_word.get(json.load(open(p)).get("word", "").strip()), -1)
            if i >= 0 and mask[i]:
                label = i
            else:
                dropped["v6 에 없는 글자" if i < 0 else "쉬는 단어" if resting[i] else "후보 밖"] += 1
        X.append(embs[r["key"]])
        M.append(mask)
        y.append(label)
        keys.append(r["key"])
        kept.append(r)
    if len(kept) < len(rows):
        print(f"  {split}: 사진 값 없는 {len(rows) - len(kept)}장 건너뜀")
    if any(dropped.values()):
        print(f"  {split}: 버린 선생 답 " + " · ".join(f"{k} {v}" for k, v in dropped.items()))
    return np.array(X, np.float32).reshape(len(X), -1), np.array(M).reshape(len(M), len(words)), np.array(y, int), keys, kept


def fit(X, M, y, decay, epochs=300):
    torch.manual_seed(0)
    mean, std = X.mean(0), X.std(0) + 1e-6
    Xt = torch.tensor((X - mean) / std)
    Mt, yt = torch.tensor(M), torch.tensor(y)
    layer = torch.nn.Linear(X.shape[1], len(words))
    opt = torch.optim.AdamW(layer.parameters(), lr=1e-3, weight_decay=decay)
    for _ in range(epochs):
        opt.zero_grad()
        logits = layer(Xt).masked_fill(~Mt, -1e9)
        torch.nn.functional.cross_entropy(logits, yt).backward()
        opt.step()
    with torch.no_grad():
        unseen = torch.ones(len(words), dtype=torch.bool)
        unseen[torch.unique(yt)] = False
        layer.bias[unseen] = -1e4
    return layer, mean, std


def scores(model, X, M):
    layer, mean, std = model
    with torch.no_grad():
        return layer(torch.tensor((X - mean) / std)).masked_fill(~torch.tensor(M), -1e9).numpy()


def predict(model, X, M):
    return scores(model, X, M).argmax(1)


EMBS = load_emb(EMB)
Xtr, Mtr, ytr, ktr, _ = load("train", f"{TEACHER}-train", EMBS)
keep = ytr >= 0
Xtr, Mtr, ytr, ktr = Xtr[keep], Mtr[keep], ytr[keep], [k for k, f in zip(ktr, keep) if f]
Xev, Mev, yev, kev, rows_ev = load("eval", TEACHER, EMBS)
sets_ev = np.array([r["set"] for r in rows_ev])
print(f"[{TAG}] 학습 {len(ytr)}장 (선생 답이 후보 안), 평가 {len(kev)}장 (선생 답 있음 {(yev >= 0).sum()}), 선생이 쓴 단어 {len(set(ytr))}개")

rng = np.random.default_rng(0)
order = rng.permutation(len(ytr))
hold = order[: len(ytr) // 10]
rest = order[len(ytr) // 10:]
best = None
for decay in [1e-4, 1e-2, 1e-1, 1.0]:
    acc = (predict(fit(Xtr[rest], Mtr[rest], ytr[rest], decay), Xtr[hold], Mtr[hold]) == ytr[hold]).mean()
    print(f"  decay {decay}: 떼어 둔 학습 사진에서 선생과 같은 답 {acc:.0%}")
    best = max(best or (acc, decay), (acc, decay))
decay = best[1]

for n in sorted({min(n, len(ytr)) for n in (1000, 2000)} | {len(ytr)}):
    idx = order[:n]
    model = fit(Xtr[idx], Mtr[idx], ytr[idx], decay)
    pred = predict(model, Xev, Mev)
    by_set = " · ".join(f"{s} {(pred == yev)[sets_ev == s].mean():.0%}" for s in ("mongdol", "extra") if (sets_ev == s).any())
    print(f"[{n}장] 평가 {len(kev)}장에서 선생과 같은 답 {(pred == yev).mean():.0%} ({by_set})")

if os.path.exists(f"{LAB}/v6/fresh.json"):
    Xfr, Mfr, _, kfr, rows_fr = load("fresh", None, EMBS)
else:
    Xfr, Mfr, kfr, rows_fr = None, None, [], []
out = f"{LAB}/answers/.student-{TAG}"
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)
top_by_set, fallbacks = {}, 0
for X, M, keys, rows in ((Xev, Mev, kev, rows_ev), (Xfr, Mfr, kfr, rows_fr)):
    if not keys:
        continue
    for k, s, m, r in zip(keys, scores(model, X, M), M, rows):
        # 앱(WordScorer)은 bias ≤ -1e3 단어를 점수에서 빼고, 남는 후보가 없으면 규칙 단어로 간다.
        ranked = [int(i) for i in np.argsort(-s, kind="stable") if m[i] and s[i] > -1e3][:20]
        top = words[ranked[0]] if ranked else (words[index[r["rule"]]] if r.get("rule") in index else None)
        json.dump({"word": top and top["word"], "id": top and top["id"], "ranked": [words[i]["id"] for i in ranked],
                   "fallback": None if ranked else "rule"}, open(f"{out}/{k}.json", "w"), ensure_ascii=False)
        fallbacks += not ranked
        if top:
            top_by_set.setdefault(r["set"], []).append(top["id"])
print(f"답 → {out}: 평가 {len(kev)}장 + fresh {len(kfr)}장 (고를 단어가 없어 규칙으로 간 사진 {fallbacks}장)")

twin = "tinyclip-" + EMB[len("coreml-"):] if EMB.startswith("coreml-") else None
if twin and os.path.exists(f"{LAB}/emb-{twin}.npz"):
    E2 = load_emb(twin)
    if all(k in E2 for k in ktr + kev):
        Xt2 = np.array([E2[k] for k in ktr], np.float32)
        Xe2 = np.array([E2[k] for k in kev], np.float32)
        pred2 = predict(fit(Xt2[idx], Mtr[idx], ytr[idx], decay), Xe2, Mev)
        print(f"맥 일치: {twin}(PyTorch) 학생과 {EMB}(Core ML) 학생의 평가 {len(kev)}장 1등 일치 {(pred2 == pred).mean():.1%}"
              f" · 선생과 같은 답 {(pred2 == yev).mean():.0%} 대 {(pred == yev).mean():.0%}")
    else:
        print(f"맥 일치: {twin}.npz 에 학습·평가 키가 다 있지 않아 건너뜀")

counts = Counter(ytr.tolist())
print(f"학습 정답으로 나온 단어: 1번 이상 {len(counts)}개 · 3번 이상 {sum(c >= 3 for c in counts.values())}개 (전체 {len(words)}, 쉬는 단어 {resting.sum()})")
if top_by_set.get("fresh500"):
    tops = top_by_set["fresh500"]
    c = Counter(tops)
    print(f"fresh500 {len(tops)}장: 학생 1등 서로 다른 단어 {len(c)}개 · 상위 20개 비중 {sum(v for _, v in c.most_common(20)) / len(tops):.0%}")

layer = model[0]
if EXPORT:
    bias = layer.bias.detach().numpy().astype(np.float32)
    export_head.write(EXPORT, ids=[w["id"] for w in words], W=layer.weight.detach().numpy().astype(np.float32), bias=bias,
                      mean=model[1], std=model[2], words_version=APP_WORDS["version"])
    print(f"고르기 층 → {EXPORT}: {len(words)}행 중 고를 수 있는 단어 {(bias > -1e4).sum()}개")
print(f"가중치 {sum(p.numel() for p in layer.parameters()):,}개 ≈ float16 {sum(p.numel() for p in layer.parameters()) * 2 / 1e6:.2f}MB")
