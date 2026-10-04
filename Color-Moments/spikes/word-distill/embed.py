"""3단계 후보 — 이미지 인코더로 사진 값을 뽑는다. 결과: ~/mongdol-word-lab/emb-<이름>.npz (keys, x)
실행: python embed.py mobileclip2-s0 | mobileclip2-s2 | siglip2-b16"""
import glob
import os
import sys
import time

import numpy as np
import torch
from PIL import Image

LAB = os.path.expanduser("~/mongdol-word-lab")
name = sys.argv[1]
device = "mps" if torch.backends.mps.is_available() else "cpu"

if name.startswith("mobileclip2"):
    import open_clip
    arch = {"mobileclip2-s0": "MobileCLIP2-S0", "mobileclip2-s2": "MobileCLIP2-S2"}[name]
    model, _, preprocess = open_clip.create_model_and_transforms(arch, pretrained="dfndr2b")
    model.eval().to(device)
    encoder = model.visual
    encode = lambda batch: model.encode_image(batch)
else:
    from transformers import AutoImageProcessor, AutoModel
    repo = "google/siglip2-base-patch16-224"
    model = AutoModel.from_pretrained(repo).eval().to(device)
    processor = AutoImageProcessor.from_pretrained(repo)
    encoder = model.vision_model
    preprocess = lambda img: processor(images=img, return_tensors="pt")["pixel_values"][0]
    encode = lambda batch: model.get_image_features(pixel_values=batch)

params = sum(p.numel() for p in encoder.parameters())
print(f"{name}: 이미지 인코더 {params / 1e6:.1f}M 개 ≈ float16 {params * 2 / 1e6:.0f}MB · int8 {params / 1e6:.0f}MB", flush=True)

paths = sorted(glob.glob(f"{LAB}/photos/*.jpg")) + sorted(glob.glob(f"{LAB}/photos-train/*.jpg"))
keys, out = [], []
t = time.time()
with torch.no_grad():
    for i in range(0, len(paths), 32):
        chunk = paths[i:i + 32]
        batch = torch.stack([preprocess(Image.open(p).convert("RGB")) for p in chunk]).to(device)
        feats = encode(batch)
        feats = getattr(feats, "pooler_output", feats)
        out.append(torch.nn.functional.normalize(feats.float(), dim=-1).cpu().numpy())
        keys += [os.path.basename(p)[:-4] for p in chunk]
x = np.concatenate(out)
np.savez(f"{LAB}/emb-{name}.npz", keys=np.array(keys), x=x)
print(f"{len(keys)}장 · {x.shape[1]}차원 · {time.time() - t:.0f}초", flush=True)
