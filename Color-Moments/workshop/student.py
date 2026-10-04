"""2단계 학생 — Vision 값(라벨 확신도 1,303 + 사진 지문 768) 위의 층 하나로 170개 중 고르기.
judge 가 허락한 후보 밖은 가리고(학습·평가 모두) 선생(Qwen) 답을 따라 배운다.
실행: python student.py [선생 이름=qwen35] [--emb 인코더이름] [--with-vision] [--export 폴더]
  --emb: Vision 값 대신 embed.py 가 뽑은 인코더 값(3단계). coreml-<이름> 이면 embed/ 가 앱과 같은 전처리·Core ML 로 뽑은 값.
  --with-vision: 둘을 이어 붙인다. --export: 전체 사진 학습의 고르기 층을 WordHead.json/.bin 으로(앱 words.json 의 id 순서).
쉬게 한 단어(words.json rest)가 선생 답인 학습 사진은 뺀다. 학습에서 정답으로 못 본 단어는 bias -1e4 — 고르지 않는다.
→ 학습 곡선, 평가 94장 성적, 미판정 단어를 answers/.student-<이름>-<n>/ 에 쓴다."""
import json
import os
import sys

import numpy as np
import torch

import export_head

LAB = os.path.expanduser("~/mongdol-word-lab")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
EMB = sys.argv[sys.argv.index("--emb") + 1] if "--emb" in sys.argv else None
EXPORT = sys.argv[sys.argv.index("--export") + 1] if "--export" in sys.argv else None
for v in (EMB, EXPORT):
    if v in args:
        args.remove(v)
TEACHER = args[0] if args else "qwen35"
WITH_VISION = "--with-vision" in sys.argv
TAG = (EMB or "vision") + ("+vision" if EMB and WITH_VISION else "")
if EXPORT and (not EMB or WITH_VISION):
    sys.exit("--export 는 --emb 인코더 값만으로 학습할 때 (앱은 Vision 값을 넣지 않는다)")


def load_emb(name):
    if name.startswith("coreml-"):
        e = json.load(open(f"{LAB}/emb-{name}.json"))
        return dict(zip(e["keys"], np.array(e["x"], np.float32)))
    e = np.load(f"{LAB}/emb-{name}.npz")
    return dict(zip(e["keys"], e["x"]))


EMBS = load_emb(EMB) if EMB else None
APP_WORDS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../Shared/Word/words.json")))
RESTING = {w["id"] for w in APP_WORDS["words"] if w.get("rest")}
words = json.load(open(f"{LAB}/words.json"))
index = {w["id"]: i for i, w in enumerate(words)}
by_word = {w["word"]: w["id"] for w in words}


def load(split, answers, embs=None):
    embs = EMBS if embs is None else embs
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
            if wid in r["allowed"] and not (split == "train" and wid in RESTING):
                label = index[wid]
        vision = np.concatenate([f["classify"], f["print"]])
        if EMB:
            e = embs[r["key"]]
            X.append(np.concatenate([e, vision]) if WITH_VISION else e)
        else:
            X.append(vision)
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
    with torch.no_grad():
        unseen = torch.ones(len(words), dtype=torch.bool)
        unseen[torch.unique(yt)] = False
        layer.bias[unseen] = -1e4
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
print(f"[{TAG}] 학습 {len(ytr)}장 (선생 답이 후보 안, 쉬는 단어 아님), 평가 {len(kev)}장, 선생이 쓴 단어 {len(set(ytr))}개")

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
    out = f"{LAB}/answers/.student-{TAG}-{n}"
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

twin = "tinyclip-" + EMB[len("coreml-"):] if EMB and EMB.startswith("coreml-") else None
if twin and not WITH_VISION and os.path.exists(f"{LAB}/emb-{twin}.npz"):
    Xt2, _, yt2, _, _ = load("train", f"{TEACHER}-train", load_emb(twin))
    Xe2, _, _, ke2, _ = load("eval", TEACHER, load_emb(twin))
    assert ke2 == kev and (yt2 >= 0).sum() == len(ytr)
    pred2 = predict(fit(Xt2[yt2 >= 0][idx], Mtr[idx], ytr[idx], decay), Xe2, Mev)
    print(f"맥 일치: {twin}(PyTorch) 학생과 {EMB}(Core ML) 학생의 평가 {len(kev)}장 1등 일치 {(pred2 == pred).mean():.1%}"
          f" · 선생과 같은 답 {(pred2 == yev).mean():.0%} 대 {same:.0%}")

layer = model[0]
if EXPORT:
    pos = {w["id"]: i for i, w in enumerate(words)}
    ids = [w["id"] for w in APP_WORDS["words"]]
    W = np.zeros((len(ids), layer.weight.shape[1]), np.float32)
    bias = np.full(len(ids), -1e4, np.float32)
    for r, wid in enumerate(ids):
        if wid in pos:
            W[r] = layer.weight[pos[wid]].detach().numpy()
            bias[r] = layer.bias[pos[wid]].item()
    export_head.write(EXPORT, ids=ids, W=W, bias=bias, mean=model[1], std=model[2], words_version=APP_WORDS["version"])
    print(f"고르기 층 → {EXPORT}: {len(ids)}행 중 고를 수 있는 단어 {(bias > -1e4).sum()}개")
print(f"가중치 {sum(p.numel() for p in layer.parameters()):,}개 ≈ float16 {sum(p.numel() for p in layer.parameters()) * 2 / 1e6:.2f}MB")
