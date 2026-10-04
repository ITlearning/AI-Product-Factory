"""고르기 층 → WordHead.json(id 목록·mean/std·bias) + WordHead.bin(float16 행렬). id 목록이 words.json 과 다르면 앱이 안 쓴다."""
import json
import os

import numpy as np


def write(out, ids, W, bias, mean, std, words_version, test=False):
    """test=True — 시험용 층. 앱은 출시 빌드에서 이 층을 깨진 모델로 보고 규칙 단어를 쓴다."""
    os.makedirs(out, exist_ok=True)
    meta = {"format": 1}
    if test:
        meta["test"] = True
    meta.update({"wordsVersion": words_version, "dim": int(W.shape[1]), "ids": list(ids),
                 "mean": [float(v) for v in mean], "std": [float(v) for v in std], "bias": [float(v) for v in bias]})
    json.dump(meta, open(os.path.join(out, "WordHead.json"), "w"), ensure_ascii=False)
    W.astype("<f2").tofile(os.path.join(out, "WordHead.bin"))
