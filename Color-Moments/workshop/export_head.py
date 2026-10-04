"""고르기 층 → WordHead.json(id 목록·mean/std·bias) + WordHead.bin(float16 행렬). id 목록이 words.json 과 다르면 앱이 안 쓴다."""
import json
import os

import numpy as np


def write(out, ids, W, bias, mean, std, words_version):
    os.makedirs(out, exist_ok=True)
    json.dump({"format": 1, "wordsVersion": words_version, "dim": int(W.shape[1]), "ids": list(ids),
               "mean": [float(v) for v in mean], "std": [float(v) for v in std], "bias": [float(v) for v in bias]},
              open(os.path.join(out, "WordHead.json"), "w"), ensure_ascii=False)
    W.astype("<f2").tofile(os.path.join(out, "WordHead.bin"))
