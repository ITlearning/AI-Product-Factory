"""2단계 학생 — Vision 값(라벨 확신도 1,303 + 사진 지문 768) 위의 층 하나로 170개 중 고르기.
judge 가 허락한 후보 밖은 가리고(학습·평가 모두) 선생(Qwen) 답을 따라 배운다.
실행: python student.py [선생 이름=qwen35] → 학습 곡선, 평가 94장 성적, 미판정 단어를 answers/student-<n>/ 에 쓴다."""
import json
import os
import sys

import numpy as np
import torch

LAB = os.path.expanduser("~/mongdol-word-lab")
TEACHER = sys.argv[1] if len(sys.argv) > 1 else "qwen35"
words = json.load(open(f"{LAB}/words.json"))
index = {w["id"]: i for i, w in enumerate(words)}
by_word = {w["word"]: w["id"] for w in words}


def load(split, answers):
    rows = json.load(open(f"{LAB}/{split}.json"))
    feats = json.load(open(f"{LAB}/{'train-features' if split == 'train' else 'features'}.json"))["photos"]
    X, M, y, keys = [], [], [], []
    for r in rows:
        f = feats.get(r["key"])
        if not f or not f["print"]:
            continue
        mask = np.zeros(len(words), bool)
        mask[[index[i] for i in r["allowed"]]] = True
        label = -1
        p = f"{LAB}/answers/{answers}/{r['key']}.json"
        if os.path.exists(p):
            wid = by_word.get(json.load(open(p)).get("word", "").strip())
            if wid in r["allowed"]:
                label = index[wid]
        X.append(np.concatenate([f["classify"], f["print"]]))
        M.append(mask)
        y.append(label)
        keys.append(r["key"])
    return np.array(X, np.float32), np.array(M), np.array(y), keys, rows


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
    return layer, mean, std


def predict(model, X, M):
    layer, mean, std = model
    with torch.no_grad():
        logits = layer(torch.tensor((X - mean) / std)).masked_fill(~torch.tensor(M), -1e9)
    return logits.argmax(1).numpy()


Xtr, Mtr, ytr, _, _ = load("train", f"{TEACHER}-train")
keep = ytr >= 0
Xtr, Mtr, ytr = Xtr[keep], Mtr[keep], ytr[keep]
Xev, Mev, yev, kev, rows_ev = load("eval", TEACHER)
print(f"학습 {len(ytr)}장 (선생 답이 후보 안), 평가 {len(kev)}장, 선생이 쓴 단어 {len(set(ytr))}개")

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

verdicts = json.load(open(f"{LAB}/verdicts.json"))
plain = {t for l in open(os.path.join(os.path.dirname(__file__), "plain_words.txt")) if not l.startswith("#") for t in l.split()}
for n in [1000, 2000, len(ytr)]:
    idx = order[:n]
    model = fit(Xtr[idx], Mtr[idx], ytr[idx], decay)
    pred = predict(model, Xev, Mev)
    same = (pred == yev).mean()
    out = f"{LAB}/answers/student-{n}"
    os.makedirs(out, exist_ok=True)
    good = judged = 0
    for k, p in zip(kev, pred):
        wid = words[p]["id"]
        json.dump({"word": words[p]["word"]}, open(f"{out}/{k}.json", "w"), ensure_ascii=False)
        v = verdicts.get(k, {})
        if wid in v:
            judged += 1
            good += v[wid] == "good"
    plain_rate = np.mean([words[p]["word"] in plain for p in pred])
    print(f"[{n}장] 평가 94장에서 선생과 같은 답 {same:.0%} · 판정된 {judged}장 중 맞음 {good} · 미판정 {len(kev) - judged} · 이름표 {plain_rate:.0%}")

layer = model[0]
print(f"가중치 {sum(p.numel() for p in layer.parameters()):,}개 ≈ float16 {sum(p.numel() for p in layer.parameters()) * 2 / 1e6:.2f}MB")
